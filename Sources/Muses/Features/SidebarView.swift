import SwiftUI
import SwiftData

/// Persistent navigation islands; expanded labels never resize browsing content.
struct SidebarView: View {
    var onSettingsCategoryChange: () -> Void = {}
    var onKeyboardFocusChange: (Bool) -> Void = { _ in }
    var onPointerHoverChange: (Bool) -> Void = { _ in }
    var canGoBack = false
    var canGoForward = false
    var onBack: () -> Void = {}
    var onForward: () -> Void = {}
    @Binding var selection: SidebarSection
    @Binding var selectedPlaylist: Playlist?
    @Binding var selectedYouTubeImport: YouTubeImport?
    @AppStorage(PrefKey.settingsLastPane) private var settingsPane = SettingsCategory.general.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hoveredIsland: String?
    @State private var railHovered = false
    @State private var islandBounds: [String: CGRect] = [:]
    @FocusState private var focusedItem: String?

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    backAction
                    if selection == .settings {
                        settingsIsland(Array(SettingsCategory.allCases.prefix(5)), key: "settings-primary")
                        settingsIsland(Array(SettingsCategory.allCases.dropFirst(5)), key: "settings-secondary")
                    } else {
                        island(key: "primary", focusKeys: ["home", "search"]) { expanded in
                            destination(.home, icon: "house.fill", expanded: expanded)
                            destination(.search, icon: "magnifyingglass", expanded: expanded)
                        }
                        island(key: "library", focusKeys: ["new", "songs", "albums", "artists", "liked", "musicVideos", "podcasts", "subscriptions", "history", "playlists"]) { expanded in
                            destination(.new, icon: "square.grid.2x2.fill", expanded: expanded)
                            destination(.songs, icon: "music.note", expanded: expanded)
                            destination(.albums, icon: "square.stack.fill", expanded: expanded)
                            destination(.artists, icon: "person.2.fill", expanded: expanded)
                            destination(.liked, icon: "heart.fill", expanded: expanded)
                            destination(.musicVideos, icon: "play.rectangle.fill", expanded: expanded)
                            destination(.podcasts, icon: "mic.fill", expanded: expanded)
                            destination(.subscriptions, icon: "person.crop.rectangle.stack", expanded: expanded)
                            destination(.history, icon: "clock.arrow.circlepath", expanded: expanded)
                            destination(.playlists, icon: "rectangle.stack.fill", expanded: expanded)
                        }
                    }
                    settingsAction
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .frame(minHeight: geometry.size.height, alignment: .center)
                .frame(width: AppleMusicTokens.sidebarCollapsedWidth)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
        }
        .padding(.vertical, 12)
        .frame(width: 234)
        .frame(maxHeight: .infinity)
        .coordinateSpace(name: "muses-navigation")
        .contentShape(SidebarNavigationHitShape(islandBounds: Array(islandBounds.values)))
        .onPreferenceChange(SidebarIslandBoundsKey.self) { islandBounds = $0 }
        .onHover { inside in
            railHovered = inside
            onPointerHoverChange(inside || hoveredIsland != nil)
        }
        .onChange(of: hoveredIsland) { _, island in
            onPointerHoverChange(railHovered || island != nil)
        }
        .onReceive(NotificationCenter.default.publisher(for: .musesFocusNavigation)) { _ in
            if selection == .settings {
                focusedItem = (SettingsCategory(rawValue: settingsPane) ?? .general).destination.rawValue
            } else {
                let key = selection.rawValue
                let destinations = ["home", "search", "new", "songs", "albums", "artists", "liked", "musicVideos", "podcasts", "subscriptions", "history", "playlists"]
                focusedItem = destinations.contains(key) ? key : SidebarSection.home.rawValue
            }
        }
        .onChange(of: focusedItem) { _, item in
            onKeyboardFocusChange(item != nil)
        }
        .onChange(of: selection) { old, new in
            if (old == .settings) != (new == .settings) {
                hoveredIsland = nil
                focusedItem = nil
            }
            if new != .playlists {
                selectedPlaylist = nil
                selectedYouTubeImport = nil
            }
        }
    }

    private var backAction: some View {
        Button(action: onBack) {
            Image(systemName: "arrow.left")
                .font(MusesTypography.system(size: 18, weight: .semibold))
                .foregroundStyle(BrandColors.textPrimary)
                .opacity(canGoBack ? 1 : 0.38)
                .frame(width: 56, height: 56)
                .contentShape(Circle())
        }
        .buttonStyle(.fullAreaPlain)
        .musesGlass(in: Circle(), role: .navigationIsland)
        .focused($focusedItem, equals: "back")
        .overlay(Circle().stroke(BrandColors.accent, lineWidth: focusedItem == "back" ? 2 : 0))
        .disabled(!canGoBack)
        .help(tr("Back", "后退", zhHant: "返回"))
        .accessibilityLabel(tr("Back", "后退", zhHant: "返回"))
        .contextMenu {
            Button(tr("Forward", "前进", zhHant: "前進"), systemImage: "arrow.right", action: onForward)
                .disabled(!canGoForward)
        }
    }

    /// The settings/home circle shares the same spacing and centered group as the capsules.
    private var settingsAction: some View {
        Button {
            navigate(selection == .settings ? .home : .settings)
        } label: {
            Image(systemName: selection == .settings ? "house.fill" : "gearshape.fill")
                .font(MusesTypography.system(size: 18, weight: .semibold))
                .foregroundStyle(BrandColors.textPrimary)
                .frame(width: 56, height: 56)
                .contentShape(Circle())
        }
        .buttonStyle(.fullAreaPlain)
        .musesGlass(in: Circle(), role: .navigationIsland)
        .focused($focusedItem, equals: "footer")
        .overlay(Circle().stroke(BrandColors.accent, lineWidth: focusedItem == "footer" ? 2 : 0))
        .help(selection == .settings ? SidebarSection.home.title : SidebarSection.settings.title)
        .accessibilityLabel(selection == .settings ? SidebarSection.home.title : SidebarSection.settings.title)
    }

    private func island<Content: View>(key: String, focusKeys: [String], @ViewBuilder content: (Bool) -> Content) -> some View {
        let expanded = hoveredIsland == key || focusKeys.contains(focusedItem ?? "")
        // The anchor reserves only the rail; the actual capsule owns its complete hit region.
        return Color.clear
            .frame(width: 56, height: CGFloat(focusKeys.count) * 44 + 12)
            .allowsHitTesting(false)
            .overlay(alignment: .leading) {
                VStack(spacing: 0) {
                    content(expanded)
                }
                .padding(6)
                .frame(width: expanded ? 218 : 56, alignment: .leading)
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(key: SidebarIslandBoundsKey.self,
                                               value: [key: proxy.frame(in: .named("muses-navigation"))])
                    }
                    .allowsHitTesting(false)
                }
                .musesGlass(in: RoundedRectangle(cornerRadius: 28), role: .navigationIsland)
                .contentShape(RoundedRectangle(cornerRadius: 28))
                .onHover { inside in
                    if inside { hoveredIsland = key }
                    else if hoveredIsland == key { hoveredIsland = nil }
                }
                .allowsHitTesting(true)
            }
            .animation(MusesMotion.hoverAnimation(reduceMotion: reduceMotion), value: expanded)
    }

    private func destination(_ section: SidebarSection, icon: String, expanded: Bool) -> some View {
        Button { navigate(section) } label: {
            islandLabel(section.title, icon: icon, selected: selection == section, expanded: expanded)
        }
        .buttonStyle(.fullAreaPlain)
        .focused($focusedItem, equals: section.rawValue)
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(BrandColors.accent, lineWidth: focusedItem == section.rawValue ? 2 : 0))
        .help(section.title)
        .accessibilityLabel(section.title)
        .accessibilityAddTraits(selection == section ? .isSelected : [])
    }

    private func settingsIsland(_ categories: [SettingsCategory], key: String) -> some View {
        island(key: key, focusKeys: categories.map(\.rawValue)) { expanded in
            ForEach(categories) { category in
                let selected = (SettingsCategory(rawValue: settingsPane) ?? .general).destination == category
                Button {
                    onSettingsCategoryChange()
                    settingsPane = category.rawValue
                } label: {
                    islandLabel(category.sidebarLabel, icon: category.toolbarIcon, selected: selected, expanded: expanded)
                }
                .buttonStyle(.fullAreaPlain)
                .focused($focusedItem, equals: category.rawValue)
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(BrandColors.accent, lineWidth: focusedItem == category.rawValue ? 2 : 0))
                .help(category.label)
                .accessibilityLabel(category.label)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    private func islandLabel(_ title: String, icon: String, selected: Bool, expanded: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(MusesTypography.system(size: 17, weight: .semibold))
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)
            if expanded {
                Text(title)
                    .font(MusesTypography.system(size: 13, weight: selected ? .semibold : .regular))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
        }
        .frame(width: expanded ? 206 : 44, height: 44, alignment: .leading)
        .foregroundStyle(selected ? BrandColors.accent : BrandColors.textPrimary)
        .background(selected ? BrandColors.accent.opacity(0.16) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 22))
        .contentShape(RoundedRectangle(cornerRadius: 22))
    }

    private func navigate(_ section: SidebarSection) {
        if section == .settings {
            onSettingsCategoryChange()
            settingsPane = SettingsCategory.general.rawValue
        }
        selectedPlaylist = nil
        selectedYouTubeImport = nil
        selection = section
        if section == .home {
            NotificationCenter.default.post(name: .musesHomeScrollToTop, object: nil)
        } else if section == .albums || section == .artists {
            NotificationCenter.default.post(name: .musesNavigateFromSearch,
                                            object: GlobalSearchRoute.section(section))
        }
    }
}

