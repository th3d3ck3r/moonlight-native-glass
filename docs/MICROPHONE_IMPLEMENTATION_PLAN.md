# Microphone implementation plan

Status: planning only. Implementation and a build require separate authorization.

## Goal

Add opt-in native Mac microphone forwarding to the user's compatible Vibepollo host, plus an optional local microphone test and live input-level bar inside Audio settings. Match the existing Liquid Glass UI and preserve Moonlight 6.2 streaming behavior.

## Controls

| Control | Behavior |
| --- | --- |
| Enable Microphone | Enables forwarding while streaming; off by default |
| Input Device | System Default, built-in microphone and available external inputs |
| Test Microphone / Stop Test | Starts/stops a local test without pairing or a host connection |
| Input-level bar | Appears during testing; live level, peak hold and clipping indication |
| Mute Microphone | Available during streaming and through the menu bar |

Testing must not transmit, record or play back the user's voice. Stop the test on Stop Test, leaving the Audio pane or closing Settings. Ending a test must not stop forwarding an enabled microphone during a stream.

## Verified reference and baseline

- Application build source: `f2531af7983233ec3e67ff908fb288e87f3f8338` (Native UI Preview 6).
- Current common-c pin: `f900dd4767759c7b9d0e93bcea666b55c69ea62f`. It lacks the sender used by Vibelight.
- Reference code: [Vibepollo receiver](https://github.com/xenstalker02/Vibepollo/blob/master/src/stream.cpp), [Vibelight microphone client](https://github.com/xenstalker02/Vibelight/blob/master/app/streaming/audio/miccapture.cpp), [matching common-c sender](https://github.com/xenstalker02/moonlight-common-c/blob/master/src/ControlStream.c).
- Reviewed tree SHAs: Vibepollo `65167cf6479237ab5d7980d77c008d366adc07f5`; Vibelight `7de61a9dc1dc86c63cc10ddaee74d0e03481646d`. Resolve/pin exact source commits before porting.
- Protocol: `0x3003` on the AES-GCM encrypted control connection (`SS_ENC_CONTROL_V2`).
- Four-byte microphone header: sequence high byte, sequence low byte, channels=1, flags=0; followed by Opus.
- Initial format: 48 kHz mono, 20 ms/960-sample frames, 64 kbps.
- Reviewed client limits Opus to 248 bytes, giving a 252-byte payload including the microphone header. Recheck bounds against the pinned engine before integration.
- Vibelight targets Steam Deck. Reuse reviewed protocol logic, not its platform-specific capture implementation.
- Confirm the installed Vibepollo revision matches this protocol before integration. No host modification is planned.

## 1. Isolated transport extension

- [ ] Review reuse licensing and attribution.
- [ ] Port only the necessary microphone transport into our pinned engine; do not replace common-c wholesale.
- [ ] Validate connection state, negotiated encryption, lengths and sequence handling before sending.
- [ ] Surface actual microphone state/errors to the native frontend.
- [ ] Keep engine/transport changes separate from UI commits. Work on this repository's native-ui branch; leave master and existing releases intact.

## 2. Native capture service

- [ ] Implement capture inside the engine helper using Core Audio, with stable device identifiers and System Default tracking.
- [ ] Request permission asynchronously only after the user explicitly enables forwarding or starts a test.
- [ ] Add microphone usage descriptions and physically verify permission attribution for the packaged frontend/nested helper. Do not assume one process's permission covers the other.
- [ ] Convert supported device formats to 48 kHz mono.
- [ ] Share one capture service between local testing and forwarding; never open duplicate capture sessions.
- [ ] Show a clear error for an unavailable selected device instead of silently activating another microphone.
- [ ] Treat microphone failure as nonfatal to video/game audio.

Apple references: [Mac capture authorization](https://developer.apple.com/documentation/bundleresources/requesting-authorization-for-media-capture-on-macos), [microphone usage description](https://developer.apple.com/documentation/bundleresources/information-property-list/nsmicrophoneusagedescription), [Core Audio device selection](https://developer.apple.com/documentation/audiotoolbox/kaudiooutputunitproperty_currentdevice).

## 3. Encoder and sending worker

- [ ] Encode 20 ms Opus frames on a dedicated worker, initially fixed at 64 kbps.
- [ ] Use preallocated bounded buffers; drop stale data rather than accumulate latency.
- [ ] Keep allocation, encoding, blocking locks, logging and network waits out of the real-time capture callback.
- [ ] Validate VBR, FEC, silence behavior and encoder complexity against host behavior and Intel CPU measurements.
- [ ] Stop capture and join the sending worker before tearing down the encoder or connection.

## 4. Optional local input test

- [ ] Work without a host or pairing.
- [ ] Compute RMS input level and peaks, and throttle frontend meter updates to a modest rate.
- [ ] Include peak hold and clipping indication without excessive animation.
- [ ] Distinguish Listening, No Input Detected, Device Unavailable and Permission Required.
- [ ] Do not report silence as proof of a broken microphone.
- [ ] Send only level/state metadata through the JSON bridge; keep raw audio within the capture/encoder process.
- [ ] Track local-test and stream ownership independently. Stop test ownership on Stop Test, pane exit and Settings close while preserving enabled forwarding.

## 5. Native UI and persistence

- [ ] Place controls within the existing Audio settings pane.
- [ ] Match existing rows, system typography, spacing, native buttons/dropdowns, SF Symbols and accent color.
- [ ] Make testing optional with a Test Microphone button that reveals the input bar.
- [ ] Add stream mute/unmute and menu bar access when the stream window is hidden.
- [ ] Persist only necessary preferences: enabled state and selected input identifier. Preserve all existing keys/defaults.
- [ ] Provide accessible level text without announcing every meter update.
- [ ] Respect light/dark appearance, Reduce Motion, Reduce Transparency and increased contrast.
- [ ] Preserve keyboard/controller focus. Avoid duplicate controls and unnecessary bitrate settings.

## 6. Session, mute and cleanup correctness

- [ ] Forward only after the encrypted stream connects, not simply when a stream window exists.
- [ ] Hiding/minimizing the stream window preserves microphone/mute choices.
- [ ] Disconnect/Quit stops capture and sends cleanly.
- [ ] Flush queued speech on mute, device changes and session transitions.
- [ ] Test a compatible silence strategy: muted output must not replay buffered speech or produce audible host packet-loss concealment.
- [ ] Handle permission denial/revocation, unplugging, default-device changes, helper failure, reconnects and rapid toggles.
- [ ] Preserve the video surface, decoding/rendering architecture, input capture, bundle identities, manual updates and existing menu bar behavior.

## 7. Validation and delivery

- [ ] Test packet framing, limits, invalid input, encryption refusal and sequence wraparound.
- [ ] Test start/stop races, bounded queues, mute, repeated reconnects and teardown ordering.
- [ ] Check new preferences, bridge commands/events and settings persistence.
- [ ] Run existing regression checks and full x86_64/Universal builds.
- [ ] Audit project/resource references, permission configuration and packaged signing.
- [ ] Inspect settings/meter in light/dark, compact layouts, keyboard focus and accessibility.
- [ ] Physically test built-in, USB and Bluetooth inputs, permission prompts/denial and device switching on an Intel Mac.
- [ ] Verify voice reaches Windows applications through Vibepollo and mute remains silent.
- [ ] Compare CPU use, audio latency, game-audio behavior and frame pacing with mic off/on, visible meter and hidden stream window.
- [ ] Do not claim Intel runtime performance or end-to-end microphone support from compilation alone.
- [ ] Publish a separate preview only after checks pass and implementation/build are authorized.
- [ ] Preserve fixed About wording and increment only the build number. No unrelated README/release documentation without instruction.

## Completion criteria

The user can select an input, optionally test it locally using a responsive native level bar, securely forward it to Vibepollo and mute it reliably. Permission/device/microphone failures must not crash the app or interrupt video. Existing stream-window and menu bar behavior remains intact.
