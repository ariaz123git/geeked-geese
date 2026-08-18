# HANDOFF — current state

**Updated:** end of the session that built the Stopover and BIG DOWN, gave every
zone its own air — and discovered that the goose had been obeying four-second-old
input on eleven of the sixteen substances, past every check this project had.

> **How this file works.** `CLAUDE.md` holds the *rules* — they rarely change.
> This file holds the *state* — it changes every session. Read this first, then
> CLAUDE.md, then `docs/ARCHITECTURE.md` if you are about to change how
> something is wired. **Update the four ⟳ sections at the end of every session.**
> If it goes stale it is worse than useless, because the next session will
> trust it.

---

## ⟳ 1. Where the project is right now

**The route has no placeholders left, both bosses are built, and for the first
time the project can prove not just that the goose responds to the controls but
that it responds WELL — and that all sixteen substances actually change how it
handles.**

| | |
|---|---|
| Engine | Godot 4.7.1, GL Compatibility renderer |
| Code | 67 GDScript files (read the live count off `[gate] PASS — N scripts`) |
| Zones built | 8 — retention pond / strip mall lot (one zone, two legs), suburbia, cottage country, **the stopover**, cut corn, truck stop, the 18th green |
| Route legs | 7 flown + the arrival. **No leg reuses another leg's zone any more.** Leg 7 is now the 230 s `BOSS_DESIGN.md` §2.2.2 asks for. |
| Substances | 16, all with models, control mutations, true codex facts and — as of this session — a HUD icon |
| Bosses | **2 built.** The Ranger (leg 3) and **BIG DOWN** (the back half of leg 7) |
| Assets | 39 textures (23 + 16 substance icons), 46 sounds (39 SFX + 7 zone ambience beds), 22 music stems — **all procedurally generated** |
| Autoloads | 10 (see `docs/ARCHITECTURE.md` §2 for the order and why it matters) |
| Gates | **7**: compile, invariants (432), controller, **feel (22 metrics, 13 asserted)**, **substances (102 checks over 16)**, credit roll, full campaign. `.\verify.ps1`, about 4 minutes |
| Version control | **A git repo, as of this session.** There was none before, despite `VIBECODING_BRIEFING.md` making "commit before every task" one of its six headline rules. |

### What works
Everything in the previous handoff, plus: leg 5 is a dawn marsh instead of a
second helping of cottage country; leg 7 has a distribution centre across the
interstate with a warehouse of down bales, a four-storey glass atrium and a man
in a suit who only closes things; every zone has its own ambience; the ending's
credit roll now actually moves and ends with a glossary of everything the player
discovered; and the flight is flown by geese that flap.

### What is specced but not built
- **Multiplayer** (`docs/MULTIPLAYER_SPEC.md`) — local split-screen only; online
  is argued against on technical grounds. **It should not be next.**
- **The Ranger's leg 6 exam** (`docs/BOSS_DESIGN.md` §2.1.4). Leg 6 now exists as
  the corn field it was written for, so this is the cheapest content left.
- **The Zamboni**, correctly deferred to a winter zone that does not exist.

---

## ⟳ 2. What changed last session

**0. THE PROJECT IS UNDER GIT NOW.** There was no `.git` at all. Every session
so far has worked without the undo that `VIBECODING_BRIEFING.md` calls one of
its six headline rules. `main` holds the untouched baseline; the session's work
is on `session2-feel`, one commit per idea, so any of it can be read or reverted
on its own. `_to_delete/` (90 MB of superseded zips and stale `.godot` caches) is
gitignored rather than deleted — that is the human's call.

**1. "PLAY IT" IS NO LONGER THE TOP OF THIS LIST, AND THAT WAS A PROCESS BUG.**
It sat at #1 for two sessions running, everything behind it was blocked on one
person having a free evening, and so nothing behind it moved. The fix is not to
delete the line; it is that feel is two things wearing one word. **Taste** — is a
waddling goose funny — stays the human's, permanently. **Response** — time to top
speed, stop distance, whether a held flap converges on a climb rate — is
arithmetic, and nothing in this project was measuring it. See `CLAUDE.md`,
*"Taste is the human's. Everything measurable is yours."*

