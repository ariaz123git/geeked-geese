# LEG 7 — THE TRUCK STOP

*Somewhere off I-95 in Georgia. Three in the morning, warm rain, wet asphalt
reflecting orange. Six rigs with their engines running, and one at a time they
leave.*

> **These notes were not written from play.** Every judgement below about
> *feel* — whether the departure schedule is tense or annoying, whether five of
> six primaries is fair, whether riding a truck is funny the second time — is
> the building agent's inference. The mechanics were verified by headless
> harness and by reading rendered PNGs; the fun is the human's to judge by
> playing it.

---

## 0. Files

| file | what it is |
|---|---|
| `scripts/world/zone_truckstop.gd` | the zone. Exposes `goose`, `camera_rig`, `zone_title()`, `mission_zone_id() -> &"truckstop"`, and instantiates the flock pen. |
| `scripts/world/prop_models_truckstop.gd` | 12 faceted models the shared library lacks, **plus a 4×5 bitmap font and `sign_text()`**. Same API as `prop_models.gd`: `build(kind, parent, params)` / `has_model(kind)` / `footprint(kind, params)`. |
| `scripts/core/mission_defs_truckstop.gd` | 6 primaries, 5 bonuses, 5 zone hidden objectives, in `mission_defs.gd`'s schema. |

Nothing else in the project was modified. `main.gd`, `mission_defs.gd`,
`prop_models.gd` and the other zones are untouched — see §7 for the two lines
somebody needs to add.

**Measured** (headless node walk, `--stats` scratch hook):

| | truck stop | cottage | strip mall |
|---|---|---|---|
| MeshInstance3D | 826 | 963 | 676 |
| StaticBody3D | 61 | 74 | 27 |
| ChaosProps | **68** | 55 | 60 |
| OmniLight3D | **24** | 32 | 21 |
| substance pickups | **7** | 20 | 21 |
| distinct substances | **4** | 16 | 16 |

The two numbers that are the zone's whole design are in bold: **four
substances and seven pickups**, against sixteen and twenty in the cottage — and
**sixty-eight chaos props**, which is more than either. The shelf is bare; the
lot is not.

---

## 1. What it is

**80 × 80 m, the same footprint as every other zone.**

```
z = +38 ── the treeline at the property line
z = +26 ── THE TRAVEL CENTRE (x -34..-9) and THE DINER (x -9..+4)
           roof at 4.90, landable.  five breakable window panes.
z = +22 ── the walk, under a 3.5 m awning.  paper boxes, ice, propane
           (x 10..24, z 26..36) THE DUMPSTER CORRAL — 3 skips, 6 sacks,
           6 pallets, 2 bins, one caged light, three block walls
z = +19 ── the car park: four cars for a building with one person in it
z = +16 ── the FUEL CANOPY (x -31..-11, z 3.5..16.5)
           roof at 6.20 landable · underside 5.40 · the only COLD light
z = +2 ─── THE TRUCK ROW: six rigs, bays at x = 4 / 10.4 / 16.8 / 23.2 /
           29.6 / 36.0, noses at z = -5.6, TRAILER ROOFS AT 4.05
z = -4 ─── the flooded corner (x -32..-16, z -20..-4), 30 cm deep, swimmable
z = -30 ── the exit lane, running west
z = -38 ── the berm, and I-95 with two rivers of headlights on it
```

**The pylon** stands at (-30, 2), 11.6 m tall, reading `DIESEL / 3.79 /
SHOWERS CB ICE` on **both** faces.

---

## 2. The three things the spec asked for, and how each was built

### 2.1 Scarcity (§172, §798)

`rest()` at leg 7 restores **0.35 intox / 0.25 stamina** — the leanest numbers
in the campaign. The zone matches them:

- **Four substances**, all previously seen, all at roughly **half** the cottage's
  dose size (0.24–0.30 against 0.34–0.52).
- **Seven pickups** total. The cottage has twenty.
- **`double_double`** (a cup on the window ledge, one going cold on the pump
  island), **`darts`** (half a pack by the door, half a pack by the corral),
  **`grass`** (one infinite patch in the weeds at the edge of the water), and
  **`nitrous`** (two cans in the corral, one on the walk).
