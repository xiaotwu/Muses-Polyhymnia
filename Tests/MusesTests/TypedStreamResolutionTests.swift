import Foundation
import Testing
@testable import Muses

@MainActor
private final class ControlledTypedBridge: YTDlpBridgeProtocol {
    var calls = 0
    var cancellations = 0
    var context = "public"
    var pending: [Int: CheckedContinuation<ResolvedAudioStream, Error>] = [:]
    var priorities: [Int: YTDlpQueuedPriority] = [:]

    func resolveAudioStream(videoId: String, quality: String, timeout: TimeInterval) async throws -> ResolvedAudioStream {
        calls += 1
        let call = calls
        priorities[call] = YTDlpRequestPriority.queuedPriority
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { pending[call] = $0 }
        } onCancel: {
            Task { @MainActor in
                self.cancellations += 1
                self.pending.removeValue(forKey: call)?.resume(throwing: CancellationError())
            }
        }
    }
    func complete(_ call: Int, context: String = "public") {
        pending.removeValue(forKey: call)?.resume(returning: ResolvedAudioStream(
            url: URL(string: "https://media.example/audio")!, codec: "opus", bitrateKbps: 151, contextID: context))
    }
    func cancelAll() {
        let old = pending; pending.removeAll()
        for continuation in old.values { continuation.resume(throwing: CancellationError()) }
    }
    func resolveStreamURL(videoId: String, quality: String, timeout: TimeInterval) async throws -> URL {
        Issue.record("Coordinator must dispatch typed protocol requirement")
        throw CancellationError()
    }
    func fetchPlaylist(url: String, timeout: TimeInterval) async throws -> [YTDlpBridge.YTDlpPlaylistEntry] { [] }
    func searchYouTube(query: String, limit: Int, timeout: TimeInterval) async throws -> [YTDlpBridge.YTDlpPlaylistEntry] { [] }
    func version() async -> String? { nil }
}

@MainActor
@Suite("Typed stream lifecycle")
struct TypedStreamResolutionTests {
    @Test("A coalesced foreground consumer promotes the same extraction")
    func foregroundConsumerPromotesSharedRequest() async throws {
        let bridge = ControlledTypedBridge()
        let resolver = StreamResolutionCoordinator(bridge: bridge, cache: StreamURLCache())
        let original = Task { try await resolver.resolveStream(videoID: "video", quality: "bestaudio") }
        defer { original.cancel(); bridge.cancelAll() }
        try await waitForPromotion { bridge.calls == 1 }
        let priority = try #require(bridge.priorities[1])
        #expect(!priority.isInteractive)
        let foreground = Task {
            try await YTDlpRequestPriority.$interactive.withValue(true) {
                try await resolver.resolveStream(videoID: "video", quality: "bestaudio")
            }
        }
        defer { foreground.cancel() }
        try await waitForPromotion { priority.isInteractive }
        #expect(bridge.calls == 1)
        bridge.complete(1)
        let first = try await original.value
        let second = try await foreground.value
        #expect(first == second)
    }

    @Test("An obsolete caller handle cannot promote a replacement request", arguments: [false, true])
    func obsoletePromotionIsRequestScoped(changesContext: Bool) async throws {
        let bridge = ControlledTypedBridge()
        let resolver = StreamResolutionCoordinator(bridge: bridge, cache: StreamURLCache(), contextID: { bridge.context })
        let caller = YTDlpQueuedPriority()
        let original = Task {
            try await YTDlpRequestPriority.$queuedPriority.withValue(caller) {
                try await resolver.resolveStream(videoID: "video", quality: "bestaudio")
            }
        }
        defer { original.cancel(); bridge.cancelAll() }
        try await waitForPromotion { bridge.calls == 1 }
        if changesContext { bridge.context = "new-session" }
        else { resolver.invalidateStream(videoID: "video", quality: "bestaudio") }
        let replacement = Task { try await resolver.resolveStream(videoID: "video", quality: "bestaudio") }
        defer { replacement.cancel() }
        try await waitForPromotion { bridge.calls == 2 }
        _ = try? await original.value
        let current = try #require(bridge.priorities[2])
        caller.promote()
        #expect(!current.isInteractive)
        #expect(bridge.calls == 2)
        bridge.complete(2, context: bridge.context)
        _ = try await replacement.value
    }

