import Testing
import Foundation
@testable import Muses

/// Audio Nerd Mode pure-logic tests.
/// Only `AudioInfoModel.rows` and the static `AudioDevice` initializers are tested; Core Audio / SwiftUI / resource loading are never touched.
@Suite("Audio Nerd Mode")
struct AudioNerdTests {

    private let unknown = tr("Unknown", "未知")

    // MARK: - nil / all-empty snapshot → every optional field is Unknown

    @Test("nil track → codec/sr/depth/rate/channels/replayGain Unknown; lossless Unknown; source Unknown")
    func nilTrackFallbacks() {
        let rows = AudioInfoModel.rows(track: nil, defaultDeviceName: nil,
                                       eqPresetId: "", volume: 0.0)
        let byLabel = Dictionary(uniqueKeysWithValues: rows.map { ($0.label, $0.value) })
        #expect(byLabel[tr("Codec", "编码")] == unknown)
        #expect(byLabel[tr("Lossless", "无损")] == unknown)
        #expect(byLabel[tr("Sample Rate", "采样率")] == unknown)
        #expect(byLabel[tr("Bit Depth", "位深")] == unknown)
        #expect(byLabel[tr("Bit Rate", "比特率")] == unknown)
        #expect(byLabel[tr("Channels", "声道")] == unknown)
        #expect(byLabel[tr("Source", "来源")] == unknown)
        #expect(byLabel[tr("Output Device", "输出设备")] == unknown)
        #expect(byLabel[tr("ReplayGain", "回放增益")] == unknown)
        #expect(byLabel[tr("EQ Preset", "EQ 预设")] == unknown)
        // Volume is always computable, even with no track.
        #expect(byLabel[tr("Volume", "音量")] == "0%")
    }

    @Test("nil device name maps to Output Device Unknown")
    func nilDeviceNameFallback() {
        let t = makeYouTubeTrack()
        let rows = AudioInfoModel.rows(track: t, defaultDeviceName: nil,
                                       eqPresetId: "Flat", volume: 0.5)
        let byLabel = Dictionary(uniqueKeysWithValues: rows.map { ($0.label, $0.value) })
        #expect(byLabel[tr("Output Device", "输出设备")] == unknown)
        // The remaining fields still come from the track snapshot.
        #expect(byLabel[tr("Codec", "编码")] == "FLAC")
        #expect(byLabel[tr("Sample Rate", "采样率")] == "96 kHz")
    }

    // MARK: - Populated fields

    @Test("YouTube hi-fi snapshot populates all fields")
    func populatedYouTubeSnapshot() {
        let t = makeYouTubeTrack() // 96kHz/24-bit/5000kbps/2ch/FLAC/lossless/replayGain -6.3
        let rows = AudioInfoModel.rows(track: t, defaultDeviceName: "Built-in Speakers",
                                       eqPresetId: "Flat", volume: 0.73)
        let byLabel = Dictionary(uniqueKeysWithValues: rows.map { ($0.label, $0.value) })
        #expect(byLabel[tr("Codec", "编码")] == "FLAC")
        #expect(byLabel[tr("Lossless", "无损")] == tr("Yes", "是"))
        #expect(byLabel[tr("Sample Rate", "采样率")] == "96 kHz")
        #expect(byLabel[tr("Bit Depth", "位深")] == "24-bit")
        #expect(byLabel[tr("Bit Rate", "比特率")] == "5000 kbps")
        #expect(byLabel[tr("Channels", "声道")] == tr("Stereo", "立体声"))
        #expect(byLabel[tr("Source", "来源")] == "YouTube")
        #expect(byLabel[tr("Output Device", "输出设备")] == "Built-in Speakers")
        #expect(byLabel[tr("ReplayGain", "回放增益")] == "-6.3 dB")
        #expect(byLabel[tr("EQ Preset", "EQ 预设")] == "Flat")
        #expect(byLabel[tr("Volume", "音量")] == "73%")
    }

