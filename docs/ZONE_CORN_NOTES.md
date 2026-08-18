# LEG 6 — THE CUT CORN · build notes

**Status:** built, compiles, renders, **never played by a human.** Every
judgement below about difficulty, pacing and feel is inference from geometry and
from six rendered frames. Nothing in here has been tested by anyone who can hold
a controller.

Spec: `CAMPAIGN_SPEC.md` §2.6 (the leg), §1.3 (what it contributes to the
teaching order: **cover and open ground**), §2.11 and Part 3 (intensity **7**,
the run's second peak), §4.3 (`rest()` on arrival), M9 in Part 8 (the build
items).

---

## 1. Files

| File | What |
|---|---|
| `scripts/world/zone_corn.gd` | the zone (~1,150 lines) |
| `scripts/world/prop_models_corn.gd` | 13 models (~1,100 lines) |
| `scripts/core/mission_defs_corn.gd` | 6 primaries, 4 bonuses, 2 hidden |
| `docs/ZONE_CORN_NOTES.md` | this |

Nothing else was touched. The two integration lines are in §7.

---

## 2. Integration — the exact edits somebody else has to make

**`scripts/core/main.gd`**, `ROUTE`, leg 6 (currently the suburbia placeholder):

```gdscript
	{"zone": "res://scripts/world/zone_corn.gd",       "name": "THE CUT CORN",       "seconds": 180.0},
```

**`scripts/core/mission_defs.gd`**, two additions, both mirroring what
`mission_defs_cottage.gd` already does. Beside the existing `COTTAGE` preload:

```gdscript
const CORN := preload("res://scripts/core/mission_defs_corn.gd")
```

and inside `for_zone()`, immediately after the `&"cottage"` branch:

```gdscript
	if zone_id == &"corn":
		return _filter_by_leg(CORN.corn() + _universal_hidden(), leg)
```

Both were applied to a throwaway copy at `/tmp/gg_corn/` and every screenshot in
§4 was taken through them.

**Nothing else is required.** The zone exposes `goose`, `camera_rig`,
`zone_title()` and `mission_zone_id()`, so `main.gd::_load_zone()` wires the HUD,
the hallucination layer and the mission system with no special cases.

---

## 3. The design, and the one idea it is built on

§1.3 assigns leg 6 exactly one contribution: **cover and open ground**. §2.6
states the inversion — *"Every zone before this one has a safe ground and a
dangerous sky. This one inverts it."* Three mechanics carry that and nothing
else in the file is load-bearing.

### 3.1 Standing corn is cover, and cover is blindness

A 3.1 m wall of ~2,960 dry stalks in one MultiMesh, **with no colliders at all.**
You walk into it, not up against it. Nothing can see you and you can see nothing,
including the combine, which is why the machine has an audio cue at all.

It is also the only place in the game where **gaining altitude costs you
something**. `_in_corn()` has a height test: above `CORN_H` you are not in cover
even though your shadow is. Three metres up you can see the whole field and the
whole field can see you.

### 3.2 The open stubble is exposure, and the layout is the mechanic

The corn (cover) is east. The farmyard — grain bin, trucks, **five of the eight
pickups**, the flock pen — is north-west. Between them is fifteen to twenty-five
metres of nothing with the combine's lane running down the middle of it.

**You cannot get what you want without crossing, and you cannot cross without
timing the machine.** That is done entirely with geometry. No new system, no
stealth code, no awareness meter.

### 3.3 The combine eats the cover

Every pass takes one more 1.05 m row. `_cut_x` marches east all leg. Measured:
a pass is 62 m at 5.4 m/s plus a 1.7 s headland turn = 13.2 s, so ~13 passes in
180 s, so **~14 m of the 39 m of standing corn is gone by the buzzer.** Verified
numerically (§4.6). `_advance_cut()` refuses the last four rows, so the mechanic
can never be deleted by waiting.

The wall you hid behind is smaller every time you come back to it. Nobody says
this out loud and nothing in the UI mentions it.

---

