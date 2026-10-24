#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)"
BUILD_OPTIONS=(--disable-sandbox --cache-path "$PWD/.build/cache" --config-path "$PWD/.build/config" --security-path "$PWD/.build/security")
BINARIES=()

for ARCH in arm64 x86_64; do
  SCRATCH="$PWD/.build/distribution/$ARCH"
  swift build -c release --arch "$ARCH" --scratch-path "$SCRATCH" "${BUILD_OPTIONS[@]}"
  BIN_DIR="$(swift build -c release --arch "$ARCH" --scratch-path "$SCRATCH" "${BUILD_OPTIONS[@]}" --show-bin-path)"
  BINARIES+=("$BIN_DIR/FlowScroll")
done

APP="$PWD/build/distribution/FlowScroll.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" downloads
lipo -create "${BINARIES[@]}" -output "$APP/Contents/MacOS/FlowScroll"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - --identifier local.flowscroll.app "$APP"
codesign --verify --deep --strict "$APP"

ARCHIVE="FlowScroll-$VERSION-universal.zip"
# A bundle-aware ZIP preserves the executable and app structure on macOS.
ditto -c -k --sequesterRsrc --keepParent "$APP" "downloads/$ARCHIVE"
(
  cd downloads
  shasum -a 256 "$ARCHIVE" > "$ARCHIVE.sha256"
)
echo "Packaged: downloads/$ARCHIVE"
