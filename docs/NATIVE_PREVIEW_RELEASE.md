**Native UI Preview 3 — resolution dropdown and crescent icon**

- Resolution is now a native dropdown: 720p, 1080p, 1440p, 4K and Native, with detected dimensions. Native uses the monitor containing Settings and stock Moonlight's native-mode detection. Saved custom dimensions remain visible; display changes do not silently overwrite settings.
- Resolution width and height save together through the existing engine preferences, preserving automatic bitrate adjustment and restart persistence.
- New blue glass crescent icon for the native frontend, including the About panel.
- About version reads “Native UI Preview 3 - Moonlight 6.2”. Creator/maintainer credit and GitHub hyperlink remain fixed; future builds increment the preview number.
- Includes Preview 2's background-helper Dock icon and pairing status refresh fixes.

Experimental SwiftUI/AppKit frontend for the Moonlight Qt 6.2.0 engine.

Native sidebar, toolbar, game cards, five Settings panes, pairing/address/details sheets and system light/dark appearance. Uses native Liquid Glass controls on macOS 26+ and regular native controls on macOS 15. The frontend uses its new crescent icon, SF Symbols and host-provided box art. Updates remain manual.

The bundled Qt helper keeps the upstream streaming, networking, settings, common-c and mDNS implementations unchanged. Each stream uses the original Session/SDL video window. Preferences and pairing are isolated from stock Moonlight and Enhanced; pair again in this app.

Built source: `904f5d127cd1e57629ca21d7b972be07719149a9`. [All required validation jobs passed](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/37670613344).

Validation: full x86_64 and Universal compilation; nested architectures, signatures and dependencies; unchanged engine source; event framing; real adapter validation and resolution persistence across restart. 16 Release-mode XCTest UI captures passed, including resolution dropdown interaction, the About panel and accessible GitHub link; composited sample-content screenshots were inspected. Included captures are labeled design previews. They do not demonstrate host connectivity.

These packages require macOS 15+. They are ad-hoc signed, not Developer ID signed or notarized. Physical Intel/Tahoe validation of this revision remains outstanding: discovery, Local Network approval, pairing, streaming, controller input, multi-display behavior and CPU/GPU/frame pacing. No performance improvement or parity is claimed. Enhanced-only microphone, clipboard and AWDL features are not included.

Intel Tahoe test checklist:
- Launch from Finder, allow Local Network access, discover/add and pair a host; verify paired status and games appear without reopening, then quit/relaunch to check persistence. Confirm no windowless helper Dock icon.
- Compare the same 1080p60 H.264 and HEVC sessions against stock 6.2.0; verify hardware decode, audio, mouse, keyboard and controller.
- Launch/resume/quit games and disconnect with Control–Option–Shift–Q or Start + Select + L1 + R1.
- Select each resolution preset and Native; confirm Retina/native dimensions and save/relaunch persistence. Move Settings between displays and verify Native dimensions refresh.
- Resize, enter/exit fullscreen and switch displays; check focus and settings persistence.
- Check light/dark mode, Reduce Transparency, Reduce Motion, increased contrast and VoiceOver.
- Compare decode time, frame pacing, CPU/GPU and stock performance-overlay results on identical hardware/settings. Save crash reports and engine logs for failures.

The release tag includes the publishing workflow and documentation added after validation. The publisher verifies that all build inputs match the tested source commit.
