import SwiftUI
import UserNotifications

/// Notification settings: opt-in switch for track-change notifications.
struct NotificationsSettingsView: View {
    @AppStorage(PrefKey.notificationsTrackChange) private var trackChangeEnabled = false
    @State private var authorizationRequested = false
    @State private var authorization: UNAuthorizationStatus?

    var body: some View {
        Section {
            Toggle(tr("Track changes", "换歌通知"), isOn: $trackChangeEnabled)
                .tint(BrandColors.accent)
                .onChange(of: trackChangeEnabled) { _, on in
                    if on && !authorizationRequested {
                        Task {
                            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert])
                            await refreshAuthorization()
                        }
                        authorizationRequested = true
                    }
                }
            LabeledContent(tr("Permission", "权限")) {
                HStack(spacing: 8) {
                    Text(permissionLabel).font(.caption).foregroundStyle(.secondary)
                    if authorization == .denied {
                        SettingsIconButton(title: tr("Open notification settings", "打开通知设置"), symbol: "arrow.up.right") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") { NSWorkspace.shared.open(url) }
                        }
                    }
                }
            }
        } header: { Text(tr("Notifications", "通知")).font(MusesTypography.headline.weight(.semibold)) }
        .task { await refreshAuthorization() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await refreshAuthorization() }
        }
    }
    private func refreshAuthorization() async {
        authorization = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }
    private var permissionLabel: String {
        switch authorization {
        case .authorized, .provisional, .ephemeral: tr("Allowed", "已允许")
        case .denied: tr("Disabled in System Settings", "在系统设置中关闭")
        case .notDetermined: tr("Not requested", "尚未请求")
        default: tr("Checking…", "正在检查…")
        }
    }
}