# 🌙 Touch Bar · private 1.3.3.0U

The native app and embedded stream window each own a native AppKit Touch Bar.
No global keyboard extension, private API or system Control Strip replacement is used.
The public 1.3.2.0 release stays available. Build 43 is an owner-only U build.

## Layout

| Context | Main controls |
|---|---|
| Startup | MoonlightLG status and Skip to Library |
| Library | Host/status/game count, previous/next host, Refresh, selected-game Play or Pair/Wake, Add, Settings |
| Apollo | Host and connection detail, Continue, Retry, Cancel/Library; availability follows real connection state |
| Stream | Live status, Capture/Release, Audio percentage/mute state, Record/time, Replay readiness, More |

Stream status expands into four selectable pages:

- **Stream:** incoming FPS, network round-trip latency and bitrate from the engine's Statistics output.
- **Decode:** decoding time, network drops and rendering FPS from the same measured output.
- **Mac:** local CPU, memory and optional driver-reported GPU load, with up to 60 one-second samples. These are client measurements, not host measurements.
- **Devices:** local Ethernet/Wi-Fi throughput, thermal pressure and controller count/battery category. No unsupported temperature or exact controller battery percentage is invented.

Audio expands into local playback mute, volume slider and percentage. The recorder's source audio is unchanged.
More expands into Statistics, the hardware overlay, fullscreen, controls, hide and disconnect.
Every expanded page has AppKit's native close/back control. The system Control Strip and physical Escape key retain their normal roles.

Crimson SF Symbols, near-black surfaces, monospaced numeric values and restrained active fills match Crimson Glass. Active capture and recording use stronger fills plus distinct labels/glyphs. No blinking effects are used.
The default stream controls require about 524 points; expanded layouts stay below the standard 685-point app region.
Labels with host/game names truncate while accessibility descriptions preserve their full text.

## State, overhead and input

Touch Bar streaming actions enqueue the existing SDL action codes, including the recording plugin actions. They do not call mouse confinement, decoder, networking or frame-pacing code directly.
Volume uses the existing atomic playback gain and preference key.
Recorder/replay controls use the existing availability, duration, readiness and saving states; duplicate replay saves are disabled.

Statistics are available when the stream Statistics feature is enabled. Disabling it discards old values; measurements older than four seconds are labeled unavailable/stale.
Local hardware sampling runs at most once per second off the main thread while the stream window is visible, key and the app is active. No overlapping sampler jobs or per-video-frame Touch Bar work are scheduled.
Detaching stops the sampler timer, clears targets, dismisses expanded bars and restores the previous window bar. A late sample cannot update a later session.

## Validation

`TouchBarTests.mm` exercises actual AppKit items and SDL actions without requiring physical Touch Bar hardware. It checks disabled actions, capture/fullscreen/mute/record/replay routes, recording state, stale statistics, main/expanded width budgets, responder restoration and repeated cleanup. It exports the actual item views as labeled fixture PNGs for layout review.
These view previews are layout evidence, not screenshots of the physical Touch Bar renderer. Existing window/fullscreen/Metal and sanitizer tests remain enabled.
Physical Touch Bar touch/hold behavior on an M1 MacBook Pro remains a hardware acceptance limit of CI.

The complete corresponding source archive is uploaded alongside the owner-only arm64 app artifact. About retains the offline legal notices and points private builds to the validation artifacts for their matching source archive.
