# NonDot GameLibrary

*English · [Español](README.es.md)*

A shelf to show off your games retro-style. Brings back the thrill of seeing a
box and a disc on your PC.

It is a desktop widget for KDE Plasma 6. Your games appear as boxes on a glass
shelf: hover over one and the box opens; press play and the disc spins while
the game starts. Available in English and Spanish; it follows your system
language.

![A game box opens on the shelf and its disc spins](screenshots/shelf-open.png)

## Features

- **Two styles.** Shelf (spines on shelves; the selected box opens) or jukebox
  (covers facing you, in a row).
- **The box opens and the disc spins** while the game starts. The animation
  length can be changed or turned off.
- **Steam games or any application.** Steam games open with
  `steam://rungameid/…`; everything else with its `.desktop` file. You can add
  several `.desktop` files at once.
- **Your own art.** Spine, cover, logo and disc art. You can cut full box art
  (back cover, spine and front cover in one image) or a disc out of a template.
  For Steam games, one button takes the cover and logo Steam already keeps on
  your computer.
- **Sounds** when moving between games, opening, playing and closing. Each disc
  can have its own sound, and each moment can use a file of yours.
- **Keyboard and gamepad.** A keyboard shortcut opens the library; move with
  the arrows, Enter to play and Esc to leave. With a gamepad, a button
  combination opens it and the d-pad or stick moves through it.
- **Only clears its own monitor.** While the library is open, it minimizes the
  windows on the widget's monitor (not the others) and brings them back later.
  During the animation it keeps the Steam window minimized.
- **Export and import** the game list as a JSON file.
- **Test mode:** everything works the same, but games are not opened.

## Screenshots

| Shelf | Jukebox |
| --- | --- |
| ![Shelf overview](screenshots/shelf.png) | ![Jukebox overview](screenshots/jukebox.png) |
| ![A box slides out of the shelf](screenshots/shelf-highlight.png) | ![The selected cover grows](screenshots/jukebox-highlight.png) |
| ![Open box with its disc](screenshots/shelf-open.png) | ![Open box in the jukebox](screenshots/jukebox-open.png) |

<details>
<summary><b>Settings (7 screenshots)</b></summary>

**Games**

![Games](screenshots/settings-games.png)

**Appearance**

![Appearance](screenshots/settings-appearance.png)

**When Playing**

![When Playing](screenshots/settings-playing.png)

**Sounds**

![Sounds](screenshots/settings-sounds.png)

**Controls**

![Controls](screenshots/settings-controls.png)

**Keyboard Shortcuts**

![Keyboard Shortcuts](screenshots/settings-shortcuts.png)

**About**

![About](screenshots/settings-about.png)

</details>

## Requirements

- **KDE Plasma 6.**
- **Qt 6.9 or newer** for the best quality (soft shadows and crisply clipped
  disc art). With an older Qt, turn on **compatibility mode** in *Appearance*:
  everything works the same, with slightly simpler shadows and edges. If the
  widget detects the modern pieces are missing, it switches to the compatible
  version on its own.

Optional:

- **Qt Multimedia** (package `qt6-multimedia` with its FFmpeg backend) for
  sounds. Without it, the widget works silently.
- **Python 3** for the gamepad. The helper only uses the standard library and
  reads gamepads from `/dev/input/event*`, never writing to them.
- **Steam**, if you want to add Steam games.

Tested on CachyOS with Plasma 6.8 on Wayland and Qt 6.12.

## Installation

From Plasma: in the panel for adding widgets, get new widgets and search for
“NonDot GameLibrary” (it is installed from the KDE Store).

Or with the `.plasmoid` file from the releases page:

```bash
kpackagetool6 -t Plasma/Applet -i nondot-gamelibrary-1.0.0.plasmoid
```

To update, replace `-i` with `-u`.

## Getting started

1. Add the widget to the desktop and press **Add games…**.
2. In *Configure… → Games*, add a Steam game (with its Steam id) or choose the
   `.desktop` file of any game or application.
3. Give it a shortcut in *Configure… → Keyboard Shortcuts* (for example,
   Ctrl+Alt+G).

> **Important for gamepads:** the gamepad opens the library by triggering that
> shortcut, so it does not work without one. Turn it on in
> *Configure… → Controls*.

## Where it keeps your things

- The game list and settings, in the Plasma configuration, like any widget.
- Images and sounds you choose are copied to
  `~/.local/share/nondot-gamelibrary`, so they are not lost if you move the
  original. *Games → Clean up unused images…* deletes the copies no game uses
  anymore.
- A temporary KWin script in `~/.cache/nondot-gamelibrary` while the library is
  open.

The widget does not connect to the internet.

## Development

```
package/   the widget (metadata.json and contents/)
po/        translations (template.pot and one .po per language)
tests/     automated tests (qmltestrunner)
tools/     packaging, translations and sound generator
```

Build the `.plasmoid`:

```bash
python3 tools/pack.py
```

Run the tests (no windows are opened):

```bash
for t in tests/tst_*.qml; do QT_QPA_PLATFORM=offscreen /usr/lib/qt6/bin/qmltestrunner -input "$t"; done
```

The widget's texts are written in English. To add or update a translation,
create or edit `po/<language>.po` and run (requires gettext):

```bash
python3 tools/translations.py
```

It extracts the texts to `po/template.pot`, updates each `.po` and compiles
them into `package/contents/locale`.

The sounds in `package/contents/sounds` are original: they are generated by
`tools/make_sounds.py`.

## License

GPL-2.0-or-later. See [LICENSE](LICENSE).
