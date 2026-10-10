"""Protect the stock streaming core; permit only reviewed native UI/action hooks."""
import hashlib
import pathlib
import subprocess

BASE = "de2467e433821664cdd2224aad8c89a625be1ad9"
REVIEWED = {'app/streaming/input/mouse.cpp': 'a817f3e23855eb579c281ef7f2edbb1d0c5af6e2f813493a3e9d4360de8c4b5f', 'app/streaming/input/input.cpp': '4db3eddc13da9b753e9c2ddc1422199c05fe3b5db71c5615a51c5c90ecaa6dd1', 'app/streaming/input/input.h': '83048758d4f56f90b0f7c373d5d4c7044e6b3f14084d237b49b5bc1fb8be1c75', 'app/streaming/input/keyboard.cpp': '2e6f63decde07aac2c4d6453ee8ab004ffe457f189aff806e6b48b0069b9ddcb', 'app/streaming/session.cpp': 'fe6eb0a1a72b3cabb02841964d8b44199ce9255a607d293fa9f6255cdb4e23d1', 'app/streaming/video/overlaymanager.cpp': '2b7a28b1a95efd0e0c210d9f2e9f192d1177d0ae74148bd6d37ea5743a619c6f', 'app/streaming/video/overlaymanager.h': '1bc455255b21b2433d73d2e54772852070be9155a034bd50367a7419b8ef94af', 'app/streaming/video/ffmpeg-renderers/vt_metal.mm': '9e9c713c3a0e8754616bdc1f6fbaff166d04ceb40aa5ec1e568d735d88acdf87', 'app/streaming/video/ffmpeg-renderers/vt_avsamplelayer.mm': '1594ff88b111303b76d242ee7ff4c8a80f1f5c0b573740d44ab1db891e142920'}
paths = subprocess.check_output(["git", "diff", "--name-only", BASE, "--", "app/streaming", "app/backend", "app/settings", "moonlight-common-c", "qmdnsengine"], text=True).splitlines()
for path in paths:
    assert path in REVIEWED, f"Unreviewed streaming/backend change: {path}"
    assert hashlib.sha256(pathlib.Path(path).read_bytes()).hexdigest() == REVIEWED[path], f"Streaming UI hook changed without review: {path}"
print("Stock backend, settings, decoding, timing and common-c unchanged; reviewed native presentation/action hooks verified")
