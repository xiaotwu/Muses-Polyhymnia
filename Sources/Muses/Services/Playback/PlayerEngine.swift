import Foundation

@MainActor
protocol PlayerEngine: AnyObject {
    var state: PlayerState { get }
    /// Completion callback: invoked when the current track finishes playing
    /// (replacing the old isPlaying flip detection). Set by PlaybackService to
    /// advance the queue seamlessly and preload the next track.
    var onCompletion: (@MainActor () -> Void)? { get set }
    /// Resolve the currently focused selection without changing transport or the next-track slot.
    func prewarmSelection(_ track: TrackSnapshot) async
    func prewarmSelections(_ tracks: [TrackSnapshot]) async
    func load(_ track: TrackSnapshot) async throws
    /// Prepares the next source without granting playback intent. Engines may
    /// resolve only, or additionally prepare a standby decoder when supported.
    func prepare(_ track: TrackSnapshot) async
    /// Returns true only after a prepared decoder has actually switched to the
    /// expected track. A resolved URL alone returns false and uses normal load.
    @discardableResult
    func playPrepared(expectedTrackID: UUID) -> Bool
    func play()
    func pause()
    func toggle()
    func seek(to time: Double)
    func setVolume(_ v: Float)
    func setPlaybackRate(_ rate: Float)
    func setEQ(_ bands: [EQBand])
    func installSpectrumTap(_ handler: @escaping (SpectrumFrame) -> Void)
    func removeSpectrumTap()
}

extension PlayerEngine {
    func prewarmSelection(_ track: TrackSnapshot) async {}
    func prewarmSelections(_ tracks: [TrackSnapshot]) async {
        if let track = tracks.first { await prewarmSelection(track) }
    }
    func setPlaybackRate(_ rate: Float) {}
}
