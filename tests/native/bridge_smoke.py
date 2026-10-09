"""Exercise the real built adapter without requiring a network host."""
import json
import os
import pathlib
import queue
import signal
import subprocess
import sys
import tempfile
import threading
import time

executable = sys.argv[1]

def helper_environment(root):
    env = {**os.environ, "MOONLIGHT_NATIVE_TEST_ROOT": root}
    if os.environ.get("MOONLIGHT_NATIVE_DIAGNOSTIC_DYLIB"):
        env["DYLD_INSERT_LIBRARIES"] = os.environ["MOONLIGHT_NATIVE_DIAGNOSTIC_DYLIB"]
    return env

class Bridge:
    def __init__(self, root, test_mode=True):
        self.events = queue.Queue()
        self.root = root
        self.test_mode = test_mode
        self.diagnostics = tempfile.TemporaryFile(mode="w+t")
        self.p = subprocess.Popen([executable, "native"] + (["test"] if test_mode else []), stdin=subprocess.PIPE,
                                  stdout=subprocess.PIPE, stderr=self.diagnostics,
                                  env=helper_environment(root), text=True)
        def read():
            for line in self.p.stdout:
                try:
                    self.events.put(json.loads(line))
                except Exception as error:
                    self.events.put({"event": "invalid", "message": str(error)})
        self.reader = threading.Thread(target=read, daemon=True)
        self.reader.start()

    def wait(self, event):
        while True:
            item = self.events.get(timeout=30)
            assert item["event"] != "invalid", item
            if item["event"] == event:
                return item

    def send(self, request):
        self.p.stdin.write(json.dumps(request) + "\n")
        self.p.stdin.flush()

    def close(self):
        if self.p.poll() is None:
            self.send({"command": "shutdown"})
            try:
                self.p.wait(timeout=30)
            except subprocess.TimeoutExpired:
                if not os.environ.get("MOONLIGHT_NATIVE_STOP_ON_FAULT"):
                    raise
                # Fatal diagnostics stop the original process so we can inspect
                # all threads, including the thread doing teardown, not a retry.
                commands = ["lldb", "--batch", "-o", f"process attach --pid {self.p.pid}",
                            "-o", "thread backtrace all", "-o", "process detach"]
                result = subprocess.run(commands, stdout=subprocess.PIPE,
                                        stderr=subprocess.STDOUT, text=True, timeout=60)
                print("HELPER ORIGINAL ALL-THREAD STACK:", result.stdout, flush=True)
                try:
                    os.kill(self.p.pid, signal.SIGCONT)
                except ProcessLookupError:
                    pass
                self.p.wait(timeout=30)
        if self.p.returncode != 0:
            self.diagnostics.seek(0)
            print("HELPER STDERR:", self.diagnostics.read(), flush=True)
            reports = pathlib.Path.home() / "Library/Logs/DiagnosticReports"
            for _ in range(10):
                matches = sorted(reports.glob("Moonlight*.ips"), key=lambda p: p.stat().st_mtime, reverse=True)
                found = False
                for report in matches[:5]:
                    raw = report.read_text()
                    try:
                        crash = json.loads(raw.split("\n", 1)[1])
                    except (ValueError, IndexError):
                        continue
                    if crash.get("pid") == self.p.pid:
                        print("HELPER CRASH REPORT:", raw, flush=True)
                        found = True
                        break
                if found:
                    break
                time.sleep(1)
            # Hosted macOS runners may suppress DiagnosticReports. Reproduce
            # immediate shutdown under LLDB so a remaining teardown crash has
            # a symbolized stack rather than only a negative return code.
            commands = pathlib.Path(self.root) / "shutdown-debug.jsonl"
            commands.write_text(json.dumps({"command": "shutdown"}) + "\n")
            for attempt in range(3):
                result = subprocess.run(["lldb", "--batch", "-o", "settings set target.disable-aslr false",
                    "-o", "process launch --stdin " + str(commands),
                    "-k", "thread backtrace all", "-k", "process kill", "--", executable,
                    "native"] + (["test"] if self.test_mode else []),
                    env={**os.environ, "MOONLIGHT_NATIVE_TEST_ROOT": self.root},
                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=60)
                print("HELPER LLDB SHUTDOWN:", result.stdout, flush=True)
                if "EXC_BAD_ACCESS" in result.stdout or "SIGSEGV" in result.stdout:
                    break
        self.reader.join(timeout=5)
        assert not self.reader.is_alive(), "Helper stdout reader did not stop"
        self.diagnostics.close()
        assert self.p.returncode == 0, self.p.returncode

