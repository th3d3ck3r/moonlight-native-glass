# 🌙 Touch Bar · private 1.3.4.0U

The native app and embedded stream window each own a native AppKit Touch Bar.
The default layout uses public AppKit controls and preserves the system Control Strip. Optional full width uses runtime-checked undocumented AppKit presentation selectors while the owning window is active.
The public 1.3.2.0 release stays available. Build 43 (1.3.3.0U) was delivered first; build 44 adds live measurements directly to the main bar. Both are owner-only U builds.

## Layout

| Context | Main controls |
|---|---|
| Startup | MoonlightLG status and Skip to Library |
| Library | Host/status/game count, previous/next host, Refresh, selected-game Play or Pair/Wake, Add, Settings |
| Apollo | Host and connection detail, Continue, Retry, Cancel/Library; availability follows real connection state |
| Stream — live stats | Capture/Release, persistent FPS/RTT/bitrate cards, Controls (recording time while active) |
| Stream — original controls | Live status, Capture/Release, Audio percentage/mute state, Record/time, Replay readiness, More |

Stream status expands into one resizable information panel with previous/next arrows, a page label and measurements. The pager wraps through six pages without a segmented control competing for space:

- **Live:** incoming FPS, network round-trip latency and bitrate from the engine's Statistics output.
- **Video:** video resolution/rate, codec and host-processing latency.
- **Time:** decoding, frame queue and rendering delays.
- **Drops:** network drops, jitter drops and rendering FPS.
- **Mac:** local CPU, memory and optional driver-reported GPU load, with up to 60 one-second samples. These are client measurements, not host measurements.
- **I/O:** local Ethernet/Wi-Fi throughput, thermal pressure and controller count/battery category. No unsupported temperature or exact controller battery percentage is invented.

The live layout grows from three to six or eight metric cards as macOS supplies more horizontal room. The wider layouts add decode time, drops and local Mac CPU/RAM/GPU. Tap the cards for the six detailed information pages. Controls contains Audio, recording/replay, the separate Statistics toggle, Window actions and disconnect.

Audio expands into local playback mute, volume slider and percentage. The recorder's source audio is unchanged.
More expands into Statistics, the hardware overlay, fullscreen, controls, hide and disconnect.
Every expanded page has AppKit's native close/back control. The default layout keeps the system Control Strip and physical Escape behavior. Expanded layouts reserve an additional 64 points for the native close/back control. No system brightness, system volume or Fn preference entries are changed.

Crimson SF Symbols, near-black surfaces, monospaced numeric values and restrained active fills match Crimson Glass. Active capture and recording use stronger fills plus distinct labels/glyphs. No blinking effects are used.
The live stream layout requires about 544 points; the original controls layout requires about 534 points. Expanded layouts fit the standard 685-point app region and reserve the native Back button. The information view and standard audio slider grow with the space macOS makes available, including a full-width app region when the system Control Strip is hidden by the user’s own macOS settings. The optional **Settings → Appearance → Touch Bar → Use full Touch Bar** setting is off by default.
Library, Settings, startup and Apollo group their controls into one item. The host/status tile stays pinned; remaining actions scroll horizontally when needed, with a visible More arrow that advances and returns to the start. Short labels and bounded 30-point drawing avoid native cell substitutions. Unusually long dynamic names may truncate while accessibility descriptions preserve their full text. No command or keyboard shortcut is removed.

## Optional full width

The full-width toggle is off by default. The preference-only approach in build 43 did not reliably hide the owner's physical Control Strip. Build 44 instead resolves AppKit's undocumented `presentSystemModalTouchBar:placement:systemTrayItemIdentifier:` and `dismissSystemModalTouchBar:` selectors at runtime. Placement 1 requests the full app region. There is no public API for app-controlled Control Strip visibility.

The frontend and engine-hosted Apollo both read the frontend preference suite and receive distributed changes. Presentation state changes before AppKit show/hide calls, protecting against reentrant notifications. Unsupported saved ON is cleared.

Presentation is owned only while the corresponding MoonlightLG library, settings, Apollo or stream window is visible, key and active. It is dismissed on focus loss, app deactivation, window close, detach or disabling the setting. Repeated refreshes do not continually steal the bar back. Missing selectors leave the standard bar available and enabling the setting reports unavailable. No DFR private framework is loaded, no system process is restarted, and no global/Fn/other-app preferences are changed. System close/back controls remain available.

