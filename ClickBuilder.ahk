#NoEnv
#SingleInstance Force
SetWorkingDir %A_ScriptDir%
SendMode, Input
SetMouseDelay, 10
SetBatchLines, -1

; Process-wide Per-Monitor DPI Aware V2 - required for correct clicks across
; monitors running at different Windows display scaling (TV vs projector).
; Must be process-wide (not thread-scoped) because AHK GUI/hotkey subroutines
; run on separate pseudo-threads. Tries newest API first, falls back for older
; Windows. Must be called BEFORE any GUI is created.
if !DllCall("SetProcessDpiAwarenessContext", "ptr", -4, "int")   ; Win10 1703+ PerMonV2
    if !DllCall("Shcore\SetProcessDpiAwareness", "int", 2, "int")  ; Win8.1+ PerMonitor
        DllCall("User32\SetProcessDPIAware")                       ; Vista+ System-wide

CoordMode, Mouse, Screen
CoordMode, ToolTip, Screen

global StepCount  := 0
global StepX      := []
global StepY      := []
global StepType   := []
global StepDelay  := []
global Picking    := 0
global SETTLE_MS  := 200
global OSDLine1
global OSDLine2

; --- Detect monitors ---
SysGet, MonCount, MonitorCount
SysGet, VW, 78
SysGet, VH, 79
SysGet, VX, 76
SysGet, VY, 77

monInfo := MonCount . " monitor(s)  |  Virtual: " . VW . "x" . VH . "  offset(" . VX . "," . VY . ")"

monDetail := ""
Loop, %MonCount%
{
    SysGet, Mon, Monitor, %A_Index%
    monDetail .= "Monitor " . A_Index . ": " . MonLeft . "," . MonTop . " to " . MonRight . "," . MonBottom . "`n"
}

; ============================================================
;  BUILD THE GUI
; ============================================================
Gui, Main:New, +AlwaysOnTop +Resize, Click Builder v1
Gui, Main:Font, s10, Segoe UI
Gui, Main:Color, 1a1a2e

Gui, Main:Font, s14 cWhite Bold
Gui, Main:Add, Text, x15 y10 w460 Center, Click Builder
Gui, Main:Font, s9 cSilver Normal
Gui, Main:Add, Text, x15 y35 w460 Center, Custom delay > move > 200ms settle > click

Gui, Main:Font, s10 c000000 Normal
Gui, Main:Add, ListView, x15 y65 w460 h230 vStepList Grid -Multi AltSubmit gListEvents, #|X|Y|Click|Wait (ms)|Monitor
LV_ModifyCol(1, 30)
LV_ModifyCol(2, 65)
LV_ModifyCol(3, 65)
LV_ModifyCol(4, 65)
LV_ModifyCol(5, 75)
LV_ModifyCol(6, 95)

Gui, Main:Font, s10 cWhite Normal
Gui, Main:Add, Button, x15  y305 w145 h36 gPickClick vBtnPick, Pick Next Click  (F2)
Gui, Main:Add, Button, x168 y305 w145 h36 gRunSequence vBtnRun, Run Sequence  (F5)
Gui, Main:Add, Button, x321 y305 w155 h36 gSaveSequence vBtnSave, Save As .ahk

Gui, Main:Add, Button, x15  y348 w145 h32 gMoveUp, Move Up
Gui, Main:Add, Button, x168 y348 w145 h32 gMoveDown, Move Down
Gui, Main:Add, Button, x321 y348 w155 h32 gDeleteStep, Delete Step

Gui, Main:Add, Button, x15  y388 w145 h32 gClearAll, Clear All
Gui, Main:Add, Button, x168 y388 w145 h32 gEditDelay, Edit Delay
Gui, Main:Add, Button, x321 y388 w155 h32 gShowMonitors, Show Monitors

Gui, Main:Add, Button, x15  y428 w225 h32 gLoadSequence, Load .ahk

Gui, Main:Font, s9 c888888
Gui, Main:Add, Text, x15 y470 w460 vStatusBar, %monInfo%

Gui, Main:Show, w490 h498
Return

; ============================================================
;  HOTKEYS
; ============================================================
F2::
    GoSub, PickClick
Return

F5::
    GoSub, RunSequence
Return

~Esc::
    if (Picking) {
        Picking := 0
        ToolTip
        Gui, Main:Show
        GuiControl, Main:, StatusBar, Pick cancelled
    }
Return

