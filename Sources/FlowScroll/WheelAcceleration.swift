import Foundation

struct WheelAcceleration {
    private var lastTime: Double?
    private var lastDirection = 0.0

    mutating func factor(at time: Double, direction: Double) -> Double {
        let sign = direction < 0 ? -1.0 : 1.0
        defer { lastTime = time; lastDirection = sign }
        guard let lastTime, sign == lastDirection else { return 1 }
        let interval = time - lastTime
        guard interval > 0, interval < 0.07 else { return 1 }
        return min(7, (1 + 0.07 / interval) / 2)
    }

    mutating func reset() { lastTime = nil; lastDirection = 0 }
}
