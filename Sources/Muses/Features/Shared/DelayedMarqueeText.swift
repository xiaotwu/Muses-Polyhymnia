import SwiftUI

/// A single accessible line. Only visible overflow gets a local offset animation.
struct DelayedMarqueeText: View {
    let text: String
    let font: Font
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var textWidth: CGFloat = 0
    @State private var availableWidth: CGFloat = 0
    @State private var isVisible = false

    private var distance: CGFloat {
        DelayedMarqueeMotion.distance(textWidth: textWidth, availableWidth: availableWidth)
    }

    private var animates: Bool {
        DelayedMarqueeMotion.isEnabled(distance: distance, isVisible: isVisible, reduceMotion: reduceMotion)
    }

    var body: some View {
        Text(text)
            .font(font)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(animates ? 0 : 1)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { availableWidth = $0 }
            .overlay(alignment: .leading) {
                let measured = Text(text)
                    .font(font)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: true)
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { textWidth = $0 }
                if animates {
                    measured
                        .keyframeAnimator(initialValue: CGFloat.zero) { content, offset in
                            content.offset(x: offset)
                        } keyframes: { _ in
                            DelayedMarqueeMotion.keyframes(distance: distance)
                        }
                        .id(AnimationIdentity(text: text, distance: distance))
                } else {
                    measured.hidden()
                }
            }
            .clipped()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(text)
            .onAppear { isVisible = true }
            .onDisappear { isVisible = false }
    }

    private struct AnimationIdentity: Hashable {
        let text: String
        let distance: CGFloat
    }
}

enum DelayedMarqueeMotion {
    static let pause: TimeInterval = 2
    static let pointsPerSecond: Double = 24

    static func distance(textWidth: CGFloat, availableWidth: CGFloat) -> CGFloat {
        guard textWidth.isFinite, availableWidth.isFinite, availableWidth > 0,
              textWidth - availableWidth > 1 else { return 0 }
        return textWidth - availableWidth
    }

    static func isEnabled(distance: CGFloat, isVisible: Bool, reduceMotion: Bool) -> Bool {
        isVisible && !reduceMotion && distance.isFinite && distance > 1
    }

    static func keyframes(distance: CGFloat) -> some Keyframes<CGFloat> {
        let travel = Double(distance) / pointsPerSecond
        return KeyframeTrack(\CGFloat.self) {
            LinearKeyframe(CGFloat.zero, duration: pause)
            LinearKeyframe(-distance, duration: travel)
            LinearKeyframe(-distance, duration: pause)
            LinearKeyframe(CGFloat.zero, duration: travel)
        }
    }

}
