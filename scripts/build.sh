#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
BUILD_OPTIONS=(--disable-sandbox --cache-path "$PWD/.build/cache" --config-path "$PWD/.build/config" --security-path "$PWD/.build/security")
swift build -c release "${BUILD_OPTIONS[@]}"
BIN_DIR="$(swift build -c release "${BUILD_OPTIONS[@]}" --show-bin-path)"
APP="$PWD/build/FlowScroll.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/FlowScroll" "$APP/Contents/MacOS/FlowScroll"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - --identifier local.flowscroll.app "$APP"
echo "Built: $APP"
