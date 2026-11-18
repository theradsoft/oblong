# Using oblong

oblong moves the active window with keyboard shortcuts: snap it to fractions of the
screen, cycle it through positions, move it between monitors, and save and recall whole
layouts of windows ("window sets"). Everything is configured from the tray icon.

- [The tray icon](#the-tray-icon)
- [Default shortcuts](#default-shortcuts)
- [How snapping and cycling work](#how-snapping-and-cycling-work)
- [Settings window](#settings-window)
- [Adding and editing shortcuts](#adding-and-editing-shortcuts)
- [Window sets](#window-sets)
- [Action reference](#action-reference)
- [The settings file](#the-settings-file)

## The tray icon

Right-click the oblong tray icon for:

| Item | What it does |
|---|---|
| **Settings...** | Shortcuts and options. Also opens when you double-click the icon, or with a shortcut set to **Open settings**. |
| **Window sets...** | Save, edit, recall, rename and delete window sets. |
| **Recall window set** | A submenu with one entry per saved set; click one to recall it. |
| **Open Oblong.ini** | Opens the settings file in your text editor. |
| **Suspend Hotkeys** | (AutoHotkey's own item) Turns all oblong shortcuts off until you untick it. |
| **Exit** | Closes oblong. |

## Default shortcuts

The keyboard rows match the screen: the number row is the top half, Q-T is full height,
A-G is the bottom half. All use **Ctrl+Alt**.

| | 1/4 | 1/3 | 1/2 | 2/3 | 3/4 |
|---|---|---|---|---|---|
| **Top half** | Ctrl+Alt+1 | Ctrl+Alt+2 | Ctrl+Alt+3 | Ctrl+Alt+4 | Ctrl+Alt+5 |
| **Full height** | Ctrl+Alt+Q | Ctrl+Alt+W | Ctrl+Alt+E | Ctrl+Alt+R | Ctrl+Alt+T |
| **Bottom half** | Ctrl+Alt+A | Ctrl+Alt+S | Ctrl+Alt+D | Ctrl+Alt+F | Ctrl+Alt+G |

| Shortcut | Action |
|---|---|
| Ctrl+Alt+Enter | Maximize |
| Ctrl+Alt+Shift+Enter | Almost maximize (centered, 90% of the screen by default) |
| Ctrl+Alt+Shift+Up | Maximize height (keep width and left edge) |
| Ctrl+Alt+C | Center (keep size) |
| Ctrl+Alt+Backspace | Restore the size and position from before oblong first moved the window |
| Ctrl+Alt+Win+Right | Move to the next monitor |
| Ctrl+Alt+Win+Left | Move to the previous monitor |

Number-row shortcuts also work on the numpad, with NumLock on or off (see
**Numpad works too** below).

There are no default shortcuts for window sets; add your own (see
[Window sets](#window-sets)).

## How snapping and cycling work

- **Widths** are fractions of the monitor's usable area (the screen minus the taskbar).
  A width is split into columns from the left; if they don't reach the right edge, one
  more right-aligned column is added. So 1/4 has four columns, 1/3 has three, 2/3 has two
  (left and right), 3/4 has two (left and right).
- **Offsets** start the columns a fraction in from the left or right edge instead. A 1/2
  width with a 1/4 offset is a centred half (1/4 free on each side). A 1/4 width with a
  1/8 offset gives three columns, at 1/8, 3/8 and 5/8. With an offset, no extra column is
  added to reach the far edge.
- **Repeat presses cycle the position, never the size.** Press Ctrl+Alt+1 once and the
  window goes to the top-left quarter; press again and it moves to the next quarter to the
  right, and so on, wrapping around.
- Cycling continues only while you keep pressing the same shortcut on the same window and
  the window is still where oblong put it. Move or resize it yourself, switch windows, or
  use a different shortcut, and the next press starts again from the first position.
- **Monitors:** the window is placed on whichever monitor it's mostly on. Next/previous
  monitor keep the window's relative size and position, and keep it maximized if it was.
  If an app won't shrink that small (Windows Terminal has a minimum width, for example),
  it's slid back inside the monitor, and moving it back still returns it to where it was.
  Monitors are ordered left to right, then top to bottom.
- **Restore** remembers each window's position from before oblong first moved it, until
  you use Restore on it.

## Settings window

Open with a double-click on the tray icon.

The list shows every shortcut and its action. Use **Add...**, **Edit...** (or
double-click a row), **Duplicate...** (a new shortcut with the same action) and
**Delete**. Ctrl-click (or Shift-click for a range) to select several rows: **Delete**
then deletes all the selected shortcuts, and the **Folder** box moves them all.

| Setting | Meaning |
|---|---|
| **Gap between windows (px)** | Space left around snapped windows: between the screen edge and a window, and between two snapped windows. 0 = windows touch. |
| **Almost maximize size (%)** | How much of the screen *Almost maximize* uses (50-100). |
| **Repeat presses cycle** | Untick to make every press go to the first position only. |
| **Numpad works too** | Shortcuts using a number-row digit also work with the same numpad digit. |
| **Start with Windows** | Adds or removes the startup shortcut. |

Nothing changes until you save; shortcuts then take effect immediately, without
restarting. **Save** keeps the window open (the time of the last save shows beside the
buttons), so you can try a shortcut and keep adjusting; **Save and Close** saves and closes
it. **Cancel** closes the window and throws away changes made since the last save. If a
shortcut can't be registered (for example another program already owns it), oblong lists
it after saving.

### Folders

To keep a long list manageable, put shortcuts in folders. Shortcuts without a folder are
listed first, then a row for each folder showing how many shortcuts it holds.
**Double-click a folder row** to collapse (▶) or expand (▼) it; oblong remembers which
folders are collapsed.

- **Moving shortcuts:** select one or more shortcuts, then choose a folder in the
  **Folder** box under the list (or **(no folder)** to take them out). The box shows the
  selected shortcuts' current folder, or is blank if they're in different ones. Moving
  into a collapsed folder keeps it collapsed, so you can file a long list without it
  growing.
- **New folder...** creates a folder. If shortcuts are selected, they're moved into it.
- The shortcut editor also has a **Folder** box: pick a folder, type a new name, or leave
  it blank.
- With a folder row selected, **Edit...** renames the folder (renaming it to another
  folder's name merges the two), and **Delete** removes the folder but keeps its
  shortcuts, which move out to the top of the list. If you select shortcuts too, those
  are deleted.
- **Add...** puts the new shortcut in the selected folder (or the folder of the selected
  shortcut). **Duplicate...** keeps the original's folder.
- Folders stay until you delete them, even when empty. Like everything else in this
  window, folder changes are kept only when you click **Save**.

## Adding and editing shortcuts

The shortcut editor opens from **Add...**, **Edit...** or **Duplicate...**.

1. **Shortcut:** click **Record...** and press the key combination. It must include
   Ctrl, Alt, Shift or Win. Press Esc to cancel recording. While recording, oblong's own
   shortcuts are paused. If the combination is already used, the editor says what for,
   and asks before replacing it when you click OK.
2. **Action:** choose what the shortcut does:
   - **Fraction (cycle spots)** - snap to a width and cycle through spots (below).
   - **Maximize**, **Almost maximize**, **Maximize height**, **Center**, **Restore**,
     **Next display**, **Previous display**.
   - **Save window set** / **Recall window set** - type or pick a set name, or leave the
     name blank to choose a set each time you press the shortcut (see
     [Shortcuts that ask which set](#shortcuts-that-ask-which-set)).
   - **Open settings** - opens this settings window.

   **Folder** (beside Action) puts the shortcut in a folder in the list; see
   [Folders](#folders).
3. The **Result** box shows the action exactly as it will be stored.

### Fraction actions: picking spots

- **Width:** pick 1/4, 1/3, 1/2, 2/3 or 3/4, or type any fraction such as `2/5` (up to 12
  columns).
- **Offset:** leave it at **None**, or pick or type a fraction to start the columns that
  far in from the edge chosen beside it (**from left** or **from right**). Width plus
  offset must fit on the screen. For a centred half, choose width 1/2 and offset 1/4. The
  spot buttons shift to show where the windows will go.
- **Spots:** the grid shows every column at three heights: top half, bottom half and full
  height. Click spots in the order you want them visited. Each spot's button shows its
  number in the cycle (`#1`, `#2`...). A spot can be added more than once.
- **All top / All bottom / All full** add every column at that height, left to right.
- **Cycle order** lists the steps; use **Up**, **Down**, **Remove** and **Clear** to adjust.
- **Across** (default) visits each step in turn: all top spots, then all bottom spots.
  **Down** goes column by column: top 1, bottom 1, top 2, bottom 2...

Examples:

| You want | Set up |
|---|---|
| One key that walks a quarter-width window across the top, then the bottom | 1/4, **All top**, **All bottom** |
| A key that always puts the window in the second third, full height (no cycling) | 1/3, click the 2nd full-height spot |
| Left half, then right half, then top-left half | 1/2, click full 1, full 2, top 1 |

One action has one width. For different widths, use separate shortcuts.

## Window sets

A window set is a saved layout: which apps go where. Use one to put your usual coding,
writing or meeting layout back with a single key.

### Desktops

Window sets work on **the desktop you're looking at**, whatever kind it is:

- **If you don't use virtual desktops,** you just have the one desktop, and window sets
  work with all your open windows. Nothing else to think about.
- **If you use virtual desktops** (Task View, or Win+Ctrl+D), "the desktop" means the one
  that's showing when you save or recall. Your original desktop and any you've added work
  the same way.

Saving only records windows on that desktop, and recalling only moves windows on that
desktop. Windows on your other desktops are never looked at or moved. So you can arrange
each desktop and save it under its own name, or save one layout and recall it on any
desktop.

### Saving a set

1. Arrange your windows on the desktop.
2. Tray icon > **Window sets...** > **Save this desktop as...**, and type a name (letters,
   numbers, spaces, `-`, `_` and `.`; up to 40 characters).

Saving records every normal window on the desktop: its app (the program, e.g.
`chrome.exe`), its monitor, and its position. Minimized windows, dialogs, popups and
oblong's own windows are left out, as are windows on other virtual desktops if you use
them. Saving under an existing name replaces that set.

You can also save with a shortcut that has the **Save window set** action, either for one
fixed set or asking for the name each time (see
[Shortcuts that ask which set](#shortcuts-that-ask-which-set)).

### Recalling a set

Any of these:

- Tray icon > **Recall window set** > the set's name.
- **Window sets...**, select the set, click **Recall**.
- A shortcut with the **Recall window set** action, for one fixed set or asking which
  set each time.

Recalling arranges the windows on the desktop you're looking at.

How windows are matched:

- **By app, not by window title.** A spot saved for `chrome.exe` takes a Chrome window,
  whichever page it shows.
- **Several windows of one app:** each saved spot gets the window closest to it, so
  recalling twice doesn't shuffle windows around. Windows left over stack on top of their
  nearest spot, with the window you used most recently on top. **No window of an app in
  the set is left behind.**
- **Apps in the set that aren't open** on this desktop are skipped; oblong does not start
  apps.
- **Apps that aren't in the set** are left alone.
- Minimized windows are left minimized.

### Shortcuts that ask which set

In the shortcut editor, choose **Save window set** or **Recall window set** and leave
**Set name** blank. The settings list shows these as "(choose each time)". Pressing the
shortcut then opens a small window:

- **Save window set:** type a new name, or pick an existing set from the list to replace
  it.
- **Recall window set:** pick a set from the list. Type its first letter to jump to it,
  or double-click it.

Press **Enter** to confirm or **Esc** to cancel. Both start on the set you saved or
recalled last, so recalling the same set again is just the shortcut and then Enter. If no
sets are saved yet, the recall shortcut only shows a notification.

One shortcut of each kind is enough to work with any number of sets, instead of one
shortcut per set.

### Monitors

Each spot remembers its monitor by the monitor's hardware ID (its model code, such as
`DEL41A8`), so it still finds the right screen after you plug monitors into different
ports or change their order. Positions are stored as a fraction of the screen, so they
still fit after a resolution or scaling change. If you have two identical monitors, their
position in the display layout tells them apart.

If a spot's monitor isn't connected, the window goes to the same relative spot on the
main monitor. Untick **If a monitor is missing, use the main monitor** to skip those
windows instead.

### Options per set

Select a set in **Window sets...** to change:

- **Cascade windows that share a spot:** instead of stacking exactly on top of each other,
  stacked windows are offset so their title bars show. They become slightly smaller to
  stay inside the spot. Maximized spots always stack exactly.
- **If a monitor is missing, use the main monitor** (see above).

Options apply immediately.

### Editing a set's apps

Select a set and click **Edit apps...**, or double-click it. Each row is one spot: the
app, its monitor, and its position.

- **Add...** adds an app that wasn't open when you saved, for example Spotify.
- **Edit...** (or double-click a row) changes the spot:
  - **App:** pick from the apps in the set and those open now, or type the program name
    (`notepad.exe`). To find a program's name, look in Task Manager > **Details**.
  - **Monitor:** one of the connected monitors. A disconnected monitor appears as
    "(not connected)" and is kept unless you choose another.
  - **Maximized**, or **Left / Top / Width / Height** in percent of the monitor's usable
    area. For example, the right half is left 50, top 0, width 50, height 100.
- **Duplicate** copies a row, to give an app a second spot.
- **Remove** deletes a row.

Click **OK** to save the changes. Saving the desktop again under the same name replaces
your hand edits.

### Renaming and deleting

**Rename...** also updates any shortcuts that use the set. **Delete** removes the set but
not the shortcuts that use it: a recall shortcut then only shows a notification that the
set doesn't exist, and a save shortcut creates the set again.

## Action reference

Every shortcut stores an action as text. The editor builds these for you; this is what
they mean if you edit `Oblong.ini` by hand.

| Action | Behavior |
|---|---|
| `1/4 Top Bottom Full` | every top spot, then bottom, then full height |
| `1/3 Top Bottom` | top and bottom only |
| `1/4 Top Bottom down` | column by column: top 1, bottom 1, top 2, bottom 2... |
| `1/4 Top@2` | always the second quarter, top half (no cycling) |
| `1/2 Full@2 Top@1 Bottom@1` | exactly these spots, in this order |
| `1/2 +1/4 Full` | a centred half: starts 1/4 in from the left |
| `1/4 -1/8 Top` | quarters ending 1/8 in from the right: at 1/8, 3/8 and 5/8 |
| `Maximize`, `AlmostMaximize`, `MaximizeHeight`, `Center`, `Restore` | as named |
| `NextDisplay`, `PrevDisplay` | move to the next / previous monitor |
| `SaveSet Coding` | save the current desktop's windows as set "Coding" |
| `RecallSet Coding` | arrange the current desktop's windows from set "Coding" |
| `SaveSet`, `RecallSet` | no name: ask which set each time |
| `Settings` | open the settings window (or bring it to the front) |

Grammar for fraction actions: `<num>/<den> [+<a>/<b> | -<a>/<b>] <step> [<step> ...] [down|across]`.
A step is `Top`, `Bottom` or `Full`, optionally followed by `@N` for a single column. The
optional offset `+a/b` starts the columns a/b in from the left edge, and `-a/b` from the
right edge.

## The settings file

`Oblong.ini` sits next to `oblong.ahk`. You normally don't need to edit it; if you do,
exit oblong first (or reload it afterwards) so your edits aren't overwritten.

```ini
[Settings]
Gap=0
AlmostMaxSize=0.9
CycleOnRepeat=1
NumpadToo=1
FolderList=Window sets
CollapsedFolders=Window sets

[Hotkeys]
1=^!1|1/4 Top
2=^!q|1/4 Full
...
7=^!+s|SaveSet

[Folders]
7=Window sets

[Set:Coding]
Cascade=0
MissingMonitor=main
1=chrome.exe|DEL41A8|1920,0|2|0.0000,0.0000,0.6667,1.0000|0
```

- Hotkey lines are `number=<AutoHotkey hotkey>|<action>`. In AutoHotkey notation `^` is
  Ctrl, `!` is Alt, `+` is Shift and `#` is Win.
- `[Folders]` puts shortcuts in folders: `number=<folder name>`, using the same number as
  the shortcut's `[Hotkeys]` line. `FolderList` lists every folder in order (including
  empty ones) and `CollapsedFolders` the collapsed ones, both separated
  by `|`.
- Each `[Set:<name>]` section is one window set. Spot lines are
  `app|monitor ID|monitor left,top|monitor order|left,top,width,height|maximized`, with
  the position as fractions (0-1) of the monitor's usable area. `MissingMonitor` is
  `main` or `skip`.
