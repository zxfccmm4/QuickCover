# QuickCover · 秒遮

**English** · [简体中文](README.zh-CN.md)

**Redact in one second. Share with peace of mind.**

Open the app and your latest screenshot is already masked. Give it a quick glance, tap Export, and you're done. Your images never leave your iPhone.

QuickCover is an on-device privacy redaction app built for iOS 26+ with native Liquid Glass design. Before you share a screenshot or photo, it automatically detects and masks faces, phone numbers, ID numbers, bank cards, QR codes, and more — and uses on-device Apple Intelligence to catch contextual sensitive lines like names, addresses, and order numbers. Tap or drag to cover anything else, then export a clean new image while leaving the original untouched.

## Key Features

- **Ready on Launch**: Once Photos access is granted, QuickCover opens directly on your latest screenshot already masked. You can also pick from Photos, paste from the clipboard, or import via the built-in document scanner.
- **Dual On-Device Detection**:
  - **Vision + Pattern Rules**: Automatically detects faces, phone numbers, ID numbers, bank card numbers, emails, URLs, IP addresses, long numeric strings (such as order numbers), likely license plates, QR codes, and barcodes.
  - **Apple Intelligence Semantic Privacy Scan** (iOS 26+ `FoundationModels`): Tap the sparkle button in the editor bar or run a scan from the Review sheet to catch contextual PII that regex rules miss — including personal names, street/shipping addresses, company or school names, order/tracking numbers, license plates, and balances. Gracefully falls back to a local contextual matcher when Apple Intelligence is unavailable.
- **6 Mask Styles, Custom Colors & 48+ Emoji Stickers**:
  - **Mosaic** (default): Supports original auto-sampled pixel blocks as well as tinted color mosaics across 12 curated Apple hues + native full-spectrum `ColorPicker`, with Fine / Standard / Coarse granularity.
  - **Stripes**: 45° diagonal mosaic stripes with customizable bar tint and granularity.
  - **Magic Erase**: Four-edge inverse-distance interpolation with sliding-median anti-bleed filtering. Never reads a single pixel inside the masked area (zero residual text trace) and smoothly reconstructs gradients, chat bubbles, and soft shadows.
  - **Solid**: 12 curated Apple colors + native `ColorPicker` for complete, trace-free coverage.
  - **Blur**: Three adjustable levels (blur can potentially be reversed; prefer Solid or Magic Erase for critical secrets).
  - **Emoji**: Quick dock strip + dark Liquid Glass picker featuring 48 curated stickers across 4 categories (*Faces & Moods*, *Cute Animals*, *Nature & Sparkles*, *Privacy Badges*), Recents, and arbitrary input via the system Emoji keyboard.
- **Interactive Animations & Magic Particle Effects**: Adding, toggling, drawing, recoloring, changing emojis, and running AI scans trigger 60fps iridescent sweeps, expanding halos, and starlight particle dissolves, paired with an Apple Intelligence-style rim glow while scanning (fully honors Reduce Motion).
- **Fast Editing & Custom Watermarks**: Tap any uncovered text line to mask it, draw custom rectangles with live pixel dimensions, press and hold the canvas to compare with the original, undo/redo freely, and overlay tiled diagonal watermarks with live preview of text, opacity, and density.
- **Clean Privacy Export**: Export as lossless PNG or JPEG with EXIF location and device metadata stripped by default, then Save to Photos, Share, or Copy.

## How It Works

Three screens, one image at a time.

1. **Pick**: Grant Photos access on first launch to automatically load and redact your latest screenshot, or choose any photo, paste from clipboard, or scan a document.
2. **Edit**:
   - The top status pill shows the active mask count, with quick access to **Watermark** and **Review** (filter by category, toggle individual findings, or cover all text).
   - The bottom toolbar houses **Undo / Redo / Draw Box / Style Tray / Apple Intelligence Scan** and **Export**. Press and hold the sparkle button to run *Smart Detect & Magic Erase* or toggle automatic AI scanning.
   - Press and hold the photo at any time to peek at the unmasked original.
3. **Export**: Review the preview, active style badge, and privacy summary, then save to Photos, share, or copy.

## Honest Scope & Limitations

