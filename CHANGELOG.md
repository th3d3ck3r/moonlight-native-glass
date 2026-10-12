# MoonlightLG changelog

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
