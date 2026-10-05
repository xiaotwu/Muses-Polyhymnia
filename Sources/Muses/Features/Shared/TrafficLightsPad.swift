import SwiftUI
import AppKit

/// Sidebar glass meets the window on three sides and rounds only toward content.
enum SidebarPaneShape {
    /// Mirror the leading pane: interior corners round toward browsing content;
    /// the window supplies the exterior corner clipping.
    static var trailingShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: AppleMusicTokens.sidebarCorner,
            bottomLeadingRadius: AppleMusicTokens.sidebarCorner,
            bottomTrailingRadius: 0,
            topTrailingRadius: 0,
            style: .continuous
        )
    }

    static var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: AppleMusicTokens.sidebarCorner,
            topTrailingRadius: AppleMusicTokens.sidebarCorner,
            style: .continuous
        )
    }
}

/// Transparent layout clearance beneath AppKit's native traffic lights.
///
/// The standard close, minimize, and zoom buttons remain owned and positioned
/// by `NSWindow`; this view never hosts or moves them.
struct TrafficLightsPad: View {
    var body: some View {
        Color.clear
            .frame(
                width: WindowChromeMetrics.trafficLightClearanceWidth,
                height: WindowChromeMetrics.trafficLightClearanceHeight
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// The one narrow AppKit boundary used to configure the SwiftUI main window.
struct MainWindowConfigurator: NSViewRepresentable {
    var onMinimumSizeChange: (CGSize) -> Void = { _ in }

    func makeNSView(context: Context) -> MainWindowConfigurationView {
        MainWindowConfigurationView()
    }

    func updateNSView(_ nsView: MainWindowConfigurationView, context: Context) {
        nsView.onMinimumSizeChange = onMinimumSizeChange
        nsView.configure()
    }
}

final class MainWindowConfigurationView: NSView {
    var onMinimumSizeChange: (CGSize) -> Void = { _ in }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        NotificationCenter.default.removeObserver(self)
        guard let window else { return }
        NotificationCenter.default.addObserver(self, selector: #selector(screenChanged),
                                               name: NSWindow.didChangeScreenNotification, object: window)
        NotificationCenter.default.addObserver(self, selector: #selector(screenChanged),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)
        configure()
    }

    @objc private func screenChanged(_ notification: Notification) { configure() }

    func configure() {
        guard let window else { return }
        let minimumSize = MusesSingleInstance.configureMainWindow(window)
        // Publish after the representable update; the scene owns the final sizing contract.
        Task { @MainActor [weak self] in self?.onMinimumSizeChange(minimumSize) }
    }
}

/// SwiftUI can update toolbar presentation after the AppKit configuration runs.
struct MainWindowTitleHidden: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 15.0, *) {
            content.toolbar(removing: .title)
        } else {
            content
        }
    }
}
