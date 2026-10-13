# MoonlightLG 1.2.0.1U title-bar mouse restoration

Checkpoint: `checkpoints/moonlightlg-1.2.0.0U-before-mouse-fix` at `165d09474d3145a2dd32d76484c0a3fbd731c6de`.

User confirmed cursor escape after the Statistics title-bar button; computer-name Control Center works correctly.

All title-bar tracking now requests a session/window-scoped input repair after AppKit finishes. Synthetic mouse-up is retained so SDL clears its focus-click bookkeeping. Deferred repair waits for button release, does not run behind an open popup, and runs on popup dismissal, overflow dismissal, window move and end resize. The production input handler reuses Control Center's release/restore-focus/recapture sequence. It honors intentional release, absolute desktop mode, hidden windows, native menus, disconnect sheets and existing local controls. No recording/decoder/pacing/network changes. Tracking monitors and timers are removed at detach; queued actions are flushed and validated against the original window ID.

Tests exercise actual AppKit clicks for Statistics, Record and Replay, relative routing, saved capture intent, intentional release, absolute mode, popup dismissal, window move, and preservation of Control Center. Existing full-screen/disconnect/shutdown and recording tests remain required. Physical host/Intel testing is still required; CI cross-builds Intel on Apple Silicon.

Validation: pending.
