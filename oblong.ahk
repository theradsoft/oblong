; =====================================================================
;  oblong.ahk  -  Rectangle-style keyboard window management for Windows
;  Requires AutoHotkey v2  (https://www.autohotkey.com)
;
;  Settings live in Oblong.ini next to this script. Change them from the
;  tray icon > Settings... (or double-click the tray icon).
;
;  Action format (what the settings window builds):
;    "1/4 Top Bottom Full"     cycle every top slot, then bottom, then full
;    "1/3 Top@2"               one specific slot (column 2, top half)
;    "1/4 Top Bottom down"     column by column instead of row by row
;    Maximize AlmostMaximize MaximizeHeight Center Restore
;    NextDisplay PrevDisplay
;    "SaveSet Coding"          remember this desktop's windows as set "Coding"
;    "RecallSet Coding"        arrange this desktop's windows from set "Coding"
; =====================================================================
#Requires AutoHotkey v2.0
#SingleInstance Force

IniFile    := A_ScriptDir "\Oblong.ini"
StartupLnk := A_Startup "\Oblong.lnk"
IconFile   := A_ScriptDir "\oblong.ico"
MAXCOLS    := 12

; Custom tray icon (also used by GUI windows and InputBoxes created after
; this). Falls back to AutoHotkey's icon if oblong.ico is missing. Not frozen,
; so the tray still shows AutoHotkey's "S" icon while hotkeys are suspended.
if FileExist(IconFile)
    try TraySetIcon(IconFile)

TypeNames   := ["Fraction (cycle spots)", "Maximize", "Almost maximize", "Maximize height"
              , "Center", "Restore", "Next display", "Previous display"
              , "Save window set", "Recall window set"]
TypeActions := ["", "Maximize", "AlmostMaximize", "MaximizeHeight"
              , "Center", "Restore", "NextDisplay", "PrevDisplay"
              , "SaveSet", "RecallSet"]

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
SetsGui := 0, SC := 0, SE := 0, SPE := 0   ; sets manager / set editor / spot editor
Picker := 0, LastSetName := ""              ; set picker for shortcuts with no set name
SetsMenu := Menu()           ; tray submenu: one item per saved window set

LoadConfig()
if (errs := ApplyHotkeys()) != ""
    MsgBox("These shortcuts couldn't be registered:`n`n" errs, "Oblong", "Icon!")

A_IconTip := "Oblong"
RebuildSetsMenu()
A_TrayMenu.Add()
A_TrayMenu.Add("Settings...", OpenSettings)
A_TrayMenu.Add("Window sets...", OpenSetsManager)
A_TrayMenu.Add("Recall window set", SetsMenu)
A_TrayMenu.Add("Open Oblong.ini", (*) => Run(IniFile))
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
    if RegExMatch(a, "i)^(SaveSet|RecallSet)(?:\s+(.*))?$", &m)
        return (m[1] = "SaveSet" ? "Save window set: " : "Recall window set: ")
            . (Trim(m[2]) = "" ? "(choose each time)" : Trim(m[2]))
    for i, act in TypeActions
        if i > 1 && act = a
            return TypeNames[i]
    return a
}

SetStartup(on) {
    if on && !FileExist(StartupLnk)
        FileCreateShortcut(A_ScriptFullPath, StartupLnk, A_ScriptDir, , "Oblong window manager"
            , FileExist(IconFile) ? IconFile : "")
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

    g := Gui(, "Oblong Settings")
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
        MsgBox("These shortcuts couldn't be registered:`n`n" errs, "Oblong", "Icon!")
    else
        TrayTip("Settings saved", "Oblong")
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
    ; Set name (only shown for Save/Recall window set), same row as Width
    Ed.SetLbl  := d.Add("Text", "x10 y80 Hidden", "Set name:")
    Ed.SetCB   := d.Add("ComboBox", "x80 y76 w240 Hidden", ListSetNames())
    Ed.SetCB.Text := p.setName
    Ed.SetCB.OnEvent("Change", RefreshEditor)
    Ed.SetNote := d.Add("Text", "x328 y72 w410 h34 Hidden", "")
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
    res := {type: 1, frac: "1/2", steps: [], down: false, setName: ""}
    if RegExMatch(s, "i)^(SaveSet|RecallSet)\s+(.*)$", &m) {
        for i, act in TypeActions
            if act = m[1]
                res.type := i
        res.setName := Trim(m[2])
        return res
    }
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
    if IsSetType(t)
        return Trim(TypeActions[t] " " Trim(Ed.SetCB.Text))   ; blank name = ask
    if t > 1
        return TypeActions[t]
    s := RegExReplace(Ed.FracCB.Text, "\s", "")
    for st in Ed.Steps
        s .= " " st.h (st.col ? "@" st.col : "")
    if Ed.DownRadio.Value
        s .= " down"
    return s
}

IsSetType(t) => TypeActions[t] = "SaveSet" || TypeActions[t] = "RecallSet"

