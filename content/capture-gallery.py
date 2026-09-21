"""Deterministic, bounded Chrome screenshot exports; never uses a user's profile."""
import os
from pathlib import Path
import shutil
import signal
import struct
import subprocess
import sys
import tempfile
import time
import urllib.request

port, chrome = sys.argv[1:]
root = Path(__file__).resolve().parent
media = root / "product-hunt" / "media"
media.mkdir(parents=True, exist_ok=True)
names = ["overview", "discover", "updates", "providers", "processes", "news", "benchmarks"]
for number, name in enumerate(names, 1):
    url = f"http://127.0.0.1:{port}/press/gallery/{number:02}"
    with urllib.request.urlopen(url, timeout=20) as response:
        if response.status != 200:
            raise RuntimeError(f"Page failed: {url}")
    with tempfile.TemporaryDirectory(prefix="harness-gallery-") as profile:
        output = Path(profile) / "capture.png"
        args = [chrome, "--headless=new", "--deterministic-mode", "--disable-gpu", "--disable-partial-raster",
                "--run-all-compositor-stages-before-draw", "--disable-features=PaintHolding", "--hide-scrollbars", "--no-first-run",
                f"--user-data-dir={profile}", "--force-device-scale-factor=2", "--virtual-time-budget=6000",
                "--window-size=1270,760", f"--screenshot={output}", url]
        # Chrome on macOS can stay alive after writing a screenshot. Own a process
        # group and end only this capture instance once a complete PNG is available.
        process = subprocess.Popen(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        complete = False
        try:
            deadline = time.monotonic() + 35
            while time.monotonic() < deadline:
                if output.exists():
                    data = output.read_bytes()
                    if data.startswith(b"\x89PNG\r\n\x1a\n") and data.endswith(b"IEND\xaeB`\x82"):
                        if struct.unpack(">II", data[16:24]) != (2540, 1520):
                            raise RuntimeError("Unexpected screenshot dimensions")
                        complete = True
                        break
                if process.poll() is not None:
                    break
                time.sleep(0.2)
            if not complete:
                raise RuntimeError(f"Chrome did not produce a complete screenshot for {url}")
            destination = media / f"{number:02}-{name}.png"
            shutil.copyfile(output, destination)
            print(f"Captured {destination.name}", flush=True)
        finally:
            try:
                os.killpg(process.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
(root / "reddit").mkdir(exist_ok=True)
shutil.copyfile(media / "01-overview.png", root / "reddit" / "share-image.png")
print("Gallery ready: seven 2540×1520 gallery images using native SwiftUI screenshots.")
