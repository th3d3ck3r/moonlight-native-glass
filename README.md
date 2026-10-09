<div align="center">

![Moonlight Native Glass](https://raw.githubusercontent.com/th3d3ck3r/moonlight-native-glass/native-ui/readme-assets/images/native-glass-banner.svg)

# 🌙 Moonlight Native Glass

### Your games. Your Mac. A native interface.

**RC1 · Native UI build 15 · Moonlight Qt 6.2.0 · Intel + Universal · Manual updates**

[![Release candidate](https://img.shields.io/badge/release-RC1-orange)](https://github.com/th3d3ck3r/moonlight-native-glass/releases/tag/native-glass-rc1)
[![Native macOS validation](https://github.com/th3d3ck3r/moonlight-native-glass/actions/workflows/native-macos.yml/badge.svg?branch=native-ui)](https://github.com/th3d3ck3r/moonlight-native-glass/actions/workflows/native-macos.yml)
![macOS 15+](https://img.shields.io/badge/macOS-15%2B-silver)
![Manual updates](https://img.shields.io/badge/updates-Manual_only-8A2BE2)
[![GPLv3](https://img.shields.io/badge/license-GPLv3-blue)](https://github.com/th3d3ck3r/moonlight-native-glass/blob/native-ui/LICENSE)

A native macOS frontend for Sunshine and compatible GameStream hosts.
Liquid Glass navigation and controls on **macOS 26+**, standard native styling on **macOS 15**, and system light/dark appearance throughout.

[📦 Download RC1](#-download-rc1) · [✨ Features](#-features) · [🖼️ Screenshots](#-screenshots) · [🧪 Testing](#-testing-and-known-limitations) · [🛠️ Build](#-build)

</div>

## 📦 Download RC1

**Release Candidate 1 is a testing release with remaining issues under investigation. Requires macOS 15 or later.**

| Your Mac | Download |
|---|---|
| 🖥️ **Intel** | [Download Intel ZIP](https://github.com/th3d3ck3r/moonlight-native-glass/releases/download/native-glass-rc1/Moonlight-Native-Glass-RC1-x86_64.zip) |
| 🍎 **Apple Silicon or Intel** | [Download Universal ZIP](https://github.com/th3d3ck3r/moonlight-native-glass/releases/download/native-glass-rc1/Moonlight-Native-Glass-RC1-universal.zip) |

[Release notes](https://github.com/th3d3ck3r/moonlight-native-glass/releases/tag/native-glass-rc1) · [SHA-256 checksums](https://github.com/th3d3ck3r/moonlight-native-glass/releases/download/native-glass-rc1/SHA256SUMS.txt) · [Previous previews](https://github.com/th3d3ck3r/moonlight-native-glass/releases)

1. Download and extract the ZIP for your Mac.
2. Move **Moonlight Native Glass.app** into Applications and open it through Finder.
3. Allow Local Network access, add or discover your host, then pair it in this app.

Packages are **ad-hoc signed and verified**, but **not Developer ID signed or notarized**. macOS may require approval before opening. Updates are manual; download a new package when you choose.

RC1 promotes the exact tested **native UI build 15** binaries with **Moonlight engine 6.2.0**. About still identifies that native UI build as Preview 15; the RC1 release label does not change the engine version or rebuild the application.

## ✨ Features

| Area | What this app provides |
|---|---|
| 🫧 **Native interface** | SwiftUI/AppKit library, sidebar, toolbar, Settings and sheets |
| 🌙 **Menu bar** | Restore an existing stream window, reopen the library, open Settings and quit; rounded crescent/full-moon states |
| 🌓 **Appearance** | System light/dark mode, Liquid Glass on Tahoe and native controls on macOS 15 |
| 🖥️ **Computers** | Discovery, manual address, pairing, wake, rename, removal and connection details |
| 🎮 **Library** | Host artwork, search, keyboard/controller navigation, game launch, hide/show and quit |
| ⚙️ **Settings** | Video, Audio, Input, Network, Advanced, Overlay and Shortcuts; changes save automatically |
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

### 🛠️ What changed for RC1

- Corrected fullscreen hide/reopen so Borderless Full Screen exits its Space before hiding and re-enters through the SDL event loop.
- Suppressed native title controls during fullscreen and hidden-window transitions.
- Preserved fullscreen input-capture intent through hide/restore and checked actual relative mouse event routing.
- Rounded both menu bar icon states while preserving the artwork.
- Separated the About panel's native UI build number from the bundled engine version.
- Fixed native helper ownership so it is cleaned up before Qt platform/logger teardown; repeated immediate shutdown checks now pass.
- Expanded settings, helper failure/cancellation, persistence and invalid/stale-host recovery coverage.

## 🖼️ Screenshots

**Actual composited app captures from macOS CI using sample hosts and games. They show the interface, not live streaming performance.**

| Light | Dark |
|---|---|
| ![Native library in light appearance](https://github.com/th3d3ck3r/moonlight-native-glass/releases/download/native-glass-rc1/main-light.png) | ![Native library in dark appearance](https://github.com/th3d3ck3r/moonlight-native-glass/releases/download/native-glass-rc1/main-dark.png) |

<details>
<summary>Settings, stream customization and shortcuts</summary>

![Video Settings](https://github.com/th3d3ck3r/moonlight-native-glass/releases/download/native-glass-rc1/settings-video.png)
![Overlay customization](https://github.com/th3d3ck3r/moonlight-native-glass/releases/download/native-glass-rc1/settings-overlay.png)
![Shortcut Settings](https://github.com/th3d3ck3r/moonlight-native-glass/releases/download/native-glass-rc1/settings-shortcuts.png)

</details>

<details>
<summary>About and menu bar access</summary>

![About panel](https://github.com/th3d3ck3r/moonlight-native-glass/releases/download/native-glass-rc1/about-dark.png)
![Menu bar actions](https://github.com/th3d3ck3r/moonlight-native-glass/releases/download/native-glass-rc1/menu-bar.png)

</details>

## 🧪 Testing and known limitations

[Validation run 37795784286](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/37795784286) passed all three required jobs at application/test source **`7202a71c`**.

| Check | Result |
|---|---|
| Intel + Universal builds | Complete builds passed; signatures, permissions, identities, dependencies and 105 Mach-O files audited |
| Native UI | All five XCTest tests passed, including library/settings/sheets, About, Dock reopening, menu bar Settings/Quit and screenshot export |
| Fullscreen/window lifecycle | Both stock macOS fullscreen modes passed startup, known-color Metal presentation, desktop return and repeated hide/reopen; native focus and relative mouse routing passed |
| Settings and helper lifecycle | Every exported setting's schema/type checks, advertised enum choices, boolean roundtrip, atomic validation, restart persistence and eight immediate launch/exit cycles passed |
| Recovery and controls | Invalid addresses/stale host requests, transport failures, launch cancellation/retry, shortcuts, overlay layout and rounded status-icon pixels passed |
| Physical host and Intel coverage | CI runtime checks use Apple Silicon; Intel is cross-built. Live-host behavior and physical Intel acceptance are not certified by these tests |
| Streaming performance | CPU/GPU usage, decode latency and frame pacing were **not benchmarked** |

**Known limitations:** RC1 still has remaining errors to iron out. Successful discovery, pairing, host actions, audio/input, reconnects, sleep/wake and display changes need real-device acceptance. Optional physical exclusive fullscreen (`I_WANT_BUGGY_FULLSCREEN`) retains upstream limitations; the normal macOS Full Screen and Borderless Full Screen modes are the tested paths. Packages are not notarized.

Report problems through [GitHub Issues](https://github.com/th3d3ck3r/moonlight-native-glass/issues) with your macOS version, Intel/Apple Silicon model, host software/version, window mode, reproduction steps and relevant logs. **Open Engine Logs** is available in the app menu. See the [audit](https://github.com/th3d3ck3r/moonlight-native-glass/blob/native-ui/docs/NATIVE_APP_AUDIT.md) and [development checkpoint](https://github.com/th3d3ck3r/moonlight-native-glass/blob/native-ui/docs/NATIVE_UI_CHECKPOINT.md) for detailed coverage.

## 🛠️ Build

The [`native-ui` branch](https://github.com/th3d3ck3r/moonlight-native-glass/tree/native-ui) contains the native app. `master` retains the stock Moonlight Qt 6.2.0 application sources; its README presents this project.

<details>
<summary>Build Intel or Universal on a Mac</summary>

Use Xcode 26+, Qt 6.11.2 and Python 3 with a recursive checkout:

```bash
git clone --recurse-submodules --branch native-ui https://github.com/th3d3ck3r/moonlight-native-glass.git
cd moonlight-native-glass
bash scripts/build-native-macos.sh universal
# Intel only:
# bash scripts/build-native-macos.sh x86_64
```

The script builds the Qt engine and native frontend, bundles them for macOS 15+, signs ad-hoc and audits dependencies. Run the UI tests with:

```bash
xcodebuild -project tests/native/NativeUITests.xcodeproj \
  -scheme NativeUITests -destination 'platform=macOS' test
```

</details>

Built on [Moonlight Qt](https://github.com/moonlight-stream/moonlight-qt) and [moonlight-common-c](https://github.com/moonlight-stream/moonlight-common-c). See the [GPL-3.0 license](https://github.com/th3d3ck3r/moonlight-native-glass/blob/native-ui/LICENSE) and [upstream documentation](https://github.com/th3d3ck3r/moonlight-native-glass/blob/native-ui/docs/UPSTREAM_README.md).
