import Testing
@testable import Muses

@MainActor
@Suite("Gallery preview playback boundary")
struct GalleryPreviewPresentationTests {
    @Test("Opening and dismissing details does not play; only explicit Play invokes the selected context")
    func explicitPlaybackOnly() {
        let presentation = GalleryPreviewPresentation()
        var played: [String] = []
        let first = GalleryMediaPreview(id: "first", title: "First", subtitle: "Artist",
                                        artwork: .placeholder, duration: nil,
                                        onPlay: { played.append("first-context") })
        let second = GalleryMediaPreview(id: "second", title: "Second", subtitle: "Publisher",
                                         artwork: .placeholder, duration: 120,
                                         onPlay: { played.append("second-context") })
        presentation.present(first)
        presentation.dismiss()
        presentation.play()
        #expect(played.isEmpty)
        presentation.present(first)
        presentation.present(second)
        presentation.play()
        #expect(played == ["second-context"])
        #expect(presentation.preview == nil)
        presentation.play()
        #expect(played.count == 1)
    }
}
