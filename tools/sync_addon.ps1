<#
.SYNOPSIS
Copies addon/Amisia into the WoW AddOns folders, so a change in the repository is in the game.

.DESCRIPTION
The addon is written once in this repository and runs in the Forever beta. This mirrors the
source folder into its AddOns folder: files that changed are copied, files that no longer exist in
the repository are deleted, and a target whose AddOns folder is missing is skipped with a note
instead of an error.

A running WoW reads the files only while it loads, so a copy made during play takes effect at the
next /reload or login.

.PARAMETER Watch
Keep running and copy again whenever something in the source folder changes (checked every second).
Stop it with Ctrl+C.

.PARAMETER Quiet
Print nothing when there was nothing to copy. The Claude Code hook uses this.

.PARAMETER NoCheck
Copy even when the Lua files do not parse. Without it a syntax error stops the copy, because one
broken file keeps the whole addon from loading in the game.

.EXAMPLE
pwsh -File tools/sync_addon.ps1
pwsh -File tools/sync_addon.ps1 -Watch
#>
[CmdletBinding()]
param(
    [switch]$Watch,
    [switch]$Quiet,
    [switch]$NoCheck
)

$ErrorActionPreference = 'Stop'

$Source = Join-Path (Split-Path -Parent $PSScriptRoot) 'addon\Amisia'
$WowRoot = if ($env:AMISIA_WOW_ROOT) { $env:AMISIA_WOW_ROOT } else { 'C:\Program Files (x86)\World of Warcraft' }
$Flavors = @('_classic_beta_')

# One syntax error keeps the whole addon from loading, and the error is then only visible in the
# client's log. So the files are parsed before they leave the repository. Node or the parser being
# absent must not block the copy, which is what exit code 2 from the checker means.
function Test-Lua {
    if ($NoCheck) { return $true }
    $node = Get-Command node -ErrorAction SilentlyContinue
    $checker = Join-Path (Split-Path -Parent $PSScriptRoot) 'addon\tests\syntax.cjs'
    if (-not $node -or -not (Test-Path -LiteralPath $checker -PathType Leaf)) { return $true }
    $out = & $node.Source $checker 2>$null
    if ($LASTEXITCODE -ne 1) { return $true }
    Write-Host 'Nicht kopiert, Lua-Syntaxfehler:' -ForegroundColor Red
    foreach ($line in $out) { if ($line -like 'FAIL*') { Write-Host "  $line" -ForegroundColor Red } }
    return $false
}

function Get-Targets {
    foreach ($flavor in $Flavors) {
        $addons = Join-Path $WowRoot "$flavor\Interface\AddOns"
        $target = Join-Path $addons 'Amisia'
        $item = Get-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue
        if ($item -and $item.LinkType) {
            # Since 2026-10-04 the AddOns folder is a junction on the Syncthing copy the N100 sends;
            # writing into it would fight that sync, so this machine leaves it alone.
            if (-not $Quiet) { Write-Host "uebersprungen: $flavor ist mit $($item.Target) verknuepft (Syncthing vom N100)" -ForegroundColor DarkGray }
        } elseif (Test-Path -LiteralPath $addons -PathType Container) {
            [pscustomobject]@{ Flavor = $flavor; Path = $target }
        } elseif (-not $Quiet) {
            Write-Host "uebersprungen: $flavor hat keinen AddOns-Ordner" -ForegroundColor DarkGray
        }
    }
}

# Relative path -> file, for source and target alike. -SkipHidden leaves out every file under a
# folder or with a name starting with a dot (editor and Claude Code settings): the source lists
# them so, and the mirror then deletes what an older copy put into the AddOns folder.
function Get-Files($root, [switch]$SkipHidden) {
    $map = @{}
    if (Test-Path -LiteralPath $root -PathType Container) {
        $prefix = (Resolve-Path -LiteralPath $root).Path.TrimEnd('\') + '\'
        foreach ($f in Get-ChildItem -LiteralPath $root -Recurse -File -Force) {
            $rel = $f.FullName.Substring($prefix.Length)
            if ($SkipHidden -and ($rel -split '\\' | Where-Object { $_.StartsWith('.') })) { continue }
            $map[$rel] = $f
        }
    }
    return $map
}

# Folders the mirror emptied, deepest first.
function Remove-EmptyDirs($root) {
    if (-not (Test-Path -LiteralPath $root -PathType Container)) { return }
    Get-ChildItem -LiteralPath $root -Recurse -Directory -Force |
        Sort-Object { $_.FullName.Length } -Descending |
        Where-Object { -not (Get-ChildItem -LiteralPath $_.FullName -Force) } |
        ForEach-Object { Remove-Item -LiteralPath $_.FullName -Force }
}

function Sync-Once {
    $src = Get-Files $Source -SkipHidden
    if ($src.Count -eq 0) { throw "Keine Dateien in $Source" }
    $total = 0
    foreach ($target in Get-Targets) {
        $dst = Get-Files $target.Path
        $copied, $removed = 0, 0
        foreach ($rel in $src.Keys) {
            $have = $dst[$rel]
            # Same size and mtime means the file is already there; the clock resolution is enough here.
            if ($have -and $have.Length -eq $src[$rel].Length -and $have.LastWriteTimeUtc -eq $src[$rel].LastWriteTimeUtc) { continue }
            $to = Join-Path $target.Path $rel
            $dir = Split-Path -Parent $to
            if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
            Copy-Item -LiteralPath $src[$rel].FullName -Destination $to -Force
            $copied++
        }
        foreach ($rel in $dst.Keys) {
            if (-not $src.ContainsKey($rel)) {
                Remove-Item -LiteralPath $dst[$rel].FullName -Force
                $removed++
            }
        }
        Remove-EmptyDirs $target.Path
        $total += $copied + $removed
        if (($copied -or $removed) -and -not $Quiet) {
            Write-Host ("{0}: {1} kopiert, {2} geloescht" -f $target.Flavor, $copied, $removed) -ForegroundColor Green
        }
    }
    return $total
}

if (-not $Watch) {
    if (-not (Test-Lua)) { exit 1 }
    $n = Sync-Once
    if (-not $Quiet) {
        if ($n -eq 0) { Write-Host 'Nichts zu tun, der Ordner ist aktuell.' -ForegroundColor DarkGray }
        else { Write-Host 'Fertig. Im Spiel wirkt es nach /reload.' }
    }
    exit 0
}

Write-Host "Beobachte $Source. Ctrl+C beendet." -ForegroundColor Cyan
if (Test-Lua) { Sync-Once | Out-Null }
# Polling instead of a FileSystemWatcher: a handful of files, and an editor that writes through a
# temporary file fires events the watcher reports for names that are already gone again.
$last = ''
while ($true) {
    Start-Sleep -Seconds 1
    $src = Get-Files $Source -SkipHidden
    $stamp = ($src.Keys | Sort-Object | ForEach-Object { "$_|$($src[$_].Length)|$($src[$_].LastWriteTimeUtc.Ticks)" }) -join ';'
    if ($stamp -eq $last) { continue }
    $last = $stamp
    if (-not (Test-Lua)) { continue }
    try {
        $n = Sync-Once
        if ($n) { Write-Host ("  {0}  {1} Dateien" -f (Get-Date -Format 'HH:mm:ss'), $n) -ForegroundColor DarkGray }
    } catch {
        # A file being written right now is locked; the next round picks it up.
        Write-Host "  noch nicht lesbar, naechster Versuch" -ForegroundColor DarkYellow
    }
}
