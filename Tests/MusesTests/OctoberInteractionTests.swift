import AppKit
import Testing
@testable import Muses

@Suite("Volume and lyrics activation")
struct OctoberInteractionTests {
    @Test("Rotary volume covers both endpoints and the middle without crossing the gap")
    func volumeSweep() {
        #expect(VolumeKnobMapping.volume(at: CGPoint(x: 4, y: 28), size: 32) == 0)
        #expect(abs(VolumeKnobMapping.volume(at: CGPoint(x: 16, y: 0), size: 32) - 0.5) < 0.001)
        #expect(VolumeKnobMapping.volume(at: CGPoint(x: 28, y: 28), size: 32) == 1)
        #expect(abs(VolumeKnobMapping.rotation(from: .pi - 0.05, to: -.pi + 0.05) - 0.1) < 0.001)
        #expect(VolumeScaleMapping.adjusted(0.9, delta: 80) == 1)
        #expect(VolumeScaleMapping.adjusted(0.1, delta: -80) == 0)
        #expect(VolumeScaleMapping.adjusted(0.5, delta: .nan) == 0.5)
    }

    @Test("Siri lyrics links preserve Unicode and reject foreign or ambiguous routes")
    func lyricsRoutes() throws {
        var components = URLComponents(string: "muses://lyrics")!
        components.queryItems = [.init(name: "q", value: "歌名 & artist")]
        #expect(LyricsSearchRoute(url: try #require(components.url))?.query == "歌名 & artist")
        #expect(LyricsSearchRoute(url: URL(string: "muses://lyrics?q=&q=other")!) == nil)
        #expect(LyricsSearchRoute(url: URL(string: "https://lyrics/?q=song")!) == nil)
        #expect(LyricsSearchRoute(url: URL(string: "muses://lyrics/private?q=song")!) == nil)
        #expect(LyricsSearchRoute(url: URL(string: "muses://lyrics?q=")!)?.query == "")
    }
}
