import AVFoundation
import Foundation
import UniformTypeIdentifiers

/// One sparse file and one request per byte range serve AVPlayer, focus warmup,
/// and the full-cache download. Only a verified complete file is published.
actor SharedStreamResource {
    struct Metadata: Sendable { let size: Int64; let mime: String }
    struct Chunk: Sendable { let data: Data; let metadata: Metadata }
    static let chunkSize: Int64 = 262_144
    static let maximumSize: Int64 = 512 * 1_048_576
    private var source: URL
    private let renew: (@Sendable () async throws -> ResolvedAudioStream)?
    private var renewal: Task<ResolvedAudioStream, Error>?
    private var requestHeaders: [String: String]
    private let typedIdentity: ResolvedAudioStream?
    private let publicationGate: MediaCachePublicationGate
    private let destination: URL
    private let staging: URL
    private let session: URLSession
    private var metadata: Metadata?
    private var completed: Set<Int64> = []
    private struct Request { let id: UUID; let task: Task<Chunk, Error> }
    private var requests: [Int64: Request] = [:]
    private var cancelled = false
    private var published = false
    private var handle: FileHandle?

    init(source: URL, destination: URL, session: URLSession,
         renew: (@Sendable () async throws -> URL)? = nil) {
        self.source = source
        if let renew { self.renew = { @Sendable in ResolvedAudioStream(url: try await renew()) } }
        else { self.renew = nil }
        self.requestHeaders = [:]
        self.typedIdentity = nil
        self.publicationGate = MediaCachePublicationGate()
        self.destination = destination
        self.session = MediaFileCache.ephemeralSession(copying: session)
        staging = destination.deletingLastPathComponent().appendingPathComponent(".\(UUID().uuidString).partial")
    }

    /// The public full-cache route preserves request headers and selected representation identity.
    init(stream: ResolvedAudioStream, destination: URL, session: URLSession? = nil,
         publicationGate: MediaCachePublicationGate = MediaCachePublicationGate(),
         renewStream: (@Sendable () async throws -> ResolvedAudioStream)? = nil) throws {
        guard let ext = MediaFileCache.cacheExtension(for: stream), destination.pathExtension.lowercased() == ext,
              MediaFileCache.isSafeDestination(destination, in: destination.deletingLastPathComponent()) else {
            throw URLError(.unsupportedURL)
        }
        self.source = stream.url
        self.requestHeaders = stream.requestHeaders
        self.typedIdentity = stream
        self.publicationGate = publicationGate
        self.renew = renewStream
        self.destination = destination
        self.session = MediaFileCache.ephemeralSession(copying: session)
        staging = destination.deletingLastPathComponent().appendingPathComponent(".\(UUID().uuidString).partial")
    }

    deinit {
        session.invalidateAndCancel()
        try? handle?.close()
        // Do not follow a root that has since become a symlink during cleanup.
        if MediaFileCache.isSafeDestination(staging, in: staging.deletingLastPathComponent()) {
            try? FileManager.default.removeItem(at: staging)
        }
    }

    func information() async throws -> Metadata {
        try checkActive()
        if let metadata { return metadata }
        return try await chunk(at: 0).metadata
    }

    /// The tail can contain the MP4 index required before the first audio frame.
    func warm() async throws {
        let info = try await information()
        let tail = ((info.size - 1) / Self.chunkSize) * Self.chunkSize
        if tail > 0 { _ = try await chunk(at: tail) }
    }

    func read(at offset: Int64, length: Int) async throws -> Data {
        let info = try await information()
        guard offset >= 0, offset <= info.size, length >= 0 else { throw URLError(.badServerResponse) }
        let count = min(Int64(length), info.size - offset, Self.chunkSize - offset % Self.chunkSize)
        guard count > 0 else { return Data() }
        _ = try await chunk(at: offset / Self.chunkSize * Self.chunkSize)
        try checkActive()
        guard let handle else { throw URLError(.cannotOpenFile) }
        try handle.seek(toOffset: UInt64(offset))
        let data = try handle.read(upToCount: Int(count)) ?? Data()
        guard data.count == Int(count) else { throw URLError(.cannotDecodeRawData) }
        return data
    }

    func finish(shouldContinue: (@Sendable () async -> Bool)? = nil) async throws -> URL {
        let info = try await information()
        var offset: Int64 = 0
        while offset < info.size {
            if let shouldContinue, !(await shouldContinue()) { throw CancellationError() }
            _ = try await chunk(at: offset)
            offset += Self.chunkSize
        }
        if let shouldContinue, !(await shouldContinue()) { throw CancellationError() }
        try checkActive()
        if !published {
            try handle?.synchronize()
            try publicationGate.whileOpen {
                try Task.checkCancellation()
                let root = destination.deletingLastPathComponent()
                guard MediaFileCache.isSafeDestination(destination, in: root),
                      MediaFileCache.isSafeDestination(staging, in: root) else { throw URLError(.noPermissionsToReadFile) }
                if !FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.moveItem(at: staging, to: destination)
                } else {
                    // A concurrent complete writer wins. Never replace or delete an existing user-owned file.
                    guard let size = try? destination.resourceValues(forKeys: [.fileSizeKey]).fileSize,
                          Int64(size) == info.size else { throw URLError(.cannotWriteToFile) }
                    try? FileManager.default.removeItem(at: staging)
                }
                published = true
            }
        }
        return destination
    }

    func cancel() {
        cancelled = true
        publicationGate.close()
        renewal?.cancel()
        for request in requests.values { request.task.cancel() }
        requests.removeAll()
        try? handle?.close()
        handle = nil
        if !published, MediaFileCache.isSafeDestination(staging, in: staging.deletingLastPathComponent()) {
            try? FileManager.default.removeItem(at: staging)
        }
    }

    private func checkActive() throws {
        try Task.checkCancellation()
        if cancelled || !publicationGate.isOpen { throw CancellationError() }
        guard ["https", "http"].contains(source.scheme ?? ""), source.user == nil, source.password == nil else {
            throw URLError(.unsupportedURL)
        }
    }

    private func chunk(at offset: Int64) async throws -> Chunk {
        try checkActive()
        if completed.contains(offset), let metadata, let handle {
            try handle.seek(toOffset: UInt64(offset))
            let data = try handle.read(upToCount: Int(min(Self.chunkSize, metadata.size - offset))) ?? Data()
            return Chunk(data: data, metadata: metadata)
        }
        let requestedSource = source
        let task: Task<Chunk, Error>
        let requestID: UUID
        if let existing = requests[offset] { task = existing.task; requestID = existing.id }
        else {
            requestID = UUID()
            let source = source, session = session, headers = requestHeaders
            task = Task {
                var request = URLRequest(url: source)
                request.timeoutInterval = 8
                request.cachePolicy = .reloadIgnoringLocalCacheData
                request.httpShouldHandleCookies = false
                for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }
                request.setValue("bytes=\(offset)-\(offset + Self.chunkSize - 1)", forHTTPHeaderField: "Range")
                let (data, response) = try await session.data(for: request)
                try Task.checkCancellation()
                guard let http = response as? HTTPURLResponse,
                      http.statusCode == 206,
                      let raw = http.value(forHTTPHeaderField: "Content-Range"),
                      let size = Self.validatedSize(range: raw, offset: offset, received: data.count) else {
                    if let http = response as? HTTPURLResponse, http.statusCode == 403 { throw URLError(.userAuthenticationRequired) }
                    throw URLError(.badServerResponse)
                }
                return Chunk(data: data, metadata: Metadata(size: size, mime: http.mimeType ?? "audio/mp4"))
            }
            requests[offset] = Request(id: requestID, task: task)
        }
        do {
            let result = try await task.value
            try checkActive()
            guard metadata == nil || metadata?.size == result.metadata.size,
                  typedIdentity?.contentLength == nil || typedIdentity?.contentLength == result.metadata.size else {
                throw URLError(.badServerResponse)
            }
            if handle == nil {
                let root = staging.deletingLastPathComponent()
                guard MediaFileCache.isSafeDestination(staging, in: root) else { throw URLError(.noPermissionsToReadFile) }
                try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true,
                                                       attributes: [.posixPermissions: 0o700])
                guard MediaFileCache.isSafeDestination(staging, in: root) else { throw URLError(.noPermissionsToReadFile) }
                guard FileManager.default.createFile(atPath: staging.path, contents: nil, attributes: [.posixPermissions: 0o600]) else { throw URLError(.cannotCreateFile) }
                handle = try FileHandle(forUpdating: staging)
            }
            if !completed.contains(offset) {
                try handle?.seek(toOffset: UInt64(offset))
                try handle?.write(contentsOf: result.data)
                completed.insert(offset)
            }
            metadata = result.metadata
            if requests[offset]?.id == requestID { requests.removeValue(forKey: offset) }
            return result
        } catch {
            if requests[offset]?.id == requestID { requests.removeValue(forKey: offset) }
            try checkActive()
            if (error as? URLError)?.code == .userAuthenticationRequired, let renew {
                if source != requestedSource { return try await chunk(at: offset) }
                if renewal == nil { renewal = Task { try await renew() } }
                guard let renewal else { throw error }
                let refreshed = try await renewal.value
                try checkActive()
                // One refreshed address per resource. Repeated rejection must
                // fail instead of creating an unbounded retry recursion.
                guard refreshed.url != source else { throw error }
                if let identity = typedIdentity {
                    guard MediaFileCache.cacheExtension(for: refreshed) == destination.pathExtension.lowercased(),
                          refreshed.contextID == identity.contextID, refreshed.formatID == identity.formatID,
                          refreshed.codec == identity.codec, refreshed.container == identity.container else { throw error }
                }
                source = refreshed.url
                requestHeaders = refreshed.requestHeaders
                return try await chunk(at: offset)
            }
            throw error
        }
    }

    static func validatedSize(range: String, offset: Int64, received: Int) -> Int64? {
        guard range.hasPrefix("bytes ") else { return nil }
        let parts = range.dropFirst(6).split(separator: "/")
        guard parts.count == 2, let total = Int64(parts[1]), total > 0, total <= maximumSize else { return nil }
        let endpoints = parts[0].split(separator: "-")
        guard endpoints.count == 2, let start = Int64(endpoints[0]), let end = Int64(endpoints[1]),
              start == offset, end == min(offset + chunkSize - 1, total - 1),
              start <= end, end - start + 1 == received else { return nil }
        return total
    }
}

