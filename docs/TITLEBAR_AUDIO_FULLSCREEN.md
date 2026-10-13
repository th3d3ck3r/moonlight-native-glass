# MoonlightLG 1.2.2.0U title audio, native fullscreen and faster Apollo flight

Owner acceptance of 1.2.1.0U: capture-driven hiding works well. Follow-ups:
green-button fullscreen reveals overlapping native chrome on input release;
Apollo stars need faster travel; add playback audio control without changing
recorded audio and preserve the existing button mouse boundary.

The fullscreen adapter now identifies native title-only chrome through public
view hierarchy and suppresses it behind the released stream command overlay.
Windowed traffic lights and the existing capture-driven row are restored on exit.
No decoder, SDL window identity, networking or drawable sizing algorithm changes.

Mute reuses session action 207. The title indicator is synchronized with the
existing menu state publisher, and the icon/tooltip/accessibility value explain
playback state. Narrow windows expose the same action in overflow. Its button is
the same MLStreamToolbarButton used by Statistics/Record/Replay, including tracked
mouse-up and scoped action 220 restoration. Intentional release remains honored.

The complete production audio callback is compiled into AudioMuteTests with only
device/Opus/recorder sinks replaced. It verifies that source packets, including
loss markers, reach recording across local mute/unmute and playback drop windows.
The actual recorder's audio mux/decoding remains covered by RecorderTests. The
production audio callback, recording adapter and recorder plugin are unchanged.

Apollo star travel increases from 28 points/s to 420 times the existing field
scale per second, retaining the same 150 deterministic stars, arrival brake,
30 Hz Canvas and Reduce Motion behavior. Ship/connection timing is unchanged.

Checkpoint: `checkpoints/moonlightlg-1.2.1.0U-before-title-audio` at
`cdd28ab50ab8a95de25e4e8f74fda17813c36f36`. Internal build 38.

Validation pending. New coverage includes AppKit native fullscreen entry (the
green-button path), top-edge hover with released input, one visible row, Metal
presentation, return to windowed chrome, actual mute-button tracking/repair,
state/action routing and the production audio mute boundary. Physical Intel
gameplay/visual acceptance remains an owner check; CI cross-builds Intel.
