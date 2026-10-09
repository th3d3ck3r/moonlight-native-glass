# Native Glass Preview 18 audit

Requested after build 16 showed error 11 on Control-Option-Shift-E, no hover
thumbnail, and ineffective menu disconnect/host-exit actions. Build 17 had not
been tested by the user. Preview 18 includes its mouse-focus fixes.

## Changes and findings

- Explicit native Disconnect and Disconnect and Exit enter Session's existing
  deferred cleanup directly. The E shortcut and overlay disconnect use those
  native actions. Host-exit intent is session-local; plain Disconnect overrides
  auto-quit for this session. The native adapter deletes the finished Session
  before quitting its helper instead of leaving deletion pending at process exit.
- Menu commands use whitelisted notification names and the active stream token.
  Tests send every command from a separate process and reject unsupported or
  wrong-token requests. This replaces the earlier payload-dependent route.
- Hover presents a cached image or a clickable fallback after 1.5 seconds,
  without waiting indefinitely for ScreenCaptureKit. Missing permission is
  explained and the permission action opens settings when a prompt is unavailable.
  Hidden streams can reuse only their own cached frame. A missing image is never
  represented as a successful real screenshot.
- The permission menu row stays in place as access changes, preventing mismatched
  labels/actions while the menu is open. Exit confirmation rechecks stream token.
- Helper stderr is retained in ~/Library/Logs/MoonlightNativeGlass. Both log menu
  entries open that folder. Messages distinguish a signal from an exit code, so
  an unexplained number 11 is not silently treated as a normal disconnect.
- Launch guards reject offline, unknown, unpaired or unsupported hosts even when
  controller input or a stale view bypasses the normal button's disabled state.

## Review scope and validation

| Area | Review and checks | Limit |
| --- | --- | --- |
| Startup and process lifecycle | Read native helper/frontend ownership, command framing, deadlines, cancellation, stale replies, shutdown callbacks and Session deletion; real process fixtures | No live streaming teardown reproduction |
| Library and windows | Read actions, keyboard/controller routing, game visibility, host selection, Dock/status restoration and window lifetime; XCTest native screens | Sample hosts and games |
| Settings and pairing UI | Read all setting bindings, schema validation, atomic updates, persistence, resolution, overlays and shortcut collisions; real adapter settings tests | No actual pairing handshake or host capability acceptance |
| Menu and thumbnails | Production menu, confirmations, current-token transport, delay/cancellation, fallback, replacement and nonactivating panel tests | Capture fixtures use images rather than live decoded frames |
| Stream presentation/input | Real SDL/AppKit mouse motion/focus, production focus/shortcut handlers, all window modes, native controls, Metal presentation and hide/restore | No host/decode or physical peripheral traffic |
| Audio and controllers | Read native mute/pause and frontend controller ownership boundaries; stock audio/controller engine retained | No speakers, microphone, gamepads or rumble acceptance |
| Backend/network/streaming core | Source boundary check against the pinned upstream baseline; inspect native integration, build complete engine and bundle dependency/signature/architecture audits | Compile/static checks do not establish live network or decode correctness |

Full validation passed for application source `5d53239f2d01b2951766285ba54cfad4ff150ce6`
in run `37894048789`: Intel, Universal and native UI jobs all completed SUCCESS.
Native focus/shortcut and separate-process menu routing tests passed. Both native
window modes presented real composited Metal output and restored after hiding.
The native lifetime fixture passed under AddressSanitizer/UndefinedBehaviorSanitizer;
logs contained no sanitizer error or undefined-behavior report. This instruments
native adapters and fixture methods, not the full decoder/network engine; process
global AppKit leak detection was disabled. Both bundle audits checked 105 Mach-O
files. Real adapter schema/type, atomic validation, settings persistence, recovery
and 100 diagnostic plus 100 ordinary immediate-shutdown cycles passed. No live
streaming session was used in that stress test. Follow-up run `37895058759`,
job `113704430040`, also passed: invalid-host guards were checked against a live
process fixture, helper diagnostic logs and signal/exit distinctions passed, and
all five native UI XCTest cases passed again. Application source is unchanged.

Intel artifact `11599678354` and Universal `11600160812` were verified unexpired.
The downloaded Intel application ZIP matched its CI checksum, native build 18
and engine 6.2.0: SHA-256
`5a06bbb3238f78f62222dda07ac03d060d9442df2fc63c5b356cd4ec7193a0f1`.

This is an audit of custom app code, integration paths
and protected upstream boundaries, not a formal proof of every upstream engine
path. Testing reduces risk; it cannot guarantee no unexpected behavior.

## What cannot be tested here

1. Your physical Intel Mac, OCLP/root-patched graphics, installed macOS build,
   display drivers, and macOS 15 runtime compatibility. CI runs macOS 26 on ARM;
   the Intel app is cross-compiled and audited.
2. Real discovery, Local Network permission prompts, pairing, Wake on LAN,
   Sunshine/Vibepollo host interaction, WAN/firewall behavior or remote failures.
3. Whether the host game actually exits after confirmation or E, versus remaining
   running after Disconnect. Command routing and intent can be tested; the host
   must verify the remote result.
4. The exact error 11 during your live session teardown. No crash stack or host
   reproduction is available. Changed cleanup ordering addresses a real lifetime
   risk, but the reported crash and the earlier intermittent SIGILL are not
   conclusively resolved solely by no-host stress passes.
5. Live Metal thumbnails with your Screen Recording permission, fullscreen
   Spaces, hidden windows, and macOS privacy decisions after an ad-hoc update.
6. Actual codec/HDR/4:4:4/hardware decoding, GPU output/color correctness, audio
   devices, surround sound, Bluetooth controllers, rumble and host input receipt.
7. Your multi-monitor arrangement, native resolution/scaling, sleep/wake, display
   hotplug, high-polling mice, custom keyboard layouts and system shortcut conflicts.
8. Long live-stream sessions, native streaming latency/performance, network
   congestion, and physical hardware power/thermal behavior. Performance testing
   remains outside the requested scope.
9. Developer ID signing/notarization or a public release installation/update flow.
   This remains an unreleased ad-hoc-signed test build; RC1/master are unchanged.
