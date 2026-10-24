import AppKit
import Combine

final class Settings: ObservableObject {
    private let defaults = UserDefaults.standard
    @Published var enabled: Bool { didSet { defaults.set(enabled, forKey: "enabled") } }
    @Published var speed: Double { didSet { defaults.set(speed, forKey: "speed") } }
    @Published var duration: Double { didSet { defaults.set(duration, forKey: "duration") } }
    @Published var reversed: Bool { didSet { defaults.set(reversed, forKey: "reversed") } }
    @Published var accelerate: Bool { didSet { defaults.set(accelerate, forKey: "accelerate") } }
    @Published var excludedApps: [String] { didSet { defaults.set(excludedApps, forKey: "excludedApps") } }

    init() {
        defaults.register(defaults: ["enabled": true, "speed": 1.0, "duration": 0.36, "accelerate": true])
        enabled = defaults.bool(forKey: "enabled")
        speed = min(4, max(0.25, defaults.double(forKey: "speed")))
        duration = min(0.8, max(0.12, defaults.double(forKey: "duration")))
        reversed = defaults.bool(forKey: "reversed")
        accelerate = defaults.bool(forKey: "accelerate")
        excludedApps = defaults.stringArray(forKey: "excludedApps") ?? []
    }

    func addExcludedApp() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.applicationBundle]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url,
              let identifier = Bundle(url: url)?.bundleIdentifier,
              !excludedApps.contains(identifier) else { return }
        excludedApps.append(identifier)
    }

    func reset() { speed = 1; duration = 0.36; reversed = false; accelerate = true }
}
