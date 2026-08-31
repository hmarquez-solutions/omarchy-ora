.pragma library

function mysteryForWeekday(day) {
  var mysteries = [
    "Glorious Mysteries",
    "Joyful Mysteries",
    "Sorrowful Mysteries",
    "Glorious Mysteries",
    "Luminous Mysteries",
    "Sorrowful Mysteries",
    "Joyful Mysteries"
  ]
  return mysteries[Math.max(0, Math.min(6, Number(day) || 0))]
}

function liturgicalColor(value) {
  var colors = {
    green: "#4f8f55",
    violet: "#74538f",
    white: "#d8cfae",
    red: "#a94b4b",
    rose: "#c9798f"
  }
  return colors[String(value || "green").toLowerCase()] || colors.green
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
