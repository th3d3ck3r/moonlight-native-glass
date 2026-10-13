# Local hardware overlay and playback volume

Development: **1.3.0.0U**, internal build **39**. Application/test source: `f952576aca91253140a543f9a3bb851412f9146f`.

## Hardware overlay

A view inside the existing SDL/AppKit stream content displays CPU load, physical memory (anonymous resident + wired + compressed; excludes purgeable cache), aggregate Ethernet/Wi-Fi receive/send rates, optional driver GPU utilization and macOS thermal state. It never substitutes stream-host statistics or app render timings for local machine readings. Numeric temperature sensors are unavailable in this build; thermal status is explicitly labeled separately from degrees Celsius. GPU driver percentages are accepted only when present, finite and within 0–100.

Mach host ports, ifaddrs lists and IOKit iterator/property objects are released on every sample. Sampling occurs on a utility queue; UI publication returns to the main thread, skips overlapping work and ignores results after detach. History is bounded to the selected time span. Opening/closing does not change stream/video/Metal geometry. Closing or session teardown stops the timer and removes the view.

The monitor remains visible and returns nil from hitTest during host capture. Intentional release enables local controls. Header dragging and bottom-right resizing are clamped inside stream content; position/size, metric visibility, opacity, 0.5/1/2 second cadence and 1/3/5 minute history are saved in the existing native overlay preference suite. Graph colors follow Crimson Glass, with cyan separating network transmit from receive. Accessibility labels and opaque Reduce Transparency fallback are included.

## Volume and input

The speaker opens a transient playback popover containing a 0–100% slider and the existing mute action (207). Gain persists locally, is atomic between AppKit/audio threads, and never boosts above unity. Mute preserves the slider level. Recorder delivery still occurs at the beginning of the actual audio callback, before playback mute/drop checks and before gain. Gain scales only the subsequently decoded float32 or signed int16 playback buffer. All non-macOS playback is unchanged.

Title/monitor buttons use MLStreamToolbarButton; volume/opacity sliders use MLStreamVolumeSlider. Both return tracked mouse-up and request existing window/session-scoped action 220. Popover interaction defers recapture until dismissal. Monitor drag/resize re-posts its consumed mouse-up and requests the same repair. Monitor popup menus use the same tracked release even when canceled without choosing an option. Menus defer until tracking finishes. Capture intent, deliberate release and absolute input are preserved by the existing engine handler.

Title order: capture → computer/Control Center → stream statistics → hardware monitor → volume → record → replay → controller battery (if present) → connection. Narrow overflow keeps that order. Group spacing separates monitoring, playback and recording.

## Validation

Production audio callback fixture checks original packets, float/int16 gain at 100/50/0/25%, signed amplitudes, mute/unmute, drop windows and invalid gain bounds. Native overlay and actual input fixtures cover monitor lifecycle, hit testing, volume/mute state, actual AppKit tracking and deferred capture restoration. Native macOS, Xcode, sanitizer, fullscreen/Metal, UI and stock platform checks must pass before distributing packages. CI cross-builds Intel on Apple Silicon; sensor availability and physical Intel acceptance require owner testing.


### Completed package and Xcode checks

- Native macOS run `38425187310`: Intel job `115392606684`, Universal job `115392606228`, UI job `115392606581` all passed. Each bundle audited 107 Mach-O files, permissions, identities and dependencies. UI suite: 12 tests, zero failures.
- Xcode run `38425187315`, job `115392609145`: fresh/incremental full app, embedded engine, source ZIP dependency setup, startup preview and UI suite all passed. UI suite: 12 tests, zero failures.
- Stock platform run `38425187333`: Windows, macOS, AppImage and Steam Link all passed.
- Production callback validates float/int16 gains at 100/50/0/25%, signed amplitudes, mute/unmute, invalid gain bounds, playback drops and byte-identical recorder packet delivery. Local ASan/UBSan audio fixture also passed.
- Actual native overlay checks passed: monitor hit testing, persistent cadence/opacity/dimensions, local resize without video resize, bounded async close/reopen and volume/mute state. Actual SDL/AppKit button/slider tracking, deferred popover recapture and intentional release passed in ordinary and ASan/UBSan input suites. Fullscreen/borderless/green-button hover and Metal geometry checks passed.
- Recorded media mux/decode, packaged Apollo/window identity, real engine bridge/persistence and 200 shutdown cycles passed.
- Previews inspected: `hardware-monitor.png` and `playback-volume.png` from the current source. Graphs show actual CI-machine readings; histories were just starting at capture time. GPU was unavailable on that runner and was labeled accordingly.
- Additional quick regression run `38425187450`, attempt 2, remains queued. The first attempt reported a canceled job with no test steps or logs. The full native ordinary and ASan/UBSan input suites already passed in run `38425187310`; no application failure was observed in the canceled quick attempt.

Downloaded app ZIP SHA-256 checksums were independently verified against CI checksum files:

| Package | SHA-256 |
| --- | --- |
| Intel | `c0d8fce84b2174401cb5d6eadfa38c46c3947eee68b4e86173e1ab0a10e01b82` |
| Universal | `286b00b02eeb6c69bb1e966aa9ac3fb1f8a3b385bb9ef6ff7f52c7b5b7477030` |

Both root bundles report 1.3.0.0U/build 39. App, engine and recorder slices match Intel-only or Intel + Apple Silicon respectively. No package has been relabeled or publicly released. The pre-change checkpoint is `checkpoints/moonlightlg-1.2.2.0U-before-hardware-volume`, at `98bc24dbfc46c6442105bf1012c9f08025c8de7d`.

Physical Intel execution and sensor availability require owner acceptance; CI executes native tests on Apple Silicon and cross-builds Intel. Numeric temperatures are explicitly unavailable in this implementation; macOS thermal status provides the fallback. GPU driver support varies. Leak detection is disabled for AppKit/SDL sanitizer fixtures; address and undefined-behavior checks are active.
