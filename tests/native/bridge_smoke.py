"""Exercise the real built adapter without requiring a network host."""
import json
import os
import pathlib
import queue
import subprocess
import sys
import tempfile
import threading

executable = sys.argv[1]

class Bridge:
    def __init__(self, root, test_mode=True):
        self.events = queue.Queue()
        self.p = subprocess.Popen([executable, "native"] + (["test"] if test_mode else []), stdin=subprocess.PIPE,
                                  stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                                  env={**os.environ, "MOONLIGHT_NATIVE_TEST_ROOT": root}, text=True)
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
            self.p.wait(timeout=30)
        assert self.p.returncode == 0, self.p.returncode

with tempfile.TemporaryDirectory() as root:
    bridge = Bridge(root)
    try:
        assert bridge.wait("ready")["protocol"] == 1
        # Verify the real packaged helper's AppKit policy, not just plist text.
        subprocess.run(["swift", "-e", "import AppKit; "
                        f"guard let app = NSRunningApplication(processIdentifier: {bridge.p.pid}) "
                        "else { fatalError(\"Helper is missing\") }; "
                        "precondition(app.activationPolicy == .accessory, \"Background helper has a Dock icon\")"],
                       check=True, timeout=60)
        settings = bridge.wait("settings")
        assert isinstance(settings["values"]["videoCodecConfig"], int), settings
        assert len(settings["schema"]) >= 30
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
        for request_id in ["cancelled-launch", "replacement-launch"]:
            live.send({"command": "pause", "requestID": request_id})
            assert live.wait("paused")["requestID"] == request_id, "Pause reply lost its launch identity"
            live.send({"command": "resume"})
            assert live.wait("hosts")["hosts"] == []
    finally:
        live.close()
print("PASS: adapter startup, JSON/settings validation, persistence, correlated pause/resume replies")
