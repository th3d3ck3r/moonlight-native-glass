"""Print the human/package version from the same metadata used by About."""
import pathlib
import plistlib
import re
import sys

info = plistlib.loads(pathlib.Path(sys.argv[1]).read_bytes())
numeric = info['MoonlightLGVersion']
channel = info['MoonlightLGReleaseChannel']
component = r'(?:0|[1-9][0-9]*)'
if not re.fullmatch(rf'{component}(?:\.{component}){{3}}', numeric) or channel not in {'U', 'E', 'stable'}:
    raise SystemExit('Invalid MoonlightLG version/channel metadata')
# Apple's bundle release version requires exactly three components. The app's
# four-component version is authoritative for About and package filenames.
if info['CFBundleShortVersionString'] != '.'.join(numeric.split('.')[:3]):
    raise SystemExit('Apple bundle version must match the first three MoonlightLG components')
print(numeric + ('' if channel == 'stable' else channel))
