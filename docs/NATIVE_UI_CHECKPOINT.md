# Native UI checkpoint

Repository: `th3d3ck3r/moonlight-native-glass` · branch: `native-ui`.
`master` application code remains stock Qt v6.2.0: `de2467e433821664cdd2224aad8c89a625be1ad9`. Its README-only homepage commit is `e0c36c9`.
The Enhanced repository is untouched.

## Architecture

SwiftUI/AppKit owns navigation, library, Settings, pairing/address/details sheets,
alerts and About. A bundled Qt helper exposes stock ComputerManager,
BoxArtManager and StreamingPreferences through versioned JSON lines. Each stream
uses a separate helper with the original Session/SDL video window. Controller
handlers detach before streaming. Preferences and pairing use a separate Qt
application name. Updates are manual; no updater object is instantiated.

No changes to `app/streaming`, `app/backend`, `app/settings`, common-c or mDNS.
Native-only CLI app-ID selection and a hidden display-selection QQuickWindow
connect the frontend to stock streaming. No Enhanced extensions are imported.

## Verified milestones

- `6c4a4b8`: native frontend + adapter; `bd4a3e8`: native actions and bundle audits.
- `65a4b57`: full Intel and Universal builds passed; signatures, nested binary
  dependencies/architectures, event framing, real bridge and restart persistence
  passed. Screenshot harness failed; it did not establish visual approval.
- `2921e24`: equals-form preview arguments resolve SwiftUI window-launch failures.
- `717a5c5`, run `37587865882`: XCTest captured all 14 native UI cases successfully.
  Inspection found Settings obscured by the preview library window.
- `474469c`, run `37588222100`: XCTest passed again; Settings window order fixed.
  Actual light/dark/compact, state, sheet and Settings screenshots inspected.
- CALayer captures are diagnostic only; native materials require composited
  screenshots. XCTest is the visual gate. Both complete architecture builds
  must pass on the final frontend revision before publishing a preview.

## Current work

Added a native checking-connection state, preserving stock discovery behavior.
README uses the requested custom banner, download/feature tables, actual sample
screenshots, collapsible build instructions and explicit validation limits.
`25c1442`, run `37588923998`: Intel passed; Universal compiled and audited,
framing and real adapter/persistence passed; the obsolete fallback layer-capture
harness hung on Add Computer. XCTest captured all 15 cases successfully.
Removing fallback capture code and duplicate diagnostics; XCTest becomes the
sole UI capture gate, now with Release optimization matching the shipped frontend.
Removed the redundant “Value” label from numeric Settings fields.
`d746f2a`, run `37589657439`: **all three jobs passed**. Full Intel and Universal
builds, signatures, permissions, identities and dependencies (105 Mach-O files),
event framing, real bridge/atomic settings validation/restart persistence, and
15 Release-mode XCTest screenshots passed. Composited screenshots inspected.
Publisher is gated to this exact SHA/run and its successful jobs/artifacts;
first publication attempt returned GitHub HTTP 403 on a historical target SHA.
`8b69293`, publication run `37590985636`: **published Preview 1** successfully.
Tag `native-glass-6.2-preview-1` points to `8b69293`; all build inputs match
`d746f2a` (publisher verifies only docs/assets/workflows changed). Intel and
Universal ZIPs, SHA256SUMS and composited UI captures are uploaded; release is a
prerelease. Master SHA verified unchanged after publishing. Final README links
point to the live assets. Next step is physical Intel Tahoe validation below. Source/native work is complete for Preview 1.
Non-blocking warnings include unused preview argument locals and upstream API
warnings. Physical validation limits below remain unchanged.

## Physical Intel Tahoe checklist

1. Finder launch and Local Network approval; discovery and manual address.
2. Pair and relaunch; verify saved pairing and settings.
3. Launch/resume/disconnect; H.264/HEVC hardware decode; audio, controller,
   keyboard and mouse. Test cancellation and interrupted startup.
4. Resize/fullscreen/display switching; focus and responder behavior; light/dark,
   Reduce Transparency, Reduce Motion and increased contrast.
5. Compare stock 6.2.0 and native on the same Mac/host/settings: CPU/GPU,
   decode time, network stats and frame pacing with overlays visible.

## Limits

Physical pairing/streaming and Intel performance have not been tested for this
new app. Compilation and unchanged source do not prove performance parity.
Helper Local Network attribution, multi-display mapping and interrupted-launch
cleanup require physical validation. Signatures are ad-hoc, not Developer ID or
notarization. Stock stream shortcuts/overlay remain; no Enhanced microphone,
clipboard or AWDL extensions. Minimum macOS is 15; new glass APIs are guarded
for 26 with native fallbacks. The Linux workspace cannot run AppKit; macOS CI
builds and screenshot checks provide the available evidence.

