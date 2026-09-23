#!/bin/bash
# iOS 27.1 SDK に API が実在するかを調べます。
# 使い方: check_api.sh <シンボル> [シンボル...]
#   例: check_api.sh reservedRegions DeviceHinge UIBackgroundExtensionView
# SwiftUI / SwiftUICore / UIKit / AVFoundation / AVKit の swiftinterface とヘッダを検索し、
# 見つかった行と直前の availability 属性を表示します。
set -uo pipefail
source "$(dirname "$0")/_sdk.sh"

[ $# -ge 1 ] || { sed -n '2,6p' "$0"; exit 1; }

FW="$DEV/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk/System/Library/Frameworks"
SDKVER=$(plutil -extract Version raw "$DEV/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk/SDKSettings.plist")
echo "SDK: iOS $SDKVER ($DEV)"

FILES=()
for m in SwiftUI SwiftUICore UIKit AVFoundation AVKit; do
  f="$FW/$m.framework/Modules/$m.swiftmodule/arm64e-apple-ios.swiftinterface"
  [ -f "$f" ] && FILES+=("$f")
  [ -d "$FW/$m.framework/Headers" ] && FILES+=("$FW/$m.framework/Headers")
done

status=0
for sym in "$@"; do
  echo
  echo "== $sym"
  # ヘッダの #import / #if やコメント行は宣言ではないので除く
  hits=$(grep -rn --include='*.swiftinterface' --include='*.h' -- "$sym" "${FILES[@]}" 2>/dev/null \
    | grep -vE '^[^:]+:[0-9]+:[[:space:]]*(#|//|/\*|\*)' | head -8)
  if [ -z "$hits" ]; then
    echo "  見つかりません（綴り違いか、SDK に存在しない可能性）"
    status=1
    continue
  fi
  while IFS= read -r line; do
    file=${line%%:*}; rest=${line#*:}; ln=${rest%%:*}; code=${rest#*:}
    module=$(echo "$file" | sed -E 's#.*/Frameworks/([A-Za-z]+)\.framework/.*#\1#')
    # 直前 4 行と同じ行から availability をすべて拾う（unavailable の指定も含む）
    avail=$(sed -n "$((ln > 4 ? ln - 4 : 1)),${ln}p" "$file" \
      | grep -oE '@available\([^)]*\)|API_(UN)?AVAILABLE\(([^()]|\([^)]*\))*\)' | sort -u | tr '\n' ' ')
    code=$(echo "$code" | sed -E 's/(SwiftUICore|SwiftUI|UIKit|UIUtilities|CoreFoundation|Swift|AVFoundation|AVKit)(::|\.)([A-Z])/\3/g; s/^ +//')
    printf '  [%s] %s\n' "$module" "$code"
    [ -n "$avail" ] && printf '        %s\n' "$avail"
  done <<< "$hits"
done
exit $status
