import Foundation
import os
import Testing
@testable import Muses

private final class ResolverEvents: @unchecked Sendable {
    private let lock = OSAllocatedUnfairLock(initialState: [YTDlpRunTrace.Event]())
    func record(_ event: YTDlpRunTrace.Event) { lock.withLock { $0.append(event) } }
    var events: [YTDlpRunTrace.Event] { lock.withLock { $0 } }
}

@Suite("Resolver stage timing")
struct ResolverTimingTests {
    @Test("Split extractor output yields fixed stages without retaining payloads")
    func safeProgress() {
        let events = ResolverEvents()
        let trace = YTDlpRunTrace(captureProgress: true, sink: { events.record($0) })
        trace.consumeStderr(Array("[youtube] Downloading web".utf8))
        trace.consumeStderr(Array("page https://private.example/?secret=token\n".utf8))
        trace.consumeStderr(Array("Downloading webpage again\nSolving JS challenges\nTesting format 251\n".utf8))
        #expect(events.events.map(\.stage) == [.requested, .webpage, .challenge, .formatCheck])
        #expect(events.events.allSatisfy { $0.value == 0 })
        let disabled = YTDlpRunTrace(sink: { events.record($0) })
        disabled.consumeStderr(Array("ERROR: HTTP Error 403".utf8))
        #expect(!events.events.contains { $0.stage == .httpForbidden || $0.stage == .extractorError })
    }

    @Test("Small stdout and stderr chunks are observed before child exit")
    func firstBytesBeforeExit() async throws {
        let events = ResolverEvents()
        let trace = YTDlpRunTrace(sink: { events.record($0) })
        let task = Task {
            try await YTDlpRunner().run(executablePath: "/bin/sh",
                args: ["-c", "printf first; printf diagnostic >&2; exec sleep 5"],
                timeout: 8, trace: trace)
        }
        for _ in 0..<200 {
            if events.events.contains(where: { $0.stage == .stdoutFirst }) &&
                events.events.contains(where: { $0.stage == .stderrFirst }) { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        let live = events.events
        task.cancel()
        _ = try? await task.value
        #expect(live.contains { $0.stage == .stdoutFirst })
        #expect(live.contains { $0.stage == .stderrFirst })
        #expect(!live.contains { $0.stage == .processExit })
        #expect(events.events.contains { $0.stage == .cancelled })
    }

    @Test("Deadline, process status, EOF byte counts and slot release survive timeout")
    func timeoutStages() async throws {
        let events = ResolverEvents()
        let runner = YTDlpRunner()
        do {
            _ = try await runner.run(executablePath: "/bin/sh",
                args: ["-c", "printf first; printf diagnostic >&2; exec sleep 5"],
                timeout: 0.2, trace: YTDlpRunTrace(sink: { events.record($0) }))
            Issue.record("Timeout unexpectedly succeeded")
        } catch let error as YTDlpBridge.YTDlpError { #expect(error == .timeout) }
        let observed = events.events
        #expect(observed.contains { $0.stage == .timeout })
        #expect(observed.contains { $0.stage == .processExit })
        #expect(observed.contains { $0.stage == .stdoutEOF && $0.value == 5 })
        #expect(observed.contains { $0.stage == .stderrEOF && $0.value == 10 })
        #expect(!observed.contains { $0.stage == .returned })
        #expect(await runner.inFlightCount == 0)
    }
}
