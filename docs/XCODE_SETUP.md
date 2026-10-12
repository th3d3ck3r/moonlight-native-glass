# Open Moonlight Native Glass in Xcode

For the native startup animation and Canvas previews, use branch
`feature/native-boot-animation`. It starts from the validated Preview 20
checkpoint and includes **no AWDL helper changes**. The stable `native-ui`
branch remains at that checkpoint.

Open **MoonlightNativeGlass.xcodeproj** at the repository root with **Xcode 26**.
Choose:

- **Moonlight Native Glass**: build and run the real app with its existing
  streaming engine. Dependency setup stays automatic.
- **Moonlight UI Preview**: run the sample library immediately, skipping both
  engine setup and startup animation.
- **Moonlight Startup Preview**: run the native startup animation in the actual
  macOS window, then show the sample library; no streaming engine is built.

For live Canvas previews, open
`macos-native/Previews/NativeGlassLivePreview.swift`, choose **Moonlight UI
Preview**, and enable **Editor > Canvas** and live mode. Use **Replay Startup**
to repeat the animation. Dark/light libraries and fixed construction-ring/logo
stages are included. For the five new motion alternatives, open
`macos-native/Previews/NativeGlassAnimationAlternatives.swift`: **Orbit Reveal**,
**Aurora Bloom**, **Starlight Weave**, **Lunar Eclipse**, and **Prism Sweep**.
Each Canvas preview has its own Replay button, uses the same small original
Moonlight logo and three window dots, and fades into the sample library. The
alternatives do not replace the app's selected animation. All original logo
assets remain unchanged. The faint square construction grid has been removed
from the current startup.

No additional source files need to be added manually: the
project already includes all preview code and resources.

The preview schemes support **Command-U** for native UI tests. Cases supply their
own launch arguments. Production deployment remains macOS 15 and newer, with
Intel and Apple Silicon build support.

## Project layout

- **Native Sources**: the existing SwiftUI/AppKit frontend files, edited in place.
- **Resources**: the unchanged Dock/menu icons; the older boot movie is retained as a fixture.
- **Tests**: native UI tests and their settings fixture.
- **Moonlight engine sources**: the existing Qt sources; the helper build uses
  qmake instead of duplicating its compiler settings inside Xcode.
- `scripts/build-xcode-engine.py`: automatic tools, incremental engine build,
  deployment and helper signing. Downloads/caches live under ignored `build/`;
  the existing prebuilt library layout remains under ignored `libs/`.

Local Run builds only need the Mac's selected architecture. To build a Universal
app, use the full scheme with `ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO` in
`xcodebuild`, or set **Build Active Architecture Only** to **No** in Xcode.
Release/archive builds use the same frontend and engine; a distributable signed
and notarized release still needs the separate release signing process.

The Canvas previews use sample data and do not launch the streaming engine.

## Previous baseline validation

Validated at source `dcf3a66a20e05e0d819f30e3078d434498d7eb6e` in
[Native Xcode Project Validation run 38098996413](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38098996413),
job `114350802360`:

- Fresh-checkout full Universal build and deep signature verification passed.
- All 107 bundled Mach-O files passed dependency and Intel/ARM architecture checks.
- Incremental rebuild reused the deployed engine and succeeded.
- The embedded real engine passed settings/type/choice, atomic validation,
  persistence, stale-host recovery and correlated pause/resume checks.
- A git-free source export automatically recovered all three pinned submodules.
- The UI Preview build skipped engine setup; all eight UI tests passed using
  the root project, including boot, Skip/Escape, close/reopen, Dock/menu routing,
  sheets, About and Settings.
- Existing native UI validation also passed at the same source in run
  `38098996384`, job `114350802318`.

CI runs on ARM macOS 26 and cross-compiles the Intel slice. Physical Intel/OCLP
behavior and live-host streaming still require testing on your Mac. The setup
changes build/project configuration and audits; the app UI and streaming core
remain at the verified Preview 20 source.

## Native startup validation

The first native startup revision passed all eight root-project UI tests at
`80cff78ddcd80acd4da47b34dfdd1787de98a995`, run `38158772255`.
A later revision removes the remaining title-region background and adds four
composited artwork-stage captures. Both full Intel/Universal packages passed in run `38159249193`; its nine-test
UI suite also passed. The root project's fresh/incremental Universal builds,
real-engine bridge and source-ZIP dependency recovery passed in run
`38159249190`. A close-during-startup UI test was made deterministic after that
run, without changing the app's production source. Final revision `8039226cfb3d5bead2f2c696f466c35f5c6d6f28` passed both nine-test
UI suites in runs `38160139878` and `38160139957`. The startup scheme built
without the engine, and all Canvas preview code compiled. See
`docs/NATIVE_STARTUP_ANIMATION.md` for evidence and physical-test limits.