## 4. What was rendered, what it showed, and what had to be fixed

Six render rounds under `xvfb-run` + `--rendering-driver opengl3`. **Every round
found something.** The list below is the honest one.

| # | Shot | What it showed |
|---|---|---|
| 1 | default spawn | zone reads; **four bugs** (below) |
| 2 | default spawn | corn density fixed, combine now in frame |
| 3 | inside the corn | cover works — and the camera was above it |
| 4 | the lane, next to the machine | combine + CLOSE PASS + HARVESTED all firing |
| 5 | grain bin roof | `silo_business` fires; roof clipped to white |
| 6 | farmhouse roof | **trees growing through the farmhouse** |

### Fixed after looking

1. **The opening frame pointed the wrong way.** `goose_camera.gd` starts its yaw
   at 0 and only ever chases the goose's *velocity*, never its heading — so on
   frame one of every zone the camera looks down world **−Z** whatever the bird
   is doing. (`zone_cottage.gd` gets its lake on screen by putting the lake at
   −Z, not by setting a heading; nothing documents this.) The first build faced
   the bird north at the farmyard and photographed its face against empty
   stubble. The shot is now composed at −Z, the heading is 0 to match, and the
   **combine starts at the far headland coming toward you** instead of behind
   you.
2. **The corn was not cover.** At 1.30 × 1.15 m spacing you could see the
   treeline straight through it — decoration, not concealment. Now 1.05 × 0.85,
   with five leaves per stalk instead of four and half again the leaf span. A
   wider leaf occludes several times more per triangle than another whole plant.
3. **The corn was too short, and that was the worst bug in the build.** At 2.1 m
   the goose was hidden and the *camera* — which sits at ~3 m — was looking
   straight over the top. The cover mechanic existed for the bird and not for
   the person playing, which is the same as it not existing. Corn is now 3.10 m
   and the camera arm pulls from 6 m to 3.5 m while you are in it.
4. **Two of the three yard trees were growing through the farmhouse.** They were
   generated from a loop with a `sin()` offset and two landed inside the house
   box. They have no colliders, so nothing was ejected and nothing errored — it
   was silently wrong and only visible from a viewpoint nobody had photographed.
   Now three literal coordinates, checked against the house box and the bin pad.
5. **Three surfaces clipped to white.** The sun is 74° up, so anything facing
   upward is the most-lit thing in the game. The grain bin's cone, its seam
   struts and the farmhouse roof all rendered as flat white shapes. All three
   are now authored far darker than looks right in the source.
6. **The grain bin came out the colour of sandstone.** The ambient here is a
   dirty-gold bounce off forty metres of red clay, so a neutral grey lands warm.
   The bin is pushed ~12% blue to come out neutral on screen — it is the zone's
   only landmark and it has to read as galvanised steel.
7. **The sky was a flat grey ceiling.** `fog_sky_affect` 0.55 → 0.28 and
   `sky_curve` 0.32 → 0.14. At the old values the zone read as *overcast*, which
   is leg 2's light and the exact opposite of the brief.
8. **The soil was the colour of a running track.** The `dirt` texture multiplies
   in with a high mean, so the tint has to sit well below the value you want.

### 4.6 Verified by instrumented run, not by eye

```
[cut] rows=37 per_row=80 total=2960
[cut]  after  6 passes: cut_x=8.3  visible=2480
[cut]  after 12 passes: cut_x=14.6 visible=2000
[cut]  after 18 passes: cut_x=20.9 visible=1520
[cut]  after 24 passes: cut_x=27.2 visible=1040
[cut]  after 30 passes: cut_x=33.5 visible=560
[cut] FINAL cut_rows=33 cut_x=36.65 visible=320 (floor is 4 rows = 320)
```

Also seen firing in renders, with the objective counter moving: `INTO THE CORN`,
`CLOSE PASS` (1/5), `HARVESTED` (1/4, on a hay bale the machine ate unprompted),
`TOP OF THE SILO` (objective completed, done-text toast shown).

