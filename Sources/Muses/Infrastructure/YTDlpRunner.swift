import Foundation
import os
import Darwin

/// Numeric observations only: never log or persist arguments, media identity or output.
final class YTDlpRunTrace: @unchecked Sendable {
    enum Stage: Int, Sendable {
        case requested, slotAcquired, launchBegin, launched, stdoutFirst, stderrFirst
        case processExit, stdoutEOF, stderrEOF, returned, timeout, cancelled, launchFailed
        case parseBegin, parseEnd
        case extractorStart, webpage, playerAPI, playerJavaScript, challenge, formatCheck
        case httpForbidden, httpRateLimit, extractorError
    }
    struct Event: Sendable {
        let stage: Stage
        let elapsed: Double
        let value: Int
    }
    private let start = ContinuousClock.now
    private let sink: @Sendable (Event) -> Void
    private struct Progress { var tail = ""; var seen: Set<Stage> = [] }
    private let progress = OSAllocatedUnfairLock(initialState: Progress())
    private let captureProgress: Bool

    init(captureProgress: Bool = false, sink: (@Sendable (Event) -> Void)? = nil) {
        self.captureProgress = captureProgress
        let id = UInt64.random(in: 1...UInt64.max)
        let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.muses.runner", category: "ResolverTiming")
        self.sink = sink ?? { event in
            log.info("request=\(id, privacy: .public) stage=\(event.stage.rawValue, privacy: .public) elapsed=\(event.elapsed, privacy: .public) value=\(event.value, privacy: .public)")
        }
        record(.requested)
    }

    func record(_ stage: Stage, value: Int = 0) {
        let duration = start.duration(to: .now).components
        sink(Event(stage: stage, elapsed: Double(duration.seconds) + Double(duration.attoseconds) / 1e18, value: value))
    }

    /// Only fixed upstream phrases become events. The bounded overlap handles
    /// split reads; raw text never enters a log, event or persistent artifact.
    func consumeStderr(_ bytes: some Collection<UInt8>) {
        guard captureProgress else { return }
        let chunk = String(decoding: bytes, as: UTF8.self)
        let stages = progress.withLock { state -> [Stage] in
            let text = state.tail + chunk
            state.tail = String(text.suffix(512))
            let patterns: [(String, Stage)] = [
                ("Extracting URL", .extractorStart), ("Downloading webpage", .webpage),
                ("player API JSON", .playerAPI), ("Downloading player ", .playerJavaScript),
                ("Solving JS challenges", .challenge), ("Testing format", .formatCheck),
                ("HTTP Error 403", .httpForbidden), ("HTTP Error 429", .httpRateLimit),
                ("ERROR:", .extractorError)
            ]
            return patterns.compactMap { phrase, stage in
                text.contains(phrase) && state.seen.insert(stage).inserted ? stage : nil
            }
        }
        for stage in stages { record(stage) }
    }

    func finishStderr() { progress.withLock { $0.tail = "" } }
}

/// Bridges `Process.terminationHandler` to async code with a Dispatch deadline.
/// Dispatch owns the deadline, so timeout delivery does not depend on Swift's
/// cooperative executor having spare capacity under CI or application load.
private final class ProcessDeadline: @unchecked Sendable {
    private enum WaitAction {
        case schedule
        case resume(Bool)
    }

    private enum State {
        case pending
        case waiting(CheckedContinuation<Bool, Never>)
        case finished(Bool)
    }

    private let state = OSAllocatedUnfairLock(initialState: State.pending)

    func processDidExit() { finish(timedOut: false) }

    func wait(timeout: TimeInterval) async -> Bool {
        await withCheckedContinuation { continuation in
            let action = state.withLock { state -> WaitAction in
                switch state {
                case .pending:
                    state = .waiting(continuation)
                    return .schedule
                case .finished(let timedOut):
                    return .resume(timedOut)
                case .waiting:
                    preconditionFailure("ProcessDeadline may only be awaited once")
                }
            }
            switch action {
            case .resume(let timedOut):
                continuation.resume(returning: timedOut)
            case .schedule:
                DispatchQueue.global(qos: .utility).asyncAfter(
                    deadline: .now() + max(0, timeout)
                ) { [self] in
                    finish(timedOut: true)
                }
            }
        }
    }

    private func finish(timedOut: Bool) {
        let continuation = state.withLock { state -> CheckedContinuation<Bool, Never>? in
            switch state {
            case .pending:
                state = .finished(timedOut)
                return nil
            case .waiting(let waiting):
                state = .finished(timedOut)
                return waiting
            case .finished:
                return nil
            }
        }
        continuation?.resume(returning: timedOut)
    }
}

