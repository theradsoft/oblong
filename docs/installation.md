# Installing oblong

oblong is a single AutoHotkey v2 script, `oblong.ahk`, plus its icon, `oblong.ico`. There
is no installer: you install AutoHotkey once, put the files in a folder you'll keep, and
run the script.

## Requirements

- Windows 10 or Windows 11
- [AutoHotkey v2](https://www.autohotkey.com) (v1.1 will not run the script)

## Steps

1. **Install AutoHotkey v2.** Download it from <https://www.autohotkey.com> and run the
   installer with the default options.
2. **Choose a permanent folder for oblong**, for example `C:\Tools\oblong`. Settings are
   saved next to the script, and the "Start with Windows" shortcut points at this
   location, so avoid Downloads or a temporary folder.
3. **Copy `oblong.ahk` and `oblong.ico` into that folder.** The icon is optional: without
   it oblong uses AutoHotkey's green "H" icon.
4. **Double-click `oblong.ahk`.** The oblong icon (a dark screen split into blue, light
   blue and yellow tiles) appears in the system tray; you may need to click the **^**
   arrow next to the clock to see it. The shortcuts work straight away.
5. **Open the settings.** Double-click the tray icon, or right-click it and choose
   **Settings...**.

On first run oblong creates `Oblong.ini` next to the script with the default shortcuts
and settings. The INI holds your personal configuration; back it up if you customize a lot.

## Start with Windows

In **Settings...**, tick **Start with Windows** and click **Save**. This puts a shortcut
called `Oblong.lnk` in your Startup folder (`shell:startup`), using the oblong icon. Untick
it to remove the shortcut.

A startup shortcut created before oblong had its icon keeps the AutoHotkey icon. To
update it, untick **Start with Windows**, click **Save**, then tick it and click **Save**
again.

## Changing the icon

Replace `oblong.ico` with any `.ico` file of your own (keep the name) and restart oblong.
To tweak the built-in design or colours, edit and run `tools/make-icon.ps1`:

```powershell
powershell -ExecutionPolicy Bypass -File tools\make-icon.ps1 -OutIco oblong.ico -PreviewPng icon-preview.png
```

While shortcuts are suspended (tray menu > **Suspend Hotkeys**, or while recording a
shortcut), the tray shows AutoHotkey's "S" icon instead, so you can tell they're off.

## Running as administrator (optional)

Windows doesn't let a normal program move windows that run as administrator (Task
Manager, an elevated terminal, some installers). If you need oblong to move those too,
run it as administrator:

- **Once:** right-click `oblong.ahk` > **Run as administrator** (on Windows 11 it may be
  under **Show more options**).
- **At every sign-in:** the Startup-folder shortcut can't start a program elevated
  without a prompt. Instead, untick **Start with Windows** in oblong and create a task in
  **Task Scheduler**:
  1. **Create Task...** (not "Create Basic Task").
  2. **General:** tick **Run with highest privileges**.
  3. **Triggers:** **New...** > **At log on** (for your user).
  4. **Actions:** **New...** > Program `C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe`,
     arguments `"C:\Tools\oblong\oblong.ahk"` (use your own folder).
  5. **Conditions:** untick **Start the task only if the computer is on AC power**.

## Updating

Close oblong (right-click the tray icon > **Exit**), replace `oblong.ahk` with the new
version, and double-click it again. Your `Oblong.ini` is kept. If oblong is already
running, double-clicking the script simply restarts it.

## Moving the script to another folder

The startup shortcut points at the old location and isn't updated automatically. After
moving the folder, run the script from its new location, open **Settings...**, untick
**Start with Windows**, click **Save**, then tick it again and click **Save**.

## Uninstalling

1. In **Settings...**, untick **Start with Windows** and click **Save** (or delete
   `Oblong.lnk` from `shell:startup`, or remove your Task Scheduler task).
2. Right-click the tray icon > **Exit**.
3. Delete the oblong folder.
4. Optionally uninstall AutoHotkey from **Settings > Apps**.
