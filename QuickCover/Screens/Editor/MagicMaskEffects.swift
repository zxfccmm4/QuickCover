import SwiftUI

/// Apple Intelligence iridescent spectrum used for Clean Up-style magic erase waves,
/// starlight particles, and on-device semantic privacy scanning rims.
enum AppleIntelligencePalette {
    static let colors: [Color] = [
        Color(red: 0.37, green: 0.86, blue: 0.83), // luminous cyan-teal
        Color(red: 0.28, green: 0.68, blue: 1.00), // sky blue
        Color(red: 0.45, green: 0.46, blue: 1.00), // indigo
        Color(red: 0.78, green: 0.36, blue: 0.96), // violet
        Color(red: 1.00, green: 0.34, blue: 0.62), // magenta
        Color(red: 1.00, green: 0.58, blue: 0.36), // warm coral
        Color(red: 0.37, green: 0.86, blue: 0.83), // seamless loop
    ]

    static var linearGradient: LinearGradient {
        LinearGradient(
            colors: Array(colors.dropLast()),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func color(at unit: Double) -> Color {
        let clamped = unit.truncatingRemainder(dividingBy: 1.0)
        let u = clamped < 0 ? clamped + 1.0 : clamped
        let count = colors.count - 1
        let idx = min(count - 1, Int(u * Double(count)))
        return colors[idx]
    }
}

/// Active screen-space animation burst rendered by `MagicBurstOverlay`.
struct ActiveMagicBurst: Identifiable, Equatable {
    let id: UUID
    /// Bounding rects in upright full-size image pixels.
    let fullRects: [CGRect]
    let kind: MagicBurstEvent.Kind
    let startedAt: TimeInterval

    var duration: TimeInterval {
        switch kind {
        case .erase, .aiScan: 0.82
        case .cover: 0.62
        case .uncover: 0.56
        case .styleMorph: 0.54
        }
    }
}

/// 60fps Apple Intelligence Clean Up-inspired shimmer wave and starlight particle dissolve overlay.
/// Completely pauses its timeline when no bursts are active (zero idle CPU/GPU cost) and respects
/// `accessibilityReduceMotion`.
struct MagicBurstOverlay: View {
    let bursts: [ActiveMagicBurst]
    let fullToCanvas: (CGRect) -> CGRect

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if !bursts.isEmpty, !reduceMotion {
            TimelineView(.animation) { timeline in
                let now = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, _ in
                    for burst in bursts {
                        let elapsed = now - burst.startedAt
                        let t = elapsed / burst.duration
                        guard t >= 0, t <= 1 else { continue }
                        for (rectIdx, fullRect) in burst.fullRects.enumerated() {
                            let rect = fullToCanvas(fullRect)
                            guard rect.width >= 4, rect.height >= 4 else { continue }
                            let stagger = min(Double(rectIdx) * 0.045, 0.22)
                            let localT = (t - stagger) / max(1.0 - stagger, 0.2)
                            guard localT >= 0, localT <= 1 else { continue }
                            drawBurst(
                                in: &context,
                                rect: rect,
                                kind: burst.kind,
                                progress: localT,
                                seed: burst.id.hashValue ^ (rectIdx &* 2654435761)
                            )
                        }
                    }
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private func drawBurst(
        in context: inout GraphicsContext,
        rect: CGRect,
        kind: MagicBurstEvent.Kind,
        progress t: Double,
        seed: Int
    ) {
        let easeOut = 1.0 - pow(1.0 - t, 3.0)
        let fade = t < 0.16 ? (t / 0.16) : pow(max(0, 1.0 - (t - 0.16) / 0.84), 1.4)
        let corner = min(10, min(rect.width, rect.height) * 0.25)
        let rounded = Path(roundedRect: rect, cornerRadius: corner, style: .continuous)

        // 1. Soft Apple Intelligence iridescent sheen wave sweeping diagonally across the cover.
        context.drawLayer { layer in
            layer.clip(to: rounded)

            let sweepX = rect.minX - rect.width * 0.65 + (rect.width * 2.3) * easeOut
            let bandWidth = max(rect.width * 0.58, 44)
            let bandRect = CGRect(
                x: sweepX - bandWidth / 2,
                y: rect.minY - rect.height * 0.3,
                width: bandWidth,
                height: rect.height * 1.6
            )

            let sheenOpacity: Double = switch kind {
            case .erase, .aiScan: 0.68 * fade
            case .cover: 0.52 * fade
            case .styleMorph: 0.48 * fade
            case .uncover: 0.34 * fade
            }

            let sheenGradient = Gradient(stops: [
                .init(color: .clear, location: 0.0),
                .init(color: AppleIntelligencePalette.colors[0].opacity(sheenOpacity), location: 0.26),
                .init(color: AppleIntelligencePalette.colors[3].opacity(sheenOpacity * 1.05), location: 0.50),
                .init(color: AppleIntelligencePalette.colors[4].opacity(sheenOpacity), location: 0.72),
                .init(color: .clear, location: 1.0),
            ])

            layer.fill(
                Path(bandRect),
                with: .linearGradient(
                    sheenGradient,
                    startPoint: CGPoint(x: bandRect.minX, y: bandRect.minY),
                    endPoint: CGPoint(x: bandRect.maxX, y: bandRect.maxY)
                )
            )

            // Soft full-area magic wash for Magic Erase & AI Scan.
            if kind == .erase || kind == .aiScan {
                let washOpacity = 0.26 * pow(max(0, 1.0 - t), 1.6)
                layer.fill(
                    rounded,
                    with: .linearGradient(
                        Gradient(colors: [
                            AppleIntelligencePalette.colors[0].opacity(washOpacity),
                            AppleIntelligencePalette.colors[3].opacity(washOpacity),
                            AppleIntelligencePalette.colors[5].opacity(washOpacity),
                        ]),
                        startPoint: CGPoint(x: rect.minX, y: rect.minY),
                        endPoint: CGPoint(x: rect.maxX, y: rect.maxY)
                    )
                )
            }
        }

        // 2. Iridescent expanding edge glow rim.
        let rimExpand: CGFloat = kind == .uncover ? CGFloat(easeOut * 8) : CGFloat((1.0 - easeOut) * 3)
        let rimRect = rect.insetBy(dx: -rimExpand, dy: -rimExpand)
        let rimPath = Path(roundedRect: rimRect, cornerRadius: corner + rimExpand * 0.5, style: .continuous)
        let rimStrokeOpacity = (kind == .erase || kind == .aiScan ? 0.92 : 0.72) * fade
        context.stroke(
            rimPath,
            with: .linearGradient(
                Gradient(colors: [
                    AppleIntelligencePalette.colors[0].opacity(rimStrokeOpacity),
                    AppleIntelligencePalette.colors[2].opacity(rimStrokeOpacity),
                    AppleIntelligencePalette.colors[4].opacity(rimStrokeOpacity),
                    AppleIntelligencePalette.colors[5].opacity(rimStrokeOpacity),
                ]),
                startPoint: CGPoint(x: rimRect.minX, y: rimRect.minY),
                endPoint: CGPoint(x: rimRect.maxX, y: rimRect.maxY)
            ),
            lineWidth: kind == .erase || kind == .aiScan ? 2.4 : 1.75
        )

        // 3. Starlight magic particles (Clean Up sparkle dust dissolve).
        let particleCount: Int = switch kind {
        case .erase, .aiScan: min(34, max(16, Int((rect.width + rect.height) / 14)))
        case .cover: min(22, max(10, Int((rect.width + rect.height) / 22)))
        case .uncover: min(18, max(8, Int((rect.width + rect.height) / 24)))
        case .styleMorph: min(14, max(6, Int((rect.width + rect.height) / 30)))
        }

        for i in 0..<particleCount {
            let h1 = hashUnit(seed, i * 3 + 1)
            let h2 = hashUnit(seed, i * 3 + 2)
            let h3 = hashUnit(seed, i * 3 + 3)

            let startX = rect.minX + CGFloat(h1) * rect.width
            let startY = rect.minY + CGFloat(h2) * rect.height
            let angle = h3 * .pi * 2.0
            let driftDist: CGFloat = switch kind {
            case .erase, .aiScan: CGFloat(10 + h3 * 22)
            case .uncover: CGFloat(14 + h3 * 24)
            case .cover: CGFloat(4 + h3 * 10)
            case .styleMorph: CGFloat(6 + h3 * 12)
            }

            let px: CGFloat
            let py: CGFloat
            if kind == .cover {
                // Particles glide gently inward and settle into the cover.
                let inward = CGFloat(1.0 - easeOut)
                px = startX + cos(angle) * driftDist * inward
                py = startY + sin(angle) * driftDist * inward
            } else {
                // Magic Erase / AI / Uncover: particles buoy upward & disperse into starlight dust.
                px = startX + cos(angle) * driftDist * CGFloat(easeOut)
                py = startY + sin(angle) * driftDist * CGFloat(easeOut) - CGFloat(easeOut * 7.0)
            }

            let twinkle = 0.6 + 0.4 * sin(t * 14.0 + h3 * 12.0)
            let pAlpha = fade * twinkle * (kind == .erase || kind == .aiScan ? 0.98 : 0.85)
            guard pAlpha > 0.03 else { continue }

            let color = (i % 3 == 0) ? Color.white : AppleIntelligencePalette.color(at: h1 + h3 * 0.4)
            let radius = CGFloat(1.8 + h3 * 3.4) * CGFloat(0.65 + 0.35 * (1.0 - t))

            if i % 3 == 0 {
                // Crisp 4-point star sparkle
                let star = fourPointStar(center: CGPoint(x: px, y: py), radius: radius * 1.55)
                context.fill(star, with: .color(color.opacity(pAlpha)))
            } else {
                // Soft glowing dust mote
                let dotRect = CGRect(x: px - radius, y: py - radius, width: radius * 2, height: radius * 2)
                context.fill(Path(ellipseIn: dotRect), with: .color(color.opacity(pAlpha)))
            }
        }
    }

    private func fourPointStar(center: CGPoint, radius: CGFloat) -> Path {
        let inner = radius * 0.28
        var path = Path()
        for step in 0..<8 {
            let r = (step % 2 == 0) ? radius : inner
            let angle = Double(step) * (.pi / 4.0)
            let pt = CGPoint(x: center.x + CGFloat(cos(angle)) * r, y: center.y + CGFloat(sin(angle)) * r)
            if step == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }

    private func hashUnit(_ seed: Int, _ salt: Int) -> Double {
        var x = UInt64(bitPattern: Int64(seed ^ (salt &* 1103515245 &+ 12345)))
        x ^= x >> 33
        x &*= 0xff51afd7ed558ccd
        x ^= x >> 33
        return Double(x & 0xFFFF) / Double(0xFFFF)
    }
}

/// Iconic Apple Intelligence rotating iridescent rim halo around the photo canvas while
/// Vision / on-device `FoundationModels` intelligence analysis is running.
struct AppleIntelligenceRimGlow: View {
    let cornerRadius: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if reduceMotion {
            shape
                .strokeBorder(AppleIntelligencePalette.linearGradient, lineWidth: 3)
                .opacity(0.85)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        } else {
            TimelineView(.animation) { timeline in
                let angle = Angle.degrees(timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3.2) / 3.2 * 360)
                let gradient = AngularGradient(
                    colors: AppleIntelligencePalette.colors,
                    center: .center,
                    angle: angle
                )
                ZStack {
                    shape
                        .strokeBorder(gradient, lineWidth: 5)
                        .blur(radius: 10)
                        .opacity(0.85)
                    shape
                        .strokeBorder(gradient, lineWidth: 2.2)
                        .opacity(0.95)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}
