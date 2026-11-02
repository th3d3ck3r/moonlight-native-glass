# 1.3.6.0U build 55 — Touch Bar graphs

Application/source commit: `cff1f15b84d4edf0759364673b030d801886ebd6`.
Inspected baseline: `469b967a0913eb34636fcc87f0266005cb61ea43` (build 54).

## Scope

- Numeric statistics cards gain auto-scaling sparklines with a fixed, rolling 180-second time axis. Current values and accessibility labels remain intact. Categorical cards remain text.
- Each metric retains at most 181 one-second samples. Repeated refreshes do not manufacture samples; unavailable values and inactive intervals break the line. Old spikes leave the scale when they leave the time window. RX/TX share one local-network scale.
- Reuses the existing telemetry parser and hardware sampler, including average host latency. No new timer or stream/recording-core changes.
- Card geometry, button arrangement, routing, Audio/Back ownership, native volume slider, central moon protection, animation assets and full-width lifecycle are unchanged. The removed Mac button stays removed.

## Validation

- Local history tests passed with AddressSanitizer and UndefinedBehaviorSanitizer.
- macOS run [41384321814](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/41384321814): Touch Bar, UI smoke, ARM64 and Intel jobs passed. Universal packaging is still running at this record; delivery targets the owner’s M1. The Touch Bar job also runs sanitized history tests, graph mapping/card-geometry checks, composited moon visibility, Audio/Back lifetime, action routing and full-width fallback/lifecycle tests.
- Xcode run [41384321725](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/41384321725): passed, including clean/incremental builds, embedded engine, source setup, Startup Preview build/run and UI Preview tests.
- CI previews inspected for existing regular/full-width card placement. Synthetic time-window tests exercise expiry/scaling without a three-minute wait.

## Private artifacts

- [M1 app](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/41384321814/artifacts/13114724213), Actions archive SHA-256 `9e78e4fe81e414b98fee910ea5f82f8fd0ba14ad8c12eed72d90f554f0e59272`.
- [Complete corresponding source](https://github.com/th3d3ck3r/moonlight-native-glass/actions/runs/41384321814/artifacts/13115270928), Actions archive SHA-256 `6cf0856b2e7dd4589f68cb83404b007d27809bab1ef445090ab743fe2790407c`.

Physical M1 gestures, graph legibility and private full-width API compatibility remain owner acceptance limits. Software checks cannot establish zero hardware regressions. No public release/tag/download-link change; publication remains on hold.
