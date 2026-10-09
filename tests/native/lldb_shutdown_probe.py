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
        listener = lldb.SBListener("native-shutdown-" + str(cycle))
        launch = lldb.SBLaunchInfo(arguments)
        launch.SetListener(listener)
        launch.SetEnvironmentEntries([k + "=" + v for k, v in environment.items()], False)
        launch.SetWorkingDirectory(root)
        launch.SetLaunchFlags(lldb.eLaunchFlagDebug)
        input_path = pathlib.Path(root) / "input.fifo"
        input_path.unlink(missing_ok=True)
        os.mkfifo(input_path)
        input_fd = os.open(input_path, os.O_RDWR | os.O_NONBLOCK)
        output_path = pathlib.Path(root) / "stdout.jsonl"
        errors_path = pathlib.Path(root) / "stderr.log"
        output_path.write_text("")
        errors_path.write_text("")
        launch.AddOpenFileAction(0, str(input_path), True, False)
        launch.AddOpenFileAction(1, str(output_path), False, True)
        launch.AddOpenFileAction(2, str(errors_path), False, True)
        output_offset = 0
        error = lldb.SBError()
        process = target.Launch(launch, error)
        assert error.Success() and process.IsValid(), str(error)
        print("Debugger shutdown cycle", cycle, "pid", process.GetProcessID(), flush=True)
        buffer = ""
        diagnostics = ""
        received = set()
        last_stop_id = None
        configuration_sent = False
        shutdown = False
        configured = cycle != 0
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            diagnostics = errors_path.read_text(errors="replace")[-16000:]
            current_output = output_path.read_text(errors="replace")
            buffer += current_output[output_offset:]
            output_offset = len(current_output)
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
            notification = lldb.SBEvent()
            restarted = False
            while listener.GetNextEvent(notification):
                if lldb.SBProcess.EventIsProcessEvent(notification):
                    restarted = lldb.SBProcess.GetRestartedFromEvent(notification)
            state = process.GetState()
            if state in (lldb.eStateStopped, lldb.eStateCrashed) and not restarted and process.GetStopID() != last_stop_id:
                last_stop_id = process.GetStopID()
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
                continuation = process.Continue()
                print("Debugger continue:", str(continuation), flush=True)
            elif state == lldb.eStateExited:
                assert shutdown and process.GetExitStatus() == 0, (cycle, process.GetExitStatus(), diagnostics)
                break
            if not shutdown and {"ready", "settings", "hosts"} <= received:
                if not configured and not configuration_sent:
                    configuration_sent = True
                    os.write(input_fd, b'{"command":"settings","values":{"enableMdns":false}}\n')
                elif configured:
                    time.sleep((cycle % 16) * 0.005)
                    os.write(input_fd, b'{"command":"shutdown"}\n')
                    shutdown = True
            time.sleep(0.005)
        else:
            print("TIMEOUT STATE:", process.GetState(), "EVENTS:", received,
                  "STDOUT:", current_output, "STDERR:", diagnostics, flush=True)
            process.Stop()
            result = lldb.SBCommandReturnObject()
            debugger.GetCommandInterpreter().HandleCommand("thread backtrace all", result)
            print(result.GetOutput(), result.GetError(), flush=True)
            process.Kill()
            raise RuntimeError("Helper timed out at cycle " + str(cycle))
        os.close(input_fd)
pathlib.Path("build/lldb-shutdown-pass").touch()
print("PASS: original-process debugger shutdown stress", flush=True)
lldb.SBDebugger.Destroy(debugger)
