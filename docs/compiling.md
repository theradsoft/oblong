# Compiling oblong into an .exe

oblong normally runs as a script: AutoHotkey reads `oblong.ahk` each time it starts.
AutoHotkey's compiler, **Ahk2Exe**, can instead bundle the script and the AutoHotkey
program into a single `oblong.exe`. This is optional; the script version does everything
the compiled one does.

## Why compile?

- **No AutoHotkey install needed.** The `.exe` runs on any Windows 10/11 PC, so you can
  carry oblong to a work machine or a fresh install without installing AutoHotkey first.
- **It looks like its own app.** `oblong.exe` has the oblong icon in Explorer, on the Start
  menu if you pin it, and on the startup shortcut. Task Manager lists it as `oblong.exe`
  instead of a generic `AutoHotkey64.exe`, which makes it easy to find and end.
- **One file to copy.** Just `oblong.exe` (plus your `Oblong.ini` if you want your
  settings).
- **Safe from accidental edits.** Double-clicking the `.exe` always runs it; it can't be
  opened in an editor by mistake.

What it doesn't change: oblong behaves exactly the same. Compiling doesn't make it faster
in any noticeable way, and it doesn't add features.

## Getting the compiler

Ahk2Exe isn't included in the AutoHotkey installer; AutoHotkey downloads it the first time
you ask to compile:

1. Open **AutoHotkey Dash** (Start menu > AutoHotkey, or run AutoHotkey without a script).
2. Click **Compile**. If the compiler isn't installed yet, Dash offers to download and
   install it. Accept.

It's installed as `C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe`. You can also
right-click any `.ahk` file > **Compile Script** (on Windows 11, under **Show more
options**), which triggers the same download the first time.

## Compiling

Keep `oblong.ahk` and `oblong.ico` in the same folder.

### With the Ahk2Exe window

1. Open **Ahk2Exe** (Dash > **Compile**, or run `Ahk2Exe.exe`).
2. **Source (script file):** `oblong.ahk`.
3. **Destination (.exe file):** `oblong.exe` in the same folder (the default).
4. **Custom Icon (.ico file):** `oblong.ico`.
5. **Base File (.bin, .exe):** choose the **v2 64-bit** base, listed like
   `v2.0.x U64 AutoHotkey64.exe`. A v1 base will fail with syntax errors, and the 32-bit
   base works but has no advantage.
6. **Compress exe with:** leave it on **(none)**. See
   [antivirus warnings](#antivirus-and-smartscreen-warnings) below.
7. Click **Convert**.

### From the command line

```powershell
& "C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe" `
    /in oblong.ahk /out oblong.exe /icon oblong.ico `
    /base "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"
```

## Switching from the script to the .exe

1. **Exit the script version** (tray icon > **Exit**). Don't run both: they're separate
   programs, so AutoHotkey's single-instance check doesn't stop the second one, and every
   shortcut would act twice.
2. **Put `oblong.exe` where you keep oblong.** Settings are read from `Oblong.ini` *next to
   the program*, so put the `.exe` in the same folder as your existing `Oblong.ini` to keep
   your shortcuts, settings and window sets. A new folder starts with the defaults.
3. **Run `oblong.exe`.**
4. **Fix Start with Windows.** The existing startup shortcut still points at `oblong.ahk`
   (oblong only creates the shortcut when it's missing). In **Settings...**, untick
   **Start with Windows**, click **Save**, tick it again and click **Save**. The new
   shortcut points at `oblong.exe`. If you start oblong from Task Scheduler, change the
   task's action to run `oblong.exe` directly, with no arguments.

`oblong.ico` is optional next to the `.exe`: the icon is built into it.

## Known issues with compiling

### Antivirus and SmartScreen warnings

Compiled AutoHotkey programs are often flagged by antivirus software, including Windows
Defender, because some malware is also written in AutoHotkey and the compiled files all
look alike. oblong isn't doing anything suspicious, but expect some of this:

- Defender or another antivirus may quarantine `oblong.exe` right after compiling or on
  first run. Restore it and add an exclusion for the file or folder if you trust it.
- If you copy the `.exe` to another PC by download, email or cloud drive, **SmartScreen**
  may say "Windows protected your PC" because the file isn't signed. Click **More info** >
  **Run anyway**, or right-click the file > **Properties** > tick **Unblock**.
- **Don't compress** the `.exe` (UPX or MPRESS options). Compressed AutoHotkey programs are
  flagged far more often, for a saving of a few hundred kilobytes.
- Some workplaces block unsigned `.exe` files outright. The script version, run by the
  installed AutoHotkey, may be allowed where a compiled one isn't.

Signing the `.exe` with a code-signing certificate avoids most of this, but certificates
cost money and are rarely worth it for a personal tool.

### You have to recompile after every change

The `.exe` contains a copy of the script from the moment you compiled it. Editing
`oblong.ahk` afterwards changes nothing until you compile again. Your settings and window
sets are separate (in `Oblong.ini`), so recompiling never loses them.

### Two copies, two sets of settings

`Oblong.ini` lives next to whichever program is running. If you run the script from one
folder and the `.exe` from another, they each have their own settings and window sets.
Keep them in the same folder, and only run one at a time.

### Tray menu differences

A compiled program's tray menu leaves out AutoHotkey's developer items (such as **Edit
Script**, **Window Spy** and **Reload Script**). oblong's own items (**Settings...**,
**Window sets...**, **Recall window set**, **Open Oblong.ini**) and **Suspend Hotkeys** and
**Exit** are still there. To reload a compiled oblong, exit it and run it again.

### Running as administrator

Compiling doesn't change what oblong can move: windows running as administrator still need
oblong to run as administrator too. You can set this on the `.exe` itself (right-click >
**Properties** > **Compatibility** > **Run this program as an administrator**), but then
Windows asks for permission every time it starts, and the Startup-folder shortcut can't
start it elevated. For elevated start at sign-in, use Task Scheduler as described in
[Running as administrator](installation.md#running-as-administrator-optional), pointing
the task at `oblong.exe`.

### The source is inside the .exe

The script's text is stored inside the `.exe`, and anyone can extract it. That's fine for
oblong, but don't rely on compiling to hide anything you add to the script, such as
passwords or keys.

### The AutoHotkey version is frozen

The `.exe` keeps the AutoHotkey version it was compiled with. Updating AutoHotkey later
doesn't update the `.exe`; recompile to pick up AutoHotkey fixes.