ShowMonitors:
    MsgBox, 64, Monitor Layout, %monInfo%`n`n%monDetail%`nCoords span all monitors. Click anywhere on any screen.
Return

; ============================================================
;  PICK A CLICK LOCATION
; ============================================================
PickClick:
    Picking := 1
    CoordMode, Mouse, Screen
    Gui, Main:Hide
    Sleep, 200
    ToolTip, Click anywhere on ANY monitor`nPress Esc to cancel, 10, 10

    KeyWait, LButton, D
    MouseGetPos, capX, capY
    KeyWait, LButton
    ToolTip
    Picking := 0

    whichMon := "?"
    Loop, %MonCount%
    {
        SysGet, Mon, Monitor, %A_Index%
        if (capX >= MonLeft && capX < MonRight && capY >= MonTop && capY < MonBottom) {
            whichMon := "Mon " . A_Index
            Break
        }
    }

    Gui, Main:Show
    MsgBox, 3, Click Type, Coords: %capX%`, %capY%  (%whichMon%)`n`nYes = Single Click`nNo = Double Click`nCancel = discard
    IfMsgBox, Cancel
    {
        GuiControl, Main:, StatusBar, Pick discarded
        Return
    }
    IfMsgBox, Yes
        clickType := "Single"
    IfMsgBox, No
        clickType := "Double"

    InputBox, delayMs, Wait Before This Step, How many ms to wait BEFORE moving to this click?`n`n0 = no extra wait`n500 = half second`n1000 = 1 second`n3000 = 3 seconds, , 360, 260, , , , , 500
    if (ErrorLevel) {
        GuiControl, Main:, StatusBar, Pick cancelled at delay prompt
        Return
    }
    if delayMs is not integer
        delayMs := 500
    if (delayMs < 0)
        delayMs := 0

    StepCount++
    StepX.Push(capX)
    StepY.Push(capY)
    StepType.Push(clickType)
    StepDelay.Push(delayMs)

    RefreshList()
    GuiControl, Main:, StatusBar, Step %StepCount%: %clickType% at %capX%`, %capY%  wait %delayMs%ms  (%whichMon%)
Return

; ============================================================
;  OSD OVERLAY  (guaranteed click-through, two lines)
; ============================================================
CreateOSD() {
    global OSDLine1, OSDLine2, OSDhwnd
    Gui, OSD:Destroy

    ; +E0x20 = WS_EX_TRANSPARENT (click-through)
    ; +E0x80000 = WS_EX_LAYERED (required for transparency)
    ; +E0x08000000 = WS_EX_NOACTIVATE (never steals focus)
    Gui, OSD:New, +AlwaysOnTop +ToolWindow -Caption +E0x08080020
    Gui, OSD:Color, 111111

    ; Line 1: countdown / step info (big yellow)
    Gui, OSD:Font, s22 cFFFF00 Bold, Segoe UI
    Gui, OSD:Add, Text, x20 y12 w760 Center vOSDLine1 +BackgroundTrans, Starting...

    ; Line 2: message (white)
    Gui, OSD:Font, s14 cWhite Normal, Segoe UI
    Gui, OSD:Add, Text, x20 y55 w760 Center vOSDLine2 +BackgroundTrans, Please do not touch the mouse until you see the driving range

    osdW := 800
    osdH := 95
    osdX := (A_ScreenWidth - osdW) // 2
    Gui, OSD:Show, x%osdX% y20 w%osdW% h%osdH% NoActivate

    ; Get the window handle
    Gui, OSD:+LastFound
    OSDhwnd := WinExist()

    ; Belt-and-suspenders: force click-through AGAIN after show
    ; 0x20 = WS_EX_TRANSPARENT, 0x80000 = WS_EX_LAYERED
    WinSet, ExStyle, +0x20, ahk_id %OSDhwnd%
    WinSet, Transparent, 200, ahk_id %OSDhwnd%
}

SetOSDLine1(txt) {
    global OSDLine1
    GuiControl, OSD:, OSDLine1, %txt%
}

SetOSDLine2(txt) {
    global OSDLine2
    GuiControl, OSD:, OSDLine2, %txt%
}

HideOSD() {
    Gui, OSD:Destroy
}

; ============================================================
;  RUN THE SEQUENCE  (with countdown overlay)
; ============================================================
RunSequence:
    if (StepCount = 0) {
        MsgBox, 48, Empty, No steps to run!
        Return
    }
    MsgBox, 1, Run Sequence, Ready to run %StepCount% step(s).`n`nA countdown overlay will appear.`nStarts 3 seconds after OK.
    IfMsgBox, Cancel
        Return

    Gui, Main:Hide

    ; Calculate total estimated time
    totalMs := 3000
    Loop, %StepCount%
    {
        totalMs += StepDelay[A_Index] + SETTLE_MS + 50
    }

    ; Show overlay
    CreateOSD()

    ; 3-2-1 grace countdown
    Loop, 3
    {
        grace := 4 - A_Index
        SetOSDLine1("Starting in " . grace . "...")
        Sleep, 1000
        totalMs -= 1000
    }

    CoordMode, Mouse, Screen
    SetMouseDelay, 10

    Loop, %StepCount%
    {
        i := A_Index

        ; Calculate remaining time
        remMs := 0
        j := i
        while (j <= StepCount)
        {
            remMs += StepDelay[j] + SETTLE_MS + 50
            j++
        }
        remSec := Round(remMs / 1000)

        SetOSDLine1("Step " . i . " of " . StepCount . "   -   " . remSec . " seconds left")

        ; 1) Custom wait - tick down in 500ms chunks
        d := StepDelay[i]
        if (d > 0) {
            waited := 0
            while (waited < d) {
                chunk := d - waited
                if (chunk > 500)
                    chunk := 500
                Sleep, %chunk%
                waited += chunk
                remMs -= chunk
                remSec := Round(remMs / 1000)
                if (remSec < 0)
                    remSec := 0
                SetOSDLine1("Step " . i . " of " . StepCount . "   -   " . remSec . " seconds left")
            }
        }

        mx := StepX[i]
        my := StepY[i]
        ct := StepType[i]

        ; 2) Move mouse
        MouseMove, %mx%, %my%, 0

        ; 3) Settle
        Sleep, %SETTLE_MS%

        ; 4) Click
        if (ct = "Double")
            Click, %mx%, %my%, 2
        else
            Click, %mx%, %my%
    }

    ; Done
    SetOSDLine1("All done!")
    SetOSDLine2("You can use the mouse now.")
    Sleep, 2500
    HideOSD()

    Gui, Main:Show
    GuiControl, Main:, StatusBar, Sequence finished!
