<#
.SYNOPSIS
Points the WoW AddOns folders at Amisia's release folders: one junction per folder (F-202, D-130; F-228, D-158).

.DESCRIPTION
Run once on the PC, in a PowerShell opened as administrator, after a release with a new set of folders
has reached the PC (Syncthing folder "amisia": %USERPROFILE%\VuloSync\Amisia with one subfolder per
addon, $Folders below). The script

1. checks that the subfolders are there (each with its TOC); otherwise it changes nothing;
2. in every client folder of WoW (_forever_, _anniversary_, _classic_era_) under Interface\AddOns:
   - removes the old junction Amisia that pointed at the whole release folder, any junction of
     $Folders that points elsewhere or does not belong to that client, and the junctions of the
     folders that are gone ($OldFolders: Amisia_Raid, the core's since F-228);
   - makes the junction Amisia (all three clients) and those of the modules (WoW Forever only:
     they load nowhere else).

It only ever removes junctions, never a real folder: a real folder of these names (an install by hand,
say) stays as it is and the script says so. Running it again changes nothing ("ok").
A client folder that is not installed is skipped. Plain ASCII on purpose: Windows PowerShell 5.1 reads a
script without byte order mark in the ANSI code page.

After it: start WoW anew (a full client restart, not /reload); the AddOn list shows Amisia and, on WoW
Forever, its modules.

.PARAMETER Release
The release folder on the PC. Default %USERPROFILE%\VuloSync\Amisia.

.PARAMETER WowDir
The WoW folder. Default $env:AMISIA_WOW_ROOT, else C:\Program Files (x86)\World of Warcraft.

.PARAMETER DryRun
Only print what would happen.

.EXAMPLE
powershell -ExecutionPolicy Bypass -File \\path\to\install_junctions.ps1
#>
[CmdletBinding()]
param(
    [string]$Release = (Join-Path $env:USERPROFILE 'VuloSync\Amisia'),
    [string]$WowDir = $(if ($env:AMISIA_WOW_ROOT) { $env:AMISIA_WOW_ROOT } else { 'C:\Program Files (x86)\World of Warcraft' }),
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'

# The addon folders, and which client gets which (the modules are WoW Forever's only, D-57, D-130, D-158).
$Folders = @('Amisia', 'Amisia_Gear', 'Amisia_Dungeons', 'Amisia_Talents')
$Clients = [ordered]@{
    '_forever_'     = @('Amisia', 'Amisia_Gear', 'Amisia_Dungeons', 'Amisia_Talents')
    '_anniversary_' = @('Amisia')
    '_classic_era_' = @('Amisia')
}
# Folders of earlier releases that are gone: their junctions go (F-228: the raid part is the core's).
$OldFolders = @('Amisia_Raid')

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    return ([Security.Principal.WindowsPrincipal]$id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# The item at path when it is a junction (or another link to a folder), else $null.
function Get-Junction([string]$Path) {
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if ($item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { return $item }
    return $null
}

# Where a junction points (PowerShell 5.1 gives a list), without a trailing backslash.
function Get-LinkTarget($Item) {
    $t = @($Item.Target) | Select-Object -First 1
    if (-not $t) { return '' }
    $t = [string]$t
    if ($t.StartsWith('\??\')) { $t = $t.Substring(4) }
    return $t.TrimEnd('\')
}

# Removes the junction only (rmdir without /s never touches what it points at).
function Remove-Junction([string]$Path) {
    if ($DryRun) { return }
    cmd /c rmdir "$Path" | Out-Null
    if ($LASTEXITCODE -ne 0 -or (Test-Path -LiteralPath $Path)) { throw "Konnte die Verknuepfung $Path nicht entfernen." }
}

function New-Junction([string]$Path, [string]$Target) {
    if ($DryRun) { return }
    New-Item -ItemType Junction -Path $Path -Target $Target | Out-Null
}

if (-not $DryRun -and -not (Test-Admin)) {
    Write-Host 'Bitte PowerShell als Administrator oeffnen (Rechtsklick, "Als Administrator ausfuehren") und noch einmal starten.' -ForegroundColor Yellow
    exit 1
}

# 1. the release folders, each with its TOC
$Release = $Release.TrimEnd('\')
$missing = @()
foreach ($f in $Folders) {
    if (-not (Test-Path -LiteralPath (Join-Path (Join-Path $Release $f) "$f.toc"))) { $missing += $f }
}
if ($missing.Count -gt 0) {
    Write-Host "In $Release fehlen: $($missing -join ', ')." -ForegroundColor Yellow
    Write-Host 'Erst den Release mit diesen Ordnern abwarten (Syncthing), dann noch einmal starten. Nichts geaendert.' -ForegroundColor Yellow
    exit 1
}
Write-Host "Release-Ordner: $Release"
if ($DryRun) { Write-Host 'Probelauf: nichts wird geaendert.' -ForegroundColor Cyan }

# 2. every client folder
$made, $removed, $kept, $skipped = 0, 0, 0, 0
foreach ($client in $Clients.Keys) {
    $addons = Join-Path $WowDir "$client\Interface\AddOns"
    if (-not (Test-Path -LiteralPath $addons)) {
        Write-Host "$client`: nicht installiert ($addons), uebersprungen."
        continue
    }
    Write-Host "$client`:"
    $wanted = $Clients[$client]
    foreach ($f in $OldFolders) {
        $link = Join-Path $addons $f
        $j = Get-Junction $link
        if ($j) {
            $points = Get-LinkTarget $j
            Remove-Junction $link
            Write-Host "  $f`: Verknuepfung entfernt, der Ordner gehoert nicht mehr zu Amisia (zeigte auf $points)"
            $removed++
        } elseif (Test-Path -LiteralPath $link) {
            Write-Host "  $f`: echter Ordner, bleibt unberuehrt. Er gehoert nicht mehr zu Amisia: bitte selbst loeschen." -ForegroundColor Yellow
            $skipped++
        }
    }
    foreach ($f in $Folders) {
        $link = Join-Path $addons $f
        $target = Join-Path $Release $f
        $want = $wanted -contains $f
        if (Test-Path -LiteralPath $link) {
            $j = Get-Junction $link
            if (-not $j) {
                Write-Host "  $f`: echter Ordner, bleibt unberuehrt. Bitte selbst pruefen (alte Kopie?)." -ForegroundColor Yellow
                $skipped++
                continue
            }
            $points = Get-LinkTarget $j
            if ($want -and $points -ieq $target) {
                Write-Host "  $f`: ok ($target)"
                $kept++
                continue
            }
            Remove-Junction $link
            Write-Host "  $f`: alte Verknuepfung entfernt (zeigte auf $points)"
            $removed++
        } elseif (Get-Junction $link) {
            # a junction whose target is gone (Test-Path follows it)
            $points = Get-LinkTarget (Get-Junction $link)
            Remove-Junction $link
            Write-Host "  $f`: tote Verknuepfung entfernt (zeigte auf $points)"
            $removed++
        }
        if ($want) {
            New-Junction $link $target
            Write-Host "  $f`: Verknuepfung angelegt -> $target" -ForegroundColor Green
            $made++
        }
    }
}

Write-Host ''
Write-Host "Fertig: $made angelegt, $removed entfernt, $kept schon richtig, $skipped echte Ordner nicht angefasst."
Write-Host 'Jetzt WoW ganz neu starten (nicht nur /reload).'
