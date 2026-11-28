//
//  HingeMonitor.swift
//  GlassHinge
//
//  Single source of truth for the glass overlay's 0...1 progress value:
//
//      0.0 = screen perfectly clear (angle at/below ~130 degrees —
//            open flat through upright to about half-closed)
//      1.0 = full glass dissolve (angle 180 degrees — lid closed)
//
//  Behaviour (product rule, changed 2026-11-27 at the user's word):
//  the effect is POSITIONAL — it tracks the lid ANGLE, so the glass
//  follows how wide the lid is open.
//
//  Angle convention (verified on the user's M5 MacBook Air, 2026-11-27):
//  the sensor value INCREASES as the lid closes — 0 is open flat,
//  ~50 is max open (tilted back), ~90 is upright, 180 is fully
//  closed. Validated across the full range: the glass is CLEAR from
//  open flat through upright up to ~130 degrees, then fades in from
//  about half-closed (lid halfway from upright to closed, ~135
//  degrees) and builds to full blur at 180 degrees (closed). The
//  first positional build used a 161-degree threshold, which only
//  showed the effect for the last 19 degrees of travel — the user
//  called it out as showing "very briefly" and asked for the
//  half-closed rule instead. If the sensor on another Mac reports the
//  opposite convention, the mapping here is the place to flip it.
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
    @Published private(set) var angleDegrees: Double = 90
    @Published private(set) var source: Source = .simulation
    @Published private(set) var sensorAvailable = false

    // MARK: - Settings (mirrored from SettingsView via AppStorage keys)

    private var enabled: Bool { UserDefaults.standard.object(forKey: "effectEnabled") as? Bool ?? true }
    private var playOnWake: Bool { UserDefaults.standard.object(forKey: "playOnWake") as? Bool ?? true }
    private var playOnSleep: Bool { UserDefaults.standard.object(forKey: "playOnSleep") as? Bool ?? true }

    /// Angle at/below which the effect is fully off (clear) — about
    /// half-closed from upright, so the fade covers the second half
    /// of the closing motion.
    private var openAngle: Double { UserDefaults.standard.object(forKey: "openAngle") as? Double ?? 130 }
    /// Angle at/above which the effect is fully on (full glass).
    private var closedAngle: Double { UserDefaults.standard.object(forKey: "closedAngle") as? Double ?? 180 }

    // MARK: - Internals

    private let sensor = LidAngleSensor()
    private var cancellables: Set<AnyCancellable> = []
    private var animationTask: Task<Void, Never>?
    private var smoothedAngle: Double = 90
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
    }

    func stop() {
        sensor.stop()
        animationTask?.cancel()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Sensor path

    /// Positional: the glass follows the lid angle. The smoothed angle
    /// maps straight to progress (openAngle -> clear, closedAngle ->
    /// full glass), and progress glides to each new value at 60 fps
    /// with an ease-out, so the fold tracks the hinge smoothly instead
    /// of jumping — the old velocity-window updates (~8x/sec with a
    /// 45% jump each time) read as a stuttering fold, and the wake
    /// reset made one lid movement fire the effect twice.
    private func ingestSensorAngle(_ angle: Double) {
        // Low-pass filter: raw Hall-sensor values jitter by a degree or two.
        smoothedAngle = smoothedAngle + (angle - smoothedAngle) * 0.35
        angleDegrees = smoothedAngle
        guard enabled, source != .simulation else { return }
        source = .sensor
        animateProgress(to: progressFor(angle: smoothedAngle), duration: 0.12, easeOut: true)
    }

    func progressFor(angle: Double) -> Double {
        let span = max(closedAngle - openAngle, 1)
        return min(max((angle - openAngle) / span, 0), 1)
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
            // The sensor owns progress now (positional): the angle
            // callbacks set the right value as the lid moves. Touching
            // progress here used to reset it mid-movement and make one
            // lid movement fire the effect twice.
            return
        }
        progress = 1
        animateProgress(to: 0, duration: 1.2)
    }

    @objc private func sessionDidBecomeActive() {
        guard sensorAvailable == false, playOnWake, !isAnimating else { return }
        // sessionDidBecomeActive fires on the same wake as screensDidWake;
        // without the isAnimating guard it restarts the wake dissolve and
        // the effect plays twice for one lid opening.
        animateProgress(to: 0, duration: 1.2)
    }

    // MARK: - Simulation / manual path

    /// Drives the effect from the Settings slider (desktop Macs, demos,
    /// screenshots, App Review). Positional by design, same as the real
    /// hinge now: it holds the effect at the dragged angle so it can be
    /// previewed and captured.
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

    private func animateProgress(to target: Double, duration: TimeInterval, easeOut: Bool = false) {
        animationTask?.cancel()
        animationTask = Task { [weak self] in
            await self?.animate(progressTo: target, duration: duration, easeOut: easeOut)
        }
    }

    /// Interpolates progress at ~60 fps. Cancelled by newer animations.
    /// Smoothstep (ease-in-out) for timed dissolves; ease-out for the
    /// sensor path, where each new target supersedes the last — ease-out
    /// starts fast, so a chain of short glides pursues the hinge instead
    /// of lagging behind it.
    private func animate(progressTo target: Double, duration: TimeInterval, easeOut: Bool = false) async {
        isAnimating = true
        defer { isAnimating = false }
        let start = progress
        let steps = max(Int(duration * 60), 1)
        for i in 1...steps {
            if Task.isCancelled { return }
            let t = Double(i) / Double(steps)
            let eased = easeOut ? (1 - (1 - t) * (1 - t)) : (t * t * (3 - 2 * t))
            setProgress(start + (target - start) * eased)
            try? await Task.sleep(nanoseconds: 16_666_667)
        }
        setProgress(target)
    }
}