Return

; ============================================================
;  SAVE AS STANDALONE .AHK  (auto-runs with overlay)
; ============================================================
SaveSequence:
    if (StepCount = 0) {
        MsgBox, 48, Empty, No steps to save!
        Return
    }
    FormatTime, ts, , yyyyMMdd_HHmmss
    defaultName := "ClickMacro_" . ts . ".ahk"
    FileSelectFile, savePath, S16, %defaultName%, Save Click Macro, AHK Scripts (*.ahk)
    if (ErrorLevel)
        Return

    if !RegExMatch(savePath, "i)\.ahk$")
        savePath .= ".ahk"

    ; Calculate total time
    saveTotalMs := 3000
    Loop, %StepCount%
    {
        saveTotalMs += StepDelay[A_Index] + 200 + 50
    }
    saveTotalSec := Round(saveTotalMs / 1000)

    f := ""
    f .= "`;  Auto-Run Click Macro`r`n"
    f .= "`;  Generated: " . A_Now . "`r`n"
    f .= "`;  Steps: " . StepCount . "  Est: ~" . saveTotalSec . "s`r`n"
    f .= "#NoEnv`r`n"
    f .= "#SingleInstance Force`r`n"
    f .= "SendMode, Input`r`n"
    f .= "SetMouseDelay, 10`r`n"
    f .= "SetBatchLines, -1`r`n"
    f .= "`; Process-wide Per-Monitor DPI Aware V2 - correct clicks across mixed-scale monitors`r`n"
    f .= "if !DllCall(""SetProcessDpiAwarenessContext"", ""ptr"", -4, ""int"")`r`n"
    f .= "    if !DllCall(""Shcore\SetProcessDpiAwareness"", ""int"", 2, ""int"")`r`n"
    f .= "        DllCall(""User32\SetProcessDPIAware"")`r`n"
    f .= "CoordMode, Mouse, Screen`r`n"
    f .= "global OSDLine1`r`n"
    f .= "global OSDLine2`r`n"
    f .= "global OSDhwnd`r`n`r`n"

    ; --- Embed OSD functions ---
    f .= "CreateOSD() {`r`n"
    f .= "    global OSDLine1, OSDLine2, OSDhwnd`r`n"
    f .= "    Gui, OSD:Destroy`r`n"
    f .= "    Gui, OSD:New, +AlwaysOnTop +ToolWindow -Caption +E0x08080020`r`n"
    f .= "    Gui, OSD:Color, 111111`r`n"
    f .= "    Gui, OSD:Font, s22 cFFFF00 Bold, Segoe UI`r`n"
    f .= "    Gui, OSD:Add, Text, x20 y12 w760 Center vOSDLine1 +BackgroundTrans, Starting...`r`n"
    f .= "    Gui, OSD:Font, s14 cWhite Normal, Segoe UI`r`n"
    f .= "    Gui, OSD:Add, Text, x20 y55 w760 Center vOSDLine2 +BackgroundTrans, Please do not touch the mouse until you see the driving range`r`n"
    f .= "    osdW := 800`r`n"
    f .= "    osdH := 95`r`n"
    f .= "    osdX := (A_ScreenWidth - osdW) // 2`r`n"
    f .= "    Gui, OSD:Show, x%osdX% y20 w%osdW% h%osdH% NoActivate`r`n"
    f .= "    Gui, OSD:+LastFound`r`n"
    f .= "    OSDhwnd := WinExist()`r`n"
    f .= "    WinSet, ExStyle, +0x20, ahk_id %OSDhwnd%`r`n"
    f .= "    WinSet, Transparent, 200, ahk_id %OSDhwnd%`r`n"
    f .= "}`r`n`r`n"

    f .= "SetOSDLine1(txt) {`r`n"
    f .= "    global OSDLine1`r`n"
    f .= "    GuiControl, OSD:, OSDLine1, %txt%`r`n"
    f .= "}`r`n`r`n"

    f .= "SetOSDLine2(txt) {`r`n"
    f .= "    global OSDLine2`r`n"
    f .= "    GuiControl, OSD:, OSDLine2, %txt%`r`n"
    f .= "}`r`n`r`n"

    f .= "HideOSD() {`r`n"
    f .= "    Gui, OSD:Destroy`r`n"
    f .= "}`r`n`r`n"

    ; --- Grace countdown ---
    f .= "CreateOSD()`r`n"
    f .= "SetOSDLine1(""Starting in 3..."")`r`n"
    f .= "Sleep, 1000`r`n"
    f .= "SetOSDLine1(""Starting in 2..."")`r`n"
    f .= "Sleep, 1000`r`n"
    f .= "SetOSDLine1(""Starting in 1..."")`r`n"
    f .= "Sleep, 1000`r`n`r`n"

    ; --- Steps ---
    ; Pre-calculate remaining time at each step
    remArr := []
    remTotal := 0
    i := StepCount
    while (i >= 1) {
        remTotal += StepDelay[i] + 250
        remArr[i] := Round(remTotal / 1000)
        i--
    }

    Loop, %StepCount%
    {
        i  := A_Index
        d  := StepDelay[i]
        mx := StepX[i]
        my := StepY[i]
        ct := StepType[i]
        rs := remArr[i]

        f .= "SetOSDLine1(""Step " . i . " of " . StepCount . "   -   " . rs . " seconds left"")`r`n"

        if (d > 0)
            f .= "Sleep, " . d . "`r`n"

        f .= "MouseMove, " . mx . ", " . my . ", 0`r`n"
        f .= "Sleep, 200`r`n"

        if (ct = "Double")
            f .= "Click, " . mx . ", " . my . ", 2`r`n"
        else
            f .= "Click, " . mx . ", " . my . "`r`n"

        f .= "`r`n"
    }

    f .= "SetOSDLine1(""All done!"")`r`n"
    f .= "SetOSDLine2(""You can use the mouse now."")`r`n"
    f .= "Sleep, 2500`r`n"
    f .= "HideOSD()`r`n"
    f .= "ExitApp`r`n`r`n"
    f .= "Esc::ExitApp`r`n"

    FileDelete, %savePath%
    FileAppend, %f%, %savePath%

    if (ErrorLevel)
        MsgBox, 16, Error, Failed to save file!
    else {
        MsgBox, 64, Saved, Macro saved to:`n%savePath%`n`nAUTO-RUNS with countdown overlay.`nEsc to abort.
        GuiControl, Main:, StatusBar, Saved: %savePath%
    }
