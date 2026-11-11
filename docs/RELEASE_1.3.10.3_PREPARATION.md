# 🌙 MoonlightLG 1.3.10.3 release record

[MoonlightLG 1.3.10.3](https://github.com/th3d3ck3r/moonlight-native-glass/releases/tag/moonlightlg-v1.3.10.3) is published as the latest stable release.

- Stable build 68 promotes the tested build 67 behavior with stable version metadata.
- The release tag and complete corresponding source point to `81ff5546ded40b641ed3a581e4a5cd3a6fe69bcd`.
- Apple Silicon, Intel and Universal package checks and Touch Bar tests passed in [macOS validation](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/42832034198).
- Exact-source [Xcode validation](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/42832034270) passed on retry after an artifact upload timeout.
- GitHub repeatedly cancelled the UI smoke job before assigning an Apple Silicon runner. An alternate Intel runner repeatedly timed out on accessibility queries. The complete UI suite subsequently passed on an Apple Silicon runner in the [successful publication run](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/42935239013).
- Publication verified app/source checksums, 107 ARM64-only Mach-O files, and all 36 dependency source archive checksums. All 12 uploaded release assets were verified by digest before marking the release public and latest.
- Apple Silicon ZIP digest `sha256:76dbc4512e66687002a1237892fcb7a0797d206ea194de21d296ebf1e1e4d1ce`.
- Complete corresponding source digest `sha256:a0f4a79c7cb8b378387a77d59f499a253a6f301577fde520f2fd767267c4871d`.

Asynchronous Metal Presentation remains off by default. The owner reported a modest improvement on the M1 trackpad with it enabled. Physical-host latency, all Touch Bar gestures, HDR and long recording playback remain on-device acceptance limits.