    private func waitForPromotion(_ predicate: () -> Bool) async throws {
        let end = ContinuousClock.now.advanced(by: .seconds(2))
        while !predicate() {
            guard ContinuousClock.now < end else { throw TypedPromotionTimeout() }
            try await Task.sleep(for: .milliseconds(1))
        }
    }

    @Test("One canceled consumer returns before another finishes in each access mode", arguments: ["public-session", "account-session"])
    func sharedCancellation(context: String) async throws {
        let bridge = ControlledTypedBridge()
        bridge.context = context
        let resolver = StreamResolutionCoordinator(bridge: bridge, cache: StreamURLCache(), contextID: { bridge.context })
        let first = Task { try await resolver.resolveStream(videoID: "video", quality: "256k") }
        while bridge.calls < 1 { await Task.yield() }
        var secondStarted = false
        let second = Task {
            secondStarted = true
            return try await resolver.resolveStream(videoID: "video", quality: "256k")
        }
        // Main-actor registration is synchronous until the resolver suspends.
        while !secondStarted { await Task.yield() }
        first.cancel()
        do { _ = try await first.value; Issue.record("Expected cancellation") }
        catch { #expect(error is CancellationError) }
        #expect(bridge.calls == 1)
        #expect(bridge.cancellations == 0)
        bridge.complete(1, context: context)
        let stream = try await second.value
        #expect(stream.codec == "opus")
        let cached = try await resolver.resolveStream(videoID: "video", quality: "256k")
        #expect(cached == stream)
        #expect(bridge.calls == 1)
    }

    @Test("Explicit invalidation cancels old work and cannot poison the replacement")
    func invalidation() async throws {
        let bridge = ControlledTypedBridge()
        let resolver = StreamResolutionCoordinator(bridge: bridge, cache: StreamURLCache())
        let first = Task { try await resolver.resolveStream(videoID: "video", quality: "256k") }
        while bridge.calls < 1 { await Task.yield() }
        resolver.invalidateStream(videoID: "video", quality: "256k")
        do { _ = try await first.value; Issue.record("Expected cancellation") }
        catch { #expect(error is CancellationError) }
        let second = Task { try await resolver.resolveStream(videoID: "video", quality: "256k") }
        while bridge.calls < 2 { await Task.yield() }
        bridge.complete(2)
        _ = try await second.value
        #expect(bridge.calls == 2)
    }

    @Test("Changing session retires pending consumers and partitions cached results")
    func sessionChange() async throws {
        let bridge = ControlledTypedBridge()
        let resolver = StreamResolutionCoordinator(bridge: bridge, cache: StreamURLCache(), contextID: { bridge.context })
        let first = Task { try await resolver.resolveStream(videoID: "video", quality: "256k") }
        while bridge.calls < 1 { await Task.yield() }
        bridge.context = "new-session"
        let second = Task { try await resolver.resolveStream(videoID: "video", quality: "256k") }
        while bridge.calls < 2 { await Task.yield() }
        do { _ = try await first.value; Issue.record("Expected cancellation") }
        catch { #expect(error is CancellationError) }
        bridge.complete(2, context: "new-session")
        let stream = try await second.value
        #expect(stream.contextID == "new-session")
    }

    @Test("All consumers leaving terminates shared extraction")
    func lastConsumerCancellation() async {
        let bridge = ControlledTypedBridge()
        let resolver = StreamResolutionCoordinator(bridge: bridge, cache: StreamURLCache())
        let task = Task { try await resolver.resolveStream(videoID: "video", quality: "256k") }
        while bridge.calls < 1 { await Task.yield() }
        task.cancel()
        _ = try? await task.value
        while bridge.cancellations < 1 { await Task.yield() }
        #expect(bridge.cancellations == 1)
    }
}

private struct TypedPromotionTimeout: Error {}
