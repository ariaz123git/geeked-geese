#requires -Version 5.1
<#
  Geeked Geese verification loop.

    .\verify.ps1              # eleven gates: compile, invariants, controller, feel, substances,
                              #   flight, credit roll, claims, audio, footprints, campaign
                              # then step 12: the gate table in docs/HANDOFF.md, against
                              #   the PASS lines those eleven just printed
    .\verify.ps1 -Shots       # also render every zone and tell you where the PNGs are
    .\verify.ps1 -Quick       # skips the 20 s campaign run
    .\verify.ps1 -StepTimeout 60   # kill any gate still running after 60 s (the
                              #   default is per step, above its own failsafe)

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
    [switch]$Quick,
    # Seconds before a gate is killed. 0 = each step's own default, set above
    # that step's in-engine failsafe so the engine's clearer message wins
    # whenever main.gd can parse at all. See Godot() below.
    [int]$StepTimeout = 0
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

# EVERY STEP CHECKS FOR `SCRIPT ERROR`, NOT JUST ONE OF THEM.
#
# Until 2026-08-18 the full-campaign step was the ONLY one that looked. Each
# other step greps for its own `[tag] PASS` line and checks the exit code, so a
# harness could raise a runtime error inside a branch the pass line does not
# depend on, print its PASS anyway, exit 0, and be reported green. That is the
# same class as a gate that cannot fail, and it went unnoticed for the life of
# the project - see docs/RECENT_FAILURES.md F-001, which this half retires.
#
# `SCRIPT ERROR` specifically, NOT a blanket `ERROR:`: the compile gate
# legitimately prints 26 lines of `ERROR: Parameter "method" is null.` parsing
# scripts/ui/briefing.gd (bisected, attributed, harmless - tools/gate.gd
# explains it), and two probes exit with `ERROR: N resources still in use at
# exit` from an engine teardown ordering issue that is diagnosed but not fixed.
# Failing on those would make the build permanently red for known-benign and
# known-open conditions, which is how a check gets deleted. F-001 stays open for
# exactly that half, with the evidence, rather than being gated prematurely.
function ScriptErrors($out) {
    return @(($out -split "`r?`n") | Where-Object { $_ -match 'SCRIPT ERROR' })
}

# Every PASS line, kept, because step 12 checks them against docs/HANDOFF.md.
$script:passLines = @{}

# THE PLAYER'S SAVE, SNAPSHOTTED BEFORE ANY GATE RUNS.
#
# Until 2026-09-25 every gate read and wrote the same save file the player
# does. On this project's own machine that file said best_chaos=131201955 and
# had all seventeen substances unlocked - the pause menu's BEST CHAOS line and
# the Almanac's whole discovery mechanic, both spent by harnesses - and a full
# run of this script rewrote it every time. scripts/core/prefs.gd is hermetic
# under any user argument now; this is the check that it stays that way, taken
# by the only thing that sees all the gates at once.
#
# Hash AND write time: a rewrite with identical content is still a write, and
# identical content is exactly what the old bug produced on most runs. The
# directory is a guess here and is confirmed against the engine after step 1,
# because a wrong guess makes this check vacuous - absent before, absent after.
$saveDir = Join-Path $env:APPDATA "Godot\app_userdata\Geeked Geese"
$savePath = Join-Path $saveDir "geeked_geese.cfg"
function SaveStamp($p) {
    if (-not (Test-Path $p)) { return "absent" }
    $hash = (Get-FileHash $p -Algorithm SHA256).Hash
    return "$hash @ $((Get-Item $p).LastWriteTimeUtc.ToString('o'))"
}
$saveBefore = SaveStamp $savePath

