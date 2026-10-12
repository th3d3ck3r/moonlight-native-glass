# MoonlightLG 1.0.00U — initial rebrand and full title-bar corners

Application source: `59ada30ea06bdaf9c547d1fd5f2605f553a2e228`.
Repository URL unchanged: `th3d3ck3r/moonlight-native-glass`.
Development branch: `feature/native-boot-animation`.

## Branding and versions

The app, executable, Finder/Dock names, About/Quit menus, library defaults, error
and permission descriptions, helper display names, Xcode project/targets/schemes,
Canvas preview names, packages and current docs now use MoonlightLG. The native
helper bundle is MoonlightLGEngine.app; its upstream engine executable and version
remain Moonlight/6.2.0. Existing bundle IDs, IPC keys, preferences and host pairing
identities are preserved. Existing logs migrate to Library/Logs/MoonlightLG when
the destination is absent, with safe fallback and concurrent-first-launch handling.

The release line starts at 1.0.00. U marks unreleased work; E marks experimental
builds; stable releases have no suffix. Numeric bundle fields and a dedicated
release-channel key generate the human version. About and package naming use the
same metadata. The current version is 1.0.00U, internal build 28. AGENTS.md records
user-required version maintenance; CHANGELOG.md records the release history.

The finite startup arrival now fades in MoonlightLG beneath the existing icon.
The edited warp field, satellites, centered icon and 4.1-second lifetime remain.
Shared construction/alternative previews also display the name.

## Full-width title-bar rounding

Preview 27 rounded the control group but left the traffic-light side square at
the bottom. One full-width, 12-point-radius surface now sits under the native
controls. The accessory controls remain in the ordinary 32-point title row.
The straight title separator is hidden while this presentation is installed.
The decorative view's hitTest returns nil, so native buttons, drag events and
SDL input retain their routing. The SDL content view, geometry and window style
are preserved. The old background, transparency, separator and title visibility
restore on detach; both fullscreen modes remove the entire decorative surface.
No networking, decoder, timing or settings implementation changes are made.

Actual compositor captures were inspected. The old lower-left row was uniformly
filled; the new corner transitions from black through the curved edge into the
material. This confirms the corner is rendered, beyond checking a radius property.
The full-width/narrow captures show one continuous thin surface. The startup name
is centered below the icon; About displays Version 1.0.00U with separate engine
attribution and the original maintainer credit.

## Validation

The local source-membership, scheme XML, shell/Python syntax, whitespace and
streaming-boundary checks passed. Native tests cover version/channel formatting,
invalid metadata, log migration, actual name/icon geometry, About/version, all
renamed menus, Dock reopening, boot completion/skip/close, full-width chrome
geometry, mouse passthrough, title buttons, capture/confinement, stream-owned
confirmation, fullscreen/Metal/hide/restore, theme switching and teardown.
The window/input fixtures and separate shutdown regression pass ASan/UBSan.
All 11 native UI tests pass on this source.

[Native macOS validation](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38278138413),
[Xcode validation](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38278138968),
and [shutdown sanitizers](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38278138691) passed.
Complete Intel and Universal builds passed; both UI suites passed 11 tests, and
200 engine shutdown cycles passed. The startup/About and full-width title-bar
compositor captures were inspected.

U builds are development only and are not posted. The workflow suppresses
downloadable app uploads for U, and experimental publishing requires E.
CI validation artifacts created before this rule was clarified are not release
downloads and are not advertised.
CI runs on Apple Silicon and cross-builds Intel. These no-host fixtures do not
certify a physical Intel/live stream or establish the exact reported signal-11 stack.

