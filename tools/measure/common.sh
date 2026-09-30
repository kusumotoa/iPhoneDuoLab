#!/bin/bash
# 測定スクリプト共通の設定。source して使う。
# 別の Xcode で作業していても、27.1 を使えるように DEVELOPER_DIR を指定する（xcode-select は変えない）。
: "${DEVELOPER_DIR:=/Applications/Xcode-27.1.0-Beta.app/Contents/Developer}"
export DEVELOPER_DIR
BUNDLE_ID="${BUNDLE_ID:-com.kusumotoa.iPhoneDuoLab}"

# iPhone Duo シミュレータの UDID（環境変数 DUO_UDID で上書きできる）
if [ -z "${DUO_UDID:-}" ]; then
  DUO_UDID=$(xcrun simctl list devices | grep "iPhone Duo (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
fi
[ -n "$DUO_UDID" ] || { echo "iPhone Duo のシミュレータが見つかりません" >&2; exit 1; }

# アプリのコンテナにある、Lab の出力（JSON）
values_json() { echo "$(xcrun simctl get_app_container "$DUO_UDID" "$BUNDLE_ID" data)/Documents/api-values.json"; }
