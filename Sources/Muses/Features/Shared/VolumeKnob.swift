import SwiftUI

/// Compact app-volume control. Drag follows continuous angular movement;
/// clicks map to the 270-degree sweep and never alter system volume.
struct VolumeKnob: View {
    @Environment(PlaybackService.self) private var playback
    @FocusState private var focused: Bool
    @State private var previousAngle: Double?
    @State private var dragValue: Double = 0
    @State private var centralDrag = false
    var size: CGFloat = 40

    var body: some View {
        let value = Double(playback.volume)
        ZStack {
            Circle().trim(from: 0, to: 0.75)
                .stroke(BrandColors.textPrimary.opacity(0.16), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(135))
            Circle().trim(from: 0, to: value * 0.75)
                .stroke(focused ? BrandColors.heading : BrandColors.accent,
                        style: StrokeStyle(lineWidth: focused ? 4 : 3, lineCap: .round))
                .rotationEffect(.degrees(135))
            Text("\(Int((value * 100).rounded()))")
                .font(MusesTypography.system(size: 10, weight: .semibold).monospacedDigit())
                .foregroundStyle(BrandColors.textPrimary)
        }
        .padding(4)
        .frame(width: size, height: size)
        .contentShape(Circle())
        .background { VolumeScrollInput { delta in
            playback.setVolume(VolumeScaleMapping.adjusted(playback.volume, delta: delta))
        }.allowsHitTesting(false) }
        .gesture(DragGesture(minimumDistance: 0).onChanged { gesture in
            focused = true
            let angle = VolumeKnobMapping.angle(at: gesture.location, size: size)
            if previousAngle == nil {
                dragValue = Double(playback.volume)
                centralDrag = isInCenter(gesture.startLocation)
            }
            if centralDrag {
                if abs(gesture.translation.height) >= 3 {
                    playback.setVolume(Float(min(1, max(0, dragValue - gesture.translation.height / 120))))
                }
            } else if let previousAngle {
                dragValue += VolumeKnobMapping.rotation(from: previousAngle, to: angle) / (1.5 * .pi)
                dragValue = min(1, max(0, dragValue))
                playback.setVolume(Float(dragValue))
            }
            previousAngle = angle
        }.onEnded { gesture in
            if !centralDrag, hypot(gesture.translation.width, gesture.translation.height) < 3 {
                playback.setVolume(VolumeKnobMapping.volume(at: gesture.location, size: size))
            }
            previousAngle = nil
        })
        .focusable().focusEffectDisabled().focused($focused)
        .onKeyPress(.leftArrow) { adjust(-0.05); return .handled }
        .onKeyPress(.downArrow) { adjust(-0.05); return .handled }
        .onKeyPress(.rightArrow) { adjust(0.05); return .handled }
        .onKeyPress(.upArrow) { adjust(0.05); return .handled }
        .help(tr("Volume: \(Int((value * 100).rounded()))%. Drag or scroll to adjust.",
                 "音量：\(Int((value * 100).rounded()))%。拖动或双指滚动调整。"))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tr("Volume", "音量"))
        .accessibilityValue("\(Int((value * 100).rounded()))%")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: adjust(0.05)
            case .decrement: adjust(-0.05)
            @unknown default: break
            }
        }
    }

    private func adjust(_ delta: Float) { playback.setVolume(min(1, max(0, playback.volume + delta))) }
    private func isInCenter(_ point: CGPoint) -> Bool {
        hypot(point.x - size / 2, point.y - size / 2) < size * 0.28
    }
}

enum VolumeKnobMapping {
    static func angle(at point: CGPoint, size: CGFloat) -> Double {
        atan2(Double(point.y - size / 2), Double(point.x - size / 2))
    }
    static func rotation(from start: Double, to end: Double) -> Double {
        atan2(sin(end - start), cos(end - start))
    }
    static func volume(at point: CGPoint, size: CGFloat) -> Float {
        let raw = (angle(at: point, size: size) - 0.75 * .pi + 2 * .pi)
            .truncatingRemainder(dividingBy: 2 * .pi)
        if raw > 1.5 * .pi { return raw < 1.75 * .pi ? 1 : 0 }
        return Float(min(1, max(0, raw / (1.5 * .pi))))
    }
}
