# Native app reliability audit — October 8, 2026

Repository: `th3d3ck3r/moonlight-native-glass`, branch `native-ui`.
Final application revision: `757c9471011fe11e0f2a10335bafc6620ed2e778`.
Earlier audit fixes: `ec055390` and `479ed492`.

## Scope

Reviewed the complete custom macOS application layer: all Swift frontend sources,
the JSON/process transport, native bridge, stream-window delegate, title bar,
overlay panels, shortcuts, controller navigation, settings persistence interface,
status menu, quit/reopen behavior, packaging and CI tests. Traced their calls into
the existing launcher, signal handling, session cleanup, discovery, pairing,
artwork and input paths. Checked the native streaming changes against the stock
baseline `de2467e433821664cdd2224aad8c89a625be1ad9`.

This is a reliability review of the app and its integration boundaries. It does
not certify every line of upstream Moonlight or its third-party dependencies,
and it does not replace a real Mac/host streaming test.

## Findings and changes

| Finding | Effect before fix | Change and regression coverage |
| --- | --- | --- |
| Failed Add/Pair sends left pending UI state | Add stayed busy until its timeout; Pair could retain a non-dismissible sheet | Clear operation state immediately on send failure. Real store tests exercise missing transport. |
| A live helper could retain an unusable command pipe | Failed sends did not reset readiness or stop the helper, so Refresh kept trying the same broken channel | Mark unavailable and stop on send failure; explicitly ignore SIGPIPE so writes surface as errors. Real subprocesses close stdin while staying alive; Add, Pair and connection-test calls recover and Refresh restarts the helper. This also adds defensive protection against signal termination. |
| A live helper's error could strand a pending launch | Stream remained active/preparing even though launch was rejected | Cancel the pending request and resume discovery on rejection. A real pipe fixture rejects launch without exiting. |
| Pause replies had no launch identity | After cancel/retry, an old acknowledgement could start the replacement launch before its own acknowledgement | UUID per launch, echoed by the real bridge; accept only the current request. Tests deliver cancelled and replacement replies separately. |
| A silent helper could leave preparation busy forever | No exit/error/acknowledgement meant no recovery | A 10-second preparation deadline cancels only the matching pending launch. A live silent fixture exercises the actual deadline. Host connection/session startup retains its existing separate timeouts. |
| Implicit quit-dialog dismissal did not cancel its launcher | Escape/outside dismissal cleared the dialog while the helper waited for confirmation | Deferred dismissal cancels if no button action handled it. Tests cover dismissal and ensure an accepted confirmation wins. |
| Intentional cancellation could look like a crash | A deliberately terminated launch helper's nonzero exit could produce an unexpected-crash alert | Track requested stops and suppress that alert only for deliberate termination. The dismissal test clears previous messages first so they cannot mask this regression. |
| Decoder applied the frame size limit to an entire read | Several valid frames in a large read could be rejected together | Validate complete and incomplete frames individually. Tests cover two valid 600 KB frames in one read and oversized complete/incomplete frames. |
| Invalid typed events left a ready but unusable helper | A malformed host/schema response displayed an error without ensuring pending UI state recovered | Stop the malformed helper and use normal exit cleanup; validate schema before applying settings. Real transport fixture verifies pairing clears. |
| Event callbacks lacked process identity/shutdown guards | Queued events had no explicit protection against replacing/shutting down their owner | Accept events only from the current helper and before shutdown; cancel launch deadlines on cleanup and do not resume/report unexpected stream exit during deliberate shutdown. |
| Library guidance omitted plain Disconnect | Suggested only the action that also quits the host game | Explain Disconnect and Disconnect and Exit separately, consistently with Input settings. |

## Control Center recurrence checks

The earlier Preview 14 fixes remain in place: return AppKit's consumed toolbar
mouse-up to SDL, remove controls before restoring stream focus/capture, ignore
stale focus-loss events when SDL still owns keyboard focus, and allow explicit
Control Center requests independently of the former enable setting.

The native window harness uses real SDL/Cocoa windows and native events. It
checks title-bar tracking, visible-pointer confinement, restored keyboard and
mouse focus, and routed relative motion before/after controls in windowed,
desktop-fullscreen and exclusive-fullscreen modes. It also checks hide/restore
without disconnect, repeated restoration, wrong-token isolation, lifecycle
cleanup and absence of an extra helper Dock icon. Overlay tests cover layout,
resize, overflow, shortcuts and saved configuration.

Those harnesses exercise the native window/overlay functions and SDL event
routing. They do not connect to a host or exercise the complete production
`SdlInputHandler`/Limelight stream loop with physical input.

## Reviewed paths without a new confirmed defect

- SIGTERM uses `setShouldExit(false)` by default; it exits the helper and respects
  the existing `quitAppAfter` preference. It does not force the host game to quit.
- The frontend owns the Dock/status UI; helper activation stays accessory.
  Restoration requires an actually opened stream window and its launch token.
- Controller navigation stops while streaming; detached handlers/observers are
  cleared. The stream retains its original SDL controller path.
- Settings are validated as one bridge transaction before mutation and saved by
  the original preferences implementation. Resolution/bitrate behavior remains
  the stock contract. Shortcut customization rejects duplicate bindings.
- Artwork work is drained before the native bridge removes a host; callbacks
  are scoped to their artwork owner. Deleting host pointers are excluded from
  native snapshots. Concurrent host network operations still need live-host
  stress testing; static review is not proof of their lifetime safety.
