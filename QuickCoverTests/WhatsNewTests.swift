import Foundation
import Photos
import Testing
import UIKit

@testable import QuickCover

@MainActor
struct WhatsNewTests {

    private func makeDefaults() -> (UserDefaults, String) {
        let suiteName = "QuickCover.WhatsNewTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }

    private func cleanupDefaults(_ suiteName: String) {
        UserDefaults().removePersistentDomain(forName: suiteName)
    }

    // MARK: - Catalog & Platform Filtering

    @Test
    func catalogMatchesExactVersionAndFallsBackToLatest() {
        let exact = WhatsNewCatalog.release(forVersion: "1.0", build: "4")
        #expect(exact?.version == "1.0-4")
        #expect(exact?.releaseNotesURL.absoluteString.hasSuffix("/v1.0-4") == true)

        let latestExact = WhatsNewCatalog.release(forVersion: "1.1", build: "6")
        #expect(latestExact?.version == "1.1-6")
        #expect(latestExact?.releaseNotesURL.absoluteString.hasSuffix("/v1.1-6") == true)
        #expect(latestExact?.features(for: .mobile).count == 5)

        // Unknown future release falls back to the newest catalog entry.
        let fallback = WhatsNewCatalog.release(forVersion: "2.4.1", build: "99")
        #expect(fallback?.version == WhatsNewCatalog.releases.first?.version)
    }

    @Test
    func featureListFiltersByPlatform() {
        let sample = WhatsNewRelease(
            version: "2.0.0",
            releaseNotesURL: WhatsNewCatalog.defaultReleaseNotesURL,
            features: [
                WhatsNewFeature(
                    id: "shared",
                    systemImage: "sparkles",
                    accent: .indigo,
                    titleKey: "whatsnew.v1_0_5.privacy.title",
                    descriptionKey: "whatsnew.v1_0_5.privacy.body",
                    platform: .all
                ),
                WhatsNewFeature(
                    id: "mobile-only",
                    systemImage: "iphone",
                    accent: .blue,
                    titleKey: "whatsnew.v1_0_5.gallery.title",
                    descriptionKey: "whatsnew.v1_0_5.gallery.body",
                    platform: .mobile
                ),
                WhatsNewFeature(
                    id: "desktop-only",
                    systemImage: "laptopcomputer",
                    accent: .teal,
                    titleKey: "whatsnew.v1_0_5.frames.title",
                    descriptionKey: "whatsnew.v1_0_5.frames.body",
                    platform: .desktop
                ),
            ]
        )

        #expect(sample.features(for: .mobile).map(\.id) == ["shared", "mobile-only"])
        #expect(sample.features(for: .desktop).map(\.id) == ["shared", "desktop-only"])
        #expect(sample.features(for: .all).map(\.id) == ["shared"])
    }

    @Test
    func displayVersionFormatsSemverAndBuildReleasesCleanly() {
        #expect(WhatsNewCatalog.displayVersion(shortVersion: "1.0", build: "5") == "1.0 (5)")
        #expect(WhatsNewCatalog.displayVersion(shortVersion: "1.2.0", build: "12") == "1.2.0")
        #expect(WhatsNewCatalog.displayVersion(shortVersion: "1.0", build: "") == "1.0")
    }

    // MARK: - Local Persistence & Debug Overrides

    @Test
    func localStoreTracksSeenPerVersionAndTriggersAgainOnUpgrade() {
        let (defaults, suiteName) = makeDefaults()
        defer { cleanupDefaults(suiteName) }

        let v6 = WhatsNewStore(
            defaults: defaults,
            environment: [:],
            arguments: [],
            shortVersion: "1.1",
            build: "6"
        )
        #expect(v6.shouldAutoPresent == true)
        #expect(v6.lastSeenVersion == nil)

        v6.markCurrentVersionSeen()
        #expect(v6.lastSeenVersion == "1.1-6")
        #expect(v6.shouldAutoPresent == false)

        // Upgrading to a new build/version triggers What's New again once.
        let v7 = WhatsNewStore(
            defaults: defaults,
            environment: [:],
            arguments: [],
            shortVersion: "1.1",
            build: "7"
        )
        #expect(v7.shouldAutoPresent == true)
        #expect(v7.resolvedRelease?.version == WhatsNewCatalog.releases.first?.version)
    }

    @Test
    func debugOverridesForcePreviewEvenWhenAlreadySeen() {
        let (defaults, suiteName) = makeDefaults()
        defer { cleanupDefaults(suiteName) }

        let baseline = WhatsNewStore(
            defaults: defaults,
            environment: [:],
            arguments: [],
            shortVersion: "1.0",
            build: "5"
        )
        baseline.markCurrentVersionSeen()
        #expect(baseline.shouldAutoPresent == false)

        let envOverride = WhatsNewStore(
            defaults: defaults,
            environment: [WhatsNewStore.forcePreviewEnvironmentKey: "1"],
            arguments: [],
            shortVersion: "1.0",
            build: "5"
        )
        #expect(envOverride.isForcePreviewEnabled == true)
        #expect(envOverride.shouldAutoPresent == true)

        let argOverride = WhatsNewStore(
            defaults: defaults,
            environment: [:],
            arguments: ["QuickCover", "--force-whats-new"],
            shortVersion: "1.0",
            build: "5"
        )
        #expect(argOverride.isForcePreviewEnabled == true)
        #expect(argOverride.shouldAutoPresent == true)

        #expect(baseline.isForcePreviewURL(URL(string: "quickcover://open?forceWhatsNew=1")!) == true)
        #expect(baseline.isForcePreviewURL(URL(string: "quickcover://open?whatsnew=true")!) == true)
        #expect(baseline.isForcePreviewURL(URL(string: "quickcover://open?forceWhatsNew=0")!) == false)
    }

    // MARK: - ShellModel Trigger Timing & Modes

    @Test
    func primerDelaysAutoPresentationUntilOnboardingCompletes() async throws {
        let (defaults, suiteName) = makeDefaults()
        defer { cleanupDefaults(suiteName) }

        let store = WhatsNewStore(
            defaults: defaults,
            environment: [:],
            arguments: [],
            shortVersion: "1.0",
            build: "5"
        )
        let shell = ShellModel(
            authorization: { .notDetermined },
            requestAccess: { .full },
            latestScreenshot: { nil },
            whatsNewStore: store,
            whatsNewPostPrimerDelay: .milliseconds(80),
            whatsNewLaunchDelay: .zero
        )

        await shell.start()
        #expect(shell.page == .primer)
        #expect(shell.whatsNewPresentation == nil, "must not present while onboarding primer is active")

        await shell.allowAccess()
        #expect(shell.page == .picker)
        #expect(shell.whatsNewPresentation == nil, "waits for post-primer settling delay to avoid overlapping sheets")

        try await Task.sleep(for: .milliseconds(160))
        #expect(shell.whatsNewPresentation != nil)
        #expect(shell.whatsNewPresentation?.mode == .automatic)
        #expect(shell.whatsNewPresentation?.mode.showsCloseButton == false)

        shell.dismissWhatsNew()
        #expect(shell.whatsNewPresentation == nil)
        #expect(store.lastSeenVersion == "1.0-5")
        #expect(store.shouldAutoPresent == false)
    }

    @Test
    func manualPresentationShowsCloseButtonEvenAfterAlreadySeen() async {
        let (defaults, suiteName) = makeDefaults()
        defer { cleanupDefaults(suiteName) }

        let store = WhatsNewStore(
            defaults: defaults,
            environment: [:],
            arguments: [],
            shortVersion: "1.0",
            build: "5"
        )
        store.markCurrentVersionSeen()

        let shell = ShellModel(
            authorization: { .authorized },
            requestAccess: { .full },
            latestScreenshot: { nil },
            whatsNewStore: store,
            whatsNewPostPrimerDelay: .zero,
            whatsNewLaunchDelay: .zero
        )

        await shell.start()
        #expect(shell.whatsNewPresentation == nil)

        shell.presentWhatsNewManually()
        #expect(shell.whatsNewPresentation?.mode == .manual)
        #expect(shell.whatsNewPresentation?.mode.showsCloseButton == true)

        shell.dismissWhatsNew()
        #expect(shell.whatsNewPresentation == nil)
    }

    @Test
    func urlDebugQueryOpensWhatsNew() {
        let (defaults, suiteName) = makeDefaults()
        defer { cleanupDefaults(suiteName) }

        let store = WhatsNewStore(
            defaults: defaults,
            environment: [:],
            arguments: [],
            shortVersion: "1.0",
            build: "5"
        )
        store.markCurrentVersionSeen()

        let shell = ShellModel(
            authorization: { .authorized },
            whatsNewStore: store,
            whatsNewPostPrimerDelay: .zero,
            whatsNewLaunchDelay: .zero
        )

        shell.handleOpenURL(URL(string: "quickcover://preview?forceWhatsNew=1")!)
        #expect(shell.whatsNewPresentation != nil)
        #expect(shell.whatsNewPresentation?.mode == .manual)
    }

    // MARK: - Localization & SF Symbol Completeness

    @Test
    func allCatalogSymbolsAndTranslationsExist() {
        let languages = ["en", "zh-Hans", "zh-Hant"]
        let chromeKeys = [
            "whatsnew.title",
            "whatsnew.versionFormat",
            "whatsnew.releaseNotes",
            "whatsnew.continue",
            "whatsnew.close",
            "whatsnew.entryTitle",
            "whatsnew.menuItem",
        ]

        for language in languages {
            let bundle = L10n.bundle(for: language)
            for key in chromeKeys {
                let value = L10n.text(key, bundle: bundle)
                #expect(!value.isEmpty && value != key, "Missing \(language) localization for \(key)")
            }
            for release in WhatsNewCatalog.releases {
                for feature in release.features {
                    let title = L10n.text(feature.titleKey, bundle: bundle)
                    let desc = L10n.text(feature.descriptionKey, bundle: bundle)
                    #expect(!title.isEmpty && title != feature.titleKey, "Missing \(language) \(feature.titleKey)")
                    #expect(!desc.isEmpty && desc != feature.descriptionKey, "Missing \(language) \(feature.descriptionKey)")
                }
            }
        }

        for release in WhatsNewCatalog.releases {
            for feature in release.features {
                #expect(UIImage(systemName: feature.systemImage) != nil, "Invalid SF Symbol \(feature.systemImage)")
            }
        }
        #expect(UIImage(systemName: "xmark") != nil)
        #expect(UIImage(systemName: "arrow.up.right") != nil)

        #expect(L10n.whatsNewVersion("1.1 (6)", bundle: L10n.bundle(for: "en")) == "Version 1.1 (6)")
        #expect(L10n.whatsNewVersion("1.1 (6)", bundle: L10n.bundle(for: "zh-Hans")) == "版本 1.1 (6)")
        #expect(L10n.whatsNewVersion("1.1 (6)", bundle: L10n.bundle(for: "zh-Hant")) == "版本 1.1 (6)")
    }
}
