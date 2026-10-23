import Foundation
import CMpv

/// Values copied from libmpv on its owner queue. No borrowed C pointer crosses this boundary.
enum MpvEvent: Sendable, Equatable {
    case loaded, restarted, ended, seeking(Bool), buffering(Bool), paused(Bool)
    case position(Double), duration(Double), bufferPercent(Double)
    case codec(String), sampleRate(Int)
    case equalizerConfigured
    case failed(MpvFailure)
}

/// Safe categories and numeric API errors only; never include libmpv logs or signed media URLs.
struct MpvFailure: Error, Sendable, Equatable {
    enum Stage: String, Sendable { case resolve, library, initialize, load, control, decode, eventQueue }
    let stage: Stage
    let code: Int32
    var property: String? = nil
}

@MainActor
protocol MpvClient: AnyObject {
    var onEvent: (@MainActor @Sendable (UInt64, MpvEvent) -> Void)? { get set }
    func load(_ stream: ResolvedAudioStream, generation: UInt64) async throws
    func stop()
    func set(_ property: String, _ value: String, generation: UInt64)
    func seek(to seconds: Double, generation: UInt64)
}

/// Production always loads the exact app-owned dylib. No PATH, Homebrew or system lookup.
@MainActor
final class NativeMpvClient: MpvClient {
    var onEvent: (@MainActor @Sendable (UInt64, MpvEvent) -> Void)?
    private let worker: MpvWorker

    init(bundle: Bundle = .main) {
        let path = bundle.bundleURL.appendingPathComponent("Contents/Frameworks/libmpv.2.dylib").path
        worker = MpvWorker(libraryPath: path)
    }

    /// Explicit injection for isolated tests; composition must use the bundle initializer.
    init(testLibraryURL: URL) {
        worker = MpvWorker(libraryPath: testLibraryURL.path)
    }

    deinit { worker.shutdown() }

    func load(_ stream: ResolvedAudioStream, generation: UInt64) async throws {
        let callback = onEvent
        try await worker.load(stream, generation: generation) { generation, event in
            DispatchQueue.main.async { callback?(generation, event) }
        }
    }
    func stop() { worker.shutdown() }
    func set(_ property: String, _ value: String, generation: UInt64) {
        worker.set(property, value, generation: generation)
    }
    func seek(to seconds: Double, generation: UInt64) { worker.seek(seconds, generation: generation) }
}

/// The unchecked conformance is justified by strict queue confinement of every mutable field
/// and C handle. Synchronous mpv APIs and destruction never run on a Swift executor.
private final class MpvWorker: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.muses.playback.mpv", qos: .userInitiated)
    private let libraryPath: String
    private var handle: OpaquePointer?
    private var timer: DispatchSourceTimer?
    private var generation: UInt64 = 0
    private var emit: (@Sendable (UInt64, MpvEvent) -> Void)?

    init(libraryPath: String) { self.libraryPath = libraryPath }

    func load(_ stream: ResolvedAudioStream, generation: UInt64,
              emit: @escaping @Sendable (UInt64, MpvEvent) -> Void) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [self] in
                close()
                self.generation = generation
                self.emit = emit
                var code: Int32 = 0
                guard let opened = muses_mpv_open(libraryPath, &code) else {
                    let stage: MpvFailure.Stage = [-1001, -1002, -1003].contains(code) ? .library : .initialize
                    continuation.resume(throwing: MpvFailure(stage: stage, code: code))
                    return
                }
                handle = opened
                let fields = stream.requestHeaders.sorted { $0.key < $1.key }.map { "\($0.key): \($0.value)" }
                let strings = fields.map { strdup($0) }
                defer { strings.forEach { free($0) } }
                let pointers = strings.map { $0.map { UnsafePointer<CChar>($0) } }
                code = pointers.withUnsafeBufferPointer {
                    muses_mpv_load(opened, stream.url.absoluteString, $0.baseAddress, $0.count)
                }
                guard code >= 0 else {
                    close()
                    continuation.resume(throwing: MpvFailure(stage: .load, code: code))
                    return
                }
                let source = DispatchSource.makeTimerSource(queue: queue)
                source.schedule(deadline: .now(), repeating: .milliseconds(50), leeway: .milliseconds(5))
                source.setEventHandler { [weak self] in self?.drain() }
                timer = source
                source.resume()
                continuation.resume()
            }
        }
    }

    func shutdown() { queue.async { [self] in close() } }

    func set(_ property: String, _ value: String, generation: UInt64) {
        queue.async { [self] in
            guard self.generation == generation, let handle else { return }
            let code = muses_mpv_set_string(handle, property, value)
            if code < 0 { emit?(generation, .failed(MpvFailure(stage: .control, code: code, property: property))) }
            else if property == "af" { emit?(generation, .equalizerConfigured) }
        }
    }

    func seek(_ seconds: Double, generation: UInt64) {
        queue.async { [self] in
            guard self.generation == generation, let handle else { return }
            let code = muses_mpv_seek(handle, seconds)
            if code < 0 { emit?(generation, .failed(MpvFailure(stage: .control, code: code, property: "seek"))) }
        }
    }

    private func close() {
        timer?.cancel()
        timer = nil
        if let handle { muses_mpv_close(handle) }
        handle = nil
        emit = nil
    }

    private func drain() {
        guard let handle else { return }
        // Bound each drain to keep queued pause/seek/replacement commands responsive.
        for _ in 0..<256 {
            var raw = muses_mpv_poll(handle)
            if raw.kind == 0 { return }
            let event: MpvEvent?
            switch raw.kind {
            case 1: event = .loaded
            case 2: event = .restarted
            case 3:
                if raw.reason == 0 { event = .ended }
                else if raw.reason == 4 { event = .failed(MpvFailure(stage: .decode, code: raw.error)) }
                else if raw.reason == 5 { event = .failed(MpvFailure(stage: .load, code: -1010)) }
                else { event = nil } // Explicit stop/quit cannot advance the facade queue.
            case 4: event = .failed(MpvFailure(stage: .decode, code: -1011))
            case 6: event = .failed(MpvFailure(stage: .eventQueue, code: -1012))
            case 5 where raw.valid != 0:
                switch raw.property {
                case 1: event = raw.number.isFinite ? .position(raw.number) : nil
                case 2: event = raw.number.isFinite ? .duration(raw.number) : nil
                case 3: event = .paused(raw.number != 0)
                case 4: event = .buffering(raw.number != 0)
                case 5: event = .seeking(raw.number != 0)
                case 6: event = .bufferPercent(raw.number)
                case 7:
                    let codec = withUnsafePointer(to: &raw.text) {
                        $0.withMemoryRebound(to: CChar.self, capacity: 128) { String(cString: $0) }
                    }
                    event = .codec(codec)
                case 8: event = MpvNumericValue.sampleRate(raw.number).map { .sampleRate($0) }
                default: event = nil
                }
            default: event = nil
            }
            if let event { emit?(generation, event) }
        }
    }
}

/// Validate C numeric properties before integer conversion; NaN/infinity must never trap the event drain.
enum MpvNumericValue {
    static func sampleRate(_ number: Double) -> Int? {
        guard number.isFinite, number > 0, number <= 768_000, number.rounded(.towardZero) == number else { return nil }
        return Int(number)
    }
}
