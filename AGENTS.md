# MoonlightLG project maintenance

The application/project is MoonlightLG. The GitHub repository name and URL stay
`th3d3ck3r/moonlight-native-glass`. Crimson Glass is the appearance theme name.
Preserve the existing bundle identifiers, preference domains, IPC notification
names and upstream engine identities for compatibility with settings, host pairing
and macOS permissions. Do not rebrand upstream copyright/license attribution.

## Versions (user-required)

The user-facing scheme is `redesign.major.minor.hotfix`, without leading zeros.
The current development version is **1.2.0.0U**. Each component is a nonnegative
integer with no decimal rollover: `1.2.9.0` → `1.2.10.0` → `1.2.11.0`.

- `U`: unreleased development work. Share U build links only directly with the user.
  Do not post them as public releases or README/changelog download links. CI app
  artifacts remain available for the user's testing.
- `E`: experimental build (e.g. **1.2.0.0E**).
- No suffix: stable release (**1.2.0.0**).

Maintain versions autonomously when changing this project:

1. Increment once per completed production change set, not once per edit/CI retry.
   Urgent corrections increment hotfix; small improvements increment minor;
   substantial features increment major; large UI/architecture redesigns increment
   redesign. Reset components after the incremented component to zero.
   Documentation/test-only edits do not bump a version.
2. Store all four numeric components in `macos-native/Info.plist` MoonlightLGVersion.
   Keep MoonlightLGReleaseChannel separate (`U`, `E`, or `stable`). Apple requires
   three components in CFBundleShortVersionString: use the first three components
   of MoonlightLGVersion. Keep CFBundleVersion as the separate increasing internal
   build number, distinguishing hotfixes even with the same Apple short version.
3. Channel promotion U → E → stable preserves the numeric version. Before each
   distributed bundle iteration, increase CFBundleVersion monotonically.
4. New development after a distributed version uses the next numeric version + U.
   Update the changelog, README and EngineProtocol.swift development fallbacks and
   version-specific UI assertions with Info.plist. Preserve archived release names,
   links and historical validation evidence. The old 1.2.00U test packages remain
   accurately labeled; the version-format migration is 1.2.0.0U, internal build 34.
5. Package names derive from metadata via scripts/moonlightlg-version.py;
   About uses the same numeric/channel metadata. Do not manually relabel an
   already validated/signed package. Complete macOS/Xcode checks before delivery.

## Validation and scope

Audit source before building. Run checks appropriate to the change and finish
required macOS/Xcode validation before delivering packages. Preserve the existing
stream-owned dialog, safe disconnect/E cleanup, title-bar/fullscreen behavior,
input confinement and finite startup lifecycle. Avoid unrelated streaming-core,
networking, decoder or settings changes. Existing streaming-boundary hashes may
change only for reviewed native UI/action hooks. Report physical-host/Intel limits
honestly; CI cross-builds Intel on Apple Silicon.
