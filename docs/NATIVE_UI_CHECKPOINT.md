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


## October 8 — Preview 15 fullscreen and expanded acceptance

- Application changes remain on `native-ui` in `th3d3ck3r/moonlight-native-glass`.
  Full Screen and Borderless Full Screen now exit their desktop/Space before
  hiding and restore through a separately registered SDL event outside AppKit
  notification callbacks, using Session's original fullscreen transition.
  Toolbar installation is suppressed during fullscreen/hidden transitions.
  About separates UI build 15 from engine 6.2.0. Both menu bar states are rounded.
- Full run [37790564463](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/37790564463)
  passed all three jobs at application revision `a0c982fd`: both complete builds,
  all five UI tests, real SDL focus/motion/lifecycle, both stock macOS fullscreen
  hint/startup/Metal/hide/restore fixtures, bridge/persistence, status icon pixels.
  Optional physical exclusive focus routing uses a controlled no-auto-minimize
  fixture; its upstream opt-in display auto-minimize limitation is not fixed.
- User subsequently requested broader non-performance app testing. Added every
  settings schema/type/enum/Boolean contract, stale-host and invalid-address
  recovery, and eight repeated immediate helper startup/shutdown cycles.
  Runs `37792252998` and `37793963298` exposed SIGSEGV on helper shutdown.
  The second run completed all broad settings/host checks before a repeated exit
  failed. Crash reports were unavailable on that runner; LLDB failure fallback
  is now included. This was a release-candidate blocker; the cleanup fix below has now passed
  the expanded regression suite. Physical acceptance remains outstanding.
- New application change `977dea4f` scopes NativeBridge and destroys it after
  event-loop/worker completion but before Qt platform/logger teardown. This
  addresses a cleanup-order risk without changing stock manager/decoder code.
  Latest source/test revision `7202a71c8f6224ea5cdad29c7e8e58434d9e66ac`.
  [Run 37795784286](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/37795784286)
  completed with SUCCESS in all three jobs: Intel, Universal and native UI.
  UI timeout is now 10 minutes after the old 5-minute limit cancelled screenshot
  export despite all five tests passing. Every setting/host rejection test, all eight immediate startup/shutdown
  cycles, both actual macOS fullscreen fixtures, native focus/motion/lifecycle,
  icon pixels, all five UI tests and both 105-Mach-O bundle audits passed.
  The shutdown crash did not recur after the ownership change.
- No README/master/release/tag changes, no Xcode project ZIP (user explicitly
  said not to create it). Preserve stream core, decoding, network, bitrate and
  settings policy. Existing source-boundary check passes; changes in Session
  and Input are reviewed native presentation hooks, main.cpp change is native
  helper ownership only. Runtime validation is ARM macOS CI; Intel remains a
  cross-build until physical live-host acceptance.
- RC recommendation: freeze features and require these automated tests plus
  physical host pairing/launch/input/audio/hide/restore/disconnect/reconnect and
  clean-install coverage on claimed macOS/architecture support. Public ordinary
  macOS distribution should use Developer ID signing and notarization; current
  previews are ad-hoc signed. GitHub RC publication should be a pre-release,
  with known limitations and separate UI/engine version numbers.


Final Preview 15 artifacts for validated source `7202a71c`:
[Intel x86_64](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/37795784286/artifacts/11558374986)
and [Universal](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/37795784286/artifacts/11559362612).
Later checkpoint/audit commits contain documentation only. Next step is physical
Intel/live-host acceptance; no release is published by this task. Fullscreen
and icon captures are attached to the same successful run. Both icon states at
standard and Retina sizes were visually reviewed in addition to pixel checks.


## RC1 published — October 8, 2026

