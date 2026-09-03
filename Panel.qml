import QtQuick
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
  readonly property color dim: Qt.darker(foreground, 1.4)
  readonly property color faint: Qt.darker(foreground, 1.9)
  readonly property color sacred: Model.liturgicalColor(ora.celebration.color || ora.day.liturgicalColor)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property bool tintCross: setting("tintCross", false) === true
  readonly property int ruleSize: 3

  // Keyboard cursor walks these in order. Cards 0–2 also answer to `d` (done).
  readonly property var actions: ["readings", "rosary", "prayer", "hallow", "bibleInAYear"]
  property int cursorIndex: 0
  property bool cursorActive: false
  property bool prayerExpanded: false

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

  function setCursor(index) {
    cursorActive = true
    cursorIndex = Math.max(0, Math.min(actions.length - 1, index))
  }

  function activate(index) {
    var action = actions[Math.max(0, Math.min(actions.length - 1, index))]
    if (action === "prayer") { prayerExpanded = !prayerExpanded; return }
    ora.open(action)
  }

  function toggleDoneAtCursor() {
    var action = actions[cursorIndex]
    if (action === "readings" || action === "rosary" || action === "prayer") ora.toggleDone(action)
  }

  function showPrayer() {
    open()
    prayerExpanded = true
    setCursor(2)
  }

  onOpenedChanged: if (opened) {
    ora.syncIfStale()
    cursorIndex = 0
    cursorActive = false
    prayerExpanded = false
    scroll.contentY = 0
    Qt.callLater(function () { keyCatcher.forceActiveFocus() })
  }

  onCursorIndexChanged: if (cursorActive) scroll.ensureVisible(cursorItem(cursorIndex))

  function cursorItem(index) {
    return [readingsCard, rosaryCard, prayerCard, listenRow, listenRow][Math.max(0, Math.min(4, index))]
  }

  Service { id: ora; settings: root.settings }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { ora.refresh(); return "ok" }
    function sync(): string { ora.sync(); return "ok" }
    function readings(): string { ora.open("readings"); return "ok" }
    function rosary(): string { ora.open("rosary"); return "ok" }
    function prayer(): string { root.showPrayer(); return "ok" }
    function done(kind: string): string {
      if (["readings", "rosary", "prayer"].indexOf(kind) < 0) return "unknown kind"
      ora.toggleDone(kind)
      return "ok"
    }
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
          color: root.tintCross ? root.sacred : button.foreground
        }
      }
    }
    tooltipText: ora.celebration.name ? "Ora · " + ora.celebration.name : "Ora"
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
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(1000))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function (dx, dy) {
        if (dy !== 0) { root.setCursor((root.cursorActive ? root.cursorIndex : -1) + dy); return }
        if (dx !== 0 && root.cursorActive && root.cursorIndex >= 3) root.setCursor(root.cursorIndex + dx)
      }
      onActivateRequested: root.activate(root.cursorActive ? root.cursorIndex : 0)
      onDeleteRequested: root.toggleDoneAtCursor()
      onCloseRequested: root.close()
      onTabRequested: function (direction) { root.switchPanel(direction) }
      onTextKey: function (text) {
        var key = String(text).toLowerCase()
        if (key === "r") ora.sync()
        else if (key === "m") ora.open("readings")
        else if (key === "u") ora.open("usccb")
        else if (key === "p") ora.open("rosary")
        else if (key === "b") ora.open("bibleInAYear")
        else if (key === "d") root.toggleDoneAtCursor()
        else if (key === "a") { root.setCursor(2); root.prayerExpanded = !root.prayerExpanded }
      }

      Flickable {
        id: scroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        function ensureVisible(item) {
          if (!item) return
          var top = item.mapToItem(column, 0, 0).y
          var bottom = top + item.height
          var pad = Style.space(8)
          if (top < contentY) contentY = Math.max(0, top - pad)
          else if (bottom > contentY + height) contentY = Math.min(contentHeight - height, bottom - height + pad)
        }

        Column {
          id: column
          width: scroll.width
          spacing: Style.spacing.panelGap

          // ---------- Hero: liturgical tile · celebration · rank line ----------
          Item {
            width: parent.width
            implicitHeight: Math.max(heroTile.height, heroLabels.implicitHeight)

            Rectangle {
              id: heroTile
              width: Style.space(50)
              height: width
              radius: Style.cornerRadius > 0 ? Style.space(12) : 0
              color: root.tint(root.sacred, 0.16)
              border.width: 1
              border.color: root.tint(root.sacred, 0.55)
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter

              Behavior on color { ColorAnimation { duration: 240 } }
              Behavior on border.color { ColorAnimation { duration: 240 } }

              OraIcon {
                anchors.centerIn: parent
                iconSize: Style.space(28)
                color: root.sacred
              }
            }

            Column {
              id: heroLabels
              anchors.left: heroTile.right
              anchors.leftMargin: Style.space(14)
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(3)

              Text {
                textFormat: Text.PlainText
                width: parent.width
                text: (ora.day.dateLabel || "Today").toUpperCase()
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1.2
                elide: Text.ElideRight
              }

              Text {
                textFormat: Text.PlainText
                width: parent.width
                text: ora.celebration.name || (ora.day.date ? "Ordinary Time" : "Loading the day…")
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
              }

              Text {
                textFormat: Text.PlainText
                width: parent.width
                visible: text !== ""
                text: Model.metaLine(ora.celebration).toUpperCase()
                color: root.sacred
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1.2
                elide: Text.ElideRight
              }

              Text {
                textFormat: Text.PlainText
                width: parent.width
                visible: text !== ""
                text: Model.alsoLine(ora.celebration)
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
              }
            }
          }

          // ---------- Rule progress ----------
          Column {
            width: parent.width
            spacing: Style.space(6)

            Item {
              width: parent.width
              implicitHeight: ruleHeader.implicitHeight

              PanelSectionHeader {
                id: ruleHeader
                text: "TODAY'S RULE"
                foreground: root.foreground
                fontFamily: root.fontFamily
                anchors.left: parent.left
                anchors.bottom: parent.bottom
              }

              Text {
                textFormat: Text.PlainText
                text: ((ora.day.progress || 0) + " OF " + root.ruleSize + "  ·  " + Model.streakLabel(ora.day.streak)).toUpperCase()
                color: (ora.day.progress || 0) >= root.ruleSize ? root.sacred : root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                anchors.right: parent.right
                anchors.bottom: parent.bottom
              }
            }

            Item {
              width: parent.width
              implicitHeight: Style.space(6)

              Rectangle {
                id: ruleTrack
                anchors.fill: parent
                radius: height / 2
                color: root.tint(root.foreground, 0.10)
              }

              Rectangle {
                anchors.left: ruleTrack.left
                anchors.verticalCenter: ruleTrack.verticalCenter
                height: ruleTrack.height
                radius: ruleTrack.radius
                color: root.sacred
                width: ruleTrack.width * Math.min(1, (ora.day.progress || 0) / root.ruleSize)
                Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: 240 } }
              }
            }
          }

          // ---------- The Word ----------
          Card {
            id: readingsCard
            index: 0

            Column {
              width: parent.width
              spacing: Style.space(8)

              CardTitle {
                title: "Mass readings"
                detail: "Bishop Barron's reflection · USCCB Lectionary"
                kind: "readings"
              }

              Column {
                width: parent.width
                spacing: Style.space(3)
                visible: (ora.day.readings || []).length > 0

                Repeater {
                  model: ora.day.readings || []
                  delegate: Row {
                    required property var modelData
                    readonly property bool gospel: modelData.label === "Gospel"
                    width: parent.width
                    spacing: Style.space(8)

                    Text {
                      textFormat: Text.PlainText
                      width: Style.space(66)
                      text: String(modelData.label || "").toUpperCase()
                      color: gospel ? root.sacred : root.faint
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      font.letterSpacing: 0.6
                      anchors.baseline: citation.baseline
                    }

                    Text {
                      id: citation
                      textFormat: Text.PlainText
                      width: parent.width - Style.space(66) - parent.spacing
                      text: modelData.citation || ""
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: gospel ? Style.font.subtitle : Style.font.body
                      font.bold: gospel
                      wrapMode: Text.WordWrap
                    }
                  }
                }
              }

              Text {
                textFormat: Text.PlainText
                width: parent.width
                visible: (ora.day.readings || []).length === 0
                text: ora.syncing ? "Fetching today's citations…" : "Citations arrive after the first sync (press r)."
                color: root.faint
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.WordWrap
              }

              Row {
                spacing: Style.space(6)

                Button {
                  iconText: Model.glyph("bookOpen")
                  text: "Reflection"
                  fontSize: Style.font.bodySmall
                  iconSize: Style.font.body
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  bordered: true
                  tooltipText: "Bishop Barron's daily Gospel reflection"
                  onClicked: ora.open("readings")
                }

                Button {
                  iconText: Model.glyph("openInNew")
                  text: "USCCB"
                  fontSize: Style.font.bodySmall
                  iconSize: Style.font.body
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  bordered: true
                  tooltipText: "Official Lectionary text"
                  onClicked: ora.open("usccb")
                }
              }
            }
          }

          // ---------- The Rosary ----------
          Card {
            id: rosaryCard
            index: 1

            Column {
              width: parent.width
              spacing: Style.space(8)

              CardTitle {
                title: "Pray the Rosary"
                detail: ora.day.mysteryName || "Today's mysteries"
                kind: "rosary"
              }

              Item {
                width: parent.width
                implicitHeight: beads.implicitHeight

                Rectangle {
                  x: Math.round(Style.space(12) / 2)
                  y: Style.space(9)
                  width: 1
                  height: Math.max(0, beads.height - Style.space(18))
                  color: root.tint(root.sacred, 0.35)
                }

                Column {
                  id: beads
                  width: parent.width
                  spacing: Style.space(2)

                  Repeater {
                    model: ora.day.mysteries || []
                    delegate: Row {
                      required property var modelData
                      required property int index
                      width: parent.width
                      height: Style.space(18)
                      spacing: Style.space(10)

                      Item {
                        width: Style.space(12)
                        height: parent.height
                        Rectangle {
                          anchors.centerIn: parent
                          width: Style.space(8)
                          height: width
                          radius: width / 2
                          color: root.sacred
                          border.width: 1
                          border.color: root.tint(root.foreground, 0.25)
                        }
                      }

                      Text {
                        textFormat: Text.PlainText
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - Style.space(12) - parent.spacing
                        text: (index + 1) + ".  " + modelData
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.bodySmall
                        elide: Text.ElideRight
                      }
                    }
                  }
                }
              }
            }
          }

          // ---------- Prayer of the hour ----------
          Card {
            id: prayerCard
            index: 2

            Column {
              width: parent.width
              spacing: Style.space(8)

              Item {
                width: parent.width
                implicitHeight: Math.max(prayerLabels.implicitHeight, prayerToggle.implicitHeight)

                Column {
                  id: prayerLabels
                  anchors.left: parent.left
                  anchors.right: prayerChevron.left
                  anchors.rightMargin: Style.space(8)
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(2)

                  Text {
                    textFormat: Text.PlainText
                    width: parent.width
                    text: ((ora.prayer.slot || "Prayer") + " prayer").toUpperCase()
                    color: root.sacred
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    font.letterSpacing: 1.2
                  }

                  Text {
                    textFormat: Text.PlainText
                    width: parent.width
                    text: ora.prayer.title || "Prayer of the hour"
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.subtitle
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                  }

                  Text {
                    textFormat: Text.PlainText
                    width: parent.width
                    visible: text !== ""
                    text: ora.prayer.subtitle || ""
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                    elide: Text.ElideRight
                  }
                }

                PanelActionButton {
                  id: prayerChevron
                  anchors.right: prayerToggle.left
                  anchors.rightMargin: Style.space(2)
                  anchors.verticalCenter: parent.verticalCenter
                  iconText: root.prayerExpanded ? Model.glyph("chevronUp") : Model.glyph("chevronDown")
                  tooltipText: root.prayerExpanded ? "Collapse" : "Read the prayer"
                  foreground: root.dim
                  hoverColor: root.foreground
                  fontFamily: root.fontFamily
                  onClicked: root.prayerExpanded = !root.prayerExpanded
                }

                DoneButton {
                  id: prayerToggle
                  kind: "prayer"
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                }
              }

              Text {
                textFormat: Text.PlainText
                width: parent.width
                visible: !root.prayerExpanded
                text: Model.splitVersicle((ora.prayer.lines || [""])[0]).body
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.italic: true
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
              }

              Column {
                width: parent.width
                spacing: Style.space(3)
                visible: root.prayerExpanded

                Repeater {
                  model: root.prayerExpanded ? (ora.prayer.lines || []) : []
                  delegate: Item {
                    required property var modelData
                    readonly property var parts: Model.splitVersicle(modelData)
                    width: parent.width
                    implicitHeight: parts.body === "" ? Style.space(6) : verse.implicitHeight

                    Row {
                      id: verse
                      width: parent.width
                      spacing: Style.space(6)
                      visible: parts.body !== ""

                      Text {
                        textFormat: Text.PlainText
                        width: parts.mark ? Style.space(18) : 0
                        text: parts.mark
                        color: root.sacred
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.bodySmall
                        font.bold: true
                        anchors.baseline: body.baseline
                      }

                      Text {
                        id: body
                        textFormat: Text.PlainText
                        width: parent.width - (parts.mark ? Style.space(18) + parent.spacing : 0)
                        text: parts.body
                        color: parts.mark === "R." ? root.foreground : root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.bodySmall
                        font.italic: parts.mark === "" && !/^Hail Mary/.test(parts.body)
                        wrapMode: Text.WordWrap
                        lineHeight: 1.15
                      }
                    }
                  }
                }
              }
            }
          }

          // ---------- This week ----------
          Column {
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              text: "THIS WEEK"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Row {
              id: weekRow
              width: parent.width
              spacing: Style.space(6)
              readonly property real cellWidth: (width - spacing * 6) / 7

              Repeater {
                model: ora.day.week || []
                delegate: Rectangle {
                  required property var modelData
                  width: weekRow.cellWidth
                  height: Style.space(44)
                  radius: Style.cornerRadius > 0 ? Style.space(8) : 0
                  color: modelData.isToday ? root.tint(root.sacred, 0.12) : "transparent"
                  border.width: 1
                  border.color: modelData.isToday ? root.tint(root.sacred, 0.55) : root.tint(root.foreground, 0.08)

                  Column {
                    anchors.centerIn: parent
                    spacing: Style.space(6)

                    Text {
                      textFormat: Text.PlainText
                      anchors.horizontalCenter: parent.horizontalCenter
                      text: modelData.letter || ""
                      color: modelData.isToday ? root.foreground : root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                    }

                    Row {
                      anchors.horizontalCenter: parent.horizontalCenter
                      spacing: Style.space(3)
                      Repeater {
                        model: [modelData.readings, modelData.rosary, modelData.prayer]
                        delegate: Rectangle {
                          required property var modelData
                          width: Style.space(6)
                          height: width
                          radius: width / 2
                          color: modelData ? root.sacred : root.tint(root.foreground, 0.14)
                        }
                      }
                    }
                  }
                }
              }
            }
          }

          // ---------- Listen ----------
          Column {
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              text: "LISTEN"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Row {
              id: listenRow
              width: parent.width
              spacing: Style.space(6)
              readonly property real cellWidth: (width - spacing) / 2

              Button {
                width: listenRow.cellWidth
                iconText: Model.glyph("headphones")
                iconSize: Style.font.title
                text: "Hallow"
                fontSize: Style.font.bodySmall
                foreground: root.foreground
                fontFamily: root.fontFamily
                verticalPadding: Style.spacing.controlPaddingY + Style.space(2)
                bordered: true
                hasCursor: root.cursorActive && root.cursorIndex === 3
                tooltipText: "Guided prayer and meditation"
                onClicked: ora.open("hallow")
                onHovered: function (h) { if (h) root.setCursor(3) }
              }

              Button {
                width: listenRow.cellWidth
                iconText: Model.glyph("podcast")
                iconSize: Style.font.title
                text: "Bible in a Year"
                fontSize: Style.font.bodySmall
                foreground: root.foreground
                fontFamily: root.fontFamily
                verticalPadding: Style.spacing.controlPaddingY + Style.space(2)
                bordered: true
                hasCursor: root.cursorActive && root.cursorIndex === 4
                tooltipText: "Fr. Mike Schmitz · Ascension"
                onClicked: ora.open("bibleInAYear")
                onHovered: function (h) { if (h) root.setCursor(4) }
              }
            }
          }

          Text {
            textFormat: Text.PlainText
            width: parent.width
            text: (ora.day.source === "builtin" ? "Offline calendar · " : "") + "Enter open  ·  d done  ·  a prayer  ·  u USCCB  ·  r sync"
            color: root.faint
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
          }
        }
      }
    }
  }

  // A cursor-aware card. Hover moves the panel cursor here (the shared
  // CursorSurface contract), clicks on the body activate the card, and any
  // controls placed inside sit above the body's MouseArea.
  component Card: CursorSurface {
    id: card
    property int index: 0
    default property alias content: inner.data

    width: parent ? parent.width : implicitWidth
    implicitHeight: inner.implicitHeight + Style.space(24)
    foreground: root.foreground
    accent: root.sacred
    bordered: true
    hasCursor: root.cursorActive && root.cursorIndex === card.index

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: root.activate(card.index)
    }

    HoverHandler {
      onHoveredChanged: if (hovered) root.setCursor(card.index)
    }

    Item {
      id: inner
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.leftMargin: Style.spacing.rowPaddingX
      anchors.rightMargin: Style.spacing.rowPaddingX
      anchors.topMargin: Style.space(12)
      implicitHeight: children.length > 0 ? children[0].implicitHeight : 0
    }
  }

  component CardTitle: Item {
    property string title: ""
    property string detail: ""
    property string kind: ""

    width: parent ? parent.width : implicitWidth
    implicitHeight: Math.max(titleLabels.implicitHeight, titleToggle.implicitHeight)

    Column {
      id: titleLabels
      anchors.left: parent.left
      anchors.right: titleToggle.left
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(2)

      Text {
        textFormat: Text.PlainText
        width: parent.width
        text: title
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.subtitle
        font.weight: Font.DemiBold
        elide: Text.ElideRight
      }

      Text {
        textFormat: Text.PlainText
        width: parent.width
        visible: detail !== ""
        text: detail
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        elide: Text.ElideRight
      }
    }

    DoneButton {
      id: titleToggle
      kind: parent.kind
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  // Check ring at the right edge of each rule card. Done → filled check in
  // the liturgical color; not done → a quiet ring.
  component DoneButton: PanelActionButton {
    property string kind: ""
    readonly property bool done: ora.isDone(kind)

    iconText: done ? Model.glyph("check") : Model.glyph("ring")
    fontSize: Style.font.iconLarge
    foreground: done ? root.sacred : root.dim
    hoverColor: root.sacred
    fontFamily: root.fontFamily
    tooltipText: done ? "Mark as not done" : "Mark as done"
    onClicked: ora.toggleDone(kind)
  }
}
