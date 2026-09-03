import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

// Talks to the `ora` helper. `refresh()` reads the local cache (instant);
// `sync()` lets the helper hit the network first, so it runs on a slow timer
// and never in the click path.
Item {
  id: root

  property var settings: ({})
  property var day: ({})
  property bool syncing: false
  property double lastSyncMs: 0
  property string lastReadingsReminder: ""
  property string lastAngelusReminder: ""
  property string lastRosaryReminder: ""
  readonly property string helper: Qt.resolvedUrl("ora").toString().replace("file://", "")
  readonly property var celebration: day.celebration || ({})
  readonly property var completed: day.completed || ({})
  readonly property var prayer: day.prayer || ({})

  signal refreshed

  function setting(key, fallback) {
    return settings && settings[key] !== undefined && settings[key] !== null ? settings[key] : fallback
  }

  function refresh() {
    if (!todayProcess.running) todayProcess.running = true
  }

  function sync() {
    if (syncProcess.running) return
    syncing = true
    syncProcess.running = true
  }

  // Sync if the caches are older than half an hour; otherwise just re-read.
  function syncIfStale() {
    if (Date.now() - lastSyncMs > 30 * 60 * 1000) sync()
    else refresh()
  }

  function applyToday(raw) {
    try {
      var parsed = JSON.parse(String(raw || "{}"))
      if (parsed && parsed.date) {
        day = parsed
        refreshed()
      }
    } catch (error) {
      console.warn("ora: invalid helper response", error)
    }
  }

  function run(args) {
    actionProcess.command = [helper].concat(args)
    if (!actionProcess.running) actionProcess.running = true
  }

  function isDone(kind) { return completed[kind] === true }

  function toggleDone(kind) {
    run(["complete", kind, isDone(kind) ? "false" : "true"])
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
    id: syncProcess
    command: [root.helper, "today", "--sync"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.applyToday(text) }
    onExited: {
      root.syncing = false
      root.lastSyncMs = Date.now()
    }
  }

  Process {
    id: actionProcess
    onExited: root.refresh()
  }

  Timer { interval: 60000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.maybeRemind() }
  Timer { interval: 30 * 60 * 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.sync() }
  // The prayer of the hour and the date roll over without any action; re-read
  // the cache every few minutes so the panel is right when it opens.
  Timer { interval: 5 * 60 * 1000; running: true; repeat: true; onTriggered: root.refresh() }
}
