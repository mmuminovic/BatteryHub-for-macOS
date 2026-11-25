#!/usr/bin/env bash
# Builds a signed, notarized and stapled DMG of Battery Hub for GitHub Releases (outside the App Store).
#
# Notarization credentials (pick one):
#   1) Keychain profile (recommended), created once with:
#        xcrun notarytool store-credentials batteryhub-notary --apple-id <id> --team-id 39KMKDXSBT
#      then run:  NOTARY_PROFILE=batteryhub-notary scripts/release-dmg.sh
#   2) Env vars or a .env file in the repo root:
#        APPLE_ID, APPLE_APP_PASSWORD (app-specific password), APPLE_TEAM_ID
#   With neither, the DMG is built and signed but not notarized.
#
# Output: dist/BatteryHub-<version>.dmg + .sha256
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
[[ -f .env ]] && set -a && source .env && set +a

APP_NAME="Battery Hub"
DIST="$ROOT/dist"
ARCHIVE="$DIST/BatteryHub-DeveloperID.xcarchive"
EXPORT="$DIST/developer-id"
SIGN_ID="Developer ID Application"

command -v xcodegen >/dev/null && xcodegen generate --quiet

rm -rf "$ARCHIVE" "$EXPORT"
mkdir -p "$DIST"

echo "▸ Archiving…"
xcodebuild -project BatteryHub.xcodeproj -scheme BatteryHub -configuration Release \
  -archivePath "$ARCHIVE" -destination "generic/platform=macOS" -allowProvisioningUpdates archive -quiet

echo "▸ Exporting (Developer ID)…"
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$EXPORT" \
  -exportOptionsPlist scripts/ExportOptions-DeveloperID.plist -quiet

APP="$EXPORT/$APP_NAME.app"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$APP/Contents/Info.plist")
DMG="$DIST/BatteryHub-$VERSION.dmg"

codesign --verify --deep --strict "$APP"

echo "▸ Creating DMG…"
STAGING="$(mktemp -d)"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
rm -f "$DMG"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGING" -ov -format UDZO -fs HFS+ "$DMG" >/dev/null
rm -rf "$STAGING"
codesign --sign "$SIGN_ID" --timestamp "$DMG"

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
  NOTARY_ARGS=(--keychain-profile "$NOTARY_PROFILE")
elif [[ -n "${APPLE_ID:-}" && -n "${APPLE_APP_PASSWORD:-${APPLE_ID_PASSWORD:-}}" && -n "${APPLE_TEAM_ID:-}" ]]; then
  NOTARY_ARGS=(--apple-id "$APPLE_ID" --password "${APPLE_APP_PASSWORD:-$APPLE_ID_PASSWORD}" --team-id "$APPLE_TEAM_ID")
else
  NOTARY_ARGS=()
fi

if (( ${#NOTARY_ARGS[@]} )); then
  echo "▸ Notarizing (this usually takes a few minutes)…"
  xcrun notarytool submit "$DMG" "${NOTARY_ARGS[@]}" --wait
  xcrun stapler staple "$DMG"
  spctl --assess --type open --context context:primary-signature -v "$DMG"
  STATUS="signed, notarized and stapled"
else
  echo "⚠️  No notarization credentials — skipping notarization (Gatekeeper will block it on other Macs)."
  STATUS="signed, NOT notarized"
fi

(cd "$DIST" && shasum -a 256 "$(basename "$DMG")" > "$(basename "$DMG").sha256")
echo "✅ $DMG  (v$VERSION build $BUILD) — $STATUS"