# EVERY GATE RUNS UNDER A WALL-CLOCK LIMIT THAT THIS SCRIPT OWNS.
#
# docs/RECENT_FAILURES.md F-005. On 2026-08-19 a patch swallowed a newline in
# main.gd, the main scene would not parse, and --gate printed nothing and never
# exited. The in-engine failsafe could not help, because it lives in main.gd
# too: a file that will not parse takes its own deadline down with it. Every
# step below boots the same main.gd, so the same fault would have hung this
# whole script, forever, with no line saying why.
#
# The shell that starts a process is the only thing that can always stop it.
# Each run goes to temp files, waits at most $limit seconds, and on timeout
# kills the whole process TREE (the console build can run the engine as a
# child, and Windows PowerShell 5.1 has no Kill(entireProcessTree)), then
# prints the last lines it caught - which is where "Parse Error ... main.gd:NNN"
# would be. Exit code 124 means "killed by this script", as in coreutils.
$script:killed = @()
function Godot([string[]]$gargs, [int]$limit) {
    if ($StepTimeout -gt 0) { $limit = $StepTimeout }
    $outFile = [IO.Path]::GetTempFileName()
    $errFile = [IO.Path]::GetTempFileName()
    $argLine = ($gargs | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }) -join ' '
    $p = Start-Process -FilePath $GODOT -ArgumentList $argLine -NoNewWindow -PassThru `
        -RedirectStandardOutput $outFile -RedirectStandardError $errFile
    $null = $p.Handle   # without this, ExitCode can read back as $null after exit
    $timedOut = -not $p.WaitForExit($limit * 1000)
    if ($timedOut) {
        & taskkill.exe /PID $p.Id /T /F 2>&1 | Out-Null
        $null = $p.WaitForExit(10000)
    }
    $text = [string](Get-Content $outFile -Raw -Encoding UTF8) + [string](Get-Content $errFile -Raw -Encoding UTF8)
    Remove-Item $outFile, $errFile -ErrorAction SilentlyContinue
    if ($timedOut) {
        $script:killed += ($gargs -join ' ')
        Write-Host "[timeout] killed after $limit s: $($gargs -join ' ')" -ForegroundColor Red
        Write-Host "          the last lines it printed:" -ForegroundColor Red
        ($text -split "`r?`n") | Where-Object { $_.Trim() -ne '' } | Select-Object -Last 12 |
            ForEach-Object { Write-Host "          $_" -ForegroundColor DarkGray }
        return @{ Out = $text; Code = 124 }
    }
    return @{ Out = $text; Code = $p.ExitCode }
}

function Pass($name, $line) {
    Write-Host "[ok] $name" -ForegroundColor Green
    if ($line) { Write-Host "      $line" -ForegroundColor DarkGray }
    $script:passLines[$name] = [string]$line
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
$r = Godot @('--headless','--no-header','--path',$root,'--','--gate') 360
$gateOut = $r.Out
$gateCode = $r.Code
$gateLines = ($gateOut -split "`r?`n") | Where-Object { $_ -match '^\[gate\]' }
$gateLines | ForEach-Object { Write-Host $_ }
if ($gateCode -ne 0) {
    Fail "compile gate" "exit $gateCode"
} elseif (-not ($gateLines -match 'PASS')) {
    Fail "compile gate" "no [gate] PASS line - did it run at all?"
} elseif ((ScriptErrors $gateOut).Count -gt 0) {
    Fail "compile gate" "SCRIPT ERROR: $((ScriptErrors $gateOut)[0])"
} else {
    Pass "compile gate" ($gateLines | Where-Object { $_ -match 'PASS' })
}
# A KILLED COMPILE GATE ENDS THE RUN. Every step after it boots the same
# main.gd, so if this one could not finish, eleven more would each wait out
# their own limit and say nothing new. The lines printed above are the evidence;
# run the gate unfiltered to see all of it (CLAUDE.md, "The parser can HANG").
if ($gateCode -eq 124) {
    Write-Host "`nThe compile gate was killed, and every later step boots the same main.gd. Stopping here." -ForegroundColor Red
    Write-Host "`nVERIFY FAILED" -ForegroundColor Red
    exit 1
}
# Confirm the snapshot above was taken of the file the engine actually uses.
$udLine = $gateLines | Where-Object { $_ -match '^\[gate\] user data: ' } | Select-Object -First 1
$saveDirOk = $false
if ($udLine) {
    $engineDir = ($udLine -replace '^\[gate\] user data: ', '').Trim() -replace '/', '\'
    $saveDirOk = ($engineDir.TrimEnd('\') -ieq $saveDir.TrimEnd('\'))
    if (-not $saveDirOk) {
        Fail "the player's save" ("this script snapshotted $saveDir but the engine's user data " +
            "directory is $engineDir - the save check below would be checking the wrong file")
    }
} else {
    Fail "the player's save" "the compile gate printed no '[gate] user data:' line, so the save path is unconfirmed"
}

# ---------------------------------------------------------------------------
# 2. THE INVARIANT HARNESS. Proves the game AGREES WITH ITSELF: the route, both
#    clocks, the leg titles, the substance data and the objective sets. The
#    gate proves the code compiles; this proves it is not lying. Every
#    assertion in it is a bug that already got through once. tools/selftest.gd.
# ---------------------------------------------------------------------------
Write-Host "`n=== invariants ===" -ForegroundColor Cyan
$r = Godot @('--headless','--no-header','--path',$root,'--','--selftest') 360
$stOut = $r.Out
$stCode = $r.Code
$stLines = ($stOut -split "`r?`n") | Where-Object { $_ -match '^\[selftest\]' }
$stLines | ForEach-Object { Write-Host $_ }
if ($stCode -ne 0) {
    Fail "invariants" "exit $stCode"
} elseif (-not ($stLines -match 'PASS')) {
    Fail "invariants" "no [selftest] PASS line"
} elseif ((ScriptErrors $stOut).Count -gt 0) {
    Fail "invariants" "SCRIPT ERROR: $((ScriptErrors $stOut)[0])"
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
$r = Godot @('--headless','--no-header','--path',$root,'--','--probe','--inputtest') 360
$inOut = $r.Out
$inCode = $r.Code
$inLines = ($inOut -split "`r?`n") | Where-Object { $_ -match '^\[input\]' }
$inLines | ForEach-Object { Write-Host $_ }
if ($inCode -ne 0) {
    Fail "controller" "exit $inCode"
} elseif (-not ($inLines -match 'PASS')) {
    Fail "controller" "no [input] PASS line"
} elseif ((ScriptErrors $inOut).Count -gt 0) {
    Fail "controller" "SCRIPT ERROR: $((ScriptErrors $inOut)[0])"
} else {
    Pass "controller" ($inLines | Where-Object { $_ -match 'PASS' })
}

# ---------------------------------------------------------------------------
# 4. THE FEEL HARNESS. The controller gate above proves the bird MOVES; its own
#    header says its thresholds catch "broken, never not tuned" and that judging
#    feel "is the human's job". That sentence is why this project's handoff
#    opened with "Play it" at the top of the list two sessions running, and why
#    nothing ever came off that list.
#
#    This step measures the half of feel that is a NUMBER, against windows that
#    each cite something already written down in this repo. It found, on its
#    first run, that a held flap COMPOUNDED: 7.36 m of climb in the first second
#    and 23.66 m in the third, with no max_rise anywhere in the controller.
#    Every other gate passed on that build. tools/feeltest.gd, docs/FEEL_TARGETS.md.
# ---------------------------------------------------------------------------
Write-Host "`n=== feel ===" -ForegroundColor Cyan
$r = Godot @('--headless','--no-header','--path',$root,'--','--probe','--feeltest') 360
$feelOut = $r.Out
$feelCode = $r.Code
$feelLines = ($feelOut -split "`r?`n") | Where-Object { $_ -match '^\[feel\]' }
$feelLines | ForEach-Object { Write-Host $_ }
if ($feelCode -ne 0) {
    Fail "feel" "exit $feelCode"
} elseif (-not ($feelLines -match 'PASS')) {
    Fail "feel" "no [feel] PASS line"
} elseif ((ScriptErrors $feelOut).Count -gt 0) {
    Fail "feel" "SCRIPT ERROR: $((ScriptErrors $feelOut)[0])"
} else {
    Pass "feel" ($feelLines | Where-Object { $_ -match 'PASS' })
}

# ---------------------------------------------------------------------------
# 5. THE SUBSTANCE GATE. The design rule at the top of scripts/core/substance.gd
#    is that "a substance must never be only a number that goes up" - every one
#    needs a control mutation. selftest.gd enforces that by READING THE .tres,
#    which cannot tell you the mutation reaches the bird.
#
#    The input-lag bug is the precedent and it is exact: eleven of the sixteen
#    substances were unplayable while every .tres involved was correct. This
#    step doses each substance and MEASURES the goose - off-axis travel for
#    drift, peak turn rate for turn_mult, one-flap climb against a prediction
#    that includes the brain chemistry, plus the clock, the body scale and
#    whether letting go stops you. tools/substancetest.gd.
#
#    Skipped by -Quick: it is about 90 s, because it flies sixteen geese.
# ---------------------------------------------------------------------------
if (-not $Quick) {
    Write-Host "`n=== substances ===" -ForegroundColor Cyan
    $r = Godot @('--headless','--no-header','--path',$root,'--','--probe','--substancetest','--failsafe:600') 720
    $subOut = $r.Out
    $subCode = $r.Code
    $subLines = ($subOut -split "`r?`n") | Where-Object { $_ -match '^\[subs\]' }
    $subLines | ForEach-Object { Write-Host $_ }
    if ($subCode -ne 0) {
        Fail "substances" "exit $subCode"
    } elseif (-not ($subLines -match 'PASS')) {
        Fail "substances" "no [subs] PASS line"
    } elseif ((ScriptErrors $subOut).Count -gt 0) {
        Fail "substances" "SCRIPT ERROR: $((ScriptErrors $subOut)[0])"
    } else {
        Pass "substances" ($subLines | Where-Object { $_ -match 'PASS' })
    }
}

# ---------------------------------------------------------------------------
# 5b. THE FLIGHT. Half this game is migrations - seven of them - and until this
#     step the only thing any check knew about one was that the campaign loop
#     reached COMPLETE. That proves the flight ENDS; it says nothing about
#     whether the bird answers the stick while it is happening, which is the
#     same gap that hid a four-second input lag for the life of the project.
#
#     Four asserted channels (climb, dive, dive-beats-climb, the honk rally) and
#     two OBSERVED ones. The lateral rows are observed on purpose: the corridor
#     crossing measures 5.78 m/s against a constant that says 17.0, and that is
#     unexplained. tools/migtest.gd carries the full list of what was ruled out.
# ---------------------------------------------------------------------------
if (-not $Quick) {
    Write-Host "`n=== flight ===" -ForegroundColor Cyan
    $r = Godot @('--headless','--no-header','--path',$root,'--','--probe','--migtest','--failsafe:300') 420
    $migOut = $r.Out
    $migCode = $r.Code
    $migLines = ($migOut -split "`r?`n") | Where-Object { $_ -match '^\[mig\]' }
    $migLines | ForEach-Object { Write-Host $_ }
    if ($migCode -ne 0) {
        Fail "flight" "exit $migCode"
    } elseif (-not ($migLines -match 'PASS')) {
        Fail "flight" "no [mig] PASS line"
    } elseif ((ScriptErrors $migOut).Count -gt 0) {
        Fail "flight" "SCRIPT ERROR: $((ScriptErrors $migOut)[0])"
    } else {
        Pass "flight" ($migLines | Where-Object { $_ -match 'PASS' })
    }
}

# ---------------------------------------------------------------------------
# 6. THE CREDIT ROLL, MEASURED. The ending's fifth beat is slabs walking up the
#    fairway, and its drive has been wrong twice - both times a speed nobody
#    could see without watching the ending for four to six minutes. Physics runs
#    headless, so the speed can just be measured. main.gd::_roll_test().
# ---------------------------------------------------------------------------
Write-Host "`n=== credit roll ===" -ForegroundColor Cyan
$r = Godot @('--headless','--no-header','--path',$root,'--','--probe','--rolltest') 360
$rollOut = $r.Out
$rollCode = $r.Code
$rollLines = ($rollOut -split "`r?`n") | Where-Object { $_ -match '^\[roll\]' }
$rollLines | ForEach-Object { Write-Host $_ }
if ($rollCode -ne 0) {
    Fail "credit roll" "exit $rollCode"
} elseif (-not ($rollLines -match 'PASS')) {
    Fail "credit roll" "no [roll] PASS line"
} elseif ((ScriptErrors $rollOut).Count -gt 0) {
    Fail "credit roll" "SCRIPT ERROR: $((ScriptErrors $rollOut)[0])"
} else {
    Pass "credit roll" ($rollLines | Where-Object { $_ -match 'measured' })
}

# ---------------------------------------------------------------------------
# 6b. THE CLAIMS GATE. The only step pointed at the DOCUMENTS rather than at the
#     game: every number a doc writes down is recomputed from the booted project
#     and compared, and every window feeltest.gd enforces is compared against the
#     argument docs/FEEL_TARGETS.md makes for it.
#
#     It is here rather than at the end because it is fast (about a second) and
#     because a stale doc is the thing most likely to have misled whoever is
#     reading this output. Seven live stale facts across four root documents on
#     the day it was written. See tools/doctest.gd and docs/CLAIMS.md.
# ---------------------------------------------------------------------------
Write-Host "`n=== claims ===" -ForegroundColor Cyan
$r = Godot @('--headless','--no-header','--path',$root,'--','--doctest') 360
$docOut = $r.Out
$docCode = $r.Code
$docLines = ($docOut -split "`r?`n") | Where-Object { $_ -match '^\[doctest\]' }
$docLines | ForEach-Object { Write-Host $_ }
if ($docCode -ne 0) {
    Fail "claims" "exit $docCode"
} elseif ($docOut -notmatch '\[doctest\] PASS') {
    Fail "claims" "no [doctest] PASS line"
} elseif ((ScriptErrors $docOut).Count -gt 0) {
    Fail "claims" "SCRIPT ERROR: $((ScriptErrors $docOut)[0])"
} else {
    Pass "claims" ($docLines | Where-Object { $_ -match 'PASS' })
}

# ---------------------------------------------------------------------------
# 6c. THE AUDIO GATE. Opens every WAV and checks it is what its name claims: a
#     bed loops and is long enough to be a bed, a one-shot is short enough to be
#     a one-shot, nothing is silent or clipping, and the sixteen layered stems
#     share a length. It cannot tell you anything SOUNDS good and says so.
#
#     The bug it exists for is in the record: the truck stop's "rain" was a
#     0.700 s goose hiss that never looped, and every existence check passed it.
# ---------------------------------------------------------------------------
Write-Host "`n=== audio ===" -ForegroundColor Cyan
$r = Godot @('--headless','--no-header','--path',$root,'--','--audiotest') 360
$audOut = $r.Out
$audCode = $r.Code
$audLines = ($audOut -split "`r?`n") | Where-Object { $_ -match '^\[audio\]' }
$audLines | ForEach-Object { Write-Host $_ }
if ($audCode -ne 0) {
    Fail "audio" "exit $audCode"
} elseif ($audOut -notmatch '\[audio\] PASS') {
    Fail "audio" "no [audio] PASS line"
} elseif ((ScriptErrors $audOut).Count -gt 0) {
    Fail "audio" "SCRIPT ERROR: $((ScriptErrors $audOut)[0])"
} else {
    Pass "audio" ($audLines | Where-Object { $_ -match 'PASS' })
}

# ---------------------------------------------------------------------------
# 6d. THE FOOTPRINT GATE. prop_models*.gd::build() sizes every model with
#     `want / footprint(kind)`, so a declared box that disagrees with the mesh
#     makes every `size:` placement of that kind wrong by exactly that ratio.
#     Nothing had ever compared the two.
#
#     ASSERTS that the meshes do not drift. REPORTS that 11 of 15 declarations
#     disagree with them - correcting one rescales the model non-uniformly,
#     which is a look and therefore the human's call. D-036.
# ---------------------------------------------------------------------------
Write-Host "`n=== footprints ===" -ForegroundColor Cyan
$r = Godot @('--headless','--no-header','--path',$root,'--','--probe','--geomtest') 360
$geoOut = $r.Out
$geoCode = $r.Code
$geoLines = ($geoOut -split "`r?`n") | Where-Object { $_ -match '^\[geom\] (PASS|FAIL|REPORTED|  )' }
$geoLines | ForEach-Object { Write-Host $_ }
if ($geoCode -ne 0) {
    Fail "footprints" "exit $geoCode"
} elseif ($geoOut -notmatch '\[geom\] PASS') {
    Fail "footprints" "no [geom] PASS line"
} elseif ((ScriptErrors $geoOut).Count -gt 0) {
    Fail "footprints" "SCRIPT ERROR: $((ScriptErrors $geoOut)[0])"
} else {
    Pass "footprints" ($geoLines | Where-Object { $_ -match 'PASS' })
}

# ---------------------------------------------------------------------------
# 7. THE WHOLE CAMPAIGN, HEADLESS, IN ABOUT TWENTY SECONDS. The strongest check
#    in the project and the cheapest: it drives all seven legs, all seven
#    flights, the results card, the roster and the ending. If it stops early,
#    read the [loop] t=... phase=... lines - it prints what it is stuck behind.
# ---------------------------------------------------------------------------
if (-not $Quick) {
    Write-Host "`n=== full campaign ===" -ForegroundColor Cyan
    $r = Godot @('--headless','--no-header','--path',$root,'--','--probe','--loop-test') 360
    $loopOut = $r.Out
    $loopCode = $r.Code
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
# 8. RENDER AND LOOK. Optional, because it needs a real display and about a
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

# ---------------------------------------------------------------------------
# 12. THE GATE TABLE IN docs/HANDOFF.md, AGAINST WHAT THE GATES JUST PRINTED.
#
#    CLAUDE.md's rule is "any number you write into a document gets a row in
#    docs/CLAIMS.md, or gets deleted" - and the table that describes the gates
#    broke it. Its count column said 148 substance checks when the gate printed
#    165, and 190 claims when doctest printed 189. Both were stale for a whole
#    session and nothing could say so, because doctest recomputes numbers from
#    the BOOTED PROJECT and cannot know what a gate prints without running it.
#
#    This script can: it has just run all eleven and kept every PASS line. So
#    the rule here is deliberately dumb and needs no per-gate configuration -
#    EVERY INTEGER IN THE DOC CELL MUST APPEAR IN THAT GATE'S PASS LINE. A cell
#    reading "22 metrics, 13 asserted" is satisfied by "22 measurements, 13
#    asserted, all in window"; a cell with no integers in it (the credit roll,
#    the campaign) asserts nothing and is skipped, which is stated below rather
#    than being silent about it.
#
#    The map is also checked BOTH WAYS. A gate added to this script without a
#    row, or a row for a gate that no longer runs, fails here - which is the
#    other half of how the table went stale: rows outlive the thing they
#    describe.
# ---------------------------------------------------------------------------
Write-Host "`n=== the gate table ===" -ForegroundColor Cyan

$gateFlags = [ordered]@{
    "compile gate" = "--gate"
    "invariants"   = "--selftest"
    "controller"   = "--probe --inputtest"
    "feel"         = "--probe --feeltest"
    "substances"   = "--probe --substancetest"
    "flight"       = "--probe --migtest"
    "credit roll"  = "--probe --rolltest"
    "claims"       = "--doctest"
    "audio"        = "--audiotest"
    "footprints"   = "--probe --geomtest"
    "full campaign" = "--probe --loop-test"
    # Its own row, so the reverse check below does not call it an orphan. The
    # cell states no number on purpose: this step's count is not known until
    # after the loop that would have to check it.
    "the gate table" = "verify.ps1"
}

$tick = [char]0x60
$handoffPath = Join-Path $root "docs\HANDOFF.md"
$docRows = @{}
# ONLY THE ROWS UNDER THE GATE HEADING. The first version matched any table
# row starting with a backtick and swept up docs/HANDOFF.md's document index
# and half of section 4 - 26 spurious failures, each politely reporting that
# nothing in this script runs `docs/MULTIPLAYER_SPEC.md`.
$inTable = $false
foreach ($line in (Get-Content $handoffPath -Encoding UTF8)) {
    if ($line -match "^#+ ") { $inTable = ($line -match "gates, and what each one"); continue }
    if (-not $inTable) { continue }
    if ($line -notmatch "^\|\s*$tick") { continue }
    $cells = $line.Split("|")
    if ($cells.Count -lt 4) { continue }
    $flag = $cells[1].Trim().Trim($tick)
    $docRows[$flag] = $cells[3].Trim()
}

$checked = 0
$skipped = @()
# Local, not \:fail - an earlier gate failing must not suppress this
# step's own verdict line.
$tableFail = $false
foreach ($name in $gateFlags.Keys) {
    $flag = $gateFlags[$name]
    if (-not $docRows.ContainsKey($flag)) {
        Fail "the gate table" "$flag runs in this script and has no row in docs/HANDOFF.md"; $tableFail = $true
        continue
    }
    $cell = $docRows[$flag]
    $want = @([regex]::Matches($cell, "\d+") | ForEach-Object { $_.Value })
    if ($want.Count -eq 0) { $skipped += $flag; continue }
    if (-not $script:passLines.ContainsKey($name)) {
        $skipped += "$flag (did not run)"
        continue
    }
    $line = $script:passLines[$name]
    $got = @([regex]::Matches($line, "\d+") | ForEach-Object { $_.Value })
    foreach ($n in $want) {
        $checked++
        if ($got -notcontains $n) {
            Fail "the gate table" ("docs/HANDOFF.md says $flag is `"$cell`", but the gate printed " +
                "`"$line`" - $n is not in it"); $tableFail = $true
        }
    }
}
foreach ($flag in $docRows.Keys) {
    if ($gateFlags.Values -notcontains $flag) {
        Fail "the gate table" "docs/HANDOFF.md has a row for $flag and nothing here runs it"; $tableFail = $true
    }
}
if ($skipped.Count -gt 0) {
    Write-Host "      stating nothing, so checking nothing: $($skipped -join ", ")" -ForegroundColor DarkGray
}
if (-not $tableFail) { Pass "the gate table" "$checked numbers in docs/HANDOFF.md match the gate that produced them" }

# ---------------------------------------------------------------------------
# 13. THE PLAYER'S SAVE, AFTER EVERY GATE HAS RUN. See the snapshot at the top.
#     A failure here means some run launched with arguments wrote to the file a
#     player's settings, best score, unlocks and seen briefings live in - or that
#     the game itself was being played while this script ran, which would also
#     legitimately change it. prefs.gd::hermetic is where to look first.
# ---------------------------------------------------------------------------
Write-Host "`n=== the player's save ===" -ForegroundColor Cyan
$saveAfter = SaveStamp $savePath
if ($saveDirOk) {
    if ($saveAfter -ne $saveBefore) {
        Fail "the player's save" ("a gate wrote $savePath`n      before: $saveBefore`n      after:  $saveAfter")
    } else {
        Pass "the player's save" "untouched by every step above ($saveAfter)"
    }
}

# --- verdict ----------------------------------------------------------------
if ($script:fail) {
    Write-Host "`nVERIFY FAILED" -ForegroundColor Red
    exit 1
}
Write-Host "`nVERIFY PASSED" -ForegroundColor Green
exit 0
