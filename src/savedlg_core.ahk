; ============================================================================
;  Save To Project - core  (AutoHotkey v1)
;
;  Watches Windows file-save dialogs (Save As, Output Movie To:, Export ...)
;  opened by After Effects / Media Encoder / Premiere Pro / Maya and points
;  them at the ROOT of the project currently open in that app:
;
;      D:\...\Acme\JOB1234_Promo_Oct26\01_Projects\01 - AE\...\Foo_V07.aep
;   -> D:\...\Acme\JOB1234_Promo_Oct26
;
;  Rules
;   - Project root = the folder that holds "01_Projects". A project outside
;     that structure falls back to the scene / project file's own folder.
;   - A dialog that ALREADY sits inside the project root is left alone
;     (so File > Save As next to the current .aep keeps working).
;   - Media Encoder has no project: After Effects' project is used, then
;     Premiere's.  With SaveDlg_AllApps on, EVERY other app (Photoshop,
;     Illustrator, browsers, Notepad ...) is treated the same way.
;   - After Effects truncates its title bar ("D:\Studio Dropbox\Cl ... 26\...").
;     The full path is recovered by a bounded breadth-first search of the
;     file system from the visible start of the path; results are cached.
;   - Maya must be set to Preferences > Files/Projects > File Dialog: OS native
;     (its default dialog is Maya's own and cannot be steered).
;   - A dialog counts as a save dialog when its title starts with Save /
;     Export / Output / Render, or its OK button says "Save" (Firefox titles
;     its dialog "Enter name of file to save to...").
;   - Open / Import dialogs are never touched.
;
;  Public knobs (set after SaveDlg_Init):
;     SaveDlg_Enabled, SaveDlg_SubFolder ("" = root, e.g. "09_Output"),
;     SaveDlg_AllApps (other apps follow After Effects / Premiere),
;     SaveDlg_Exclude (exe names never touched, e.g. ["chrome.exe"]),
;     SaveDlg_RootMarker (folder whose parent is the project root),
;     SaveDlg_CacheFile (ini file that persists resolved paths)
; ============================================================================

SaveDlg_Init() {
    global SaveDlg_Enabled, SaveDlg_SubFolder, SaveDlg_Apps, SaveDlg_TitleRe
    global SaveDlg_Handled, SaveDlg_Cache, SaveDlg_CacheFile, SaveDlg_TestRoot
    global SaveDlg_WalkMaxDepth, SaveDlg_LastInfo, SaveDlg_LastTarget, SaveDlg_SaveBtnRe
    global SaveDlg_AllApps, SaveDlg_Exclude, SaveDlg_RootMarker
    SaveDlg_Enabled      := true
    SaveDlg_AllApps      := true
    SaveDlg_Exclude      := []
    SaveDlg_RootMarker   := "01_Projects"
    SaveDlg_SubFolder    := ""
    SaveDlg_Apps         := ["AfterFX.exe", "Adobe Media Encoder.exe", "Adobe Premiere Pro.exe", "maya.exe"]
    SaveDlg_TitleRe      := "i)^(Save|Export|Output|Render)"
    SaveDlg_SaveBtnRe    := "i)^(Save|Export|Speichern|Enregistrer|Guardar|Salva|Opslaan|Zapisz|Salvar)"
    SaveDlg_WalkMaxDepth := 7
    SaveDlg_Handled      := {}       ; hwnd -> true   (dialogs already processed)
    SaveDlg_Cache        := {}       ; truncated title path -> full path
    SaveDlg_CacheFile    := ""       ; optional ini; section [cache]
    SaveDlg_TestRoot     := ""       ; test hook: forces the project root
    SaveDlg_LastInfo     := ""       ; trace of the last lookup (for the status window)
    SaveDlg_LastTarget   := ""
    SetTimer, SaveDlg_Tick, 300
}

SaveDlg_Toggle() {
    global SaveDlg_Enabled
    SaveDlg_Enabled := !SaveDlg_Enabled
    SaveDlg_Tip("Save To Project: " . (SaveDlg_Enabled ? "ON" : "OFF"))
}

; ---------------------------------------------------------------------------
;  Dialog watcher
; ---------------------------------------------------------------------------
SaveDlg_Tick() {
    global SaveDlg_Enabled, SaveDlg_Handled
    if (!SaveDlg_Enabled)
        return
    gone := []
    for hwnd in SaveDlg_Handled
        if !WinExist("ahk_id " . hwnd)
            gone.Push(hwnd)
    for i, hwnd in gone
        SaveDlg_Handled.Delete(hwnd)

    WinGet, dlgList, List, ahk_class #32770
    Loop % dlgList {
        hwnd := dlgList%A_Index%
        if SaveDlg_Handled.HasKey(hwnd)
            continue
        WinGet, exe, ProcessName, ahk_id %hwnd%
        if !SaveDlg_Watches(exe)
            continue
        if !SaveDlg_IsFileDialog(hwnd)
            continue                           ; not (yet) a file dialog - re-check next tick
        SaveDlg_Handled[hwnd] := true
        SaveDlg_Redirect(hwnd, exe)
    }
}

; Known apps always; any other app only with SaveDlg_AllApps. Never ourselves
; or an excluded exe.
SaveDlg_Watches(exe) {
    global SaveDlg_Apps, SaveDlg_AllApps, SaveDlg_Exclude
    if (exe = "")
        return false
    for i, x in SaveDlg_Exclude
        if (x = exe)
            return false
    for i, x in SaveDlg_Apps
        if (x = exe)
            return true
    if (exe = "AutoHotkey.exe" || (A_IsCompiled && exe = A_ScriptName))
        return false
    return SaveDlg_AllApps
}

; A Windows common file dialog: save-like title or OK button, a filename box
; and a shell view.
SaveDlg_IsFileDialog(hwnd) {
    global SaveDlg_TitleRe
    WinGetTitle, title, ahk_id %hwnd%
    if !RegExMatch(title, SaveDlg_TitleRe) && !SaveDlg_HasSaveButton(hwnd)
        return false
    ControlGet, hEdit, Hwnd,, Edit1, ahk_id %hwnd%
    if (!hEdit)
        return false
    WinGet, ctrls, ControlList, ahk_id %hwnd%
    return InStr(ctrls, "DirectUIHWND") || InStr(ctrls, "SHELLDLL_DefView")
}

; OK button (control id 1) labelled "&Save" / "Save" - Open dialogs say "&Open".
SaveDlg_HasSaveButton(hwnd) {
    global SaveDlg_SaveBtnRe
    hBtn := DllCall("GetDlgItem", "Ptr", hwnd, "Int", 1, "Ptr")
    if (!hBtn)
        return false
    ControlGetText, label,, ahk_id %hBtn%
    return RegExMatch(StrReplace(label, "&"), SaveDlg_SaveBtnRe)
}

SaveDlg_Redirect(hwnd, exe) {
    global SaveDlg_LastTarget
    root := SaveDlg_GetProjectRoot(exe)
    if (root = "")
        return
    target := SaveDlg_TargetFor(root)
    if (target = "")
        return

    cur := SaveDlg_GetDialogFolder(hwnd)
    if (cur != "" && SaveDlg_IsUnder(cur, root))
        return                                 ; already inside the project - leave it

    if !WinExist("ahk_id " . hwnd)
        return                                 ; closed while we were looking
    ControlGetText, origName, Edit1, ahk_id %hwnd%
    ControlFocus, Edit1, ahk_id %hwnd%
    ControlSetText, Edit1, %target%, ahk_id %hwnd%
    Sleep, 60
    ControlSend, Edit1, {Enter}, ahk_id %hwnd%
    Sleep, 300
    ControlSetText, Edit1, %origName%, ahk_id %hwnd%
    SaveDlg_LastTarget := target
    SaveDlg_Tip("-> " . target)
}

; root (+ optional subfolder if it exists) - "" if the root is not a folder
SaveDlg_TargetFor(root) {
    global SaveDlg_SubFolder
    if !InStr(FileExist(root), "D")
        return ""
    if (SaveDlg_SubFolder != "" && InStr(FileExist(root . "\" . SaveDlg_SubFolder), "D"))
        return root . "\" . SaveDlg_SubFolder
    return root
}

; Folder the dialog currently shows, read from its breadcrumb bar.
; The label is localized ("Address: D:\..." in English, translated elsewhere), so only the
; path part is trusted.
SaveDlg_GetDialogFolder(hwnd) {
    WinGet, ctrls, ControlList, ahk_id %hwnd%
    Loop, Parse, ctrls, `n
    {
        if !InStr(A_LoopField, "ToolbarWindow32")
            continue
        ControlGetText, t, %A_LoopField%, ahk_id %hwnd%
        if RegExMatch(t, "^[^:]+:\s+((?:[A-Za-z]:\\|\\\\).*)$", m)
            return RTrim(m1, "\")
    }
    return ""
}

SaveDlg_IsUnder(path, root) {
    return InStr(RTrim(path, "\") . "\", RTrim(root, "\") . "\") = 1
}

; ---------------------------------------------------------------------------
;  Project lookup
; ---------------------------------------------------------------------------
SaveDlg_GetProjectRoot(exe) {
    global SaveDlg_TestRoot
    if (SaveDlg_TestRoot != "")
        return SaveDlg_TestRoot
    if (exe = "AfterFX.exe")
        proj := SaveDlg_AEProject()
    else if (exe = "Adobe Premiere Pro.exe")
        proj := SaveDlg_PremiereProject()
    else if (exe = "maya.exe")
        proj := SaveDlg_MayaProject()
    else {                                     ; Media Encoder / any other app: AE first, then Premiere
        proj := SaveDlg_AEProject()
        if (proj = "")
            proj := SaveDlg_PremiereProject()
    }
    return SaveDlg_RootFromProject(proj)
}

; "Adobe After Effects 2026 - X:\...\Foo.aep *"
SaveDlg_AEProject() {
    return SaveDlg_ProjectFromTitle("AfterFX.exe", "i)^Adobe After Effects [^-]*- (.+?\.aep)( \*)?$")
}

; "Adobe Premiere Pro 2026 - X:\...\Foo.prproj *"
SaveDlg_PremiereProject() {
    return SaveDlg_ProjectFromTitle("Adobe Premiere Pro.exe", "i)^Adobe Premiere Pro [^-]*- (.+?\.prproj)( \*)?$")
}

; "Autodesk Maya 2025: X:/.../scene.ma*  ---  pCube1"   (forward slashes, * = modified)
SaveDlg_MayaProject() {
    return SaveDlg_ProjectFromTitle("maya.exe", "i)^Autodesk Maya[^:]*:\s*(.+?\.m[ab])\*?(\s+---.*)?$")
}

SaveDlg_ProjectFromTitle(exe, re) {
    WinGet, winList, List, ahk_exe %exe%
    Loop % winList {
        WinGetTitle, title, % "ahk_id " . winList%A_Index%
        if RegExMatch(title, re, m)
            return SaveDlg_ResolveTruncated(StrReplace(m1, "/", "\"))
    }
    return ""
}

; Root = parent of the "01_Projects" (SaveDlg_RootMarker) folder; otherwise the project file's folder.
SaveDlg_RootFromProject(projPath) {
    global SaveDlg_RootMarker
    if (projPath = "")
        return ""
    SplitPath, projPath,, dir
    if (p := InStr(dir . "\", "\" . SaveDlg_RootMarker . "\"))
        return SubStr(dir, 1, p - 1)
    return dir
}

; "D:\Studio Dropbox\Cl ... 26\01_Projects\...\Foo_V07.aep" -> full path
SaveDlg_ResolveTruncated(p) {
    global SaveDlg_Cache, SaveDlg_CacheFile, SaveDlg_LastInfo
    if !InStr(p, " ... ")
        return p
    if (SaveDlg_Cache.HasKey(p) && FileExist(SaveDlg_Cache[p]))
        return SaveDlg_Cache[p]
    if (SaveDlg_CacheFile != "") {
        IniRead, cached, %SaveDlg_CacheFile%, cache, %p%, %A_Space%
        if (cached != "" && FileExist(cached)) {
            SaveDlg_Cache[p] := cached
            return cached
        }
    }
    cut    := InStr(p, " ... ")
    prefix := SubStr(p, 1, cut - 1)
    suffix := SubStr(p, cut + 5)
    t0 := A_TickCount
    full := SaveDlg_WalkResolve(prefix, suffix)
    SaveDlg_LastInfo := "Title path: " . p . "`nFile-system search took " . (A_TickCount - t0) . " ms: " . (full != "" ? full : "(not found)")
    if (full != "") {
        SaveDlg_Cache[p] := full
        if (SaveDlg_CacheFile != "")
            IniWrite, %full%, %SaveDlg_CacheFile%, cache, %p%
    }
    return full
}

; Breadth-first search from the visible start of the path.
;   prefix "D:\Studio Dropbox\Cl"  ->  start in D:\Studio Dropbox, folders "Cl*"
;   suffix "26\01_Projects\...\Foo.aep" -> a folder whose name ends in "26" that contains the rest
SaveDlg_WalkResolve(prefix, suffix) {
    global SaveDlg_WalkMaxDepth
    pBS := InStr(prefix, "\", false, 0)
    if (!pBS)
        return ""
    pDir  := SubStr(prefix, 1, pBS - 1)
    pPart := SubStr(prefix, pBS + 1)
    sBS := InStr(suffix, "\")
    if (!sBS)
        return ""
    sPart := SubStr(suffix, 1, sBS - 1)
    sRest := SubStr(suffix, sBS + 1)
    if (pDir = "" || !InStr(FileExist(pDir . "\"), "D"))
        return ""
    queue := []
    Loop, Files, %pDir%\%pPart%*, D
        queue.Push({path: A_LoopFileLongPath, depth: 1})
    while (queue.Length()) {
        item := queue.RemoveAt(1)
        d := item.path
        SplitPath, d, name
        if (sPart = "" || (StrLen(name) >= StrLen(sPart) && SubStr(name, 1 - StrLen(sPart)) = sPart))
            if FileExist(d . "\" . sRest)
                return d . "\" . sRest
        if (item.depth >= SaveDlg_WalkMaxDepth)
            continue
        Loop, Files, %d%\*, D
        {
            if (SubStr(A_LoopFileName, 1, 1) = ".")
                continue
            queue.Push({path: A_LoopFileLongPath, depth: item.depth + 1})
        }
    }
    return ""
}

; Human-readable summary for a status window
SaveDlg_Status() {
    global SaveDlg_Enabled, SaveDlg_SubFolder, SaveDlg_LastInfo, SaveDlg_LastTarget, SaveDlg_AllApps
    ae := SaveDlg_AEProject()
    pp := SaveDlg_PremiereProject()
    my := SaveDlg_MayaProject()
    s := "After Effects project:`n   " . (ae != "" ? ae : "(none open / not running)")
    s .= "`n`nPremiere Pro project:`n   " . (pp != "" ? pp : "(none open / not running)")
    s .= "`n`nMaya scene:`n   " . (my != "" ? my : "(none open / not running)")
    root := SaveDlg_RootFromProject(ae != "" ? ae : pp)
    target := root != "" ? SaveDlg_TargetFor(root) : ""
    s .= "`n`n" . (SaveDlg_AllApps ? "Adobe + all other apps'" : "Adobe") . " save dialogs will open at:`n   " . (target != "" ? target : "(unknown - no project detected)")
    if (my != "") {
        mroot := SaveDlg_RootFromProject(my)
        s .= "`n`nMaya save dialogs will open at:`n   " . (mroot != "" ? SaveDlg_TargetFor(mroot) : "(unknown)")
    }
    s .= "`n`nSubfolder setting: " . (SaveDlg_SubFolder != "" ? SaveDlg_SubFolder : "(none - project root)")
    s .= "`nRedirect: " . (SaveDlg_Enabled ? "enabled" : "disabled")
    if (SaveDlg_LastInfo != "")
        s .= "`n`nLast lookup:`n" . SaveDlg_LastInfo
    if (SaveDlg_LastTarget != "")
        s .= "`n`nLast dialog sent to:`n   " . SaveDlg_LastTarget
    return s
}

SaveDlg_Tip(msg) {
    ToolTip, %msg%
    SetTimer, SaveDlg_ClearTip, -1500
}
SaveDlg_ClearTip() {
    ToolTip
}
