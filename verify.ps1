#requires -Version 5.1
<#
  Geeked Geese verification loop.

    .\verify.ps1              # gate, invariants, controller, credit roll, campaign
    .\verify.ps1 -Shots       # also render every zone and tell you where the PNGs are
    .\verify.ps1 -Quick       # skips the 20 s campaign run

  Run this after EVERY batch of edits. Nothing may be described as working until
  this passes and its output has been read.

  ---------------------------------------------------------------------------
  WHAT CHANGED, AND WHY THE OLD VERSION OF THIS FILE WAS DANGEROUS
  ---------------------------------------------------------------------------
  This script used to run four steps, and not one of them could catch the bug
  it was supposed to:

    * `godot --headless --import` was the headline check. --import scans and
      imports ASSETS. It does not compile GDScript at all. See the long argument
      at the top of tools/gate.gd; four shipped bugs got through it.
    * `tools/validate_project.gd` ran via `--script`, which parses outside the
      booted project, so every file touching an autoload false-fails on
      `Identifier not found: Subs` — and typo'd method names pass.
    * gdformat/gdlint were pointed at "systems", "goose", "zones" and "test".
      None of those directories exist. The code is under scripts/. Both steps
      were silently skipping the entire project.
    * GUT was never installed, so the unit-test step never ran.

  And the failure heuristic was worse than the steps: Step() failed on any
  `ERROR:` in stderr, while the real compile gate legitimately prints 26 lines
  of `ERROR: Parameter "method" is null.` parsing scripts/ui/briefing.gd
  (bisected, attributed, harmless — CLAUDE.md documents it). Wiring the real
  gate into the old Step() would have produced a permanent red build.

  So each check below owns its own verdict: it states the exact line that means
  PASS, and it checks the process exit code as well. No heuristics.
#>

param(
    [switch]$Shots,
    [switch]$Quick
)

$ErrorActionPreference = "Continue"

# --- locate the engine ------------------------------------------------------
# Always the *_console.exe. The plain .exe is GUI-subsystem, so PowerShell does
# not wait for it and its exit code is unreliable.
$GODOT = $env:GODOT
if (-not $GODOT) {
    $cmd = Get-Command godot -ErrorAction SilentlyContinue
    if ($cmd) { $GODOT = $cmd.Source }
}
if (-not $GODOT) {
    $guess = "C:\Tools\Godot\Godot_v4.7.1-stable_win64_console.exe"
    if (Test-Path $guess) { $GODOT = $guess }
}
if (-not $GODOT) {
    Write-Host "Godot not found. Set `$env:GODOT to the *_console.exe, or put it on PATH." -ForegroundColor Red
    exit 1
}
if ($GODOT -notmatch "console") {
    Write-Host "WARNING: '$GODOT' is not the console build. Exit codes and stdout will be unreliable." -ForegroundColor Yellow
}

$script:fail = $false
$root = $PSScriptRoot

function Fail($name, $why) {
    Write-Host "[FAIL] $name - $why" -ForegroundColor Red
    $script:fail = $true
}

function Pass($name, $line) {
    Write-Host "[ok] $name" -ForegroundColor Green
    if ($line) { Write-Host "      $line" -ForegroundColor DarkGray }
}

# ---------------------------------------------------------------------------
# 0. THE IMPORT. Not a check - a prerequisite. A fresh checkout has no .godot
#    cache and the first run has to build one before anything else means
#    anything. Its output is deliberately ignored.
# ---------------------------------------------------------------------------
if (-not (Test-Path (Join-Path $root ".godot"))) {
    Write-Host "`n=== first-run asset import (this takes a minute) ===" -ForegroundColor Cyan
    & $GODOT --headless --no-header --path $root --import | Out-Null
}

