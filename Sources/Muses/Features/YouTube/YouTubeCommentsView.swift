import SwiftUI

/// Volatile, read-only comment browsing on the official video surface.
struct YouTubeCommentsView: View {
    let videoID: String
    let onClose: () -> Void
    @Environment(YouTubeAccountService.self) private var account
    @State private var browser = YouTubeCommentBrowser()

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(tr("Comments", "评论", zhHant: "留言"))
                    .font(MusesTypography.title2.weight(.semibold))
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(MusesTypography.body.weight(.semibold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.fullAreaPlain)
                .accessibilityLabel(tr("Close comments", "关闭评论", zhHant: "關閉留言"))
                .help(tr("Close comments", "关闭评论", zhHant: "關閉留言"))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if !account.isConnected {
                        ContentUnavailableView(
                            tr("Connect YouTube", "连接 YouTube", zhHant: "連接 YouTube"),
                            systemImage: "person.crop.circle",
                            description: Text(tr("Connect your account to read comments here.",
                                                 "连接账号后即可在这里阅读评论。",
                                                 zhHant: "連接帳號後即可在這裡閱讀留言。")))
                    } else {
                        if let errorMessage = browser.errorMessage {
                            HStack {
                                Text(errorMessage).font(MusesTypography.callout)
                                Button(tr("Retry", "重试", zhHant: "重試")) {
                                    browser.retry()
                                }
                            }
                        }
                        if let selectedThread = browser.selectedThread {
                            Button(tr("Close replies", "收起回复", zhHant: "收起回覆")) {
                                browser.closeReplies()
                            }
                            Text(selectedThread.topLevelComment.text).font(MusesTypography.body)
                            Divider()
                            ForEach(browser.replies) { reply in commentRow(reply) }
                            if browser.nextReplyToken != nil {
                                Button(tr("Load more replies", "加载更多回复", zhHant: "載入更多回覆")) {
                                    browser.loadMoreReplies()
                                }.disabled(browser.loading)
                            }
                        } else {
                            ForEach(browser.threads) { thread in
                                VStack(alignment: .leading, spacing: 5) {
                                    commentRow(thread.topLevelComment)
                                    if thread.totalReplyCount > 0 {
                                        Button(tr("View replies", "查看回复", zhHant: "查看回覆")
                                               + " (\(thread.totalReplyCount))") {
                                            browser.selectReplies(thread)
                                        }.font(MusesTypography.caption)
                                    }
                                }
                                Divider()
                            }
                            if browser.nextToken != nil {
                                Button(tr("Load more comments", "加载更多评论", zhHant: "載入更多留言")) {
                                    browser.loadMoreThreads()
                                }.disabled(browser.loading)
                            }
                            if browser.threads.isEmpty && !browser.loading && browser.errorMessage == nil {
                                Text(tr("No comments available.", "暂无可用评论。", zhHant: "暫無可用留言。"))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if browser.loading { ProgressView().controlSize(.small) }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
        }
        .task(id: videoID + "|" + (account.activeChannelID ?? "") + "|\(account.isConnected)") {
            browser.reset(videoID: videoID, client: account.dataAPIClient())
        }
        .onDisappear { browser.cancel() }
    }

    private func commentRow(_ comment: YouTubeComment) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(comment.author).font(MusesTypography.subheadline.weight(.semibold))
            Text(comment.text).font(MusesTypography.body).textSelection(.enabled)
            if let publishedAt = comment.publishedAt {
                Text(publishedAt, format: .dateTime.year().month().day())
                    .font(MusesTypography.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
