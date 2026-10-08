# Scalable native stream overlay and shortcut customization plan

Status: planning only. Do not implement or build until separately authorized.

## Goal and boundaries

Replace the current stream overlay presentation with UI matching Moonlight Native Glass. Make it scale correctly with the stream window, Retina/non-Retina displays and an optional user-selected size. Preserve the user's currently successful latency and frame pacing.

Keep networking, discovery/pairing, codec selection, VideoToolbox decoding, HDR, audio, video layers, rendering/presentation scheduling and input-capture behavior unchanged. Existing menu bar hide/restore and moon states remain intact. Microphone work is a separate plan and is not a dependency.

## Source findings

Inspected the current native-ui application source:
- app/streaming/video/overlaymanager.h/.cpp: two overlay types, statistics and status; fixed 20/36 font sizes, ModeSeven font, yellow/red text and rasterized outlined SDL surfaces.
- app/streaming/video/ffmpeg.cpp: statistics formatting currently updates roughly once per second using the existing measurement windows.
- app/streaming/video/ffmpeg-renderers/vt_metal.mm and vt_avsamplelayer.mm: the Mac renderer implementations own overlay composition. Neither may be assumed to be the user's active renderer until runtime evidence is obtained.
- app/streaming/input/input.cpp and keyboard.cpp: fixed Ctrl+Alt+Shift combinations call existing local action handlers. Controller statistics toggling also exists.
- app/native/nativeapplication.mm: delegates to SDL's original window handling and implements stream-window hide/restore.
- macos-native/Sources/NativeSettingsView.swift: current native settings have no overlay customization section.

The checked code has statistics/status overlays, not an existing native shortcut-button toolbar. Adding a button bar is an additive presentation feature. Changing key bindings is a separate input feature and should be independently reviewed.

## Proposed appearance

1. A compact statistics card near the stream's upper-left corner, retaining every existing metric and unit.
2. Readable status messages in a small native toast; do not silently discard network warnings or controller mouse-mode messages.
3. An optional compact control bar with native buttons, SF Symbols, tooltips and an overflow menu.
4. Glass limited to control/navigation surfaces. Use restrained readable statistics backgrounds; no full-window blur or video wrapper.
5. System typography, monospaced digits for changing numbers, current accent and spacing. Light/dark appearance follows macOS.
6. Use genuine NSGlassEffectView/native glass on macOS 26+ when appropriate; native material/opaque fallbacks on macOS 15. Reduce Transparency uses an opaque accessible surface. Avoid relying on newer APIs without availability guards.

## Scalability specification

| Setting/state | Intended behavior |
| --- | --- |
| Automatic (default) | Adapts layout to available window dimensions while keeping text/buttons readable |
| Size control | Proposed 80–150% range with named presets; validate minimum legibility before finalizing |
| Retina/external display | Layout in points; raster backing uses actual display scale, not stream pixel resolution |
| Small stream window | Compact metrics layout; extra controls go into overflow |
| Wide/fullscreen stream | Comfortable spacing without stretching the card or growing with stream resolution |
| Larger user size | Increase fonts, symbols, padding and target sizes together; clamp panel to visible bounds |
| Display change | Recompute backing scale and anchors from window/display notifications |
| Saved placement | Store relative corner/anchor and bounded offsets; recover visibly if displays change |

- Reflow rather than crop. Keep all metrics accessible through the expanded layout.
- Respect visible content bounds, fullscreen safe areas and title bar; do not place controls offscreen or across display edges.
- Snap to corners and allow optional dragging while in an explicit overlay interaction/customization mode.
- Do not scale by applying a blurry bitmap transform.
- Avoid changing constraints or subview geometry recursively from layout callbacks. Compute stable frames, skip no-op changes, and keep AppKit updates on the main thread.
- Restore Defaults resets overlay preferences alone.
- Do not add independent font, button and padding sliders.

## Phase 1: Baseline and presentation prototype

