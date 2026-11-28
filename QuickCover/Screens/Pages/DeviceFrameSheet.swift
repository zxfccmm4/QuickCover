import PhotosUI
import SwiftUI
import UIKit

// MARK: - Platform Brand Icons for Export Aspect Ratios

/// Authentic vector platform brand badge for each `ExportAspectRatio` preset.
struct PlatformAspectBadgeView: View {
    let preset: ExportAspectRatio
    var size: CGFloat = 30

    var body: some View {
        let radius = size * 0.26
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        ZStack {
            switch preset {
            case .xiaohongshu3x4:
                shape.fill(
                    LinearGradient(
                        colors: [Color(red: 1.0, green: 0.14, blue: 0.26), Color(red: 0.93, green: 0.06, blue: 0.20)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                Text(verbatim: "小红书")
                    .font(.system(size: size * 0.275, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.45)
                    .lineLimit(1)
                    .padding(.horizontal, size * 0.08)

            case .douyin9x16:
                shape.fill(Color(red: 0.07, green: 0.07, blue: 0.09))
                Canvas { ctx, s in
                    func notePath(offset: CGSize) -> Path {
                        let w = s.width, h = s.height
                        let ox = offset.width, oy = offset.height
                        var p = Path()
                        // Vertical stem + lower loop + curved top flag forming the iconic "d" musical note
                        p.move(to: CGPoint(x: w * 0.56 + ox, y: h * 0.21 + oy))
                        p.addLine(to: CGPoint(x: w * 0.56 + ox, y: h * 0.62 + oy))
                        p.addArc(
                            center: CGPoint(x: w * 0.42 + ox, y: h * 0.63 + oy),
                            radius: w * 0.14,
                            startAngle: .degrees(0),
                            endAngle: .degrees(265),
                            clockwise: false
                        )
                        p.move(to: CGPoint(x: w * 0.56 + ox, y: h * 0.22 + oy))
                        p.addQuadCurve(
                            to: CGPoint(x: w * 0.76 + ox, y: h * 0.36 + oy),
                            control: CGPoint(x: w * 0.62 + ox, y: h * 0.34 + oy)
                        )
                        return p
                    }
                    let stroke = StrokeStyle(lineWidth: s.width * 0.105, lineCap: .round, lineJoin: .round)
                    ctx.stroke(notePath(offset: CGSize(width: -s.width * 0.045, height: -s.height * 0.035)),
                               with: .color(Color(red: 0.15, green: 0.96, blue: 0.93)), style: stroke)
                    ctx.stroke(notePath(offset: CGSize(width: s.width * 0.045, height: s.height * 0.035)),
                               with: .color(Color(red: 1.0, green: 0.17, blue: 0.33)), style: stroke)
                    ctx.stroke(notePath(offset: .zero), with: .color(.white), style: stroke)
                }

            case .wechatCover:
                shape.fill(
                    LinearGradient(
                        colors: [Color(red: 0.09, green: 0.80, blue: 0.42), Color(red: 0.03, green: 0.68, blue: 0.34)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                Canvas { ctx, s in
                    let w = s.width, h = s.height
                    // Back bubble (top-left)
                    let backRect = CGRect(x: w * 0.17, y: h * 0.23, width: w * 0.46, height: h * 0.37)
                    ctx.fill(Path(ellipseIn: backRect), with: .color(.white))
                    var backTail = Path()
                    backTail.move(to: CGPoint(x: w * 0.24, y: h * 0.55))
                    backTail.addLine(to: CGPoint(x: w * 0.20, y: h * 0.64))
                    backTail.addLine(to: CGPoint(x: w * 0.34, y: h * 0.58))
                    backTail.closeSubpath()
                    ctx.fill(backTail, with: .color(.white))

                    // Subtle separator stroke + front bubble (bottom-right)
                    let frontRect = CGRect(x: w * 0.40, y: h * 0.40, width: w * 0.43, height: h * 0.34)
                    ctx.fill(Path(ellipseIn: frontRect.insetBy(dx: -w * 0.025, dy: -w * 0.025)),
                             with: .color(Color(red: 0.05, green: 0.72, blue: 0.36)))
                    ctx.fill(Path(ellipseIn: frontRect), with: .color(.white))
                    var frontTail = Path()
                    frontTail.move(to: CGPoint(x: w * 0.75, y: h * 0.69))
                    frontTail.addLine(to: CGPoint(x: w * 0.80, y: h * 0.78))
                    frontTail.addLine(to: CGPoint(x: w * 0.67, y: h * 0.73))
                    frontTail.closeSubpath()
                    ctx.fill(frontTail, with: .color(.white))

                    // Classic twin eyes in both bubbles
                    let green = Color(red: 0.04, green: 0.69, blue: 0.34)
                    let eyeR = w * 0.036
                    for cx in [w * 0.33, w * 0.47] {
                        ctx.fill(Path(ellipseIn: CGRect(x: cx - eyeR, y: h * 0.39 - eyeR, width: eyeR * 2, height: eyeR * 2)), with: .color(green))
                    }
                    let fEyeR = w * 0.032
                    for cx in [w * 0.54, w * 0.68] {
                        ctx.fill(Path(ellipseIn: CGRect(x: cx - fEyeR, y: h * 0.55 - fEyeR, width: fEyeR * 2, height: fEyeR * 2)), with: .color(green))
                    }
                }

            case .bilibili16x9:
                shape.fill(
                    LinearGradient(
                        colors: [Color(red: 0.99, green: 0.47, blue: 0.62), Color(red: 0.95, green: 0.35, blue: 0.54)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                Canvas { ctx, s in
                    let w = s.width, h = s.height
                    // Slanted antennae
                    var ant = Path()
                    ant.move(to: CGPoint(x: w * 0.32, y: h * 0.21))
                    ant.addLine(to: CGPoint(x: w * 0.44, y: h * 0.34))
                    ant.move(to: CGPoint(x: w * 0.68, y: h * 0.21))
                    ant.addLine(to: CGPoint(x: w * 0.56, y: h * 0.34))
                    ctx.stroke(ant, with: .color(.white), style: StrokeStyle(lineWidth: w * 0.072, lineCap: .round))

                    // Little TV white outer body & pink screen cutout
                    let tvRect = CGRect(x: w * 0.19, y: h * 0.33, width: w * 0.62, height: h * 0.43)
                    ctx.stroke(Path(roundedRect: tvRect, cornerRadius: w * 0.11), with: .color(.white), lineWidth: w * 0.075)

                    // Expressive slanted eyes + tiny legs
                    var details = Path()
                    details.move(to: CGPoint(x: w * 0.34, y: h * 0.50))
                    details.addLine(to: CGPoint(x: w * 0.43, y: h * 0.54))
                    details.move(to: CGPoint(x: w * 0.66, y: h * 0.50))
                    details.addLine(to: CGPoint(x: w * 0.57, y: h * 0.54))
                    // Small w mouth
                    details.move(to: CGPoint(x: w * 0.43, y: h * 0.62))
                    details.addQuadCurve(to: CGPoint(x: w * 0.50, y: h * 0.62), control: CGPoint(x: w * 0.465, y: h * 0.66))
                    details.addQuadCurve(to: CGPoint(x: w * 0.57, y: h * 0.62), control: CGPoint(x: w * 0.535, y: h * 0.66))
                    // Feet
                    details.move(to: CGPoint(x: w * 0.32, y: h * 0.77))
                    details.addLine(to: CGPoint(x: w * 0.30, y: h * 0.82))
                    details.move(to: CGPoint(x: w * 0.68, y: h * 0.77))
                    details.addLine(to: CGPoint(x: w * 0.70, y: h * 0.82))
                    ctx.stroke(details, with: .color(.white), style: StrokeStyle(lineWidth: w * 0.058, lineCap: .round, lineJoin: .round))
                }

            case .portrait4x5:
                shape.fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.99, green: 0.85, blue: 0.46),
                            Color(red: 0.98, green: 0.49, blue: 0.12),
                            Color(red: 0.84, green: 0.16, blue: 0.46),
                            Color(red: 0.59, green: 0.18, blue: 0.75),
                            Color(red: 0.31, green: 0.36, blue: 0.84),
                        ],
                        startPoint: .bottomLeading,
                        endPoint: .topTrailing
                    )
                )
                ZStack {
                    RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
                        .stroke(.white, lineWidth: size * 0.068)
                        .frame(width: size * 0.56, height: size * 0.56)
                    Circle()
                        .stroke(.white, lineWidth: size * 0.068)
                        .frame(width: size * 0.25, height: size * 0.25)
                    Circle()
                        .fill(.white)
                        .frame(width: size * 0.075, height: size * 0.075)
                        .offset(x: size * 0.16, y: -size * 0.16)
                }

            case .youtube16x9:
                shape.fill(Color.white)
                    .overlay(shape.stroke(Color.black.opacity(0.10), lineWidth: 0.6))
                RoundedRectangle(cornerRadius: size * 0.14, style: .continuous)
                    .fill(Color(red: 1.0, green: 0.0, blue: 0.0))
                    .frame(width: size * 0.74, height: size * 0.52)
                    .overlay {
                        Image(systemName: "play.fill")
                            .font(.system(size: size * 0.24, weight: .bold))
                            .foregroundStyle(.white)
                            .offset(x: size * 0.02)
                    }

            case .xCard16x9:
                shape.fill(Color.black)
                Canvas { ctx, s in
                    let w = s.width, h = s.height
                    // Official X geometric mark: hollow double-stroke '\' ribbon + thin solid '/' slash
                    var ribbon = Path()
                    ribbon.move(to: CGPoint(x: w * 0.24, y: h * 0.22))
                    ribbon.addLine(to: CGPoint(x: w * 0.36, y: h * 0.22))
                    ribbon.addLine(to: CGPoint(x: w * 0.76, y: h * 0.78))
                    ribbon.addLine(to: CGPoint(x: w * 0.64, y: h * 0.78))
                    ribbon.closeSubpath()
                    ctx.stroke(ribbon, with: .color(.white), style: StrokeStyle(lineWidth: w * 0.068, lineJoin: .round))

                    var slash = Path()
                    slash.move(to: CGPoint(x: w * 0.72, y: h * 0.22))
                    slash.addLine(to: CGPoint(x: w * 0.26, y: h * 0.78))
                    ctx.stroke(slash, with: .color(.white), style: StrokeStyle(lineWidth: w * 0.072, lineCap: .round))
                }

            case .appStorePhone69, .appStoreIPad13, .appStoreMac16x10:
                shape.fill(
                    LinearGradient(
                        colors: [Color(red: 0.11, green: 0.77, blue: 1.0), Color(red: 0.07, green: 0.44, blue: 0.96)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                Canvas { ctx, s in
                    let w = s.width, h = s.height
                    let stroke = StrokeStyle(lineWidth: w * 0.088, lineCap: .round, lineJoin: .round)
                    var bars = Path()
                    // App Store interlocking 3-bar stylized "A"
                    bars.move(to: CGPoint(x: w * 0.50, y: h * 0.23))
                    bars.addLine(to: CGPoint(x: w * 0.25, y: h * 0.72))
                    bars.move(to: CGPoint(x: w * 0.44, y: h * 0.23))
                    bars.addLine(to: CGPoint(x: w * 0.75, y: h * 0.72))
                    bars.move(to: CGPoint(x: w * 0.22, y: h * 0.58))
                    bars.addLine(to: CGPoint(x: w * 0.78, y: h * 0.58))
                    ctx.stroke(bars, with: .color(.white), style: stroke)
                }

            case .original, .square1x1, .portrait2x3, .classic4x3, .photo3x2:
                shape.fill(Color.secondary.opacity(0.14))
                if let r = preset.ratio {
                    let box = size * 0.56
                    let w = r >= 1 ? box : max(size * 0.24, box * r)
                    let h = r >= 1 ? max(size * 0.24, box / r) : box
                    RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                        .strokeBorder(Theme.accent, lineWidth: 1.7)
                        .frame(width: w, height: h)
                } else {
                    Image(systemName: "aspectratio")
                        .font(.system(size: size * 0.48, weight: .medium))
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .frame(width: size, height: size)
        .overlay(
            shape.stroke(Color.white.opacity(0.16), lineWidth: 0.5)
        )
    }
}

// MARK: - Modular Reusable Studio Panels (Used Inline on ExportScreen & DeviceFrameStudioView)

/// Self-contained Backdrop panel supporting Solid Palette + Hue Strip + ColorPicker, Multi-stop Custom
/// Gradient Synthesizer, Custom Background Photo Picker with Blur/Dim, and Ambient Blur — with or without hardware frame.
struct StudioBackdropPanel: View {
    @Environment(EditorModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme

    var onSelectionFeedback: () -> Void

    @State private var pickedBackdropItem: PhotosPickerItem?
    @State private var isLoadingPhoto = false
    @State private var recipeCursor = 0
    @State private var selectedHue: Double = 0.60

    private var frame: DeviceFrameOptions { model.deviceFrame }

    private var hasActiveBackdrop: Bool {
        frame.isStudioCanvasActive && frame.showsBackground
    }

    private var customBackgroundColorBinding: Binding<Color> {
        Binding(
            get: {
                let c = frame.solidBackgroundColor
                return Color(red: c.red, green: c.green, blue: c.blue)
            },
            set: { newColor in
                if let rgb = CustomColorRGB(cgColor: UIColor(newColor).cgColor) {
                    var next = model.deviceFrame
                    next.solidBackgroundColor = rgb
                    next.backdropKind = .solidColor
                    next.showsBackground = true
                    if next.model == nil { next.enableFramelessBackdrop = true }
                    model.deviceFrame = next
                }
            }
        )
    }

    private var gradStartBinding: Binding<Color> {
        Binding(
            get: {
                let c = frame.customGradientStart
                return Color(red: c.red, green: c.green, blue: c.blue)
            },
            set: { newColor in
                if let rgb = CustomColorRGB(cgColor: UIColor(newColor).cgColor) {
                    var next = model.deviceFrame
                    next.customGradientStart = rgb
                    next.usesCustomGradient = true
                    next.backdropKind = .gradient
                    next.showsBackground = true
                    if next.model == nil { next.enableFramelessBackdrop = true }
                    model.deviceFrame = next
                }
            }
        )
    }

    private var gradMidBinding: Binding<Color> {
        Binding(
            get: {
                let c = frame.customGradientMid ?? blendRGB(frame.customGradientStart, frame.customGradientEnd)
                return Color(red: c.red, green: c.green, blue: c.blue)
            },
            set: { newColor in
                if let rgb = CustomColorRGB(cgColor: UIColor(newColor).cgColor) {
                    var next = model.deviceFrame
                    next.customGradientMid = rgb
                    next.usesCustomGradient = true
                    next.backdropKind = .gradient
                    next.showsBackground = true
                    if next.model == nil { next.enableFramelessBackdrop = true }
                    model.deviceFrame = next
                }
            }
        )
    }

    private var gradEndBinding: Binding<Color> {
        Binding(
            get: {
                let c = frame.customGradientEnd
                return Color(red: c.red, green: c.green, blue: c.blue)
            },
            set: { newColor in
                if let rgb = CustomColorRGB(cgColor: UIColor(newColor).cgColor) {
                    var next = model.deviceFrame
                    next.customGradientEnd = rgb
                    next.usesCustomGradient = true
                    next.backdropKind = .gradient
                    next.showsBackground = true
                    if next.model == nil { next.enableFramelessBackdrop = true }
                    model.deviceFrame = next
                }
            }
        )
    }

    var body: some View {
        let cardShape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        VStack(spacing: 12) {
            // 1. Backdrop Kind & Off/Transparent Strip (always accessible with or without device frame)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button {
                        withAnimation(.snappy(duration: 0.22)) {
                            var next = model.deviceFrame
                            if next.isActive {
                                next.showsBackground = false
                            } else {
                                next.enableFramelessBackdrop = false
                                next.showsBackground = true
                            }
                            model.deviceFrame = next
                        }
                        onSelectionFeedback()
                    } label: {
                        let isOff = !frame.isStudioCanvasActive || (frame.isActive && !frame.showsBackground)
                        HStack(spacing: 5) {
                            Image(systemName: frame.isActive ? "checkerboard.rectangle" : "nosign")
                                .font(.caption.weight(.semibold))
                            Text(frame.isActive ? "frame.backdrop.transparent" : "frame.bgOff")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(isOff ? .white : Theme.body)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(isOff ? Theme.accentButton : Theme.fill))
                    }
                    .buttonStyle(PressStyle(scale: 0.95))

                    ForEach(DeviceBackdropKind.allCases) { kind in
                        let isSel = hasActiveBackdrop && frame.backdropKind == kind
                        Button {
                            withAnimation(.snappy(duration: 0.22)) {
                                var next = model.deviceFrame
                                next.backdropKind = kind
                                next.showsBackground = true
                                if next.model == nil { next.enableFramelessBackdrop = true }
                                model.deviceFrame = next
                            }
                            onSelectionFeedback()
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: iconName(for: kind))
                                    .font(.caption.weight(.semibold))
                                Text(LocalizedStringKey(kind.titleKey))
                                    .font(.caption.weight(.semibold))
                            }
                            .foregroundStyle(isSel ? .white : Theme.body)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(isSel ? Theme.accentButton : Theme.fill))
                        }
                        .buttonStyle(PressStyle(scale: 0.95))
                    }
                }
                .padding(.vertical, 2)
            }

            if !hasActiveBackdrop {
                VStack(alignment: .leading, spacing: 6) {
                    Text(frame.isActive ? "frame.transparentHint" : "frame.framelessHint")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryLabel)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(cardShape.fill(Theme.card))
                .overlay(cardShape.stroke(Theme.cardBorder(for: colorScheme), lineWidth: 0.5))
            } else {
                // 2. Backdrop Editor Body for Selected Kind
                switch frame.backdropKind {
                case .solidColor:
                    solidPaletteEditor(cardShape: cardShape)
                case .gradient:
                    gradientSynthesizerEditor(cardShape: cardShape)
                case .customImage:
                    customImageEditor(cardShape: cardShape)
                case .adaptiveBlur:
                    VStack(alignment: .leading, spacing: 6) {
                        Label("frame.bgKind.adaptiveBlur", systemImage: "sparkles")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.body)
                        Text("frame.backdrop.adaptiveBlurDesc")
                            .font(.footnote)
                            .foregroundStyle(Theme.secondaryLabel)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(cardShape.fill(Theme.card))
                    .overlay(cardShape.stroke(Theme.cardBorder(for: colorScheme), lineWidth: 0.5))
                }
            }
        }
        .onChange(of: pickedBackdropItem) { _, item in
            guard let item else { return }
            Task { @MainActor in
                isLoadingPhoto = true
                defer {
                    isLoadingPhoto = false
                    pickedBackdropItem = nil
                }
                if let source = await Intake.picture(from: item),
                   let cg = source.thumbnail(maxLongSide: 2400) {
                    var next = model.deviceFrame
                    next.customBackgroundImage = CustomBackdropImage(image: cg)
                    next.backdropKind = .customImage
                    next.showsBackground = true
                    if next.model == nil { next.enableFramelessBackdrop = true }
                    model.deviceFrame = next
                    onSelectionFeedback()
                }
            }
        }
    }

    @ViewBuilder
    private func solidPaletteEditor(cardShape: RoundedRectangle) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("frame.solidPaletteTitle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.secondaryLabel)
                Spacer()
                Text(verbatim: hexString(for: frame.solidBackgroundColor))
                    .font(.caption.weight(.semibold).monospaced())
                    .foregroundStyle(Theme.secondaryLabel)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Theme.fill))
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6),
                spacing: 10
            ) {
                ForEach(DeviceFrameOptions.solidSwatches, id: \.self) { swatch in
                    let isSel = frame.solidBackgroundColor == swatch
                    Button {
                        var next = model.deviceFrame
                        next.solidBackgroundColor = swatch
                        next.backdropKind = .solidColor
                        next.showsBackground = true
                        if next.model == nil { next.enableFramelessBackdrop = true }
                        model.deviceFrame = next
                        onSelectionFeedback()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color(red: swatch.red, green: swatch.green, blue: swatch.blue))
                                .frame(width: 30, height: 30)
                                .overlay(Circle().strokeBorder(Color.primary.opacity(0.18), lineWidth: 0.75))
                            if isSel {
                                Circle()
                                    .strokeBorder(Theme.accent, lineWidth: 2.2)
                                    .frame(width: 38, height: 38)
                            }
                        }
                        .frame(height: 40)
                    }
                    .buttonStyle(PressStyle(scale: 0.92))
                }
            }

            // Quick Continuous Spectrum Hue Strip + Native Full ColorPicker
            HStack(spacing: 12) {
                GeometryReader { geo in
                    let w = max(geo.size.width, 1)
                    ZStack(alignment: .leading) {
                        LinearGradient(
                            colors: (0...6).map { Color(hue: Double($0) / 6.0, saturation: 0.78, brightness: 0.92) },
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.primary.opacity(0.12), lineWidth: 0.5))

                        Circle()
                            .fill(Color(hue: selectedHue, saturation: 0.78, brightness: 0.92))
                            .frame(width: 22, height: 22)
                            .overlay(Circle().stroke(.white, lineWidth: 2))
                            .shadow(color: .black.opacity(0.22), radius: 3, y: 1)
                            .offset(x: max(0, min(w - 22, CGFloat(selectedHue) * (w - 22))))
                    }
                    .contentShape(.rect)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let hue = min(max(Double(value.location.x / w), 0), 1)
                                selectedHue = hue
                                let ui = UIColor(hue: hue, saturation: 0.78, brightness: 0.92, alpha: 1)
                                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                                if ui.getRed(&r, green: &g, blue: &b, alpha: &a) {
                                    var next = model.deviceFrame
                                    next.solidBackgroundColor = CustomColorRGB(red: Double(r), green: Double(g), blue: Double(b))
                                    next.backdropKind = .solidColor
                                    next.showsBackground = true
                                    if next.model == nil { next.enableFramelessBackdrop = true }
                                    model.deviceFrame = next
                                }
                            }
                    )
                }
                .frame(height: 22)

