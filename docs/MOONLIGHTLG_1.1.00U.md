# MoonlightLG 1.1.00U — Apollo connection rendezvous

Application/test source: `085b776ec4600da49a2cbd50917c3d7ad43d80a8`.

Internal build 29. U build links go directly to the owner, never in public
release/download posts. The existing GitHub repository name/URL are unchanged.

## Presentation

A new TimelineView/Canvas scene draws an Apollo command/service-module spacecraft,
engine glow, deterministic drifting stars and a cratered full moon. During actual
connection it flies; a real connected event brings in the moon and smoothly
transitions to an elliptical orbit. The orbit has no automatic completion.
Continue to Stream is explicit and single-use. Host/game, real engine stages,
warnings, errors and Cancel/Retry live at the bottom. Settings errors retain their own
dialog and cannot mark the connection failed. Retry creates a fresh flight/launch identity. Reduce Motion renders a
static scene; controls/status remain available. Animation uses 30 fps only while
the scene is visible, with no new media or bitmap assets. Xcode Canvas includes
Flight and Orbit previews using the same production view.

## Engine boundary audit before builds

Only native frontend/bridge and reviewed presentation hooks change. The native
helper's optional await-continue argument holds Session::exec before SDL window,
fullscreen and input creation. Audio is muted before the connection thread starts.
The Qt command channel remains active while awaiting Continue. Continue releases
the gate and hands the pipe to the established SDL menu reader. The frontend
waits for windowOpened before dismissing the scene and hiding the library.
Old eight-argument native helpers and ordinary Qt launches bypass this gate.

A receiver-bound 50 ms Qt timer keeps cancellation/termination responsive while
waiting. The actual gate consumes SDL_QUIT and takes the existing deferred cleanup
path; cancellation preserves the host game. No decoder, network, settings,
protocol or packet-timing implementation is changed. Stale keyboard/mouse/controller
button/touch events from the rendezvous are flushed before normal input begins.
The existing disconnect sheet, E shortcut, native owner invalidation and fullscreen
presentation hooks remain in place. The streaming boundary check records only
this inspected Session UI hook change.

## Regression coverage

The production gate is extracted directly for a C++ decision fixture, covering
indefinite wait, mute, explicit entry, stale input flush, cancellation, connection
loss and unchanged stock launches. Real frontend process/pipe fixtures cover
connected readiness without a window, explicit/duplicate Continue, orbit Cancel,
paused-launch identity, confirmation dismissal, menu acknowledgments, Settings
error isolation, fresh Retry identity, ignored late Cancel errors/window events and engine
failure recovery. UI tests capture flight/orbit/error and verify orbit persists
until Continue and cancellation returns to the library.

## Completed validation

[Native macOS validation](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38287571187)
and [Xcode validation](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38287571088)
passed on the application/test source above. Complete Intel/Universal builds,
signatures, permissions, identities, dependencies and all 105 Mach-O files passed
bundle audits. Both UI suites passed **12 tests with 0 failures**, including flight,
orbit until explicit Continue, errors, cancellation and Reduce Motion. Fresh and
incremental Xcode builds, source-ZIP setup and startup/UI preview schemes passed.

Production-gate and real frontend process/pipe tests passed, including isolated
Settings errors, fresh Retry identities and ignored late errors/window events
after intentional Cancel. Fullscreen/Metal hide/restore and actual SDL input,
capture and owner-lifetime fixtures passed, including ASan/UBSan. Real-engine
schema/type/enum/Boolean roundtrip, atomic validation, persistence and 200 immediate
shutdown cycles passed. The separate [E/deferred callback shutdown regression](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38285859784)
also passed; its native hooks are identical in the final source.

Actual [compositor captures](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38287571187/artifacts/11764138654)
were inspected for flight, orbit, the bottom error panel and the static Reduce
Motion scene. Buttons and details fit, and the moon/spacecraft remain visible.
The packaged root resource files are byte-identical to 1.0.00U: no new image/video
asset is included.

Both downloaded app packages were independently checked against artifact and
included package checksums. App/helper identities and version/channel metadata
were verified, along with Intel x86_64 and both Universal app/engine slices.

| Package | Version / internal build | Package SHA-256 |
|---|---|---|
| Intel | 1.1.00U / 29 | `a68cfe4e169039fd86587e5abbc0abe1607dd31964063ac7b9c76b9394c788f0` |
| Universal | 1.1.00U / 29 | `1f407cf20a9cb3ccfd924cbbedd84e2cc2cae2786c46cf8d01f0bafd91a9371b` |

App download links are shared only directly with the owner. No U release is posted.

## Physical acceptance
CI uses Apple Silicon and cross-builds Intel; no-host fixtures do not certify a
physical Intel/live Sunshine connection. Live acceptance should include long
waiting, host loss while orbiting, Cancel/Retry, windowed/fullscreen entry and
immediate mouse/controller input after Continue.
