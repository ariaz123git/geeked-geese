# Geeked Geese

A physics comedy made in Godot 4.7.1. You are a Canada goose flying your flock
from a suburban retention pond to a Florida golf course, and on the way you eat
parody "substances" that each change how the controls work: input lag, a camera
that wanders off without you, movement that only goes in right angles. Geese
lost on the flights stay lost, so the flock you land with is your score.

<!-- GIF pending (Ariaz records a clip): uncomment when docs/media/gameplay.gif exists.
![Gameplay](docs/media/gameplay.gif)
-->

**Early and unpolished.** The whole campaign runs from start to finish — seven
legs, seven flights, two bosses and an ending — but balance and feel are still
being tuned through play, and several designed features are queued rather than
built (`docs/HANDOFF.md` §3).

## Run it

1. Install Godot 4.7.1 — the plain **Godot Engine** download, not Godot Engine – .NET.
   There's no installer; unzip and double-click the `.exe`. That file *is* Godot.
2. Godot → **Import** → pick `project.godot` in this folder → **Import & Edit**.
3. **First open takes 15–30 seconds** while it imports 40 textures and 68 .wav files.
   That only happens once.
4. Press **F5**.

GDScript only, no external dependencies, no imported art or audio. Runs on the
GL Compatibility renderer, so it works on any GPU including integrated graphics.

## Controls

| | |
|---|---|
| **WASD** | move (camera-relative) |
| **Mouse** | look — free camera, auto-follow resumes ~2.5s after you stop |
| **Scroll wheel** | zoom |
| **SPACE** | flap — **you need a run-up on the ground**, or you just hop |
| **SHIFT** | dive |
| **H** / **F** | HONK |
| **E** *(hold)* | build a dose — **release** inside the green band |
| **Q** | zone: share what you're on with the flock · flight: hand off the lead |
| **G** | at the flock pen: make the goose you are standing by the designated driver |
| **J** / **K** | swing the camera |
| **TAB** | objectives: full · compact · off |
| **ESC** | pause · settings · **Almanac** |
| **R** | restart run (press twice) |
| **ENTER** | continue past the migration results |

Gamepad: left stick move, **right stick camera** (Invert Y applies), A flap,
B honk, X eat, Y share, RB dive, LB name the designated driver at the flock pen,
**Back** objectives. **Start** pauses; in menus the D-pad moves and **A** presses,
and A also continues past every results card.

The mouse is captured on launch. **Escape** releases it; clicking the window
grabs it back.

## How it's built and verified