**Not yet seen fire in a render:** `OPEN GROUND`, `BROKE COVER`, and both hidden
objectives. All four need player input over several seconds, which the probe
cannot supply. Their arithmetic is checked in §6 but a human should confirm them
in the first five minutes of playtesting.

---

## 5. Deliberate deviations from the spec, and why

| Spec says | Built | Why |
|---|---|---|
| "a **combine** working the boundary" that will "run you over, throw you thirty metres **and take the props with it**" | An Area3D and a punt. The machine has **no solid collider at all.** | A 5.6 m kinematic body crossing the map at 5.4 m/s is the exact shape of this project's two most expensive bugs: a `CharacterBody3D` squeezed between a moving `StaticBody3D` and the ground has nowhere to resolve to, and a `RigidBody3D` that starts a frame inside one is ejected to an absurd coordinate (bins to y = −1120). The Area reaches every body on the frame it touches it and clears it before penetration is a concept. The read is identical. The cost is that you cannot stand on the combine, which the spec does not ask for. |
| "props recycled from `prop_models.gd` (minivan → grain truck, house → farmhouse…)" | Farmhouse, fences, trees, bins, chairs and the BBQ are recycled. **The grain truck is a new model.** | A minivan does not read as a grain truck at any distance, and the truck's open grain box is where one of two ethanol sources lives — it needed to be a container you can look into. |
| "A grain **silo**" | A **corrugated steel grain bin**, squat and round. | A concrete tower silo is a northern dairy object. A corn farm in Sampson County stores shelled corn in a galvanised bin. It is the difference between the zone reading as North Carolina and reading as Wisconsin. The silo survives, as promised; it is just the right silo. |
| "a **chained farm dog**" | Chained, barks inside 16 m, turns to track you, never moves. | A loose dog is a second pursuer and the zone already has one. A chained one is a three-metre circle of extremely loud danger you route around and that never catches you. |
| Zone clock 180 s, mission id `&"corn"`, 4 of 6 primaries | As specified. `required_primaries(6)` computes to 4 with 6 primaries; no override needed. | — |
| Six substances: berries, double-double, grass, math, darts, whippet | Exactly those six, in **eight** pickups, **five of them in the farmyard**. | The shelf is not thin because there is less of it — it is thin because getting to it costs a crossing every time. |

### Where the spec was silent, and what I decided

- **Field size** 88 × 88 m, flat, no elevation change anywhere. Cottage Country
  owns verticality; this zone owns the horizontal plane. A bump in it would give
  the player a way to break line of sight that is not the corn, which is the one
  thing that has to stay unique.
- **Where the yard goes.** North-west corner, diagonally opposite the corn. This
  is the single most important decision in the file and it is what makes "cover
  and open ground" a *level* rather than a *feature*.
- **What "cover" pays.** There is no stealth system and I did not add one. Cover
  pays in score labels (`INTO THE CORN` / `BROKE COVER`) and in the combine
  ignoring you while you are in it, and it costs you sight.
- **The combine leans toward an exposed goose**, bounded to about 4.5 m off its
  lane. Enough to reach the crossing strip, never enough to follow you across
  the field. `BOSS_DESIGN.md` is explicit that a pursuit boss is a genre this
  controller does not have, and the moment the combine chases, the corn stops
  being a decision and becomes the only correct answer.
- **The camera pulls in inside the corn** (6.0 → 3.5 m, height 2.2 → 1.9). Both
  are `@export`s the rig re-reads every frame; `main.gd`'s own probe writes
  `distance` the same way. The rig's authored values are captured at spawn
  rather than hardcoded, so a future retune of `goose_camera.gd` is not fought.
- **Two lane props start in the combine's path.** They are eaten in the first
  thirty seconds whether the player does anything or not. That is deliberate:
  the objective ticks twice unprompted and *demonstrates* the verb before
  charging for it, and it is the cheapest possible insurance against a primary
  that can never complete — which this project has already shipped once, in
  suburbia.

---

## 6. Objective numbers, and where they came from

