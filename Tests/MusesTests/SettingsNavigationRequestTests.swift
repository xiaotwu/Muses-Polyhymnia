import Foundation
import Testing
@testable import Muses

/// Exercise the real request path without creating windows or posting app notifications.
@Suite("Deferred Settings navigation", .serialized) @MainActor
struct SettingsNavigationRequestTests {
    @Test("a windowless update request retains About without changing the current pane")
    func deferredAboutRequest() {
        withRestoredPendingState {
            let savedPane = UserDefaults.standard.string(forKey: PrefKey.settingsLastPane)
            var windowRequests = 0
            var notifications: [SettingsCategory] = []

            MusesSingleInstance.requestSettings(.about, presentMainWindow: {
                windowRequests += 1
                // The destination must be available even if window creation is synchronous.
                #expect(MusesSingleInstance.pendingSettings == .about)
            }, notify: {
                notifications.append($0)
                #expect(MusesSingleInstance.pendingSettings == .about)
            })

            #expect(windowRequests == 1)
            #expect(notifications == [.about])
            // No RootView received the notification; a later view still has its destination.
            #expect(MusesSingleInstance.pendingSettings == .about)
            #expect(UserDefaults.standard.string(forKey: PrefKey.settingsLastPane) == savedPane)
        }
    }

    @Test("the ordinary Settings command supersedes a pending deep link with General")
    func ordinaryRequestReplacesDeepLink() {
        withRestoredPendingState {
            MusesSingleInstance.requestSettings(.about, presentMainWindow: {}, notify: { _ in })
            MusesSingleInstance.requestSettings(presentMainWindow: {}, notify: { _ in })
            #expect(MusesSingleInstance.pendingSettings == .general)
        }
    }

    @Test("legacy categories retain their redirected destination until the main view appears",
          arguments: [(SettingsCategory.audioQuality, SettingsCategory.playback),
                      (.desktop, .general), (.updates, .about), (.youtube, .youtube)])
    func deferredCategory(_ requested: SettingsCategory, _ expected: SettingsCategory) {
        withRestoredPendingState {
            var notification: SettingsCategory?
            MusesSingleInstance.requestSettings(requested, presentMainWindow: {}, notify: { notification = $0 })
            #expect(notification == expected)
            #expect(MusesSingleInstance.pendingSettings == expected)
        }
    }

    @Test("a new Settings request supersedes older settings and search destinations")
    func latestRequestWins() {
        withRestoredPendingState {
            MusesSingleInstance.pendingSearchRoute = .section(.songs)
            MusesSingleInstance.requestSettings(.about, presentMainWindow: {}, notify: { _ in })
            MusesSingleInstance.requestSettings(.lyrics, presentMainWindow: {}, notify: { _ in })
            #expect(MusesSingleInstance.pendingSettings == .lyrics)
            #expect(MusesSingleInstance.pendingSearchRoute == nil)
        }
    }

    private func withRestoredPendingState(_ operation: () -> Void) {
        let settings = MusesSingleInstance.pendingSettings
        let search = MusesSingleInstance.pendingSearchRoute
        defer {
            MusesSingleInstance.pendingSettings = settings
            MusesSingleInstance.pendingSearchRoute = search
        }
        operation()
    }
}
