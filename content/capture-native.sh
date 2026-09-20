#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 - "$ROOT" <<'PY'
from pathlib import Path
import subprocess, tempfile, struct, sys, shutil
root = Path(sys.argv[1])
app = root / 'apps/mac/build/Harness Manager.app/Contents/MacOS/Harness Manager'
if not app.exists(): raise SystemExit('Build the app first: make build')
with tempfile.TemporaryDirectory(prefix='harness-native-') as folder:
    subprocess.run([str(app), '--capture-marketing', folder, '-ApplePersistenceIgnoreState', 'YES'], check=True, timeout=90)
    names = ['workspace', 'discover', 'updates', 'providers', 'processes', 'news']
    for name in names:
        data = (Path(folder) / (name + '.png')).read_bytes()
        if not data.startswith(b'\x89PNG\r\n\x1a\n') or not data.endswith(b'IEND\xaeB`\x82'): raise SystemExit('Invalid capture: ' + name)
        width, height = struct.unpack('>II', data[16:24])
        if width < 1100 or height < 700: raise SystemExit('Capture resolution is too low: ' + name)
    dest = root / 'apps/web/public/screenshots'
    dest.mkdir(parents=True, exist_ok=True)
    for name in names: shutil.copyfile(Path(folder) / (name + '.png'), dest / (name + '.png'))
print('Six actual native app screenshots exported. Review them before publishing.')
PY
