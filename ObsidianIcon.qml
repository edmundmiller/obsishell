import QtQuick
import QtQuick.Effects
import qs.Commons

Item {
  id: root

  property real iconSize: Style.font.icon
  property color color: Color.foreground
  property bool pulsing: false

  width: iconSize
  height: iconSize
  implicitWidth: iconSize
  implicitHeight: iconSize

  opacity: pulsing ? 0.55 : 1.0

  Image {
    id: mark
    anchors.fill: parent
    source: Qt.resolvedUrl("assets/obsidian.svg")
    sourceSize.width: Math.round(width * Screen.devicePixelRatio)
    sourceSize.height: Math.round(height * Screen.devicePixelRatio)
    fillMode: Image.PreserveAspectFit
    smooth: true
    visible: false
    layer.enabled: true
  }

  MultiEffect {
    anchors.fill: mark
    source: mark
    colorization: 1.0
    colorizationColor: root.color
  }

  SequentialAnimation on opacity {
    running: root.pulsing
    loops: Animation.Infinite
    NumberAnimation { to: 0.35; duration: 450 }
    NumberAnimation { to: 1.0; duration: 450 }
  }
}
