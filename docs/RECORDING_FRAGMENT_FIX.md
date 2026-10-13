# MoonlightLG 1.2.0.2U fragmented keyframe hotfix

User confirms 1.2.0.1U mouse fixes work. Original Stream Quality stops immediately with the generic recorder queue-overloaded message.

The old adapter and plugin cap a frame at 128 fragments, independently of byte size or actual queue occupancy. A keyframe fragmented into 129 pieces is rejected as overload even when the recorder queue is empty. ABI 4 allows up to 65,536 fragments under the unchanged 32 MB frame/ingress byte budget. Normal frames use 128 inline metadata entries; larger frames reuse thread-local pointer metadata, bounded to 1 MiB per decoder thread on 64-bit systems. Payload is copied only once by the plugin. No producer waits for the worker. Allocation failures stay inside the adapter and are reported through a nonallocating rejection callback.

Regression tests exercise the actual adapter collector at 128/2,048/excessive fragment counts, metadata reuse and invalid/oversized input. Functional tests split valid H.264 keyframes with a valid filler NAL into 1,024 fragments, save recording/replay and decode them with audio. Error messages distinguish fragment limits, frame bytes, queue bytes/items, invalid input and memory failure. Mouse/presentation/centering/keyframe-request code is unchanged.

Checkpoint: `checkpoints/moonlightlg-1.2.0.1U-before-recorder-fragments` at `f802a61a6a0edfd57fc579f85727d0453cb6bd8a`.

Validated production source: `a6374ae8454d2855817f9fbb240c07138951ac48`.

- [Recorder functional/sanitizers](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38346575613) passed ABI 4 loading/rejection, collector boundaries/reuse, valid H.264 keyframes split into 1,024 fragments, recording/replay decoding of 240 frames with AAC audio and zero test drops, stop/restart, custom resized HEVC and explicit input/queue failure diagnostics. Normal and ASan/UBSan runs passed; leak detection was not enabled.
- [Full native validation](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38346575493): Intel and Universal packages audited 107 Mach-O files each, identity/dependencies/permissions/signatures; actual SDL Apollo/centering/fullscreen/title-bar/drag/input and window lifetime sanitizer checks passed. UI suite: 12 tests, zero failures. Packaged bridge/persistence and immediate shutdown checks passed.
- [Full Xcode](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38346575647): fresh/incremental full app, embedded engine, source-ZIP setup and 12 UI tests passed.
- [Stock platform builds](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/38346575833): Windows, macOS, AppImage and Steam Link passed.
- Downloaded app ZIPs verified as 1.2.0.2U/build 36, correct plugin CPU slices/export and no test/sanitizer fixtures. Intel SHA-256 `396772964dcfee16be965c21a8367b93de5b3ceeefd1b859f5467ecc8621bf95`; Universal SHA-256 `c104fd8b8055349b904adeaab318df6cc728bf1582616f4303fcd34164864d05`.

Native mouse/presentation/centering source is identical to the owner's working 1.2.0.1U checkpoint. No public U release or app download links were posted.

This fixes a proven false-overload path; the actual owner's frame fragmentation and sustained recorder throughput still require live-host acceptance. CI does not establish unchanged physical Intel latency/frame time.
