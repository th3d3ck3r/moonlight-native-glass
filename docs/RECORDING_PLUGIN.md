# MoonlightLG recording plugin — 1.2.00U (build 33)

Recording work is isolated on `feature/recording-plugin`. The known-good rollback
checkpoint is `checkpoints/moonlightlg-1.1.03U-before-recording`, commit
`798eedd508911131ad78df8800345493ac72990c`. No merge or public U release is authorized.
Recording controls default to disabled. Existing preferences retain their identities.

## Engine adapter

`recording/RecorderABI.h` is a versioned C interface with no Qt, FFmpeg or C++ ABI
objects. `app/native/nativerecorder.mm` loads the signed bundled dylib, checks the
ABI, supplies session configuration, and owns plugin lifetime. The module stays mapped until helper exit so asynchronous system completion blocks can finish unwinding safely. A missing/incompatible
plugin leaves streaming available. A future upstream engine update needs these
small reviewed taps reapplied and the adapter rebuilt; this is not a binary plugin
mechanism supplied by upstream Moonlight.

The reviewed changes relative to the checkpoint are:

- `FFmpegVideoDecoder::submitDecodeUnit`: compressed ingress for both push and pull
  renderers. Borrowed `bufferList` data is copied only while capture is interested.
- Decoded output after the existing RTP PTS assignment and before the existing pacer:
  retain a VideoToolbox pixel buffer only in Custom Hardware Encoding mode.
- Audio configuration and an Opus packet tap before drop/mute/playback-device checks:
  the recorder has its own decoder, so local mute does not silence saved movies. Missing-packet notifications use the negotiated Opus frame duration for concealment rather than shortening the audio timeline.
- Session video setup, post-Continue recording startup, three titlebar actions, fast
  ingress quiescence on disconnect, and finalization after `LiStopConnection` in
  deferred cleanup. No input handlers, network code, common-c, decoder algorithms,
  pacing, renderer implementation, or stock preference schema are changed.

The plugin is independent of the displayed window geometry. It does not capture the
screen, titlebar, startup animation or control center. Mouse work remains deferred. Record / Stop and Save Replay are also available in the menu-bar menu for fullscreen or hidden windows.

## Modes and files

Original Stream Quality copies Annex-B H.264/HEVC into length-prefixed samples,
creates the format description from complete parameter sets, and supplies compressed
samples to AVAssetWriter with nil video output settings. No second video encoder is
created. Stream resolution, FPS and bitrate are retained. AV1/4:4:4, changed format
or reordered source timestamps fail visibly rather than starting an implicit encode.

A manual recording starts on the next usable natural keyframe. Some hosts do not
provide periodic keyframes, so waiting may be indefinite. The plugin does not ask
the host for extra IDRs. Use Custom Hardware Encoding for a controlled local GOP.

Custom Hardware Encoding requires a VideoToolbox decoded pixel buffer and a verified
hardware H.264/HEVC compression session. One encoder supplies recording and replay.
Requested bitrate, resolution and FPS are bounded. Resizing uses a pixel-transfer
session; lower FPS discards frames before encoding. Hardware unavailability, rejected
properties and unsupported HDR report errors. There is no software fallback. This
first U implementation supports SDR custom encoding; source HEVC Main10 can be copied
for HDR, subject to actual file/display validation. HDR metadata correctness and
5.1/7.1 channel layouts require physical-host acceptance testing.

Movies use a QuickTime `.mov` container with AAC audio. The manual writer has no time
cap. Files use unique names in Movies/MoonlightLG or the selected folder. The writer
emits an initial movie fragment after one second and later fragments at ten seconds.
Successful stop finalizes the movie; interrupted partial movies are retained. Recovery
is possible, not guaranteed for every interruption or file system failure.

## Replay and overload

Replay starts with a complete keyframe and evicts whole GOPs. 30/60-second buffers
have a 256 MB payload cap. Five-minute buffers use unlinked private disk files capped
at 2 GB of retained payload. One in-progress save retains its own snapshot, so peak
storage can approach twice the buffer cap plus the destination movie. Metadata and
in-flight samples add overhead. The selected duration is a maximum, not a promise:
missing keyframes and storage limits may shorten or clear the usable buffer.

Ingress uses a fixed 256-slot queue and a 32 MB queued-payload limit. Producers do
not wait for a playback mutex, an encoder, or disk writes. A bounded enqueue failure
stops the recorder conservatively instead of dropping a compressed reference frame
and pretending the recording remains valid. The stream continues. Save Replay runs
on a separate export queue and leaves capture active. Only one save is allowed at a
time. AAC is encoded by each output writer; video is shared without a second encode.

When controls are disabled, the plugin is not loaded. When enabled but neither
recording nor replay is active, frame ingress returns at the bridge's atomic interest
check. Encoding, packet copies and replay buffering are inactive.

## Research and validation

Primary references consulted:

- [Opus multistream decoding](https://opus-codec.org/docs/opus_api-1.5/group__opus__multistream.html): missing-packet concealment requires the exact missing frame duration.

- [AVAssetWriterInput output settings](https://developer.apple.com/documentation/avfoundation/avassetwriterinput/outputsettings): nil passes samples through.
- [Hardware encoder requirement](https://developer.apple.com/documentation/videotoolbox/kvtvideoencoderspecification_requirehardwareacceleratedvideoencoder): unsupported or busy hardware can fail.
- [Movie fragments](https://developer.apple.com/documentation/avfoundation/avassetwriter/moviefragmentinterval): partially written movies may remain playable.
- [H.264 parameter-set format descriptions](https://developer.apple.com/documentation/coremedia/cmvideoformatdescriptioncreatefromh264parametersets(allocator:parametersetcount:parametersetpointers:parametersetsizes:nalunitheaderlength:formatdescriptionout:)).
- [Real-time writer readiness](https://developer.apple.com/documentation/avfoundation/avassetwriterinput/isreadyformoremediadata).

Portable parser/RTP rollover and three-producer queue stress checks pass locally.
macOS plugin tests generate compressed source video and Opus audio, record and save
replay, decode the resulting movies, exercise hardware capability failure and disk
failure, and measure the disabled submission path. Full macOS/Xcode, existing UI,
startup, disconnect, fullscreen, bundle and shutdown validation are required before
sharing a U package. Validation results will be recorded after those jobs complete.

CI cannot prove unchanged latency/frame time on the owner's host. Physical Intel,
Apple Silicon, HDR, surround, long-duration recordings, window resizing/minimizing
and simultaneous replay/recording need owner hardware measurements before promotion.
