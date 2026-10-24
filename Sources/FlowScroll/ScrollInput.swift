import Foundation

/// Phase-bearing events belong to a native gesture; phase-free pixel events may
/// come from high-resolution mouse wheels (for example Logitech drivers).
struct ScrollInput {
    var continuous: Bool
    var phase: Int64 = 0
    var momentumPhase: Int64 = 0
    var lineY: Double = 0
    var lineX: Double = 0
    var pointY: Double = 0
    var pointX: Double = 0

    var isNativeGesture: Bool { phase != 0 || momentumPhase != 0 }

    func distance(speed: Double, reversed: Bool) -> (y: Double, x: Double)? {
        guard !isNativeGesture else { return nil }
        let scale = speed * (reversed ? -1.0 : 1.0)
        if continuous { return (pointY * scale, pointX * scale) }
        return (lineY * 16 * scale, lineX * 16 * scale)
    }
}
