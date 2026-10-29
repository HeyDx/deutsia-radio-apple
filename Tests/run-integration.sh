#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
ENGINE="$PWD/dist/Deutsia Radio.app/Contents/Frameworks/vlc"
for TEST in Playback Hls; do
  swiftc -module-cache-path /tmp/deutsia-module-cache -swift-version 5 -import-objc-header Sources/VLC.h Sources/Models.swift Sources/Security.swift Sources/Network.swift Sources/NetworkPolicy.swift Sources/Playlist.swift Sources/Dash.swift Sources/Player.swift "Tests/${TEST}Tests.swift" -L "$ENGINE/lib" -lvlc -Xlinker -rpath -Xlinker "$ENGINE/lib" -o "/tmp/deutsia-${TEST}-tests"
  "/tmp/deutsia-${TEST}-tests" "$ENGINE"
done