Return

; ============================================================
;  LOAD A PREVIOUSLY SAVED .AHK MACRO
; ============================================================
LoadSequence:
    FileSelectFile, loadPath, 3, , Load Click Macro, AHK Scripts (*.ahk)
    if (ErrorLevel)
        Return

    StepCount := 0
    StepX     := []
    StepY     := []
    StepType  := []
    StepDelay := []

    pendingDelay := 0
    FileRead, fileLines, %loadPath%
    Loop, Parse, fileLines, `n, `r
    {
        line := Trim(A_LoopField)

        if (RegExMatch(line, "i)^\s*Sleep\s*,\s*(\d+)", m)) {
            val := m1 + 0
            if (val != 200 && val != 3000 && val != 1000 && val != 2500)
                pendingDelay := val
            Continue
        }

        if (RegExMatch(line, "i)^\s*MouseMove"))
            Continue

        if (RegExMatch(line, "i)^\s*Click\s*,\s*(-?\d+)\s*,\s*(-?\d+)\s*(?:,\s*(\d+))?", m)) {
            StepCount++
            StepX.Push(m1 + 0)
            StepY.Push(m2 + 0)

            if (m3 = "2")
                StepType.Push("Double")
            else
                StepType.Push("Single")

            StepDelay.Push(pendingDelay)
            pendingDelay := 0
        }
    }

    RefreshList()
    GuiControl, Main:, StatusBar, Loaded %StepCount% step(s) from file
