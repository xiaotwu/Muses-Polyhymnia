import Testing
@testable import Muses

@Suite("Home source presentation")
struct HomeSourceSelectionTests {
    @Test("Home keeps two sources and interprets the existing persisted modes")
    func persistedModes() {
        #expect(HomeSourceSelection.allCases == [.recommended, .account])
        #expect(HomeSourceSelection(mode: .muses) == .recommended)
        #expect(HomeSourceSelection(mode: .youtubeMusic) == .account)
        #expect(HomeSourceSelection.recommended.mode == .muses)
        #expect(HomeSourceSelection.account.mode == .youtubeMusic)
    }

    @Test("successful empty Muses Home offers Search without a no-op Retry")
    func emptyLibraryPresentation() {
        let presentation = HomeDiscoveryEmptyPresentation(
            source: .recommended, lastRefreshError: nil, sections: [])
        #expect(presentation == .library)
        #expect(!presentation.showsRetry)
    }

    @Test("empty account recommendations retain their own recovery action")
    func emptyAccountPresentation() {
        let presentation = HomeDiscoveryEmptyPresentation(
            source: .account, lastRefreshError: nil, sections: [])
        #expect(presentation == .account)
        #expect(presentation.showsRetry)
    }

    @Test("both sources retain Retry for a feed failure or an unlabelled failed section")
    func emptyFailurePresentation() {
        let failed = HomeSection(id: "failed", title: "Failed", kind: .quickPicks,
                                 items: [], status: .failed(nil), source: .localLibrary)
        for source in HomeSourceSelection.allCases {
            let feedFailure = HomeDiscoveryEmptyPresentation(
                source: source, lastRefreshError: "Unavailable", sections: [])
            let sectionFailure = HomeDiscoveryEmptyPresentation(
                source: source, lastRefreshError: nil, sections: [failed])
            #expect(feedFailure == .failure)
            #expect(feedFailure.showsRetry)
            #expect(sectionFailure == .failure)
            #expect(sectionFailure.showsRetry)
        }
    }

    @Test("Muses hides both live and cached account content")
    func musesContainsOnlyLibraryRecommendations() {
        let sections = [section("local", source: .localLibrary),
                        section("saved-local", source: .cached, origin: .localLibrary),
                        section("web", source: .signedInWeb, channel: "UC_one"),
                        section("saved-web", source: .cached, origin: .signedInWeb, channel: "UC_one")]
        #expect(HomeSourceSelection.recommended.visibleSections(sections, accountChannelID: "UC_one")
            .map(\.id) == ["local", "saved-local"])
    }

    @Test("Account presentation includes only the current channel's verified origins")
    func accountContainsOnlyOwnedContent() {
        let sections = [section("local", source: .localLibrary),
                        section("web", source: .signedInWeb, channel: "UC_one"),
                        section("likes", source: .officialAccount, channel: "UC_one"),
                        section("saved-web", source: .cached, origin: .signedInWeb, channel: "UC_one"),
                        section("other-web", source: .cached, origin: .signedInWeb, channel: "UC_two"),
                        section("unowned", source: .signedInWeb),
                        section("unknown-cache", source: .cached, channel: "UC_one")]
        #expect(HomeSourceSelection.account.visibleSections(sections, accountChannelID: "UC_one")
            .map(\.id) == ["web", "likes", "saved-web"])
        #expect(HomeSourceSelection.account.visibleSections(sections, accountChannelID: nil).isEmpty)
        #expect(HomeSourceSelection.account.visibleSections(sections, accountChannelID: "").isEmpty)
    }

    private func section(_ id: String, source: HomeSource, origin: HomeSource? = nil,
                         channel: String? = nil) -> HomeSection {
        HomeSection(id: id, title: id, kind: .quickPicks, items: [], source: source,
                    cachedOrigin: origin, accountChannelID: channel)
    }
}
