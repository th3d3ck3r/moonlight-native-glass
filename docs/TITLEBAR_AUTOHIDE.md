# MoonlightLG 1.2.1.0U capture-driven title controls

Reference: the owner's QuickTime recording, October 13, 2026. Title controls overlay
the video; captured streaming hides them, and intentional input release shows them.
There is no hover-to-reveal target while capture is active. Existing keyboard and
menu action routes remain unchanged, including Control Center, statistics,
recording/replay, release/capture and disconnect.

Windowed presentation installs AppKit full-size content once, retaining the same
SDL content view and window frame. The thin title accessory and traffic lights
are hidden during capture; the decorative glass fades over 160 ms (zero with
Reduce Motion). Hidden buttons and native title-area dragging are disabled
immediately. Showing/hiding does not toggle window style or video geometry.
Fullscreen/borderless presentation uses the same stream command row as a top
overlay on release, without a native title row or geometry change.

Focus loss, title popovers, overflow menus and attached sheets keep local controls
accessible. Capture ownership is still decided by the existing input handler;
visibility never activates or releases host capture. The existing mouse-up,
popup/menu dismissal and drag repair routes are retained. Focus observers and
animation completions are scoped to the attached owner; detach removes the
overlay, restores windowed style/movement and invalidates stale hide completions.

Checkpoint: `checkpoints/moonlightlg-1.2.0.2U-before-autohide`, source
`a17ad5f0bc78c272958eac2a62f022319673eecb`. Internal build 37.

Coverage: actual AppKit/SDL control tracking and relative motion; intentional
release; absolute mouse mode; popover/overflow dismissal; real SDL drag state;
all presentation modes; hidden key routing; invariant window/video/Metal drawable
geometry; quick release after a hide begins; teardown/style restoration; composited
hidden/released screenshots. Streaming-core hashes remain unchanged.

Validation pending. CI uses Apple Silicon and cross-builds Intel; physical Intel
gameplay, visual acceptance, host mouse confinement and sustained recording remain
owner checks. U download links are shared only directly with the owner.
