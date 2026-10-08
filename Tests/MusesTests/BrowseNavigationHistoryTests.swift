import Foundation
import Testing
@testable import Muses

@Suite("Browse navigation history")
struct BrowseNavigationHistoryTests {
    @Test func branchingAndDetails() {
        var history = BrowseNavigationHistory()
        let playlist = BrowseRoute.playlist(UUID())
        history.visit(.section(.playlists))
        history.visit(playlist)
        #expect(history.back() == .section(.playlists))
        #expect(history.forward() == playlist)
        #expect(history.back() == .section(.playlists))
        history.visit(.section(.songs))
        #expect(!history.canGoForward)
        history.visit(.section(.songs))
        #expect(history.entries.count == 3)
        #expect(history.back() == .section(.playlists))
        #expect(history.back() == .section(.home))
        #expect(history.back() == nil)
    }

    @Test func deletionFallbackAndBoundedMemory() {
        var history = BrowseNavigationHistory()
        for _ in 0..<150 { history.visit(.playlist(UUID())) }
        #expect(history.entries.count == 100)
        history.replaceCurrent(.section(.playlists))
        #expect(history.entries.last == .section(.playlists))
        #expect(history.forward() == nil)
    }
    @Test func settingsSubpagesShareHistoryAndBranch() {
        var history = BrowseNavigationHistory()
        let category = BrowseRoute.settings("youtube", [])
        let details = BrowseRoute.settings("youtube", [.diagnostics, .identity])
        history.visit(category)
        history.visit(details)
        #expect(history.back() == category)
        #expect(history.forward() == details)
        #expect(history.back() == category)
        history.visit(.settings("appearance", []))
        #expect(!history.canGoForward)
    }

    @Test func restoredDetailsHaveAParentWithoutRestoringOldHistory() {
        var settings = BrowseNavigationHistory(initial: .settings("appearance", []))
        #expect(settings.back() == .section(.home))
        var playlist = BrowseNavigationHistory(initial: .playlist(UUID()))
        #expect(playlist.back() == .section(.playlists))
        let snapshot = BrowseRouteSnapshot(route: .settings("youtube", [.account]), accountChannelID: "UCtest")
        #expect(snapshot.route(activeChannelID: nil) == .settings("youtube", [.account]))
        let channel = BrowseRouteSnapshot(route: .channel("UCchannel"), accountChannelID: "UCowner")
        #expect(channel.route(activeChannelID: "other") == nil)
        #expect(channel.route(activeChannelID: "UCowner") == .channel("UCchannel"))
    }

    @Test func modalCommandsPreserveHistoryUntilDismissal() {
        var history = BrowseNavigationHistory()
        history.visit(.section(.songs))
        history.visit(.section(.artists))
        #expect(history.back() == .section(.songs))
        let before = history.entries

        let blocked = BrowseNavigationCommands(
            canGoBack: history.canGoBack, canGoForward: history.canGoForward,
            isModalPresented: true,
            back: { _ = history.back() }, forward: { _ = history.forward() })
        #expect(!blocked.canGoBack && !blocked.canGoForward && !blocked.canSearch && !blocked.canBrowse)
        blocked.back()
        #expect(history.entries[history.index] == .section(.songs))
        blocked.forward()
        #expect(history.entries == before)
        #expect(history.entries[history.index] == .section(.songs))

        let restored = BrowseNavigationCommands(
            canGoBack: history.canGoBack, canGoForward: history.canGoForward,
            back: { _ = history.back() }, forward: { _ = history.forward() })
        #expect(restored.canGoBack && restored.canGoForward && restored.canSearch && restored.canBrowse)
        restored.forward()
        #expect(history.entries[history.index] == .section(.artists))
        restored.back()
        #expect(history.entries[history.index] == .section(.songs))
    }

    @Test func legacyDesktopRouteRestoresItsCurrentOwnerAndHistory() throws {
        let data = Data(#"{"version":1,"kind":"settings","value":"desktop","settingsPath":[]}"#.utf8)
        let snapshot = try JSONDecoder().decode(BrowseRouteSnapshot.self, from: data)
        let route = try #require(snapshot.route(activeChannelID: nil))
        #expect(route == .settings("general", []))

        var history = BrowseNavigationHistory(initial: route)
        #expect(history.back() == .section(.home))
        #expect(history.forward() == .settings("general", []))
        history.visit(.settings("appearance", []))
        #expect(history.back() == .settings("general", []))
    }

}
