#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CONFIGURATION="${1:-Release}"
DERIVED="$ROOT/build/DerivedData"
APP_OUT="$ROOT/build"

echo "→ Building Harness Manager ($CONFIGURATION)…"

xcodebuild \
  -project HarnessManager.xcodeproj \
  -scheme HarnessManager \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED" \
  -destination "platform=macOS" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_ALLOWED=YES \
  build

APP_SRC=$(find "$DERIVED/Build/Products/$CONFIGURATION" -name "Harness Manager.app" -maxdepth 1 | head -n 1)
if [[ -z "$APP_SRC" ]]; then
  echo "Build succeeded but app bundle not found" >&2
  exit 1
fi

mkdir -p "$APP_OUT"
rm -rf "$APP_OUT/Harness Manager.app"
cp -R "$APP_SRC" "$APP_OUT/Harness Manager.app"

echo "✓ Built: $APP_OUT/Harness Manager.app"
echo "  Open with: open \"$APP_OUT/Harness Manager.app\""