/// Delegate and AVFoundation requests are confined to a dedicated serial queue.
/// Network and file operations stay in the resource actor, away from MainActor.
final class SharedStreamLoader: NSObject, AVAssetResourceLoaderDelegate, @unchecked Sendable {
    let queue = DispatchQueue(label: "com.muses.stream-resource")
    private let resource: SharedStreamResource
    private var tasks: [ObjectIdentifier: Task<Void, Never>] = [:]
    init(resource: SharedStreamResource) { self.resource = resource }

    func asset() -> AVURLAsset {
        let asset = AVURLAsset(url: URL(string: "muses-stream://audio/\(UUID().uuidString).m4a")!)
        asset.resourceLoader.setDelegate(self, queue: queue)
        return asset
    }

    func resourceLoader(_ resourceLoader: AVAssetResourceLoader,
                        shouldWaitForLoadingOfRequestedResource request: AVAssetResourceLoadingRequest) -> Bool {
        let box = RequestBox(request)
        let id = ObjectIdentifier(request)
        tasks[id] = Task { [resource, weak self] in
            do {
                let info = try await resource.information()
                guard !Task.isCancelled, let self else { return }
                let requested = await self.configure(box, metadata: info)
                if let requested {
                    var offset = requested.offset
                    let end = min(info.size, requested.end)
                    while offset < end {
                        try Task.checkCancellation()
                        let bytes = try await resource.read(at: offset, length: Int(min(end - offset, SharedStreamResource.chunkSize)))
                        guard !bytes.isEmpty else { throw URLError(.cannotDecodeRawData) }
                        try Task.checkCancellation()
                        await self.respond(box, data: bytes)
                        offset += Int64(bytes.count)
                    }
                }
                await self.finish(box, error: nil)
            } catch {
                guard let self else { return }
                await self.finish(box, error: error)
            }
        }
        return true
    }

