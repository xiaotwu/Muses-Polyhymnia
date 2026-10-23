import Foundation

/// Shared resolution and catalog boundary; URL-only adapters keep existing test doubles usable.
@MainActor
protocol YTDlpBridgeProtocol: AnyObject {
    func resolveAudioStream(videoId: String, quality: String, timeout: TimeInterval) async throws -> ResolvedAudioStream
    func resolveStreamURL(videoId: String, quality: String, timeout: TimeInterval) async throws -> URL
    func fetchPlaylist(url: String, timeout: TimeInterval) async throws -> [YTDlpBridge.YTDlpPlaylistEntry]
    func searchYouTube(query: String, limit: Int, timeout: TimeInterval) async throws -> [YTDlpBridge.YTDlpPlaylistEntry]
    func version() async -> String?
    func invalidateSearch(query: String, limit: Int)
    func fetchSongMetadata(videoId: String, timeout: TimeInterval) async throws -> YTDlpBridge.YTDlpPlaylistEntry?
}

extension YTDlpBridgeProtocol {
    func resolveAudioStream(videoId: String, quality: String, timeout: TimeInterval) async throws -> ResolvedAudioStream {
        ResolvedAudioStream(url: try await resolveStreamURL(videoId: videoId, quality: quality, timeout: timeout))
    }
    func invalidateSearch(query: String, limit: Int) {}
    func fetchSongMetadata(videoId: String, timeout: TimeInterval) async throws -> YTDlpBridge.YTDlpPlaylistEntry? { nil }
}

extension YTDlpBridge: YTDlpBridgeProtocol {}
