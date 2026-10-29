#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
APP="$PWD/dist/Deutsia Radio.app"
ENGINE="${VLC_SOURCE:-/tmp/deutsia-vlc/VLC.app/Contents/MacOS}"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Frameworks/vlc" "$APP/Contents/Resources"
if [ ! -f "$APP/Contents/Frameworks/vlc/lib/libvlc.dylib" ]; then
  cp -R "$ENGINE/lib" "$ENGINE/plugins" "$APP/Contents/Frameworks/vlc/"
fi
find "$APP/Contents/Frameworks/vlc/plugins" \( -name '*.jar' -o -name 'plugins.dat' \) -delete
swiftc -module-cache-path /tmp/deutsia-module-cache -swift-version 5 -O -target arm64-apple-macosx13.0 -import-objc-header Sources/VLC.h Sources/*.swift -L "$APP/Contents/Frameworks/vlc/lib" -lvlc -Xlinker -rpath -Xlinker @executable_path/../Frameworks/vlc/lib -o "$APP/Contents/MacOS/DeutsiaRadio"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict>
<key>CFBundleIconFile</key><string>AppIcon</string><key>CFBundleExecutable</key><string>DeutsiaRadio</string><key>CFBundleIdentifier</key><string>com.deutsia.community.mac</string><key>CFBundleName</key><string>Deutsia Radio</string><key>CFBundleDisplayName</key><string>Deutsia Radio</string><key>CFBundlePackageType</key><string>APPL</string><key>CFBundleShortVersionString</key><string>0.1.1</string><key>CFBundleVersion</key><string>2</string><key>LSMinimumSystemVersion</key><string>13.0</string><key>NSHighResolutionCapable</key><true/><key>NSAppTransportSecurity</key><dict><key>NSAllowsArbitraryLoads</key><true/></dict><key>NSFaceIDUsageDescription</key><string>解锁电台应用</string><key>NSLocalNetworkUsageDescription</key><string>连接本机音频通道和你配置的 I2P / 自定义代理。</string><key>NSHumanReadableCopyright</key><string>Based on deutsia radio © 2025 deutsia, Apache-2.0. Uses libVLC, LGPL-2.1.</string>
</dict></plist>
PLIST
cp LICENSE NOTICE Resources/AppIcon.icns Resources/Credits.html Resources/VLC-COPYING*.txt "$APP/Contents/Resources/"
cp -R Resources/Localization/*.lproj "$APP/Contents/Resources/"
find "$APP/Contents/Frameworks" -type f -name '*.dylib' -exec codesign --force --sign - {} \; 2>/dev/null
codesign --force --sign - "$APP"
echo "$APP"
