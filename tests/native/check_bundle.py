"""Validate the delivered bundle, including every nested Mach-O slice."""
import pathlib
import hashlib
import plistlib
import re
import subprocess
import sys

app = pathlib.Path(sys.argv[1])
architecture = sys.argv[2]
assert architecture in {"arm64", "x86_64", "universal"}, "Unknown bundle architecture"
required = {"x86_64", "arm64"} if architecture == "universal" else {architecture}
for bundle, identity in [(app, "com.moonlight-stream.NativeGlass"),
                         (app / "Contents/Helpers/MoonlightLGEngine.app", "com.moonlight-stream.NativeGlass.Engine")]:
    info = plistlib.loads((bundle / "Contents/Info.plist").read_bytes())
    assert info["CFBundleIdentifier"] == identity
    assert info["CFBundleDisplayName"] == ("MoonlightLG" if bundle == app else "MoonlightLG Engine")
    assert info["CFBundleName"] == ("MoonlightLG" if bundle == app else "MoonlightLG Engine")
    if bundle == app:
        assert re.fullmatch(r"(?:0|[1-9][0-9]*)(?:\.(?:0|[1-9][0-9]*)){3}", info["MoonlightLGVersion"])
        assert info["CFBundleShortVersionString"] == ".".join(info["MoonlightLGVersion"].split(".")[:3])
        assert info["MoonlightLGReleaseChannel"] in {"U", "E", "stable"}
        assert info["CFBundleExecutable"] == "MoonlightLG"
    assert bool(info.get("LSUIElement", False)) == (bundle != app), "Only the frontend may own a Dock application icon"
    assert info["NSLocalNetworkUsageDescription"]
    assert "_nvstream._tcp" in info["NSBonjourServices"]
    assert (bundle / "Contents/MacOS" / info["CFBundleExecutable"]).is_file()
    icon_name = info["CFBundleIconFile"]
    icon = bundle / "Contents/Resources" / (icon_name if icon_name.endswith(".icns") else icon_name + ".icns")
    expected_icon = pathlib.Path("macos-native/Resources") / ("crimson.icns" if bundle == app else "moonlight.icns")
    assert icon.read_bytes() == expected_icon.read_bytes(), f"{bundle}: mismatched Dock icon"

assert (app / "Contents/Resources/boot-animation.mp4").read_bytes() == pathlib.Path("macos-native/Resources/boot-animation.mp4").read_bytes(), "Boot animation resource differs"
assert (app / "Contents/Resources/full-moon.png").read_bytes() == pathlib.Path("macos-native/Resources/full-moon.png").read_bytes(), "Menu bar full moon resource differs"

for name in ["boot-moon.png", "crimson-moon.png", "crimson-full-moon.png", "crimson.icns"]:
    assert (app / "Contents/Resources" / name).read_bytes() == (pathlib.Path("macos-native/Resources") / name).read_bytes(), f"Missing or mismatched artwork: {name}"

# Inspect the real ICNS representation, not an assumed Dock mask.
subprocess.run(["/usr/bin/swift", "-e", r'''import AppKit
let image = NSImage(contentsOfFile: CommandLine.arguments[1])!
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
for (x,y) in [(0,0),(bitmap.pixelsWide-1,0),(0,bitmap.pixelsHigh-1),(bitmap.pixelsWide-1,bitmap.pixelsHigh-1)] {
    precondition(bitmap.colorAt(x:x,y:y)!.alphaComponent < 0.01, "Dock asset must have transparent rounded corners")
}
print("Native Dock icon corner transparency verified")
''', str(app / "Contents/Resources/crimson.icns")], check=True)

assert (app / "Contents/Helpers/MoonlightLGEngine.app/Contents/Frameworks/libMoonlightLGConnection.dylib").is_file(), "Missing stream-window connection view"

legal = app / "Contents/Helpers/MoonlightLGEngine.app/Contents/Resources/Legal"
for name in ["index.html", "GPL-3.0.txt", "THIRD_PARTY_NOTICES.txt", "SOURCES.json", "ModeSeven-font.txt"]:
    assert (legal / name).is_file() and (legal / name).stat().st_size > 0, f"Missing legal notice: {name}"
