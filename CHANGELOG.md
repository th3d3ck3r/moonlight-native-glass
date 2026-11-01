# MoonlightLG changelog

## 🌙 1.3.5.4 — prepared, unpublished

- Prepare the stable-labelled Apple Silicon package, complete corresponding source and legal notices. Internal build 52; publication requires the owner’s explicit go.
- Includes the native black/crimson Touch Bar, live statistics, six detailed pages, continuous volume control, recording/replay actions and optional full-width presentation.
- Includes settings persistence, startup safety, animation/rendering refinements and the library placement correction described in the private entries below. Physical M1 layout and full-width compatibility remain hardware acceptance limits.
- Public downloads remain on 1.3.2.0 until publication.

## 1.3.5.4U — private library Touch Bar placement

- Remove physical-bar principal-item centering from the library, startup and Apollo canvases. Use the same ordinary placement as the working stream bar so the available app region is not shifted toward the Control Strip.
- Preserve the flexible canvas, animation, scrolling, shortcuts, crimson volume slider and existing full-width lifecycle. Internal build 51.
- Check normal and independent full-width bar placement in the native regressions. Physical M1 presentation still requires owner confirmation.

## 1.3.5.3U — private adaptive Touch Bar sizing

- Make the home/connection Touch Bar item flexible so AppKit gives it the available app area instead of centering a content-sized row. The animation follows that allocation in normal and full-width modes.
- Adapt stream measurements to the actual Control Strip reservation, retaining essential controls, scrolling, detailed statistics and the crimson volume slider. Keep full network-latency details accessible while the main bar uses a compact value.
- Add allocation regressions with the Control Strip hidden, shown and expanded. Internal build 50; the owner’s M1 videos identify the physical regression, while CI still cannot certify on-device presentation.

## 1.3.5.2U — private Moon pulse and Touch Bar recovery

- Remove build 48’s 1085-point fitting-width request. Layout artwork, host status, actions and overflow against the visible AppKit allocation so the system Control Strip cannot clip commands or push the moon off centre.
- Give frontend full-width presentation an independent bar and independent controls. Prepare its content before presenting, preserve animation clocks during handoff, and keep the normal window bar intact for restoration.
- Check that modal content is actually hosted after presentation; on failure restore the standard bar and turn the option off with an explanatory settings message. Preserve global, Fn and other-app preferences.
- Preflight stream controls and guard private presentation/dismissal exceptions. Preserve stream action routing, continuous volume and all existing controls, plus build 48’s boot smoothness changes.
- Adopt the supplied Moon pulse across the Touch Bar, including the finite startup sweep, connecting sweep and one-time connected shockwave. Use elapsed wall time, stop work with hidden/inactive owners, respect Reduce Motion, and lower the animation cadence during streaming. Keep the screen startup/connection artwork unchanged.
- Keep the central moon clear and commands reachable through scrolling. Pin Capture and Controls in narrow streaming allocations while measurements scroll between them. Use a short Continue label with its full accessible name so Continue, Retry and Cancel fit together at normal physical width. The menu bar moon stays a system template at idle and turns crimson only after the stream actually starts.
- Add clipped-host rendering and injected lifecycle/failure regressions. Internal build 49; physical Touch Bar and macOS-private presentation acceptance remain outside CI.

## 1.3.5.1U — private full-bar animation correction

- Startup and Apollo artwork now spans the full allocated app area, behind the existing controls. Actions dock to the right so the central moon stays readable; narrow bars retain scrolling and nonblocking taps.
- Target the M1 display’s 60 Hz for boot, bound the procedural boot effect to 1280×800 physical pixels while keeping text and layout native, and request 60 fps for smoother Touch Bar motion while retaining the supplied scene timing. Skip expensive smoke calculations only where their exact visibility mask is zero; the authored scene and assets stay intact.
- Use the full-bar still artwork while idle without a live renderer. Preserve library and stream controls, the volume bar, Reduce Motion, finite startup, focus/cleanup and the separate full-width opt-in. The system Control Strip is not changed by the artwork.
- Add actual composited 685/1085-point row render checks. Internal build 48; physical M1 cadence and Touch Bar presentation still require hardware acceptance.

## 1.3.5.0U — private Smoke accretion artwork

