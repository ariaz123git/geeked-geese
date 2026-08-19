# HANDOFF — current state

**Updated:** end of the session that gave leg 1 a different game from leg 2,
gave each of the seven flights its own shape, turned the repo's own prose into
something a gate can fail on, and finally put a number on the glide.

> **How this file works.** `CLAUDE.md` holds the *rules* — they rarely change.
> This file holds the *state* — it changes every session. Read this first, then
> `docs/DECISIONS.md`, then CLAUDE.md. **Update the four ⟳ sections at the end of
> every session.** If it goes stale it is worse than useless, because the next
> session will trust it.
>
> **Numbers in this file are checked.** `tools/doctest.gd` recomputes them from
> the booted project on every `verify.ps1` run — see `docs/CLAIMS.md`. If you
> write a new number in here, give it a claim row or take it out.

---

## ⟳ 1. Where the project is right now

**The campaign is built, measured, and — as of this session — it is no longer
the same game twice.** Two things that the design documents had specified and
the code had never implemented are now implemented, and both had the same
shape: a spec table written in the language of the code, sitting in a markdown
file, that nothing loaded.

- **Legs 1 and 2 were 420 seconds of the same place with the same sixteen
  substances.** Leg 1 now offers three. The first rise of the escalation curve
  exists.
- **All seven interstitial flights were the same 85-second crossing.** Each now
  has its own duration, opening quiet, hazard density and mix, and flight 1
  cannot take a bird.

And the third thing is why this file now has a header telling you its numbers
are checked: a survey found **seven** live stale facts across four root
documents — three different texture counts in three files, a design bible
reading "2 zones" against eight, a README calling the built stopover "the last
placeholder in the route", and `CLAUDE.md`'s own line budget exceeded by 90%.
`docs/DECISIONS.md` was this project's answer to prose *decisions* rotting.
Nothing answered prose *facts* rotting. Now `--doctest` does.

| | |
|---|---|
| Engine | Godot 4.7.1, GL Compatibility renderer |
| Code | 72 GDScript files (read the live count off `[gate] PASS — N scripts`) |
| Zones built | 8 — retention pond / strip mall lot (one zone, two legs, **two shelves now**), suburbia, cottage country, the stopover, cut corn, truck stop, the 18th green |
| Route legs | 7 flown + the arrival |
| Substances | 16, all with models, control mutations, true codex facts and a HUD icon. **Leg 1 offers 3 of them**; every other leg offers its zone's full set |
| Flights | **7, and no two alike.** Hazards per crossing: 3.9 · 12.7 · 21.3 · 44.1 · 9.3 · 39.1 · 70.4. Flight 1 is `lethal: false` |
| Bosses | 2 — the Ranger (leg 3) and BIG DOWN (the back half of leg 7) |
| Assets | 40 textures (23 + 17 substance icons), 46 sounds (39 SFX + 7 zone ambience beds), 22 music stems — all procedurally generated |
| Autoloads | 10 (see `docs/ARCHITECTURE.md` §2 for the order and why it matters) |
| Gates | **11**: compile, invariants (862), controller (8), feel (22 metrics, 13 asserted), substances (135 over 16), flight (14), credit roll, claims (190), **audio (246 over 68 files)**, **footprints (45 over 15 kinds)**, full campaign. `.\verify.ps1`, about six minutes |
| Docs that check themselves | `--doctest` — every number in `docs/CLAIMS.md`'s table, `feeltest.gd`'s 13 windows against `FEEL_TARGETS.md`'s arguments, `CLAUDE.md`'s line ceiling, and the five-entry cap on `docs/RECENT_FAILURES.md`. Plus `selftest::_the_docs()`, which seeded the idea |
| Decisions | `docs/DECISIONS.md` — **26 entries.** Four are `Open (human)` and must not be closed by an agent: D-005, D-006, D-007, D-019. Seven new this session, D-020 to D-026 |

### What is new this session, in one line each
Leg 1 is a tutorial shelf (D-022) · seven flights have seven shapes (D-023) ·
the documents are gated (D-024) · the failure log is capped and evicted by
conversion (D-025) · `CLAUDE.md` has a downward-only line ratchet (D-026) ·
bread is specced and deliberately unbuilt (D-020) · the tutorial shelf must
offer one lag-free control (D-021).

### What is specced but not built
- **Bread** — `CAMPAIGN_SPEC.md` §2.1's fourth leg-1 item and the thesis of the
  whole game. **D-020**, with the reason it is a shelf-wide change rather than a
  one-`if` one.
- **The Ranger's leg 6 exam** (`BOSS_DESIGN.md` §2.1.4). D-013 records the real
  blocker as a sound no agent can hear.
- **Multiplayer** (`MULTIPLAYER_SPEC.md`) — and it should not be next.
- **The Zamboni**, correctly deferred to a winter zone that does not exist.

---

## ⟳ 2. What changed last session

### 1. Leg 1 is a different game from leg 2

`zone_strip_mall.gd::_sources()` built all sixteen substances unconditionally
and the file had **no leg branch anywhere**, while `CAMPAIGN_SPEC.md` §2.1 gives
leg 1 three and §2.2 gives leg 2 *"all sixteen — this is where the lid comes
off"*, with the spec's own intensity column going 2 → 4 across that boundary.

`TUTORIAL_SHELF` is `berries, double_double, grass`, and the reason it is those
three is in the file: berries teaches that a substance is a control mutation and
not a score bonus, double_double is why aiming at the sweet spot is worth the
risk, grass is `infinite` so the dose arc can be practised without spending
anything — and **the set is closed under the game's own mixing rule**, since
`MAX_STACK` is 2, leg 1's `double_parked` primary requires two substances at
once, and `berries|double_double` is THE WOBBLER. `selftest` asserts that a
named combo is reachable rather than trusting it.

`_source()` is now the only function in the file that can build a pickup: the
grass patches used to construct their own because they needed `infinite`, and a
leg filter is only as good as its narrowest choke point.

**The check is in two places and both are needed.** `selftest.gd::_the_shelf()`
reads the declaration (12 static invariants). `main.gd --loop-test` counts what
the **director actually built**, on every leg:

```
[loop] shelf census: leg1=3 leg2=16 leg3=10 leg4=16 leg5=16 leg6=6 leg7=4
```

That line is the first route-wide statement of the substance curve that has ever
existed. Both were watched failing, and the second canary is the one that
matters: with the declaration correct and the guard in `_source()` bypassed,
**selftest passes and only the census catches it** — which is the
`stamina_restore` shape (D-017/D-018) caught before the fact instead of after.

