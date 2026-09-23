#!/bin/bash
# iOS 27.1 以降の SDK を持つ Xcode を探して DEV に入れる共通処理です。
# DEVELOPER_DIR が設定されていればそれを優先します。

find_developer_dir() {
  if [ -n "${DEVELOPER_DIR:-}" ] && [ -d "$DEVELOPER_DIR" ]; then
    echo "$DEVELOPER_DIR"; return 0
  fi
  local d sdk ver
  for d in "$(xcode-select -p 2>/dev/null)" /Applications/Xcode*.app/Contents/Developer; do
    sdk="$d/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk"
    [ -f "$sdk/SDKSettings.plist" ] || continue
    ver=$(plutil -extract Version raw "$sdk/SDKSettings.plist" 2>/dev/null) || continue
    # sort -V で小さい方が 27.1 なら ver >= 27.1
    if [ "$(printf '27.1\n%s\n' "$ver" | sort -V | head -1)" = "27.1" ]; then
      echo "$d"; return 0
    fi
  done
  return 1
}

DEV=$(find_developer_dir) || {
  echo "iOS 27.1 以降の SDK を持つ Xcode が見つかりません。DEVELOPER_DIR で指定してください。" >&2
  exit 2
}
