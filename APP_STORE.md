# GlassHinge — final App Store listing (trademark-safe)

All store metadata deliberately avoids third-party product names (no Apple
product names in the name, subtitle, or keywords) and never implies any
affiliation with or endorsement by Apple. See BRANDING_AND_LEGAL.md.

## Identity

- **Name:** `GlassHinge: Lid Glass Effect` (29 chars)
- **Subtitle:** `Fold-style glass for your Mac` (29 chars)
- **Bundle ID:** com.glasshinge.mac
- **Primary category:** Utilities · **Secondary:** Graphics & Design
- **Price at launch:** Free
- **Later (v1.1):** Free + optional **Pro unlock, one-time $3.99** — see pricing plan in BRANDING_AND_LEGAL.md
- **Age rating:** 4+ · **Privacy:** Data Not Collected

## Promotional text (170 chars max)

> Move your lid, watch the glass. GlassHinge turns closing your laptop into a liquid-glass fold — real-time on sensor Macs, a smooth glass dissolve on wake everywhere else.

## Keywords (100 chars max, no trademarked terms)

`lid,hinge,glass,fold,blur,overlay,menubar,laptop,wake,sleep,animation,effect`

## Description

> GlassHinge gives your laptop the fold.
>
> Move or close your lid and a liquid-glass overlay sweeps across the screen: your desktop blurs as if seen through folding glass, light catches the fold, and everything settles back as the lid stops — a tiny moment of theatre, every time you close your Mac.
>
> On laptops with a built-in lid angle sensor, the effect follows your hinge in real time while it moves — then settles back to perfectly clear the moment the lid stops, whatever angle you stop at. It never leaves your screen blurry. On every other Mac, GlassHinge plays a smooth glass dissolve when your Mac wakes — open the lid, get the glass.
>
> • Real-time hinge tracking on sensor models (2019 16-inch Pro and many later Pros, recent Airs)
> • Wake and sleep glass dissolve on all other Macs
> • Three glass styles: Ocean Blue, Clear Glass, Frost
> • Adjustable angle range and intensity
> • Manual preview and simulation slider — try it on any Mac, even a desktop
> • Menu-bar app with effectively zero idle footprint
> • Launch at login, works across all displays
> • No permissions needed. No screen recording. No accounts, no ads, and no data collected — ever.
>
> GlassHinge is free, and everything free today stays free. Pro styles are on the way as an optional one-time unlock.

## What's New — v1.0

> First release: real-time glass fold on sensor laptops, wake/sleep dissolve everywhere else, three glass styles, and a simulation mode so anyone can play with the fold.

## Screenshots (capture plan)

1. Lid mid-close, glass sweep at ~50% (simulation slider on a desktop shot is fine).
2. Full dissolve over a colourful desktop.
3. Settings window showing styles + sensor status.
4. Menu-bar popover.

## Notes for App Review

Hello! GlassHinge is a free, fully sandboxed menu-bar app. What it does:

1. **Reads the laptop lid angle sensor** via the *public* IOKit HID API (`IOHIDManager`/`IOHIDDevice`), matched narrowly to the built-in sensor device (VID 0x05AC / PID 0x8104, Sensor usage page 0x0020, Orientation usage 0x008A). No private API symbols are used and the app never touches keyboards, mice, or other input devices.
2. **Draws a decorative glass visual effect** over the user's own screen using `NSVisualEffectView` behind-window blending. Nothing is captured or recorded.
3. If no sensor is present (desktop Macs, older models, VMs), the app **detects this at runtime** and instead plays a timed dissolve on sleep/wake, plus a manual simulation slider and a "Play effect" button — so it is fully functional and reviewable on any Mac.

The app requests no permissions (no camera, mic, screen recording, files, or network). Privacy manifest declares only UserDefaults settings storage (CA92.1).

To preview: open the app from the menu bar, click **Play effect**, or Settings → Preview & simulation → **Manual simulation** and drag the lid-angle slider.

GlassHinge is an independent app and is not affiliated with Apple. Thank you!
