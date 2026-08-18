# LEG 3 — COTTAGE COUNTRY

*Muskoka, at night. A granite shelf with a cottage on it, a lake underneath,
and about six metres of nothing in between.*

---

## 0. Files

| file | what it is |
|---|---|
| `scripts/world/zone_cottage.gd` | the zone. Exposes `goose`, `camera_rig`, `zone_title()`, `mission_zone_id() -> &"cottage"`, and instantiates the flock pen. |
| `scripts/world/prop_models_cottage.gd` | 21 faceted models the shared library lacks. Same API as `prop_models.gd`: `build(kind, parent, params)` / `has_model(kind)` / `footprint(kind, params)`. |
| `scripts/core/mission_defs_cottage.gd` | 6 primaries, 5 bonuses, 5 zone hidden objectives, in `mission_defs.gd`'s schema. |
| `tools/zone_tour.gd` | **optional, verification only.** Renders the zone from 14 fixed viewpoints and runs three audits (ejection, float/sink, traversal). Never loaded by the game. Ship it or don't — it belongs beside `mission_harness.gd`. |

Nothing in `/home/claude/GeekedGeese/` was modified.

---

## 1. What it is

**80 x 80 m, same footprint as the other two zones, but with 12 m of height in it.**

```
z = +40 ── back of the property: pines, dirt driveway, a parked minivan
z = +22 ── THE COTTAGE (15 x 10, screen porch + deck facing the lake)
z = +10 ── the fire pit: 6 Muskoka chairs, coolers, firewood, 4 people, a dog
z = +4.6 ─ the lip of the shelf.  y = 6.60
           ╲ granite ledges at 5.10 / 3.55 / 1.95, or a sheer 6 m drop
z = -2 ──── the shore terrace, full width.  y = 0.55
z = -5 ──── the waterline.  y = 0
z = -40 ─── THE LAKE: dock, boathouse, three loons, a moon path, a toad
```

**Stats** (measured by `tools/zone_tour.gd`, with the two existing zones for scale):

| | cottage | strip mall | suburbia |
|---|---|---|---|
| triangles | **358,162** | 378,634 | 220,554 |
| MeshInstance3D | 963 | 676 | 874 |
| ChaosProps | 55 | 60 | 60 |
| StaticBody3D | 74 | 27 | 297 |
| substance pickups | 20 | 21 | 14 |
| OmniLight3D | **32** | 21 | 14 |
| DirectionalLight3D | 2 | 1 | 2 |

Triangle budget lands between the two existing zones. Light count is the one
number that is genuinely higher, and §2.6 explains why and what it costs.

**Distinct substances placed: all 16.** toad slime (the hero — see §4), fermented
berries (two two-fours, one by the fire and one on the dock), grass (three
infinite patches: shelf, terrace, and one halfway up the rock face), darts
(half a pack on the dock rail), whippets (in the cooler), double-double (on the
deck rail), fly agaric (two clusters in the moss under the pines), catnip (herb
pot on the porch step), special K and math (on the picnic table), robo and acid
(in the boathouse), gravy (a poutine container by the fire), bars and percs (on
the porch knee wall), molly (the dog by the fire).

**21 models** in `prop_models_cottage.gd`: canoe, kayak, muskoka_chair, fire_pit,
dock_section, dock_light, pine, bug_zapper, cooler, loon, toad, dog, rock, scrub,
firewood, log, paddle, two_four, picnic_table, cottage, boathouse.

---

## 2. Night visibility — the make-or-break, and how it was solved

The requirement was: **the player must be able to see well enough to fly**, and
the zone must not read as the parking lot with the lights off. Those pull in
opposite directions, so the solve is layered, and each layer was added because a
render showed the previous one wasn't enough.

### 2.1 Ambient is the floor, not the moon

```gdscript
env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
env.ambient_light_color  = Color(0.34, 0.44, 0.68)
env.ambient_light_energy = 0.46
```

`AMBIENT_SOURCE_SKY` (what both other zones use) delivers essentially nothing
against a 0.02 night sky. An explicit colour ambient means **no surface in the
zone is ever darker than a legible deep blue.** This single line decides whether
the zone is playable and it is deliberately far above what a night sky actually
delivers. It started at 0.55 and came down to 0.46 once the moon went up.

### 2.2 The moon is the shape

