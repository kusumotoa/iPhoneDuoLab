#!/bin/bash
# 内側・外側の両ディスプレイを撮り、ほぼ真っ黒な画像は捨てる（閉じた姿勢の内側ディスプレイなど）。
# 開いた姿勢では、外側ディスプレイの画像も残ることがある。使うのは、点灯しているほうだけ。
# 使い方: shot.sh <出力パス（拡張子なし）>   → <出力パス>-inner.png / -outer.png
# 注意: simctl で撮った画像は、端末が上下逆の向きでも、文字が読める向きで保存される。
#       画像の見た目からは撮った向きが分からないので、orient.sh の出力を控えておく。
set -e
source "$(dirname "$0")/common.sh"
OUT="$1"; mkdir -p "$(dirname "$OUT")"
# 外側 1398 px 幅、内側 2007 px 幅のディスプレイを探す
LIST=$(xcrun simctl io "$DUO_UDID" enumerate 2>&1 | awk '/^Port:/{if(u&&w~/^(1398|2007)$/)print u" "w; u="";w=""} /UUID:/{u=$2} /Default width:/{w=$3} END{if(u&&w~/^(1398|2007)$/)print u" "w}')
while read -r UUID W; do
  KIND=$([ "$W" = 2007 ] && echo inner || echo outer)
  xcrun simctl io "$DUO_UDID" screenshot --display "$UUID" "${OUT}-${KIND}.png" >/dev/null 2>&1
  MEAN=$(magick "${OUT}-${KIND}.png" -colorspace Gray -format "%[fx:mean]" info:)
  if [ "$(echo "$MEAN < 0.02" | bc -l)" = 1 ]; then rm -f "${OUT}-${KIND}.png"; else echo "撮影: ${OUT}-${KIND}.png"; fi
done <<< "$LIST"
