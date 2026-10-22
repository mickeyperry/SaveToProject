# Save To Project

A tiny Windows tray app for After Effects, Media Encoder, Premiere Pro and Maya users.
Nothing else to install.

**Download:** grab `SaveToProject.exe` from the [latest release](../../releases/latest).

Whenever one of those apps opens a **Save As / Output Movie To / Export** dialog, the dialog
jumps to the folder of the project that is currently open, instead of wherever Windows last
saved something.

```
Project open in After Effects:
  D:\Studio Dropbox\Clients\Acme\JOB1234_Promo_Oct26\01_Projects\01 - AE\02 - Compositing\Hero\Hero_V07.aep

Save dialog opens at:
  D:\Studio Dropbox\Clients\Acme\JOB1234_Promo_Oct26
```

## Install

1. Copy `SaveToProject.exe` anywhere (e.g. `C:\Tools\SaveToProject\`). Keep it there; don't run it from Downloads.
2. Double-click it. A folder icon appears in the system tray.
3. Answer **Yes** to "Start with Windows" so it is always running.

If Windows SmartScreen shows "Windows protected your PC", click **More info → Run anyway**.
The exe is an unsigned AutoHotkey build; some antivirus tools flag those. The full source is in `src\`.

## How it decides where to go

- The **project root** is the folder that contains `01_Projects`. A project saved outside that
  structure uses the scene / project file's own folder. Your studio uses a different name?
  Set `rootmarker=` in `settings.ini` (e.g. `rootmarker=Projects`) and restart the app.
- A dialog that is **already inside the project** is left alone, so *File → Save As* still opens
  next to your current `.aep` for V07 → V08 saving.
- **Media Encoder** has no project of its own, so it follows After Effects, then Premiere Pro.
- **Every other app** (Photoshop, Illustrator, Chrome, Notepad, ...) does the same when
  *All apps follow After Effects* is on (the default): as long as AE has a project open, their
  Save / Export dialogs open at that project's root. With no AE project it uses Premiere's; with
  neither, dialogs are left alone. To keep an app out, add it to `settings.ini`:
  `exclude=chrome.exe,Code.exe` under `[settings]`, then restart the app.
- **Open / Import** dialogs are never touched. Only dialogs whose title starts with
  Save, Export, Output or Render, or whose main button says **Save** (e.g. Firefox's
  "Enter name of file to save to...").
- After Effects shortens the path in its title bar (`D:\Studio Dropbox\Cl ... 26\01_Projects\...`).
  The app recovers the full path with a quick search of the drive from the visible start of the
  path (about 30 ms) and remembers it, so later dialogs are instant.

## Maya

Maya's own file browser cannot be steered, so switch Maya to the Windows dialog once:
**Windows → Settings/Preferences → Preferences → Files/Projects → File Dialog: OS native**.
After that, Save Scene As / Export dialogs open at the project root (the folder holding
`01_Projects` above the scene; otherwise the scene's own folder).

## Houdini

Not supported. Houdini on Windows has no option to use the Windows file dialog, and its own
file chooser cannot be redirected from outside. If you want the same behaviour in Houdini, the
Houdini way is a `456.py` startup script that sets `$JOB` to the project root when a `.hip` loads.

## Tray menu

| Item | What it does |
|---|---|
| Enabled | Pause / resume the redirect |
| All apps follow After Effects | Also redirect Save / Export dialogs of every other program to the AE project root |
| Subfolder under project... | Land in a subfolder of the root, e.g. `09_Output`. Empty = root. If a project lacks that subfolder the root is used. |
| Start with Windows | Adds / removes a shortcut in your Startup folder |
| Show current project | Shows the detected projects, the folder dialogs will open at, and how the last lookup was resolved. Use this first when something looks wrong. |
| Open settings folder | `%APPDATA%\SaveToProject\settings.ini` |

## Requirements

Windows 10 / 11. Any recent After Effects, Media Encoder, Premiere Pro or Maya.

## Build from source

Needs AutoHotkey v1.1 with its `Compiler` folder (`Ahk2Exe.exe` + `Unicode 64-bit.bin`), then:

```powershell
.\build.ps1
```

`src\savedlg_core.ahk` is the logic; `src\SaveToProject.ahk` is the tray shell. The core can also be
`#Include`d into an existing AutoHotkey script: call `SaveDlg_Init()` once.
