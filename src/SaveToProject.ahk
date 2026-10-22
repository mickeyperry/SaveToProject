; ============================================================================
;  Save To Project  -  tray app  (AutoHotkey v1, compiles with Ahk2Exe)
;
;  Makes After Effects / Media Encoder / Premiere Pro "Save As" dialogs open
;  in the folder of the project that is currently open.  See README.md.
; ============================================================================
#NoEnv
#SingleInstance Force
#Persistent
SetBatchLines, -1
SetTitleMatchMode, 2
#Include %A_ScriptDir%\savedlg_core.ahk

global APP := "Save To Project"
global VER := "1.1.0"
global cfgDir  := A_AppData . "\SaveToProject"
global cfgFile := cfgDir . "\settings.ini"
global lnkFile := A_Startup . "\Save To Project.lnk"
FileCreateDir, %cfgDir%

SaveDlg_Init()
IniRead, v, %cfgFile%, settings, enabled, 1
SaveDlg_Enabled := (v = 1)
IniRead, v, %cfgFile%, settings, subfolder, %A_Space%
SaveDlg_SubFolder := Trim(v, " \")
IniRead, v, %cfgFile%, settings, allapps, 1
SaveDlg_AllApps := (v = 1)
IniRead, v, %cfgFile%, settings, rootmarker, 01_Projects
if ((v := Trim(v, " \")) != "")
    SaveDlg_RootMarker := v
IniRead, v, %cfgFile%, settings, exclude, %A_Space%     ; e.g. exclude=chrome.exe,Code.exe
Loop, Parse, v, `,
    if ((x := Trim(A_LoopField)) != "")
        SaveDlg_Exclude.Push(x)
SaveDlg_CacheFile := cfgFile

Menu, Tray, NoStandard
Menu, Tray, Add, %APP% v%VER%, About
Menu, Tray, Add
Menu, Tray, Add, Enabled, ToggleEnabled
Menu, Tray, Add, All apps follow After Effects, ToggleAllApps
Menu, Tray, Add, Subfolder under project..., SetSubfolder
Menu, Tray, Add, Start with Windows, ToggleStartup
Menu, Tray, Add
Menu, Tray, Add, Show current project, ShowStatus
Menu, Tray, Add, Open settings folder, OpenCfg
Menu, Tray, Add, Exit, Quit
Menu, Tray, Default, Show current project
Menu, Tray, Tip, %APP%
if (!A_IsCompiled) {
    icoPath := A_ScriptDir . "\..\assets\icon.ico"
    if FileExist(icoPath)
        Menu, Tray, Icon, %icoPath%
}
UpdateMenu()

IniRead, startup, %cfgFile%, settings, startup, __none__
if (startup = "__none__") {                     ; first run
    MsgBox, 0x24, %APP%, %APP% is now running in the system tray.`n`nSave / Export dialogs from After Effects, Media Encoder and Premiere Pro will open in the current project's folder.`n`nStart it automatically with Windows?
    IfMsgBox, Yes
        SetStartup(true)
    else
        SetStartup(false)
} else if (startup = 1 && !FileExist(lnkFile)) {
    SetStartup(true)                            ; exe was moved - refresh the shortcut
}
TrayTip, %APP%, Running. Right-click the tray icon for options., 3, 1
return

; ---------------------------------------------------------------------------
ToggleEnabled:
    SaveDlg_Enabled := !SaveDlg_Enabled
    IniWrite, % SaveDlg_Enabled ? 1 : 0, %cfgFile%, settings, enabled
    UpdateMenu()
return

ToggleAllApps:
    SaveDlg_AllApps := !SaveDlg_AllApps
    IniWrite, % SaveDlg_AllApps ? 1 : 0, %cfgFile%, settings, allapps
    UpdateMenu()
return

SetSubfolder:
    InputBox, sub, %APP% - subfolder, Open save dialogs in this subfolder of the project root`n(for example  09_Output ).`nLeave empty for the project root itself.`nIf a project has no such subfolder the root is used.,, 420, 220,,,,, %SaveDlg_SubFolder%
    if (ErrorLevel)
        return
    SaveDlg_SubFolder := Trim(sub, " \")
    IniWrite, %SaveDlg_SubFolder%, %cfgFile%, settings, subfolder
    UpdateMenu()
return

ToggleStartup:
    SetStartup(!FileExist(lnkFile))
return

ShowStatus:
    MsgBox, 0x40, %APP% - status, % SaveDlg_Status()
return

OpenCfg:
    Run, explorer.exe "%cfgDir%"
return

About:
    MsgBox, 0x40, %APP% v%VER%, %APP% v%VER%`n`nWhen After Effects, Media Encoder, Premiere Pro or Maya opens a Save / Export / Output dialog, it is pointed at the root of the project that is open in that app: the folder that holds "%SaveDlg_RootMarker%".`n`nWith "All apps follow After Effects" on, Save / Export dialogs of every other program (Photoshop, browsers, Notepad ...) go to the After Effects project's root too (Premiere's if AE has nothing open).`n`nDialogs that already sit inside the project (e.g. File > Save As next to the .aep) are left alone. Open / Import dialogs are never touched.`n`nMaya: set Preferences > Files/Projects > File Dialog to "OS native".`n`nSettings: %cfgFile%
return

Quit:
    ExitApp
return

; ---------------------------------------------------------------------------
UpdateMenu() {
    global
    static subLabel := "Subfolder under project..."
    Menu, Tray, % SaveDlg_Enabled ? "Check" : "UnCheck", Enabled
    Menu, Tray, % SaveDlg_AllApps ? "Check" : "UnCheck", All apps follow After Effects
    Menu, Tray, % FileExist(lnkFile) ? "Check" : "UnCheck", Start with Windows
    newLabel := "Subfolder under project... (" . (SaveDlg_SubFolder != "" ? SaveDlg_SubFolder : "root") . ")"
    Menu, Tray, Rename, %subLabel%, %newLabel%
    subLabel := newLabel
    Menu, Tray, Tip, % APP . (SaveDlg_Enabled ? "" : " (disabled)")
}

SetStartup(on) {
    global cfgFile, lnkFile
    if (on) {
        if (A_IsCompiled)
            FileCreateShortcut, %A_ScriptFullPath%, %lnkFile%, %A_ScriptDir%
        else
            FileCreateShortcut, %A_AhkPath%, %lnkFile%, %A_ScriptDir%, "%A_ScriptFullPath%"
    } else {
        FileDelete, %lnkFile%
    }
    IniWrite, % on ? 1 : 0, %cfgFile%, settings, startup
    UpdateMenu()
}
