# 🌙 MoonlightLG 1.3.2.0

### Your games. Your Mac. A native interface.

A full MoonlightLG release with **Crimson Glass**, native macOS controls, dedicated **Apple Silicon-only** packaging, and the latest Continue-to-Stream fixes.

## 📦 Downloads

| Your Mac | Download |
|---|---|
| 🍎 **Apple Silicon — M1 and newer** | [**MoonlightLG-1.3.2.0-arm64.zip**](https://github.com/th3d3ck3r/moonlight-native-glass/releases/download/moonlightlg-v1.3.2.0/MoonlightLG-1.3.2.0-arm64.zip) |
| 🖥️ **Intel** | [MoonlightLG-1.3.2.0-x86_64.zip](https://github.com/th3d3ck3r/moonlight-native-glass/releases/download/moonlightlg-v1.3.2.0/MoonlightLG-1.3.2.0-x86_64.zip) |
| 💻 **Apple Silicon + Intel** | [MoonlightLG-1.3.2.0-universal.zip](https://github.com/th3d3ck3r/moonlight-native-glass/releases/download/moonlightlg-v1.3.2.0/MoonlightLG-1.3.2.0-universal.zip) |

**macOS 15+ · Moonlight Qt 6.2.0 · Internal build 42 · Manual updates**

The Apple Silicon-only package contains arm64 code throughout its app, engine, frameworks, and plugins. SHA-256 checksums are attached as **SHA256SUMS.txt**.

## ✨ Included

- 🫧 Native sidebar, toolbar, game library, pairing sheets, and Settings. Liquid Glass on macOS 26+, with native styling on macOS 15.
- 🌑 Near-black **Crimson Glass** with crimson accents, matching moon artwork, and optional system appearance.
- 🚀 Warp Arrival startup and an Apollo connection screen with real status details.
- 🎛️ Native stream controls, fullscreen behavior, input capture/release, and menu bar access.
- 📊 Stream statistics cards with optional sparklines, plus an adjustable local hardware monitor.
- 🔊 Playback volume and mute independent of source recording audio.
- 🎬 Optional recording/replay plugin, Original Stream Quality, and hardware-encoding options. Enable Recording before starting a stream.
- 🎮 Host discovery, pairing, game artwork/search, launch, wake, rename, and host-game quit actions.

## 🛠️ Continue-to-Stream fixes

- Connection buttons handle press and release without nesting an NSCell tracking loop inside the Qt/SDL-owned window.
- Continue acceptance is distinguished from confirmation that the stream window has opened.
- Both Continue paths have a 15-second handoff deadline. A stalled handoff cancels the helper and restores the library with a visible error.
- Delayed-click and real-process timeout regressions cover the previously missed paths.

## 🚀 Install or update

1. Download and extract the ZIP for your Mac.
2. Quit the old copy and move **MoonlightLG.app** into **Applications**.
3. Open the app and allow Local Network access. If macOS blocks opening, use **System Settings → Privacy & Security → Open Anyway**.
4. Pair your host in MoonlightLG, choose a game or Desktop, then click **Continue to Stream** once connected.

Existing MoonlightLG preference and pairing identities are preserved. Packages are ad-hoc signed and verified; they are not Developer ID signed or notarized.

## 💛 Credits, licenses & source

About distinguishes MoonlightLG modifications from the original Moonlight projects and other components. **Licenses & Notices** opens an offline index of original copyright/license texts, Qt third-party attributions, the font notice, and the full GPL. Redistribution/modification rights and the no-warranty notice are visible in About. The GPL license, combined third-party notices, and exact source inventory are also attached separately to this release.

[Download the complete corresponding source archive](https://github.com/th3d3ck3r/moonlight-native-glass/releases/download/moonlightlg-v1.3.2.0/MoonlightLG-1.3.2.0-source.tar.gz). This includes the tracked app and initialized submodule sources, original dependency source archives, build recipes/patches, and a source/hash inventory.

## 🧪 Validation & limits

Publication requires complete Apple Silicon, Intel, and Universal packages; nested architecture/signature/dependency checks; native macOS and Xcode validation; both UI suites; Continue/recovery, fullscreen/Metal, and sanitizer checks. The packaged arm64 engine is also exercised directly.

Live-host latency, HDR, surround-audio, and streaming behavior on every physical Mac are not established by CI. No new live-stream performance claims are made in this release.

![MoonlightLG Crimson Glass library](https://github.com/th3d3ck3r/moonlight-native-glass/releases/download/moonlightlg-v1.3.2.0/main-dark.png)

[📚 Full README](https://github.com/th3d3ck3r/moonlight-native-glass#readme) · [📝 Changelog](https://github.com/th3d3ck3r/moonlight-native-glass/blob/moonlightlg-v1.3.2.0/CHANGELOG.md) · [🐛 Issues](https://github.com/th3d3ck3r/moonlight-native-glass/issues)

This software is based in part on the work of the FreeType Team.
This software is based in part on the work of the Independent JPEG Group.
