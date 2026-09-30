"""指定した色に一致する画素の外接矩形を、pt（画像の px ÷ 3）で出す。

使い方: uv run --with pillow --with numpy bbox.py <画像> <16進色> [許容差=8]

ビューの位置は、onGeometryChange の frame ではなく、この方法で測る。
frame は ignoresSafeArea や contentMargins による見た目の変化を反映しない。
測りたいビューに固有の色（例: Color.blue.opacity(0.28)）を付けて撮る。
"""
import sys

import numpy as np
from PIL import Image

path, hexcolor = sys.argv[1], sys.argv[2].lstrip("#")
tol = int(sys.argv[3]) if len(sys.argv) > 3 else 8
target = np.array([int(hexcolor[i:i + 2], 16) for i in (0, 2, 4)])
img = np.asarray(Image.open(path).convert("RGB")).astype(int)
mask = np.abs(img - target).max(axis=2) <= tol
ys, xs = np.where(mask)
if len(xs) == 0:
    print("対象色なし")
    sys.exit()
scale = 3.0
x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
print(f"x {x0/scale:.1f} → {x1/scale:.1f} / y {y0/scale:.1f} → {y1/scale:.1f} / "
      f"幅 {(x1-x0)/scale:.1f} 高 {(y1-y0)/scale:.1f} / 画面比 {mask.mean()*100:.0f}%")
