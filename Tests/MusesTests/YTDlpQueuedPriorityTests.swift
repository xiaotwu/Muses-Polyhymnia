import Foundation
import Testing
@testable import Muses

@MainActor
@Suite("Queued resolver promotion", .serialized)
struct YTDlpQueuedPriorityTests {
    @Test("Promotion before acquisition is sticky without taking a background slot")
    func promotionBeforeAcquisition() async throws {
        try await withFixture { f in
            let background = f.start("background", hold: true)
            try await f.until { f.exists("background.started") }
            let priority = YTDlpQueuedPriority()
            priority.promote()
            _ = try await f.start("selected", priority: priority).value
            #expect(f.starts("selected") == 1)
            #expect(await f.runner.inFlightCount == 1)
            #expect(!f.exists("background.finished"))
            try f.release("background")
            _ = try await background.value
            #expect(await f.runner.inFlightCount == 0)
        }
    }

    @Test("Promoting an already running extraction never restarts it or reserves the interactive slot")
    func alreadyRunning() async throws {
        try await withFixture { f in
            let priority = YTDlpQueuedPriority()
            let running = f.start("running", hold: true, priority: priority)
            try await f.until { f.exists("running.started") }
            priority.promote()
            _ = try await f.start("probe", interactive: true).value
            #expect(f.starts("running") == 1 && !f.exists("running.finished"))
            #expect(await f.runner.inFlightCount == 1)
            try f.release("running")
            _ = try await running.value
            #expect(await f.runner.inFlightCount == 0)
        }
    }

    @Test("A promoted waiter waits for the foreground lane even when a background slot opens")
    func occupiedForegroundGrant() async throws {
        try await withFixture { f in
            let background = f.start("background", hold: true)
            let foreground = f.start("foreground", hold: true, interactive: true)
            try await f.until { f.exists("background.started") && f.exists("foreground.started") }
            let priority = YTDlpQueuedPriority()
            let selected = f.start("selected", priority: priority)
            try await f.until { await f.runner.waitingCount == 1 }
            priority.promote()
            try await f.until { await f.runner.interactiveWaitingCount == 1 }
            try f.release("background"); _ = try await background.value
            _ = try await f.start("background-probe").value
            #expect(!f.exists("selected.started"))
            #expect(await f.runner.inFlightCount == 1)
            #expect(await f.runner.interactiveWaitingCount == 1)
            try f.release("foreground"); _ = try await foreground.value
            _ = try await selected.value
            #expect(f.starts("selected") == 1)
            #expect(await f.runner.inFlightCount == 0)
            #expect(await f.runner.waitingCount == 0)
        }
    }

