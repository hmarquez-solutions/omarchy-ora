import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

Item {
  id: root

  property var settings: ({})
  property var day: ({})
  property string lastReadingsReminder: ""
  property string lastAngelusReminder: ""
  property string lastRosaryReminder: ""
  readonly property string helper: Qt.resolvedUrl("ora").toString().replace("file://", "")

  signal refreshed

  function setting(key, fallback) {
    return settings && settings[key] !== undefined ? settings[key] : fallback
  }

  function refresh() {
    if (!todayProcess.running) todayProcess.running = true
  }

  function applyToday(raw) {
    try {
      day = JSON.parse(String(raw || "{}"))
      refreshed()
    } catch (error) {
      console.warn("ora: invalid helper response", error)
    }
  }

  function run(args) {
    actionProcess.command = [helper].concat(args)
    if (!actionProcess.running) actionProcess.running = true
  }

  function complete(kind) {
    var current = day.completed && day.completed[kind] === true
    run(["complete", kind, current ? "false" : "true"])
  }

  function open(provider) { run(["open", provider]) }

  function maybeRemind() {
    if (setting("remindersEnabled", true) !== true) return
    var now = new Date()
    var stamp = now.getFullYear() + "-" + now.getMonth() + "-" + now.getDate()
    if (Model.due(now, setting("readingsReminder", "07:30")) && lastReadingsReminder !== stamp) {
      lastReadingsReminder = stamp
      run(["notify", "readings"])
    } else if (Model.due(now, setting("angelusReminder", "12:00")) && lastAngelusReminder !== stamp) {
      lastAngelusReminder = stamp
      run(["notify", "angelus"])
    } else if (Model.due(now, setting("rosaryReminder", "20:00")) && lastRosaryReminder !== stamp) {
      lastRosaryReminder = stamp
      run(["notify", "rosary"])
    }
  }

  Process {
    id: todayProcess
    command: [root.helper, "today"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.applyToday(text) }
  }

  Process {
    id: actionProcess
    onExited: root.refresh()
  }

  Timer { interval: 60000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.maybeRemind() }
  Timer { interval: 900000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }
}
