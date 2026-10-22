import Foundation
import Testing
@testable import Muses

@MainActor
@Suite("Typed selected audio metadata")
struct ResolvedAudioStreamTests {
    private let json = #"{"id":"abcdefghijk","url":"https://media.example/audio?expire=4102444800&token=secret","format_id":"251","acodec":"opus","vcodec":"none","ext":"webm","abr":256.4,"asr":48000,"filesize":123456,"protocol":"https","http_headers":{"User-Agent":"yt-dlp","Cookie":"secret","Authorization":"secret","X-Token":"secret","Referer":"https://www.youtube.com/","Origin":"https://music.youtube.com"}}"#

    @Test("Actual source values and safe request headers survive decoding")
    func completeMetadata() throws {
        let stream = try AudioStreamJSONParser.parse(json, videoID: "abcdefghijk", contextID: "session-a")
        #expect(stream.formatID == "251")
        #expect(stream.codec == "opus")
        #expect(stream.container == "webm")
        #expect(stream.bitrateKbps == 256.4)
        #expect(stream.sampleRate == 48000)
        #expect(stream.contentLength == 123456)
        #expect(stream.requestHeaders.count == 3)
        #expect(stream.requestHeaders["user-agent"] == "yt-dlp")
        #expect(stream.expiresAt == Date(timeIntervalSince1970: 4102444800))
        #expect(stream.contextID == "session-a")
        #expect(!String(reflecting: stream).contains("secret"))
    }

