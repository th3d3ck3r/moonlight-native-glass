Experimental SwiftUI/AppKit frontend for the Moonlight Qt 6.2.0 engine.

Native sidebar, toolbar, game cards, five Settings panes, pairing/address/details sheets and system light/dark appearance. Uses native Liquid Glass controls on macOS 26+ and regular native controls on macOS 15. Moonlight icon, SF Symbols and host-provided box art are reused. Updates remain manual.

The bundled Qt helper keeps the upstream streaming, networking, settings, common-c and mDNS implementations unchanged. Each stream uses the original Session/SDL video window. Preferences and pairing are isolated from stock Moonlight and Enhanced; pair again in this app.

Validated source: `d746f2adf461e0dced2ef49e8c15c6e91642a198`. [All required validation jobs passed](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/37589657439).

Validation: full x86_64 and Universal compilation; nested architectures, signatures and dependencies; unchanged engine source; event framing; real adapter validation and preference persistence. 15 Release-mode XCTest UI captures passed; composited sample-content screenshots were inspected. Included captures are labeled design previews. They do not demonstrate host connectivity.

These packages require macOS 15+. They are ad-hoc signed, not Developer ID signed or notarized. Physical Intel/Tahoe discovery, Local Network approval, pairing, streaming, controller input, multi-display behavior and CPU/GPU/frame pacing remain unverified. No performance improvement or parity is claimed. Enhanced-only microphone, clipboard and AWDL features are not included.

Intel Tahoe test checklist:
- Launch from Finder, allow Local Network access, discover/add and pair a host; quit/relaunch to check persistence.
- Compare the same 1080p60 H.264 and HEVC sessions against stock 6.2.0; verify hardware decode, audio, mouse, keyboard and controller.
- Launch/resume/quit games and disconnect with Control–Option–Shift–Q or Start + Select + L1 + R1.
- Resize, enter/exit fullscreen and switch displays; check focus and settings persistence.
- Check light/dark mode, Reduce Transparency, Reduce Motion, increased contrast and VoiceOver.
- Compare decode time, frame pacing, CPU/GPU and stock performance-overlay results on identical hardware/settings. Save crash reports and engine logs for failures.