The build restores its own two legacy `PresentationModePerApp` entries from build 43's saved backup, preserving later manual edits. New presentation does not write that domain. Preference migration tests inject disposable suites; presentation lifecycle tests inject fake show/hide callbacks instead of taking over the runner's bar. Preview mode does not present full width. Physical Touch Bar acceptance is still required because CI cannot verify the actual Control Strip or touch renderer.

## State, overhead and input

Touch Bar streaming actions enqueue the existing SDL action codes, including the recording plugin actions. They do not call mouse confinement, decoder, networking or frame-pacing code directly.
Volume uses the existing atomic playback gain and preference key.
Recorder/replay controls use the existing availability, duration, readiness and saving states; duplicate replay saves are disabled.

Touch Bar statistics do not require the on-screen Statistics window. The existing decoder statistics formatting runs at its original one-second cadence and publishes to the Touch Bar without requesting an overlay surface or changing visibility. Window statistics remain an independent, explicit action. Measurements older than four seconds are labeled unavailable/stale; detach clears the subscription and its readings.
Local hardware sampling runs at most once per second off the main thread while the stream window is visible, key and the app is active. No overlapping sampler jobs or per-video-frame Touch Bar work are scheduled.
Detaching stops the sampler timer, clears targets, dismisses expanded bars and restores the previous window bar. A late sample cannot update a later session.

## Validation

`TouchBarTests.mm` exercises actual AppKit items and SDL actions without requiring physical Touch Bar hardware. It checks disabled actions, capture/fullscreen/mute/record/replay routes, recording state, stale statistics, main/expanded width budgets, responder restoration and repeated cleanup. It exports the actual item views as labeled fixture PNGs for layout review.
These view previews are layout evidence, not screenshots of the physical Touch Bar renderer. Existing window/fullscreen/Metal and sanitizer tests remain enabled.
Physical Touch Bar touch/hold behavior on an M1 MacBook Pro remains a hardware acceptance limit of CI.

The complete corresponding source archive is uploaded alongside the owner-only arm64 app artifact. About retains the offline legal notices and points private builds to the validation artifacts for their matching source archive.

Physical-bar photos from the owner revealed that standard NSButtonCell rendering substituted larger metrics than ordinary-window previews. Native buttons now draw their own fixed-size symbols/text within 30 points while keeping target/action and accessibility semantics. Two-line host status uses separate bounded line rectangles; static action labels are checked against the real drawing font and symbol padding.

## Function inventory

| Function | Preserved route |
|---|---|
| Host name/status and game count | Pinned library tile, two bounded lines; full accessibility label |
| Previous/next host, Refresh, Play/Pair/Wake, Add, Settings | Library action row; horizontal swipe/More reveals overflow |
| Continue, Retry, Cancel/Library | Apollo row; original phase/action gating and nonblocking button handling |
| Startup Skip; Settings Back and full-width toggle | Context action row |
| Capture/release input | Main stream button; existing SDL action 1 |
| Live and detailed statistics | Main cards and six-page information panel; separate window toggle uses action 3 |
| Playback mute/volume | Controls → Audio; action 207 and existing playback gain, recorder source unchanged |
| Record/stop; replay save | Controls; existing actions 217/219, readiness/saving/error states retained |
| Local hardware monitor | Controls → Window → Monitor |
| Fullscreen; stream controls; hide | Controls → Window; existing actions 2/11/0 |
| Disconnect | Controls → Disconnect; existing action 12 |
| Existing keyboard/controller/menu routes | Unchanged; Touch Bar calls the existing handlers |

`TouchBarFrontendTests` renders the host tile and full/narrow action row, checks overflow access and full-width lifecycle with fake callbacks. `TouchBarTests` checks all six detailed pages remain reachable with a visible measurement area and exercises action routing, playback slider, local monitor and cleanup. `TouchBarPresentationTests` replaces only process-local presentation methods and focus getters to verify native ownership without touching CI's actual bar. Physical swipe/touch rendering and Control Strip behavior on the owner's M1 remain hardware acceptance checks.