- Integrate the supplied cratered moon and crimson smoke GPU scenes for startup and connection, preserving finite startup, status panels, nonblocking Continue/Cancel/Retry and stream/input boundaries.
- Adapt the supplied Touch Bar animation to the existing compact host/status tile; retain readable status, commands, scrolling, optional full width, streaming statistics and the crimson volume slider. Motion stops when inactive, hidden, detached, idle or streaming, and respects Reduce Motion.
- Add supplied app and template menu artwork and README banner. Package the Metal library and artwork for the native app, connection helper and previews. Guard renderer construction against reentrant AppKit layout callbacks.
- The supplied 13-second preview is the visual reference. Main/Touch Bar GPU rendering, compact tile/glyph visibility, animation lifecycle, numeric persistence and the 12-test Xcode UI suite passed on the integration candidate before packaging. Internal build 47; physical Touch Bar rendering and live host performance require hardware acceptance beyond CI.

## 1.3.4.2U — private Touch Bar audio navigation correction

- Keep Audio and Window pages inside the existing Controls Touch Bar popover instead of opening nested popovers, which can flash back to the main bar on hardware. Add an explicit Back control; preserve the crimson volume slider, white percentage, mute and all existing actions.
- Keep the selected page through telemetry, recording and volume updates; reopening Controls starts at its main page. Add navigation and repeated volume-adjustment regressions.
- Enable the existing measured bitrate output in macOS builds and read codec metadata from the actual engine format. Distinguish missing optional measurements from stale snapshots; host encode latency remains unavailable when the host does not supply it. Internal build 46; physical Touch Bar acceptance remains outside CI.

## 1.3.4.1U — private startup correction

- Fix the build 44 launch trap while initializing Touch Bar preferences: reuse the frontend’s existing preference store and safely retain the normal bar if the engine-hosted view cannot open the shared suite. Existing saved settings and the volume bar are preserved.
- Add a regression for unavailable shared preferences and production frontend startup validation. Internal build 45; physical macOS 27.2 acceptance remains outside CI.

## 1.3.4.0U — private live Touch Bar statistics

- FPS, network RTT and bitrate appear directly on the main Touch Bar beside Capture and Controls. Wider layouts add timing, network drops and local Mac hardware readings.
- Touch Bar telemetry uses the unchanged one-second statistics calculations independently of the on-screen statistics overlay. Audio, recording/replay and window actions remain available under Controls.
- Refined Warp Arrival and Apollo animations, preserving the native Continue/Cancel controls and Touch Bar integration. Startup Preview build/run, UI Preview tests and real Qt/SDL interaction checks passed on the isolated uploaded-animation branch at a9680117 before integration. Apollo retains the uploaded 60 fps schedule.
- Correct physical Touch Bar label clipping with explicit 30-point native button drawing, bounded two-line host status and readable action widths.
- Fix the ineffective preference-only full-width option with runtime-guarded AppKit system-modal presentation scoped to the active app/window; restore legacy per-app entries and leave system preferences unchanged.
- Preserve numeric settings while typing and drain queued discovery writes during app termination, so bandwidth survives restart and reaches the next stream. Other saved preferences and automatic bitrate adjustment semantics remain intact.
- Keep host status pinned with a horizontal control strip for narrow library/connection layouts. A single detailed-statistics panel holds a compact six-page pager and visible measurements; no oversized segmented selector competes with or hides the dashboard.
- Full-width presentation reads the shared frontend preference in both app and engine-hosted Apollo, observes distributed updates, and releases ownership safely during reentrant focus/close callbacks. Unsupported persisted full width is disabled.
- Route Controls to the recognized stream action and keep Touch Bar capture/statistics/hide/fullscreen working even when their keyboard shortcuts are disabled. Fullscreen delegates to the existing operation; shortcut behavior is unchanged.
- Optional original controls layout; full-width presentation stays off by default. Internal build 44; complete macOS/Xcode validation is required before delivery. Physical Touch Bar acceptance remains outside CI.


## 1.3.3.0U — private Touch Bar build