### 2. Seven flights, seven shapes

`migration.gd` had `TARGET_DISTANCE := 2000.0` as its only termination test and
never read the leg, so every crossing ran 2000 / 23.46 = **85.3 s** and rolled
its hazards from a flat `randi() % 3`. Half the game was one flight served seven
times. `docs/ROUTE_DATA.md` §1.3 had shipped the per-flight table since it was
written and nothing loaded it.

`FLIGHTS` now carries seconds, lethality, opening quiet, spawn interval, hazard
probability and hazard mix per leg. Fields ROUTE_DATA declares that no code reads
(`sky`, `ground`, `km`, `put_down`) are deliberately **not** copied in — D-017's
rule, applied before the fact.

The shape is not a ramp, and that is the point: flight 4 is a local peak, flight
5 out of the Stopover drops to 9.3 hazards, flight 7 is the summit at 70.4. The
Stopover exists to be a recovery beat and would mean nothing followed by the
hardest crossing yet. `migtest` grew five measurements and a per-leg build
census (9 → 14), checking three different kinds of thing: that the table is well
formed, that it has the shape the design argues for, and that **each leg's
migration is actually built with those numbers**. The canary that reverts the
table to the old uniform flight reproduces `~33 obstacles` exactly — the number
the previous HANDOFF recorded for the old build — which is why the formula is
trusted rather than convenient.

### 3. The claims gate: the ninth, and the only one pointed at the prose

`docs/CLAIMS.md` lists every number the repo writes into a document and where.
`tools/doctest.gd` recomputes each from the booted project on every run. **182
claims at the first green run.** It also binds `feeltest.gd`'s thirteen
`_assert_window` literals to the windows `FEEL_TARGETS.md` argues for — two
copies of the same thirteen numbers with nothing comparing them, where the half
carrying the *argument* was the half free to drift.

**Nothing in `CLAIMS.md` stores an expected value.** The alternative shape —
entries with counters or freshness stamps maintained by a reflection pass —
needs a loop that runs every session and is honest about its own work, and a
hand-maintained freshness stamp is stale metadata about staleness.

It found a bug in itself on its first run: the metric-name character class
`[a-z_.]` silently dropped `ground.turn_180`, so it counted 12 windows where
there are 13.

### 4. Two mechanisms that make the next session cheaper

**`docs/RECENT_FAILURES.md`, capped at five, evicted only by conversion**
(D-025). The Reflexion shape: write on failure, store the diagnosis not the
transcript, hard-cap the buffer. An entry leaves only when it has been turned
into an assertion, a hook or a deleted footgun, named in the same commit. The
cap is the forcing function — it is the only reason a lessons file ever gets
*smaller*, and `CLAUDE.md`'s own lessons list is unbounded and permanent.

**A downward-only line ratchet on `CLAUDE.md`** (D-026). `README_KIT.md` said
the file was *"under 200 lines on purpose"*; it was 379 and nothing noticed. The
ratchet fired within an hour of being written — documenting `--doctest` pushed
the file to 390, and paying for it meant compressing the dead-gates section
(which `tools/gate.gd` already argues in full) and the architecture preamble.
Net: 379 lines **with a ninth gate documented**.

### 5. The substance gate stopped blaming cats, and every step now reads stderr

`--substancetest` went red with `offaxis 1.099` between two sober runs while
`turnrate` and `climb` agreed to `0.000`. That is a cat — leg 1 builds seven and
none stop for a measurement. It started **now** because narrowing leg 1's shelf
removed thirteen `SubstancePickup` constructions, every one of which consumed
`randf()`; `main._ready()` calls `randomize()`, so the cats' spawn positions come
off the same stream. **A change with nothing to do with cats moved every cat.**
That is F-002 and it is not retired: the retake loop added to `substancetest`
treats the symptom for one harness.

And `verify.ps1` was checking for `SCRIPT ERROR` on **one of its nine steps**.
Now all nine do, through one shared helper. That is half of F-001; the other
half — `ERROR: N resources still in use at exit`, printed by two green gates
since before this session — is diagnosed, not fixed, and the file says exactly
what was tried and measured.

### 6. D-006 has its number, and it is concentrated rather than spread

`tools/glidetest.gd` — **a report, not a gate**, because the decision is taste
and an agent must not close it. It walks every zone the director builds, finds
every static box collider whose top face fits the goose capsule, and asks which
elevated surfaces are reachable from another **by gliding alone**.

```
[glide] 168 standable surfaces, 113 of them elevated above 1.5 m
[glide] 0.85 : 1  ->   42 of 113 elevated surfaces glide-reachable (37%)
[glide] 3.00 : 1  ->   86 of 113 elevated surfaces glide-reachable (76%)   [+44]
```

The argument against widening the glide was that it *"would silently invalidate
every 'the goose cannot reach that' assumption in eight zone builders"*, and
nobody had counted it. Counted, the cost is not spread across the campaign:
**legs 1, 2 and 6 are identical at every ratio tested** — flat ground with a
building on it — while **suburbia goes from 0 of its 21 elevated surfaces to
16.** The longest glide available anywhere in suburbia today is **0.0 m**. It is
the leg that introduces height and it is built on getting between roofs costing
flaps; a 3:1 glide does not adjust that zone, it deletes its premise.

Five approximations are named in the file's header and every one errs toward
*reachable*, so the counts are ceilings. **D-006 stays Open (human).**

---

## ⟳ 3. What to do next

**Nothing here is waiting on you.** See `CLAUDE.md`, *"Taste is the human's.
Everything measurable is yours."*

### The four that are genuinely yours
Tracked as `Open (human)` in `docs/DECISIONS.md`. **An agent must not close
these.** D-006 the glide ratio, D-005 the hard-landing threshold, D-007 the truck
stop's closing beat, D-019 whether tolerance should stop softening penalties.
Items 1 and 2 below give two of them a *number* without closing them, which is
the highest form of help an agent can offer here.

### Ranked, for an agent

1. **Decide D-006, or don't — but it now has its number.** `tools/glidetest.gd`
   (`--probe --glidetest`, a report, not a gate) walked all seven zones:
   **168 standable surfaces, 113 elevated, 42 of them (37%) glide-reachable
   today and 86 (76%) at 3 : 1.** The cost is concentrated rather than spread —
   legs 1, 2 and 6 are identical at every ratio tested, while **suburbia goes
   from 0 of its 21 elevated surfaces to 16**, and the longest glide available
   in that zone today is 0.0 m. Full table and the five named approximations in
   `docs/FEEL_TARGETS.md` §5.1. **Still Open (human); an agent must not close
   it.** What is left is the same walk for D-005 (item 2), which reuses the same
   enumeration.

