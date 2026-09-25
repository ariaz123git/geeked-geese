# HANDOFF — current state

> # ▶ THE QUEUE IS §3 BELOW.
>
> **The human set the format on 2026-09-20: autonomous sessions.** The
> 2026-09-25 session worked the whole of the queue `docs/NEXT_SESSION.md`
> carried and kept going; §3 is the new queue, ranked. `NEXT_SESSION.md` now
> holds what is the human's, with the reasoning behind each.
>
> **Still the human's, and an agent must not decide them:** making substances
> required (it overrides `BOSS_DESIGN.md` §3.5 in writing), cat petting (they
> asked to discuss it), and the `Open (human)` decisions listed in §3.

**Updated:** 2026-09-25, after one long autonomous session — D-054 to D-081 —
that kept sweeping for controls wired to nothing and found the seam was not
exhausted. It found a pad that could play one zone and never leave it, a
Settings panel that did not do what four of its rows said, a flight that paid
the player NOT to fly in formation, a tutorial card that taught the flight's one
rule backwards, and an ending that floated a score over the goose on the one
screen specced to have none. Every gate now shares nothing with the player's
save, and `docs/RECENT_FAILURES.md` is empty.

> **How this file works.** `CLAUDE.md` holds the *rules* — they rarely change.
> This file holds the *state* — it changes every session. Read this first, then
> `docs/DECISIONS.md`, then CLAUDE.md. **Update the four ⟳ sections at the end of
> every session.**
>
> **Numbers in this file are checked.** `tools/doctest.gd` recomputes them from
> the booted project on every `verify.ps1` run — see `docs/CLAIMS.md` — and
> `verify.ps1` checks the gate table below against the gates that printed it.
> If you write a new number in here, give it a claim row or take it out.

---

## ⟳ 1. Where the project is right now

**The campaign is built, measured, and — as of this session — driven the way a
player drives it.** Seven legs, seven flights that differ, two bosses and an
ending. What changed is the verification: the gates used to prove that code did
what code said, and a run of sessions found that this repo's most repeated bug
is a control that is advertised and connected to nothing. So the gates now send
real input — keys, pad buttons, both sticks, clicks pushed into the viewport —
through the path a player's input takes, and assert what the far end did.

- **Every menu, card and overlay is reachable and closable on a keyboard and a
  pad**, every pause-menu button answers a real click, and every Settings row
  reaches the thing it controls.
- **Every verb the README names has been pressed by a harness except mouse
  look**, which no headless run can drive — in the zone, in the flight and at
  the ending, the flight's lead handoff and the ending's honk for the first time
  this session.
- **The gates are hermetic**: a run with arguments neither reads nor writes the
  player's save, and `verify.ps1` fails if one does.
- **A gate that hangs is killed** with its last lines printed, and **a gate
  that leaks an audio stream at exit is red.**