Return

; ============================================================
;  LIST MANAGEMENT
; ============================================================
MoveUp:
    row := LV_GetNext()
    if (row <= 1)
        Return
    SwapSteps(row, row - 1)
    RefreshList()
    LV_Modify(row - 1, "Select Focus")
Return

MoveDown:
    row := LV_GetNext()
    if (row = 0 || row >= StepCount)
        Return
    SwapSteps(row, row + 1)
    RefreshList()
    LV_Modify(row + 1, "Select Focus")
Return

DeleteStep:
    row := LV_GetNext()
    if (row = 0)
        Return
    StepX.RemoveAt(row)
    StepY.RemoveAt(row)
    StepType.RemoveAt(row)
    StepDelay.RemoveAt(row)
    StepCount--
    RefreshList()
    GuiControl, Main:, StatusBar, Step deleted. %StepCount% step(s) remaining.
Return

ClearAll:
    if (StepCount = 0)
        Return
    MsgBox, 4, Confirm, Clear all %StepCount% step(s)?
    IfMsgBox, No
        Return
    StepCount := 0
    StepX     := []
    StepY     := []
    StepType  := []
    StepDelay := []
    RefreshList()
    GuiControl, Main:, StatusBar, All steps cleared
Return

EditDelay:
    row := LV_GetNext()
    if (row = 0) {
        MsgBox, 48, Select, Select a step first!
        Return
    }
    oldDelay := StepDelay[row]
    InputBox, newDelay, Edit Delay, New wait (ms) BEFORE step %row%:, , 300, 160, , , , , %oldDelay%
    if (ErrorLevel)
        Return
    if newDelay is not integer
        Return
    if (newDelay < 0)
        newDelay := 0
    StepDelay[row] := newDelay
    RefreshList()
    LV_Modify(row, "Select Focus")
    GuiControl, Main:, StatusBar, Step %row% wait updated to %newDelay% ms
Return

ListEvents:
Return

; ============================================================
;  HELPERS
; ============================================================
RefreshList() {
    global
    Gui, Main:Default
    LV_Delete()
    Loop, %StepCount%
    {
        i := A_Index
        cx := StepX[i]
        cy := StepY[i]

        whichMon := "?"
        SysGet, mc, MonitorCount
        Loop, %mc%
        {
            SysGet, Mon, Monitor, %A_Index%
            if (cx >= MonLeft && cx < MonRight && cy >= MonTop && cy < MonBottom) {
                whichMon := "Mon " . A_Index
                Break
            }
        }

        LV_Add("", i, cx, cy, StepType[i], StepDelay[i], whichMon)
    }
}

SwapSteps(a, b) {
    global
    tmp := StepX[a],     StepX[a] := StepX[b],     StepX[b] := tmp
    tmp := StepY[a],     StepY[a] := StepY[b],     StepY[b] := tmp
    tmp := StepType[a],  StepType[a] := StepType[b],  StepType[b] := tmp
    tmp := StepDelay[a], StepDelay[a] := StepDelay[b], StepDelay[b] := tmp
}

MainGuiClose:
MainGuiEscape:
    ExitApp
Return
