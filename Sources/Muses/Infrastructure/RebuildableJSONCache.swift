import Darwin
import Foundation

struct JSONCacheLimits: Sendable {
    let bytes: Int64
    let entries: Int
    let entryBytes: Int

    static let search = JSONCacheLimits(bytes: 64 * 1_048_576, entries: 256, entryBytes: 2 * 1_048_576)
    static let home = JSONCacheLimits(bytes: 128 * 1_048_576, entries: 512, entryBytes: 2 * 1_048_576)
    static let catalog = JSONCacheLimits(bytes: 200 * 1_048_576, entries: 100, entryBytes: 2 * 1_048_576)
}

/// One disk budget covers the whole family, including all account/locale partitions.
/// Only owned SHA-256 JSON files are evictable. Unknown files and abandoned staging
/// files still consume admission capacity, but are never removed by this cache.
/// Call writes off the main actor. Encoding and large writes never hold an SWR ticket lock.
final class RebuildableJSONCache: @unchecked Sendable {
    private let rootPath: String
    let limits: JSONCacheLimits
    private let state: JSONCacheFamilyState

    init(root: URL, limits: JSONCacheLimits) {
        rootPath = root.isFileURL ? Self.normalizedPath(root.path) : "/"
        self.limits = limits
        state = JSONCacheFamilyRegistry.shared.state(for: rootPath)
    }

    /// Protect the active account's validated fallback from unrelated Home writes.
    /// This never reads data from another partition or changes freshness/provenance.
    func protectFallback(at url: URL) {
        guard let components = relativeComponents(url), Self.isJSONName(components.last ?? "") else { return }
        state.protectionLock.withLock { state.protectedPath = components.joined(separator: "/") }
    }

    func beginPublication(at url: URL, id: UUID) {
        guard let path = relativeComponents(url)?.joined(separator: "/") else { return }
        state.identityLock.withLock { state.publications[path] = id }
    }

    func finishPublication(at url: URL, id: UUID) {
        guard let path = relativeComponents(url)?.joined(separator: "/") else { return }
        state.identityLock.withLock {
            if state.publications[path] == id { state.publications.removeValue(forKey: path) }
        }
    }