| | |
|---|---|
| Engine | Godot 4.7.1, GL Compatibility renderer |
| Code | 73 GDScript files (read the live count off `[gate] PASS — N scripts`) |
| Zones built | 8 — retention pond / strip mall lot (one zone, two legs, **two shelves**), suburbia, cottage country, the stopover, cut corn, truck stop, the 18th green |
| Route legs | 7 flown + the arrival |
| Substances | **17.** Leg 1 offers 4 (berries, double-double, grass, **bread**); every other leg offers its zone's full set |
| Flights | **7, and no two alike.** Hazards per crossing: 3.9 · 12.7 · 21.3 · 44.1 · 9.3 · 39.1 · 70.4. Flight 1 is `lethal: false` |
| Bosses | 2 — the Ranger (leg 3) and BIG DOWN (the back half of leg 7) |
| Assets | 40 textures (23 + 17 substance icons), 46 sounds (39 SFX + 7 zone ambience beds), 22 music stems — all procedurally generated |
| Autoloads | 10 (see `docs/ARCHITECTURE.md` §2 for the order and why it matters) |
| Gates | **11.** `.\verify.ps1`, about six minutes |
| Decisions | `docs/DECISIONS.md`, newest on top. Six are `Open (human)` and must not be closed by an agent: D-005, D-006, D-007, D-019, D-036, **D-068** |
| Failure log | `docs/RECENT_FAILURES.md` — **empty**, of a hard cap of 5 (F-005, F-003 and F-001 all retired 2026-09-25: by `verify.ps1`'s timeout, by `probe_common.settled()`, and by the audio exit wait plus `ScriptErrors` catching leaks — D-072). An entry leaves only by becoming a check |

### The twelve gates, and what each one is the only thing that can see

| gate | proves | count |
|---|---|---|
| `--gate` | every `.gd` compiles and every resource loads, inside the booted project | 73 scripts |
| `--selftest` | the game agrees with itself | **967 invariants** |
| `--probe --inputtest` | the bird obeys a key, **including the one that eats** — and so does the UI, **and a pad can get from leg 1 to leg 2**, and every Settings row reaches what it controls, and the dose hint appears on the grass, and restart resets a whole run, and the wheel and the click, and every menu button clicked for real, and G at the flock pen, **and both sticks and Back, and the Almanac walked, and BIG DOWN's echo** | 158 checks |
| `--probe --feeltest` | it obeys WELL | 22 metrics, 13 asserted |
| `--probe --substancetest` | all seventeen substances bite | 172 checks |
| `--probe --migtest` | the flight answers the stick, the seven differ, **and Q hands off the lead — and flying the V is scored as holding your slot** | 22 measurements |
| `--probe --rolltest` | the credit roll travels, **and H on the 18th green honks the goose, answers with the whole course, and starts the credits — and a honked slab falls over and scores nothing** |  |
| `--doctest` | **the documents still tell the truth** | 193 claims |
| `--audiotest` | **the WAVs are what their names claim, the volume sliders reach a bus, and quitting mid-sound leaks nothing** | 255 over 68 files |
| `--probe --geomtest` | **a model is the size its table says, nothing edible is buried in a solid, and the bird stands ON the ground** | 56 over 15 kinds, 74 pickups |
| `--probe --loop-test` | seven legs, seven flights and the ending | + the shelf census |
| `verify.ps1` | **every count in this table matches the gate that printed it** | |

### What is specced but not built
- **The Ranger's leg 6 exam** (`BOSS_DESIGN.md` §2.1.4). D-013 records the real
  blocker as a sound no agent can hear.
- **Multiplayer** (`MULTIPLAYER_SPEC.md`) — and it should not be next.
- **The Zamboni**, correctly deferred to a winter zone that does not exist.

---

## ⟳ 2. What changed last session

The 2026-09-25 session. Every item has a DECISIONS entry with the measurement,
the canary that proved its check can fail, and the files; this is the map.

### 1. The gates stopped sharing a save file with the player (D-054)

Three gates had been passing *because of* the save on the machine that ran them:
it said the first-run cards had been seen, and without it those cards paused the
tree in the middle of their measurements. Runs with arguments after `--`
are now hermetic (`prefs.gd::hermetic`), `verify.ps1` hashes the player's save
before and after and fails if it moved, and the first hermetic run found three
gates that needed fixing to pass honestly. **The player's save on this machine
was written by gates before this fix** (all seventeen substances unlocked, a
nine-digit best chaos, both first-run briefings marked seen); it was left
exactly as found, and resetting it is the human's call — §3 has the one line.

### 2. Controls wired to nothing — the sweep, continued

Driven the way a player drives them; bugs first, then what was merely covered.

| | found |
|---|---|
| D-055 | **a pad could play one zone and never leave it**: no pause, and flight 1's results card waited on `gg_skip`, which had no pad button |
| D-056 | Settings: **Invert Y and Show hints unreachable on a pad**, sliders 95–100 presses end to end, Art style left every cat and person unchanged, Show hints undone by closing the menu |
| D-057 | the share key has two handlers, and D-032 had fixed one — **the pen paid for a saturated flock on every press** |
| D-059 | the card that teaches the dose arc was designed, specced and built, and **nothing called it** |
| D-060 | the director's menu watch lived in a pausable `_process` and **never saw a menu open** |
| D-063 | the roster that announces a death closed on the press that skipped the flight |
| D-073 | **the flight paid the player not to fly in formation** — the slot was scored against the V at rest while the V on screen moved |
| D-075 | the flight's one card taught its one rule backwards: the draft does not burn slower, it pays |
| D-077 | **a pad could not look around** — the right stick did nothing — and no harness had ever moved a stick |
| D-079 | **honking a credit slab scored**, on the one screen specced to have no score |

And pressed for the first time, all working, recorded so nobody re-sweeps them:
restart end to end (D-061), the mouse wheel and click (D-065), every menu button
by a real click (D-066), G at the flock pen (D-071), the flight's lead handoff
in all four branches (D-073), the ending's honk and the credits it starts
(D-076), the Almanac's arrows, D-pad and rows (D-078).

### 3. The instruments

- **`verify.ps1` kills a hung gate** and prints its last lines (D-062). It used
  to wait forever on a `main.gd` that would not parse.
- **The audio leak at exit is closed, twice** (D-072, D-074): stopped streams
  need the mixer thread to retire them, and positional players live in the zone
  where no exit wait could reach. A leaked stream is now a red step, and
  `--audiotest` quits mid-sound on purpose so that stays true.
- **`migtest`'s half crossing is measured, not divided** (D-067), and
  **every harness that builds settles first** (D-070).
- **`--findtest`** counts how findable each leg's pickups are (D-068, report
  only): leg 1's double-double — half of its one named combo — is the least
  findable thing in the leg. Where it goes is the human's.
