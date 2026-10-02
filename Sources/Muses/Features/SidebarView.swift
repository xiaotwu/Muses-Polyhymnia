import SwiftUI
import SwiftData

/// Persistent navigation islands; expanded labels never resize browsing content.
struct SidebarView: View {
    var onSettingsCategoryChange: () -> Void = {}
    var onKeyboardFocusChange: (Bool) -> Void = { _ in }
    @Binding var selection: SidebarSection
    @Binding var selectedPlaylist: Playlist?
    @Binding var selectedYouTubeImport: YouTubeImport?
    @AppStorage(PrefKey.settingsLastPane) private var settingsPane = SettingsCategory.general.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hoveredIsland: String?
    @FocusState private var focusedItem: String?

    var body: some View {
        VStack(spacing: 16) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if selection == .settings {
                        settingsIsland(Array(SettingsCategory.allCases.prefix(5)), key: "settings-primary")
                        settingsIsland(Array(SettingsCategory.allCases.dropFirst(5)), key: "settings-secondary")
                    } else {
                        island(key: "primary", focusKeys: ["search", "home"]) { expanded in
                            destination(.search, icon: "magnifyingglass", expanded: expanded)
                            destination(.home, icon: "house.fill", expanded: expanded)
                        }
                        island(key: "library", focusKeys: ["new", "songs", "catalog", "liked", "musicVideos", "podcasts", "subscriptions", "history", "playlists"]) { expanded in
                            destination(.new, icon: "square.grid.2x2.fill", expanded: expanded)
                            destination(.songs, icon: "music.note", expanded: expanded)
                            catalogDestination(expanded: expanded)
                            destination(.liked, icon: "heart.fill", expanded: expanded)
                            destination(.musicVideos, icon: "play.rectangle.fill", expanded: expanded)
                            destination(.podcasts, icon: "mic.fill", expanded: expanded)
                            destination(.subscriptions, icon: "person.crop.rectangle.stack", expanded: expanded)
                            destination(.history, icon: "clock.arrow.circlepath", expanded: expanded)
                            destination(.playlists, icon: "rectangle.stack.fill", expanded: expanded)
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()

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
        .padding(.top, 12)
        .padding(.bottom, 16)
        .frame(width: AppleMusicTokens.sidebarCollapsedWidth)
        .frame(maxHeight: .infinity, alignment: .top)
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

    private func island<Content: View>(key: String, focusKeys: [String], @ViewBuilder content: (Bool) -> Content) -> some View {
        let expanded = hoveredIsland == key || focusKeys.contains(focusedItem ?? "")
        return VStack(spacing: 0) {
            content(expanded)
        }
        .padding(6)
        .frame(width: expanded ? 218 : 56, alignment: .leading)
        .musesGlass(in: RoundedRectangle(cornerRadius: 28), role: .navigationIsland)
        .frame(width: 56, alignment: .leading)
        .onHover { inside in
            if inside { hoveredIsland = key }
            else if hoveredIsland == key { hoveredIsland = nil }
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

    private func catalogDestination(expanded: Bool) -> some View {
        let selected = selection == .albums || selection == .artists
        let title = tr("Albums & Artists", "专辑与艺术家")
        return Menu {
            Button(SidebarSection.albums.title, systemImage: "square.stack.fill") { navigate(.albums) }
            Button(SidebarSection.artists.title, systemImage: "person.2.fill") { navigate(.artists) }
        } label: {
            islandLabel(title, icon: "square.stack.fill", selected: selected, expanded: expanded)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .focused($focusedItem, equals: "catalog")
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(BrandColors.accent, lineWidth: focusedItem == "catalog" ? 2 : 0))
        .help(title)
        .accessibilityLabel(title)
        .accessibilityValue(selected ? selection.title : "")
        .accessibilityAddTraits(selected ? .isSelected : [])
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
            if expanded {
                Text(title)
                    .font(MusesTypography.system(size: 13, weight: selected ? .semibold : .regular))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
        }
        .foregroundStyle(selected ? BrandColors.accent : BrandColors.textPrimary)
        .background(selected ? BrandColors.accent.opacity(0.16) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 22))
        .contentShape(RoundedRectangle(cornerRadius: 22))
    }

    private func navigate(_ section: SidebarSection) {
        selectedPlaylist = nil
        selectedYouTubeImport = nil
        selection = section
    }
}

extension Notification.Name {
    static let musesSelectPlaylist = Notification.Name("muses.selectPlaylist")
    static let musesPlaylistsChanged = Notification.Name("muses.playlistsChanged")
}