- Native Crimson Glass Touch Bar controls for the library, Apollo connection and stream window. Stream actions share existing SDL handlers.
- Live status, capture/release, local audio/mute/volume, recording time and replay readiness; secondary controls for statistics, hardware overlay, fullscreen, stream controls, hide and disconnect.
- Six information pages: incoming FPS/RTT/bitrate, resolution/codec/host latency, decode/queue/render delays, network/jitter drops and rendering FPS, local CPU/RAM/GPU sparklines, and network/thermal/controller status. Unavailable and stale measurements are labeled.
- Optional full-width Touch Bar setting in Appearance, off by default; backs up and restores only MoonlightLG’s per-app presentation entries.
- Internal build 43. Private U artifacts delivered to the owner; stable 1.3.2.0 remains available. ARM/Intel/Universal, Xcode, both UI suites, window/Metal/sanitizer and shutdown tests passed at 989a9a0; corrected AppKit alignment-rectangle preview fixture passed at 116989f6. Physical Touch Bar behavior remains unverified by CI.


## 🌙 1.3.2.0 — stable — 2026-10-30

- Dedicated Apple Silicon-only (arm64) build for M-series Macs, alongside Intel and Universal packages. All nested Mach-O files are thinned before signing and checked for arm64-only slices.
- Includes the Continue button event-pump and timeout-recovery fixes from 1.3.1.1U, plus Crimson Glass, stream statistics and optional recording/replay.
- About now credits the original projects, shows GPL redistribution/no-warranty notices, and links to offline original licenses and corresponding source. Full source archives are attached to the release.
- Internal build 42. Apple Silicon, Intel and Universal packages, full/incremental Xcode, both UI suites, Continue/recovery, fullscreen/Metal and sanitizer checks passed. The release includes original notices for 36 source components and the complete corresponding source archive. Live-host performance and streaming on every physical Mac are not verified by CI.

## 1.3.1.1U — unreleased — 2026-10-30

- Keep Continue/Cancel mouse presses nonblocking inside the Qt/SDL-owned connection window. A press and release arriving on separate event-pump turns no longer require NSCell's nested tracking loop.
- Distinguish Continue acceptance from an opened stream window. Both the hosted Continue button and frontend Continue action use the same 15-second handoff deadline; a stalled handoff cancels the helper and restores the library with a visible error.
- Add delayed mouse-event button coverage and real-process regressions for both stalled Continue paths. Internal build 41; complete Intel/Universal packages, full/incremental Xcode, both 12-test UI suites, delayed-click/recovery, fullscreen/Metal and sanitizer checks passed at source `f1a96a3`. Live-host acceptance remains unverified.

- The general window fixture now cancels stale AppKit zoom-hover timers; dedicated green-button/fullscreen coverage remains active.

## 1.3.1.0U — unreleased — 2026-10-13

- Stream statistics now match the hardware monitor: Crimson Glass, uppercase labels, bold values and rolling one-minute sparklines. All source readings and metadata are retained.
- Persistent Graphs toggle in the panel and Overlay settings; Off gives compact value cards. Controls are click-through during host capture and share existing mouse repair when released.
- Internal build 40. Full Intel/Universal bundles, fresh/incremental Xcode, both 12-test UI suites, graph parsing/history, actual mouse/fullscreen/Metal and sanitizer checks passed. Polished On/Off previews reviewed. Intel download inspected independently; Universal passed CI bundle validation.

## 1.3.0.0U — unreleased — 2026-10-13

- Adjustable local CPU, RAM, GPU (where supported), network graphs and thermal status in a Crimson Glass overlay. Position, size, opacity, visible metrics, refresh cadence and history are remembered. Captured gameplay passes clicks through; releasing input enables adjustment.
- Speaker button opens playback volume and mute controls. PCM gain is applied only to local playback after original encoded audio reaches the recorder.
- Title actions grouped as input/control, monitoring, playback/recording, then controller/connection status. New controls use the existing mouse-up/capture restoration boundary.
- Internal build 39. Checkpoint: `checkpoints/moonlightlg-1.2.2.0U-before-hardware-volume`. Intel/Universal packages, fresh/incremental Xcode, both 12-test UI suites, native mouse/fullscreen/Metal/sanitizer and production playback-volume/recording boundary checks passed. Downloaded versions, CPU slices and checksums verified.

## 1.2.2.0U — unreleased — 2026-10-13