`target_scale(6)` = **1.9** (the cap). `reward_scale(6)` = **1.5**.
`required_primaries(6)` = **4 of 6**.

| id | kind | base → leg 6 | notes |
|---|---|---|---|
| `close_quarters` | P | 3 → **5** (cap 5) | ~13 machine passes available; 2 s scoring cooldown |
| `run_the_open` | P | 2 → **4** (cap 4) | ≥3 s exposed per crossing, must re-arm near cover |
| `harvest_festival` | P | 2 → **4** (cap 4) | 2 free, 12 candidates |
| `silo_business` | P | 1 (`no_scale`) | one landing pad |
| `sweet_science` | P | 3 → **4** (cap 4) | **capped only here** — six substances, eight pickups |
| `loud_lad` | P | 10 → **19** | anti-stall; free and always available |
| `bale_out` | B | 2 → **4** (cap 5) | six round bales |
| `share_the_wealth` | B | 2 → **4** | the only objective with a real cost |
| `variety_pack` | B | 5 → **8** (unique, half-rate) | ≥14 distinct labels exist |
| `low_flying_aircraft` | B | 3 → **6** | `DESIGN_MISSIONS.md` §206's leg-5+ mastery constraint |
| `oldest_trick` | H | fixed | corn → close pass → break cover, in 14 s |
| `redundant` | H | fixed | wreck the scarecrow |

`sweet_science` is the only objective in the game with a zone-specific cap. Leg 6
ships six substances rather than sixteen; the uncapped leg-6 multiplier asks for
six clean doses off eight pickups, which is not escalation, it is the objective
system lying to the player.

**Only two bonus rows are ever on screen** (`mission_hud.gd::MAX_BONUS_ROWS`, with
a queue that refills as they complete). All four exist and are tracked. This is
not a bug and it is not new.

---

## 7. What is stubbed, faked or missing