- Engine logs are generated in `/tmp` on macOS by the existing logging path;
  Open Engine Logs points there. JSON events use stdout separately from logs.
- The streaming boundary check confirms backend, settings, common-c, decoding
  and timing remain at the stock baseline except the explicitly reviewed native
  presentation/input hooks. This audit adds no new streaming-core hooks.

## Validation

[Full macOS validation run 37774999668](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/37774999668)
completed successfully for exact application revision `757c9471`, with all three
required jobs passing:

| Job | Verified result |
| --- | --- |
| Intel x86_64 | Complete build, ad-hoc signature verification, permissions/identities, bundled dependencies and all 105 Mach-O files; event framing tests passed. |
| Universal x86_64 + arm64 | Complete build and the same 105-file bundle audit for both slices; all framing, real-process failure/cancellation, overlay, actual SDL window/input, real bridge/settings persistence and status-icon checks passed. The bridge verified both cancelled and replacement pause IDs. |
| Native UI | Five XCTest tests, zero failures. Settings customization, shortcuts, resolution selection, native screens, Dock reopen, status menu lifecycle and About checks passed. Compact library, expanded Overlay settings and Shortcuts captures were visually reviewed. |

Runtime tests ran on an arm64 macOS 26.6.2 runner with Xcode 26.6.0. The Intel
artifact was cross-compiled and its architectures/dependencies audited; this
does not establish physical Intel runtime behavior.

Verified packages (still Preview 14; build artifacts, no published release):
[Intel](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/37774999668/artifacts/11549692572)
and [Universal](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/37774999668/artifacts/11550003271).
Each artifact includes its package checksum. Diagnostic captures:
[native UI](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/37774999668/artifacts/11549542740)
and [stream overlays](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/37774999668/artifacts/11549467576).

The earlier runs, 37773353878 and 37773851856, passed native UI jobs but were
superseded during full builds as cancellation/closed-pipe checks were tightened;
they are not final validation. The latter also passed its full Intel build.
Local checks: streaming boundary verification, Python syntax validation and
`git diff --check` passed. Workflow syntax and ordering checks confirmed transport
regressions execute once and before the complete build. macOS compilation/runtime
checks ran on GitHub's macOS runner because this workspace is Linux.
Transport/framing and frontend failure tests now execute before the expensive
engine build; overlay/SDL, complete bundle builds, real bridge/persistence and
native UI checks remain required.

## Physical validation still required

On the Intel Mac with a real host, repeat Control Center open/Done by title-bar
click and its configured shortcut in all three display modes, including repeated
cycles, capture previously released, absolute mouse/pointer lock, and focus
changes to Settings/another app. Check immediate host motion and clicks after
Done, and ensure no held keys/buttons remain stuck. Verify close/hide/restoration,
plain Disconnect, quit-host preference behavior and host/controller reconnects.
Also stress cancellation/retry and host removal while network operations finish.

The fixes and regression checks reduce recurrence risk. They cannot guarantee
that no future bug occurs. No release publication or README update is part of
this audit.

## Fullscreen regression follow-up — Preview 15

The October 8 recording reported broken Full Screen and Borderless Full Screen,
including Control–Option–Shift–Q in each mode. The previous SDL lifecycle tests
entered fullscreen after an already-open window, released capture before hiding,
and asserted only window visibility/focus. They did not assert the visible
screen contents or reproduce Session's two macOS fullscreen configurations.

`FullscreenWindowTests.mm` now initializes separate processes with Session's
actual `SDL_HINT_VIDEO_MAC_FULLSCREEN_SPACES` values: Full Screen uses `0`,
Borderless Full Screen uses `1`; both normally use desktop fullscreen on macOS.
It enters fullscreen before creating the Metal view, verifies native attachment
preserves its geometry and has no toolbar, presents known Metal pixels, then
hides with relative mouse and keyboard capture active. Composited screenshots
assert the underlying desktop fixture is visible, followed by two successful
fullscreen restore/presentation cycles and a return to windowed title controls.
The test also verifies all hide/restore transitions use the supplied callback.

Run `37781278549` reproduced the black-Space failure in Borderless Full Screen:
initial presentation succeeded, but the first hide captured black pixels. Full
Screen passed initial presentation and both hide/restore cycles. The shipped
v19 dependency set uses SDL3 through sdl2-compat, whose hide operation orders out
a fullscreen Cocoa window without first exiting its fullscreen Space. A hidden
window alone is therefore insufficient evidence of a successful desktop return.

The native adapter now saves the requested fullscreen flags, exits fullscreen
before hiding, and restores the requested mode on reopen. Its production callback
uses Session's existing `toggleFullscreen()` and its existing platform safety;
no decoder implementation, network, timing, bitrate or settings policy changes.
The small Session callback registration/cleanup is reviewed as a presentation
hook in the protected-source check. Native titlebar attachment also avoids ever
installing a toolbar on an already-fullscreen window, or restoring title styling
that it never installed. The black-output-at-startup report remains subject to
physical Intel/host validation: a known-color Metal fixture is not a live decode
or frame-pacing test.

About uses native UI build 15 separately from the bundled engine's actual short
version. Existing credits remain unchanged except the engine version number.
Both cached menu bar icon states use the same rounded mask; source artwork stays
unchanged. Rendered pixel checks cover transparent corners, opaque edges and
original color at standard and Retina sizes, in addition to existing state,
cache, accessibility and observation tests. README and release publication stay
outside this work.