/// The viewport fits expanded capsules; transparent space beyond the rail remains pass-through.
struct SidebarNavigationHitShape: Shape {
    var islandBounds: [CGRect]

    func path(in rect: CGRect) -> Path {
        var path = Path(CGRect(x: 0, y: 0, width: AppleMusicTokens.sidebarCollapsedWidth, height: rect.height))
        for bounds in islandBounds where bounds.width > 56 {
            path.addRoundedRect(in: bounds, cornerSize: CGSize(width: 28, height: 28))
        }
        return path
    }
}

private struct SidebarIslandBoundsKey: PreferenceKey {
    static let defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

/// Real history actions from the focused main-window scene, including immersive dismissal.
struct BrowseNavigationCommands {
    let canGoBack: Bool
    let canGoForward: Bool
    let back: () -> Void
    let forward: () -> Void
}

private struct BrowseNavigationCommandsKey: FocusedValueKey {
    typealias Value = BrowseNavigationCommands
}

extension FocusedValues {
    var musesBrowseNavigation: BrowseNavigationCommands? {
        get { self[BrowseNavigationCommandsKey.self] }
        set { self[BrowseNavigationCommandsKey.self] = newValue }
    }
}

extension Notification.Name {
    static let musesFocusNavigation = Notification.Name("muses.focusNavigation")
    static let musesSelectPlaylist = Notification.Name("muses.selectPlaylist")
    static let musesPlaylistsChanged = Notification.Name("muses.playlistsChanged")
}