                ColorPicker("frame.customColor", selection: customBackgroundColorBinding, supportsOpacity: false)
                    .labelsHidden()
            }
        }
        .padding(14)
        .background(cardShape.fill(Theme.card))
        .overlay(cardShape.stroke(Theme.cardBorder(for: colorScheme), lineWidth: 0.5))
    }

    @ViewBuilder
    private func gradientSynthesizerEditor(cardShape: RoundedRectangle) -> some View {
        VStack(spacing: 10) {
            // Curated Apple Gradients Row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(DeviceGradientPreset.allCases) { preset in
                        let isSel = !frame.usesCustomGradient && frame.gradientPreset == preset
                        let gradientColors = preset.stops.map { Color(red: $0.0, green: $0.1, blue: $0.2) }
                        Button {
                            var next = model.deviceFrame
                            next.backdropKind = .gradient
                            next.usesCustomGradient = false
                            next.gradientPreset = preset
                            // Seed custom gradient pickers cleanly from preset endpoints for seamless further tweaking.
                            if let first = preset.stops.first, let last = preset.stops.last {
                                next.customGradientStart = CustomColorRGB(red: Double(first.0), green: Double(first.1), blue: Double(first.2))
                                next.customGradientMid = preset.stops.count >= 3
                                    ? CustomColorRGB(red: Double(preset.stops[1].0), green: Double(preset.stops[1].1), blue: Double(preset.stops[1].2))
                                    : nil
                                next.customGradientEnd = CustomColorRGB(red: Double(last.0), green: Double(last.1), blue: Double(last.2))
                            }
                            model.deviceFrame = next
                            onSelectionFeedback()
                        } label: {
                            VStack(spacing: 4) {
                                ZStack {
                                    Circle()
                                        .fill(LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .frame(width: 34, height: 34)
                                        .overlay(Circle().strokeBorder(Color.primary.opacity(0.15), lineWidth: 0.75))
                                    if isSel {
                                        Circle()
                                            .strokeBorder(Theme.accent, lineWidth: 2.2)
                                            .frame(width: 42, height: 42)
                                    }
                                }
                                .frame(width: 44, height: 44)

                                Text(LocalizedStringKey(preset.titleKey))
                                    .font(.caption2.weight(isSel ? .semibold : .regular))
                                    .foregroundStyle(isSel ? Theme.accent : Theme.secondaryLabel)
                                    .lineLimit(1)
                            }
                            .frame(minWidth: 48)
                        }
                        .buttonStyle(PressStyle(scale: 0.94))
                    }
                }
                .padding(.vertical, 2)
            }

            // Custom Multi-Stop Gradient Synthesizer Card
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("frame.customGradTitle", systemImage: "paintpalette")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.secondaryLabel)
                    Spacer()

                    Button {
                        var next = model.deviceFrame
                        let swap = next.customGradientStart
                        next.customGradientStart = next.customGradientEnd
                        next.customGradientEnd = swap
                        next.usesCustomGradient = true
                        next.backdropKind = .gradient
                        model.deviceFrame = next
                        onSelectionFeedback()
                    } label: {
                        Label("frame.gradSwap", systemImage: "arrow.left.arrow.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.body)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Theme.fill))
                    }
                    .buttonStyle(PressStyle(scale: 0.94))

                    Button {
                        let recipes = DeviceFrameOptions.customGradientRecipes
                        let pick = recipes[recipeCursor % recipes.count]
                        recipeCursor += 1
                        var next = model.deviceFrame
                        next.customGradientStart = pick.0
                        next.customGradientMid = pick.1
                        next.customGradientEnd = pick.2
                        next.usesCustomGradient = true
                        next.backdropKind = .gradient
                        model.deviceFrame = next
                        onSelectionFeedback()
                    } label: {
                        Label("frame.gradInspire", systemImage: "sparkles")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Theme.accentButton))
                    }
                    .buttonStyle(PressStyle(scale: 0.94))
                }

                // Live Preview Gradient Strip
                let previewColors = frame.activeGradientStops.map { Color(red: $0.0, green: $0.1, blue: $0.2) }
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: previewColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.primary.opacity(0.14), lineWidth: 0.5)
                    )

                // Equal-Width 3-Column Color Stops Row (Start · Optional Mid · End)
                HStack(spacing: 8) {
                    HStack(spacing: 5) {
                        ColorPicker("", selection: gradStartBinding, supportsOpacity: false)
                            .labelsHidden()
                        Text("frame.gradStart")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Theme.body)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .padding(.horizontal, 8)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.fill))

                    if frame.customGradientMid != nil {
                        HStack(spacing: 4) {
                            ColorPicker("", selection: gradMidBinding, supportsOpacity: false)
                                .labelsHidden()
                            Text("frame.gradMid")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Theme.body)
                                .lineLimit(1)
                            Button {
                                var next = model.deviceFrame
                                next.customGradientMid = nil
                                next.usesCustomGradient = true
                                next.backdropKind = .gradient
                                model.deviceFrame = next
                                onSelectionFeedback()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(Theme.secondaryLabel)
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding(.horizontal, 8)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.fill))
                    } else {
                        Button {
                            var next = model.deviceFrame
                            next.customGradientMid = blendRGB(next.customGradientStart, next.customGradientEnd)
                            next.usesCustomGradient = true
                            next.backdropKind = .gradient
                            model.deviceFrame = next
                            onSelectionFeedback()
                        } label: {
                            Label("frame.gradAddMid", systemImage: "plus")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.accent)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .padding(.horizontal, 8)
                                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.accent.opacity(0.12)))
                        }
                        .buttonStyle(PressStyle(scale: 0.95))
                    }

                    HStack(spacing: 5) {
                        ColorPicker("", selection: gradEndBinding, supportsOpacity: false)
                            .labelsHidden()
                        Text("frame.gradEnd")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Theme.body)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .padding(.horizontal, 8)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.fill))
                }

                // Direction Chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(GradientDirection.allCases) { dir in
                            let isDir = frame.gradientDirection == dir
                            Button {
                                model.deviceFrame.gradientDirection = dir
                                model.deviceFrame.backdropKind = .gradient
                                onSelectionFeedback()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: dir.systemImage)
                                        .font(.system(size: 11, weight: .semibold))
                                    Text(LocalizedStringKey(dir.titleKey))
                                        .font(.caption2.weight(.medium))
                                }
                                .foregroundStyle(isDir ? .white : Theme.body)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(isDir ? Theme.accentButton : Theme.fill))
                            }
                            .buttonStyle(PressStyle(scale: 0.95))
                        }
                    }
                }
            }
            .padding(14)
            .background(cardShape.fill(Theme.card))
            .overlay(cardShape.stroke(Theme.cardBorder(for: colorScheme), lineWidth: 0.5))
        }
    }

    @ViewBuilder
    private func customImageEditor(cardShape: RoundedRectangle) -> some View {
        VStack(spacing: 12) {
            if let customBg = frame.customBackgroundImage {
                HStack(spacing: 12) {
                    Image(decorative: customBg.image, scale: 1)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.primary.opacity(0.15), lineWidth: 0.5)
                        )

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            PhotosPicker(selection: $pickedBackdropItem, matching: .images) {
                                Label("frame.customImageChange", systemImage: "photo.on.rectangle")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(Theme.accentButton))
                            }
                            .buttonStyle(PressStyle(scale: 0.95))

                            Button(role: .destructive) {
                                var next = model.deviceFrame
                                next.customBackgroundImage = nil
                                next.backdropKind = .gradient
                                model.deviceFrame = next
                                onSelectionFeedback()
                            } label: {
                                Text("frame.customImageClear")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Theme.secondaryLabel)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(Theme.fill))
                            }
                            .buttonStyle(PressStyle(scale: 0.95))
                        }

                        Text(verbatim: "\(customBg.image.width) × \(customBg.image.height)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(Theme.secondaryLabel)
                    }

                    Spacer(minLength: 0)
                }

                VStack(spacing: 8) {
                    HStack {
                        Label("frame.customImageBlur", systemImage: "drop.halffull")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Theme.body)
                        Spacer()
                        Text(verbatim: "\(Int((frame.customImageBlur * 100).rounded()))%")
                            .font(.caption2.weight(.semibold).monospacedDigit())
                            .foregroundStyle(Theme.secondaryLabel)
                    }
                    Slider(
                        value: Binding(
                            get: { model.deviceFrame.customImageBlur },
                            set: { model.deviceFrame.customImageBlur = $0 }
                        ),
                        in: 0...1,
                        step: 0.05
                    )
                    .tint(Theme.accent)

                    HStack {
                        Label("frame.customImageDim", systemImage: "sun.min")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Theme.body)
                        Spacer()
                        Text(verbatim: "\(Int((frame.customImageDim * 100).rounded()))%")
                            .font(.caption2.weight(.semibold).monospacedDigit())
                            .foregroundStyle(Theme.secondaryLabel)
                    }
                    Slider(
                        value: Binding(
                            get: { model.deviceFrame.customImageDim },
                            set: { model.deviceFrame.customImageDim = $0 }
                        ),
                        in: 0...0.60,
                        step: 0.05
                    )
                    .tint(Theme.accent)
                }
            } else {
                PhotosPicker(selection: $pickedBackdropItem, matching: .images) {
                    VStack(spacing: 8) {
                        if isLoadingPhoto {
                            ProgressView()
                        } else {
                            Image(systemName: "photo.badge.plus")
                                .font(.title2.weight(.medium))
                                .foregroundStyle(Theme.accent)
                        }
                        Text("frame.customImagePick")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.body)
                        Text("frame.customImagePickSub")
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryLabel)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: [6, 4]))
                            .foregroundStyle(Theme.accent.opacity(0.45))
                    )
                }
                .buttonStyle(PressStyle(scale: 0.98))
            }
        }
        .padding(14)
        .background(cardShape.fill(Theme.card))
        .overlay(cardShape.stroke(Theme.cardBorder(for: colorScheme), lineWidth: 0.5))
    }

    private func iconName(for kind: DeviceBackdropKind) -> String {
        switch kind {
        case .gradient: "circle.lefthalf.filled"
        case .solidColor: "paintpalette"
        case .customImage: "photo.on.rectangle"
        case .adaptiveBlur: "sparkles"
        }
    }

    private func blendRGB(_ a: CustomColorRGB, _ b: CustomColorRGB) -> CustomColorRGB {
        CustomColorRGB(
            red: (a.red + b.red) * 0.5,
            green: (a.green + b.green) * 0.5,
            blue: (a.blue + b.blue) * 0.5
        )
    }

    private func hexString(for rgb: CustomColorRGB) -> String {
        let r = Int((rgb.red * 255).rounded())
        let g = Int((rgb.green * 255).rounded())
        let b = Int((rgb.blue * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

/// Self-contained Apple Hardware Category + 2026 Model + Finish selector panel.
struct StudioDeviceFramePanel: View {
    @Environment(EditorModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme

    var onSelectionFeedback: () -> Void
    var onJumpToBackdrop: (() -> Void)? = nil

    private var frame: DeviceFrameOptions { model.deviceFrame }
    private var activeCategory: DeviceCategory { frame.category }

    var body: some View {
        let cardShape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        VStack(spacing: 12) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(DeviceCategory.allCases) { category in
                            categoryPill(for: category)
                                .id(category)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .onAppear {
                    proxy.scrollTo(activeCategory, anchor: .center)
                }
                .onChange(of: activeCategory) { _, newCategory in
                    withAnimation(.snappy(duration: 0.22)) {
                        proxy.scrollTo(newCategory, anchor: .center)
                    }
                }
            }

            if activeCategory == .none {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        IconTile(
                            systemImage: "sparkles.rectangle.stack",
                            ground: Theme.accent.opacity(colorScheme == .dark ? 0.22 : 0.12),
                            tint: Theme.accent
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text("frame.cat.none")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.body)
                            Text("frame.framelessHint")
                                .font(.caption)
                                .foregroundStyle(Theme.secondaryLabel)
                        }
                        Spacer(minLength: 0)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach([AppleDeviceModel.iPhone18ProMax, .macBookPro14M6, .iPadPro11M5]) { quickModel in
                                Button {
                                    var next = model.deviceFrame
                                    next.model = quickModel
                                    next.finish = next.resolvedFinish
                                    model.deviceFrame = next
                                    onSelectionFeedback()
                                } label: {
                                    Label(quickModel.displayName, systemImage: quickModel.systemImage)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Theme.body)
                                        .lineLimit(1)
                                        .padding(.horizontal, 13)
                                        .frame(minHeight: 38)
                                        .background(Capsule().fill(Theme.fill))
                                }
                                .buttonStyle(PressStyle(scale: 0.95))
                            }
                        }
                    }

                    if let onJumpToBackdrop {
                        Button {
                            onJumpToBackdrop()
                        } label: {
                            Label("export.customizeBackdrop", systemImage: "paintpalette")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(Capsule().fill(Theme.accentButton))
                        }
                        .buttonStyle(PressStyle(scale: 0.97))
                    }
                }
                .padding(14)
                .background(cardShape.fill(Theme.card))
                .overlay(cardShape.stroke(Theme.cardBorder(for: colorScheme), lineWidth: 0.5))
            } else {
                // Model cards + metallic finishes
                VStack(alignment: .leading, spacing: 10) {
                    Text("frame.section.model")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.secondaryLabel)

                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(activeCategory.models) { deviceModel in
                                    modelCard(for: deviceModel)
                                        .id(deviceModel)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                        .onAppear {
                            if let current = frame.model {
                                proxy.scrollTo(current, anchor: .center)
                            }
                        }
                        .onChange(of: frame.model) { _, newModel in
                            if let newModel {
                                withAnimation(.snappy(duration: 0.22)) {
                                    proxy.scrollTo(newModel, anchor: .center)
                                }
                            }
                        }
                    }

                    if let selectedModel = frame.model, selectedModel.availableFinishes.count > 1 {
                        Divider()

                        Text("frame.section.finish")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.secondaryLabel)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(selectedModel.availableFinishes) { finish in
                                    finishChip(for: finish)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                .padding(14)
                .background(cardShape.fill(Theme.card))
                .overlay(cardShape.stroke(Theme.cardBorder(for: colorScheme), lineWidth: 0.5))
            }
        }
    }

    private func categoryPill(for category: DeviceCategory) -> some View {
        let isSelected = activeCategory == category
        return Button {
            var next = model.deviceFrame
            if category == .none {
                next.model = nil
            } else if next.category != category {
                next.model = category.models.first
                next.finish = next.resolvedFinish
            }
            model.deviceFrame = next
            onSelectionFeedback()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: category.systemImage)
                    .font(.subheadline.weight(.medium))
                    .symbolRenderingMode(.hierarchical)
                Text(LocalizedStringKey(category.titleKey))
                    .font(.subheadline.weight(isSelected ? .semibold : .medium))
            }
            .foregroundStyle(isSelected ? .white : Theme.body)
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(Capsule().fill(isSelected ? Theme.accentButton : Theme.fill))
        }
        .buttonStyle(PressStyle(scale: 0.95))
    }

    private func modelCard(for deviceModel: AppleDeviceModel) -> some View {
        let isSelected = frame.model == deviceModel
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return Button {
            var next = model.deviceFrame
            next.model = deviceModel
            next.finish = next.resolvedFinish
            model.deviceFrame = next
            onSelectionFeedback()
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: deviceModel.systemImage)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(isSelected ? Theme.accent : Theme.secondaryLabel)
                    Spacer(minLength: 4)
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.accent)
                    }
                }

                Text(verbatim: deviceModel.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? Theme.accent : Theme.body)
                    .lineLimit(1)

                Text(verbatim: deviceModel.specTag)
                    .font(.caption2)
                    .foregroundStyle(Theme.secondaryLabel)
                    .lineLimit(1)
            }
            .frame(minWidth: 144, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                shape.fill(isSelected ? Theme.accent.opacity(colorScheme == .dark ? 0.22 : 0.11) : Theme.fill)
            )
            .overlay(
                shape.strokeBorder(
                    isSelected ? Theme.accent : Theme.cardBorder(for: colorScheme),
                    lineWidth: isSelected ? 1.6 : 0.5
                )
            )
        }
        .buttonStyle(PressStyle(scale: 0.96))
    }

    private func finishChip(for finish: DeviceFinish) -> some View {
        let isSelected = frame.resolvedFinish == finish
        return Button {
            model.deviceFrame.finish = finish
            onSelectionFeedback()
        } label: {
            VStack(spacing: 5) {
                ZStack {
                    Circle()
                        .fill(Color(cgColor: finish.cgColor))
                        .frame(width: 26, height: 26)
                        .overlay(Circle().strokeBorder(Color.primary.opacity(0.18), lineWidth: 0.75))
                    if isSelected {
                        Circle()
                            .strokeBorder(Theme.accent, lineWidth: 2)
                            .frame(width: 34, height: 34)
                    }
                }
                .frame(width: 36, height: 36)

                Text(LocalizedStringKey(finish.titleKey))
                    .font(.caption2.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Theme.accent : Theme.secondaryLabel)
                    .lineLimit(1)
            }
            .frame(minWidth: 50)
        }
        .buttonStyle(PressStyle(scale: 0.94))
    }
}