- Suppress native macOS title chrome behind the released command overlay after green-button fullscreen, retaining one visible stream title row.
- Faster scale-aware Apollo warp stars, preserving arrival braking and Reduce Motion.
- Playback Mute/Unmute in the title row and narrow overflow, synchronized with the existing stream menu; source recording audio stays independent.
- Mute uses the same tracked mouse-up and session/window-scoped capture restoration as the other title buttons.
- Internal build 38. Checkpoint: `checkpoints/moonlightlg-1.2.1.0U-before-title-audio`. Full Intel/Universal packages, Xcode, both 12-test UI suites, green-button fullscreen/hover, actual mute-button capture restoration, production recording-mute boundary and sanitizer checks passed. Downloaded versions/CPU slices/checksums verified.

## 1.2.1.0U — unreleased — 2026-10-13

- QuickTime-style title controls overlay the video and hide while host input is captured; releasing input shows them again. Local popups, menus and focus loss keep controls accessible.
- Fullscreen and borderless fullscreen show only the stream command overlay on release, with no native title row or drawable resize. Windowed video extends beneath the title area; capture changes do not alter window/video geometry.
- Existing shortcuts, recording, replay and mouse restoration routes are preserved. Hidden controls do not intercept clicks or allow title-area dragging. Hide animation respects Reduce Motion.
- Internal build 37. Checkpoint: `checkpoints/moonlightlg-1.2.0.2U-before-autohide`. Full Intel/Universal, Xcode, both 12-test UI suites, actual SDL mouse/Metal and sanitizer checks passed. Downloaded packages verified as 1.2.1.0U/build 37.

## 1.2.0.2U — unreleased — 2026-10-13

- Accept large fragmented source-quality keyframes instead of falsely reporting queue overload at 129 fragments. Keep 32 MB ingress bounds and use reusable, bounded fragment metadata; recorder ABI 4.
- Distinguish fragment/frame input limits, queue byte/item congestion, invalid frames and allocation failures.
- Internal build 36. Mouse fixes are owner-confirmed and unchanged. Checkpoint: `checkpoints/moonlightlg-1.2.0.1U-before-recorder-fragments`.

- Fragmented-keyframe functional and sanitizer checks, both complete macOS packages, full Xcode, both 12-test UI suites and stock platform builds passed. Downloaded package versions/architectures/checksums verified. Physical source-quality recording acceptance remains.

## 1.2.0.1U — unreleased — 2026-10-13

- Restore prior relative mouse capture after title-bar buttons, overflow menus, popup dismissal and window dragging/resizing. Explicit input release and absolute desktop mode are preserved; computer-name Control Center behavior is retained.
- Request missing host keyframes for source-quality recording/replay startup and empty-buffer recovery, with bounded retries and explicit timeout; recorder ABI 3.
- Center the final stream window on its current display after resolution changes at Continue/start.
- Internal build 35. Checkpoint: `checkpoints/moonlightlg-1.2.0.0U-before-mouse-fix`.
- Both complete macOS packages, full Xcode, both 12-test UI suites, actual SDL drag/title-bar/Control Center and shutdown sanitizer checks passed. Recorder ABI 3 functional and sanitizer checks passed. Downloaded package metadata, architectures and SHA-256 verified. Live-host keyframe response and physical mouse behavior remain owner acceptance tests; U packages remain owner-only.

## 1.2.0.0U — unreleased — 2026-10-13

- Adopt redesign.major.minor.hotfix without leading zeros or rollover at 10.
- About and package filenames use the four-component version; Apple bundle metadata keeps its required three-component format. Internal build 34.
- Recording behavior is unchanged. Existing 1.2.00U/build 33 test packages and validation evidence retain their original labels. Video library and mouse changes remain deferred.

## 1.2.00U — unreleased — 2026-10-13

- Isolated recording/replay plugin, original-stream copy, optional hardware H.264/HEVC encoding and titlebar controls.
- Recording settings, independent audio capture, bounded queues and RAM/disk buffers.
- Disabled by default. Rollback checkpoint: `checkpoints/moonlightlg-1.1.03U-before-recording`. Mouse work remains deferred.
- Internal build 33. U links remain owner-only.
- [Design and validation](docs/RECORDING_PLUGIN.md). Recorder functional/sanitizer checks, both complete packages, both 12-test UI suites, full Xcode and stock platform builds passed. Live-host performance, HDR and surround acceptance remain.

