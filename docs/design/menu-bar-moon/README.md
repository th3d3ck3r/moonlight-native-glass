# Menu bar moon states — design proposal

Status: plan and artwork only. No application code, bundle resources, project references, build number or release changed.

## Intended behavior

| Actual stream-window state | Menu bar artwork | Primary click |
|---|---|---|
| No stream window has opened | Existing crescent | Open the regular app |
| Connecting, but no stream window exists yet | Existing crescent | Open the regular app |
| A stream window has opened and is visible | Full moon | Bring that same window forward |
| That opened stream window is hidden to the menu bar | Full moon | Restore that same window |
| An opened window is minimized or fullscreen | Full moon | Bring that existing window forward |
| The stream window ends/is destroyed, or its helper exits | Existing crescent | Open the regular app |

Use the existing `EngineStore.streamWindowExists` state. Do not derive the icon from `streamActive`, `streamStarted`, the host's running-game state, network activity, focus or window visibility. Hiding a window must not reset its existence state. Ending the stream must reset it.

The app's Dock/About icon stays the approved crescent. This proposal changes only the menu bar status indicator. Preserve Preview 5's primary-click routing and secondary-click Settings/Quit menu, including Quit confirmation and stream cleanup.

## Proposed artwork

- `crescent-existing.png`: exact approved app artwork extracted from the current ICNS; reference/idle state, not a redesign.
- `full-moon-proposed.png`: matching full moon design with the same midnight navy background, cyan/periwinkle glass and two small dots; proposed opened-window state.
- `generation-prompt.txt`: reproducible brief and source reference for the proposed artwork.

Keep both states the same displayed size (18 points), padding and optical alignment. Use 1×/2× exports for menu bar use when implementing; keep master PNGs as design sources. The proposal artwork has not yet been tested as an installed 18-point status item. Check both states on Retina/non-Retina, light/dark menu bars and external displays before accepting final exports.

## Implementation plan — future work only

1. Confirm the full-moon artwork visually matches the approved crescent and remains recognizable at 18/36 pixels. Avoid craters, extra badges, new colors or an animation.
2. Add only the final full-moon resource and verified project/build-script references. Keep the existing app ICNS and bundle identity intact.
3. Extend `NativeStatusMenu` to cache both `NSImage` objects at 18 points. Bind it once to `EngineStore.$streamWindowExists`, remove duplicate state values and apply image updates on the main thread.
4. Retain that observation in the app-owned status controller, not in the library view's appearance lifecycle. Updates must continue while the library and/or stream window is hidden or closed. Use a weak controller capture and cancel the observation on teardown.
5. Initialize from the current existence value; use the approved crescent if the new resource cannot load. Update only the status image, tooltip and accessibility label. Suggested labels: “Moonlight Native Glass — no stream window” and “Moonlight Native Glass — stream window open”. Keep the restore/right-click instructions in the tooltip.
6. Use an immediate, static swap. No timer, frame polling, pulsing, morphing or opacity animation. This respects Reduce Motion and adds no streaming render work. Keep state distinguishable by shape and accessible text, not color alone; check increased contrast and Reduce Transparency.
7. Validate the state transitions below and review the diff for accidental streaming/settings changes. Build the full x86_64 and Universal apps, verify resources/signatures/bridges and rerun existing UI/SDL lifecycle checks.
8. Only after an implementation request and passing checks, increment the build number, create a separately labeled preview and update GitHub/README. Keep the current Preview 5 and prior releases intact.

## Validation checklist for future implementation

- Cold launch/no window → crescent; a connecting helper with no window also remains crescent.
- Actual window-open event → full moon, independently of whether video has started.
- Hide/minimize/fullscreen/reopen cycles retain full moon and restore the same window without relaunching the game.
- Normal disconnect, window destruction, launch failure and helper crash → crescent; primary click returns to the regular app.
- Close the library while the stream window exists; verify the status observer keeps updating. Repeat sessions and confirm no duplicate observers/status items or stale full moon.
- Verify tooltip and VoiceOver labels in both states; inspect 18-point/Retina rendering, appearance, increased contrast, Reduce Transparency and Reduce Motion.
- Preserve Settings/Quit, Quit cancellation, keyboard/controller disconnect shortcuts, focus, audio, input and manual updates.
- Physical Intel Tahoe/Mac-and-host test: compare audio/input recovery, CPU/GPU and frame pacing with Preview 5 while visible and hidden. Successful compilation or host-free SDL tests do not establish streaming performance.

## Current source references

- Built Preview 5 application source: `e96caef79fde987b495f9a62c245215e28f29057`.
- Current status/window state: `macos-native/Sources/EngineStore.swift` (`streamWindowExists`, `windowOpened`, `windowClosed`, helper exit).
- Current status controller: `macos-native/Sources/MoonlightNativeApp.swift` (`NativeStatusMenu`, `NativeStatusActions`).
- This directory is a proposal and is not referenced by the application or build scripts.
