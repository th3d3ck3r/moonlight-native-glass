"""Run the packaged helper directly under LLDB; no diagnostic library injection."""
import json
import lldb
import os
import pathlib
import tempfile
import time

executable = os.environ["MOONLIGHT_NATIVE_PROBE_EXECUTABLE"]
debugger = lldb.SBDebugger.Create()
debugger.SetAsync(True)
debugger.HandleCommand("settings set target.disable-aslr false")
target = debugger.CreateTarget(executable)
assert target.IsValid(), executable
with tempfile.TemporaryDirectory() as root:
    environment = {k: v for k, v in os.environ.items()
                   if k not in ("DYLD_INSERT_LIBRARIES", "MOONLIGHT_NATIVE_DIAGNOSTIC_DYLIB",
                                "MOONLIGHT_NATIVE_STOP_ON_FAULT")}
    environment["MOONLIGHT_NATIVE_TEST_ROOT"] = root
    for cycle in range(int(os.environ.get("MOONLIGHT_NATIVE_SHUTDOWN_CYCLES", "1000"))):
        arguments = ["native"] + (["test"] if cycle % 2 == 0 else [])
        launch = lldb.SBLaunchInfo(arguments)
        launch.SetEnvironmentEntries([k + "=" + v for k, v in environment.items()], False)
        launch.SetWorkingDirectory(root)
        launch.SetLaunchFlags(lldb.eLaunchFlagDebug)
        error = lldb.SBError()
        process = target.Launch(launch, error)
        assert error.Success() and process.IsValid(), str(error)
        print("Debugger shutdown cycle", cycle, "pid", process.GetProcessID(), flush=True)
        buffer = ""
        diagnostics = ""
        received = set()
        shutdown = False
        configured = cycle != 0
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            diagnostics = (diagnostics + (process.GetSTDERR(65536) or ""))[-16000:]
            buffer += process.GetSTDOUT(65536) or ""
            while "\n" in buffer:
                line, buffer = buffer.split("\n", 1)
                try:
                    event = json.loads(line)
                except ValueError:
                    continue
                name = event.get("event")
                received.add(name)
                if name == "settings" and event["values"]["enableMdns"] is False:
                    configured = True
            state = process.GetState()
            if state in (lldb.eStateStopped, lldb.eStateCrashed):
                fatal = state == lldb.eStateCrashed
                for thread in process:
                    reason = thread.GetStopReason()
                    if reason == lldb.eStopReasonException:
                        fatal = True
                    if reason == lldb.eStopReasonSignal and thread.GetStopReasonDataAtIndex(0) in (4, 5, 6, 10, 11):
                        fatal = True
                if fatal:
                    print("ORIGINAL HELPER FAULT STDERR:", diagnostics, flush=True)
                    result = lldb.SBCommandReturnObject()
                    debugger.GetCommandInterpreter().HandleCommand("thread backtrace all", result)
                    print("ORIGINAL HELPER ALL THREADS:", result.GetOutput(), result.GetError(), flush=True)
                    process.Kill()
                    raise RuntimeError("Original helper fault at cycle " + str(cycle))
                process.Continue()
            elif state == lldb.eStateExited:
                assert shutdown and process.GetExitStatus() == 0, (cycle, process.GetExitStatus(), diagnostics)
                break
            elif not shutdown and {"ready", "settings", "hosts"} <= received:
                if not configured:
                    process.PutSTDIN('{"command":"settings","values":{"enableMdns":false}}\n')
                else:
                    time.sleep((cycle % 16) * 0.005)
                    process.PutSTDIN('{"command":"shutdown"}\n')
                    shutdown = True
            time.sleep(0.005)
        else:
            process.Kill()
            raise RuntimeError("Helper timed out at cycle " + str(cycle))
pathlib.Path("build/lldb-shutdown-pass").touch()
print("PASS: original-process debugger shutdown stress", flush=True)
lldb.SBDebugger.Destroy(debugger)