A `DirectionalLight3D` at 0.82 energy, `Color(0.66, 0.76, 1.00)`, 26° above the
horizon at yaw 196°, shadows on. Ambient alone renders the world as flat
cardboard — the moon is what makes the granite read as granite and throws the
cottage's shadow across the shelf. `sun_angle_max = 3.5` on the sky material
gives an actual moon disc you can navigate by. A second shadowless directional
at 0.17 from behind the cottage puts a rim on the far side of every pine so the
treeline separates from the sky instead of being one black mass.

### 2.3 The point lights are the *place*

Twelve fixed `OmniLight3D`s, all shadowless (an omni shadow on GL Compatibility
is a cube render, and twelve of them is not a trade worth making for shadows a
player reads as noise at night):

| light | colour | energy | range |
|---|---|---|---|
| campfire — reach | warm orange | 5.4 ± flicker | 22 |
| campfire — core | deep orange | 2.6 ∓ flicker | 7.5 |
| cottage porch | warm | 2.6 | 13 |
| cottage lake windows | warm | 1.9 | 9.5 |
| cottage back window | warm | 1.5 | 8.5 |
| bug zapper | violet | 2.4 + zap flash | 10 |
| dock light | pale white | 3.4 | 17 |
| boathouse lamp | warm | 2.4 | 13 |
| stair lamp (upper) | warm | 1.5 | 7 |
| stair lamp (lower) | warm | 1.4 | 6.5 |
| driveway pole | cold white | 1.8 | 12 |
| the toad's rock | green | 1.1 | 5 |

The two firelights flicker **out of phase** on two octaves of sine (not noise —
noise reads as a broken bulb), so the core and the reach never dip together and
the plateau never goes momentarily dark. The bug zapper is the only *cold*
artificial source up top, which is what makes the fire and the windows read as
warm.

### 2.4 The pickups are the breadcrumbs

Every `SubstancePickup` already carries its own `OmniLight3D`. At night that
stops being findability polish and becomes the zone's **wayfinding layer**, so
sources are placed along routes rather than clustered: there is a grass patch
halfway up the rock face purely so the climb has a lit waypoint, and one at the
far end of the terrace so the shoreline has a destination.

### 2.5 Emissive geometry, because a lit window is not a lit-up window

`prop_models_cottage.gd` builds every model with **two** builders — a normal
shaded shell and a `SHADING_MODE_UNSHADED` "glow" shell. An unshaded face
renders at exactly its vertex colour regardless of what light reaches it, which
is precisely "this surface is emitting". That is what the cottage's eight
windows, the porch interior, the fire, the bug zapper grid, the dock bulb, the
boathouse lamp and the toad's eyes are made of. A pale-yellow *lit* quad at 0.46
ambient is a grey rectangle; this isn't.

The glow mesh is only attached when it has triangles, so a model with no light
source costs exactly one `MeshInstance3D`, same as before.

### 2.6 Two things that are lighting solutions but don't look like it

**Tiled ground.** GL Compatibility lights a single `MeshInstance3D` with at most
**eight** lights (`rendering/limits/opengl/max_lights_per_object`, default 8). An
80 m plateau as one mesh therefore picks eight of the zone's twelve lamps and
drops the rest — and *which* eight changes as things move, so the ground
flickers. Every large surface in this zone (plateau duff, mown grass, granite
patches, the lake, the deck) is split into tiles by `_flat_tiles()` for exactly
that reason.

**The moon path.** A band of additive tiles running from under the moon toward
the dock. Physically it's the specular glare of a low moon on a rippled surface;
practically it is the only thing giving 35 m of black water a **readable
direction**. Without it a player out over the lake has no cue at all for which
way the shore is. It is faked as geometry rather than left to the specular
highlight because a single flat quad with a normal map produces exactly one
hotspot for the entire lake. The water material also carries a 0.42 emission —
the smallest lie that stops the lake being a hole in the world when seen from
the top of the cliff.

### 2.7 What the renders showed, round by round

1. **First probe.** Legible but flat and slightly washed; the fire pit and the
   cottage deck overlapped, and eleven `firewood` STACK models had been scaled
   into 24 cm collider boxes, so the ground around the fire looked like the
   level had exploded. Split the layout apart; added a `log` model (a prop model
   must be authored at the size of the collider it hangs on).
2. **Tour round 1** (wide / fire / cliff / dock). Night reads, but the rock face
   was unmistakably *poured concrete stadium seating* and the cottage was a bus
   shelter — its porch spanned the whole facade and hid every window.
3. **Round 2.** Ambient 0.55 → 0.46, moon 0.62 → 0.82, granite tint 0.30 → 0.175
   with the UV scale tripled, moon path added, porch narrowed to 44% of the
   facade and pushed off-centre so half the lake wall is bare siding carrying
   two big lit windows. Cottage now reads. New problem: **the scattered granite
   rendered as white confetti.**
