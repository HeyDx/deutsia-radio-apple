#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
if ! xcrun --sdk iphoneos --show-sdk-path >/dev/null 2>&1; then
  echo '缺少 iOS SDK。请安装兼容的完整 Xcode，并设置 DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer。' >&2
  exit 2
fi
if ! command -v pod >/dev/null; then
  echo '需要 CocoaPods 以安装已固定的官方 MobileVLCKit 3.6.0。请先安装 CocoaPods，再运行此脚本。' >&2
  exit 2
fi
python3 generate-project.py
pod install
TEAM="${TEAM_ID:-}"
if [ -z "$TEAM" ]; then
  TEAM="$(security find-identity -v -p codesigning | sed -nE 's/.*Apple Development:.*\(([A-Z0-9]{10})\).*/\1/p' | head -1)"
fi
if [ -z "$TEAM" ]; then
  echo '请先在 Xcode > Settings > Accounts 中登录当前 Apple ID，在项目 Signing & Capabilities 选择 Personal Team。然后设置 TEAM_ID（开发团队 ID）。' >&2
  exit 2
fi
xcodebuild -workspace DeutsiaRadio.xcworkspace -scheme DeutsiaRadio -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath build -allowProvisioningUpdates DEVELOPMENT_TEAM="$TEAM" CODE_SIGN_STYLE=Automatic build
APP="$PWD/build/Build/Products/Debug-iphoneos/DeutsiaRadio.app"
if [ -n "${DEVICE_UDID:-}" ]; then
  xcrun devicectl device install app --device "$DEVICE_UDID" "$APP"
fi
echo "$APP"
