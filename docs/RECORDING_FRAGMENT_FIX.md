# MoonlightLG 1.2.0.2U fragmented keyframe hotfix

User confirms 1.2.0.1U mouse fixes work. Original Stream Quality stops immediately with the generic recorder queue-overloaded message.

The old adapter and plugin cap a frame at 128 fragments, independently of byte size or actual queue occupancy. A keyframe fragmented into 129 pieces is rejected as overload even when the recorder queue is empty. ABI 4 allows up to 65,536 fragments under the unchanged 32 MB frame/ingress byte budget. Normal frames use 128 inline metadata entries; larger frames reuse thread-local pointer metadata, bounded to 1 MiB per decoder thread on 64-bit systems. Payload is copied only once by the plugin. No producer waits for the worker. Allocation failures stay inside the adapter and are reported through a nonallocating rejection callback.

Regression tests exercise the actual adapter collector at 128/2,048/excessive fragment counts, metadata reuse and invalid/oversized input. Functional tests split valid H.264 keyframes with a valid filler NAL into 1,024 fragments, save recording/replay and decode them with audio. Error messages distinguish fragment limits, frame bytes, queue bytes/items, invalid input and memory failure. Mouse/presentation/centering/keyframe-request code is unchanged.

Checkpoint: `checkpoints/moonlightlg-1.2.0.1U-before-recorder-fragments` at `f802a61a6a0edfd57fc579f85727d0453cb6bd8a`.

Validation: pending. Physical host acceptance remains required; frame-time impact is not established by CI.
