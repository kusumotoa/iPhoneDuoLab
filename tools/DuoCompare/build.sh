#!/bin/bash
# 同じソースを異なる SDK でビルドして、それぞれ .app バンドルに組み立てます。
# 使い方: ./build.sh <XcodeApp名> <SDKラベル> <バンドル名>
set -euo pipefail

XCODE_APP="$1"      # 例: Xcode-26.6.0.app
LABEL="$2"          # 例: 26
IOS_TARGET="$3"     # 例: 26.0

HERE="$(cd "$(dirname "$0")" && pwd)"
DEV="/Applications/$XCODE_APP/Contents/Developer"
SDK="$DEV/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk"
SWIFTC="$DEV/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"

NAME="DuoCompare$LABEL"
APP="$HERE/$NAME.app"
rm -rf "$APP"
mkdir -p "$APP"

"$SWIFTC" -parse-as-library \
  -sdk "$SDK" \
  -target "arm64-apple-ios$IOS_TARGET-simulator" \
  -o "$APP/$NAME" \
  "$HERE/App.swift"

SDK_VER=$(plutil -extract Version raw "$SDK/SDKSettings.plist")

cat > "$APP/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>$NAME</string>
  <key>CFBundleIdentifier</key><string>com.kusumotoa.compare.$NAME</string>
  <key>CFBundleName</key><string>$NAME</string>
  <key>CFBundleDisplayName</key><string>SDK $LABEL</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSRequiresIPhoneOS</key><true/>
  <key>MinimumOSVersion</key><string>$IOS_TARGET</string>
  <key>UIDeviceFamily</key><array><integer>1</integer></array>
  <key>UILaunchScreen</key><dict/>
  <key>DTPlatformName</key><string>iphonesimulator</string>
  <key>DTPlatformVersion</key><string>$SDK_VER</string>
  <key>DTSDKName</key><string>iphonesimulator$SDK_VER</string>
  <key>CFBundleSupportedPlatforms</key><array><string>iPhoneSimulator</string></array>
</dict>
</plist>
PLIST

echo "built $NAME with SDK $SDK_VER"
vtool -show-build "$APP/$NAME" | grep -E "sdk|minos|platform" || true
