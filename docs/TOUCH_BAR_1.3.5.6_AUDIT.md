# Build 53 rejection and build 54 repair

Owner report: in regular mode beside the system Control Strip, the moon is
covered and pressing Back from the volume page crashes the app. Full width had
not yet been tested by the owner. Do not treat build 53 as accepted.

Audit against a12fd7652fa9040a4551d048638f81eea7898e92 found:

- Regular live statistics set moonCenter=-1, selecting a black fill over the
  centre. The test incorrectly expected the moon target to be hidden.
- Audio changed the root bar's item identifiers. Returning could recreate the
  animated surface and replace its retained association while an older surface
  was navigating. Physical crash stacks were not supplied, so this is a lifecycle
  defect addressed by the repair, not a confirmed symbolized crash diagnosis.
- The library scroll view covered the moon's restore target and allowed moving
  controls across the stationary artwork region.
- Mac system controls occupied a separate native item, reducing the artwork's
  allocated width. Frontend system-controller creation could also occur after
  the activation update.

Build 54 keeps one root canvas throughout composed navigation. Audio places the
complete native slider host directly in that canvas, outside every scroll view.
Page changes wait until the button callback has returned and reject stale bar
identities/invalidated owners. Existing volume gain, percentage, mute and action
routes are retained. A 96-point artwork region is protected on the main readout,
Audio and secondary pages; scrolling is masked away from that fixed region.
Compact metrics use two cells on each side (FPS, RTT, bitrate, connection state).
The owner subsequently requested removal of the nonfunctional Mac button. Its
button, system volume/brightness backend and associated lifecycle code are removed
entirely. Full width retains the original single artwork allocation. Existing source-copy recording
keyframe scheduling and all streaming-core files are unchanged from build 53.

Regression checks cover center-pixel artwork visibility in composited fixtures,
equal metric widths and nonintersection with the moon, native slider-host ancestry,
40 Audio/Back cycles with autorelease-pool draining, root/slider identity, queued
navigation at detach, and normal/modal ownership. They exercise AppKit views on
CI, not the owner's physical Touch Bar. Physical drag, Back, full-width rendering
remain hardware acceptance checks. No long recording tests.
