<#
.SYNOPSIS
Sets up the Windows task that exports the WoW Forever client tables by itself after every client patch.

.DESCRIPTION
Run once on the PC, in a PowerShell opened as administrator. The script

1. writes %USERPROFILE%\Tools\amisia\run_export.ps1, which fetches the newest tools/export_db2.ps1 from
   the Amisia repository on GitHub (keeps the last copy when offline) and runs it, with a short log
   in export.log next to it;
2. registers the task "Amisia Client-Tabellen": two minutes after logging on and then every two hours,
   in the background without a window (also while WoW runs: export_db2.ps1 then stops at once and
   the next run tries again).

export_db2.ps1 stops at once when every table of the installed build is already exported, so a run
without a patch takes a second. After a patch Syncthing brings the tables to ~/addons/_wago, and the
N100 builds and checks the data by itself (tools/auto_data.py); the release stays the user's call.

.PARAMETER EveryHours
Hours between two runs. Default 2.

.PARAMETER Remove
Remove the task again (the folder Tools\amisia stays).

.EXAMPLE
iwr https://raw.githubusercontent.com/amisia-loot/amisia-loot.github.io/main/tools/install_export_task.ps1 -OutFile $env:TEMP\install_export_task.ps1; powershell -ExecutionPolicy Bypass -File $env:TEMP\install_export_task.ps1
#>
[CmdletBinding()]
param(
    [int]$EveryHours = 2,
    [switch]$Remove
)
$ErrorActionPreference = 'Stop'
$TaskName = 'Amisia Client-Tabellen'
$Dir = Join-Path $env:USERPROFILE 'Tools\amisia'
$User = "$env:USERDOMAIN\$env:USERNAME"

if ($Remove) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "Aufgabe '$TaskName' entfernt."
    exit 0
}

$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) {
    Write-Host 'Bitte PowerShell als Administrator öffnen (Rechtsklick, "Als Administrator ausführen") und noch einmal starten.' -ForegroundColor Yellow
    exit 1
}

New-Item -ItemType Directory -Force -Path $Dir | Out-Null
$Runner = Join-Path $Dir 'run_export.ps1'
@'
# Written by tools/install_export_task.ps1 (Amisia). Run by the task "Amisia Client-Tabellen".
$Dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$Log = Join-Path $Dir 'export.log'
$Script = Join-Path $Dir 'export_db2.ps1'
$Url = 'https://raw.githubusercontent.com/amisia-loot/amisia-loot.github.io/main/tools/export_db2.ps1'
function Log([string]$Text) { Add-Content -Path $Log -Value ('{0:yyyy-MM-dd HH:mm} {1}' -f (Get-Date), $Text) -Encoding UTF8 }
if ((Test-Path $Log) -and (Get-Item $Log).Length -gt 512KB) { Move-Item $Log "$Log.old" -Force }
try {
    Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile "$Script.new" -TimeoutSec 60
    Move-Item "$Script.new" $Script -Force
} catch {
    Log ('Download fehlgeschlagen, nehme die letzte Kopie: ' + $_.Exception.Message)
}
if (-not (Test-Path $Script)) { Log 'Kein export_db2.ps1 vorhanden.'; exit 1 }
$out = & powershell -NoProfile -ExecutionPolicy Bypass -File $Script *>&1 | Out-String
$rc = $LASTEXITCODE
$tail = ($out -split "`r?`n" | Where-Object { $_ -match '\S' } | Select-Object -Last 2) -join ' | '
Log ("Ende {0}: {1}" -f $rc, $tail)
exit $rc
'@ | Set-Content -Path $Runner -Encoding UTF8

$action = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument "-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$Runner`""
$logon = New-ScheduledTaskTrigger -AtLogOn -User $User
$logon.Delay = 'PT2M'
$repeat = New-ScheduledTaskTrigger -Once -At (Get-Date).Date.AddHours((Get-Date).Hour + 1) `
    -RepetitionInterval (New-TimeSpan -Hours $EveryHours) -RepetitionDuration (New-TimeSpan -Days 3650)
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 45) -MultipleInstances IgnoreNew
# S4U: runs in the background (no window over the game), with the user's profile, no stored password
$principal = New-ScheduledTaskPrincipal -UserId $User -LogonType S4U -RunLevel Limited
Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger @($logon, $repeat) -Settings $settings `
    -Principal $principal -Force `
    -Description 'Amisia: exportiert nach einem WoW-Patch die Client-Tabellen nach VuloSync\wago (tools/export_db2.ps1).' | Out-Null

Write-Host "Aufgabe '$TaskName' eingerichtet: 2 Minuten nach der Anmeldung und alle $EveryHours Stunden." -ForegroundColor Green
Write-Host "Protokoll: $Dir\export.log"
Start-ScheduledTask -TaskName $TaskName
Write-Host 'Der erste Lauf ist gestartet (ohne Patch ist er in Sekunden fertig).'
