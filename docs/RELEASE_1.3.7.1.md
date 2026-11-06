# 🌙 MoonlightLG 1.3.7.1 · Crimson Glass

Apple Silicon · macOS 15+ · internal build 61 · manual updates

## 🎬 Recording fixes

- 🛠️ **Original Stream Quality keeps recording through brief timestamp overlaps.** Duplicate or slightly backward host timestamps are corrected while preserving the encoded video and keyframes. The recorder returns to host timing once it catches up.
- ⏩ **Experimental keyframes for seeking.** In **Settings → Recording → Original Stream Quality**, turn on **Request Keyframes for Seeking (Experimental)** before connecting. The option is off by default. While the recorder is keeping up, it requests a host keyframe at most once every 10 seconds. A missed response alone does not stop the recording.
- 💾 **More tolerant file writing.** Source-copy recording briefly retries a busy writer on the recorder worker, with bounded buffering.
- 🧾 **Persistent diagnostics.** Recording and replay errors, timestamp repairs, and experimental keyframe requests and writes are logged in `~/Library/Logs/MoonlightLG/recording.log`.

## 📦 Downloads & installation

- 🍎 Apple Silicon app — `MoonlightLG-1.3.7.1-arm64.zip`
- 📚 Complete corresponding source — `MoonlightLG-1.3.7.1-source.tar.gz`
- 🔐 `SHA256SUMS.txt`, GPL license, third-party notices and source manifest

Quit the old app, unzip the download and move **MoonlightLG.app** into **Applications**. The app is ad-hoc signed. If macOS blocks the first launch, see **System Settings → Privacy & Security**.

## 🧪 Validation

The macOS regression test injects duplicate and backward timestamps, then decodes every frame in the recording and replay. Long HEVC recordings and seeking on a live VibePollo host remain an on-device check.
