#!/usr/bin/env bash
set -euo pipefail
MAC_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$MAC_ROOT/../.." && pwd)"
APP="$MAC_ROOT/build/Harness Manager.app"
[[ -d "$APP" ]] || { echo "Build the app first: make build" >&2; exit 1; }
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")
[[ "$VERSION" =~ ^[0-9]+(\.[0-9]+)*$ ]] || { echo "Invalid app version: $VERSION" >&2; exit 1; }
if [[ -n "${NOTARY_PROFILE:-}" && -z "${DEVELOPER_ID:-}" ]]; then
    echo "Notarization requires DEVELOPER_ID." >&2; exit 1
fi
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP" "$STAGE/Harness Manager.app"
if [[ -n "${DEVELOPER_ID:-}" ]]; then
    codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID" \
        --entitlements "$MAC_ROOT/HarnessManager/Resources/HarnessManager.entitlements" "$STAGE/Harness Manager.app"
fi
codesign --verify --deep --strict "$STAGE/Harness Manager.app"
cp "$REPO_ROOT/LICENSE" "$STAGE/LICENSE.txt"
ln -s /Applications "$STAGE/Applications"
cat > "$STAGE/Read Me.txt" <<TEXT
Harness Manager $VERSION
Drag Harness Manager to Applications, then launch it.
Requires macOS 14 or later. Supports Apple silicon and Intel.

Free and open source under Apache 2.0.
https://github.com/juansebsol/mac-ai-harness-manager
TEXT
if [[ -z "${NOTARY_PROFILE:-}" ]]; then
    printf '\nThis preview is not Apple-notarized. If macOS blocks it, review\nthe app in System Settings > Privacy & Security.\n' >> "$STAGE/Read Me.txt"
fi
OUTPUT="$MAC_ROOT/dist"
mkdir -p "$OUTPUT"
DMG="$OUTPUT/Harness-Manager-$VERSION.dmg"
hdiutil create -volname "Harness Manager" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
if [[ -n "${DEVELOPER_ID:-}" ]]; then
    codesign --force --timestamp --sign "$DEVELOPER_ID" "$DMG"
fi
if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG"
    xcrun stapler validate "$DMG"
fi
hdiutil verify "$DMG"
cp "$DMG" "$OUTPUT/Harness-Manager.dmg"
(cd "$OUTPUT" && shasum -a 256 "Harness-Manager-$VERSION.dmg" Harness-Manager.dmg > SHA256SUMS.txt)
# Preserve the website's existing local download route.
mkdir -p "$REPO_ROOT/apps/web/public/downloads"
cp "$OUTPUT/Harness-Manager.dmg" "$REPO_ROOT/apps/web/public/downloads/Harness-Manager.dmg"
(cd "$REPO_ROOT/apps/web/public/downloads" && shasum -a 256 Harness-Manager.dmg > Harness-Manager.dmg.sha256)
echo "Release files: $OUTPUT"