**2. THE FLAP COMPOUNDED, AND EVERY EXISTING GATE PASSED ON IT.** `_flap()` read
`velocity.y = maxf(velocity.y, 0.0) + power`, which ADDS the impulse to an
already-positive climb. The cooldown only lets gravity take 3.3 m/s back against
a power of 6.08, so a held flap netted **+2.78 m/s on the last one, compounding,
with no ceiling** — there is a `max_fall` in the controller and there has never
been a `max_rise`.

| | before | after |
|---|---|---|
| climb in the 1st second of held flap | 7.36 m | **4.50 m** |
| climb in the 3rd second | 23.66 m | **4.45 m** |
| peak climb rate | 29.5 m/s | **6.08 m/s** |
| **one flap, from level** | **1.73 m** | **1.73 m** |

`maxf(velocity.y, power)` SETS the climb instead of adding to it, so the single
flap is bit-for-bit unchanged and the 1.70 m racking promise in §4 survives
untouched. The independent `inputtest` gate corroborates: its takeoff fell from
**+34.98 m to +11.30 m**.

**3. TWO NEW GATES.**
- `tools/feeltest.gd` (`--probe --feeltest`) — 22 controller metrics, 13
  asserted against windows argued out in `docs/FEEL_TARGETS.md`. Every window
  cites something this repo already wrote down. Eleven of the twelve are
  bit-stable across consecutive runs.
- `tools/substancetest.gd` (`--probe --substancetest`) — doses all sixteen
  substances and measures the bird. `selftest.gd` enforced the "never only a
  number that goes up" rule **by reading the `.tres`**, which cannot tell you
  the mutation reaches the goose; the input-lag bug is the precedent, with
  eleven of sixteen unplayable while every `.tres` was correct. **117 checks**,
  including the cats: `aggro_cats` is catnip's whole reason to exist and no
  measurement of the *bird* can see it, so that one measures the cats.

**4. BOTH NEW GATES SPENT MOST OF THEIR FIRST RUNS ACCUSING A HEALTHY GAME**,
and that is the part worth remembering. Leg 1 is the retention pond and the
goose spawns in it, so the "ground" metrics were measuring `_tick_water()`. Sink
rate sampled at terminal velocity compared `max_fall` to itself and reported
that the dive button does nothing. The substance fingerprint took 12.2 s of game
time against a nitrous that lasts 7.0, so it measured the bird after the
substance had ended. Drift was measured as a wobble when over a short window it
is a bias. The climb was predicted without the brain chemistry that scales it.
**Every one of those first presented as the game being broken.** Both files now
carry a measured noise floor — sober twice, and refuse to report if the two
disagree — and contamination guards that fail LOUDLY as *harness* faults, saying
in as many words: do not tune the game from these numbers.

**5. LEG 7 IS 230 s**, which `docs/BOSS_DESIGN.md` §2.2.2 has always asked for.
The comment in `main.gd::ROUTE` forbidding it described a constraint that
`zone_truckstop.gd::_clock_scale()` had already removed, and nobody noticed
because **a comment cannot run**. It is now
`tools/selftest.gd::_the_rig_schedule()` — the same constraint as an assertion,
checked on every clock the leg can legally be dealt. BIG DOWN needed no change:
`DOCK_OPENS_WITH` puts the truck-stop phase at t=112, which is the 110 s §2.2.2
specifies, to within two seconds.

**6. The render probe could not write a file on Windows and said it had.**
`Image.save_png()` *returns* an error rather than raising one, and all twelve
call sites printed `[probe] wrote /tmp/gg_x.png` unconditionally. The project's
entire visual verification loop was a step that could not fail. It now takes
`--out:`, checks the return, and exits non-zero. It also gained `--secs:`
(wall-clock, because `--frames:` was calibrated for a 2 fps software renderer and
photographs the wrong moment entirely on a machine with a GPU), `--look:` (frame
something other than the goose — an encounter that arrives from behind was
literally unphotographable), and `--goto:`.

**7. LEG 5 IS A BESPOKE ZONE.** `zone_stopover.gd` — a National Wildlife Refuge
impoundment at dawn: drowned marsh, cattails, dead standing timber, a dyke road,
an observation tower, a birdwatcher whose scope tracks you, and forty geese
standing around doing nothing. All sixteen substances are present and the zone
says nothing about it. Two of its four primaries are about **looking at your own
flock**, which is true nowhere else in the game. The route has no placeholders
left.

