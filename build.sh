#!/usr/bin/env bash
# Builds DiskUsageVisualizer.app from the SwiftPM target.
# Output: ./build/DiskUsageVisualizer.app
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

CONFIG="${CONFIG:-release}"
APP_NAME="DiskUsageVisualizer"
BUILD_DIR="$SCRIPT_DIR/build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"

echo "==> Building ($CONFIG)"
swift build -c "$CONFIG" --arch arm64

BIN_PATH="$(swift build -c "$CONFIG" --show-bin-path)/$APP_NAME"
if [ ! -f "$BIN_PATH" ]; then
    echo "Binary not found at $BIN_PATH" >&2
    exit 1
fi

echo "==> Assembling .app bundle"
rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RESOURCES_DIR"
cp "$BIN_PATH" "$MACOS/$APP_NAME"
cp "$SCRIPT_DIR/Resources/Info.plist" "$CONTENTS/Info.plist"

echo "==> Code-signing (ad-hoc, with entitlements)"
codesign --force --sign - \
    --entitlements "$SCRIPT_DIR/Resources/DiskUsageVisualizer.entitlements" \
    --options runtime \
    "$APP_DIR"

echo "==> Verifying signature"
codesign --verify --verbose=2 "$APP_DIR"

echo
echo "Built: $APP_DIR"
echo "Run:   open '$APP_DIR'"
echo "Or:    '$MACOS/$APP_NAME'"
