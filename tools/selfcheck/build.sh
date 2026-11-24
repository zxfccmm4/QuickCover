#!/bin/bash
# Builds the self-check package: the app with the self-check page compiled in, plus the 30 fake
# pictures in the bundle, as an IPA for the owner's own phone. It is not an App Store build.
#
#   tools/selfcheck/build.sh            (run from anywhere, on the builder)
#   XCODEBUILD=xcodebuild tools/selfcheck/build.sh    (anywhere else, e.g. GitHub Actions)
#
# The page is reached by holding the title on the first screen for two seconds.
set -e -o pipefail
cd "$(dirname "$0")/../.."

out=.airbuild/artifacts/selfcheck
archive="$out/QuickCoverSelfCheck.xcarchive"
rm -rf -- "$out"
mkdir -p "$out"

# A device build, Release: left to itself the archive comes out for the simulator, in Debug.
"${XCODEBUILD:-airbuild-xcode}" archive \
  -project QuickCover.xcodeproj \
  -scheme QuickCover \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -archivePath "$archive" \
  "SWIFT_ACTIVE_COMPILATION_CONDITIONS=\$(inherited) SELF_CHECK" \
  CODE_SIGNING_ALLOWED=NO

app="$archive/Products/Applications/QuickCover.app"
test -d "$app"

# What the package says of itself, and a stop if it is not a device build.
for key in DTPlatformName DTSDKName CFBundleIdentifier CFBundleShortVersionString CFBundleVersion CFBundleDisplayName MinimumOSVersion; do
  printf '%s = %s\n' "$key" "$(/usr/libexec/PlistBuddy -c "Print :$key" "$app/Info.plist" 2>/dev/null || echo '-')"
done
lproj=$(ls -d "$app"/*.lproj 2>/dev/null | xargs -n1 basename | tr '\n' ' ')
echo "languages = $lproj"
test "$(/usr/libexec/PlistBuddy -c 'Print :DTPlatformName' "$app/Info.plist" | tr 'A-Z' 'a-z')" = iphoneos

# The pictures travel with the test target only; this package carries them too.
cp -R QuickCoverTests/Fixtures "$app/SelfCheckFixtures"

# Adding files outdates the signature. The package is unsigned for the owner's sideloading tool,
# which signs at install time, so an ad-hoc signature is enough; without it the seal is simply removed.
mkdir -p "$out/Payload"
cp -R "$app" "$out/Payload/QuickCover.app"
codesign --force --sign - --timestamp=none "$out/Payload/QuickCover.app" || rm -rf "$out/Payload/QuickCover.app/_CodeSignature"

(cd "$out" && rm -f QuickCoverSelfCheck.ipa && zip -qryX QuickCoverSelfCheck.ipa Payload)
unzip -l "$out/QuickCoverSelfCheck.ipa" | grep -c "SelfCheckFixtures/" | xargs -I{} echo "fixtures in the package: {}"
echo "self-check package: $out/QuickCoverSelfCheck.ipa"
