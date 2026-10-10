# Native Glass Preview 20: same-window startup animation

Application source: `289f190520d90dfc336e94dd63a88bf4e3a7de32`.
Final validation run: [38082342799](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38082342799) — all three jobs passed.
Branch: `native-ui`. Native UI version: 20. Moonlight engine: 6.2.0.

## Behavior

- The approved eight-second boot movie (2560 x 1440, 60 fps) is included as
  `Contents/Resources/boot-animation.mp4`. The build/bundle audit verifies its
  bytes. It contains the Moonlight glass moon, shimmer, orbit trails and title.
- Startup plays inside the existing library window, using a native AVPlayerLayer
  above the window's navigation content. A native container retains the existing
  library controller and places playback beside its disabled hosting view. No
  extra splash window is created; the stream window and routing are unchanged.
  Attachment is deferred out of view hierarchy enumeration and guarded against
  the repeated window callbacks produced by reparenting the library.
- The library and helper initialize behind the animation. Library mouse,
  keyboard and controller interaction remains blocked through the 0.65-second
  crossfade. Skip and Escape allow early completion; the final movie frame stays
  visible through the fade.
- Every fresh app process plays the intro. Closing/reopening the library within
  a running process does not replay it. Restoring a live stream remains unchanged.
  The player, overlay, KVO, notification observers and tasks are cleared after
  completion or window close/termination, including the window-scoped Escape
  event monitor.
- Reduce Motion bypasses playback on ordinary launches. Missing/corrupt media,
  player failure, or a bounded stall watchdog reveal the library. Explicit design
  playback probes can exercise the animation independently of the CI runner's
  accessibility preferences; a separate preview case covers Reduce Motion.
- The user requested an Xcode 26 style in-window opening reveal that repeats at
  launch. Moonlight's own approved artwork is used; no Xcode artwork/resources
  are copied into the app. Exact matching of Xcode's motion has not been visually
  established from a recording of that reference.

## Validation

Local streaming-boundary and whitespace checks passed. The media was verified
as 480 frames at 2560 x 1440 / 60 fps. Real AVPlayer fixtures passed playback
advancement, actual native-window attachment, duplicate reports, close cleanup,
invalid media, Reduce Motion and the stalled-playback watchdog.

All eight XCTest UI cases passed in playback probe `38081886708` at source
`90505c2e20dc3ec06f8c774461fdf3a14d5fd272`: same-window automatic completion,
Skip/Escape, reopen/fresh launch, missing/corrupt/Reduce Motion fallbacks, close
during playback, Dock/status-menu routing, About, native screens and Settings.
The exported screenshots were inspected and show the moon/stars above the
library, followed by the normal library.

The final source passed all eight UI tests again, including opening and
dismissing Add Computer after the fade. Intel job `114301668066`, Universal
job `114301668000` and UI job `114301667941` succeeded.

The complete regression suite passed native overlay state/shortcuts/layout/focus
and teardown; Full Screen and Borderless Full Screen startup with composited
Metal output and captured hide/restore; SDL window/input lifetime with and
without AddressSanitizer and UndefinedBehaviorSanitizer; event framing and
frontend failure recovery; every engine setting schema/type and choices, atomic
validation, persistence, stale-host recovery and correlated pause/resume replies;
100 immediate helper shutdown cycles with a crash trace hook plus another 100
without it; and status icon/menu/click/restore/removed-hover checks.

Both app bundles passed ad-hoc signature verification and permission/identity,
library dependency and architecture checks for all 105 Mach-O files. Both
packages were independently downloaded and checked against their artifact
digests and package SHA-256 values; native/engine identities, versions, executable
slices and exact boot/icon bytes were verified.

## Packages

- [x86_64](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38082342799/artifacts/11680628373): package SHA-256
  `75a302226eb88d60ae0ad8fcad87620a97edf3e401c69653021d43986dc963ef`.
- [universal](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38082342799/artifacts/11681047031): package SHA-256
  `d1688c5291347528117f66d0288a8c96fc8d8f7e416b1fd5dd8e8802e4da3435`.

The movie SHA-256 is
`aac772a8e367143a27e06d686fa6ceb9d5ae9d86682933dcad8121b3a84949ff`.

## Limits

CI uses ARM macOS 26; Intel builds are cross-compiled. Actual video smoothness,
AVPlayer graphics behavior and visual transitions on the user's Intel/OCLP Mac
still require physical testing. No live Sunshine/Vibepollo host is available;
remote game exit, the original reported error 11 and native streaming performance
remain unconfirmed. Previous Preview 19 live-host/hardware and signing limits
continue to apply. This is an unreleased, ad-hoc-signed test build. No master,
public README, release/tag or streaming-backend changes are authorized here.
