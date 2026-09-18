#!/bin/bash
# Builds Webcam.app  —  usage: ./build.sh
set -euo pipefail
cd "$(dirname "$0")"

APP="Webcam.app"
BIN="Webcam"

echo "Compiling..."
clang -fobjc-arc -O2 -Wall \
    -o "$BIN" webcam.m \
    -framework Cocoa -framework AVFoundation -framework QuartzCore -framework CoreMedia

echo "Assembling $APP..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$BIN"
cp Info.plist "$APP/Contents/Info.plist"

# Ad-hoc signature so macOS TCC (camera permission) is happy.
codesign --force --sign - "$APP" >/dev/null 2>&1 || true

echo "Done -> $APP"
echo "Run with:  open $APP"
