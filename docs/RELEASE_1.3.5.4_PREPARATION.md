# MoonlightLG 1.3.5.4 release preparation — ON HOLD

The owner authorized preparation only. Do not publish, create a public release tag, mark a release latest, or change public download links until the owner explicitly gives the go.

- Prepared version: 1.3.5.4, stable-labelled internal build 52; Apple Silicon package only.
- Validated application/source commit: `0998e563c5e237bc3cc8a81cd55a38897d253877`.
- Required macOS validation: run `41361342517`, success, including ARM/Intel/Universal, UI, Touch Bar, connection/window/input and package checks.
- Required Xcode validation: run `41361342458`, success, including Startup Preview build/run and UI Preview tests.
- Prepared bundle: `MoonlightLG-1.3.5.4-Release-Ready`, artifact `13104984227`, run `41362813832` (success). Includes M1 app, complete corresponding source, licenses/notices/source manifest, checksums, screenshots, release notes and publication-hold metadata. Artifact retention is 90 days.
- App SHA-256: `47f75467eb98998994b0e7d8568a0d0ea297d2005e2f7402e0fa05b1a3e69342`.
- Source SHA-256: `425aed2e3c19db642e6d36742e9823e08299f319a45cc831c39a173c0ad6f13b`.
- Bundle SHA-256: `79fbb06274ca19db3952225d51bf8f86f87a68c55605bc9b690ee8d1aa74f070`.
- Staging verified all 107 Mach-O files ARM64-only, stable version/build metadata, package checksums, source commit and all 36 dependency source archive checksums.

## Publication access blocker

GitHub Actions draft release creation returned HTTP 403, `Resource not accessible by integration`, in run `41362607674`. No draft was created. The preparation workflow was changed to read-only repository permissions and artifact staging; it contains no release-create or release-publish command. Resolve release-write access through authorized permissions before publication; do not bypass the denial.

Final inspection confirmed no `moonlightlg-v1.3.5.4` public tag or release. Latest public release remains `moonlightlg-v1.3.2.0`, with its downloads unchanged. Nothing was published.

Physical M1 Touch Bar placement/full-width behavior and real-host playback remain on-device acceptance limits, as stated in the release notes. Existing owner photos demonstrate the in-stream layout, not every action or the latest library placement fix.

After the explicit go, recheck the exact source, artifact integrity/availability and release permissions, publish the approved assets, then update public README/changelog links and status. Preserve source correspondence, licenses, existing release history and the user version scheme. Do not rebuild/relabel the verified ZIP merely to publish it.
