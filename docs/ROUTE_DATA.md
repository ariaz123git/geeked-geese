# GEEKED GEESE — ROUTE DATA

*Companion to `CAMPAIGN_SPEC.md`. This is the file you implement from. Everything
here is a literal value intended to be typed into the project.*

---

## 1. The `ROUTE` constant

Replaces `ZONE_ROTATION` at `scripts/core/main.gd:16`. Suggested home:
`scripts/core/route.gd` as a `RefCounted` with a `const ROUTE` and a couple of
lookup helpers, preloaded by `main.gd` — keeping it out of `main.gd` keeps the
director readable and makes the route diffable on its own.

### 1.1 Entry schema

```gdscript
{
  "leg":       int,          # 1..8, redundant with the index, kept for readability
  "id":        StringName,   # Mission zone id. Must match zone.mission_zone_id()
  "zone":      String,       # script path. "" means this leg has no zone.
  "variant":   StringName,   # set on the zone node BEFORE add_child(). &"" = default
  "name":      String,       # "THE RETENTION POND"
  "region":    String,       # "Mississauga, Ontario"
  "seconds":   float,        # base zone clock, before mission/migration modifiers
  "par_scale": float,        # multiplies PAR_BASE for this leg. 1.0 = normal
  "required_override": int,  # required primaries; -1 = use required_primaries()
  "rest":      {"intox": float, "stamina": float},   # applied ON ARRIVAL at this leg
  "brief":     StringName,   # briefing card id, or &"" for none
  "fact":      StringName,   # Almanac route fact shown on THIS leg's flight-end card
  "music":     StringName,   # Music.STEMS key
  "flight":    Dictionary,   # see 1.2. null on leg 8.
}
```

### 1.2 `flight` sub-schema

```gdscript
{
  "name":         String,     # "THE 401" — shown on the flight-end card
  "km":           int,        # distance flown this flight
  "to_florida":   int,        # km remaining AFTER this flight. Straight-line, not cumulative.
  "seconds":      float,      # duration at integrity 1.0. target_distance = seconds * 23.46
  "lethal":       bool,       # false = no bird may be lost on this flight
  "first_spawn":  float,      # seconds of empty sky before the first spawn
  "interval":     Vector2,    # [min, max] seconds between spawn attempts
  "obstacle_p":   float,      # 0..1 chance a spawn is an obstacle; remainder is a thermal
  "mix":          {"wires": float, "turbine": float, "wind": float},   # sums to 1.0
  "sky":          StringName, # &"overcast_day" | &"golden" | &"night" | &"dawn" | &"haze" | &"night_rain"
  "ground":       StringName, # &"suburb" | &"forest" | &"lake" | &"farm" | &"coast" | &"interstate"
  "put_down":     bool,       # PUT DOWN HERE available (always true from flight 6)
  "put_down_hint":bool,       # show the one-time prompt
}
```

`target_distance = seconds * BASE_SPEED * 1.15 * 0.6 = seconds * 23.46`, which
preserves the existing relationship in `migration.gd:306–307` (`speed = 34 *
lerp(0.55, 1.15, integrity)`, `distance += speed * delta * 0.6`).

### 1.3 The table

