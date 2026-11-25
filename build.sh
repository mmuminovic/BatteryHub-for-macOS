#!/bin/bash
# Battery Hub — lokalni build (Release, sandbox, potpisan tvojim Apple Development sertifikatom).
#
#   ./build.sh            → napravi build/Release/Battery Hub.app i pokreni ga
#   ./build.sh install    → napravi, kopiraj u /Applications i pokreni
#   ./build.sh demo       → Debug build sa izmišljenim uređajima (za screenshotove), bez Bluetooth-a
#
# Za App Store: scripts/release-appstore.sh (vidi README).
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Battery Hub"
EXECUTABLE="BatteryHub"
DERIVED="build/DerivedData"
CONFIG="Release"
[[ "${1:-}" == "demo" ]] && CONFIG="Debug"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "❌ Treba ti Xcode (App Store) — Command Line Tools nisu dovoljni za Xcode projekat."
  exit 1
fi
command -v xcodegen >/dev/null && xcodegen generate --quiet

echo "🔨 Kompajliram ($CONFIG)…"
xcodebuild -project BatteryHub.xcodeproj -scheme BatteryHub -configuration "$CONFIG" \
  -derivedDataPath "$DERIVED" -destination "generic/platform=macOS" -allowProvisioningUpdates build -quiet

APP="$DERIVED/Build/Products/$CONFIG/$APP_NAME.app"
echo "✅ Napravljeno: $APP"

pkill -x "$EXECUTABLE" 2>/dev/null || true
sleep 0.3

case "${1:-}" in
  install)
    DEST="/Applications/$APP_NAME.app"
    rm -rf "$DEST"
    ditto "$APP" "$DEST"
    echo "📦 Instalirano u $DEST"
    open "$DEST"
    ;;
  demo)
    open "$APP" --args -DemoDevices
    ;;
  *)
    open "$APP"
    ;;
esac
echo "🔋 Battery Hub je pokrenut — pogledaj menu bar."