4. **Round 3.** Two causes, both found by cropping and zooming the render.
   (a) The `rock` model's quartz veins and lichen were authored as literal pale
   colours; at 0.4× scale the details *are* the rock. Both now derive from the
   base colour. (b) Loose stone was being handed the same tint as the bedrock,
   but the bedrock is textured (concrete at ~0.55 mean × tint) while the models
   are raw vertex colour — so every boulder was at twice the value of the ground
   under it. Separate `C_ROCK` constant, ~40% darker. Also replaced the leaning
   "slabs" on the sheer sections: rotated boxes read unmistakably as grey
   *cards*, and stacked boulder models cost the same and have a broken outline.
5. **Round 4.** Rock details still poked through the silhouette at glancing
   angles (long thin white slivers). Veins and lichen pulled inside the actual
   blob radius. `_blob`'s top-cap lightening dropped from +0.10 to +0.03 — that
   value was tuned for a daylit zone, and under a low moon the top cap of every
   blob is the one face pointing straight at the key light.
6. **Round 5.** The toad and the dog were each doubled: `pickup_models.gd`
   already builds a toad for `toad_slime` and a retriever for `molly`, and the
   zone had stacked its own model on top of both. Removed both duplicates; the
   sleeping-dog model moved to the porch as the cottage's *other* dog, and the
   toad model became two small ones further along the shore (§4).
7. **Round 6.** Verification only. Renders from the fire, the deck, the cliff,
   the dock, water level, the boathouse, the stairs, the back woods and the
   darkest corner of the property. Everything legible; nothing floating.

**Can you see?** Yes, including from the darkest corner — the north-west woods,
36 m from the fire with a pine between you and it, is lit well enough to read
the ground, the trunks, the scrub, the cottage and the horizon line.

---

## 3. Layout and verticality

Verticality is the reason this zone exists, and it is expressed four ways.

**The drop.** The plateau is at y = 6.60 and the water at y = 0. Walk off the
cottage deck heading for the lake and there is nothing between you and the water
for six metres. Two of the eight shoreline segments are deliberately **sheer** —
one of them sits directly below the fire pit, which is where the player already
is — so the zone has a proper diving board rather than a slope.

**The ledges.** The other six segments break into granite steps at 1.95 / 3.55 /
5.10, with per-segment jitter in both height and depth so it doesn't read as one
80 m staircase. Every rise is **inside a single flap**:

> a flap from a standstill is `flap_impulse² / (2 × glide_gravity)` = `6.4² / 22`
> = **1.86 m**. The largest gap on the face, with worst-case jitter applied, is
> **1.62 m**. The first draft put ledge 1 at 2.10 and the jitter pushed the worst
> case to 1.77 — technically possible, and exactly the margin that turns into
> "I'm stuck at the bottom of the map".

**The stairs.** A zigzag of two flights and a landing, both under 33°, down the
east end of the face, with a solar lamp on each. It is the walk-home route for a
bird with no stamina, and it is lit specifically so it's findable from the water.

**The lake.** 35 m deep, one box `Area3D` in the `water` group over all of it.
The wade line is set by measurement rather than by eye:

> The goose's body collider is a capsule lying along Z, so its **vertical**
> half-extent is the 0.34 radius, not the 0.55 half-length, and its water probe
> is a 0.22 sphere on the origin. A lake bed at −0.30 and an Area3D top at +0.20
> means the bird floats with its origin at **0.04** — waterline just under
> halfway up the body, which is what a swimming goose looks like — and switches
> to the swim state when the rock under its feet drops a hand's width below the
> surface. The first pass had the bed at −0.55 and the bird swam 80% submerged,
> which reads as drowning.

**Navigability is guaranteed, not assumed.** A 30° wade-in ramp runs the *entire*
80 m shoreline. There is deliberately no stretch of this lake you can swim up to
and be unable to get out of: the zone already asks the player to solve a
six-metre cliff, and stacking "and also you're stuck in the water" on top of that
is not difficulty, it's a bug with a story.

`tools/zone_tour.gd --audit` drops the goose at 13 places and reports where it
ends up and what state it's in. Current output:

