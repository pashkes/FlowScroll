import Foundation

/// Integrates a finite distance with exponential easing, independently of frame rate.
struct ScrollMotion {
    private(set) var remaining: Double = 0
    private var fractional: Double = 0

    var isActive: Bool { remaining != 0 || fractional != 0 }

    mutating func add(_ distance: Double) {
        if distance * remaining < 0 { reset() }
        remaining = max(-12_000, min(12_000, remaining + distance))
    }

    mutating func step(elapsed: Double, duration: Double) -> Int32 {
        guard isActive else { return 0 }
        let fraction = 1 - exp(-max(0, elapsed) / max(0.025, duration))
        let movement = remaining * fraction
        remaining -= movement
        fractional += movement
        if abs(remaining) < 0.05 {
            fractional += remaining
            remaining = 0
            let output = Int32(fractional.rounded())
            fractional = 0
            return output
        }
        let output = Int32(fractional.rounded(.towardZero))
        fractional -= Double(output)
        return output
    }

    mutating func reset() { remaining = 0; fractional = 0 }
}
