import Testing
@testable import Muses

struct VolumeScaleMappingTests {
    @Test func endpointTapsDoNotRequireAnExactBoundary() {
        for width in [10.0, 80.0, 90.0, 173.0, 304.0] {
            let tolerance = min(6, width * 0.08)
            #expect(VolumeScaleMapping.volume(at: tolerance / 2, width: width) == 0)
            #expect(VolumeScaleMapping.volume(at: width - tolerance / 2, width: width) == 1)
            #expect(VolumeScaleMapping.volume(at: tolerance, width: width) == 0)
            #expect(VolumeScaleMapping.volume(at: width - tolerance, width: width) == 1)
        }
        // The compact panel's reported 95% tap should reach its visible maximum.
        #expect(VolumeScaleMapping.volume(at: 90 * 0.95, width: 90) == 1)
    }

    @Test func endpointInterpolationIsContinuousAndMonotonic() {
        for width in [10.0, 90.0, 304.0] {
            var previous: Float = 0
            for index in 0...1000 {
                let value = VolumeScaleMapping.volume(at: width * Double(index) / 1000, width: width)
                #expect(value.isFinite && value >= previous && value <= 1)
                #expect(value - previous < 0.002)
                previous = value
            }
            #expect(previous == 1)
        }
    }

    @Test func pointerMatchesEntireVisibleScale() {
        for width in [80.0, 173.0, 304.0] {
            #expect(VolumeScaleMapping.volume(at: 0, width: width) == 0)
            #expect(VolumeScaleMapping.volume(at: width * 0.25, width: width) == 0.25)
            #expect(VolumeScaleMapping.volume(at: width / 2, width: width) == 0.5)
            #expect(VolumeScaleMapping.volume(at: width, width: width) == 1)
            #expect(VolumeScaleMapping.volume(at: -20, width: width) == 0)
            #expect(VolumeScaleMapping.volume(at: width + 20, width: width) == 1)
        }
        #expect(VolumeScaleMapping.volume(at: .nan, width: 100) == 0)
        #expect(VolumeScaleMapping.volume(at: 10, width: 0) == 0)
    }
}
