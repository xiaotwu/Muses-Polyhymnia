import Darwin
import Foundation
import Testing
@testable import Muses

@Suite("Aggregate media cache budget", .serialized)
struct MediaCacheBudgetTests {
    private func root() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("muses-budget-\(UUID())")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func paths(_ root: URL, video: String) -> (URL, URL) {
        (MediaFileCache.file(videoId: video, quality: "bestaudio", ext: "webm", in: root),
         root.appendingPathComponent(".\(UUID().uuidString).partial"))
    }

    @Test("Whole-file reservations include unwritten ranges; cancellation returns capacity and removes only its partial")
    func reservationsAndCancellation() throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        let budget = MediaCacheBudget { 8192 }
        let (a, partialA) = paths(root, video: "first")
        let first = try budget.begin(destination: a, staging: partialA, bytes: 8192, mayEvict: true)
        try first.handle.write(contentsOf: Data(repeating: 1, count: 1024))
        let (b, partialB) = paths(root, video: "second")
        #expect(throws: (any Error).self) {
            try budget.begin(destination: b, staging: partialB, bytes: 8192, mayEvict: true)
        }
        #expect(try budget.maintain(in: root) == 8192)
        #expect(try Data(contentsOf: partialA).count == 1024)
        try first.handle.close(); first.lease.release()
        #expect(!FileManager.default.fileExists(atPath: partialA.path))
        let second = try budget.begin(destination: b, staging: partialB, bytes: 8192, mayEvict: true)
        try second.handle.close(); second.lease.release()
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
    }

    @Test("Lowering capacity during a transfer is rechecked before publication")
    func reducedCapacityBeforePublication() throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        let value = MutableMediaBudget(16_384)
        let budget = MediaCacheBudget { value.bytes }
        let (destination, partial) = paths(root, video: "first")
        let transfer = try budget.begin(destination: destination, staging: partial, bytes: 8192, mayEvict: true)
        try transfer.handle.write(contentsOf: Data(repeating: 1, count: 8192))
        try transfer.handle.close()
        value.bytes = 4096
        #expect(throws: (any Error).self) { try budget.publish(transfer.lease) }
        transfer.lease.release()
        #expect(!FileManager.default.fileExists(atPath: destination.path))
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
    }

    @Test("The budget owns its descriptor after the writer closes; publication returns a readable file")
    func descriptorOwnershipThroughPublication() throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        let budget = MediaCacheBudget { 8192 }
        let (destination, partial) = paths(root, video: "new")
        let transfer = try budget.begin(destination: destination, staging: partial, bytes: 8192, mayEvict: true)
        let payload = Data(repeating: 3, count: 8192)
        try transfer.handle.write(contentsOf: payload)
        try transfer.handle.synchronize(); try transfer.handle.close()
        let reader = try budget.publish(transfer.lease)
        try reader.seek(toOffset: 0)
        #expect(try reader.readToEnd() == payload)
        #expect(try budget.maintain(in: root) == 8192)
        #expect(try Data(contentsOf: destination) == payload)
        #expect(!FileManager.default.fileExists(atPath: partial.path))
        try reader.close(); transfer.lease.release()
    }

    @Test("Unknown bytes consume capacity without being deleted; symlink roots and entries cannot redirect eviction")
    func unknownFilesAndSymlinks() throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        let foreign = root.appendingPathComponent("keep.txt")
        let bytes = Data(repeating: 4, count: 8192)
        try bytes.write(to: foreign)
        let budget = MediaCacheBudget { 8192 }
        let (destination, partial) = paths(root, video: "new")
        #expect(throws: (any Error).self) {
            try budget.begin(destination: destination, staging: partial, bytes: 8192, mayEvict: true)
        }
        #expect(try Data(contentsOf: foreign) == bytes)
        let linkedRoot = root.appendingPathComponent("linked")
        try FileManager.default.createSymbolicLink(at: linkedRoot, withDestinationURL: root)
        let (linkedDestination, linkedPartial) = paths(linkedRoot, video: "new")
        #expect(throws: (any Error).self) {
            try budget.begin(destination: linkedDestination, staging: linkedPartial, bytes: 8192, mayEvict: true)
        }
        try FileManager.default.removeItem(at: linkedRoot)
        let linkedFile = MediaFileCache.file(videoId: "linked", quality: "bestaudio", ext: "webm", in: root)
        try FileManager.default.createSymbolicLink(at: linkedFile, withDestinationURL: foreign)
        #expect(throws: (any Error).self) { try budget.maintain(in: root) }
        #expect(try Data(contentsOf: foreign) == bytes)
        #expect(try FileManager.default.destinationOfSymbolicLink(atPath: linkedFile.path) == foreign.path)
    }

    @Test("Allocated blocks of tiny unknown files count toward the same total capacity")
    func allocatedFootprint() throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        var allocated: Int64 = 0
        for index in 0..<4 {
            let url = root.appendingPathComponent("unknown-\(index)")
            try Data([1]).write(to: url)
            var info = stat()
            try #require(lstat(url.path, &info) == 0)
            allocated += max(info.st_size, Int64(info.st_blocks) * 512)
        }
        try #require(allocated > 4, "This filesystem fixture must allocate blocks for tiny files")
        let footprint = allocated
        let exact = MediaCacheBudget { footprint }
        #expect(try exact.maintain(in: root) == allocated)
        let tight = MediaCacheBudget { footprint - 1 }
        #expect(throws: (any Error).self) { try tight.maintain(in: root) }
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).count == 4)
    }

    @Test("A replaced root cannot receive or retire the old reservation")
    func replacedRoot() throws {
        let root = try root()
        let moved = root.appendingPathExtension("retired")
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: moved)
        }
        let budget = MediaCacheBudget { 8192 }
        let (destination, partial) = paths(root, video: "new")
        let transfer = try budget.begin(destination: destination, staging: partial, bytes: 8192, mayEvict: true)
        try transfer.handle.write(contentsOf: Data(repeating: 7, count: 8192))
        try transfer.handle.close()
        try FileManager.default.moveItem(at: root, to: moved)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let replacement = Data(repeating: 9, count: 8192)
        try replacement.write(to: partial)
        #expect(throws: (any Error).self) { try budget.publish(transfer.lease) }
        transfer.lease.release()
        #expect(try Data(contentsOf: partial) == replacement)
        #expect(try Data(contentsOf: moved.appendingPathComponent(partial.lastPathComponent)) == Data(repeating: 7, count: 8192))
        #expect(!FileManager.default.fileExists(atPath: destination.path))
    }

    @Test("Startup prunes only day-old unleased UUID partials, preserving fresh and active work")
    func stalePartialMaintenance() throws {
        let root = try root()
        defer { try? FileManager.default.removeItem(at: root) }
        let budget = MediaCacheBudget { 16_384 }
        let old = paths(root, video: "old").1
        let fresh = paths(root, video: "fresh").1
        for file in [old, fresh] { try Data(repeating: 2, count: 4096).write(to: file) }
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -172_800)], ofItemAtPath: old.path)
        let (destination, active) = paths(root, video: "active")
        let transfer = try budget.begin(destination: destination, staging: active, bytes: 8192, mayEvict: true)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -172_800)], ofItemAtPath: active.path)
        #expect(try budget.maintain(in: root) == 12_288)
        #expect(!FileManager.default.fileExists(atPath: old.path))
        #expect(FileManager.default.fileExists(atPath: fresh.path))
        #expect(FileManager.default.fileExists(atPath: active.path))
        try transfer.handle.close(); transfer.lease.release()
    }

    @Test("Capacity accepts supported settings and defaults to two binary gigabytes")
    func configuredCapacity() {
        for value in [1, 2, 5, 10] { #expect(MediaCacheBudget.bytes(forGigabytes: value) == Int64(value) * 1_073_741_824) }
        for value in [-1, 0, 3, Int.max] { #expect(MediaCacheBudget.bytes(forGigabytes: value) == 2_147_483_648) }
    }
}

private final class MutableMediaBudget: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Int64
    init(_ value: Int64) { self.value = value }
    var bytes: Int64 {
        get { lock.withLock { value } }
        set { lock.withLock { value = newValue } }
    }
}
