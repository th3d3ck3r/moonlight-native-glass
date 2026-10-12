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
remain in the stream window, and Retry creates a fresh session/window safely after
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
and teardown. Full macOS/Xcode/visual validation is pending.

Internal build 30, version 1.1.01U. U build links are shared directly with the owner
and are not posted in public release/download lists. Physical live-host and Intel
acceptance remain required beyond Apple Silicon CI/cross-compilation.
