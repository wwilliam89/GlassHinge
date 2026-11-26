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
//  Rebuilt here with AppKit/SwiftUI primitives only:
//
//    * REAL blur of what's underneath — an NSVisualEffectView with
//      .behindWindow blending, so the user's actual desktop dissolves,
//      not a fake screenshot. No Screen Recording permission needed.
//    * A blue/cyan liquid-glass tint whose opacity tracks progress.
//    * A diagonal "glass shine" band that sweeps across the screen as the
//      hinge moves — the visible signature of light crossing folding glass.
//    * A soft vertical refraction streak near the hinge-axis side, plus a
//      barely-there scale (max +2%) so content feels locked in space
//      while the "glass" moves over it.
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
    private var p: Double { monitor.progress * intensity }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                // 1. Real behind-window blur (the dissolve).
                VisualEffectBlur(material: style.material, blendingMode: .behindWindow)
                    .opacity(p)
                    .ignoresSafeArea()

                // 2. Liquid-glass tint.
                LinearGradient(
                    colors: style.tintColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .opacity(p * style.tintOpacity)
                .ignoresSafeArea()

                // 3. Diagonal glass shine sweeping with the hinge.
                if !reduceMotion {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.55), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: w * 0.45, height: h * 1.6)
                        .rotationEffect(.degrees(18))
                        .blur(radius: 30)
                        .offset(x: -w * 0.8 + (w * 1.6 * p))
                        .opacity(p)
                        .ignoresSafeArea()
                }

                // 4. Edge refraction — brighter line low on the screen,
                //    like light catching the bottom edge of folding glass
                //    near the MacBook hinge.
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