```gdscript
const ROUTE := [
{
  "leg": 1, "id": &"pond",
  "zone": "res://scripts/world/zone_strip_mall.gd", "variant": &"pond",
  "name": "THE RETENTION POND", "region": "Mississauga, Ontario",
  "seconds": 240.0, "par_scale": 0.50, "required_override": 2,
  "rest": {"intox": 1.00, "stamina": 1.00},
  "brief": &"zone_first_run", "fact": &"fact_retention_ponds", "music": &"cottage",
  "flight": {
    "name": "THE 401", "km": 12, "to_florida": 1842, "seconds": 45.0,
    "lethal": false, "first_spawn": 6.0, "interval": Vector2(2.8, 4.2),
    "obstacle_p": 0.35, "mix": {"wires": 1.00, "turbine": 0.00, "wind": 0.00},
    "sky": &"overcast_day", "ground": &"suburb",
    "put_down": false, "put_down_hint": false,
  },
},
{
  "leg": 2, "id": &"strip_mall",
  "zone": "res://scripts/world/zone_strip_mall.gd", "variant": &"mall",
  "name": "THE STRIP MALL LOT", "region": "Mississauga, Ontario",
  "seconds": 180.0, "par_scale": 1.00, "required_override": -1,
  "rest": {"intox": 1.00, "stamina": 1.00},
  "brief": &"", "fact": &"fact_canada_goose", "music": &"strip_mall",
  "flight": {
    "name": "OVER THE QEW", "km": 38, "to_florida": 1812, "seconds": 70.0,
    "lethal": true, "first_spawn": 4.0, "interval": Vector2(2.0, 3.2),
    "obstacle_p": 0.50, "mix": {"wires": 0.70, "turbine": 0.30, "wind": 0.00},
    "sky": &"overcast_day", "ground": &"suburb",
    "put_down": false, "put_down_hint": false,
  },
},
{
  "leg": 3, "id": &"suburbia",
  "zone": "res://scripts/world/zone_suburbia.gd", "variant": &"",
  "name": "SUBURBIA", "region": "Oakville, Ontario",
  "seconds": 180.0, "par_scale": 1.00, "required_override": -1,
  "rest": {"intox": 0.75, "stamina": 0.60},
  "brief": &"", "fact": &"fact_moult_migration", "music": &"suburbia",
  "flight": {
    "name": "THE WRONG WAY", "km": 190, "to_florida": 1995, "seconds": 80.0,
    "lethal": true, "first_spawn": 3.0, "interval": Vector2(1.6, 2.6),
    "obstacle_p": 0.58, "mix": {"wires": 0.50, "turbine": 0.30, "wind": 0.20},
    "sky": &"golden", "ground": &"forest",
    "put_down": false, "put_down_hint": false,
  },
},
{
  "leg": 4, "id": &"cottage",
  "zone": "res://scripts/world/zone_cottage.gd", "variant": &"",
  "name": "COTTAGE COUNTRY", "region": "Muskoka, Ontario",
  "seconds": 180.0, "par_scale": 1.00, "required_override": -1,
  "rest": {"intox": 0.60, "stamina": 0.45},
  "brief": &"", "fact": &"fact_flightless", "music": &"cottage",
  "flight": {
    "name": "THE LONG HAUL", "km": 640, "to_florida": 1360, "seconds": 110.0,
    "lethal": true, "first_spawn": 3.0, "interval": Vector2(1.2, 2.0),
    "obstacle_p": 0.66, "mix": {"wires": 0.45, "turbine": 0.30, "wind": 0.25},
    "sky": &"night", "ground": &"lake",
    "put_down": true, "put_down_hint": false,
  },
},
{
  "leg": 5, "id": &"stopover",
  "zone": "res://scripts/world/zone_cottage.gd", "variant": &"refuge",
  "name": "THE STOPOVER", "region": "Montezuma NWR, New York",
  "seconds": 150.0, "par_scale": 0.55, "required_override": 2,
  "rest": {"intox": 1.00, "stamina": 0.90},
  "brief": &"", "fact": &"fact_stopover", "music": &"cottage",
  "flight": {
    "name": "DOWN THE SUSQUEHANNA", "km": 690, "to_florida": 690, "seconds": 75.0,
    "lethal": true, "first_spawn": 5.0, "interval": Vector2(2.4, 3.6),
    "obstacle_p": 0.40, "mix": {"wires": 0.60, "turbine": 0.20, "wind": 0.20},
    "sky": &"dawn", "ground": &"forest",
    "put_down": true, "put_down_hint": false,
  },
},
{
  "leg": 6, "id": &"corn",
  "zone": "res://scripts/world/zone_corn.gd", "variant": &"",
  "name": "THE CUT CORN", "region": "Sampson County, North Carolina",
  "seconds": 180.0, "par_scale": 1.00, "required_override": -1,
  "rest": {"intox": 0.40, "stamina": 0.28},
  "brief": &"", "fact": &"fact_waste_grain", "music": &"suburbia",
  "flight": {
    "name": "THE FALL LINE", "km": 390, "to_florida": 310, "seconds": 95.0,
    "lethal": true, "first_spawn": 3.0, "interval": Vector2(1.2, 2.0),
    "obstacle_p": 0.68, "mix": {"wires": 0.40, "turbine": 0.35, "wind": 0.25},
    "sky": &"haze", "ground": &"farm",
    "put_down": true, "put_down_hint": true,
  },
},
{
  "leg": 7, "id": &"truckstop",
  "zone": "res://scripts/world/zone_strip_mall.gd", "variant": &"truckstop",
  "name": "THE TRUCK STOP", "region": "off I-95, Georgia",
  "seconds": 180.0, "par_scale": 1.00, "required_override": -1,
  "rest": {"intox": 0.35, "stamina": 0.25},
  "brief": &"", "fact": &"fact_power_lines", "music": &"strip_mall",
  "flight": {
    "name": "THE INTERSTATE", "km": 310, "to_florida": 0, "seconds": 130.0,
    "lethal": true, "first_spawn": 20.0, "interval": Vector2(0.9, 1.6),
    "obstacle_p": 0.80, "mix": {"wires": 0.55, "turbine": 0.10, "wind": 0.35},
    "sky": &"night_rain", "ground": &"interstate",
    "put_down": true, "put_down_hint": false,
  },
},
{
  "leg": 8, "id": &"green",
  "zone": "res://scripts/world/zone_green.gd", "variant": &"",
  "name": "THE 18TH GREEN", "region": "north Florida",
  "seconds": 0.0, "par_scale": 0.0, "required_override": 0,
  "rest": {"intox": 1.00, "stamina": 1.00},
  "brief": &"", "fact": &"fact_golf_courses", "music": &"green",
  "flight": null,
},
]
```

