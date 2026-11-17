# Known issues and limitations

## Status

- **Window sets are new and haven't had much real-world testing yet**, especially
  recalling (actually moving windows) and the set and spot editor dialogs. If something
  misbehaves, note what you did and which apps were involved.
- The settings window and shortcut editor are also fairly new.

## Moving windows

- **Windows running as administrator can't be moved** (Task Manager, elevated terminals,
  some installers and games) unless oblong also runs as administrator. Those windows
  stay where they are. See
  [Running as administrator](installation.md#running-as-administrator-optional).
- **Some apps enforce a minimum size.** If a spot is smaller than the app allows (for
  example a narrow 1/4 column on a small screen), the window ends up larger than the spot
  and overlaps its neighbour.
- **Some apps reposition themselves** after being moved (certain games, splash screens,
  apps that remember their own layout). oblong can't stop that.
- **Restore** only knows positions from before oblong first moved a window during this
  session. Restarting oblong forgets them.

## Shortcuts

- **Shift + numpad digits don't work with NumLock on.** Windows turns Shift+Numpad1 into
  End, so a shortcut like Ctrl+Shift+1 won't fire from the numpad. Use Win, Ctrl or Alt
  instead of Shift for shortcuts you want on the numpad.
- **Ctrl+Alt+arrow keys may rotate the screen** on PCs with Intel graphics. Turn off the
  Intel hotkeys in the Intel Graphics Command Center, or pick other keys.
- **Shortcuts already owned by another program** can't be registered. oblong lists them
  when it starts or when you save settings; choose a different combination.
- **Overriding Windows' own shortcuts** (such as Win+Left/Right snapping) works by
  binding the same keys in oblong. A few Windows shortcuts (for example Win+L) can't be
  overridden.
- While the shortcut recorder is waiting for a key, all oblong shortcuts are paused.

## Start with Windows

- **Moving the script breaks the startup shortcut.** It keeps pointing at the old
  location and isn't repaired automatically. Untick and re-tick **Start with Windows**
  (clicking **Save** each time) after moving. See
  [Moving the script](installation.md#moving-the-script-to-another-folder).
- The startup shortcut can't start oblong as administrator. Use Task Scheduler instead.

## Window sets

- **With virtual desktops, only the one that's showing.** Saving and recalling never
  look at or move windows on your other desktops, and oblong can't move a window from one
  desktop to another
  (Windows offers no supported way for one program to do that to another program's
  windows).
- **Apps aren't started.** If an app in the set isn't open on the current desktop, its
  spot is left empty.
- **Minimized windows are ignored** when saving and recalling.
- **Matching is by app only.** With several windows of the same app, oblong can't tell
  which one "belongs" in which spot; it uses the nearest one. Two browser windows may swap
  places if you've moved them around between recalls.
- **Windows pinned to all desktops** ("Show this window on all desktops") are on every
  desktop, so every recall can move them.
- **Recalling may change which window is active.** Restoring a maximized window or
  maximizing one brings it to the front.
- **Some windows aren't included:** dialogs, popups, tool windows, windows with no title
  bar that can't be resized, and oblong's own windows. Unusual apps that draw their own
  window frame may be missed.
- **Microsoft Store apps** are identified by looking up the real app behind the Windows
  "application frame" window. If that lookup fails, the app shows up as
  `applicationframehost.exe` and all such apps are treated as one.
- **Monitors without a hardware ID.** Some docks, adapters, projectors and virtual
  displays don't report one. Spots on those monitors are matched by their place in the
  display layout instead, which breaks if you rearrange displays.
- **Two identical monitors** share a hardware ID and are told apart by their position in
  the display layout. Swapping where they sit in **Display settings** swaps their windows.
- **Cascade uses a fixed 32-pixel offset**, which looks small on high-DPI screens. If a
  spot is too small to cascade all its windows, they stack exactly instead.
- **Saving a set again replaces hand edits** made with **Edit apps...**.
- **Deleting a set doesn't delete shortcuts** that use it. Remove them in **Settings...**.