- User authorized RC1 publication and README updates while acknowledging remaining errors.
- [RC1](https://github.com/th3d3ck3r/moonlight-native-glass/releases/tag/native-glass-rc1)
  is public with `prerelease=true`, `draft=false`, Intel/Universal ZIPs, SHA-256
  checksums and 13 composited interface screenshots. Tag targets publication
  commit `baa4d9fb8924ee2ece8de02884bb9622314c928a`.
- Promotes unchanged validated application/test source `7202a71c`, native UI
  build 15 and Moonlight engine 6.2.0 from run `37795784286`. Distribution ZIP
  filenames are RC1; About still identifies Native UI Preview 15. No executable,
  resource, signature or engine version was changed for this promotion.
- [Publication run 37868422420](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/37868422420)
  passed exact-source, all-three-job, application-input, master-baseline and
  original package checksum checks, uploaded draft assets, then published.
- README on both native-ui and master now links RC1, current screenshots and
  install instructions, explains seven Settings panes and correct hide/controls/
  disconnect shortcuts, reviewed engine hooks, test coverage and known limits.
  Master commit `de9fcf6951beaa46553b40f849747e9fd81c85de` changes README only.
  All ten README release-asset links were verified against published assets.
- Remaining reported errors are unspecified; do not invent fixes or call RC1
  a stable/bug-free release. Future work should obtain reproduction details and
  preserve protected stock backend/decoder/settings/timing implementations.
  Physical host/Intel coverage and performance are not certified by CI.


## Unreleased Preview 16 — October 9, 2026; shutdown investigation open

User authorized more menu controls, a thumbnail-only hover preview clickable to
restore the stream, and fixing the reported helper error while implementing this.
Keep RC1, master, public README and release/tag assets untouched. No Xcode ZIP.
The user has authorized offering the current build for physical testing while the
intermittent shutdown failure is investigated.

Implemented native UI build 16 (engine metadata remains 6.2.0):
- Stream hide/restore, independent library opening, controls, explicit capture/
  release input, statistics, mute/unmute, session disconnect, and confirmed
  disconnect-and-exit-host-game. Confirmation defaults to Cancel and rechecks
  the session identity before routing commands.
- Windowed/fullscreen/borderless preferences are labeled Next Stream because
  pinned SDL reads its macOS fullscreen policy at video initialization.
- Settings, engine logs, About and existing guarded Quit. Stream actions and
  checked labels follow the current stream state.
- 1.5-second hover delay, nonactivating image-only NSPanel, click/VoiceOver
  restore, 350ms pointer travel grace, cancellation on menu opening/pointer exit/
  stream replacement/end, and generation guards against stale async captures.
- ScreenCaptureKit window snapshots (640px width), cached successful fallback
  when hidden, explicit Allow Stream Thumbnails permission action. No continuous
  capture or streaming frame hook. Without a successful image, no preview.
- Both menu icon states have a cached 4px rounded mask at 18px; original assets
  and Dock icon remain intact.

Application fix source a6c7b7bb5d086afb00fd2b9fa66e17d55ae3a273:
- NativeBridge terminal shutdown rejects further framed requests and disconnects
  adapter callbacks before member destruction. Main retains early bridge teardown.
- Packaged native helpers restrict Qt plugin paths to their canonical PlugIns
  directory, verified despite inherited build-SDK QT_PLUGIN_PATH.
- Native helper initializes OpenSSL before Qt using OPENSSL_INIT_NO_ATEXIT.
  Per-object Qt/SDL/manager cleanup remains normal; shared crypto globals have
  process lifetime. Stock network/decoder/settings/timing/common-c are unchanged.
  The change reduces a teardown risk but is NOT a proven complete crash fix.

Validation and unresolved evidence:
- Full build run 37878107640 succeeded in Intel, Universal and native UI jobs.
  Five UI XTests, menu/thumbnail/status-icon tests, helper preference/protocol/
  recovery checks, terminal-batch regression, actual Metal fullscreen/borderless
  hide/restore/input fixtures, boundary checks and both 105-Mach-O bundle audits
  passed. 100 diagnostic plus 100 ordinary repeated shutdown cycles passed.
- Older baseline failed SIGSEGV; run 37875169429 captured a Qt TLS worker inside
  CRYPTO_THREAD_read_lock / OBJ_sn2nid / TLS server hello while shutting down.
  Plugin contamination and crypto global teardown were investigated.
- Extended current-source run 37878935283: ordinary job failed at cycle 184 with
  SIGILL (-4); diagnostic-injected job passed 1000. Do not treat diagnostic-only
  passes or short ordinary passes as resolution of this ordinary failure.
- Minimal diagnostic run 37879803954 passed 1000, with no fault captured.
- Persistent original-process LLDB probe run 37883034972 timed out at first cycle;
  test I/O was corrected in 2898be748f7d35335957ff3a1e4a497c53e08724.
  Run 37883272349 is the follow-up. This changes diagnostics only, not the app.
- Actual physical Intel/live-host behavior, hidden live Metal thumbnail capture
  under Screen Recording permission, and native streaming performance remain
  unverified. CI image injection verifies thumbnail behavior, not real capture.
- Preview 16 is available for user testing with the known intermittent shutdown
  failure disclosed. It is not cleared for release.

Current test artifacts (verified unexpired and source-matched):
[Intel](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/37878107640/artifacts/11593168821)
and [Universal](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/37878107640/artifacts/11593232681).
These are unreleased ad-hoc-signed artifacts. Do not deliver earlier local ZIPs
from a10/9920 source or silently replace RC1.

Next: inspect the original ordinary fault's full-thread stack; make an evidence-
based fix within native adapter scope; rerun complete builds and extended ordinary
stress. Record failures as well as passes. Local execution environment became
offline during diagnosis; GitHub API/workflow access continues to work.

### Follow-up original-process diagnostics

- Local execution recovered; checkout was fast-forwarded to the saved remote
  changes. The Intel A6 artifact was downloaded and its SHA-256 matched the CI
  checksum: `94157da9dde16e26ae8f64bce619c8affa00720ed1ce74005b4da3a1e2b6561f`.
  The user received the actual inner application ZIP as an unreleased test build.
  Bundle metadata confirms native UI build 16 and engine 6.2.0.
- Debugger protocol fixes ultimately consumed LLDB state events through an
  explicit listener. Run `37883768248` printed all 1000 cycles and
  `PASS: original-process debugger shutdown stress` at 04:45:06 UTC. The job
  was cancelled at its 20-minute limit while destroying the diagnostic debugger
  after that pass. This is completed test evidence, not a green workflow result,
  and it does not resolve the prior ordinary-run SIGILL at cycle 184.
- The next probe runs 2000 ordinary, uninstrumented shutdown cycles with OS core
  dumps enabled on the disposable CI runner. On failure, LLDB examines the
  original core and captures all thread stacks plus loaded images. Only text
  diagnostics are uploaded, not raw core memory. Application code is unchanged.

### Ordinary extended validation completed

- Run `37885722307`, job `113675172114`, completed SUCCESS on October 9 at
  04:59 UTC. It exercised all 2000 ordinary immediate-shutdown cycles, alternating
  test/discovery modes, with the packaged A6 Universal helper and inherited Qt
  SDK environment. All helper startup/settings/persistence/recovery checks also
  passed. No injected module or live debugger was used. No crash/core was observed.
- Text diagnostics artifact `11597030099` contains the complete ordinary test
  log. The accompanying native UI run `37885722414`, job `113675172176`, passed;
  full builds were deliberately skipped because application source was unchanged.
- Combined evidence now includes 2000 ordinary cycles and 1000 debugger-controlled
  cycles without recurrence, plus the original A6 full build validation. This is
  stronger test evidence but does not explain or erase the earlier ordinary
  SIGILL at cycle 184 in run `37878935283`. Keep that intermittent failure open;
  do not call it conclusively fixed or publish Preview 16 as a cleared release.
- No new application code was changed in this diagnostic round. The test ZIP
  already provided remains the source-matched A6 native UI build 16. Physical
  Intel/live-host acceptance (including actual thumbnail capture) remains next.

### Preview 17 mouse focus regression work

- User reports the mouse issue fixed in build 15 returned in build 16, possibly
  after menu bar interaction; exact physical-host trigger is not confirmed.
- Capture Input now uses Done's release/restore-mouse-focus/recapture sequence.
  Native focus loss preserves capture intent across duplicate events, and focus
  gain restores that intent unless controls are visible or input was explicitly
  released. These are native presentation/input hooks; engine version stays 6.2.0.
- SDL/AppKit regression coverage compiles the actual production focus methods,
  using real SDL capture and window focus plus a no-host key-release sink. It
  checks duplicate loss, restored relative mouse motion, explicit release and
  visible controls in each existing window mode. Live streaming remains untested.
- Local boundary and whitespace checks passed. Full macOS builds and integration
  tests are required before delivering preview 17. RC1 and public releases stay
  unchanged. The earlier intermittent shutdown SIGILL remains unexplained.

- Focus gain additionally checks actual SDL keyboard focus, so a stale queued
  event cannot steal focus from another window or consume saved capture intent.

### Preview 17 final validation

- Source `7f3cc0e80642fd003d06c044a9682595883eacf7`, run `37890126899`:
  Intel job `113689010436`, Universal job `113689010430`, and native UI job
  `113689010337` all completed SUCCESS. Production focus handlers compiled
  against real SDL passed duplicate loss, stale gain, actual mouse focus/motion,
  explicit release and controls-visible checks across all existing window modes.
- Fullscreen/borderless startup and composited Metal hide/restore, overlays,
  protocol/failure recovery, menu/thumbnail lifecycle, settings persistence and
  100 diagnostic plus 100 ordinary helper shutdown cycles passed. Both bundle
  audits validated all 105 Mach-O files. These are CI tests, not live host or
  physical Intel streaming acceptance. The user's exact menu trigger still needs
  confirmation, and the earlier intermittent shutdown SIGILL remains unexplained.
- Verified unexpired Intel artifact `11597853266`, Universal `11598163427`.
  Downloaded Intel inner ZIP confirms native UI build 17, engine 6.2.0 and
  SHA-256 `a50644642a4eafca77f2caae7c9a693a49269ae074d7e7890e02287e1c14374f`.
  RC1/master/public README/releases unchanged; Preview 17 is an unreleased test.

### Preview 18 reported shortcut/menu/thumbnail failures

- User has not tested 17. Build 16 reported error 11 after Ctrl-Alt-Shift-E;
  hover showed no thumbnail and menu disconnect/host-exit appeared ineffective.
- Native menu disconnect actions now dispatch session cleanup directly rather
  than queueing another generic SDL_QUIT. The E shortcut and overlay Disconnect
  use that same route. The helper waits for readyForDeletion, deletes Session
  while Qt/SDL are alive, then exits; native E no longer asks for earlier process
  exit. Stock Qt shortcuts, cleanup implementation and streaming engine remain.
- Menu transport uses whitelisted action-specific notification names and the
  stream token, without payload conversion; real separate-process routing tests
  cover every supported action and reject wrong tokens/unknown actions.
- Hover displays a cached image or clickable permission/unavailable fallback
  after the delay, before awaiting capture. Capture denial is no longer silent.
  Permission row remains present to avoid shifting open menu items. Logs now
  retain helper stderr and distinguish termination signals from exit codes.
- No live host teardown or user crash stack is available: these are fixes for
  identified paths, not conclusive proof that error 11 cannot recur. A separate
  intermittent SIGILL from previous ordinary stress also remains unexplained.
- Full app review/testing and both complete builds are pending. Preview 18 is
  private/unreleased; do not publish or alter RC1/master/public README.

### Preview 18 complete builds and audit

- Application source `5d53239f2d01b2951766285ba54cfad4ff150ce6`, run
  `37894048789`: Intel job `113701344983`, Universal `113701344661`,
  native UI `113701344933` all SUCCESS. Production shortcut/focus methods and
  all whitelisted separate-process menu actions passed. Modal confirmation,
  stale token, thumbnail fallbacks and settings/helper lifecycle checks passed.
- Native SDL window fixture also passed under ASan/UBSan with no runtime-error
  report; no full engine sanitization or process-global AppKit leak assertion.
  Fullscreen/borderless composited Metal checks passed. Both 105-Mach-O audits
  passed. Real helper stress passed 100 diagnostic and 100 ordinary cycles.
- Intel artifact `11599678354`, Universal `11600160812`, both unexpired.
  Verified Intel inner ZIP build 18 / engine 6.2.0, SHA-256
  `5a06bbb3238f78f62222dda07ac03d060d9442df2fc63c5b356cd4ec7193a0f1`.
- Audit and explicit untested list: docs/NATIVE_APP_AUDIT_PREVIEW_18.md.
  The reported live E-shortcut error 11 remains unconfirmed without a user
  crash stack/host reproduction; retain the earlier intermittent SIGILL evidence.
- A final UI probe strengthens invalid-host launch coverage using a live process
  fixture and makes future UBSan findings fail immediately. It changes tests/CI
  and documentation only; the verified application code/artifacts are unchanged.