**Notes for the implementer**

- **`rest` is applied ON ARRIVAL at that leg**, i.e. it is what `rest()` grants at
  the end of the *previous* leg's flight. Leg 7's `{0.35, 0.25}` is what you get
  after flight 6, going into the truck stop. Leg 1's entry is never read (nothing
  precedes it). Leg 8's is cosmetic only — a full clear, so the survivors on the
  green render at full condition rather than at whatever the Interstate left them.
- `to_florida` on leg 3 is **higher** than leg 2's. That is deliberate and it is
  the joke. The map screen must be able to render an increase without treating it
  as an error.
- `music` for `pond` and `stopover` reuses the `cottage` (lake) stems; `corn`
  reuses `suburbia`; `truckstop` reuses `strip_mall`. Only `green` needs a new
  stem set. Add the aliases to `music.gd:94`'s alias table rather than duplicating
  `STEMS` entries.
- Leg 8's `seconds: 0.0` signals "no clock" to `Game.start_zone()`. Guard
  `zone_running = false` for leg 8 explicitly rather than relying on a zero
  timer, or `_process()` will immediately transition to MIGRATION.

---

## 2. Distance ledger

| After | Flight | km flown | Cumulative flown | km to Florida |
|---|---|---|---|---|
| — | *(start, on the pond)* | — | 0 | 1,850 |
| L1 | THE 401 | 12 | 12 | 1,842 |
| L2 | OVER THE QEW | 38 | 50 | 1,812 |
| L3 | **THE WRONG WAY** | 190 | 240 | **1,995 ▲** |
| L4 | THE LONG HAUL | 640 | 880 | 1,360 |
| L5 | DOWN THE SUSQUEHANNA | 690 | 1,570 | 690 |
| L6 | THE FALL LINE | 390 | 1,960 | 310 |
| L7 | **THE INTERSTATE** | 310 | **2,270** | **0** |

Credits line: **`2,270 KM FLOWN. 1,850 IN A STRAIGHT LINE.`**

---

## 3. Wall-clock budget

| Leg | Zone | Results card | Flight (@ integrity 0.65) | Flight card | Leg total |
|---|---|---|---|---|---|
| 1 | 240 s | 25 s | 52 s | 12 s | 5:29 |
| 2 | 180 s | 25 s | 81 s | 12 s | 4:58 |
| 3 | 180 s | 25 s | 93 s | 12 s | 5:10 |
| 4 | 180 s | 25 s | 128 s | 12 s | 5:45 |
| 5 | 150 s | 25 s | 87 s | 12 s | 4:34 |
| 6 | 180 s | 25 s | 110 s | 12 s | 5:27 |
| 7 | 180 s | 25 s | 151 s | 0 s | 5:56 |
| 8 | 270 s (arrival + honk) | — | — | 120 s (credits) | 6:30 |
| | | | | **TOTAL** | **≈ 43:50** |

