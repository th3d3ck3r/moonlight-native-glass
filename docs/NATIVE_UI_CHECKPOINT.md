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
