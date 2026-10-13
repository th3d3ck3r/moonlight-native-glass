"""Compile the complete production audio callback in the no-device fixture."""
import pathlib

source = pathlib.Path("app/streaming/audio/audio.cpp").read_text()
start = source.index("void Session::arDecodeAndPlaySample(")
body = source.index("{", start)
depth, end = 1, body + 1
while depth:
    depth += (source[end] == "{") - (source[end] == "}")
    end += 1
pathlib.Path("build").mkdir(exist_ok=True)
pathlib.Path("build/NativeAudioCallback.inc").write_text(source[start:end] + "\n")
