# 🌙 MoonlightLG 1.3.7.1 release record

[MoonlightLG 1.3.7.1](https://github.com/th3d3ck3r/moonlight-native-glass/releases/tag/moonlightlg-v1.3.7.1) was published as the latest stable release on November 6, 2026.

- Stable build 61 promotes the recording code from development build 60. CI built fresh stable app and source packages from `22e329f252591b0c6b552ded511c6450b107a1ea`.
- The release tag points to `3f803fe5fbb7b29450b32f6c00e00b80e5921edd`. Only the publication workflow differs from the exact validated build commit.
- [macOS validation](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/42298180675) and [Xcode validation](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/42298180681) passed.
- [Publication run](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/42298365510) verified the staged app and source checksums, all 107 bundled ARM64 Mach-O files and the dependency source hashes. GitHub Actions compared all 12 uploaded asset digests before publishing.
- [Verified release bundle](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/42298365510/artifacts/13543502656) digest `sha256:e1238e496b79d54fe620a39e22c424a36fa01ab99d61eb6247dda56410cc1888`.
- Apple Silicon ZIP digest `sha256:1d6616fd2eb9bcf86af4b34b6a0116b816be3976921edda3a9b449f7aab08a56`.
- Corresponding source digest `sha256:c5ec574217db593e34536e72952bdd42aa0f407025f796902f49ce553eeeb9ea`.

Long HEVC recording and seeking on the owner's VibePollo host remain an on-device check.
