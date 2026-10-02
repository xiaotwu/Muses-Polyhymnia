import AppKit
import SwiftUI
import WebKit

/// Session-owned presentation. Reparenting the view never navigates or creates another player.
@Observable
@MainActor
final class VideoSurface: NSObject, NSWindowDelegate {
    private(set) var isFloating = false
    private(set) var isClosing = false
    let session: VideoPlaybackSession
    @ObservationIgnored private let playerView: NSView
    @ObservationIgnored private let stopPlayer: (@escaping () -> Void) -> Void
    @ObservationIgnored private let resume: Bool
    @ObservationIgnored private let presentsWindow: Bool
    @ObservationIgnored private var panel: NSPanel?
    @ObservationIgnored private weak var playback: PlaybackService?
    var onPresentationClosed: (() -> Void)?

    convenience init(session: VideoPlaybackSession, playback: PlaybackService, resume: Bool) {
        let (view, coordinator) = YouTubeWKEmbed.makePlayer(session: session, onStopped: {})
        self.init(session: session, playback: playback, resume: resume, playerView: view,
                  presentsWindow: true) { completion in
            coordinator.onStopped = completion
            YouTubeWKEmbed.stopPlayer(view, coordinator: coordinator)
        }
    }

    /// Injected view and stop acknowledgement allow lifecycle tests without a live WebView.
    init(session: VideoPlaybackSession, playback: PlaybackService, resume: Bool,
         playerView: NSView, presentsWindow: Bool,
         stopPlayer: @escaping (@escaping () -> Void) -> Void) {
        self.session = session
        self.playback = playback
        self.playerView = playerView
        self.stopPlayer = stopPlayer
        self.resume = resume
        self.presentsWindow = presentsWindow
        super.init()
        session.onClose = { [weak self] in self?.close() }
    }

    func attach(to host: NSView, floating: Bool) {
        guard !isClosing, floating == isFloating, playerView.superview !== host else { return }
        playerView.removeFromSuperview()
        playerView.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(playerView)
        NSLayoutConstraint.activate([
            playerView.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            playerView.topAnchor.constraint(equalTo: host.topAnchor),
            playerView.bottomAnchor.constraint(equalTo: host.bottomAnchor)
        ])
    }

    func float() {
        guard !isClosing, !isFloating, let playback else { return }
        isFloating = true
        guard presentsWindow else { return }
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 480, height: 270),
                            styleMask: [.titled, .fullSizeContentView, .resizable, .utilityWindow],
                            backing: .buffered, defer: false)
        panel.title = tr("Floating Video", "悬浮视频", zhHant: "浮動影片")
        panel.identifier = NSUserInterfaceItemIdentifier("Muses.floating-video")
        panel.isReleasedWhenClosed = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
        panel.contentMinSize = NSSize(width: 320, height: 180)
        panel.contentAspectRatio = NSSize(width: 16, height: 9)
        panel.delegate = self
        panel.contentView = NSHostingView(rootView: FloatingVideoView(surface: self).environment(playback))
        self.panel = panel
        if let main = NSApp.windows.first(where: { $0.identifier == MusesSingleInstance.mainWindowIdentifier }),
           let visible = main.screen?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: min(max(visible.minX, main.frame.maxX - 504), visible.maxX - 480),
                                         y: min(max(visible.minY, main.frame.minY + 24), visible.maxY - 270)))
        } else { panel.center() }
        panel.makeKeyAndOrderFront(nil)
    }

    /// Returning preserves transport, session identity, and the exact WebView instance.
    func dock() {
        guard !isClosing else { return }
        isFloating = false
        releasePanel()
    }

    func returnToMain() {
        guard !isClosing else { return }
        dock()
        MusesSingleInstance.pendingVideoPresentation = true
        MusesSingleInstance.orderFrontMainWindow()
        NotificationCenter.default.post(name: .musesDockYouTubeVideo, object: nil)
    }

    func close() {
        guard !isClosing else { return }
        isClosing = true
        releasePanel()
        session.requestClose()
        onPresentationClosed?()
        onPresentationClosed = nil
        playerView.removeFromSuperview()
        stopPlayer { [weak playback, session, resume] in
            playback?.finishVideoSession(session, resume: resume)
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        close()
        return false
    }

    private func releasePanel() {
        panel?.delegate = nil
        panel?.orderOut(nil)
        panel?.contentView = nil
        panel?.close()
        panel = nil
    }
}

private struct FloatingVideoView: View {
    let surface: VideoSurface
    @Environment(PlaybackService.self) private var playback

    var body: some View {
        ZStack(alignment: .topTrailing) {
            YouTubeWKEmbed(surface: surface, floating: true)
                .background(.black)
                .overlay {
                    if surface.session.state.error != nil {
                        Text(tr("Video unavailable", "视频暂不可用", zhHant: "影片暫不可用"))
                            .foregroundStyle(.white).padding()
                    }
                }
            HStack(spacing: 12) {
                Button(action: surface.returnToMain) {
                    Label(tr("Return to main window", "返回主窗口", zhHant: "返回主視窗"),
                          systemImage: "arrow.up.left.and.arrow.down.right")
                }
                Button(action: surface.close) { Image(systemName: "xmark") }
                    .accessibilityLabel(tr("Close video", "关闭视频", zhHant: "關閉影片"))
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .foregroundStyle(.white)
            .padding(8)
            .background(.black.opacity(0.65), in: Capsule())
            .padding(10)
        }
        .ignoresSafeArea()
        .onExitCommand(perform: surface.close)
    }
}
