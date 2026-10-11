# Native startup animation and live Canvas preview

This change starts at the validated Preview 20 source checkpoint
`9532df823f7785f75dc6db4bfa93fc4d2ef26683`, on
`feature/native-boot-animation`. It contains no AWDL helper source, settings,
installation scripts, services, or helper build changes. Preview build: 22.

The user's supplied Xcode onboarding reference informs the choreography:
a seed expands into a blue fill, four particles separate, fine construction
rings and grid lines emerge, and the fill contracts into the **unchanged
bundled `moonlight.icns` logo**. The native sequence takes 4.1 seconds plus a
0.35-second fade. It uses time-driven SwiftUI vector drawing at a requested
60 Hz, scales to the window/backing resolution, and stops updating on completion.
No video decoder is involved; the previous movie remains an unused resource.

During startup only the artwork and genuine macOS close/minimize/zoom buttons
appear. No library, title text, toolbar, sidebar, search field, or visible Skip
button is constructed underneath it. Escape and the accessibility Skip action
bypass startup. Reduce Motion and missing/invalid artwork go straight to the
library. Closing or quitting cleans up the timer and window appearance. Reopening
the window in the same process doesn't replay; a fresh app launch does.

## Live preview

Open `MoonlightNativeGlass.xcodeproj`, select **Moonlight UI Preview**, and open
`macos-native/Previews/NativeGlassLivePreview.swift`. Enable **Editor > Canvas**
and its live mode. Choose **Native Glass · Live startup** and use **Replay
Startup** to repeat. Dark and light sample-library previews are also included.
The Canvas represents the three window buttons visually; the running app uses
actual AppKit controls. Sample previews do not launch the streaming engine.

## Verification

`BootPlaybackTests.swift` exercises synchronous chrome hiding, unchanged content,
frame preservation, resize, natural completion, skip, close, invalid/missing
artwork and Reduce Motion on macOS. The existing UI tests verify one window,
stable frame across reveal, no underlying library/search during startup, real
close buttons, Escape, reopen/relaunch, and sheet routing after reveal.
The root Xcode build compiles the new Canvas file. Full Intel/universal builds
and the existing streaming/input/engine checks remain required before delivery.

Exact perceived smoothness and matching on the user's Intel/OCLP Mac require
local testing; 60 Hz scheduling is a target, not a hardware frame-rate guarantee.
