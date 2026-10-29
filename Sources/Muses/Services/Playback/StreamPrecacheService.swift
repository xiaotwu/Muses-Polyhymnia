import Foundation
import SwiftData

/// Opt-in idle downloads. It never changes the queue, history, or playback state,
/// and never evicts previously played files to make room for predictions.
/// The shared media budget also governs ordinary paused-playback downloads.
@Observable
@MainActor
final class StreamPrecacheService {
    enum Scope: String, CaseIterable { case favorites, recent, both }
    private let defaults: UserDefaults
    private let resolution: any ResolvedStreamProvider
    private let session: URLSession
    private let directory: URL
    private let cacheBudget: MediaCacheBudget
    private let candidates: (Scope) -> [TrackSnapshot]
    private let isBusy: () -> Bool
    @ObservationIgnored private var work: Task<Void, Never>?
    private var resource: SharedStreamResource?
    @ObservationIgnored private var publicationGate: MediaCachePublicationGate?
    private var generation = UUID()
    var completedCount = 0
    private var preparationStatus = PreparationStatus.off

    var status: String { preparationStatus.localizedDescription }

    private enum PreparationStatus {
        case off, waitingForIdle, budgetReached
        case preparing(title: String)
        case finished(downloaded: Int)

        var localizedDescription: String {
            switch self {
            case .off: tr("Off", "已关闭")
            case .waitingForIdle: tr("Waiting for idle playback", "等待播放空闲")
            case .budgetReached: tr("Cache budget reached", "已达到缓存容量限制")
            case .preparing(let title): tr("Preparing \(title)", "正在准备 \(title)")
            case .finished(let count): tr("Preparation finished: \(count) downloaded", "预下载已结束：新增 \(count) 首")
            }
        }
    }

    init(resolution: any ResolvedStreamProvider, defaults: UserDefaults = .standard,
         candidates: @escaping (Scope) -> [TrackSnapshot], isBusy: @escaping () -> Bool,
         session: URLSession? = nil, directory: URL = MediaFileCache.directory,
         cacheBudget: MediaCacheBudget = .shared) {
        self.resolution = resolution
        self.session = MediaFileCache.ephemeralSession(copying: session)
        self.directory = directory
        self.defaults = defaults
        self.cacheBudget = cacheBudget
        self.candidates = candidates
        self.isBusy = isBusy
    }

    isolated deinit {
        work?.cancel()
        publicationGate?.close()
        session.invalidateAndCancel()
    }

    func pauseForPlayback() {
        generation = UUID()
        publicationGate?.close()
        publicationGate = nil
        work?.cancel()
        work = nil
        if let resource { Task { await resource.cancel() } }
        resource = nil
        if defaults.bool(forKey: PrefKey.streamPrecacheEnabled) { preparationStatus = .waitingForIdle }
    }