Plus briefings (~60 s across the run) and menu time. **≈ 45 minutes**, which is
exactly the band `WIN_CONDITIONS.md` §1.4 identified as "fits a sitting; the
escalation curve completes exactly here."

Under **EASY FLYING** flights run ~15% longer (slower stamina drain means more
time in ragged formation is survivable, not faster) — budget 48 minutes.

---

## 4. `Flock.rest()` curve

Replaces the unconditional heal at `flock_state.gd:114`.

```gdscript
## Sober up + heal between legs. Intoxication clears; scars don't.
## The amount recovered comes from the route: the first half of the flyway is
## forgiving and the second half remembers. The Stopover is the only full clear
## in the back half, and it is the whole reason that leg exists.
func rest(arriving_at_leg: int) -> void:
	var r: Dictionary = Route.rest_for(arriving_at_leg)
	var i: float = r.intox
	var s: float = r.stamina
	if Rungs.has(&"hard_water"):        # Ascension rung 4
		i *= 0.5
		s *= 0.5
	for b in birds:
		if not b.alive: continue
		b.intox   = maxf(0.0, b.intox - i)
		b.stamina = minf(1.0, b.stamina + s)
```

| Arriving at | intox cleared | stamina restored |
|---|---|---|
| 2 — Strip Mall | 1.00 | 1.00 |
| 3 — Suburbia | 0.75 | 0.60 |
| 4 — Cottage | 0.60 | 0.45 |
| **5 — The Stopover** | **1.00** | **0.90** |
| 6 — The Cut Corn | 0.40 | 0.28 |
| 7 — The Truck Stop | 0.35 | 0.25 |
| 8 — The Green | 1.00 | 1.00 *(cosmetic only)* |

---

## 5. Attrition constants

| Constant | Old | New | File |
|---|---|---|---|
| intox stamina burn | `0.012` | **`0.045`** | `migration.gd:433` |
| `DRAIN_LEAD` | `0.028` | unchanged | `migration.gd:31` |
| `DRAIN_DRAFT` | `-0.020` | unchanged | `migration.gd:32` |
| drop-out grace at zero stamina | — | **`3.0 s`** | new |
| max birds lost per flight | — | **`2`** | new |
| distress threshold (pip flashes, honk every 4 s) | — | **`0.15`** | new |
| rally targets lowest stamina below | — | **`0.20`** | `migration.gd:351` |
| rally stamina grant | — | **`+0.06`** | `migration.gd:351` |
| rally per-bird cooldown | — | **`8.0 s`** | new |
| PUT DOWN available after | — | **40% distance** | new |
| PUT DOWN altitude gate | — | **`Y_MIN + 4`** held **1.5 s** | new |
| PUT DOWN rescue threshold / grant | — | **below 0.20 → +0.15** | new |
| Stopover top-up floor | — | **3** | new |
| blanket share dose | `0.32` | unchanged | `goose_controller.gd:660` |
| aimed pen share dose | `0.42` | unchanged | `flock_pen.gd:72` |

### 5.1 Why 0.045 — the arithmetic

Draft recovery at integrity *g* is `0.020 * lerp(0.2, 1.0, g)`. Intox burn is
`intox * k`. Net stamina change per second for a drafting bird:

| intox | burn @ k=0.045 | recovery @ g=0.60 | net | time to zero from 1.0 |
|---|---|---|---|---|
| 0.0 (DD) | 0.000 | +0.0104 | **+0.0104** | never |
| 0.2 | 0.0090 | +0.0104 | +0.0014 | never |
| 0.3 | 0.0135 | +0.0104 | −0.0031 | 322 s — survives any single flight |
| 0.5 | 0.0225 | +0.0104 | −0.0121 | 83 s — **dies on flight 4 or 7** |
| 0.65 | 0.0293 | +0.0104 | −0.0189 | 53 s |
| 0.9 | 0.0405 | +0.0104 | −0.0301 | 33 s |

