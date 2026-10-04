import SwiftUI
import SwiftData

/// Review direct evidence before an explicitly confirmed, recoverable migration.
struct CatalogIdentityReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(YouTubeCatalogService.self) private var catalog
    @State private var preview: CatalogIdentityPreview?
    @State private var failed = false
    @State private var loading = false
    @State private var query = ""
    @State private var showConfirmed = false
    @State private var showEvidenceList = false
    @State private var selectedID: UUID?
    @State private var candidateCount = 0
    @State private var unresolvedCount = 0
    @State private var resolvedCount = 0
    @State private var receipt: CatalogMigrationReceipt?
    @State private var migrationAvailable = false
    @State private var migrationError: String?
    @State private var migrationNotice: String?
    @State private var confirmMigration = false
    @State private var undoRequested = false

    private var visibleRows: [CatalogIdentityPreview.Row] {
        guard let preview else { return [] }
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return preview.rows.filter { row in
            (showConfirmed ? row.resolution == .alreadyResolved : row.resolution != .alreadyResolved)
            && (text.isEmpty || row.title.localizedStandardContains(text) || row.id.uuidString.localizedStandardContains(text))
        }
    }

    var body: some View {
        GeometryReader { geometry in
            // Keep the native table usable when the header and controls exceed a compact pane.
            // The footer remains outside this scroll view so confirmation is always reachable.
            if geometry.size.height < 400 {
                ScrollView {
                    reviewContent(compact: true, availableWidth: geometry.size.width - 40)
                }
            } else {
                reviewContent(compact: false, availableWidth: geometry.size.width - 40)
            }
        }
        .safeAreaInset(edge: .bottom) {
            reviewFooter
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task { await refresh() }
        .confirmationDialog(
            undoRequested
                ? tr("Roll back the last identity migration?", "回滚上次身份迁移？", zhHant: "回復上次身分移轉？")
                : tr("Apply release relationships (\(candidateCount))?", "应用 \(candidateCount) 条发行关系？", zhHant: "套用 \(candidateCount) 條發行關係？"),
            isPresented: $confirmMigration, titleVisibility: .visible
        ) {
            Button(undoRequested ? tr("Roll Back", "回滚", zhHant: "回復") : tr("Apply", "应用", zhHant: "套用")) {
                Task { await performMigration() }
            }
            Button(tr("Cancel", "取消", zhHant: "取消"), role: .cancel) {}
        } message: {
            Text(undoRequested
                 ? tr("Only identities changed by this migration are restored. Later likes, notes and history are retained. Conflicting identities stop the operation.", "只恢复本次迁移改动的身份，保留之后的收藏、笔记和历史。身份冲突时停止操作。", zhHant: "只復原本次移轉變更的身分，保留之後的喜愛項目、筆記和歷史。身分衝突時停止操作。")
                 : tr("An independent recovery snapshot is saved first. Every direct source-backed relationship in this preview is applied, including those hidden by search. Unsupported or indirect candidates stay unresolved.", "先保存独立恢复快照，再应用本预览中全部有直接来源证据的关系，包括搜索隐藏的条目。不受支持或间接候选保持未解析。", zhHant: "先儲存獨立復原快照，再套用本預覽中全部有直接來源證據的關係，包括搜尋隱藏的項目。不受支援或間接候選保持未解析。"))
        }
    }

    private func reviewContent(compact: Bool, availableWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if preview != nil {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { summaryTiles }
                    VStack(spacing: 8) { summaryTiles }
                }
            }
            HStack(spacing: 8) {
                TextField(tr("Find a track", "查找曲目", zhHant: "尋找曲目"), text: $query)
                    .textFieldStyle(.roundedBorder)
                SettingsIconButton(title: tr("Refresh preview", "刷新预览", zhHant: "重新整理預覽"), symbol: "arrow.clockwise") {
                    Task { await refresh() }
                }.disabled(loading)
            }
            HStack {
                Picker(tr("Review status", "核对状态"), selection: $showConfirmed) {
                    Text(tr("Pending", "待处理")).tag(false)
                    Text(tr("Confirmed", "已确认")).tag(true)
                }.pickerStyle(.segmented)
                Picker(tr("Evidence layout", "证据布局"), selection: $showEvidenceList) {
                    Text(tr("Table", "表格")).tag(false)
                    Text(tr("Problems", "问题列表")).tag(true)
                }.pickerStyle(.menu).frame(maxWidth: 140)
            }
            migrationControls
            if loading {
                ProgressView(tr("Reading library…", "正在读取资料库…", zhHant: "正在讀取資料庫…"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if failed {
                ContentUnavailableView {
                    Label(tr("Unable to read library", "无法读取资料库", zhHant: "無法讀取資料庫"), systemImage: "exclamationmark.triangle")
                } description: {
                    Text(tr("No changes were made. Refresh to try again.", "未做任何修改。请刷新重试。", zhHant: "未做任何修改。請重新整理再試。"))
                }
            } else if preview != nil {
                if visibleRows.isEmpty {
                    ContentUnavailableView(tr("No tracks to review", "没有可核对的曲目", zhHant: "沒有可核對的曲目"), systemImage: "music.note.list")
                } else if !showEvidenceList {
                    GeometryReader { geometry in
                        if geometry.size.width > 640 {
                            HStack(spacing: 16) {
                                evidenceTable
                                evidencePreview.frame(width: 250)
                            }
                        } else {
                            VStack(spacing: 12) {
                                evidenceTable
                                    .frame(minHeight: compact ? 220 : nil)
                                evidencePreview.frame(maxHeight: 200)
                            }
                        }
                    }
                    .frame(height: compact ? (availableWidth > 640 ? 260 : 432) : nil)
                } else {
                    List {
                        ForEach(["arrow.down.circle", "exclamationmark.triangle", "questionmark.circle", "checkmark.circle"], id: \.self) { symbol in
                            let rows = visibleRows.filter { $0.resolution.reviewSymbol == symbol }
                            if !rows.isEmpty {
                                Section {
                                    ForEach(rows) { row in
                        DisclosureGroup {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(row.id.uuidString).font(MusesTypography.caption.monospaced()).textSelection(.enabled)
                                ForEach(row.currentReleaseIDs, id: \.self) { current in
                                    LabeledContent(
                                        tr("Current release", "现有发行", zhHant: "現有發行"),
                                        value: current)
                                }
                                if row.evidence.isEmpty {
                                    Text(tr("No direct album membership evidence. Names and upload channels are not used to infer identity.",
                                            "缺少直接专辑归属证据。不会按名称或上传频道推断身份。",
                                            zhHant: "缺少直接專輯歸屬證據。不會按名稱或上傳頻道推斷身分。"))
                                        .foregroundStyle(.secondary)
                                }
                                ForEach(row.evidence, id: \.itemID) { evidence in
                                    VStack(alignment: .leading, spacing: 4) {
                                        if let url = YouTubeCatalogLink.releaseURL(stableID: evidence.releaseID) {
                                            Link(evidence.releaseID, destination: url)
                                        } else {
                                            Text(evidence.releaseID)
                                        }
                                        Text(tr("Playlist position: \(evidence.order + 1)", "歌单位置：\(evidence.order + 1)", zhHant: "歌單位置：\(evidence.order + 1)"))
                                        Text(evidence.itemID.uuidString).font(MusesTypography.caption.monospaced()).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .font(MusesTypography.callout).padding(.vertical, 8)
                        } label: {
                            HStack(spacing: 12) {
                                Text(row.title).lineLimit(2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                SettingsStatus(title: row.resolution.reviewLabel,
                                               symbol: row.resolution.reviewSymbol)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                        }
                        .disclosureGroupStyle(CatalogReviewDisclosureStyle())
                                    }
                                } header: { Text(rows.first?.resolution.reviewLabel ?? "") }
                            }
                        }
                    }
                    .listStyle(.inset)
                    .scrollContentBackground(.hidden)
                    .background(.background, in: RoundedRectangle(cornerRadius: 12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .frame(height: compact ? 260 : nil)
                }
            }
        }
        .padding(20)
    }

    private var reviewFooter: some View {
        HStack(spacing: 12) {
            Text(tr("Verified relationships · \(candidateCount)", "已核实关系 · \(candidateCount)"))
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
            applyButton
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(.background)
    }

    private var evidenceTable: some View {
        Table(visibleRows, selection: $selectedID) {
            TableColumn(tr("Track", "曲目")) { row in
                Text(row.title).lineLimit(2)
            }.width(min: 140, ideal: 220)
            TableColumn(tr("Confidence", "可信状态")) { row in
                Label(row.resolution.reviewLabel, systemImage: row.resolution.reviewSymbol)
                    .font(.caption)
            }.width(min: 100, ideal: 140)
            TableColumn(tr("Evidence", "证据")) { row in
                Text(row.evidence.count.formatted()).monospacedDigit()
                    .accessibilityLabel(tr("\(row.evidence.count) direct evidence items", "\(row.evidence.count) 条直接证据"))
            }.width(70)
        }
        .onChange(of: showConfirmed) { _, _ in selectedID = nil }
        .onChange(of: query) { _, _ in
            if !visibleRows.contains(where: { $0.id == selectedID }) { selectedID = nil }
        }
    }

    private var evidencePreview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let row = visibleRows.first(where: { $0.id == selectedID }) {
                    Text(row.title).font(.headline).fixedSize(horizontal: false, vertical: true)
                    SettingsStatus(title: row.resolution.reviewLabel, symbol: row.resolution.reviewSymbol)
                    DisclosureGroup(tr("Current relationships", "现有关系")) {
                        ForEach(row.currentReleaseIDs, id: \.self) { Text($0).font(.caption.monospaced()).textSelection(.enabled) }
                        if row.currentReleaseIDs.isEmpty { Text(tr("None", "无")) }
                    }
                    DisclosureGroup(tr("Direct source evidence", "直接来源证据")) {
                        ForEach(row.evidence, id: \.itemID) { evidence in
                            VStack(alignment: .leading, spacing: 4) {
                                if let url = YouTubeCatalogLink.releaseURL(stableID: evidence.releaseID) {
                                    Link(evidence.releaseID, destination: url)
                                } else { Text(evidence.releaseID) }
                                Text(tr("Playlist position: \(evidence.order + 1)", "歌单位置：\(evidence.order + 1)"))
                            }.font(.caption).textSelection(.enabled).padding(.vertical, 4)
                        }
                        if row.evidence.isEmpty {
                            Text(tr("Names and upload channels do not establish album identity. Direct source evidence is required.", "名称与上传频道不构成专辑身份，需要直接来源证据。"))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Text(row.id.uuidString).font(.caption.monospaced()).textSelection(.enabled).foregroundStyle(.secondary)
                } else {
                    ContentUnavailableView(tr("Select a track", "选择曲目"), systemImage: "checklist",
                                           description: Text(tr("Inspect the current relationships and direct evidence before applying.", "应用前检查现有关系及直接证据。")))
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder private var summaryTiles: some View {
        reviewStat(tr("Relationships to apply", "可应用关系"), value: candidateCount)
        reviewStat(tr("Tracks to review", "待核对曲目"), value: unresolvedCount)
        reviewStat(tr("Linked tracks", "已关联曲目"), value: resolvedCount)
    }

    private func reviewStat(_ title: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value.formatted())
                .font(MusesTypography.heading(value.formatted(), size: 26))
                .foregroundStyle(BrandColors.heading)
            Text(title).font(MusesTypography.callout).foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
    }

    private var applyButton: some View {
        Button(tr("Apply · \(candidateCount)", "应用 · \(candidateCount)")) {
            undoRequested = false
            confirmMigration = true
        }
        .settingsAction(prominent: true)
        .disabled(loading || !migrationAvailable || candidateCount == 0 || receipt?.state == .prepared || receipt?.state == .rollingBack)
        .help(tr("Applies every verified relationship, including tracks hidden by search.",
                 "应用全部已核实关系，包括搜索隐藏的曲目。"))
    }

    private var migrationControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let receipt {
                DisclosureGroup(tr("Recovery", "恢复")) {
                    HStack(spacing: 8) {
                        Spacer()
                        if receipt.state != .rolledBack {
                            Button(tr("Roll back…", "回滚…")) {
                                undoRequested = true
                                confirmMigration = true
                            }
                            .settingsAction()
                            .disabled(loading || !migrationAvailable)
                        }
                        SettingsIconButton(title: tr("Show recovery snapshot", "显示恢复快照", zhHant: "顯示復原快照"), symbol: "folder") {
                            NSWorkspace.shared.activateFileViewerSelecting([receipt.snapshot])
                        }
                    }
                }
            }
            if receipt?.state == .prepared || receipt?.state == .rollingBack {
                Label(tr("Operation unfinished. Review recovery before continuing.", "操作未完成，请先查看恢复记录。"), systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            }
            if let migrationError {
                Label(migrationError, systemImage: "exclamationmark.triangle").foregroundStyle(.red)
            }
            if let migrationNotice { Text(migrationNotice).foregroundStyle(.secondary) }
        }
        .font(MusesTypography.callout)
    }

    private func performMigration() async {
        guard !loading else { return }
        loading = true
        migrationError = nil
        migrationNotice = nil
        await Task.yield()
        do {
            if undoRequested, let receipt {
                self.receipt = try CatalogIdentityMigration.rollback(receipt, in: modelContext.container)
                migrationNotice = tr("Identity changes rolled back. Later user data was retained.", "身份改动已回滚，后续用户数据已保留。", zhHant: "身分變更已回復，後續使用者資料已保留。")
            } else if let preview {
                receipt = try CatalogIdentityMigration.apply(preview, to: modelContext.container)
                migrationNotice = tr("Identity changes applied and verified. Recovery snapshot saved.", "身份改动已应用并核对，恢复快照已保存。", zhHant: "身分變更已套用並核對，復原快照已儲存。")
            }
            catalog.rebuildFromTrackMetadata()
        } catch { migrationError = error.localizedDescription }
        loading = false
        await refresh()
    }

    private func refresh() async {
        guard !loading else { return }
        loading = true
        failed = false
        await Task.yield()
        guard !Task.isCancelled else { loading = false; return }
        do {
            let result = try CatalogIdentityPreview.read(from: modelContext.container)
            preview = result
            candidateCount = result.rows.reduce(into: 0) { count, row in
                if case .proposed(let releases) = row.resolution {
                    count += releases.count
                }
            }
            unresolvedCount = result.rows.filter {
                switch $0.resolution {
                case .ambiguous, .unresolved: true
                default: false
                }
            }.count
            resolvedCount = result.rows.filter { $0.resolution == .alreadyResolved }.count
            migrationAvailable = (try? CatalogIdentityMigration.storeURL(modelContext.container)) != nil
            if migrationAvailable {
                do { receipt = try CatalogIdentityMigration.latestReceipt(in: modelContext.container) }
                catch { migrationAvailable = false; migrationError = error.localizedDescription }
            }
        }
        catch { preview = nil; failed = true }
        loading = false
    }
}

/// Keep the complete visible row keyboard- and pointer-accessible.
private struct CatalogReviewDisclosureStyle: DisclosureGroupStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                configuration.isExpanded.toggle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: configuration.isExpanded ? "chevron.down" : "chevron.right")
                        .font(MusesTypography.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 12)
                    configuration.label
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.fullAreaPlain)
            .accessibilityValue(configuration.isExpanded
                                ? tr("Expanded", "已展开") : tr("Collapsed", "已收起"))
            if configuration.isExpanded {
                configuration.content.padding(.leading, 20)
            }
        }
    }
}

extension CatalogIdentityPreview.Resolution {
    var reviewSymbol: String {
        switch self {
        case .alreadyResolved: "checkmark.circle"
        case .proposed: "arrow.down.circle"
        case .ambiguous: "exclamationmark.triangle"
        case .unresolved: "questionmark.circle"
        }
    }

    var reviewLabel: String {
        switch self {
        case .alreadyResolved:
            tr("Linked", "已关联", zhHant: "已關聯")
        case .proposed:
            tr("Verified · pending", "已核实 · 待应用", zhHant: "已核實 · 待套用")
        case .ambiguous:
            tr("Needs review", "待核对", zhHant: "待核對")
        case .unresolved:
            tr("Needs evidence", "缺少证据", zhHant: "缺少證據")
        }
    }
}
