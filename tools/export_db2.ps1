<#
.SYNOPSIS
Exports the WoW Forever client tables (DB2) Amisia's build scripts read as CSV files, straight from
the local WoW install, through wow.tools.local.

.DESCRIPTION
Replaces the hand downloads from wago.tools. The script

1. reads the installed Forever build from <WoW>\.build.info (product from
   <WoW>\_classic_beta_\.flavor.info, normally wow_classic_beta);
2. stops early when every table of that build already lies in the output folder (idempotent);
3. starts wow.tools.local (WTL) in the background with the WoW folder and product, waits until it has
   loaded the build, and pins the installed build when WTL picked a different one from the patch server;
4. downloads each table from WTL's CSV export (http://localhost:<port>/dbc/export/), renames array
   columns from Name[0] to Name_0 like wago.tools does, and writes <Table>.<build>.csv into the output
   folder (written to a temporary file first, then moved, so Syncthing never sends half a file);
5. stops WTL again (unless it was already running) and prints a summary.

A WTL that already answers on the port is used as it is and left running.

The result per table goes to _export.<build>.txt in the output folder; a table the build has empty
or lacks is not asked for again until -Force.

Exit codes: 0 everything exported (or already there), 1 setup error (nothing exported),
2 at least one required table failed with an error. Empty or absent tables only print a warning.

.PARAMETER WtlDir
Folder where Release-win-x64.zip of wow.tools.local was extracted (contains wow.tools.local.exe and
wwwroot). Default: $env:AMISIA_WTL_DIR, else %USERPROFILE%\Tools\wow.tools.local.

.PARAMETER WowDir
WoW install folder holding .build.info. Default: $env:AMISIA_WOW_ROOT, else
C:\Program Files (x86)\World of Warcraft.

.PARAMETER Flavor
Flavour folder of Forever inside WowDir. Default _classic_beta_.

.PARAMETER Product
TACT product. Default: second line of <WowDir>\<Flavor>\.flavor.info, else wow_classic_beta.

.PARAMETER OutDir
Output folder. Default %USERPROFILE%\VuloSync\wago (Syncthing sends it to ~/addons/_wago on the N100).

.PARAMETER Tables
Export only these tables (all count as required). Default: Amisia's list (see $RequiredTables and
$OptionalTables below).

.PARAMETER Locale
Locale of the string columns (*_lang). Default enUS, like wago.tools.

.PARAMETER Hotfixes
Apply the hotfixes of the client's DBCache.bin (log in once so the cache is current). Without it the
base data of the build is exported, as on wago.tools.

.PARAMETER Force
Export again even when <Table>.<build>.csv already exists.

.PARAMETER Port
Local port for WTL. Default 5077.

.PARAMETER StartTimeoutMin
Minutes to wait for WTL to load the build. Default 20 (the first start downloads the listfile).

.PARAMETER IgnoreRunningGame
Start even when a WoW process from WowDir is running (wow.tools.local 0.9.9 can fail on locked files).

.EXAMPLE
powershell -ExecutionPolicy Bypass -File tools\export_db2.ps1

