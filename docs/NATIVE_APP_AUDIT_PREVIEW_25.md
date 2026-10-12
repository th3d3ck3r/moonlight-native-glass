# Preview 25 — stream-owned host-exit confirmation

Application source: `12b78d84d8952c88e2fee3692551e8c60c07cd1b`.
Branch: `feature/native-boot-animation`.

## Scope and behavior

The menu's **Disconnect and Exit Host Game…** confirmation previously ran in
Swift frontend AppKit. That process does not own the SDL stream window and
cannot attach a sheet to it. It now sends a token-scoped helper request; the
stream helper presents an NSAlert sheet attached to the original stream window.
No library activation or frontend alert is needed for that confirmation.

Cancel restores the saved capture intent; confirmation retains the existing
host-exit session action. The frontend menu's delayed input-resume command cannot
recapture input behind the stream sheet. Repeated requests share one sheet.
Hiding/closing the window and helper teardown cancel the sheet, and stale replies
cannot affect a replaced session. Existing plain Disconnect and keyboard E
routing are retained. Session changes are macOS native presentation hooks only;
upstream networking, decoding and timing implementations are unchanged.

The existing compositor, input and fullscreen regression fixtures now cover
actual sheet-parent identity in Windowed, desktop fullscreen and the optional
physical-exclusive fixture, Cancel and confirmation result routing, duplicate
requests, restored capture, and teardown with an open sheet. The same window
fixture runs with AddressSanitizer and UndefinedBehaviorSanitizer. Swift status
menu tests verify delegation rather than a frontend modal; channel tests verify
the new command travels over the real subprocess pipe.

## Validation

[Native validation run 38223259048](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38223259048)
passed the complete Intel and Universal builds, all 10 UI tests, event/channel
failure recovery, startup cleanup, overlay and fullscreen checks, extended
stream/sheet/input fixture, sanitizer fixture, real-engine settings/persistence,
200 shutdown cycles and status-menu/icon tests.

[Xcode validation run 38223259187](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38223259187)
passed fresh/incremental full-app builds, the real-engine checks, source-ZIP
dependency recovery, startup preview and all 10 UI preview tests.

The Intel artifact was independently downloaded and verified against its artifact
digest and included package checksum; its frontend is x86_64 and its bundle build
number is 25. Package SHA-256:
`4182956b8ce8e68eed781b22d8b3934523499cf86360a70466199a85427c602a`.
[Intel confirmation test build](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38223259048/artifacts/11735132814).
The source boundary and whitespace checks passed. These results establish the
tested dialog/window behavior, not a fix for the physical live-stream crash.

## Unresolved crash report

The user confirmed Control–Option–Shift–E produces **Engine stopped: signal 11**.
That means the helper crashed; this is not a host connection error code. The
faulting-thread backtrace from the physical Mac and corresponding stream log are
still needed to locate it. This change does not claim to fix that crash, and the
no-host CI fixtures cannot reproduce or certify a live stream's complete shutdown.

Useful files: the newest `stream-*.log` from the app's **Open Engine Logs** menu
(`~/Library/Logs/MoonlightNativeGlass`) and the newest Moonlight `.ips` report in
`~/Library/Logs/DiagnosticReports`.

Experimental Build 24 remains the published verified snapshot with both original
reports listed as known issues. Preview 25 is an unpublished test build for the
confirmation change; no new release is created by this follow-up.
