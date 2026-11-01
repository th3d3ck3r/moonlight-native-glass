"""Compare supplied and optimized shaders on a real GPU, then report GPU timings.

The reference is test-only. No additional functions or libraries enter app bundles.
Times describe the CI GPU, not guaranteed physical M1/Touch Bar frame rates.
"""
import pathlib
import platform
import subprocess

root = pathlib.Path(__file__).resolve().parent.parent
build = root / 'build/smoke-shader-performance'
build.mkdir(parents=True, exist_ok=True)
wrapper = r'''
// Test-only dispatch wrapper: evaluate the production stitchable entry points.
kernel void smokeProbe(device float4 *output [[buffer(0)]],
                       constant float *p [[buffer(1)]],
                       uint2 gid [[thread_position_in_grid]]) {
    uint width = uint(p[0]), height = uint(p[1]);
    if (gid.x >= width || gid.y >= height) return;
    float2 size = float2(width, height) / p[9];
    float2 position = (float2(gid) + 0.5) / p[9];
    half4 result;
    if (p[8] != 0.0) {
        result = smokeAccretionStrip(position, half4(0.0), size,
                                    p[2], p[3], p[4], p[5], p[6], p[7]);
    } else {
        result = smokeAccretion(position, half4(0.0), size,
                               p[2], p[3], p[4], p[5], p[6], p[7], 0.0);
    }
    output[gid.y * width + gid.x] = float4(result);
}
'''
for name, source in [
    ('reference', root / 'tests/native/fixtures/SmokeAccretionReference.metal'),
    ('optimized', root / 'macos-native/Sources/SmokeAccretion.metal')
]:
    staged = build / (name + '.metal')
    staged.write_text(source.read_text() + wrapper)
    subprocess.run(['xcrun', '--sdk', 'macosx', 'metal', '-std=metal3.1', '-mmacosx-version-min=15.0',
                    '-c', str(staged), '-o', str(build / (name + '.air'))], check=True)
    subprocess.run(['xcrun', '--sdk', 'macosx', 'metallib', str(build / (name + '.air')),
                    '-o', str(build / (name + '.metallib'))], check=True)
executable = build / 'smoke-shader-performance'
subprocess.run(['xcrun', 'swiftc', '-swift-version', '5', '-parse-as-library',
                '-target', platform.machine() + '-apple-macos15.0',
                str(root / 'tests/native/SmokeShaderPerformanceTests.swift'), '-o', str(executable)], check=True)
subprocess.run([str(executable), str(build)], check=True, timeout=90)
