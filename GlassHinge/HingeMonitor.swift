//
//  HingeMonitor.swift
//  GlassHinge
//
//  Single source of truth for the glass overlay's 0...1 progress value:
//
//      0.0 = screen perfectly clear (the resting state)
//      1.0 = full glass dissolve
//
//  Behaviour (product rule): the effect is MOVEMENT-ONLY. Glass appears
//  while the hinge is moving and settles back to fully clear within about
//  a second of the lid stopping — whatever angle it stops at — so the
//  screen is never left blurry while you work. On sensor Macs the progress
//  is driven by hinge VELOCITY, not position. (Simulation mode in Settings
//  is the one exception: it holds the effect by position, deliberately,
//  so anyone can preview it and take screenshots.)
//
//  Three sources, tried in order, so the app does something useful on
//  every Mac ("support as many types as possible"):
//
//    1. Sensor      — real hinge angle on MacBooks with the angle sensor
//                     (2019 16" MacBook Pro and many later models). The
//                     overlay is scrubbed BY THE HINGE, frame for frame,
//                     the same technique community foldable recreations use to assign
//                     hinge values to animation frames.
//    2. Workspace   — every other MacBook: NSWorkspace sleep / wake and
//                     screen-saver notifications drive a 1.2s time-based
//                     dissolve. The opening half is what the user actually
//                     sees on wake, mirroring a foldable's open animation.
//    3. Simulation  — desktop Macs, external displays, App Review machines
//                     and anyone who wants to preview: a slider + Demo
//                     button in Settings, and a menu-bar "Play effect".
//
//  Honest hardware note: when a MacBook lid is FULLY closed the display is
//  off, so no app can show anything at 0 degrees. Like on a foldable, this effect
//  lives in the motion — while the lid is closing (down to ~25 degrees)
//  and while it is opening / waking.
//

import AppKit
import Combine
import Foundation

@MainActor
final class HingeMonitor: NSObject, ObservableObject {

    enum Source: String {
        case sensor = "Lid angle sensor"
        case workspace = "Sleep / wake (no angle sensor)"
        case simulation = "Simulation"
    }

    // MARK: - Published state

    @Published private(set) var progress: Double = 0
    @Published private(set) var angleDegrees: Double = 110
    @Published private(set) var source: Source = .simulation
    @Published private(set) var sensorAvailable = false

    // MARK: - Settings (mirrored from SettingsView via AppStorage keys)

    private var enabled: Bool { UserDefaults.standard.object(forKey: "effectEnabled") as? Bool ?? true }
    private var playOnWake: Bool { UserDefaults.standard.object(forKey: "playOnWake") as? Bool ?? true }
    private var playOnSleep: Bool { UserDefaults.standard.object(forKey: "playOnSleep") as? Bool ?? true }

    /// Angle at/above which the effect is fully off.
    private var openAngle: Double { UserDefaults.standard.object(forKey: "openAngle") as? Double ?? 110 }
    /// Angle at/below which the effect is fully on.
    private var closedAngle: Double { UserDefaults.standard.object(forKey: "closedAngle") as? Double ?? 28 }

    // MARK: - Internals

    private let sensor = LidAngleSensor()
    private var cancellables: Set<AnyCancellable> = []
    private var animationTask: Task<Void, Never>?
    private var smoothedAngle: Double = 110

    // Movement detection: velocity is measured over a ~120 ms window so
    // 1-2 degrees of sensor jitter can't fake a movement.
    private var windowAngle: Double = 110
    private var windowStart: Date?
    private var lastMovementDate: Date?
    private var settleTimer: Timer?
    private var isAnimating = false

    // MARK: - Lifecycle

    func start() {
        let found = sensor.start { [weak self] angle in
            Task { @MainActor [weak self] in
                self?.ingestSensorAngle(angle)
            }
        }
        sensorAvailable = found
        source = found ? .sensor : .workspace
        registerWorkspaceObservers()
        if found { startSettleTimer() }
    }

