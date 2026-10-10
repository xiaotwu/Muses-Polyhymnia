import AppIntents
import Foundation

/// System automation submits to the app's existing validated playback route.
@available(macOS 15.0, *)
struct PlayYouTubeLinkIntent: AppIntent {
    static let title: LocalizedStringResource = "Play YouTube Link"
    static let description = IntentDescription("Play a YouTube video or song in Muses.")
    static let openAppWhenRun = true

    @Parameter(title: "YouTube Link")
    var link: URL

    @Dependency private var playbackRouter: ExternalPlaybackRouter
    private var presentMainWindow: @MainActor @Sendable () -> Void = {
        MusesSingleInstance.orderFrontMainWindow()
    }

    init() {}

    /// Explicit bindings let unit tests exercise the handoff without system activation.
    @MainActor
    init(playbackRouter: ExternalPlaybackRouter,
         presentMainWindow: @escaping @MainActor @Sendable () -> Void) {
        self.playbackRouter = playbackRouter
        self.presentMainWindow = presentMainWindow
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Play \(\.$link) in Muses")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard ExternalPlaybackRoute(url: link) != nil else {
            throw LinkIntentError.unsupported
        }
        presentMainWindow()
        guard playbackRouter.open(link) else {
            throw LinkIntentError.unsupported
        }
        return .result()
    }
}

private enum LinkIntentError: LocalizedError {
    case unsupported
    var errorDescription: String? {
        tr("This is not a supported YouTube video link.", "这不是受支持的 YouTube 视频链接。", zhHant: "這不是支援的 YouTube 影片連結。")
    }
}

@available(macOS 15.0, *)
struct MusesAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: PlayYouTubeLinkIntent(),
                    phrases: ["Play a YouTube link in \(.applicationName)"],
                    shortTitle: "Play YouTube Link", systemImageName: "play.rectangle")
        AppShortcut(intent: SearchLyricsIntent(),
                    phrases: ["Search lyrics in \(.applicationName)", "Match lyrics in \(.applicationName)"],
                    shortTitle: "Search Lyrics", systemImageName: "text.magnifyingglass")
    }
}