- [ ] Verify remote native-ui HEAD, repository instructions, source and workflow state; preserve newer authorized work.
- [ ] Capture current app build/source, chosen renderer, stream resolution/FPS, display scale and settings.
- [ ] Measure old overlay hidden/visible under the same stream workload on the user's Intel Mac.
- [ ] Prototype a small auxiliary AppKit panel associated with the existing SDL stream window. Do not replace its contentView, reparent its video layer, change SDL's delegate contract or create a full-screen transparent canvas.
- [ ] Create a noninteractive statistics surface that does not take key focus or mouse events. Treat interactive controls as a distinct bounded surface.
- [ ] Verify fullscreen spaces, parent ordering, minimization, hidden-window restore and multiple displays before choosing the final attachment approach.
- [ ] Check whether true glass samples/composites correctly over the actual Metal/AVSampleBuffer video surface, including HDR. Do not assume appearance or performance from a static mockup.
- [ ] Choose native AppKit implementation in the stream helper as the initial approach, minimizing new SwiftUI runtime/window integration in the rendering process. SwiftUI remains the customization frontend.

References: https://developer.apple.com/documentation/appkit/nsglasseffectview and https://developer.apple.com/documentation/appkit/nspanel.

## Phase 2: Read-only presentation adapter

- [ ] Introduce a small overlay presentation interface that receives copied text/state snapshots from existing producers.
- [ ] Preserve every statistic's calculation, sampling interval, metric definition and warning trigger.
- [ ] Coalesce UI updates; at most one pending main-thread update, with stale session updates rejected using a session generation/token.
- [ ] Keep allocation, AppKit work and waiting out of decode/render callbacks and renderer locks.
- [ ] Disable duplicate legacy visuals only when the native presentation path is available and owns that overlay. Keep the original path as fallback.
- [ ] Do not maintain a second independent statistics calculation or add high-frequency sampling.
- [ ] Remove observers, timers and panels safely on session exit; handle late callbacks.
- [ ] Event-driven sizing/visibility; no hidden overlay polling or new display-link loop.
- [ ] Any edits under currently protected engine paths must be narrowly reviewed presentation hooks with explicit CI coverage, not a blanket relaxation of baseline checks.

## Phase 3: Native layout and sizing

- [ ] Implement automatic reflow and the size preference with bounded point sizes.
- [ ] Render statistics from existing values, keeping labels/units accurate. If structured rows require an adapter, avoid fragile parsing and do not invent metrics.
- [ ] Preserve status visibility/duration semantics; use warning symbols and text rather than color alone.
- [ ] Verify SDR/HDR readability, scaling, overflow, long labels and missing values.
- [ ] Support Reduce Motion, Reduce Transparency, contrast and VoiceOver without repeatedly announcing live statistics.
- [ ] Ensure the passive panel cannot affect stream key focus or capture.
- [ ] Provide an early clearly labeled mockup, followed by actual app captures when a prototype exists.

## Phase 4: Shortcut-button customization

Add one Overlay section within Settings using the current native style.

- [ ] Choose visible actions and order using stable action IDs and native list/reordering controls.
- [ ] Provide size, placement and Restore Defaults in the same section.
- [ ] Proposed actions from existing handlers: Full Screen, Performance Statistics, Release/Capture Input, Mouse Mode, Cursor Visibility, Minimize, Paste Clipboard, Pointer Region Lock and Keyboard Capture.
- [ ] Disconnect must be visually distinct and cannot silently become Quit Host Game. Verify the two existing quit actions before naming/exposing them.
- [ ] Unavailable actions are disabled with a reason; the button bar must not circumvent existing platform/state eligibility.
- [ ] Dispatch through the existing action handler on its proper SDL/session thread. Do not synthesize keyboard combinations to activate buttons.
- [ ] Preserve current keyboard/controller shortcuts and all normal input forwarding.
- [ ] Opening interactive controls must use the existing input-release mechanism, preserve prior capture state and restore it appropriately. Never forward UI clicks to the host or leave modifiers/buttons stuck.
- [ ] Do not auto-release capture solely because the pointer passes over the overlay.
- [ ] In small windows place excess actions in a native overflow menu, keeping a consistent keyboard/controller path.