with tempfile.TemporaryDirectory() as root:
    bridge = Bridge(root)
    try:
        ready = bridge.wait("ready")
        assert ready["protocol"] == 1
        if os.environ.get("MOONLIGHT_NATIVE_SKIP_TERMINAL_CHECK") != "1":
            plugins = (pathlib.Path(executable).resolve().parent / "../PlugIns").resolve()
            assert ready["pluginPaths"] == [str(plugins)], ready
        # Verify the real packaged helper's AppKit policy, not just plist text.
        subprocess.run(["swift", "-e", "import AppKit; "
                        f"guard let app = NSRunningApplication(processIdentifier: {bridge.p.pid}) "
                        "else { fatalError(\"Helper is missing\") }; "
                        "precondition(app.activationPolicy == .accessory, \"Background helper has a Dock icon\")"],
                       check=True, timeout=60)
        settings = bridge.wait("settings")
        assert isinstance(settings["values"]["videoCodecConfig"], int), settings
        assert len(settings["schema"]) >= 30
        original = settings["values"]
        schema = settings["schema"]
        assert len({item["id"] for item in schema}) == len(schema), "Duplicate setting IDs"
        assert {item["id"] for item in schema} == set(original), "Schema/value mismatch"
        for item in schema:
            key = item["id"]
            assert type(original[key]) is (bool if item["boolean"] else int), key
            # Every writable preference must reject the wrong JSON type and
            # leave the complete settings transaction unchanged.
            bridge.send({"command": "settings", "values": {key: "invalid"}})
            bridge.wait("error")
            bridge.send({"command": "snapshot"})
            assert bridge.wait("settings")["values"] == original, key
            for choice in item["choices"]:
                bridge.send({"command": "settings", "values": {key: choice["value"]}})
                assert bridge.wait("settings")["values"][key] == choice["value"], (key, choice)
            if item["choices"]:
                bridge.send({"command": "settings", "values": {key: original[key]}})
                bridge.wait("settings")
        toggled = {item["id"]: not original[item["id"]] for item in schema if item["boolean"]}
        bridge.send({"command": "settings", "values": toggled})
        changed = bridge.wait("settings")["values"]
        assert all(changed[key] == value for key, value in toggled.items()), "Boolean settings roundtrip"
        bridge.send({"command": "settings", "values": original})
        assert bridge.wait("settings")["values"] == original, "Settings restoration"
        if len(sys.argv) > 2:
            pathlib.Path(sys.argv[2]).write_text(json.dumps(settings))
        before = settings["values"]["configurationWarnings"]
        bridge.send({"command": "settings", "values": {"configurationWarnings": not before}})
        assert bridge.wait("settings")["values"]["configurationWarnings"] == (not before)
        bridge.send({"command": "settings", "values": {"fps": 0, "width": 1280}})
        bridge.wait("error")
        bridge.send({"command": "snapshot"})
        unchanged = bridge.wait("settings")["values"]
        assert unchanged["width"] == settings["values"]["width"], "Invalid transaction partially applied"
        for invalid in [{"objectName": "overwrite"}, {"rendererSelection": -1}, {"enableHdr": "true"}]:
            bridge.send({"command": "settings", "values": invalid})
            bridge.wait("error")
        bridge.send({"command": "settings", "values": {"width": 2560, "height": 1440}})
        resolution = bridge.wait("settings")["values"]
        assert (resolution["width"], resolution["height"]) == (2560, 1440), "Resolution transaction failed"
        # The isolated test root has no hosts. Disable discovery before testing
        # the ordinary pause/resume path so it cannot probe the local network.
        bridge.send({"command": "settings", "values": {"enableMdns": False}})
        assert bridge.wait("settings")["values"]["enableMdns"] is False
        bridge.p.stdin.write("not json\n"); bridge.p.stdin.flush(); bridge.wait("error")
    finally:
        bridge.close()
    restarted = Bridge(root)
    try:
        restarted.wait("ready")
        persisted = restarted.wait("settings")["values"]
        assert persisted["configurationWarnings"] == (not before), "Preference did not persist"
        assert (persisted["width"], persisted["height"]) == (2560, 1440), "Resolution did not persist"
    finally:
        restarted.close()
    live = Bridge(root, test_mode=False)
    try:
        live.wait("ready")
        assert live.wait("settings")["values"]["enableMdns"] is False
        assert live.wait("hosts")["hosts"] == []
        # Invalid addresses must be rejected before any network operation.
        for address in ["", "bad host", "https://example.invalid", "x" * 254]:
            live.send({"command": "addHost", "address": address})
            live.wait("error")
        # Stale host actions must recover without changing the host list or
        # leaving the ordinary helper unusable; no real host is contacted.
        for action in ["pair", "wake", "rename", "remove", "hideGame", "artwork", "quitApp"]:
            live.send({"command": action, "host": "missing-host", "pin": "1234", "name": "Test", "app": 1, "hidden": True})
            live.wait("error")
            live.send({"command": "snapshot"})
            assert live.wait("hosts")["hosts"] == [], action
            assert live.wait("settings")["values"]["enableMdns"] is False, action
        for request_id in ["cancelled-launch", "replacement-launch"]:
            live.send({"command": "pause", "requestID": request_id})
            assert live.wait("paused")["requestID"] == request_id, "Pause reply lost its launch identity"
            live.send({"command": "resume"})
            assert live.wait("hosts")["hosts"] == []
    finally:
        live.close()
    if os.environ.get("MOONLIGHT_NATIVE_SKIP_TERMINAL_CHECK") != "1":
        terminal = Bridge(root)
        terminal.wait("ready"); terminal.wait("settings"); terminal.wait("hosts")
        # Requests already framed in the same read must be ignored after shutdown.
        # Starting new work after aboutToQuit bypasses the backend's one-time
        # cancellation signal and exposes adapter callbacks during destruction.
        terminal.p.stdin.write('{"command":"shutdown"}\n{"command":"snapshot"}\n{"command":"unknown-after-shutdown"}\n')
        terminal.p.stdin.flush()
        terminal.p.wait(timeout=30)
        terminal.close()
        assert terminal.events.empty(), "Helper processed commands after terminal shutdown"
        print("PASS: shutdown is terminal for queued requests and adapter callbacks", flush=True)
    for cycle in range(int(os.environ.get("MOONLIGHT_NATIVE_SHUTDOWN_CYCLES", "8"))):
        print("Immediate helper shutdown cycle", cycle, "test mode" if cycle % 2 == 0 else "discovery mode", flush=True)
        repeated = Bridge(root, test_mode=(cycle % 2 == 0))
        try:
            repeated.wait("ready")
            assert repeated.wait("settings")["values"]["enableMdns"] is False
            assert repeated.wait("hosts")["hosts"] == []
        finally:
            repeated.close()
print("PASS: adapter startup, every setting schema/type, enum choices, Boolean roundtrip, atomic validation, persistence, invalid address/stale host recovery, correlated pause/resume replies")
