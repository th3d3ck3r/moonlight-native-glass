# 🌙 MoonlightLG 1.3.5.4 · Crimson Glass

Apple Silicon · internal build 52

## ✨ Touch Bar

- Native black/crimson controls for the library, connection and stream windows, with SF Symbols, readable host status and scrolling for secondary actions.
- Live FPS, network RTT and measured bitrate directly on the main bar, independently of the on-screen overlay. Six detailed statistics pages retain timing, codec, drops and local hardware readings, with unavailable/stale values identified.
- Continuous local volume slider and mute, capture/release, recording/replay, fullscreen, hide and disconnect controls. Audio and Window pages retain their navigation instead of opening nested popovers.
- Optional full-width presentation, off by default, with runtime compatibility guards, focus/visibility cleanup and normal-bar fallback. Global, Fn and other-app preferences are preserved.
- Library/startup/connection bars no longer request principal-item centering, matching the placement policy of the working stream bar.

## 🌌 Animations and reliability

- Supplied Smoke accretion artwork and Moon pulse animations, adapted to the allocated Touch Bar area and existing controls.
- Finite startup, nonblocking Continue/Cancel/Retry, Reduce Motion support and hidden/inactive renderer cleanup.
- Numeric settings autosave and shutdown write draining preserve bandwidth through restart and into the next stream. Startup preference-store failures safely retain the normal bar.

## 📦 Packages and source

- Apple Silicon-only app ZIP for M-series Macs; macOS 15 or later.
- Packages are ad-hoc signed and verified, but not Developer ID signed or notarized. Installation guidance is in the README.
- Complete corresponding application, submodule and third-party dependency source archive.
- SHA-256 checksums, GPL license, third-party notices and source manifest accompany the release. Existing upstream copyright and About credits are retained.

## 🧪 Validation and limits

Validation covers exact-source macOS and Xcode builds, Startup Preview build/run, UI Preview tests, connection/window/input regressions, architecture, version, checksum, source and legal checks.

CI has no physical Touch Bar or live streaming host. The owner has demonstrated the in-stream layout on an M1; the latest library placement, full-width system presentation and real-host playback performance still require on-device acceptance. Full width uses guarded private AppKit APIs and can fall back to the normal bar on unsupported runtimes. These checks do not certify every physical action or guarantee compatibility with future macOS versions.

