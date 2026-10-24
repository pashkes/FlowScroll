import Foundation

@main
struct ScrollMotionTests {
    static func main() {
        testPreservesDistanceAtDifferentFrameRates()
        testOppositeDirectionCancelsOldTail()
        testRepeatedInputAccumulates()
        testResetStopsImmediately()
        testAnimationHasFiniteDuration()
        testAnimationHasGentleStart()
        testNewImpulseDoesNotRestartOldAnimation()
        testInputBetweenDisplayFrames()
        testDroppedFramesKeepDistance()
        testAccelerationIsBoundedAndResets()
        testHighResolutionWheelUsesPointDistance()
        testNativeGesturesPassThrough()
        testDiscreteWheelKeepsScaling()
        print("PASS: 13 tests (finite impulses, gentle attack, overlapping input, display timing, input classification, acceleration)")
    }

    static func check(_ condition: Bool, _ message: String) {
        guard condition else { fatalError(message) }
    }

    static func testPreservesDistanceAtDifferentFrameRates() {
        for fps in [30.0, 60, 120, 144] {
            var motion = ScrollMotion()
            motion.add(160)
            var total = 0
            for _ in 0..<2000 {
                total += Int(motion.step(elapsed: 1 / fps, duration: 0.12))
                if !motion.isActive { break }
            }
            check(total == 160, "Lost distance at \(fps) Hz: \(total)")
            check(!motion.isActive, "Motion did not settle")
        }
    }

    static func testOppositeDirectionCancelsOldTail() {
        var motion = ScrollMotion()
        motion.add(500)
        _ = motion.step(elapsed: 0.01, duration: 0.2)
        motion.add(-32)
        var total = 0
        for _ in 0..<1000 { total += Int(motion.step(elapsed: 0.01, duration: 0.12)) }
        check(total == -32, "Direction reversal retained the old tail")
    }

    static func testRepeatedInputAccumulates() {
        var motion = ScrollMotion()
        var total = 0
        for _ in 0..<20 {
            motion.add(16)
            total += Int(motion.step(elapsed: 0.008, duration: 0.12))
        }
        for _ in 0..<1000 { total += Int(motion.step(elapsed: 0.008, duration: 0.12)) }
        check(total == 320, "Repeated input lost distance: \(total)")
    }

    static func testResetStopsImmediately() {
        var motion = ScrollMotion()
        motion.add(100)
        motion.reset()
        check(!motion.isActive, "Reset left active motion")
        check(motion.step(elapsed: 1, duration: 0.12) == 0, "Reset emitted a scroll")
    }

    static func testAnimationHasFiniteDuration() {
        var motion = ScrollMotion()
        motion.add(90)
        var total = 0
        for _ in 0..<36 { total += Int(motion.step(elapsed: 0.01, duration: 0.36)) }
        check(!motion.isActive && total == 90,
              "360 ms animation must end at 360 ms, without a long quantized tail")
    }

    static func testAnimationHasGentleStart() {
        var motion = ScrollMotion()
        motion.add(900)
        let first = motion.step(elapsed: 0.03, duration: 0.36)
        let second = motion.step(elapsed: 0.03, duration: 0.36)
        check(first < second, "Wheel impulse must accelerate smoothly instead of jumping to peak speed")
    }

    static func testNewImpulseDoesNotRestartOldAnimation() {
        var combined = ScrollMotion()
        var first = ScrollMotion()
        var second = ScrollMotion()
        combined.add(90); first.add(90)
        var combinedTotal = 0
        var referenceTotal = 0
        for frame in 0..<54 {
            if frame == 18 { combined.add(90); second.add(90) }
            combinedTotal += Int(combined.step(elapsed: 0.01, duration: 0.36))
            referenceTotal += Int(first.step(elapsed: 0.01, duration: 0.36))
            referenceTotal += Int(second.step(elapsed: 0.01, duration: 0.36))
            check(abs(combinedTotal - referenceTotal) <= 1, "New impulse restarted the old animation")
        }
        check(!combined.isActive && combinedTotal == 180, "Overlapping impulses must complete on their own schedules")
    }

    static func testInputBetweenDisplayFrames() {
        var motion = ScrollMotion()
        motion.add(90, delay: 0.009)
        check(motion.step(elapsed: 0.009, duration: 0.36) == 0,
              "New input must not include time before it arrived")
        var total = 0
        for _ in 0..<36 { total += Int(motion.step(elapsed: 0.01, duration: 0.36)) }
        check(total == 90 && !motion.isActive, "Delayed pulse lost distance")
    }

    static func testDroppedFramesKeepDistance() {
        var motion = ScrollMotion()
        motion.add(-90)
        var total = 0
        for dt in [0.016, 0.017, 0.075, 0.012, 0.24] {
            total += Int(motion.step(elapsed: dt, duration: 0.36))
        }
        check(total == -90 && !motion.isActive, "Dropped display frames must not stretch animation or lose distance")
    }

    static func testHighResolutionWheelUsesPointDistance() {
        let input = ScrollInput(continuous: true, pointY: 12, pointX: -3)
        guard let distance = input.distance(speed: 2, reversed: false) else {
            check(false, "Phase-free pixel wheel was bypassed; inertia never starts")
            return
        }
        check(distance.y == 24 && distance.x == -6, "Pixel wheel must preserve point distance")
        var motion = ScrollMotion()
        motion.add(distance.y)
        _ = motion.step(elapsed: 1.0 / 120, duration: 0.35)
        check(motion.isActive, "Wheel should leave an inertia tail")
        let reversed = input.distance(speed: 1, reversed: true)!
        check(reversed.y == -12 && reversed.x == 3, "Pixel wheel reversal failed")
    }

    static func testNativeGesturesPassThrough() {
        for phase: Int64 in [1, 2, 4, 8, 16, 128] {
            check(ScrollInput(continuous: true, phase: phase, pointY: 12).distance(speed: 1, reversed: false) == nil,
                  "Native scroll phase must pass through")
        }
        check(ScrollInput(continuous: true, momentumPhase: 2, pointY: 12).distance(speed: 1, reversed: false) == nil,
              "Native momentum must pass through")
    }

    static func testDiscreteWheelKeepsScaling() {
        let distance = ScrollInput(continuous: false, lineY: 3, lineX: -1).distance(speed: 2, reversed: false)!
        check(distance.y == 120 && distance.x == -120, "Discrete wheel should use direction and a 60-point step at 1x")
        let oneLine = ScrollInput(continuous: false, lineY: 1).distance(speed: 2, reversed: false)!
        check(oneLine.y == distance.y, "System line acceleration must not change a single wheel step")
    }

    static func testAccelerationIsBoundedAndResets() {
        var acceleration = WheelAcceleration()
        check(acceleration.factor(at: 1, direction: 1) == 1, "First notch must not accelerate")
        let fast = acceleration.factor(at: 1.01, direction: 1)
        check(fast > 1 && fast <= 7, "Fast rotation should accelerate")
        check(acceleration.factor(at: 1.011, direction: 1) == 7, "Acceleration must be capped")
        check(acceleration.factor(at: 1.02, direction: -1) == 1, "Reversal must reset acceleration")
        check(acceleration.factor(at: 1.5, direction: -1) == 1, "Pause must reset acceleration")
        acceleration.reset()
        check(acceleration.factor(at: 1.501, direction: -1) == 1, "Explicit reset must clear acceleration")
    }
}
