#!/bin/bash
# Builds the self-check package: the app with the self-check page compiled in, plus the 30 fake
# pictures in the bundle, as an IPA for the owner's own phone. It is not an App Store build.
#
#   tools/selfcheck/build.sh            (run from anywhere, on the builder)
#
# The page is reached by holding the title on the first screen for two seconds.
set -e -o pipefail
cd "$(dirname "$0")/../.."

out=.airbuild/artifacts/selfcheck
archive="$out/QuickCoverSelfCheck.xcarchive"
rm -rf -- "$out"
mkdir -p "$out"

airbuild-xcode archive \
  -project QuickCover.xcodeproj \
  -scheme QuickCover \
  -archivePath "$archive" \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS=SELF_CHECK

app="$archive/Products/Applications/QuickCover.app"
test -d "$app"

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
