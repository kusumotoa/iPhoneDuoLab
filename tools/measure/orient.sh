#!/bin/bash
# 現在の姿勢と向きを、UIKit の値から出す。回転ボタンは上下が逆の向きも通るので、測定や撮影の前に使う。
#   画面の大きさ / 垂直バーの辺 / ヒンジの状態 / 予約領域（内側カメラの位置が向きの目印）
set -e
source "$(dirname "$0")/common.sh"
xcrun simctl terminate "$DUO_UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl launch "$DUO_UDID" "$BUNDLE_ID" -lab uikitValues >/dev/null
sleep 3
J=$(values_json)
echo "size $(jq -r '."uikit.size"' "$J") | bar $(jq -r '."uikit.verticalBarEdge"' "$J") | hinge $(jq -r '."uikit.hingeEvents"' "$J" | awk '{print $1}')"
jq -r '."uikit.occlusion.inactive"' "$J" | grep -oE "\[x [-0-9.]+ y [-0-9.]+ w [-0-9.]+ h [-0-9.]+; margins[^]]*active (true|false)\]" | sed 's/margins.*active/active/'
