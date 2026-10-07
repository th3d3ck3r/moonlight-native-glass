#!/bin/bash
set -euo pipefail

# Usage: scripts/build-native-macos.sh x86_64|universal
# Keep the original Qt project, dependencies and streaming build flags.
arch_set=${1:-universal}
case "$arch_set" in
    x86_64) qt_archs="x86_64"; native_archs=(x86_64) ;;
    universal) qt_archs="x86_64 arm64"; native_archs=(x86_64 arm64) ;;
    *) echo "Expected x86_64 or universal" >&2; exit 1 ;;
esac
source_root=$(pwd)
build_root="$source_root/build/native-$arch_set"
mkdir -p "$build_root/engine" "$build_root/bin"
python3 setup-deps.py
export CFLAGS=-flto=thin CXXFLAGS=-flto=thin LDFLAGS=-flto=thin
(
    cd "$build_root/engine"
    qmake "$source_root/moonlight-qt.pro" QMAKE_APPLE_DEVICE_ARCHS="$qt_archs"
    make -j"$(sysctl -n hw.logicalcpu)" release
)
engine_app="$build_root/engine/app/Moonlight.app"
macdeployqt "$engine_app" -qmldir="$source_root/app/gui" -appstore-compliant -no-codesign
# Qt's optional Mimer SQL driver references an unavailable proprietary client
# library. Moonlight does not use Mimer; ship no broken optional driver.
rm -f "$engine_app/Contents/PlugIns/sqldrivers/libqsqlmimer.dylib"
sdk=$(xcrun --sdk macosx --show-sdk-path)
for cpu in "${native_archs[@]}"; do
    xcrun swiftc -swift-version 5 -parse-as-library -O -sdk "$sdk" \
        -target "$cpu-apple-macos15.0" macos-native/Sources/*.swift \
        -o "$build_root/bin/MoonlightNative-$cpu"
    lipo "$engine_app/Contents/MacOS/Moonlight" -verify_arch "$cpu"
done
app="$build_root/Moonlight Native Glass.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$app/Contents/Helpers"
if [ "$arch_set" = universal ]; then
    lipo -create "$build_root/bin/MoonlightNative-x86_64" "$build_root/bin/MoonlightNative-arm64" -output "$app/Contents/MacOS/MoonlightNative"
else
    cp "$build_root/bin/MoonlightNative-x86_64" "$app/Contents/MacOS/MoonlightNative"
fi
cp app/moonlight.icns "$app/Contents/Resources/moonlight.icns"
cp macos-native/Info.plist "$app/Contents/Info.plist"
ditto "$engine_app" "$app/Contents/Helpers/MoonlightEngine.app"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier com.moonlight-stream.NativeGlass.Engine' "$app/Contents/Helpers/MoonlightEngine.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleDisplayName Moonlight Native Glass Engine' "$app/Contents/Helpers/MoonlightEngine.app/Contents/Info.plist"

# Ad-hoc signatures make all nested code verifiable and retain one bundle
# identity. This is not Developer ID signing or notarization. Verify all code;
# do not strip signatures or alter entitlements to bypass privacy controls.
codesign --force --deep --sign - "$app"
codesign --verify --deep --strict --verbose=2 "$app"
python3 tests/native/check_bundle.py "$app" "$arch_set"
echo "Built $app"