## Phase 5: Optional Mac-style key bindings (separate change)

- [ ] Retain legacy Ctrl+Alt+Shift shortcuts by default.
- [ ] Display Mac modifier glyphs and natural English tooltips.
- [ ] Offer an explicit Mac preset/custom binding editor only after button/overlay behavior is validated.
- [ ] Distinguish local app shortcuts from combinations sent to the Windows host.
- [ ] Never globally remap Command to Control as part of styling.
- [ ] Detect duplicate/reserved combinations, key-repeat problems, keyboard layout differences and unavailable capture-system-key modes.
- [ ] Verify consumed local shortcuts do not leak partial modifier/key sequences to the host; verify key-up cleanup.
- [ ] Keep controller defaults unchanged. Add any controller rebinding only in a separately authorized scope.
- [ ] Store versioned new preferences with safe defaults; do not rewrite existing stream settings.

## Validation matrix

### Source and build
- [ ] Review diffs specifically for decoding, synchronization, frame queues, display-link/vsync, audio, networking and input changes.
- [ ] Verify Objective-C/AppKit bridges, resources, availability guards and both Mac renderer integrations.
- [ ] Full x86_64 and Universal builds; existing bundle, protocol, persistence, native UI and SDL window lifecycle checks.
- [ ] Add focused tests for clamp/reflow, unavailable actions, action dispatch, stale callbacks and preferences.

### Window and input
- [ ] Small/normal/large windows; 720p/1080p/1440p/4K/native stream sizes without tying overlay size to stream pixels.
- [ ] Retina and non-Retina output; moving between displays with different scale.
- [ ] Fullscreen transitions, Spaces, minimize, menu bar hide/restore, display disconnect and repeated sessions.
- [ ] Relative/absolute mouse, keyboard/controller focus, clipboard and modifier cleanup.
- [ ] Scale changes during streaming must not recursively invalidate layout or resize the video surface.
- [ ] Ensure panels hide with the stream and do not appear over other apps or unrelated streams.

### Appearance and accessibility
- [ ] macOS 26 glass and macOS 15 fallback; light/dark, Reduce Transparency/Motion, increased contrast.
- [ ] SDR/HDR, bright/dark game backgrounds, enlarged text, long labels and missing metrics.
- [ ] VoiceOver labels, keyboard focus, tooltips, noncolor warning cues and unclipped overflow.

### Physical Intel performance gate
- [ ] Compare old hidden/visible overlay to new hidden/statistics/control-bar states using identical settings and a repeatable game scene.
- [ ] Record available CPU/GPU evidence, decode/render latency, frame drops and frame-time distributions/tail spikes. Distinguish RTT, decode time and display/frame pacing.
- [ ] Repeat runs where needed to separate noise from changes; do not set an arbitrary performance claim before measuring baseline variance.
- [ ] Test resizing/scaling, interaction, fullscreen and HDR, not only a static panel.
- [ ] Reject/adjust effects or presentation approach if it adds repeatable latency or pacing regressions. Native opaque styling is an acceptable fallback.
- [ ] Builds or ARM CI cannot establish Intel streaming performance.

## Delivery sequence

1. Baseline evidence and native/scalable presentation prototype.
2. Statistics/status replacement and physical Intel comparison.
3. Button bar and customization, keeping original keyboard behavior.
4. Optional Mac binding preset as a separately reviewed feature.
5. Only after authorization and required validation: increment build number and publish a separate preview link. Preserve About text, master and earlier releases; update README only if requested.

No implementation, build, microphone change or streaming behavior change is authorized by this planning document.