- `CLAUDE.md` went 373 → 264 lines by pointer, not deletion (D-064).
- `docs/RECENT_FAILURES.md` is **empty**: F-005, F-003 and F-001 each left by
  becoming a check.

### 4. Bread has a model (D-069)

It was the only substance with none — a glowing grey sphere — in the leg whose
lesson is *recognise it before you eat it*.

---

## ⟳ 3. What to do next

**Nothing here is waiting on you.** See `CLAUDE.md`, *"Taste is the human's.
Everything measurable is yours."*

### Yours — an agent must not decide these

`Open (human)` in `docs/DECISIONS.md`, plus the two design questions in
`docs/NEXT_SESSION.md`:

| | |
|---|---|
| **D-068** | leg 1's double-double — half of THE WOBBLER, the leg's one named combo — is its least findable pickup: farthest from the spawn, the only one on a prop, out of the opening shot. **Recommended, not taken:** move it to the lot's near side. Where things go is level design |
| **D-019** | tolerance softens penalties, against the documented economy — arguably part of why *"substances don't matter"* |
| **D-036** | eleven of fifteen props are declared the wrong size; correcting one rescales its model non-uniformly, which is a look |
| **D-006** | the glide ratio. 3:1 opens ten surfaces across seven zones |
| **D-005** | the hard-landing threshold. One surface in the game has no soft way down |
| **D-007** | the truck stop's closing beat is proportional, not absolute |
| Substances as keys | `NEXT_SESSION.md` §1 — it overrides `BOSS_DESIGN.md` §3.5 in writing |
| Cat petting | `NEXT_SESSION.md` §4 — you asked to discuss it |
| **Your save file** | gates wrote it before D-054 made them hermetic: all 17 substances unlocked, `best_chaos` 131201955, both first-run cards marked seen. Which of that you earned cannot be told apart, so it was left exactly as found. To start clean (your volume and settings go with it): `Rename-Item "$env:APPDATA\Godot\app_userdata\Geeked Geese\geeked_geese.cfg" geeked_geese.cfg.polluted` |

### Ranked, for an agent

1. **Keep sweeping, and read §2's table for the shape.** Every `_input` in
   the game has now been pressed by a harness. Still never driven as a player
   sends them: the Ranger's and BIG DOWN's reactions to the flap, the dive and
   the share, which the campaign loop reaches by calling methods; and **mouse
   look**, which no headless run can drive because `MOUSE_MODE_CAPTURED` is
   never honoured headless (`GODOT_4.7_RULES` §4.5) — find a path or record it
   as the known hole. And when something is finally driven, check what it did:
   three of this session's bugs were a control that worked, driving something
   that was wrong.
2. **`hold_actors()` freezes the actors and not the physics** (§4). D-058
   retook the one check that failed on a parked prop; nothing stops props
   accumulating on the substance pad over a run.
