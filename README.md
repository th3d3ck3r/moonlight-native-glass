<div align="center">

![Moonlight Native Glass — Native UI Preview](readme-assets/images/native-glass-banner.svg)

# 🌙 Moonlight Native Glass

### Your games. Your Mac. A native interface.

**SwiftUI / AppKit · Moonlight Qt 6.2.0 · Intel + Universal · Manual updates**

[![Native macOS validation](https://github.com/th3d3ck3r/moonlight-native-glass/actions/workflows/native-macos.yml/badge.svg?branch=native-ui)](https://github.com/th3d3ck3r/moonlight-native-glass/actions/workflows/native-macos.yml)
[![Moonlight Qt 6.2.0](https://img.shields.io/badge/engine-Moonlight_Qt_6.2.0-blue)](https://github.com/moonlight-stream/moonlight-qt/releases/tag/v6.2.0)
![macOS 15+](https://img.shields.io/badge/macOS-15%2B-silver)
![Manual updates](https://img.shields.io/badge/updates-Manual_only-8A2BE2)
[![GPLv3](https://img.shields.io/badge/license-GPLv3-blue)](LICENSE)

A native macOS frontend for Sunshine and compatible GameStream hosts.
Liquid Glass navigation and controls on **macOS 26+**, regular native styling on **macOS 15**, and system light/dark appearance throughout.

[📦 Downloads](#-downloads) · [✨ Features](#-features) · [🖼️ Preview](#-preview) · [🧪 Validation](#-validation) · [🛠️ Build](#-build)

</div>

## 📦 Downloads

**Native UI Preview 3 is available. Requires macOS 15 or later.**

| Your Mac | Package |
|---|---|
| 🖥️ **Intel** | [⬇️ Download Intel ZIP](https://github.com/th3d3ck3r/moonlight-native-glass/releases/download/native-glass-6.2-preview-3/Moonlight-Native-Glass-Preview-3-x86_64.zip) |
| 🍎 **Intel + Apple Silicon** | [⬇️ Download Universal ZIP](https://github.com/th3d3ck3r/moonlight-native-glass/releases/download/native-glass-6.2-preview-3/Moonlight-Native-Glass-Preview-3-universal.zip) |

[Release notes](https://github.com/th3d3ck3r/moonlight-native-glass/releases/tag/native-glass-6.2-preview-3) · [SHA-256 checksums](https://github.com/th3d3ck3r/moonlight-native-glass/releases/download/native-glass-6.2-preview-3/SHA256SUMS.txt) · [Validation runs](https://github.com/th3d3ck3r/moonlight-native-glass/actions/workflows/native-macos.yml) · [Checkpoint](docs/NATIVE_UI_CHECKPOINT.md)

English interface. Manual updates only. Preview packages use verified **ad-hoc signatures**, not Developer ID signing or notarization.

## ✨ Features

| Area | What this app provides |
|---|---|
| 🫧 **Native interface** | SwiftUI/AppKit sidebar, toolbar, game library, Settings and sheets; new glass crescent icon |
| 🌓 **Appearance** | System light/dark mode; native Liquid Glass controls on Tahoe; standard controls on macOS 15 |
| 🖥️ **Computers** | Discovery, manual address, pairing, wake, rename, remove and connection details |
| 🎮 **Library** | Host artwork, search, keyboard/controller navigation, game launch, hide and quit |
| ⚙️ **Settings** | Five native panes; resolution dropdown with 720p, 1080p, 1440p, 4K and detected Native dimensions |
| 🎬 **Streaming** | Original Moonlight Qt 6.2 Session/SDL window, renderer and codec capability checks |
| 🔊 **Input and audio** | Stock Moonlight keyboard, mouse, controller and audio paths |
| 📦 **Updates** | One English edition. Download new versions when you choose. |

The frontend is native; a bundled Qt helper still handles discovery, pairing, preferences and streaming. The streaming, backend, settings, common-c and mDNS source remains unchanged from the 6.2.0 baseline. Codec, HDR and hardware decoding availability depends on your Mac and host.

This is a separate project from Enhanced. Enhanced-only microphone, clipboard and AWDL extensions are not included. Preferences and pairing credentials are isolated from stock Moonlight and Enhanced; pair your host in this app.

## 🖼️ Preview

**Actual app screenshots from macOS CI, using sample computers and games. These are not mockups or proof of live streaming.**

| Light | Dark |
|---|---|
| ![Native library in light appearance](https://github.com/th3d3ck3r/moonlight-native-glass/releases/download/native-glass-6.2-preview-3/main-light.png) | ![Native library in dark appearance](https://github.com/th3d3ck3r/moonlight-native-glass/releases/download/native-glass-6.2-preview-3/main-dark.png) |

<details>
<summary>Native Settings screenshot</summary>

![Native Video Settings with sample preferences](https://github.com/th3d3ck3r/moonlight-native-glass/releases/download/native-glass-6.2-preview-3/settings-video.png)

</details>

<details>
<summary>About and new app icon</summary>

![About panel with crescent icon and creator credit](https://github.com/th3d3ck3r/moonlight-native-glass/releases/download/native-glass-6.2-preview-3/about-dark.png)

</details>

## 🧪 Validation

| Check | Verified state |
|---|---|
| Full Intel + Universal app builds | Passed at `904f5d1` · [validation run](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/37670613344) |
| Nested binaries, architectures and signatures | Passed signature, identity, permission and dependency audits of 105 Mach-O files |
| Engine bridge and settings persistence | Passed real helper validation, including resolution transaction/restart persistence and invalid-input rejection |
| Native UI screenshots | 16 Release-mode XCTest captures passed: light/dark/compact, loading/empty/offline/unpaired, sheets and five Settings panes; resolution selection checked and screenshots inspected |
| Physical Intel Tahoe pairing and streaming | **Not tested for this new app** |
| Intel CPU/GPU usage and frame pacing | **Not measured**; compilation does not prove performance parity |

`master` retains the stock Moonlight Qt **v6.2.0** application code from `de2467e433821664cdd2224aad8c89a625be1ad9`; its README presents this fork. Native development and build instructions live on [`native-ui`](https://github.com/th3d3ck3r/moonlight-native-glass/tree/native-ui). The earlier Enhanced repository and releases are untouched.

<details>
<summary>Intel Tahoe test checklist and known limits</summary>

- Launch through Finder; approve Local Network access and verify discovery/manual address.
- Pair and confirm status/games appear without reopening; relaunch to check persistence.
- Select 720p, 1080p, 1440p, 4K and Native; verify dimensions and resolution persistence, including scaled Retina and external displays.
- Launch/resume/disconnect a game; test H.264/HEVC hardware decode, audio and controller/keyboard/mouse input.
- Check resizing, fullscreen, display switching, light/dark mode, Reduce Transparency, Reduce Motion and increased contrast.
- Compare stock 6.2.0 and this app on the same Mac, host and settings: CPU/GPU usage, decode time, frame pacing and network statistics.

The bundled helper's Local Network attribution, multi-display behavior and interrupted-launch cleanup need physical testing. Disconnect with **Control–Option–Shift–Q** or **Start + Select + L1 + R1**. The streaming overlay remains the stock engine's overlay.

</details>

## 🛠️ Build

<details>
<summary>Build Intel or Universal on a Mac</summary>

Use Xcode 26+, Qt 6.11.2 and Python 3. Start with a recursive checkout on `native-ui`:

```bash
git clone --recurse-submodules --branch native-ui https://github.com/th3d3ck3r/moonlight-native-glass.git
cd moonlight-native-glass
bash scripts/build-native-macos.sh universal
# Intel only:
# bash scripts/build-native-macos.sh x86_64
```

The script builds the stock Qt engine, compiles the frontend for macOS 15+, bundles both, signs ad-hoc and audits nested dependencies. CI also checks protocol framing, actual engine persistence and native UI windows.

```bash
xcodebuild -project tests/native/NativeUITests.xcodeproj \
  -scheme NativeUITests -destination 'platform=macOS' test
```

</details>

## 🫧 Roadmap

| Stage | Status |
|---|---|
| Native sidebar, library, Settings and sheets | Implemented |
| Tahoe controls + macOS 15 fallback | Implemented; physical accessibility checks remain |
| Intel + Universal preview packages | Preview 2 published · experimental |
| Physical streaming and performance comparison | Required before calling this a stable replacement |

Built on [Moonlight Qt](https://github.com/moonlight-stream/moonlight-qt) and [moonlight-common-c](https://github.com/moonlight-stream/moonlight-common-c). See [GPL-3.0 license](LICENSE) and [original upstream documentation](docs/UPSTREAM_README.md).