2. **Give D-005 its number.** `impact = absf(_last_y_speed)` against
   `hard_landing_speed` 13.0 with `glide_gravity` 11.0 makes the threshold a
   descent of **v²/2g = 7.68 m**, and **7 of the 16 substances set
   `ragdoll_landings`**. Write the closed form into `FEEL_TARGETS.md` §5.2 and
   count how many surfaces in each zone sit more than 7.68 m above their
   neighbour.

3. **Build bread** (D-020). It is `CAMPAIGN_SPEC.md` §2.1's fourth leg-1 item
   and the thesis of the game delivered before the player reads a word: the
   obvious food is the trap. It needs a `.tres`, a generated icon, an Almanac
   entry, a `you are full` mutation in `_tick_eat`, and it moves the number
   sixteen that four gates count. Now that leg 1 has a shelf of its own, it has
   somewhere to go.

4. **Retire F-002 rather than living with it.** Seed the probes' RNG, or give
   the zone builders a seed, so a build's actor layout is a function of the seed
   rather than of how many `randf()` calls happened to precede it. Every harness
   that measures inside a zone is exposed to this, and the failure always looks
   like a regression in whatever the harness measures.

5. **`tools/geomtest.gd` — the abandoned FOOTPRINTS checker**, from the built
   zone rather than from `build(kind, {})`. §4 records the attempt and the wall
   it hit. `FOOTPRINTS` is load-bearing (`build()` sizes with
   `want / footprint(kind)`), `down_bale` is suspected 8–12% small, and nothing
   has ever compared the declared box to the real mesh AABB.

6. **`tools/audiotest.gd` — assert what the WAVs *are*,** since nobody can hear
   them. The bug it could not see is in the record: the truck stop's "rain" was a
   0.700 s goose hiss that never looped. Duration bands per family, `loop_mode`
   on every `amb_*`, non-silence, no clipping. It must not claim anything
   *sounds* good.

7. **The remaining per-flight fields.** `ROUTE_DATA.md` §1.3 also gives each
   flight a `sky`, a `ground` and a `put_down` flag, and §5 gives a
   max-birds-lost-per-flight of 2 and a PUT DOWN altitude gate. None is wired,
   and per D-017 none should be copied into `FLIGHTS` until the code that reads
   it exists.

8. **Cut two things.** `scripts/ui/objectives.gd` (169 lines) is instantiated
   nowhere, while `zone_strip_mall.gd`'s `objectives()` still returns a
   six-entry list that disagrees with `mission_defs.gd` about the cart target —
   a second, disagreeing objective list for the first zone the player sees.

9. **Lower the `CLAUDE.md` ratchet.** It is at 379 against a target of 200, and
   the research is specific about why it matters: the file is loaded into every
   session **and every subagent**, and adherence degrades with instruction
   *count*, with silent omission as the dominant error. The candidates are named
   in D-026 — the architecture description (derivable from
   `docs/ARCHITECTURE.md`, which exists) is the biggest block that is
   description rather than instruction.

### Recorded, decided without measuring, and revertible
`stamina_restore` pays out (D-018) — delete one `if` in `_tick_eat` to revert.
Leg 1's shelf is three substances (D-022) — one constant to revert. The seven
flights' numbers are ROUTE_DATA's, not measured against a player (D-023).

---

## ⟳ 4. Known issues and honest gaps

### NEW THIS SESSION — survived an adversarial refutation panel, NOT fixed

Twenty-seven of the audit's 37 survivors were left alone, deliberately: the ten
that were fixed are in §2, and the ones below are recorded with their arithmetic
so the next session can act without re-deriving anything. **Each was checked by
an agent that did not find it, told to refute it and to default to refuted when
unsure.** Ranked.

**Tolerance shrinks PENALTIES toward neutral, which is the inverse of the
documented economy.** `docs/ARCHITECTURE.md` §3 and `substance.gd`'s own comment
both say it: *"Tolerance scales the good parts and never the bad ones. That
asymmetry is the entire economy."* `resolve()` picks `good` or `bad` **per
field**, but every one of the four multipliers is a benefit on one side of 1.0
and a penalty on the other, so each is right for only half its range. Measured
across the shelf at tolerance 3 (`tol = 1/(1+0.35·3) = 0.488`):

| | |
|---|---|
| Penalties **softened** by tolerance (8 substances) | percs' flap 0.80 → 0.90 and speed 0.70 → 0.85; grass 0.88 → 0.94 / 0.78 → 0.89; also bars, berries, gravy, robo, special_k, toad_slime |
| Benefits **immune** to tolerance (8 substances) | double_double's turn stays 1.50 at every tolerance, molly's 1.20, darts' 1.05; special_k's gravity stays 0.55, toad_slime's 0.70, and four more |

So **the fourth percocet impairs you less than the first**, and the tenth
double-double turns exactly as sharply as the first. The doc's own worked
example — *"the fourth double-double gives you less speed and the same jitter"* —
is one of the cases that is correct; nobody wrote an example for the four that
are not. **The fix is to select the scale by the DIRECTION of the value rather
than by the field name**, which is a handful of lines. Not done here because it
makes six substances materially more punishing at tolerance and no instrument in
this project can evaluate that. Note also that `gravity_mult` below 1.0 is
genuinely ambiguous — floatier is a traversal *benefit* and a control
*impairment* — so that one is a design call, not arithmetic.

**`substancetest`'s `DOSE = 0.6` is an OVERDOSE for acid and percs**, which
contradicts the constant's own comment (*"inside the sweet band of every
substance in the shelf, so `resolve()` returns quality 1.0"*). Acid's `sweet_max`
is 0.55, percs' is lower still. So two of the sixteen have been measured on the
`overdosed` branch with `bad = 1.6` the whole time, and the printout has never
said so. `[0.45, 0.55]` is in band for all sixteen (highest `sweet_min` is
nitrous at 0.45, lowest `sweet_max` is acid at 0.55), or dose each substance at
`clampf(0.6, sweet_min, sweet_max)`.

**`gg_share` pays 75 chaos and a combo link on every key press**, with no
cooldown and no cost once the flock is saturated. The honk has a 0.22 s cooldown
for exactly this reason; the share has none, and does not check whether it moved
anything.

**Six authored objectives are gated behind `from_leg` values their zone never
reaches**, including the game's only chain-length primary (`sustained_campaign`).
`no_brakes` and both `variety_pack` rows are the cheap ones — lower `from_leg` to
the zone's real leg. `sustained_campaign` needs a home in a zone that runs at
leg 5+.

