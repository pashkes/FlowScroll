import Foundation

@main
struct ScrollMotionTests {
    static func main() {
        testPreservesDistanceAtDifferentFrameRates()
        testOppositeDirectionCancelsOldTail()
        testRepeatedInputAccumulates()
        testResetStopsImmediately()
        testHighResolutionWheelUsesPointDistance()
        testNativeGesturesPassThrough()
        testDiscreteWheelKeepsScaling()
        print("PASS: 7 tests (distance verified at 30, 60, 120, 144 Hz; mouse and gesture classification)")
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
        check(distance.y == 96 && distance.x == -32, "Discrete scaling changed")
    }
}
