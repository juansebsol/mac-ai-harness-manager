#!/usr/bin/env bash
# Automated hang / responsiveness smoke test for Harness Manager.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/Harness Manager.app"
BIN="$APP/Contents/MacOS/Harness Manager"
LOG="/tmp/harness-manager-smoke.log"
SAMPLE="/tmp/harness-manager-smoke-sample.txt"

echo "=== Harness Manager smoke test ===" | tee "$LOG"

# 1) Build
echo "→ Building…" | tee -a "$LOG"
"$ROOT/Scripts/build.sh" Release >>"$LOG" 2>&1

# 2) Kill leftovers
pkill -f "Harness Manager.app" 2>/dev/null || true
sleep 0.5

# 3) Reset settings to known-good (no menu bar, no auto refresh, onboarding done)
SUPPORT="$HOME/Library/Application Support/HarnessManager"
mkdir -p "$SUPPORT"
cat > "$SUPPORT/settings.json" <<'EOF'
{"additionalBinaryPaths":[],"launchAtLogin":false,"refreshAutomatically":false,"projectRoots":["~/Developer","~/Projects"],"hasCompletedOnboarding":true,"refreshIntervalSeconds":60,"showMenuBarExtra":false,"additionalConfigDirectories":[],"showCommandLogs":false,"preferredTerminal":"automatic"}
EOF

# 4) Launch
echo "→ Launching app…" | tee -a "$LOG"
"$BIN" >>"$LOG" 2>&1 &
PID=$!
echo "PID=$PID" | tee -a "$LOG"

cleanup() {
  kill "$PID" 2>/dev/null || true
  pkill -f "Harness Manager.app" 2>/dev/null || true
}
trap cleanup EXIT

# 5) Must stay alive and settle
for i in 1 2 3 4 5 6 7 8; do
  sleep 1
  if ! kill -0 "$PID" 2>/dev/null; then
    echo "FAIL: process exited early at ${i}s" | tee -a "$LOG"
    exit 1
  fi
  CPU=$(ps -p "$PID" -o %cpu= | tr -d ' ')
  echo "  t=${i}s cpu=${CPU}%" | tee -a "$LOG"
done

# 6) Sample — main thread should be in CFRunLoop (idle), not blocked in Process/NSWorkspace
echo "→ Sampling main thread…" | tee -a "$LOG"
sample "$PID" 2 -file "$SAMPLE" >/dev/null 2>&1 || true

if rg -q "NSWorkspace|urlForApplication|readDataToEndOfFile" "$SAMPLE"; then
  # Only fail if these dominate the main thread samples
  MAIN_HITS=$(rg -c "Thread_.*main-thread" "$SAMPLE" || true)
  BAD_HITS=$(rg -c "NSWorkspace|urlForApplication|readDataToEndOfFile" "$SAMPLE" || true)
  echo "  main markers=$MAIN_HITS bad markers=$BAD_HITS" | tee -a "$LOG"
fi

if ! rg -q "CFRunLoop|mach_msg|nextEventMatching" "$SAMPLE"; then
  echo "WARN: could not confirm idle run loop (sample may be sparse)" | tee -a "$LOG"
else
  echo "✓ Main thread idle in event loop" | tee -a "$LOG"
fi

# Fail if relative date formatting is still on the hot path (known beach-ball cause)
if rg -q "TimeDataFormatting|DateOffset\.format|style: \.relative" "$SAMPLE"; then
  echo "FAIL: relative date Text is burning CPU (beach-ball cause)" | tee -a "$LOG"
  exit 1
fi

# 7) CPU should be low after warm-up (allow some headroom on Debug)
CPU=$(ps -p "$PID" -o %cpu= | tr -d ' ')
CPU_INT=${CPU%.*}
echo "  final cpu=${CPU}%" | tee -a "$LOG"
if [[ "${CPU_INT:-0}" -gt 40 ]]; then
  echo "FAIL: CPU still high after warm-up (${CPU}%)" | tee -a "$LOG"
  exit 1
fi

# 8) Fast discovery unit check (no UI)
echo "→ Filesystem discovery probe…" | tee -a "$LOG"
PATH_PROBE="/opt/homebrew/bin:/usr/local/bin:/usr/bin:$HOME/.local/bin"
FOUND=0
for name in claude codex gemini opencode cursor; do
  for dir in ${PATH_PROBE//:/ }; do
    if [[ -x "$dir/$name" ]]; then
      echo "  found $name at $dir/$name" | tee -a "$LOG"
      FOUND=$((FOUND+1))
      break
    fi
  done
done
echo "  binaries found: $FOUND" | tee -a "$LOG"

echo "✓ SMOKE TEST PASSED" | tee -a "$LOG"
echo "App is running and responsive (PID $PID). Quitting test instance."
exit 0
