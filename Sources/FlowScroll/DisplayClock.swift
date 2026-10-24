import AppKit
import QuartzCore
import CoreVideo

/// Follows the display under the mouse. Motion stays on the event tap's main
/// thread; Core Video's real-time callback only schedules a frame.
final class DisplayClock: NSObject {
    var onFrame: (() -> Void)?
    private(set) var isRunning = false
    private(set) var displayID: CGDirectDisplayID = 0
    private var modernLink: AnyObject?
    private var legacyLink: CVDisplayLink?
    private let lock = NSLock()
    private var pending = false

    func start(at point: CGPoint) -> Bool {
        var display = CGMainDisplayID()
        var count: UInt32 = 0
        _ = CGGetDisplaysWithPoint(point, 1, &display, &count)
        if count == 0 { display = CGMainDisplayID() }
        if isRunning && displayID == display { return true }
        stop()
        displayID = display
        if #available(macOS 14.0, *) {
            guard let screen = NSScreen.screens.first(where: {
               ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == display
            }) else { return false }
            let link = screen.displayLink(target: self, selector: #selector(displayFrame))
            let maximum = Float(max(60, screen.maximumFramesPerSecond))
            link.preferredFrameRateRange = CAFrameRateRange(minimum: min(60, maximum), maximum: maximum, preferred: maximum)
            modernLink = link
            isRunning = true
            link.add(to: .main, forMode: .common)
            return true
        } else {
        // macOS 13 compatibility. At most one main-thread frame can be queued.
        var link: CVDisplayLink?
        guard CVDisplayLinkCreateWithCGDisplay(display, &link) == kCVReturnSuccess,
              let link else { return false }
        guard CVDisplayLinkSetOutputHandler(link, { [weak self] _, _, _, _, _ in
            self?.enqueueFrame()
            return kCVReturnSuccess
        }) == kCVReturnSuccess else { return false }
        legacyLink = link
        isRunning = true
        guard CVDisplayLinkStart(link) == kCVReturnSuccess else { stop(); return false }
        return true
        }
    }

    @available(macOS 14.0, *)
    @objc private func displayFrame(_ link: CADisplayLink) {
        if isRunning { onFrame?() }
    }

    private func enqueueFrame() {
        lock.lock()
        guard !pending else { lock.unlock(); return }
        pending = true
        lock.unlock()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.lock.lock(); self.pending = false; self.lock.unlock()
            if self.isRunning { self.onFrame?() }
        }
    }

    func stop() {
        isRunning = false
        if #available(macOS 14.0, *) {
            (modernLink as? CADisplayLink)?.invalidate()
        } else if let legacyLink {
            CVDisplayLinkStop(legacyLink)
        }
        modernLink = nil
        legacyLink = nil
    }

    deinit { stop() }
}
