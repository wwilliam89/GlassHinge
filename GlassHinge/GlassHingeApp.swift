//
//  GlassHingeApp.swift
//  GlassHinge
//
//  A menu-bar app: no main window. LSUIElement is set in Info.plist so it
//  stays out of the Dock by default (user can re-enable it in Settings).
//
//  The HingeMonitor and overlay are owned by AppServices (started from
//  AppDelegate) so the menu, Settings and overlay all share one instance.
//

import SwiftUI

@main
struct GlassHingeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var monitor = AppServices.shared.monitor
    @StateObject private var store = FreemiumStore()

    var body: some Scene {
        MenuBarExtra("GlassHinge", systemImage: "macwindow") {
            MenuBarContent(monitor: monitor)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(monitor: monitor)
                .task { await store.load() }
        }
    }
}

struct MenuBarContent: View {
    @ObservedObject var monitor: HingeMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "macwindow")
                Text("GlassHinge").font(.headline)
                Spacer()
                Text(monitor.sensorAvailable ? "Sensor ON" : "Fallback")
                    .font(.caption2)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.thinMaterial, in: Capsule())
            }
            if monitor.sensorAvailable {
                Text("Lid angle: \(Int(monitor.angleDegrees))°")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Text("No lid angle sensor on this Mac — the glass dissolve plays on wake instead.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button("Play effect") { monitor.playDemo() }
                .keyboardShortcut("g", modifiers: [.command, .shift])
            Button("Settings…") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut(",", modifiers: .command)
            Divider()
            Button("Quit GlassHinge") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
        .padding(12)
        .frame(width: 280)
    }
}
