"""Protect the stock streaming core; permit only reviewed native UI/action hooks."""
import hashlib
import pathlib
import subprocess

BASE = "de2467e433821664cdd2224aad8c89a625be1ad9"
REVIEWED = {'app/streaming/input/mouse.cpp': 'a817f3e23855eb579c281ef7f2edbb1d0c5af6e2f813493a3e9d4360de8c4b5f', 'app/streaming/input/input.cpp': '916893f825c34b33da1fcc4042e9144260ffb0416b05a2b86ac72e0a48ffd9ad', 'app/streaming/input/input.h': '8d606ae162efa6b2afd3b0272a346d4c474acbb98b07f106eeb7b39cbea736f8', 'app/streaming/input/keyboard.cpp': '2e6f63decde07aac2c4d6453ee8ab004ffe457f189aff806e6b48b0069b9ddcb', 'app/streaming/session.cpp': '6ba5c118d3cb0012523af42ccfd8a8f3318cd75c7c0f00640fde33d66c588613', 'app/streaming/video/overlaymanager.cpp': '2b7a28b1a95efd0e0c210d9f2e9f192d1177d0ae74148bd6d37ea5743a619c6f', 'app/streaming/video/overlaymanager.h': '1bc455255b21b2433d73d2e54772852070be9155a034bd50367a7419b8ef94af', 'app/streaming/video/ffmpeg-renderers/vt_metal.mm': '9e9c713c3a0e8754616bdc1f6fbaff166d04ceb40aa5ec1e568d735d88acdf87', 'app/streaming/video/ffmpeg-renderers/vt_avsamplelayer.mm': '1594ff88b111303b76d242ee7ff4c8a80f1f5c0b573740d44ab1db891e142920'}
paths = subprocess.check_output(["git", "diff", "--name-only", BASE, "--", "app/streaming", "app/backend", "app/settings", "moonlight-common-c", "qmdnsengine"], text=True).splitlines()
for path in paths:
    assert path in REVIEWED, f"Unreviewed streaming/backend change: {path}"
    assert hashlib.sha256(pathlib.Path(path).read_bytes()).hexdigest() == REVIEWED[path], f"Streaming UI hook changed without review: {path}"
print("Stock backend, settings, decoding, timing and common-c unchanged; reviewed native presentation/action hooks verified")
