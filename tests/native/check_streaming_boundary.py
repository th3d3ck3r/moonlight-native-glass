"""Protect the stock streaming core; permit only reviewed native UI/action hooks."""
import hashlib
import pathlib
import subprocess

BASE = "de2467e433821664cdd2224aad8c89a625be1ad9"
REVIEWED = {'app/streaming/input/mouse.cpp': 'a817f3e23855eb579c281ef7f2edbb1d0c5af6e2f813493a3e9d4360de8c4b5f', 'app/streaming/input/input.cpp': '64eadb2ce7e04b5f5b6891c7bb26a2af1244731dba8520a7d3805baf05dfb819', 'app/streaming/input/input.h': '9c1e72097c87912845bd235463467c0ae8f8ffde37d4fafd6f49dafd28da0f3d', 'app/streaming/input/keyboard.cpp': '038c61f8846dcec67bbf41373de21205e7e6b16ec90594ce0ea3dd58216181ec', 'app/streaming/session.cpp': '5e4912f4cf9b6c95f42129592fc53b43dd67ca866af8baabf02e4ea315caa54b', 'app/streaming/video/overlaymanager.cpp': '2b7a28b1a95efd0e0c210d9f2e9f192d1177d0ae74148bd6d37ea5743a619c6f', 'app/streaming/video/overlaymanager.h': '1bc455255b21b2433d73d2e54772852070be9155a034bd50367a7419b8ef94af', 'app/streaming/video/ffmpeg-renderers/vt_metal.mm': '9e9c713c3a0e8754616bdc1f6fbaff166d04ceb40aa5ec1e568d735d88acdf87', 'app/streaming/video/ffmpeg-renderers/vt_avsamplelayer.mm': '1594ff88b111303b76d242ee7ff4c8a80f1f5c0b573740d44ab1db891e142920'}
paths = subprocess.check_output(["git", "diff", "--name-only", BASE, "--", "app/streaming", "app/backend", "app/settings", "moonlight-common-c", "qmdnsengine"], text=True).splitlines()
for path in paths:
    assert path in REVIEWED, f"Unreviewed streaming/backend change: {path}"
    assert hashlib.sha256(pathlib.Path(path).read_bytes()).hexdigest() == REVIEWED[path], f"Streaming UI hook changed without review: {path}"
print("Stock backend, settings, decoding, timing and common-c unchanged; reviewed native presentation/action hooks verified")
