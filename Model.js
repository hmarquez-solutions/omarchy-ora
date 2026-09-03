.pragma library

// Nerd Font (Material Design set) icons. Code points above U+FFFF cannot be
// spelled with "\uXXXX" in QML strings, so they are built at load time.
var glyphs = {
  check: String.fromCodePoint(0xf012c),
  ring: String.fromCodePoint(0xf0130),
  bookOpen: String.fromCodePoint(0xf00bd),
  openInNew: String.fromCodePoint(0xf03cc),
  chevronDown: String.fromCodePoint(0xf0140),
  chevronUp: String.fromCodePoint(0xf0143),
  headphones: String.fromCodePoint(0xf02cb),
  podcast: String.fromCodePoint(0xf0994),
  cross: String.fromCodePoint(0xf0953)
}

function glyph(name) { return glyphs[name] || "" }

// Liturgical colors tuned to read on both dark and light shell themes.
// "White" is rendered as vestment gold, its traditional substitute, because
// literal white vanishes on a light panel.
function liturgicalColor(value) {
  var colors = {
    green: "#5b9a63",
    violet: "#8d6db3",
    purple: "#8d6db3",
    white: "#cfae5a",
    gold: "#cfae5a",
    red: "#c0524f",
    rose: "#d48aa3",
    black: "#6f6f78"
  }
  return colors[String(value || "green").toLowerCase()] || colors.green
}

// "MEMORIAL · ORDINARY TIME · YEAR II" — the small-caps line under the
// celebration name. Weekdays swap the (empty) rank for the week number.
function metaLine(celebration) {
  var c = celebration || {}
  var parts = []
  if (c.rank) parts.push(c.rank)
  else if (c.week) parts.push("Week " + c.week)
  if (c.season && c.season !== c.name) parts.push(c.season)
  if (c.liturgicalYear) parts.push(c.liturgicalYear)
  return parts.join("  ·  ")
}

// Secondary celebrations and vigils worth a mention beneath the headline.
function alsoLine(celebration) {
  var c = celebration || {}
  var bits = []
  if (c.weekdayName) bits.push(c.weekdayName)
  var also = c.alsoToday || []
  for (var i = 0; i < also.length; i++) bits.push("Also: " + also[i])
  if (c.vigil) bits.push("Evening: Vigil of the " + c.vigil)
  return bits.join("  ·  ")
}

// Prayer lines are plain strings; versicles carry a "V. " / "R. " prefix
// that the panel renders as a colored responsory mark.
function splitVersicle(line) {
  var text = String(line || "")
  var match = text.match(/^([VR])\.\s+(.*)$/)
  if (match) return { mark: match[1] + ".", body: match[2] }
  return { mark: "", body: text }
}

function streakLabel(days) {
  var n = Number(days) || 0
  if (n <= 0) return "Start a streak today"
  return n + (n === 1 ? "-day streak" : "-day streak")
}

function validTime(value) {
  return /^([01][0-9]|2[0-3]):[0-5][0-9]$/.test(String(value || ""))
}

function due(now, value) {
  if (!validTime(value)) return false
  var hh = String(now.getHours()).padStart(2, "0")
  var mm = String(now.getMinutes()).padStart(2, "0")
  return hh + ":" + mm === value
}