## 1.1.03U — unreleased — 2026-10-12

- Use the boot animation's golden-angle star layout in the Apollo scene, with
  sideways travel instead of radial motion and the same star styling.
- Internal build 32. U download links remain owner-only.

Both complete packages, both 12-test UI suites, production connection-window
controls, fullscreen/Metal, sanitizers and 200 shutdown cycles passed. Flight and
orbit captures were visually checked. See [audit](docs/MOONLIGHTLG_1.1.03U.md).

## 1.1.02U — unreleased — 2026-10-12

- Use native AppKit connection buttons with direct target/action callbacks and
  first-click support inside the Qt/SDL stream window.
- Test actual Continue and Cancel mouse clicks with Qt, SDL and the SwiftUI
  animation running together, including Metal and same-window handoff.
- Internal build 31. U download links remain owner-only.

Both complete packages, both 12-test UI suites, actual Qt/SDL mouse-event routing,
window ownership, fullscreen/Metal, sanitizers and 200 shutdown cycles passed.
See [audit](docs/MOONLIGHTLG_1.1.02U.md). Live-host handoff remains an owner acceptance test.

## 1.1.01U — unreleased — 2026-10-12

- Correct placement: open the actual SDL stream window before starting host/game
  lookup, show Apollo flight and connection details inside it, and retain its full
  moon orbit until Continue. Video uses that same window/content view afterward.
- Remove the production animation from the library. Keep shared Canvas previews.
- Route window Close to Cancel during connection; keep errors/Retry in the stream
  window. Add real SDL/SwiftUI owner and handoff identity regression coverage.
- Internal build 30. U build links remain owner-only.

[Native macOS](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38294786786)
and [Xcode](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38294786858)
passed, including both 12-test UI suites, real window-first helper tests, same-window
handoff/confirmation/restore, complete Intel/Universal bundles, sanitizers and 200
shutdown cycles. See [audit](docs/MOONLIGHTLG_1.1.01U.md).

## 1.1.00U — unreleased — 2026-10-12

- Add a procedural Apollo spacecraft connection scene, flight through space,
  a full-moon rendezvous and continuing orbit until Continue to Stream.
- Show actual connection stages, host/game, warnings, errors and Cancel/Retry at
  the bottom. Respect Reduce Motion; no video or new bitmap asset is added.
- Hold stream window/fullscreen/input creation and silence stream audio until
  Continue. Preserve ordinary Qt launches and deferred connection cleanup.
- Keep U download links owner-only. Internal build 29.

[Native macOS validation](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38287571187)
and [Xcode validation](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38287571088)
passed. Intel/Universal bundles, both 12-test UI suites, fullscreen/input fixtures,
sanitizers and 200 engine shutdown cycles passed. See [audit](docs/MOONLIGHTLG_1.1.00U.md).
U app download links are shared directly with the owner only.

## 1.0.00U — unreleased — 2026-10-12

The first MoonlightLG version, following native Preview 27. The repository URL
remains `th3d3ck3r/moonlight-native-glass`.

- Rebrand the app, Dock/Finder identity, menus, About, permission descriptions,
  helper display names, Xcode project/schemes, build products and current docs.
- Add MoonlightLG beneath the startup icon with a finite arrival fade; retain the
  user-edited crimson warp, centered icon, satellite motion and playback timing.
- Introduce maintained major.minor.two-digit-patch versions with U for unreleased,
  E for experimental and no suffix for stable. Packages and About share metadata.
- Migrate the existing engine-log folder to MoonlightLG safely. Existing settings,
  bundle IDs, host pairing and permission identities are retained.
- Extend rounding across the full thin title bar, including the traffic-light side,
  with a decorative background that passes mouse input through.
- Carry forward the slim stream title row, line-graph icon, stream-owned
  disconnect sheet, input fixes and safe shutdown from Previews 25–27.

U build links go directly to the owner only; no public release/download posts.
Promote deliberately to E or stable before public distribution.

Validation: [Native macOS](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38278138413),
[Xcode](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38278138968),
and [shutdown sanitizers](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38278138691) passed.
Both UI suites passed 11 tests. See [audit](docs/MOONLIGHTLG_1.0.00U.md).
Older previews and Experimental 24 retain their historical names.