    @Test("Invalid identity, URL, transport, merged video, expired source and oversize fail safely")
    func rejectedPayloads() {
        let payloads = [
            json.replacingOccurrences(of: "abcdefghijk", with: "other"),
            json.replacingOccurrences(of: "https://media.example/audio", with: "file:///tmp/audio"),
            json.replacingOccurrences(of: #""protocol":"https""#, with: #""protocol":"http_dash_segments""#),
            json.replacingOccurrences(of: #""vcodec":"none""#, with: #""vcodec":"vp9""#),
            json.replacingOccurrences(of: "4102444800", with: "1"),
            json + String(repeating: " ", count: AudioStreamJSONParser.maximumBytes),
            #"{"id":"abcdefghijk","requested_formats":[]}"#
        ]
        for payload in payloads {
            #expect(throws: YTDlpBridge.YTDlpError.self) {
                try AudioStreamJSONParser.parse(payload, videoID: "abcdefghijk", contextID: "session")
            }
        }
    }

    @Test("Top quality has no AAC-first cap or invented bitrate")
    func qualityPolicy() throws {
        #expect(YTDlpBridge.qualityMap["256k"] == "bestaudio")
        #expect(YTDlpBridge.qualityMap["bestaudio"] == "bestaudio")
        let stream = try AudioStreamJSONParser.parse(json.replacingOccurrences(of: #","abr":256.4"#, with: ""),
            videoID: "abcdefghijk", contextID: "session")
        #expect(stream.bitrateKbps == nil)
    }

    @Test("Signed expiry and session partitions bound typed cache; legacy invalidation evicts it")
    func cacheContract() {
        let cache = StreamURLCache()
        let url = URL(string: "https://media.example/audio")!
        cache.setStream(videoId: "video", quality: "256k", stream: ResolvedAudioStream(url: url, contextID: "a"))
        #expect(cache.getStream(videoId: "video", quality: "256k", contextID: "a") != nil)
        #expect(cache.getStream(videoId: "video", quality: "256k", contextID: "b") == nil)
        cache.invalidate(videoId: "video", quality: "256k")
        #expect(cache.getStream(videoId: "video", quality: "256k", contextID: "a") == nil)
        cache.setStream(videoId: "video", quality: "256k", stream: ResolvedAudioStream(url: url,
            expiresAt: Date().addingTimeInterval(15), contextID: "a"))
        #expect(cache.getStream(videoId: "video", quality: "256k", contextID: "a") == nil)
    }
}

@MainActor
@Suite("Structured resolver invocation")
struct StructuredResolverInvocationTests {
    @Test("Typed extraction requests JSON, sorts by bitrate, and never falls back from a broken cookie session")
    func noSilentDowngrade() async throws {
        let directory = MusesDataPaths.root(bundleID: Bundle.main.bundleIdentifier).appending(path: "tmp/typed-resolver-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let binary = directory.appending(path: "yt-dlp")
        let script = #"""
        #!/bin/sh
        printf x >> "$0.calls"
        json=0
        sort=0
        config=0
        checked=0
        for arg in "$@"; do
            [ "$arg" = "--dump-single-json" ] && json=1
            [ "$arg" = "abr,asr" ] && sort=1
            [ "$arg" = "--ignore-config" ] && config=1
            [ "$arg" = "--check-formats" ] && checked=1
            [ "$arg" = "--extractor-args" ] && exit 5
        done
        [ "$json$sort$config$checked" = "1111" ] || exit 4
        echo 'Cookie extraction failed at https://example.test/?token=do-not-leak' >&2
        exit 1
        """#
        try script.write(to: binary, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: binary.path)
        let bridge = YTDlpBridge(binaryPath: binary.path, searchCache: nil,
            streamAccessPolicy: .configuredAccount,
            playbackCookieArguments: { ["--cookies-from-browser", "chrome"] })
        for _ in 0..<2 {
            do {
                _ = try await bridge.resolveAudioStream(videoId: "abcdefghijk", quality: "256k", timeout: 1)
                Issue.record("Expected session failure")
            } catch let error as YTDlpBridge.YTDlpError {
                #expect(error == .exitCode(1, "cookie"))
                #expect(!String(describing: error).contains("do-not-leak"))
            }
        }
        #expect(try String(contentsOf: URL(fileURLWithPath: binary.path + ".calls"), encoding: .utf8) == "x")
    }

    private func makeBinary(_ script: String) throws -> URL {
        let directory = MusesDataPaths.root(bundleID: Bundle.main.bundleIdentifier)
            .appending(path: "tmp/typed-access-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let binary = directory.appending(path: "yt-dlp")
        try script.write(to: binary, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: binary.path)
        return binary
    }

    @Test("Public mode never reads configured Chrome cookies and carries checked format metadata")
    func publicSkipsCookieConfiguration() async throws {
        let binary = try makeBinary(#"""
        #!/bin/sh
        checked=0
        for arg in "$@"; do
            case "$arg" in
                --cookies|--cookies-from-browser) echo 'Cookie permission denied' >&2; exit 1 ;;
                --check-formats) checked=1 ;;
                --extractor-args) exit 6 ;;
            esac
        done
        [ "$checked" = 1 ] || exit 5
        echo '{"id":"abcdefghijk","url":"https://media.example/audio","format_id":"251","acodec":"opus","vcodec":"none","abr":130.269,"protocol":"https"}'
        """#)
        defer { try? FileManager.default.removeItem(at: binary.deletingLastPathComponent()) }
        var cookieConfigurationReads = 0
        let bridge = YTDlpBridge(binaryPath: binary.path, searchCache: nil,
            streamAccessPolicy: .publicAudio, playbackCookieArguments: {
                cookieConfigurationReads += 1
                return ["--cookies-from-browser", "chrome"]
            })
        let context = bridge.streamContextID
        let resolver = StreamResolutionCoordinator(bridge: bridge, cache: StreamURLCache())
        let stream = try await resolver.resolveStream(videoID: "abcdefghijk", quality: "256k")
        let cached = try await resolver.resolveStream(videoID: "abcdefghijk", quality: "256k")
        #expect(cookieConfigurationReads == 0)
        #expect(context.hasPrefix("public-"))
        #expect(stream.contextID == context)
        #expect(cached == stream)
        #expect(stream.bitrateKbps == 130.269)
    }

    @Test("Account mode without an authorized source fails before binary launch")
    func missingAccountSourceFailsClosed() async {
        let bridge = YTDlpBridge(binaryPath: "/nonexistent/yt-dlp", searchCache: nil,
            streamAccessPolicy: .configuredAccount, playbackCookieArguments: { [] })
        do {
            _ = try await bridge.resolveAudioStream(videoId: "abcdefghijk", quality: "256k")
            Issue.record("Account-required request must not resolve anonymously")
        } catch let error as YTDlpBridge.YTDlpError {
            #expect(error == .exitCode(1, "authorized session unavailable"))
        } catch { Issue.record("Unexpected error type") }
    }

    @Test("Access mode is encoded in opaque session/cache identity")
    func accessModePartitionsContext() {
        let publicBridge = YTDlpBridge(searchCache: nil, streamAccessPolicy: .publicAudio,
            playbackCookieArguments: { Issue.record("Public context read cookie settings"); return [] })
        let accountBridge = YTDlpBridge(searchCache: nil, streamAccessPolicy: .configuredAccount,
            playbackCookieArguments: { ["--cookies", "/private/session-path"] })
        let publicContext = publicBridge.streamContextID
        let accountContext = accountBridge.streamContextID
        #expect(publicContext != accountContext)
        #expect(publicContext.hasPrefix("public-"))
        #expect(accountContext.hasPrefix("account-"))
        #expect(!accountContext.contains("session-path"))
        let cache = StreamURLCache()
        cache.setStream(videoId: "video", quality: "256k", stream: ResolvedAudioStream(
            url: URL(string: "https://media.example/audio")!, contextID: accountContext))
        #expect(cache.getStream(videoId: "video", quality: "256k", contextID: publicContext) == nil)
        #expect(cache.getStream(videoId: "video", quality: "256k", contextID: accountContext) != nil)
        accountBridge.invalidateStreamSession()
        #expect(accountBridge.streamContextID != accountContext)
        #expect(publicBridge.streamContextID == publicContext)
    }

    @Test("Typed subprocess receives the 8 MiB stdout bound")
    func typedPipeLimit() async throws {
        let binary = try makeBinary("#!/bin/sh\n/bin/dd if=/dev/zero bs=1048576 count=9 2>/dev/null\n")
        defer { try? FileManager.default.removeItem(at: binary.deletingLastPathComponent()) }
        let bridge = YTDlpBridge(binaryPath: binary.path, searchCache: nil, streamAccessPolicy: .publicAudio)
        do {
            _ = try await bridge.resolveAudioStream(videoId: "abcdefghijk", quality: "256k", timeout: 5)
            Issue.record("Expected runner to reject the oversized stdout before JSON decoding")
        } catch let error as YTDlpBridge.YTDlpError {
            #expect(error == .parseFailed("Subprocess output exceeded configured limit"))
        }
    }

    @Test("Stored video profiles select uncapped audio only in typed playback", arguments: ["best", "1080p", "720p"])
    func legacyVideoProfilesResolveAudio(quality: String) async throws {
        let binary = try makeBinary(#"""
        #!/bin/sh
        audio=0
        while [ "$#" -gt 0 ]; do
            if [ "$1" = "-f" ]; then
                shift
                [ "$1" = "bestaudio" ] || exit 7
                audio=1
            fi
            shift
        done
        [ "$audio" = 1 ] || exit 8
        echo '{"id":"abcdefghijk","url":"https://media.example/audio","format_id":"251","acodec":"opus","vcodec":"none","abr":270.5,"protocol":"https"}'
        """#)
        defer { try? FileManager.default.removeItem(at: binary.deletingLastPathComponent()) }
        let bridge = YTDlpBridge(binaryPath: binary.path, searchCache: nil, streamAccessPolicy: .publicAudio)
        let stream = try await bridge.resolveAudioStream(videoId: "abcdefghijk", quality: quality)
        #expect(stream.codec == "opus")
        #expect(stream.bitrateKbps == 270.5)
        #expect(YTDlpBridge.qualityMap[quality] != "bestaudio")
    }

}
