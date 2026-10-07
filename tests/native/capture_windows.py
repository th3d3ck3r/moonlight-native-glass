"""Bounded runtime capture: a stuck app fails CI instead of hanging it."""
import pathlib
import subprocess
import sys

executable = sys.argv[1]
destination = pathlib.Path(sys.argv[2])
destination.mkdir(parents=True, exist_ok=True)
captures = [("main-light", ["--light"]), ("main-dark", ["--dark"]), ("main-compact", ["--dark", "--compact"])]
for screen in ["empty", "loading", "offline", "unpaired", "add", "pair", "details", "settings-video", "settings-audio", "settings-input", "settings-network", "settings-advanced"]:
    captures.append((screen, ["--dark", "--preview-screen=" + screen]))
for name, flags in captures:
    output = destination / f"{name}.png"
    try:
        subprocess.run(["/usr/bin/open", "-n", "-W", str(pathlib.Path(executable).resolve().parents[2]), "--args", "--design-preview", "--settings-fixture=" + str(destination / "settings-fixture.json"), *flags, "--capture-preview=" + str(output)],
                       check=True, timeout=35)
    except (subprocess.TimeoutExpired, subprocess.CalledProcessError):
        reports = pathlib.Path.home() / "Library/Logs/DiagnosticReports"
        for report in sorted(reports.glob("MoonlightNative*"))[-2:]:
            print(report.read_text()[:16000], flush=True)
        raise
    if not output.is_file():
        log = pathlib.Path(str(output) + ".log")
        if log.exists(): print(log.read_text(), flush=True)
        capture_log = pathlib.Path(str(output) + ".capture-log")
        if capture_log.exists(): print(capture_log.read_text(), flush=True)
    assert output.is_file() and output.stat().st_size > 0
    method = pathlib.Path(str(output) + ".capture-method.txt")
    print(f"PASS: native {name} layout capture" if method.exists() else f"PASS: native {name} WindowServer screenshot", flush=True)