Read against the share costs: **one blanket share is 0.32 and is survivable.
Two is 0.64 and is not, on a long flight.** That is the price the share key was
always supposed to carry.

---

## 6. Mission-system deltas

The system in `DESIGN_MISSIONS.md` survives essentially intact. Exhaustively,
here is everything that changes:

| # | Change | Kind |
|---|---|---|
| 1 | `from_leg` / `until_leg` now mean **route authoring**, not difficulty scaling. Leg 6 is the corn field and gets corn objectives. | semantics only, no code |
| 2 | `target_scale()` — **unchanged.** Its 1.9× cap at leg 6 now lands exactly on the last full-pressure zone. A happy accident; leave it. | none |
| 3 | `required_primaries()` gains one line: `if route.required_override >= 0: return route.required_override`. Used by legs 1 and 5 only. | small |
| 4 | `par` gains a cap and a per-leg scale: `PAR_BASE * min(1 + 0.15*(leg-1), 1.75) * route.par_scale`. **This is `TR#2` and it is a bug fix.** | bug fix |
| 5 | Four new zone ids: `pond`, `stopover`, `corn`, `truckstop`. Until each has a `mission_defs` entry, `_generic()` covers it — **so every new leg is playable the day its geometry exists.** | data |
| 6 | Leg 8 never calls `begin_leg()`. `main.gd` skips `_setup_objectives()` and `_show_results()` when `route.seconds == 0.0`. | small |
| 7 | Two new hidden objectives at the Stopover (§7 below) and two at the corn field. | data |
| 8 | `evaluate_leg()` — **unchanged.** Soft fail, grading, style score, flock note, all as-is. | none |

---

## 7. New objective sets (outline)

Enough to build from. Full `cond` trees follow the grammar in
`DESIGN_MISSIONS.md` §2.2. House rules apply: never name a substance in visible
text; every objective completable while causing chaos; write like a person who
finds this funny.

### 7.1 `pond` — leg 1 · 4 primaries (need 2), 3 bonuses, 1 hidden

| kind | id | text | cond sketch |
|---|---|---|---|
| P | `first_honk` | Honk at {n} things that did not ask | `label HONK`, target 6 |
| P | `get_in_the_water` | Get in the water. You're a goose. | `stat water_time >= 4.0` |
| P | `sweet_science` | Land {n} doses in the sweet spot *(watch the meter, not the vibes)* | `stat sweet_spots`, target 2 |
| P | `pond_scum` | Introduce {n} things to physics | `label []` (any), target 10 |
| B | `share_the_wealth` | Share what you're on with the flock, {n}× *(they will remember this in the air)* | `event shared`, target 1 |
| B | `cart_in_the_pond` | There is already a shopping cart in there. Add to it. | `label CART` when `in_water` |
| B | `name_a_driver` | Pick somebody to stay clean | `event dd_designated` |
| H | `dont_eat_the_bread` | **"THAT WASN'T FOOD"** / *"Half a loaf of white bread. You are, technically, full."* | `event sub_taken id=bread` |

**The bread hidden objective is the most important string in leg 1.** It fires
the first time anybody eats the obvious thing, unlocks the first Almanac page,
and teaches that hidden objectives exist — the job `outburst` does elsewhere.

### 7.2 `stopover` — leg 5 · 4 primaries (need 2), 4 bonuses, 2 hidden

