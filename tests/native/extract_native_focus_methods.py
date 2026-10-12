"""Compile production focus decisions in the SDL/AppKit integration fixture.

The fixture supplies SDL-backed capture and a no-network key-release sink so
these lifecycle decisions can be exercised without an active streaming host.
"""
import pathlib

def method(path, signature):
    source = pathlib.Path(path).read_text()
    start = source.index(signature)
    body = source.index("{", start)
    depth = 1
    end = body + 1
    while depth:
        depth += (source[end] == "{") - (source[end] == "}")
        end += 1
    return source[start:end]

methods = []
for name in ("notifyFocusLost", "notifyFocusGained", "handleNativeOverlayAction", "nativeMenuCaptureIntent", "isCaptureActive", "setCaptureActive", "updatePointerRegionLock"):
    filename = "keyboard.cpp" if name == "handleNativeOverlayAction" else "mouse.cpp" if name == "updatePointerRegionLock" else "input.cpp"
    returns = "bool" if name in ("nativeMenuCaptureIntent", "isCaptureActive") else "void"
    methods.append(method("app/streaming/input/" + filename, returns + " SdlInputHandler::" + name + "("))
methods.insert(0, method("app/streaming/streamutils.cpp", "void StreamUtils::scaleSourceToDestinationSurface("))
pathlib.Path("build").mkdir(exist_ok=True)
pathlib.Path("build/NativeFocusMethods.inc").write_text("\n\n".join(methods))

header = pathlib.Path("app/streaming/input/input.h").read_text()
start = header.index("    enum KeyCombo {")
end = header.index("};", start) + 2
pathlib.Path("build/NativeKeyCombos.inc").write_text(header[start:end])
