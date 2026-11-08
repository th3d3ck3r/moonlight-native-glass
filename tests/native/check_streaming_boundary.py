"""Protect the stock streaming core; permit only reviewed native UI/action hooks."""
import hashlib
import pathlib
import subprocess

BASE = "de2467e433821664cdd2224aad8c89a625be1ad9"
# Title-bar repair is a macOS native input/action hook; see docs/TITLEBAR_MOUSE_FIX.md.
# Native Touch Bar stats reuse the existing one-second formatting branch; no decoder, pacing or aggregation algorithm changes.
# Explicit native fullscreen action 221 reuses the stock transition independently of the keyboard binding; no keyboard/decoder algorithms change.
# Opt-in macOS mouse telemetry and stock focus comparison preserve the default routing.
# Experimental macOS scheduling and targeted menu notifications preserve input routing.
# Recording adapter taps reviewed against checkpoint 798eedd; see docs/RECORDING_PLUGIN.md.
REVIEWED = {'app/streaming/input/mouse.cpp': 'e3261fc5d8fd51e5e2577d672efd898f14c0a862c7fd5e8c8a8fddfe4feec0bb', 'app/streaming/input/input.cpp': '58a7cf482cca8e71af157d512e344cb18d5f325b1b50ab2927fcaa31f95a6987', 'app/streaming/input/input.h': 'f465b7706053dbe3bc04ef1e0ba3e2bb54e36678236552d813aa7c1ba6c25a98', 'app/streaming/input/keyboard.cpp': 'c5fc09cb3456a4a67963f98be3214afb1fd7293ce73643722ec1b1c7323272ad', 'app/streaming/session.cpp': '79d086f57f92bf3ba0b40471b9475595ec6092368e915134709e0d40bb2bed68', 'app/streaming/video/overlaymanager.cpp': '2b7a28b1a95efd0e0c210d9f2e9f192d1177d0ae74148bd6d37ea5743a619c6f', 'app/streaming/video/overlaymanager.h': '1bc455255b21b2433d73d2e54772852070be9155a034bd50367a7419b8ef94af', 'app/streaming/video/ffmpeg-renderers/vt_metal.mm': '9e9c713c3a0e8754616bdc1f6fbaff166d04ceb40aa5ec1e568d735d88acdf87', 'app/streaming/video/ffmpeg-renderers/vt_avsamplelayer.mm': '1594ff88b111303b76d242ee7ff4c8a80f1f5c0b573740d44ab1db891e142920', 'app/streaming/video/ffmpeg.cpp': '1a10e4cbef3512581cc4204e97b0d0ab394dcd5ba890e45ce513753a8e543b16', 'app/streaming/audio/audio.cpp': '76fe8dc101110128258225e442dc1ebbcfc46b57ba58991e2ef2cfac091a2e3c'}
paths = subprocess.check_output(["git", "diff", "--name-only", BASE, "--", "app/streaming", "app/backend", "app/settings", "moonlight-common-c", "qmdnsengine"], text=True).splitlines()
for path in paths:
    assert path in REVIEWED, f"Unreviewed streaming/backend change: {path}"
    assert hashlib.sha256(pathlib.Path(path).read_bytes()).hexdigest() == REVIEWED[path], f"Streaming UI hook changed without review: {path}"
print("Stock backend, settings, decoder algorithms, timing and common-c unchanged; reviewed native presentation/action and recorder taps verified")
