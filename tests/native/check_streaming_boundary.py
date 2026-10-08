"""Protect the stock streaming core; permit only reviewed native UI/action hooks."""
import hashlib
import pathlib
import subprocess

BASE = "de2467e433821664cdd2224aad8c89a625be1ad9"
REVIEWED = {'app/streaming/input/mouse.cpp': 'a817f3e23855eb579c281ef7f2edbb1d0c5af6e2f813493a3e9d4360de8c4b5f', 'app/streaming/input/input.cpp': '62e85652e9d4d2152922d13d1acad050d9a78f55037dd92b454d572bd594ed9b', 'app/streaming/input/input.h': 'fc11c1128b573bddb2fb558e8914485fcc9a937a9209b76d1a6f8483e0a75e70', 'app/streaming/input/keyboard.cpp': '185c34302e0888be27e38b4fb788fb451bb8ee4790e6776fc78856e89b03cdaa', 'app/streaming/session.cpp': 'b7a477dcb4781096ac8ae09d5a0920720ebc39fd7b5ae61d2172fdec1b9139ff', 'app/streaming/video/overlaymanager.cpp': '2b7a28b1a95efd0e0c210d9f2e9f192d1177d0ae74148bd6d37ea5743a619c6f', 'app/streaming/video/overlaymanager.h': '1bc455255b21b2433d73d2e54772852070be9155a034bd50367a7419b8ef94af', 'app/streaming/video/ffmpeg-renderers/vt_metal.mm': '9e9c713c3a0e8754616bdc1f6fbaff166d04ceb40aa5ec1e568d735d88acdf87', 'app/streaming/video/ffmpeg-renderers/vt_avsamplelayer.mm': '1594ff88b111303b76d242ee7ff4c8a80f1f5c0b573740d44ab1db891e142920'}
paths = subprocess.check_output(["git", "diff", "--name-only", BASE, "--", "app/streaming", "app/backend", "app/settings", "moonlight-common-c", "qmdnsengine"], text=True).splitlines()
for path in paths:
    assert path in REVIEWED, f"Unreviewed streaming/backend change: {path}"
    assert hashlib.sha256(pathlib.Path(path).read_bytes()).hexdigest() == REVIEWED[path], f"Streaming UI hook changed without review: {path}"
print("Stock backend, settings, decoding, timing and common-c unchanged; reviewed native presentation/action hooks verified")
