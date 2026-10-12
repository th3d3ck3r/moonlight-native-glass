<div align="center">

![Moonlight Native Glass](https://raw.githubusercontent.com/th3d3ck3r/moonlight-native-glass/native-ui/readme-assets/images/native-glass-banner.svg)

# 🌙 Moonlight Native Glass

### Your games. Your Mac. A native interface.

**🧪 Experimental Build 24 · Crimson Glass · Moonlight Qt 6.2.0 · Intel + Universal · Manual updates**

[![Experimental build](https://img.shields.io/badge/release-Experimental_24-crimson)](https://github.com/th3d3ck3r/moonlight-native-glass/releases/tag/native-glass-experimental-24)
[![Native macOS validation](https://github.com/th3d3ck3r/moonlight-native-glass/actions/workflows/native-macos.yml/badge.svg?branch=feature/native-boot-animation)](https://github.com/th3d3ck3r/moonlight-native-glass/actions/workflows/native-macos.yml)
![macOS 15+](https://img.shields.io/badge/macOS-15%2B-silver)
![Manual updates](https://img.shields.io/badge/updates-Manual_only-8A2BE2)
[![GPLv3](https://img.shields.io/badge/license-GPLv3-blue)](https://github.com/th3d3ck3r/moonlight-native-glass/blob/native-ui/LICENSE)

A native macOS frontend for Sunshine and compatible GameStream hosts.
Liquid Glass navigation and controls on **macOS 26+**, standard native styling on **macOS 15**, with a near-black **Crimson Glass** theme, crimson accents and matching moon artwork. Turn Crimson Glass off in Appearance settings to follow the system appearance.

[🧪 Download Experimental 24](#-download-experimental-build-24) · [✨ Features](#-features) · [🖼️ Screenshots](#-screenshots) · [🧪 Testing](#-testing-and-known-limitations) · [🛠️ Build](#-build)

</div>

## 🧪 Download Experimental Build 24

**This is an experimental pre-release for testing, not a stable release. Requires macOS 15 or later.**

| Your Mac | Download |
|---|---|
| 🖥️ **Intel** | [Download Experimental 24 Intel ZIP](https://github.com/th3d3ck3r/moonlight-native-glass/releases/download/native-glass-experimental-24/Moonlight-Native-Glass-Experimental-24-x86_64.zip) |
| 🍎 **Apple Silicon or Intel** | [Download Experimental 24 Universal ZIP](https://github.com/th3d3ck3r/moonlight-native-glass/releases/download/native-glass-experimental-24/Moonlight-Native-Glass-Experimental-24-universal.zip) |

[Release notes](https://github.com/th3d3ck3r/moonlight-native-glass/releases/tag/native-glass-experimental-24) · [SHA-256 checksums](https://github.com/th3d3ck3r/moonlight-native-glass/releases/download/native-glass-experimental-24/SHA256SUMS.txt) · [Earlier RC1](https://github.com/th3d3ck3r/moonlight-native-glass/releases/tag/native-glass-rc1) · [All releases](https://github.com/th3d3ck3r/moonlight-native-glass/releases)

1. Download and extract the ZIP for your Mac.
2. Move **Moonlight Native Glass.app** into Applications and open it through Finder.
3. Allow Local Network access, add or discover your host, then pair it in this app.

Packages are **ad-hoc signed and verified**, but **not Developer ID signed or notarized**. macOS may require approval before opening. Updates are manual; download a new package when you choose.

Experimental 24 contains the exact validated **native UI build 24** binaries with **Moonlight engine 6.2.0**. About identifies the native UI as Preview 24. The experimental label does not rebuild or change the application. Physical Intel/live-host testing is still required, particularly Control Center mouse behavior.

## ✨ Features

| Area | What this app provides |
|---|---|
| 🫧 **Native interface** | SwiftUI/AppKit library, sidebar, toolbar, Settings and sheets |
| 🌙 **Menu bar** | Restore an existing stream window, reopen the library, open Settings and quit; rounded crescent/full-moon states |
| 🌓 **Appearance** | App-wide Crimson Glass, matching moon icons, Liquid Glass on Tahoe and native controls on macOS 15; optional system appearance |
| 🖥️ **Computers** | Discovery, manual address, pairing, wake, rename, removal and connection details |
| 🎮 **Library** | Host artwork, search, keyboard/controller navigation, game launch, hide/show and quit |
| ⚙️ **Settings** | Appearance, Video, Audio, Input, Network, Advanced, Overlay and Shortcuts; changes save automatically |
| 🚀 **Startup** | Crimson Warp Arrival with a moon and two satellites; Escape to skip; respects Reduce Motion |
| 🎬 **Streaming** | Moonlight Qt 6.2.0 Session/SDL window and stock codec, renderer and hardware capability checks |
| 🎛️ **Stream controls** | Native controls, statistics/status surfaces, customizable buttons and shortcuts; windowed title-bar controls |
| 📦 **Updates** | One English edition; manual installation and updates |

A bundled Moonlight Qt helper handles discovery, pairing, preferences and streaming. Stock backend, settings policy, common-c, mDNS, decoding and timing implementations remain intact. Small reviewed macOS presentation/input hooks connect the native controls and window lifecycle to the engine; a source-boundary check guards those changes. Codec, HDR and hardware-decoding availability depends on your Mac and host.

This is a separate project from Enhanced. Enhanced-only microphone, clipboard and AWDL extensions are not included. Preferences and pairing credentials are isolated from stock Moonlight and Enhanced; pair your host here.

### 🎛️ Window and stream actions

| Default shortcut | Action |
|---|---|
| **Control–Option–Shift–Q** | Hide the existing stream window while keeping the session connected |
| **Control–Option–Shift–O** | Show or hide stream controls |
| **Control–Option–Shift–B** | Disconnect the stream without quitting the host game |
| **Start + Select + L1 + R1** | Stock controller disconnect shortcut |

Closing the red button in a windowed stream also hides that window. Use the menu bar icon to restore it. Full Screen and Borderless Full Screen hide/restore are covered by automated tests. Shortcuts can be customized in Settings. **Disconnect and Exit** also quits the host game; it is different from plain Disconnect.

### 🛠️ What changed in Experimental 24

- Added the edited **crimson Warp Arrival** startup, matching Dock/menu icons and app-wide crimson accents while retaining native Liquid Glass.
- Rounded the actual Dock icon asset and applied crimson styling to statistics, status and Control Center overlays.
- Preserved Control Center's visible, confined cursor through resize/display updates and focus return; Done retains the previous captured or released input state.
- Removed square opaque backing corners from rounded overlays when Reduce Transparency is enabled.
- Expanded regression coverage using the production capture methods, repeated relative/absolute mouse cycles, fullscreen hide/restore and sanitizers.
- Validated complete Intel and Universal packages, a fresh Xcode build, incremental rebuild, startup/UI previews and real-engine settings/lifecycle behavior.

## 🖼️ Screenshots

**Actual composited app captures from macOS CI using sample hosts and games. They show the interface, not live streaming performance.**

| Crimson library | Stream overlays |
|---|---|
| ![Crimson Glass library](https://github.com/th3d3ck3r/moonlight-native-glass/releases/download/native-glass-experimental-24/main-dark.png) | ![Rounded crimson stream overlays](https://github.com/th3d3ck3r/moonlight-native-glass/releases/download/native-glass-experimental-24/overlay-controls-dark.png) |

<details>
<summary>Settings, stream customization and shortcuts</summary>

![Video Settings](https://github.com/th3d3ck3r/moonlight-native-glass/releases/download/native-glass-experimental-24/settings-video.png)
![Overlay customization](https://github.com/th3d3ck3r/moonlight-native-glass/releases/download/native-glass-experimental-24/settings-overlay.png)
![Shortcut Settings](https://github.com/th3d3ck3r/moonlight-native-glass/releases/download/native-glass-experimental-24/settings-shortcuts.png)

</details>

<details>
<summary>About and menu bar access</summary>

![About panel](https://github.com/th3d3ck3r/moonlight-native-glass/releases/download/native-glass-experimental-24/about-dark.png)
![Menu bar actions](https://github.com/th3d3ck3r/moonlight-native-glass/releases/download/native-glass-experimental-24/menu-bar.png)

</details>

## 🧪 Testing and known limitations

[Native validation run 38219537762](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38219537762) and [Xcode validation run 38219537999](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38219537999) passed at application/test source **`4d8ee8a4`**.

| Check | Result |
|---|---|
| Intel + Universal builds | Complete builds passed; signatures, permissions, identities, dependencies and 105 Mach-O files audited; downloaded package checksums independently verified |
| Native UI and Xcode | All 10 XCTest tests passed in each UI run; fresh/incremental complete Xcode builds, source-ZIP dependency setup and preview schemes passed |
| Window and input lifecycle | Both normal macOS fullscreen modes passed Metal presentation and captured hide/restore; production capture/region/focus tests and repeated relative/absolute Control Center cycles passed |
| Settings and helper lifecycle | Schema/type/enum/Boolean roundtrip, atomic validation, persistence, failure/cancellation recovery and 200 immediate shutdown cycles passed in native validation |
| Memory and controls | SDL/AppKit window/input tests passed with AddressSanitizer and UndefinedBehaviorSanitizer; shortcuts, layout, theme switching and rounded icon checks passed |
| Physical host and Intel coverage | CI runs on Apple Silicon and cross-builds Intel. Live-host behavior and physical Intel acceptance still require testing |
| Streaming performance | CPU/GPU usage, decode latency and frame pacing were **not benchmarked** |

**Reported issues under investigation:** The disconnect confirmation can appear with the library instead of the stream window, and Control–Option–Shift–E has been reported to crash the streaming helper with signal 11. These reports are not resolved by Build 24.

**Follow-up test build 26:** The confirmation is now a sheet owned by the stream window. Native E also retains deferred cleanup when controls are unavailable, and stopped window owners reject queued focus callbacks. Both shutdown failures were reproduced in CI before their fixes. [Build 26 audit and validation](docs/NATIVE_APP_AUDIT_PREVIEW_26.md) · [Intel test package](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38228271873/artifacts/11737731988). The physical live-stream signal-11 report still needs confirmation on a Mac; Experimental 24 remains the published snapshot.

**Experimental limitations:** Test Control Center's cursor visibility, confinement and immediate remote input after Done on a live host in Windowed, Full Screen and Borderless Full Screen. Also test discovery/pairing, host actions, audio/controllers, reconnects, sleep/wake, display changes and startup smoothness on your Mac. Optional physical exclusive fullscreen (`I_WANT_BUGGY_FULLSCREEN`) retains upstream limitations. Packages are not notarized. Passing CI does not establish real-device streaming correctness.

Report problems through [GitHub Issues](https://github.com/th3d3ck3r/moonlight-native-glass/issues) with your macOS version, Intel/Apple Silicon model, host software/version, window mode, reproduction steps and relevant logs. **Open Engine Logs** is available in the app menu. See the [Build 24 audit](https://github.com/th3d3ck3r/moonlight-native-glass/blob/feature/native-boot-animation/docs/NATIVE_APP_AUDIT_PREVIEW_24.md) for fixes, validation evidence and physical acceptance steps.

## 🛠️ Build

The [`native-glass-experimental-24` tag](https://github.com/th3d3ck3r/moonlight-native-glass/tree/native-glass-experimental-24) contains the frozen Experimental 24 source. [`feature/native-boot-animation`](https://github.com/th3d3ck3r/moonlight-native-glass/tree/feature/native-boot-animation) contains ongoing fixes after that snapshot. [`native-ui`](https://github.com/th3d3ck3r/moonlight-native-glass/tree/native-ui) retains the earlier native UI development line. `master` retains the stock Moonlight Qt 6.2.0 application sources; its README presents this project.

<details>
<summary>Build Intel or Universal on a Mac</summary>

Use Xcode 26+, Qt 6.11.2 and Python 3 with a recursive checkout:

```bash
git clone --recurse-submodules --branch native-glass-experimental-24 https://github.com/th3d3ck3r/moonlight-native-glass.git
cd moonlight-native-glass
bash scripts/build-native-macos.sh universal
# Intel only:
# bash scripts/build-native-macos.sh x86_64
```

Open **MoonlightNativeGlass.xcodeproj** for the full app and the **Moonlight Startup Preview** / **Moonlight UI Preview** schemes. The script above builds the same Qt engine and native frontend, bundles them for macOS 15+, signs ad-hoc and audits dependencies. Run the UI tests with:

```bash
xcodebuild -project tests/native/NativeUITests.xcodeproj \
  -scheme NativeUITests -destination 'platform=macOS' test
```

</details>

Built on [Moonlight Qt](https://github.com/moonlight-stream/moonlight-qt) and [moonlight-common-c](https://github.com/moonlight-stream/moonlight-common-c). See the [GPL-3.0 license](https://github.com/th3d3ck3r/moonlight-native-glass/blob/native-ui/LICENSE) and [upstream documentation](https://github.com/th3d3ck3r/moonlight-native-glass/blob/native-ui/docs/UPSTREAM_README.md).