**8. BIG DOWN IS BUILT.** `boss_big_down.gd` + `prop_models_bigdown.gd` — the
back half of leg 7. The dock opens with no announcement, the warehouse is racked
with white down bales that burst into the same feather particle the game has
spent on faceplants for six legs, the honk finally shatters glass, and the leg
ends on a roof in the rain looking back across the interstate at the truck stop
where your flock is. Nobody says a word about any of it.

**9. Every zone has its own air.** Seven procedurally generated ambience beds,
chosen by zone id in `_load_zone()`. Every leg used to play `amb_parking_lot`.
The truck stop's "rain" turned out to be a 0.700 s goose hiss that never looped —
`Sfx` only forces looping on keys ending in `_loop` — so the wettest zone in the
game opened with seven tenths of a second of hissing and then three minutes of
silence, under a visible downpour.

**10. The Almanac reaches the ending.** The credit roll ends with one slab per
substance the player discovered, naming what it actually was. No counter, no
percentage — a completion score at the end of a forty-five minute run is an
invitation to farm the rest. Separately: **the credit roll never moved.** Writing
`linear_velocity` does not suspend contact friction, so a 8 m/s² ramp lost to
μ·g ≈ 9.8 and the whole roll settled at 0.31 m/s and piled into a wall 40 m short
of the camera. Nobody had seen it because the ending had only ever been probed at
twelve seconds.

**11. The flight was flown by planks.** `migration.gd` hardcoded the classic
visual and never called `animate()`, so every goose in every crossing held its
wings rigid. Obstacles also had no once-only flag: a wire or turbine re-fired
every frame for the 20–40 frames it sat in the trigger window, removing a
*different* goose each time.

**12. The clock lie, a third time.** Leg 1 — the only leg that never passes
through `_on_migration_done()` — had been running 180 s against a route that says
240 for the entire life of the project. `main.gd` gained the public
`leg_seconds()` accessor `docs/CLOCK_AND_CAMERA_NOTES.md` asked for by name.

**13. `ROUTE.name` was read by nothing at all.** Leg 1 announced itself as the
strip mall lot and leg 5 as cottage country, while the route, the campaign spec
and the ending's own credit roll called them the retention pond and the stopover.
The two reused zones were the only ones that could not know which leg they were
standing in, and they were exactly the two that got it wrong.

**14. A long tail, found by an adversarial panel.** 32 findings, each fix
re-checked by an agent that did not write it. The panel caught three fixes that
did not work — including one that moved `ChaosProp`'s cooldown into
`_physics_process` and silently broke `CreditSlab`, which overrides it without
calling `super()`. Also fixed: `is_on_floor()` read before `move_and_slide()`; a
fall that did not begin with a takeoff never landing at all; `Juice.pop()`
scaling an NPC's collision capsule and a pickup's trigger volume; a blackout
coroutine that outlived its leg; framerate-dependent flight banking; hitstop
leaking into the camera FOV; hallucinations hard-coded to `y = 0` and therefore
spawning underwater in the one zone whose ground is at 6.6 m; four substances
with no HUD icon; a third independent toad.

**15. A second pass over the audit backlog**, all verified headlessly because the
machine was in use:

- **The credit roll had never actually been fixed, and the reason was an API
  choice rather than a number.** Writing `linear_velocity` from
  `_physics_process` on a RigidBody3D lands BEFORE the physics step, and the
  solver then applies gravity, friction and contact resolution on top of it —
  so raising the acceleration constant from 8 to 24 just meant losing a bigger
  number every tick. The drive is now in `_integrate_forces()`, which runs
  inside the step and is authoritative, and driving slabs get `can_sleep = false`
  because a sleeping body receives no integrate callback at all. There is a new
  gate for it: **`--rolltest` measures the speed headlessly**, because the
  symptom took four to six minutes of watching the ending to notice. Measured
  1.96 m/s against a designed 2.15; the old drive measures **0.00**.
- **BIG DOWN's guaranteed spectacle pointed the wrong way.** §2.2.7 promises that
  if the player never breaks the last wall, "he backs into it, panicking". He was
  told to retreat along his own `basis.z`, but his last waypoint is the lit
  window — inboard of the north face — so he arrives *facing* the glass and his
  back walked him south, away from the storey that was exploding. He is now
  handed the wall's position.
