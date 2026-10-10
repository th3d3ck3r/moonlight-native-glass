# Native Glass Preview 19: stream menu repair and hover removal

Source: `f3e3e18798a87b196854b047514ac6c60e68d5e1`, branch `native-ui`.
Validation run: `38065418163`.

## Resulting behavior

- The frontend sends stream menu commands through its existing helper pipe. A
  dedicated framed-command reader queues SDL actions while Session suspends Qt
  processing; it does not call AppKit window APIs from its worker thread.
  Qt's stdin notifier hands over after connection startup. The reader starts
  only after the native SDL event type is registered and stops before teardown.
- Commands carry a stream token, action and request ID. Unknown actions, wrong
  tokens and invalid IDs are rejected. The live Session acknowledges accepted
  commands; missing acknowledgements become visible errors rather than silence.
  Broken frontend EOF requests plain Disconnect, never host-game exit.
- Opening the status menu or host-exit confirmation explicitly releases mouse
  capture and held host buttons/keys. Closing or cancelling restores prior input
  intent. Library/Settings actions and hidden windows do not force recapture.
  Explicit Release Input remains respected. Duplicate begin/end actions are safe.
  The capture menu item reflects saved intent during temporary release, avoiding
  a label/action change underneath an open menu.
- Disconnect and Exit still reaches stock deferred Session cleanup, stops the
  connection, then calls the same `NvHTTP::quitApp()` host operation used by the
  working library Quit App path. Native host-quit failures are now reported;
  ordinary Qt behavior and the underlying host operation are preserved.
- Hover preview, tracking handlers, screenshot/cache tasks and thumbnail panels
  are removed. Their Screen Recording menu item and usage-description key are
  removed from the native frontend. The rounded crescent/full-moon icons, primary
  click-to-restore/library behavior and remaining menu commands are retained.
- Native UI build is 19; Moonlight engine version remains 6.2.0. The connecting
  moon/star animation is a design preview only and is not integrated.

## Validation

Run `38065418163` completed successfully: Intel job `114252004822`,
Universal job `114252004653`, and native UI job `114252004783`. Full builds,
bundle audits (105 Mach-O files), SDL/AppKit window/input fixtures, ASan/UBSan
fixtures, frontend process fixtures and all five native UI XCTest cases passed.
Real helper settings/schema/persistence/recovery checks and 100 diagnostic plus
100 ordinary immediate shutdown cycles passed. Status-icon checks passed.

Unexpired artifacts: Intel `11675296898`, Universal `11674873692`. The downloaded
Intel inner ZIP was verified as native UI 19 / engine 6.2.0, SHA-256
`a3ed53b298611f3ee9689cc07ef15593cd3cd81760ff80a6ab92c33b99faa47c`.

The updated tests cover the actual pipe reader with fragmented commands under
`SDL_WaitEventTimeout`, without explicit extra `NSRunLoop` pumping; all supported
commands, wrong tokens, unknown actions, request IDs, reader shutdown and EOF.
Production focus/input methods are compiled into the real SDL/AppKit fixture.
Saved capture intent keeps the open menu label/action stable. Menu release/cancel
restoration is exercised in every window mode, along with
explicitly released input and returning from the library. Frontend process tests
cover both acknowledgements and missing acknowledgements. Status-item tests cover
icon state, confirmations, retained restore actions and absence of hover work.

## Limits

No live Sunshine/Vibepollo streaming host or the user's physical Intel/OCLP Mac
is available here. These checks cannot confirm the remote game actually exits,
reproduce the exact live error 11, validate decoder/driver teardown under that
stream, or benchmark native streaming performance. CI runs on ARM macOS 26;
the Intel application is cross-compiled and audited. Full engine/decoder/network
code is not sanitizer-instrumented. The earlier intermittent SIGILL remains
unexplained. Existing Preview 18 live-host, hardware, privacy and signing limits
continue to apply. This remains an unreleased, ad-hoc-signed test build.
