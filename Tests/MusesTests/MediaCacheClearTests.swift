import Foundation
import Testing
@testable import Muses

@Suite("Media cache clear and size failures")
struct MediaCacheClearTests {
    private func root() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("muses-cache-clear-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        return root
    }

    @Test("Successful clear removes complete and partial files and recreates a private empty directory")
    func successfulClear() throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        try Data(repeating: 1, count: 8_192).write(to: root.appendingPathComponent("audio.m4a"))
        try Data(repeating: 2, count: 16_384).write(to: root.appendingPathComponent("video.webm"))
        try Data(repeating: 3, count: 4_096).write(to: root.appendingPathComponent(".download.partial"))
        #expect(try SettingsMediaCacheSummary.read(root) == .init(audio: 8_192, video: 16_384, other: 4_096))

        try MediaFileCache.clearAll(in: root)

        #expect(try SettingsMediaCacheSummary.read(root).total == 0)
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
        #expect(try FileManager.default.attributesOfItem(atPath: root.path)[.posixPermissions] as? Int == 0o700)
    }

    @Test("A real read-only cache reports clear failure, preserves bytes, and succeeds after access is restored")
    func permissionFailureAndRetry() throws {
        let root = try root()
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path)
            try? FileManager.default.removeItem(at: root)
        }
        let file = root.appendingPathComponent("retained.m4a")
        let bytes = Data(repeating: 42, count: 53_248)
        try bytes.write(to: file)
        let before = try SettingsMediaCacheSummary.read(root)
        try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: root.path)

        #expect(throws: (any Error).self) { try MediaFileCache.clearAll(in: root) }
        #expect(try Data(contentsOf: file) == bytes)
        #expect(try SettingsMediaCacheSummary.read(root) == before)

        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path)
        try MediaFileCache.clearAll(in: root)
        #expect(try SettingsMediaCacheSummary.read(root).total == 0)
    }

    @Test("An unreadable cache size throws instead of returning an empty summary and can be retried")
    func unreadableSizeAndRetry() throws {
        let root = try root()
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path)
            try? FileManager.default.removeItem(at: root)
        }
        try Data(repeating: 9, count: 8_192).write(to: root.appendingPathComponent("retained.m4a"))
        let before = try SettingsMediaCacheSummary.read(root)
        try FileManager.default.setAttributes([.posixPermissions: 0o100], ofItemAtPath: root.path)

        #expect(throws: (any Error).self) { try SettingsMediaCacheSummary.read(root) }

        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path)
        #expect(try SettingsMediaCacheSummary.read(root) == before)
    }

    @Test("A symlink cache root fails closed without deleting or counting the external directory")
    func symlinkRootPreservesExternalFiles() throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        let external = root.appendingPathComponent("external", isDirectory: true)
        try FileManager.default.createDirectory(at: external, withIntermediateDirectories: true)
        let sentinel = external.appendingPathComponent("sentinel.m4a")
        let bytes = Data(repeating: 7, count: 8_192)
        try bytes.write(to: sentinel)
        let link = root.appendingPathComponent("streams", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: external)

        #expect(throws: (any Error).self) { try MediaFileCache.clearAll(in: link) }
        #expect(throws: (any Error).self) { try SettingsMediaCacheSummary.read(link) }
        #expect(try Data(contentsOf: sentinel) == bytes)
        #expect(try FileManager.default.destinationOfSymbolicLink(atPath: link.path) == external.path)
    }

    @Test("Size summary excludes symlink entries and a missing directory is not reported as empty")
    func unavailableAndExternalEntries() throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        let streams = root.appendingPathComponent("streams", isDirectory: true)
        try FileManager.default.createDirectory(at: streams, withIntermediateDirectories: true)
        let sentinel = root.appendingPathComponent("outside.m4a")
        try Data(repeating: 3, count: 8_192).write(to: sentinel)
        try FileManager.default.createSymbolicLink(at: streams.appendingPathComponent("linked.m4a"),
                                                   withDestinationURL: sentinel)
        #expect(try SettingsMediaCacheSummary.read(streams).total == 0)
        #expect(throws: (any Error).self) {
            try SettingsMediaCacheSummary.read(root.appendingPathComponent("missing", isDirectory: true))
        }
        #expect(try Data(contentsOf: sentinel).count == 8_192)
    }
}
