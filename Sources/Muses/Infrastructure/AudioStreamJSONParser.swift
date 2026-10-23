import Foundation

/// Decodes only the selected representation. Never includes extractor payloads in errors.
enum AudioStreamJSONParser {
    static let maximumBytes = 8 * 1024 * 1024

    private struct Format: Decodable {
        let id: String?
        let url: String?
        let format_id: String?
        let acodec: String?
        let vcodec: String?
        let ext: String?
        let abr: Double?
        let asr: Int?
        let filesize: Int64?
        let `protocol`: String?
        let http_headers: [String: String]?
        let requested_formats: [Format]?
        let requested_downloads: [Format]?
    }

    static func parse(_ stdout: String, videoID: String, contextID: String) throws -> ResolvedAudioStream {
        func invalid() -> YTDlpBridge.YTDlpError { .parseFailed("Invalid selected audio representation") }
        guard stdout.utf8.count <= maximumBytes,
              let data = stdout.data(using: .utf8),
              let root = try? JSONDecoder().decode(Format.self, from: data),
              root.id == videoID else { throw invalid() }
        // Merged video/audio and fragmented multi-resource results need their own transport.
        guard root.requested_formats == nil else { throw invalid() }
        let selected: Format
        if let downloads = root.requested_downloads {
            guard downloads.count == 1 else { throw invalid() }
            selected = downloads[0]
        } else { selected = root }
        guard let raw = selected.url, raw.utf8.count <= 32_768,
              let url = URL(string: raw), url.scheme == "https" || url.scheme == "http",
              url.host != nil, url.user == nil, url.password == nil,
              let codec = selected.acodec, codec != "none", !codec.isEmpty,
              selected.vcodec == nil || selected.vcodec == "none",
              let formatID = selected.format_id, !formatID.isEmpty else { throw invalid() }
        let protocolName = selected.protocol ?? url.scheme
        guard ["https", "http", "m3u8", "m3u8_native"].contains(protocolName ?? "") else { throw invalid() }
        var headers: [String: String] = [:]
        // An allowlist prevents credential-bearing custom headers crossing this boundary.
        let allowed = ["user-agent", "accept", "accept-language", "accept-encoding", "referer", "origin"]
        for (key, value) in (root.http_headers ?? [:]).merging(selected.http_headers ?? [:], uniquingKeysWith: { _, new in new }) {
            guard allowed.contains(key.lowercased()), value.utf8.count <= 4096,
                  !value.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 }) else { continue }
            if ["referer", "origin"].contains(key.lowercased()) {
                guard let ref = URLComponents(string: value), ref.scheme == "https",
                      ["www.youtube.com", "music.youtube.com", "youtube.com"].contains(ref.host ?? ""),
                      ref.user == nil, ref.password == nil, ref.query == nil, ref.fragment == nil else { continue }
            }
            headers[key.lowercased()] = value
        }
        let expiry = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?
            .first(where: { $0.name == "expire" })?.value.flatMap(Double.init)
            .flatMap { $0.isFinite ? Date(timeIntervalSince1970: $0) : nil }
        guard selected.abr == nil || (selected.abr!.isFinite && selected.abr! > 0),
              selected.asr == nil || selected.asr! > 0,
              selected.filesize == nil || selected.filesize! > 0 else { throw invalid() }
        let stream = ResolvedAudioStream(url: url, requestHeaders: headers,
            formatID: formatID, codec: codec, container: selected.ext,
            bitrateKbps: selected.abr, sampleRate: selected.asr, contentLength: selected.filesize,
            expiresAt: expiry, protocolName: protocolName, contextID: contextID)
        guard !stream.isExpired() else { throw invalid() }
        return stream
    }
}
