"""Compile the shared Smoke accretion shaders/art for app and hosted connection.

The cache is source/SDK keyed, so the helper and frontend reuse one compilation.
Both bundles own their resources: SwiftUI ShaderLibrary.bundle(.main) and
NSImage(named:) must work when the connection view runs in the Qt/SDL helper.
"""
import hashlib
import json
import pathlib
import shutil
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
shader = ROOT / 'macos-native/Sources/SmokeAccretion.metal'
shaders = [shader, ROOT / 'macos-native/Sources/TouchBarMoonPulse.metal']
catalog = ROOT / 'macos-native/Resources/Assets.xcassets'
output = pathlib.Path(sys.argv[1]).resolve()
sdk = subprocess.check_output(['xcrun', '--sdk', 'macosx', '--show-sdk-path'], text=True).strip()
inputs = [*shaders, pathlib.Path(__file__), *sorted(p for p in catalog.rglob('*') if p.is_file())]
digest = hashlib.sha256(sdk.encode())
for path in inputs:
    digest.update(str(path.relative_to(ROOT)).encode()); digest.update(path.read_bytes())
key = digest.hexdigest()
cache = ROOT / 'build/visual-resources' / key
marker = cache / 'visual-resources.json'
if not marker.exists():
    cache.mkdir(parents=True, exist_ok=True)
    air_files = []
    for source in shaders:
        air = cache / (source.stem + '.air')
        subprocess.run(['xcrun', '--sdk', 'macosx', 'metal', '-std=metal3.1', '-mmacosx-version-min=15.0',
                        '-c', str(source), '-o', str(air)], check=True)
        air_files.append(str(air))
    subprocess.run(['xcrun', '--sdk', 'macosx', 'metallib', *air_files,
                    '-o', str(cache / 'default.metallib')], check=True)
    subprocess.run(['xcrun', 'actool', '--compile', str(cache), '--platform', 'macosx',
                    '--minimum-deployment-target', '15.0', '--target-device', 'mac',
                    '--output-format', 'human-readable-text', '--notices', '--warnings', str(catalog)], check=True)
    assert (cache / 'Assets.car').is_file(), 'Asset compiler did not produce Assets.car'
    marker.write_text(json.dumps({'source_sha256': hashlib.sha256(shader.read_bytes()).hexdigest(),
                                 'shader_sha256': {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in shaders},
                                 'catalog_cache_key': key}, sort_keys=True) + '\n')
output.mkdir(parents=True, exist_ok=True)
for name in ['default.metallib', 'Assets.car', 'visual-resources.json']:
    shutil.copy2(cache / name, output / name)
print('Packaged Smoke accretion Metal library and artwork:', output, flush=True)
