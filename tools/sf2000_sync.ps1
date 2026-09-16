# SF2000 / GB300 card sync (task C2.8) -- the only thing the user runs: put the console's card in the PC,
# double-click SF2000_SYNC.bat.
#  1. collects the last console run from the card (the game's log, start-up stages, frame timing, bench results,
#     settings, the multicore log.txt) into docs\device\sf2000_<date>\ and removes docs\SF2000_TEST_REQUIRED.md
#  2. installs / updates the game: cores\bobrhopper\core_87000000 for the console's variant, launch files in
#     ROMS\bobrhopper\ (FrogUI) and ROMS\bobrhopper;*.gba stubs (multicore), data\ (conf\ with the settings stays)
#  3. verifies the copy and flushes the card (it is not ejected: the user keeps it mounted)
# The card is recognised by bios\bisrv.asd and a cores folder at its root. The variant (sf2000_mc, gb300_mc,
# sf2000_frogui, gb300_frogui) is asked once and remembered in cores\bobrhopper\variant.txt.
param(
    [string]$CardRoot = "",  # a folder standing in for the card (tests); default: the drive holding bios\bisrv.asd
    [string]$DocsRoot = "",  # where docs\device and SF2000_TEST_REQUIRED.md live (tests); default: repo docs
    [string]$Variant = "",   # skips the question; default: cores\bobrhopper\variant.txt on the card
    [switch]$NoEject
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
if (-not $DocsRoot) { $DocsRoot = Join-Path $repo 'docs' }
$known = @('sf2000_mc', 'gb300_mc', 'sf2000_frogui', 'gb300_frogui')

function Say([string]$msg) { Write-Host $msg }
function Fail([string]$msg) { Write-Host "BLAD: $msg" -ForegroundColor Red; exit 1 }

# --- the card ------------------------------------------------------------------------------------------------
$drive = $null
if ($CardRoot) {
    if (-not (Test-Path -LiteralPath $CardRoot)) { Fail "brak folderu karty $CardRoot" }
} else {
    $cards = @(Get-Volume | Where-Object {
            $_.DriveLetter -and (Test-Path -LiteralPath "$($_.DriveLetter):\bios\bisrv.asd") -and
            (Test-Path -LiteralPath "$($_.DriveLetter):\cores")
        })
    if ($cards.Count -eq 0) { Fail "nie widze karty SF2000/GB300 (bios\bisrv.asd i cores\). Wloz karte i uruchom ponownie." }
    if ($cards.Count -gt 1) { Fail "widze kilka kart SF2000/GB300 naraz - zostaw jedna" }
    $drive = [string]$cards[0].DriveLetter
    $CardRoot = "${drive}:\"
}
if (-not (Test-Path -LiteralPath (Join-Path $CardRoot 'bios\bisrv.asd'))) { Fail "to nie karta SF2000/GB300: brak bios\bisrv.asd w $CardRoot" }
$roms = Join-Path $CardRoot 'ROMS'
$game = Join-Path $roms 'bobrhopper'
$coreDir = Join-Path $CardRoot 'cores\bobrhopper'
$variantFile = Join-Path $coreDir 'variant.txt'
Say "Karta: $CardRoot"

# --- 0. the old name ------------------------------------------------------------------------------------------
# O17: the game used to live in ROMS\crossyroad and cores\crossyroad. Renaming the folder (rather than making a new
# one) carries the player's settings, the best score AND the logs of the last console run across in one move; the
# logs are renamed too, so step 1 below still collects them.
$oldGame = Join-Path $roms 'crossyroad'
if ((Test-Path -LiteralPath $oldGame) -and -not (Test-Path -LiteralPath $game)) {
    Rename-Item -LiteralPath $oldGame -NewName 'bobrhopper'
    Say "Zmieniono nazwe folderu na karcie: ROMS\crossyroad -> ROMS\bobrhopper (ustawienia i rekord zachowane)."
} elseif (Test-Path -LiteralPath $oldGame) {
    $oldCfg = Join-Path $oldGame 'conf\crossy.cfg'
    $newCfg = Join-Path $game 'conf\crossy.cfg'
    if ((Test-Path -LiteralPath $oldCfg) -and -not (Test-Path -LiteralPath $newCfg)) {
        New-Item -ItemType Directory -Force -Path (Join-Path $game 'conf') | Out-Null
        Copy-Item -LiteralPath $oldCfg -Destination $newCfg -Force
    }
    Remove-Item -LiteralPath $oldGame -Recurse -Force
    Say "Usunieto stary folder ROMS\crossyroad (ustawienia zachowane)."
}
foreach ($pair in @(@('crossyroad.log', 'bobrhopper.log'), @('crossyroad-launcher.log', 'bobrhopper-launcher.log'))) {
    $stale = Join-Path $game $pair[0]
    if (Test-Path -LiteralPath $stale) { Move-Item -LiteralPath $stale -Destination (Join-Path $game $pair[1]) -Force }
}
Get-ChildItem -LiteralPath $roms -Filter 'crossyroad;*.gba' -File -ErrorAction SilentlyContinue | Remove-Item -Force
$oldCore = Join-Path $CardRoot 'cores\crossyroad'
if (Test-Path -LiteralPath $oldCore) {
    $oldVariant = Join-Path $oldCore 'variant.txt'
    if ((Test-Path -LiteralPath $oldVariant) -and -not (Test-Path -LiteralPath $variantFile)) {
        New-Item -ItemType Directory -Force -Path $coreDir | Out-Null
        Copy-Item -LiteralPath $oldVariant -Destination $variantFile -Force
    }
    Remove-Item -LiteralPath $oldCore -Recurse -Force
    Say "Usunieto stary cores\crossyroad (wariant konsoli zapamietany)."
}

if (-not $Variant -and (Test-Path -LiteralPath $variantFile)) {
    $Variant = ([string](Get-Content -LiteralPath $variantFile -TotalCount 1)).Trim()
}
if ($known -notcontains $Variant) {
    Say "Ktora konsola i ktore menu sa na tej karcie?"
    Say "  1  SF2000 z multicore"
    Say "  2  GB300 z multicore"
    Say "  3  SF2000 z FrogUI"
    Say "  4  GB300 V2 z FrogUI"
    $answer = Read-Host "Numer (1-4)"
    $index = 0
    if (-not [int]::TryParse($answer, [ref]$index) -or $index -lt 1 -or $index -gt 4) { Fail "nieznany wybor '$answer'" }
    $Variant = $known[$index - 1]
}
Say "Wariant: $Variant"

# --- 1. collect the last console run -------------------------------------------------------------------------
$runFiles = @('bobrhopper.log', 'stage.txt', 'game_game30.txt', 'game_game60.txt', 'bench_bench.txt', 'renderbench.txt')
$present = @($runFiles | Where-Object { Test-Path -LiteralPath (Join-Path $game $_) })
if ($present.Count) {
    $dest = Join-Path (Join-Path $DocsRoot 'device') ('sf2000_' + (Get-Date -Format 'yyyy-MM-dd_HHmm'))
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    foreach ($name in $present) { Copy-Item -LiteralPath (Join-Path $game $name) -Destination $dest -Force }
    $cfg = Join-Path $game 'conf\crossy.cfg'
    if (Test-Path -LiteralPath $cfg) { Copy-Item -LiteralPath $cfg -Destination $dest -Force }
    $beside = Join-Path $game 'crossy.cfg'
    if (Test-Path -LiteralPath $beside) { Copy-Item -LiteralPath $beside -Destination (Join-Path $dest 'crossy_beside_rom.cfg') -Force }
    $xlog = Join-Path $CardRoot 'log.txt'
    if (Test-Path -LiteralPath $xlog) { Copy-Item -LiteralPath $xlog -Destination (Join-Path $dest 'multicore_log.txt') -Force }
    Set-Content -LiteralPath (Join-Path $dest 'variant.txt') -Value $Variant -Encoding ascii
    Say "Zebrano wyniki z konsoli: $dest"
    $required = Join-Path $DocsRoot 'SF2000_TEST_REQUIRED.md'
    if (Test-Path -LiteralPath $required) {
        Remove-Item -LiteralPath $required -Force
        Say "SF2000_TEST_REQUIRED.md usuniety, Claude przeanalizuje wyniki."
    }
}

# --- 2. install / update the game ----------------------------------------------------------------------------
$core = Join-Path $repo "out\sf2000\core_87000000_$Variant"
$data = Join-Path $repo 'data_sf2000'
foreach ($p in @($core, (Join-Path $data 'manifest.txt'), (Join-Path $data 'music\title.wav'))) {
    if (-not (Test-Path -LiteralPath $p)) { Fail "brak $p (zbuduj: sh build/build_sf2000.sh sf2000_core, sh build/bake_sf2000.sh)" }
}
foreach ($dir in @($coreDir, $game, (Join-Path $game 'conf'))) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
Copy-Item -LiteralPath $core -Destination (Join-Path $coreDir 'core_87000000') -Force
Set-Content -LiteralPath $variantFile -Value $Variant -Encoding ascii
foreach ($rom in @('BobrHopper', 'BobrHopper60', 'bench', 'RenderBench')) {
    foreach ($path in @((Join-Path $game $rom), (Join-Path $roms "bobrhopper;$rom.gba"))) {
        if (-not (Test-Path -LiteralPath $path)) { [System.IO.File]::WriteAllBytes($path, [byte[]]@()) }
    }
}
$cardData = Join-Path $game 'data'
if ((Test-Path -LiteralPath $cardData) -and $cardData.EndsWith('bobrhopper\data')) {
    Remove-Item -LiteralPath $cardData -Recurse -Force
}
Copy-Item -LiteralPath $data -Destination $cardData -Recurse -Force
foreach ($old in $runFiles) {
    $p = Join-Path $game $old
    if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Force }
}
Say "Zainstalowano BobrHopper ($Variant)."

