# 🧪 Moonlight Native Glass — Experimental Build 24

**Experimental pre-release · Native UI 24 · Moonlight Qt 6.2.0 · macOS 15+ · Intel + Universal**

This promotes the exact verified Preview 24 packages from application source
`4d8ee8a4bab531aaa43ee7a9ccef6b51f8f08053`. Only the distribution filenames change;
the binaries are not rebuilt. About displays Native UI Preview 24.

## ✨ Changes

- App-wide Crimson Glass with the edited crimson Warp Arrival, moon/satellites,
  matching Dock/menu artwork and native Liquid Glass on supported macOS versions.
- Rounded actual Dock asset and crimson statistics, status and Control Center surfaces.
- Control Center cursor ownership survives region/resize/display updates and focus
  return. Done preserves the earlier captured or released input state.
- Rounded opaque overlay fallback when Reduce Transparency is enabled.
- Expanded production capture tests, fullscreen lifecycle checks and sanitizer coverage.

## 📦 Downloads

Choose `Moonlight-Native-Glass-Experimental-24-x86_64.zip` for Intel, or
`Moonlight-Native-Glass-Experimental-24-universal.zip` for Intel/Apple Silicon.
Extract the ZIP and move the app to Applications. Allow Local Network access and
pair your host in this app. Updates remain manual.

Packages are ad-hoc signed and verified, but not Developer ID signed or notarized.
SHA256SUMS.txt is attached. Screenshots use sample content, not live streaming.

## ✅ Validation

[Native validation](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38219537762):
Intel and Universal bundle builds/audits; all 10 native UI tests; fullscreen Metal
presentation/hide/restore; production relative/absolute capture and local pointer
confinement; AddressSanitizer/UndefinedBehaviorSanitizer; settings/persistence,
failure recovery, 200 immediate shutdown cycles and menu/icon checks.

[Xcode validation](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38219537999):
fresh and incremental full-app builds, real-engine checks, source-ZIP pinned
submodule recovery, startup preview and all 10 UI preview tests.

[Full audit](https://github.com/th3d3ck3r/moonlight-native-glass/blob/feature/native-boot-animation/docs/NATIVE_APP_AUDIT_PREVIEW_24.md).
Both packages were independently downloaded and verified against artifact digests,
package SHA-256 files, versions, architecture slices and exact icon assets.

## 🐛 Reported issues under investigation

- Disconnect confirmation can appear with the library rather than the stream window.
- Control–Option–Shift–E has been reported to show error 11.

These post-validation reports remain unresolved in this experimental snapshot.

## 🧪 Still experimental

CI runs on Apple Silicon and cross-builds Intel; no live Vibepollo/Sunshine host
was available. Test cursor visibility/confinement and immediate host input after
Done in Windowed, Full Screen and Borderless Full Screen, including repeated
open/Done, relative/absolute input, resize and app/menu focus changes. Discovery,
pairing, audio/controllers, reconnects, sleep/wake and Intel/OCLP animation/glass
behavior still need physical acceptance. Streaming performance was not benchmarked.
Optional physical exclusive fullscreen retains upstream limitations.

Report issues with reproduction steps, Mac/macOS, host version, window mode and
engine logs. This is an experimental build, not a stable release.
