# Preview 26 — native exit fallback and stopped window callbacks

Application source: `087845d08f5f48a7f77b47b1a48719ef100c5fdd`.
Branch: `feature/native-boot-animation`.

## Changes

The Preview 18 native E fix was still present. A separate fallback remained:
when native controls were unavailable, Control–Option–Shift–E reached the stock
Qt exit case and set Session's process-exit flag. The native helper now sends the
same action 209 used by the fixed native shortcut. Session accepts disconnect
209/212 independently of native presentation, and helper action events register
before the first overlay or command-reader startup. Other overlay actions still
require presentation. Ordinary Qt retains its process-exit flag and SDL_QUIT.

A second shutdown fixture exposed a queued focus callback reinstalling controls
after its stream owner stopped. Owners now invalidate synchronously, reject queued
callbacks after stop/replacement, remove observers, and restore the SDL window's
original delegate. Session stops native presentation before deleting the input
handler, decoder and SDL window. Frontend window-closed notification is preserved.
No network, decoder, frame timing or common-c implementation changes are made.
The stream-owned disconnect sheet from Preview 25 is retained.

## Reproduction and validation

The regression fixture compiles the actual production E case and Session event
predicate with real SDL Cocoa windows and the native presentation implementation.
The baseline run 38227445902 fails with:
`Native E fallback requested process exit before deferred cleanup`.
After routing the fallback safely, run 38227913737 passes the shortcut checks but
fails with: `Deferred focus callback reattached native controls after stream teardown`.
These failures demonstrate concrete bugs without a host or user crash logs.

[Shutdown regression run 38228271895](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38228271895)
passes both formerly failing checks on the final source. The fixture uses
AddressSanitizer and UndefinedBehaviorSanitizer.
It checks native mode before initial overlay attachment, disconnect actions,
unchanged ordinary Qt exit, queued focus callbacks, toolbar removal and SDL teardown.

## Physical live-stream limitation

These changes fix the demonstrated fallback and callback lifetime failures.
CI does not reproduce the user's physical live stream or establish its exact
signal-11 stack. A physical Mac stream should confirm the shortcut disconnects
and exits the host game without a helper crash. No crash warning is suppressed.
Experimental Build 24 remains the public prerelease; Preview 26 is a test build.


[Native validation run 38228271873](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38228271873)
passed full Intel and Universal builds and bundle audits, event framing, frontend
failure/cancellation recovery, boot presentation, overlays, fullscreen/window
and stream-owned sheet/input tests, ASan/UBSan, real-engine settings/persistence,
200 shutdown cycles, status icon/menu tests and all 10 native UI tests.
[Universal test build 26](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38228271873/artifacts/11737199309).

[Xcode validation run 38228271892](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38228271892)
passed fresh/incremental complete application builds, embedded engine checks,
source-ZIP dependency recovery, startup preview and all 10 UI preview tests.
The native validation's separate UI smoke suite also passed all 10 tests.
Local source-boundary and whitespace checks passed.

## Intel package verification

[Intel test build 26](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38228271873/artifacts/11737731988).
Its downloaded artifact digest and internal package SHA-256 were independently
verified; the native executable is x86_64 and the bundle build number is 26.
Package SHA-256: `ac9006ffe18b28c69d07dcfbfab92c45ed6c670778ed3649db25d41e4e96786e`.

The Universal artifact was also independently downloaded and verified against its
artifact digest and package checksum; its executable includes arm64 and x86_64
and its bundle build number is 26. Package SHA-256:
`274786aa8fc0b0f4d70e4f03b115a875076733d86b13b20b21c3d4311c88a60e`.
