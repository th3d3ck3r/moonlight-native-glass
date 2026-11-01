"""Compile the shared procedural connection view for the SDL window owner."""
import pathlib, subprocess, sys, tempfile
root = pathlib.Path(__file__).resolve().parent.parent
output = pathlib.Path(sys.argv[1]).resolve()
arches = sys.argv[2:]
assert arches and set(arches) <= {'arm64', 'x86_64'}
output.parent.mkdir(parents=True, exist_ok=True)
sdk = subprocess.check_output(['xcrun', '--sdk', 'macosx', '--show-sdk-path'], text=True).strip()
sources = [root / 'macos-native/Sources' / name for name in ['EngineProtocol.swift', 'NativeCrimsonTheme.swift', 'SmokeAccretionScene.swift', 'MoonlightLGTouchBarArt.swift', 'NativeConnectionView.swift']]
sources.append(root / 'macos-native/ConnectionHost/NativeConnectionHost.swift')
with tempfile.TemporaryDirectory() as temp:
    slices = []
    for arch in arches:
        target = pathlib.Path(temp) / (arch + '.dylib')
        subprocess.run(['xcrun', 'swiftc', '-swift-version', '5', '-parse-as-library', '-emit-library', '-O', '-sdk', sdk,
            '-target', arch + '-apple-macos15.0', '-module-name', 'MoonlightLGConnection',
            '-Xlinker', '-install_name', '-Xlinker', '@rpath/libMoonlightLGConnection.dylib',
            *map(str, sources), '-o', str(target)], check=True)
        slices.append(str(target))
    subprocess.run(['lipo', '-create', *slices, '-output', str(output)], check=True)

subprocess.run([sys.executable, str(root / 'scripts/build-visual-resources.py'), str(output.parent.parent / 'Resources')], check=True)