## Build 2 fixes and About policy

- `e298884`, run `37625715679`: full Intel/Universal and 15-screen native UI validation passed. The packaged background helper's real AppKit activation policy is verified accessory. Stream processes keep regular activation. Successful pairing publishes its confirmed host snapshot before dismissing the PIN sheet and resumes stock polling/app-list retrieval.
- `7400b7b`: fixed About credits, native GitHub hyperlink and bundle build number 2. An XCTest menu-coordinate exception blocked the new About case; the same production About function now opens through the design-preview entry point (`b5159b5`).
- Keep About text fixed: “Native Glass created and maintained by Th3D3ck3r”, GitHub Repository link, existing engine/interface/manual-update/license credits. Future builds change only CFBundleVersion; add no release-specific notices to About.
- Before publication, require all full build jobs plus the About screenshot/link check to pass on the final revision. Live pairing refresh and stream focus still require physical Mac/host testing.

- `73c85e3`, run `37628175967`: About dialog/link check and all 16 composited UI captures passed; About screenshot inspected for exact credits and clipping.
- Final build 2 source/package revision: `aa7fe3bffee47f4ad6542871402dd9d6a541beac`; validation run `37628909463`. Full Intel/Universal jobs and all UI checks passed. The real helper Dock-policy, JSON framing, atomic settings and restart persistence checks passed; About screenshot inspected. Preview 2 publication is gated to this source and run.

- `a16b0ef`, publication run `37630160986`: Preview 2 published with Intel/Universal ZIPs, checksums and composited design captures. Build inputs match validated `aa7fe3b`; Preview 1 retained. Master application code unchanged. Next: physical pairing-refresh, idle/stream Dock icons and stream focus testing on Intel Tahoe.

## Build 3 preparation

- About version line now reads `Native UI Preview 3 - Moonlight 6.2`, with the preview number derived from CFBundleVersion. The standard appended build suffix is suppressed. Credits and GitHub hyperlink stay fixed.
- Build number and validation artifact names advanced to 3. Streaming engine sources unchanged. Crescent icon integrated in the native frontend. Preview 3 publication follows required validation.

- Build 3 Settings: native resolution dropdown replaces separate width/height fields; presets 720p/1080p/1440p/4K plus current Settings monitor's native mode (stock CoreGraphics native-mode flag). Dimensions sent atomically to existing preferences; stock bitrate adjustment preserved. Unknown saved sizes displayed as Custom. Native choices refresh on display/window changes, without silently rewriting saved dimensions.
- New crescent icon packaged only in the native frontend; stock streaming helper icon unchanged. UI test bundle now includes actual app icon. Added dropdown interaction and real resolution transaction/restart persistence coverage. Validated source `904f5d127cd1e57629ca21d7b972be07719149a9`, run `37670613344`: full Intel and Universal builds, 105 Mach-O audits, event framing, actual helper Dock policy and resolution/restart persistence all passed. All 16 native UI captures and dropdown selection checks passed; composited screenshots reviewed. Physical Intel Tahoe resolution/native display behavior and streaming performance still require Mac/host testing.

- Preview 3 published by `4cb882f`, publishing run `37673684514`: Intel/Universal packages, checksums and 10 composited captures uploaded; built inputs match validated `904f5d1`. Previous previews retained. README download links and Settings/About screenshots updated on native-ui and the master homepage; master application code unchanged. Next: physical Intel Tahoe preset/Native selection, display switching, pairing refresh and stock streaming comparison.

## Preview 3 physical feedback

- User initially reported black video above 1080p with audio continuing, then confirmed it works and requested only the icon change. No streaming workaround or decoder/renderer/backend change was made. No cause established; investigation closed at user direction.
- Engine Dock icon remained old because only the outer frontend resource was replaced. Packaging now copies the same crescent ICNS into the nested engine bundle before signing; bundle audit checks both declared icons are identical. Existing bundle identities and engine executable remain unchanged. Icon packaging revision `25f78a4f3304fc624fcf881e4b25eb33e1bdab61`, validation run `37677092273`: full Intel/Universal bundles and declared-icon equality audits passed; protocol, real helper/persistence and all 16 native UI captures passed. No new release yet.

## Build 4 preparation

