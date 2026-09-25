# HANDOFF — current state

> # ▶ READ `docs/NEXT_SESSION.md` FIRST — IT CARRIES THE QUEUE.
>
> **The human set the next session's format on 2026-09-20: autonomous.** That
> file used to say the opposite; it has been re-pointed. Work its ranked queue,
> starting with the control-that-does-nothing sweep, which has produced four real
> bugs in four attempts and is not exhausted.
>
> **Two things there are still the human's and an agent must not decide them:**
> making substances required (it overrides `BOSS_DESIGN.md` §3.5 in writing), and
> cat petting (they asked to discuss it). §3 below is about INSTRUMENTS and is
> the second queue, not the first.

**Updated:** 2026-09-20, after a short session that started from one sentence
of real play — *"there is still no pause menu"* — and found **four bugs that
were all the same bug**: an advertised control wired to nothing, passing twelve
green gates because no gate asked whether the far end was attached.

The pause menu could close itself and never open itself. No harness in this
project had **ever** sent an input event through the viewport. The menu's seven
buttons had never been clicked by anyone. And the SFX volume slider had no bus
to write to, with all seventeen sound players routed past it to Master.

> **How this file works.** `CLAUDE.md` holds the *rules* — they rarely change.
> This file holds the *state* — it changes every session. Read this first, then
> `docs/DECISIONS.md`, then CLAUDE.md. **Update the four ⟳ sections at the end of
> every session.**
>
> **Numbers in this file are checked.** `tools/doctest.gd` recomputes them from
> the booted project on every `verify.ps1` run — see `docs/CLAIMS.md`. If you
> write a new number in here, give it a claim row or take it out.

---

## ⟳ 1. Where the project is right now

**The campaign is built and it is no longer the same game twice.** Three things
the design documents specified and the code had never implemented are now
implemented, and all three had the same shape: **a spec written in the language
of the code, sitting in a markdown file, that nothing loaded.**

- Legs 1 and 2 were 420 seconds of the same place with the same sixteen
  substances. **Leg 1 now offers four**, and one of them is bread.
- All seven interstitial flights were the same 85-second crossing. **Each now
  has its own shape**, and flight 1 cannot take a bird.
- Bread — `CAMPAIGN_SPEC.md` §2.1's "the obvious food is the trap", specced since
  the campaign was — **is built**, and it removes the game's main verb for
  twenty seconds.

**And the instruments grew faster than the game did, on purpose.** Eight gates
became twelve and the invariant count went 619 → 953. The new ones each close a
category nothing could see before: the DOCS (`--doctest`), the AUDIO
(`--audiotest`), the GEOMETRY (`--geomtest`) and the gate table itself
(`verify.ps1` step 12). Between them they found seven stale facts, a bed that
only loops because of a runtime patch, eleven props declared the wrong size, and
two gate counts this repo had been quoting wrong for a session.

**The second half of the session is a list of things that were WRONG, not of
things that were missing.** Nine of them, each found by an instrument built to
look for it and each now carrying the assertion that would have caught it:

- **Six substance pickups had their model inside a solid** — two berry sources at
  the centreline of a tree trunk, grass 0.5 m inside the cottage's west wall, a
  thermos in a truck cab, a coffee cup in a fuel dispenser. Five are one bug: a
  pickup written at a prop's ANCHOR as though the anchor were its SURFACE.
- **Both goose models stood underground** — 101 mm on the lowpoly bird and 180 mm
  on the classic one, on every frame the bird was still. The recorded estimate
  was "5–10 cm" and named only one of the two.
- **The substance gate had been measuring acid and percs at 1.6× their declared
  badness** for its whole life, on `resolve()`'s overdose branch.
- **`input_lag` — the field whose four-second ramp made eleven substances
  unplayable — had no behavioural coverage in any gate.** Now measured, and the
  nine that cannot be measured this way say so and say why.
- **The eating verb had never been driven by a key**, which is why
  `stamina_restore` could be dead in six `.tres` files with every gate green.
- **The results card itemised a combo-multiplied CHAOS figure with raw rewards**,
  so the itemisation drifted further out the better the player chained.