- **There is no catnip, and there are still two cats.** For the first time in
  the run the cats are simply cats.

The intended read is the one §2.7 states and forbids anyone from saying out
loud: at the end of a long trip there is almost nothing left, it barely does
anything, and you are still doing it. Nothing in the zone comments on it. The
closest it comes is the hidden objective `closing_time`, which is nine words.

### 2.2 Primaries writable without chemistry (§602)

`required_primaries(7)` = `2 + floor(6/2)` = **5**, clamped to `n-1` = **5 of
6** — no override needed, the formula lands exactly on the spec's number. But
5 of 6 on four weak substances is the campaign's most likely unfairness, so
**all six primaries are completable stone-cold sober**, and five of them are
the five things §2.7 names:

| primary | at leg 7 | needs chemistry? |
|---|---|---|
| `loud_lad` — Honk at 16 things that did not ask | 16 | no |
| `dead_hours` — Wreck 12 things. Nobody will hear it. | 12 | no |
| `hitch` — Leave with one of them | 1 | no |
| `corral` — Redistribute 8 things from the corral | 8 | no |
| `window_seat` — Put 4 of the diner's windows somewhere else | 4 of 5 | no |
| `up_top` — Stand on 4 different rigs | 4 of 6 | no |

**The one deviation:** `sweet_science` (the dose-meter objective, deliberately
identical in all three built zones) is **demoted to a BONUS** here, at base 2
rather than 3. Keeping it as a primary would have broken the spec's rule;
deleting it would have removed the game's only skill objective from a leg. It
is still payable, it is just not required. Flagged for the human — if it turns
out that leg 7 feels chemistry-less rather than chemistry-*starved*, promoting
it back and dropping the requirement to 4 is the alternative the spec allows.

### 2.3 Rigs that leave (§1511)

Six `AnimatableBody3D` tractor-trailers, `sync_to_physics = true`, departing at
**0:22, 0:48, 1:16, 1:46, 2:18 and 2:46** of a 180 s clock. Each one:

1. **PARKED** — a launch pad. Trailer roof at 4.05 m, which is three flaps from
   the asphalt, one flap from the fuel-island kerb, and one flap *below* the
   travel-centre roof.
2. **ARMED** (3.2 s) — air brakes (`hiss` at pitch 1.55) and the whole trailer's
   glow shell blinking at 6 Hz. This is the only warning the zone gives that
   anything is on a timer, and it is deliberately not a clock.
3. **ROLLING** — accelerates to 9.5 m/s along two waypoints: forward out of the
   bay to the exit lane at z = -30, then a long left onto it and west. A
   travelling white headlight and a small red tail light are reparented to
   whichever rig is moving.
4. **GONE** at x < -48.

The last one leaves at 2:46, which leaves **fourteen seconds of a completely
empty parking lot** before the buzzer. That is the zone's argument, made in
physics rather than in text.

**Riding works, and it was measured, not assumed.** A headless harness put the
goose on bay 0's roof and stepped physics:

```
[ride] settled goose=(4.0, 4.39, 8.6) floor=true state=GROUND boarded=true
[ride] i=140 rig=(4.0, 0.0, -9.23)   goose=(4.0, 4.39, 1.37)    ride=2.35 rode=true
[ride] i=280 rig=(1.88, 0.0, -28.84) goose=(1.88, 4.39, -18.24) ride=4.68 rode=true
[ride] i=350 rig=(-6.57, 0.0, -35.6) goose=(-6.57, 4.39, -25.0) ride=5.85 rode=true
[ride] END   goose=(-17.4, 4.39, -25.3) moved=40.1 rode=true state=ROLLING
```

The bird is carried exactly, through the 90° turn, forty metres in seven
seconds. `constant_linear_velocity` is set on the body every frame *as well as*
the transform — that is the value `CharacterBody3D` reads for platform velocity,
and without it the trailer slides out from under the goose.

