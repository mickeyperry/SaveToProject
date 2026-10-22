# Builds dist\SaveToProject.exe with Ahk2Exe (AutoHotkey v1 compiler).
# Compiler: C:\Program Files\AutoHotkey\Compiler  (Ahk2Exe.exe + "Unicode 64-bit.bin",
# both ship inside the AutoHotkey_1.1.x.zip from autohotkey.com if your install lacks them).
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$compiler = "C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe"
$base     = "C:\Program Files\AutoHotkey\Compiler\Unicode 64-bit.bin"
if (-not (Test-Path $compiler)) { throw "Ahk2Exe not found at $compiler" }
if (-not (Test-Path $base))     { throw "Base file not found at $base" }
New-Item -ItemType Directory -Force "$root\dist" | Out-Null
$out = "$root\dist\SaveToProject.exe"
if (Test-Path $out) { Remove-Item $out -Force }
# Ahk2Exe returns before it finishes writing, so wait on the process.
$p = Start-Process -FilePath $compiler -Wait -PassThru -NoNewWindow -ArgumentList @(
    '/in', "`"$root\src\SaveToProject.ahk`"", '/out', "`"$out`"",
    '/icon', "`"$root\assets\icon.ico`"", '/base', "`"$base`"", '/silent', 'verbose')
if (-not (Test-Path $out)) { throw "compile failed - no output (exit $($p.ExitCode))" }
Copy-Item "$root\README.md" "$root\dist\README.md" -Force
"built $out  ($((Get-Item $out).Length) bytes)"
