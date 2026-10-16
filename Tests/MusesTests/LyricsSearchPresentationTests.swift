import Foundation
import SwiftUI
import Testing
@testable import Muses

@MainActor
@Suite("Lyrics search presentation ownership")
struct LyricsSearchPresentationTests {
    @Test("Separate requests keep literal queries and distinct presentation identities")
    func literalQueryAndUniqueIdentity() {
        let query = "  Café「Synthetic Night」 (Session 2)\n"
        let first = LyricsSearchRequest(query: query)
        let second = LyricsSearchRequest(query: query)

        #expect(first.query == query)
        #expect(second.query == query)
        #expect(first.id != second.id)
    }

    @Test("A cold request survives a callback from the previous empty root render")
    func coldRequestAfterEmptyRootRender() {
        let state = LyricsPresentationFixture()
        let emptyRender = state.render(.root)
        #expect(emptyRender.wrappedValue == nil)
        let request = LyricsSearchRequest(query: "Synthetic cold request")
        state.request = request

        emptyRender.wrappedValue = nil
        let currentRender = state.render(.root)

        #expect(emptyRender.wrappedValue == nil)
        #expect(currentRender.wrappedValue == request)
        #expect(state.request == request)
        #expect(state.canonicalWriteCount == 0)
    }

    @Test("Plain Audio Info preserves root presentation without opening EQ")
    func plainAudioInfoUsesRootPresentation() {
        let state = LyricsPresentationFixture()
        state.audioInfoPresented = true
        let request = LyricsSearchRequest(query: "Synthetic plain info request")
        state.request = request
        let root = state.render(.root)
        let inactiveEQ = state.render(.equalizer)

        #expect(root.wrappedValue == request)
        #expect(inactiveEQ.wrappedValue == nil)
        inactiveEQ.wrappedValue = nil

        #expect(root.wrappedValue?.id == request.id)
        #expect(state.request == request)
        #expect(!state.equalizerPresented)
        #expect(state.canonicalWriteCount == 0)
    }

    @Test("A stale EQ flag and local dialog cannot steal a request from a closed Audio Info host")
    func staleEQStateFallsBackToRoot() {
        let state = LyricsPresentationFixture()
        state.audioInfoPresented = false
        state.equalizerPresented = true
        state.showSaveDialog = true
        let request = LyricsSearchRequest(query: "Synthetic root fallback")
        state.request = request
        let root = state.render(.root)
        let staleEQ = state.render(.equalizer)

        #expect(root.wrappedValue == request)
        #expect(staleEQ.wrappedValue == nil)
        staleEQ.wrappedValue = nil

        #expect(state.request == request)
        #expect(root.wrappedValue?.query == request.query)
        #expect(state.canonicalWriteCount == 0)
    }

    @Test("Root-to-EQ handoff retains the same request and ignores the old root dismissal")
    func rootToEqualizerHandoff() {
        let state = LyricsPresentationFixture()
        state.audioInfoPresented = true
        let request = LyricsSearchRequest(query: "Synthetic handoff — same identity")
        state.request = request
        let oldRoot = state.render(.root)
        #expect(oldRoot.wrappedValue == request)

        state.equalizerPresented = true
        let equalizer = state.render(.equalizer)
        #expect(oldRoot.wrappedValue == nil)
        #expect(equalizer.wrappedValue == request)
        oldRoot.wrappedValue = nil

        #expect(state.render(.root).wrappedValue == nil)
        #expect(equalizer.wrappedValue?.id == request.id)
        #expect(equalizer.wrappedValue?.query == request.query)
        #expect(state.request == request)
        #expect(state.canonicalWriteCount == 0)
    }

    @Test("EQ-to-root fallback retains identity and ignores the old EQ dismissal")
    func equalizerToRootHandoff() {
        let state = LyricsPresentationFixture()
        state.activate(.equalizer)
        let request = LyricsSearchRequest(query: "Synthetic fallback (Session 2)")
        state.request = request
        let oldEQ = state.render(.equalizer)
        #expect(oldEQ.wrappedValue == request)

        state.equalizerPresented = false
        let root = state.render(.root)
        oldEQ.wrappedValue = nil

        #expect(oldEQ.wrappedValue == nil)
        #expect(root.wrappedValue == request)
        #expect(state.request?.id == request.id)
        #expect(state.canonicalWriteCount == 0)
    }

    @Test("A prior render cannot dismiss a newer request even when its query is identical",
          arguments: [LyricsSearchHost.root, .equalizer])
    func oldDismissalCannotClearReplacement(host: LyricsSearchHost) {
        let state = LyricsPresentationFixture()
        state.activate(host)
        let first = LyricsSearchRequest(query: "Repeated synthetic query")
        state.request = first
        let oldRender = state.render(host)
        #expect(oldRender.wrappedValue == first)
        let replacement = LyricsSearchRequest(query: first.query)
        #expect(replacement.id != first.id)

        state.request = replacement
        let newRender = state.render(host)
        oldRender.wrappedValue = nil

        #expect(oldRender.wrappedValue == nil)
        #expect(newRender.wrappedValue == replacement)
        #expect(state.request == replacement)
        #expect(state.canonicalWriteCount == 0)
    }

