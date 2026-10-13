import Foundation

/// New-tab account content comes only from the connected YouTube Data API snapshot.
@MainActor
enum YouTubePersonalDiscovery {
    static func likedSection(videos: [YouTubeVideo], accountChannelID: String) -> HomeSection? {
        guard !videos.isEmpty, !accountChannelID.isEmpty else { return nil }
        let items = videos.prefix(20).map {
            DiscoveryItem.youTube(YouTubeDiscoveryCard(
                id: $0.id,
                title: $0.title,
                uploader: $0.channelTitle,
                thumbnailURL: $0.thumbnailURL))
        }
        return HomeSection(
            id: "yt-liked",
            title: tr("Liked on YouTube", "YouTube 喜欢"),
            subtitle: tr("From your account", "来自你的账号"),
            kind: .youTubeCarousel,
            items: Array(items),
            status: .loaded,
            source: .officialAccount,
            accountChannelID: accountChannelID)
    }

    static func sections(
        liked: [YouTubeVideo],
        accountChannelID: String
    ) -> [HomeSection] {
        likedSection(videos: liked, accountChannelID: accountChannelID).map { [$0] } ?? []
    }
}
