import Darwin
import Foundation

/// One aggregate budget for complete media, quarantines and reserved partials.
/// All callers share this authority; filesystem work belongs on a utility task.
final class MediaCacheBudget: @unchecked Sendable {
    static let shared = MediaCacheBudget {
        bytes(forGigabytes: UserDefaults.standard.integer(forKey: PrefKey.streamPrecacheLimitGB))
    }

    static func bytes(forGigabytes value: Int) -> Int64 {
        Int64([1, 2, 5, 10].contains(value) ? value : 2) * 1_073_741_824
    }

    final class Lease: @unchecked Sendable {
        fileprivate let id: UUID
        private let owner: MediaCacheBudget
        fileprivate init(id: UUID, owner: MediaCacheBudget) { self.id = id; self.owner = owner }
        func release() { owner.release(id) }
        func releaseAfterUse() { Task.detached(priority: .utility) { [owner, id] in owner.release(id) } }
        deinit { releaseAfterUse() }
    }

    struct PinnedEntry: Sendable {
        let entry: MediaFileCache.CompletedEntry
        let lease: Lease
    }

    struct Transfer: Sendable {
        let lease: Lease
        let handle: FileHandle
    }

    private struct Root: Hashable {
        let path: String
        let device: Int64
        let inode: UInt64
    }

    private struct Stamp {
        let device: Int64
        let inode: UInt64
        let size: Int64
        let allocated: Int64
        let modifiedSeconds: Int64
        let modifiedNanoseconds: Int64
        init(_ value: stat) {
            device = Int64(value.st_dev); inode = UInt64(value.st_ino); size = value.st_size
            allocated = Int64(value.st_blocks) * 512
            modifiedSeconds = Int64(value.st_mtimespec.tv_sec)
            modifiedNanoseconds = Int64(value.st_mtimespec.tv_nsec)
        }
        var footprint: Int64 { max(size, allocated) }
        func matches(_ value: stat) -> Bool {
            device == Int64(value.st_dev) && inode == UInt64(value.st_ino) && size == value.st_size
                && modifiedSeconds == Int64(value.st_mtimespec.tv_sec) && modifiedNanoseconds == Int64(value.st_mtimespec.tv_nsec)
        }
    }

    private struct Entry {
        let name: String
        let stamp: Stamp
        let accessed: TimeInterval
        let eligible: Bool
    }

    private enum Holding {
        case file(name: String, descriptor: Int32)
        case transfer(destination: String, staging: String, stamp: Stamp, descriptor: Int32, bytes: Int64, mayEvict: Bool)
    }

    private struct Record { let root: Root; var holding: Holding }
    private let lock = NSLock()
    private let limitBytes: @Sendable () -> Int64
    private var records: [UUID: Record] = [:]
    private var lastUse: [Root: [String: TimeInterval]] = [:]

    init(limitBytes: @escaping @Sendable () -> Int64) { self.limitBytes = limitBytes }