    @Test("Only the current presenter consumes its current request, once",
          arguments: [LyricsSearchHost.root, .equalizer])
    func activePresenterDismissesOnce(host: LyricsSearchHost) {
        let state = LyricsPresentationFixture()
        state.activate(host)
        state.request = LyricsSearchRequest(query: "Synthetic close request")
        let active = state.render(host)
        let inactive = state.render(host == .root ? .equalizer : .root)
        #expect(active.wrappedValue != nil)

        inactive.wrappedValue = nil
        #expect(state.request != nil)
        #expect(state.canonicalWriteCount == 0)
        active.wrappedValue = nil
        active.wrappedValue = nil

        #expect(state.request == nil)
        #expect(state.render(host).wrappedValue == nil)
        #expect(state.canonicalWriteCount == 1)
    }

    @Test("Save As keeps an incoming request pending and exposes it after cancellation")
    func saveDialogDefersIncomingRequest() {
        let state = LyricsPresentationFixture()
        state.activate(.equalizer)
        state.showSaveDialog = true
        let emptyRender = state.render(.equalizer)
        let request = LyricsSearchRequest(query: "Synthetic request during Save As")
        state.request = request
        let blocked = state.render(.equalizer)

        #expect(blocked.wrappedValue == nil)
        #expect(state.render(.root).wrappedValue == nil)
        blocked.wrappedValue = nil
        #expect(state.request == request)
        state.showSaveDialog = false
        let resumed = state.render(.equalizer)
        emptyRender.wrappedValue = nil

        #expect(resumed.wrappedValue == request)
        #expect(resumed.wrappedValue?.id == request.id)
        #expect(state.canonicalWriteCount == 0)
    }

    @Test("Delete confirmation keeps the latest request and rejects an older blocked render")
    func deleteConfirmationPreservesLatestRequest() {
        let state = LyricsPresentationFixture()
        state.activate(.equalizer)
        state.pendingRemoval = ActionConfirmation(
            title: "Delete synthetic preset?", message: "Synthetic confirmation fixture.", action: {})
        let first = LyricsSearchRequest(query: "Synthetic request during deletion confirmation")
        state.request = first
        let olderBlocked = state.render(.equalizer)
        #expect(olderBlocked.wrappedValue == nil)
        olderBlocked.wrappedValue = nil
        #expect(state.request == first)
        let replacement = LyricsSearchRequest(query: "Latest synthetic request")
        state.request = replacement

        #expect(state.render(.equalizer).wrappedValue == nil)
        state.pendingRemoval = nil
        let resumed = state.render(.equalizer)
        olderBlocked.wrappedValue = nil

        #expect(resumed.wrappedValue == replacement)
        #expect(state.request == replacement)
        #expect(state.canonicalWriteCount == 0)
    }

    @Test("Moving into a locally blocked EQ host keeps one pending request without root fallback")
    func blockedHandoffDoesNotFallBackOrConsume() {
        let state = LyricsPresentationFixture()
        state.audioInfoPresented = true
        let request = LyricsSearchRequest(query: "Synthetic blocked handoff")
        state.request = request
        let oldRoot = state.render(.root)
        #expect(oldRoot.wrappedValue == request)

        state.equalizerPresented = true
        state.showSaveDialog = true
        let blockedEQ = state.render(.equalizer)
        oldRoot.wrappedValue = nil
        blockedEQ.wrappedValue = nil

        #expect(state.render(.root).wrappedValue == nil)
        #expect(blockedEQ.wrappedValue == nil)
        #expect(state.request == request)
        state.showSaveDialog = false
        #expect(state.render(.equalizer).wrappedValue == request)
        #expect(state.canonicalWriteCount == 0)
    }

    @Test("Presentation projections cannot replace the canonical business request")
    func projectedBindingCannotInsertOrReplaceRequests() {
        let state = LyricsPresentationFixture()
        state.activate(.equalizer)
        let current = LyricsSearchRequest(query: "Synthetic canonical request")
        state.request = current
        let equalizer = state.render(.equalizer)
        let root = state.render(.root)
        let unexpected = LyricsSearchRequest(query: "Synthetic projected write")

        equalizer.wrappedValue = unexpected
        root.wrappedValue = unexpected

        #expect(state.request == current)
        #expect(equalizer.wrappedValue == current)
        #expect(root.wrappedValue == nil)
        #expect(state.canonicalWriteCount == 0)
    }
}

@MainActor
private final class LyricsPresentationFixture {
    var request: LyricsSearchRequest?
    var audioInfoPresented = false
    var equalizerPresented = false
    var showSaveDialog = false
    var pendingRemoval: ActionConfirmation?
    private(set) var canonicalWriteCount = 0

    func activate(_ host: LyricsSearchHost) {
        audioInfoPresented = host == .equalizer
        equalizerPresented = host == .equalizer
    }

    func render(_ host: LyricsSearchHost) -> Binding<LyricsSearchRequest?> {
        let canonical = Binding<LyricsSearchRequest?>(
            get: { self.request },
            set: { self.request = $0; self.canonicalWriteCount += 1 })
        return LyricsSearchPresentation.binding(
            request: canonical, host: host,
            activeHost: {
                LyricsSearchPresentation.host(
                    audioInfoPresented: self.audioInfoPresented,
                    equalizerPresented: self.equalizerPresented)
            },
            isBlocked: { host == .equalizer && (self.showSaveDialog || self.pendingRemoval != nil) })
    }
}
