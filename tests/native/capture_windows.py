"""Bounded runtime capture: a stuck app fails CI instead of hanging it."""
import pathlib
import subprocess
import sys

executable = sys.argv[1]
destination = pathlib.Path(sys.argv[2])
destination.mkdir(parents=True, exist_ok=True)
captures = [("main-light", ["--light"]), ("main-dark", ["--dark"]), ("main-compact", ["--dark", "--compact"])]
for screen in ["empty", "offline", "unpaired", "add", "pair", "details", "settings-video", "settings-audio", "settings-input", "settings-network", "settings-advanced"]:
    captures.append((screen, ["--dark", "--preview-screen", screen]))
for name, flags in captures:
    output = destination / f"{name}.png"
    try:
        subprocess.run([executable, "--design-preview", "--settings-fixture", str(destination / "settings-fixture.json"), *flags, "--capture-preview", str(output)],
                       check=True, timeout=35)
    except (subprocess.TimeoutExpired, subprocess.CalledProcessError):
        reports = pathlib.Path.home() / "Library/Logs/DiagnosticReports"
        for report in sorted(reports.glob("MoonlightNative*"))[-2:]:
            print(report.read_text()[:16000], flush=True)
        raise
    assert output.is_file() and output.stat().st_size > 0
    print(f"PASS: app-rendered {name} screenshot", flush=True)