1. **THE COMBINE'S ENGINE SOUND IS A PLACEHOLDER AND IS THE FIRST THING TO
   REPLACE.** There is no engine sample in the project (`HANDOFF` §4: *"No
   zone-specific SFX anywhere"*), so it is `crash_heavy` pitched to 0.27 on a
   0.9 s cycle standing in for a diesel lug. **It is not cosmetic even though it
   lives in `_process`:** the corn is cover for the combine as well as for the
   goose, and sound is the only channel the player has for locating the machine
   while they are inside the wall. If this cue is wrong, cover is *unfair*
   rather than tense. It wants a real looping engine with distance falloff and a
   pitch that rises on the headland turn.
2. **The combine's reel does not turn.** It is baked into the single model mesh.
   Spinning it needs the reel split into its own child node — about twenty lines
   in `prop_models_corn.gd` plus a `_process` rotate.
3. **The dust plume is seven billboarded alpha quads**, not particles. It reads
   at forty metres, which is its job, but it does not react to the wind, the
   turn or the machine's speed.
4. **The zone borrows the parking-lot ambience** (`main.gd` loops
   `amb_parking_lot` for every zone). Same gap the cottage has.
5. **Music has no `corn` entry.** Every render printed
   `WARNING: Music: unknown zone 'corn', going quiet.` from `music.gd:409`.
   The leg is currently silent. **This is outside my file list and needs one
   line in `music.gd`.**
6. **No Almanac fact is wired.** The true one is sitting in the geometry already:
   waste grain in harvested fields is a major fuel source for migrating geese,
   and the twentieth-century spread of corn agriculture measurably changed where
   they migrate and winter. The spilled heap under the bin's chute exists
   precisely so that fact has somewhere to point.
7. **No crows fly.** They perch and rotate slightly. A scatter-when-honked-at
   would be five lines and is the obvious next gag.
8. **`Flock.rest()` does not match the spec for this leg** — see §9.

---

## 8. What a human should tune first, in order

1. **The combine's speed (`COMBINE_SPEED`, 5.4 m/s).** A waddling goose does
   4.2. Everything about this zone's danger is that one ratio and it has never
   been felt. If the machine is unfair, this is the knob — not the hazard box.
2. **`OPEN_MARGIN` (8 m) and `OPEN_HOLD` (3 s).** Whether "crossing the open
   ground" feels like a decision or like standing still waiting for a number.
   `OPEN_REARM` (4.5 m) is the sharpest of the three: a player who hovers eight
   metres from cover will never re-arm and may conclude the objective is broken.
3. **`close_quarters`' cap (5).** Named in `mission_defs_corn.gd` as the first
   thing to drop if leg 6 tests badly. `harvest_festival`'s cap (4) is second.
   **Do not touch `run_the_open`** — it is the objective that teaches the zone.
4. **The camera pull-in inside the corn** (3.5 m / 1.9 m). It is a strong,
   opinionated effect and it is the difference between the corn feeling like a
   place and feeling like a rendering glitch. It might be too strong.
5. **Corn height (3.10 m).** It is tall for real corn. It is that tall because
   the chase camera sits at ~3 m and anything shorter defeats the mechanic. If
   the camera is ever retuned, retune this with it — **they are one number.**
6. **The palette.** The zone is authored against a 74° sun and a gold ambient;
   several surfaces are authored much darker or bluer than they look on screen.
   If the environment block is touched, the grain bin's colour, its roof, the
   farmhouse roof and the soil tint all move with it.

---

## 9. Bugs and mismatches noticed outside this brief — reported, not fixed

1. **`Flock.rest()` does not implement `CAMPAIGN_SPEC` §4.3.**
   `flock_state.gd:213` has `REST_CURVE := [0.95, 0.95, 0.80, 0.65, 1.00, 0.45,
   0.35, 0.25]`, so arriving at leg 6 restores **0.45** stamina where the spec's
   table says **0.28**. Separately, the spec gives a per-leg *intoxication
   cleared* value (0.40 for leg 6) and `rest()` applies a **flat `intox - 0.75`
   for every leg**, so that whole column is unimplemented. The back half is
   therefore materially more forgiving than Part 4's attrition maths assumes.
2. **`main.gd::ROUTE` leg 7 is 230 s.** `CAMPAIGN_SPEC` §2.7 and the summary
   table in §2.11 both say **180**. Legs 1–6 and 8 match the spec; leg 7 does
   not.
3. **`music.gd` has no case for new zones.** Every leg-6 render printed
   `WARNING: Music: unknown zone 'corn', going quiet.` The zone plays in silence.
   The same will happen to the truck stop and the stopover as they land, so this
   probably wants a default rather than seven more cases.
4. **The documented compile gate in `CLAUDE.md` §"Verify" and `HANDOFF` §7 is
   still the old `--import | grep ERROR` one**, which `tools/gate.gd` proves
   never compiled GDScript at all. Both documents should be updated to
   `godot --headless --path . -- --gate`.
5. **`HANDOFF` §7's render-probe commands omit that a display is required.**
   `--rendering-driver opengl3` without `--headless` needs an X server; in a
   container that is `xvfb-run -a -s "-screen 0 1280x720x24"`. Every probe
   command in that section fails without it.
6. **Nothing documents that the camera rig ignores the goose's spawn heading.**
   `goose_camera.gd` initialises `_yaw = 0.0` and only ever chases *velocity*, so
   the opening frame of every zone looks down world −Z regardless of what the
   zone set `goose.heading` to. Cottage happens to be built around this; a zone
   author who doesn't know it will compose the wrong shot, and I did. It belongs
   in `CLAUDE.md` next to the `-Z is forward` rule.

---

## 10. Honest closing statement

The zone compiles cleanly through the real gate, it renders, and the six
mechanics that carry it were each watched firing in a screenshot or verified
numerically. **Nobody has played it.** Whether a combine at 5.4 m/s is
frightening or merely annoying, whether hiding in the corn is tense or
claustrophobic, and whether the walk across the open ground is a decision or a
chore are all things only a person with a keyboard can answer, and all three are
the difference between this being the run's second peak and being a field.
