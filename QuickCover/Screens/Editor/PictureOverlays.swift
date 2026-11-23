import SwiftUI

/// A capsule of glass over the picture (design.md §6「图上的胶囊」, §4): 36 high, corner 18, 14 inside,
/// white `.subheadline`. With `spins` a 16 pt white spinner comes first, 8 before the text (4.2.1,
/// §7.3.1): one turn in 0.8 s, even. 4.8.4 and 4.8.5 are medium;「原圖」(4.8.6) is semibold.
struct PictureCapsule: View {
    let text: LocalizedStringKey
    var weight: Font.Weight = .medium
    var spins = false

    var body: some View {
        HStack(spacing: 8) {
            if spins {
                Spinner()
                    .frame(width: 16, height: 16)
                    .accessibilityHidden(true)
            }
            Text(text)
                .font(.subheadline.weight(weight))
                .foregroundStyle(Theme.body)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 36)
        .glassEffect(.regular, in: .capsule)
    }
}

/// The「正在找」spinner (§8): 16 pt, a turn in 0.8 s, at an even speed.
struct Spinner: View {
    @State private var isTurning = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.28)
            .stroke(Theme.body, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .rotationEffect(.degrees(isTurning ? 360 : 0))
            .animation(.linear(duration: 0.8).repeatForever(autoreverses: false), value: isTurning)
            .onAppear { isTurning = true }
    }
}

/// The edge that marks a located item (design.md §7.4.3): 3 pt outside the box a 2 pt teal line,
/// outside that 1 pt black, then 5 pt black at 12%. In the points of the picture, so it moves with
/// it. How long it is lit is the picture's business.
struct LocateRing: View {
    /// The item's box.
    let rect: CGRect

    private let corner: CGFloat = 2

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner + 11, style: .continuous)
                .inset(by: -11)
                .strokeBorder(Color.black.opacity(0.12), lineWidth: 5)
            RoundedRectangle(cornerRadius: corner + 6, style: .continuous)
                .inset(by: -6)
                .strokeBorder(Color.black, lineWidth: 1)
            RoundedRectangle(cornerRadius: corner + 4, style: .continuous)
                .inset(by: -4)
                .strokeBorder(Theme.accentOnBlack, lineWidth: 2)
        }
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.midX, y: rect.midY)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The box being drawn (design.md §7.3.7): a 1.5 pt teal edge, teal at 10% inside, corner 3, and a
/// 1 pt black line outside it so it shows on a light picture too.
struct DrawBoxOverlay: View {
    let rect: CGRect

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .inset(by: -1)
                .strokeBorder(Color.black, lineWidth: 1)
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Theme.accentOnBlack.opacity(0.1))
                .strokeBorder(Theme.accentOnBlack, lineWidth: 1.5)
        }
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.midX, y: rect.midY)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
