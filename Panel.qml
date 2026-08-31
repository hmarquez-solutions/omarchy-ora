import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "io.github.hmarquez-solutions.ora"
  ipcTarget: "ora"
  manageIpc: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color sacred: Model.liturgicalColor(ora.day.liturgicalColor)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  property int cursorIndex: 0
  property bool cursorActive: false
  readonly property var actions: ["readings", "rosary", "usccb", "hallow", "bibleInAYear"]

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function activate(index) {
    ora.open(actions[Math.max(0, Math.min(actions.length - 1, index))])
  }

  onOpenedChanged: if (opened) {
    ora.refresh()
    cursorIndex = 0
    cursorActive = false
    Qt.callLater(function () { keyCatcher.forceActiveFocus() })
  }

  Service { id: ora; settings: root.settings }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { ora.refresh(); return "ok" }
    function readings(): string { ora.open("readings"); return "ok" }
    function rosary(): string { ora.open("rosary"); return "ok" }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    iconComponent: Component {
      Item {
        OraIcon {
          anchors.centerIn: parent
          iconSize: Style.bar.iconCanvas
          color: button.foreground
        }
      }
    }
    tooltipText: ora.day.liturgicalDay ? "Ora · " + ora.day.liturgicalDay : "Ora"
    onPressed: function (code) {
      if (code === Qt.RightButton) ora.open("readings")
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(390))
    contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(620))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function (dx, dy) {
        if (dy === 0) return
        root.cursorActive = true
        root.cursorIndex = Math.max(0, Math.min(root.actions.length - 1, root.cursorIndex + dy))
      }
      onActivateRequested: root.activate(root.cursorIndex)
      onCloseRequested: root.close()
      onTabRequested: function (direction) { root.switchPanel(direction) }
      onTextKey: function (text) {
        var key = String(text).toLowerCase()
        if (key === "r") ora.refresh()
        else if (key === "m") ora.open("readings")
        else if (key === "p") ora.open("rosary")
      }
    }

    ColumnLayout {
      id: content
      width: parent.width
      spacing: Style.space(12)

      Rectangle {
        Layout.fillWidth: true
        implicitHeight: hero.implicitHeight + Style.space(28)
        radius: Style.space(10)
        color: Qt.rgba(root.sacred.r, root.sacred.g, root.sacred.b, 0.16)
        border.color: Qt.rgba(root.sacred.r, root.sacred.g, root.sacred.b, 0.55)

        Column {
          id: hero
          anchors.centerIn: parent
          width: parent.width - Style.space(28)
          spacing: Style.space(4)
          Text { width: parent.width; text: ora.day.dateLabel || "Today"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.heading; font.weight: Font.DemiBold }
          Text { width: parent.width; text: ora.day.liturgicalDay || "Loading the day…"; color: root.sacred; font.family: root.fontFamily; font.pixelSize: Style.font.subtitle }
          Text { width: parent.width; text: ora.day.mysteryName || ""; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
        }
      }

      Text { text: "TODAY'S RULE"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.weight: Font.Bold }

      Repeater {
        model: [
          { title: "Mass readings", detail: "Word on Fire · readings and reflection", action: "readings", done: ora.day.completed && ora.day.completed.readings, mysteries: [] },
          { title: "Pray the Rosary", detail: ora.day.mysteryName || "Today's mysteries", action: "rosary", done: ora.day.completed && ora.day.completed.rosary, mysteries: ora.day.mysteries || [] }
        ]
        delegate: Rectangle {
          required property var modelData
          required property int index
          Layout.fillWidth: true
          implicitHeight: Math.max(Style.space(58), ruleRow.implicitHeight + Style.space(20))
          radius: Style.space(8)
          color: root.cursorActive && root.cursorIndex === index ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12) : "transparent"
          border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.16)

          RowLayout {
            id: ruleRow
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Style.space(10)
            anchors.rightMargin: Style.space(10)
            spacing: Style.space(10)

            Text {
              text: modelData.done ? "✓" : "○"
              color: modelData.done ? root.sacred : root.dim
              font.pixelSize: Style.font.heading
              horizontalAlignment: Text.AlignHCenter
              Layout.preferredWidth: Style.space(22)
              Layout.alignment: Qt.AlignTop
            }

            Column {
              Layout.fillWidth: true
              Layout.preferredWidth: 1
              spacing: 1
              Text {
                width: parent.width
                text: modelData.title
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.subtitle
                font.weight: Font.Medium
              }
              Text {
                width: parent.width
                text: modelData.detail
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
              }
              Item {
                width: 1
                height: Style.space(6)
                visible: (modelData.mysteries || []).length > 0
              }
              Repeater {
                model: modelData.mysteries || []
                delegate: Text {
                  required property var modelData
                  required property int index
                  width: parent.width
                  text: (index + 1) + "  " + modelData
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }
            }

            Text {
              text: "↗"
              color: root.dim
              font.pixelSize: Style.font.subtitle
              Layout.alignment: Qt.AlignTop
            }
          }

          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.activate(index) }
        }
      }

      Text { text: "REFLECT & LISTEN"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.weight: Font.Bold }

      Repeater {
        model: [
          { title: "USCCB", detail: "Official conference readings" },
          { title: "Open Hallow", detail: "Continue your guided prayer" },
          { title: "Fr. Mike Schmitz", detail: "Bible in a Year" }
        ]
        delegate: Rectangle {
          required property var modelData
          required property int index
          readonly property int actionIndex: index + 2
          Layout.fillWidth: true
          implicitHeight: Style.space(50)
          radius: Style.space(8)
          color: root.cursorActive && root.cursorIndex === actionIndex ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12) : "transparent"
          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(12)
            anchors.rightMargin: Style.space(12)
            spacing: Style.space(10)
            Column {
              Layout.fillWidth: true
              Layout.preferredWidth: 1
              spacing: 0
              Text {
                width: parent.width
                text: modelData.title
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.subtitle
              }
              Text {
                width: parent.width
                text: modelData.detail
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
              }
            }
            Text { text: "↗"; color: root.dim; font.pixelSize: Style.font.subtitle }
          }
          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.activate(actionIndex) }
        }
      }

      Text {
        Layout.fillWidth: true
        text: "Right-click the bar icon for today's readings · r refreshes"
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
      }
    }
  }
}