    /// The decoder keeps this lease until its client has stopped using the file.
    func existing(videoID: String, quality: String, in url: URL) -> PinnedEntry? {
        lock.withLock {
            guard let directory = try? Directory(url, create: false) else { return nil }
            pruneOldUsageRoots(replacedBy: directory.root)
            guard let entry = MediaFileCache.completedEntry(videoID: videoID, quality: quality, in: url) else { return nil }
            let descriptor = openat(directory.fd, entry.url.lastPathComponent, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
            guard descriptor >= 0 else { return nil }
            var info = stat()
            guard flock(descriptor, LOCK_SH | LOCK_NB) == 0, fstat(descriptor, &info) == 0,
                  Self.ownedRegular(info), Int64(info.st_dev) == entry.fingerprint.device,
                  UInt64(info.st_ino) == entry.fingerprint.inode, info.st_size == entry.fingerprint.size,
                  MediaFileCache.matches(entry, in: url), directory.stillNamed else {
                Darwin.close(descriptor); return nil
            }
            let id = UUID()
            records[id] = Record(root: directory.root, holding: .file(name: entry.url.lastPathComponent, descriptor: descriptor))
            lastUse[directory.root, default: [:]][entry.url.lastPathComponent] = Date().timeIntervalSince1970
            return PinnedEntry(entry: entry, lease: Lease(id: id, owner: self))
        }
    }

    /// Reserve the entire representation before creating its first partial byte.
    /// Predictions may refuse admission rather than evict previously played media.
    func begin(destination: URL, staging: URL, bytes: Int64, mayEvict: Bool) throws -> Transfer {
        try lock.withLock {
            try Task.checkCancellation()
            let directory = try Directory(destination.deletingLastPathComponent(), create: true)
            guard staging.deletingLastPathComponent().standardizedFileURL == destination.deletingLastPathComponent().standardizedFileURL,
                  Self.partialName(staging.lastPathComponent), bytes > 0, bytes <= max(0, limitBytes()),
                  MediaFileCache.isSafeDestination(destination, in: destination.deletingLastPathComponent()) else {
                throw URLError(.cannotWriteToFile)
            }
            _ = try trim(directory, additional: allocationBytes(bytes, in: directory), excluding: [], mayEvict: mayEvict)
            guard directory.stillNamed else { throw URLError(.noPermissionsToReadFile) }
            let descriptor = openat(directory.fd, staging.lastPathComponent,
                                    O_RDWR | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
            guard descriptor >= 0 else { throw URLError(.cannotCreateFile) }
            var info = stat()
            guard flock(descriptor, LOCK_EX | LOCK_NB) == 0, fstat(descriptor, &info) == 0 else {
                Darwin.close(descriptor); _ = unlinkat(directory.fd, staging.lastPathComponent, 0)
                throw URLError(.cannotCreateFile)
            }
            let id = UUID()
            let writer = dup(descriptor)
            guard writer >= 0 else {
                Darwin.close(descriptor); _ = unlinkat(directory.fd, staging.lastPathComponent, 0)
                throw URLError(.cannotOpenFile)
            }
            records[id] = Record(root: directory.root,
                holding: .transfer(destination: destination.lastPathComponent, staging: staging.lastPathComponent,
                                   stamp: Stamp(info), descriptor: descriptor, bytes: bytes, mayEvict: mayEvict))
            return Transfer(lease: Lease(id: id, owner: self), handle: FileHandle(fileDescriptor: writer, closeOnDealloc: true))
        }
    }

    /// Publication and eviction share a critical section. The cancellation gate
    /// surrounds only the final rename/descriptor transition, never a disk scan.
    func publish(_ lease: Lease, gate: MediaCachePublicationGate = .init()) throws -> FileHandle {
        try lock.withLock {
            try Task.checkCancellation()
            guard gate.isOpen else { throw CancellationError() }
            guard let record = records[lease.id],
                  case .transfer(let destination, let staging, let original, let stagedDescriptor, let bytes, let mayEvict) = record.holding else {
                throw CancellationError()
            }
            let directory = try Directory(URL(fileURLWithPath: record.root.path), create: false)
            var info = stat()
            guard directory.root == record.root, directory.stillNamed,
                  fstatat(directory.fd, staging, &info, AT_SYMLINK_NOFOLLOW) == 0,
                  Self.ownedRegular(info), original.device == Int64(info.st_dev), original.inode == UInt64(info.st_ino),
                  info.st_size == bytes else { throw URLError(.cannotWriteToFile) }
            var existing = stat()
            let present = fstatat(directory.fd, destination, &existing, AT_SYMLINK_NOFOLLOW) == 0
            if present {
                guard Self.ownedRegular(existing), existing.st_size == bytes else { throw URLError(.cannotWriteToFile) }
            } else if errno != ENOENT { throw URLError(.cannotWriteToFile) }
            let additional = present ? 0 : max(try allocationBytes(bytes, in: directory), Stamp(info).footprint)
            _ = try trim(directory, additional: additional, excluding: [lease.id],
                         skippedNames: [staging], protectedNames: [destination], mayEvict: mayEvict)
            return try gate.whileOpen {
                try Task.checkCancellation()
                guard directory.stillNamed else { throw URLError(.noPermissionsToReadFile) }
                if present {
                    guard unlinkat(directory.fd, staging, 0) == 0 else { throw URLError(.cannotRemoveFile) }
                } else {
                    guard renameatx_np(directory.fd, staging, directory.fd, destination, UInt32(RENAME_EXCL)) == 0 else {
                        throw URLError(.cannotWriteToFile)
                    }
                }
                // Hold a shared lock through resource cancellation/deinit, including
                // legacy range readers which may still be using their open handle.
                let descriptor = present
                    ? openat(directory.fd, destination, O_RDONLY | O_NOFOLLOW | O_CLOEXEC) : stagedDescriptor
                var pinned = stat()
                var named = stat()
                guard descriptor >= 0, flock(descriptor, LOCK_SH | LOCK_NB) == 0,
                      fstat(descriptor, &pinned) == 0, Self.ownedRegular(pinned), pinned.st_size == bytes,
                      (present ? Stamp(existing).matches(pinned)
                        : original.device == Int64(pinned.st_dev) && original.inode == UInt64(pinned.st_ino)),
                      fstatat(directory.fd, destination, &named, AT_SYMLINK_NOFOLLOW) == 0,
                      Stamp(pinned).matches(named) else {
                    if present, descriptor >= 0 { Darwin.close(descriptor) }
                    throw URLError(.cannotOpenFile)
                }
                if present { Darwin.close(stagedDescriptor) }
                records[lease.id]?.holding = .file(name: destination, descriptor: descriptor)
                lastUse[record.root, default: [:]][destination] = Date().timeIntervalSince1970
                let reader = dup(descriptor)
                guard reader >= 0 else { throw URLError(.cannotOpenFile) }
                return FileHandle(fileDescriptor: reader, closeOnDealloc: true)
            }
        }
    }

    /// Also runs when predictions are disabled: old excess complete media and
    /// unleased, day-old app partials can never grow indefinitely across launches.
    @discardableResult
    func maintain(in url: URL) throws -> Int64 {
        try lock.withLock {
            let directory = try Directory(url, create: false)
            let protected = protectedNames(in: directory.root)
            for entry in try entries(in: directory) where Self.partialName(entry.name)
                && !protected.contains(entry.name)
                && Date().timeIntervalSince1970 - Double(entry.stamp.modifiedSeconds) > 86_400 {
                _ = retire(entry, in: directory)
            }
            return try trim(directory, additional: 0, excluding: [], mayEvict: true)
        }
    }

    private func release(_ id: UUID) {
        lock.withLock {
            guard let record = records.removeValue(forKey: id) else { return }
            switch record.holding {
            case .file(_, let descriptor): Darwin.close(descriptor)
            case .transfer(_, let staging, let stamp, let descriptor, _, _):
                Darwin.close(descriptor)
                guard let directory = try? Directory(URL(fileURLWithPath: record.root.path), create: false),
                      directory.root == record.root else { return }
                var info = stat()
                if fstatat(directory.fd, staging, &info, AT_SYMLINK_NOFOLLOW) == 0,
                   Self.ownedRegular(info), stamp.device == Int64(info.st_dev), stamp.inode == UInt64(info.st_ino) {
                    _ = unlinkat(directory.fd, staging, 0)
                }
            }
        }
    }

    private func protectedNames(in root: Root, excluding ids: Set<UUID> = []) -> Set<String> {
        var result = Set<String>()
        for (id, record) in records where record.root == root && !ids.contains(id) {
            switch record.holding {
            case .file(let name, _): result.insert(name)
            case .transfer(let destination, let staging, _, _, _, _): result.formUnion([destination, staging])
            }
        }
        return result
    }

    private func trim(_ directory: Directory, additional: Int64, excluding ids: Set<UUID>,
                      skippedNames: Set<String> = [], protectedNames extra: Set<String> = [], mayEvict: Bool) throws -> Int64 {
        let files = try entries(in: directory)
        pruneOldUsageRoots(replacedBy: directory.root)
        if let access = lastUse[directory.root] {
            let retained = Set(files.map(\.name)).union(protectedNames(in: directory.root))
            lastUse[directory.root] = access.filter { retained.contains($0.key) }
        }
        guard additional <= max(0, limitBytes()) else { throw URLError(.dataLengthExceedsMaximum) }
        let protected = protectedNames(in: directory.root, excluding: ids).union(extra)
        var reserved: [String: (bytes: Int64, stamp: Stamp)] = [:]
        for (id, record) in records where record.root == directory.root && !ids.contains(id) {
            if case .transfer(_, let staging, let stamp, _, let bytes, _) = record.holding {
                reserved[staging] = (try allocationBytes(bytes, in: directory), stamp)
            }
        }
        var used: Int64 = additional
        for entry in files where !skippedNames.contains(entry.name) {
            var bytes = entry.stamp.footprint
            if let transfer = reserved[entry.name], transfer.stamp.device == entry.stamp.device,
               transfer.stamp.inode == entry.stamp.inode {
                bytes = max(transfer.bytes, bytes); reserved.removeValue(forKey: entry.name)
            }
            let (sum, overflow) = used.addingReportingOverflow(bytes)
            guard !overflow else { throw URLError(.dataLengthExceedsMaximum) }; used = sum
        }
        for transfer in reserved.values {
            let (sum, overflow) = used.addingReportingOverflow(transfer.bytes)
            guard !overflow else { throw URLError(.dataLengthExceedsMaximum) }; used = sum
        }
        let limit = max(0, limitBytes())
        if used <= limit { return used }
        guard mayEvict else { throw URLError(.dataLengthExceedsMaximum) }
        let access = lastUse[directory.root, default: [:]]
        let candidates = files.filter { $0.eligible && !protected.contains($0.name) && !skippedNames.contains($0.name) }
            .sorted { (access[$0.name] ?? $0.accessed, $0.name) < (access[$1.name] ?? $1.accessed, $1.name) }
        for entry in candidates where used > limit {
            try Task.checkCancellation()
            if retire(entry, in: directory) { used -= entry.stamp.footprint }
        }
        guard used <= limit else { throw URLError(.dataLengthExceedsMaximum) }
        return used
    }

    private func entries(in directory: Directory) throws -> [Entry] {
        guard directory.stillNamed else { throw URLError(.noPermissionsToReadFile) }
        let descriptor = openat(directory.fd, ".", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard descriptor >= 0 else { throw URLError(.cannotOpenFile) }
        guard let stream = fdopendir(descriptor) else { Darwin.close(descriptor); throw URLError(.cannotOpenFile) }
        defer { closedir(stream) }
        var result: [Entry] = []
        while true {
            errno = 0
            guard let item = readdir(stream) else {
                if errno != 0 { throw URLError(.cannotOpenFile) }
                break
            }
            let name = withUnsafePointer(to: item.pointee.d_name) {
                $0.withMemoryRebound(to: CChar.self, capacity: Int(item.pointee.d_namlen) + 1) { String(cString: $0) }
            }
            if name == "." || name == ".." { continue }
            var info = stat()
            guard fstatat(directory.fd, name, &info, AT_SYMLINK_NOFOLLOW) == 0 else { throw URLError(.cannotOpenFile) }
            // streams is deliberately flat. Unknown directories are never
            // traversed or deleted, and cannot silently escape accounting.
            guard [(S_IFREG), (S_IFLNK)].contains(info.st_mode & S_IFMT), info.st_size >= 0, info.st_blocks >= 0 else {
                throw URLError(.cannotOpenFile)
            }
            let accessed = max(Double(info.st_atimespec.tv_sec), Double(info.st_mtimespec.tv_sec))
            result.append(Entry(name: name, stamp: Stamp(info), accessed: accessed,
                                eligible: Self.ownedRegular(info) && Self.managedName(name)))
        }
        return result
    }

    private func retire(_ entry: Entry, in directory: Directory) -> Bool {
        guard directory.stillNamed else { return false }
        let descriptor = openat(directory.fd, entry.name, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        guard descriptor >= 0 else { return false }
        defer { Darwin.close(descriptor) }
        var info = stat()
        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0, fstat(descriptor, &info) == 0,
              Self.ownedRegular(info), entry.stamp.matches(info) else { return false }
        let retired = ".evict-\(UUID().uuidString)"
        guard renameatx_np(directory.fd, entry.name, directory.fd, retired, UInt32(RENAME_EXCL)) == 0 else { return false }
        var moved = stat()
        guard fstatat(directory.fd, retired, &moved, AT_SYMLINK_NOFOLLOW) == 0, entry.stamp.matches(moved) else {
            _ = renameatx_np(directory.fd, retired, directory.fd, entry.name, UInt32(RENAME_EXCL)); return false
        }
        guard unlinkat(directory.fd, retired, 0) == 0 else {
            _ = renameatx_np(directory.fd, retired, directory.fd, entry.name, UInt32(RENAME_EXCL)); return false
        }
        lastUse[directory.root]?.removeValue(forKey: entry.name)
        return true
    }

    private static func ownedRegular(_ info: stat) -> Bool {
        (info.st_mode & S_IFMT) == S_IFREG && info.st_uid == getuid() && info.st_nlink == 1
    }

    private func pruneOldUsageRoots(replacedBy root: Root) {
        let leased = Set(records.values.map(\.root))
        for old in Array(lastUse.keys) where old.path == root.path && old != root && !leased.contains(old) {
            lastUse.removeValue(forKey: old)
        }
    }

    private func allocationBytes(_ bytes: Int64, in directory: Directory) throws -> Int64 {
        let (rounded, overflow) = bytes.addingReportingOverflow(directory.allocationUnit - 1)
        guard bytes >= 0, !overflow else { throw URLError(.dataLengthExceedsMaximum) }
        return rounded / directory.allocationUnit * directory.allocationUnit
    }

    private static func partialName(_ name: String) -> Bool {
        name.hasPrefix(".") && name.hasSuffix(".partial") && UUID(uuidString: String(name.dropFirst().dropLast(8))) != nil
    }

    private static func managedName(_ name: String) -> Bool {
        let value = name as NSString
        if MediaFileCache.mediaExtensions.contains(value.pathExtension.lowercased()) {
            let parts = value.deletingPathExtension.components(separatedBy: "__")
            return parts.count == 2 && MediaFileCache.validKey(videoID: parts[0], quality: parts[1])
        }
        guard name.hasPrefix("."), name.hasSuffix(".quarantine") else { return false }
        let body = String(name.dropFirst().dropLast(11))
        if body.hasPrefix("rejected-") { return UUID(uuidString: String(body.dropFirst(9))) != nil }
        guard let dot = body.lastIndex(of: "."), UUID(uuidString: String(body[body.index(after: dot)...])) != nil else { return false }
        return managedName(String(body[..<dot]))
    }

    /// Walk every ancestor with O_NOFOLLOW. Retain the directory identity and
    /// use descriptor-relative operations so a renamed root cannot redirect IO.
    private final class Directory {
        let fd: Int32
        let root: Root
        let allocationUnit: Int64
        init(_ url: URL, create: Bool) throws {
            guard url.isFileURL else { throw URLError(.unsupportedURL) }
            var path = url.standardizedFileURL.path
            if path.hasPrefix("/var/") || path.hasPrefix("/tmp/") { path = "/private" + path }
            let components = path.split(separator: "/").map(String.init)
            guard !components.isEmpty else { throw URLError(.noPermissionsToReadFile) }
            var current = Darwin.open("/", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            guard current >= 0 else { throw URLError(.noPermissionsToReadFile) }
            do {
                for (index, name) in components.enumerated() {
                    var next = openat(current, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
                    if next < 0, errno == ENOENT, create, index == components.count - 1 {
                        guard mkdirat(current, name, 0o700) == 0 || errno == EEXIST else { throw URLError(.cannotCreateFile) }
                        next = openat(current, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
                    }
                    guard next >= 0 else { throw URLError(.noPermissionsToReadFile) }
                    Darwin.close(current); current = next
                }
                var info = stat()
                var volume = statfs()
                guard fstat(current, &info) == 0, info.st_uid == getuid(), fstatfs(current, &volume) == 0 else {
                    throw URLError(.noPermissionsToReadFile)
                }
                fd = current; root = Root(path: path, device: Int64(info.st_dev), inode: UInt64(info.st_ino))
                allocationUnit = max(512, Int64(volume.f_bsize))
            } catch { Darwin.close(current); throw error }
        }
        var stillNamed: Bool {
            var info = stat()
            return lstat(root.path, &info) == 0 && (info.st_mode & S_IFMT) == S_IFDIR
                && info.st_uid == getuid() && Int64(info.st_dev) == root.device && UInt64(info.st_ino) == root.inode
        }
        deinit { Darwin.close(fd) }
    }
}