**The results card's short-landing clock is derived from the NEXT leg's base**,
but landing short replays the CURRENT leg. Add a `short_zone_base` beside
`next_zone_base` in `evaluate_leg()`'s result.

**The results card's CHAOS note quotes un-multiplied objective rewards** while
claiming they are the amounts inside the multiplied chaos figure.

**`juice.gd`'s non-negotiable rule "HITSTOP HAS EXACTLY FIVE CALL SITES" is
false — there are eight.** The honest fix here is not a corrected comment but the
project's own idiom: an invariant that greps `scripts/` for `Juice.hitstop(` and
asserts both the count and each site's `(seconds, strength)` against a table
declared in `juice.gd`. A rule in prose is the failure mode `CLAUDE.md`'s banner
is about.

**`no_early_exit` travels the whole pipeline and is read by one thing:
`almanac.gd`, which prints a line about it.** There is no early-exit verb in the
game, so the Almanac states a rule about the player's options that is not true.
It is also in `selftest`'s `CONTROL_KEYS`, which means a substance could satisfy
the design rule with a field that mutates nothing.

**Placement arithmetic, each with both numbers:** leg 6's double-double pickup
sits **inside the grain truck's cab** because the placement ignores the truck's
0.14 rad yaw; Suburbia's island lamp collider is centred **0.6 m too high**, so
it floats and overhangs its own luminaire; about **a quarter of leg 1's lawn
signs spawn in the retention pond**; the recycling bin's chevron badge floats
**8.6 cm** in front of the tub; and `LowPolyBuilder.wedge()` closes **only one of
its two ridge ends**, leaving a hole in every model that uses it.

**Cosmetic but real:** `_flap_anim` is decayed only inside `_tick_fly`, so one
standing hop leaves the wings flapping at full rate for the rest of the leg; the
lowpoly goose's webbed feet sit 5–10 cm **below** the collider and are underground
whenever the bird stands; `Prefs` never flushes on quit, so a settings change made
inside the 0.4 s debounce is lost; and `almanac.layer = 20` in `_build_overlays()`
is overwritten by the Almanac's own `_ready()`.

**Gaps in the gates themselves, named honestly:**

- **`input_lag` has no behavioural coverage in any of the nine gates.** It is
  the field that caused this project's most expensive bug — eleven of sixteen
  substances unplayable — and `substancetest` counts it as satisfying the design
  rule while asserting nothing about it. Same for `grid_snap`.
- **Nothing exercises the eating verb through the path the player uses.** Every
  harness reaches into `Subs.take()` directly, so `_tick_eat`'s charge arc, the
  sweet-spot band, the abort, the pickup's `consumed()` and the SWEET SPOT /
  OVERDOSE / BARELY ANYTHING scoring have never been driven by a key. That is
  why `stamina_restore` could be dead with every gate green, and it is why its
  wiring is asserted **statically** rather than behaviourally.
- **`migtest`'s `lateral.half_cross` cannot fail unless `full_cross` fails too** —
  it is derived from the same drive rather than measured independently.
- ~~**`verify.ps1` checks for `SCRIPT ERROR` on one of its eight steps.**~~
  **Fixed 2026-08-18.** All nine steps do, through one shared `ScriptErrors`
  helper. It is `SCRIPT ERROR` and not a blanket `ERROR:` on purpose, and the
  helper says why: the compile gate legitimately prints 26 attributed lines, and
  two probes exit with `ERROR: N resources still in use` from a teardown
  ordering issue that is diagnosed and open. See `docs/RECENT_FAILURES.md`
  F-001, which this half retired.
- **The failsafe is armed after the first zone has already been built.**
  `_arm_failsafe()` runs partway through `_ready()`, so a crash or stall before
  that point is still an invisible process.

---
### Carried forward from previous sessions


**THE GLIDE IS 0.85–0.87 : 1 AND NOBODY HAS DECIDED WHETHER THAT IS RIGHT.** A
metre forward per metre down is a controlled fall, and
`GEEKED_GEESE_DESIGN.md:130` promises *"chain it into a safe glide and you're
fine"*. It is now asserted in `feeltest.gd` **as a regression guard only** —
centred on today's value so `glide_gravity`, `air_speed` or `max_fall` cannot
move traversal silently — and the design question is written up in
`docs/FEEL_TARGETS.md` §5.1 with the argument on both sides. Changing it is one
line and it invalidates "the goose cannot reach that" in eight zone builders.

**A 20 m glide arrives at 20.9 m/s against a `hard_landing_speed` of 13.0.**
Sober that is a 15-point "ROUGH LANDING" and a small shake — a reward. On any
substance with `ragdoll_landings` it is an unavoidable faceplant on every
descent from height, and nothing in the game teaches flaring on approach. Either
a good implicit lesson or an unfair one; that depends on playing it.
`FEEL_TARGETS.md` §5.2.

**The truck stop's closing beat is proportional, not absolute.** The rig
schedule leaves exactly 6.0% of the leg as empty lot at every clock — 13.8 s at
leg 7's new 230 s, but 6.6 s at Mission's 110 s floor. A readable moment is
arguably absolute (a human needs ~10 s to notice an empty lot whatever the clock
says). One line in `zone_truckstop.gd::_clock_scale()`. Not changed, because
nothing specifies it and it is pacing.

**One substance channel still declares its own resolution and asserts nothing.**
A `turn_mult` within 10% of 1.0 cannot be told from noise by the peak-turn-rate
measurement; `darts` at 1.05 is the only case, and it is asserted on climb
instead (its `flap_mult` of 1.12 puts one flap 68% above sober). The printout
says so on every run rather than hiding it.

**A sweep for this project's own documented failure modes came back clean, and
two things that LOOK like violations are not.** Worth recording so the next
session does not re-flag them:

- `migration.gd:508`'s `lerpf(target.y, player_pos.y, 0.85)` looks like the
  framerate-dependent smoothing `CLAUDE.md` forbids. It is not: `target` is
  rebuilt from scratch every frame, so this is a fixed blend of two same-frame
  values, and the actual smoothing on the next line is
  `lerp(target, clampf(3.4 * delta, ...))`, which is correct.
- `cat.gd`, `npc_human.gd` and `boss_ranger.gd` all read `is_on_floor()` before
  `move_and_slide()`. That is the benign grounded-walker pattern — one frame of
  stale floor state costs 0.37 m/s of gravity that the slide resolves anyway.
  The goose's version WAS a real bug because it gated a landing EVENT, which is
  a different thing, and it is already fixed and commented.