3. **The Ranger's leg 6 exam** — `BOSS_DESIGN.md` §2.1.4. D-013 records the
   real blocker as the propane cannon's bang, which is a human one.
4. **Cut `CLAUDE.md` toward 200.** It is at 264 against a ratchet that only goes
   down; what remains is mostly real rules.
5. **The remaining per-flight fields** (`ROUTE_DATA.md` §1.3's `sky`,
   `ground`, `put_down`). Per D-017, none until the code that reads it exists.
6. **Convert a zone to a real `.tscn`.** Accepted debt, and a candidate for
   being retired as a decision, since everything it buys needs a human in the
   editor.

### Recorded, decided without measuring, and revertible

**This session's, each a small revert:** the dose hint appears the first time
the bird stands on anything edible (D-059 — delete one call); the loss roster
ignores presses for 0.34 s, matched to the results card (D-063); bread's look
(D-069); the flight card's corrected sentence is in my words (D-075); the right
stick pitches at 1.6 rad/s and Back toggles the objectives (D-077); the drafting
slot is clamped to the corridor and still scored on X and Z only (D-073); the
two restart windows stay 1.5 s and 3.0 s, now with the reason written down (D-080).

**Carried forward:** `stamina_restore` pays out (D-018). Leg 1's shelf is four
substances (D-022, D-037). Bread's `charge_time`, sweet band and zero
`stamina_restore` are mine. The share cooldown of 1.0 s is pacing (D-032).
`sustained_campaign` lives in the cut corn (D-034). Fallen fruit lands 1.1 m
from a trunk on the side away from the water, and leg 6's thermos sits 1.60 m
along the cab's local -x (D-043) — the distances are arithmetic, the directions
are mine. The cottage grass patch moved 1.6 m west rather than onto the porch
(D-045). Both goose models are lifted onto the capsule's contact point rather
than the bird being made shorter (D-045).

---

## ⟳ 4. Known issues and honest gaps

