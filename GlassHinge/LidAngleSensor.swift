//
//  LidAngleSensor.swift
//  GlassHinge
//
//  Reads the MacBook lid (hinge) angle from the built-in Hall-effect angle
//  sensor, where one is fitted. This is the same public IOKit HID approach
//  used by the well-known open-source LidAngleSensor project:
//
//    * HID device:  vendor ID 0x05AC (Apple), product ID 0x8104
//    * Usage page:  0x0020 (Sensor)
//    * Usage:       0x008A (Orientation) — the lid angle element
//    * Value:       centidegrees (1/100 degree) in a 16-bit field
//
//  Hardware: first fitted to the 2019 16-inch MacBook Pro and carried into
//  many (not all) later models. Base 13-inch M1 MacBook Air / Pro models use
//  a binary Hall switch instead and report no angle — callers MUST handle
//  `isAvailable == false` and fall back gracefully (see HingeMonitor).
//
//  No private API symbols are used: only public IOHIDManager / IOHIDDevice
//  calls, matched narrowly to the sensor usage so the app never touches
//  keyboards, mice, or other input devices.
//

import Foundation
import IOKit.hid

final class LidAngleSensor {

    // MARK: - Hardware identifiers

    static let vendorID = 0x05AC
    static let productID = 0x8104
    static let usagePage = 0x0020   // Sensor page
    static let usage = 0x008A       // Orientation

    // MARK: - State

    private(set) var isAvailable = false
    private(set) var currentAngleDegrees: Double?

    private var manager: IOHIDManager?
    private var device: IOHIDDevice?
    private var onUpdate: ((Double) -> Void)?
    private var pollTimer: Timer?
    private var callbackDelivered = false

    deinit {
        stop()
    }

    // MARK: - Lifecycle

    /// Starts monitoring. Returns true when a sensor device was found.
    /// `onUpdate` is called on a background run loop thread with the angle
    /// in degrees, 0...180. On the user's M5 MacBook Air the value
    /// INCREASES as the lid closes (0 = open flat, ~90 = upright,
    /// 180 = fully closed) — the opposite of the 0 = closed convention
    /// in the community project's docs, so HingeMonitor maps it
    /// accordingly (clear at/below ~161 degrees, full glass at 180).
    @discardableResult
    func start(onUpdate: @escaping (Double) -> Void) -> Bool {
        stop()
        self.onUpdate = onUpdate

        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matching: [String: Any] = [
            kIOHIDVendorIDKey: Self.vendorID,
            kIOHIDProductIDKey: Self.productID,
            kIOHIDPrimaryUsagePageKey: Self.usagePage,
            kIOHIDPrimaryUsageKey: Self.usage
        ]
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)

        guard IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess else {
            return false
        }

        let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> ?? []
        guard let device = devices.first else {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            return false
        }

        guard IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess else {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            return false
        }

        self.manager = manager
        self.device = device
        isAvailable = true

        // Primary path: input-value callbacks for the orientation element.
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        IOHIDDeviceRegisterInputValueCallback(device, { context, _, _, value in
            guard let context else { return }
            let sensor = Unmanaged<LidAngleSensor>.fromOpaque(context).takeUnretainedValue()
            let element = IOHIDValueGetElement(value)
            guard IOHIDElementGetUsagePage(element) == UInt32(LidAngleSensor.usagePage),
                  IOHIDElementGetUsage(element) == UInt32(LidAngleSensor.usage) else { return }
            let raw = IOHIDValueGetIntegerValue(value)
            sensor.handleRawValue(raw)
        }, context)
        IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)

        // Fallback path: some firmware only answers feature reports.
        // Poll at 20 Hz until (unless) callbacks prove themselves, then keep
        // polling only if no callback has arrived. Cost is negligible and
        // the timer is invalidated in stop().
        if let angle = readFeatureReportAngle() {
            deliver(angle)
        }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, !self.callbackDelivered else { return }
            if let angle = self.readFeatureReportAngle() {
                self.deliver(angle)
            }
        }

        return true
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        if let device {
            IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
            IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        if let manager {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        device = nil
        manager = nil
        isAvailable = false
        callbackDelivered = false
        onUpdate = nil
    }

    // MARK: - Value handling

    private func handleRawValue(_ raw: CFIndex) {
        callbackDelivered = true
        // Element reports centidegrees; very small raw values (< 360) are
        // already whole degrees on some firmware. Normalise either way.
        let degrees = raw > 360 ? Double(raw) / 100.0 : Double(raw)
        deliver(degrees)
    }

    private func deliver(_ degrees: Double) {
        guard degrees >= 0, degrees <= 180 else { return }
        currentAngleDegrees = degrees
        onUpdate?(degrees)
    }

    /// Reads the angle via a HID feature report (Report ID 1) as a fallback
    /// for firmware that doesn't stream input reports.
    private func readFeatureReportAngle() -> Double? {
        guard let device else { return nil }
        var buffer = [UInt8](repeating: 0, count: 64)
        var length = buffer.count
        let result = buffer.withUnsafeMutableBufferPointer { ptr -> IOReturn in
            guard let base = ptr.baseAddress else { return kIOReturnBadArgument }
            return IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, 1, base, &length)
        }
        guard result == kIOReturnSuccess, length >= 3 else { return nil }

        // Scan the first few bytes for a plausible little-endian centidegree
        // value (0...18000). Layouts differ slightly between generations.
        for offset in 0...(min(length, 8) - 2) {
            let centi = UInt16(buffer[offset]) | (UInt16(buffer[offset + 1]) << 8)
            if centi > 0, centi <= 18_000 {
                return Double(centi) / 100.0
            }
        }
        return nil
    }
}