Also checked and clean: no duplicate `class_name`, no Godot 3 syntax anywhere,
no `contact_monitor` set true without `max_contacts_reported`, no
`CollisionShape3D.disabled` written outside `set_deferred`, no duplicate
resource ids, no invented `uid://`. The two mechanical ones are now invariants
(`selftest.gd::_the_files()`) so they stay clean.

**THE ZONE IS ALIVE WHILE ANYTHING IS BEING MEASURED, and all three
input-driving gates are exposed to it.** Leg 1 builds seven cats that wander at
2.6 m/s and a lot of loose shopping carts; none of them stop for a measurement.
Observed across this session's runs:

- `feeltest` read a top speed of **7.37 m/s** once — faster than `waddle_speed`
  (4.2) *and* `swim_speed` (5.4) — and failed the build on a healthy
  controller. **Fixed:** the walk is now retaken up to three times when the
  measured speed exceeds `waddle_speed × 1.25`, and reports a harness fault if
  all three are disturbed.
- `inputtest` read `sober walk: 2.40 m` on the final run of the session against
  its usual 3.79, and **passed anyway** — its thresholds are deliberately loose
  (`sober > 1.0`), which is exactly what its header says they are for. Not a
  bug, but it means its numbers are not comparable run to run.
- `substancetest`'s `speed` column is a diagnostic and asserted on nothing, so a
  shove shows up in the printout and fails nothing. Its asserted channels
  (drift vector, turn rate, climb) were bit-stable throughout.

If a future gate needs a quiet zone, the lever is pausing the actors — but note
that a measurement taken in a dead world is measuring a different game.

**MIGRATION IS MEASURED NOW, AND EVERY CHANNEL MATCHES ITS PREDICTION.**
`migtest.gd` (step 5b) drives a real flight headless: the corridor crossing is
**1.53 s** against a predicted 1.53, the half crossing 0.77 against 0.76, climb
2.55 against 2.54, dive 1.48 against 1.46, sink 1.60 against 1.60, and the honk
rally pulls the worst drifter in to ×0.11 of its drift against the ×0.15 the
code applies. All six asserted channels hold.

It did not start there. For one commit the crossing measured **4.50 s** and this
section called it *the top open question in the project* — **the tree was
paused.** `migration.gd`'s `process_mode` is INHERIT, so a paused tree stops its
`_process` and all of `_tick_player` with it; the harness unpaused once on entry
and a card re-paused it. The gate now reports 178 paused frames = 2.97 s against
a discrepancy of 4.50 − 1.53 = 2.97 s. `_tick()` un-pauses, counts, and does not
bill those frames to the game. `docs/FEEL_TARGETS.md` §6 keeps the full
post-mortem, because the shape of it is worth more than the fix.

~~**Leg 1's world-space labels collide.**~~ **Fixed and re-rendered.** The flock
pen's prompt read `[G] …AKE GOR… THE DD` — an unreadable smear. Two causes, and
only the second one mattered: every label shared `render_priority = 1`, so the
prompt sorted equally against six birds' decorative name tags; and it sat at
y = 1.03, **below head height on a 1.3 m bird**, so the geese standing in front
drew their necks straight through it.

`no_depth_test` was NOT the answer and stays off — `_label()` gives the reason
and it is a good one: a label that shines through the strip mall wall tells the
player their flock is inside the building. Instead the prompt now sits at 1.66,
clear of the flock's own geometry, with `render_priority = 4` so it wins ties
against the tags. It reads `[G]  MAKE TERRY THE DD`, whole, in
`shots/gg_zone1_0.png` — which is gitignored, so regenerate it with
`--probe --leg:1 --shots:1 --secs:2`; the command is the durable artefact, not
the image.

Everything else in the twelve renders read correctly: leg 7's HUD clock says
**3:49** for its new 230 s, leg 5's dawn marsh is intact, and the Almanac shows
16/16.

**`FOOTPRINTS` is never checked against the meshes it describes, and it is not
documentation — it is load-bearing.** `prop_models.gd::build()` sizes with
`model.scale = want / footprint(kind)`, so a declared box that disagrees with
the mesh makes every `size:`-scaled placement wrong by exactly that error, in
every zone that asks for one. Nothing has ever compared the two, and
`docs/HANDOFF.md` already suspected `FOOTPRINTS[&"down_bale"]` of being 8–12%
small. **A checker was attempted this session and abandoned**: building every
kind through `build(kind, {})` crashed inside the builders, which want params
the empty dictionary does not supply. The idea is sound and the pattern is
`tools/feeltest.gd`; the work is figuring out the per-kind default params first.
Nothing was left in the tree.

**Nobody has heard any of the ambience beds, including the agent that generated
them.** There is no audio probe and no way to listen headless. What *has* been
measured, outside the engine: all seven loop with zero discontinuity at the wrap,
have stable envelopes, and have spectral centroids that separate sensibly
(lake-night lowest at 1521 Hz, truck stop and corn up at ~4.8 kHz). That is
evidence, not the same thing as hearing them.

**Nobody has been inside the BIG DOWN warehouse.** The exterior, the lit atrium,
the signage and the roof beat are all photographed and correct. The interior —
an 11 m dark box lit only by racking lights — has never been looked at from
inside, and its tri budget (~45k for the full encounter) has never been measured
against a frame.

**`glazier` counted shatter EVENTS, not panes, and the file said otherwise.**
`mission.gd:784` advances a label counter by exactly +1 per scoring call
regardless of its amount, and `boss_big_down.gd` deliberately batches a whole
shatter into one `Game.score()` so the combo bumps once. The objective's own
comment claimed the batch "advances this by six"; it advanced it by one, so a
player who took out two storeys with a single honk watched the row sit at 1 of
10. The encounter now also emits one `pane_broken` note per pane and the
objective counts that event — the score stays batched, the count is honest.
**Not re-rendered; the arithmetic is in the comment at both sites.**
> **And that fix shipped with a leftover.** The old whole-event note was never
> deleted, so from then until this session every shatter emitted **n + 1** and
> `glazier` completed on roughly half the panes. Fixed; see §2.9. The pattern is
> worth naming: *a counting bug fixed by adding a second emitter is not fixed
> until the first emitter is gone.*