import json
inventory = json.loads((legal / "SOURCES.json").read_text())
components = {entry["id"] for entry in inventory["components"]}
assert {"qtbase", "qtdeclarative", "qtsvg", "ffmpeg", "sdl3", "sdl-ttf", "opus", "openssl", "libplacebo", "moltenvk"} <= components
assert "WITHOUT ANY WARRANTY" in (legal / "THIRD_PARTY_NOTICES.txt").read_text()
for component in inventory["components"]:
    assert component["ref"] != "from-binary" and component["sha256"]
    assert component["notices"], f"Missing original notices for {component['name']}"
    for notice in component["notices"]:
        path = legal / notice["path"]
        assert path.is_file() and hashlib.sha256(path.read_bytes()).hexdigest() == notice["sha256"], f"Changed legal text: {path}"
for name in inventory["local_notices"]:
    assert (legal / name).is_file(), f"Missing original source-submodule notice: {name}"

checked = 0
for file in app.rglob("*"):
    if not file.is_file() or file.is_symlink():
        continue
    description = subprocess.check_output(["file", "-b", str(file)], text=True)
    if "Mach-O" not in description:
        continue
    slices = set(subprocess.check_output(["lipo", "-archs", str(file)], text=True).split())
    assert required <= slices, f"{file}: missing {required - slices}"
    if architecture == "arm64":
        assert slices == {"arm64"}, f"{file}: Apple Silicon-only package contains {slices}"
    dependencies = subprocess.check_output(["otool", "-L", str(file)], text=True)
    # otool -L also lists a dylib's own LC_ID_DYLIB. It is an identity,
    # not an edge that must resolve through this image's runpath list.
    install_names = set(line.strip() for line in
                        subprocess.check_output(["otool", "-D", str(file)], text=True).splitlines()
                        if line.strip().startswith(("@rpath/", "@loader_path/", "@executable_path/")))
    nearest_app = next(parent for parent in file.parents if parent.suffix == ".app")
    frameworks = nearest_app / "Contents/Frameworks"
    for line in dependencies.splitlines():
        if not line.startswith("\t"):
            continue
        dependency = line.strip().split(" (", 1)[0]
        if dependency in install_names:
            continue
        if dependency.startswith(("/System/Library/", "/usr/lib/", "/Library/Apple/System/Library/")):
            continue  # Apple libraries may live only in the dyld shared cache.
        if dependency.startswith("@rpath/libswift"):
            continue  # Swift runtime is supplied by supported macOS versions.
        if dependency.startswith("@rpath/"):
            candidate = frameworks / dependency[len("@rpath/"):]
            if not candidate.exists():
                # Xcode's preview/debug executor declares @executable_path as
                # an LC_RPATH and loads its debug dylib beside the executable.
                # Require that actual runpath before accepting this location.
                load_commands = subprocess.check_output(["otool", "-l", str(file)], text=True)
                if re.search(r"cmd LC_RPATH\s+cmdsize \d+\s+path @executable_path \(offset \d+\)", load_commands):
                    candidate = nearest_app / "Contents/MacOS" / dependency[len("@rpath/"):]
            assert candidate.exists(), f"{file}: unresolved bundled dependency {dependency}"
        elif dependency.startswith("@loader_path/"):
            candidate = file.parent / dependency[len("@loader_path/"):]
            assert candidate.exists(), f"{file}: unresolved loader dependency {dependency}"
        elif dependency.startswith("@executable_path/"):
            candidate = nearest_app / "Contents/MacOS" / dependency[len("@executable_path/"):]
            assert candidate.exists(), f"{file}: unresolved executable dependency {dependency}"
        else:
            # Mach-O dylib IDs are also listed by otool -L; a relative ID can
            # name this file itself. Absolute SDK/Homebrew links are rejected.
            assert not dependency.startswith("/"), f"{file}: external dependency {dependency}"
    checked += 1
assert checked >= 2, "No native app and engine found"
print(f"Validated bundle permissions, identities, library dependencies and {checked} Mach-O files: {sorted(required)}")

