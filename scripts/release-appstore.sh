#!/usr/bin/env bash
# Archives Battery Hub and uploads it to App Store Connect (or only exports a .pkg with --export-only).
#
# Requirements (one-time):
#   • Xcode → Settings → Accounts: signed in with the Apple ID of team 39KMKDXSBT
#     (automatic, cloud-managed signing — no certificates need to be in the keychain).
#   • An app record in App Store Connect with bundle ID "com.mmuminovic.batteryhub".
#   • Bump CURRENT_PROJECT_VERSION in project.yml for every upload (and MARKETING_VERSION per release).
#
#   scripts/release-appstore.sh               → archive + upload to App Store Connect
#   scripts/release-appstore.sh --export-only → archive + dist/appstore-export/Battery Hub.pkg (no upload)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DIST="$ROOT/dist"
ARCHIVE="$DIST/BatteryHub-AppStore.xcarchive"
OPTIONS="scripts/ExportOptions-AppStore.plist"
EXPORT="$DIST/appstore"
if [[ "${1:-}" == "--export-only" ]]; then
  OPTIONS="scripts/ExportOptions-AppStore-Export.plist"
  EXPORT="$DIST/appstore-export"
fi

command -v xcodegen >/dev/null && xcodegen generate --quiet

rm -rf "$ARCHIVE" "$EXPORT"
mkdir -p "$DIST"

echo "▸ Archiving…"
xcodebuild -project BatteryHub.xcodeproj -scheme BatteryHub -configuration Release \
  -archivePath "$ARCHIVE" -destination "generic/platform=macOS" -allowProvisioningUpdates archive -quiet

echo "▸ Exporting ($(basename "$OPTIONS"))…"
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$EXPORT" \
  -exportOptionsPlist "$OPTIONS" -allowProvisioningUpdates

if [[ "${1:-}" == "--export-only" ]]; then
  echo "✅ $EXPORT/Battery Hub.pkg — upload it with Transporter, or run this script without --export-only."
else
  echo "✅ Uploaded. Processing takes ~10–30 min, then the build appears under TestFlight / App Store in App Store Connect."
fi
