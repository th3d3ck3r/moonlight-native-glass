# Optional AWDL stability helper

Work is isolated on `feature/awdl-helper`. The default is **off**. No helper is
registered, installed, or approved by building or launching the app.

## Checkpoint and quick rollback

The pre-feature checkpoint is `checkpoint/pre-awdl-2026-10-11`, commit
`9532df823f7785f75dc6db4bfa93fc4d2ef26683`. It includes the validated Xcode setup
and the existing Preview 20 app sources. `native-ui` stays at this checkpoint
until the new feature is reviewed and validated.

In Xcode, check out the checkpoint branch and build **Moonlight Native Glass**.
For a local Git checkout with no uncommitted work:

```sh
git switch checkpoint/pre-awdl-2026-10-11
```

If the optional helper has been approved, first end all streams, turn the feature
off, and use **Settings → Network → Remove Helper** in the experimental app.
Removal confirms restoration and refuses while another frontend has a live
lease. Switching source branches alone does not unregister a system service.
If the frontend crashes, leases expire after 15 seconds, with a one-second check
interval. Failed restoration retries until the interface becomes available.

## User controls

Settings → Network contains installation, approval settings, refresh, removal,
and **Suppress AWDL while streaming**. Install/approval requires an explicit user
action. Apple-issued, consistently signed builds use `SMAppService.daemon`;
administrator approval is in macOS Login Items & Extensions. Ad-hoc private
builds use an explicit administrator-authorized installer implemented inside the
verified helper executable. It copies the helper to `/Library/PrivilegedHelperTools`,
writes its fixed launchd configuration, and stores the approved frontend signing
requirement in a root-owned file. There is no automatically generated root shell
script and no general-purpose installer RPC. Reinstall the helper after updating
an ad-hoc build so its approved frontend signature is refreshed. Remove Helper
uses the matching installation path and administrator authorization when needed. Copying the app to Applications before approval
is recommended. The helper is bundled under `Contents/Library/Helpers`; its
launchd plist is under `Contents/Library/LaunchDaemons`.

This targets the `awdl0` interface only. Ordinary Wi-Fi, host discovery,
network protocols, streaming input, decoders, and renderer code are unchanged.
AirDrop and AWDL-based AirPlay/Continuity functionality can be unavailable while
suppression is active. It is not a general background traffic limiter.

## Lifetime and security

The frontend acquires a lease only after the real engine reports streaming.
It renews every five seconds. The daemon expires leases after fifteen seconds
and restores AWDL after the last lease disappears. Hiding or minimizing the
stream does not end the lease. Engine exit, normal stream completion, feature
disable, and frontend shutdown release the connection. Preview/test launches
cannot install or activate the service.

The daemon uses ioctl on a hardcoded `awdl0` interface, with no shell execution
or caller-supplied interface names. It preserves the pre-stream up/down state,
journals restoration before disabling an initially up interface, recovers after
daemon restart, and checks once per second for macOS re-enabling AWDL. Idle
checks do not query or modify any interfaces.

Mutual XPC code requirements derive from the executables' actual valid
signatures. The administrator-installed variant reads its approved frontend
requirement from a root-owned, mode 0600 file; it never trusts a user-writable
bundle identifier or user preferences. Ad-hoc builds use designated cdhash requirements; Developer ID
builds retain their designated signing requirements. A bundle ID alone is never
accepted as proof of authorization. The fixed recovery file is root-owned,
mode 0600, created exclusively without following symlinks. Unexpected files at
that path cause startup to fail closed.

## Validation limits

Lease/crash recovery tests inject simulated interfaces and never modify CI
networking. CI compiles both architectures, verifies the helper signature and
packaging, and exercises existing frontend and UI tests. Actual administrator
approval, XPC service launch, Intel/OCLP Wi-Fi driver behavior, Apple sharing
restoration, sleep/wake, and streaming latency require testing on a physical Mac.
No live performance improvement or zero-regression guarantee is claimed.
