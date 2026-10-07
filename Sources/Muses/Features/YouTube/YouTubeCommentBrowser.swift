import Foundation
import Observation

/// View-local, volatile comment pages. Switching destinations replaces the
/// outstanding request without mixing thread and reply continuation tokens.
@Observable @MainActor
final class YouTubeCommentBrowser {
    private(set) var threads: [YouTubeCommentThread] = []
    private(set) var nextToken: String?
    private(set) var loading = false
    private(set) var errorMessage: String?
    private(set) var selectedThread: YouTubeCommentThread?
    private(set) var replies: [YouTubeComment] = []
    private(set) var nextReplyToken: String?
    @ObservationIgnored private var client: YouTubeDataAPIClient?
    @ObservationIgnored private var videoID = ""
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var requestID = UUID()

    @discardableResult
    func reset(videoID: String, client: YouTubeDataAPIClient?) -> Task<Void, Never>? {
        cancel()
        self.videoID = videoID
        self.client = client
        threads = []
        nextToken = nil
        selectedThread = nil
        replies = []
        nextReplyToken = nil
        errorMessage = nil
        return loadThreads(reset: true)
    }

    @discardableResult
    func selectReplies(_ thread: YouTubeCommentThread) -> Task<Void, Never>? {
        cancel()
        selectedThread = thread
        replies = []
        nextReplyToken = nil
        return loadReplies(reset: true)
    }

    func closeReplies() {
        cancel()
        selectedThread = nil
        replies = []
        nextReplyToken = nil
        errorMessage = nil
    }

    @discardableResult
    func loadMoreThreads() -> Task<Void, Never>? {
        guard nextToken != nil else { return nil }
        return loadThreads(reset: false)
    }

    @discardableResult
    func loadMoreReplies() -> Task<Void, Never>? {
        guard nextReplyToken != nil else { return nil }
        return loadReplies(reset: false)
    }

    @discardableResult
    func retry() -> Task<Void, Never>? {
        selectedThread == nil ? loadThreads(reset: threads.isEmpty) : loadReplies(reset: replies.isEmpty)
    }

    func cancel() {
        task?.cancel()
        task = nil
        requestID = UUID()
        loading = false
    }

    private func loadThreads(reset: Bool) -> Task<Void, Never>? {
        guard let client, !loading else { return nil }
        cancel()
        let expected = requestID
        let videoID = videoID
        let token = reset ? nil : nextToken
        loading = true
        errorMessage = nil
        let request = Task { [weak self] in
            do {
                let page = try await client.commentThreads(videoID: videoID, pageToken: token)
                guard let self, !Task.isCancelled, self.requestID == expected else { return }
                if reset { self.threads = page.items }
                else {
                    var seen = Set(self.threads.map(\.id))
                    self.threads += page.items.filter { seen.insert($0.id).inserted }
                }
                self.nextToken = page.nextPageToken
            } catch {
                guard let self, !Task.isCancelled, self.requestID == expected else { return }
                self.errorMessage = error.localizedDescription
            }
            if let self, self.requestID == expected { self.loading = false }
        }
        task = request
        return request
    }

    private func loadReplies(reset: Bool) -> Task<Void, Never>? {
        guard let client, let selectedThread, !loading else { return nil }
        cancel()
        let expected = requestID
        let token = reset ? nil : nextReplyToken
        loading = true
        errorMessage = nil
        let request = Task { [weak self] in
            do {
                let page = try await client.commentReplies(parentID: selectedThread.topLevelComment.id,
                                                           pageToken: token)
                guard let self, !Task.isCancelled, self.requestID == expected else { return }
                if reset { self.replies = page.items }
                else {
                    var seen = Set(self.replies.map(\.id))
                    self.replies += page.items.filter { seen.insert($0.id).inserted }
                }
                self.nextReplyToken = page.nextPageToken
            } catch {
                guard let self, !Task.isCancelled, self.requestID == expected else { return }
                self.errorMessage = error.localizedDescription
            }
            if let self, self.requestID == expected { self.loading = false }
        }
        task = request
        return request
    }
}