- **Magic Erase vs. Apple Photos Clean Up**: iOS 26/27 does not expose the generative pixel-inpainting model behind Apple Photos' Clean Up to third-party apps. QuickCover's Magic Erase uses pure on-device boundary interpolation — ideal and trace-free on solid colors, gradient cards, chat bubbles, and document backgrounds. For complex photographic scenes where absolute redaction matters, use Solid, colored Mosaic, or Emoji.
- **Always Glance Before Exporting**: Multi-line wrapped numbers or chat avatars may occasionally need a quick manual tap or box, and license plates are matched heuristically. Always review the preview before sharing.
- **Mosaic & Blur Trace Notice**: Large typography under Mosaic or Blur can still retain faint luminance silhouettes; Export highlights this and lets you switch to Solid in one tap.

## 100% On-Device Privacy

QuickCover has no accounts, no servers, and no third-party networking SDKs. Vision detection, on-device Apple Intelligence inference, and mask rendering all run strictly on your iPhone — even in Airplane Mode. Exporting creates a new copy and never mutates your original photo.

## Requirements

- **OS**: iOS 26.0 or later (built for iOS 26 / 27 Liquid Glass; on-device `FoundationModels` requires an Apple Intelligence-capable device with Apple Intelligence enabled, and falls back to the local contextual matcher elsewhere).
- **Languages**: English, Simplified Chinese, Traditional Chinese.

## Installation & Releases

Download the latest self-check IPA from [Releases](https://github.com/zxfccmm4/QuickCover/releases). Every release automatically includes structured changelog notes and a commit diff link — you can also browse [CHANGELOG.md](CHANGELOG.md).

- The IPA is unsigned; sign and install it with your preferred sideloading tool.
- The self-check build includes an embedded Self-Check screen (press and hold the home title for 2 seconds) and 30 synthetic baseline test images; otherwise it is identical to daily use.
- Every push to `main` automatically builds `QuickCover-<version>-<build>-selfcheck.ipa` via GitHub Actions and publishes it under tag `v<version>-<build>` (updating assets in place when the version/build number is unchanged).

## Build from Source

Requires Xcode 26 or later (CI builds with Xcode 26.5).

```sh
# Build the app (unsigned)
xcodebuild build -project QuickCover.xcodeproj -scheme QuickCover \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO

# Build the self-check IPA (output at .airbuild/artifacts/selfcheck/QuickCoverSelfCheck.ipa)
XCODEBUILD=xcodebuild tools/selfcheck/build.sh

# Run unit tests (replace simulator name with an iOS 26+ simulator installed locally)
xcodebuild test -project QuickCover.xcodeproj -scheme QuickCover \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'
```

## Architecture & Project Layout

- Pure native **Swift 6 + SwiftUI**, zero third-party dependencies.
- System frameworks: **Vision** (faces, Chinese/English text, QR & barcodes), **FoundationModels** (on-device Apple Intelligence semantic privacy detection), **VisionKit** (document scanner), and **CoreGraphics** (mosaic, stripes, Magic Erase, emoji & watermark rendering).
- All 30 baseline test fixtures use synthetic data with zero real personal information; see [tools/baseline/FIXTURES.md](tools/baseline/FIXTURES.md).

```text
QuickCover/
  App/            App entry point and navigation state (RootView / ShellModel)
  Screens/        Onboarding, picker & scanner, editor, style tray, emoji picker, watermark, export
  Editor/         Editor state, checklist, undo/redo, Liquid Glass components, localization helpers
  Recognition/    Vision recognizer, Apple Intelligence advisor, 6-style & Magic Erase renderer
  SelfCheck/      Embedded self-check view and baseline evaluation runner
QuickCoverTests/  250+ unit tests and 30 synthetic baseline test fixtures
tools/selfcheck/  Self-check IPA build script and GitHub Release notes generator
tools/baseline/   Baseline fixture generation and scoring tools
docs/ios/         Product brief, design specification, and copy sheets
CHANGELOG.md      Release history
```

## Documentation

- [Changelog](CHANGELOG.md)
- [Product Brief (Chinese)](docs/ios/brief.md)
- [Design Specification (Chinese)](docs/ios/design.md)
- [UI Copy (Chinese)](docs/ios/copy.md)
- [Baseline Fixtures Convention](tools/baseline/FIXTURES.md)

---

Made with AirBuild
