"""Verify the actual packaged helper opens its SDL window before host lookup."""
import json, pathlib, queue, subprocess, sys, threading, time, uuid
exe = pathlib.Path(sys.argv[1]).resolve()
process = subprocess.Popen([str(exe), 'native', 'stream', str(uuid.uuid4()), '1', '600', '420', str(uuid.uuid4()),
    'await-continue', 'Connection order fixture', 'Desktop'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
events = queue.Queue()
def read():
    for line in process.stdout:
        events.put(json.loads(line))
threading.Thread(target=read, daemon=True).start()
opened = False
try:
    deadline = time.monotonic() + 30
    while time.monotonic() < deadline:
        event = events.get(timeout=30)
        if event['event'] == 'error': raise AssertionError(event)
        if event['event'] == 'stage':
            assert opened, 'Networking/host lookup began before the stream window opened'
            break
        if event['event'] == 'connectionWindowOpened': opened = True
    assert opened
    process.stdin.write(json.dumps({'command':'cancelStream'})+'\n'); process.stdin.flush()
    process.wait(timeout=15)
    assert process.returncode == 0, process.stderr.read()
    print('PASS: packaged helper opens the actual stream window before host/game lookup and cancels before a Session')
finally:
    if process.poll() is None: process.kill(); process.wait()
