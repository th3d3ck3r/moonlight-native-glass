"""Build bundle-backed artwork/lifecycle tests plus real composited GPU probes."""
import platform
import pathlib
import plistlib
import subprocess
import sys

root = pathlib.Path(__file__).resolve().parent.parent
build = root / 'build/smoke-art-tests'
build.mkdir(parents=True, exist_ok=True)
shared = ['SmokeAccretionScene.swift', 'MoonlightLGTouchBarArt.swift']
fixtures = [
    ('TouchBarFrontend', ['EngineProtocol.swift', 'NativeCrimsonTheme.swift', *shared, 'NativeConnectionView.swift'], 'TouchBarFrontendTests.swift', []),
    ('TouchBarArt', shared, 'MoonlightLGTouchBarArtTests.swift', []),
    ('SmokeScene', shared, 'SmokeSceneRenderTests.swift', [str(root / 'build/smoke-scene-previews')])
]
for name, sources, test, arguments in fixtures:
    app = build / (name + '.app')
    executable = app / 'Contents/MacOS' / name
    executable.parent.mkdir(parents=True, exist_ok=True)
    (app / 'Contents/Info.plist').write_bytes(plistlib.dumps({
        'CFBundleIdentifier': 'com.moonlight-stream.NativeGlass.Tests.' + name,
        'CFBundleExecutable': name, 'CFBundlePackageType': 'APPL',
        'CFBundleName': name, 'LSMinimumSystemVersion': '15.0'
    }))
    subprocess.run([sys.executable, str(root / 'scripts/build-visual-resources.py'), str(app / 'Contents/Resources')], check=True)
    subprocess.run(['xcrun', 'swiftc', '-swift-version', '5', '-parse-as-library', '-target', platform.machine() + '-apple-macos15.0',
                    *[str(root / 'macos-native/Sources' / s) for s in sources],
                    str(root / 'tests/native' / test), '-o', str(executable)], check=True)
    subprocess.run(['codesign', '--force', '--deep', '--sign', '-', str(app)], check=True)
    subprocess.run([str(executable), *arguments, '--design-preview'], cwd=root, check=True, timeout=90)
