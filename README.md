# Ora for Omarchy

A quiet Catholic rule of prayer in the Omarchy bar.

Ora puts the liturgical day, the Mass readings, the Rosary, and a prayer for the hour one click away. It uses local state, native Omarchy notifications, and links to trusted providers—no account, no analytics, no bundled copyrighted content.

## Features

- **Today's celebration** from the US Roman calendar: memorials, feasts, and solemnities with their rank and liturgical color (Liturgical Calendar API, cached per year; a built-in season calendar covers offline use)
- **Mass reading citations** for the day, Gospel emphasized, with one-click access to Bishop Barron's Word on Fire reflection and the official USCCB Lectionary text
- **Rosary** mysteries for the weekday, shown as a bead chain
- **Prayer of the hour**: Morning Offering, Angelus (Regina Caeli in Easter), Memorare, and the Act of Contrition, readable in the panel
- **Rule tracking**: mark readings, Rosary, and prayer done; a progress bar, a seven-day strip, and a streak keep you honest
- Reminders for the readings, Angelus, and Rosary, with click-to-open
- Launch links for Hallow and Fr. Mike Schmitz's Bible in a Year
- Optional liturgical tint for the bar cross
- Mouse and keyboard navigation, IPC for scripting

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
- Arrow keys or `j`/`k`: move through the cards
- Enter: open the card (the prayer card expands instead)
- `d` or `x`: mark the highlighted card done or not done
- `m`: open the Word on Fire reflection
- `u`: open the USCCB readings
- `p`: open the Rosary how-to
- `a`: show the prayer of the hour
- `b`: open Bible in a Year
- `r`: sync calendar and readings now
- Escape: close

## IPC

```bash
omarchy-shell ora toggle          # open or close the panel
omarchy-shell ora prayer          # open with the prayer of the hour expanded
omarchy-shell ora readings        # open today's reflection in the browser
omarchy-shell ora rosary
omarchy-shell ora done rosary     # toggle a rule item: readings | rosary | prayer
omarchy-shell ora sync            # refresh the network caches
```

## Settings

- **Color the bar cross by liturgical season** (off by default)
- **Prayer reminders** on/off, with times for the readings, Angelus, and Rosary in 24-hour `HH:MM`

## Data sources and privacy

- Celebrations come from the [Liturgical Calendar API](https://litcal.johnromanodorazio.com/) for the US national calendar, cached for the civil year in `~/.cache/omarchy/ora/`.
- Reading citations and the day's reflection link come from the USCCB and Word on Fire RSS feeds, cached for six hours. Only citations are stored; the Lectionary text stays on USCCB's page.
- Completion state stays in `~/.local/state/omarchy/ora/state.json` and is trimmed to 45 days.
- Ora links to third-party content in the browser; it does not proxy or reproduce it. Hallow is a launch link because it has no public content API.

## Development

```bash
./ora today                       # cache-only payload the panel reads
./ora today --sync                # fetch calendar and feeds first
./ora today --date 2026-04-05T12:00
python3 -m unittest discover -s tests -v
```

Clone or symlink this repository into `~/.config/omarchy/plugins/`. The shell watches that directory for changes, but it does not follow symlinks, and it caches compiled QML, so after editing QML run `omarchy-restart-shell`.

## License

MIT
