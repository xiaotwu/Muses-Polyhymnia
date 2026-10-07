import Foundation
import Testing
@testable import Muses

/// Deliberately ignores cancellation while a page is held, as an already
/// completed network read can still reach its caller after destination changes.
private actor DelayedCommentPages {
    private let pages: [String: String]
    private let delayed: Set<String>
    private var continuations: [String: CheckedContinuation<Void, Never>] = [:]
    private var requestWaiters: [String: CheckedContinuation<Void, Never>] = [:]
    private var requested: Set<String> = []
    private(set) var keys: [String] = []

    init(pages: [String: String], delayed: Set<String>) {
        self.pages = pages
        self.delayed = delayed
    }

    func read(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let url = try #require(request.url)
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let replies = url.path.hasSuffix("/comments")
        let identity = query.first { $0.name == (replies ? "parentId" : "videoId") }?.value ?? ""
        let token = query.first { $0.name == "pageToken" }?.value ?? "initial"
        let key = "\(replies ? "replies" : "threads"):\(identity):\(token)"
        keys.append(key)
        requested.insert(key)
        requestWaiters.removeValue(forKey: key)?.resume()
        if delayed.contains(key) {
            await withCheckedContinuation { continuations[key] = $0 }
        }
        let body = try #require(pages[key])
        return (Data(body.utf8), try #require(HTTPURLResponse(
            url: url, statusCode: 200, httpVersion: nil, headerFields: nil)))
    }

    func waitForRequest(_ key: String) async {
        if requested.contains(key) { return }
        await withCheckedContinuation { requestWaiters[key] = $0 }
    }

    func release(_ key: String) { continuations.removeValue(forKey: key)?.resume() }
}

@MainActor
@Suite("YouTube comment browser request ownership")
struct YouTubeCommentBrowserTests {
    @Test("opening replies replaces a pending thread page and preserves separate pagination")
    func repliesReplaceThreadPagination() async throws {
        let delayedKey = "threads:abcdefghijk:thread-page-2"
        let source = DelayedCommentPages(pages: [
            "threads:abcdefghijk:initial": Self.threads("top-1", token: "thread-page-2"),
            delayedKey: Self.threads("late-top", token: "late-thread-token"),
            "replies:top-1:initial": Self.replies(["reply-1"], token: "reply-page-2"),
            "replies:top-1:reply-page-2": Self.replies(["reply-1", "reply-2"], token: nil)
        ], delayed: [delayedKey])
        let browser = YouTubeCommentBrowser()
        let client = YouTubeDataAPIClient(accessTokenProvider: { "test-token" },
            http: { try await source.read($0) })
        await browser.reset(videoID: "abcdefghijk", client: client)?.value
        let thread = try #require(browser.threads.first)
        let oldPage = try #require(browser.loadMoreThreads())
        await source.waitForRequest(delayedKey)

        let replyPage = browser.selectReplies(thread)
        #expect(replyPage != nil)
        await replyPage?.value
        #expect(browser.replies.map(\.id) == ["reply-1"])
        #expect(browser.nextReplyToken == "reply-page-2")
        #expect(!browser.loading)

        await source.release(delayedKey)
        await oldPage.value
        #expect(browser.threads.map(\.topLevelComment.id) == ["top-1"])
        #expect(browser.nextToken == "thread-page-2")
        await browser.loadMoreReplies()?.value
        #expect(browser.replies.map(\.id) == ["reply-1", "reply-2"])
        #expect(browser.nextReplyToken == nil)
        browser.closeReplies()
        #expect(browser.selectedThread == nil)
        #expect(browser.replies.isEmpty)
        #expect(browser.nextToken == "thread-page-2")
        #expect(await source.keys == ["threads:abcdefghijk:initial", delayedKey,
            "replies:top-1:initial", "replies:top-1:reply-page-2"])
    }

    @Test("closing replies and changing video reject a late reply page")
    func replacedVideoRejectsReplies() async throws {
        let delayedKey = "replies:top-1:initial"
        let source = DelayedCommentPages(pages: [
            "threads:abcdefghijk:initial": Self.threads("top-1", token: "old-thread-token"),
            delayedKey: Self.replies(["old-reply"], token: "old-reply-token"),
            "threads:lmnopqrstuv:initial": Self.threads("new-top", token: nil)
        ], delayed: [delayedKey])
        let browser = YouTubeCommentBrowser()
        let client = YouTubeDataAPIClient(accessTokenProvider: { "test-token" },
            http: { try await source.read($0) })
        await browser.reset(videoID: "abcdefghijk", client: client)?.value
        let thread = try #require(browser.threads.first)
        let oldReply = try #require(browser.selectReplies(thread))
        await source.waitForRequest(delayedKey)
        browser.closeReplies()
        #expect(!browser.loading)
        #expect(browser.nextReplyToken == nil)
        await browser.reset(videoID: "lmnopqrstuv", client: client)?.value
        await source.release(delayedKey)
        await oldReply.value
        #expect(browser.threads.map(\.topLevelComment.id) == ["new-top"])
        #expect(browser.selectedThread == nil)
        #expect(browser.replies.isEmpty)
        #expect(browser.nextToken == nil)
        #expect(browser.nextReplyToken == nil)
        #expect(browser.errorMessage == nil)
        #expect(!browser.loading)

        await browser.reset(videoID: "lmnopqrstuv", client: nil)?.value
        #expect(browser.threads.isEmpty)
        #expect(!browser.loading)
        #expect(browser.errorMessage == nil)
        #expect(await source.keys.count == 3)
    }

    @Test("disconnecting a failed destination clears its recovery state without another request")
    func disconnectClearsFailure() async throws {
        let browser = YouTubeCommentBrowser()
        let client = YouTubeDataAPIClient(accessTokenProvider: { "test-token" },
            http: { _ in throw URLError(.networkConnectionLost) })
        await browser.reset(videoID: "abcdefghijk", client: client)?.value
        #expect(browser.errorMessage != nil)
        #expect(!browser.loading)
        await browser.reset(videoID: "abcdefghijk", client: nil)?.value
        #expect(browser.errorMessage == nil)
        #expect(browser.selectedThread == nil)
        #expect(browser.threads.isEmpty)
        #expect(browser.replies.isEmpty)
        #expect(browser.nextToken == nil)
        #expect(browser.nextReplyToken == nil)
        #expect(browser.retry() == nil)
    }

    private static func threads(_ commentID: String, token: String?) -> String {
        let tokenField = token.map { "\"nextPageToken\":\"\($0)\"," } ?? ""
        return """
            {\(tokenField)"items":[{"id":"thread-\(commentID)","snippet":{
            "totalReplyCount":2,"topLevelComment":{"id":"\(commentID)","snippet":{
            "authorDisplayName":"Reader","textDisplay":"Comment"}}}}]}
            """
    }

    private static func replies(_ ids: [String], token: String?) -> String {
        let tokenField = token.map { "\"nextPageToken\":\"\($0)\"," } ?? ""
        let items = ids.map {
            "{\"id\":\"\($0)\",\"snippet\":{\"authorDisplayName\":\"Reader\",\"textDisplay\":\"Reply\"}}"
        }.joined(separator: ",")
        return "{\(tokenField)\"items\":[\(items)]}"
    }
}
