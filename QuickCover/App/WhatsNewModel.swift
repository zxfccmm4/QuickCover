import Foundation
import SwiftUI

/// Target platform filter for individual What's New feature highlights.
enum WhatsNewPlatform: String, CaseIterable, Hashable, Sendable {
    case all
    case desktop
    case mobile

    static var current: WhatsNewPlatform {
        #if os(macOS)
        .desktop
        #else
        .mobile
        #endif
    }

    func matches(_ target: WhatsNewPlatform) -> Bool {
        self == .all || self == target
    }
}

/// A single highlighted feature row inside the What's New sheet.
struct WhatsNewFeature: Identifiable, Hashable, Sendable {
    enum AccentTone: String, CaseIterable, Hashable, Sendable {
        case indigo
        case green
        case blue
        case teal
        case orange
        case purple

        var color: Color {
            switch self {
            case .indigo: .indigo
            case .green: .green
            case .blue: .blue
            case .teal: .teal
            case .orange: .orange
            case .purple: .purple
            }
        }
    }

    let id: String
    let systemImage: String
    let accent: AccentTone
    let titleKey: String
    let descriptionKey: String
    let platform: WhatsNewPlatform

    init(
        id: String,
        systemImage: String,
        accent: AccentTone,
        titleKey: String,
        descriptionKey: String,
        platform: WhatsNewPlatform = .all
    ) {
        self.id = id
        self.systemImage = systemImage
        self.accent = accent
        self.titleKey = titleKey
        self.descriptionKey = descriptionKey
        self.platform = platform
    }
}

/// Curated What's New payload for a specific app release.
struct WhatsNewRelease: Identifiable, Hashable, Sendable {
    let version: String
    let releaseNotesURL: URL
    let features: [WhatsNewFeature]

    var id: String { version }

    func features(for platform: WhatsNewPlatform = .current) -> [WhatsNewFeature] {
        features.filter { $0.platform.matches(platform) }
    }
}

/// Distinguishes automatic upgrade presentation from manual replay (e.g. from About or menu bar).
enum WhatsNewPresentationMode: Equatable, Sendable {
    case automatic
    case manual

    /// Mobile sheets only display a top-right close button when opened manually.
    var showsCloseButton: Bool {
        self == .manual
    }
}

/// Active presentation payload bound to the root sheet.
struct WhatsNewPresentation: Identifiable, Equatable, Sendable {
    let id: UUID
    let release: WhatsNewRelease
    let displayVersion: String
    let mode: WhatsNewPresentationMode

    init(
        id: UUID = UUID(),
        release: WhatsNewRelease,
        displayVersion: String,
        mode: WhatsNewPresentationMode
    ) {
        self.id = id
        self.release = release
        self.displayVersion = displayVersion
        self.mode = mode
    }
}

/// Versioned catalog of QuickCover What's New entries, ordered newest-first.
enum WhatsNewCatalog {
    static let defaultReleaseNotesURL = URL(string: "https://github.com/zxfccmm4/QuickCover/releases")!

