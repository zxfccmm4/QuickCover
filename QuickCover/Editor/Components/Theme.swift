import SwiftUI
import UIKit

/// Apple HIG semantic design tokens for QuickCover across Light and Dark appearances.
/// Standard pages adopt dynamic system surfaces and Liquid Glass; the editor canvas and its live
/// inspector sheets share a focused dark photo-studio aesthetic like Apple Photos & Markup.
enum Theme {
    /// Adaptive brand teal (`#0A7E80` Light / `#5EDCD4` Dark).
    static let accent = Color("AccentColor")
    /// Luminous teal for active tool indicators and selection overlays on the dark editor canvas.
    static let accentOnBlack = Color("AccentOnBlack")
    /// Deep accessible teal for prominent white-on-tint actions (`#0B7A7A` Light / `#0D8A8B` Dark).
    static let accentButton = Color("AccentButton")

    /// Primary label color, adapting automatically to Light and Dark Mode.
    static let body = Color.primary
    /// Secondary descriptive text using system semantic contrast.
    static let secondaryLabel = Color.secondary
    /// Tertiary color for disabled controls and disclosure indicators.
    static let tertiary = Color(.tertiaryLabel)
    /// System separator tint.
    static let separator = Color(.separator)

    /// Standard grouped page canvas (`systemGroupedBackground`).
    static let page = Color(.systemGroupedBackground)
    /// Pure black studio backdrop used exclusively by the photo editor canvas.
    static let studioCanvas = Color.black
    /// Elevated card surface (`secondarySystemGroupedBackground`).
    static let card = Color(.secondarySystemGroupedBackground)
    /// Secondary text inside callouts.
    static let calloutText = Color.secondary

    /// System fills for icon badges and subtle tracks.
    static let fill = Color(.tertiarySystemFill)
    static let fillTwo = Color(.quaternarySystemFill)

    /// Semantic warning surface and glyph tint (blur / mosaic / stripes advisories).
    static let blurNotice = Color.orange.opacity(0.14)
    static let blurNoticeIcon = Color.orange

    /// High-contrast foreground on luminous teal in the dark editor studio.
    static let onAccent = Color(hex: 0x0B3B3F)
    /// Confirmation green for saved/copied toasts.
    static let saved = Color.green
    /// System destructive/error red.
    static let errorIcon = Color.red

    static let disabledOpacity = 0.42

    /// Subtle hairline border adapting cleanly to Light and Dark Mode cards.
    static func cardBorder(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white.opacity(0.09) : Color.black.opacity(0.05)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}

extension Font {
    static let glassIcon = Font.system(size: 19, weight: .semibold)
    static let tileIcon = Font.system(size: 16, weight: .semibold)
    static let noticeIcon = Font.system(size: 18, weight: .semibold)
    static let buttonText = Font.body.weight(.semibold)
    static let smallButtonText = Font.subheadline.weight(.semibold)
}

/// Shared Apple HIG spacing & concentric corner metrics.
enum Metrics {
    static let pageInset: CGFloat = 16
    static let cardRadius: CGFloat = 20
    static let innerRadius: CGFloat = 12
    static let cardSpacing: CGFloat = 20
    static let rowMinHeight: CGFloat = 52
    static let minimumTarget: CGFloat = 44
}

// MARK: - iOS 26 / 27 Progressive Apple Design Helpers

extension View {
    /// Applies iOS 27 `navigationTransition(.crossFade)` when compiled with the iOS 27 SDK.
    @ViewBuilder
    func crossFadeTransitionIfAvailable() -> some View {
        #if compiler(>=6.4)
        if #available(iOS 27.0, *) {
            self.navigationTransition(.crossFade)
        } else {
            self
        }
        #else
        self
        #endif
    }

    /// Uses iOS 27 `alert(error:actions:)` when compiled with the iOS 27 SDK, falling back cleanly
    /// to iOS 26 `alert(isPresented:error:actions:)`.
    @ViewBuilder
    func localizedErrorAlert<E: LocalizedError, A: View>(
        error: Binding<E?>,
        @ViewBuilder actions: () -> A
    ) -> some View {
        #if compiler(>=6.4)
        if #available(iOS 27.0, *) {
            self.alert(error: error, actions: actions)
        } else {
            self.alert(
                isPresented: Binding(
                    get: { error.wrappedValue != nil },
                    set: { if !$0 { error.wrappedValue = nil } }
                ),
                error: error.wrappedValue,
                actions: { _ in actions() },
                message: { _ in EmptyView() }
            )
        }
        #else
        self.alert(
            isPresented: Binding(
                get: { error.wrappedValue != nil },
                set: { if !$0 { error.wrappedValue = nil } }
            ),
            error: error.wrappedValue,
            actions: { _ in actions() },
            message: { _ in EmptyView() }
        )
        #endif
    }

    /// Supports iOS 27 `pasteDestination(for:)` for image payloads when compiled with the iOS 27 SDK.
    @ViewBuilder
    func imagePasteDestination(perform action: @escaping ([Data]) -> Void) -> some View {
        #if compiler(>=6.4)
        if #available(iOS 27.0, *) {
            self.pasteDestination(for: Data.self, action: action)
        } else {
            self
        }
        #else
        self
        #endif
    }

    /// Supports iOS 27 `copyable(_:)` on exported images when compiled with the iOS 27 SDK.
    @ViewBuilder
    func copyableTransferable<T: Transferable>(_ item: @autoclosure @escaping () -> [T]) -> some View {
        #if compiler(>=6.4)
        if #available(iOS 27.0, *) {
            self.copyable(item())
        } else {
            self
        }
        #else
        self
        #endif
    }
}

/// Preserves the OS Light/Dark color scheme across dark-studio child subtrees when needed.
private struct SystemColorSchemeKey: EnvironmentKey {
    static let defaultValue: ColorScheme = .light
}

extension EnvironmentValues {
    var systemColorScheme: ColorScheme {
        get { self[SystemColorSchemeKey.self] }
        set { self[SystemColorSchemeKey.self] = newValue }
    }
}
