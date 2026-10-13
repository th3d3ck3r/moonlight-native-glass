# Stream statistics cards and graphs

Development version **1.3.1.0U**, internal build **40**. Application/test source `2e8ef9d605819bcbd87967290b8a9ae7154dfa2a`. Full GitHub validation passed.

The existing native stream statistics surface now uses the hardware monitor's Crimson Glass palette, rounded material, uppercase field labels, bold values and crimson sparklines. Video resolution/codec metadata and every diagnostic value remain present. Labels are shortened for readability; accessibility labels retain the original field names and values. Unknown fields remain textual and wrap rather than being misread as numeric metrics.

Measured FPS, bitrate, network/jitter drops, network RTT, host processing, decode, queue and rendering time can be charted. Host latency charts use the reported average (the third min/max/average value), while the original three values remain displayed. RTT variance and bitrate peaks remain in the text. Missing/nonfinite/negative values are graph gaps, never invented zeroes. History is bounded to 60 seconds and 120 samples per metric, keyed by field identity. Disappeared fields are removed. Closing statistics clears history. Resize/theme/graph toggles do not generate samples; snapshot revisions ensure each production update is consumed once.

Graphs default On. A persistent Graphs button in the panel and Show Graphs toggle in Overlay settings switch to compact value cards when Off. Existing overlay size/position settings remain effective. Wide panels use two columns; narrow/tall content scrolls after input release. A 32-point top reservation keeps the new header below title controls. Notifications/status messages retain their existing text and material treatment.

While host capture is active, the entire statistics panel and its content pass clicks through. On intentional release, Graphs and scrolling become accessible without taking keyboard/main focus. Graphs uses MLStreamToolbarButton, the same tracked release and parent-window/session-scoped repair as the title row. No new engine action, streaming/decoder timing, audio gain, recording tap, permission, or pairing change is introduced.

The parser/history fixture covers original metadata, bitrate/peak preservation, host average selection, RTT/variance, unavailable/invalid readings, bounded histories and disappeared fields. Local ordinary and ASan/UBSan parser tests passed. Native overlay tests cover graph persistence, compact height, unchanged video geometry, unchanged sample count on toggles and captured pass-through. Actual SDL/AppKit input tests exercise the graph button and prior capture restoration. Full native/Xcode and bundle validation are required before distributing builds.

The first preview pass exposed a two-point document/viewport height mismatch that kept a scrollbar visible on otherwise fitting cards. Document height now matches the viewport when content fits, and the outer panel uses the same crimson outline as hardware monitoring. A first real numeric sample appears as a dot before a line history exists. The shutdown fixture now waits for its actual main-queue barrier with a finite three-second deadline rather than assuming a 150 ms drain is sufficient under cold AppKit/ASan load; all original teardown assertions remain.

An unsanitized window fixture timed out in AppKit’s green-widget remote tiling-menu loop before reaching statistics controls. The sampled stack identified delayed hover during hide/restore. The general fixture now resolves its still-live window by ID when keyboard focus is temporarily nil, parks only when relative mode is off, and sends native zero-delta departure motion on every pump. The separate native green-button/top-hover regression remains unchanged, as do all 13/-7 relative-routing assertions. This is a test-only change.


## Completed validation

- Native macOS run `38439419368`: Intel job `115441798594`, Universal job `115441798152` and UI smoke job `115441798638` passed. UI suite: 12 tests, zero failures.
- Xcode run `38439419451`, job `115442501438`: fresh/incremental full app, embedded engine, source ZIP setup, startup preview and root UI suite passed. UI suite: 12 tests, zero failures.
- Quick regression run `38439419364`, job `115441797865`: shutdown/E fallback, overlay cards/toggle, fullscreen/Metal and actual input tracking/sanitizer tests passed.
- Stock-platform run `38439419462`: Windows, macOS, AppImage and Steam Link passed.
- Actual graph-button mouse tracking, prior capture restoration, intentional release, fullscreen/borderless/green-button hover, ordinary and ASan/UBSan routing checks passed with the original 13/-7 relative-motion assertions retained. No production input algorithm was changed.
- Recording mux/decode, source audio vs playback-volume boundary, packaged Apollo/window identity, engine bridge/persistence and 200 shutdown cycles passed.
- Polished Graphs On/Off captures inspected: matching crimson border, compact values-only layout, and no scrollbar when all cards fit. First samples are points; history grows from real subsequent updates.

The Intel artifact `11835390844` was downloaded and independently inspected: version **1.3.1.0U**, build **40**, Intel app/engine/recorder slices, and app ZIP SHA-256 `a1fdcc10ec01d5708b05e75dd225b7906b18d09583307d6acc0a808a4388b28e`, matching the packaged checksum file.

The Universal artifact `11834918331` passed the CI bundle audit for Intel + Apple Silicon. GitHub reports artifact archive digest `sha256:41401864623fb4484b5b0752dd8153869981475b5f5e70d2c8109d36a348000a`. The workspace connection went offline during its final local download check, so an additional independent unzip/checksum inspection of that download was not completed. CI audited both bundles and generated their SHA-256 files before uploading; no package was relabeled. U links are shared directly with the owner only.

Checkpoint: `checkpoints/moonlightlg-1.3.0.0U-before-stream-cards`, at `a7d9507ed1340de9d89e45756836478be7403bc6`. Physical Intel/host acceptance remains an owner check; CI runs native tests on Apple Silicon and cross-builds Intel. Leak detection is disabled for AppKit/SDL sanitizer fixtures, while address/undefined-behavior checks remain active.