    @Test("YouTube source distinction with lossy and mono")
    func youTubeSourceLossyMono() {
        let t = TrackSnapshot(
            id: UUID(), title: "YT", artist: "A",
            albumTitle: nil, durationSeconds: 180,
            youTubeId: "vid123",
            artworkUrl: "https://i.ytimg.com/vi/vid123/hqdefault.jpg",
            sampleRate: 44100, bitDepth: nil, codec: "opus", isLossless: false,
            liked: false, lyrics: nil, replayGain: nil,
            bitRate: 128_000, channels: 1, lyricsOffsetMs: nil)
        let rows = AudioInfoModel.rows(track: t, defaultDeviceName: nil,
                                       eqPresetId: "Vocal", volume: 1.0)
        let byLabel = Dictionary(uniqueKeysWithValues: rows.map { ($0.label, $0.value) })
        #expect(byLabel[tr("Source", "来源")] == "YouTube")
        #expect(byLabel[tr("Lossless", "无损")] == tr("No", "否"))
        #expect(byLabel[tr("Bit Depth", "位深")] == unknown) // YouTube has no bit depth
        #expect(byLabel[tr("Channels", "声道")] == tr("Mono", "单声道"))
        #expect(byLabel[tr("Sample Rate", "采样率")] == "44.1 kHz")
        #expect(byLabel[tr("Bit Rate", "比特率")] == "128 kbps")
        #expect(byLabel[tr("ReplayGain", "回放增益")] == unknown)
        #expect(byLabel[tr("EQ Preset", "EQ 预设")] == "Vocal")
        #expect(byLabel[tr("Volume", "音量")] == "100%")
    }

    @Test("5.1 multichannel displays numeric channel count")
    func multichannelNumeric() {
        let t = TrackSnapshot(
            id: UUID(), title: "Surround", artist: "A",
            albumTitle: nil, durationSeconds: 100,
            youTubeId: "test-video",
            artworkUrl: nil,
            sampleRate: 48000, bitDepth: 24, codec: "FLAC", isLossless: true,
            liked: false, lyrics: nil, replayGain: 0.0,
            bitRate: 4_600_000, channels: 6, lyricsOffsetMs: nil)
        let rows = AudioInfoModel.rows(track: t, defaultDeviceName: "AVR",
                                       eqPresetId: "Flat", volume: 0.5)
        let byLabel = Dictionary(uniqueKeysWithValues: rows.map { ($0.label, $0.value) })
        #expect(byLabel[tr("Channels", "声道")] == "6")
        #expect(byLabel[tr("ReplayGain", "回放增益")] == "+0.0 dB")
    }

    @Test("Empty EQ preset ID maps to Unknown")
    func emptyEQPresetFallback() {
        let t = makeYouTubeTrack()
        let rows = AudioInfoModel.rows(track: t, defaultDeviceName: nil,
                                       eqPresetId: "", volume: 0.0)
        let byLabel = Dictionary(uniqueKeysWithValues: rows.map { ($0.label, $0.value) })
        #expect(byLabel[tr("EQ Preset", "EQ 预设")] == unknown)
    }

