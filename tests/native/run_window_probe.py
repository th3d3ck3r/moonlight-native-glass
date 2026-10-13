"""Bound a native UI fixture and capture the actual stalled Mac stack on timeout."""
import os
import pathlib
import subprocess
import sys

if len(sys.argv) < 2:
    raise SystemExit("Usage: run_window_probe.py executable [arguments...]")
limit = float(os.environ.get("MOONLIGHT_NATIVE_PROBE_TIMEOUT", "240"))
child = subprocess.Popen(sys.argv[1:])
try:
    raise SystemExit(child.wait(timeout=limit))
except subprocess.TimeoutExpired:
    print(f"Native window fixture exceeded {limit:g}s; sampling PID {child.pid}", flush=True)
    report = pathlib.Path("build/window-probe-sample.txt")
    report.parent.mkdir(parents=True, exist_ok=True)
    try:
        subprocess.run(["/usr/bin/sample", str(child.pid), "1", "-file", str(report)],
                       timeout=20, check=False)
        if report.exists():
            print(report.read_text(errors="replace"), flush=True)
    except (OSError, subprocess.TimeoutExpired) as error:
        print(f"Process sample unavailable: {error}", flush=True)
    finally:
        child.terminate()
        try:
            child.wait(timeout=5)
        except subprocess.TimeoutExpired:
            child.kill()
            child.wait()
    raise SystemExit(124)
