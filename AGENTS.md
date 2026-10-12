# MoonlightLG project maintenance

The application/project is MoonlightLG. The GitHub repository name and URL stay
`th3d3ck3r/moonlight-native-glass`. Crimson Glass is the appearance theme name.
Preserve the existing bundle identifiers, preference domains, IPC notification
names and upstream engine identities for compatibility with settings, host pairing
and macOS permissions. Do not rebrand upstream copyright/license attribution.

## Versions (user-required)

Start the MoonlightLG release line at **1.0.00**. The user-facing scheme is
`major.minor.patch` with at least two patch digits, followed by:

- `U`: unreleased development work (initial version **1.0.00U**). Never post U
  builds as releases, downloadable app artifacts or README download links. CI may
  build/test them; publish only after deliberate promotion to E or stable and validation.
- `E`: experimental build (same numeric version, e.g. **1.0.00E**).
- No suffix: stable release (**1.0.00**).

Maintain versions autonomously when changing this project:

1. Increment once per completed production change set, not once per edit/CI retry.
   Fixes/small UI adjustments increment patch; meaningful compatible features
   increment minor and reset patch to 00; major incompatible revisions increment
   major and reset minor/patch. Documentation/test-only edits do not bump a version.
2. Keep the numeric version in `macos-native/Info.plist` CFBundleShortVersionString.
   Keep the channel in MoonlightLGReleaseChannel (`U`, `E`, or `stable`). Never put
   suffix letters in the numeric Apple bundle version fields.
3. Channel promotion U → E → stable preserves the numeric version. Before each
   distributed bundle iteration, increase numeric CFBundleVersion monotonically;
   retain its count across the old preview/new MoonlightLG naming transition.
4. New development after a distributed version uses the next numeric version + U.
   Update the changelog, README/current download links, and any development-version
   fallbacks in EngineProtocol.swift and version-specific UI assertions together
   with Info.plist. Keep archived release
   filenames/links and historical validation evidence accurate.
5. Package names derive from bundle metadata via scripts/moonlightlg-version.py;
   About uses the same numeric/channel metadata. Do not hardcode a different package
   version or manually change an already validated/signed package's channel.

## Validation and scope

Audit source before building. Run checks appropriate to the change and finish
required macOS/Xcode validation before delivering packages. Preserve the existing
stream-owned dialog, safe disconnect/E cleanup, title-bar/fullscreen behavior,
input confinement and finite startup lifecycle. Avoid unrelated streaming-core,
networking, decoder or settings changes. Existing streaming-boundary hashes may
change only for reviewed native UI/action hooks. Report physical-host/Intel limits
honestly; CI cross-builds Intel on Apple Silicon.
