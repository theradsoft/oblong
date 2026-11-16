; =====================================================================
;  SnapKeys.ahk  -  Rectangle-style keyboard window management for Windows
;  Requires AutoHotkey v2  (https://www.autohotkey.com)
;
;  Settings live in SnapKeys.ini next to this script. Change them from the
;  tray icon > Settings... (or double-click the tray icon).
;
;  Action format (what the settings window builds):
;    "1/4 Top Bottom Full"     cycle every top slot, then bottom, then full
;    "1/3 Top@2"               one specific slot (column 2, top half)
;    "1/4 Top Bottom down"     column by column instead of row by row
;    Maximize AlmostMaximize MaximizeHeight Center Restore
;    NextDisplay PrevDisplay
; =====================================================================
#Requires AutoHotkey v2.0
#SingleInstance Force

IniFile    := A_ScriptDir "\SnapKeys.ini"
StartupLnk := A_Startup "\SnapKeys.lnk"
MAXCOLS    := 12

TypeNames   := ["Fraction (cycle spots)", "Maximize", "Almost maximize", "Maximize height"
              , "Center", "Restore", "Next display", "Previous display"]
TypeActions := ["", "Maximize", "AlmostMaximize", "MaximizeHeight"
              , "Center", "Restore", "NextDisplay", "PrevDisplay"]

; Runtime state
Gap := 0, CycleOnRepeat := true, AlmostMaxSize := 0.9, NumpadToo := true
Bindings   := []
Registered := []
Originals  := Map()          ; hwnd -> rect before first snap (for Restore)
LastHwnd   := 0
LastAction := ""
LastIndex  := 0
LastRect   := {L: 0, T: 0, R: 0, B: 0}
SetGui := 0, Ctl := 0, Ed := 0, WorkBindings := []

LoadConfig()
if (errs := ApplyHotkeys()) != ""
    MsgBox("These shortcuts couldn't be registered:`n`n" errs, "SnapKeys", "Icon!")

A_IconTip := "SnapKeys"
A_TrayMenu.Add()
A_TrayMenu.Add("Settings...", OpenSettings)
A_TrayMenu.Add("Open SnapKeys.ini", (*) => Run(IniFile))
A_TrayMenu.Default := "Settings..."

; ============================ CONFIG ==================================
DefaultBindings() {
    pairs := [
        "^!1", "1/4 Top",     "^!2", "1/3 Top",     "^!3", "1/2 Top",
        "^!4", "2/3 Top",     "^!5", "3/4 Top",
        "^!q", "1/4 Full",    "^!w", "1/3 Full",    "^!e", "1/2 Full",
        "^!r", "2/3 Full",    "^!t", "3/4 Full",
        "^!a", "1/4 Bottom",  "^!s", "1/3 Bottom",  "^!d", "1/2 Bottom",
        "^!f", "2/3 Bottom",  "^!g", "3/4 Bottom",
        "^!Enter", "Maximize",          "^!+Enter", "AlmostMaximize",
        "^!+Up", "MaximizeHeight",      "^!c", "Center",
        "^!Backspace", "Restore",
        "^!#Right", "NextDisplay",      "^!#Left", "PrevDisplay"
    ]
    out := []
    Loop pairs.Length // 2
        out.Push({key: pairs[A_Index * 2 - 1], action: pairs[A_Index * 2]})
    return out
}

LoadConfig() {
    global Gap, CycleOnRepeat, AlmostMaxSize, NumpadToo, Bindings
    if !FileExist(IniFile) {
        Bindings := DefaultBindings()
        SaveConfig()
        return
    }
    try Gap := Integer(IniRead(IniFile, "Settings", "Gap", 0))
    try AlmostMaxSize := Number(IniRead(IniFile, "Settings", "AlmostMaxSize", 0.9))
    CycleOnRepeat := IniRead(IniFile, "Settings", "CycleOnRepeat", 1) = 1
    NumpadToo     := IniRead(IniFile, "Settings", "NumpadToo", 1) = 1
    Bindings := []
    try sect := IniRead(IniFile, "Hotkeys")
    catch
        sect := ""
    ; each line:  N=<hotkey>|<action>
    Loop Parse sect, "`n", "`r" {
        p := InStr(A_LoopField, "=")
        if !p
            continue
        val := SubStr(A_LoopField, p + 1)
        bar := InStr(val, "|", , -1)
        if bar > 1
            Bindings.Push({key: SubStr(val, 1, bar - 1), action: SubStr(val, bar + 1)})
    }
}

SaveConfig() {
    IniWrite(Gap, IniFile, "Settings", "Gap")
    IniWrite(AlmostMaxSize, IniFile, "Settings", "AlmostMaxSize")
    IniWrite(CycleOnRepeat ? 1 : 0, IniFile, "Settings", "CycleOnRepeat")
    IniWrite(NumpadToo ? 1 : 0, IniFile, "Settings", "NumpadToo")
    try IniDelete(IniFile, "Hotkeys")
    pairs := ""
    for i, b in Bindings
        pairs .= (pairs = "" ? "" : "`n") i "=" b.key "|" b.action
    if pairs != ""
        IniWrite(pairs, IniFile, "Hotkeys")
}

ApplyHotkeys() {
    global Registered
    for k in Registered
        try Hotkey(k, "Off")
    Registered := []
    errs := ""
    for b in Bindings {
        for k in ExpandKeys(b.key) {
            try {
                Hotkey(k, MakeHandler(b.action), "On")
                Registered.Push(k)
            } catch {
                if k = b.key
                    errs .= PrettyKey(b.key) "   (" b.action ")`n"
            }
        }
    }
    return errs
}

; A number-row digit also gets its numpad twins (NumLock on and off names)
ExpandKeys(k) {
    static numLockOff := Map("0", "NumpadIns",  "1", "NumpadEnd",   "2", "NumpadDown"
                           , "3", "NumpadPgDn", "4", "NumpadLeft",  "5", "NumpadClear"
                           , "6", "NumpadRight","7", "NumpadHome",  "8", "NumpadUp"
                           , "9", "NumpadPgUp")
    list := [k]
    if NumpadToo && RegExMatch(k, "^([\^!+#<>*~$]*)(\d)$", &m)
        list.Push(m[1] "Numpad" m[2], m[1] numLockOff[m[2]])
    return list
}

PrettyKey(k) {
    if !RegExMatch(k, "^([\^!+#<>*~$]*)(.+)$", &m)
        return k
    s := ""
    if InStr(m[1], "^")
        s .= "Ctrl+"
    if InStr(m[1], "!")
        s .= "Alt+"
    if InStr(m[1], "+")
        s .= "Shift+"
    if InStr(m[1], "#")
        s .= "Win+"
    key := m[2]
    if StrLen(key) = 1
        key := StrUpper(key)
    return s key
}

FriendlyAction(a) {
    for i, act in TypeActions
        if i > 1 && act = a
            return TypeNames[i]
    return a
}

SetStartup(on) {
    if on && !FileExist(StartupLnk)
        FileCreateShortcut(A_ScriptFullPath, StartupLnk, A_ScriptDir)
    else if !on && FileExist(StartupLnk)
        FileDelete(StartupLnk)
}

; ======================= SETTINGS WINDOW ==============================
OpenSettings(*) {
    global SetGui, WorkBindings, Ctl
    if SetGui {
        SetGui.Show()
        return
    }
    WorkBindings := []
    for b in Bindings
        WorkBindings.Push({key: b.key, action: b.action})

    g := Gui(, "SnapKeys Settings")
    g.SetFont("s9", "Segoe UI")
    Ctl := {}
    g.Add("Text", "x10 y10", "Shortcuts (double-click to edit):")
    Ctl.LV := g.Add("ListView", "x10 y28 w560 h300 -Multi Grid NoSortHdr", ["Shortcut", "Action"])
    Ctl.LV.OnEvent("DoubleClick", (*) => EditSelected())
    g.Add("Button", "x10 y336 w90", "Add...").OnEvent("Click", (*) => EditBinding(0))
    g.Add("Button", "x106 y336 w90", "Edit...").OnEvent("Click", (*) => EditSelected())
    g.Add("Button", "x202 y336 w90", "Duplicate...").OnEvent("Click", (*) => DupSelected())
    g.Add("Button", "x298 y336 w90", "Delete").OnEvent("Click", (*) => DeleteSelected())

    g.Add("GroupBox", "x10 y372 w560 h96", "Settings")
    g.Add("Text", "x24 y398", "Gap between windows (px):")
    Ctl.Gap := g.Add("Edit", "x190 y394 w60 Number")
    g.Add("UpDown", "Range0-100", Gap)
    g.Add("Text", "x300 y398", "Almost maximize size (%):")
    Ctl.AM := g.Add("Edit", "x460 y394 w60 Number")
    g.Add("UpDown", "Range50-100", Round(AlmostMaxSize * 100))
    Ctl.Cycle   := g.Add("Checkbox", "x24 y434 Checked" (CycleOnRepeat ? 1 : 0), "Repeat presses cycle")
    Ctl.Numpad  := g.Add("Checkbox", "x200 y434 Checked" (NumpadToo ? 1 : 0), "Numpad works too")
    Ctl.Startup := g.Add("Checkbox", "x380 y434 Checked" (FileExist(StartupLnk) ? 1 : 0), "Start with Windows")

    g.Add("Button", "x380 y482 w100", "Save").OnEvent("Click", SaveSettings)
    g.Add("Button", "x486 y482 w84", "Cancel").OnEvent("Click", (*) => CloseSettings())
    g.OnEvent("Close", (*) => CloseSettings())
    g.OnEvent("Escape", (*) => CloseSettings())
    SetGui := g
    RefreshList()
    g.Show("w580 h518")
}

RefreshList(selectRow := 0) {
    lv := Ctl.LV
    lv.Delete()
    for b in WorkBindings
        lv.Add(, PrettyKey(b.key), FriendlyAction(b.action))
    lv.ModifyCol(1, 170)
    lv.ModifyCol(2, 370)
    if selectRow
        lv.Modify(selectRow, "Select Focus Vis")
}

EditSelected() {
    if row := Ctl.LV.GetNext()
        EditBinding(row)
}

DupSelected() {
    if row := Ctl.LV.GetNext()
        EditBinding(0, WorkBindings[row].action)
}

DeleteSelected() {
    if row := Ctl.LV.GetNext() {
        WorkBindings.RemoveAt(row)
        RefreshList(Min(row, WorkBindings.Length))
    }
}

SaveSettings(*) {
    global Gap, AlmostMaxSize, CycleOnRepeat, NumpadToo, Bindings
    Gap := Max(0, Integer(Ctl.Gap.Value || 0))
    AlmostMaxSize := Max(50, Min(100, Integer(Ctl.AM.Value || 90))) / 100
    CycleOnRepeat := Ctl.Cycle.Value = 1
    NumpadToo := Ctl.Numpad.Value = 1
    Bindings := []
    for b in WorkBindings
        Bindings.Push({key: b.key, action: b.action})
    SaveConfig()
    errs := ApplyHotkeys()
    try SetStartup(Ctl.Startup.Value = 1)
    CloseSettings()
    if errs != ""
        MsgBox("These shortcuts couldn't be registered:`n`n" errs, "SnapKeys", "Icon!")
    else
        TrayTip("Settings saved", "SnapKeys")
}

CloseSettings() {
    global SetGui
    if SetGui {
        SetGui.Destroy()
        SetGui := 0
    }
}

; ======================= SHORTCUT EDITOR ==============================
EditBinding(idx, prefillAction := "") {
    global Ed
    if idx
        b := WorkBindings[idx]
    else
        b := {key: "", action: prefillAction != "" ? prefillAction : "1/2 Full"}
    p := ParseForEditor(b.action)

    d := Gui("+Owner" SetGui.Hwnd " -MinimizeBox", idx ? "Edit shortcut" : "Add shortcut")
    d.SetFont("s9", "Segoe UI")
    Ed := {Gui: d, Idx: idx, Key: b.key, Steps: p.steps, Ih: 0, Btns: Map(), FracCtls: []}

    d.Add("Text", "x10 y12", "Shortcut:")
    Ed.KeyEdit := d.Add("Edit", "x80 y8 w240 ReadOnly", b.key = "" ? "(none - click Record)" : PrettyKey(b.key))
    d.Add("Button", "x328 y7 w90", "Record...").OnEvent("Click", StartRecording)
    Ed.KeyNote := d.Add("Text", "x426 y12 w314", b.key = "" ? "" : ShortcutNote(b.key))

    d.Add("Text", "x10 y44", "Action:")
    Ed.TypeDDL := d.Add("DropDownList", "x80 y40 w240 Choose" p.type, TypeNames)
    Ed.TypeDDL.OnEvent("Change", RefreshEditor)

    AddF("Text", "x10 y80", "Width:")
    Ed.FracCB := AddF("ComboBox", "x80 y76 w80", ["1/4", "1/3", "1/2", "2/3", "3/4"])
    Ed.FracCB.Text := p.frac
    Ed.FracCB.OnEvent("Change", RefreshEditor)
    Ed.FracNote := AddF("Text", "x168 y80 w400", "")
    AddF("Text", "x10 y108 w560", "Click the spots in the order you want them visited. Numbers show the cycle order.")
    AddF("Text", "x10 y130", "Top / bottom half")
    AddF("Text", "x290 y130", "Full height")

    for h in ["Top", "Bottom", "Full"] {
        arr := []
        Loop MAXCOLS {
            btn := d.Add("Button", "x0 y0 w10 h10 Hidden", "+")
            btn.OnEvent("Click", SlotHandler(h, A_Index))
            arr.Push(btn)
        }
        Ed.Btns[h] := arr
    }

    AddF("Button", "x10 y304 w84", "All top").OnEvent("Click", (*) => AddStep("Top", 0))
    AddF("Button", "x98 y304 w84", "All bottom").OnEvent("Click", (*) => AddStep("Bottom", 0))
    AddF("Button", "x290 y304 w84", "All full").OnEvent("Click", (*) => AddStep("Full", 0))

    AddF("Text", "x570 y130", "Cycle order:")
    Ed.SeqLB := AddF("ListBox", "x570 y148 w170 h150", [])
    AddF("Button", "x570 y304 w52", "Up").OnEvent("Click", (*) => MoveStep(-1))
    AddF("Button", "x626 y304 w52", "Down").OnEvent("Click", (*) => MoveStep(1))
    AddF("Button", "x682 y304 w58", "Remove").OnEvent("Click", RemoveStep)
    AddF("Button", "x570 y334 w170", "Clear").OnEvent("Click", ClearSteps)

    Ed.AcrossRadio := AddF("Radio", "x10 y340" (p.down ? "" : " Checked"), "Across: finish each height before the next")
    Ed.DownRadio   := AddF("Radio", "x10 y362" (p.down ? " Checked" : ""), "Down: go column by column")
    Ed.AcrossRadio.OnEvent("Click", RefreshEditor)
    Ed.DownRadio.OnEvent("Click", RefreshEditor)

    d.Add("Text", "x10 y398", "Result:")
    Ed.Preview := d.Add("Edit", "x80 y394 w660 ReadOnly")
    d.Add("Button", "x560 y432 w85", "OK").OnEvent("Click", EdOK)
    d.Add("Button", "x655 y432 w85", "Cancel").OnEvent("Click", (*) => CloseEditor())
    d.OnEvent("Close", (*) => CloseEditor())
    d.OnEvent("Escape", (*) => CloseEditor())

    SetGui.Opt("+Disabled")
    d.Show("w750 h470")
    RefreshEditor()
}

AddF(type, opts, text := "") {
    c := Ed.Gui.Add(type, opts, text)
    Ed.FracCtls.Push(c)
    return c
}

SlotHandler(h, col) => (*) => AddStep(h, col)

ParseForEditor(a) {
    s := RegExReplace(Trim(a), "\s*@\s*", "@")
    res := {type: 1, frac: "1/2", steps: [], down: false}
    if RegExMatch(s, "^(\d+)\s*/\s*(\d+)\s*(.*)$", &m) {
        res.frac := m[1] "/" m[2]
        for tok in StrSplit(m[3], [" ", ","]) {
            if tok = "down"
                res.down := true
            else if RegExMatch(tok, "i)^(Top|Bottom|Full)(?:@(\d+))?$", &t)
                res.steps.Push({h: StrTitle(t[1]), col: t[2] = "" ? 0 : Integer(t[2])})
        }
        return res
    }
    for i, act in TypeActions
        if i > 1 && act = s
            res.type := i
    return res
}

FracColumns(txt) {
    if !RegExMatch(txt, "^\s*(\d+)\s*/\s*(\d+)\s*$", &m) || m[2] = 0
        return 0
    w := m[1] / m[2]
    if w <= 0 || w > 1
        return 0
    n := ColumnPositions(w).Length
    return n <= MAXCOLS ? n : 0
}

; Same ordering rules as ParseSlots, but as {h, col} pairs for labelling
ExpandStops(n) {
    groups := []
    for st in Ed.Steps {
        g := []
        if st.col
            g.Push({h: st.h, col: Min(st.col, n)})
        else
            Loop n
                g.Push({h: st.h, col: A_Index})
        groups.Push(g)
    }
    out := []
    if !Ed.DownRadio.Value {
        for g in groups
            for s in g
                out.Push(s)
    } else {
        longest := 0
        for g in groups
            longest := Max(longest, g.Length)
        Loop longest {
            i := A_Index
            for g in groups
                if i <= g.Length
                    out.Push(g[i])
        }
    }
    return out
}

BuildAction() {
    t := Ed.TypeDDL.Value
    if t > 1
        return TypeActions[t]
    s := RegExReplace(Ed.FracCB.Text, "\s", "")
    for st in Ed.Steps
        s .= " " st.h (st.col ? "@" st.col : "")
    if Ed.DownRadio.Value
        s .= " down"
    return s
}

RefreshEditor(*) {
    isFrac := Ed.TypeDDL.Value = 1
    for c in Ed.FracCtls
        c.Visible := isFrac
    n := isFrac ? FracColumns(Ed.FracCB.Text) : 0
    stops := n ? ExpandStops(n) : []
    for h in ["Top", "Bottom", "Full"] {
        px := h = "Full" ? 290 : 10
        py := h = "Bottom" ? 223 : 148
        ph := h = "Full" ? 150 : 75
        Loop MAXCOLS {
            i := A_Index
            btn := Ed.Btns[h][i]
            if i > n {
                btn.Visible := false
                continue
            }
            bw := 260 / n
            btn.Move(Round(px + (i - 1) * bw), py, Round(bw) - 2, ph - 2)
            nums := ""
            for k, s in stops
                if s.h = h && s.col = i
                    nums .= (nums = "" ? "" : ",") k
            btn.Text := nums = "" ? "+" : "#" nums
            btn.Visible := true
        }
    }
    if isFrac && n
        Ed.FracNote.Value := "Pick one or type your own, e.g. 2/5"
    else if isFrac
        Ed.FracNote.Value := "Enter a fraction like 1/4 (up to " MAXCOLS " slots)"
    items := []
    for st in Ed.Steps
        items.Push(st.h (st.col ? " @" st.col : " (all)"))
    sel := Ed.SeqLB.Value
    Ed.SeqLB.Delete()
    if items.Length
        Ed.SeqLB.Add(items)
    if sel && sel <= items.Length
        Ed.SeqLB.Choose(sel)
    Ed.Preview.Value := BuildAction()
}

AddStep(h, col) {
    Ed.Steps.Push({h: h, col: col})
    RefreshEditor()
    Ed.SeqLB.Choose(Ed.Steps.Length)
}

MoveStep(dir) {
    i := Ed.SeqLB.Value
    j := i + dir
    if !i || j < 1 || j > Ed.Steps.Length
        return
    tmp := Ed.Steps[i], Ed.Steps[i] := Ed.Steps[j], Ed.Steps[j] := tmp
    RefreshEditor()
    Ed.SeqLB.Choose(j)
}

RemoveStep(*) {
    if i := Ed.SeqLB.Value {
        Ed.Steps.RemoveAt(i)
        RefreshEditor()
        if Ed.Steps.Length
            Ed.SeqLB.Choose(Min(i, Ed.Steps.Length))
    }
}

ClearSteps(*) {
    Ed.Steps := []
    RefreshEditor()
}

ShortcutNote(key) {
    for i, b in WorkBindings
        if i != Ed.Idx && b.key = key
            return "Already used for: " FriendlyAction(b.action)
    return ""
}

StartRecording(*) {
    if Ed.Ih
        return
    Ed.KeyEdit.Value := "Press the key combination...  (Esc cancels)"
    Ed.KeyNote.Value := ""
    Suspend(true)                 ; so existing shortcuts don't fire while recording
    ih := InputHook("L0")
    ih.KeyOpt("{All}", "NS")      ; notify on every key, keep it from other apps
    ih.OnKeyDown := RecKeyDown
    Ed.Ih := ih
    ih.Start()
}

RecKeyDown(ih, vk, sc) {
    name := GetKeyName(Format("vk{:x}sc{:x}", vk, sc))
    if name = "" || name ~= "i)^[LR]?(Control|Ctrl|Alt|Shift|Win)$"
        return                    ; wait for the non-modifier key
    mods := (GetKeyState("Ctrl", "P") ? "^" : "")
          . (GetKeyState("Alt", "P") ? "!" : "")
          . (GetKeyState("Shift", "P") ? "+" : "")
          . (GetKeyState("LWin", "P") || GetKeyState("RWin", "P") ? "#" : "")
    StopRecording()
    if mods = "" {
        Ed.KeyEdit.Value := Ed.Key = "" ? "(none - click Record)" : PrettyKey(Ed.Key)
        Ed.KeyNote.Value := name = "Escape" ? "" : "Include Ctrl, Alt, Shift or Win."
        return
    }
    Ed.Key := mods name
    Ed.KeyEdit.Value := PrettyKey(Ed.Key)
    Ed.KeyNote.Value := ShortcutNote(Ed.Key)
}

StopRecording() {
    if Ed && Ed.Ih {
        Ed.Ih.Stop()
        Ed.Ih := 0
        Suspend(false)
    }
}

EdOK(*) {
    if Ed.Ih
        return
    owner := "Owner" Ed.Gui.Hwnd
    if Ed.Key = "" {
        MsgBox("Click Record and press a key combination first.", "SnapKeys", "Icon! " owner)
        return
    }
    if Ed.TypeDDL.Value = 1 {
        if !FracColumns(Ed.FracCB.Text) {
            MsgBox("Enter a width fraction like 1/4.", "SnapKeys", "Icon! " owner)
            return
        }
        if !Ed.Steps.Length {
            MsgBox("Click at least one spot (or an 'All' button).", "SnapKeys", "Icon! " owner)
            return
        }
    }
    for i, b in WorkBindings {
        if i != Ed.Idx && b.key = Ed.Key {
            r := MsgBox(PrettyKey(b.key) " is already used for:`n" FriendlyAction(b.action)
                      . "`n`nReplace it?", "SnapKeys", "YesNo Icon! " owner)
            if r = "No"
                return
            WorkBindings.RemoveAt(i)
            if Ed.Idx > i
                Ed.Idx -= 1
            break
        }
    }
    nb := {key: Ed.Key, action: BuildAction()}
    if Ed.Idx
        WorkBindings[Ed.Idx] := nb
    else
        WorkBindings.Push(nb)
    row := Ed.Idx ? Ed.Idx : WorkBindings.Length
    CloseEditor()
    RefreshList(row)
}

CloseEditor() {
    global Ed
    StopRecording()
    SetGui.Opt("-Disabled")
    Ed.Gui.Destroy()
    Ed := 0
    SetGui.Show()
}

; ======================== WINDOW MOVING ===============================
MakeHandler(act) => (*) => DoAction(act)

DoAction(action) {
    ; Per-monitor DPI awareness so coordinates are right on mixed-DPI setups
    DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")

    hwnd := GetTargetWindow()
    if !hwnd
        return

    wasMax := WinGetMinMax(hwnd) = 1
    if WinGetMinMax(hwnd) != 0
        WinRestore(hwnd)

    vis := GetVisibleRect(hwnd)
    if action != "Restore" && !Originals.Has(hwnd)
        Originals[hwnd] := vis

    mons := GetMonitors()
    mi := MonitorIndexOfRect(mons, vis)
    wa := mons[mi]

    switch action {
    case "Restore":
        if Originals.Has(hwnd) {
            SetVisibleRect(hwnd, Originals[hwnd])
            Originals.Delete(hwnd)
        }
        Remember(0, "", 0, LastRect)
        return

    case "Center":
        w  := Min(vis.R - vis.L, (wa.R - wa.L) - 2 * Gap)
        ht := Min(vis.B - vis.T, (wa.B - wa.T) - 2 * Gap)
        l  := Round(wa.L + ((wa.R - wa.L) - w) / 2)
        t  := Round(wa.T + ((wa.B - wa.T) - ht) / 2)
        SetVisibleRect(hwnd, {L: l, T: t, R: l + w, B: t + ht})
        Remember(hwnd, action, 1, GetVisibleRect(hwnd))
        return

    case "MaximizeHeight":
        SetVisibleRect(hwnd, {L: vis.L, T: wa.T + Gap, R: vis.R, B: wa.B - Gap})
        Remember(hwnd, action, 1, GetVisibleRect(hwnd))
        return

    case "NextDisplay", "PrevDisplay":
        n := mons.Length
        if n < 2
            return
        mj := action = "NextDisplay" ? Mod(mi, n) + 1 : Mod(mi - 2 + n, n) + 1
        src := mons[mi], dst := mons[mj]
        sw := src.R - src.L, sh := src.B - src.T
        dw := dst.R - dst.L, dh := dst.B - dst.T
        ; keep the same relative position and size on the new display
        r := {L: Round(dst.L + (vis.L - src.L) / sw * dw)
            , T: Round(dst.T + (vis.T - src.T) / sh * dh)
            , R: Round(dst.L + (vis.R - src.L) / sw * dw)
            , B: Round(dst.T + (vis.B - src.T) / sh * dh)}
        SetVisibleRect(hwnd, r)
        if wasMax
            WinMaximize(hwnd)
        Remember(hwnd, action, 1, GetVisibleRect(hwnd))
        return
    }

    list := FractionRects(action)
    if !list.Length
        return
    idx := 1
    if CycleOnRepeat && LastHwnd = hwnd && LastAction = action && RectsClose(vis, LastRect)
        idx := Mod(LastIndex, list.Length) + 1
    SetVisibleRect(hwnd, FracToRect(list[idx], wa))
    Remember(hwnd, action, idx, GetVisibleRect(hwnd))
}

; Returns the slots for an action as [x, y, width, height] fractions of the
; work area. Multiple slots = positions cycled through on repeat presses.
FractionRects(action) {
    out := []
    if RegExMatch(action, "^\s*\d+\s*/")
        return ParseSlots(action)
    switch action {
    case "Maximize":
        out.Push([0, 0, 1, 1])
    case "AlmostMaximize":
        mg := (1 - AlmostMaxSize) / 2
        out.Push([mg, mg, AlmostMaxSize, AlmostMaxSize])
    }
    return out
}

; Turns "1/4 Top Bottom@2 Full down" into an ordered list of slots.
;   Top / Bottom / Full  -> every column at that height, left to right
;   Top@N etc.           -> just column N at that height
;   down                 -> walk each column through the heights before moving
;                           right (default is across: finish a height first)
ParseSlots(action) {
    s := RegExReplace(Trim(action), "\s*@\s*", "@")
    if !RegExMatch(s, "^(\d+)\s*/\s*(\d+)\s+(.+)$", &m)
        return []
    w := m[1] / m[2]
    if w <= 0 || w > 1
        return []
    xs := ColumnPositions(w)
    down := false
    groups := []
    for tok in StrSplit(m[3], [" ", ","]) {
        if tok = ""
            continue
        if tok = "down" {
            down := true
            continue
        }
        if tok = "across"
            continue
        if !RegExMatch(tok, "i)^(Top|Bottom|Full)(?:@(\d+))?$", &t)
            return []
        if t[1] = "Top"
            y := 0, h := 0.5
        else if t[1] = "Bottom"
            y := 0.5, h := 0.5
        else
            y := 0, h := 1
        g := []
        if t[2] != "" {
            n := Max(1, Min(Integer(t[2]), xs.Length))
            g.Push([xs[n], y, w, h])
        } else {
            for x in xs
                g.Push([x, y, w, h])
        }
        groups.Push(g)
    }
    out := []
    if !down {
        for g in groups
            for r in g
                out.Push(r)
    } else {
        longest := 0
        for g in groups
            longest := Max(longest, g.Length)
        Loop longest {
            i := A_Index
            for g in groups
                if i <= g.Length
                    out.Push(g[i])
        }
    }
    return out
}

; Left edges for a given width: tile from the left, then add a right-aligned
; slot if the tiles don't reach the right edge (e.g. 2/3 -> 0, 1/3).
ColumnPositions(w) {
    xs := []
    x := 0
    while x + w <= 1.0001 {
        xs.Push(x)
        x += w
    }
    if xs[xs.Length] + w < 0.9999
        xs.Push(1 - w)
    return xs
}

FracToRect(f, wa) {
    hg := Gap / 2
    ox := wa.L + hg, oy := wa.T + hg
    aw := (wa.R - wa.L) - Gap, ah := (wa.B - wa.T) - Gap
    return {L: Round(ox + f[1] * aw + hg)
          , T: Round(oy + f[2] * ah + hg)
          , R: Round(ox + (f[1] + f[3]) * aw - hg)
          , B: Round(oy + (f[2] + f[4]) * ah - hg)}
}

GetTargetWindow() {
    hwnd := WinExist("A")
    if !hwnd
        return 0
    if WinGetClass(hwnd) ~= "^(Progman|WorkerW|Shell_TrayWnd|Shell_SecondaryTrayWnd)$"
        return 0
    return hwnd
}

; Visible frame, excluding Windows 10/11's invisible resize borders
GetVisibleRect(hwnd) {
    buf := Buffer(16, 0)
    if DllCall("dwmapi\DwmGetWindowAttribute", "ptr", hwnd, "uint", 9, "ptr", buf, "uint", 16) = 0
        return {L: NumGet(buf, 0, "int"), T: NumGet(buf, 4, "int")
              , R: NumGet(buf, 8, "int"), B: NumGet(buf, 12, "int")}
    WinGetPos(&x, &y, &w, &h, hwnd)
    return {L: x, T: y, R: x + w, B: y + h}
}

SetVisibleRect(hwnd, r) {
    ; Two passes: the second corrects size if the window rescaled itself
    ; after crossing onto a monitor with different DPI.
    Loop 2 {
        WinGetPos(&x, &y, &w, &h, hwnd)
        v := GetVisibleRect(hwnd)
        bl := v.L - x, bt := v.T - y, br := (x + w) - v.R, bb := (y + h) - v.B
        WinMove(r.L - bl, r.T - bt, (r.R - r.L) + bl + br, (r.B - r.T) + bt + bb, hwnd)
        if RectsClose(GetVisibleRect(hwnd), r, 2)
            break
    }
}

; Work areas (screen minus taskbar), sorted left-to-right then top-to-bottom
GetMonitors() {
    mons := []
    Loop MonitorGetCount() {
        MonitorGetWorkArea(A_Index, &l, &t, &r, &b)
        mon := {L: l, T: t, R: r, B: b}
        pos := mons.Length + 1
        for i, e in mons {
            if (mon.L < e.L) || (mon.L = e.L && mon.T < e.T) {
                pos := i
                break
            }
        }
        mons.InsertAt(pos, mon)
    }
    return mons
}

MonitorIndexOfRect(mons, r) {
    cx := (r.L + r.R) / 2, cy := (r.T + r.B) / 2
    best := 1, bestD := ""
    for i, mon in mons {
        if cx >= mon.L && cx < mon.R && cy >= mon.T && cy < mon.B
            return i
        dx := Max(mon.L - cx, 0, cx - mon.R), dy := Max(mon.T - cy, 0, cy - mon.B)
        d := dx * dx + dy * dy
        if bestD = "" || d < bestD
            best := i, bestD := d
    }
    return best
}

RectsClose(a, b, tol := 8) {
    return Abs(a.L - b.L) <= tol && Abs(a.T - b.T) <= tol
        && Abs(a.R - b.R) <= tol && Abs(a.B - b.B) <= tol
}

Remember(hwnd, action, idx, rect) {
    global LastHwnd, LastAction, LastIndex, LastRect
    LastHwnd := hwnd, LastAction := action, LastIndex := idx, LastRect := rect
}
