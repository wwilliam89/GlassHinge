# GlassHinge

A featherweight Mac menu-bar app that gives your laptop a foldable-style glass fold: as you move or close the lid, a blue liquid-glass overlay sweeps over the screen — the display dissolving "as if opening a transparent window" while the hardware moves around it, just like a folding phone's fold/unfold animation.

## How it works

- **Sensor MacBooks** (2019 16-inch MacBook Pro and many later Pro models): reads the built-in lid angle sensor over public IOKit HID (vendor 0x05AC, product 0x8104, Sensor page, Orientation usage) and drives the glass effect *from hinge movement* — the same technique community foldable recreations use (hinge values driving animation frames). The effect is movement-only: glass appears while the hinge moves and settles back to fully clear about a second after it stops, at any angle.
- **Other MacBooks**: plays a 1.2-second glass dissolve on wake (the opening half you actually see), plus a quick close dissolve before the display sleeps.
- **Desktop Macs / external displays / no-sensor models**: menu-bar "Play effect" (⌘⇧G), on-wake dissolve, and a Manual Simulation slider in Settings that works everywhere — including on App Review machines.

The effect is pure SwiftUI + an `NSVisualEffectView` with behind-window blending, so it shows a *real* blur of your desktop — no Screen Recording permission needed. Overlay windows are hidden whenever the effect is at rest, so idle CPU/memory use is effectively zero. Fully sandboxed (only the `app-sandbox` entitlement), no network, no file access, collects no data.

## Honest limits (by design)

- When a MacBook lid is **fully closed** the display is off — nothing can render there. Like on a foldable, the effect lives *in the motion*: while closing (down to ~25°) and while opening/waking. That's why the opening half is the centerpiece on sensor-less Macs.
- Not every MacBook has an angle sensor (e.g. base 13" M1 Air/Pro use a binary Hall switch), so the app detects at runtime and degrades gracefully — it always does something useful.

## Building

Open `GlassHinge.xcodeproj` in Xcode on any Mac (macOS 13+ SDK). Build & run. Nothing to install — zero dependencies.

### Free now, paid later

v1 ships fully free. `FreemiumStore.swift` already contains the StoreKit 2 scaffold: flip `monetizationEnabled` to `true`, create the `com.glasshinge.mac.pro.unlock` product in App Store Connect, and Pro UI appears — without restructuring the app. Launching free with the IAP plumbing pre-wired means no big rebuild to start charging.

## Hands-off publishing (Xcode Cloud)

1. Enroll in the Apple Developer Program ($99/yr) and set the bundle ID (currently `com.glasshinge.mac` — change it to your domain in the target's Signing settings).
2. Push this folder to a repo, then in Xcode: Report Navigator → Cloud tab → create a workflow:
   - **CI**: build on every push to `main`
   - **Release**: Archive → TestFlight / App Store on tags like `v1.0.0` (or manual)
3. Xcode Cloud includes 25 compute hours/month free — plenty for this app.
4. Create the App Store listing from `APP_STORE.md`, fill Pricing (Free) and App Privacy (Data Not Collected), then submit.

## Privacy

Collects nothing, sends nothing. Privacy manifest (`PrivacyInfo.xcprivacy`) declares only UserDefaults access for settings (CA92.1).
