#!/usr/bin/env python3
"""Prepare the real helper for Xcode without installing global dependencies."""
import hashlib
import json
import os
import pathlib
import platform
import plistlib
import shutil
import subprocess
import sys
import tarfile
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
QT_VERSION = "6.11.2"
AQT_REVISION = "073e34d7c2ab4ae6961ed7cca690b3abd5ba5a7e"


def run(arguments, **kwargs):
    print("Xcode engine:", " ".join(str(a) for a in arguments), flush=True)
    subprocess.run([str(a) for a in arguments], check=True, **kwargs)


def digest_file(path):
    result = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            result.update(block)
    return result.hexdigest()


def python_for_tools(cache):
    # Xcode's bundled Python may be 3.9; the pinned Qt installer needs 3.10+.
    # A verified, private interpreter avoids requiring Homebrew or admin access.
    manifest = json.loads((ROOT / "scripts/xcode-python.json").read_text())
    machine = platform.machine()
    architecture = "arm64" if machine in ("arm64", "aarch64") else "x86_64"
    spec = manifest["architectures"][architecture]
    portable = cache / ("python-" + manifest["release"] + "-" + architecture)
    interpreter = portable / "python/bin/python3"
    if not interpreter.exists():
        portable.mkdir(parents=True, exist_ok=True)
        archive = portable / "python.tar.gz"
        print("Downloading the project's private Python tools", flush=True)
        urllib.request.urlretrieve(spec["url"], archive)
        if digest_file(archive) != spec["sha256"]:
            archive.unlink()
            raise RuntimeError("Private Python download failed its SHA-256 check")
        with tarfile.open(archive) as package:
            package.extractall(portable)
        archive.unlink()
    return interpreter


def prepare_sources():
    environment = os.environ.copy()
    environment["GIT_TERMINAL_PROMPT"] = "0"
    if (ROOT / ".git").exists():
        run(["git", "submodule", "update", "--init", "--recursive"], cwd=ROOT, env=environment)
    else:
        # GitHub's source ZIP omits gitlinks. Fetch those same pinned sources
        # automatically so opening the project still needs no setup commands.
        modules = json.loads((ROOT / "scripts/xcode-submodules.json").read_text())
        for module in modules:
            folder = ROOT / module["path"]
            if not (folder / ".git").exists():
                folder.parent.mkdir(parents=True, exist_ok=True)
                run(["git", "clone", "--no-checkout", module["url"], folder], env=environment)
            run(["git", "-C", folder, "checkout", "--detach", module["commit"]], env=environment)
            run(["git", "-C", folder, "submodule", "update", "--init", "--recursive"], env=environment)


def main():
    if os.environ.get("NATIVE_UI_PREVIEW") == "YES":
        print("UI preview: real engine setup is skipped", flush=True)
        return
    if platform.system() != "Darwin":
        raise RuntimeError("The full Xcode build requires macOS")
    products = pathlib.Path(os.environ["BUILT_PRODUCTS_DIR"])
    cache = ROOT / "build/xcode-dependencies"
    cache.mkdir(parents=True, exist_ok=True)
    python = python_for_tools(cache)
    venv = cache / ("aqt-" + AQT_REVISION)
    tool_python = venv / "bin/python3"
    if not tool_python.exists():
        run([python, "-m", "venv", venv])
    installed = venv / ".installed"
    if not installed.exists():
        run([tool_python, "-m", "pip", "install", "--disable-pip-version-check",
             "git+https://github.com/miurahr/aqtinstall.git@" + AQT_REVISION])
        installed.write_text(AQT_REVISION + "\n")
    qt_root = cache / "qt"
    qmake = qt_root / QT_VERSION / "macos/bin/qmake"
    if not qmake.exists():
        run([tool_python, "-m", "aqt", "install-qt", "mac", "desktop",
             QT_VERSION, "clang_64", "-O", qt_root])
    if subprocess.check_output([str(qmake), "-query", "QT_VERSION"], text=True).strip() != QT_VERSION:
        raise RuntimeError("The Xcode Qt cache has an unexpected version")
    environment = os.environ.copy()
    prepare_sources()
    prebuilt_marker = ROOT / "libs/mac/.xcode-v19"
    if not prebuilt_marker.exists():
        run([python, ROOT / "setup-deps.py"], cwd=ROOT)
        prebuilt_marker.write_text("v19\n")
    architectures = os.environ.get("ARCHS", platform.machine()).split()
    if not architectures or not set(architectures) <= {"arm64", "x86_64"}:
        raise RuntimeError("Unsupported Xcode architecture list: " + repr(architectures))
    build = ROOT / ("build/xcode-engine-" + "-".join(sorted(architectures)))
    build.mkdir(parents=True, exist_ok=True)
    environment.update(CFLAGS="-flto=thin", CXXFLAGS="-flto=thin", LDFLAGS="-flto=thin")
    run([qmake, ROOT / "moonlight-qt.pro", "QMAKE_APPLE_DEVICE_ARCHS=" + " ".join(architectures)],
        cwd=build, env=environment)
    run(["make", "-j" + str(min(os.cpu_count() or 2, 4)), "release"], cwd=build, env=environment)
    raw_app = build / "app/Moonlight.app"
    binary = raw_app / "Contents/MacOS/Moonlight"
    for architecture in architectures:
        run(["lipo", binary, "-verify_arch", architecture])
    # Build incrementally. Deploy/sign only when the engine or recipe changed.
    fingerprint = hashlib.sha256("\n".join(digest_file(path) for path in (
        binary, raw_app / "Contents/Info.plist", pathlib.Path(__file__),
        ROOT / "macos-native/Resources/moonlight.icns")).encode()).hexdigest()
    helper = products / "MoonlightLGEngine.app"
    marker = products / ".moonlight-engine.sha256"
    if helper.exists() and marker.exists() and marker.read_text().strip() == fingerprint:
        print("The bundled engine is up to date", flush=True)
        return
    products.mkdir(parents=True, exist_ok=True)
    if helper.exists():
        shutil.rmtree(helper)
    shutil.copytree(raw_app, helper, symlinks=True)
    run([qmake.parent / "macdeployqt", helper, "-qmldir=" + str(ROOT / "app/gui"),
         "-appstore-compliant", "-no-codesign"])
    mimer = helper / "Contents/PlugIns/sqldrivers/libqsqlmimer.dylib"
    if mimer.exists():
        mimer.unlink()
    info_path = helper / "Contents/Info.plist"
    info = plistlib.loads(info_path.read_bytes())
    info.update(CFBundleIdentifier="com.moonlight-stream.NativeGlass.Engine",
                CFBundleDisplayName="MoonlightLG Engine", CFBundleName="MoonlightLG Engine",
                NSLocalNetworkUsageDescription="MoonlightLG connects to computers on your local network for game streaming.", LSUIElement=True)
    info_path.write_bytes(plistlib.dumps(info, sort_keys=False))
    shutil.copy2(ROOT / "macos-native/Resources/moonlight.icns",
                 helper / "Contents/Resources/moonlight.icns")
    run(["codesign", "--force", "--deep", "--sign", "-", helper])
    marker.write_text(fingerprint + "\n")


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        print("error: Xcode engine setup failed: " + str(error), file=sys.stderr)
        sys.exit(1)
