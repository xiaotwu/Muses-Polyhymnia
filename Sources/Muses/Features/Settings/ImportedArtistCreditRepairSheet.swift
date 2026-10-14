import SwiftUI
import SwiftData

/// A user-specified incorrect credit is the authorization boundary. The preview
/// never treats an arbitrary difference from an imported item as corruption.
struct ImportedArtistCreditRepairSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(LibraryService.self) private var library
    @Environment(\.dismiss) private var dismiss
    @State private var incorrectArtist = ""
    @State private var preview: ImportedArtistCreditPreview?
    @State private var includingUnresolved = false
    @State private var receipt: ImportedArtistCreditRepairReceipt?
    @State private var error: String?
    @State private var notice: String?
    @State private var busy = false
    @State private var confirmUndo = false

    private var selectedCount: Int {
        preview?.selectedRows(includingUnresolved: includingUnresolved).count ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(tr("Repair imported artist credits", "修复旧导入署名"))
                    .font(MusesTypography.headline)
                Spacer()
                Button(tr("Done", "完成")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .disabled(busy)
            }
            Text(tr("Enter a credit you know is incorrect, such as a former playlist owner. Only exact matches are reviewed. Other artist edits are preserved.",
                    "请输入你已确认错误的署名，例如原歌单持有人。只核对完全匹配的曲目，保留其他艺术家编辑。"))
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                TextField(tr("Exact incorrect credit", "完整错误署名"), text: $incorrectArtist)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { readPreview() }
                Button(tr("Preview", "预览")) { readPreview() }
                    .disabled(busy || incorrectArtist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if busy { ProgressView().controlSize(.small) }
            if let error {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red).font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let notice {
                Text(notice).font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let preview {
                Text(tr("\(preview.rows.count) exact matches · \(selectedCount) selected",
                        "\(preview.rows.count) 个完全匹配 · 已选择 \(selectedCount) 个"))
                    .font(.callout)
                Table(preview.rows) {
                    TableColumn(tr("Track", "曲目")) { row in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(row.title).lineLimit(2)
                            Text(row.videoID).font(.caption.monospaced()).foregroundStyle(.secondary)
                        }
                    }.width(min: 150, ideal: 230)
                    TableColumn(tr("Current credit", "现有署名")) { row in
                        Text(row.before).lineLimit(2)
                    }.width(min: 120, ideal: 160)
                    TableColumn(tr("Replacement", "修复后")) { row in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(row.after.isEmpty ? tr("Artist unavailable", "艺人信息暂缺") : row.after)
                                .lineLimit(2)
                            Text(basisLabel(row.basis)).font(.caption).foregroundStyle(.secondary)
                        }
                    }.width(min: 150, ideal: 210)
                }
                .frame(minHeight: 180, maxHeight: .infinity)
                Toggle(tr("Include unresolved tracks: clear the incorrect credit and show Artist unavailable",
                          "包含未解析曲目：清空错误署名并显示“艺人信息暂缺”"), isOn: $includingUnresolved)
                    .disabled(busy)
                    .font(.callout)
                Text(tr("Source credits come from the imported video item and may name its publisher. They are not verified performers. Missing or conflicting sources are skipped unless included above.",
                        "来源署名取自导入的视频条目，可能是发布者，并不代表已核实的音乐艺人。来源缺失或冲突默认跳过，除非勾选上面的选项。"))
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ContentUnavailableView(tr("Review before applying", "应用前先核对"), systemImage: "checklist",
                    description: Text(tr("The preview does not change your library.", "预览不会修改资料库。")))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Divider()
            if let receipt {
                if receipt.state == .prepared || receipt.state == .undoPrepared {
                    Label(tr("Unfinished record · \(receipt.changes.count) artist fields may already have been saved. Recovery checks this batch before restoring its previous credits.",
                             "未完成的记录 · \(receipt.changes.count) 项署名可能已经保存。恢复会先核对本批状态，再恢复原署名。"),
                          systemImage: "exclamationmark.triangle")
                        .font(.callout).foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                } else if receipt.state == .applied {
                    Text(tr("Last repair · \(receipt.changes.count) artist fields saved · recovery available",
                            "上次修复 · 已保存 \(receipt.changes.count) 项署名 · 可撤销"))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 12) {
                if let receipt, receipt.state != .undone {
                    Button(receipt.state == .applied ? tr("Undo last repair…", "撤销上次修复…") : tr("Review unfinished repair…", "恢复未完成的修复…")) {
                        confirmUndo = true
                    }
                    .disabled(busy)
                }
                Spacer()
                Button(tr("Apply · \(selectedCount)", "应用 · \(selectedCount)")) { apply() }
                    .settingsAction(prominent: true)
                    .disabled(busy || selectedCount == 0 || receipt?.state == .prepared || receipt?.state == .undoPrepared)
            }
        }
        .padding(20)
        .frame(minWidth: 680, idealWidth: 820, minHeight: 520, idealHeight: 640)
        .onChange(of: incorrectArtist) {
            preview = nil
            includingUnresolved = false
            notice = nil
        }
        .task { loadReceipt() }
        .confirmationDialog(tr("Restore credits changed by the last repair?", "恢复上次修复改动的署名？"),
                            isPresented: $confirmUndo, titleVisibility: .visible) {
            Button(tr("Restore previous credits", "恢复原署名")) { undo() }
            Button(tr("Cancel", "取消"), role: .cancel) {}
        } message: {
            Text(tr("The batch may already be saved. Recovery checks its current state: an uncommitted batch only closes its record; a committed batch restores only its recorded artist fields. Later artist edits or changed video identities stop the operation. Other library data is retained.",
                    "本批署名可能已经保存。恢复会核对现状：未提交的批次只结束记录；已提交的批次只恢复记录中的艺术家字段。后续署名编辑或视频身份变化会使操作停止，其他资料库数据均保留。"))
        }
    }

    private func basisLabel(_ basis: ImportedArtistCreditPreview.Basis) -> String {
        switch basis {
        case .verifiedArtist: tr("Verified artist metadata", "已核实的艺人元数据")
        case .sourceCredit: tr("Imported source credit", "来源署名")
        case .unresolved: tr("Unresolved · skipped by default", "未解析 · 默认跳过")
        }
    }

    private func loadReceipt() {
        do { receipt = try ImportedArtistCreditRepair.latestReceipt(in: modelContext.container) }
        catch { self.error = error.localizedDescription }
    }

    private func readPreview() {
        guard !busy else { return }
        error = nil
        notice = nil
        do {
            preview = try ImportedArtistCreditRepair.preview(incorrectArtist: incorrectArtist, in: modelContext.container)
            includingUnresolved = false
            loadReceipt()
        } catch { self.error = error.localizedDescription }
    }

    private func apply() {
        guard let preview, !busy else { return }
        busy = true
        error = nil
        defer { busy = false; loadReceipt() }
        do {
            receipt = try ImportedArtistCreditRepair.apply(preview, includingUnresolved: includingUnresolved,
                                                           to: modelContext.container,
                                                           onCommit: { library.artistCreditRepairDidCommit() })
            self.preview = nil
            notice = tr("Artist credits repaired. A recovery record was saved; playlist sources and history were retained.",
                        "署名已修复并保存恢复记录，歌单来源与历史已保留。")
        } catch { self.error = error.localizedDescription }
    }

    private func undo() {
        guard let receipt, !busy else { return }
        busy = true
        error = nil
        defer { busy = false; loadReceipt() }
        do {
            self.receipt = try ImportedArtistCreditRepair.undo(receipt, in: modelContext.container,
                                                              onCommit: { library.artistCreditRepairDidCommit() })
            preview = nil
            notice = tr("Recorded artist credits restored. Other library data was retained.", "已恢复记录中的原署名，其他资料库数据已保留。")
        } catch { self.error = error.localizedDescription }
    }
}
