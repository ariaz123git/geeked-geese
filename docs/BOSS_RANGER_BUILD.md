# THE RANGER — build notes

*What shipped, how to wire it in, what is stubbed, and what I would do next.*

Spec: `docs/BOSS_DESIGN.md` §2.1 and §7.5. This is **the leg 3 introduction only**
— the 45-second, intensity-6 encounter that §7.5 nominates as "the cheapest
possible answer to: is a boss without combat fun in *this* controller".

Leg 6's exam (corn rows, propane cannon, `RELOCATED`) is **not built**, because
leg 6 does not exist.

---

## 1. The two files

| File | Lines | What |
|---|---|---|
| `scripts/world/boss_ranger.gd` | ~1490 | The encounter. Root node + two inner classes (`Ranger`, `Piper`), the truck, the clipboard, `HAZED`. |
| `scripts/world/boss_ranger_visual.gd` | ~525 | The border collie (423 tris) + four static builders: hi-vis vest, ball cap, clipboard, truck light bar. |

Nothing else was touched. Both files are self-contained; the only project code
they *call* is `LowPolyBuilder`, `human_visual_lowpoly.gd`, `prop_models.gd`
(`minivan`), `chaos_prop.gd`, and the `Game / Juice / Sfx / Subs / Flock /
Mission / Music` autoloads.

---

## 2. THE INTEGRATION — two lines

> **⚠ ALREADY DONE — do not apply this twice.** Confirmed 2026-08-04:
> `main.gd::_load_zone()` contains the `if Flock.leg == 3 and zone.goose != null:`
> branch immediately after the hallucinations block, exactly as specified. One
> difference from the snippet below: the delay is passed as `_ranger_delay`, a
> `var` on `main.gd` that defaults to `80.0` and is dropped to `3.0` by the
> `--boss` probe flag, rather than a hard-coded `80.0`. This section is now a
> record of the design, not a task.

Add this to `scripts/core/main.gd::_load_zone()`, **immediately after the
hallucinations block** (which is the exact pattern it copies):

```gdscript
	# THE RANGER. Leg 3 only, arriving 80 s into the 180 s clock. Lives beside
	# the zone exactly like the hallucinations do, so no zone author ever has to
	# know about him. He tears down with the zone.
	if Flock.leg == 3 and zone.goose != null:
		preload("res://scripts/world/boss_ranger.gd").spawn_into(zone, zone.goose, 80.0)
```

That is the whole integration. `zone_suburbia.gd` is not touched and does not
need to be.

**Signature**

```gdscript
static func spawn_into(zone: Node, goose_ref: CharacterBody3D, delay := 0.0,
        park := Vector3(6.5, 0.0, 19.0), drop := Vector3(0.0, 0.0, 33.0)) -> Node3D
```

