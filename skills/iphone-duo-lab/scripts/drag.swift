import CoreGraphics
import Foundation

// スライダーをドラッグするための最小ユーティリティです。
// 使い方: swift drag.swift <fromX> <fromY> <toX> <toY>
let a = CommandLine.arguments
guard a.count >= 5,
      let fx = Double(a[1]), let fy = Double(a[2]),
      let tx = Double(a[3]), let ty = Double(a[4]) else {
    print("usage: drag.swift fromX fromY toX toY")
    exit(1)
}

func post(_ type: CGEventType, _ p: CGPoint) {
    guard let e = CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: p, mouseButton: .left) else { return }
    e.post(tap: .cghidEventTap)
}

post(.mouseMoved, CGPoint(x: fx, y: fy))
usleep(150_000)
post(.leftMouseDown, CGPoint(x: fx, y: fy))
usleep(150_000)

let steps = 30
for i in 1...steps {
    let t = Double(i) / Double(steps)
    post(.leftMouseDragged, CGPoint(x: fx + (tx - fx) * t, y: fy + (ty - fy) * t))
    usleep(25_000)
}

usleep(150_000)
post(.leftMouseUp, CGPoint(x: tx, y: ty))
print("dragged (\(fx),\(fy)) -> (\(tx),\(ty))")
