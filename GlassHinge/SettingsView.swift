//
//  SettingsView.swift
//  GlassHinge
//

import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var monitor: HingeMonitor

    @AppStorage("effectEnabled") private var effectEnabled = true
    @AppStorage("playOnWake") private var playOnWake = true
    @AppStorage("playOnSleep") private var playOnSleep = true
    @AppStorage("glassStyle") private var glassStyleRaw = GlassStyle.oceanBlue.rawValue
    @AppStorage("effectIntensity") private var intensity = 1.0
    @AppStorage("showInDock") private var showInDock = false

    @State private var launchAtLogin = false
    @State private var simAngle = 90.0
    @State private var simMode = false

    var body: some View {
        Form {
            Section("Effect") {
                Toggle("Enable glass effect", isOn: $effectEnabled)
                Picker("Glass style", selection: $glassStyleRaw) {
                    ForEach(GlassStyle.allCases) { style in
                        Text(style.rawValue).tag(style.rawValue)
                    }
                }
                Slider(value: $intensity, in: 0.2...1.5, step: 0.05) {
                    Text("Intensity")
                }
                Button("Play effect now") { monitor.playDemo() }
                    .keyboardShortcut("g", modifiers: [.command, .shift])
            }

            Section("When it plays") {
                Toggle("Play when the lid opens (on wake)", isOn: $playOnWake)
                Toggle("Play when the display goes to sleep", isOn: $playOnSleep)
                Text("On MacBooks with a lid angle sensor the glass follows the lid angle — clear when upright, blurring as you close it. On other Macs it plays as a 1.2-second glass dissolve on wake.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Sensor status") {
                HStack {
                    Image(systemName: monitor.sensorAvailable ? "angle" : "desktopcomputer")
                    VStack(alignment: .leading) {
                        Text(monitor.source.rawValue)
                        if monitor.sensorAvailable {
                            Text("Angle: \(Int(monitor.angleDegrees))°")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("This Mac has no angle sensor. Sensor models: 2019 16-inch MacBook Pro and many later Pro models. Desktop Macs and other models use the wake/dissolve fallback.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("Preview & simulation") {
                Toggle("Manual simulation", isOn: $simMode)
                    .onChange(of: simMode) { on in
                        if on { monitor.simulate(angle: simAngle) }
                        else { monitor.endSimulation() }
                    }
                if simMode {
                    Slider(value: $simAngle, in: 0...180, step: 1) {
                        Text("Lid angle: \(Int(simAngle))°")
                    }
                    .onChange(of: simAngle) { angle in
                        monitor.simulate(angle: angle)
                    }
                    Text("Drag the lid angle — the glass overlay follows, exactly like the hinge does on sensor MacBooks.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { on in
                        toggleLaunchAtLogin(on)
                    }
                Toggle("Show in Dock (off = menu-bar only)", isOn: $showInDock)
                    .onChange(of: showInDock) { show in
                        NSApp.setActivationPolicy(show ? .regular : .accessory)
                    }
            }

            Section("About") {
                Text("GlassHinge is free. Pro features are coming later and will never remove what is free today.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 420, minHeight: 520)
        .padding(12)
        .onAppear { refreshLaunchAtLogin() }
    }

    // MARK: - Launch at login (macOS 13+ public API)

    private func refreshLaunchAtLogin() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func toggleLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            refreshLaunchAtLogin()
        }
    }
}
