#!/bin/bash
# Device Hub のヒンジ角度スライダーを指定角度へドラッグします。
# 使い方: hinge.sh <0〜180の角度> [--dry-run]
#   0 = closed / 180 = fully open / 中間 = partially folded（例: 127）
# AXValue の書き換えはシミュレータに反映されないため、CGEvent で実際にマウスをドラッグします。
# マウスが動くので、ユーザーや他のセッションがシミュレータを操作していないときに実行してください。
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

ANGLE="${1:-}"
DRY="${2:-}"
[[ "$ANGLE" =~ ^[0-9]+(\.[0-9]+)?$ ]] || { sed -n '2,6p' "$0"; exit 1; }
awk -v a="$ANGLE" 'BEGIN{exit !(a>=0 && a<=180)}' || { echo "角度は 0〜180 で指定してください" >&2; exit 1; }

pgrep -x DeviceHub >/dev/null || { echo "DeviceHub が起動していません" >&2; exit 2; }
WINS=$(osascript -e 'tell application "System Events" to tell process "DeviceHub" to count of windows' 2>/dev/null || echo 0)
[ "$WINS" -gt 0 ] || { echo "DeviceHub のウインドウが開いていません（DeviceHub で iPhone Duo のデバイス画面を開いてください）" >&2; exit 2; }

# スライダー本体とつまみの位置・サイズを取得する（x y w h / kx ky kw kh / value）
read_slider() {
  osascript <<'EOF'
tell application "System Events"
  tell process "DeviceHub"
    repeat with w in windows
      repeat with e in (entire contents of w)
        try
          if (role of e) is "AXSlider" then
            if (value of attribute "AXMaxValue" of e) = 180.0 then
              set p to position of e
              set s to size of e
              set out to ((item 1 of p) as string) & " " & ((item 2 of p) as string) & " " & ((item 1 of s) as string) & " " & ((item 2 of s) as string)
              set k to ""
              repeat with c in (UI elements of e)
                if (role of c) is "AXValueIndicator" then
                  set kp to position of c
                  set ks to size of c
                  set k to ((item 1 of kp) as string) & " " & ((item 2 of kp) as string) & " " & ((item 1 of ks) as string) & " " & ((item 2 of ks) as string)
                end if
              end repeat
              return out & " " & k & " " & ((value of e) as string)
            end if
          end if
        end try
      end repeat
    end repeat
    return ""
  end tell
end tell
EOF
}

S=$(read_slider)
[ -n "$S" ] || { echo "ヒンジ角度のスライダーが見つかりません（iPhone Duo のデバイス画面を表示しているか確認してください）" >&2; exit 3; }
read -r X Y W H KX KY KW KH VAL <<< "$S"

# つまみの中心が動ける範囲はトラックの両端からつまみ幅の半分ずつ内側
read -r FROM_X TO_X CY <<< "$(awk -v x="$X" -v y="$Y" -v w="$W" -v h="$H" -v kx="$KX" -v kw="$KW" -v a="$ANGLE" 'BEGIN{
  left = x + kw/2; right = x + w - kw/2
  printf "%.1f %.1f %.1f", kx + kw/2, left + (right-left)*a/180, y + h/2 }')"

echo "スライダー: x=$X y=$Y w=$W h=$H / つまみ x=$KX w=$KW / 現在の値 $VAL"
echo "ドラッグ: ($FROM_X, $CY) → ($TO_X, $CY)  目標 ${ANGLE}°"
[ "$DRY" = "--dry-run" ] && { echo "--dry-run のためドラッグしません"; exit 0; }

swift "$HERE/drag.swift" "$FROM_X" "$CY" "$TO_X" "$CY"
sleep 1.5
AFTER=$(read_slider | awk '{print $NF}')
echo "ドラッグ後の値: $AFTER"