    @Test("A promoted waiter can be cancelled while both lanes are occupied")
    func promotedCancellation() async throws {
        try await withFixture { f in
            let background = f.start("background", hold: true)
            let foreground = f.start("foreground", hold: true, interactive: true)
            try await f.until { await f.runner.inFlightCount == 2 }
            let priority = YTDlpQueuedPriority()
            let queued = f.start("cancelled", priority: priority)
            try await f.until { await f.runner.waitingCount == 1 }
            priority.promote()
            queued.cancel()
            do { _ = try await queued.value; Issue.record("Expected cancelled promoted waiter") }
            catch { #expect(error is CancellationError) }
            #expect(await f.runner.waitingCount == 0)
            #expect(!f.exists("cancelled.started"))
            try f.release("foreground"); try f.release("background")
            _ = try await foreground.value; _ = try await background.value
            #expect(await f.runner.inFlightCount == 0)
            // Both lanes can subsequently be occupied, without a leaked grant.
            let nextBackground = f.start("next-background", hold: true)
            let nextForeground = f.start("next-foreground", hold: true, interactive: true)
            try await f.until { await f.runner.inFlightCount == 2 }
            let nextQueued = f.start("next-queued")
            try await f.until { await f.runner.waitingCount == 1 }
            #expect(!f.exists("next-queued.started"))
            try f.release("next-background"); try f.release("next-foreground")
            _ = try await nextBackground.value; _ = try await nextForeground.value
            _ = try await nextQueued.value
            #expect(await f.runner.inFlightCount == 0)
        }
    }

    @Test("Promotion preserves the original queued deadline")
    func promotedTimeout() async throws {
        try await withFixture { f in
            _ = f.start("background", hold: true)
            _ = f.start("foreground", hold: true, interactive: true)
            try await f.until { await f.runner.inFlightCount == 2 }
            let priority = YTDlpQueuedPriority()
            let queued = f.start("expired", priority: priority, timeout: 0.4)
            try await f.until { await f.runner.waitingCount == 1 }
            try await Task.sleep(for: .milliseconds(300))
            priority.promote()
            var timedOut = false
            let result = Task {
                do { _ = try await queued.value; Issue.record("Expected original queue deadline") }
                catch { #expect((error as? YTDlpBridge.YTDlpError) == .timeout); timedOut = true }
            }
            try await f.until(timeout: .milliseconds(250)) { timedOut }
            await result.value
            #expect(await f.runner.waitingCount == 0)
            #expect(!f.exists("expired.started"))
        }
    }

    @Test("Grant, promotion and cancellation races release the actual lane exactly once", arguments: 0..<6)
    func promotionGrantCancellationRace(iteration: Int) async throws {
        try await withFixture { f in
            let background = f.start("background", hold: true)
            let foreground = f.start("foreground", hold: true, interactive: true)
            try await f.until { await f.runner.inFlightCount == 2 }
            let priority = YTDlpQueuedPriority()
            let queued = f.start("racing", priority: priority)
            try await f.until { await f.runner.waitingCount == 1 }
            if iteration.isMultiple(of: 2) {
                priority.promote(); try f.release("foreground"); queued.cancel()
            } else {
                try f.release("background"); priority.promote(); queued.cancel()
            }
            _ = try? await queued.value
            try f.release("foreground"); try f.release("background")
            _ = try await foreground.value; _ = try await background.value
            try await f.until {
                let active = await f.runner.inFlightCount
                let waiting = await f.runner.waitingCount
                return active == 0 && waiting == 0
            }
            #expect(f.starts("racing") <= 1)
            _ = try await f.start("post-race-background").value
            _ = try await f.start("post-race-foreground", interactive: true).value
            #expect(await f.runner.inFlightCount == 0)
        }
    }

    @Test("Every queued outcome releases the handle's runner callback", arguments: ["grant", "cancel", "timeout"])
    func completedCallbackLifetime(outcome: String) async throws {
        let priority = YTDlpQueuedPriority()
        weak var observed: YTDlpRunner?
        try await withFixture { f in
            observed = f.runner
            let background = f.start("background", hold: true)
            try await f.until { f.exists("background.started") }
            let queued = f.start("selected", priority: priority, timeout: 0.1)
            try await f.until { await f.runner.waitingCount == 1 }
            if outcome == "grant" {
                priority.promote()
                _ = try await queued.value
            } else {
                if outcome == "cancel" { queued.cancel() }
                do { _ = try await queued.value; Issue.record("Expected queued failure") }
                catch {
                    if outcome == "cancel" { #expect(error is CancellationError) }
                    else { #expect((error as? YTDlpBridge.YTDlpError) == .timeout) }
                }
            }
            try f.release("background"); _ = try await background.value
        }
        // The pre-existing waiter deadline task also retains the runner until
        // its original deadline, independently of the promotion observer.
        try await Task.sleep(for: .milliseconds(150))
        #expect(observed == nil)
        priority.promote()
    }

    private func withFixture(_ body: (PriorityRunnerFixture) async throws -> Void) async throws {
        let f = try PriorityRunnerFixture()
        do { try await body(f); await f.close() }
        catch { await f.close(); throw error }
    }
}

@MainActor
private final class PriorityRunnerFixture {
    typealias Work = Task<(stdout: String, stderr: String), Error>
    let runner = YTDlpRunner(maxConcurrent: 1)
    let directory: URL
    let binary: URL
    var tasks: [Work] = []
    init() throws {
        directory = FileManager.default.temporaryDirectory.appending(path: "runner-priority-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        binary = directory.appending(path: "worker")
        let quoted = "'" + directory.path.replacingOccurrences(of: "'", with: "'\\''") + "'"
        try """
        #!/bin/sh
        root=\(quoted)
        printf 'started\\n' >> "$root/$1.started"
        if [ "$2" = hold ]; then
          while [ ! -e "$root/$1.release" ]; do /bin/sleep 0.005; done
        fi
        printf finished > "$root/$1.finished"
        printf ready
        """.write(to: binary, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: binary.path)
    }
    func start(_ name: String, hold: Bool = false, interactive: Bool = false,
               priority: YTDlpQueuedPriority? = nil, timeout: TimeInterval = 5) -> Work {
        let runner = runner, binary = binary
        let task = Task {
            try await YTDlpRequestPriority.$interactive.withValue(interactive) {
                try await YTDlpRequestPriority.$queuedPriority.withValue(priority) {
                    try await runner.run(executablePath: binary.path, args: [name, hold ? "hold" : "quick"], timeout: timeout)
                }
            }
        }
        tasks.append(task)
        return task
    }
    func exists(_ name: String) -> Bool { FileManager.default.fileExists(atPath: directory.appending(path: name).path) }
    func starts(_ name: String) -> Int {
        (try? String(contentsOf: directory.appending(path: name + ".started"), encoding: .utf8).split(separator: "\n").count) ?? 0
    }
    func release(_ name: String) throws { try Data().write(to: directory.appending(path: name + ".release")) }
    func until(timeout: Duration = .seconds(2), _ predicate: () async -> Bool) async throws {
        let end = ContinuousClock.now.advanced(by: timeout)
        while !(await predicate()) {
            guard ContinuousClock.now < end else { throw PriorityRunnerTimeout() }
            try await Task.sleep(for: .milliseconds(1))
        }
    }
    func close() async {
        tasks.forEach { $0.cancel() }
        for task in tasks { _ = try? await task.value }
        tasks.removeAll()
        try? FileManager.default.removeItem(at: directory)
    }
}

private struct PriorityRunnerTimeout: Error {}