- Scope: match streaming engine Dock icon to frontend crescent, add persistent native menu bar access, plus build number 4. About wording remains fixed and automatically reads Native UI Preview 4 - Moonlight 6.2. Streaming code and settings behavior unchanged. Full final build validation pending before publication.

- Added native MenuBarExtra using the same crescent ICNS at 18 pt. Closing the library leaves the app and existing helper available; menu actions reopen the single library window, open Settings and quit through existing streaming confirmation/cleanup. Normal Dock/responder behavior retained; no LSUIElement/identity or backend changes. Added actual close/reopen/Settings/Quit UI coverage and menu screenshot.

- Menu bar probe at `845ac62`, run `37679491188`: app remained running after close and all menu actions were accessible. Screenshot query selected an empty menu frame; switched to composited main-screen capture so the status icon and visible menu are captured together. Remaining reopen/Settings/Quit checks rerun before publication.

- Follow-up probe `d908f4d` selected the left application menu by its title. Captured screen/AX hierarchy confirms the crescent status item exists as StatusItem `native-status-item`. Test now targets that item and its own menu descendants, using their observed frames for mouse clicks. No application code changes required for the test correction.

- Menu bar lifecycle probe bdfc99f582b0e8a22ec58601d57c3c081febd2bf passed (run 37681428750): close, reopen, Settings and Quit. All 17 captures passed. Final full Intel/Universal validation follows.

- Preview 4 final source: 007bbc594bacb768e1abcc31478c7d95e94ba4de. Validation run 37682529752 passed all three required jobs: full x86_64, Universal and 17 native UI captures/lifecycle checks. Protected engine source remains stock 6.2; master code unchanged. Physical Intel streaming/close-window-during-stream checks remain outstanding. Publishing verified artifacts only.

- Preview 4 published successfully by run 37683717439 at publishing commit c65a603e331bc2b48a84cf345c9b139732592692. Both ZIPs, SHA-256 checksums and 11 screenshots uploaded; previous releases preserved. README updated on native-ui and master (documentation only).

## Preview 5: separate stream-window behavior build
- Requested: only restore a stream window after it actually opened; close hides that window instead of disconnecting. If no stream window exists, primary status click opens the regular library. Right-click retains Settings/Quit.
- macOS-only presentation adapter forwards SDL's existing window delegate; no changes under upstream streaming/backend/settings. Window availability comes from actual opened SDL Cocoa windows, separately from stream-active/starting flags. Restore uses a per-launch token and the macOS main run loop because Session suspends Qt processing.
- Add a real SDL lifecycle harness (no host/video) for close/hide without SDL_QUIT, repeated cross-process restore/focus, wrong-token isolation, resize forwarding, absent/destroyed windows and cleanup. Require it with full builds/UI checks before publishing.
- Preview 4 stays intact; Preview 5 will have a separate release/download link.

- Full x86_64 and Universal builds at e96caef79fde987b495f9a62c245215e28f29057 passed in run 37692872366, including 105 Mach-O audits and the real SDL lifecycle harness. Native screenshots/primary icon click passed; XCTest Settings selection was ambiguous with the app menu. Scope the query to the secondary status menu and run a UI-only probe with identical build inputs.

- Corrected UI probe 6e88eeddea911552f0b685ea29bde893b0c31778 passed in run 37693779148 (17 captures plus primary icon/right-click Settings/Quit). Build source e96caef remains identical; only UI-test query and checkpoint changed. Publisher verifies both required build jobs and SDL test plus the passing UI run and rejects any application/build-input changes between them.
- Preview 5 is a separate download; keep Preview 4 README links and older releases intact. Physical Intel Tahoe audio/input/renderer behavior while hidden remains to be tested against a real host.

- Preview 5 published successfully at tag native-glass-6.2-preview-5 via run 37694314866 and commit 43527e1ef2bf2c2a5d9dd92c379f4f6bbe608abd. Both packages, checksums and 11 composited screenshots uploaded. About/menu captures visually inspected; fixed About text and build 5 verified. Preview 4 retained. README adds separate Preview 5 links on native-ui/master; master code stays stock 6.2.


## Preview 14: Control Center follow-up, October 8, 2026

