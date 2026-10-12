# MoonlightLG 1.1.03U — connection star layout

Use the existing Warp Arrival boot animation's 150-star golden-angle layout,
lane spacing and perspective depth distribution in the Apollo scene. The boot
animation itself remains unchanged. For connection flight, points move sideways
(right to left) instead of radially, and slow when Apollo reaches the moon.
The boot star styling is retained: flight trails point horizontally and shrink
to points as Apollo reaches orbit.

The former modular x/y coordinates formed diagonal lines. Using the boot layout
breaks that alignment while retaining the user's preferred existing design.
The native buttons, flight/orbit, connection gate and window ownership are unchanged.

Application/test source: `011e16025fc0ed6f155be5fd16ba83c371c497b3`.
Version: 1.1.03U, internal build 32.

| Check | Result |
|---|---|
| [Native macOS run 38305771305](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38305771305) | Complete Intel/Universal builds, bundle audits and 12 UI tests passed |
| [Xcode run 38305771327](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38305771327) | Fresh/incremental full app, source ZIP setup, preview schemes, real engine and 12 UI tests passed |
| Production window | Qt/SDL/SwiftUI Continue/Cancel mouse events, same-window handoff, orbit wait, host-game confirmation, Close and restore passed |
| Regressions | Fullscreen/Metal, window/input lifetime and ASan/UBSan passed; 200 immediate engine shutdown cycles passed |
| Source boundary | Startup Warp Arrival, networking, decoding, settings and reviewed streaming hashes unchanged |
| Package verification | Both downloads matched CI checksums; version/channel/build metadata and all 106 Mach-O files checked for required architectures |

The actual stream-window orbit capture and the separate flight design preview
were visually checked. The former confirms the production window ownership;
the latter confirms the horizontal flight trail direction and boot-style layout.

| Package | SHA-256 |
|---|---|
| `MoonlightLG-1.1.03U-x86_64.zip` | `bc2591ddab927ebfabf60021f74f5599c02aa336460245e4bdef674364dcc019` |
| `MoonlightLG-1.1.03U-universal.zip` | `baa3f0888fa1a7ad7d788cb36c9af235c021857febff574da05b3513647c86b7` |

Intel was cross-built on Apple Silicon, not run on physical Intel hardware.
Live-host handoff remains an owner Mac acceptance test. U app download links are
shared directly with the owner, never posted as releases or downloads here.
