# MoonlightLG 1.1.01U — connection animation in the actual stream window

The previous 1.1.00U placed the animation in the library and waited before creating
the stream window. That placement was incorrect. This correction opens the real
SDL stream window first, before host/game lookup or Session networking starts.

The helper hosts the same procedural SwiftUI Apollo view as an ordinary subview
of the SDL Cocoa content view. It does not wrap a Qt window, replace the SDL
content view, or create another window for the video. Connection stages and
errors are sent directly to that view; Connected enters orbit until Continue.
Continue removes only the temporary hosting view, then Session adopts the same
SDL window, initializes normal input/video and applies the requested fullscreen
mode. No remote input/audio is active while waiting. Zoom/fullscreen is disabled
on the connection chrome until handoff; Close routes to Cancel. Errors and Retry
remain in the stream window; warnings are visible at the bottom and the host-game quit
confirmation is a sheet owned by that same window. Dock/menu restore brings back
the connecting window, including after minimization. Retry creates a fresh session/window safely after
cleanup. The library is hidden when the stream connection window opens.

The SwiftUI host is a small compiled dylib in the helper Frameworks directory,
using the existing view/Canvas code and no new media. Both CLI and Xcode package
recipes compile every required CPU slice and sign/audit the nested code. Existing
preferences, pairing/bundle identities, thin rounded stream chrome, disconnect
sheet and safe E/deferred cleanup are preserved.

Before builds: streaming boundary review permits only the Session window-adoption
and presentation gate hooks. Decoder/transport/settings/timing code is unchanged.
The production gate fixture passes locally. An actual SDL/SwiftUI window fixture
checks window-first visibility, content/window identity through orbit and Continue,
Close/Cancel routing, removal of the hosting subview, normal controls attachment
and teardown.

## Completed validation

[Native macOS](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38294786786),
[Xcode](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38294786858)
and [shutdown regression](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38294786762)
passed on the source below. Both 12-test UI suites passed with zero failures.
Fresh/incremental Xcode builds, source-ZIP setup, previews, complete Intel/Universal
builds, signatures/permissions/identities/dependencies and all 106 Mach-O files
passed. Frontend pipe fixtures verify owner-initiated Continue, Restore, Retry,
Settings-error isolation and ignored late Cancel messages. The real packaged helper
proves connectionWindowOpened precedes host/game lookup, then cancels safely before
a Session. The real SDL/SwiftUI fixture verifies native window/content identity,
Close/Cancel, minimize/restore, the stream-owned host-game confirmation sheet,
Crimson Glass chrome and the normal controls after handoff. The original
fullscreen/Metal/input/capture/lifetime and ASan/UBSan checks passed. Real-engine
settings/persistence and 200 immediate shutdown cycles passed.

The actual [composited stream-window capture](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38294786786/artifacts/11768261790)
was inspected: the Apollo scene and bottom details are inside the SDL window,
without the library toolbar, and its title bar matches Crimson Glass.

Both downloaded app packages were independently verified for artifact/package
checksums, 1.1.01U/build 30 metadata, retained bundle identity and CPU architecture.
The frontend, engine and embedded SwiftUI host are x86_64 in Intel and arm64+x86_64
in Universal. The host exports the required attach/update/detach ABI.

| Package | SHA-256 |
|---|---|
| Intel | `4661482a30df834314d451436aeeffd51b81150889dd2b4553188bbd5ff72a7c` |
| Universal | `e6bd9aae7618cc78e071dc822a32c59f82509526323a1b83561561270e29ef8d` |

App download links are shared directly with the owner only.

Application/test source: `b924605d343c4a461d46e452c748f18fa6dd5360`.

Internal build 30, version 1.1.01U. U build links are shared directly with the owner
and are not posted in public release/download lists. Physical live-host and Intel
acceptance remain required beyond Apple Silicon CI/cross-compilation.