- Continue in `th3d3ck3r/moonlight-native-glass`, branch `native-ui`. The older Enhanced `liquid-ui` branch is not this application's current working branch. Master application sources remain the stock baseline; only its README differs.
- Preview 14 retains the pending fixes for toolbar button tracking: return the consumed title-bar mouse-up to SDL so its focus-click state clears; remove native panels before restoring stream mouse/keyboard focus; preserve capture across stale focus-loss events. Explicit Control Center requests work independently of the removed enable switch. Default Show / Hide Controls is Control–Option–Shift–O. Plain Disconnect remains Control–Option–Shift–B; Close Stream Window remains Control–Option–Shift–Q and hides the stream.
- Built application source: `1d6a23957a0976fa83cd66dda5981aa178139a6b`. [Validation run 37769667726](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/37769667726) passed both full build jobs: x86_64 and Universal, bundled signatures/dependencies/architecture audits, native overlays, real SDL stream-window lifecycle/input, event framing, real engine bridge/settings persistence, frontend failure recovery and menu-bar state. That run's overall failure came from the Settings test query/click, subsequently corrected; do not describe the overall run as successful.
- SDL's relative mode uses system cursor disassociation and does not require a nonempty Cocoa confinement rectangle without an explicit grab. The regression now compares fresh relative-mode state to restored state and routes native motion through SDL before/after controls in windowed, desktop-fullscreen and exclusive-fullscreen modes. The nonempty Cocoa confinement assertion remains for the visible Control Center pointer. Synthetic native events are not a physical mouse/live-host streaming test.
- [Final UI validation run 37771230158](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/37771230158), revision `a8028666d570bf2bb9cef48afd74b07e638d5357`, passed all five XCTest tests with zero failures, including Overlay disclosure expansion and Add Button visibility, Settings screens, Dock reopen, menu-bar lifecycle and About. Only the XCTest source differs from the full-build revision; application/resource/build inputs are identical. Disclosure controls are queried by accessibility identity and the actual arrow is clicked using its observed AX frame, after window activation.
- Both Preview 14 packages are available as build artifacts: [Intel](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/37769667726/artifacts/11546704780), [Universal](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/37769667726/artifacts/11547304999). No new release or README update was made. Keep Preview 6 and other releases intact.
- Physical Intel Tahoe retest still required: default settings, open Control Center by title-bar click and Control–Option–Shift–O; confirm the local cursor is visible/confined, click Done and immediately test movement/clicks on the host. Repeat in all three window modes and across repeated opens; test plain Disconnect and the close/hide shortcut. Hosted native window tests do not establish live capture, connectivity or decoder performance on the user's Mac.

## Native app reliability audit, October 8, 2026

- User requested a whole-app audit to reduce recurrence. Reviewed the entire custom native frontend/bridge/presentation layer and its upstream integration boundaries; findings, coverage and remaining live-host checks are in [NATIVE_APP_AUDIT.md](NATIVE_APP_AUDIT.md). This does not certify every upstream/dependency line or replace physical Intel streaming validation.
- Final application revision `757c9471011fe11e0f2a10335bafc6620ed2e778` fixes failed Add/Pair state, live broken-pipe recovery, rejected/silent pending launches, late cancelled pause replies (per-launch request IDs), implicit quit-confirmation dismissal, false crash reports for deliberate cancellation, per-frame decoding limits and malformed typed-event recovery. Helper event ownership/shutdown guards are explicit. Library text distinguishes Disconnect from Disconnect and Exit.
- Failure/framing tests run before expensive builds. Expanded real-pipe fixtures cover missing/closed stdin, Refresh after a broken pipe, live rejection, cancel/retry acknowledgement order, confirm-vs-dismiss ordering, quiet cancellation, actual preparation timeout, malformed events and busy launch guards. The real built bridge echoes each pause request ID and retains settings persistence behavior. Streaming-core hooks and their reviewed hashes remain unchanged.
- [Run 37774999668](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/37774999668) completed successfully for that exact revision: full Intel and Universal builds, 105-file Mach-O dependency/architecture audits, signatures, overlay/SDL window-input checks, engine framing/failure/bridge/persistence/status checks and all five native UI tests with zero failures. Compact library, expanded Overlay customization and Shortcuts captures reviewed. Runtime tests used arm64 macOS 26.6.2/Xcode 26.6.0; physical Intel remains untested.
- Audited Preview 14 artifacts: [Intel](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/37774999668/artifacts/11549692572), [Universal](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/37774999668/artifacts/11550003271). This supersedes the earlier Preview 14 artifacts for these audit fixes. No release, version bump, README change or master code change was made. Prior audit runs were superseded during builds and are not final validation.
- Physical acceptance remains: real host movement/clicks immediately after Control Center Done, repeated title-bar/shortcut cycles across all three modes, capture already released, absolute mouse/pointer lock, Settings/app focus changes, controller/host reconnects, cancellation/retry and host removal during network completion. Automated checks reduce risk; no claim that bugs can never recur.
