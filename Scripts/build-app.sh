#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

./Scripts/build-media-reader.sh

swift build -c release --product Vino

APP="$ROOT/dist/Vino.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$ROOT/.build/release/Vino" "$APP/Contents/MacOS/Vino"
# Load shipped artwork through Bundle.main; SwiftPM supplies it during development.
cp "$ROOT/Sources/Vino/Assets/listening-room.png" "$APP/Contents/Resources/"
mkdir -p "$APP/Contents/Frameworks"
cp "$ROOT/.build/media-reader/VinoMediaReader.dylib" "$APP/Contents/Frameworks/"
cp "$ROOT/Resources/MediaReader/read.pl" "$APP/Contents/Resources/"
cp "$ROOT/Resources/MediaReader/NOTICE.md" "$APP/Contents/Resources/MediaReader-NOTICE.md"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
chmod +x "$APP/Contents/MacOS/Vino"

if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$APP" >/dev/null
fi

echo "Built: $APP"
