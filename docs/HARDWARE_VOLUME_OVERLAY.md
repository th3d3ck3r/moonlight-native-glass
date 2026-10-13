# Local hardware overlay and playback volume

Development: **1.3.0.0U**, internal build **39**. Validation in progress.

## Hardware overlay

A view inside the existing SDL/AppKit stream content displays CPU load, physical memory (anonymous resident + wired + compressed; excludes purgeable cache), aggregate Ethernet/Wi-Fi receive/send rates, optional driver GPU utilization and macOS thermal state. It never substitutes stream-host statistics or app render timings for local machine readings. Numeric temperature sensors are unavailable in this build; thermal status is explicitly labeled separately from degrees Celsius. GPU driver percentages are accepted only when present, finite and within 0–100.

Mach host ports, ifaddrs lists and IOKit iterator/property objects are released on every sample. Sampling occurs on a utility queue; UI publication returns to the main thread, skips overlapping work and ignores results after detach. History is bounded to the selected time span. Opening/closing does not change stream/video/Metal geometry. Closing or session teardown stops the timer and removes the view.

The monitor remains visible and returns nil from hitTest during host capture. Intentional release enables local controls. Header dragging and bottom-right resizing are clamped inside stream content; position/size, metric visibility, opacity, 0.5/1/2 second cadence and 1/3/5 minute history are saved in the existing native overlay preference suite. Graph colors follow Crimson Glass, with cyan separating network transmit from receive. Accessibility labels and opaque Reduce Transparency fallback are included.

## Volume and input

The speaker opens a transient playback popover containing a 0–100% slider and the existing mute action (207). Gain persists locally, is atomic between AppKit/audio threads, and never boosts above unity. Mute preserves the slider level. Recorder delivery still occurs at the beginning of the actual audio callback, before playback mute/drop checks and before gain. Gain scales only the subsequently decoded float32 or signed int16 playback buffer. All non-macOS playback is unchanged.

Title/monitor buttons use MLStreamToolbarButton; volume/opacity sliders use MLStreamVolumeSlider. Both return tracked mouse-up and request existing window/session-scoped action 220. Popover interaction defers recapture until dismissal. Monitor drag/resize re-posts its consumed mouse-up and requests the same repair. Menus defer until tracking finishes. Capture intent, deliberate release and absolute input are preserved by the existing engine handler.

Title order: capture → computer/Control Center → stream statistics → hardware monitor → volume → record → replay → controller battery (if present) → connection. Narrow overflow keeps that order. Group spacing separates monitoring, playback and recording.

## Validation

Production audio callback fixture checks original packets, float/int16 gain at 100/50/0/25%, signed amplitudes, mute/unmute, drop windows and invalid gain bounds. Native overlay and actual input fixtures cover monitor lifecycle, hit testing, volume/mute state, actual AppKit tracking and deferred capture restoration. Native macOS, Xcode, sanitizer, fullscreen/Metal, UI and stock platform checks must pass before distributing packages. CI cross-builds Intel on Apple Silicon; sensor availability and physical Intel acceptance require owner testing.
