#!/bin/bash
# Builds build/KeyboardLock.app from the Swift package.
#   VERSION        app version written in Info.plist (default: 0.0.0-dev)
#   SIGN_IDENTITY  code signing identity (default: "KeyboardLock Dev", falls back to ad-hoc if missing)
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-0.0.0-dev}"
IDENTITY="${SIGN_IDENTITY:-KeyboardLock Dev}"
if ! security find-identity -v -p codesigning | grep -q "$IDENTITY"; then
  echo "Signing identity '$IDENTITY' not found, using ad-hoc signature"
  IDENTITY="-"
fi

swift build -c release

APP=build/KeyboardLock.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/KeyboardLock "$APP/Contents/MacOS/"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>KeyboardLock</string>
  <key>CFBundleIdentifier</key><string>dev.coco.keyboardlock</string>
  <key>CFBundleExecutable</key><string>KeyboardLock</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
</dict></plist>
PLIST

codesign --force --sign "$IDENTITY" --identifier dev.coco.keyboardlock "$APP"
echo "Built $APP ($VERSION)"