> **READ THIS INDEX BEFORE THE BODY.** Everything below was true when it was
> written and **most of it has since been fixed** — each fixed entry is struck
> through in place with the decision that closed it, because the arithmetic in
> them is why the fix is what it is and deleting it would cost the next reader
> the reasoning. The entries that are NOT struck are live.
>
> **Still open, in rough order of cost:** `hold_actors()` freezes the actors
> and not the physics, so props can pile up on a measuring pad (D-058 retook the
> one check that failed on it); tolerance softens penalties (D-019, the human's);
> and the three BIG DOWN items, which need a render or a judgement. **Fixed on
> 2026-09-25:** `migtest`'s half crossing (D-067) and the missing per-step
> timeout (D-062), struck through below. **The placement list is empty** — all
> five are fixed and `--geomtest` has an assertion for each class.


### From an earlier audit — survived an adversarial refutation panel

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

~~**`substancetest`'s `DOSE = 0.6` is an OVERDOSE for acid and percs**~~ **FIXED, D-042** — `_dose_for()` clamps into each substance's own band and every substance is asserted not to resolve `overdosed`. Original text:

**`substancetest`'s `DOSE = 0.6` is an OVERDOSE for acid and percs**, which
contradicts the constant's own comment (*"inside the sweet band of every
substance in the shelf, so `resolve()` returns quality 1.0"*). Acid's `sweet_max`
is 0.55, percs' is lower still. So two of the sixteen have been measured on the
`overdosed` branch with `bad = 1.6` the whole time, and the printout has never
said so. `[0.45, 0.55]` is in band for all sixteen (highest `sweet_min` is
nitrous at 0.45, lowest `sweet_max` is acid at 0.55), or dose each substance at
`clampf(0.6, sweet_min, sweet_max)`.

~~**`gg_share` pays 75 chaos and a combo link on every key press**~~ **FIXED, D-032** — a 1.0 s cooldown, and it only pays when the dose moved a bird. Original text:, with no
cooldown and no cost once the flock is saturated. The honk has a 0.22 s cooldown
for exactly this reason; the share has none, and does not check whether it moved
anything.

~~**Six authored objectives are gated behind `from_leg` values their zone never~~ **FIXED, D-034** — three were redundant copies and were deleted, one re-gated, two moved; `selftest` now fails on any objective gated outside its zone's legs. Original text:

**Six authored objectives are gated behind `from_leg` values their zone never
reaches**, including the game's only chain-length primary (`sustained_campaign`).
`no_brakes` and both `variety_pack` rows are the cheap ones — lower `from_leg` to
the zone's real leg. `sustained_campaign` needs a home in a zone that runs at
leg 5+.

~~**The results card's short-landing clock is derived from the NEXT leg's base**~~ **FIXED, D-040** — wrong on four of seven legs; leg 1 by a full minute. Original text:,
but landing short replays the CURRENT leg. Add a `short_zone_base` beside
`next_zone_base` in `evaluate_leg()`'s result.

~~**The results card's CHAOS note quotes un-multiplied objective rewards**~~
**FIXED, D-048** — `_complete()` records what `Game.score()` actually paid and
`evaluate_leg()` sums that. Original text:

**The results card's CHAOS note quotes un-multiplied objective rewards** while
claiming they are the amounts inside the multiplied chaos figure.

~~**`juice.gd`'s rule "HITSTOP HAS EXACTLY FIVE CALL SITES"**~~ **FIXED, D-038** — it is a table now, checked symmetrically, exactly as this entry proposed. Original text:

**`juice.gd`'s non-negotiable rule "HITSTOP HAS EXACTLY FIVE CALL SITES" is
false — there are eight.** The honest fix here is not a corrected comment but the
project's own idiom: an invariant that greps `scripts/` for `Juice.hitstop(` and
asserts both the count and each site's `(seconds, strength)` against a table
declared in `juice.gd`. A rule in prose is the failure mode `CLAUDE.md`'s banner
is about.

~~**`no_early_exit` travels the whole pipeline**~~ **FIXED, D-029** — deleted, and `CONTROL_KEYS` is now checked for exactly this hole. Original text:

**`no_early_exit` travels the whole pipeline and is read by one thing:
`almanac.gd`, which prints a line about it.** There is no early-exit verb in the
game, so the Almanac states a rule about the player's options that is not true.
It is also in `selftest`'s `CONTROL_KEYS`, which means a substance could satisfy
the design rule with a field that mutates nothing.

**Placement arithmetic, each with both numbers.** **ALL FIVE ARE FIXED**: lawn signs D-033, `wedge()` D-039, leg 6's cab D-043 (along with five more buried pickups nothing in this list had ever noticed), suburbia's lamp and the recycling chevron D-045. Original text:

**Placement arithmetic, each with both numbers:** leg 6's double-double pickup
sits **inside the grain truck's cab** because the placement ignores the truck's
0.14 rad yaw; Suburbia's island lamp collider is centred **0.6 m too high**, so
it floats and overhangs its own luminaire; about **a quarter of leg 1's lawn
signs spawn in the retention pond**; the recycling bin's chevron badge floats
**8.6 cm** in front of the tub; and `LowPolyBuilder.wedge()` closes **only one of
its two ridge ends**, leaving a hole in every model that uses it.

**Cosmetic but real. ALL FOUR ARE FIXED**: `_flap_anim`, `Prefs` and `almanac.layer` (the last as D-030), and the feet as D-045 — where the recorded "5–10 cm" turned out to be **101 mm on the lowpoly bird and 180 mm on the classic one**, which this entry never mentioned. Original text:

**Cosmetic but real:** `_flap_anim` is decayed only inside `_tick_fly`, so one
standing hop leaves the wings flapping at full rate for the rest of the leg; the
lowpoly goose's webbed feet sit 5–10 cm **below** the collider and are underground
whenever the bird stands; `Prefs` never flushes on quit, so a settings change made
inside the 0.4 s debounce is lost; and `almanac.layer = 20` in `_build_overlays()`
is overwritten by the Almanac's own `_ready()`.

**Gaps in the gates themselves, named honestly:**

- ~~**`input_lag` has no behavioural coverage in any of the eleven gates.**~~
  **FIXED, D-046** — `substancetest` measures the delay from key to movement and
  asserts it, and `_the_grid()` holds a diagonal to catch `grid_snap` (0.785 rad
  dosed against 0.000 sober, which is PI/4 exactly). **But only 2 of the 11
  laggards are asserted**, and the reason is in the code rather than the harness:
  drift is added to the stick AFTER the lag buffer, so under a drifting substance
  the bird moves on frame 1 however stale the stick is. The nine are printed as
  not asserted with that reason. Two is enough to hold the MECHANISM — one buffer
  serves all eleven — but a wrong number in one `.tres` is still only covered
  statically. Original text:

- **`input_lag` has no behavioural coverage in any of the eleven gates.** It is
  the field that caused this project's most expensive bug — eleven of sixteen
  substances unplayable — and `substancetest` counts it as satisfying the design
  rule while asserting nothing about it. Same for `grid_snap`.
- ~~**Nothing exercises the eating verb through the path the player uses.**~~
  **FIXED, D-047** — `inputtest::_eat_test()` walks onto leg 1's grass, holds
  `gg_eat` to three charges and releases, asserting the arc is a clock, that each
  dose scores the label its band deserves, that the substance goes active, that
  `stamina_restore` lands (**+0.260 measured against a declared 0.25**, across the
  release frame so `regen_ground` cannot pay for it), and that an abort drops the
  charge. 8 checks → 30. Original text:

- **Nothing exercises the eating verb through the path the player uses.** Every
  harness reaches into `Subs.take()` directly, so `_tick_eat`'s charge arc, the
  sweet-spot band, the abort, the pickup's `consumed()` and the SWEET SPOT /
  OVERDOSE / BARELY ANYTHING scoring have never been driven by a key. That is
  why `stamina_restore` could be dead with every gate green, and it is why its
  wiring is asserted **statically** rather than behaviourally.
- **NEW: `hold_actors()` freezes the ACTORS and not the PHYSICS.** Cats and
  humans stop; `chaos_prop` rigid bodies keep rolling, and leg 1 is full of
  loose shopping carts. On 2026-09-10 this failed a full verify at 1.130 rad on
  a correct controller, and on the very next verify it disturbed **two of three**
  attempts — so it is frequent, not rare, and the clean runs the day before were
  luck. Every measurement in `substancetest.gd` retakes for this reason; the new
  grid check was the only one that did not, and now does. **The general problem
  is unfixed**: nothing can freeze a rigid body mid-measurement, and
  `find_dry_ground()` cannot reject a pad with a cart rolling toward it. This is
  the RUNTIME half of what F-002 was about — D-041 retired the build-order half
  (seeded streams), not this one.

- ~~**`migtest`'s `lateral.half_cross` cannot fail unless `full_cross` fails too**~~
  **FIXED, D-067** — timed from the corridor's centre on its own run; canaried
  with a slow right half, which the old derivation passed. Original text: it is
  derived from the same drive rather than measured independently.
- ~~**`verify.ps1` checks for `SCRIPT ERROR` on one of its eight steps.**~~
  **Fixed 2026-08-18.** All nine steps do, through one shared `ScriptErrors`
  helper. It is `SCRIPT ERROR` and not a blanket `ERROR:` on purpose, and the
  helper says why: the compile gate legitimately prints 26 attributed lines, and
  two probes exit with `ERROR: N resources still in use` from a teardown
  ordering issue that is diagnosed and open. See `docs/RECENT_FAILURES.md`
  F-001, which this half retired. **The other half closed 2026-09-25 (D-072):**
  the leak was playbacks the mixer thread had not yet retired, both audio
  autoloads now stop and wait for it at exit, and `ScriptErrors` matches
  `resources still in use at exit` as well — so a leak is now a red step.
- ~~**The failsafe is armed after the first zone has already been built.**~~
  **FIXED, D-049** — `_arm_headless_deadline()` is now the first statement of
  `_ready()`, and `selftest::_the_failsafe_is_first()` asserts the ordering.
  Original text:

- **The failsafe is armed after the first zone has already been built.**
  `_arm_failsafe()` runs partway through `_ready()`, so a crash or stall before
  that point is still an invisible process.

- ~~**`verify.ps1` has no per-step wall-clock timeout, and the in-engine
  failsafe cannot substitute for one.**~~ **FIXED, D-062** — one `Godot()`
  helper kills a hung gate with `taskkill /T`, prints its last lines and stops
  the run; canaried with this exact fault. Original text: found the hard way on 2026-08-19: a
  swallowed newline in `main.gd` made the main scene fail to parse, so
  `_probe_if_headless()` never ran, `tree.quit()` was never called, and the
  process sat alive forever printing nothing past the `^[gate]` filter. **The
  failsafe cannot help because it lives in `main.gd` too** — a file that will
  not parse takes its own deadline down with it. The shell that started the
  process is the only thing that can always kill it. The fix is one helper in
  `verify.ps1` — `Start-Process -PassThru -RedirectStandardOutput` plus
  `WaitForExit(ms)` and `Kill()` — applied to all twelve invocations; it was
  not done in the same session as the bug that revealed it because it is a
  refactor of the file that runs everything.

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

~~**`FOOTPRINTS` is never checked against the meshes it describes.**~~ **FIXED,
D-028 — and it found eleven of fifteen wrong, which is now D-036, `Open
(human)`.** The abandoned-attempt note below is why the new one measures BUILT
ZONES instead of constructing kinds. Original text:

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
them — and that is still true.** What changed is that `--audiotest` (D-035) now
asserts what they ARE: that every bed loops, is long enough to be a bed, is not
silent and does not clip. It still cannot tell you anything sounds good.
Original text:

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

**And three that are not read so much as RUN.** Each is checked by a gate, so
it cannot quietly stop being true:

| File | What it is | What checks it |
|---|---|---|
| `docs/DECISIONS.md` | Decision STATUS. What is settled, what is open, what is the human's. Append-only; a reversal is a new entry. | discipline |
| `docs/CLAIMS.md` | **Every number this repo writes into a document**, and where. Nothing in it stores an expected value — `doctest.gd` recomputes each from the booted project. | `--doctest` |
| `docs/RECENT_FAILURES.md` | The last five things that went wrong, with a diagnosis and a named check that would retire each. **Capped at five**, and an entry leaves only by becoming that check. | `--doctest` |

---

## 6. Verifying

**On Windows, all eleven gates in one command:**
```
.\verify.ps1            # compile, invariants, controller, feel, substances,
                        #   flight, credit roll, claims, audio, footprints,
                        #   campaign
.\verify.ps1 -Quick     # skips the slow ones
.\verify.ps1 -Shots     # also renders every zone into .\shots\
```
**Every step now fails on `SCRIPT ERROR`.** Until 2026-08-18 only the campaign
step looked, so a harness could raise inside a branch its pass line did not
depend on, print PASS, exit 0, and be reported green — the same class as a gate
that cannot fail. One shared `ScriptErrors` helper, and the reason it matches
`SCRIPT ERROR` rather than a blanket `ERROR:` is written at that helper: the
compile gate's attributed `briefing.gd` lines are benign and would make the
build permanently red. Since 2026-09-25 it also matches `resources still in use at
exit` — the audio leak that used to be excused there is fixed (D-072), so
it is now a failure like any other.

**9. The claims gate** — the only one pointed at this repo's own prose:
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

**10. The audio gate** — the only one that opens the WAVs:
```
godot --headless --path . -- --audiotest 2>&1 | grep '^\[audio\]'
```
A bed loops and is long enough to be a bed; a one-shot is short enough to be a
one-shot; nothing is silent or clipping; the sixteen layered stems share a
length. **It cannot tell you anything sounds good and says so on every run**,
along with how many files it skipped for being QOA-compressed. The bug it
exists for: the truck stop's "rain" was a 0.700 s goose hiss that never looped.

**11. The footprint gate** — the only thing that has ever compared
`FOOTPRINTS` to a mesh:
```
godot --headless --path . -- --probe --geomtest 2>&1 | grep '^\[geom\]'
```
`build()` sizes with `want / footprint(kind)`, so a declaration that disagrees
with the mesh makes every `size:` placement of that kind wrong by that ratio.
It **asserts** the meshes do not drift and **reports** that eleven of fifteen
declarations disagree — correcting one rescales a model non-uniformly, which is
a look, which is D-036 and the human's.

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
