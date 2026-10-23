import Foundation
import Testing
@testable import Muses

@MainActor
@Suite("Mpv native library boundary", .serialized)
struct MpvNativeClientTests {
    @Test("An absent exact library fails closed without consulting system mpv")
    func missingPackagedLibrary() async {
        let path = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("muses-mpv-absent-\(UUID().uuidString)/libmpv.2.dylib")
        let client = NativeMpvClient(testLibraryURL: path)
        do {
            try await client.load(ResolvedAudioStream(url: URL(string: "https://example.test/audio")!), generation: 1)
            Issue.record("An absent packaged library must fail closed")
        } catch let failure as MpvFailure {
            #expect(failure.stage == .library)
            #expect(failure.code == -1001)
        } catch {
            Issue.record("Expected a safe structured library failure")
        }
        client.stop()
    }
}
