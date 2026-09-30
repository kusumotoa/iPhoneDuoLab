#!/bin/bash
# Lab を起動し、書き出された JSON を表示する。
# 使い方: read-lab.sh <-lab の名前> [追加の起動引数...]
#   例:   read-lab.sh apiValues
#         read-lab.sh sheet -sheet place-trailing
# 内側ディスプレイにはタッチが届かないので、起動引数で目的の画面を直接開く。
# 値の書き出しは非同期なので、WebView など重い Lab は WAIT を伸ばす（WebView は 7 以上）。
set -e
source "$(dirname "$0")/common.sh"
LAB="$1"; shift
xcrun simctl terminate "$DUO_UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl launch "$DUO_UDID" "$BUNDLE_ID" -lab "$LAB" "$@" >/dev/null
sleep "${WAIT:-3}"
cat "$(values_json)"
