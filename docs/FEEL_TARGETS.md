# FEEL TARGETS — the numbers, and the argument for each one

Every window asserted by `tools/feeltest.gd` is written down here with the
reason it is where it is. **The reason is the point.** A window with a number
and no argument is a vibe wearing a lab coat, and the next session cannot tell
whether widening it is a fix or a cover-up.

> **How to use this file.** Run `godot --headless --path . -- --probe --feeltest`.
> Every row it prints has an entry below. If a row goes OUT, come here first —
> the entry says what the number means and what breaks when it drifts.

---

## 0. Why this file exists at all

This project could always prove the goose **moves**. It could never prove the
goose moves **well**, and `tools/inputtest.gd` says so in its own header:

> *"WHAT THIS CANNOT DO: judge whether any of it FEELS good. That is the human's
> job and this file does not have an opinion about it. Every threshold below is
> deliberately loose — they are there to catch 'broken', never 'not tuned'."*

That sentence is honest and it was also load-bearing in a bad way. With no
instrument for feel, the only available move at the end of every session was to
defer to the human — so `docs/HANDOFF.md` §3 said **"Play it"** at the top of the
list two sessions running, nothing else could proceed behind it, and the project
stalled on a queue of one.

The unblock is not to stop caring about feel. It is to notice that **"feel" is
two things wearing one word:**

| | |
|---|---|
| **Taste** | Is a waddling goose funny. Is the honk timed right. Is the Ranger's voice good. Is the ending earned. |
| **Response** | How long to reach top speed. How far you slide after letting go. Whether holding the flap button converges on a climb rate or diverges into orbit. |

The first column is the human's, permanently, and no file in this repo will ever
have an opinion about it. **The second column is arithmetic**, it is what makes a
controller feel broken rather than merely unfunny, and nothing in this project
was measuring any of it.

`feeltest.gd` does the second column. It found, on its first run, that a held
flap **compounded** — 7.36 m of climb in the first second and 23.66 m in the
third, accelerating, with a `max_fall` in the controller and no `max_rise`
anywhere. Five gates passed on that build.

---

## 1. Two classes of metric, and the distinction is load-bearing

**ASSERTED** — has a window, fails the build. A metric only gets promoted to
asserted once its value has been measured, reasoned about, and written up here.

**OBSERVED** — measured and printed, no window, fails nothing. This is where a
metric lives while it is still being understood.

An OBSERVED row is **not** a weakened assertion. It is an honest *"we are
watching this and have not earned an opinion yet."* Adding a metric is cheap.
Adding a **window** is not, and should not be.

### The rule for changing a window

