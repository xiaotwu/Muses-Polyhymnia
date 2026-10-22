import Foundation

/// The complete, short-lived media request context returned by a resolver.
/// Credentials stay in their authorized helper; headers here must be non-sensitive.
struct ResolvedAudioStream: Equatable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    let url: URL
    let requestHeaders: [String: String]
    let formatID: String?
    let codec: String?
    let container: String?
    let bitrateKbps: Double?
    let sampleRate: Int?
    let contentLength: Int64?
    let expiresAt: Date?
    let protocolName: String?
    /// Non-secret identity used to partition public and authorized resolver sessions.
    let contextID: String

    init(url: URL, requestHeaders: [String: String] = [:], formatID: String? = nil,
         codec: String? = nil, container: String? = nil, bitrateKbps: Double? = nil,
         sampleRate: Int? = nil, contentLength: Int64? = nil, expiresAt: Date? = nil,
         protocolName: String? = nil, contextID: String = "public") {
        self.url = url
        self.requestHeaders = requestHeaders
        self.formatID = formatID
        self.codec = codec
        self.container = container
        self.bitrateKbps = bitrateKbps
        self.sampleRate = sampleRate
        self.contentLength = contentLength
        self.expiresAt = expiresAt
        self.protocolName = protocolName
        self.contextID = contextID
    }

    func isExpired(at now: Date = Date(), margin: TimeInterval = 30) -> Bool {
        expiresAt.map { $0 <= now.addingTimeInterval(margin) } ?? false
    }

    var description: String { "ResolvedAudioStream(redacted)" }
    var debugDescription: String { description }
}

@MainActor
protocol ResolvedStreamProvider: AnyObject, Sendable {
    /// Opaque current access/session identity. Unknown providers cannot transfer speculative work.
    var streamContextID: String? { get }
    func resolveStream(videoID: String, quality: String) async throws -> ResolvedAudioStream
    func invalidateStream(videoID: String, quality: String)
}

extension ResolvedStreamProvider {
    var streamContextID: String? { nil }
}
