"""Validate the delivered bundle, including every nested Mach-O slice."""
import pathlib
import plistlib
import subprocess
import sys

app = pathlib.Path(sys.argv[1])
required = {"x86_64", "arm64"} if sys.argv[2] == "universal" else {"x86_64"}
for bundle, identity in [(app, "com.moonlight-stream.NativeGlass"),
                         (app / "Contents/Helpers/MoonlightEngine.app", "com.moonlight-stream.NativeGlass.Engine")]:
    info = plistlib.loads((bundle / "Contents/Info.plist").read_bytes())
    assert info["CFBundleIdentifier"] == identity
    assert info["NSLocalNetworkUsageDescription"]
    assert "_nvstream._tcp" in info["NSBonjourServices"]
    assert (bundle / "Contents/MacOS" / info["CFBundleExecutable"]).is_file()

checked = 0
for file in app.rglob("*"):
    if not file.is_file() or file.is_symlink():
        continue
    description = subprocess.check_output(["file", "-b", str(file)], text=True)
    if "Mach-O" not in description:
        continue
    slices = set(subprocess.check_output(["lipo", "-archs", str(file)], text=True).split())
    assert required <= slices, f"{file}: missing {required - slices}"
    checked += 1
assert checked >= 2, "No native app and engine found"
print(f"Validated bundle permissions, identities and {checked} Mach-O files: {sorted(required)}")
