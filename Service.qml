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

  // Fixed interpreter and script path, never a PATH lookup. The helper is what
  // carries a click to the browser and a reminder to the notification daemon,
  // so nothing in the session may redirect it. `-I` ignores every PYTHON*
  // variable and keeps the script's own directory off sys.path.
  readonly property string interpreter: "/usr/bin/python3"
  readonly property string helper: decodeURIComponent(Qt.resolvedUrl("ora").toString().replace(/^file:\/\//, ""))
  readonly property var celebration: day.celebration || ({})
  readonly property var completed: day.completed || ({})
  readonly property var prayer: day.prayer || ({})

  // A day's payload is a few kilobytes; treat anything far past that as not ours.
  readonly property int maxPayloadChars: 262144
  readonly property int actionTimeoutMs: 10000
  readonly property int syncTimeoutMs: 90000

  signal refreshed

  function setting(key, fallback) {
    return settings && settings[key] !== undefined && settings[key] !== null ? settings[key] : fallback
  }

  // The helper's whole environment. Nothing inherited: the interpreter and the
  // dynamic loader never see PYTHONPATH, LD_PRELOAD or a shadowed PATH. What is
  // passed through is what xdg-open, the browser it launches and the D-Bus
  // notification call need to land on the user's own session and look like
  // the rest of their desktop.
  function helperEnvironment() {
    var env = { PATH: "/usr/bin:/bin" }
    var keep = [
      "HOME", "USER", "LOGNAME", "TZ",
      "LANG", "LANGUAGE", "LC_ALL", "LC_MESSAGES", "LC_TIME",
      "XDG_RUNTIME_DIR", "XDG_STATE_HOME", "XDG_CACHE_HOME", "XDG_CONFIG_HOME",
      "XDG_DATA_HOME", "XDG_DATA_DIRS", "XDG_CONFIG_DIRS",
      "XDG_CURRENT_DESKTOP", "XDG_SESSION_TYPE", "XDG_SESSION_ID", "XDG_SESSION_DESKTOP",
      "WAYLAND_DISPLAY", "DISPLAY", "XAUTHORITY", "DBUS_SESSION_BUS_ADDRESS",
      "HYPRLAND_INSTANCE_SIGNATURE",
      "GDK_BACKEND", "GDK_SCALE", "GDK_DPI_SCALE", "GTK_THEME", "GTK_USE_PORTAL",
      "QT_QPA_PLATFORM", "QT_QPA_PLATFORMTHEME", "QT_STYLE_OVERRIDE",
      "QT_AUTO_SCREEN_SCALE_FACTOR", "QT_SCALE_FACTOR", "QT_WAYLAND_DISABLE_WINDOWDECORATION",
      "SDL_VIDEODRIVER", "CLUTTER_BACKEND", "MOZ_ENABLE_WAYLAND", "ELECTRON_OZONE_PLATFORM_HINT",
      "XCURSOR_THEME", "XCURSOR_SIZE", "HYPRCURSOR_THEME", "HYPRCURSOR_SIZE"
    ]
    for (var i = 0; i < keep.length; i++) {
      var value = Quickshell.env(keep[i])
      if (value) env[keep[i]] = String(value)
    }
    if (!env.LANG) env.LANG = "C.UTF-8"
    return env
  }

  function helperCommand(args) {
    return [interpreter, "-I", helper].concat(args)
  }

  function refresh() {
    if (!todayProcess.running) todayProcess.running = true
  }

  function sync() {
    if (syncProcess.running) return
    syncing = true
    syncTimeout.restart()
    syncProcess.running = true
  }

  // Sync if the caches are older than half an hour; otherwise just re-read.
  function syncIfStale() {
    if (Date.now() - lastSyncMs > 30 * 60 * 1000) sync()
    else refresh()
  }

  function applyToday(raw) {
    var text = String(raw || "{}")
    if (text.length > maxPayloadChars) {
      console.warn("ora: helper response too large, ignored")
      return
    }
    try {
      var parsed = JSON.parse(text)
      if (parsed && parsed.date) {
        day = parsed
        refreshed()
      }
    } catch (error) {
      console.warn("ora: invalid helper response", error)
    }
  }

  function run(args) {
    if (actionProcess.running) return
    actionProcess.command = helperCommand(args)
    actionTimeout.restart()
    actionProcess.running = true
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
    command: root.helperCommand(["today"])
    clearEnvironment: true
    environment: root.helperEnvironment()
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.applyToday(text) }
  }

  Process {
    id: syncProcess
    command: root.helperCommand(["today", "--sync"])
    clearEnvironment: true
    environment: root.helperEnvironment()
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.applyToday(text) }
    onExited: {
      syncTimeout.stop()
      root.syncing = false
      root.lastSyncMs = Date.now()
    }
  }

  Process {
    id: actionProcess
    clearEnvironment: true
    environment: root.helperEnvironment()
    onExited: {
      actionTimeout.stop()
      root.refresh()
    }
  }

  // Watchdogs: the helper's own network timeouts bound a sync at well under a
  // minute, and an action only spawns xdg-open or a D-Bus call. A process that
  // outlives these is stuck, and SIGKILL ends it whatever it is doing.
  Timer {
    id: actionTimeout
    interval: root.actionTimeoutMs
    repeat: false
    onTriggered: if (actionProcess.running) actionProcess.signal(9)
  }

  Timer {
    id: syncTimeout
    interval: root.syncTimeoutMs
    repeat: false
    onTriggered: if (syncProcess.running) syncProcess.signal(9)
  }

  Timer { interval: 60000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.maybeRemind() }
  Timer { interval: 30 * 60 * 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.sync() }
  // The prayer of the hour and the date roll over without any action; re-read
  // the cache every few minutes so the panel is right when it opens.
  Timer { interval: 5 * 60 * 1000; running: true; repeat: true; onTriggered: root.refresh() }
}
