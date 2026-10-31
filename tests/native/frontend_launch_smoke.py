"""Launch the deliverable frontend, not a preview, with saved Touch Bar modes.

Run only on an isolated macOS CI account: the frontend's preference domain is
backed up and restored, and engine settings use a temporary root. This exercises
AppKit attachment and the real default preference argument that previews bypass.
It cannot establish behavior on a physical Touch Bar or another macOS version.
"""
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time

DOMAIN = "com.moonlight-stream.NativeGlass"
app = Path(sys.argv[1]).resolve()
output = Path(sys.argv[2]).resolve()
output.mkdir(parents=True, exist_ok=True)
executable = app / "Contents/MacOS/MoonlightLG"
assert executable.is_file(), executable


def children(pid):
    rows = subprocess.check_output(["ps", "-axo", "pid=,ppid=,comm="], text=True)
    return [row.split(None, 2) for row in rows.splitlines()
            if len(row.split(None, 2)) == 3 and int(row.split(None, 2)[1]) == pid]


with tempfile.TemporaryDirectory(prefix="moonlightlg-launch-") as directory:
    root = Path(directory)
    backup = root / "preferences.plist"
    had_preferences = subprocess.run(["defaults", "export", DOMAIN, str(backup)],
                                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0
    probe_source = root / "window-probe.swift"
    probe_source.write_text('''import CoreGraphics
import Foundation
let pid = Int(CommandLine.arguments[1])!
let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
let visible = windows.filter { window in
    guard (window[kCGWindowOwnerPID as String] as? Int) == pid,
          (window[kCGWindowLayer as String] as? Int) == 0,
          let bounds = window[kCGWindowBounds as String] as? [String: Any],
          let width = bounds["Width"] as? Double, let height = bounds["Height"] as? Double else { return false }
    return width >= 680 && height >= 460
}
if visible.isEmpty { fputs("No visible MoonlightLG main window\\n", stderr); exit(1) }
print("PASS: visible frontend main window")
''')
    probe = root / "window-probe"
    subprocess.run(["xcrun", "swiftc", str(probe_source), "-o", str(probe)], check=True)
    try:
        for enabled in (False, True):
            label = "full-width-on" if enabled else "full-width-off"
            subprocess.run(["defaults", "write", DOMAIN, "touchBarFullWidth", "-bool", str(enabled).lower()], check=True)
            with (output / f"{label}.log").open("w") as log:
                process = subprocess.Popen([str(executable)], stdout=log, stderr=log,
                                           env={**os.environ, "MOONLIGHT_NATIVE_TEST_ROOT": str(root / label)},
                                           start_new_session=True)
                try:
                    # The real finite boot is 4.1 seconds plus its fade. Keep the
                    # process alive through library construction, not just launch.
                    deadline = time.monotonic() + 9
                    while time.monotonic() < deadline:
                        assert process.poll() is None, f"{label}: frontend exited {process.returncode}; see {log.name}"
                        time.sleep(.2)
                    subprocess.run([str(probe), str(process.pid)], check=True)
                    helpers = children(process.pid)
                    assert any("MoonlightLGEngine.app/Contents/MacOS/Moonlight" in row[2] for row in helpers), \
                        f"{label}: real discovery helper is missing: {helpers}"
                    subprocess.run(["screencapture", "-x", str(output / f"{label}.png")], check=True)
                    print(f"PASS: packaged frontend survives real startup/library handoff with saved {label}; discovery helper running", flush=True)
                finally:
                    # Test teardown only. Keep the engine in this test's process
                    # group so a failed startup cannot leave helpers behind.
                    try:
                        os.killpg(process.pid, signal.SIGTERM)
                    except ProcessLookupError:
                        pass
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        os.killpg(process.pid, signal.SIGKILL)
                        process.wait(timeout=5)
    finally:
        subprocess.run(["defaults", "delete", DOMAIN], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if had_preferences:
            subprocess.run(["defaults", "import", DOMAIN, str(backup)], check=True)
