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
//  Rebuilt here with AppKit/SwiftUI primitives only. The fold works
//  top-down: a fold line starts at the top edge and sweeps downward as
//  the lid closes (and back up as it opens), the way the user asked for
//  it in testing — the bottom-up version read as odd against how the
//  screen actually travels when the lid moves. Above the line the
//  desktop is folded glass (real blur + liquid tint); below it the
//  desktop is still flat and clear; the crease itself carries a band of
//  light. The fold is positional: the line's place is the lid angle, so
//  the glass follows how wide the lid is open.
//
//  The fade is what sells the liquid glass, so it is not a flat linear
//  crossfade:
//    * The blur and tint ease in (smoothstep) — the content holds sharp,
//      then melts through the glass, then clears.
//    * A milky wash peaks mid-fold, like content dissolving through
//      thick glass, and fades to nothing at either end.
//    * The crease has a shadow on its folded side as well as a shine,
//      so the fold reads as a physical bend with depth, not a flat
//      gradient.
//    * The shine carries a faint chromatic fringe (cyan/blue edges
//      around a white core), the way light splits at a glass edge.
//
//  Layers, all driven by HingeMonitor.progress:
//
//    * REAL blur of what's underneath — an NSVisualEffectView with
//      .behindWindow blending, so the user's actual desktop dissolves,
//      not a fake screenshot. No Screen Recording permission needed.
//      The blur is masked to the folded region above the fold line.
//    * A blue/cyan liquid-glass tint, masked to the same folded region.
//    * A milky white wash over the folded region, peaking mid-fold.
//    * A dark crease shadow just above the fold line.
//    * A horizontal crease shine (with chromatic fringe) riding the
//      fold line downward from the top edge.
//    * A soft glow along the top edge, like light catching the fold,
//      plus a barely-there scale (max +2%) so content feels locked in
//      space while the "glass" moves over it.
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
            // The fold line starts at the top edge and sweeps down as
            // the lid closes (and back up as it opens). foldY is its
            // distance from the top of the screen: 0 at rest, h fully
            // folded.
            let foldY = h * p
            let band: Double = 90
            let foldTop = max(0, (foldY - band) / h)
            let foldBottom = min(1, (foldY + band) / h)
            // Mask: glass above the fold line, clear below it, with a
            // soft edge at the crease.
            let foldMask = LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: .white, location: foldTop),
                    .init(color: .clear, location: foldBottom)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            // Eased fade: hold sharp, melt through the glass, clear.
            let fade = p * p * (3 - 2 * p)
            // Milky wash peaking mid-fold: dissolving through glass.
            let milk = sin(Double.pi * p) * 0.28
            ZStack {
                // 1. Real behind-window blur (the dissolve), folding
                //    down from the top edge.
                VisualEffectBlur(material: style.material, blendingMode: .behindWindow)
                    .opacity(fade)
                    .mask(foldMask)
                    .ignoresSafeArea()

                // 2. Liquid-glass tint, same fold.
                LinearGradient(
                    colors: style.tintColors,
                    startPoint: .top,
                    endPoint: .bottom
                )
                .opacity(fade * style.tintOpacity)
                .mask(foldMask)
                .ignoresSafeArea()

                // 3. Milky wash over the folded region, peaking mid-fold.
                Color.white
                    .opacity(milk)
                    .mask(foldMask)
                    .ignoresSafeArea()

                // 4. Crease shadow — a dark band just above the fold
                //    line, on the folded side, giving the bend depth.
                if !reduceMotion {
                    Rectangle()
                        .fill(Color.black.opacity(0.22))
                        .frame(width: w, height: 110)
                        .blur(radius: 28)
                        .offset(y: foldY - 55 - h / 2)
                        .opacity(fade)
                        .ignoresSafeArea()
                }

                // 5. Crease shine — a horizontal band of light riding
                //    the fold line as it sweeps down from the top edge,
                //    with a faint chromatic fringe at its edges.
                if !reduceMotion {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, .cyan.opacity(0.28), .white.opacity(0.6), .blue.opacity(0.28), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: w, height: 140)
                        .blur(radius: 24)
                        .offset(y: foldY - h / 2)
                        .opacity(fade)
                        .ignoresSafeArea()
                }

                // 6. Top-edge glow — light catching the folding glass
                //    where the fold starts.
                VStack {
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
                        .opacity(fade)
                    Spacer()
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
