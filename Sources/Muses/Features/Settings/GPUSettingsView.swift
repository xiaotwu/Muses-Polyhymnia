import SwiftUI

/// GPU acceleration settings (Metal spectrum rendering toggle).
struct GPUSettingsView: View {
    @AppStorage("reducedPlaybackVisuals") private var reducedVisuals = false
    @AppStorage(PrefKey.gpuAcceleration) var gpuAcceleration = true

    var body: some View {
        Section {
            SettingsExplainedToggle(title: tr("Reduced playback visuals", "省电播放视觉模式"), isOn: $reducedVisuals,
                information: tr("Stops vinyl rotation and spectrum sampling while preserving audio playback. This preference also applies when those surfaces become visible again.", "停止黑胶旋转与频谱采样，保留音频播放。重新显示相关界面时仍保持此偏好。"))
            SettingsExplainedToggle(title: tr("Metal spectrum", "Metal 频谱"), isOn: $gpuAcceleration,
                information: tr("Applies to the spectrum display in Audio Info.",
                                "用于音频信息中的频谱显示。"))
        } header: { Text(tr("Performance", "性能")).font(MusesTypography.headline.weight(.semibold)) }
    }
}
