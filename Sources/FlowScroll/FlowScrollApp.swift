import SwiftUI
import AppKit
import ServiceManagement

@main
struct FlowScrollApp: App {
    @StateObject private var settings: Settings
    @StateObject private var engine: ScrollEngine

    init() {
        let settings = Settings()
        _settings = StateObject(wrappedValue: settings)
        _engine = StateObject(wrappedValue: ScrollEngine(settings: settings))
    }

    var body: some Scene {
        MenuBarExtra {
            SettingsView(settings: settings, engine: engine)
        } label: {
            Image(systemName: engine.running ? "computermouse.fill" : "computermouse")
        }
        .menuBarExtraStyle(.window)
    }
}

struct SettingsView: View {
    @ObservedObject var settings: Settings
    @ObservedObject var engine: ScrollEngine
    @State private var loginEnabled = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "computermouse.fill")
                    .font(.system(size: 28)).foregroundStyle(.mint)
                VStack(alignment: .leading, spacing: 3) {
                    Text("FlowScroll").font(.title2.bold())
                    Text("Smooth scrolling, naturally").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Circle().fill(engine.running ? Color.green : Color.orange).frame(width: 8, height: 8)
            }

            Toggle("Smooth scrolling", isOn: $settings.enabled)
                .font(.headline).toggleStyle(.switch)
            Text(engine.inputStatus).font(.caption).foregroundStyle(.secondary)
            if engine.originalRunning {
                Label("SmoothScroll is also running. Turn off its scrolling before comparing.", systemImage: "info.circle")
                    .font(.caption).foregroundStyle(.orange)
            }

            if !engine.hasPermission {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Allow Accessibility access", systemImage: "lock.shield")
                        .font(.subheadline.bold())
                    Text("Enable FlowScroll in macOS System Settings to allow it to process mouse wheel events.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Open System Settings") { engine.openPermissions() }
                        .buttonStyle(.borderedProminent).tint(.mint)
                }.padding(12).background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
            } else if settings.enabled && !engine.running {
                Text("Could not connect to scrolling. Check Accessibility access and restart the app.")
                    .font(.caption).foregroundStyle(.orange)
                Button("Retry connection") { engine.refresh() }
            }

            VStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack { Text("Speed"); Spacer(); Text(String(format: "%.2f×", settings.speed)).monospacedDigit().foregroundStyle(.secondary) }
                    Slider(value: $settings.speed, in: 0.25...4, step: 0.05).tint(.mint)
                }
                VStack(alignment: .leading, spacing: 6) {
                    HStack { Text("Animation duration"); Spacer(); Text("\(Int((settings.duration * 1000).rounded())) ms").monospacedDigit().foregroundStyle(.secondary) }
                    Slider(value: $settings.duration, in: 0.12...0.8, step: 0.01).tint(.mint)
                    HStack { Text("Snappy"); Spacer(); Text("Smooth") }.font(.caption2).foregroundStyle(.secondary)
                }
                Toggle("Reverse scroll direction", isOn: $settings.reversed)
                Toggle("Accelerate fast scrolling", isOn: $settings.accelerate)
            }

            Divider()
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Excluded apps").font(.subheadline.bold())
                    Spacer()
                    Button { settings.addExcludedApp() } label: { Image(systemName: "plus") }
                        .help("Choose an app")
                }
                if settings.excludedApps.isEmpty {
                    Text("Add apps that should keep their default scrolling.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    ScrollView {
                        VStack(spacing: 6) {
                            ForEach(settings.excludedApps, id: \.self) { identifier in
                                HStack {
                                    Text(appName(identifier)).lineLimit(1)
                                    Spacer()
                                    Button { settings.excludedApps.removeAll { $0 == identifier } } label: { Image(systemName: "minus.circle") }
                                        .buttonStyle(.plain).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }.frame(maxHeight: 100)
                }
            }

            Toggle("Launch at login", isOn: Binding(get: { loginEnabled }, set: { enabled in
                    do {
                        if enabled { try SMAppService.mainApp.register() }
                        else { try SMAppService.mainApp.unregister() }
                        loginError = nil
                        loginEnabled = enabled
                        if SMAppService.mainApp.status == .requiresApproval {
                            SMAppService.openSystemSettingsLoginItems()
                        }
                    } catch {
                        loginError = error.localizedDescription
                        loginEnabled = SMAppService.mainApp.status == .enabled
                    }
                }))
            if let loginError { Text(loginError).font(.caption).foregroundStyle(.orange) }
            Text("Native trackpad gestures keep their default scrolling. Control and Command wheel shortcuts pass through unchanged.")
                .font(.caption).foregroundStyle(.secondary)
            Divider()
            HStack {
                Button("Reset") { settings.reset() }.buttonStyle(.plain).foregroundStyle(.secondary)
                Spacer()
                Text("v0.2.2").font(.caption).foregroundStyle(.tertiary)
                Button("Quit") { engine.stop(); NSApplication.shared.terminate(nil) }.buttonStyle(.plain)
            }
        }
        .padding(22).frame(width: 360)
    }

    private func appName(_ identifier: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier) else { return identifier }
        return url.deletingPathExtension().lastPathComponent
    }
}