**The map wall is part of the joke.** An `AnimatableBody3D` is a `StaticBody3D`
subclass, so the rig drives straight through the invisible boundary at z/x = ±40
and the goose riding it does not. The harness has the wall scraping the bird off
at ~9.4 s, sixty-plus metres from where it started, at the dark end of the lot.
That is why `WENT WITH IT` fires at **6.5 s** and not the 8.0 s it was first
written at — eight seconds cleared the wall by 1.4 s, which is not a margin.

---

## 3. Night, rain, and the lettering

### 3.1 The signage problem, solved once, in one function

**A truck stop is made of signage, and this project has shipped mirrored text
twice** (a stop sign reading `POTS`, a trailer reading `ƎƆIVЯƎƧ`). Every model
is authored facing -Z, so a sign's front face has normal (0,0,-1), its reader
stands at -Z looking along +Z, and **for that reader world +X runs right to
left.**

`prop_models_truckstop.gd::sign_text()` computes the pen's advance direction as

```gdscript
var r := up.cross(normal).normalized()
```

which is on-screen right for *any* flat face:

| face normal | advance |
|---|---|
| -Z (a sign facing the road) | -X |
| +Z (the back of the same sign) | +X |
| +X (a trailer's right flank) | -Z |
| +Y, `up` = -Z (paint on the asphalt) | +X |

**This was rendered and read before anything else was built.** A scratch scene
put `DIESEL` / `OPEN 24 HRS` on a -Z face, `SHOWERS` on a +X face and `TRUCKS`
painted flat on the ground, all through the same helper; all three read
correctly first time. Every lettered surface in the zone goes through it:
`DIESEL`, `3.79`, `SHOWERS CB ICE` (pylon, both faces), `TRAVEL CENTER`,
`SHOWERS / SCALE`, `EAT`, `OPEN 24 HRS` (facade), `FUEL` (canopy fascia, both
faces), `TRUCKS` and `NO IDLING` (asphalt), and six trailer names on twelve
flanks.

The font is **4×5**, not the more usual 3×5, because M/N/V/W are genuinely
ambiguous at three pixels wide and this zone's whole job is to be read. Runs of
lit pixels are merged horizontally and the whole string commits to **one mesh**,
so a sign is one draw call.

> `NO IDLING`, painted on the asphalt of a row of six trucks with their engines
> running, is the best joke available in a parking lot at 3 a.m. and it costs
> forty boxes.

### 3.2 Can you see anything?

The cottage solved night with a moon. This zone cannot — it is raining and there
is no moon — so **everything the player navigates by is man-made**, which is
both correct and a completely different-looking zone.

| layer | what it is |
|---|---|
| ambient | `AMBIENT_SOURCE_COLOR`, `Color(0.42, 0.43, 0.50)` @ 0.44 — **nearly neutral, very slightly cool** |
| "the overcast" | one 0.30-energy directional straight down, shadows ON. No sun disc on the sky material. Its only job is to give things a top face and a contact shadow. |
| rim | a 0.20 shadowless directional at sodium colour from the interstate side, so silhouettes separate from a black sky |
| 9 sodium lamps | `Color(1.00, 0.62, 0.22)`, 3.4 energy, 26 m range, on 9 m poles with cocked mast arms |
| the fuel canopy | 4 **cool white** sources at 6.2 energy — the only cold light on the lot, and the reason the canopy reads as a destination from anywhere |
| glow geometry | window bands, fascia strips, marker lights, conspicuity tape, lamp lenses, the diner's strip light, the interstate's headlights, every letter |
| the pickups | 7, each carrying its own light — the wayfinding layer for the dark half |

**The ambient started warm** — `(0.56, 0.46, 0.40)`, on the theory that
everything filling the shadows here is sodium. The first render was a lot in
which the tarmac, the trailers, the sky and the lamps were all the same brown.
**Sodium only reads as sodium if the things it is not hitting are cold.** The
ambient is the cold now and the nine lamps supply every warm pixel in the zone.

Fog went 0.0105 → **0.0062** for the same reason: at 0.0105 the far wall was 57%
fogged and the back half of the lot was mud. Rain reads from the streaks and the
reflections, not from haze.

### 3.3 Wet asphalt, without falling in the hole

The obvious build is a translucent dark sheen plane over the asphalt with a
normal map. That is **exactly** the trap this project has hit twice: a
translucent coloured plane over similarly-coloured ground renders as nothing,
and the strip mall's pond needed a dark mud basin behind it before anyone could
see the water.

So wet is built as **light, not surface**. Under every sodium head, `_pool()`
lays three concentric **additive, unshaded** discs plus a short smear running
away from the pole. Additive over dark asphalt cannot fail to be brighter than
what is under it. Two things the first render forced:

- The three discs are `BoxMesh`, so three concentric squares read as **a
  square** — the lot had rectangular puddles of light with corners on them. They
  are now yawed 0° / 22.5° / 45°, which is a rosette for free.
- The smear tiles overlapped, and **overlapping additive tiles double their
  alpha in the overlap**, so the smear rendered as corduroy. Tile depth now
  equals the step exactly.

Rain is `CPUParticles3D` (not GPU — this project ships on GL Compatibility),
300 streaks in a 26 m box that follows the goose, `local_coords = false`.
Audio is `hiss` looped on its own `&"rain"` bus, **stopped in `_exit_tree()`**
so it does not follow the player into the flight.

### 3.4 The flooded corner

16 × 16 m, **30 cm deep**, with the cottage's measured wade numbers: bed at
-0.30, `Area3D` top at +0.20. Verified headless — the goose floats at
`y = 0.0405` (the designed 0.04), reports `WATER`, and walks back out up a ramp:

```
[audit] in flood:        pos=(-24.0, 0.0405, -12.0)  state=WATER
[audit] walked out east: pos=(-16.51, 0.2616, -12.0) state=WATER   (on the ramp, rising)
```

There are wade ramps on **all four** sides. There is deliberately no edge of
this puddle you can swim up to and be unable to get out of.

**Making it look like water took two goes.** At the cottage lake's 0.88 alpha it
was "a slightly darker rectangle of tarmac" and nothing else. The fix is two
things: alpha down to **0.52** (this is 30 cm of standing rain, not 35 m of
lake), and **four painted stall lines that walk off the dry lot and carry on
underneath the surface**, dimmer and colder. A line that crosses the boundary
and goes dim cannot be misread. That is the single unambiguous "this is water"
cue in the zone and it is eight boxes.

---

## 4. What the renders caught

Every one of these was invisible in the source and obvious in a PNG.

1. **Lettering, before anything else.** A scratch scene with four facings.
   All four read; `up × normal` confirmed empirically rather than argued.
2. **The models, at a readable distance.** The tractor's dash glow was *behind*
   its own windscreen (z -1.42 against glass at -1.49) so the cab was simply
   dark; the ice box's lit interior was *behind* its own door, so the freezer
   was an unlit white cabinet. Both are the same bug and both are one number.
   The `gator` was authored in tyre-black and rendered as a hole in the ground
   next to the goose — it is grey-brown now.
3. **The whole lot was brown.** See §3.2.
4. **Four of six geese were standing on the diner awning, reading their own
   name tags.** `flock_pen.gd` grounds each bird with a raycast that starts
   **four metres above** the centre it was given, so a pen placed under anything
   lower than that snaps the entire flock onto the roof of it. This is a real
   trap for any future zone with an overhang and it is not documented anywhere
   else. The pen is now at (-7, 0, 0), in the open, under a light pool.
5. **`SHOWERS / SCALE` was written at y = 3.34, under a solid awning at
   3.32–3.53** that spans four metres of Z — invisible from everywhere in the
   lot except directly underneath it. Both facade lines now live above 3.6.
6. **The pylon showed its back to the entire lot.** A pylon points at the road,
   which here is -Z, so a player standing in the lot reads the blank grey side.
   It is double-sided now, like every real one — which is also the proof that
   `sign_text()` handles +Z as well as -Z.
7. **The pylon's own pole stood in front of `3.79`**, and `SHOWERS CB ICE` had
   been written *below* the sign panel entirely. Pole 8.8 → 8.3 m, lines raised.
8. **`FUEL` was buried inside the fascia band it was written on**, and painted
   in a corporate dark blue — on an **unshaded** material, which renders at
   exactly its vertex colour. Moved 22 cm proud, brightened, and put on both
   fasciae because half the lot approaches the canopy from the north.
9. **A 2.2-energy red omni one metre from the spawn point.** The travelling tail
   light turned a third of the frame into a red haze. 0.95 energy, 7 m range.
10. **Six identical pale trailers.** The body colour took 12% of the tractor's
    paint; under sodium the row was one indistinguishable wall and you could not
    count it, let alone plan a route through it. 30% now.

Renders read (all at 1100×620, GL Compatibility under Xvfb): the letter-test
scene, three spawn shots at leg 7, and fixed-camera views of the whole lot from
the air, the diner front, the fuel canopy from both sides, the dumpster corral,
the flooded corner, the exit lane, the pylon, and the facade signage.

---

## 5. Headless audits

Run against a copy of the project with a scratch hook in the zone; the hook is
**not** in the shipped file.

```
[audit] chaos_props=68 ejected=0
[audit] omni_lights=24
[audit] panes=5
[audit] i=3 gpos=(-8.0, 1.576, 25.315) v=8.91 overlaps=true gone=true
[audit] in flood: pos=(-24.0, 0.0405, -12.0) state=WATER
```

- **0 props ejected of 68.** (Recycling bins once reached y ≈ −1120 in the strip
  mall by spawning inside the storefront; nothing here spawns inside a collider.)
- **24 omni lights** — 17 fixed plus 7 pickups, against the GL Compatibility
  default cap of 32. The cottage sits exactly on 32 and cannot take another
  source; this zone has eight lights of headroom.
- **The diner window breaks** on contact above 4 m/s and the goose ends up
  inside the bay.
- **The flood swims.**

---

## 6. The objective list

Full definitions with inline rationale in `scripts/core/mission_defs_truckstop.gd`.

At leg 7 `target_scale` is pinned at its **1.9 ceiling**, so every base number
in that file is very nearly doubled before a player sees it. A base of 6 reads
as 12. Every number was written by checking what it becomes.

### Primaries (6, need 5) — see §2.2 for the table

### Bonuses (5)

| id | text | why |
|---|---|---|
| `sweet_science` | Land 4 doses in the sweet spot | demoted from primary (§2.2); base 2, not 3, because leg 7 doubles it |
| `share_the_wealth` | Share what you're on with the flock, 4× — *"the next one is the long one"* | the only objective with a real cost, on the leg where it costs the most: flight 7 is 130 s with no thermals for the first 60% |
| `gator_country` | Rehome 6 pieces of somebody's tyre | the cheap toy. Seven shed retreads, and they are the only props in the zone that are *not* in a cluster |
| `long_way_round` | Land 6 hits without landing | verticality, chemistry-free — the objective most likely to be attempted by a player who has given up on the substances |
| `variety_pack` *(leg 4+)* | Wreck 6 different kinds of thing | walks the player around all four clusters |

### Hidden (5 zone-flavoured; the 7 universal ones ride along)

| id | banner | why |
|---|---|---|
| `where_are_you_going` | WHERE ARE YOU GOING — *"Six seconds on the roof of a stranger's trailer, doing sixty, in the rain. Nobody made you."* | layers on a primary the player already wants. 1.2 s completes `hitch`; 6.5 s takes you past the property line |
| `closing_time` | CLOSING TIME — *"Everyone else had somewhere to be."* | fires when the sixth rig pulls out at 2:46 if you are still there. Requires nothing, cannot be missed by a player who stays, cannot be earned by one who has been carried out. The zone says the quiet part once, in nine words |
| `breakfast` | BREAKFAST — *"Coffee and a cigarette at three in the morning. You are not a goose, you are a driver."* | the two most obvious things at a truck stop, which are also the two weakest things in the game |
| `it_counts_as_water` | IT COUNTS AS WATER — *"Sixteen metres of parking lot with nowhere to drain. To a goose that is a lake."* | 8 s **continuous** afloat |
| `through_the_front` | THROUGH THE FRONT WINDOW — *"They will be talking about this at shift change."* | the window primary, but airborne. The honest route is off the awning, which is directly above the glass |

---

## 7. Integration — the exact lines

Two edits, in files this zone deliberately did not touch.

### 7.1 `scripts/core/main.gd` — the route

Replace the leg-7 entry (currently a strip-mall placeholder at 230 s):

```gdscript
	{"zone": "res://scripts/world/zone_truckstop.gd",   "name": "THE TRUCK STOP",     "seconds": 180.0},
```

180 s, not 230 — `CAMPAIGN_SPEC` §2.7 and the per-leg table both say 180, and
the departure schedule in `DEPART_AT` is written against a 180 s clock. If the
clock changes, that constant has to change with it.

### 7.2 `scripts/core/mission_defs.gd` — the objectives

Add the preload beside the existing `COTTAGE` one:

```gdscript
const TRUCKSTOP := preload("res://scripts/core/mission_defs_truckstop.gd")
```

and one branch in `for_zone()`:

```gdscript
		&"suburbia":
			out.append_array(_suburbia())
		&"truckstop":
			out.append_array(TRUCKSTOP.truckstop())      # <-- add
		_:
			out.append_array(_generic())
```

`_filter_by_leg()`, target scaling, reward scaling and the seven universal
hidden objectives then apply with no further wiring. `mission_defs_truckstop.gd`
also exposes its own `for_zone(zone_id, leg)` so a harness can load it
standalone; the branch above is the shipping path.

### 7.3 Optional

`scripts/core/music.gd` has no `truckstop` stem set, so the zone runs to
`Music: unknown zone 'truckstop', going quiet` — which is printed as a warning
on every load. It is on the spec's own touch-point list (`music.gd:65`).

### 7.4 Verify

```
godot --headless --path . -- --gate 2>&1 | grep '^\[gate\]'
godot --path . --rendering-driver opengl3 -- --probe --leg:7 --shots:3 --secs:3 --out:<dir>
godot --path . --rendering-driver opengl3 -- --probe --leg:7 --boss --secs:8 --out:<dir>   # BIG DOWN
```

The first line used to name a Linux binary under `/tmp` that does not exist on
this machine, and the second used `--frames:12` — frames, not seconds. Both were
written against the container this zone was built in. `--frames` is calibrated
for a renderer running at about 2 fps; on a machine with a GPU the same number is
a fifth of a second and photographs the moment before anything has happened.
**Use `--secs`.** `--out:` is now required for the PNGs to land anywhere you can
read them.

Under `--probe` the zone compresses `DEPART_AT` by 0.06 so the rigs actually
move inside a twenty-frame software render. That is the same dev hook `main.gd`
gives the Ranger with `--boss`, and it is the only place `--probe` changes
gameplay.

---

## 8. What a human should tune first, in order

1. **Whether 5 of 6 is fair.** §2.7 calls this the campaign's most likely
   unfairness and it is the first thing to playtest. The primaries are all
   chemistry-free, but "free of chemistry" is not the same as "achievable in
   180 s". The two that worry me are `window_seat` (four panes needs four
   separate 4 m/s run-ups at a wall) and `corral` (eight objects in a walled
   enclosure at the far corner of the lot). If it bites, the spec's own fallback
   is dropping the requirement to 4.
