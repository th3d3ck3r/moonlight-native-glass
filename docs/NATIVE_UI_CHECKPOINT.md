# Native UI checkpoint

Repository: `th3d3ck3r/moonlight-native-glass` · work branch: `native-ui`.
Untouched Qt 6.2.0 baseline: `de2467e433821664cdd2224aad8c89a625be1ad9` on `master`.
The Enhanced repository is not part of this project.

## Intended result

A SwiftUI/AppKit frontend resembling the earlier Liquid UI: native sidebar,
toolbar, game cards, settings and sheets; system light/dark mode; Liquid Glass
navigation/controls on macOS 26+, ordinary native styling on macOS 15.
Reuse Moonlight's icon, host artwork and SF Symbols. Updates remain manual.
Intel remains a first-class build and physical test target.

## Architecture

The outer native app owns all navigation, settings, pairing sheets and alerts.
A bundled Qt helper exposes a versioned JSON-lines adapter to ComputerManager,
BoxArtManager, StreamingPreferences and the stock CLI launcher. A separate
helper process runs each stream with the original Session and SDL window.
A hidden QQuickWindow passes the selected display to Session; it loads no QML
and never wraps the video surface. Controller handlers in the native library
detach before streaming. Native preferences/certificates use a separate Qt
application name; regular Moonlight and Enhanced settings are not overwritten.

The upstream networking, pairing, certificates, video/audio/input code,
renderer defaults, codec capability checks and persistence implementation have
not been edited. Existing settings property names and enum values are retained.
No Qt update-checker object is instantiated by the native adapter.

## Commits and validation

- `6c4a4b8`: native frontend and engine adapter.
- `4ca1f46`: baseline fetch and app-ID launch selection.
- `bd4a3e8`: native actions and dependency/signature audits.
- Validation run `37581985013`: Intel build passed; Universal compilation,
  bundle audit, framing, real adapter and persistence passed. Window capture
  failed on compact launch; earlier NSView bitmap screenshots omitted layers
  and are unsuitable for visual approval. No preview release published.
- Next change uses WindowServer captures, preview-only state-restoration
  isolation, explicit window identifiers and sample screenshots of sheets,
  empty/offline/unpaired states and every settings pane.

- `65a4b57`: Intel and Universal app builds and adapter checks passed again;
  direct executable launches produced no SwiftUI windows in CI. Capture now
  launches the application bundle through Launch Services, matching Finder.
  A small native-only UI job provides fast feedback before full engine builds.
  Its sample Settings fixture comes from the actual tested helper output.
- Native bitrate controls now match the stock 150/500 Mbps range and clamp
  behavior when higher bitrates are disabled.

## Current validation

Local: shell syntax, Python syntax and whitespace checks pass.
The workspace runs Linux; SwiftUI/AppKit and Qt macOS compilation must run in
`Native macOS Validation`. Both x86_64 and Universal builds are required.
CI verifies nested Mach-O architectures, signatures, bundle identities and
Local Network keys; tests fragmented events, malformed commands, atomic
preference validation and persistence across a real helper restart.
Main-window captures use sample content, visibly labeled Design preview.
They are app-rendered UI screenshots, not proof of host connectivity.

## Next gates

1. Resolve all native compiler, engine build and runtime smoke-test failures.
2. Inspect captured light/dark/compact windows; extend secondary-screen checks.
3. Package a clearly labeled preview only after required checks pass.
4. Physical Intel Tahoe test: Finder launch and Local Network approval;
   discovery/manual address; pairing and relaunch persistence; game launch,
   resume and quit; H.264/HEVC hardware decode; audio/controller/keyboard;
   window/fullscreen/display switching; settings persistence; accessibility.
5. Compare identical stock 6.2.0/native settings and hardware using decode
   time, frame pacing, network statistics, CPU and GPU evidence. Compilation
   and unchanged source do not establish equal streaming performance.

## Known limits to verify

This is a new adapter, not a finished compatibility guarantee. Local Network
attribution for the bundled helper needs Finder-launched physical testing.
Ad-hoc signatures are verifiable but are not Developer ID signing/notarization.
The stream's stock SDL shortcuts and performance overlay remain upstream's.
App hide/unhide and the stock Internet-port test are exposed in native UI;
their host behavior still needs physical verification. No microphone/clipboard enhancements from Enhanced
are implied. Multi-display mapping and interrupted-launch cleanup need runtime
coverage. Physical pairing, streaming and Intel performance are not claimed.

### Composited screenshot gate (October 7)
- `6d94a3d`: main light/dark/compact windows launch; the empty-case launch still passed a separate value argument. All fixture arguments now use equals form.
- CALayer fallback captures omit system glass/sidebar surfaces. These are layout diagnostics only, not visually approved previews.
- Added a UI-only Xcode test target compiling the actual native sources. XCTest captures each native window/sheet with sample content, without loading the engine or changing production signing. Its first CI run is pending.
- Next: inspect XCTest screenshots, resolve any failures, then run ordinary full Intel and Universal validation before a preview release. No release published yet.
