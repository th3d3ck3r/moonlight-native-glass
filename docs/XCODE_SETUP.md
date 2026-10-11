# Open Moonlight Native Glass in Xcode

Clone `th3d3ck3r/moonlight-native-glass` and select the `native-ui` branch.
Open **MoonlightNativeGlass.xcodeproj** at the repository root. A GitHub source
ZIP of the `native-ui` branch also works; its missing submodule sources are
fetched automatically by the full build.
Use Xcode 26: the existing frontend references the macOS 26 Liquid Glass SDK.
The built app still supports macOS 15 or later through its runtime fallbacks.

## Run the full app

Select **Moonlight Native Glass**, choose **My Mac**, and press **Command-R**.
The first build automatically fetches the pinned submodules, Moonlight v19
dependencies, Qt 6.11.2 and private build tools. Internet access is needed for
that first build, which takes longer than subsequent incremental builds.
No Homebrew, separate Qt installation, terminal setup or Apple Developer team
is required for local development. The app uses an ad-hoc signature.

The project builds and embeds the real streaming helper from this checkout.
It does not download an older release or depend on expiring Actions artifacts.
The original qmake build remains the engine's source of truth.

## Work on the UI quickly

Select **Moonlight UI Preview** and press **Command-R**. This scheme uses sample
hosts/games, shows the startup animation, and skips the engine and dependency
downloads. It does not connect to a streaming host.

Both schemes support **Command-U** for the native UI tests. Tests use the Preview
configuration, with each case supplying its own launch arguments.
The Preview configuration enables SwiftUI preview support. Run the UI Preview
scheme to preview the app window with sample content.

## Project layout

- **Native Sources**: the existing SwiftUI/AppKit frontend files, edited in place.
- **Resources**: the Dock/menu icon and boot movie used by the app.
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

This setup does not connect a remote chat session to your Mac or grant screen
control. It prepares the local checkout for Xcode editing, running and debugging.

## Validation

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
