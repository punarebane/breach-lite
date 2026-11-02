#!/bin/bash
# Export every preset and build the itch.io zips into build/dist.
set -e
cd "$(dirname "$0")/.."
mkdir -p build/web build/windows build/linux build/macos build/dist
touch build/.gdignore
godot --headless --import >/dev/null 2>&1 || true
for p in Web Windows Linux macOS; do
  godot --headless --export-release "$p" 2>&1 | grep -E "^ERROR" && exit 1 || true
done
rm -f build/dist/*.zip
(cd build/web && zip -qr ../dist/breach-lite-web.zip index.html index.js index.wasm index.pck index.png index.icon.png index.apple-touch-icon.png index.audio.worklet.js index.audio.position.worklet.js)
(cd build/windows && zip -qr ../dist/breach-lite-windows.zip Breach-lite.exe)
(cd build/linux && zip -qr ../dist/breach-lite-linux.zip Breach-lite.x86_64)
cp build/macos/Breach-lite.zip build/dist/breach-lite-macos.zip
ls -la build/dist
