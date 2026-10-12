# MoonlightLG 1.1.02U — connection controls

The owner reported that clicking Continue left the Apollo orbit unchanged.
Connection controls now use AppKit NSButton target/action dispatch inside the
Qt/SDL-owned NSHostingView, with first-click acceptance. The Canvas animation,
connection protocol and same SDL window handoff remain intact.

The regression fixture now runs QGuiApplication alongside SDL and the production
Swift host dylib. It sends actual down/up events to native Cancel and Continue,
checks hit testing and callback delivery, verifies the Continue gate is released,
and retains the same window/content identity for stream controls. It uses a Metal
window, checks restore, host-game sheets and Close, then tears down normally.

Validated application/test source: `ceb1e5d9004c0941012495acd0e1497fef10c398`.
Numeric version `1.1.02`, channel `U`, internal build `31`.

| Validation | Result |
|---|---|
| [Native macOS run 38301674388](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38301674388) | Intel and Universal complete builds, bundle audits and 12 UI tests passed |
| [Xcode run 38301674450](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38301674450) | Fresh/incremental full app, source ZIP setup, preview schemes, embedded engine and 12 UI tests passed |
| Actual connection controls | Native button hit testing, mouse down/up delivery to Cancel and Continue, callback delivery and gate release passed with Qt, SDL, Metal and the production Swift host |
| Window ownership | Orbit waits for Continue; same SDL window/content survives handoff; Close, restore and stream-owned host-game confirmation passed |
| Streaming regressions | Fullscreen/Metal, input/window lifetime and ASan/UBSan checks passed; reviewed streaming boundary hashes unchanged |
| Engine lifecycle | Real settings/persistence and 200 immediate shutdown cycles passed |
| Packages | Both downloaded archives matched CI checksums; metadata and all 106 Mach-O files checked for required architectures |

The actual stream-window capture `apollo-inside-stream-window.png` was visually
checked from the native run's window previews. The Canvas flight/orbit and bottom
details remain intact, with native Continue and Cancel controls.

| Package | SHA-256 |
|---|---|
| `MoonlightLG-1.1.02U-x86_64.zip` | `56307bd398939da528b0349b412c655f395af244d61239d80087d05bdf101253` |
| `MoonlightLG-1.1.02U-universal.zip` | `ebc2a0303270122e3ccf46a096701c87cc0d79dd24ad80b70db8f39781e3b242` |

The Intel app, engine and connection-view binaries contain x86_64; dependency
audits verify their required Intel slice. Universal includes arm64 and x86_64.
Intel was cross-built on Apple Silicon, not run on physical Intel hardware.

No live host is available on the macOS CI runner. These tests verify real button
events, callback delivery and window ownership, while actual host/decoder handoff
requires the owner's Mac acceptance test. U package links are shared directly with
the owner, never posted as releases or downloads here.
