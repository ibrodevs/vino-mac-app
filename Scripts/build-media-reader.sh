#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/media-reader
clang -dynamiclib -fobjc-arc -mmacosx-version-min=13.0 \
  -framework Foundation -framework AppKit \
  Resources/MediaReader/MediaReader.m -o .build/media-reader/VinoMediaReader.dylib
codesign --force --sign - .build/media-reader/VinoMediaReader.dylib
cp Resources/MediaReader/read.pl .build/media-reader/
