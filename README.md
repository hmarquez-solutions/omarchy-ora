# Ora for Omarchy

A quiet Catholic rule of prayer in the Omarchy bar.

Ora puts the day, the Rosary, and trusted Catholic resources one click away. It uses local state, native Omarchy notifications, and official provider links—no account, analytics, scraping, or bundled copyrighted devotional content.

## Features

- Liturgical season and color in the bar
- Today's Rosary mysteries
- Official daily Mass readings from the USCCB
- Daily Gospel Reflections from Word on Fire
- Launch links for Hallow and Fr. Mike Schmitz's Bible in a Year
- Configurable daily reminders for the readings, Angelus, and Rosary
- Local completion marks retained for 45 days
- Mouse and keyboard navigation

Ora's built-in calendar intentionally covers broad Roman-calendar seasons and major fixed solemnities. The linked USCCB page remains authoritative for the complete local calendar and daily readings.

## Install

```bash
omarchy plugin add https://github.com/hmarquez-solutions/omarchy-ora --enable
```

If your Omarchy version expects a manual clone:

```bash
git clone https://github.com/hmarquez-solutions/omarchy-ora \
  ~/.config/omarchy/plugins/io.github.hmarquez-solutions.ora
omarchy-shell shell rescanPlugins
```

Then add **Ora** to the bar from Omarchy's bar settings. The plugin defaults to the right section.

## Controls

- Left click: open Ora
- Right click: open today's Mass readings
- Arrow keys or `j`/`k`: move through actions
- Enter: activate
- `m`: open Mass readings
- `r`: refresh
- Escape: close

## Privacy and content

Completion state stays in `~/.local/state/omarchy/ora/state.json`. Ora links to third-party content in the browser; it does not download, reproduce, or proxy that content. Hallow is currently a launch integration because it does not offer a documented public content API.

## Development

```bash
./ora today
./ora today --date 2026-04-05
python3 -m unittest discover -s tests -v
```

User plugin files hot-reload under `~/.config/omarchy/plugins/`. For development, clone or symlink this repository there and run `omarchy-shell shell rescanPlugins` if needed.

## License

MIT