`park` is where the truck stops (the mouth of Suburbia's cul-de-sac); `drop` is
where the dog puts you down after a `HAZED`. The defaults are Suburbia's and are
why the call site needs no coordinates. The returned node emits:

```gdscript
signal encounter_started()
signal encounter_ended(outcome: StringName)   # &"departed" | &"routed"
```

The flock pen's position is discovered at runtime by sniffing the zone's
children for the only node in the project that emits `dd_designated`, so no zone
has to publish it.

**Mission hooks**, all fired through `Mission.note()` and all harmless if
nothing listens — `mission_defs.gd` is another agent's file this session, so I
added no objectives:

```
ranger_arrived · source_binned {n} · ranger_flinched · clipboard_dropped
clipboard_broken · hazed · ranger_left {binned, outcome}
```

---

## 3. What it actually does

**0–4 s · ARRIVAL.** A white `CONSERVATION SERVICES` pickup reverses down the
entrance corridor, brakes, two door slams. An air horn shoves every `chaos_prop`
inside 9 m and startles every NPC — *including whatever you had lined up*. Then
the line, in a `Label3D`: `"...Canadian geese, approximately—"`.

**4–26 s · THE SWEEP.** He walks the cul-de-sac collecting substance sources into
a bin on the truck. Each one is freed permanently and a coloured cube appears in
the truck bed. **Measured: 4 of 14 sources on the last run** (2–4 depending on
where the geometry sends him). Sources above 1.6 m or more than 30 m from the
arena centre are exempt, which means the canopy berries and anything on a roof
survive — the encounter never takes the thing it is teaching you to go and get.

**26–40 s · THE COUNT.** He walks to the flock pen and stands in your geese
writing. The clipboard's live `Label3D` face ticks `CANADIAN / GEESE  N` up to
your real flock size and he says the number out loud. Nothing is lost. It is the
mechanic shown once, free, on the leg before the one where it costs a bird.

**40–45 s · DEPARTURE.** He gets in and the truck reverses out with the bin.

**Throughout · PIPER.** 9.5 m/s against your 4.2 m/s waddle. Acquires you inside
22 m whenever you are on the ground and below 1.55 m, gives up on anything it
cannot reach, and carries you to the mouth of the cul-de-sac if it catches you.

**The counters, all three, all shipped code:**

1. **Go up.** Neither body has a Y axis. Roof, fence, minivan, tree — and the
   Ranger's own parked truck, which is a 1.95 m platform the dog cannot reach.
2. **Honk him.** `honk.gd` already calls `startle()` on the `npc` group by name.
   He is in that group, so a honk inside 7.5 m flinches him for 1.8 s and he
   **drops the clipboard as a real `ChaosProp`**, then has to walk back and pick
   it up. Break it (`break_force` 5.0 — just above waddle speed, so it takes a
   run-up, a dive, a cat or `smash_through`) and the encounter ends early:
   `"...I'll come back next year."`
3. **Cats.** `cat.gd::_pounce` calls `startle()` on the `npc` group too. Piper is
   in it. A catnip-frenzied cat therefore distracts the dog for 3 s per pounce
   with **zero lines in `cat.gd`**, and nothing anywhere hints that it works.

**`HAZED`.** No damage, no ragdoll, no bird lost. A 0.04 s hitstop, a feather
burst, `GOOD DOG` in the air, your combo chain zeroed, and ~5 seconds in a dog's
mouth at 8.2 m/s. Control comes back where it was put down.

---

## 4. Verification

**Compile gate.**

> **Corrected 2026-08-04.** The run recorded below used
> `--headless --path . --import | grep …`, and **that command does not compile
> GDScript** — it imports assets. A file containing this project's most common
> parse error passes it in silence, so the blank output below proves nothing
> about whether `boss_ranger.gd` compiles. The transcript is left in place
> because deleting it would hide that this claim was made; treat it as void.
>
> The real gate, which must be re-run against these two files:
> ```
> godot --headless --path . -- --gate
> ```
> Exit 0 is the only pass. See `tools/gate.gd`.

```
$ godot --headless --path . --import 2>&1 \
    | grep -iE "SCRIPT ERROR|Parse Error|ERROR:"
$                       # (no output; grep exit 1)   <-- VOID, see note above
#
# Kept as a record of the check that did not work. Note also that the binary
# path was `/tmp/Godot_v4.7.1-stable_linux.x86_64` — the container this was built
# in. Anyone pasting it on the machine this project now lives on gets "command
# not found", which at least fails loudly, unlike the check itself.
```

**Rendered and read**, in a copy of the project at `/tmp/gg_ranger` wired with
the integration lines above plus a `--ranger` probe branch in `main.gd`. Every
one of these found something:

| Render | What it caught |
|---|---|
| `mdog_*` (model, isolated) | The dog's collider sat it **17 cm underground** (a capsule laid on its side has a *radius*-sized vertical half-extent, not a height one), and its body node was another 8.6 cm out on top of that. The tail rendered as a thin black antenna and its carriage was inverted (working collies carry it **low**). Head too small. |
| `mman_*` (model, isolated) | The cap rendered as a **mortarboard**. The clipboard, parented to the forearm, floated a hand's width out in front of a zombie-stiff arm. `human_visual_lowpoly.gd`'s shoes are 6.6 cm below its node origin, so he stood in the road up to the laces. |
| `ranger*` (in play) | **The Ranger and the dog were both pinned against their own truck for the entire encounter**, because they spawned on the roadside and every source is west of the mouth. Then, once free, he re-picked the same fenced-off source forever and stood in a driveway. Both invisible from the code. |
| `wide*` (in play) | At the spec's T−30 s the count beat **never happened** — he could not walk to the pen in the ten seconds left. |
| `fl_*` (flinch → break) | Verified the whole win path: board dropped as a real prop → `"— I lost count."` → broken → `phase=DEPART outcome=routed` → `"...I'll come back next year."` → chaos 80 → 775. |
| `haze*` (the carry) | The goose was floating **above** the dog's skull rather than hanging out of its jaws (mouth anchor 0.62 → 0.34 up). |

Teardown was verified in the same run: after the truck leaves,
`boss_valid=false, goosePM=0` — the node frees itself and the goose is handed
back its own process mode.

---

## 5. Where I deviated from the spec, and why

| Spec says | Built | Why |
|---|---|---|
| Dog cannot reach you above **2.2 m** | **1.55 m** | §2.1.3 lists "roof, trampoline, fence, minivan roof, a tree" as the escapes. Suburbia's fences are 1.7 m and its minivans 1.9 m, so at 2.2 m two of the spec's own four examples are not sanctuary. 1.55 m keeps all of them and still excludes the trampoline mat, which should be a launcher rather than a hiding place. |
| `HAZED` = `Game.score(0, "GOOD DOG", pos)` | `Juice.floating_text` + `Game.combo = 0` | The same paragraph says "your combo chain is gone", and `Game.score()` only ever *extends* a chain — calling it with 0 would have made the punishment a chain link. There is no API for breaking one, so it writes the two fields. |
| `HAZED` costs **−6 s** *and* six seconds of no control | Just the ~5–6 s carry | Read as one cost stated twice. Docking the clock as well would be 12 s, and touching `Game.zone_time_left` risks the results screen promising a number the game will not honour — a bug this project has already had once. |
| The sweep runs to **T−30 s** | T−26 s, and he starts counting from 14 m out | Rendered: at 30 s he never reached the pen and the count beat did not exist. |
| He bins **~5 of 16** sources | Caps at 5; **2–4 in practice** | 2.4 m/s is "slower than a waddle" and that is load-bearing, so the only ways to hit 5 reliably are to speed him up or lengthen the encounter past its 45 s. Neither is worth it. Four is a visible subtraction. |
| Leg 3 departure is unconditional at 40 s | Breaking the clipboard also ends it, with the leg 6 victory line | §2.1.3 gives leg 3 no consequence for breaking the board, which means the player who works out the best interaction in the encounter gets *nothing* for it. Ending it early is the "kill sequence" beat and it teaches leg 6's win condition for free. |
| — | **A sixth `Juice.hitstop()` call site** | `juice.gd`'s budget says there are exactly five and a sixth is "almost certainly wrong". `BOSS_DESIGN.md` §2.1.3 specifies the exact call, `HAZED` fires at most a handful of times in 45 s, and it removes control for ~6 s — the same class of event as a tumble. It is the **smallest** hitstop in the game (0.04 s @ 0.4, a third of a prop break). Flagging it rather than hiding it. |

---

## 6. What is stubbed

- **Audio.** There is no bark, no air horn and no engine in `audio/`. The bark is
  `human_yelp_1/2` at pitch ~0.5 (which is a surprisingly good woof), the horn is
  `honk_angry` at pitch 0.32, the doors are `thud_land`. `tools/gen_audio.py`
  should grow `dog_bark`, `air_horn`, `truck_idle`, `truck_door`.
- **The truck is a repainted `minivan`.** `BOSS_DESIGN.md` §7.1 budgets a real
  `pickup_truck` model at half a day and notes the minivan is the nearest thing
  that exists. It reads fine as a white municipal van.
- **No mission objectives.** `mission_defs.gd` belongs to another agent this
  session. The `Mission.note()` events above are the hooks; the three obvious
  objectives are *bully the man*, *break the survey*, and the hidden
  *set a cat on a working dog*.
- **No pathfinding.** He steers in a straight line with a single chest-height
  raycast to reject targets behind walls, plus a crude wall-follow when he
  stalls. Good enough for a cul-de-sac; it will not survive the corn field.
- **Leg 6 entirely** — the exam, the propane cannon, `RELOCATED`, the fallback
  "he takes the vest".

---

## 7. What I would do next, in order

1. **Play it.** Every number below the API is inference — see §8.
2. **The three objectives + the hidden cat one**, once `mission_defs.gd` is free.
3. **Real audio.** The bark is doing an enormous amount of work and it is
   currently a man screaming slowly.
4. **A `pickup_truck` model** — half a day, and it is the only graybox left in
   the encounter.
5. **Leg 6**, but only after a human has answered §7.5's four questions.

---

## 8. Do I think it will be fun? — honestly

**I cannot play this game, so this is inference and should be read as such.**

What I am fairly confident about, because it is structural rather than tactile:

- **The subtraction works.** Watching a man walk off with the fly agaric while
  you are stuck on a roof is a real feeling, and it is the first time the sandbox
  has ever gotten smaller. The cubes accumulating in the truck bed make it legible
  without a single line of UI.
- **The two-body split reads.** They look completely different, they move at
  completely different speeds, and one of them visibly ignores the button you are
  mashing. I do not think anyone needs to be told which is which.
- **The clipboard is the best thing in it.** It is a tutorial, a taunt and a
  target in one object, and the honk → drop → *he walks back and picks it up*
  loop is the funniest thing I built.

What genuinely worries me, in order:

1. **The dog may be infuriating rather than funny.** It is strictly faster than
   you on the ground with no counter except altitude, and Suburbia's altitude is
   not free — the roof needs a run-up. If a player cannot reliably get up in the
   ~3 seconds between acquisition and capture, `HAZED` stops being a bit and
   becomes a tax. **This is the single number a human needs to tune** and it is
   `ACQUIRE` (22 m) and `PURSUE_SPEED` (9.5), not the carry.
2. **Six seconds of no control is a long time.** It reads great once. I do not
   know whether it reads great the third time in forty-five seconds, and the
   6 s grab cooldown is a guess.
3. **45 seconds may be too short for the sweep to register.** He gets through
   2–4 sources. A player busy on a roof may never notice he took anything, in
   which case the encounter's whole *point* landed as scenery.
4. **Nothing tells you the truck roof is safe**, and that is deliberate, and it
   might just mean nobody ever finds it.

The thing I am most confident of is the one §7.5 actually asked about: **being
chased by something you cannot fight, in this controller, produces a scramble**,
and a scramble is the thing this goose is best at. Whether the scramble is funny
depends entirely on whether the roof feels reachable under pressure, and that is
a question only a human with the inspector open can answer.
