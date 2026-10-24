import AppKit
import ApplicationServices
import Combine
import QuartzCore

final class ScrollEngine: ObservableObject {
    @Published private(set) var hasPermission = false
    @Published private(set) var running = false
    @Published private(set) var inputStatus = "Покрутите колёсико для проверки"
    @Published private(set) var originalRunning = false
    private var latestInputStatus = "Покрутите колёсико для проверки"
    private var handledEvents = 0
    private var emittedFrames = 0
    private var pixelEvents = 0
    private var gestureEvents = 0
    private let settings: Settings
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let animation = DisplayClock()
    private var permissionTimer: Timer?
    private var subscriptions = Set<AnyCancellable>()
    private var observers: [NSObjectProtocol] = []
    private var vertical = ScrollMotion()
    private var horizontal = ScrollMotion()
    private var acceleration = WheelAcceleration()
    private var lastFrame = CACurrentMediaTime()
    private var displayFrames = 0
    private var longestFrame = 0.0
    private var eventLocation = CGPoint.zero
    private var eventFlags: CGEventFlags = []
    private var targetPID: pid_t = 0
    private let marker: Int64 = 0x464C4F575343
    private let modifierMask: CGEventFlags = [.maskShift, .maskControl, .maskAlternate, .maskCommand, .maskSecondaryFn]

    init(settings: Settings) {
        self.settings = settings
        animation.onFrame = { [weak self] in self?.tick() }
        settings.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.cancelMotion(); self?.refresh() }
        }.store(in: &subscriptions)
        for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.willSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.cancelMotion() })
        }
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            self?.refresh()
            self?.publishDiagnostics()
        }
        permissionTimer = timer
        RunLoop.main.add(timer, forMode: .common)
        refresh()
    }

    func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        refresh()
    }

    func openPermissions() {
        requestPermission()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func refresh() {
        let original = NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == "com.galambalazs.SmoothScroll" }
        if originalRunning != original { originalRunning = original }
        let trusted = AXIsProcessTrusted()
        if hasPermission != trusted { hasPermission = trusted }
        guard trusted, settings.enabled else { stop(); return }
        if let tap {
            if !CGEvent.tapIsEnabled(tap: tap) { CGEvent.tapEnable(tap: tap, enable: true) }
            let active = CGEvent.tapIsEnabled(tap: tap)
            if running != active { running = active }
            return
        }
        let mask = CGEventMask(1) << CGEventType.scrollWheel.rawValue
        guard let newTap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
            options: .defaultTap, eventsOfInterest: mask,
            callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                return Unmanaged<ScrollEngine>.fromOpaque(context).takeUnretainedValue().handle(type: type, event: event)
            }, userInfo: Unmanaged.passUnretained(self).toOpaque()) else { return }
        tap = newTap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: newTap, enable: true)
        running = true
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            cancelMotion()
            if let tap, settings.enabled { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard event.getIntegerValueField(.eventSourceUserData) != marker else { return Unmanaged.passUnretained(event) }
        guard settings.enabled,
              !event.flags.contains(.maskControl), !event.flags.contains(.maskCommand),
              !settings.excludedApps.contains(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "") else {
            cancelMotion()
            latestInputStatus = "Пропущено: выключено, исключение или Ctrl/⌘"
            return Unmanaged.passUnretained(event)
        }
        let input = ScrollInput(
            continuous: event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0,
            phase: event.getIntegerValueField(.scrollWheelEventScrollPhase),
            momentumPhase: event.getIntegerValueField(.scrollWheelEventMomentumPhase),
            lineY: event.getDoubleValueField(.scrollWheelEventDeltaAxis1),
            lineX: event.getDoubleValueField(.scrollWheelEventDeltaAxis2),
            pointY: Double(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)),
            pointX: Double(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2)))
        guard let distance = input.distance(speed: settings.speed, reversed: settings.reversed) else {
            gestureEvents += 1
            latestInputStatus = "Системный жест: без обработки"
            cancelMotion()
            return Unmanaged.passUnretained(event)
        }
        // Create the replacement before swallowing input, so allocation failure passes through.
        guard CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: 0, wheel2: 0, wheel3: 0) != nil else {
            return Unmanaged.passUnretained(event)
        }
        let y = distance.y
        let x = distance.x
        guard x != 0 || y != 0 else { return Unmanaged.passUnretained(event) }
        if event.flags != eventFlags { cancelMotion() }
        eventLocation = event.location
        eventFlags = event.flags
        targetPID = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0
        let wasAnimating = animation.isRunning
        let now = CACurrentMediaTime()
        guard animation.start(at: eventLocation) else {
            latestInputStatus = "Нет синхронизации с экраном: системная прокрутка"
            return Unmanaged.passUnretained(event)
        }
        if !wasAnimating { lastFrame = now }
        handledEvents += 1
        if input.continuous { pixelEvents += 1 }
        latestInputStatus = input.continuous ? "Пиксельное колёсико: инерция включена" : "Обычное колёсико: инерция включена"
        let delay = max(0, now - lastFrame)
        let gain = !input.continuous && settings.accelerate
            ? acceleration.factor(at: now, direction: y != 0 ? y : x) : 1
        vertical.add(y * gain, delay: delay)
        horizontal.add(x * gain, delay: delay)
        return nil
    }

    private func tick() {
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == targetPID,
              CGEventSource.flagsState(.combinedSessionState).intersection(modifierMask) == eventFlags.intersection(modifierMask) else { cancelMotion(); return }
        let now = CACurrentMediaTime()
        let elapsed = max(0, now - lastFrame)
        displayFrames += 1
        longestFrame = max(longestFrame, elapsed)
        lastFrame = now
        let y = vertical.step(elapsed: elapsed, duration: settings.duration)
        let x = horizontal.step(elapsed: elapsed, duration: settings.duration)
        if x != 0 || y != 0,
           let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: y, wheel2: x, wheel3: 0) {
            event.location = eventLocation
            event.flags = eventFlags
            event.setIntegerValueField(.eventSourceUserData, value: marker)
            event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
            event.post(tap: .cghidEventTap)
            emittedFrames += 1
        }
        if !vertical.isActive && !horizontal.isActive { cancelMotion() }
    }

    private func cancelMotion() {
        animation.stop()
        vertical.reset(); horizontal.reset()
        acceleration.reset()
    }

    private func publishDiagnostics() {
        let text = !settings.enabled ? "Прокрутка FlowScroll выключена" : latestInputStatus
        if inputStatus != text { inputStatus = text }
        // Only aggregate counters; no application names, pointer positions or content.
        let status: [String: Any] = ["permission": hasPermission, "running": running,
            "handledEvents": handledEvents, "pixelEvents": pixelEvents,
            "gestureEvents": gestureEvents, "emittedFrames": emittedFrames,
            "inputStatus": inputStatus, "displayFrames": displayFrames,
            "longestFrameMs": longestFrame * 1000, "originalRunning": originalRunning,
            "version": "0.2.0"]
        if let data = try? JSONSerialization.data(withJSONObject: status, options: [.sortedKeys]) {
            let path = NSTemporaryDirectory() + "flowscroll-status-\(getuid()).json"
            try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
    }

    func stop() {
        cancelMotion()
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        tap = nil; runLoopSource = nil
        if running { running = false }
    }
}