**BIG DOWN's two bonus objectives never reach the HUD, and the fix is a design
call somebody has to make.** `mission_hud.gd` draws at most two BONUS rows and
queues the rest; the truck stop already ships five, and BIG DOWN's `soft_inventory`
and `glazier` are appended after them, so the player walks into a warehouse full
of down bales and a glass atrium and the panel says nothing about either. Every
mechanical fix collides with the design: putting them first announces an
encounter that `docs/BOSS_DESIGN.md` §2.2.2 insists opens *"with no
announcement"*; raising the row cap changes every zone; making them HIDDEN gives
counted objectives reveal semantics they do not fit. The honest options are (a)
accept the announcement, (b) let the encounter swap the visible bonus set when
the dock opens, or (c) leave them as pure score. **Not guessed.**

**KNOWN, EVIDENCED, NOT FIXED — all from the same audit, all in BIG DOWN, and
all needing either a render or a judgement I would not make blind.**

- **The pane "Ears" are in the `npc` group, so every honk inside the tower
  scores a HONK.** `honk.gd` pays out whenever it hits anything in that group,
  which means the truck stop's "Honk at 16 things that did not ask" primary can
  be finished entirely indoors by mashing H at a wall. `cat.gd::_nearest_victim`
  sweeps the same group out to 55 m and cannot tell a bodiless Ear from a person,
  so a frenzied cat would path 40 m south toward one it can never reach.
  **The clean fix now exists and I did not take it:** `honk.gd` gained a `honked`
  signal this session, so the encounter can listen for real honks directly and
  the Ears can leave the `npc` group entirely. That is surgery on the boss's
  central mechanic and it must be rendered, so it waits.
- **The curtain wall is not a barrier** — a 1.52 m open gap at each end and a
  1.08 m band at every storey line, so a goose can fly past the glass without
  breaking it. §2.2.4's premise is that the honk is the only navigation verb that
  works in a glass box.
- **A whippet honk from outside can trigger the weather early.** One honk clears
  more glass than the encounter budgets for, and three of six top-storey panes is
  the trigger.
- ~~**`collider_boxes(&"racking")` promises a clear full-width deck at every beam
  level and the mesh fills it.**~~ **Measured, rendered and fixed.** The numbers,
  from the constants: the deck collider is `RACK_DEPTH × 0.92` = **1.012 m** deep
  and full bay width; the bales are half-depth 0.435 at z = 0 and half-width 0.56
  at `cx ± 0.62` on a 2.70 bay. That leaves a clear strip of **0.07 m at the aisle
  face and 0.17 m at the bay edges** — and **the goose capsule is 0.68 m wide and
  1.10 m long.** There was nowhere on any level it could stand: it landed on the
  promised collider and was inside the bales, which is precisely what breaks the
  "one level per flap" argument the 1.70 m pitch exists for.
  **Confirmed by the first render ever taken inside the warehouse**
  (`--probe --leg:7 --goto:-2,5.5,-70`), and fixed by leaving one stock slot in
  four empty, chosen off the seeded wobble the stock already uses so the gaps are
  deterministic. Re-rendered: the gaps are visible and the place still reads as
  the white cliff it is supposed to.
- Smaller, all evidenced: the `fill_power_sign`'s second line is buried inside
  its own emissive panel and its hazard chevrons float; the bale stencil's first
  line is 20% wider than the label it sits on; `shutter_set_closed` hides half a
  slat too many; the atrium's mullion pitch (1.75 m) disagrees with the pane
  pitch the encounter uses; `FOOTPRINTS[&"down_bale"]` is 8–12% smaller than the
  mesh it describes.

**The bales are not trampolines.** `docs/BOSS_DESIGN.md` §2.2.3 wants them
bouncy; they are 22 kg rigid bodies that get shoved. A goose rebounding off one
needs code in `goose_controller.gd::_resolve_collisions`, which would change how
*every* prop in the game feels.

**The man in the tower is in a dark shirt, not a suit.**
`human_visual_lowpoly.gd` has no jacket, collar or tie geometry. The briefcase
reads perfectly; the suit does not.

**BIG DOWN's sprinklers and blackout are unbuilt.** §2.2.4 lists four boss moves;
the shutter and the lift-as-departure exist. The blackout is nearly free —
`prop_models_bigdown.gd` exposes `FloorLights/Bank0..N` for exactly it.

**FIXED FROM EVIDENCE, NOT RE-RENDERED.** The adversarial audit ran out of
session budget partway through; its verifiers died and the harness recorded the
findings as "killed" because no vote survived — a bookkeeping artefact, **not a
refutation**. Three came with enough evidence to act on and were fixed, but the
machine was in use and a render probe opens a real GL window, so **none of the
three has been looked at since the fix. Photograph them before trusting them:**

```
godot --path . --rendering-driver opengl3 -- --probe --leg:5 --goto:5,1,-17 --look:Goose --secs:3 --out:<dir>
godot --path . --rendering-driver opengl3 -- --probe --leg:5 --goto:4.15,1,-6 --secs:25 --shots:2 --out:<dir>
```

- **The refuge sign sat inside the chase camera's rest position.**
  `goose_camera.gd`'s SpringArm has `collision_mask = 1` and `_model_at()` builds
  no collider, so a 2.5 m board was invisible to the rig and filled the screen
  for anyone standing where both of this zone's bonuses send them. Both placards
  now have a hidden `StaticBody3D`, like the dyke and the tower already did.
- **Mist banks drifted onto the dyke and across the camera.** `_tick_mist()`
  wrapped only at ±54 m and never kept a bank over water. There is now a
  `MIST_KEEP_OUT` corridor that reflects a bank's velocity rather than wrapping
  it, so it turns around before its edge reaches the gravel.
- **Grazing residents walked off their own ground and hovered.** The section's
  own rule is that no wander spread may walk a bird off its surface, and one
  shared 1.8 m spread broke it on the 2.20 m road crown. Spread is now per bird:
  the road grazers get 0.65 and the island's south bird 1.0.

**Checked and deliberately left alone**
- `cat.gd:216` and `npc_human.gd:168` read `is_on_floor()` before
  `move_and_slide()`, which is the rule the goose's landing check was hoisted to
  obey. For a walker that never leaves the ground it has no symptom — the idiom
  is "cancel accumulated gravity while grounded", and last tick's answer is
  right whenever the state is not changing. Changing it would alter how every
  NPC in every zone sits on a slope, for nothing. **Not a bug. Do not "fix" it
  without a symptom.**

**Bugs**
- `prop_models.gd::_house` has a gable seam where the wall triangle meets the
  roof soffit. Visible up close, invisible at gameplay distance.
- Two engine warnings at shutdown (`ObjectDB instances leaked`). Reproduces on a
  stock project with one looping sound; it is engine shutdown ordering.