- **The headless deadline was armed after the first zone was built**, which is
  the largest body of code in the project and the likeliest thing to hang.
- **The table that lists the gates was checked by none of them**, and two of its
  counts were stale. It is now checked by the script that runs them.
- **`grid_snap` was invisible to all 22 substance channels** because every one of
  them holds forward, and a forward stick is already on an axis.

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
| Decisions | `docs/DECISIONS.md` — **40 entries.** Five are `Open (human)` and must not be closed by an agent: D-005, D-006, D-007, D-019, **D-036** |
| Failure log | `docs/RECENT_FAILURES.md` — 2 of a hard cap of 5 (F-005 retired 2026-09-25 by `verify.ps1`'s timeout). An entry leaves only by becoming a check |

### The twelve gates, and what each one is the only thing that can see

| gate | proves | count |
|---|---|---|
| `--gate` | every `.gd` compiles and every resource loads, inside the booted project | 73 scripts |
| `--selftest` | the game agrees with itself | **954 invariants** |
| `--probe --inputtest` | the bird obeys a key, **including the one that eats** — and so does the UI, **and a pad can get from leg 1 to leg 2**, and every Settings row reaches what it controls, and the dose hint appears on the grass, and restart resets a whole run, and the wheel and the click, and every menu button clicked for real | 143 checks |
| `--probe --feeltest` | it obeys WELL | 22 metrics, 13 asserted |
| `--probe --substancetest` | all seventeen substances bite | 172 checks |
| `--probe --migtest` | the flight answers the stick, and the seven differ | 14 measurements |
| `--probe --rolltest` | the credit roll travels |  |
| `--doctest` | **the documents still tell the truth** | 195 claims |
| `--audiotest` | **the WAVs are what their names claim, and the volume sliders reach a bus** | 254 over 68 files |
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

### 1. Leg 1 is a different game from leg 2, and bread is the lesson

`zone_strip_mall.gd::_sources()` built all sixteen substances unconditionally
with **no leg branch anywhere**, against `CAMPAIGN_SPEC.md` §2.1's three and
§2.2's *"all sixteen — this is where the lid comes off"*. `TUTORIAL_SHELF` is
now `berries, double_double, grass, bread`, and the set is closed under the
game's own mixing rule: `MAX_STACK` is 2, leg 1's `double_parked` primary needs
two at once, and `berries|double_double` is THE WOBBLER — exactly one
discoverable named combo, and it is the flagship.

**Bread is a substance, not a special case, and that is why it was cheap.**
"For twenty seconds you cannot dose, and your chaos is halved" is *exactly* what
a `Substance` already is, so it cost one export (`blocks_dosing`), one line in
`resolve()`, one in `_empty_mods()`, one in `_aggregate()` and one refusal in
`take()`. The HUD strip, the timer, the tolerance, the Almanac entry and the
unlock it inherits. D-037.

The check is in two places and both are needed: `selftest` reads the
declaration, and **`--loop-test` counts the pickups the DIRECTOR built** on every
leg.

```
[loop] shelf census: leg1=4 leg2=17 leg3=10 leg4=16 leg5=16 leg6=6 leg7=4
```

### 2. Seven flights, seven shapes

`migration.gd` had one `TARGET_DISTANCE := 2000.0` and never read the leg, so
every crossing ran 85.3 s and rolled hazards from a flat `randi() % 3`. Half the
game was one flight served seven times, and `ROUTE_DATA.md` §1.3 had shipped the
table the whole time. The shape is deliberately not a ramp — flight 5 drops to
9.3 hazards because the Stopover is the run's one recovery beat. D-023.

### 3. Three new gates, and each found something on its first run

- **`--doctest`** (D-024) recomputes every number the docs state. **Seven stale
  facts** across four root documents on day one — including `CLAUDE.md`'s own
  line budget, exceeded by 90%. It later caught five more the moment bread added
  one icon, which is the gate paying for itself.
- **`--audiotest`** (D-035) opens the WAVs. Its canary showed **exactly four
  files** depend on `sfx.gd`'s runtime loop patch and would otherwise play once
  and stop.
- **`--geomtest`** (D-028, D-036) compares every prop against the footprint its
  builder declares. **Eleven of fifteen are out by more than 6%**, `hydrant` by
  −28.5% and `stop_sign`'s depth by **+75%**.

### 4. THE GLIDE NUMBER PUBLISHED TWO SESSIONS AGO WAS WRONG, AND IT WAS MINE

`glidetest` first reported that widening the glide to 3:1 would take reachable
surfaces from 42 of 113 to 86, and that "suburbia is the whole decision". Those
went into `FEEL_TARGETS.md` §5.1 and were committed. **The true figures are 21 of
84 rising to 31**, and suburbia goes 0 → 1 — close to the opposite conclusion.

It was counting the four invisible boundary walls every zone rings itself with.
**The tell was in the output and I did not read it:** every zone reported
*exactly* four hazardous surfaces and two of them named the same position. Three
filters were tried; the third (visibility) was the dangerous one, because
`_hide_meshes()` hides the graybox of **the roof plateau**, so it threw away 73
of 158 surfaces including every landable roof.

The gate now prints what every walk discarded, asserts its own filter is stable,
and fails if `FEEL_TARGETS.md` stops publishing the totals it measures. D-028.

### 5. The harnesses stopped being shoved by cats

Four consecutive sober fingerprints disagreed on bearing (0.775, 0.138, 0.462,
1.211 rad) while `turnrate` and `climb` were bit-identical in all four — a cat
camped on the pad, so retaking could not find a quiet window. It started because
editing the LAWN SIGNS moved the cats: `randomize()` plus one shared draw
sequence means **any zone-builder edit re-rolls every actor downstream of it.**
`probe_common.hold_actors()` freezes cats and NPCs for controller measurements
only — catnip still measures 7 of 7 in frenzy, which is the proof the scoping is
right. Sober noise went to 0.000 with zero retakes. D-027.

### 6. Nine smaller things, each with its arithmetic

| | |
|---|---|
| 27.1% of the lawn-sign sampling rectangle was inside the pond | 2.4 signs in the water per run, in the first zone the player sees. D-033 |
| `gg_share` paid 75 × combo on **every** press | no cooldown, and no check the dose landed. D-032 |
| `no_early_exit` was read by one thing: a label in the Almanac | for a verb single-player does not have, **and it was in `CONTROL_KEYS`**. D-029 |
| `main.gd` set `almanac.layer = 20`; `almanac.gd` sets 40 | 40 winning is the only reason the Almanac is visible. D-030 |
| one standing hop left the wings beating at full rate for the rest of the leg | `_flap_anim` decayed only inside `_tick_fly` |
| `Prefs` never flushed on quit | any setting changed in the last `SAVE_DEBOUNCE` seconds was lost |
| six authored objectives could never appear | three redundant, one re-gated, two moved. D-034 |
| the hitstop rule said "EXACTLY FIVE CALL SITES" | there were eight. D-038 |
| `wedge()` closed one of its ridge's two ends | a hole in both cat ears, both dog ears and the human's nose. D-039 |
| the results card quoted the NEXT leg's clock for a landing that replays THIS one | wrong on four of seven legs; leg 1 by a full minute. D-040 |

And an undefined escape sequence (`\*` in a RegEx) **stalls the GDScript parser
with no output at all** — the same symptom `CLAUDE.md` attributed only to a
reused local name. That is now 72 invariants, one per script. D-031.

---

### 7. THE HUMAN PRESSED ESCAPE, AND FOUR THINGS FELL OUT

One sentence of real play beat twelve gates. **`pause_menu.gd` set
`process_mode = PROCESS_MODE_WHEN_PAUSED`, and that gates `_input()` as well as
`_process()`** — so the node was inert whenever the tree was RUNNING, and the
only thing that pauses the tree is the menu's own `_open_menu()`. It could close
itself and could never open itself. Settings, the Almanac, the control card, the
flock roster and restart went with it; the README advertises all of them.

**Why twelve gates missed it, and this is the part that generalises:** *nothing
in this project had ever sent an input event through the viewport.* Every
harness either calls `Input.action_press()` — which sets action STATE and never
produces an `InputEvent`, so no `_input()` anywhere fires — or calls a handler
directly. `main.gd`'s own restart probe does the latter, `_unhandled_input(rev)`
invoked on main, which proves the handler works and proves nothing about whether
the event reaches it. Same shape as D-047's eating verb: **the method was
tested, the path was not.**

`Input.parse_input_event()` is the difference, and the four fixes all come from
pointing it at things nobody had driven:

| | |
|---|---|
| D-050 | the pause menu. Its own gate was written first and failed on the unfixed code — the bug was its own canary |
| D-051 | TAB, R and J swept the same way. **All three were fine**, and are now locked in |
| D-052 | the menu's buttons, pressed through `Button.pressed`. ALMANAC / CONTROLS / FLOCK all worked; they were simply unreachable |
| D-053 | **the SFX volume slider was connected to nothing** — `bus SFX index=-1`, `0 of 17` players on it |

D-053 came with a second bug in the same breath: `Prefs` is autoload #1 and
applies volumes before `Music` (#10) creates its bus, so **a saved music volume
was written to a bus that did not exist** and the game came back at full music
until the player touched the slider again. Both `Sfx` and `Music` now re-apply
through a new public `Prefs.apply_audio()`.

Checked and found INNOCENT, rather than assumed: `screen_shake`, `fx_intensity`
and `show_hints` all connect to `pref_changed` and re-read live. `almanac.gd` is
also `PROCESS_MODE_WHEN_PAUSED` and that one is **correct** — it is only ever
opened from the pause menu, while the tree is already paused.

Counts: `inputtest` 30 → 56, `audiotest` 246 → 254.

---

## ⟳ 3. What to do next

**Nothing here is waiting on you.** See `CLAUDE.md`, *"Taste is the human's.
Everything measurable is yours."*

### The five that are genuinely yours
`Open (human)` in `docs/DECISIONS.md`, and **an agent must not close them**:

| | |
|---|---|
| **D-036** | eleven of fifteen props are declared the wrong size. Correcting one rescales the model *non-uniformly* — `stop_sign` would go to (1.07, 1.01, **0.57**) — so it is a look. `geomtest` prints a copy-paste baseline block for exactly this |
| **D-006** | the glide ratio. Now costed: 3:1 opens **ten** surfaces across seven zones, not the 44 the first (wrong) measurement claimed |
| **D-005** | the hard-landing threshold. Now costed: **one** surface in the whole game has no soft way down. A curiosity, not a design problem |
| **D-019** | tolerance softens penalties, against the documented economy |
| **D-007** | the truck stop's closing beat is proportional, not absolute |

### Ranked, for an agent

> **This is the SECOND queue.** `docs/NEXT_SESSION.md` carries the first one,
> and its item 1 — keep sweeping for controls that do nothing — outranks
> everything here: it has produced four real bugs in four attempts and the
> remaining surfaces (results screen, briefing card, the settings widgets
> themselves, the restart confirm, the roster) have still never been driven.
> The list below is about INSTRUMENTS, and items 1 and 3 of it are duplicated
> there in priority order.

1. **Give `verify.ps1` a per-step wall-clock timeout.** Found the hard way this
   session and written up in §4: a `main.gd` that will not parse hangs the
   whole script forever, and **the in-engine failsafe cannot help because it
   lives in `main.gd` too**. One helper — `Start-Process -PassThru
   -RedirectStandardOutput`, `WaitForExit(ms)`, `Kill()` — applied to twelve
   invocations. It is a refactor of the file that runs everything, which is why
   it was not done in the same commit as the bug that revealed it.

2. **Retire F-001 properly.** Every step of `verify.ps1` fails on
   `SCRIPT ERROR`; the remaining half is the leak itself. Two things were tried
   and measured — `Music._exit_tree()` **does** run, and an equivalent in
   `sfx.gd` left the count at exactly 17 — so the holder is not the autoload
   caches. The remaining candidate is the AudioServer's playbacks.

3. **`migtest`'s `lateral.half_cross` cannot fail independently** of
   `full_cross`; it is derived from the same drive rather than measured. The
   last un-addressed gate gap in §4.

4. **The Ranger's leg 6 exam** — `BOSS_DESIGN.md` §2.1.4. D-013 records the real
   blocker as the propane cannon's bang, which is a human one.

5. **Cut `CLAUDE.md` toward 200.** It is at 373 against a ratchet that only goes
   down — which bit this session: a needed addition was refused at 376 and had
   to be paid for by tightening two existing paragraphs. The biggest remaining
   block is the architecture description, which is derivable from
   `docs/ARCHITECTURE.md`, a file that exists.

6. **The remaining per-flight fields.** `ROUTE_DATA.md` §1.3 also gives each
   flight a `sky`, a `ground` and a `put_down` flag, and §5 a
   max-birds-lost-per-flight of 2. Per D-017 none should be copied into
   `FLIGHTS` until the code that reads it exists.

7. **Convert a zone to a real `.tscn`.** Still accepted debt, and still a
   candidate for being retired as a decision rather than carried as a task,
   since everything it buys needs a human in the editor.

**Retired since the last handoff:** F-002 (D-041, per-group seeded streams), the
whole placement-arithmetic list (D-043, D-045), the `input_lag`/`grid_snap`
coverage gap (D-046), the eating-verb gap (D-047), the results card (D-048) and
the failsafe ordering (D-049).
### Recorded, decided without measuring, and revertible
`stamina_restore` pays out (D-018). Leg 1's shelf is four substances (D-022,
D-037). Bread's `charge_time`, sweet band and zero `stamina_restore` are mine
and each is a one-line revert. The share cooldown of 1.0 s is pacing (D-032).
`sustained_campaign` lives in the cut corn now, which is a design call (D-034).
Fallen fruit lands 1.1 m from a trunk on the side away from the water, and leg
6's thermos sits 1.60 m along the cab's local -x (D-043) — the distances are
arithmetic, the directions are mine. The cottage grass patch moved 1.6 m west
rather than onto the porch (D-045). Both goose models are lifted onto the
capsule's contact point rather than the bird being made shorter (D-045).

---

## ⟳ 4. Known issues and honest gaps

> **READ THIS INDEX BEFORE THE BODY.** Everything below was true when it was
> written and **twelve of the entries have since been fixed** — each is struck
> through in place with the decision that closed it, because the arithmetic in
> them is why the fix is what it is and deleting it would cost the next reader
> the reasoning. The entries that are NOT struck are live.
>
> **Still open, in rough order of cost:** `migtest`'s `lateral.half_cross`
> cannot fail independently; **verify.ps1 has no per-step wall-clock timeout**,
> so a main.gd that will not parse hangs it forever; and the three BIG DOWN
> items, which need a render
> or a judgement. **The placement list is empty** — all five are fixed and
> `--geomtest` now has an assertion for each class.


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

- **`migtest`'s `lateral.half_cross` cannot fail unless `full_cross` fails too** —
  it is derived from the same drive rather than measured independently.
- ~~**`verify.ps1` checks for `SCRIPT ERROR` on one of its eight steps.**~~
  **Fixed 2026-08-18.** All nine steps do, through one shared `ScriptErrors`
  helper. It is `SCRIPT ERROR` and not a blanket `ERROR:` on purpose, and the
  helper says why: the compile gate legitimately prints 26 attributed lines, and
  two probes exit with `ERROR: N resources still in use` from a teardown
  ordering issue that is diagnosed and open. See `docs/RECENT_FAILURES.md`
  F-001, which this half retired.
- ~~**The failsafe is armed after the first zone has already been built.**~~
  **FIXED, D-049** — `_arm_headless_deadline()` is now the first statement of
  `_ready()`, and `selftest::_the_failsafe_is_first()` asserts the ordering.
  Original text:

- **The failsafe is armed after the first zone has already been built.**
  `_arm_failsafe()` runs partway through `_ready()`, so a crash or stall before
  that point is still an invisible process.

- **NEW: `verify.ps1` has no per-step wall-clock timeout, and the in-engine
  failsafe cannot substitute for one.** Found the hard way on 2026-08-19: a
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
`SCRIPT ERROR` rather than a blanket `ERROR:` is written at that helper: two
known-benign and one known-open stderr condition would otherwise make the build
permanently red. See `docs/RECENT_FAILURES.md` F-001.

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
