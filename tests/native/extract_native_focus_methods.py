"""Compile production focus decisions in the SDL/AppKit integration fixture.

The fixture supplies SDL-backed capture and a no-network key-release sink so
these lifecycle decisions can be exercised without an active streaming host.
"""
import pathlib

source = pathlib.Path("app/streaming/input/input.cpp").read_text()
methods = []
for name in ("notifyFocusLost", "notifyFocusGained"):
    start = source.index("void SdlInputHandler::" + name + "()")
    body = source.index("{", start)
    depth = 1
    end = body + 1
    while depth:
        depth += (source[end] == "{") - (source[end] == "}")
        end += 1
    methods.append(source[start:end])
pathlib.Path("build").mkdir(exist_ok=True)
pathlib.Path("build/NativeFocusMethods.inc").write_text("\n\n".join(methods))
