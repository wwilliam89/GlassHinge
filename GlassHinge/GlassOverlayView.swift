//
//  GlassOverlayView.swift
//  GlassHinge
//
//  The foldable-phone glass fold effect, rebuilt for a laptop lid.
//
//  The reference effect (from hands-on coverage of foldables): as the
//  device folds or unfolds, the display "naturally blurs during the
//  transition as if opening a transparent window", content dissolves as
//  if it had passed through the moving glass and reappears on the other
//  side, with a blue, liquid-glass tint and content that stays locked in
//  perceived space while the hardware moves around it. This file is an
//  original re-implementation of that idea — no third-party assets, code,
//  or product names are used anywhere in the app or its store listing.
//
//  Rebuilt here with AppKit/SwiftUI primitives only, and folded the way
//  a MacBook actually folds: the hinge is the BOTTOM edge of the screen,
//  so the fold works bottom-up. A fold line starts at the hinge and
//  rises toward the top as the lid moves. Below the line the desktop is
//  folded glass (real blur + liquid tint); above it the desktop is still
//  flat and clear; the crease itself carries a band of light. When the
//  lid stops, the fold melts back down to the hinge and the screen is
//  clear again.
//
//    * REAL blur of what's underneath — an NSVisualEffectView with
//      .behindWindow blending, so the user's actual desktop dissolves,
//      not a fake screenshot. No Screen Recording permission needed.
//      The blur is masked to the folded region below the fold line.
//    * A blue/cyan liquid-glass tint whose opacity tracks progress,
//      masked to the same folded region.
//    * A horizontal crease shine that rides the fold line upward from
//      the hinge as the lid moves — the visible signature of light
//      crossing the crease.
//    * A soft glow along the bottom edge, like light catching the
//      hinge itself, plus a barely-there scale (max +2%) so content
//      feels locked in space while the "glass" moves over it.
//
//  Everything is a pure function of HingeMonitor.progress, so on sensor
//  MacBooks the hinge itself scrubs the animation; elsewhere a timed
//  animation drives the same value.
//

import AppKit
import SwiftUI

struct GlassOverlayView: View {
    @ObservedObject var monitor: HingeMonitor
    @AppStorage("glassStyle") private var styleRaw = GlassStyle.oceanBlue.rawValue
    @AppStorage("effectIntensity") private var intensity = 1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var style: GlassStyle { GlassStyle(rawValue: styleRaw) ?? .oceanBlue }
    private var p: Double { min(1, max(0, monitor.progress * intensity)) }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            // The fold line starts at the hinge (bottom edge) and rises
            // to the top as the lid moves. foldY is its distance from
            // the top of the screen: h at rest, 0 fully folded.
            let foldY = h * (1 - p)
            let band: Double = 90
            let foldTop = max(0, (foldY - band) / h)
            let foldBottom = min(1, (foldY + band) / h)
            // Mask: glass below the fold line, clear above it, with a
            // soft edge at the crease.
            let foldMask = LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: .clear, location: foldTop),
                    .init(color: .white, location: foldBottom)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            ZStack {
                // 1. Real behind-window blur (the dissolve), folded up
                //    from the hinge.
                VisualEffectBlur(material: style.material, blendingMode: .behindWindow)
                    .opacity(p)
                    .mask(foldMask)
                    .ignoresSafeArea()

                // 2. Liquid-glass tint, same fold.
                LinearGradient(
                    colors: style.tintColors,
                    startPoint: .top,
                    endPoint: .bottom
                )
                .opacity(p * style.tintOpacity)
                .mask(foldMask)
                .ignoresSafeArea()

                // 3. Crease shine — a horizontal band of light riding
                //    the fold line as it rises from the hinge.
                if !reduceMotion {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.6), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: w, height: 140)
                        .blur(radius: 24)
                        .offset(y: foldY - h / 2)
                        .opacity(p)
                        .ignoresSafeArea()
                }

                // 4. Hinge glow — light catching the bottom edge of the
                //    folding glass at the MacBook hinge.
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.35), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 90)
                        .blur(radius: 24)
                        .opacity(p)
                }
                .ignoresSafeArea()
            }
            // Content-locked-in-space illusion: the glass layer grows a
            // touch while everything beneath stays put.
            .scaleEffect(1 + 0.02 * p)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Styles (free set; structure leaves room for paid Pro styles later)

enum GlassStyle: String, CaseIterable, Identifiable {
    case oceanBlue = "Ocean Blue"
    case clearGlass = "Clear Glass"
    case frost = "Frost"

    var id: String { rawValue }

    var material: NSVisualEffectView.Material {
        switch self {
        case .oceanBlue: return .fullScreenUI
        case .clearGlass: return .hudWindow
        case .frost: return .popover
        }
    }

    var tintColors: [Color] {
        switch self {
        case .oceanBlue: return [Color.blue.opacity(0.35), Color.cyan.opacity(0.20), Color.white.opacity(0.10)]
        case .clearGlass: return [Color.white.opacity(0.12), Color.white.opacity(0.04)]
        case .frost: return [Color.white.opacity(0.28), Color.gray.opacity(0.12)]
        }
    }

    var tintOpacity: Double {
        switch self {
        case .oceanBlue: return 0.9
        case .clearGlass: return 0.6
        case .frost: return 1.0
        }
    }
}

// MARK: - NSVisualEffectView bridge

struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