# ---------------------------------------------------------------------------
# 1. THE COMPILE GATE. Compiles every .gd and loads every .tres/.tscn from
#    INSIDE the booted project, which is the only context where the autoloads
#    are registered and identifier resolution is real. tools/gate.gd.
# ---------------------------------------------------------------------------
Write-Host "`n=== compile gate ===" -ForegroundColor Cyan
$gateOut = & $GODOT --headless --no-header --path $root -- --gate 2>&1 | Out-String
$gateCode = $LASTEXITCODE
$gateLines = ($gateOut -split "`r?`n") | Where-Object { $_ -match '^\[gate\]' }
$gateLines | ForEach-Object { Write-Host $_ }
if ($gateCode -ne 0) {
    Fail "compile gate" "exit $gateCode"
} elseif (-not ($gateLines -match 'PASS')) {
    Fail "compile gate" "no [gate] PASS line - did it run at all?"
} else {
    Pass "compile gate" ($gateLines | Where-Object { $_ -match 'PASS' })
}

# ---------------------------------------------------------------------------
# 2. THE INVARIANT HARNESS. Proves the game AGREES WITH ITSELF: the route, both
#    clocks, the leg titles, the substance data and the objective sets. The
#    gate proves the code compiles; this proves it is not lying. Every
#    assertion in it is a bug that already got through once. tools/selftest.gd.
# ---------------------------------------------------------------------------
Write-Host "`n=== invariants ===" -ForegroundColor Cyan
$stOut = & $GODOT --headless --no-header --path $root -- --selftest 2>&1 | Out-String
$stCode = $LASTEXITCODE
$stLines = ($stOut -split "`r?`n") | Where-Object { $_ -match '^\[selftest\]' }
$stLines | ForEach-Object { Write-Host $_ }
if ($stCode -ne 0) {
    Fail "invariants" "exit $stCode"
} elseif (-not ($stLines -match 'PASS')) {
    Fail "invariants" "no [selftest] PASS line"
} else {
    Pass "invariants" ($stLines | Where-Object { $_ -match 'PASS' })
}

# ---------------------------------------------------------------------------
# 3. THE CONTROLLER, WITH ITS HANDS ON IT. Holds W, flaps, honks and doses, and
#    asserts the bird actually did something. It exists because an input-lag bug
#    that made eleven of the sixteen substances unplayable got past the compile
#    gate, the invariants AND the full campaign run - none of which had ever
#    pressed a key. tools/inputtest.gd.
# ---------------------------------------------------------------------------
Write-Host "`n=== controller ===" -ForegroundColor Cyan
$inOut = & $GODOT --headless --no-header --path $root -- --probe --inputtest 2>&1 | Out-String
$inCode = $LASTEXITCODE
$inLines = ($inOut -split "`r?`n") | Where-Object { $_ -match '^\[input\]' }
$inLines | ForEach-Object { Write-Host $_ }
if ($inCode -ne 0) {
    Fail "controller" "exit $inCode"
} elseif (-not ($inLines -match 'PASS')) {
    Fail "controller" "no [input] PASS line"
} else {
    Pass "controller" ($inLines | Where-Object { $_ -match 'PASS' })
}

# ---------------------------------------------------------------------------
# 4. THE CREDIT ROLL, MEASURED. The ending's fifth beat is slabs walking up the
#    fairway, and its drive has been wrong twice - both times a speed nobody
#    could see without watching the ending for four to six minutes. Physics runs
#    headless, so the speed can just be measured. main.gd::_roll_test().
# ---------------------------------------------------------------------------
Write-Host "`n=== credit roll ===" -ForegroundColor Cyan
$rollOut = & $GODOT --headless --no-header --path $root -- --probe --rolltest 2>&1 | Out-String
$rollCode = $LASTEXITCODE
$rollLines = ($rollOut -split "`r?`n") | Where-Object { $_ -match '^\[roll\]' }
$rollLines | ForEach-Object { Write-Host $_ }
if ($rollCode -ne 0) {
    Fail "credit roll" "exit $rollCode"
} elseif (-not ($rollLines -match 'PASS')) {
    Fail "credit roll" "no [roll] PASS line"
} else {
    Pass "credit roll" ($rollLines | Where-Object { $_ -match 'measured' })
}

