import Foundation
import Testing
@testable import Muses

private actor CatalogRequestRecorder {
    var urls: [URL] = []
    var methods: [String] = []
    var bodies: [Data?] = []
    func append(_ request: URLRequest) {
        if let url = request.url { urls.append(url) }
        methods.append(request.httpMethod ?? "")
        bodies.append(request.httpBody)
    }
}

@Suite("YouTube catalog reads")
struct YouTubeCatalogReadTests {
    @Test("subscription target resolves only an exact stable channel ID")
    func channelLookup() async throws {
        let recorder = CatalogRequestRecorder()
        let client = YouTubeDataAPIClient(accessTokenProvider: { "test-token" },
            http: { request in
                let url = try #require(request.url)
                await recorder.append(request)
                let body = """
                    {"items":[{"id":"UCabcdefghij123456789012",
                    "snippet":{"title":"Verified Channel"}}]}
                    """
                return (Data(body.utf8), HTTPURLResponse(url: url,
                    statusCode: 200, httpVersion: nil, headerFields: nil)!)
            })
        let channel = try await client.channel(id: "UCabcdefghij123456789012")
        #expect(channel?.title == "Verified Channel")
        let urls = await recorder.urls
        #expect(urls.count == 1)
        #expect(URLComponents(url: urls[0], resolvingAgainstBaseURL: false)?
            .queryItems?.contains(.init(name: "id", value: "UCabcdefghij123456789012")) == true)
        await #expect(throws: YouTubeDataAPIClient.DataAPIError.self) {
            _ = try await client.channel(id: "Channel Name")
        }
        #expect(await recorder.urls.count == 1)
    }

    @Test("video metadata uses source timestamp and ISO duration without inferring missing availability")
    func videoMetadata() async throws {
        let client = YouTubeDataAPIClient(accessTokenProvider: { "test-token" },
            http: { request in
                let url = try #require(request.url)
                let body = """
                    {"items":[{"id":"abcdefghijk","snippet":{"publishedAt":"2025-11-14T08:30:00Z"},
                    "contentDetails":{"duration":"PT1H2M3S"},"status":{"uploadStatus":"processed"}}]}
                    """
                return (Data(body.utf8), HTTPURLResponse(url: url,
                    statusCode: 200, httpVersion: nil, headerFields: nil)!)
            })
        let values = try await client.videoMetadata(ids: ["abcdefghijk"])
        let item = try #require(values.first)
        #expect(item.durationMs == 3_723_000)
        #expect(item.publishedAt != nil)
        #expect(item.availability == .available)
    }

}
