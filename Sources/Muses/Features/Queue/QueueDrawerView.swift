import SwiftUI

private enum QueueFocusTarget: Hashable {
    case drawer
}

/// Integrated trailing pane showing Current Queue / Up Next / History.
/// The current queue and Up Next support drag reordering (`.onMove`); History is read-only.
struct QueueDrawerView: View {
    @Environment(PlaybackService.self) private var playback
    @Binding var isPresented: Bool
    var showsScrim: Bool = true
    /// Advanced Queue flag off: keep the existing UI (grouping, history labels, restore, and remove are hidden).
    @AppStorage(PrefKey.ffAdvancedQueue) private var advancedQueue = true
    /// Target group id and draft text for the rename-group alert.
    @State private var renameTarget: QueueGroup.ID?
    @State private var renameText = ""
    @State private var pendingRemoval: ActionConfirmation?
    @State private var collectionExpanded = true
    @State private var upNextExpanded = true
    @State private var historyExpanded = false
    @State private var groupsExpanded = false
    @State private var showsSmartShuffleInfo = false
    @State private var smartShuffleFocusTask: Task<Void, Never>?
    @FocusState private var smartShuffleInfoFocused: Bool
    /// Keep Escape available while painting focus only on the close affordance.
    @FocusState private var focusedTarget: QueueFocusTarget?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            if showsScrim {
                BrandColors.scrim
                    .ignoresSafeArea()
                    .onTapGesture { isPresented = false }
            }
            drawer
                .frame(width: QueueChromePolicy.width)
                .frame(maxHeight: .infinity)
                .clipShape(SidebarPaneShape.trailingShape)
                .background {
                    // The trailing pane uses its own header inset; extend chrome
                    // through any remaining unified-toolbar safe area.
                    Color.clear
                        .musesGlass(in: SidebarPaneShape.trailingShape, role: .persistentChrome)
                        .ignoresSafeArea(.container, edges: .top)
                }
                .focusable()
                .focusEffectDisabled()
                .focused($focusedTarget, equals: .drawer)
                .onKeyPress(.escape) {
                    guard renameTarget == nil, pendingRemoval == nil else { return .ignored }
                    dismissUnlessRenaming()
                    return .handled
                }
                .transition(.move(edge: .trailing))
        }
        .actionConfirmation($pendingRemoval)
        .onExitCommand { dismissUnlessRenaming() }
        .onAppear { focusedTarget = .drawer }
        .onChange(of: renameTarget) { _, target in
            focusedTarget = target == nil ? .drawer : nil
        }
        .onDisappear { smartShuffleFocusTask?.cancel(); smartShuffleFocusTask = nil }
        .onChange(of: showsSmartShuffleInfo) { _, shown in
            smartShuffleFocusTask?.cancel()
            smartShuffleFocusTask = nil
            if !shown {
                // Let the native popover finish its dismissal before restoring key focus.
                smartShuffleFocusTask = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(150))
                    guard !Task.isCancelled else { return }
                    if isPresented, !showsSmartShuffleInfo { focusedTarget = .drawer }
                }
            }
        }
        .animation(MusesMotion.drawerAnimation(reduceMotion: reduceMotion), value: isPresented)
    }

    private func dismissUnlessRenaming() {
        if showsSmartShuffleInfo {
            showsSmartShuffleInfo = false
            return
        }
        if renameTarget == nil, pendingRemoval == nil { isPresented = false }
    }

    private var repeatAccessibilityValue: String {
        switch playback.queue.repeatMode {
        case .off: return tr("Off", "关闭")
        case .one: return tr("One song", "单曲")
        case .all: return tr("Current queue", "当前队列")
        }
    }

    private var drawer: some View {
        VStack(spacing: 0) {
            header
            if playback.queue.persistenceFailed {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(tr("Queue changes could not be saved.", "队列更改未能保存。", zhHant: "佇列變更未能儲存。"))
                    Spacer(minLength: 4)
                    Button(tr("Retry", "重试", zhHant: "重試")) {
                        playback.queue.persist()
                    }
                }
                .font(MusesTypography.caption)
                .foregroundStyle(.orange)
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
                .accessibilityElement(children: .combine)
            }
            HStack(spacing: 8) {
                Toggle(isOn: Binding(get: { playback.queue.smartShuffle.enabled },
                                     set: { playback.setSmartShuffle($0) })) {
                    Label(tr("Smart Shuffle", "智能随机播放"), systemImage: "sparkles")
                }
                .toggleStyle(.switch)
                .controlSize(.small)
                Button {
                    showsSmartShuffleInfo.toggle()
                } label: {
                    Image(systemName: "info.circle")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.borderless)
                .help(tr("About Smart Shuffle", "关于智能随机播放"))
                .accessibilityLabel(tr("About Smart Shuffle", "关于智能随机播放"))
                .popover(isPresented: $showsSmartShuffleInfo) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(tr("Smart Shuffle", "智能随机播放"))
                            .font(MusesTypography.headline)
                        Text(tr("After three collection songs, insert at most one YouTube Music recommendation. Play Next takes priority. Recommendations never change your saved playlist.",
                                "每播放三首集合歌曲，最多插入一首 YouTube Music 推荐。手动下一首优先；推荐不会改变已保存的歌单。"))
                            .font(MusesTypography.callout)
                            .foregroundStyle(BrandColors.textSecondary)
                    }
                    .padding(18)
                    .frame(width: 300, alignment: .leading)
                    .focusable()
                    .focused($smartShuffleInfoFocused)
                    .onAppear { smartShuffleInfoFocused = true }
                    .onKeyPress(.escape) {
                        showsSmartShuffleInfo = false
                        return .handled
                    }
                    .onExitCommand { showsSmartShuffleInfo = false }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
            list
        }
    }

    private var header: some View {
        HStack {
            Text(tr("Playing Next", "接下来播放"))
                .font(MusesTypography.system(size: 17, weight: .semibold))
                .foregroundStyle(BrandColors.textPrimary)
            Spacer()
            // Repeat mode cycle
            Button {
                playback.queue.setRepeat(playback.queue.repeatMode.next)
            } label: {
                Image(systemName: playback.queue.repeatMode == .one ? "repeat.1" : "repeat")
                    .font(MusesTypography.body.weight(.semibold))
                    .chromeActionCircle()
                    .background(playback.queue.repeatMode == .off ? Color.clear : BrandColors.accent.opacity(0.12), in: Circle())
                    .overlay(Circle().stroke(playback.queue.repeatMode == .off ? Color.clear : BrandColors.accent.opacity(0.25), lineWidth: 1).allowsHitTesting(false))
            }
            .foregroundStyle(playback.queue.repeatMode == .off
                             ? BrandColors.textSecondary : BrandColors.accent)
            .buttonStyle(.fullAreaPlain)
            .help(tr("Repeat mode", "循环模式"))
            .accessibilityLabel(tr("Repeat mode", "循环模式"))
            .accessibilityValue(repeatAccessibilityValue)

            // Shuffle toggle
            Button {
                playback.queue.toggleShuffle()
            } label: {
                Image(systemName: "shuffle")
                    .font(MusesTypography.body.weight(.semibold))
                    .chromeActionCircle()
                    .background(playback.queue.shuffle ? BrandColors.accent.opacity(0.12) : Color.clear, in: Circle())
                    .overlay(Circle().stroke(playback.queue.shuffle ? BrandColors.accent.opacity(0.25) : Color.clear, lineWidth: 1).allowsHitTesting(false))
            }
            .foregroundStyle(playback.queue.shuffle
                             ? BrandColors.accent : BrandColors.textSecondary)
            .buttonStyle(.fullAreaPlain)
            .help(tr("Shuffle", "随机播放"))
            .accessibilityLabel(tr("Shuffle", "随机播放"))
            .accessibilityValue(playback.queue.shuffle ? tr("On", "开启") : tr("Off", "关闭"))

            // Advanced Queue: create a group (flag on only), auto-named "Group N";
            // renaming happens through an inline alert (text field) on the group row.
            if advancedQueue {
                Button {
                    let n = playback.queue.groups.count + 1
                    playback.queue.addGroup(tr("Group \(n)", "分组 \(n)", zhHant: "分組 \(n)"))
                    groupsExpanded = true
                } label: {
                    Image(systemName: "plus")
                        .font(MusesTypography.body.weight(.semibold))
                        .chromeActionCircle()
                }
                .foregroundStyle(BrandColors.textSecondary)
                .buttonStyle(.fullAreaPlain)
                .help(tr("Add group", "新建分组"))
                .accessibilityLabel(tr("Add group", "新建分组"))
            }

            ChromeIconButton(
                systemName: "xmark",
                help: tr("Close", "关闭"),
                accessibility: tr("Close queue", "关闭队列")
            ) { isPresented = false }
            .overlay {
                if focusedTarget == .drawer {
                    Capsule().stroke(BrandColors.textPrimary.opacity(0.7), lineWidth: 1.5)
                        .allowsHitTesting(false)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 12)
    }

    private var list: some View {
        List {
            nowPlayingSection
            upNextSection
            recommendationSection
            collectionSection
            groupsSection
            historySection
        }
        .listStyle(.plain)
        .listRowSeparator(.visible)
        .scrollContentBackground(.hidden)
        .background(.clear)
        .environment(\.defaultMinListRowHeight, 44)
        .alert(tr("Rename group", "重命名分组"), isPresented: Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } })) {
            TextField(tr("Group name", "分组名"), text: $renameText)
            Button(tr("Rename", "重命名")) {
                let name = renameText.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty, let id = renameTarget {
                    playback.queue.renameGroup(id: id, to: name)
                }
                renameTarget = nil
            }
            Button(tr("Cancel", "取消"), role: .cancel) { renameTarget = nil }
        }
    }

    private var nowPlayingSection: some View {
        Section(tr("Now Playing", "正在播放")) {
            if let item = playback.queue.current() {
                QueueRow(item: item, isCurrent: true)
                    .queueRowActions(title: item.track.title) {
                        if playback.queue.insertedCurrent?.id == item.id {
                            itemContextMenu(for: item, inUpNext: false, isCurrentRow: true)
                        } else {
                            TrackContextMenuItems(snapshot: item.track, onPlay: { playback.toggle() },
                                queueItemID: item.id,
                                videoContext: playback.queue.items.map(\.track) + playback.queue.upNext.map(\.track),
                                videoSource: item.fromContext)
                        }
                    }
                    .focusable()
                    .onKeyPress(.return) {
                        guard playback.isPrimaryActionAvailable else { return .ignored }
                        playback.toggle()
                        return .handled
                    }
                    .accessibilityActions {
                        if playback.isPrimaryActionAvailable {
                            Button(tr("Play or pause", "播放或暂停")) { playback.toggle() }
                        }
                    }
            } else {
                queueEmptyRow(tr("Choose a song to start listening", "选择歌曲开始收听"))
            }
        }
    }

    private var upNextSection: some View {
        Section {
            if upNextExpanded {
                ForEach(playback.queue.upNext) { item in
                    QueueRow(item: item, isCurrent: false, showHistoryBadge: advancedQueue)
                        .queueRowActions(title: item.track.title) { itemContextMenu(for: item, inUpNext: true) }
                        .onTapGesture(count: 2) { playQueueItem(item) }
                        .focusable()
                        .onKeyPress(.return) { playQueueItem(item); return .handled }
                        .accessibilityAction(named: Text(tr("Play", "播放"))) { playQueueItem(item) }
                }
                .onMove { indices, destination in
                    guard let from = indices.first else { return }
                    playback.queue.moveUpNext(from: from,
                                              to: destination > from ? destination - 1 : destination)
                }
                if playback.queue.upNext.isEmpty {
                    queueEmptyRow(tr("Choose Play Next from any track menu", "在曲目菜单中选择「下一首播放」"))
                }
            }
        } header: {
            sectionHeading(tr("Up Next", "下一首"), count: playback.queue.upNext.count,
                           expanded: $upNextExpanded)
        }
    }

    private var collectionSection: some View {
        Section {
            if collectionExpanded {
                ForEach(visibleQueueItems) { item in
                    QueueRow(item: item,
                             isCurrent: playback.queue.current()?.id == item.id,
                             showHistoryBadge: advancedQueue)
                        .queueRowActions(title: item.track.title) { itemContextMenu(for: item, inUpNext: false) }
                        .onTapGesture(count: 2) { playQueueItem(item) }
                        .focusable()
                        .onKeyPress(.return) { playQueueItem(item); return .handled }
                        .accessibilityAction(named: Text(tr("Play", "播放"))) { playQueueItem(item) }
                }
                .onMove { indices, destination in
                    guard playback.queue.groups.allSatisfy({ !$0.collapsed }) else { return }
                    guard let from = indices.first else { return }
                    playback.queue.move(from: from,
                                        to: destination > from ? destination - 1 : destination)
                }
                if visibleQueueItems.isEmpty {
                    queueEmptyRow(tr("No collection queued", "尚无当前集合"))
                }
            }
        } header: {
            sectionHeading(tr("Current Collection", "当前集合"), count: playback.queue.items.count,
                           expanded: $collectionExpanded)
        }
    }

    @ViewBuilder
    private var groupsSection: some View {
        // Advanced Queue: group management (collapse / rename / delete).
        if advancedQueue, !playback.queue.groups.isEmpty {
            Section {
                if groupsExpanded {
                    ForEach(playback.queue.groups) { group in
                        HStack {
                            Button {
                                playback.queue.toggleCollapsed(groupId: group.id)
                            } label: {
                                Image(systemName: group.collapsed ? "chevron.right" : "chevron.down")
                                    .font(MusesTypography.caption2)
                                    .foregroundStyle(BrandColors.textSecondary)
                                    .frame(width: 28, height: 28)
                            }
                            .buttonStyle(.fullAreaPlain)
                            .help(group.collapsed ? tr("Expand group", "展开分组")
                                                  : tr("Collapse group", "折叠分组"))
                            .accessibilityLabel(group.collapsed
                                ? tr("Expand \(group.name)", "展开 \(group.name)", zhHant: "展開 \(group.name)")
                                : tr("Collapse \(group.name)", "折叠 \(group.name)", zhHant: "折疊 \(group.name)"))
                            Text(group.name).foregroundStyle(BrandColors.textPrimary).lineLimit(1)
                            Spacer()
                            Text("\(itemsInGroup(group.id))")
                                .font(MusesTypography.caption2).foregroundStyle(BrandColors.textSecondary)
                        }
                        .queueRowActions(title: group.name) { groupActions(group) }
                    }
                }
            } header: {
                sectionHeading(tr("Groups", "分组"), count: playback.queue.groups.count,
                               expanded: $groupsExpanded)
            }
        }
    }

    @ViewBuilder private func groupActions(_ group: QueueGroup) -> some View {
        Button(tr("Move group up", "上移分组"), systemImage: "arrow.up") { moveGroup(group, by: -1) }
            .disabled(!canMoveGroup(group, by: -1))
        Button(tr("Move group down", "下移分组"), systemImage: "arrow.down") { moveGroup(group, by: 1) }
            .disabled(!canMoveGroup(group, by: 1))
        Divider()

        Button(tr("Rename", "重命名")) {
            renameTarget = group.id
            renameText = group.name
        }
        Button(tr("Delete group", "删除分组"), role: .destructive) {
            pendingRemoval = ActionConfirmation(
                title: tr("Delete group?", "删除分组？"),
                message: tr("Remove \(group.name). Its songs remain in the queue.", "删除「\(group.name)」，歌曲仍保留在队列中。"),
                action: { playback.queue.removeGroup(id: group.id) }
            )
        }

    }

    private func canMoveGroup(_ group: QueueGroup, by offset: Int) -> Bool {
        guard let index = playback.queue.groups.firstIndex(where: { $0.id == group.id }) else { return false }
        return playback.queue.groups.indices.contains(index + offset)
    }

    private func moveGroup(_ group: QueueGroup, by offset: Int) {
        guard canMoveGroup(group, by: offset),
              let index = playback.queue.groups.firstIndex(where: { $0.id == group.id }) else { return }
        playback.queue.moveGroup(from: index, to: index + offset)
    }

    private var historySection: some View {
        Section {
            if historyExpanded {
                ForEach(playback.queue.history, id: \.historyRecordID) { item in
                    QueueRow(item: item, isCurrent: false, showHistoryBadge: advancedQueue)
                        .queueRowActions(title: item.track.title) {
                            TrackContextMenuItems(
                                snapshot: item.track,
                                onPlay: {
                                    playback.playTrack(
                                        item.track,
                                        context: [item.track],
                                        from: item.fromContext
                                    )
                                }, queueItemID: item.id, allowsCurrentPlaybackAction: false,
                                videoContext: [item.track], videoSource: item.fromContext
                            )
                            if advancedQueue {
                                Divider()
                                Button(tr("Restore to queue", "还原到队列")) {
                                    guard let id = item.historyRecordID else { return }
                                    playback.queue.restoreHistoryRecord(id: id)
                                }
                                Button(tr("Remove from history", "从历史移除"), role: .destructive) {
                                    pendingRemoval = ActionConfirmation(
                                        title: tr("Remove history item?", "移除历史记录？"),
                                        message: tr("Remove \(item.track.title) from queue history. Playlists are unchanged.", "从队列历史中移除「\(item.track.title)」，歌单不受影响。"),
                                        actionTitle: tr("Remove", "移除"),
                                        action: {
                                            guard let id = item.historyRecordID else { return }
                                            playback.queue.removeHistoryRecord(id: id)
                                        }
                                    )
                                }
                            }
                        }
                }
                if playback.queue.history.isEmpty {
                    queueEmptyRow(tr("Played songs will appear here", "播放过的歌曲会显示在这里"))
                }
            }
        } header: {
            sectionHeading(tr("History", "历史记录"), count: playback.queue.history.count,
                           expanded: $historyExpanded)
        }
    }

    @ViewBuilder
    private var recommendationSection: some View {
        if let recommendation = playback.queue.smartShuffle.pending {
            Section(tr("YouTube Music recommendation", "YouTube Music 推荐", zhHant: "YouTube Music 推薦")) {
                QueueRow(item: recommendation, isCurrent: false, showHistoryBadge: false)
                    .queueRowActions(title: recommendation.track.title) {
                        Button(tr("Play Next", "下一首播放", zhHant: "下一首播放")) {
                            playback.queue.playNext(recommendation.track)
                        }
                    }
            }
        }
    }

    private func sectionHeading(_ title: String, count: Int, expanded: Binding<Bool>) -> some View {
        Button { expanded.wrappedValue.toggle() } label: {
            HStack(spacing: 8) {
                Image(systemName: expanded.wrappedValue ? "chevron.down" : "chevron.right")
                    .font(MusesTypography.caption2.weight(.semibold))
                Text(title).font(MusesTypography.callout.weight(.semibold))
                Spacer(minLength: 4)
                Text("\(count)").font(MusesTypography.caption.monospacedDigit())
            }
            .foregroundStyle(BrandColors.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(title)
        .accessibilityValue(tr("\(count) items, \(expanded.wrappedValue ? "expanded" : "collapsed")",
                              "\(count) 项，\(expanded.wrappedValue ? "已展开" : "已收起")"))
    }

    private func queueEmptyRow(_ message: String) -> some View {
        Text(message)
            .font(MusesTypography.caption)
            .foregroundStyle(BrandColors.textSecondary)
            .padding(.vertical, 8)
    }

    /// Hide members of collapsed groups, except the currently playing row.
    private var visibleQueueItems: [QueueItem] {
        let collapsed = Set(playback.queue.groups.filter(\.collapsed).map(\.id))
        guard !collapsed.isEmpty else { return playback.queue.items }
        let currentID = playback.queue.current()?.id
        return playback.queue.items.filter { item in
            guard let gid = item.groupId, collapsed.contains(gid) else { return true }
            return item.id == currentID
        }
    }

    /// Number of entries in items + upNext that belong to a given group.
    private func itemsInGroup(_ id: QueueGroup.ID) -> Int {
        playback.queue.items.filter { $0.groupId == id }.count
        + playback.queue.upNext.filter { $0.groupId == id }.count
    }

    /// Queue rows always expose useful track actions. Advanced Queue adds the
    /// lock and grouping operations without turning the basic menu into an empty shell.
    @ViewBuilder
    private func itemContextMenu(for item: QueueItem, inUpNext: Bool,
                                 isCurrentRow: Bool = false) -> some View {
        TrackContextMenuItems(
            snapshot: item.track,
            onPlay: { playQueueItem(item) },
            queueItemID: item.id,
            videoContext: playback.queue.items.map(\.track) + playback.queue.upNext.map(\.track),
            videoSource: item.fromContext,
            showsPlayNext: isCurrentRow,
            showsAddToQueue: isCurrentRow
        )
        Divider()
        Button(tr("Move Up", "上移"), systemImage: "arrow.up") {
            moveQueueItem(item, by: -1, inUpNext: inUpNext)
        }
        .disabled(!canMoveQueueItem(item, by: -1, inUpNext: inUpNext))
        Button(tr("Move Down", "下移"), systemImage: "arrow.down") {
            moveQueueItem(item, by: 1, inUpNext: inUpNext)
        }
        .disabled(!canMoveQueueItem(item, by: 1, inUpNext: inUpNext))
        if advancedQueue {
            Divider()
            Button(item.locked ? tr("Unlock", "解锁") : tr("Lock", "锁定")) {
                playback.queue.toggleLocked(itemId: item.id)
            }
            if !playback.queue.groups.isEmpty {
                Menu(tr("Move to group", "移入分组")) {
                    Button(tr("None", "无")) { setGroupId(item: item, to: nil) }
                    ForEach(playback.queue.groups) { g in
                        Button(g.name) { setGroupId(item: item, to: g.id) }
                    }
                }
            }
        }
        if canRemove(item: item, inUpNext: inUpNext) {
            Divider()
            Button(tr("Remove", "移除"), role: .destructive) {
                pendingRemoval = ActionConfirmation(
                    title: tr("Remove from queue?", "从队列移除？"),
                    message: tr("Remove \(item.track.title) from the queue. Playlists are unchanged.", "从队列移除「\(item.track.title)」，歌单不受影响。"),
                    actionTitle: tr("Remove", "移除"),
                    action: {
                        guard canRemove(item: item, inUpNext: inUpNext) else { return }
                        if inUpNext, let idx = playback.queue.upNext.firstIndex(where: { $0.id == item.id }) {
                            playback.queue.removeUpNext(at: idx)
                        } else if !inUpNext, let idx = playback.queue.items.firstIndex(where: { $0.id == item.id }) {
                            playback.queue.removeItem(at: idx)
                        }
                    }
                )
            }
        }
    }

    private func canMoveQueueItem(_ item: QueueItem, by offset: Int, inUpNext: Bool) -> Bool {
        let items = inUpNext ? playback.queue.upNext : playback.queue.items
        guard inUpNext || playback.queue.groups.allSatisfy({ !$0.collapsed }),
              let index = items.firstIndex(where: { $0.id == item.id }) else { return false }
        return items.indices.contains(index + offset)
    }

    private func moveQueueItem(_ item: QueueItem, by offset: Int, inUpNext: Bool) {
        guard canMoveQueueItem(item, by: offset, inUpNext: inUpNext) else { return }
        let items = inUpNext ? playback.queue.upNext : playback.queue.items
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        if inUpNext { playback.queue.moveUpNext(from: index, to: index + offset) }
        else { playback.queue.move(from: index, to: index + offset) }
    }

    private func playQueueItem(_ item: QueueItem) {
        playback.playQueueItem(id: item.id)
    }

    private func canRemove(item: QueueItem, inUpNext: Bool) -> Bool {
        if inUpNext { return true }
        guard let index = playback.queue.items.firstIndex(where: { $0.id == item.id }) else {
            return false
        }
        return index != playback.queue.currentIndex
    }

    /// Resolve the occurrence and target group again when the menu action executes.
    private func setGroupId(item: QueueItem, to gid: UUID?) {
        playback.queue.setGroupId(itemId: item.id, to: gid)
    }
}

private struct QueueRow: View {
    @Environment(YouTubeImportService.self) private var importService
    let item: QueueItem
    let isCurrent: Bool
    var showHistoryBadge: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            ArtworkView(source: ArtworkSource.resolve(for: item.track), cornerRadius: 5,
                        glyphSize: 16, targetSize: 36)
                .overlay(alignment: .bottomTrailing) {
                    if isCurrent || (showHistoryBadge && item.historyState != nil) {
                        Image(systemName: leadingIcon)
                            .font(MusesTypography.system(size: 9, weight: .semibold))
                            .foregroundStyle(leadingTint)
                            .padding(3)
                            .background(BrandColors.surface, in: Circle())
                    }
                }
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.track.title)
                    .font(MusesTypography.system(size: 13, weight: isCurrent ? .semibold : .regular))
                    .foregroundStyle(isCurrent ? BrandColors.accent : BrandColors.textPrimary)
                    .lineLimit(1)
                Text(SongCreditCache.shared.artist(snapshot: item.track))
                    .font(MusesTypography.caption)
                    .foregroundStyle(BrandColors.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            if item.locked {
                Image(systemName: "lock.fill")
                    .font(MusesTypography.caption2)
                    .foregroundStyle(BrandColors.textSecondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .background {
            if isCurrent {
                RoundedRectangle(cornerRadius: 8)
                    .fill(BrandColors.textPrimary.opacity(0.08))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(item.track.title + ", " + SongCreditCache.shared.artist(snapshot: item.track))
        .accessibilityValue([isCurrent ? tr("Now Playing", "正在播放") : nil,
                             item.locked ? tr("Locked", "已锁定") : nil,
                             showHistoryBadge ? historyLabel : nil]
            .compactMap { $0 }.joined(separator: ", "))
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
        .task(id: item.track.youTubeId) { _ = await importService.songMetadata(videoID: item.track.youTubeId) }
    }

    private var historyLabel: String? {
        switch item.historyState {
        case .played: tr("Played", "已播放")
        case .skipped: tr("Skipped", "已跳过")
        case .removed: tr("Removed", "已移除")
        case nil: nil
        }
    }

    /// Current playback uses play.fill; history entries get an icon from their state label; otherwise music.note.
    private var leadingIcon: String {
        if isCurrent { return "play.fill" }
        if showHistoryBadge, let s = item.historyState {
            switch s {
            case .played: return "checkmark.circle"
            case .skipped: return "forward.end.fill"
            case .removed: return "trash"
            }
        }
        return "music.note"
    }
    private var leadingTint: Color {
        if isCurrent { return BrandColors.accent }
        if showHistoryBadge, let s = item.historyState {
            switch s {
            case .played: return BrandColors.textSecondary
            case .skipped: return BrandColors.textSecondary
            case .removed: return BrandColors.textSecondary
            }
        }
        return BrandColors.textSecondary
    }


}

private extension View {
    /// Pointer menus and visible actions expose the same complete track operations.
    func queueRowActions<Actions: View>(title: String, @ViewBuilder _ actions: @escaping () -> Actions) -> some View {
        HStack(spacing: 6) {
            self.contextMenu(menuItems: actions)
                .frame(maxWidth: .infinity, alignment: .leading)
            Menu(content: actions) {
                Image(systemName: "ellipsis")
                    .font(MusesTypography.system(size: 13, weight: .semibold))
                    .foregroundStyle(BrandColors.textSecondary)
                    .frame(width: 28, height: 28)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(tr("Options for \(title)", "\(title) 的选项"))
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden)
            .frame(width: 28, height: 28)
            .help(tr("Options for \(title)", "\(title) 的选项"))
            .accessibilityLabel(tr("Options for \(title)", "\(title) 的选项"))
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
        .listRowBackground(Color.clear)
    }
}
