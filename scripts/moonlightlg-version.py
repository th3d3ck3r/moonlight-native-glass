"""Print the human/package version from the same metadata used by About."""
import pathlib
import plistlib
import re
import sys

info = plistlib.loads(pathlib.Path(sys.argv[1]).read_bytes())
numeric = info['CFBundleShortVersionString']
channel = info['MoonlightLGReleaseChannel']
if not re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]{2,}', numeric) or channel not in {'U', 'E', 'stable'}:
    raise SystemExit('Invalid MoonlightLG version/channel metadata')
major, minor, patch = map(int, numeric.split('.'))
print(f'{major}.{minor}.{patch:02d}' + ('' if channel == 'stable' else channel))
