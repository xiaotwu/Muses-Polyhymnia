import AppKit

/// Retains an external presentation request until the actual main window attaches.
/// Factories can arrive after an App Intent starts the process without a scene.
@MainActor
final class MainWindowPresentationCoordinator {
    private var factory: (() -> Void)?
    private(set) var isPending = false
    private(set) var isCreationRequested = false

    func installFactory(_ factory: @escaping () -> Void) {
        self.factory = factory
    }

    @discardableResult
    func request(presentExisting: () -> Bool) -> Bool {
        isPending = true
        return fulfillPendingRequest(presentExisting: presentExisting)
    }

    @discardableResult
    func fulfillPendingRequest(presentExisting: () -> Bool) -> Bool {
        guard isPending else { return false }
        if presentExisting() {
            complete()
            return true
        }
        guard let factory else { return false }
        guard !isCreationRequested else { return true }
        isCreationRequested = true
        factory()
        return true
    }

    func mainWindowConfigured(present: () -> Void) {
        guard isPending else { return }
        complete()
        present()
    }

    private func complete() {
        isPending = false
        isCreationRequested = false
    }
}

/// Same bundle ID can still launch twice from different `.app` paths (dev builds /
/// worktrees). The second process must not open the SwiftData store.
enum MusesSingleInstance {
    static let mainSceneID = "main"
    @MainActor private static let configuredMainWindows = NSHashTable<NSWindow>.weakObjects()
    @MainActor private static let mainWindowPresentation = MainWindowPresentationCoordinator()
    @MainActor private static var mainWindowBootstrapScheduled = false
    @MainActor static var pendingSettings = false
    @MainActor static var pendingVideoPresentation = false
    @MainActor static var pendingSearchRoute: GlobalSearchRoute?
    @MainActor static var pendingLyricsQuery: String?

    @MainActor static func requestLyricsSearch(_ query: String) {
        pendingLyricsQuery = query
        orderFrontMainWindow()
        NotificationCenter.default.post(name: .musesSearchLyrics, object: query)
    }

    @MainActor
    static func requestSettings(_ category: SettingsCategory? = nil) {
        if let category {
            UserDefaults.standard.set(category.destination.rawValue, forKey: PrefKey.settingsLastPane)
        }
        pendingSearchRoute = nil
        pendingSettings = true
        orderFrontMainWindow()
        NotificationCenter.default.post(name: .musesOpenSettings, object: category)
    }
    @MainActor
    static func requestSearchNavigation(_ route: GlobalSearchRoute) {
        pendingSettings = false
        pendingSearchRoute = route
        orderFrontMainWindow()
        NotificationCenter.default.post(name: .musesNavigateFromSearch, object: route)
    }

    static let mainWindowAutosaveName = "MusesMainWindow"
    static let mainWindowIdentifier = NSUserInterfaceItemIdentifier("Muses.main-window")

    static func shouldYield(otherPids: [pid_t], currentPid: pid_t) -> Bool {
        otherPids.contains { $0 != currentPid && $0 > 0 }
    }

    /// Activate the already-running copy and abort this process *before* opening
    /// the active YouTube-native store. Safe to call from `MusesApp.init`.
    static func yieldIfOtherInstanceRunning(
        bundleId: String? = Bundle.main.bundleIdentifier,
        currentPid: pid_t = ProcessInfo.processInfo.processIdentifier
    ) {
        guard let bundleId else { return }
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
            .filter { $0.processIdentifier != currentPid }
        guard let existing = others.first else { return }
        existing.activate(options: [.activateAllWindows])
        Darwin.exit(0)
    }

    @MainActor
    static func isMainWindow(_ window: NSWindow) -> Bool {
        configuredMainWindows.contains(window) || window.identifier == mainWindowIdentifier
            || window.frameAutosaveName == mainWindowAutosaveName
    }

    @MainActor
    static func mainWindow(in windows: [NSWindow]) -> NSWindow? {
        windows.first(where: isMainWindow)
    }

    /// Commands exist even when a foreground Intent starts the app without its
    /// main view. Install their scene action without requiring RootView.onAppear.
    @MainActor
    static func installMainWindowFactory(_ factory: @escaping () -> Void) {
        mainWindowPresentation.installFactory(factory)
        guard mainWindowPresentation.isPending, !mainWindowBootstrapScheduled else { return }
        mainWindowBootstrapScheduled = true
        // Finish the command/scene graph update before asking SwiftUI to open it.
        Task { @MainActor in
            await Task.yield()
            mainWindowBootstrapScheduled = false
            mainWindowPresentation.fulfillPendingRequest(presentExisting: presentExistingMainWindow)
        }
    }

    /// Brings forward only the configured browse window. Auxiliary Search and
    /// Mini Player windows must never be promoted into the main-window role.
    @MainActor
    @discardableResult
    static func orderFrontMainWindow() -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        return mainWindowPresentation.request(presentExisting: presentExistingMainWindow)
    }

    @MainActor
    private static func presentExistingMainWindow() -> Bool {
        guard let window = mainWindow(in: NSApp.windows) else { return false }
        presentMainWindow(window)
        return true
    }

    @MainActor
    private static func presentMainWindow(_ window: NSWindow) {
        NSApp.activate(ignoringOtherApps: true)
        if window.isMiniaturized { window.deminiaturize(nil) }
        window.makeKeyAndOrderFront(nil)
    }

    /// Idempotent main-window configuration. Standard traffic-light buttons
    /// remain in AppKit's native titlebar hierarchy.
    @MainActor
    @discardableResult
    static func configureMainWindow(_ window: NSWindow) -> CGSize {
        configuredMainWindows.add(window)
        window.identifier = mainWindowIdentifier
        window.setFrameAutosaveName(mainWindowAutosaveName)
        window.isMovableByWindowBackground = true
        // Keep one stable semantic title for Window-menu and accessibility use;
        // route changes must never surface a destination label in the titlebar.
        window.title = "Muses"
        window.subtitle = ""
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.titlebarSeparatorStyle = .none
        window.toolbar?.isVisible = true
        window.toolbar?.allowsUserCustomization = false
        window.toolbarStyle = .unified
        let minimumSize = WindowChromeMetrics.minimumContentSize(
            visibleSize: (window.screen ?? NSScreen.main)?.visibleFrame.size,
            titlebarHeight: window.frame.height - window.contentLayoutRect.height)
        window.contentMinSize = minimumSize
        for type in [
            NSWindow.ButtonType.closeButton,
            .miniaturizeButton,
            .zoomButton
        ] {
            window.standardWindowButton(type)?.isHidden = false
        }
        mainWindowPresentation.mainWindowConfigured { presentMainWindow(window) }
        return minimumSize
    }
}
