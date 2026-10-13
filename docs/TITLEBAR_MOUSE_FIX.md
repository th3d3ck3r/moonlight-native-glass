# MoonlightLG 1.2.0.1U title-bar mouse restoration

Checkpoint: `checkpoints/moonlightlg-1.2.0.0U-before-mouse-fix` at `165d09474d3145a2dd32d76484c0a3fbd731c6de`.

User confirmed cursor escape after the Statistics title-bar button; computer-name Control Center works correctly.

All title-bar tracking now requests a session/window-scoped input repair after AppKit finishes. Synthetic mouse-up is retained so SDL clears its focus-click bookkeeping. Deferred repair waits for button release, does not run behind an open popup, and runs on popup dismissal, overflow dismissal, window move and end resize. The production input handler reuses Control Center's release/restore-focus/recapture sequence. It honors intentional release, absolute desktop mode, hidden windows, native menus, disconnect sheets and existing local controls. The mouse portion leaves decoder/pacing/network algorithms unchanged. The same hotfix adds on-demand recording keyframe recovery through the existing common-c API; common-c source is unchanged. Tracking monitors and timers are removed at detach; queued actions are flushed and validated against the original window ID.

Tests exercise actual AppKit clicks for Statistics, Record and Replay, relative routing, saved capture intent, intentional release, absolute mode, popup dismissal, window move, and preservation of Control Center. Existing full-screen/disconnect/shutdown and recording tests remain required. Physical host/Intel testing is still required; CI cross-builds Intel on Apple Silicon.

Validated production source: `0850af3fcdaf172fed3f538e3b80451522bbeab8`.

- [Full native validation](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38343787230): complete Intel/Universal packages; actual SDL connection-window centering, fullscreen Metal presentation, title-bar/drag/focus/control restoration, ASan/UBSan window lifetime, engine bridge/persistence and 200 immediate shutdown cycles passed. Each delivered bundle audited 107 Mach-O files. UI smoke suite: 12 tests, zero failures.
- [Full Xcode](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38343787235): fresh/incremental complete apps, embedded engine, source-ZIP setup and 12 UI tests passed.
- [Title-bar/drag and teardown sanitizers](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38343787234): passed with real SDL moving state, native mouse-up, relative routing, button tracking, popup/overflow dismissal, explicit release, desktop absolute mode and Control Center preservation. Leak detection was not enabled.
- [Recorder functional + sanitizers](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38343019797): ABI 3 waiting/timeout state, bounded keyframe request policy, H.264 copy with AAC/Opus loss handling, replay, stop/restart and custom resized HEVC passed. Tested recording/adapter source is unchanged in the final production commit.
- [Stock platform builds](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38343787525): macOS, Windows, AppImage and Steam Link passed.
- Downloaded app ZIPs independently verified as 1.2.0.1U/build 35, correct CPU slices and recorder export, without test/sanitizer fixtures. SHA-256: Intel `87f85b3ad6389f9548ab399bab3d82a02ab8c341eeed10e54e9df2549fe96f34`; Universal `44919cf2cca0e5e6c7779bd43105656a9290e67d01846a49986fd35c2ae6cbd4`.

No public U release or app download links were posted. Physical Intel/host keyframe responses, latency/frame time, HDR/surround and live mouse behavior still need owner acceptance.

The same hotfix centers the complete native window frame after the stream size is applied on Continue. Size selection uses the existing connection window display. Fullscreen enters on that display, and maximized/minimized states are preserved. Actual SDL connection-window tests cover landscape/portrait size changes and retained window/content identity.

Drag root cause: SDL's native window checks that its delegate is an SDL listener before forwarding mouse-up to clear its moving state. The MoonlightLG wrapper forwarded selectors but not listener class identity. The proxy now forwards isKindOfClass identity as well, allowing SDL's own drag-end implementation to run. Tests enter SDL's real moving state using the native notification, send mouse-up through NSApp, assert moving clears and verify relative motion routing.
