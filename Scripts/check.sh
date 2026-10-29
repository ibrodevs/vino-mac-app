#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
./Scripts/build-media-reader.sh
swift build
mkdir -p dist
BIN_PATH="$(swift build --show-bin-path)"
swiftc -parse-as-library -o dist/VinoChecks \
  Sources/Vino/WallpaperView.swift Sources/Vino/NowPlayingService.swift \
  Sources/Vino/NowPlayingTrack.swift Sources/Vino/JXANowPlayingReader.swift \
  "$BIN_PATH/Vino.build/DerivedSources/resource_bundle_accessor.swift" Scripts/Checks.swift
cp -R "$BIN_PATH/Vino_Vino.bundle" dist/
./dist/VinoChecks "$@"