```
open lake       (-4, 1.5, -22) -> (-4, 0.04, -22)   WATER
shallows        ( 6, 1.5,  -8) -> ( 6, 0.04,  -8)   WATER
beach ramp      ( 6, 1.5, -5.6)-> ( 6, 0.75, -5.6)  GROUND
shore terrace                  -> y 1.54            GROUND
ledge 1 / 2 / 3                -> y 2.48/5.26/6.94  GROUND
plateau                        -> y 6.94            GROUND
boathouse roof                 -> y 4.89            GROUND
dock / stair landing           -> y 1.30 / 3.99     GROUND
cottage roof                   -> y 11.91           GROUND
```

Plus: **0 ejected props of 55** (a ChaosProp spawned intersecting a StaticBody is
launched across the map in two physics frames; the first build had several).

---

## 4. The toad

`toad_slime`'s codex fact — the US National Park Service formally asking visitors
to refrain from licking the Colorado River toad — is the best true thing in the
game, and its blurb literally reads *"There is a toad by the pond at night."*
This is that pond. Finding it is built as a small sequence rather than a pickup
on the floor:

1. **Two small toads** sit on the shore rocks further along the terrace, in the
   dark. Their only visible feature is a pair of glowing eyes on the emissive
   shell — which is exactly how you find a toad at night.
2. **The one that matters** is on a granite boulder standing out of the water
   past the end of the dock, at the outer edge of the dock light. From the dock
   it is a faint green smudge on black water; getting to it means going down the
   cliff and swimming.
3. A 7 m proximity trigger prints *"something moved"* in swamp green, once, and
   plays a croak (`goose_grumble` pitched to 0.44).
4. After that it **croaks on a timer** whenever the player is within 12 m.
5. Taking it fires the hidden objective `do_not_lick_the_toad` — *"There was no
   sign. There is now."* — at **500** rather than the strip mall's 350, because
   here it was found rather than stumbled into.

Ambient audio does the rest: a loon wails every 7–15 s from whichever loon the
timer picks, which is both the sound of the place and a directional cue for a
lost player out over the water.

---

## 5. The objective list

Full definitions with inline rationale in `scripts/core/mission_defs_cottage.gd`.
Beyond being funny, this list has exactly one job the other two don't: **get the
player off the shelf.** Two of the six primaries cannot be completed with your
feet on the plateau, and it does that without ever asking the player to go
somewhere and *not* cause chaos.

### Primaries (6 — `required` is 2 of 5 at legs 1–2, 3 of 6 at legs 3–4, 4 of 6 at 5–6)

| id | text | one-line rationale |
|---|---|---|
| `chair_launch` | Introduce {n} Muskoka chairs to gravity | The zone's shopping cart: light, high-value, cartwheels forever, and there are six of them in a ring around a fire at the top of a cliff. |
| `sweet_science` | Land {n} doses in the sweet spot | Deliberately identical in all three zones — the dose meter is the only real skill in the game and a skill you practise in one zone isn't one. |
| `loud_lad` | Honk at {n} things that did not ask | The anti-stall objective, and it matters *more* here: this is the zone where a new player can genuinely fail to find anything for twenty seconds because it's dark. |
| `long_way_down` | Land {n} hits without landing | **The verticality primary.** Never says "fly", never says "jump off the cliff" — says the thing you want anyway and quietly rules out how you did it in the other two zones. |
| `above_the_waterline` | Stand on something out in the lake *(hint: there is only one candidate)* | Suburbia's `get_up_there`, rebuilt for a zone whose roofs are at the *bottom*. Finding the boathouse roof teaches both vertical routes at once. |
| `ten_second_cottage` *(leg 3+)* | Wreck {n} things inside ten seconds *(hint: the fire is surrounded by furniture)* | The leg-3 constraint. Also routes the player into the best-lit set-piece on the map at exactly the leg they've stopped needing help finding it. |

### Bonuses (5, streamed two at a time by the HUD)

| id | text | rationale |
|---|---|---|
| `firewood_ballistics` | Redistribute {n} pieces of firewood | Eleven loose splits on a granite shelf is a toy, and a bonus should be "enjoy the toy". |
| `fleet_action` | Put {n} boats back in the water. Hard. | Canoes are the heaviest thing a goose can actually move, so shifting one is a physics achievement — and they're at the *bottom* of the cliff, so the fastest route is to arrive at speed. |
| `share_the_wealth` *(leg 2+)* | Share what you're on with the flock, {n}x | The only objective with a real cost. Belongs in every zone, not just the first. |
| `variety_pack` *(leg 4+)* | Wreck {n} different kinds of thing | Late-leg breadth — which in a dark zone also means pushing the player into the parts of the map they haven't yet had a reason to light up. |
| `night_flight` *(leg 5+)* | Land {n} hits airborne, on two things | Mastery constraint: sustained flight *and* aggression *and* a live pair. Creates a chemistry problem without naming chemistry. |