/// Unified Layout / Template / Corner Radius / Scale panel working cleanly both with and without an Apple hardware frame.
struct StudioLayoutPanel: View {
    @Environment(EditorModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme

    var onSelectionFeedback: () -> Void

    private var frame: DeviceFrameOptions { model.deviceFrame }

    var body: some View {
        let cardShape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        VStack(spacing: 12) {
            // 1. Presentation Templates (works framed or frameless)
            VStack(alignment: .leading, spacing: 10) {
                Text("frame.section.template")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.secondaryLabel)

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
                    spacing: 8
                ) {
                    ForEach(DeviceShowcaseTemplate.allCases) { tpl in
                        templateTile(for: tpl)
                    }
                }

                if frame.template == .heroTopTitle {
                    VStack(spacing: 8) {
                        TextField(
                            "frame.heroTitlePlaceholder",
                            text: Binding(
                                get: { model.deviceFrame.heroTitle },
                                set: { model.deviceFrame.heroTitle = $0 }
                            )
                        )
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.done)

                        TextField(
                            "frame.heroSubtitlePlaceholder",
                            text: Binding(
                                get: { model.deviceFrame.heroSubtitle },
                                set: { model.deviceFrame.heroSubtitle = $0 }
                            )
                        )
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.done)
                    }
                    .padding(.top, 2)
                }
            }
            .padding(14)
            .background(cardShape.fill(Theme.card))
            .overlay(cardShape.stroke(Theme.cardBorder(for: colorScheme), lineWidth: 0.5))

            // 2. Fine Adjustments: Subject Scale, Frameless Corner Radius, Drop Shadow, Output Resolution
            VStack(spacing: 12) {
                if frame.isStudioCanvasActive && frame.showsBackground {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Label(frame.isActive ? "frame.deviceScale" : "frame.subjectScale", systemImage: "arrow.up.left.and.arrow.down.right")
                                .font(.subheadline)
                            Spacer()
                            Text(verbatim: "\(Int((frame.deviceScale * 100).rounded()))%")
                                .font(.footnote.weight(.semibold).monospacedDigit())
                                .foregroundStyle(Theme.secondaryLabel)
                                .contentTransition(.numericText())
                        }
                        Slider(
                            value: Binding(
                                get: { model.deviceFrame.deviceScale },
                                set: { model.deviceFrame.deviceScale = $0 }
                            ),
                            in: 0.50...1.00,
                            step: 0.02
                        )
                        .tint(Theme.accent)
                    }

                    if !frame.isActive {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Label("frame.cornerRadius", systemImage: "square.on.square")
                                    .font(.subheadline)
                                Spacer()
                                Text(verbatim: "\(Int((frame.framelessCornerRadius * 100).rounded()))%")
                                    .font(.footnote.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(Theme.secondaryLabel)
                                    .contentTransition(.numericText())
                            }
                            Slider(
                                value: Binding(
                                    get: { model.deviceFrame.framelessCornerRadius },
                                    set: { model.deviceFrame.framelessCornerRadius = $0 }
                                ),
                                in: 0.00...0.14,
                                step: 0.01
                            )
                            .tint(Theme.accent)
                        }
                    }

                    Divider()

                    Toggle(isOn: Binding(
                        get: { model.deviceFrame.showsShadow },
                        set: { newVal in
                            model.deviceFrame.showsShadow = newVal
                            onSelectionFeedback()
                        }
                    )) {
                        Label("frame.showsShadow", systemImage: "shadow")
                            .font(.subheadline)
                    }
                    .tint(Theme.accent)

                    Divider()
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label("frame.outputScale", systemImage: "aspectratio")
                            .font(.subheadline)
                        Spacer()
                        Text(verbatim: "\(Int((frame.outputScale * 100).rounded()))%")
                            .font(.footnote.weight(.semibold).monospacedDigit())
                            .foregroundStyle(Theme.secondaryLabel)
                            .contentTransition(.numericText())
                    }
                    Slider(
                        value: Binding(
                            get: { model.deviceFrame.outputScale },
                            set: { model.deviceFrame.outputScale = $0 }
                        ),
                        in: 0.40...1.00,
                        step: 0.05
                    )
                    .tint(Theme.accent)

                    HStack(spacing: 8) {
                        ForEach([1.0, 0.75, 0.5], id: \.self) { preset in
                            let isCurrent = abs(frame.outputScale - preset) < 0.01
                            Button {
                                model.deviceFrame.outputScale = preset
                                onSelectionFeedback()
                            } label: {
                                Text(verbatim: "\(Int(preset * 100))%")
                                    .font(.caption.weight(isCurrent ? .semibold : .medium))
                                    .foregroundStyle(isCurrent ? .white : Theme.body)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(isCurrent ? Theme.accentButton : Theme.fill))
                            }
                            .buttonStyle(PressStyle(scale: 0.95))
                        }
                    }
                }
            }
            .padding(14)
            .background(cardShape.fill(Theme.card))
            .overlay(cardShape.stroke(Theme.cardBorder(for: colorScheme), lineWidth: 0.5))
        }
    }

    private func templateTile(for tpl: DeviceShowcaseTemplate) -> some View {
        let isSelected = frame.isStudioCanvasActive && frame.template == tpl
        let shape = RoundedRectangle(cornerRadius: 13, style: .continuous)
        return Button {
            var next = model.deviceFrame
            next.template = tpl
            if next.model == nil { next.enableFramelessBackdrop = true }
            if (tpl == .heroTopTitle || tpl == .bottomBleed || tpl == .topBleed || !next.isActive) && !next.showsBackground {
                next.showsBackground = true
            }
            model.deviceFrame = next
            onSelectionFeedback()
        } label: {
            VStack(spacing: 5) {
                Image(systemName: tpl.systemImage)
                    .font(.system(size: 16, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isSelected ? Theme.accent : Theme.body)
                    .frame(height: 22)

                Text(LocalizedStringKey(tpl.titleKey))
                    .font(.caption2.weight(isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? Theme.accent : Theme.body)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .padding(.horizontal, 6)
            .background(
                shape.fill(isSelected ? Theme.accent.opacity(colorScheme == .dark ? 0.22 : 0.12) : Theme.fill)
            )
            .overlay(
                shape.strokeBorder(
                    isSelected ? Theme.accent : Theme.cardBorder(for: colorScheme),
                    lineWidth: isSelected ? 1.6 : 0.5
                )
            )
        }
        .buttonStyle(PressStyle(scale: 0.96))
    }
}

// MARK: - Standalone Pushable Studio (Maintained cleanly via Shared Modular Panels)

/// Full-screen split live-preview studio for framing, templates, and custom backdrops.
struct DeviceFrameStudioView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case model
        case template
        case backdrop

        var id: String { rawValue }
        var titleKey: String { "frame.tab.\(rawValue)" }
    }

    @Environment(EditorModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var activeTab: Tab = .model
    @State private var renderedPreview: CGImage?
    @State private var selectionFeedbackCount = 0

    private var previewAspect: CGFloat {
        let img = renderedPreview ?? model.preview
        guard img.height > 0 else { return 1 }
        return CGFloat(img.width) / CGFloat(img.height)
    }

    private var outputDimensionText: String {
        if let rendered = renderedPreview, model.deviceFrame.isStudioCanvasActive {
            let ext = model.deviceFrame.needsPNG ? "PNG" : resolvedFormatLabel
            return "\(rendered.width) × \(rendered.height) · \(ext)"
        }
        let scale = model.deviceFrame.outputScale
        let w = Int((model.size.width * scale).rounded())
        let h = Int((model.size.height * scale).rounded())
        return "\(w) × \(h) · \(resolvedFormatLabel)"
    }

    private var resolvedFormatLabel: String {
        let target = model.preferences.exportFormat.utType(original: model.picture.fileType)
        if target == .png { return "PNG" }
        if target == .heic { return "HEIC" }
        if target == .jpeg { return "JPEG" }
        return target.preferredFilenameExtension?.uppercased() ?? "IMAGE"
    }

    var body: some View {
        GeometryReader { proxy in
            let stageHeight = max(236, min(350, proxy.size.height * 0.42))

            VStack(spacing: 0) {
                livePreviewStage(height: stageHeight, width: proxy.size.width)

                Divider()

                Picker("frame.sheetTitle", selection: $activeTab) {
                    ForEach(Tab.allCases) { tab in
                        Text(LocalizedStringKey(tab.titleKey)).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Metrics.pageInset)
                .padding(.vertical, 10)
                .background(Theme.page)

                ScrollView {
                    VStack(spacing: 12) {
                        switch activeTab {
                        case .model:
                            StudioDeviceFramePanel(
                                onSelectionFeedback: { selectionFeedbackCount += 1 },
                                onJumpToBackdrop: { activeTab = .backdrop }
                            )
                        case .template:
                            StudioLayoutPanel {
                                selectionFeedbackCount += 1
                            }
                        case .backdrop:
                            StudioBackdropPanel {
                                selectionFeedbackCount += 1
                            }
                        }
                    }
                    .padding(.horizontal, Metrics.pageInset)
                    .padding(.vertical, 12)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .background(Theme.page.ignoresSafeArea())
        }
        .navigationTitle("frame.sheetTitle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if model.deviceFrame.isStudioCanvasActive {
                    Button("frame.clear") {
                        model.deviceFrame = .none
                        selectionFeedbackCount += 1
                    }
                    .tint(Theme.secondaryLabel)
                }

                Button("frame.done") {
                    dismiss()
                }
                .fontWeight(.semibold)
                .tint(Theme.accent)
            }
        }
        .sensoryFeedback(.selection, trigger: selectionFeedbackCount)
    }

    private func livePreviewStage(height: CGFloat, width: CGFloat) -> some View {
        let maxW = max(140, width - Metrics.pageInset * 2)
        let maxH = max(140, height - 42)
        let fitted = PictureFit.size(aspect: previewAspect, maxWidth: maxW, maxHeight: maxH)

        return ZStack(alignment: .topTrailing) {
            Color(colorScheme == .dark ? .secondarySystemBackground : .systemGroupedBackground)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .overlay {
                    CoveredPicture(editor: model, size: fitted) { rendered in
                        renderedPreview = rendered
                    }
                    .padding(.vertical, 10)
                }

            Text(verbatim: outputDimensionText)
                .font(.caption2.weight(.semibold).monospacedDigit())
                .foregroundStyle(Theme.secondaryLabel)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(Theme.cardBorder(for: colorScheme), lineWidth: 0.5))
                .padding(.trailing, 14)
                .padding(.top, 10)
        }
        .frame(height: height)
    }
}