2. **`DEPART_AT`.** Six departures across 180 s is a guess. Too early and the
   lot is empty before the player has understood that rigs are rideable; too
   late and `up_top` (4 of 6 roofs) is trivial. The single most important number
   is the **first** one, 22 s — it is the only teaching moment the mechanic gets.
3. **Rig speed (9.5 m/s) and the turn rate (0.62 rad/s).** A ride currently
   lasts ~9.5 s from bay 0. Faster is funnier and much harder to stay on.
4. **Whether the zone is too dark.** It is the second-darkest thing in the game
   and the render tests say it is legible, but "legible in a still" and "legible
   while flying" are different claims and only one of them has been checked.
5. **The flooded corner's read.** It is legible now but it is the weakest
   surface in the zone. It probably wants an animated ripple or a second,
   brighter reflection band before it really looks like standing water.
6. **The `hitch` hint** — *"they are not waiting for you"* — is the only warning
   the zone gives that anything is on a clock. If playtesters miss all six
   departures, that hint is too subtle and the honest fix is a diegetic one
   (louder air brakes, longer arm time) rather than a HUD timer.

---

## 9. What's stubbed, missing, or known-wrong

- **No zone-specific audio.** The rain is `hiss` on a loop and the air brakes
  are `hiss` pitched up; the diesel pulling away is `crash_heavy` at 0.42. All
  three work better than they deserve to, but `tools/gen_audio.py` should get a
  real rain bed, an idling diesel, and an air-brake release. **Untested by ear**
  — this container has no audio device, so the only claim I can make about the
  sound is that the calls compile and the loop is stopped on exit.