.EXAMPLE
powershell -ExecutionPolicy Bypass -File tools\export_db2.ps1 -Tables ItemSparse,Item -Force
#>
[CmdletBinding()]
param(
    [string]$WtlDir,
    [string]$WowDir,
    [string]$Flavor = '_classic_beta_',
    [string]$Product,
    [string]$OutDir,
    [string[]]$Tables,
    [string]$Locale = 'enUS',
    [switch]$Hotfixes,
    [switch]$Force,
    [int]$Port = 5077,
    [int]$StartTimeoutMin = 20,
    [switch]$IgnoreRunningGame
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

# Tables the build scripts read (tools/build_bis.py, build_dungeons.py, build_gear.py, build_map.py).
$RequiredTables = @(
    'ItemSparse', 'Item', 'ItemSet', 'ItemSetSpell', 'ItemXItemEffect', 'ItemEffect',
    'SpellEffect', 'SpellName', 'Spell', 'SpellMisc', 'SpellItemEnchantment', 'RandPropPoints',
    'LFGDungeons', 'ContentTuning', 'UiMapAssignment', 'AreaTable', 'Map',
    'JournalInstance', 'JournalEncounter', 'JournalEncounterItem', 'DungeonEncounter'
)
# Exported when the build has them; a miss is only a warning.
$OptionalTables = @(
    'JournalEncounterCreature',
    'ItemDamageOneHand', 'ItemDamageOneHandCaster', 'ItemDamageTwoHand', 'ItemDamageTwoHandCaster',
    'ItemDamageAmmo', 'ItemArmorQuality', 'ItemArmorShield', 'ItemArmorTotal', 'ArmorLocation',
    'ItemRandomProperties', 'ItemRandomSuffix'
)

function Fail([string]$Message) {
    Write-Host "FEHLER: $Message" -ForegroundColor Red
    exit 1
}

# ------------------------------------------------------------------ defaults and checks
if (-not $WtlDir) { $WtlDir = if ($env:AMISIA_WTL_DIR) { $env:AMISIA_WTL_DIR } else { Join-Path $env:USERPROFILE 'Tools\wow.tools.local' } }
if (-not $WowDir) { $WowDir = if ($env:AMISIA_WOW_ROOT) { $env:AMISIA_WOW_ROOT } else { 'C:\Program Files (x86)\World of Warcraft' } }
if (-not $OutDir) { $OutDir = Join-Path $env:USERPROFILE 'VuloSync\wago' }

$BuildInfoPath = Join-Path $WowDir '.build.info'
if (-not (Test-Path -LiteralPath $BuildInfoPath -PathType Leaf)) {
    Fail "Keine .build.info in '$WowDir'. -WowDir muss der WoW-Hauptordner sein (der mit Data\ und .build.info, nicht $Flavor)."
}

if (-not $Product) {
    $flavorInfo = Join-Path (Join-Path $WowDir $Flavor) '.flavor.info'
    $Product = 'wow_classic_beta'
    if (Test-Path -LiteralPath $flavorInfo -PathType Leaf) {
        $lines = @(Get-Content -LiteralPath $flavorInfo)
        if ($lines.Count -ge 2 -and $lines[1].Trim()) { $Product = $lines[1].Trim() }
    } else {
        Write-Warning "Keine $Flavor\.flavor.info gefunden, nehme Produkt '$Product'."
    }
}

# .build.info: '|'-separated, first line 'Name!TYPE:size|...', one row per installed product.
$biLines = @(Get-Content -LiteralPath $BuildInfoPath | Where-Object { $_.Trim() })
if ($biLines.Count -lt 2) { Fail "'$BuildInfoPath' ist leer." }
$header = @($biLines[0].Split('|') | ForEach-Object { $_.Split('!')[0] })
function Col([string[]]$Row, [string]$Name) {
    $i = [array]::IndexOf($header, $Name)
    if ($i -lt 0 -or $i -ge $Row.Count) { return '' }
    return $Row[$i]
}
$rows = @($biLines | Select-Object -Skip 1 | ForEach-Object { , ($_.Split('|')) })
$mine = @($rows | Where-Object { (Col $_ 'Product') -eq $Product })
if ($mine.Count -eq 0) {
    $have = ($rows | ForEach-Object { Col $_ 'Product' }) -join ', '
    Fail "Produkt '$Product' ist nicht in .build.info (vorhanden: $have). Mit -Product das richtige angeben."
}
$active = @($mine | Where-Object { (Col $_ 'Active') -eq '1' })
$row = if ($active.Count -gt 0) { $active[0] } else { $mine[0] }
$Build = Col $row 'Version'
$BuildKey = Col $row 'Build Key'
$CdnKey = Col $row 'CDN Key'
if ($Build -notmatch '^\d+\.\d+\.\d+\.\d+$') { Fail "Unerwartete Version '$Build' fuer $Product in .build.info." }
Write-Host "Installiert: $Product $Build"

# 'pwsh -File' hands '-Tables A,B' over as one string: split it.
if ($Tables) { $Tables = @($Tables | ForEach-Object { $_ -split '[,;\s]+' } | Where-Object { $_ }) }
$required = if ($Tables) { @($Tables) } else { $RequiredTables }
$optional = if ($Tables) { @() } else { $OptionalTables }

if (-not (Test-Path -LiteralPath $OutDir -PathType Container)) {
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
}
function Target([string]$Table) { Join-Path $OutDir "$Table.$Build.csv" }
# _export.<build>.txt keeps the result per table, so a table the build has empty or lacks is not
# asked for again on the next run (and the N100 sees why a CSV is missing).
$StatusFile = Join-Path $OutDir "_export.$Build.txt"
$known = @{}
if (Test-Path -LiteralPath $StatusFile -PathType Leaf) {
    foreach ($l in Get-Content -LiteralPath $StatusFile) {
        $parts = $l.Split("`t")
        if ($parts.Count -ge 2) { $known[$parts[0]] = $parts[1] }
    }
}
function Done([string]$Table) {
    $p = Target $Table
    if ((Test-Path -LiteralPath $p -PathType Leaf) -and ((Get-Item -LiteralPath $p).Length -gt 0)) { return $true }
    return $known.ContainsKey($Table) -and ($known[$Table] -eq 'leer' -or $known[$Table] -eq 'nicht im Build')
}

$todo = @(@($required) + @($optional) | Where-Object { $Force -or -not (Done $_) })
if ($todo.Count -eq 0) {
    Write-Host "Alle Tabellen fuer $Build liegen schon in $OutDir (-Force exportiert neu)." -ForegroundColor Green
    exit 0
}

# ------------------------------------------------------------------ HTTP client
Add-Type -AssemblyName System.Net.Http
$BaseUrl = "http://localhost:$Port"
$http = New-Object System.Net.Http.HttpClient
$http.Timeout = [TimeSpan]::FromMinutes(30)

function Get-Text([string]$Path, [int]$TimeoutSec = 5) {
    # Returns the body of a 2xx answer, or $null when WTL does not answer (yet).
    $cts = New-Object System.Threading.CancellationTokenSource ([TimeSpan]::FromSeconds($TimeoutSec))
    try {
        $resp = $http.GetAsync($BaseUrl + $Path, $cts.Token).GetAwaiter().GetResult()
        if (-not $resp.IsSuccessStatusCode) { return $null }
        return $resp.Content.ReadAsStringAsync().GetAwaiter().GetResult()
    } catch {
        return $null
    } finally {
        $cts.Dispose()
    }
}

# ------------------------------------------------------------------ start wow.tools.local
$proc = $null
$logOut = Join-Path ([IO.Path]::GetTempPath()) 'amisia-wtl.out.log'
$logErr = Join-Path ([IO.Path]::GetTempPath()) 'amisia-wtl.err.log'

function Show-Log {
    foreach ($f in @($logOut, $logErr)) {
        if (Test-Path -LiteralPath $f) {
            Write-Host "--- letzte Zeilen von $f ---"
            Get-Content -LiteralPath $f -Tail 25 | ForEach-Object { Write-Host $_ }
        }
    }
}
function Stop-Wtl {
    if ($script:proc -and -not $script:proc.HasExited) {
        Write-Host 'Beende wow.tools.local.'
        Stop-Process -Id $script:proc.Id -Force -ErrorAction SilentlyContinue
    }
}

$exitCode = 0
try {
    if (Get-Text '/casc/getVersion') {
        Write-Host "wow.tools.local laeuft schon auf $BaseUrl, nutze es (bleibt danach an)."
    } else {
        $exe = Join-Path $WtlDir 'wow.tools.local.exe'
        if (-not (Test-Path -LiteralPath $exe -PathType Leaf) -or -not (Test-Path -LiteralPath (Join-Path $WtlDir 'wwwroot') -PathType Container)) {
            Fail "wow.tools.local nicht gefunden: '$exe' (mit wwwroot daneben). Release-win-x64.zip dorthin entpacken oder -WtlDir angeben."
        }
        if (-not $IgnoreRunningGame) {
            $wowRoot = (Resolve-Path -LiteralPath $WowDir).Path.TrimEnd('\') + '\'
            $running = @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
                    try { $_.Path -and $_.Path.StartsWith($wowRoot, [StringComparison]::OrdinalIgnoreCase) } catch { $false }
                })
            if ($running.Count -gt 0) {
                Fail ("WoW laeuft noch (" + (($running | ForEach-Object { $_.ProcessName }) -join ', ') + "). Bitte beenden (oder -IgnoreRunningGame).")
            }
        }
        $wtlArgs = @('-wowFolder', ('"' + $WowDir + '"'), '-wowProduct', $Product, '-locale', $Locale)
        $oldUrls = $env:ASPNETCORE_URLS
        $env:ASPNETCORE_URLS = $BaseUrl
        try {
            $script:proc = Start-Process -FilePath $exe -ArgumentList $wtlArgs -WorkingDirectory $WtlDir `
                -NoNewWindow -PassThru -RedirectStandardOutput $logOut -RedirectStandardError $logErr
        } finally {
            $env:ASPNETCORE_URLS = $oldUrls
        }
        Write-Host "Starte wow.tools.local ($Product), warte bis der Build geladen ist (erster Start laedt Listfile und Definitionen) ..."
    }

    # wait for the loaded build
    $deadline = (Get-Date).AddMinutes($StartTimeoutMin)
    $loaded = $null
    while (-not $loaded) {
        if ($script:proc -and $script:proc.HasExited) {
            Show-Log
            Fail "wow.tools.local hat sich beendet (Exit $($script:proc.ExitCode)). Log siehe oben."
        }
        if ((Get-Date) -gt $deadline) {
            Show-Log
            Fail "wow.tools.local hat nach $StartTimeoutMin Minuten keinen Build geladen."
        }
        $name = Get-Text '/casc/buildname'
        if ($name -and $name.Trim()) { $loaded = $name.Trim().Trim('"') } else { Start-Sleep -Seconds 3 }
    }
    Write-Host "wow.tools.local hat $loaded geladen."

    if ($loaded -ne $Build) {
        # WTL takes the newest build from the patch server; pin the installed one.
        if (-not $BuildKey -or -not $CdnKey) { Fail "Geladen ist $loaded statt $Build, und .build.info hat keine Build/CDN Keys." }
        Write-Host "Schalte auf den installierten Build $Build um ..."
        $ok = Get-Text ("/casc/switchConfigs?product=$Product&buildconfig=$BuildKey&cdnconfig=$CdnKey") 1800
        $loaded = (Get-Text '/casc/buildname')
        if ($loaded) { $loaded = $loaded.Trim().Trim('"') }
        if ($ok -notmatch 'true' -or $loaded -ne $Build) {
            Fail "Konnte den installierten Build $Build nicht laden (geladen: $loaded). WoW im Launcher aktualisieren und erneut starten."
        }
    }

    # ------------------------------------------------------------------ export
    $results = New-Object System.Collections.Generic.List[object]
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    $hf = if ($Hotfixes) { 'true' } else { 'false' }
    foreach ($table in $todo) {
        $isRequired = $required -contains $table
        $url = "$BaseUrl/dbc/export/?name=$table&build=$Build&locale=$Locale&useHotfixes=$hf"
        $status = ''
        $rowsOut = 0
        try {
            $resp = $http.GetAsync($url).GetAwaiter().GetResult()
            $code = [int]$resp.StatusCode
            if ($code -eq 200) {
                $text = $utf8.GetString($resp.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult())
                $nl = $text.IndexOf("`n")
                if ($nl -lt 0) { $nl = $text.Length }
                # wago.tools names array columns Name_0, Name_1; WTL writes Name[0].
                $head = [regex]::Replace($text.Substring(0, $nl), '\[(\d+)\]', '_$1')
                $text = $head + $text.Substring($nl)
                $tmp = Join-Path ([IO.Path]::GetTempPath()) ("amisia-$table.$Build.csv.part")
                [IO.File]::WriteAllText($tmp, $text, $utf8)
                Move-Item -LiteralPath $tmp -Destination (Target $table) -Force
                $rowsOut = ([regex]::Matches($text, "`n")).Count - 1
                $status = 'ok'
            } elseif ($code -eq 204) {
                $status = 'leer'
            } elseif ($code -eq 404) {
                $status = 'nicht im Build'
            } else {
                $status = "Fehler HTTP $code"
            }
        } catch {
            $status = 'Fehler: ' + $_.Exception.Message
        }
        $results.Add([pscustomobject]@{ Tabelle = $table; Status = $status; Zeilen = $rowsOut; Pflicht = $isRequired })
        $color = if ($status -eq 'ok') { 'Green' } elseif ($isRequired -and $status -like 'Fehler*') { 'Red' } else { 'Yellow' }
        Write-Host ("{0,-26} {1}{2}" -f $table, $status, $(if ($status -eq 'ok') { " ($rowsOut Zeilen)" } else { '' })) -ForegroundColor $color
    }

    foreach ($r in $results) { $known[$r.Tabelle] = $r.Status }
    $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm'
    $lines = @($known.Keys | Sort-Object | ForEach-Object { "$_`t$($known[$_])`t$stamp" })
    [IO.File]::WriteAllText($StatusFile, (($lines -join "`r`n") + "`r`n"), $utf8)

    # Empty or absent tables are only warnings: the build scripts fall back for missing tables.
    $failed = @($results | Where-Object { $_.Pflicht -and $_.Status -ne 'ok' -and $_.Status -ne 'leer' -and $_.Status -ne 'nicht im Build' })
    $skipped = (@($required) + @($optional)).Count - $todo.Count
    Write-Host ''
    Write-Host ("Fertig: {0} exportiert, {1} schon vorhanden, {2} Pflicht-Tabellen fehlgeschlagen. Ziel: {3}" -f `
            @($results | Where-Object { $_.Status -eq 'ok' }).Count, $skipped, $failed.Count, $OutDir)
    if ($failed.Count -gt 0) {
        if ($script:proc) {
            Write-Host 'Bei HTTP 400 steht der Grund im wow.tools.local-Log:' -ForegroundColor Red
            Show-Log
        } else {
            Write-Host 'Bei HTTP 400 steht der Grund im Konsolenfenster von wow.tools.local.' -ForegroundColor Red
        }
        $exitCode = 2
    }
} finally {
    Stop-Wtl
    $http.Dispose()
}
exit $exitCode
