"""Protect the stock streaming core; permit only reviewed native UI/action hooks."""
import hashlib
import pathlib
import subprocess

BASE = "de2467e433821664cdd2224aad8c89a625be1ad9"
REVIEWED = {'app/streaming/input/mouse.cpp': 'ac2d7c48c44b46f2c3d69d9ae9389112595570a6b80da8c950d724f5cac92621', 'app/streaming/input/input.cpp': '9b7a5da739d2bf1514513ca2228ebc7a6360436c21117930dbaecf7cc695b159', 'app/streaming/input/input.h': '83048758d4f56f90b0f7c373d5d4c7044e6b3f14084d237b49b5bc1fb8be1c75', 'app/streaming/input/keyboard.cpp': 'f5bf84eb294c346c16442eb2ba5ecb572d3fc9f930ec83307f5348fcf4e6c539', 'app/streaming/session.cpp': '67073d8b73590041769af3fbbcf1bb9f48fd430451c6f4ec566cb03b855177e9', 'app/streaming/video/overlaymanager.cpp': '2b7a28b1a95efd0e0c210d9f2e9f192d1177d0ae74148bd6d37ea5743a619c6f', 'app/streaming/video/overlaymanager.h': '1bc455255b21b2433d73d2e54772852070be9155a034bd50367a7419b8ef94af', 'app/streaming/video/ffmpeg-renderers/vt_metal.mm': '9e9c713c3a0e8754616bdc1f6fbaff166d04ceb40aa5ec1e568d735d88acdf87', 'app/streaming/video/ffmpeg-renderers/vt_avsamplelayer.mm': '1594ff88b111303b76d242ee7ff4c8a80f1f5c0b573740d44ab1db891e142920'}
paths = subprocess.check_output(["git", "diff", "--name-only", BASE, "--", "app/streaming", "app/backend", "app/settings", "moonlight-common-c", "qmdnsengine"], text=True).splitlines()
for path in paths:
    assert path in REVIEWED, f"Unreviewed streaming/backend change: {path}"
    assert hashlib.sha256(pathlib.Path(path).read_bytes()).hexdigest() == REVIEWED[path], f"Streaming UI hook changed without review: {path}"
print("Stock backend, settings, decoding, timing and common-c unchanged; reviewed native presentation/action hooks verified")