### Hidden (5 zone-flavoured; the 7 universal ones ride along as usual)

| id | banner | rationale |
|---|---|---|
| `do_not_lick_the_toad` | DO NOT LICK THE TOAD — *"There was no sign. There is now."* | This is the toad's home (§4). Paid at 500, not 350: here it was found. |
| `chair_avalanche` | MUSKOKA CHAIR AVALANCHE — *"Four chairs, five seconds. Somebody's grandfather made those."* | The cart train, ported. Rewards committing to one run through the ring instead of grazing — and it happens inside the biggest light in the zone. |
| `night_swim` | NIGHT SWIM — *"The lake is warmer than the air. That is a lie the lake tells every year."* | Ten **continuous** seconds afloat: long enough to notice the loons, the moon path, and that the cottage is a small light a long way up. A hidden objective that pays for looking around. |
| `answered_the_loon` | THAT IS NOT WHAT IT SAID — *"It was not talking to you. You answered anyway."* | Six honks in five seconds *while in the water*. Every part is accidental-discoverable, and the first time a player mashes honk while floating in a dark lake with a loon calling back, the game should notice. |
| `view_from_up_here` | THE VIEW FROM UP HERE — *"On a roof, over a lake, in the dark, on two things. This is a lifestyle."* | Layers on a primary the player already wants, so the reveal lands as "oh, there was *more* to that" rather than as a separate errand. |

---

## 6. Integration — exact steps

> **⚠ ALREADY DONE, AND §6.2 IS NOW WRONG.** Verified 2026-08-04. All three
> scripts are in the repo, the zone is in the route, and the mission hook is in
> place (`mission_defs.gd:50` preloads `COTTAGE`; `mission_defs.gd:85-86`
> branches on `zone_id == &"cottage"`). Do not apply this section again.
>
> **`ZONE_ROTATION` no longer exists.** It was replaced by `ROUTE`, a fixed
> 8-entry array of `{zone, name, seconds}` dictionaries, when the game became
> finite and winnable — see `HANDOFF.md` §2. There is no modulo and no wrap.
> `zone_cottage.gd` currently appears at legs 4, 5 and 8 of `ROUTE` (legs 5–8
> reuse built zones as placeholders), **not** at leg 3 — leg 3 is
> `zone_suburbia.gd`, which is also where the Ranger encounter lives. Everything
> in this document that says "leg 3" means "the cottage zone" and has been true
> of a different leg number since the route landed.
>
> §6.1 also lists `tools/zone_tour.gd`, which was never committed. See §6.5.

### 6.1 Copy the files

```
scripts/world/zone_cottage.gd
scripts/world/prop_models_cottage.gd
scripts/core/mission_defs_cottage.gd
tools/zone_tour.gd            (optional, verification only — NEVER COMMITTED)
```

### 6.2 `scripts/core/main.gd` — the rotation  *(superseded — see the note above)*

Add one line to `ZONE_ROTATION`:

```gdscript
const ZONE_ROTATION := [
	"res://scripts/world/zone_strip_mall.gd",
	"res://scripts/world/zone_suburbia.gd",
	"res://scripts/world/zone_cottage.gd",
]
```

That's the whole change. `_zone_script_for_leg()` already wraps with
`(leg - 1) % ZONE_ROTATION.size()`, so leg 3 is cottage country, leg 4 is back to
the strip mall, and the loop is now a three-zone cycle. The zone already exposes
`goose`, `camera_rig`, `zone_title()` and `mission_zone_id()`, so nothing else in
`main.gd` needs touching.

### 6.3 `scripts/core/mission_defs.gd` — the objectives

Two edits. Add the preload beside the existing constants:

```gdscript
const COTTAGE := preload("res://scripts/core/mission_defs_cottage.gd")

const PRIMARY := 0
```

and one branch in `for_zone()`:

```gdscript
	match zone_id:
		&"strip_mall":
			out.append_array(_strip_mall())
		&"suburbia":
			out.append_array(_suburbia())
		&"cottage":
			out.append_array(COTTAGE.cottage())          # <-- add
		_:
			out.append_array(_generic())
	out.append_array(_universal_hidden())
```

`_filter_by_leg()` and `_universal_hidden()` then apply to the cottage set exactly
as they do to the other two, so `from_leg` gating, target scaling, reward scaling
and the seven universal hidden objectives all work with no further wiring.

