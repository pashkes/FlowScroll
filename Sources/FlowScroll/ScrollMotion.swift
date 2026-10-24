import Foundation

/// Each wheel impulse follows its own finite curve. New input adds velocity
/// gradually instead of restarting a shared decaying accumulator.
struct ScrollMotion {
    private struct Impulse {
        var distance: Double
        var age: Double
        var emitted: Double = 0
    }
    private var impulses: [Impulse] = []
    private var fractional: Double = 0
    private(set) var remaining: Double = 0

    var isActive: Bool { !impulses.isEmpty }

    mutating func add(_ distance: Double, delay: Double = 0) {
        guard distance.isFinite, distance != 0 else { return }
        if distance * remaining < 0 { reset() }
        let available = max(0, 12_000 - abs(remaining))
        let bounded = (distance < 0 ? -1.0 : 1.0) * min(abs(distance), available)
        guard bounded != 0 else { return }
        if impulses.count >= 512 { return }
        impulses.append(Impulse(distance: bounded, age: -max(0, delay)))
        remaining += bounded
    }

    mutating func step(elapsed: Double, duration: Double) -> Int32 {
        guard isActive else { return 0 }
        let duration = max(0.04, duration)
        var movement = 0.0
        for index in impulses.indices {
            impulses[index].age += max(0, elapsed)
            let progress = min(1, max(0, impulses[index].age / duration))
            // Integral of 20t(1-t)^3: short acceleration, longer deceleration.
            let eased = progress * progress * (10 + progress * (-20 + progress * (15 - 4 * progress)))
            let position = impulses[index].distance * eased
            movement += position - impulses[index].emitted
            impulses[index].emitted = position
        }
        impulses.removeAll { $0.age >= duration - 1e-9 }
        remaining = impulses.reduce(0) { $0 + $1.distance - $1.emitted }
        fractional += movement
        let output: Int32
        if impulses.isEmpty {
            output = Int32(fractional.rounded())
            fractional = 0
        } else {
            output = Int32(fractional.rounded(.towardZero))
            fractional -= Double(output)
        }
        return output
    }

    mutating func reset() {
        impulses.removeAll(keepingCapacity: true)
        remaining = 0
        fractional = 0
    }
}
