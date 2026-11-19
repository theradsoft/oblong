# oblong

Rectangle-style keyboard window management for Windows 11, written in AutoHotkey v2.

Snap the active window to fractions of the screen (1/4, 1/3, 1/2, 2/3, 3/4, or any
fraction you type) at the top half, bottom half or full height. Repeat presses cycle the
window through positions, and you can define your own cycles. Everything is configured
from a settings window.

## Documentation

Full guides are in [`docs/`](docs/README.md):
[installation](docs/installation.md), [usage](docs/usage.md),
[compiling to an .exe](docs/compiling.md) and [known issues](docs/known-issues.md).

## Requirements

- Windows 10 or 11
- [AutoHotkey v2](https://www.autohotkey.com)

## Getting started

1. Install AutoHotkey v2.
2. Keep `oblong.ahk` and `oblong.ico` together in a folder and double-click `oblong.ahk`.
   The oblong icon appears in the tray.
3. Double-click the tray icon (or right-click > **Settings...**) to change shortcuts and options.

Settings are saved to `Oblong.ini` next to the script and created with defaults on first run.

## Default shortcuts

Keyboard rows match screen position. All use **Ctrl+Alt**.

| | 1/4 | 1/3 | 1/2 | 2/3 | 3/4 |
|---|---|---|---|---|---|
| Top half | 1 | 2 | 3 | 4 | 5 |
| Full height | Q | W | E | R | T |
| Bottom half | A | S | D | F | G |

Pressing the same shortcut again slides the window to the next position at the same size.
Number-row shortcuts also work on the numpad.

| Shortcut | Action |
|---|---|
| Ctrl+Alt+Enter | Maximize |
| Ctrl+Alt+Shift+Enter | Almost maximize |
| Ctrl+Alt+Shift+Up | Maximize height |
| Ctrl+Alt+C | Center |
| Ctrl+Alt+Backspace | Restore size and position from before the first snap |
| Ctrl+Alt+Win+Right / Left | Next / previous monitor |

## Custom cycles

In the settings window, add a shortcut, choose **Fraction**, pick a width and click the
spots in the order you want them visited. Under the hood each action is a short string:

| Action | Behavior |
|---|---|
| `1/4 Top Bottom Full` | every top slot, then bottom, then full height |
| `1/3 Top Bottom` | top and bottom only |
| `1/4 Top Bottom down` | column by column: top 1, bottom 1, top 2, bottom 2... |
| `1/4 Top@2` | always the second quarter, top half (no cycling) |
| `1/2 Full@2 Top@1 Bottom@1` | exactly these slots, in this order |
| `1/2 +1/4 Full` | centred half: offset 1/4 from the left (`-1/4` measures from the right) |
| `1/1 Top Bottom` | full width: top half, then bottom half (`1/1` = the whole width) |

## Window sets

A window set remembers where each app's windows sit on your desktop, so you can arrange
them that way again with one shortcut. Open them from the tray icon >
**Window sets...**: click **Save this desktop as...**, give the set a name, and recall it
later from that window, from the tray's **Recall window set** menu, or with a shortcut
(choose **Save window set** or **Recall window set** as the action in the shortcut editor;
leave the set name blank to pick the set from a list each time you press it).

- **Any desktop:** works the same whether you use one desktop or several virtual
  desktops. With virtual desktops, saving and recalling only involve the desktop that's
  showing, so you can set up each one and save it under its own name, or reuse one set on
  any of them.
- **By app, not by window:** windows are matched by program (`chrome.exe`), so changing
  titles don't matter. With several windows of one app, each saved spot gets the nearest
  one, and any extra windows stack onto their nearest spot (most recently used on top).
  Turn on **Cascade** for a set to offset stacked windows so their title bars show.
- **Tied to monitors:** each spot remembers its monitor by hardware ID, so it survives
  reordering and resolution changes. If that monitor isn't connected, the window goes to
  the same relative spot on the main monitor (or is skipped, if you turn that option off).
- **Editable:** select a set and click **Edit apps...** (or double-click it) to change its
  list of apps. Each row is one spot: the app (`chrome.exe`), its monitor, and its
  position as percentages of the monitor (or maximized). Add apps that weren't open when
  you saved, remove ones you don't want, move a spot to another monitor, or duplicate a
  row to give an app a second spot. Saving the desktop again under the same name
  replaces your edits.
- Minimized windows are ignored when saving and recalling.

## Notes

- Windows running as administrator (e.g. Task Manager) can only be moved if the script
  also runs as administrator.
- Some Intel graphics drivers use Ctrl+Alt+arrows to rotate the screen; disable that in
  the Intel control panel if it conflicts.
- If you move the script, toggle **Start with Windows** off and on again so the startup
  shortcut points at the new location.
