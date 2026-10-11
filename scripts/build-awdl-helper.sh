#!/bin/bash
set -euo pipefail
# Builds/bundles only. Never registers a daemon or touches network interfaces.
app_path=$1
shift
if [ "$#" -eq 0 ]; then echo 'Expected at least one architecture' >&2; exit 1; fi
source_path=$(cd "$(dirname "$0")/.." && pwd)
helper_build=$(mktemp -d)
trap 'rm -rf "$helper_build"' EXIT
helper_slices=()
for helper_cpu in "$@"; do
    xcrun clang++ -std=c++17 -fobjc-arc -O2 -Wall -Wextra -Werror \
      -target "$helper_cpu-apple-macos15.0" -framework Foundation -framework Security \
      "$source_path/macos-native/AWDLHelper/main.mm" -o "$helper_build/$helper_cpu"
    helper_slices+=("$helper_build/$helper_cpu")
done
mkdir -p "$app_path/Contents/Library/Helpers" "$app_path/Contents/Library/LaunchDaemons"
lipo -create "${helper_slices[@]}" -output "$app_path/Contents/Library/Helpers/MoonlightAWDLHelper"
cp "$source_path/macos-native/AWDLHelper/com.moonlight-stream.NativeGlass.AWDLHelper.plist" "$app_path/Contents/Library/LaunchDaemons/"
codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY:--}" --identifier com.moonlight-stream.NativeGlass.AWDLHelper "$app_path/Contents/Library/Helpers/MoonlightAWDLHelper"
