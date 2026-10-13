"""Build the isolated, versioned macOS recording plugin against engine libopus."""
import os
import pathlib
import subprocess
import sys
import tempfile
root = pathlib.Path(__file__).resolve().parent.parent
output = pathlib.Path(sys.argv[1]).resolve()
arches = sys.argv[2:]
sanitizer = ['-g', '-fno-omit-frame-pointer', '-fsanitize=address,undefined', '-fno-sanitize-recover=all'] if os.environ.get("MLG_RECORDER_SANITIZE") == "1" else []
assert arches and set(arches) <= {'arm64', 'x86_64'}
output.parent.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory() as temp:
    slices = []
    for arch in arches:
        target = pathlib.Path(temp) / (arch + '.dylib')
        subprocess.run(['xcrun', 'clang++', '-std=c++17', '-fobjc-arc', '-O2', '-dynamiclib',
                        '-arch', arch, '-mmacosx-version-min=15.0', '-fvisibility=hidden',
                        '-I', str(root / 'libs/mac/include'), '-L', str(root / 'libs/mac/lib'), '-lopus.0',
                        '-framework', 'Foundation', '-framework', 'AVFoundation', '-framework', 'VideoToolbox',
                        '-framework', 'CoreMedia', '-framework', 'CoreVideo', '-framework', 'AudioToolbox',
                        '-Wl,-install_name,@rpath/libMoonlightLGRecorder.dylib',
                        *sanitizer, str(root / 'recording/Recorder.mm'), '-o', str(target)], check=True)
        slices.append(str(target))
    subprocess.run(['lipo', '-create', *slices, '-output', str(output)], check=True)
