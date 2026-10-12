# Native Glass Preview 24 audit — October 12, 2026

Repository: `th3d3ck3r/moonlight-native-glass`.
Branch: `feature/native-boot-animation`.
Application and validation source: `4d8ee8a4bab531aaa43ee7a9ccef6b51f8f08053`.

## Scope

Read the complete native Swift application layer and native AppKit/Qt adapters:
library and game cards, all settings panes and host sheets, app lifecycle,
controller navigation, process transport and event framing, stream launch and
menu commands, startup coordinator and production warp, crimson appearance,
Dock/status artwork, native title toolbar, stream-window delegate, overlays and
cleanup. Traced overlay actions and focus/region updates through the existing
Session and SdlInputHandler. Reviewed packaging, permissions and CI integration.

The audit covers the custom native app and its integration boundaries; it is not
a line-by-line certification of upstream Moonlight or third-party dependencies.
No other confirmed defect was found in the reviewed native application paths.

## Findings and fixes

| Finding | Result and change |
| --- | --- |
| The Control Center cursor setup returned immediately on every repeat call | Setup now reasserts visibility and whole-window confinement without replacing the original state restored on dismissal. |
| Production region updates did not preserve local controls ownership | Resize, decoder reset and display updates retain the visible controls pointer. Focus return restores that local pointer without recapturing host input. Menu/dialog suspension retains its existing temporary-release behavior. |
| The integration fixture substituted its own capture implementation | Tests now compile the production `setCaptureActive`, `isCaptureActive`, `updatePointerRegionLock`, focus/action methods and aspect-fit calculation. The network sink and system-key preference update remain fixture stubs. |
| Preview 23's crimson assertion assumed translucent colors | The test now checks the correct dark opaque palette and full opacity when Reduce Transparency is enabled, and the brighter translucent palette otherwise. It continues checking all overlay surfaces and existing panel identity on theme changes. |
| Composited screenshots showed square opaque corners behind rounded overlays | NSPanel stays transparent; the opaque accessibility fallback is clipped inside the rounded root material. Tests check transparent panel backgrounds and the rounded clip. |
| Xcode validation ignored native adapter/input-only commits | Workflow paths now include those changes, so the full project and preview schemes validate the final revision. |

The reviewed streaming boundary hash changes cover only the two macOS local
cursor hooks in `input.cpp` and `mouse.cpp`. Upstream decoding, timing, networking,
settings policy and common-c are unchanged. The existing edited Warp Arrival,
star lane 45, crimson icons/title styling and native Liquid Glass are retained.
The actual Dock ICNS and transparent menu images have zero-alpha corners.

## Validation

Final [native validation run 38219537762](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38219537762)
passed all three jobs: Intel, Universal and native UI. Final
[Xcode validation run 38219537999](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38219537999)
passed the fresh complete app build, incremental build, embedded real-engine
checks, source-ZIP pinned dependency recovery, startup preview scheme and UI
preview scheme. Both independent UI runs passed all 10 XCTest cases.

The native suite passed event framing, frontend process/failure recovery,
startup/chrome cleanup, all overlay shortcuts/state/layout/overflow/theme checks,
fullscreen Metal presentation and captured hide/restore, actual SDL window/input
lifecycle, and the same input/window fixture under AddressSanitizer and
UndefinedBehaviorSanitizer. Expanded production capture tests cover repeated
open/Done, relative and absolute modes, prior captured/released intent, pointer
state repair after region/focus updates, Cocoa confinement and deferred capture.
Real bridge checks passed settings schema/types/enum choices/Boolean roundtrip,
atomic validation, persistence, invalid/stale-host recovery and correlated
pause/resume replies. Immediate shutdown passed 100 cycles with the crash trace
hook and another 100 without it. Status icon/menu/restore checks passed.

Reviewed 27 native UI captures from the first Preview 24 pass (the Swift UI
sources are identical to the final pass), and final composited stream overlays.
The final images confirm rounded opaque fallback corners without the square
backing, legible labels, separated panels and visible Disconnect/Done controls.
Local streaming-boundary, Python syntax, shell syntax and whitespace checks
passed. The actual Dock and menu image corners were independently inspected.

Both downloaded packages were independently verified against the GitHub
artifact digests and their included package SHA-256 files. Bundle versions,
frontend architecture slices and exact icon resource bytes were checked again.
CI also verifies both bundle identities, Local Network/Bonjour keys, executable
architectures, nested dependencies and ad-hoc signatures.

| Package | Download | Package SHA-256 |
| --- | --- | --- |
| Intel x86_64 | [Preview 24 Intel](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38219537762/artifacts/11733153391) | `edc02dd8dddf22e9fc79e8a354505dccd247469c611f8939f7f6c73f0d468b8f` |
| Universal | [Preview 24 Universal](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38219537762/artifacts/11734556392) | `5938eb296def4d2fd4b4d5434ab1ccea8ef322c1e1d626741032620ac5e0edbb` |

[Final stream overlay captures](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38219537762/artifacts/11734305386)
and [final native UI captures](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38219537762/artifacts/11734105541)
are available from the same validation run.

## Physical acceptance still required

CI runs on ARM macOS 26 and cross-compiles Intel. It has no live
Vibepollo/Sunshine host. On the Intel Mac, repeat Control Center open/Done using
the title bar and shortcut in Windowed, Full Screen and Borderless Full Screen;
check cursor visibility/confinement, immediate remote motion/clicks after Done,
relative/absolute input, initially released input, repeated cycles, resize,
menu/Settings/other-app focus changes, Disconnect and close/reopen. Also verify
startup smoothness and Liquid Glass rendering on that Mac.

The automated fixtures exercise real SDL/AppKit windows and Cocoa confinement,
including native motion routing, but cannot establish physical mouse behavior,
remote input delivery, streaming performance or Intel/OCLP graphics correctness.
Packages are ad-hoc-signed previews. No release/tag or master change was made.
