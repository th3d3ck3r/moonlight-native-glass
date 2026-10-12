# Preview 27 — slim rounded stream title row

Application source: `29bfc288f5ab51809f5e2d8d6b19cb09efd0f834`.
Branch: `feature/native-boot-animation`.

## Appearance and behavior

Statistics now uses the native `chart.xyaxis.line` symbol rather than bars.
The taller stream NSToolbar is replaced by one right-aligned title-bar accessory,
sharing the ordinary macOS title row with the original traffic lights. The real
SDL Cocoa fixture measures 32 points of window chrome before and after attachment:
adding the controls consumes no extra video area. The computer name stays centered.
Native Liquid Glass on macOS 26 uses an 8-point corner radius; macOS 15 falls back
to rounded title-bar visual-effect material. The row uses smaller glyphs and text,
while button hit regions fill the available title-row height.

At narrow widths, More Stream Controls exposes the existing capture, Control
Center, statistics, battery and connection commands through a native menu.
The same actions, tooltips, accessibility labels, active crimson tint and connection/
battery warnings are retained. The native button tracking workaround remains.

The accessory is removed before fullscreen transitions. Borderless windows never
query unsupported titlebar-accessory APIs; the fixture also checks their actual
view hierarchy for visible leftover controls. Both fullscreen modes retain full
video geometry and hide the title controls. Detach restores the original title
visibility and transparency. Existing stream-owned confirmation and Preview 26
shutdown fixes remain in place. Session's only new change brackets its existing
SDL fullscreen call with native presentation detach/restore; decoder, networking,
settings, timing and common-c implementations remain unchanged.

## Validation

[Native validation run 38271677015](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38271677015)
passed full Intel and Universal builds and bundle audits, event framing,
frontend failure recovery, boot/chrome cleanup, all window/overlay/input fixtures,
ASan/UBSan, real-engine settings/persistence, 200 shutdown cycles, status icons,
menu actions and all 10 native UI tests.

Actual macOS compositor captures were inspected for the wide and narrow rows.
The overlay fixture verifies ordinary title-row height, all actions, narrow layout
without overlapping the host entry, wider-window restoration, controller/popover
behavior, theme changes and teardown. Real SDL/Metal fullscreen, captured hide/
restore, physical AppKit title-button clicks, input-confinement restoration and
stream-owned confirmation fixtures pass, including ASan/UBSan window/input runs.
The separate shutdown sanitizer regression passes on this source.

[Shutdown sanitizer run 38271677011](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38271677011) passed.
[Xcode validation run 38271677006](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38271677006)
passed fresh and incremental complete app builds, embedded real-engine checks,
source-ZIP dependency recovery, startup preview and all 10 UI preview tests.
The separate native UI smoke suite also passed all 10 tests. Local whitespace and
source-boundary checks passed.

## Intel test package

[Intel Build 27](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38271677015/artifacts/11757816102).
The downloaded artifact digest, internal package checksum, x86_64 executable and
bundle build number 27 were independently verified. Package SHA-256:
`afd3b21e8eb35ed1c22fe76f07a492035d0dfe38215722ef8dfa615c8d99521a`.

[Universal Build 27](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38271677015/artifacts/11758131113).
The Universal artifact digest, package checksum, arm64/x86_64 architectures and
bundle build number 27 were also independently verified. Package SHA-256:
`0bbd084a59a6953dcb2e10bb01362cd127697f2e15e7c39576d7d8e174b21027`.

Experimental 24 remains the public prerelease; Build 27 is a follow-up test package.
CI uses Apple Silicon, with Intel cross-builds; a physical Intel/live host test is
not represented by the no-host window and input fixtures.