- **No music stem.** §7.3.
- **The rigs never come back.** By design, but it means a player who spends the
  first two minutes in the corral finds a lot with two trucks left in it and no
  explanation. That is the intent; it may read as content failing to load.
- **A rig will drive through a chaos prop rather than punting it.** The rig is
  an `AnimatableBody3D` and it does push `RigidBody3D`s, but nothing is placed
  in the departure path deliberately and the interaction has not been rendered.
  A cone getting demolished by a departing truck is free comedy nobody has
  claimed yet.
- **The goose can be crushed against the map wall by a rig it is riding.** It
  gets scraped off rather than killed (see §2.3) and it is arguably the funniest
  thing in the zone, but it has only been verified in a headless harness, never
  watched.
- **The diner bay is a 1.4 m diorama, not a room.** Break the glass and you can
  stand in it, and the "interior" is one metre deep. At night, through glass, it
  reads; from inside, with the glass gone, it will not.
- **`NpcHuman` has no edge avoidance** (the cottage notes flag the same thing).
  The one cook is inside a 13 × 1.4 m bay with a 1 m counter in it, so it should
  stay put, but it has not been watched for three minutes.
- **`_pane_body` colliders are disabled, not freed**, on break. Five dead
  `StaticBody3D`s with disabled shapes is nothing, but it is not tidy.