    func resourceLoader(_ resourceLoader: AVAssetResourceLoader, didCancel request: AVAssetResourceLoadingRequest) {
        tasks.removeValue(forKey: ObjectIdentifier(request))?.cancel()
    }
    func stop() {
        queue.async { [self] in
            for task in tasks.values { task.cancel() }
            tasks.removeAll()
        }
    }
    private struct Read: Sendable { let offset: Int64; let end: Int64 }
    private final class RequestBox: @unchecked Sendable {
        let request: AVAssetResourceLoadingRequest
        init(_ request: AVAssetResourceLoadingRequest) { self.request = request }
    }
    private func configure(_ box: RequestBox, metadata: SharedStreamResource.Metadata) async -> Read? {
        await withCheckedContinuation { continuation in
            queue.async {
                let request = box.request
                if let info = request.contentInformationRequest {
                    info.contentType = UTType(mimeType: metadata.mime)?.identifier ?? UTType.mpeg4Audio.identifier
                    info.contentLength = metadata.size
                    info.isByteRangeAccessSupported = true
                }
                guard let data = request.dataRequest else { continuation.resume(returning: nil); return }
                let offset = max(data.requestedOffset, data.currentOffset)
                let end = data.requestsAllDataToEndOfResource ? metadata.size
                    : data.requestedOffset + Int64(data.requestedLength)
                continuation.resume(returning: Read(offset: offset, end: end))
            }
        }
    }
    private func respond(_ box: RequestBox, data: Data) async {
        await withCheckedContinuation { continuation in
            queue.async {
                if !box.request.isCancelled { box.request.dataRequest?.respond(with: data) }
                continuation.resume()
            }
        }
    }
    private func finish(_ box: RequestBox, error: Error?) async {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                tasks.removeValue(forKey: ObjectIdentifier(box.request))
                if !box.request.isCancelled {
                    if let error { box.request.finishLoading(with: error) }
                    else { box.request.finishLoading() }
                }
                continuation.resume()
            }
        }
    }
}