    func configure() {
        pauseForPlayback()
        completedCount = 0
        let enabled = defaults.bool(forKey: PrefKey.streamPrecacheEnabled)
        if !enabled { preparationStatus = .off }
        let generation = generation
        let scope = Scope(rawValue: defaults.string(forKey: PrefKey.streamPrecacheScope) ?? "favorites") ?? .favorites
        let quality = defaults.string(forKey: PrefKey.ytAudioQuality) ?? "bestaudio"
        let budget = Self.budgetBytes(defaults.integer(forKey: PrefKey.streamPrecacheLimitGB))
        work = Task { @MainActor [weak self] in
            guard let self else { return }
            let directory = directory, cacheBudget = cacheBudget
            // Maintenance is independent of prediction consent. Protected decoder
            // files survive a smaller limit; no further cache is admitted meanwhile.
            _ = await Task.detached(priority: .utility) { try? cacheBudget.maintain(in: directory) }.value
            guard enabled, !Task.isCancelled, self.generation == generation else { return }
            // Downloads remain enabled across launches, but wait while playback
            // is active. No high-frequency playback clock is observed.
            while isBusy() {
                do { try await Task.sleep(for: .seconds(3)) } catch { return }
                guard !Task.isCancelled, self.generation == generation else { return }
            }
            guard MediaFileCache.isSafeDirectory(directory, allowMissing: true) else { return }
            let rows = candidates(scope)
            var seen = Set<String>()
            for track in rows where seen.insert(track.youTubeId).inserted {
                guard !Task.isCancelled, self.generation == generation, !isBusy() else { return }
                guard !track.youTubeId.isEmpty, MediaFileCache.existing(videoId: track.youTubeId, quality: quality, in: directory) == nil else { continue }
                let directory = directory
                let used = await Task.detached(priority: .utility) { MediaFileCache.totalBytes(in: directory) }.value
                guard !Task.isCancelled, self.generation == generation, !isBusy() else { return }
                guard used < budget else { preparationStatus = .budgetReached; return }
                preparationStatus = .preparing(title: track.title)
                var ownedResource: SharedStreamResource?
                do {
                    let stream = try await YTDlpRequestPriority.$interactive.withValue(false) {
                        try await resolution.resolveStream(videoID: track.youTubeId, quality: quality)
                    }
                    try Task.checkCancellation()
                    guard !isBusy(), self.generation == generation else { return }
                    guard let ext = MediaFileCache.cacheExtension(for: stream),
                          MediaFileCache.validKey(videoID: track.youTubeId, quality: quality) else { continue }
                    let destination = MediaFileCache.file(videoId: track.youTubeId, quality: quality, ext: ext, in: directory)
                    let gate = MediaCachePublicationGate()
                    publicationGate = gate
                    let resource = try SharedStreamResource(stream: stream, destination: destination, session: session,
                        publicationGate: gate, cacheBudget: cacheBudget, mayEvictCache: false)
                    ownedResource = resource
                    self.resource = resource
                    let info = try await resource.information()
                    try Task.checkCancellation()
                    guard self.generation == generation, !isBusy() else {
                        await resource.cancel()
                        return
                    }
                    guard Self.fits(size: info.size, used: used, budget: budget) else {
                        await resource.cancel(); self.resource = nil
                        continue
                    }
                    _ = try await resource.finish { [weak self] in
                        await MainActor.run {
                            guard let self else { return false }
                            return self.generation == generation && !self.isBusy() &&
                                self.defaults.bool(forKey: PrefKey.streamPrecacheEnabled)
                        }
                    }
                    await resource.cancel()
                    guard !Task.isCancelled, self.generation == generation else { return }
                    self.resource = nil
                    self.publicationGate = nil
                    completedCount += 1
                } catch {
                    await ownedResource?.cancel()
                    if Task.isCancelled || self.generation != generation { return }
                    self.resource = nil
                    self.publicationGate = nil
                }
            }
            if self.generation == generation { preparationStatus = .finished(downloaded: completedCount) }
        }
    }

    func awaitWorkForTests() async { await work?.value }

    static func budgetBytes(_ gigabytes: Int) -> Int64 { MediaCacheBudget.bytes(forGigabytes: gigabytes) }
    static func fits(size: Int64, used: Int64, budget: Int64) -> Bool {
        size > 0 && used >= 0 && used <= budget && size <= budget - used
    }

    static func snapshots(container: ModelContainer, scope: Scope) -> [TrackSnapshot] {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<Track>(sortBy: [SortDescriptor(\.playCount, order: .reverse)])
        switch scope {
        case .favorites: descriptor.predicate = #Predicate { $0.liked == true }
        case .recent: descriptor.predicate = #Predicate { $0.lastPlayedAt != nil }
        case .both: descriptor.predicate = #Predicate { $0.liked == true || $0.lastPlayedAt != nil }
        }
        descriptor.fetchLimit = 200
        return ((try? context.fetch(descriptor)) ?? []).map { TrackSnapshot(from: $0) }
    }
}
