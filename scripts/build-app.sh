#!/usr/bin/env bash
# Build a local LokaliteApp.app bundle from the current checkout, mirroring the
# release workflow (xcodebuild + manual bundle assembly + ad-hoc sign). Useful
# for testing the daemon / auto-launch without cutting a real release.
#
# Usage: scripts/build-app.sh [Release|Debug]   (default: Release)
#   Release -> prod vault/keychain/socket (com.lokalite.vault)
#   Debug   -> dev  vault/keychain/socket (com.lokalite.vault.dev)
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-Release}"
VERSION="$(git describe --tags --abbrev=0 2>/dev/null || echo 0.0.0)"
SHORT_VERSION="${VERSION#v}-local"
DD=".build/dd"
PRODUCTS="$DD/Build/Products/$CONFIG"
APP=".build/LokaliteApp.app"

echo "==> Building CLI ($CONFIG)…"
if [ "$CONFIG" = "Release" ]; then swift build -c release --product lokalite >/dev/null
else swift build --product lokalite >/dev/null; fi

echo "==> Building app with xcodebuild ($CONFIG)…"
xcodebuild build -scheme LokaliteApp -configuration "$CONFIG" \
  -derivedDataPath "$DD" -destination "platform=macOS" \
  CODE_SIGNING_ALLOWED=NO >/dev/null

echo "==> Assembling $APP …"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$PRODUCTS/LokaliteApp" "$APP/Contents/MacOS/LokaliteApp"
cp assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp -R "$PRODUCTS"/*.bundle "$APP/Contents/Resources/" 2>/dev/null || true

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Lokalite</string>
  <key>CFBundleDisplayName</key><string>Lokalite</string>
  <key>CFBundleExecutable</key><string>LokaliteApp</string>
  <key>CFBundleIdentifier</key><string>com.lokalite.app</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleVersion</key><string>${SHORT_VERSION}</string>
  <key>CFBundleShortVersionString</key><string>${SHORT_VERSION}</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST
printf 'APPL????' > "$APP/Contents/PkgInfo"

codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true

echo "==> Done."
echo "App: $(cd "$(dirname "$APP")" && pwd)/$(basename "$APP")   (config: $CONFIG, version: $SHORT_VERSION)"
echo "CLI: $(pwd)/.build/$([ "$CONFIG" = Release ] && echo release || echo debug)/lokalite"
