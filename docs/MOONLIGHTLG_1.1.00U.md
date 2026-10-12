# MoonlightLG 1.1.00U — Apollo connection rendezvous

Internal build 29. U build links go directly to the owner, never in public
release/download posts. The existing GitHub repository name/URL are unchanged.

## Presentation

A new TimelineView/Canvas scene draws an Apollo command/service-module spacecraft,
engine glow, deterministic drifting stars and a cratered full moon. During actual
connection it flies; a real connected event brings in the moon and smoothly
transitions to an elliptical orbit. The orbit has no automatic completion.
Continue to Stream is explicit and single-use. Host/game, real engine stages,
warnings, errors and Cancel/Retry live at the bottom. Reduce Motion renders a
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
paused-launch identity, confirmation dismissal, menu acknowledgments and engine
failure recovery. UI tests capture flight/orbit/error and verify orbit persists
until Continue and cancellation returns to the library.

Complete macOS/Xcode results and visual inspection will be recorded after runs.
CI uses Apple Silicon and cross-builds Intel; no-host fixtures do not certify a
physical Intel/live Sunshine connection. Live acceptance should include long
waiting, host loss while orbiting, Cancel/Retry, windowed/fullscreen entry and
immediate mouse/controller input after Continue.