- **The encounter's clocks were in scaled seconds and the leg's in real ones.**
  HARD_CAP "90 seconds" was 225 real seconds on nitrous, and substances only ever
  push `time_scale` down. On a punished leg 7 the player could still be inside
  the building when the leg ended.
- **`glazier` counted scoring calls, not panes** (see §4), and **the Stopover's
  honk reactions listened to the KEY rather than the honk** — `do_honk()` returns
  early inside its 0.22 s cooldown, so mashing H paid out an eight-goose primary
  in about a second with fewer than half the presses making a sound. `honk.gd`
  now has a `honked` signal.
- Geometry, all arithmetic: the observation tower's legs and landing posts
  carried a spare `-0.125` on their centres with no matching half-height, so
  every one hung 70 mm short of the plate it was meant to carry; the weir's
  splash was built entirely beneath the waterline; a girt band ran across all
  four open dock doorways in mid-air; and five aisle lights hung 1.1 m below the
  roof steel in an 11 m dark room, lit.

**16. The new code was then audited by agents that did not write it**, with a
three-vote refutation panel per finding, because every fix batch this session
contained at least one fix that did not work. It found, among others:

- **The Stopover's `name_a_driver` primary could never complete.** The flock pen
  names a driver, sobers the bird, vests it, plays two sounds and throws
  DESIGNATED DRIVER into the air — and never scored the label the objective waits
  on. A required primary, unwinnable. `tools/selftest.gd` now fails the build if
  any `LBL_*` in a defs file is referenced from nowhere else; CLAUDE.md records
  this bug class costing two objectives in Suburbia, so that was its second run.
- **A repeatable revive.** Landing short does not advance the leg, so failing
  flight 5 re-entered leg 5 and fired `rest()` again — including the Stopover
  top-up, which `CAMPAIGN_SPEC.md` §4.5 calls the only place in the game a goose
  is ever gained. Bailing on one crossing was a free resurrection, repeatable.
- **The rig departure schedule was absolute against 180 s**, while leg 7 can be
  handed 120 s after a bad leg 6 — so a third of the trucks never left, and the
  player who most needed the emptying-lot beat was the only one who never got it.
- **It was raining indoors** — and, underneath that, the truck stop's rain had
  always fallen straight through the fuel canopy, the travel-centre roof and the
  diner awning, the three places the zone offers as shelter.
- **Two bugs introduced by this session's own fixes**: the new GROUND-state
  landing check was sized with real-world gravity rather than the controller's
  28 m/s² (a 0.64 m trigger, not the 1.8 m its comment claimed) and could not
  tell a fall from a launch, so every trampoline bounce in Suburbia became a
  faceplant with a hitstop.
- **A stuck audio loop**: walking out of a pickup's range mid-charge left the
  dose charge loop rising in your ears until the leg ended, because
  `clear_eat_target()` zeroes the charge in the same statement that clears the
  target, so the guard that would have stopped the sound was already false.

The verifier prompt defaults to `refuted = true` when unsure. That is the setting
that matters: a panel that wants to agree finds nothing.

---

## ⟳ 3. What to do next

**Nothing here is waiting on you any more.** This list opened with **"Play it"**
for two sessions running, which meant everything behind it was blocked on one
person having a free evening, and so nothing behind it moved. That was a
process bug, and it has been fixed at the root rather than by deleting the line:
`tools/feeltest.gd` (step 4 of `verify.ps1`) now measures 22 controller metrics,
13 of them asserted against windows argued out in `docs/FEEL_TARGETS.md`. Tuning
is work an agent can do and show receipts for. See `CLAUDE.md`, *"Taste is the
human's. Everything measurable is yours."*

**Play it whenever you want to.** It is your game. It is not a dependency.

In order:

1. **Two feel questions that are genuinely yours** — `docs/FEEL_TARGETS.md` §5.
   Neither is a bug; both are one-line changes that alter traversal everywhere,
   which is why they were left rather than decided.
   * The glide is **0.87–0.98 : 1** — a metre forward per metre down, which is a
     controlled fall. `GEEKED_GEESE_DESIGN.md:130` promises *"chain it into a
     safe glide and you're fine"*, and at 1:1 there is not much glide to chain.
   * Any 20 m glide arrives at **20.9 m/s** against a `hard_landing_speed` of
     13.0. Sober that is a 15-point "ROUGH LANDING" and a reward; on a substance
     with `ragdoll_landings` it is an unavoidable faceplant every descent.
