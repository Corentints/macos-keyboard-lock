#!/bin/bash
# Packages build/KeyboardLock.app into build/KeyboardLock-<VERSION>.dmg (drag-to-Applications layout).
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-0.0.0-dev}"
APP=build/KeyboardLock.app
DMG="build/KeyboardLock-$VERSION.dmg"

[ -d "$APP" ] || { echo "Missing $APP, run scripts/build-app.sh first" >&2; exit 1; }

STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

rm -f "$DMG"
hdiutil create -volname "KeyboardLock" -srcfolder "$STAGING" -format UDZO -ov "$DMG"
(cd build && shasum -a 256 "$(basename "$DMG")" > "$(basename "$DMG").sha256")
echo "Created $DMG"
