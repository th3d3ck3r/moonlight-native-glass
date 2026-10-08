**Native UI Preview 5 — separate stream-window menu bar build**

This is a separate download; Preview 4 and its release remain available.

- Closing an already opened **windowed** stream hides the original SDL window instead of disconnecting. Click the crescent status icon to restore the same window.
- The icon chooses the stream only after its window has actually opened, independently of connection/stream-active flags. While connecting with no stream window, or after the window has ended, it opens the regular app.
- Right-click (or Control-click) the icon for Open Moonlight or Stream, Settings and Quit. Explicit Quit retains the existing streaming confirmation and cleanup. Disconnect shortcuts remain unchanged.
- Build number 5; all other About wording, credit, GitHub link, icon assets, settings, permissions, bundle identities and signing behavior stay fixed.

The macOS presentation adapter forwards the existing SDL Cocoa window delegate. Only windowed close is intercepted. Normal fullscreen behavior, SDL window destruction, focus/input callbacks and resize handling remain with SDL. Restore uses a per-process-launch token and the native main run loop while Session suspends Qt processing. No per-frame UI polling is added. The upstream streaming/backend/settings/common-c/mDNS source remains unchanged.

Built source: `e96caef79fde987b495f9a62c245215e28f29057`. [Required validation](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/37692872366): full x86_64 and Universal builds; nested architecture/signature/dependency/icon audits; protocol framing; actual helper persistence; native UI captures ([UI validation revision `6e88eed`](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/37693779148)); real SDL window lifecycle harness. The harness checks close/hide without session-quit events, repeated cross-process restore/focus with no Qt loop, wrong-token isolation, resize forwarding and absent/destroyed-window safety. It does **not** connect to a host or decode video. Captures use sample content.

Requires macOS 15+. Native Liquid Glass controls on macOS 26+, standard native controls on macOS 15; system light/dark appearance. Manual updates. Ad-hoc signed, not Developer ID signed or notarized. The bundled stock Moonlight Qt 6.2.0 engine remains responsible for streaming. Enhanced-only microphone, clipboard and AWDL features are not included.

Physical Intel Tahoe checklist:
- Before opening a stream window, close the library and click the crescent; confirm the regular app opens, including while connection startup has not created a window.
- Open a windowed stream, click its red close button, then click the crescent. Confirm the same session resumes visibly without relaunching the host game. Repeat and verify audio, keyboard, mouse/controller input and focus.
- Disconnect normally; click the icon again and confirm it returns to the regular app. Test right-click Settings, Quit and Cancel while a stream window is hidden.
- Test fullscreen transitions, minimize/restore, moving between displays, resizing and host/network failure while hidden.
- Check pairing/settings persistence, H.264/HEVC hardware decode, optional HDR, light/dark appearance and accessibility.
- Compare CPU/GPU, decode time and frame pacing against stock 6.2.0 on identical hardware/settings; no Intel runtime/performance claim is made from compilation or window tests.

The release tag includes documentation/workflow changes after validation; the publisher verifies that the UI validation revision changes only tests/docs and that all packaged build inputs still match the full-build source.
