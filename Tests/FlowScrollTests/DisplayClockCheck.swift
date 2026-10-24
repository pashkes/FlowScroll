import AppKit
import QuartzCore

@main
struct DisplayClockCheck {
    static func main() {
        _ = NSApplication.shared
        let clock = DisplayClock()
        var timestamps: [Double] = []
        clock.onFrame = { timestamps.append(CACurrentMediaTime()) }
        guard clock.start(at: .zero) else { fatalError("Display link could not start") }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.6))
        clock.stop()
        guard timestamps.count >= 10 else { fatalError("Display link did not deliver frames: \(timestamps.count)") }
        let gaps = zip(timestamps.dropFirst(), timestamps).map { $0 - $1 }
        guard gaps.allSatisfy({ $0 > 0 }) else { fatalError("Non-monotonic display frame timestamps") }
        let mean = gaps.reduce(0, +) / Double(gaps.count)
        print(String(format: "PASS: display clock: %d frames, mean %.2f ms (%.1f Hz)", timestamps.count, mean * 1000, 1 / mean))
    }
}