    static let releases: [WhatsNewRelease] = [
        WhatsNewRelease(
            version: "1.1-6",
            releaseNotesURL: URL(string: "https://github.com/zxfccmm4/QuickCover/releases/tag/v1.1-6")!,
            features: [
                WhatsNewFeature(
                    id: "v1_1_6-longshot",
                    systemImage: "rectangle.split.1x2",
                    accent: .indigo,
                    titleKey: "whatsnew.v1_0_5.longshot.title",
                    descriptionKey: "whatsnew.v1_0_5.longshot.body",
                    platform: .all
                ),
                WhatsNewFeature(
                    id: "v1_1_6-frames",
                    systemImage: "iphone",
                    accent: .blue,
                    titleKey: "whatsnew.v1_0_5.frames.title",
                    descriptionKey: "whatsnew.v1_0_5.frames.body",
                    platform: .all
                ),
                WhatsNewFeature(
                    id: "v1_1_6-gallery",
                    systemImage: "photo.on.rectangle.angled",
                    accent: .teal,
                    titleKey: "whatsnew.v1_0_5.gallery.title",
                    descriptionKey: "whatsnew.v1_0_5.gallery.body",
                    platform: .mobile
                ),
                WhatsNewFeature(
                    id: "v1_1_6-emoji",
                    systemImage: "swatchpalette.fill",
                    accent: .orange,
                    titleKey: "whatsnew.v1_0_5.emoji.title",
                    descriptionKey: "whatsnew.v1_0_5.emoji.body",
                    platform: .all
                ),
                WhatsNewFeature(
                    id: "v1_1_6-privacy",
                    systemImage: "lock.shield.fill",
                    accent: .green,
                    titleKey: "whatsnew.v1_0_5.privacy.title",
                    descriptionKey: "whatsnew.v1_0_5.privacy.body",
                    platform: .all
                ),
            ]
        ),
        WhatsNewRelease(
            version: "1.0-4",
            releaseNotesURL: URL(string: "https://github.com/zxfccmm4/QuickCover/releases/tag/v1.0-4")!,
            features: [
                WhatsNewFeature(
                    id: "v1_0_4-about",
                    systemImage: "info.circle.fill",
                    accent: .blue,
                    titleKey: "whatsnew.v1_0_4.about.title",
                    descriptionKey: "whatsnew.v1_0_4.about.body",
                    platform: .all
                ),
                WhatsNewFeature(
                    id: "v1_0_4-capabilities",
                    systemImage: "sparkles",
                    accent: .indigo,
                    titleKey: "whatsnew.v1_0_4.capabilities.title",
                    descriptionKey: "whatsnew.v1_0_4.capabilities.body",
                    platform: .all
                ),
                WhatsNewFeature(
                    id: "v1_0_4-privacy",
                    systemImage: "hand.raised.fill",
                    accent: .green,
                    titleKey: "whatsnew.v1_0_4.privacy.title",
                    descriptionKey: "whatsnew.v1_0_4.privacy.body",
                    platform: .all
                ),
                WhatsNewFeature(
                    id: "v1_0_4-l10n",
                    systemImage: "globe",
                    accent: .teal,
                    titleKey: "whatsnew.v1_0_4.l10n.title",
                    descriptionKey: "whatsnew.v1_0_4.l10n.body",
                    platform: .all
                ),
            ]
        ),
        WhatsNewRelease(
            version: "1.0-3",
            releaseNotesURL: URL(string: "https://github.com/zxfccmm4/QuickCover/releases/tag/v1.0-3")!,
            features: [
                WhatsNewFeature(
                    id: "v1_0_3-ai",
                    systemImage: "sparkles",
                    accent: .indigo,
                    titleKey: "whatsnew.v1_0_3.ai.title",
                    descriptionKey: "whatsnew.v1_0_3.ai.body",
                    platform: .all
                ),
                WhatsNewFeature(
                    id: "v1_0_3-magic",
                    systemImage: "wand.and.stars",
                    accent: .blue,
                    titleKey: "whatsnew.v1_0_3.magic.title",
                    descriptionKey: "whatsnew.v1_0_3.magic.body",
                    platform: .all
                ),
                WhatsNewFeature(
                    id: "v1_0_3-palette",
                    systemImage: "paintpalette.fill",
                    accent: .orange,
                    titleKey: "whatsnew.v1_0_3.palette.title",
                    descriptionKey: "whatsnew.v1_0_3.palette.body",
                    platform: .all
                ),
                WhatsNewFeature(
                    id: "v1_0_3-offline",
                    systemImage: "lock.shield.fill",
                    accent: .green,
                    titleKey: "whatsnew.v1_0_3.offline.title",
                    descriptionKey: "whatsnew.v1_0_3.offline.body",
                    platform: .all
                ),
            ]
        ),
    ]