> `mission_defs_cottage.gd` also exposes its own `for_zone(zone_id, leg)` with the
> same signature, so a harness can load it standalone. The one-line hook above is
> the shipping path.

### 6.4 `project.godot` — one optional setting

Nothing is *required*. The zone is tuned to sit exactly at the engine default:
**12 fixed lamps + 20 pickup lamps = 32**, and
`rendering/limits/opengl/max_renderable_lights` defaults to 32. If you ever add a
substance source here, raise it first or the renderer will start dropping lights:

```ini
[rendering]
limits/opengl/max_renderable_lights=48
```

Raising `limits/opengl/max_lights_per_object` above the default 8 is **not**
recommended — the zone already solves that by tiling its large surfaces, and
raising it costs shader time everywhere including the other two zones.

### 6.5 Verify

> **Corrected 2026-08-04.** Two problems with the original block: the first line
> was the fake compile gate (`--import` imports assets, it does not compile
> GDScript), and **`--tour`, `--audit` and `--views:` are not implemented** —
> `tools/zone_tour.gd` is not in this repo and `main.gd::_probe_if_headless()`
> has no such flags, so those two commands silently degrade to an ordinary probe
> and produce shots you did not ask for while looking like they passed.

```bash
godot --headless --path . -- --gate 2>&1 | grep '^\[gate\]'
godot --path . --rendering-driver opengl3 -- --probe --leg:3 --shots:3 --secs:3 --out:<dir>
godot --path . --rendering-driver opengl3 -- --probe --leg:3 --boss --secs:6 --out:<dir>
godot --path . --rendering-driver opengl3 -- --probe --leg:6 --shots:1 --secs:3 --out:<dir>
```

Leg 6 is worth running because it is where target scaling maxes out and the HUD
text is longest.

**Not available (kept as a wish-list, not a command):** a `--tour` mode with
named `--views:wide,cliff,dock` set-ups and an `--audit` pass. That needed a
four-line hook in `_probe_if_headless()` plus `tools/zone_tour.gd`; neither was
committed. The flags `main.gd` actually supports are listed in
`docs/ROUTE_DATA.md` §11.

---

## 7. What's still wrong

- **The ledges still read as courses of masonry from directly below.** They're
  box colliders because physics has to be predictable and a goose has to be able
  to land on one without the collision normal arguing with it; the dressing
  (boulders straddling every lip, talus at the foot, moss bands, scrub, fracture
  decals) breaks it up a lot but not completely. The honest fix is a real
  authored mesh with a separate simplified collider, which belongs in the same
  pass that turns all three zones into `.tscn` files.
- **32 omni lights is the zone's ceiling, and it's a hard one.** Any new
  substance source pushes it over the GL Compatibility default. §6.4 has the
  setting; it just isn't free.
- **No sound design of its own.** It borrows `amb_parking_lot` from `main.gd`
  like the other zones, which is wrong for a lake at night. The loon call is
  `honk_c` at 0.4 pitch and the toad is `goose_grumble` at 0.44 — both work
  better than they have any right to, but `tools/gen_audio.py` should get a real
  loon wail, crickets, and lapping water.
- **No buoyancy.** The swim state damps vertical velocity to zero rather than
  floating the bird to a surface, so a goose that dives in fast settles a little
  low for a second before the lake bed catches it. That's the existing
  controller's behaviour, not something this zone introduced, and it's most
  visible here because this is the first zone with real water. The tied canoe
  gets away with it by luck: its collider is 0.66 deep and the bed is 0.30 down,
  so a live rigid body settles at its designed draught with no faking at all.
- **`fleet_action` counts the tied canoe.** It's live physics rather than frozen,
  so a goose that shoves it scores `CANOE` without ever touching the three on
  the beach. That's arguably correct — it is a boat and you did put it in the
  water harder — but it makes the bonus slightly cheaper than intended.
- **The NPCs by the fire will occasionally walk off the cliff.** `NpcHuman` has
  gravity and a 22 m leash but no edge avoidance, so one eventually goes over.
  It lands in the lake and keeps wandering. Funny exactly once; a nuisance by
  the third time. Cheapest fix is an invisible wall along the shelf lip on the
  NPC's collision layer only.
- **The zone doesn't report `ON THE ROOF` for the cottage roof**, only for the
  boathouse. That's deliberate — `above_the_waterline` says "out in the lake"
  and there is only one candidate — but a player who lands on the cottage first
  will reasonably expect it to count.
