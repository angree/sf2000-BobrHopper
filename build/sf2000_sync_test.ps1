# Task C2.8: tools\sf2000_sync.ps1 against a fake card (out\check\sf2000card) and fake docs (out\check\sf2000docs):
# a folder without bios\bisrv.asd is refused; install with a given variant on an empty card; a simulated console run
# (the game's log, stages, timing, settings, the multicore log.txt); a second sync without -Variant (remembered on
# the card) that collects the run, removes SF2000_TEST_REQUIRED.md, keeps the settings and clears the old logs.
#   powershell -NoProfile -ExecutionPolicy Bypass -File build\sf2000_sync_test.ps1
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$card = Join-Path $repo 'out\check\sf2000card'
$docs = Join-Path $repo 'out\check\sf2000docs'
foreach ($p in @($card, $docs)) { if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force } }
New-Item -ItemType Directory -Force -Path (Join-Path $card 'cores'), (Join-Path $card 'ROMS'), $docs | Out-Null
$sync = Join-Path $repo 'tools\sf2000_sync.ps1'
$script:fail = 0
function Check([string]$what, [bool]$ok) {
    if ($ok) { Write-Host "  ok   $what" } else { Write-Host "  FAIL $what"; $script:fail = 1 }
}
$game = Join-Path $card 'ROMS\bobrhopper'
$variant = 'gb300_frogui'

Write-Host "sf2000_sync_test: a folder that is not a console card"
& powershell -NoProfile -ExecutionPolicy Bypass -File $sync -CardRoot $card -DocsRoot $docs -Variant $variant -NoEject | Out-Host
Check "refused without bios\bisrv.asd" ($LASTEXITCODE -eq 1)
New-Item -ItemType Directory -Force -Path (Join-Path $card 'bios') | Out-Null
Set-Content -LiteralPath (Join-Path $card 'bios\bisrv.asd') -Value 'firmware' -Encoding ascii
Set-Content -LiteralPath (Join-Path $docs 'SF2000_TEST_REQUIRED.md') -Value 'test' -Encoding utf8

Write-Host "sf2000_sync_test: first sync (install)"
& powershell -NoProfile -ExecutionPolicy Bypass -File $sync -CardRoot $card -DocsRoot $docs -Variant $variant -NoEject | Out-Host
Check "exit code 0" ($LASTEXITCODE -eq 0)
$installed = Join-Path $card 'cores\bobrhopper\core_87000000'
$built = Join-Path $repo "out\sf2000\core_87000000_$variant"
Check "core of the chosen variant installed" ((Test-Path $installed) -and ((Get-FileHash $installed).Hash -eq (Get-FileHash $built).Hash))
Check "variant remembered on the card" ((Get-Content (Join-Path $card 'cores\bobrhopper\variant.txt')) -contains $variant)
Check "FrogUI launch files in ROMS\bobrhopper" ((Test-Path (Join-Path $game 'BobrHopper')) -and (Test-Path (Join-Path $game 'BobrHopper60')) -and (Test-Path (Join-Path $game 'bench')))
Check "multicore stubs in ROMS" ((Test-Path -LiteralPath (Join-Path $card 'ROMS\bobrhopper;BobrHopper.gba')) -and (Test-Path -LiteralPath (Join-Path $card 'ROMS\bobrhopper;BobrHopper60.gba')))
Check "data complete" ((Get-ChildItem (Join-Path $game 'data') -Recurse -File).Count -eq (Get-ChildItem (Join-Path $repo 'data_sf2000') -Recurse -File).Count)
Check "nothing collected yet" (-not (Test-Path (Join-Path $docs 'device')))
Check "SF2000_TEST_REQUIRED.md kept without a console run" (Test-Path (Join-Path $docs 'SF2000_TEST_REQUIRED.md'))

Write-Host "sf2000_sync_test: simulated console run"
Set-Content -LiteralPath (Join-Path $game 'bobrhopper.log') -Value 'BobrHopper v003 game' -Encoding ascii
Set-Content -LiteralPath (Join-Path $game 'stage.txt') -Value 'stage 9 first retro_run' -Encoding ascii
Set-Content -LiteralPath (Join-Path $game 'game_game30.txt') -Value 'frames 900 steps 1800 dropped_steps 0' -Encoding ascii
Set-Content -LiteralPath (Join-Path $game 'conf\crossy.cfg') -Value 'highscore=42' -Encoding ascii
Set-Content -LiteralPath (Join-Path $card 'log.txt') -Value 'bobrhopper: stage 9' -Encoding ascii

Write-Host "sf2000_sync_test: second sync (collect + update, variant from the card)"
& powershell -NoProfile -ExecutionPolicy Bypass -File $sync -CardRoot $card -DocsRoot $docs -NoEject | Out-Host
Check "exit code 0" ($LASTEXITCODE -eq 0)
$runs = @(Get-ChildItem (Join-Path $docs 'device') -Directory -Filter 'sf2000_*')
Check "one console run folder" ($runs.Count -eq 1)
if ($runs.Count -eq 1) {
    $d = $runs[0].FullName
    Check "log, stages, timing, settings, multicore log and variant collected" ((Test-Path (Join-Path $d 'bobrhopper.log')) -and (Test-Path (Join-Path $d 'stage.txt')) -and (Test-Path (Join-Path $d 'game_game30.txt')) -and (Test-Path (Join-Path $d 'crossy.cfg')) -and (Test-Path (Join-Path $d 'multicore_log.txt')) -and ((Get-Content (Join-Path $d 'variant.txt')) -contains $variant))
}
Check "SF2000_TEST_REQUIRED.md removed" (-not (Test-Path (Join-Path $docs 'SF2000_TEST_REQUIRED.md')))
Check "settings kept on the card" ((Get-Content (Join-Path $game 'conf\crossy.cfg')) -contains 'highscore=42')
Check "old run files cleared for the next run" (-not (Test-Path (Join-Path $game 'bobrhopper.log')) -and -not (Test-Path (Join-Path $game 'stage.txt')))
Check "the same variant installed again" ((Get-FileHash $installed).Hash -eq (Get-FileHash $built).Hash)

foreach ($p in @($card, $docs)) { if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force } }
if ($script:fail) { Write-Host "sf2000_sync_test: FAILED"; exit 1 }
Write-Host "sf2000_sync_test: OK"
exit 0