RefreshEditor(*) {
    t := Ed.TypeDDL.Value
    isFrac := t = 1
    isSetAct := IsSetType(t)
    for c in Ed.FracCtls
        c.Visible := isFrac
    Ed.SetLbl.Visible := isSetAct
    Ed.SetCB.Visible := isSetAct
    Ed.SetNote.Visible := isSetAct
    if isSetAct && TypeActions[t] = "SaveSet"
        Ed.SetNote.Value := "Saves this desktop's windows under this name (replacing it). "
            . "Leave blank to type or pick a name each time."
    else if isSetAct
        Ed.SetNote.Value := "Arranges this desktop's windows from this set. "
            . "Leave blank to pick a set each time."
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
        MsgBox("Click Record and press a key combination first.", "Oblong", "Icon! " owner)
        return
    }
    if Ed.TypeDDL.Value = 1 {
        if !FracColumns(Ed.FracCB.Text) {
            MsgBox("Enter a width fraction like 1/4.", "Oblong", "Icon! " owner)
            return
        }
        if !Ed.Steps.Length {
            MsgBox("Click at least one spot (or an 'All' button).", "Oblong", "Icon! " owner)
            return
        }
    }
    if IsSetType(Ed.TypeDDL.Value) && Trim(Ed.SetCB.Text) != "" && !ValidSetName(Trim(Ed.SetCB.Text)) {
        MsgBox("Set names use letters, numbers, spaces, - _ or . (up to 40 characters). "
            . "Leave it blank to choose a set each time.", "Oblong", "Icon! " owner)
        return
    }
    for i, b in WorkBindings {
        if i != Ed.Idx && b.key = Ed.Key {
            r := MsgBox(PrettyKey(b.key) " is already used for:`n" FriendlyAction(b.action)
                      . "`n`nReplace it?", "Oblong", "YesNo Icon! " owner)
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
    ; Window sets don't need a target window. No name = ask with a picker.
    if RegExMatch(action, "i)^(SaveSet|RecallSet)(?:\s+(.*))?$", &m) {
        name := Trim(m[2])
        if name = ""
            PickSet(m[1] = "SaveSet" ? "Save" : "Recall")
        else if m[1] = "SaveSet"
            SaveSet(name)
        else
            RecallSet(name)
        return
    }

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

; Work areas (screen minus taskbar), sorted left-to-right then top-to-bottom.
; detail adds: ML/MT (full monitor origin), Primary, Hw (hardware model ID
; such as DEL41A8, "" if unknown) and Order (position in this sorted list).
GetMonitors(detail := false) {
    mons := []
    prim := detail ? MonitorGetPrimary() : 0
    Loop MonitorGetCount() {
        MonitorGetWorkArea(A_Index, &l, &t, &r, &b)
        mon := {L: l, T: t, R: r, B: b}
        if detail {
            MonitorGet(A_Index, &ml, &mt)
            mon.ML := ml, mon.MT := mt
            mon.Primary := A_Index = prim
            mon.Hw := MonitorHwId(MonitorGetName(A_Index))
        }
        pos := mons.Length + 1
        for i, e in mons {
            if (mon.L < e.L) || (mon.L = e.L && mon.T < e.T) {
                pos := i
                break
            }
        }
        mons.InsertAt(pos, mon)
    }
    if detail
        for i, mon in mons
            mon.Order := i
    return mons
}

; "\\.\DISPLAY1" -> hardware model ID of the monitor on it, e.g. "DEL41A8".
; Stays the same whichever port or order the monitor is plugged in.
MonitorHwId(devName) {
    dd := Buffer(840, 0)                    ; DISPLAY_DEVICEW
    NumPut("uint", 840, dd, 0)
    try {
        ; flag 1 = EDD_GET_DEVICE_INTERFACE_NAME: \\?\DISPLAY#DEL41A8#...
        if DllCall("EnumDisplayDevicesW", "str", devName, "uint", 0, "ptr", dd, "uint", 1) {
            id := StrGet(dd.Ptr + 328, 128, "UTF-16")
            if RegExMatch(id, "i)DISPLAY#([^#]+)#", &m)
                return m[1]
        }
    }
    return ""
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

; ========================= WINDOW SETS ================================
; A set records, for each app window on the CURRENT virtual desktop, the app
; (exe name), the monitor and the position as fractions of that monitor's
; work area. Recalling only touches windows on the current desktop, matched
; by app; windows on other desktops are never moved.
;
; INI:  [Set:<name>]
;       Cascade=0|1               windows sharing a spot: exact stack / cascade
;       MissingMonitor=main|skip  saved monitor not connected
;       N=<exe>|<hwid>|<monL>,<monT>|<order>|<fx>,<fy>,<fw>,<fh>|<max 0/1>

ValidSetName(n) => StrLen(n) <= 40 && RegExMatch(n, "^\w[\w .\-]*$")

ListSetNames() {
    out := []
    try secs := IniRead(IniFile)
    catch
        return out
    Loop Parse secs, "`n", "`r"
        if SubStr(A_LoopField, 1, 4) = "Set:"
            out.Push(SubStr(A_LoopField, 5))
    return out
}

HasSet(name) {
    for n in ListSetNames()
        if n = name
            return true
    return false
}

LoadSet(name) {
    try sect := IniRead(IniFile, "Set:" name)
    catch
        return 0
    s := {cascade: false, missing: "main", spots: []}
    Loop Parse sect, "`n", "`r" {
        p := InStr(A_LoopField, "=")
        if !p
            continue
        k := Trim(SubStr(A_LoopField, 1, p - 1)), v := SubStr(A_LoopField, p + 1)
        if k = "Cascade"
            s.cascade := v = 1
        else if k = "MissingMonitor"
            s.missing := v
        else if IsInteger(k) {
            f := StrSplit(v, "|")
            if f.Length < 6
                continue
            o := StrSplit(f[3], ","), r := StrSplit(f[5], ",")
            if o.Length < 2 || r.Length < 4
                continue
            try s.spots.Push({exe: StrLower(f[1]), hw: f[2]
                , mx: Integer(o[1]), my: Integer(o[2]), order: Integer(f[4])
                , f: [Number(r[1]), Number(r[2]), Number(r[3]), Number(r[4])]
                , max: f[6] = 1})
        }
    }
    return s
}

; Top-level app windows on the current desktop, front-most first.
ListAppWindows() {
    out := []
    myPid := DllCall("GetCurrentProcessId", "uint")
    for hwnd in WinGetList() {
        try {
            if !IsAppWindow(hwnd, myPid)
                continue
            exe := AppExe(hwnd)
        } catch
            continue
        if exe != ""
            out.Push({hwnd: hwnd, exe: exe})
    }
    return out
}

; Normal windows that show on the taskbar: not ours, not minimized, not on
; another virtual desktop (cloaked), not tool windows, popups or dialogs.
IsAppWindow(hwnd, myPid) {
    if WinGetPID(hwnd) = myPid || WinGetMinMax(hwnd) = -1 || IsCloaked(hwnd)
        return false
    if WinGetClass(hwnd) ~= "^(Progman|WorkerW|Shell_TrayWnd|Shell_SecondaryTrayWnd)$"
        return false
    r := GetVisibleRect(hwnd)
    if r.R - r.L < 40 || r.B - r.T < 40
        return false
    ex := WinGetExStyle(hwnd), st := WinGetStyle(hwnd)
    if ex & 0x40000                     ; WS_EX_APPWINDOW: always on the taskbar
        return true
    if ex & 0x08000080                  ; WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE
        return false
    if DllCall("GetWindow", "ptr", hwnd, "uint", 4, "ptr")   ; has an owner
        return false
    return (st & 0xC00000) = 0xC00000 || (st & 0x40000)      ; title bar or resizable
}

; Windows on other virtual desktops (and suspended Store apps) are cloaked
IsCloaked(hwnd) {
    c := 0
    DllCall("dwmapi\DwmGetWindowAttribute", "ptr", hwnd, "uint", 14, "uint*", &c, "uint", 4)
    return c != 0
}

; Lower-case exe name. Store apps all live in ApplicationFrameHost.exe, so
; look up the real app from its CoreWindow child.
AppExe(hwnd) {
    exe := StrLower(WinGetProcessName(hwnd))
    if exe != "applicationframehost.exe"
        return exe
    pid := WinGetPID(hwnd)
    try {
        for c in WinGetControlsHwnd(hwnd) {
            buf := Buffer(512, 0)
            DllCall("GetClassName", "ptr", c, "ptr", buf, "int", 256)
            if StrGet(buf) != "Windows.UI.Core.CoreWindow"
                continue
            cpid := 0
            DllCall("GetWindowThreadProcessId", "ptr", c, "uint*", &cpid)
            if cpid && cpid != pid
                return StrLower(ProcessGetName(cpid))
        }
    }
    return exe
}

SaveSet(name) {
    if !ValidSetName(name) {
        TrayTip("Not a valid set name: " name, "Oblong")
        return 0
    }
    DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")
    mons := GetMonitors(true)
    spots := []
    for w in ListAppWindows() {
        try {
            isMax := WinGetMinMax(w.hwnd) = 1
            r := GetVisibleRect(w.hwnd)
        } catch
            continue
        m := mons[MonitorIndexOfRect(mons, r)]
        ww := m.R - m.L, wh := m.B - m.T
        f := isMax ? [0, 0, 1, 1]
                   : [(r.L - m.L) / ww, (r.T - m.T) / wh, (r.R - r.L) / ww, (r.B - r.T) / wh]
        spots.Push({exe: w.exe, hw: m.Hw, mx: m.ML, my: m.MT, order: m.Order, f: f, max: isMax})
    }
    if !spots.Length {
        TrayTip("No windows to save on this desktop", "Oblong")
        return 0
    }
    WriteSet(name, spots)
    RebuildSetsMenu()
    RefreshSetsList(name)
    TrayTip("Saved '" name "' (" spots.Length " window" (spots.Length = 1 ? "" : "s") ")", "Oblong")
    global LastSetName := name
    return spots.Length
}

; Replace a set's spots, keeping its Cascade/MissingMonitor options
WriteSet(name, spots) {
    sec := "Set:" name
    content := "Cascade=" IniRead(IniFile, sec, "Cascade", 0)
             . "`nMissingMonitor=" IniRead(IniFile, sec, "MissingMonitor", "main")
    for i, sp in spots
        content .= "`n" i "=" sp.exe "|" sp.hw "|" sp.mx "," sp.my "|" sp.order "|"
            . Format("{:.4f},{:.4f},{:.4f},{:.4f}", sp.f*) "|" (sp.max ? 1 : 0)
    try IniDelete(IniFile, sec)
    IniWrite(content, IniFile, sec)
}

RecallSet(name) {
    s := LoadSet(name)
    if !s || !s.spots.Length {
        TrayTip("No window set named '" name "'", "Oblong")
        return
    }
    global LastSetName := name
    DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")
    mons := GetMonitors(true)
    primary := mons[1]
    for m in mons
        if m.Primary
            primary := m

    ; Where each spot lands on the current monitor setup, grouped by app
    byExe := Map()
    for sp in s.spots {
        m := FindMonitor(mons, sp)
        if !m {
            if s.missing = "skip"
                continue
            m := primary
        }
        ww := m.R - m.L, wh := m.B - m.T
        sp.rect := {L: Round(m.L + sp.f[1] * ww), T: Round(m.T + sp.f[2] * wh)
                  , R: Round(m.L + (sp.f[1] + sp.f[3]) * ww), B: Round(m.T + (sp.f[2] + sp.f[4]) * wh)}
        sp.wins := []
        if !byExe.Has(sp.exe)
            byExe[sp.exe] := []
        byExe[sp.exe].Push(sp)
    }

    ; This desktop's windows of those apps, front-most first
    winsByExe := Map()
    for w in ListAppWindows() {
        if !byExe.Has(w.exe)
            continue
        try w.rect := GetVisibleRect(w.hwnd)
        catch
            continue
        if !winsByExe.Has(w.exe)
            winsByExe[w.exe] := []
        winsByExe[w.exe].Push(w)
    }

    moved := 0
    for exe, spots in byExe {
        if !winsByExe.Has(exe)
            continue
        AssignWindows(winsByExe[exe], spots)
        for sp in spots
            moved += PlaceStack(sp, s.cascade)
    }
    Remember(0, "", 0, LastRect)
    if !moved
        TrayTip("No windows from '" name "' on this desktop", "Oblong")
}

; Hardware ID first (position, then order, to tell identical models apart).
; Position/order alone are only trusted when hardware IDs aren't available,
; so a disconnected monitor counts as missing instead of matching a stranger.
FindMonitor(mons, sp) {
    if sp.hw != "" {
        c := []
        haveIds := false
        for m in mons {
            if m.Hw != ""
                haveIds := true
            if m.Hw = sp.hw
                c.Push(m)
        }
        if c.Length = 1
            return c[1]
        if c.Length > 1 {
            for m in c
                if m.ML = sp.mx && m.MT = sp.my
                    return m
            for m in c
                if m.Order = sp.order
                    return m
            return c[1]
        }
        if haveIds
            return 0
    }
    for m in mons
        if m.ML = sp.mx && m.MT = sp.my
            return m
    for m in mons
        if m.Order = sp.order
            return m
    return 0
}

; Each spot first gets its nearest window; leftover windows join their
; nearest spot. sp.wins ends up front-most first.
AssignWindows(wins, spots) {
    pairs := []
    for i, w in wins
        for j, sp in spots
            pairs.Push({i: i, j: j, d: CenterDist(w.rect, sp.rect)})
    SortByD(pairs)
    assign := Map(), usedS := Map()
    for p in pairs
        if !assign.Has(p.i) && !usedS.Has(p.j)
            assign[p.i] := p.j, usedS[p.j] := true
    for p in pairs                       ; sorted, so first hit is nearest
        if !assign.Has(p.i)
            assign[p.i] := p.j
    for i, w in wins
        spots[assign[i]].wins.Push(w)
}

CenterDist(a, b) => ((a.L + a.R) - (b.L + b.R)) ** 2 + ((a.T + a.B) - (b.T + b.B)) ** 2

SortByD(arr) {
    if arr.Length < 2
        return
    Loop arr.Length - 1 {
        i := A_Index + 1
        cur := arr[i], j := i - 1
        while j >= 1 && arr[j].d > cur.d {
            arr[j + 1] := arr[j]
            j -= 1
        }
        arr[j + 1] := cur
    }
}

; Place a spot's windows back to front so the most recently used stays on top.
; Cascade offsets each window so the title bars behind it peek out.
PlaceStack(sp, cascade) {
    n := sp.wins.Length
    if !n
        return 0
    r := sp.rect
    step := cascade && n > 1 && !sp.max ? 32 : 0
    w := (r.R - r.L) - step * (n - 1), h := (r.B - r.T) - step * (n - 1)
    if w < 300 || h < 200                ; too many to cascade: stack exactly
        step := 0, w := r.R - r.L, h := r.B - r.T
    placed := 0
    Loop n {
        k := A_Index - 1                 ; 0 = back-most
        hwnd := sp.wins[n - k].hwnd
        t := {L: r.L + k * step, T: r.T + k * step, R: r.L + k * step + w, B: r.T + k * step + h}
        try {
            if WinGetMinMax(hwnd) != 0
                WinRestore(hwnd)
            if !Originals.Has(hwnd)
                Originals[hwnd] := GetVisibleRect(hwnd)
            SetVisibleRect(hwnd, t)
            if sp.max
                WinMaximize(hwnd)
            placed += 1
        }
    }
    return placed
}

; ------------------------- tray submenu -------------------------------
RebuildSetsMenu() {
    SetsMenu.Delete()
    names := ListSetNames()
    for n in names
        SetsMenu.Add(n, RecallFromMenu)
    if !names.Length {
        SetsMenu.Add("(none saved)", (*) => 0)
        SetsMenu.Disable("(none saved)")
    }
}

RecallFromMenu(itemName, *) => RecallSet(itemName)

; ------------------------- manager window -----------------------------
OpenSetsManager(*) {
    global SetsGui, SC
    if SetsGui {
        SetsGui.Show()
        return
    }
    g := Gui(, "Oblong Window Sets")
    g.SetFont("s9", "Segoe UI")
    SC := {}
    g.Add("Text", "x10 y8 w460 h46", "A set remembers where each app's windows sit on the current desktop. "
        . "Recalling arranges the windows on whichever desktop you're on. Double-click a set to edit its apps.")
    SC.LV := g.Add("ListView", "x10 y56 w460 h190 -Multi Grid NoSortHdr", ["Set", "Windows", "Apps"])
    SC.LV.OnEvent("ItemSelect", SetsSelChanged)
    SC.LV.OnEvent("DoubleClick", (*) => EditSetSpots())
    g.Add("Button", "x10 y254 w140", "Save this desktop as...").OnEvent("Click", (*) => SaveSetPrompt())
    g.Add("Button", "x154 y254 w74", "Edit apps...").OnEvent("Click", (*) => EditSetSpots())
    g.Add("Button", "x232 y254 w74", "Recall").OnEvent("Click", (*) => RecallSelected())
    g.Add("Button", "x310 y254 w78", "Rename...").OnEvent("Click", (*) => RenameSelected())
    g.Add("Button", "x392 y254 w78", "Delete").OnEvent("Click", (*) => DeleteSelectedSet())
    g.Add("GroupBox", "x10 y288 w460 h72", "Options for the selected set")
    SC.Cascade := g.Add("Checkbox", "x24 y310 w440", "Cascade windows that share a spot (instead of stacking exactly)")
    SC.Missing := g.Add("Checkbox", "x24 y334 w440", "If a monitor is missing, use the main monitor (instead of skipping)")
    SC.Cascade.OnEvent("Click", SetOptionChanged)
    SC.Missing.OnEvent("Click", SetOptionChanged)
    g.Add("Button", "x370 y370 w100", "Close").OnEvent("Click", (*) => CloseSetsManager())
    g.OnEvent("Close", (*) => CloseSetsManager())
    g.OnEvent("Escape", (*) => CloseSetsManager())
    SetsGui := g
    RefreshSetsList()
    g.Show("w480 h406")
}

RefreshSetsList(select := "") {
    if !SetsGui
        return
    lv := SC.LV
    lv.Delete()
    row := 0
    for i, n in ListSetNames() {
        s := LoadSet(n)
        apps := "", seen := Map()
        if s
            for sp in s.spots
                if !seen.Has(sp.exe) {
                    seen[sp.exe] := true
                    apps .= (apps = "" ? "" : ", ") RegExReplace(sp.exe, "\.exe$")
                }
        lv.Add(, n, s ? s.spots.Length : 0, apps)
        if n = select
            row := i
    }
    lv.ModifyCol(1, 120)
    lv.ModifyCol(2, "60 Integer")
    lv.ModifyCol(3, 256)
    if row
        lv.Modify(row, "Select Focus Vis")
    SetsSelChanged()
}

SelectedSet() {
    row := SC.LV.GetNext()
    return row ? SC.LV.GetText(row, 1) : ""
}

SetsSelChanged(*) {
    n := SelectedSet()
    SC.Cascade.Enabled := n != ""
    SC.Missing.Enabled := n != ""
    if n = ""
        return
    SC.Cascade.Value := IniRead(IniFile, "Set:" n, "Cascade", 0) = 1
    SC.Missing.Value := IniRead(IniFile, "Set:" n, "MissingMonitor", "main") != "skip"
}

SetOptionChanged(*) {
    n := SelectedSet()
    if n = ""
        return
    IniWrite(SC.Cascade.Value ? 1 : 0, IniFile, "Set:" n, "Cascade")
    IniWrite(SC.Missing.Value ? "main" : "skip", IniFile, "Set:" n, "MissingMonitor")
}

SaveSetPrompt() {
    owner := "Owner" SetsGui.Hwnd
    r := InputBox("Name for the windows on this desktop:", "Save window set", "W320 H130", SelectedSet())
    if r.Result != "OK"
        return
    n := Trim(r.Value)
    if !ValidSetName(n) {
        MsgBox("Use letters, numbers, spaces, - _ or . (up to 40 characters).", "Oblong", "Icon! " owner)
        return
    }
    if HasSet(n) && MsgBox("Replace the set '" n "'?", "Oblong", "YesNo Icon? " owner) = "No"
        return
    SaveSet(n)
}

RecallSelected() {
    if (n := SelectedSet()) != ""
        RecallSet(n)
}

RenameSelected() {
    old := SelectedSet()
    if old = ""
        return
    owner := "Owner" SetsGui.Hwnd
    r := InputBox("New name for '" old "':", "Rename window set", "W320 H130", old)
    if r.Result != "OK"
        return
    n := Trim(r.Value)
    if n == old
        return
    if !ValidSetName(n) {
        MsgBox("Use letters, numbers, spaces, - _ or . (up to 40 characters).", "Oblong", "Icon! " owner)
        return
    }
    if n != old && HasSet(n) {          ; != is case-insensitive: a case-only rename is fine
        MsgBox("There's already a set named '" n "'.", "Oblong", "Icon! " owner)
        return
    }
    content := IniRead(IniFile, "Set:" old)
    IniDelete(IniFile, "Set:" old)
    IniWrite(content, IniFile, "Set:" n)
    RenameSetInBindings(old, n)
    RebuildSetsMenu()
    RefreshSetsList(n)
}

; Keep shortcuts pointing at a renamed set
RenameSetInBindings(old, newName) {
    changed := false
    for b in Bindings
        if RegExMatch(b.action, "i)^(SaveSet|RecallSet)\s+(.+)$", &m) && Trim(m[2]) = old
            b.action := m[1] " " newName, changed := true
    if changed {
        SaveConfig()
        ApplyHotkeys()
    }
    if SetGui {
        for b in WorkBindings
            if RegExMatch(b.action, "i)^(SaveSet|RecallSet)\s+(.+)$", &m) && Trim(m[2]) = old
                b.action := m[1] " " newName
        RefreshList()
    }
}

DeleteSelectedSet() {
    n := SelectedSet()
    if n = ""
        return
    if MsgBox("Delete the window set '" n "'?`n`nShortcuts that use it will stop doing anything."
            , "Oblong", "YesNo Icon? Owner" SetsGui.Hwnd) = "No"
        return
    IniDelete(IniFile, "Set:" n)
    RebuildSetsMenu()
    RefreshSetsList()
}

CloseSetsManager() {
    global SetsGui
    if SetsGui {
        SetsGui.Destroy()
        SetsGui := 0
    }
}

; ------------------------- set editor ---------------------------------
; Edits a working copy of one set's spots (SE.Spots); OK writes it back.

CopySpot(sp) => {exe: sp.exe, hw: sp.hw, mx: sp.mx, my: sp.my, order: sp.order, f: sp.f.Clone(), max: sp.max}

; Monitor list in the same coordinate space the sets are saved in, without
; leaving this thread per-monitor DPI aware (that would change how GUIs scale)
MonitorsForEditor() {
    old := DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")
    mons := GetMonitors(true)
    if old
        DllCall("SetThreadDpiAwarenessContext", "ptr", old, "ptr")
    return mons
}

MonitorLabel(m) => m.Order ": " (m.Hw != "" ? m.Hw : "Monitor") (m.Primary ? " (main)" : "")

SpotMonitorText(sp) {
    if m := FindMonitor(SE.Mons, sp)
        return MonitorLabel(m)
    return (sp.hw != "" ? sp.hw : "Monitor " sp.order) " (not connected)"
}

Pct(x) => RTrim(RTrim(Format("{:.1f}", x * 100), "0"), ".")

SpotPosText(sp) {
    if sp.max
        return "Maximized"
    return "left " Pct(sp.f[1]) "%, top " Pct(sp.f[2]) "%, " Pct(sp.f[3]) "% x " Pct(sp.f[4]) "%"
}

EditSetSpots() {
    global SE
    n := SelectedSet()
    if n = "" || SE
        return
    s := LoadSet(n)
    if !s
        return
    spots := []
    for sp in s.spots
        spots.Push(CopySpot(sp))

    g := Gui("+Owner" SetsGui.Hwnd " -MinimizeBox", "Edit window set - " n)
    g.SetFont("s9", "Segoe UI")
    SE := {Gui: g, Name: n, Spots: spots, Mons: MonitorsForEditor()}
    g.Add("Text", "x10 y10 w560", "Each row is a spot for one app. An app's windows fill its spots nearest-first; "
        . "extra windows stack on the nearest one. An app can have several rows.")
    SE.LV := g.Add("ListView", "x10 y44 w560 h220 -Multi Grid NoSortHdr", ["App", "Monitor", "Position"])
    SE.LV.OnEvent("DoubleClick", (*) => EditSpotSelected())
    g.Add("Button", "x10 y272 w90", "Add...").OnEvent("Click", (*) => EditSpot(0))
    g.Add("Button", "x106 y272 w90", "Edit...").OnEvent("Click", (*) => EditSpotSelected())
    g.Add("Button", "x202 y272 w90", "Duplicate").OnEvent("Click", (*) => DupSpot())
    g.Add("Button", "x298 y272 w90", "Remove").OnEvent("Click", (*) => RemoveSpot())
    g.Add("Button", "x390 y312 w85", "OK").OnEvent("Click", (*) => SaveSetEdits())
    g.Add("Button", "x485 y312 w85", "Cancel").OnEvent("Click", (*) => CloseSetEditor())
    g.OnEvent("Close", (*) => CloseSetEditor())
    g.OnEvent("Escape", (*) => CloseSetEditor())
    SetsGui.Opt("+Disabled")
    RefreshSpotList(spots.Length ? 1 : 0)
    g.Show("w580 h348")
}

RefreshSpotList(sel := 0) {
    lv := SE.LV
    lv.Delete()
    for sp in SE.Spots
        lv.Add(, sp.exe, SpotMonitorText(sp), SpotPosText(sp))
    lv.ModifyCol(1, 150)
    lv.ModifyCol(2, 150)
    lv.ModifyCol(3, 236)
    if sel
        lv.Modify(sel, "Select Focus Vis")
}

EditSpotSelected() {
    if row := SE.LV.GetNext()
        EditSpot(row)
}

DupSpot() {
    if row := SE.LV.GetNext() {
        SE.Spots.InsertAt(row + 1, CopySpot(SE.Spots[row]))
        RefreshSpotList(row + 1)
    }
}

RemoveSpot() {
    if row := SE.LV.GetNext() {
        SE.Spots.RemoveAt(row)
        RefreshSpotList(Min(row, SE.Spots.Length))
    }
}

SaveSetEdits() {
    if !SE.Spots.Length {
        MsgBox("A set needs at least one app. To get rid of the set, cancel and use Delete."
            , "Oblong", "Icon! Owner" SE.Gui.Hwnd)
        return
    }
    name := SE.Name
    WriteSet(name, SE.Spots)
    CloseSetEditor()
    RefreshSetsList(name)
}

CloseSetEditor() {
    global SE
    if !SE
        return
    SetsGui.Opt("-Disabled")
    SE.Gui.Destroy()
    SE := 0
    SetsGui.Show()
}

; ------------------------- spot editor --------------------------------
; Apps already in the set plus apps open on this desktop, for the App box
KnownApps() {
    out := [], seen := Map()
    for sp in SE.Spots
        if !seen.Has(sp.exe)
            seen[sp.exe] := true, out.Push(sp.exe)
    for w in ListAppWindows()
        if !seen.Has(w.exe)
            seen[w.exe] := true, out.Push(w.exe)
    return out
}

EditSpot(idx) {
    global SPE
    if SPE
        return
    if idx
        sp := SE.Spots[idx]
    else
        sp := {exe: "", hw: "", mx: 0, my: 0, order: 1, f: [0, 0, 0.5, 1], max: false}

    d := Gui("+Owner" SE.Gui.Hwnd " -MinimizeBox", idx ? "Edit app spot" : "Add app spot")
    d.SetFont("s9", "Segoe UI")
    SPE := {Gui: d, Idx: idx, Spot: sp, MonChoices: []}

    d.Add("Text", "x10 y12", "App:")
    SPE.App := d.Add("ComboBox", "x90 y8 w230", KnownApps())
    SPE.App.Text := sp.exe

    ; Monitor choices: the saved one if it isn't connected, then current ones
    d.Add("Text", "x10 y44", "Monitor:")
    items := [], choose := 0
    m0 := idx ? FindMonitor(SE.Mons, sp) : 0
    if idx && !m0 {
        items.Push(SpotMonitorText(sp))
        SPE.MonChoices.Push(0)
        choose := 1
    }
    for m in SE.Mons {
        items.Push(MonitorLabel(m))
        SPE.MonChoices.Push(m)
        if (m0 && m = m0) || (!idx && m.Primary)
            choose := items.Length
    }
    SPE.Mon := d.Add("DropDownList", "x90 y40 w230 Choose" Max(choose, 1), items)

    SPE.Max := d.Add("Checkbox", "x90 y72" (sp.max ? " Checked" : ""), "Maximized")
    SPE.Max.OnEvent("Click", SpotMaxToggled)
    d.Add("Text", "x10 y104", "Left %:")
    SPE.L := d.Add("Edit", "x90 y100 w70", Pct(sp.f[1]))
    d.Add("Text", "x180 y104", "Top %:")
    SPE.T := d.Add("Edit", "x250 y100 w70", Pct(sp.f[2]))
    d.Add("Text", "x10 y134", "Width %:")
    SPE.W := d.Add("Edit", "x90 y130 w70", Pct(sp.f[3]))
    d.Add("Text", "x180 y134", "Height %:")
    SPE.H := d.Add("Edit", "x250 y130 w70", Pct(sp.f[4]))
    d.Add("Text", "x10 y164 w310", "Percent of the monitor's usable area (without the taskbar).")

    d.Add("Button", "x140 y194 w85", "OK").OnEvent("Click", SpotOK)
    d.Add("Button", "x235 y194 w85", "Cancel").OnEvent("Click", (*) => CloseSpotEditor())
    d.OnEvent("Close", (*) => CloseSpotEditor())
    d.OnEvent("Escape", (*) => CloseSpotEditor())
    SE.Gui.Opt("+Disabled")
    SpotMaxToggled()
    d.Show("w330 h230")
}

SpotMaxToggled(*) {
    on := !SPE.Max.Value
    for c in [SPE.L, SPE.T, SPE.W, SPE.H]
        c.Enabled := on
}

SpotOK(*) {
    owner := "Owner" SPE.Gui.Hwnd
    exe := StrLower(Trim(SPE.App.Text))
    if !RegExMatch(exe, "^[^\\/:*?`"<>|]+\.exe$") {
        MsgBox("Enter the app's program name, like chrome.exe.", "Oblong", "Icon! " owner)
        return
    }
    isMax := SPE.Max.Value = 1
    if isMax {
        f := [0, 0, 1, 1]
    } else {
        f := []
        for c in [SPE.L, SPE.T, SPE.W, SPE.H] {
            v := Trim(c.Value)
            if !IsNumber(v) {
                MsgBox("Left, top, width and height must be numbers (percent).", "Oblong", "Icon! " owner)
                return
            }
            f.Push(Number(v) / 100)
        }
        ; small tolerance: captured frames can poke a few pixels past the edge
        if f[3] <= 0 || f[4] <= 0 || f[1] < -0.02 || f[2] < -0.02
                || f[1] + f[3] > 1.02 || f[2] + f[4] > 1.02 {
            MsgBox("Keep the spot inside the monitor: left + width and top + height "
                . "can't go past 100%, and width and height must be above 0.", "Oblong", "Icon! " owner)
            return
        }
    }
    sp := SPE.Spot
    ns := {exe: exe, hw: sp.hw, mx: sp.mx, my: sp.my, order: sp.order, f: f, max: isMax}
    if m := SPE.MonChoices[SPE.Mon.Value]
        ns.hw := m.Hw, ns.mx := m.ML, ns.my := m.MT, ns.order := m.Order
    if SPE.Idx
        SE.Spots[SPE.Idx] := ns
    else
        SE.Spots.Push(ns)
    row := SPE.Idx ? SPE.Idx : SE.Spots.Length
    CloseSpotEditor()
    RefreshSpotList(row)
}

CloseSpotEditor() {
    global SPE
    if !SPE
        return
    SE.Gui.Opt("-Disabled")
    SPE.Gui.Destroy()
    SPE := 0
    SE.Gui.Show()
}

; ------------------------- set picker ---------------------------------
; Opened by a SaveSet/RecallSet shortcut that has no set name.
; Save: type a new name or pick an existing one to replace. Recall: pick a set.
; Enter confirms, Esc cancels. Starts on the set used last.
PickSet(mode) {
    global Picker
    if Picker {
        Picker.Gui.Show()
        return
    }
    isSave := mode = "Save"
    names := ListSetNames()
    if !isSave && !names.Length {
        TrayTip("No window sets saved yet", "Oblong")
        return
    }
    g := Gui("+AlwaysOnTop -MinimizeBox", isSave ? "Save window set" : "Recall window set")
    g.SetFont("s9", "Segoe UI")
    Picker := {Gui: g, Save: isSave}
    if isSave {
        g.Add("Text", "xm w280", "Save the windows on this desktop as:")
        Picker.Ctl := g.Add("ComboBox", "xm y+6 w280", names)
        Picker.Ctl.Text := LastSetName
        g.Add("Text", "xm y+6 w280 cGray", "Pick a set to replace it, or type a new name.")
    } else {
        g.Add("Text", "xm w280", "Arrange the windows on this desktop from:")
        Picker.Ctl := g.Add("ListBox", "xm y+6 w280 r" Min(Max(names.Length, 4), 12), names)
        Picker.Ctl.OnEvent("DoubleClick", PickerOK)
        sel := 1
        for i, n in names
            if n = LastSetName
                sel := i
        Picker.Ctl.Choose(sel)
    }
    g.Add("Button", "xm+112 y+12 w80 Default", isSave ? "Save" : "Recall").OnEvent("Click", PickerOK)
    g.Add("Button", "x+8 yp w80", "Cancel").OnEvent("Click", (*) => ClosePicker())
    g.OnEvent("Close", (*) => ClosePicker())
    g.OnEvent("Escape", (*) => ClosePicker())
    g.Show("AutoSize Center")
    try WinActivate(g.Hwnd)
    Picker.Ctl.Focus()
}

PickerOK(*) {
    if !Picker
        return
    isSave := Picker.Save
    name := Trim(Picker.Ctl.Text)
    if isSave && !ValidSetName(name) {
        MsgBox("Use letters, numbers, spaces, - _ or . (up to 40 characters).", "Oblong"
            , "Icon! Owner" Picker.Gui.Hwnd)
        return
    }
    if name = ""
        return
    ClosePicker()                        ; close first so it's out of the way
    if isSave
        SaveSet(name)
    else
        RecallSet(name)
}

ClosePicker() {
    global Picker
    if Picker {
        Picker.Gui.Destroy()
        Picker := 0
    }
}
