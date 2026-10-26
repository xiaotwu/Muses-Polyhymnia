import Foundation
import Darwin

/// App-owned complete media only. Signed URLs, headers and account context never enter this directory.
enum MediaFileCache {
    static let mediaExtensions = Set(["m4a", "mp4", "webm", "opus", "ogg", "mp3", "aac", "flac", "wav"])

    static var directory: URL {
        let dir = MusesDataPaths.caches.appendingPathComponent("streams", isDirectory: true)
        if isSafeDirectory(dir, allowMissing: true) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true,
                                                     attributes: [.posixPermissions: 0o700])
        }
        return dir
    }

    static func sanitizedQuality(_ quality: String) -> String {
        quality.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: " ", with: "_")
    }

    static func validKey(videoID: String, quality: String) -> Bool {
        func component(_ value: String) -> Bool {
            !value.isEmpty && value.utf8.count <= 160 && value.utf8.allSatisfy {
                (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 || $0 == 95
            }
        }
        return component(videoID) && component(sanitizedQuality(quality))
    }

    static func file(videoId: String, quality: String, ext: String, in root: URL? = nil) -> URL {
        let root = root ?? directory
        guard validKey(videoID: videoId, quality: quality), mediaExtensions.contains(ext.lowercased()) else {
            return root.appendingPathComponent(".invalid-cache-key")
        }
        return root.appendingPathComponent("\(videoId)__\(sanitizedQuality(quality)).\(ext.lowercased())")
    }

    /// Legacy files are accepted only as completed regular media entries; partials and sidecars never match.
    static func existing(videoId: String, quality: String, in root: URL? = nil) -> URL? {
        let root = root ?? directory
        guard validKey(videoID: videoId, quality: quality), isSafeDirectory(root, allowMissing: false) else { return nil }
        for ext in mediaExtensions.sorted() {
            let url = file(videoId: videoId, quality: quality, ext: ext, in: root)
            if isCompletedFile(url, in: root) { return url }
        }
        return nil
    }

    struct Fingerprint: Equatable, Sendable {
        let device: Int64
        let inode: UInt64
        let size: Int64
        let modifiedSeconds: Int64
        let modifiedNanoseconds: Int64
        let changedSeconds: Int64
        let changedNanoseconds: Int64

        fileprivate init(_ info: stat) {
            device = Int64(info.st_dev)
            inode = UInt64(info.st_ino)
            size = Int64(info.st_size)
            modifiedSeconds = Int64(info.st_mtimespec.tv_sec)
            modifiedNanoseconds = Int64(info.st_mtimespec.tv_nsec)
            changedSeconds = Int64(info.st_ctimespec.tv_sec)
            changedNanoseconds = Int64(info.st_ctimespec.tv_nsec)
        }

        // A rename may update ctime; inode, size and content modification time must still match.
        fileprivate func matchesMoved(_ other: Fingerprint) -> Bool {
            device == other.device && inode == other.inode && size == other.size &&
                modifiedSeconds == other.modifiedSeconds && modifiedNanoseconds == other.modifiedNanoseconds
        }
    }

    struct CompletedEntry: Equatable, Sendable {
        let url: URL
        let videoID: String
        let quality: String
        let fingerprint: Fingerprint
    }

    static func completedEntry(videoID: String, quality: String, in root: URL) -> CompletedEntry? {
        guard let url = existing(videoId: videoID, quality: quality, in: root),
              let identity = fingerprint(url, in: root) else { return nil }
        return CompletedEntry(url: url, videoID: videoID, quality: quality, fingerprint: identity)
    }

    static func matches(_ entry: CompletedEntry, in root: URL) -> Bool {
        fingerprint(entry.url, in: root) == entry.fingerprint
    }

    private static func fingerprint(_ url: URL, in root: URL) -> Fingerprint? {
        guard isCompletedFile(url, in: root) else { return nil }
        let descriptor = Darwin.open(url.path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        guard descriptor >= 0 else { return nil }
        defer { Darwin.close(descriptor) }
        var info = stat()
        guard Darwin.fstat(descriptor, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG,
              info.st_size > 4096 else { return nil }
        return Fingerprint(info)
    }

    /// Recoverably retire one decoder-rejected file identity. Never overwrite a concurrent replacement.
    /// The directory descriptor confines both rename endpoints to the verified root; RENAME_EXCL
    /// protects the unique quarantine destination and any attempted rollback.
    static func quarantine(_ entry: CompletedEntry, in root: URL) -> URL? {
        guard isSafeDirectory(root, allowMissing: false), matches(entry, in: root),
              file(videoId: entry.videoID, quality: entry.quality, ext: entry.url.pathExtension, in: root)
                .standardizedFileURL.path == entry.url.standardizedFileURL.path else { return nil }
        let directoryFD = Darwin.open(root.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard directoryFD >= 0 else { return nil }
        defer { Darwin.close(directoryFD) }
        var directoryInfo = stat()
        var pathInfo = stat()
        guard Darwin.fstat(directoryFD, &directoryInfo) == 0, Darwin.lstat(root.path, &pathInfo) == 0,
              directoryInfo.st_dev == pathInfo.st_dev, directoryInfo.st_ino == pathInfo.st_ino,
              (pathInfo.st_mode & S_IFMT) == S_IFDIR else { return nil }
        let sourceName = entry.url.lastPathComponent
        let named = ".\(sourceName).\(UUID().uuidString).quarantine"
        let quarantineName = named.utf8.count <= 255 ? named : ".rejected-\(UUID().uuidString).quarantine"
        var before = stat()
        guard Darwin.fstatat(directoryFD, sourceName, &before, AT_SYMLINK_NOFOLLOW) == 0,
              (before.st_mode & S_IFMT) == S_IFREG, Fingerprint(before) == entry.fingerprint else { return nil }
        guard Darwin.renameatx_np(directoryFD, sourceName, directoryFD, quarantineName, UInt32(RENAME_EXCL)) == 0 else {
            return nil
        }
        var moved = stat()
        guard Darwin.fstatat(directoryFD, quarantineName, &moved, AT_SYMLINK_NOFOLLOW) == 0,
              (moved.st_mode & S_IFMT) == S_IFREG, entry.fingerprint.matchesMoved(Fingerprint(moved)) else {
            // An external replacement raced the rename. Restore only into an empty source name;
            // if another replacement already exists, retain all bytes without overwriting it.
            _ = Darwin.renameatx_np(directoryFD, quarantineName, directoryFD, sourceName, UInt32(RENAME_EXCL))
            return nil
        }
        return root.appendingPathComponent(quarantineName)
    }

    static func isCompletedFile(_ url: URL, in root: URL) -> Bool {
        guard isSafeDestination(url, in: root), mediaExtensions.contains(url.pathExtension.lowercased()),
              let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]),
              values.isRegularFile == true, values.isSymbolicLink != true,
              let size = values.fileSize, size > 4096,
              url.standardizedFileURL.resolvingSymlinksInPath().path == canonicalSystemPath(url).path else { return false }
        return true
    }

    /// Reject a symlink anywhere below the system's /var and /tmp aliases, including the cache root itself.
    static func isSafeDirectory(_ root: URL, allowMissing: Bool) -> Bool {
        guard root.isFileURL else { return false }
        let canonical = canonicalSystemPath(root)
        guard canonical.resolvingSymlinksInPath().path == canonical.path else { return false }
        if let values = try? root.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]) {
            return values.isDirectory == true && values.isSymbolicLink != true
        }
        return allowMissing && !FileManager.default.fileExists(atPath: root.path)
    }

    static func isSafeDestination(_ url: URL, in root: URL) -> Bool {
        guard url.isFileURL, isSafeDirectory(root, allowMissing: true),
              canonicalSystemPath(url.deletingLastPathComponent()).path == canonicalSystemPath(root).path,
              canonicalSystemPath(url).resolvingSymlinksInPath().path == canonicalSystemPath(url).path else { return false }
        if let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey]) {
            return values.isSymbolicLink != true && values.isRegularFile == true
        }
        return !FileManager.default.fileExists(atPath: url.path)
    }

    private static func canonicalSystemPath(_ url: URL) -> URL {
        let standardized = url.standardizedFileURL
        let path = standardized.path
        if path.hasPrefix("/var/") || path.hasPrefix("/tmp/") {
            return URL(fileURLWithPath: "/private" + path, isDirectory: url.hasDirectoryPath).standardizedFileURL
        }
        return standardized
    }

    /// Only public direct representations are persistable. HLS is a manifest, not a complete media file.
    static func cacheExtension(for stream: ResolvedAudioStream) -> String? {
        guard isPublicContext(stream.contextID), validRemoteStream(stream),
              [nil, "http", "https"].contains(stream.protocolName) else { return nil }
        let ext = stream.container?.lowercased() ?? stream.url.pathExtension.lowercased()
        return mediaExtensions.contains(ext) ? ext : nil
    }

    static func isPublicContext(_ context: String) -> Bool { context == "public" || context.hasPrefix("public-") }

    static func validRemoteStream(_ stream: ResolvedAudioStream) -> Bool {
        guard ["https", "http"].contains(stream.url.scheme?.lowercased() ?? ""), stream.url.host != nil,
              stream.url.user == nil, stream.url.password == nil, !stream.isExpired(),
              stream.requestHeaders.count <= 32 else { return false }
        let allowed = Set(["user-agent", "referer", "origin", "accept", "accept-language", "accept-encoding"])
        return stream.requestHeaders.allSatisfy { name, value in
            allowed.contains(name.lowercased()) && value.utf8.count <= 8192 &&
            !value.unicodeScalars.contains { $0.value < 32 || $0.value == 127 }
        }
    }

    /// Rebuild injected sessions from an ephemeral configuration; retain only test URLProtocol registration.
    static func ephemeralSession(copying session: URLSession? = nil) -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        if let session { config.protocolClasses = session.configuration.protocolClasses }
        config.httpShouldSetCookies = false
        config.httpCookieAcceptPolicy = .never
        config.httpCookieStorage = nil
        config.urlCredentialStorage = nil
        config.urlCache = nil
        config.httpAdditionalHeaders = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 120
        return URLSession(configuration: config, delegate: MediaCacheSessionDelegate(), delegateQueue: nil)
    }

    static func remove(videoId: String, quality: String) {
        let root = directory
        guard validKey(videoID: videoId, quality: quality), isSafeDirectory(root, allowMissing: false) else { return }
        for ext in mediaExtensions {
            let url = file(videoId: videoId, quality: quality, ext: ext, in: root)
            if isSafeDestination(url, in: root) { try? FileManager.default.removeItem(at: url) }
        }
    }

    static func totalBytes(in root: URL? = nil) -> Int64 {
        let root = root ?? directory
        guard isSafeDirectory(root, allowMissing: false), let items = try? FileManager.default.contentsOfDirectory(
            at: root, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey]) else { return 0 }
        return items.reduce(Int64(0)) { sum, url in
            guard isSafeDestination(url, in: root),
                  let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > 0 else { return sum }
            let (total, overflow) = sum.addingReportingOverflow(Int64(size))
            return overflow ? Int64.max : total
        }
    }

    static func clearAll(in root: URL? = nil) throws {
        let root = root ?? directory
        guard isSafeDirectory(root, allowMissing: true) else { throw CocoaError(.fileWriteNoPermission) }
        if FileManager.default.fileExists(atPath: root.path) {
            try FileManager.default.removeItem(at: root)
        }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
    }
}

private final class MediaCacheSessionDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust
                          ? .performDefaultHandling : .rejectProtectionSpace, nil)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        guard let url = request.url, ["https", "http"].contains(url.scheme ?? ""),
              url.user == nil, url.password == nil else { completionHandler(nil); return }
        var safe = request
        safe.httpShouldHandleCookies = false
        safe.setValue(nil, forHTTPHeaderField: "Cookie")
        safe.setValue(nil, forHTTPHeaderField: "Authorization")
        safe.setValue(nil, forHTTPHeaderField: "Proxy-Authorization")
        completionHandler(safe)
    }
}

/// Cancellation closes publication synchronously before an async resource.cancel reaches its actor.
final class MediaCachePublicationGate: @unchecked Sendable {
    private let lock = NSLock()
    private var open = true
    func close() { lock.lock(); open = false; lock.unlock() }
    var isOpen: Bool { lock.lock(); defer { lock.unlock() }; return open }
    func whileOpen<T>(_ operation: () throws -> T) throws -> T {
        lock.lock()
        defer { lock.unlock() }
        guard open else { throw CancellationError() }
        return try operation()
    }
}