| kind | id | text | cond sketch |
|---|---|---|---|
| P | `take_the_air` | Get {n} seconds of continuous air | `sustain airborne`, 10 s |
| P | `meet_the_locals` | Honk at {n} geese who were having a nice morning | `label LOCAL GOOSE`, target 8 |
| P | `sweet_science` | Land {n} doses in the sweet spot | target 3 |
| P | `mind_the_flock` | Get {n} of your flock back above half | `stat flock_stamina_min >= 0.5` — **the only flock-condition primary in the game** |
| B | `birdwatcher` | Be observed | `label SCOPE` |
| B | `tower` | Get on the observation tower | `label ON THE TOWER`, no_scale |
| B | `name_a_driver` | Pick somebody to stay clean *(if you haven't)* | `event dd_designated` |
| B | `variety_pack` | Wreck {n} different kinds of thing | `unique labels` |
| H | `slept_on_it` **late** | **"SLEPT ON IT"** / *"You sat on a pond for two and a half minutes and did absolutely nothing. Your flock has never been fitter."* | `stat subs_taken == 0`. `flock: {stamina: +0.25}` |
| H | `not_a_rest_stop` **late** | **"THIS IS NOT A REST STOP"** / *"Everyone was having a nice morning."* | `stat peak_subs >= 3`. No penalty — the penalty is that you skipped the heal. |

### 7.3 `corn` — leg 6 · 6 primaries (need 4), 4 bonuses, 2 hidden

| kind | id | text | cond sketch |
|---|---|---|---|
| P | `combine_harvester` | Get in the way of the harvest, {n}× | `label COMBINE NEAR MISS` |
| P | `silo` | Get on top of the silo | `label ON THE SILO`, no_scale |
| P | `open_ground` | Cross the stubble {n}× without landing | `sequence` |
| P | `sweet_science` | Land {n} doses in the sweet spot | target 5 |
| P | `bale_out` | Introduce {n} round bales to physics | `label BALE`, cap 9 |
| P | `low_flying_aircraft` *(leg 5+)* | Land {n} hits without ever landing | as suburbia |
| B | `hide` | Spend {n} seconds inside the corn | `sustain in_corn`, 8 s |
| B | `the_dog` | Ruin one dog's entire year | `label DOG` |
| B | `scarecrow` | Settle the scarecrow question | `label SCARECROW` |
| B | `share_the_wealth` | *(as elsewhere)* | |
| H | `combine_harvester_2` | **"IT DOES NOT STOP"** / *"You were under it. It did not notice. It was never going to notice."* | pass under the combine while airborne |
| H | `grain_of_truth` | **"FERMENTED"** / *"This corn has been on the ground since September. So have you, mostly."* | take berries in the stubble |

### 7.4 `truckstop` — leg 7 · 6 primaries (need 5), 3 bonuses, 2 hidden

**These six must be completable without chemistry** — the shelf is four weak
substances and the requirement is the hardest in the game. See
`CAMPAIGN_SPEC.md` §2.7 and Appendix B.

| kind | id | text | cond sketch |
|---|---|---|---|
| P | `hitch` | Ride a truck out of the lot | `label RODE A TRUCK`, no_scale |
| P | `diner` | The window was load-bearing | `label DINER WINDOW` |
| P | `loud_lad` | Honk at {n} things that did not ask | target 14 |
| P | `dumpster_dive` | Introduce {n} things to physics in the corral | `label` in region |
| P | `no_brakes` | Wreck {n} things inside ten seconds | `window`, half-rate scaling |
| P | `sustained_campaign` | Get a {n}× chain going and hold it | as strip mall |
| B | `moths` | The lights have a following | `label MOTHS` |
| B | `nobody_awake` | Wake exactly one man up | `label SLEEPER CAB` |
| B | `puddle` | Cannonball the flooded corner | `label SPLASH`, no_scale |
| H | `last_call` | **"LAST CALL"** / *"There is almost nothing left here and you found all of it."* | take all four available substances in one leg |
| H | `three_am` | **"IT IS THREE IN THE MORNING"** / *"Nobody asked you to do this. Nobody asked you to do any of it."* | 2,000 chaos with zero substances active |

---

## 8. Almanac route facts

Text file. Shown one per leg on the flight-end card, where the player has already
stopped. Never mid-gameplay. Never a reward.

| id | Leg | Headline | Body (write to ~45 words) |
|---|---|---|---|
| `fact_retention_ponds` | 1 | **You live here because we built it.** | Stormwater retention ponds are a modern, human-made habitat: open water, no cover for predators, mown grass to the waterline. It's close to ideal goose habitat, and it's a large part of why some Canada geese stopped migrating at all. |
| `fact_canada_goose` | 2 | **It's a Canada goose.** | *Branta canadensis.* Named for the place, not the nationality. There is no such bird as a "Canadian goose," and the running gag in this game is not a joke about grammar. |
| `fact_moult_migration` | 3 | **Geese do fly the wrong way.** | Non-breeding and failed-breeding Canada geese undertake a *moult migration* — north, in summer, sometimes over a thousand kilometres, to moult somewhere with more food and fewer predators. It is one of the strangest true things about them. |
| `fact_flightless` | 4 | **Six weeks on foot.** | Geese moult their flight feathers all at once and cannot fly for roughly six weeks a year. They spend it near water, walking, and being extremely unpleasant about it. |
| `fact_stopover` | 5 | **Migration is mostly not flying.** | A migration is hops between staging areas where birds refuel. For most migrants, time spent refuelling exceeds time spent in the air — sometimes by a lot. The stopover is not a break from the migration. It *is* the migration. |
| `fact_waste_grain` | 6 | **Corn changed the map.** | Waste grain left in harvested fields is a major fuel source for migrating geese. The twentieth-century spread of corn agriculture measurably changed where North American geese migrate and where they spend the winter. |
| `fact_power_lines` | 7 | **This is why the wires are here.** | Collision with transmission lines and towers kills a significant number of large birds every year. It is why bird diverters and marker balls exist on spans near wetlands — bright plastic spheres, strung on the wires, so something can see them. |
| `fact_golf_courses` | 8 | **A golf course is a goose's idea of heaven.** | Short grass, open sightlines, standing water, no hunting, no predators. Golf courses built close to perfect goose habitat and are now surprised about the geese. |

### 8.1 The bread entry — and the dispute

`data/substances/bread.tres` → `codex_fact`:

> **Bread is a bad idea, and one of the reasons everybody gives is contested.**
> Bread has very little of what waterfowl need, and a bread-heavy diet is widely
> blamed for **angel wing**, a wing deformity in growing birds. The nutritional
> mechanism is plausible and partly supported — but the direct causal link
> between bread specifically and angel wing is thinner than the internet's
> confidence about it, and researchers disagree. Feeding bread to waterfowl is
> still a bad idea for reasons that don't depend on the disputed part.

This is the first Almanac page the player ever unlocks, and putting a live
scientific dispute on it sets the register for the whole codex. It is the design
bible's reindeer-and-fly-agaric rule applied at the front door.

---

## 9. The Ascension rules

One text file, one screen. Rungs unlock cumulatively by finishing the route;
once unlocked, each rule can be toggled independently.

```gdscript
const RUNGS := [
  {"id": &"late_start",     "name": "LATE START",        "desc": "Every zone is 15 seconds shorter."},
  {"id": &"thin_pickings",  "name": "THIN PICKINGS",     "desc": "30% fewer substances in every zone."},
  {"id": &"no_top_up",      "name": "NO TOP-UP",         "desc": "Nobody joins you at the Stopover."},
  {"id": &"hard_water",     "name": "HARD WATER",        "desc": "The flock recovers half as much between legs."},
  {"id": &"the_long_way",   "name": "THE LONG WAY",      "desc": "One more objective required, every leg."},
  {"id": &"still_air",      "name": "STILL AIR",         "desc": "No thermals. Anywhere."},
  {"id": &"short_flock",    "name": "SHORT FLOCK",       "desc": "You leave with five."},
  {"id": &"no_passengers",  "name": "NO PASSENGERS",     "desc": "Being sober is not the same as being safe."},
  {"id": &"headwind",       "name": "HEADWIND",          "desc": "Every flight is 15% longer."},
  {"id": &"late_departure", "name": "THE LATE DEPARTURE","desc": "Winter catches you.", "content": true},
]
```

Implementation notes:

- Each of rungs 1–9 is a single conditional at one call site. Listed in
  `CAMPAIGN_SPEC.md` §7.1.
- **Rung 10 is content**, not a rule — it is where the deferred winter zone lives.
  Ship 1–9 first.
- **Nothing is ever gated.** Every substance, zone, joke and Almanac page is
  available at rung 0.
- Persist in `Prefs` as `ascension_unlocked: int` (highest rung reached) and
  `ascension_active: Array[StringName]` (what's toggled on for the next run).

---

## 10. `Prefs` additions

| Key | Type | Default | Purpose |
|---|---|---|---|
| `memorial` | `Array[Dictionary]` | `[]` | `{name, leg, cause, run}` — every goose lost, all runs. Printed in the credits. Capped at 200 entries, oldest dropped. |
| `runs_finished` | `int` | `0` | Drives the second-run text layer. |
| `ascension_unlocked` | `int` | `0` | Highest rung reached. |
| `ascension_active` | `Array[StringName]` | `[]` | Rules on for the next run. |
| `best_by_rung` | `Dictionary` | `{}` | `{rung_signature: {time, chaos, geese_home}}`. |
| `easy_flying` | `bool` | `false` | The accessibility toggle. **Never surfaced anywhere in the ending.** |
| `clock_scale` | `float` | `1.0` | 0.75 / 1.0 / 1.5 multiplier on every zone clock. |

---

## 11. Verification

> **Corrected 2026-08-04.** Three things in this table were wrong:
>
> 1. `godot --headless --path . --import` **does not compile GDScript** — it
>    imports assets, and a file with this project's most common parse error
>    passes it in silence. The gate is `godot --headless --path . -- --gate`
>    (`tools/gate.gd`).
> 2. **None of the harness files named below exist in this repo.** `tools/`
>    contains only `gate.gd` and the three `gen_*.py` generators. The rows marked
>    **new** were always a *plan*; the `mission_harness.gd` row was not, and it
>    is not reproducible.
> 3. The `route_harness.gd` row asserts *"leg 8 sets `Phase.RESULTS`"*. **That is
>    no longer the shipped behaviour.** `main.gd::_finish_run()` installs
>    `zone_finale.gd` and deliberately does **not** set `Phase.RESULTS` — see
>    `docs/FINALE_NOTES.md` §1, which explains that a RESULTS phase leaves
>    `Music`'s migration watchdog armed and drags the flight cue back over the
>    ending. A harness written to the assertion below would fail against correct
>    code.

| Tool | What it proves |
|---|---|
| `godot --headless --path . -- --gate` | Every `.gd`/`.tres`/`.tscn` compiles and loads inside the booted project. Exit 0 is the only pass. |
| `tools/mission_harness.gd` *(does not exist)* | The 82 existing checks still pass, plus new cases for `par_scale`, `required_override` and the four new zone ids. |
| **new** `tools/route_harness.gd` *(does not exist)* | Walks all 8 legs headless: every `zone` path loads, every `id` has a `mission_defs` entry or falls to `_generic()`, `to_florida` reaches exactly 0, wall-clock sums to 42–48 min, ~~leg 8 sets `Phase.RESULTS`~~ **→ leg 8 hands off to `zone_finale.gd` via `_finish_run()` and leaves the phase alone**. |
| **new** `tools/flight_harness.gd` *(does not exist)* | 3 archetypes × 200 runs × 7 flights. Asserts careful median ≥ 5, typical mode = 4, reckless median ≤ 2, floor = 1 always, modal first loss on leg 4. **This is the gate on M6.** |
| `main.gd --loop-test` *(exists)* | Extend to `--route-test`: drives all 8 legs on 4-second clocks and prints every phase transition. (The "ending at `Phase.RESULTS`" expectation is stale — see note 3 above.) |
| `tools/mission_hud_probe.gd` *(does not exist)* | Add a probe for the flight roster strip and the flight-end map card. `_draw()` never runs headless, and both are `_draw()`. |

**Probe flags that actually exist** in `main.gd::_probe_if_headless()`:
`--gate`, `--selftest`, `--inputtest`, `--probe`, `--migration`, `--fx`, `--ui`,
`--close`, `--finale`, `--roster`, `--boss`, `--loop-test`, `--brief-zone`,
`--brief-flight`, `--brief-recap`, plus `--sub:<id>`, `--leg:N`, `--shots:N`,
`--frames:N`, `--secs:F`, `--out:<dir>`, `--look:<NodeName>` and
`--goto:x,y,z`. Anything else in this repo's docs is aspirational.

> **Prefer `--secs:` to `--frames:`.** Frames are frame-rate dependent and every
> `--frames` value written in this repo was calibrated against a container
> rendering at about 2 fps. `--out:` is effectively required — the default write
> location on Windows is not `/tmp`, and the probe used to claim a write it had
> not made.
