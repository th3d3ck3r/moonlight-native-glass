#!/usr/bin/env python3
"""Archive tracked app/submodule sources and the exact dependency source archives."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tarfile

ROOT = Path(__file__).resolve().parent.parent


def digest_file(path):
    digest = hashlib.sha256()
    with path.open('rb') as source:
        for block in iter(lambda: source.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def package(output):
    cache = ROOT / 'build/legal-source-archives'
    manifest = json.loads((cache / 'SOURCES.json').read_text())
    version = subprocess.check_output([sys.executable, str(ROOT / 'scripts/moonlightlg-version.py'),
                                      str(ROOT / 'macos-native/Info.plist')], text=True).strip()
    commit = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip()
    files = subprocess.check_output(['git', 'ls-files', '--recurse-submodules', '-z'], cwd=ROOT).decode().split('\0')
    output.parent.mkdir(parents=True, exist_ok=True)
    prefix = 'MoonlightLG-' + version + '-source'
    with tarfile.open(output, 'w:gz', compresslevel=6, dereference=False) as archive:
        for relative in files:
            if relative:
                archive.add(ROOT / relative, arcname=prefix + '/' + relative, recursive=False)
        archive.add(cache / 'SOURCES.json', arcname=prefix + '/third-party-source/SOURCES.json')
        for component in manifest['components']:
            source = cache / component['archive']
            if digest_file(source) != component['sha256']:
                raise RuntimeError('Source archive checksum changed: ' + component['name'])
            archive.add(source, arcname=prefix + '/third-party-source/' + source.name)
        import io
        text = ('Application source commit: ' + commit + '\n'
                'Build instructions: README.md and scripts/build-native-macos.sh\n'
                'All tracked application submodule sources are included.\n'
                'Original dependency source archives and their hashes are in third-party-source/.\n'
                'The dependency recipe v19 archive includes the macOS build scripts and patches.\n').encode()
        info = tarfile.TarInfo(prefix + '/SOURCE_INFORMATION.txt')
        info.size = len(text)
        archive.addfile(info, io.BytesIO(text))
    print('Packaged corresponding source:', output, '(' + str(output.stat().st_size) + ' bytes)')


if __name__ == '__main__':
    package(Path(sys.argv[1]).resolve())