# ---------------------------------------------------------------------------
# 5. THE WHOLE CAMPAIGN, HEADLESS, IN ABOUT TWENTY SECONDS. The strongest check
#    in the project and the cheapest: it drives all seven legs, all seven
#    flights, the results card, the roster and the ending. If it stops early,
#    read the [loop] t=... phase=... lines - it prints what it is stuck behind.
# ---------------------------------------------------------------------------
if (-not $Quick) {
    Write-Host "`n=== full campaign ===" -ForegroundColor Cyan
    $loopOut = & $GODOT --headless --no-header --path $root -- --probe --loop-test 2>&1 | Out-String
    $loopCode = $LASTEXITCODE
    ($loopOut -split "`r?`n") | Where-Object { $_ -match '^\[run\]|^\[loop\] leg \d|^\[loop\] END' } | ForEach-Object { Write-Host $_ }
    if ($loopCode -ne 0) {
        Fail "full campaign" "exit $loopCode"
    } elseif ($loopOut -notmatch '\[run\] COMPLETE') {
        Fail "full campaign" "never reached [run] COMPLETE - the route stops somewhere"
    } elseif ($loopOut -match 'SCRIPT ERROR') {
        Fail "full campaign" "SCRIPT ERROR during the run"
    } else {
        $survivors = ($loopOut -split "`r?`n") | Where-Object { $_ -match '\[run\] COMPLETE' }
        Pass "full campaign" $survivors
    }
}

# ---------------------------------------------------------------------------
# 6. RENDER AND LOOK. Optional, because it needs a real display and about a
#    minute - but it is NOT optional before claiming anything about how the
#    game looks. Every visual bug in this project's history was found by
#    reading a PNG and none of them were findable by reading code: an
#    inside-out mesh, a goose flying backwards, a dog buried to its knees, a
#    sign reading backwards, text running off the screen.
#
#    --secs is wall-clock and --frames is not. The documented --frames values
#    were calibrated against a container rendering this project in software at
#    about 2 fps; on a machine with a GPU the same numbers fire a tenth of a
#    second in and photograph the moment before anything has happened.
# ---------------------------------------------------------------------------
if ($Shots) {
    $shotDir = Join-Path $root "shots"
    if (Test-Path $shotDir) { Remove-Item (Join-Path $shotDir "*.png") -ErrorAction SilentlyContinue }
    New-Item -ItemType Directory -Force $shotDir | Out-Null
    $shotArg = ($shotDir -replace '\\', '/')

    Write-Host "`n=== render probes ===" -ForegroundColor Cyan
    foreach ($leg in 1..7) {
        & $GODOT --no-header --path $root --rendering-driver opengl3 -- `
            --probe "--leg:$leg" --shots:1 --secs:2 "--out:$shotArg" 2>&1 |
            Where-Object { $_ -match '^\[probe\]' } | ForEach-Object { Write-Host $_ }
        if ($LASTEXITCODE -ne 0) { Fail "render leg $leg" "exit $LASTEXITCODE (a shot failed to write)" }
    }
    foreach ($extra in @(@("--finale"), @("--migration"), @("--ui"))) {
        & $GODOT --no-header --path $root --rendering-driver opengl3 -- `
            --probe @extra --shots:1 --secs:3 "--out:$shotArg" 2>&1 |
            Where-Object { $_ -match '^\[probe\]' } | ForEach-Object { Write-Host $_ }
        if ($LASTEXITCODE -ne 0) { Fail "render $extra" "exit $LASTEXITCODE (a shot failed to write)" }
    }
    $pngs = Get-ChildItem $shotDir -Filter *.png
    Write-Host "`n$($pngs.Count) image(s) in $shotDir" -ForegroundColor Cyan
    Write-Host "OPEN AT LEAST THREE OF THEM before saying anything about how the game looks." -ForegroundColor Yellow
}

# --- verdict ----------------------------------------------------------------
if ($script:fail) {
    Write-Host "`nVERIFY FAILED" -ForegroundColor Red
    exit 1
}
Write-Host "`nVERIFY PASSED" -ForegroundColor Green
exit 0