    func stop() {
        sensor.stop()
        settleTimer?.invalidate()
        settleTimer = nil
        animationTask?.cancel()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Sensor path

    private func ingestSensorAngle(_ angle: Double) {
        // Low-pass filter: raw Hall-sensor values jitter by a degree or two.
        smoothedAngle = smoothedAngle + (angle - smoothedAngle) * 0.35
        angleDegrees = smoothedAngle
        guard enabled, source != .simulation else { return }
        source = .sensor

        // Velocity over a ~120 ms window (deg/sec). |v| above ~10 deg/s
        // sustained across the window counts as the hinge really moving.
        let now = Date()
        if windowStart == nil {
            windowStart = now
            windowAngle = smoothedAngle
            return
        }
        let dt = now.timeIntervalSince(windowStart!)
        guard dt >= 0.12 else { return }
        let velocity = (smoothedAngle - windowAngle) / dt
        windowStart = now
        windowAngle = smoothedAngle

        if abs(velocity) > 10 {
            lastMovementDate = now
            // Faster hinge movement = stronger glass. A deliberate close
            // runs roughly 60-180 deg/s; cap at full effect.
            let target = min(max(abs(velocity) / 140.0, 0.15), 1)
            setProgress(progress + (target - progress) * 0.45)
        }
    }

    /// Runs while the sensor is live: when the hinge has been still for
    /// more than ~0.25 s, decay the glass back to perfectly clear
    /// (~1 s), whatever angle the lid stopped at.
    private func startSettleTimer() {
        settleTimer?.invalidate()
        settleTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self,
                      self.source == .sensor,
                      !self.isAnimating,
                      self.progress > 0 else { return }
                if let last = self.lastMovementDate,
                   Date().timeIntervalSince(last) > 0.25 {
                    let next = self.progress * 0.72
                    self.setProgress(next < 0.02 ? 0 : next)
                }
            }
        }
    }

    func progressFor(angle: Double) -> Double {
        let span = max(openAngle - closedAngle, 1)
        return min(max((openAngle - angle) / span, 0), 1)
    }

    // MARK: - Workspace fallback path

    private func registerWorkspaceObservers() {
        let ws = NSWorkspace.shared.notificationCenter
        ws.addObserver(self, selector: #selector(systemWillSleep),
                       name: NSWorkspace.willSleepNotification, object: nil)
        ws.addObserver(self, selector: #selector(screensDidWake),
                       name: NSWorkspace.screensDidWakeNotification, object: nil)
        ws.addObserver(self, selector: #selector(sessionDidBecomeActive),
                       name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)
    }

    @objc private func systemWillSleep() {
        // System is about to sleep (lid closing on sensor-less MacBooks,
        // or idle sleep). Play the closing dissolve if there's time.
        guard sensorAvailable == false, playOnSleep else { return }
        animateProgress(to: 1, duration: 0.5)
    }

    @objc private func screensDidWake() {
        // The visible money shot on sensor-less Macs: the fold-style glass
        // dissolve as the lid opens and the screen lights up.
        guard playOnWake else { return }
        if sensorAvailable {
            // Reset any stale progress from the close; if the lid is still
            // moving, the sensor's velocity tracking rebuilds the effect.
            setProgress(0)
            lastMovementDate = nil
            return
        }
        progress = 1
        animateProgress(to: 0, duration: 1.2)
    }

    @objc private func sessionDidBecomeActive() {
        guard sensorAvailable == false, playOnWake else { return }
        animateProgress(to: 0, duration: 1.2)
    }

    // MARK: - Simulation / manual path

    /// Drives the effect from the Settings slider (desktop Macs, demos,
    /// screenshots, App Review). Positional ON PURPOSE: simulation holds
    /// the effect at the dragged angle so it can be previewed and captured,
    /// unlike the real hinge, which is movement-only and settles clear.
    func simulate(angle: Double) {
        source = .simulation
        angleDegrees = angle
        setProgress(progressFor(angle: angle))
    }

    /// Returns control to the real sensor / workspace source.
    func endSimulation() {
        source = sensorAvailable ? .sensor : .workspace
        if source == .workspace {
            animateProgress(to: 0, duration: 0.6)
        }
    }

    /// Menu-bar / Settings "Play effect": full close-open cycle, time based.
    func playDemo() {
        animationTask?.cancel()
        animationTask = Task { [weak self] in
            guard let self else { return }
            await self.animate(progressTo: 1, duration: 1.1)
            try? await Task.sleep(nanoseconds: 150_000_000)
            await self.animate(progressTo: 0, duration: 1.3)
        }
    }

    // MARK: - Animation helpers

    private func setProgress(_ value: Double) {
        progress = min(max(value, 0), 1)
    }

    private func animateProgress(to target: Double, duration: TimeInterval) {
        animationTask?.cancel()
        animationTask = Task { [weak self] in
            await self?.animate(progressTo: target, duration: duration)
        }
    }

    /// Ease-in-out interpolation at ~60 fps. Cancelled by newer animations.
    private func animate(progressTo target: Double, duration: TimeInterval) async {
        isAnimating = true
        defer { isAnimating = false }
        let start = progress
        let steps = max(Int(duration * 60), 1)
        for i in 1...steps {
            if Task.isCancelled { return }
            let t = Double(i) / Double(steps)
            let eased = t * t * (3 - 2 * t) // smoothstep
            setProgress(start + (target - start) * eased)
            try? await Task.sleep(nanoseconds: 16_666_667)
        }
        setProgress(target)
    }
}