---

## 10. Bugs noticed outside this brief

Reported, not fixed.

1. **`tools/gate.gd:85` prints ~24 engine errors on every run.**
   `ERROR: Parameter "method" is null.` from `variant_call.cpp` in
   `is_builtin_method_vararg` / `get_builtin_method_argument_count` /
   `get_builtin_method_return_type` / `get_validated_builtin_method`. It
   reproduces on a clean checkout with none of my files present, the gate still
   exits 0 and still reports `PASS`, but a gate whose *own* output contains two
   dozen `ERROR:` lines is a gate people will learn to skim — and `CLAUDE.md`'s
   rule is "treat any `ERROR:` on stderr as a failure". Worth silencing.

2. **`flock_pen.gd::_ground_at()` raycasts from `at.y + 4.0`.** Any pen placed
   under an overhang lower than four metres puts the entire flock on the roof of
   it, silently. It cost me a render cycle here (§4.4) and it will cost the next
   zone one too. A cheap fix is to start the ray at `at.y + 0.5` and only fall
   back to a high start if nothing is hit.

3. **`goose_camera.gd` yaw follows *velocity*, not heading.** A stationary goose
   at spawn therefore always looks along world -Z regardless of `goose.heading`,
   which means `heading` at spawn is purely cosmetic and every zone's first
   frame is decided by which way -Z happens to point. Not wrong, but it is not
   what the spawn code in any of the zones reads as if it believes.

4. **`Music: unknown zone` is a `push_warning`, not a print.** Three of the
   eight legs will emit it once the bespoke zones land. See §7.3.
