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
time the project can prove the goose responds to the controls.**

| | |
|---|---|
| Engine | Godot 4.7.1, GL Compatibility renderer |
| Code | 65 GDScript files (read the live count off `[gate] PASS — N scripts`) |
| Zones built | 8 — retention pond / strip mall lot (one zone, two legs), suburbia, cottage country, **the stopover**, cut corn, truck stop, the 18th green |
| Route legs | 7 flown + the arrival. **No leg reuses another leg's zone any more.** |
| Substances | 16, all with models, control mutations, true codex facts and — as of this session — a HUD icon |
| Bosses | **2 built.** The Ranger (leg 3) and **BIG DOWN** (the back half of leg 7) |
| Assets | 39 textures (23 + 16 substance icons), 46 sounds (39 SFX + 7 zone ambience beds), 22 music stems — **all procedurally generated** |
| Autoloads | 10 (see `docs/ARCHITECTURE.md` §2 for the order and why it matters) |
| Gates | 5: compile, invariants (393), controller, credit roll, full campaign. `.\verify.ps1` |

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

**1. THE CONTROLLER WAS BROKEN AND NOTHING COULD SEE IT.** `_wanted()`'s
input-lag buffer read the **oldest** sample rather than the newest one old
enough, and was trimmed by a 240-entry count instead of by age. Every substance
with input lag — **eleven of the sixteen** — therefore ramped from 0 to a **four
second** delay over its first four seconds and stayed there. Fermented berries
ask for 0.22 s and got 4.0. That is not "drunk", it is "disconnected".

Proven, not argued: reverting the fix makes a goose on bars cover **0.00 m** in a
full second of held-forward, and the compile gate still passes.

**2. Three new gates, because of #1.** The compile gate, the campaign loop test
and every review this project has ever had were incapable of seeing that bug.
- `tools/selftest.gd` (`--selftest`) — **393 invariants**: the route, both
  clocks, the leg titles, every substance's data, the objective sets, the
  ambience beds, every audio and texture key the code asks for. Every assertion
  is a bug that already got through once.
- `tools/inputtest.gd` (`--probe --inputtest`) — holds W, flaps, honks and doses,
  and measures what the bird did.
- `verify.ps1`, rewritten. Its four old steps could not catch a GDScript error
  between them; see §6.

**3. The render probe could not write a file on Windows and said it had.**
`Image.save_png()` *returns* an error rather than raising one, and all twelve
call sites printed `[probe] wrote /tmp/gg_x.png` unconditionally. The project's
entire visual verification loop was a step that could not fail. It now takes
`--out:`, checks the return, and exits non-zero. It also gained `--secs:`
(wall-clock, because `--frames:` was calibrated for a 2 fps software renderer and
photographs the wrong moment entirely on a machine with a GPU), `--look:` (frame
something other than the goose — an encounter that arrives from behind was
literally unphotographable), and `--goto:`.

**4. LEG 5 IS A BESPOKE ZONE.** `zone_stopover.gd` — a National Wildlife Refuge
impoundment at dawn: drowned marsh, cattails, dead standing timber, a dyke road,
an observation tower, a birdwatcher whose scope tracks you, and forty geese
standing around doing nothing. All sixteen substances are present and the zone
says nothing about it. Two of its four primaries are about **looking at your own
flock**, which is true nowhere else in the game. The route has no placeholders
left.

**5. BIG DOWN IS BUILT.** `boss_big_down.gd` + `prop_models_bigdown.gd` — the
back half of leg 7. The dock opens with no announcement, the warehouse is racked
with white down bales that burst into the same feather particle the game has
spent on faceplants for six legs, the honk finally shatters glass, and the leg
ends on a roof in the rain looking back across the interstate at the truck stop
where your flock is. Nobody says a word about any of it.

**6. Every zone has its own air.** Seven procedurally generated ambience beds,
chosen by zone id in `_load_zone()`. Every leg used to play `amb_parking_lot`.
The truck stop's "rain" turned out to be a 0.700 s goose hiss that never looped —
`Sfx` only forces looping on keys ending in `_loop` — so the wettest zone in the
game opened with seven tenths of a second of hissing and then three minutes of
silence, under a visible downpour.

**7. The Almanac reaches the ending.** The credit roll ends with one slab per
substance the player discovered, naming what it actually was. No counter, no
percentage — a completion score at the end of a forty-five minute run is an
invitation to farm the rest. Separately: **the credit roll never moved.** Writing
`linear_velocity` does not suspend contact friction, so a 8 m/s² ramp lost to
μ·g ≈ 9.8 and the whole roll settled at 0.31 m/s and piled into a wall 40 m short
of the camera. Nobody had seen it because the ending had only ever been probed at
twelve seconds.

**8. The flight was flown by planks.** `migration.gd` hardcoded the classic
visual and never called `animate()`, so every goose in every crossing held its
wings rigid. Obstacles also had no once-only flag: a wire or turbine re-fired
every frame for the 20–40 frames it sat in the trigger window, removing a
*different* goose each time.

**9. The clock lie, a third time.** Leg 1 — the only leg that never passes
through `_on_migration_done()` — had been running 180 s against a route that says
240 for the entire life of the project. `main.gd` gained the public
`leg_seconds()` accessor `docs/CLOCK_AND_CAMERA_NOTES.md` asked for by name.

**10. `ROUTE.name` was read by nothing at all.** Leg 1 announced itself as the
strip mall lot and leg 5 as cottage country, while the route, the campaign spec
and the ending's own credit roll called them the retention pond and the stopover.
The two reused zones were the only ones that could not know which leg they were
standing in, and they were exactly the two that got it wrong.

**11. A long tail, found by an adversarial panel.** 32 findings, each fix
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

**13. A second pass over the audit backlog**, all verified headlessly because the
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

**12. The new code was then audited by agents that did not write it**, with a
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
12 of them asserted against windows argued out in `docs/FEEL_TARGETS.md`. Tuning
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
2. **Leg 7's clock.** BIG DOWN opens the dock on the clock rather than on a fixed
   countdown, so it works at 180 s today. The design wants 230 s (110 truck stop
   → ≤75 tower → 15 roof), which needs `zone_truckstop.gd::DEPART_AT` rescaled
   to the 110-second first phase. The comment in `main.gd::ROUTE` explains why
   that has not been done.
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
