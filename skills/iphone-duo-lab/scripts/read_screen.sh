#!/bin/bash
# Device Hub の AX ツリーから、表示中の文字列（AXStaticText / AXHeading / AXButton の description）を出力します。
# シミュレータ内で動いているアプリの要素もそのまま現れるので、スクリーンショットを読まずに値を取れます。
# 使い方: read_screen.sh [絞り込み用の正規表現]
#   例: read_screen.sh '×|regular|compact|Tr '
# デバイス一覧や設定パネルの文字列も含まれるため、必要なら正規表現で絞り込んでください。
set -uo pipefail

pgrep -x DeviceHub >/dev/null || { echo "DeviceHub が起動していません" >&2; exit 2; }
WINS=$(osascript -e 'tell application "System Events" to tell process "DeviceHub" to count of windows' 2>/dev/null || echo 0)
[ "$WINS" -gt 0 ] || { echo "DeviceHub のウインドウが開いていません" >&2; exit 2; }

OUT=$(osascript <<'EOF'
tell application "System Events"
  tell process "DeviceHub"
    set out to ""
    repeat with w in windows
      repeat with e in (entire contents of w)
        try
          set r to role of e
          if r is "AXStaticText" or r is "AXHeading" or r is "AXButton" then
            set d to description of e
            if d is not missing value and d is not "" and d is not "text" and d is not "button" then
              set out to out & r & "	" & d & linefeed
            end if
          end if
        end try
      end repeat
    end repeat
    return out
  end tell
end tell
EOF
)

if [ $# -ge 1 ]; then
  echo "$OUT" | grep -E -- "$1"
else
  echo "$OUT"
fi
