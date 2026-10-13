# MoonlightLG 1.2.2.0U title audio, native fullscreen and faster Apollo flight

Owner acceptance of 1.2.1.0U: capture-driven hiding works well. Follow-ups:
green-button fullscreen reveals overlapping native chrome on input release;
Apollo stars need faster travel; add playback audio control without changing
recorded audio and preserve the existing button mouse boundary.

The fullscreen adapter now identifies native title-only chrome through public
view hierarchy and suppresses it behind the released stream command overlay.
Windowed traffic lights and the existing capture-driven row are restored on exit.
No decoder, SDL window identity, networking or drawable sizing algorithm changes.

Mute reuses session action 207. The title indicator is synchronized with the
existing menu state publisher, and the icon/tooltip/accessibility value explain
playback state. Narrow windows expose the same action in overflow. Its button is
the same MLStreamToolbarButton used by Statistics/Record/Replay, including tracked
mouse-up and scoped action 220 restoration. Intentional release remains honored.

The complete production audio callback is compiled into AudioMuteTests with only
device/Opus/recorder sinks replaced. It verifies that source packets, including
loss markers, reach recording across local mute/unmute and playback drop windows.
The actual recorder's audio mux/decoding remains covered by RecorderTests. The
production audio callback, recording adapter and recorder plugin are unchanged.

Apollo star travel increases from 28 points/s to 420 times the existing field
scale per second, retaining the same 150 deterministic stars, arrival brake,
30 Hz Canvas and Reduce Motion behavior. Ship/connection timing is unchanged.

Checkpoint: `checkpoints/moonlightlg-1.2.1.0U-before-title-audio` at
`cdd28ab50ab8a95de25e4e8f74fda17813c36f36`. Internal build 38.

Validated app/test head: `e265aa82d6aef69f6b1a0ab54c601b86b8bae058`.

- [Full native macOS validation](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38372308222): complete Intel/Universal packages, 107 Mach-O files each, permissions/identity/signatures/dependencies, production audio callback mute boundary, recorded-file audio decoding, Apollo/window identity, all fullscreen modes and native green-button entry/hover passed. Normal and ASan/UBSan mouse/window suites passed, including actual Mute tracking, saved capture intent, deliberate release, absolute mode, popover/overflow/drag and shutdown. Leak detection was disabled. UI suite: 12 tests, zero failures. Packaged bridge/persistence and 200 shutdown cycles passed.
- [Full Xcode validation](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38372308248): fresh/incremental complete app, real engine, source-ZIP setup, startup preview and 12 UI tests passed.
- [Standalone native/sanitizer regression](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38372308253) passed.
- [Stock platform builds](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38372308468): Windows, macOS, AppImage and Steam Link passed.
- A prior unsanitized fixture stalled in AppKit's green-widget hover tiling menu, confirmed by its process sample. The general fixture now parks a leftover cursor in content and sends AppKit motion, while preserving relative-motion routing. The separate explicit native-green/fullscreen/top-hover coverage is unchanged and passes. No production change was made for this test-environment issue.
- Composited native-green and windowed captures inspected: one title row, speaker glyph and retained control layout.
- Downloaded packages verified as 1.2.2.0U/build 38, with correct app/engine/recorder CPU slices and matching ZIP checksums. Intel SHA-256 `1be5fec160d9196cead07d9b774e2a406290c1a2cbfb889b6c7eb6dd43fa18c1`; Universal SHA-256 `d20fb53da0d4489daa40c02563925943cba7732739b7995b620e86c8d00ef5d7`.

No public U release or app download links were posted. Physical Intel visual,
gameplay, confinement and recording acceptance remains an owner check; CI runs on
Apple Silicon and cross-builds Intel. Decoder, audio/recording source and timing
algorithms remain unchanged.
