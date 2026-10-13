# MoonlightLG 1.2.1.0U capture-driven title controls

Reference: the owner's QuickTime recording, October 13, 2026. Title controls overlay
the video; captured streaming hides them, and intentional input release shows them.
There is no hover-to-reveal target while capture is active. Existing keyboard and
menu action routes remain unchanged, including Control Center, statistics,
recording/replay, release/capture and disconnect.

Windowed presentation installs AppKit full-size content once, retaining the same
SDL content view and window frame. The thin title accessory and traffic lights
are hidden during capture; the decorative glass fades over 160 ms (zero with
Reduce Motion). Hidden buttons and native title-area dragging are disabled
immediately. Showing/hiding does not toggle window style or video geometry.
Fullscreen/borderless presentation uses the same stream command row as a top
overlay on release, without a native title row or geometry change.

Focus loss, title popovers, overflow menus and attached sheets keep local controls
accessible. Capture ownership is still decided by the existing input handler;
visibility never activates or releases host capture. The existing mouse-up,
popup/menu dismissal and drag repair routes are retained. Focus observers and
animation completions are scoped to the attached owner; detach removes the
overlay, restores windowed style/movement and invalidates stale hide completions.

Checkpoint: `checkpoints/moonlightlg-1.2.0.2U-before-autohide`, source
`a17ad5f0bc78c272958eac2a62f022319673eecb`. Internal build 37.

Coverage: actual AppKit/SDL control tracking and relative motion; intentional
release; absolute mouse mode; popover/overflow dismissal; real SDL drag state;
all presentation modes; hidden key routing; invariant window/video/Metal drawable
geometry; quick release after a hide begins; teardown/style restoration; composited
hidden/released screenshots. Streaming-core hashes remain unchanged.

Validated app/test/CI head: `faeb3a0e92b2946dfd5c2483c2c09aa3fddc398a`.

- [Full native validation](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38358470454): complete Intel/Universal packages audited 107 Mach-O files each; actual SDL/Apollo, windowed/fullscreen/borderless Metal presentation, mouse capture, native hit targets, key routing, controls/popovers/overflow, dragging, geometry and lifecycle checks passed. Normal and ASan/UBSan window suites passed; leak detection was disabled. UI suite: 12 tests, zero failures. Packaged engine/bridge/persistence and shutdown checks passed.
- [Full Xcode validation](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38357020387) at app/test source `23df07d5c78d62b1635791d1baba408d48a14d56`: fresh/incremental full app, embedded engine, source-ZIP setup and 12 UI tests passed. Subsequent changes only bound the independent native CI fixture's runtime; app/Xcode source is unchanged.
- [Shutdown and title input sanitizers](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38357020330) passed, including composited hidden/released previews and both Metal fullscreen modes.
- [Stock platform builds](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38358470561): Windows, macOS, AppImage and Steam Link passed.
- An earlier unsanitized fixture stalled. The final bounded retry passed without timing out, as did the full sanitizer fixture. The CI wrapper samples a future stalled fixture before terminating it; it is absent from delivered apps.
- Downloaded app ZIPs verified as 1.2.1.0U/build 37, with the correct app/engine/recorder CPU slices and matching packaged checksums. Intel SHA-256 `d6e9716135056916eb2041d8a4135145f4819aaf2650d1ca8abf22a3a7841870`; Universal SHA-256 `fa7816b9143426435ac183970b7352bc631e98410886d05ae4983f4eef8ab68c`.

No public U release or app download links were posted. CI runs on Apple Silicon and
cross-builds Intel; physical Intel gameplay, visual acceptance, host confinement
and sustained recording remain owner checks. CI does not establish physical-host
latency or frame-time performance.
