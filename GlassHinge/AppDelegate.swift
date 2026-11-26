//
//  AppDelegate.swift
//  GlassHinge
//

import AppKit

/// Shared services so SwiftUI scenes and the overlay use the same monitor.
@MainActor
final class AppServices {
    static let shared = AppServices()
    let monitor = HingeMonitor()
    private lazy var overlay = GlassOverlayController(monitor: monitor)
    private var started = false

    private init() {}

    func start() {
        guard !started else { return }
        started = true
        monitor.start()
        overlay.start()
    }

    func stop() {
        overlay.stop()
        monitor.stop()
        started = false
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar only by default; Settings can switch this to .regular.
        let showInDock = UserDefaults.standard.bool(forKey: "showInDock")
        NSApp.setActivationPolicy(showInDock ? .regular : .accessory)
        Task { @MainActor in AppServices.shared.start() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        Task { @MainActor in AppServices.shared.stop() }
    }
}
