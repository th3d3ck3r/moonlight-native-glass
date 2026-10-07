# Native UI checkpoint

Repository: `th3d3ck3r/moonlight-native-glass` · branch: `native-ui`.
`master` remains stock Qt v6.2.0: `de2467e433821664cdd2224aad8c89a625be1ad9`.
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
