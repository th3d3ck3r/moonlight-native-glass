"""Validate the delivered bundle, including every nested Mach-O slice."""
import pathlib
import plistlib
import re
import subprocess
import sys

app = pathlib.Path(sys.argv[1])
required = {"x86_64", "arm64"} if sys.argv[2] == "universal" else {"x86_64"}
for bundle, identity in [(app, "com.moonlight-stream.NativeGlass"),
                         (app / "Contents/Helpers/MoonlightEngine.app", "com.moonlight-stream.NativeGlass.Engine")]:
    info = plistlib.loads((bundle / "Contents/Info.plist").read_bytes())
    assert info["CFBundleIdentifier"] == identity
    assert bool(info.get("LSUIElement", False)) == (bundle != app), "Only the frontend may own a Dock application icon"
    assert info["NSLocalNetworkUsageDescription"]
    assert "_nvstream._tcp" in info["NSBonjourServices"]
    assert (bundle / "Contents/MacOS" / info["CFBundleExecutable"]).is_file()
    icon_name = info["CFBundleIconFile"]
    icon = bundle / "Contents/Resources" / (icon_name if icon_name.endswith(".icns") else icon_name + ".icns")
    assert icon.read_bytes() == (app / "Contents/Resources/moonlight.icns").read_bytes(), f"{bundle}: mismatched Dock icon"

assert (app / "Contents/Resources/boot-animation.mp4").read_bytes() == pathlib.Path("macos-native/Resources/boot-animation.mp4").read_bytes(), "Boot animation resource differs"
assert (app / "Contents/Resources/full-moon.png").read_bytes() == pathlib.Path("macos-native/Resources/full-moon.png").read_bytes(), "Menu bar full moon resource differs"

helper = app / "Contents/Library/Helpers/MoonlightAWDLHelper"
assert helper.is_file(), "AWDL helper was not bundled"
daemon = plistlib.loads((app / "Contents/Library/LaunchDaemons/com.moonlight-stream.NativeGlass.AWDLHelper.plist").read_bytes())
assert daemon["BundleProgram"] == "Contents/Library/Helpers/MoonlightAWDLHelper"
assert daemon["Label"] == "com.moonlight-stream.NativeGlass.AWDLHelper"
assert daemon["MachServices"] == {daemon["Label"]: True}
assert "ProgramArguments" not in daemon, "Use the bundled SMAppService helper, never a shell command"

checked = 0
for file in app.rglob("*"):
    if not file.is_file() or file.is_symlink():
        continue
    description = subprocess.check_output(["file", "-b", str(file)], text=True)
    if "Mach-O" not in description:
        continue
    slices = set(subprocess.check_output(["lipo", "-archs", str(file)], text=True).split())
    assert required <= slices, f"{file}: missing {required - slices}"
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
