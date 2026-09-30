#!/bin/bash
# 同じ app を、別々のバンドル ID・表示名で 2 つ入れる。
# 「内側カメラを使う app と、使わない app が並んだとき」を、Split View で確かめるために使う。
#
# 使い方:
#   実機:           ./install-two-apps.sh device <デバイスの識別子> <Team ID>
#   シミュレータ:   ./install-two-apps.sh sim
#
# 入るもの:
#   - 「Duo カメラ側」     com.kusumotoa.iPhoneDuoLab.camera
#   - 「Duo 観察側」       com.kusumotoa.iPhoneDuoLab.observer
# どちらも「カメラの並走テスト」画面（`-lab cameraSplit`）を持つ。役割は画面で切り替えられ、アプリごとに保存される。
#
# 実機の識別子は `xcrun devicectl list devices` で分かる。署名には自分の Team ID が要る。
set -e
source "$(dirname "$0")/common.sh"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
MODE="${1:-sim}"
DEVICE="${2:-}"
TEAM="${3:-}"

if [ "$MODE" = device ] && { [ -z "$DEVICE" ] || [ -z "$TEAM" ]; }; then
  echo "使い方: $0 device <デバイスの識別子> <Team ID>" >&2
  exit 1
fi

build_and_install() {
  local suffix="$1" display="$2"
  local dd="/tmp/duolab-two-$suffix"
  local common=(-project "$ROOT/iPhoneDuoLab.xcodeproj" -scheme iPhoneDuoLab -derivedDataPath "$dd"
                PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID.$suffix" INFOPLIST_KEY_CFBundleDisplayName="$display")
  echo "== ${display} (${BUNDLE_ID}.${suffix}) をビルド"
  if [ "$MODE" = device ]; then
    xcodebuild "${common[@]}" -destination "id=$DEVICE" -allowProvisioningUpdates \
      DEVELOPMENT_TEAM="$TEAM" CODE_SIGN_STYLE=Automatic build | tail -3
    xcrun devicectl device install app --device "$DEVICE" "$dd/Build/Products/Debug-iphoneos/iPhoneDuoLab.app"
  else
    xcodebuild "${common[@]}" -destination "id=$DUO_UDID" build | tail -3
    xcrun simctl install "$DUO_UDID" "$dd/Build/Products/Debug-iphonesimulator/iPhoneDuoLab.app"
  fi
}

build_and_install camera "Duo カメラ側"
build_and_install observer "Duo 観察側"
echo "完了。ホーム画面に「Duo カメラ側」と「Duo 観察側」が入りました。手順は docs/08-camera-split-check.md"