# --- 3. verify, flush---------------------------------------------------------------------------------
$problems = @()
if ((Get-Item -LiteralPath (Join-Path $coreDir 'core_87000000')).Length -ne (Get-Item -LiteralPath $core).Length) { $problems += 'rdzen' }
$srcCount = (Get-ChildItem -LiteralPath $data -Recurse -File).Count
$dstCount = (Get-ChildItem -LiteralPath $cardData -Recurse -File).Count
if ($srcCount -ne $dstCount) { $problems += "data ($dstCount z $srcCount plikow)" }
foreach ($rom in @('BobrHopper', 'BobrHopper60', 'bench', 'RenderBench')) {
    if (-not (Test-Path -LiteralPath (Join-Path $game $rom))) { $problems += "plik startowy $rom" }
    if (-not (Test-Path -LiteralPath (Join-Path $roms "bobrhopper;$rom.gba"))) { $problems += "skrot bobrhopper;$rom.gba" }
}
if ($problems.Count) { Fail ("kopia niekompletna: " + ($problems -join ', ')) }
Say "Sprawdzono: rdzen, $dstCount plikow danych, pliki startowe i skroty."

# the card stays mounted (the user: no ejecting); only the write cache is flushed
if ($drive) {
    Write-VolumeCache -DriveLetter $drive
    Say "Zapisano na karte."
}
Say "Na konsoli: multicore - bobrhopper;BobrHopper, FrogUI - folder bobrhopper, plik BobrHopper."
exit 0