    func read(at url: URL) -> Data? {
        guard limits.entryBytes > 0, let components = relativeComponents(url),
              let root = openRoot(create: false) else { return nil }
        defer { close(root) }
        guard let parent = openDirectory(components.dropLast(), from: root, create: false) else { return nil }
        defer { close(parent) }
        let name = components.last!
        guard Self.isJSONName(name) else { return nil }
        let file = openat(parent, name, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        guard file >= 0 else { return nil }
        let handle = FileHandle(fileDescriptor: file, closeOnDealloc: true)
        var info = stat()
        guard fstat(file, &info) == 0, Self.isOwnedFile(info),
              info.st_size >= 0, info.st_size <= Int64(limits.entryBytes),
              let data = try? handle.read(upToCount: limits.entryBytes + 1),
              data.count <= limits.entryBytes else { return nil }
        return data
    }

    /// Stage at most one bounded document per family. The caller's publication
    /// gate runs only around the final rename, after inventory/pruning/bulk I/O.
    @discardableResult
    func write(_ data: Data, at url: URL, publicationID: UUID? = nil,
               publish: (_ commit: () -> Bool) -> Bool = { $0() }) -> Bool {
        guard !data.isEmpty, data.count <= limits.entryBytes, limits.bytes > 0,
              limits.entries > 0, let components = relativeComponents(url),
              Self.isJSONName(components.last ?? "") else { return false }
        return state.operationLock.withLock {
            if let publicationID,
               !state.identityLock.withLock({ state.publications[components.joined(separator: "/")] == publicationID }) { return false }
            guard let root = openRoot(create: true) else { return false }
            defer { close(root) }
            let name = components.last!
            let targetPath = components.joined(separator: "/")
            var existing = stat()
            let priorParent = openDirectory(components.dropLast(), from: root, create: false)
            if let priorParent {
                defer { close(priorParent) }
                if fstatat(priorParent, name, &existing, AT_SYMLINK_NOFOLLOW) == 0 {
                    guard Self.isOwnedFile(existing) else { return false }
                } else if errno != ENOENT { return false }
            }
            guard let inventory = self.inventory(root) else { return false }
            var bytes = inventory.reduce(Int64(0)) { $0 + $1.bytes }
            var count = inventory.count
            // Keep the old destination until atomic replacement, so a rejected
            // refresh cannot destroy the last successful account snapshot.
            let newDirectoryCount = priorParent == nil ? components.count - 1 : 0
            let reserved = Int64((data.count + 4095) / 4096 * 4096 + newDirectoryCount * 4096)
            guard reserved <= limits.bytes else { return false }
            for item in inventory.sorted(by: { ($0.modified, $0.path) < ($1.modified, $1.path) }) {
                if bytes <= limits.bytes - reserved && count + 1 + newDirectoryCount <= limits.entries { break }
                guard item.evictable, item.path != targetPath else { continue }
                let removed = state.protectionLock.withLock {
                    guard state.protectedPath != item.path else { return false }
                    return remove(item, from: root)
                }
                if removed { bytes -= item.bytes; count -= 1 }
            }
            guard bytes <= limits.bytes - reserved, count + 1 + newDirectoryCount <= limits.entries,
                  let parent = openDirectory(components.dropLast(), from: root, create: true) else { return false }
            defer { close(parent) }
            let stagedName = ".\(UUID().uuidString).tmp"
            let descriptor = openat(parent, stagedName, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
            guard descriptor >= 0 else { return false }
            defer { close(descriptor); _ = unlinkat(parent, stagedName, 0) }
            var offset = 0
            let written = data.withUnsafeBytes { buffer -> Bool in
                while offset < buffer.count {
                    let amount = Darwin.write(descriptor, buffer.baseAddress!.advanced(by: offset), buffer.count - offset)
                    if amount < 0 && errno == EINTR { continue }
                    guard amount > 0 else { return false }
                    offset += amount
                }
                return true
            }
            var staged = stat()
            guard written, fstat(descriptor, &staged) == 0,
                  bytes + Self.footprint(staged) <= limits.bytes else { return false }
            return publish {
                self.state.identityLock.withLock {
                    if let publicationID, self.state.publications[targetPath] != publicationID { return false }
                    // A clear/replacement of the root or partition revokes this
                    // staging directory even if the same textual path exists again.
                    guard self.stillNames(root, components: []),
                          self.stillNames(parent, components: Array(components.dropLast())) else { return false }
                    var current = stat()
                    if fstatat(parent, name, &current, AT_SYMLINK_NOFOLLOW) == 0 {
                        guard Self.isOwnedFile(current),
                              existing.st_ino == 0 || Self.sameFile(current, existing) else { return false }
                    } else if errno != ENOENT || existing.st_ino != 0 { return false }
                    let renamed = renameat(parent, stagedName, parent, name) == 0
                    if publicationID != nil { self.state.publications.removeValue(forKey: targetPath) }
                    return renamed
                }
            }
        }
    }

    func remove(at url: URL) {
        guard let components = relativeComponents(url), Self.isJSONName(components.last ?? "") else { return }
        state.identityLock.withLock {
            state.publications.removeValue(forKey: components.joined(separator: "/"))
            guard let root = openRoot(create: false) else { return }
            defer { close(root) }
            guard let parent = openDirectory(components.dropLast(), from: root, create: false) else { return }
            defer { close(parent) }
            var info = stat()
            if fstatat(parent, components.last!, &info, AT_SYMLINK_NOFOLLOW) == 0, Self.isOwnedFile(info) {
                _ = unlinkat(parent, components.last!, 0)
            }
        }
    }

    func clear(in directory: URL) {
        let path = Self.normalizedPath(directory.path)
        guard path == rootPath || path.hasPrefix(rootPath + "/") else { return }
        let prefix = path == rootPath ? "" : String(path.dropFirst(rootPath.count + 1)) + "/"
        revokePublications(in: directory)
        guard let root = openRoot(create: false) else { return }
        defer { close(root) }
        guard let files = inventory(root) else { return }
        for file in files where file.evictable && file.path.hasPrefix(prefix) { _ = remove(file, from: root) }
    }

    /// Privacy invalidation also revokes unopened, not-yet-written partitions.
    /// The optional final parent name selects one layer across all its locales.
    func revokePublications(in directory: URL, onlyParentName: String? = nil) {
        let path = Self.normalizedPath(directory.path)
        guard path == rootPath || path.hasPrefix(rootPath + "/") else { return }
        let prefix = path == rootPath ? "" : String(path.dropFirst(rootPath.count + 1)) + "/"
        state.identityLock.withLock {
            for key in Array(state.publications.keys) where key.hasPrefix(prefix)
                && (onlyParentName == nil || key.split(separator: "/").dropLast().last.map(String.init) == onlyParentName) {
                state.publications.removeValue(forKey: key)
            }
        }
    }

    private struct Item {
        let path: String
        let info: stat
        let bytes: Int64
        let modified: TimeInterval
        let evictable: Bool
    }

    private func inventory(_ root: Int32) -> [Item]? {
        var result: [Item] = []
        func visit(_ descriptor: Int32, prefix: String, depth: Int) -> Bool {
            guard depth <= 8 else { return false }
            // A fresh open description does not share directory iteration offsets.
            let iterator = openat(descriptor, ".", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            guard iterator >= 0 else { return false }
            guard let stream = fdopendir(iterator) else { close(iterator); return false }
            defer { closedir(stream) }
            while true {
                errno = 0
                guard let entry = readdir(stream) else { return errno == 0 }
                let name = withUnsafeBytes(of: entry.pointee.d_name) {
                    String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self)
                }
                if name == "." || name == ".." { continue }
                guard result.count < 20_000 else { return false }
                var info = stat()
                guard fstatat(descriptor, name, &info, AT_SYMLINK_NOFOLLOW) == 0 else { return false }
                let path = prefix + name
                result.append(Item(path: path, info: info, bytes: Self.footprint(info),
                    modified: TimeInterval(info.st_mtimespec.tv_sec) + Double(info.st_mtimespec.tv_nsec) / 1e9,
                    evictable: Self.isJSONName(name) && Self.isOwnedFile(info)))
                if info.st_mode & S_IFMT == S_IFDIR {
                    let child = openat(descriptor, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
                    guard child >= 0 else { return false }
                    let ok = visit(child, prefix: path + "/", depth: depth + 1)
                    close(child)
                    if !ok { return false }
                }
            }
        }
        return visit(root, prefix: "", depth: 0) ? result : nil
    }

    private func remove(_ item: Item, from root: Int32) -> Bool {
        guard stillNames(root, components: []) else { return false }
        let components = item.path.split(separator: "/").map(String.init)
        guard let parent = openDirectory(components.dropLast(), from: root, create: false) else { return false }
        defer { close(parent) }
        var current = stat()
        guard fstatat(parent, components.last!, &current, AT_SYMLINK_NOFOLLOW) == 0,
              Self.isOwnedFile(current), Self.sameFile(current, item.info),
              Self.footprint(current) == item.bytes,
              current.st_mtimespec.tv_sec == item.info.st_mtimespec.tv_sec,
              current.st_mtimespec.tv_nsec == item.info.st_mtimespec.tv_nsec else { return false }
        return unlinkat(parent, components.last!, 0) == 0
    }

    private func relativeComponents(_ url: URL) -> [String]? {
        guard url.isFileURL else { return nil }
        let path = Self.normalizedPath(url.path)
        guard path.hasPrefix(rootPath + "/") else { return nil }
        let parts = path.dropFirst(rootPath.count + 1).split(separator: "/").map(String.init)
        return parts.isEmpty || parts.count > 8 ? nil : parts
    }

    private func openRoot(create: Bool) -> Int32? {
        let anchor = open("/", O_RDONLY | O_DIRECTORY | O_CLOEXEC)
        guard anchor >= 0 else { return nil }
        defer { close(anchor) }
        guard rootPath != "/", let result = openDirectory(rootPath.split(separator: "/").map(String.init)[...], from: anchor, create: create) else { return nil }
        var info = stat()
        guard fstat(result, &info) == 0, info.st_uid == getuid() else { close(result); return nil }
        return result
    }

    private func openDirectory(_ components: ArraySlice<String>, from root: Int32, create: Bool) -> Int32? {
        var result = dup(root)
        guard result >= 0 else { return nil }
        for name in components {
            var next = openat(result, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            if next < 0 && errno == ENOENT && create {
                if mkdirat(result, name, 0o700) != 0 && errno != EEXIST { close(result); return nil }
                next = openat(result, name, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            }
            close(result)
            guard next >= 0 else { return nil }
            result = next
        }
        return result
    }

    private func stillNames(_ descriptor: Int32, components: [String]) -> Bool {
        guard let root = openRoot(create: false) else { return false }
        defer { close(root) }
        guard let current = openDirectory(components[...], from: root, create: false) else { return false }
        defer { close(current) }
        var before = stat(), after = stat()
        return fstat(descriptor, &before) == 0 && fstat(current, &after) == 0 && Self.sameFile(before, after)
    }

    private static func isOwnedFile(_ info: stat) -> Bool {
        info.st_mode & S_IFMT == S_IFREG && info.st_uid == getuid() && info.st_nlink == 1
    }
    private static func sameFile(_ lhs: stat, _ rhs: stat) -> Bool { lhs.st_dev == rhs.st_dev && lhs.st_ino == rhs.st_ino }
    private static func footprint(_ info: stat) -> Int64 { max(Int64(info.st_size), Int64(info.st_blocks) * 512) }
    private static func isJSONName(_ name: String) -> Bool {
        name.utf8.count == 69 && name.hasSuffix(".json") && name.utf8.prefix(64).allSatisfy {
            (48...57).contains($0) || (97...102).contains($0)
        }
    }
    private static func normalizedPath(_ supplied: String) -> String {
        var components: [Substring] = []
        for part in supplied.split(separator: "/") {
            if part == "." { continue }
            if part == ".." { if !components.isEmpty { components.removeLast() }; continue }
            components.append(part)
        }
        let path = "/" + components.joined(separator: "/")
        if path == "/var" || path.hasPrefix("/var/") || path == "/tmp" || path.hasPrefix("/tmp/") { return "/private" + path }
        return path
    }
}

private final class JSONCacheFamilyState: @unchecked Sendable {
    let operationLock = NSLock()
    let protectionLock = NSLock()
    let identityLock = NSLock()
    var protectedPath: String?
    var publications: [String: UUID] = [:]
}

private final class JSONCacheFamilyRegistry: @unchecked Sendable {
    static let shared = JSONCacheFamilyRegistry()
    private let lock = NSLock()
    private var states: [String: JSONCacheFamilyState] = [:]
    func state(for root: String) -> JSONCacheFamilyState {
        lock.withLock {
            if let state = states[root] { return state }
            let state = JSONCacheFamilyState()
            states[root] = state
            return state
        }
    }
}
