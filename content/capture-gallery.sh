#!/usr/bin/env bash
# Capture WEB previews, not native SwiftUI screenshots.
set -euo pipefail
PORT="${1:-3000}"
if ! [[ "$PORT" =~ ^[0-9]+$ ]] || (( PORT < 1 || PORT > 65535 )); then
  echo "Provide a valid local port (1–65535)." >&2
  exit 1
fi
CHROME="${CHROME_BIN:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
if [[ ! -x "$CHROME" ]]; then
  echo "Chrome not found. Set CHROME_BIN to your Chrome or Chromium executable." >&2
  exit 1
fi
python3 "$(dirname "$0")/capture-gallery.py" "$PORT" "$CHROME"
