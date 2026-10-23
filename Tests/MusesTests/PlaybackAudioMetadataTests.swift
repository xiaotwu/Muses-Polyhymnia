import Foundation
import Testing
@testable import Muses

@Suite("Resolved playback audio metadata")
struct PlaybackAudioMetadataTests {
    @Test("The active stream replaces stale library quality claims")
    func activeSourceOverridesLibraryMetadata() {
        let track = TrackSnapshot(id: UUID(), title: "Track", artist: "Artist",
            albumTitle: nil, durationSeconds: 180, youTubeId: "test-video", artworkUrl: nil,
            sampleRate: 96000, bitDepth: 24, codec: "FLAC", isLossless: true,
            bitRate: 5_000_000, channels: 2)
        let actual = AudioQualityInfo(sampleRate: 48000, bitDepth: 0, codec: "Opus",
            isLossless: false, bitrateKbps: 128.4, formatID: "251")
        let rows = AudioInfoModel.rows(track: track, defaultDeviceName: nil,
            eqPresetId: "Flat", volume: 0.5, playbackQuality: actual)
        let values = Dictionary(uniqueKeysWithValues: rows.map { ($0.label, $0.value) })
        #expect(values[tr("Codec", "编码")] == "Opus")
        #expect(values[tr("Sample Rate", "采样率")] == "48 kHz")
        #expect(values[tr("Bit Rate", "比特率")] == "128.4 kbps")
        #expect(values[tr("Bit Depth", "位深")] == AudioInfoModel.unknown)
        #expect(values[tr("Lossless", "无损")] == tr("No", "否"))
    }

    @Test("Unknown active bitrate does not fall back to a library estimate")
    func unknownStreamBitrateStaysUnknown() {
        let track = TrackSnapshot(id: UUID(), title: "Track", artist: "Artist",
            albumTitle: nil, durationSeconds: 180, youTubeId: "test-video", artworkUrl: nil,
            sampleRate: 96000, bitDepth: 24, codec: "FLAC", isLossless: true,
            bitRate: 5_000_000)
        let actual = AudioQualityInfo(sampleRate: 0, bitDepth: 0, codec: "", isLossless: false)
        let rows = AudioInfoModel.rows(track: track, defaultDeviceName: nil,
            eqPresetId: "Flat", volume: 0.5, playbackQuality: actual)
        for label in [tr("Codec", "编码"), tr("Sample Rate", "采样率"),
                      tr("Bit Depth", "位深"), tr("Bit Rate", "比特率"), tr("Lossless", "无损")] {
            #expect(rows.first { $0.label == label }?.value == AudioInfoModel.unknown)
        }
    }

    @Test("Invalid or stale bitrate values never become displayed quality")
    func invalidBitratesAreUnavailable() {
        for value in [Double.nan, Double.infinity, -1, 0] {
            let actual = AudioQualityInfo(sampleRate: 0, bitDepth: 0, codec: "Opus",
                isLossless: false, bitrateKbps: value)
            #expect(actual.bitrateKbps == nil)
            #expect(actual.bitrateLabel == nil)
        }
        let stale = AudioQualityInfo(sampleRate: 48000, bitDepth: 0, codec: "Opus",
            isLossless: false, bitrateKbps: 256)
        let rows = AudioInfoModel.rows(track: nil, defaultDeviceName: nil,
            eqPresetId: "Flat", volume: 0.5, playbackQuality: stale)
        #expect(rows.first { $0.label == tr("Bit Rate", "比特率") }?.value == AudioInfoModel.unknown)
    }
}