/// Runs yt-dlp subprocesses off the `@MainActor`, with concurrency throttling.
///
/// A previous implementation ran `Process.run()` plus a 20ms `process.isRunning`
/// poll on the `@MainActor`; a cold start of Home could spawn ~6 yt-dlp processes,
/// each pinning the main thread with polling. This runner moves every blocking
/// subprocess operation (`run()` / `waitUntilExit()` / pipe reads) into
/// `Task.detached`, so the main thread just suspends at the `await` instead of
/// polling; cancellable background slots and one foreground slot bound concurrency.
actor YTDlpRunner {

    /// Production default 2, so a cold start does not launch ~6 yt-dlp processes
    /// at once and bog the system down; injectable for tests.
    private let maxConcurrent: Int
    private var inFlight = 0
    private var interactiveInFlight = 0
    private struct Waiter {
        let id: UUID
        let interactive: Bool
        let continuation: CheckedContinuation<Void, Error>
    }
    private var waiters: [Waiter] = []

    init(maxConcurrent: Int = 2) {
        self.maxConcurrent = max(1, maxConcurrent)
    }

    /// Reserve a separate single slot for the user's current selection so
    /// discovery and prefetch cannot queue ahead of first sound.
    func run(executablePath: String, args: [String], timeout: TimeInterval,
             stdoutLimit: Int = 64 * 1024 * 1024,
             stderrLimit: Int = 1024 * 1024,
             trace: YTDlpRunTrace? = nil) async throws -> (stdout: String, stderr: String) {
        let trace = trace ?? YTDlpRunTrace()
        guard stdoutLimit >= 0, stderrLimit >= 0 else {
            throw YTDlpBridge.YTDlpError.parseFailed("Invalid subprocess output limit")
        }
        let interactive = YTDlpRequestPriority.interactive
        let started = Date()
        do { try await acquire(interactive: interactive, timeout: timeout) }
        catch {
            trace.record(error is CancellationError ? .cancelled : .timeout)
            throw error
        }
        trace.record(.slotAcquired)
        defer { release(interactive: interactive) }
        try Task.checkCancellation()
        let remaining = timeout - Date().timeIntervalSince(started)
        guard remaining > 0 else { throw YTDlpBridge.YTDlpError.timeout }
        return try await Self.executeDetached(executablePath: executablePath, args: args, timeout: remaining,
            stdoutLimit: stdoutLimit, stderrLimit: stderrLimit, trace: trace)
    }

    var inFlightCount: Int { inFlight + interactiveInFlight }
    var waitingCount: Int { waiters.count }

    private func acquire(interactive: Bool, timeout: TimeInterval) async throws {
        try Task.checkCancellation()
        if interactive ? interactiveInFlight < 1 : inFlight < maxConcurrent {
            if interactive { interactiveInFlight += 1 } else { inFlight += 1 }
            return
        }
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                waiters.append(Waiter(id: id, interactive: interactive, continuation: continuation))
                Task {
                    try? await Task.sleep(for: .seconds(max(0, timeout)))
                    self.timeoutWaiter(id)
                }
            }
        } onCancel: {
            Task { await self.cancelWaiter(id) }
        }
    }

    private func timeoutWaiter(_ id: UUID) {
        guard let index = waiters.firstIndex(where: { $0.id == id }) else { return }
        waiters.remove(at: index).continuation.resume(throwing: YTDlpBridge.YTDlpError.timeout)
    }

    private func cancelWaiter(_ id: UUID) {
        guard let index = waiters.firstIndex(where: { $0.id == id }) else { return }
        waiters.remove(at: index).continuation.resume(throwing: CancellationError())
    }

    private func release(interactive: Bool) {
        if let index = waiters.firstIndex(where: { $0.interactive == interactive }) {
            waiters.remove(at: index).continuation.resume()
        } else if interactive { interactiveInFlight -= 1 }
        else { inFlight -= 1 }
    }

    // MARK: - Detached execution

    /// Actually spawns the subprocess; runs entirely in `Task.detached` and
    /// touches no actor or the main thread.
    private static func executeDetached(executablePath: String,
                                        args: [String],
                                        timeout: TimeInterval,
                                        stdoutLimit: Int,
                                        stderrLimit: Int,
                                        trace: YTDlpRunTrace) async throws
        -> (stdout: String, stderr: String) {
        let processControl = CancellableYTDlpProcess()
        let worker = Task.detached(priority: .utility) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = args
            // Keep the bundled runtime's cache in this app's own namespace.
            var environment = ProcessInfo.processInfo.environment
            environment["DENO_DIR"] = MusesDataPaths.caches.appending(path: "deno").path
            environment["DENO_NO_UPDATE_CHECK"] = "1"
            process.environment = environment

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe
            let outHandle = stdoutPipe.fileHandleForReading
            let errHandle = stderrPipe.fileHandleForReading

            // Read both pipes concurrently so large outputs cannot fill the
            // pipe buffers and deadlock. Blocking reads must stay off Swift's
            // cooperative pool, including for detached tasks: a background
            // extraction must not occupy the workers needed to launch playback.
            let outRead = Task.detached(priority: .utility) {
                await Self.readPipe(outHandle, limit: stdoutLimit, retainTail: false, trace: trace)
            }
            let errRead = Task.detached(priority: .utility) {
                await Self.readPipe(errHandle, limit: stderrLimit, retainTail: true, trace: trace)
            }

            let deadline = ProcessDeadline()
            process.terminationHandler = { child in
                trace.record(.processExit, value: Int(child.terminationStatus))
                deadline.processDidExit()
            }

            do {
                try Task.checkCancellation()
                trace.record(.launchBegin)
                try process.run()
                trace.record(.launched)
                processControl.started(process)
            } catch {
                trace.record(.launchFailed)
                stdoutPipe.fileHandleForWriting.closeFile()
                stderrPipe.fileHandleForWriting.closeFile()
                _ = await outRead.value
                _ = await errRead.value
                if error is CancellationError { throw error }
                throw YTDlpBridge.YTDlpError.notFound
            }

            // A detached Swift watchdog can begin late on a saturated executor.
            // The Dispatch-backed deadline starts from launch deterministically.
            let timedOut = await deadline.wait(timeout: timeout)
            if timedOut { trace.record(.timeout); processControl.cancel() }
            // Reap the process before consuming the pipes. Real yt-dlp is one
            // executable; this also keeps the runner's Process lifetime clear.
            process.waitUntilExit()

            let outData = await outRead.value
            let errData = await errRead.value
            let stdout = String(data: outData.data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let stderr = String(data: errData.data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            try Task.checkCancellation()
            if timedOut {
                throw YTDlpBridge.YTDlpError.timeout
            }
            guard !outData.exceededLimit else {
                throw YTDlpBridge.YTDlpError.parseFailed("Subprocess output exceeded configured limit")
            }
            let status = process.terminationStatus
            if status != 0 {
                throw YTDlpBridge.YTDlpError.exitCode(Int(status), stderr)
            }
            trace.record(.returned)
            return (stdout, stderr)
        }
        return try await withTaskCancellationHandler {
            try await worker.value
        } onCancel: {
            worker.cancel()
            trace.record(.cancelled)
            processControl.cancel()
        }
    }

    private struct CapturedPipe: Sendable {
        let data: Data
        let exceededLimit: Bool
    }

    private static func readPipe(_ handle: FileHandle, limit: Int, retainTail: Bool,
                                 trace: YTDlpRunTrace) async -> CapturedPipe {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                var data = Data()
                var exceeded = false
                var total = 0
                var buffer = [UInt8](repeating: 0, count: 64 * 1024)
                // Continue draining after the cap: abandoning a full stderr pipe
                // can deadlock a child before its stdout/termination is delivered.
                // Foundation's read(upToCount:) can fill its requested count
                // before returning. POSIX read delivers the currently available
                // bytes, so first-byte timing is not delayed until child exit.
                while true {
                    let count = buffer.withUnsafeMutableBytes {
                        Darwin.read(handle.fileDescriptor, $0.baseAddress, $0.count)
                    }
                    if count < 0 && errno == EINTR { continue }
                    guard count > 0 else { break }
                    let chunk = buffer.prefix(count)
                    if total == 0 { trace.record(retainTail ? .stderrFirst : .stdoutFirst) }
                    total += chunk.count
                    if retainTail { trace.consumeStderr(chunk) }
                    if retainTail {
                        data.append(contentsOf: chunk)
                        if data.count > limit {
                            exceeded = true
                            data.removeFirst(data.count - limit)
                        }
                    } else {
                        let remaining = max(0, limit - data.count)
                        data.append(contentsOf: chunk.prefix(remaining))
                        if chunk.count > remaining { exceeded = true }
                    }
                }
                if retainTail { trace.finishStderr() }
                trace.record(retainTail ? .stderrEOF : .stdoutEOF, value: total)
                continuation.resume(returning: CapturedPipe(data: data, exceededLimit: exceeded))
            }
        }
    }
}

/// Task-local intent follows protocol-based engine calls without changing the
/// playback engine or yt-dlp test doubles' public interfaces.
enum YTDlpRequestPriority {
    @TaskLocal static var interactive = false
}

private final class CancellableYTDlpProcess: @unchecked Sendable {
    private struct State { var process: Process?; var cancelled = false }
    private let state = OSAllocatedUnfairLock(initialState: State())

    func started(_ process: Process) {
        let cancelled = state.withLock { state in
            state.process = process
            return state.cancelled
        }
        if cancelled { terminate(process) }
    }

    func cancel() {
        let process = state.withLock { state in
            state.cancelled = true
            return state.process
        }
        if let process { terminate(process) }
    }

    private func terminate(_ process: Process) {
        guard process.isRunning else { return }
        process.terminate()
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.5) {
            if process.isRunning { _ = kill(process.processIdentifier, SIGKILL) }
        }
    }
}
