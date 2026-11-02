# MoonlightLG 1.3.6.0 — publication authorized, access blocked

The owner authorized release after private build 55 and requested the established emoji README style. This lifts the earlier preparation-only hold for this version. GitHub release-create access is still unresolved; no public release/tag or new public download link may be asserted before publication succeeds.

## Exact stable source

- Version: 1.3.6.0, stable-labelled internal build 56.
- Application/source commit: `11ed502e0b301ac632d92eaa7fd23f3322c127ed`.
- Functional baseline: build 55, `cff1f15b84d4edf0759364673b030d801886ebd6`; build 56 changes stable metadata and fallback labels only, with release documentation. No ZIP is relabelled.
- macOS validation: [41388931149](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/41388931149), success.
- Xcode validation: [41388931202](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/41388931202), success.

## Bundle staging

The read-only preparation workflow targets the exact successful runs above. It verifies stable build 56 metadata, app/source checksums, every nested Mach-O architecture and all dependency-source archive hashes, then stages the M1 app, corresponding source, legal files, screenshots, release notes and the post-publication README as a 90-day Actions artifact. No release creation is attempted.

### Verified bundle

- [MoonlightLG-1.3.6.0-Release-Ready](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/41390729937/artifacts/13116774963), artifact `13116774963`, preparation run `41390729937` (success), retained 90 days.
- Includes the stable M1 app, complete corresponding source, checksums, GPL/notices/source manifest, screenshots, release notes, post-publication README and publication/access metadata.
- App SHA-256: `e9f567b3ccec0e9391a3e39df9c97171e290f1244af83db3fc0c58678505ffd3`.
- Source SHA-256: `5b8af324bb6cd3b5323305f4e5e3c5b4420cdd932f2f4406883199a2ac5e84fd`.
- Complete Actions bundle SHA-256: `ef37198a2e0e6798bb085511dbf661455c06a9e4e703b5601d964c053d34e4bb`.
- Staging verified all 107 nested Mach-O files ARM64-only and all 36 dependency-source archive checksums.
- Exact-source macOS run passed ARM, Intel, Universal, Touch Bar, UI, connection/window/input, recording and sanitizer checks. Exact-source Xcode run passed clean/incremental app builds, embedded engine/source setup, Startup Preview build/run and UI Preview tests.
- Final public-state inspection: latest remains `moonlightlg-v1.3.2.0`; `moonlightlg-v1.3.6.0` tag is absent. No draft/public release was created by this work; no publication retry, branch merge or branch deletion occurred.

## Publication access

The previous draft attempt, run `41362607674`, job `125015990550`, returned HTTP 403, `Resource not accessible by integration`, at `gh release create`. Its token summary already advertised Contents: write; merely repeating that setting is not evidence that the failure is resolved. No draft was created.

The current connector supports repository edits and Actions reads but exposes no release-create/upload/publish operation. Repository metadata reports push/admin access; that does not establish release-create capability. No new publication attempt or credential/interface fallback was made. Resolve authorized release-write access before any publication. The preparation workflow remains contents/actions read-only and contains no release-create or release-publish command.

## Prepared presentation

- [Release notes](RELEASE_1.3.6.0.md).
- [Complete post-publication README](README_1.3.6.0_RELEASE.md): emoji sections, M1 download table, screenshots, features, install/controls, validation and source/credits. This is staged copy; its new release links become live only after the matching assets are published.
- Branch README describes the upcoming version while preserving working 1.3.2.0 public download destinations.
- Publish the exact stable app and complete corresponding source together with checksums, notices and source manifest. Update public README/download status only after asset availability is confirmed. Do not merge/delete branches or publish the superseded 1.3.5.4 preparation.

## Hardware limits

Physical M1 graph legibility, gestures, animation cadence, private full-width compatibility and long recording playback remain owner acceptance limits. Software validation does not establish zero physical-hardware regressions. The removed Mac button remains removed.
