import SwiftUI
import Testing
@testable import Muses

@Suite("Delayed text overflow")
struct DelayedMarqueeTextTests {
    @Test("Fitting text and subpixel differences stay still")
    func fittingText() {
        #expect(DelayedMarqueeMotion.distance(textWidth: 180, availableWidth: 206) == 0)
        #expect(DelayedMarqueeMotion.distance(textWidth: 206, availableWidth: 206) == 0)
        #expect(DelayedMarqueeMotion.distance(textWidth: 206.5, availableWidth: 206) == 0)
    }

    @Test("The actual keyframes hold, reveal the full tail, hold and return")
    func pauseAndTravel() {
        let distance = DelayedMarqueeMotion.distance(textWidth: 302, availableWidth: 206)
        let timeline = KeyframeTimeline(initialValue: CGFloat.zero) {
            DelayedMarqueeMotion.keyframes(distance: distance)
        }
        #expect(distance == 96)
        #expect(abs(timeline.duration - 12) < 0.001)
        #expect(abs(timeline.value(time: 1.9)) < 0.001)
        #expect(abs(timeline.value(time: 3) + 24) < 0.001)
        #expect(abs(timeline.value(time: 6) + 96) < 0.001)
        #expect(abs(timeline.value(time: 7.9) + 96) < 0.001)
        #expect(abs(timeline.value(time: 9) + 72) < 0.001)
        #expect(abs(timeline.value(time: 12)) < 0.001)
    }

    @Test("Hidden text and Reduce Motion never run a marquee")
    func visibilityAndMotion() {
        #expect(DelayedMarqueeMotion.isEnabled(distance: 96, isVisible: true, reduceMotion: false))
        #expect(!DelayedMarqueeMotion.isEnabled(distance: 96, isVisible: false, reduceMotion: false))
        #expect(!DelayedMarqueeMotion.isEnabled(distance: 96, isVisible: true, reduceMotion: true))
        #expect(!DelayedMarqueeMotion.isEnabled(distance: 0, isVisible: true, reduceMotion: false))
    }

    @Test("Unresolved or invalid geometry never starts motion")
    func invalidGeometry() {
        #expect(DelayedMarqueeMotion.distance(textWidth: 302, availableWidth: 0) == 0)
        #expect(DelayedMarqueeMotion.distance(textWidth: .infinity, availableWidth: 206) == 0)
        #expect(DelayedMarqueeMotion.distance(textWidth: 302, availableWidth: .nan) == 0)
        #expect(!DelayedMarqueeMotion.isEnabled(distance: .nan, isVisible: true, reduceMotion: false))
    }
}
