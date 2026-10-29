#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
swiftc -module-cache-path /tmp/deutsia-module-cache -swift-version 5 Sources/Models.swift Sources/Security.swift Sources/Network.swift Sources/NetworkPolicy.swift Sources/Playlist.swift Sources/Dash.swift Sources/CatalogLanguage.swift Sources/ImportExport.swift Tests/CoreTests.swift -o /tmp/deutsia-core-tests
/tmp/deutsia-core-tests
