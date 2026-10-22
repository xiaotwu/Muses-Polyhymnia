import Foundation
import Testing
@testable import Muses

@Suite("Resolver pipe output bounds")
struct ResolverOutputBoundsTests {
    @Test("Oversized output is drained and rejected while both pipes remain live")
    func oversizedStdoutIsRejectedWithoutPipeDeadlock() async throws {
        let runner = YTDlpRunner()
        do {
            _ = try await runner.run(executablePath: "/bin/sh", args: ["-c",
                "head -c 262144 /dev/zero & head -c 262144 /dev/zero >&2; wait"],
                timeout: 5, stdoutLimit: 4096, stderrLimit: 4096)
            Issue.record("Oversized stdout unexpectedly passed")
        } catch let error as YTDlpBridge.YTDlpError {
            guard case .parseFailed(let message) = error else {
                Issue.record("Unexpected error category"); return
            }
            #expect(message == "Subprocess output exceeded configured limit")
        }
        #expect(await runner.inFlightCount == 0)
        let next = try await runner.run(executablePath: "/bin/echo", args: ["ready"], timeout: 2)
        #expect(next.stdout == "ready")
    }

    @Test("Large stderr retains a bounded diagnostic tail without losing valid stdout")
    func stderrTailDoesNotDiscardSuccess() async throws {
        let output = try await YTDlpRunner().run(executablePath: "/bin/sh", args: ["-c",
            "head -c 262144 /dev/zero >&2; echo tail >&2; echo result"],
            timeout: 5, stdoutLimit: 64, stderrLimit: 64)
        #expect(output.stdout == "result")
        #expect(output.stderr.utf8.count <= 64)
        #expect(output.stderr.hasSuffix("tail"))
    }
}
