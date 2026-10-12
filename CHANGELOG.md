# MoonlightLG changelog

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
