import QtQuick
import qs.Commons

// Pixel-aligned Latin cross. Odd thickness on an even canvas (or pill
// caps) sits a half-pixel off and reads as a crooked plus; keep size and
// stroke even, square the ends, and put the crossbar in the upper third.
Item {
  id: root

  property real iconSize: Style.font.icon
  property color color: Color.foreground

  readonly property int s: {
    var n = Math.max(8, Math.round(iconSize))
    return n % 2 === 0 ? n : n + 1
  }
  readonly property int t: s >= 20 ? 4 : 2
  readonly property int pad: 1
  readonly property int stemX: (s - t) / 2
  readonly property int armW: {
    var w = Math.round(s * 0.64)
    if ((w - t) % 2 !== 0) w += 1
    return Math.min(s - pad * 2, Math.max(t + 4, w))
  }
  readonly property int armX: (s - armW) / 2
  readonly property int armY: {
    var y = Math.round(s * 0.26)
    if (y % 2 !== 0) y -= 1
    return Math.max(pad, y)
  }

  implicitWidth: s
  implicitHeight: s
  width: s
  height: s

  Rectangle {
    x: root.stemX
    y: root.pad
    width: root.t
    height: root.s - root.pad * 2
    color: root.color
  }

  Rectangle {
    x: root.armX
    y: root.armY
    width: root.armW
    height: root.t
    color: root.color
  }
}
