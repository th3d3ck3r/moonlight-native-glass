# MoonlightLG 1.3.5.5U implementation

Development follows inspected baseline 0e7c4a59de26c4a3fdb9dd30ca5626c1f7ee196d.

- Library rows use a balanced split of their occupied control widths, compact
  Refresh/Add/Settings glyphs at normal width, and scrolling at narrow widths.
  Full accessible names and existing targets/disabled states remain intact.
  Startup and Apollo retain their layout policy and animation assets.
- Regular stream statistics use equal-width cells without an asymmetric moon gap.
  Full-width metrics retain their authored gap; detail paging remains unchanged.
- The Audio page exposes the existing NSSliderTouchBarItem directly to AppKit.
  Its slider is no longer removed from the native item and put in a scroll view.
  The continuous crimson slider, playback gain, percentage and Back route remain.
- A Mac popover is available only in the optional full-width presentation, from
  both owners. Its native slider items control the default audio output and
  built-in display brightness. Core Audio properties must be writable; brightness
  uses runtime-resolved DisplayServices functions, with errors shown as unavailable.
  System Strip restores normal presentation. Focus loss disables writes and
  dismisses this popover; teardown clears timers and targets. No global/Fn setting,
  stream gain, synthetic key event or host brightness/volume is modified.
- Original Stream Quality recording requests an IDR approximately every two
  seconds through the existing status poll and LiRequestIdrFrame. Naturally
  received keyframes defer requests. Startup/recovery keeps its bounded retries
  and timeout; periodic requests never create a timeout failure. Replay-only,
  stopped, failed and custom encoding states do not generate periodic requests.
  Ingress only updates an atomic keyframe timestamp. No new decoder-thread waits,
  streaming-core modifications, recorder ABI changes or video re-encoding.

The host chooses response timing. IDR requests can increase instantaneous bitrate
and use the existing protocol recovery mechanism; unchanged physical latency is
not established. Periodic keyframes are an attempted improvement for long-file
seeking, not a confirmed diagnosis of the owner's player freeze/crash.

Validation includes deterministic scheduling tests, native item/layout/navigation
checks, mocked system-control providers and existing build/lifecycle suites.
No long-duration recording test is requested. Physical M1 touch tracking, private
brightness API compatibility and long-recording playback require owner acceptance.