- The results card is optimistic by 60 s after a migration that landed short — it
  is computed before the flight, so it cannot know. Design question, not drift.
- Two independent `pallet` models with disagreeing footprints in two libraries.
- `SceneTree.create_timer()`'s `ignore_time_scale` defaults to **false**, so every
  timer in the project is time-scaled. Mostly harmless, occasionally not.
- Hallucination fakes never re-probe the ground while walking, so one that starts
  on the cottage plateau and walks 24 m ends up in mid-air.

**A HEADLESS RUN CAN NO LONGER BECOME AN INVISIBLE PROCESS.**

Every tool branch in `main.gd::_probe_if_headless()` is
`preload("res://tools/x.gd").run(...)`, with the quit living inside the tool. So
a tool that fails to COMPILE — one Variant-inference typo is enough, and it is
the most common error in this codebase — yields a broken GDScript, the call
raises `Invalid call. Nonexistent function 'run'`, the branch never reaches a
quit, and the engine drops into an ordinary main loop with no window and no
vsync.

On 2026-08-17 a `--selftest` run did exactly that and ran for **eighteen hours
at 100% of a core**, doing nothing. It was invisible: the shell that launched it
had long since timed out and let go, so no task list showed it. It held the
launcher's process tree open, which blocked that launcher from updating itself,
and the only previously-known cure was a reboot. The parse error that caused it
was fixed four minutes later; the process outlived the fix by a day.

`_arm_failsafe()` now sets a wall-clock deadline before anything dispatches —
240 s for the tool flags, 900 s for render probes, `--failsafe:N` to override.
A healthy run exits long before it fires. Canary-proven: break a tool on purpose
and the process exits in 9 s with code 2 and an explanatory line, instead of
never.

**Noise that is not a bug**
- The gate prints 26 × `ERROR: Parameter "method" is null.` while parsing
  `briefing.gd`. Bisected and attributed; the file compiles and loads fine. This
  is why the documented gate command filters to `^\[gate\]`.
- Render probes print an ALSA error in containers with no sound card.

**Untested by anyone who can actually play**
Still everything. See §3.

---

## 5. The documents, and what each is for

| File | What it is |
|---|---|
| `GEEKED_GEESE_DESIGN.md` | The original design bible. Vision, tone, the substance table. |
| `docs/ARCHITECTURE.md` | **How the code is wired, and which architecture arguments are settled.** |
| `docs/CAMPAIGN_SPEC.md` | The build plan. Route, intensity curve, flock balance, the ending. |
| `docs/ROUTE_DATA.md` | Per-leg data tables extracted from the above. |
| `docs/WIN_CONDITIONS.md` | The decision doc that chose the campaign shape. Read for *why*. |
| `docs/BOSS_DESIGN.md` | The Ranger and BIG DOWN, fully specced. |
| `docs/BOSS_RANGER_BUILD.md` | What the Ranger actually became, and where it deviates. |
| `docs/FINALE_NOTES.md` | The ending: what it does, and what it deliberately does not. |
| `docs/ZONE_CORN_NOTES.md` · `ZONE_TRUCKSTOP_NOTES.md` · `ZONE3_NOTES.md` | Per-zone build notes. Read before touching that zone. |
| `docs/MULTIPLAYER_SPEC.md` | Technical verdict + local split-screen modes. |
| `docs/DESIGN_MISSIONS.md` | The per-leg objective system, its research and schema. |
| `docs/CLOCK_AND_CAMERA_NOTES.md` | Two systems that each shipped the same bug twice. |
| `docs/ONBOARDING_NOTES.md` | Briefing cards, the V-formation diagram. |
| `docs/JUICE_NOTES.md` | Game feel, the intensity budget, the `time_scale` contract. |
| `docs/MUSIC_NOTES.md` | The score: stems, adaptive rules, what substances do to the mix. |
| `docs/prop_models_notes.md` | The prop library. |
| `docs/GODOT_4.7_RULES.md` | Engine API notes for a version newer than any model's training data. |
| `docs/GIT_SETUP_PROMPT.md` | Paste-ready prompt for setting up git + GitHub. |

---

## 6. Verifying

**On Windows, all nine gates in one command:**
```
.\verify.ps1            # compile, invariants, controller, feel, substances,
                        #   flight, credit roll, claims, campaign
.\verify.ps1 -Quick     # skips the slow three
.\verify.ps1 -Shots     # also renders every zone into .\shots\
```
**Every step now fails on `SCRIPT ERROR`.** Until 2026-08-18 only the campaign
step looked, so a harness could raise inside a branch its pass line did not
depend on, print PASS, exit 0, and be reported green — the same class as a gate
that cannot fail. One shared `ScriptErrors` helper, and the reason it matches
`SCRIPT ERROR` rather than a blanket `ERROR:` is written at that helper: two
known-benign and one known-open stderr condition would otherwise make the build
permanently red. See `docs/RECENT_FAILURES.md` F-001.

**9. The claims gate** — new, and the only one pointed at this repo's own prose:
```
godot --headless --path . -- --doctest 2>&1 | grep '^\[doctest\]'
```
Every number a document states is recomputed from the booted project;
`feeltest.gd`'s thirteen windows are checked against the arguments
`FEEL_TARGETS.md` makes for them; `CLAUDE.md` is held to a downward-only line
ceiling; `RECENT_FAILURES.md` is held to five entries. See `docs/CLAIMS.md`.
`verify.ps1` was rewritten this session because **not one of its four old steps
could catch the bug it was supposed to**: it ran `--import` (which never
compiled GDScript), `validate_project.gd` via `--script` (which false-fails on
every file touching an autoload), and gdformat/gdlint pointed at four
directories that do not exist. Its failure heuristic — any `ERROR:` on stderr —
would also have permanently red-flagged the real gate, which legitimately prints
26 lines of attributed noise. Each step now states the exact line that means
PASS and checks the exit code. No heuristics.

**1. The compile gate.** Every `.gd` compiles, every `.tres`/`.tscn` loads:
```
godot --headless --path . -- --gate 2>&1 | grep '^\[gate\]'    # check ${PIPESTATUS[0]}
```
`[gate] PASS — N scripts, M resources, 0 failures` + exit 0. Add `--gate-verbose`
to print each path before it is parsed, which is how you attribute engine noise
to a file. **Do not go back to `--import | grep ERROR`;** `tools/gate.gd`'s
header explains at length why it never worked.

