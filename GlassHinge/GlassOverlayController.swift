//
//  GlassOverlayController.swift
//  GlassHinge
//
//  Owns one borderless, click-through overlay window per display and shows
//  them only while the effect is active (progress > 0.02), so the app's
//  idle footprint is effectively zero — no window, no compositing cost.
//
//  Windows sit at .screenSaver level with .canJoinAllSpaces so the glass
//  covers whatever the user is looking at, including full-screen apps,
//  but they never take focus or input: ignoresMouseEvents is always on.
//

import AppKit
import Combine
import SwiftUI

@MainActor
final class GlassOverlayController: NSObject {

    private let monitor: HingeMonitor
    private var windows: [NSWindow] = []
    private var cancellable: AnyCancellable?
    private var isShowing = false

    init(monitor: HingeMonitor) {
        self.monitor = monitor
    }

    func start() {
        rebuildWindows()
        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)

        cancellable = monitor.$progress
            .removeDuplicates(by: { abs($0 - $1) < 0.004 })
            .sink { [weak self] progress in
                Task { @MainActor [weak self] in
                    self?.updateVisibility(progress: progress)
                }
            }
    }

    func stop() {
        cancellable?.cancel()
        hide()
        windows.forEach { $0.close() }
        windows.removeAll()
    }

    // MARK: - Windows

    private func rebuildWindows() {
        windows.forEach { $0.close() }
        windows = NSScreen.screens.map { screen in
            let window = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false,
                screen: screen
            )
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.ignoresMouseEvents = true
            window.level = .screenSaver
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            window.contentView = NSHostingView(rootView: GlassOverlayView(monitor: monitor))
            window.setFrame(screen.frame, display: false)
            return window
        }
        if isShowing {
            windows.forEach { $0.orderFrontRegardless() }
        }
    }

    @objc private func screensChanged() {
        rebuildWindows()
    }

    private func updateVisibility(progress: Double) {
        let shouldShow = progress > 0.02
        if shouldShow, !isShowing {
            isShowing = true
            windows.forEach { $0.orderFrontRegardless() }
        } else if !shouldShow, isShowing {
            hide()
        }
    }

    private func hide() {
        isShowing = false
        windows.forEach { $0.orderOut(nil) }
    }
}