    @Test("Audio Info displays the selected custom preset name instead of its stored UUID")
    func customEQPresetName() {
        let selectedID = UUID()
        let otherID = UUID()
        let names = [selectedID: "Listening", otherID: "Other preset"]
        let rows = AudioInfoModel.rows(track: nil, defaultDeviceName: nil,
            eqPresetId: selectedID.uuidString.lowercased(), volume: 0,
            customPresetNames: names)
        let displayed = rows.first { $0.label == tr("EQ Preset", "EQ 预设") }?.value
        #expect(displayed == "Listening")
        #expect(displayed != selectedID.uuidString)
        #expect(AudioInfoModel.eqPresetName(id: otherID.uuidString, customNames: names, bypassed: false)
                == "Other preset")
    }

    @Test("built-in and unsaved custom EQ names retain their distinct meanings")
    func builtInAndCustomEQPresetNames() {
        for preset in BuiltinEQPresets.all {
            #expect(AudioInfoModel.eqPresetName(id: preset.name, customNames: [:], bypassed: false)
                    == preset.name)
        }
        #expect(AudioInfoModel.eqPresetName(id: "Custom", customNames: [:], bypassed: false)
                == tr("Custom", "自定义", zhHant: "自訂"))
    }

    @Test("deleted, empty and invalid preset identities never appear as names or imply Flat")
    func unresolvedEQPresetNames() {
        let selectedID = UUID()
        let replacementID = UUID()
        let names = [selectedID: "Listening", replacementID: "Listening"]
        #expect(AudioInfoModel.eqPresetName(id: selectedID.uuidString, customNames: names, bypassed: false)
                == "Listening")
        // A same-named row with another identity cannot replace the deleted selection.
        #expect(AudioInfoModel.eqPresetName(id: selectedID.uuidString,
            customNames: [replacementID: "Listening"], bypassed: false) == unknown)
        for invalidID in ["", " ", "not-a-preset"] {
            #expect(AudioInfoModel.eqPresetName(id: invalidID, customNames: names, bypassed: false) == unknown)
        }
        #expect(AudioInfoModel.eqPresetName(id: selectedID.uuidString,
            customNames: [selectedID: " \n "], bypassed: false) == unknown)
    }

    @Test("bypass is reported ahead of named or unavailable EQ presets")
    func bypassedEQPresetName() {
        let selectedID = UUID()
        for id in [selectedID.uuidString, "Flat", "Custom", ""] {
            let rows = AudioInfoModel.rows(track: nil, defaultDeviceName: nil,
                eqPresetId: id, volume: 0, customPresetNames: [selectedID: "Listening"], eqBypassed: true)
            #expect(rows.first { $0.label == tr("EQ Preset", "EQ 预设") }?.value
                    == tr("Bypassed", "已旁路", zhHant: "已旁路"))
        }
    }

    @Test("Row count is fixed at 11 and labels are unique")
    func rowCountAndUniqueLabels() {
        let rows = AudioInfoModel.rows(track: nil, defaultDeviceName: nil,
                                       eqPresetId: "", volume: 0.0)
        #expect(rows.count == 11)
        let labels = rows.map(\.label)
        #expect(Set(labels).count == labels.count)
    }

    // MARK: - AudioDevice initializers (pure values, no Core Audio)

    @Test("AudioDevice equality and identity semantics")
    func audioDeviceValueSemantics() {
        let a = AudioDeviceService.AudioDevice(id: 42, name: "Dev A", channels: 2)
        let b = AudioDeviceService.AudioDevice(id: 42, name: "Dev A", channels: 2)
        let c = AudioDeviceService.AudioDevice(id: 43, name: "Dev A", channels: 2)
        #expect(a == b)
        #expect(a != c)
        #expect(a.id == 42)
    }

    // MARK: - helpers

    @Test("Fractional kilohertz retain the original integer-Hz precision")
    func fractionalSampleRates() {
        for (rate, expected) in [(44100, "44.1 kHz"), (22050, "22.05 kHz"), (44101, "44.101 kHz"),
                                 (48000, "48 kHz"), (96000, "96 kHz")] {
            #expect(AudioQualityInfo.sampleRateLabel(rate) == expected)
            let rows = AudioInfoModel.rows(track: makeYouTubeTrack(sampleRate: rate),
                                           defaultDeviceName: nil, eqPresetId: "Flat", volume: 0)
            #expect(rows.first { $0.label == tr("Sample Rate", "采样率") }?.value == expected)
        }
    }

    private func makeYouTubeTrack(sampleRate: Int = 96000) -> TrackSnapshot {
        TrackSnapshot(
            id: UUID(), title: "Song", artist: "Artist",
            albumTitle: "Album", durationSeconds: 240,
            youTubeId: "test-video",
            artworkUrl: nil,
            sampleRate: sampleRate, bitDepth: 24, codec: "FLAC", isLossless: true,
            liked: true, lyrics: nil, replayGain: -6.3,
            bitRate: 5_000_000, channels: 2, lyricsOffsetMs: nil)
    }
}