Widening a window to make a red build green is the single easiest way to destroy
this file's value, and `CLAUDE.md` already forbids it in general terms
(*"Never weaken an assertion, delete a check, or lower a tolerance to make
something pass"*). Concretely, here:

1. **A window may be changed only by editing its argument below, first.** If the
   new number does not survive being written down next to a reason, it is wrong.
2. **A window may never be widened in the same commit that made it fail.**
3. Moving a metric from ASSERTED back to OBSERVED is allowed, once, with a
   written reason — and it must say what would have to be true to promote it
   again.

---

## 2. The asserted windows

Values are from the run on **2026-08-17**, sober, leg 1, on dry ground.

### Ground

| Metric | Window | Now | The argument |
|---|---|---|---|
| `ground.latency` | 1–3 ticks | **1** | One physics tick is the floor — you cannot beat the tick the key arrives on. 3 ticks is 50 ms and is already the point where a player stops believing the bird is theirs. |
| `ground.top_speed` | 3.0–6.0 m/s | **4.20** | Zones are ~80 m across. Below 3 m/s crossing one takes half a minute and the 3-minute zone clock becomes a walking simulator. Above 6 m/s it stops reading as a *waddle*, which is the whole physical joke. |
| `ground.time_to_top` | 0.10–0.40 s | **0.20** | Under 0.10 s the bird has no mass at all and reads as a cursor. Over 0.40 s it reads as pushing a fridge. This is `waddle_speed / waddle_accel` and nothing else. |
| `ground.stop_distance` | 0.05–0.80 m | **0.59** | The goose capsule is about 0.7 m long. Coasting more than one body length past the key you released is the definition of "icy" — and the zones are full of ledges and water you are trying *not* to slide into. |
| `ground.turn_180` | 0.15–0.80 s | **0.30** | Chasing a rolling cart is the core comedy verb of the strip mall. Over 0.8 s to turn around makes every overshoot a punishment instead of a joke. |

### Flight

| Metric | Window | Now | The argument |
|---|---|---|---|
| `fly.one_flap_climb` | 1.30–2.30 m | **1.73** | **The one number this project already committed to.** `docs/HANDOFF.md` §4 argues from *"a goose climbs the racking one level per flap"*, and BIG DOWN's racking is built on a **1.70 m** beam pitch to suit it. A single flap lifting 1.73 m is that promise, kept, to within 2%. If this drifts, a whole encounter's geometry silently stops working. |
| `fly.climb_peak` | 1.0–14.0 m/s | **6.08** | Above 14 m/s the bird clears anything built in this game in under two seconds, and zone geometry — roofs, racking, the atrium, the whole vertical dimension of the level design — stops meaning anything. |
| `fly.climb_convergence` | 0.55–1.40× | **0.99** | Metres climbed in the **3rd** second of a held flap over metres climbed in the **1st**. Holding a button must converge on a *rate*. Above 1.40 the flap compounds, altitude is free, and the stamina bar is the only thing between the player and orbit. **This is the assertion the file was written for**; see §4. |
| `fly.dive_beats_glide` | 1.15–4.0× | **1.65** | The dive has its own button. If it does not measurably beat simply falling, it is not a verb. Measured over a **20 m drop**, not as a sink rate — see §5 for why that distinction matters. |
| `fly.glide_ratio` | 0.70–1.10 :1 | **0.85–0.87** | Metres forward per metre down over a real 20 m drop — the number that decides whether you can reach that other roof. **This window is a regression guard, not an endorsement.** It is centred on what the game does today so that `glide_gravity`, `air_speed` or `max_fall` cannot move without traversal moving silently with them. Whether 0.86 : 1 is the *right* glide is a live design question and it is **§5.1**, not this table. |

### Stamina

| Metric | Window | Now | The argument |
|---|---|---|---|
| `stam.flaps_to_empty` | 6–24 flaps | **22** | Under 6, a full bar is a hiccup rather than a resource and there is no "when do I spend" decision to make. Over 24 it is not a constraint at all. **This sits near the top of its window and that is known** — `regen_glide` refunds 0.05/s on the cooldown frames, so the effective cost is ~0.043 rather than the nominal `flap_cost` of 0.058. Worth revisiting; not worth asserting tighter until a human has flown it. |
| `stam.refill_ground` | 1.5–8.0 s | **3.82** | This is the length of the pause the game *forces* on a grounded bird. Over 8 s it stops being a rhythm and becomes a punishment, in a mode with a 3-minute clock. |

### Response

| Metric | Window | Now | The argument |
|---|---|---|---|
| `dose.latency` | 1–12 ticks | **1** | Eating is the game's core verb. More than 12 ticks (0.2 s) between the dose landing and the world changing breaks the cause-and-effect the entire comedy depends on. |

---

## 3. The observed rows — measured, not yet judged

These are printed on every run and fail nothing. Two of them are real open
questions and are written up in §5 rather than quietly asserted.

| Metric | Now | What it is |
|---|---|---|
| `fly.climb_1st_second` / `fly.climb_3rd_second` | **4.50 m** / **4.45 m** | The two halves of `climb_convergence`, printed so a failure is readable without re-deriving it. |
| `fly.glide_20m_time` | **1.90 s** | Seconds to lose 20 m gliding, forward held, no flap. |
| `fly.glide_20m_run` | **16.9–17.3 m** | Horizontal distance covered over that descent. |
| `fly.glide_impact` | **20.90 m/s** | Arrival speed after a 20 m glide. `hard_landing_speed` is 13.0. **See §5.2.** |
| `fly.dive_20m_time` | **1.15 s** | The same 20 m with dive held. |
| `fly.turn_180` | **0.67 s** | Air turn. `air_turn_rate` is 4.2 against the ground's 9.0 — banking, deliberately. |
| `cam.catch_up` | **0.35 s** | Rig to within 4 m of a bird teleported 20 m. `-1` means it never did. |
| `cam.residual` | **3.99 m** | Rig-to-bird distance when that window closed. |

### Stability, measured

A gate that flickers is worse than no gate, because it teaches everyone to
ignore red. So the harness was run three times back to back on an unchanged
build. **Eleven of the twelve asserted at the time came back bit-identical:**

```
ground.latency        1.00  1.00  1.00      fly.one_flap_climb    1.73  1.73  1.73
ground.top_speed      4.20  4.20  4.20      fly.climb_peak        6.08  6.08  6.08
ground.time_to_top    0.20  0.20  0.20      fly.climb_convergence 0.99  0.99  0.99
ground.turn_180       0.30  0.30  0.30      fly.dive_beats_glide  1.65  1.65  1.65
ground.stop_distance  0.59  0.60  0.59      stam.flaps_to_empty  22.00 22.00 22.00
dose.latency          1.00  1.00  1.00      stam.refill_ground    3.82  3.82  3.82
```

`ground.stop_distance` moves by 0.01 m against a window 0.75 m wide.

**This did not come for free, and the flake was instructive.** The zone does not
spawn the goose in the same place twice, so `_find_dry_ground()` returns a
different pad each run — 7 m from spawn on one, 28 m on the next. An earlier
version accepted the first spot that was dry *while standing still*, and on one
run that was the pond shoreline: the walk test then held forward for two
seconds, covered 8.4 m, waded in, and reported `top_speed` **5.40** — which is
`swim_speed` — and `stop_distance` **1.41 m**, because `_tick_water()` has no
friction term. **It turned `verify.ps1` red on a controller that was fine.**

Two things fixed it, and the second matters more than the first:

1. `_find_dry_ground()` now requires a dry **pad** — four probes at
   `PAD_RADIUS` = 9 m must all be dry — rather than a dry point, and the walk
   test was shortened to 90 ticks so it stays inside that pad.
2. `_watch_dry()` counts any tick of a ground measurement on which the bird was
   actually in water, and a non-zero count fails the run with a message saying
   **HARNESS fault, do not tune the controller from these numbers.** A wrong
   answer now announces itself instead of being reported as a verdict.

### The glide rows were promoted, and what it took

They were OBSERVED at first because they moved 17.36, 17.40 and **19.54 m**
across identical runs — a 12% swing, and *a metric that moves 12% between
identical runs cannot fail a build.*

The cause was the camera, not the bird. `_raw_input()` rotates the stick by
`-cam.get_yaw()`, and `goose_camera.gd` auto-follows the direction of travel, so
the world bearing "forward" means **rotates while the bird is flying**. Correct
for play; ruinous for measurement. `_aloft()` now parks the rig's `_manual_t`,
which takes the auto-follow branch out and pins the yaw for the whole test.

Three runs after the fix: **17.12, 17.32, 16.92 m** — a 0.40 m spread against
2.18 m before, and a ratio of 0.85–0.87 against 0.87–0.98. `fly.glide_ratio` is
asserted on that basis; `fly.glide_20m_run` stays observed because it is the
same measurement in less useful units.

---

## 4. The bug this file was built to catch

`_flap()` read:

```gdscript
velocity.y = maxf(velocity.y, 0.0) + power
```

It **added** the impulse to an already-positive climb. One flap costs 0.30 s of
cooldown; `glide_gravity` takes only `11.0 × 0.30 = 3.3` m/s back over that
window, while `power` is 6.08 at resting adrenaline. Every held flap therefore
netted **+2.78 m/s on the last one**, compounding, unbounded.

| | before | after |
|---|---|---|
| climb, 1st second of held flap | 7.36 m | **4.50 m** |
| climb, 3rd second | 23.66 m | **4.45 m** |
| convergence ratio | **3.22×** | **0.99×** |
| peak climb rate | 29.5 m/s | **6.08 m/s** |
| **one flap, from level** | **1.73 m** | **1.73 m** |

The fix is `maxf(velocity.y, power)` — the flap **sets** the climb instead of
adding to it. From level flight both forms give exactly `power`, so the single
flap is bit-for-bit unchanged and the 1.70 m racking promise survives untouched.
Only the stacking goes. It also self-limits across `flap_mult`: Double-Double's
2× flap rate doubles `power` *and* halves the cooldown, and still converges.

**Every other gate passed on the broken build** — compile, 393 invariants, the
controller smoke test, the credit roll, and the full seven-leg campaign.

---

## 5. Two open questions this file deliberately does NOT decide

Both are one-line changes. Both change how the whole game traverses. Neither is
a bug, and asserting a window on either would be inventing a taste judgement and
calling it arithmetic.

### 5.1 The glide is 0.98 : 1

A goose currently travels **0.98 m forward per 1 m down**. That is a controlled
fall, not a glide. `GEEKED_GEESE_DESIGN.md:130` promises *"chain it into a safe
glide and you're fine"*, and at 1:1 there is not much glide to chain into.

**The case for changing it:** flight between rooftops is the fantasy, thermals
are a whole migration-mode mechanic built on the assumption that altitude is
worth something, and 1:1 makes altitude worth almost exactly one horizontal
metre.

**The case against:** the zones are 80 m across and 20–35 m tall. A 3:1 glide
crosses an entire zone from one flap-stack, which trivialises the ground
traversal the chaos scoring is built around. It would also silently invalidate
every "the goose cannot reach that" assumption in eight zone builders.

**If it changes:** a separate `glide_sink_max` (~5 m/s) used when not diving,
leaving `max_fall` at 34 for dives. One export, one line in `_tick_fly()`. It
would need the full campaign re-run and probably a pass over zone geometry.

### 5.2 Any 20 m glide arrives at 20.9 m/s, and `hard_landing_speed` is 13.0

So a plain descent from tall geometry always registers as a hard landing.

**This is much less alarming than it looks**, and the code is why: sober, a hard
landing is `Juice.hitstop(0.05)`, a shake scaled to impact, and **"ROUGH LANDING"
for 15 points**. It is a *reward*. The faceplant — tumble, 1.15 s of lost
control, 0.9 shake — only fires when `m.ragdoll_landings` is set, which is a
substance opting into it.

**But** on those substances, every single descent from height becomes a
faceplant with no way to avoid it except flaring on approach, and nothing in the
game teaches flaring. That is either a good implicit lesson or an unfair one,
and **which of those it is depends on playing it.** Left observed on purpose.

---

## 6. The flight, computed — and why this section is weaker than the rest

**Everything above this line was MEASURED. This section was not.** It is derived
from `migration.gd`'s own constants, because migration mode is half the game —
seven flights against seven zones — and has no feel instrument at all. Derived
numbers are real arithmetic but they are not evidence that the code does what
the arithmetic says. Treat this as a lead, not a result, and if it matters,
build the gate.

`_tick_player()` integrates position directly rather than running physics, so
the response times fall straight out:

| | | |
|---|---|---|
| Corridor width | **26 m** | `CORRIDOR_X` 13, both ways |
| Lateral speed | **17 m/s** | |
| **Full corridor crossing** | **1.53 s** | edge to edge |
| Half crossing | **0.76 s** | centre to edge |
| Climb, 5 → 34 m | **2.54 s** | flap 13.0 against a 1.6 sink |
| Dive, 34 → 5 m | **1.46 s** | dive 18.2 plus the sink |
| Passive sink, no input | **18.1 s** | to fall the whole band |

### The one that is interesting

`CAMPAIGN_SPEC.md` §2.6 gives leg 7 — THE PEAK, the hardest flight in the game —
a hazard spawn interval of **[0.9, 1.6] s**. A full corridor crossing takes
**1.53 s**.

So at the tight end of that range **the player cannot cross the full corridor
between two hazards.** A half crossing (0.76 s) fits comfortably inside even a
0.9 s gap.

That is not obviously wrong — it is arguably the correct shape for a peak. It
means the corridor is wide enough that you **commit to a side** and make small
corrections, rather than swinging across the whole lane on every obstacle. What
it is not is *stated anywhere*, and a property this load-bearing being an
accident of two numbers in two different files is exactly the pattern that
produced the clock lie three times.

**If it is intended, write it down.** If it is not, the lever is
`CORRIDOR_X`, the lateral 17.0, or the spawn interval — and moving any of them
changes all seven flights.

---

## 7. What will never be in this file

Whether the goose is funny. Whether the honk lands. Whether the strip mall is a
good first zone. Whether the ending earns itself. Whether any of it is *fun*.

Those are taste, they are the human's, and no measurement replaces them. What
this file removes is the excuse of pretending that **"the flap compounds by
3.22× and nothing has a max_rise"** was ever in the same category.
