**Native UI Preview 4 — menu bar access and matching engine icon**

- The bundled streaming engine now uses the same blue glass crescent icon as the native frontend. Both bundle icon resources are checked for equality before release.
- Native crescent menu bar icon keeps the app available after closing the library. Open Moonlight, Settings and Quit actions use normal macOS window behavior and existing stream cleanup.
- Build number incremented to 4. About automatically reads “Native UI Preview 4 - Moonlight 6.2”; all other About wording and the GitHub link remain fixed.
- Streaming, settings and resolution behavior are unchanged from Preview 3. Includes its resolution dropdown and previous pairing/Dock fixes.

Experimental SwiftUI/AppKit frontend for the Moonlight Qt 6.2.0 engine.

Native sidebar, toolbar, game cards, five Settings panes, pairing/address/details sheets and system light/dark appearance. Uses native Liquid Glass controls on macOS 26+ and regular native controls on macOS 15. The frontend uses its new crescent icon, SF Symbols and host-provided box art. Updates remain manual.

The bundled Qt helper keeps the upstream streaming, networking, settings, common-c and mDNS implementations unchanged. Each stream uses the original Session/SDL video window. Preferences and pairing are isolated from stock Moonlight and Enhanced; pair again in this app.

Built source: `007bbc594bacb768e1abcc31478c7d95e94ba4de`. [All required validation jobs passed](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/37682529752).

Validation: full x86_64 and Universal compilation; nested architectures, signatures, dependencies and matching frontend/engine icons; unchanged engine source; event framing; real adapter validation and resolution persistence across restart. 17 Release-mode XCTest UI captures passed, including close/reopen/Settings/Quit menu bar actions and resolution dropdown interaction, the About panel and accessible GitHub link; composited sample-content screenshots were inspected. Included captures are labeled design previews. They do not demonstrate host connectivity.

These packages require macOS 15+. They are ad-hoc signed, not Developer ID signed or notarized. Physical Intel/Tahoe validation of this revision remains outstanding: discovery, Local Network approval, pairing, streaming, controller input, multi-display behavior and CPU/GPU/frame pacing. No performance improvement or parity is claimed. Enhanced-only microphone, clipboard and AWDL features are not included.

Intel Tahoe test checklist:
- Launch from Finder, allow Local Network access, discover/add and pair a host; verify paired status and games appear without reopening, then quit/relaunch to check persistence. Confirm no windowless helper Dock icon.
- Compare the same 1080p60 H.264 and HEVC sessions against stock 6.2.0; verify hardware decode, audio, mouse, keyboard and controller.
- Launch/resume/quit games and disconnect with Control–Option–Shift–Q or Start + Select + L1 + R1.
- Select each resolution preset and Native; confirm Retina/native dimensions and save/relaunch persistence. Move Settings between displays and verify Native dimensions refresh.
- Close the library and reopen it from the crescent menu bar icon; open Settings and quit. Check closing the library during streaming leaves the stream connected, and Quit retains confirmation.
- Resize, enter/exit fullscreen and switch displays; check focus and settings persistence.
- Check light/dark mode, Reduce Transparency, Reduce Motion, increased contrast and VoiceOver.
- Compare decode time, frame pacing, CPU/GPU and stock performance-overlay results on identical hardware/settings. Save crash reports and engine logs for failures.

The release tag includes the publishing workflow and documentation added after validation. The publisher verifies that all build inputs match the tested source commit.
