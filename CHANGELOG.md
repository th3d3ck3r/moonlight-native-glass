# MoonlightLG changelog

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