Built with [Claude Code](https://claude.com/claude-code). An agent cannot play
the game, so nothing counts as working until a check it can run headless says so. `.\verify.ps1` runs 13 gates, about seven minutes in all:

| gate | what it checks |
|---|---|
| `--gate` | every script compiles and every resource loads, inside the booted project where the autoloads exist |
| `--selftest` | the game agrees with itself — route, clocks, substance data, objectives, asset keys. 968 invariants as of 2026-10-11, each one a bug that got through once |
| `--probe --inputtest` | real key, gamepad and mouse events sent through the path a player's input takes: the bird moves, every menu opens and closes, every Settings row reaches what it controls, a pad can play past the first leg |
| `--probe --feeltest` | controller response — time to top speed, slide after release, whether a held flap converges — measured against windows argued in `docs/FEEL_TARGETS.md` |
| `--probe --substancetest` | every substance dosed, and its effect on the bird measured |
| `--probe --migtest` | the flight answers the stick, and the seven flights differ |
| `--probe --rolltest` | the credit roll moves, and the ending's honk starts it |
| `--probe --loop-test` | the whole campaign, seven legs and the ending, played headless |
| `--audiotest` | every WAV is what its name says: beds loop, one-shots are short, nothing is silent or clipped |
| `--probe --geomtest` | models are the size their tables say, and nothing edible is buried in a solid |
| `--doctest` | every number the documents state is recomputed from the project (`docs/CLAIMS.md`), so the docs cannot quietly go stale; several counts in this README are checked this way |
| the gate table | the counts in `docs/HANDOFF.md` match what the gates just printed |
| the player's save | test runs never read or write the player's settings, scores or unlocks; `verify.ps1` hashes the save before the first gate and after the last |

A gate passes only on its exact PASS line and exit code 0, and any `SCRIPT
ERROR` fails it even then. The rules the agent works under are part of the repo:
`CLAUDE.md` (standing rules), `docs/HANDOFF.md` (current state and the queue),
`docs/DECISIONS.md` (every decision, and whose it was) and
`docs/RECENT_FAILURES.md`.

**All assets are procedural.** 23 seamless-tiling surface textures plus one icon
per substance from `tools/gen_textures.py` (numpy and Pillow);
39 SFX and 7 zone ambience beds from `tools/gen_audio.py`, including three honk
variants that pitch-shift per substance and with body size;
22 music stems from `tools/gen_music.py` (numpy and the Python standard library,
like the audio script). The outputs are committed; re-run any of the three to
regenerate them.

### Running the checks

```
.\verify.ps1            # every gate, about seven minutes
.\verify.ps1 -Quick     # skips the slow three
.\verify.ps1 -Shots     # also renders every zone into .\shots\
```

`verify.ps1` finds Godot through `$env:GODOT`, then `godot` on `PATH`, then a
default path written in the script; point it at the `*_console.exe`. Any gate
also runs on its own:

```
godot --headless --path . -- --gate 2>&1 | grep '^\[gate\]'
godot --headless --path . -- --selftest 2>&1 | grep '^\[selftest\]'
godot --headless --path . -- --probe --loop-test
```

**Render probes** — the only way to check anything visual:
```
godot --path . --rendering-driver opengl3 -- --probe --leg:3          # any leg, 1-7
godot --path . --rendering-driver opengl3 -- --probe --migration
godot --path . --rendering-driver opengl3 -- --probe --fx --sub:fly_agaric
godot --path . --rendering-driver opengl3 -- --probe --ui             # menus
godot --path . --rendering-driver opengl3 -- --probe --close          # goose closeup
godot --path . --rendering-driver opengl3 -- --probe --leg:3 --boss   # the Ranger
godot --path . --rendering-driver opengl3 -- --probe --finale         # the ending
```

**Two flags that matter more than they look:**

`--out:<dir>` — where the PNGs go. The default is `/tmp` on Linux and
`<user data>/shots` on Windows. It used to be the bare literal `/tmp` at twelve
call sites, and `Image.save_png()` *returns* an error rather than raising one,
so on Windows every probe printed `[probe] wrote /tmp/gg_zone_0.png` while
writing nothing whatsoever. The probe now checks the return and exits non-zero
if any shot failed.

`--secs:N` — seconds between shots, and **the one to use for anything that
happens on a timer.** `--frames:N` counts frames, and every probe command in the
old docs was calibrated against a container rendering this project in software
at about 2 fps, where 26 frames is thirteen seconds. On a machine with a GPU the
same command is four tenths of a second — which is why `--probe --leg:3 --boss`
photographed an empty cul-de-sac three seconds before the Ranger arrives, and
looked exactly like a boss that had failed to spawn.

None of this can tell you whether the goose *feels* good. That takes playing it.

## Project layout

```
scripts/core/       the director (main.gd), the autoloads, substances, objectives
scripts/goose/      controller, camera, honk, both goose models
scripts/migration/  the flight between zones
scripts/world/      zones, bosses, cats, people, props, pickups
scripts/ui/         HUD, pause menu and settings, briefing cards, Almanac, results
data/substances/    one .tres per substance
shaders/            screen_fx.gdshader, the one post-processing shader
textures/ audio/    generated assets, committed
tools/              the gates and reports (gate.gd, *test.gd), the asset generators (gen_*.py)
docs/               design specs, current state, decisions, claims
verify.ps1          runs every gate
```

## The loop

**THE FLYWAY** — a finite journey from a suburban retention pond to a Florida
golf course: seven legs, seven flights, and an arrival. About 45 minutes. It
ends, and the ending is playable.

**Zone** (sandbox, 2½–4 min) → **Migration** (fly the V to the next leg) →
repeat, eight times. Tolerance, flock condition and Almanac unlocks carry
across. Land short on a migration and you lose a minute of the next zone — a
soft fail, never a death.

**The flock is the stakes.** Geese are permanently lost on the flights and no
longer heal back to full between legs, so what you arrive in Florida with is the
run's real score. Your own bird can never be lost, so the journey always
finishes; the question is who finishes it with you.

Full route, intensity curve, flock balance and the ending are specced in
`docs/CAMPAIGN_SPEC.md`.

## What's in it

**17 substances**, all data-driven, each with its own control mutation, screen
treatment and honk pitch. Every one but bread names the real drug it's a joke
about, and every one carries a true, sourced fact.

| In-game | Mimics | What it does to your hands |
|---|---|---|
| Fermented Berries | Ethanol | Input lag, drift, ragdoll landings, smashes through props |
| Double-Double | Caffeine | 2× flap rate and **you cannot stand still** |
| Whippet | Nitrous oxide | 7 seconds of slow-motion, then you fall out of the sky |
| Math | Methamphetamine | Fastest thing in the game and **you cannot turn** |
| Grass | Cannabis | Slow, heavy, longest duration, **lowest** chaos multiplier |
| Special K | Ketamine | **The camera detaches from your bird** and drifts |
| Robo-Trippin' | DXM | Movement **snaps to 90°** |
| Molly | MDMA | Everything is wonderful; 13-second serotonin crash |
| Darts | Nicotine | Barely anything — and **3× tolerance per dose** |
| Catnip | Nepetalactone | Nothing to you. Turns every cat into your artillery. |
| Toad Slime | Bufotoxin / 5-MeO-DMT | Kaleidoscope trip you **cannot end early** |
| Fly Agaric | Muscimol | **Macropsia** — your body pulses between 0.35× and 2.8× |
| Gravy | Dimenhydrinate | **Deliriant** — spawns fake props and people |
| Bars | Alprazolam | Perfect steadiness, and **the HUD forgets to exist** |
| Percs | Oxycodone | No fall damage, nothing hurts, everything is slow |
| Acid | LSD | 34 seconds of flowing hue rotation; can't end it early |
| Bread | Nothing at all | You're **full**: nothing else goes down until it wears off |

**Systems:** tolerance (persists forever), comedowns, 5 named 2-way combos,
3-at-once blackout, dose sweet-spot arc, hallucinations, macropsia body scaling,
Goose Brain neurotransmitter HUD, per-zone objectives, Almanac unlocks,
persistent settings and best score.

**Eight zones:** the Retention Pond · the Strip Mall Lot · Suburbia (cul-de-sac, six houses, fenced
backyards, a trampoline, a kiddie pool, sprinklers, gnomes) · Cottage Country at
night · The Stopover (a dawn marsh) · The Cut Corn (a combine that does not look where it is going) · The Truck
Stop (3 a.m., rain, rigs that leave without you) · and the 18th green.

**The migration flight:** V formation, drafting economy, **lead rotation**,
thermals, headwind bands, transmission wires, wind turbines.

**Objectives gate the leg.** The timer does not just expire into the next
phase. Each zone has a set of primary objectives (you need most, never all),
bonus objectives that stream two at a time, and hidden objectives that only
reveal themselves when you stumble into them. Passing a leg well gives you more
clock next time; scraping through gives you less. Nothing hard-fails you out of
a run. Design rationale, the full objective list and the escalation curve are in
`docs/DESIGN_MISSIONS.md`.

**Controls onboarding.** A briefing card before the first zone and before the
first flight — the flight one includes an animated V-formation diagram that
shows lead rotation wordlessly — plus a short auto-dismissing recap on later
flights and a permanent CONTROLS reference in the pause menu. See
`docs/ONBOARDING_NOTES.md`.

**Two art styles.** Settings → Art style switches between a faceted polygons-only
low-poly goose (~570 triangles, no curved primitives anywhere) and the original
smooth-primitive one. The cats and the people follow the goose so the world stays
consistent. Switching is live.

**Game feel.** A `Juice` autoload provides hitstop, a global shake bus,
squash-and-stretch, pooled particle bursts and floating score text — all
respecting the existing FX-intensity and screen-shake accessibility sliders. The
hitstop composes with the nitrous slow-motion rather than fighting it; see
`docs/JUICE_NOTES.md`.

**Faceted environment props** — 20 low-poly models (minivan, shopping cart,
house, dumpster, trees, fences, gnomes) in `scripts/world/prop_models.gd`, and
every substance has a hand-built pickup model.

## Not built yet

`docs/HANDOFF.md` §3 has the ranked queue. Headlines:

- **Substances as keys** — one objective per zone from leg 2 that needs an
  *effect* (through things, a big flap, slow time) which at least two of that
  leg's substances provide. Decided in `docs/DECISIONS.md` D-091, not built.
- **The Ranger's leg 6 exam** — `docs/BOSS_DESIGN.md` §2.1.4; the corn field it
  was written for exists, and the blocker is a sound that needs a human ear.
- **Multiplayer.** Specced in `docs/MULTIPLAYER_SPEC.md` — local split-screen
  only; online is argued against on technical grounds.

Claims in this file about mechanics come from gates whose output was read.
Whether any of it is fun is decided by playing it.

## Where to change things

**Tuning the feel** — `scripts/goose/goose_controller.gd`, the `@export` groups
at the top. These decide whether the game is good. They're exported so you can
drag them in the inspector while it's running.

**Adding a substance** — drop a `.tres` in `data/substances/`. Picked up
automatically at boot, no code change. Copy `berries.tres` as a template.

> **The rule:** a substance must never be only a number that goes up. Every one
> needs a *control mutation* — something that changes how the player's hands
> work. If it only edits `speed_mult`, delete it.

**Screen effects** — `shaders/screen_fx.gdshader`, one branch per substance
family (wobble / jitter / slowmo / trip / macropsia / acid / blackout). This is
where the visual budget should go; it's shader work, so one person can do it all.

**The flight** — `scripts/migration/migration.gd`. `DRAIN_LEAD` and
`DRAIN_DRAFT` are the whole balance, tuned so a 75-second flight forces 2–3
handoffs. If a player can hold the point the entire way, lead rotation is
decorative and the sequence is pointless.

**Adding a zone** — copy the shape of `zone_strip_mall.gd`, then add it to
`ROUTE` in `scripts/core/main.gd` and give it a branch in
`mission_defs.gd::for_zone()`. A zone only has to expose `goose`, `camera_rig`,
and optionally `zone_title()`, `mission_zone_id()` and `objectives()`.

## Accessibility

The substance screen effects are strong on purpose. **Settings → FX intensity**
scales all of them, down to zero, without touching the mechanics. Screen shake
has its own slider. Both persist.

## Known trade-off: the levels are procedural

Zones, the goose, and all UI are built in code rather than as `.tscn` scenes.
That was deliberate for a first-playable — it means the project runs correctly
the first time you open it with no missing references. It is **the wrong way to
do level design.** Once the controller feels right, `zone_strip_mall.gd` should
become a real scene you can drag around in the editor.

Input actions are also registered in code (`scripts/core/game.gd`) rather than
in Project Settings, for the same reason. Copy them into the Input Map and
delete `_setup_input()` whenever you like; nothing else depends on it.

## The gate before building anything else

Hand it to someone who's never seen it. If they're laughing inside 90 seconds
with no explanation from you, build the rest. If you have to explain the joke,
go back to the controller numbers.

## License

MIT — see [`LICENSE`](LICENSE). Copyright (c) 2026 Ariaz Askarkani.