2. ~~**Leg 7's clock.**~~ **Done this session.** Leg 7 is 230 s, which is what
   `docs/BOSS_DESIGN.md` §2.2.2 asks for, and BIG DOWN's `DOCK_OPENS_WITH`
   (118 s left) puts the truck-stop phase at t=112 — the 110 s §2.2.2 specifies,
   to within two seconds. **No code changed except the number.** The comment in
   `main.gd::ROUTE` forbidding it described a constraint that
   `zone_truckstop.gd::_clock_scale()` had already removed, and nobody noticed
   because a comment cannot run. It is now
   `tools/selftest.gd::_the_rig_schedule()`, which reproduces the scaling and
   checks the last rig still departs with the zone's closing beat intact on
   every clock the leg can legally be dealt.
   * **One open taste question, recorded rather than decided.** That closing
     beat is *proportional* — the schedule leaves exactly 6.0% of the leg empty
     at every clock, so 13.8 s at 230 s and 6.6 s at Mission's 110 s floor. A
     readable moment is arguably absolute, not proportional: a human needs
     roughly ten seconds to notice an empty lot whatever the clock says. Making
     it absolute is a one-line change to `_clock_scale()`. Not made, because
     nothing specifies it and it is pacing.
3. **The Ranger's leg 6 exam** — the corn field it was written for now exists.
4. **Convert a zone to a real `.tscn`.** Still the accepted debt, still the wrong
   way to do level design, and now eight zones deep.
5. **The two encounters have been photographed but never played.** BIG DOWN's
   75-second cap, the shutter telegraph and whether a honk-shattered curtain
   wall reads as the payoff it is designed to be are all unknown; so are the
   Ranger's `ACQUIRE` (22 m), `PURSUE_SPEED` (9.5 m/s) and six-second `HAZED`.
   **This is recorded as a known gap, not as a request.** An encounter's pacing
   is taste. If it wants measuring, the pattern to copy is `tools/feeltest.gd`:
   find the part of it that is a number, argue a window for that number in
   `docs/FEEL_TARGETS.md`, and leave the rest alone.

---

## ⟳ 4. Known issues and honest gaps

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

**MIGRATION HAS NO FEEL INSTRUMENT AT ALL, and one derived number is worth a
look.** Seven flights against seven zones and nothing measures any of them
beyond "the campaign completed". `_tick_player()` integrates position directly,
so the response times fall out of the constants: a full corridor crossing is
**1.53 s**, a half crossing 0.76 s, a full climb 2.54 s. Leg 7 — the peak —
spawns hazards every **[0.9, 1.6] s**, so at the tight end **a full corridor
crossing does not fit between two hazards** and a half crossing comfortably
does. That is arguably the right shape for the hardest flight: you commit to a
side rather than swinging across the lane. It is also written down nowhere, and
a property this load-bearing living in two constants in two files is the pattern
that produced the clock lie three times. `docs/FEEL_TARGETS.md` §6 — **derived,
not measured**, and labelled as such.

**Leg 1's world-space labels collide.** In `shots/gg_zone1_0.png` the flock pen
prompt and the goose name tags overprint each other near the pond — the visible
result is a smear reading `[G] …AKE GOR… THE DD`. Six geese with names, a
`[G] TAKE <name>` prompt and a `THE DD` tag all draw in the same square of
screen with no z-ordering or de-overlap between them. Pre-existing, cosmetic,
and a layout judgement rather than a bug, so it is recorded rather than guessed
at. Everything else in the twelve renders read correctly: leg 7's HUD clock now
says **3:49** for its new 230 s, leg 5's dawn marsh is intact, and the Almanac
shows 16/16.

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
- **`collider_boxes(&"racking")` promises a clear full-width deck at every beam
  level and the mesh fills it**, which breaks the "a goose climbs the racking one
  level per flap" argument the 1.70 m beam pitch exists for.
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

**On Windows, all four checks in one command:**
```
.\verify.ps1            # gate + invariants + controller + the whole campaign
.\verify.ps1 -Quick     # skips the 20 s campaign run
.\verify.ps1 -Shots     # also renders every zone into .\shots\
```
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
