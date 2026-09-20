#!/usr/bin/env bash
set -euo pipefail
MAC_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "$MAC_ROOT/../.." && pwd)"
APP="$MAC_ROOT/build/Harness Manager.app"
[[ -d "$APP" ]] || { echo "Build the app first: make build" >&2; exit 1; }
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP" "$STAGE/Harness Manager.app"
cp "$REPO_ROOT/LICENSE" "$STAGE/LICENSE.txt"
ln -s /Applications "$STAGE/Applications"
cat > "$STAGE/Read Me.txt" <<'TEXT'
Harness Manager 0.1.0
Drag Harness Manager to Applications, then launch it.
Requires macOS 14 or later. Supports Apple silicon and Intel.

This early preview is ad-hoc signed, not Developer ID notarized.
If macOS blocks it, review the app in System Settings > Privacy & Security.

Free and open source under Apache 2.0.
https://github.com/juansebsol/mac-ai-harness-manager
TEXT
OUTPUT="$REPO_ROOT/apps/web/public/downloads"
mkdir -p "$OUTPUT"
hdiutil create -volname "Harness Manager" -srcfolder "$STAGE" -ov -format UDZO "$OUTPUT/Harness-Manager.dmg"
(cd "$OUTPUT" && shasum -a 256 Harness-Manager.dmg > Harness-Manager.dmg.sha256)
echo "Packaged: $OUTPUT/Harness-Manager.dmg"
