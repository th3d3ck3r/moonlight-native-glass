# 🌙 MoonlightLG 1.3.6.0 · Crimson Glass

### Your games. Your Mac. A native interface.

Apple Silicon · macOS 15+ · internal build 56 · manual updates

## ✨ Touch Bar, with a little history

- 📈 Auto-scaling sparklines show a rolling **three minutes** of numeric telemetry inside the existing cards. Current values stay readable; missing readings and inactive intervals leave gaps.
- 🎛️ Live FPS, RTT and bitrate remain independent of the screen overlay. Six detailed pages cover codec, timing, drops, hardware and local-network activity.
- 🌑 Balanced compact statistics and a protected moon area preserve the existing layout and buttons.
- 🔊 The crimson playback-volume slider lives outside horizontal scrolling. Audio/Back navigation preserves its owning surface and complete native slider host.
- 🌙 Library, Apollo and stream controls retain SF Symbols, accessible meanings, horizontal scrolling and supplied Smoke/Moon animations.
- 🫧 Optional full width is off by default, restores the system Control Strip on focus loss/disable/close/detach and falls back to the regular bar when unsupported. Global/Fn/other-app preferences are preserved. The unused Mac button is removed.

## 🌌 Reliability & recording

- Finite startup, nonblocking Continue/Cancel/Retry, Reduce Motion and inactive-renderer cleanup.
- Bandwidth autosave survives restart and reaches the next stream.
- Original Stream Quality recording requests periodic host keyframes while retaining compressed source-copy recording. This is not a claim that hour-long playback has been physically verified.
- Existing streaming/input boundaries, shortcuts, pairing identities, animation assets and license attribution are preserved.

## 📦 Downloads & installation

- 🍎 Apple Silicon-only app: `MoonlightLG-1.3.6.0-arm64.zip`.
- 📚 Complete corresponding source: `MoonlightLG-1.3.6.0-source.tar.gz`, including submodules, pinned dependency sources, recipes and patches.
- 🔐 `SHA256SUMS.txt`, GPL license, third-party notices and source manifest accompany the app.

Quit the old app, extract the ZIP and move **MoonlightLG.app** into **Applications**. Allow Local Network access when prompted. Packages are ad-hoc signed and verified, not Developer ID signed or notarized; if macOS blocks opening, use **System Settings → Privacy & Security → Open Anyway**. Preferences and pairing identities are preserved.

## 🧪 Validation & limits

Exact-source macOS and Xcode validation must pass before publication, including Touch Bar layout/navigation/ownership, graph history sanitizers, settings persistence, connection/window/input checks, Startup Preview and UI tests. Staging verifies checksums, stable version metadata, ARM64-only nested binaries and all dependency-source hashes.

CI has no physical Touch Bar or live streaming host. Physical M1 gestures, graph legibility, optional full-width compatibility, animation cadence and long recording playback remain owner acceptance checks. Full width uses guarded private AppKit APIs; future runtime compatibility is not guaranteed. Intel is cross-built on Apple Silicon; this release delivers the M1 package.

## 💛 Credits & source

MoonlightLG builds on Moonlight Qt and moonlight-common-c. Original copyright/license texts, offline notices and About attribution remain intact. The complete corresponding source accompanies the release.

This software is based in part on the work of the FreeType Team.
This software is based in part on the work of the Independent JPEG Group.
