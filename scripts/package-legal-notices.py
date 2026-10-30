#!/usr/bin/env python3
"""Bundle original licenses/attributions and exact source archives before signing."""
import concurrent.futures
import ctypes
import hashlib
import html
import json
from pathlib import Path, PurePosixPath
import posixpath
import re
import shutil
import struct
import subprocess
import sys
import tarfile
import time
import urllib.request

ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / 'build/legal-source-archives'
LEGAL_NAME = re.compile(r'license|licence|copying|copyright|notice|authors|^ftl[.]txt$|^ofl[.]txt$', re.I)


def digest_file(path):
    digest = hashlib.sha256()
    with path.open('rb') as source:
        for block in iter(lambda: source.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def font_notices(path):
    data = path.read_bytes()
    results = set()
    for i in range(struct.unpack_from('>H', data, 4)[0]):
        tag, _, offset, _ = struct.unpack_from('>4sIII', data, 12 + 16 * i)
        if tag != b'name':
            continue
        _, count, strings = struct.unpack_from('>HHH', data, offset)
        for j in range(count):
            platform, _, _, name, size, start = struct.unpack_from('>6H', data, offset + 6 + j * 12)
            if name in (0, 7, 8, 9, 13, 14):
                value = data[offset + strings + start:offset + strings + start + size]
                results.add(value.decode('utf-16-be' if platform in (0, 3) else 'mac_roman', errors='replace'))
    if not results:
        raise RuntimeError('The bundled font has no preserved attribution metadata')
    return '\n'.join(sorted(results)) + '\n'


def moltenvk_ref(bundle):
    library = next(bundle.glob('Contents/Frameworks/libMoltenVK*.dylib'), None)
    if library is None:
        raise RuntimeError('Missing packaged MoltenVK for source identification')
    # macdeployqt may have adjusted load commands. Make this build-time load
    # valid on Apple Silicon; the complete bundle is signed again afterward.
    subprocess.run(['codesign', '--force', '--sign', '-', str(library)], check=True)
    driver = ctypes.CDLL(str(library))
    get_version = driver.vkGetVersionStringsMVK
    get_version.argtypes = [ctypes.c_char_p, ctypes.c_uint32, ctypes.c_char_p, ctypes.c_uint32]
    get_version.restype = None
    molten, vulkan = ctypes.create_string_buffer(256), ctypes.create_string_buffer(256)
    get_version(molten, len(molten), vulkan, len(vulkan))
    match = re.search(r'\b(\d+[.]\d+[.]\d+)\b', molten.value.decode())
    if not match:
        raise RuntimeError('Cannot identify the bundled MoltenVK source version')
    print('Resolved packaged MoltenVK source version:', match[1], flush=True)
    return 'v' + match[1]


def download(component):
    target = CACHE / (component['id'] + '.tar.gz')
    url = f"https://codeload.github.com/{component['repo']}/tar.gz/{component['ref']}"
    if not target.exists():
        for attempt in range(3):
            temporary = target.with_suffix('.download')
            try:
                with urllib.request.urlopen(url, timeout=120) as source, temporary.open('wb') as output:
                    shutil.copyfileobj(source, output)
                temporary.replace(target)
                break
            except OSError:
                temporary.unlink(missing_ok=True)
                if attempt == 2:
                    raise
                time.sleep(attempt + 1)
    checksum = digest_file(target)
    return {**component, 'archive': target.name, 'archive_url': url, 'sha256': checksum,
            'source_url': f"https://github.com/{component['repo']}/tree/{component['ref']}"}


def collect_archive(component, destination):
    output = destination / 'components' / component['id']
    output.mkdir(parents=True)
    records = []
    with tarfile.open(CACHE / component['archive'], 'r:gz') as archive:
        files = {}
        for member in archive:
            relative = PurePosixPath(*PurePosixPath(member.name).parts[1:])
            if member.isfile() and relative.parts and '..' not in relative.parts:
                files[str(relative)] = member
        chosen = {p for p in files if LEGAL_NAME.search(PurePosixPath(p).name)
                  or any(part.lower() in ('licenses', 'licences') for part in PurePosixPath(p).parts)
                  or PurePosixPath(p).name == 'qt_attribution.json'}
        # Preserve original Qt copyright/license metadata and any custom-named
        # license files it references, as well as conventional license files.
        for path, member in files.items():
            if PurePosixPath(path).name != 'qt_attribution.json':
                continue
            # Preserve copyright metadata verbatim, including nonstandard text
            # and scanner fixtures. Decode only LicenseFile values; unrelated
            # malformed copyright strings must not discard original notices.
            text = archive.extractfile(member).read().decode('utf-8-sig')
            for match in re.finditer(r'"LicenseFile"\s*:\s*', text):
                try:
                    names, _ = json.JSONDecoder(strict=False).raw_decode(text, match.end())
                except json.JSONDecodeError as error:
                    raise RuntimeError(f"Cannot read license reference: {component['name']}/{path}") from error
                if isinstance(names, str):
                    names = [names]
                if names is None:
                    names = []
                if not isinstance(names, list) or not all(isinstance(name, str) for name in names):
                    raise RuntimeError(f"Invalid license reference: {component['name']}/{path}")
                for name in names:
                    candidate = posixpath.normpath(str(PurePosixPath(path).parent / name))
                    if candidate in files:
                        chosen.add(candidate)
        for path in sorted(chosen):
            data = archive.extractfile(files[path]).read()
            target = output / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
            records.append({'path': str(target.relative_to(destination)), 'sha256': hashlib.sha256(data).hexdigest()})
    if not records:
        raise RuntimeError('No license files found for ' + component['name'])
    return {**component, 'notices': records}


def package(bundle):
    CACHE.mkdir(parents=True, exist_ok=True)
    components = json.loads((ROOT / 'legal/components.json').read_text())
    for component in components:
        if component['ref'] == 'from-binary':
            component['ref'] = moltenvk_ref(bundle)
    # The cache is tied to this exact manifest. Never reuse an archive after a
    # source revision changes, including a changed runtime MoltenVK version.
    identity = hashlib.sha256(json.dumps(components, sort_keys=True).encode()).hexdigest()
    marker = CACHE / '.manifest'
    if not marker.exists() or marker.read_text() != identity:
        for archive in CACHE.glob('*.tar.gz'):
            archive.unlink()
        marker.write_text(identity)
    destination = bundle / 'Contents/Resources/Legal'
    if destination.exists():
        shutil.rmtree(destination)
    destination.mkdir(parents=True)
    shutil.copyfile(ROOT / 'LICENSE', destination / 'GPL-3.0.txt')
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
        sources = list(pool.map(download, components))
    # MoltenVK embeds its own pinned SPIRV-Cross/cereal code. Preserve those
    # exact revisions too, rather than assuming the SDK-wide revisions match.
    extra = []
    with tarfile.open(CACHE / 'moltenvk.tar.gz', 'r:gz') as archive:
        for name, repo in [('SPIRV-Cross', 'KhronosGroup/SPIRV-Cross'),
                           ('SPIRV-Tools', 'KhronosGroup/SPIRV-Tools'),
                           ('SPIRV-Headers', 'KhronosGroup/SPIRV-Headers'), ('cereal', 'USCiLab/cereal')]:
            suffix = '/ExternalRevisions/' + name + '_repo_revision'
            member = next((m for m in archive.getmembers() if m.name.endswith(suffix)), None)
            if member is None:
                raise RuntimeError('Missing MoltenVK source revision for ' + name)
            revision = archive.extractfile(member).read().decode().strip()
            if not re.fullmatch(r'[0-9a-f]{40}', revision):
                raise RuntimeError('Invalid MoltenVK source revision for ' + name)
            extra.append({'id': 'moltenvk-' + name.lower(), 'name': name + ' (MoltenVK)', 'repo': repo, 'ref': revision})
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        sources.extend(pool.map(download, extra))
    inventory = [collect_archive(component, destination) for component in sources]
    local_records = []
    local_roots = [ROOT / p for p in ['h264bitstream', 'moonlight-common-c/moonlight-common-c',
                   'qmdnsengine/qmdnsengine', 'app/SDL_GameControllerDB']]
    for directory in local_roots:
        for source in directory.rglob('*'):
            if source.is_file() and not source.is_symlink() and LEGAL_NAME.search(source.name):
                relative = source.relative_to(ROOT)
                target = destination / 'application-components' / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(source, target)
                local_records.append(str(target.relative_to(destination)))
    if not local_records:
        raise RuntimeError('Missing source-submodule license notices')
    (destination / 'ModeSeven-font.txt').write_text(font_notices(ROOT / 'app/ModeSeven.ttf'))
    summary = ('MoonlightLG modifications: Copyright (c) 2026 Th3D3ck3r.\n'
               'Original Moonlight Qt and moonlight-common-c: the Moonlight developers and contributors.\n'
               'Qt framework: Copyright The Qt Company Ltd. and contributors.\n'
               'All original copyright statements are preserved in the component notices below.\n\n'
               'MoonlightLG is free software under GNU GPL version 3. You may redistribute and modify it under that license.\n'
               'This program is provided WITHOUT ANY WARRANTY, including MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.\n'
               'See GPL-3.0.txt for the full terms. Other components retain their respective licenses.\n\n'
               'Qt libraries are dynamically linked. Their LGPL/GPL terms, original notices and Qt third-party attributions are included.\n'
               'No additional restriction on modifying/relinking those libraries or reverse engineering for debugging such modifications is imposed.\n\n'
               'The source package and SOURCES.json identify the exact application and dependency sources, build recipes and patches.\n'
               'The inventory also includes source/build inputs that may not be linked into every package.\n\n')
    notices = [destination / 'GPL-3.0.txt', destination / 'ModeSeven-font.txt']
    notices += [destination / p for p in local_records]
    notices += [destination / item['path'] for component in inventory for item in component['notices']]
    combined = summary + ''.join('\n\n===== ' + str(path.relative_to(destination)) + ' =====\n' + path.read_text(errors='replace') for path in notices)
    (destination / 'THIRD_PARTY_NOTICES.txt').write_text(combined)
    manifest = {'application': 'MoonlightLG', 'license': 'GPL-3.0',
                'application_source': 'https://github.com/th3d3ck3r/moonlight-native-glass/releases/tag/moonlightlg-v1.3.2.0',
                'source_package': 'MoonlightLG-1.3.2.0-source.tar.gz', 'components': inventory,
                'local_notices': local_records, 'font_notice': 'ModeSeven-font.txt'}
    (destination / 'SOURCES.json').write_text(json.dumps(manifest, indent=2) + '\n')
    (CACHE / 'SOURCES.json').write_text(json.dumps(manifest, indent=2) + '\n')
    body = '<!doctype html><html lang="en"><meta charset="utf-8"><title>MoonlightLG — Licenses &amp; Notices</title>'
    body += '<style>body{max-width:900px;margin:40px auto;padding:0 24px;background:#101014;color:#eee;font:16px system-ui}a{color:#ff6177}pre{white-space:pre-wrap;overflow-wrap:anywhere}</style>'
    body += '<h1>MoonlightLG — Licenses &amp; Notices</h1><pre>' + html.escape(summary) + '</pre>'
    body += '<p><a href="GPL-3.0.txt">GNU GPL version 3</a> · <a href="THIRD_PARTY_NOTICES.txt">All copyright and license notices</a> · <a href="SOURCES.json">Exact source inventory</a></p>'
    body += '<h2>Original notices and attributions</h2><ul>'
    body += ''.join('<li><a href="' + html.escape(str(path.relative_to(destination)), quote=True) + '">' + html.escape(str(path.relative_to(destination))) + '</a></li>' for path in notices)
    (destination / 'index.html').write_text(body + '</ul></html>')
    print(f'Packaged legal notices: {len(inventory)} source components, {len(notices)} original notice files')


if __name__ == '__main__':
    package(Path(sys.argv[1]).resolve())