    /// Reads `(CFBundleShortVersionString, CFBundleVersion)` from the target bundle.
    static func currentVersionInfo(in bundle: Bundle = .main) -> (shortVersion: String, build: String) {
        let shortVersion = (bundle.infoDictionary?["CFBundleShortVersionString"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let build = (bundle.infoDictionary?["CFBundleVersion"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (
            shortVersion?.isEmpty == false ? shortVersion! : "1.0.0",
            build ?? ""
        )
    }

    /// Canonical version key persisted locally so both marketing-version bumps (e.g. `1.1.0`)
    /// and QuickCover build releases (e.g. `1.0-5` → `1.0-6`) trigger What's New once per device.
    static func versionKey(shortVersion: String, build: String?) -> String {
        let version = shortVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBuild = build?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmedBuild.isEmpty else { return version }
        return "\(version)-\(trimmedBuild)"
    }

    /// Human-friendly version text rendered inside the Version badge pill.
    static func displayVersion(shortVersion: String, build: String?) -> String {
        let version = shortVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBuild = build?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let components = version.split(separator: ".")
        if components.count >= 3 || trimmedBuild.isEmpty {
            return version
        }
        return "\(version) (\(trimmedBuild))"
    }

    /// Resolves the best matching release entry for a version/build pair, automatically falling back
    /// to the newest curated release when the running version has no explicit catalog entry yet.
    static func release(
        forVersion version: String,
        build: String? = nil,
        in catalog: [WhatsNewRelease] = releases
    ) -> WhatsNewRelease? {
        guard !catalog.isEmpty else { return nil }
        let normalizedVersion = version.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedBuild = build?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let normalizedBuild, !normalizedBuild.isEmpty {
            let combined = "\(normalizedVersion)-\(normalizedBuild)"
            if let exact = catalog.first(where: { $0.version == combined }) {
                return exact
            }
        }

        if let exact = catalog.first(where: { $0.version == normalizedVersion }) {
            return exact
        }

        let parts = normalizedVersion.split(separator: ".")
        if parts.count >= 2 {
            let majorMinor = "\(parts[0]).\(parts[1])"
            if let minorMatch = catalog.first(where: { $0.version == majorMinor }) {
                return minorMatch
            }
        }

        return catalog.first
    }
}

/// Device-local persistence and debug-override evaluator for What's New presentation.
///
/// Intentionally backed by local `UserDefaults` (never iCloud / `NSUbiquitousKeyValueStore`)
/// so every device a user upgrades presents What's New once independently.
@MainActor
final class WhatsNewStore {
    static let lastSeenVersionKey = "whatsnew.lastSeenVersion"
    static let forcePreviewEnvironmentKey = "QUICKCOVER_FORCE_WHATS_NEW"
    static let forcePreviewLaunchArguments: Set<String> = ["-ForceWhatsNew", "--force-whats-new"]
    static let forcePreviewQueryParameters: Set<String> = ["forcewhatsnew", "whatsnew"]

    private let defaults: UserDefaults
    private let environment: [String: String]
    private let arguments: [String]
    private let catalog: [WhatsNewRelease]
    private let platform: WhatsNewPlatform

    let shortVersion: String
    let build: String

    init(
        defaults: UserDefaults = .standard,
        bundle: Bundle = .main,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        arguments: [String] = ProcessInfo.processInfo.arguments,
        shortVersion: String? = nil,
        build: String? = nil,
        catalog: [WhatsNewRelease] = WhatsNewCatalog.releases,
        platform: WhatsNewPlatform = .current
    ) {
        let info = WhatsNewCatalog.currentVersionInfo(in: bundle)
        self.defaults = defaults
        self.environment = environment
        self.arguments = arguments
        self.shortVersion = shortVersion ?? info.shortVersion
        self.build = build ?? info.build
        self.catalog = catalog
        self.platform = platform
    }

    var currentVersionKey: String {
        WhatsNewCatalog.versionKey(shortVersion: shortVersion, build: build)
    }

    var displayVersion: String {
        WhatsNewCatalog.displayVersion(shortVersion: shortVersion, build: build)
    }

    var lastSeenVersion: String? {
        defaults.string(forKey: Self.lastSeenVersionKey)
    }

    /// True when developer preview override is enabled via environment variable or launch argument.
    var isForcePreviewEnabled: Bool {
        if let raw = environment[Self.forcePreviewEnvironmentKey] {
            if Self.isTruthyFlag(raw) {
                return true
            }
        }
        return arguments.contains { Self.forcePreviewLaunchArguments.contains($0) }
    }

    /// True when a deep link / URL contains a debug preview query parameter (e.g. `?forceWhatsNew=1`).
    func isForcePreviewURL(_ url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return false
        }
        return queryItems.contains { item in
            Self.forcePreviewQueryParameters.contains(item.name.lowercased())
                && Self.isTruthyFlag(item.value ?? "1")
        }
    }

    /// Resolved release entry for the current version, falling back to the latest entry if needed.
    var resolvedRelease: WhatsNewRelease? {
        guard let release = WhatsNewCatalog.release(
            forVersion: shortVersion,
            build: build,
            in: catalog
        ) else {
            return nil
        }
        guard !release.features(for: platform).isEmpty else {
            return nil
        }
        return release
    }

    /// True when the sheet should appear automatically on this device.
    var shouldAutoPresent: Bool {
        guard resolvedRelease != nil else { return false }
        if isForcePreviewEnabled {
            return true
        }
        return lastSeenVersion != currentVersionKey
    }

    /// Records the current device as having seen this version.
    func markCurrentVersionSeen() {
        defaults.set(currentVersionKey, forKey: Self.lastSeenVersionKey)
    }

    /// Clears the local seen record (useful in tests and debug tooling).
    func resetSeenState() {
        defaults.removeObject(forKey: Self.lastSeenVersionKey)
    }

    func makePresentation(mode: WhatsNewPresentationMode) -> WhatsNewPresentation? {
        guard let release = resolvedRelease else { return nil }
        return WhatsNewPresentation(
            release: release,
            displayVersion: displayVersion,
            mode: mode
        )
    }

    private static func isTruthyFlag(_ value: String) -> Bool {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes", "on":
            true
        default:
            false
        }
    }
}