**2. The invariant harness** — new. The gate proves the code compiles; this
proves the game **agrees with itself**:
```
godot --headless --path . -- --selftest 2>&1 | grep '^\[selftest\]'
```
Every assertion in `tools/selftest.gd` is a bug that already got through once:
the two clocks disagreeing (which shipped three separate times), a `ROUTE.name`
read by nothing, a zone id silently falling through to the generic objective
set, a substance with no HUD icon, an audio key with no `.wav`. It also enforces
the one design rule with a machine-checkable form — **no substance may be only a
number that goes up** — by asserting every `.tres` carries at least one control
mutation.

**3. The controller, with its hands on it** — new, and the only check that
presses a key:
```
godot --headless --path . -- --probe --inputtest 2>&1 | grep '^\[input\]'
```
`tools/inputtest.gd` holds W, flaps, honks and doses, and asserts the bird
actually did something. It exists because an input-lag bug that made eleven of
the sixteen substances unplayable got past the compile gate, the invariants
**and** the full campaign run — none of which had ever touched an input. Its
canary is proven: reverting the fix makes a goose on bars cover **0.00 m** in a
full second of held forward, and the gate still passes.

**4. The credit roll, measured** — new. The ending's fifth beat is marble slabs
walking up the fairway, and its drive has now been wrong twice; both times the
symptom was a SPEED that took four to six minutes of watching the ending to
notice. Physics runs headless, so measure it:
```
godot --headless --path . -- --probe --rolltest 2>&1 | grep '^\[roll\]'
```
Canary-proven: with the old `_physics_process` drive it measures **0.00 m/s**.

**4b. Feel, measured** — new this session, and the first gate with an opinion.
22 controller metrics, 13 asserted against windows argued out one by one in
`docs/FEEL_TARGETS.md`:
```
godot --headless --path . -- --probe --feeltest 2>&1 | grep '^\[feel\]'
```
It caught a flap that COMPOUNDED — 7.36 m of climb in the first second of
holding the button and 23.66 m in the third — on a build where all five older
gates passed. Canary-proven: reverting `_flap()` to `maxf(velocity.y, 0.0) +
power` puts `climb_convergence` at 3.22x against a window of [0.55, 1.40].

**4c. The substances, doses measured** — new this session. The design rule at the
top of `scripts/core/substance.gd` was enforced only by reading the `.tres`; this
doses all sixteen and measures the bird:
```
godot --headless --path . -- --probe --substancetest 2>&1 | grep '^\[subs\]'
```
102 checks. Canary-proven by breaking the PATH from data to controller rather
than the data itself — dropping `drift` in `_aggregate()`, `turn_mult` in
`_tick_ground()` and `flap_mult` in `_flap()` all fire, as does shortening a
substance below the length of its own measurement.

**BOTH NEW GATES SPENT THEIR FIRST RUNS ACCUSING A HEALTHY GAME.** Leg 1 is the
retention pond and the goose spawns in it, so "ground" metrics measured
`_tick_water()`. Sink rate sampled at terminal velocity compares `max_fall` to
itself. The substance fingerprint outlasted a 7 s nitrous. Read the comments
before believing a failure: both files carry a measured noise floor and
contamination guards that name themselves as harness faults.

**5. The whole campaign, headless, in about twenty seconds:**
```
godot --headless --path . -- --probe --loop-test
```
It should reach `[run] COMPLETE` and then `leg 8`. If it stops early, read the
`[loop] t=… phase=… current=…` lines — it prints what it is stuck behind.

**Render probes** — and read the PNGs.
```
godot --path . --rendering-driver opengl3 -- --probe --leg:3 --shots:2 --secs:3 --out:<dir>
godot --path . --rendering-driver opengl3 -- --probe --leg:3 --boss --secs:6   # the Ranger
godot --path . --rendering-driver opengl3 -- --probe --finale --secs:33        # the credit roll
godot --path . --rendering-driver opengl3 -- --probe --migration --secs:2.5    # the flight
godot --path . --rendering-driver opengl3 -- --probe --fx --sub:fly_agaric
godot --path . --rendering-driver opengl3 -- --probe --ui                      # menus
godot --path . --rendering-driver opengl3 -- --probe --leg:7 --look:BossBigDown
```

> **Three flags that matter more than they look.**
>
> `--out:<dir>` — where the PNGs go. It used to be the bare literal `/tmp` at
> twelve call sites, and `Image.save_png()` *returns* an error rather than
> raising one, so **on Windows every probe printed `[probe] wrote …` while
> writing nothing at all.** The probe now checks the return and exits non-zero
> if a shot failed.
>
> `--secs:N` — seconds between shots, and **the one to use for anything on a
> timer.** `--frames:N` counts frames, and every probe command in this file used
> to be calibrated against a container rendering in software at ~2 fps, where 26
> frames is thirteen seconds. On a machine with a GPU the same command is four
> tenths of a second — which is why `--probe --leg:3 --boss` photographed an
> empty cul-de-sac three seconds before the truck arrives, and looked exactly
> like a boss that had failed to spawn.
>
> `--look:<NodeName>` — frame something that is not the goose. The chase camera
> starts behind the bird facing where the bird faces, which is correct for the
> game and useless for photographing an encounter that arrives from behind.
> `--boss` implies it.

**Regenerating assets** (optional; the outputs are committed):
```
cd tools && python3 gen_textures.py && python3 gen_audio.py && python3 gen_music.py
```
Needs `numpy` and `pillow`. `gen_music.py` takes ~30 s and writes 33 MB.

---

## 7. How this session worked, for whoever picks it up

Built in Cowork with heavy use of parallel subagents — one per independent
workstream (a zone, a boss, the ending, the roster, a bug list). That works well,
with three caveats earned the hard way:

**1. Give agents disjoint file ownership, explicitly, by path.** Every prompt
this session listed the files that agent owned and named the files other agents
were in. Zero conflicts across nine agents.

**2. "Render it and read the PNG" is non-negotiable.** Every agent that only
compile-checked shipped something visibly broken. Every agent that rendered found
real bugs — geese standing on an awning, a dog buried to its knees, a sign
reading backwards, a whole encounter pinned against its own truck. None of those
are findable by reading code.

**3. Agents find bugs outside their brief, and those are the valuable ones.** The
dead compile gate, the phantom leg 8, the double-advancing migration signal and
the name collision in `_clear()` were all found by an agent reading a file for
context. Ask for them explicitly, and tell agents to report rather than fix.

The one thing that would have saved the most time this session: **checking that
the gate actually failed on a bad file, at the start rather than at the end.** A
verification step nobody has verified is worse than none, because it launders
guesses into claims.
