# Moonlight Native Glass — RC1

Release Candidate 1 promotes the verified native UI build 15 with Moonlight Qt engine 6.2.0. Intel and Universal packages require macOS 15 or later. Updates remain manual.

This is a testing release. Remaining errors are still being investigated; please report reproducible problems through GitHub Issues. RC1 is not a stable-release claim.

## Downloads and installation

- Intel: `Moonlight-Native-Glass-RC1-x86_64.zip`
- Apple Silicon or Intel: `Moonlight-Native-Glass-RC1-universal.zip`
- Verify downloads with `SHA256SUMS.txt`.

Extract the ZIP, move Moonlight Native Glass.app into Applications and open it through Finder. Allow Local Network access and pair your host in this app. Packages use verified ad-hoc signatures, not Developer ID signing or notarization.

## Changes since the published previews

- Full Screen/Borderless hide and reopen now exit the desktop/Space before hiding and restore through the SDL event loop outside AppKit notification callbacks.
- Native title controls stay suppressed during fullscreen and hidden-window transitions.
- Native input capture and real relative mouse routing are checked after controls and restore.
- Both crescent/full-moon menu bar states have rounded corners.
- About reports the native UI build and bundled Moonlight engine version separately.
- Native helper ownership ends before Qt platform/logger teardown; eight repeated immediate launch/exit cycles passed after the shutdown fix.
- Expanded real-helper settings validation, persistence, invalid/stale-host recovery, transport failure and cancellation/retry tests.

Control–Option–Shift–Q hides the stream window; Control–Option–Shift–O toggles controls; Control–Option–Shift–B disconnects without quitting the host game. Disconnect and Exit also quits the host game. Bindings are customizable.

## Validation

[Run 37795784286](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/37795784286) passed all three required jobs for exact application/test source `7202a71c8f6224ea5cdad29c7e8e58434d9e66ac`: complete Intel/Universal builds and 105-Mach-O bundle audits; all five native UI tests; both stock macOS fullscreen startup/Metal/hide/reopen fixtures; actual SDL keyboard/mouse/motion lifecycle; all settings schema/type/enum/Boolean checks, atomic validation and persistence; invalid/stale-host recovery; eight immediate helper launch/exit cycles; protocol/error recovery; overlay/shortcut and rounded status-icon checks.

RC1 ZIPs contain the unchanged validated application. About still identifies Native UI Preview 15 and Moonlight engine 6.2.0. The RC1 name labels the promoted release; it does not alter signed binaries or claim a newer engine.

## Known limitations

- Remaining errors are under investigation. Include reproduction steps and engine logs in reports.
- CI runtime testing uses Apple Silicon. Physical Intel/live-host discovery, pairing, audio/input, host operations, reconnects, sleep/wake and display changes are not certified by this run.
- CPU/GPU usage, decode latency and frame pacing were not benchmarked.
- Optional physical exclusive fullscreen retains upstream opt-in limitations. The usual macOS Full Screen and Borderless Full Screen modes are the tested paths.
- Packages are ad-hoc signed and not notarized.

Stock backend, settings policy, common-c, mDNS, decoding and timing implementations remain intact. Reviewed native presentation/input hooks connect the frontend to the Moonlight engine. No streaming-core redesign is included.
