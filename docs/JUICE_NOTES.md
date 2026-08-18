# Juice — research, design, and integration

Deliverable: `scripts/core/juice.gd`, an autoload-shaped `Juice` node providing
`hitstop`, `shake`, `pop`, `burst`, `floating_text`, plus `reset()` and
`debug_counts()`.

Verified: 40/40 headless assertions pass (pooling, leaks, zero-pref no-ops,
hitstop composition at baseline and under nitrous, shake bus, reset), plus a
visual pass confirming all four burst kinds and the floating text actually
render.

---

## 1. What I researched

**The two canonical talks.** Nijman's *The Art of Screenshake* is a live
demonstration of ~30 incremental additions to an unchanged shooter — bigger
bullets, muzzle flash, impact effects, hit animation, enemy knockback,
permanence (holes and casings that stay), camera lerp, screen shake, player
knockback, **sleep/pause on hit**, gun delay, gun kickback, shell casings,
bass on the impact sound, camera kick opposing the shot, bigger explosions,
lingering smoke. The lesson is not any single item; it is that none of them
touch the mechanics and all of them compound. Jonasson & Purho's *Juice it or
lose it* makes the same case from a Breakout clone, and its specific vocabulary
is tweening/easing, squash-and-stretch, particles, trails, screen shake, and
layered sound.

**The criticism, which I took seriously and which shaped the API.**

* *Vestibular harm.* Camera motion the player's body did not initiate is a
  documented motion-sickness trigger. Xbox Accessibility Guideline 117 is the
  clearest statement of the remedy: avoid camera shake, camera bob, motion blur
  and speed lines, or provide a way to turn them off — and it explicitly
  prefers a **sliding intensity scale per effect** over a binary toggle, citing
  Halo Infinite's 0–100% controls for screen shake and full-screen effects and
  Cyberpunk 2077's additive-camera-movement slider.
* *Occlusion.* Effects that sit between the camera and the thing the player is
  trying to read are a net loss no matter how good the clip looks. This is the
  most common way "juice" makes a game worse.
* *Hitstop as an inflation problem.* A freeze applied to every contact stops
  reading as impact and starts reading as frame drops. It only works if it is
  rare and short.

Consequences in the code: nothing is on/off; `screen_shake` and `fx_intensity`
scale continuously and reaching 0 is a genuine no-op (tested). Shake is capped
at 1.2 and decays at 2.4/s so a pile-up cannot produce a long ride. Hitstop is
hard-clamped to 120 ms, requests never queue (longest wins), and it is
suppressed outright under deep slow-motion. Bursts are small, short-lived and
spawned at the event, never toward the camera.

Sources:
[Art of Screenshake writeup](https://theengineeringofconsciousexperience.com/jan-willem-nijman-vlambeer-the-art-of-screenshake/) ·
[the talk](https://www.youtube.com/watch?v=SkgkIXZ_13Y) ·
[Juice it or lose it](https://www.gdcvault.com/play/1016487/Juice-It-or-Lose) ·
[Xbox Accessibility Guideline 117](https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/117) ·
[Making games juicy](https://abagames.github.io/joys-of-small-game-development-en/make_game_juicy.html)

---

## 2. How hitstop coexists with the nitrous `time_scale` system

`substance_manager.gd` already owns `Engine.time_scale`, rewriting it every
frame:

```gdscript
Engine.time_scale = lerpf(Engine.time_scale, mods.time_scale, 1.0 - pow(0.001, delta))
```

Two systems writing one global is how you get a clock that never settles. A
naive hitstop would be erased by that lerp within ~100 ms, and — worse — Subs
would then be lerping *from* the dipped value, so the freeze would contaminate
the substance slow-motion state.

**The rule: Subs owns the baseline, Juice owns a multiplier, Juice writes
last.**

1. `process_priority = 100` in `Juice._ready()` guarantees Juice's `_process`
   runs after Subs' regardless of autoload order, so Juice's write is the one
   that lands.
2. **Juice never reads `Engine.time_scale` to decide anything.** It reads
   `Subs.mods.time_scale` — the substance system's *intent*, a plain unsmoothed
   number nothing else touches — and publishes `base * dip`. That closes the
   feedback loop that would otherwise let Juice's own output become its input.
3. When the freeze ends, Juice writes exactly `base` once and then stops writing
   entirely. Subs' lerp resumes from precisely the value it was heading for, so
   there is no snap and no fight.

Two consequences worth stating, because they are design decisions and not
accidents:

* **Hitstop is relative.** On nitrous (`time_scale` 0.45) a hitstop dips to
  `0.45 × depth` and recovers to **0.45, not 1.0**. It reads as an impact
  *inside* the slow-motion instead of cancelling it. Tested explicitly.
* **Hitstop fades out as the world slows.** Strength is scaled by the baseline
  and suppressed entirely below `time_scale` 0.15, because a freeze frame
  inside slow motion is nearly invisible and only costs responsiveness.

Also: `process_mode = PROCESS_MODE_ALWAYS` and the hitstop ticks in **real**
seconds (`delta / Engine.time_scale`). Without both, pausing mid-freeze would
leave `Engine.time_scale` pinned at 0.05 forever.

One tuning note the test caught: the ease curve is `pow(k, 0.4)`, not `k*k`. A
symmetric ease has already returned a third of the freeze by the time the first
frame is drawn — a requested depth of 0.08 was arriving on screen as 0.36,
which reads as a slowdown rather than a hit.

---

## 3. What each function does

| call | behaviour |
|---|---|
| `hitstop(seconds, strength)` | Clamped to 120 ms. Longest outstanding request wins; requests never queue. Relative to the substance baseline. |
| `shake(amount)` | Adds to a global bus, scaled by `screen_shake`. Capped at 1.2, decays at 2.4/s. The camera reads it, so anything anywhere can trigger it. |
| `shake_value()` | Current magnitude, for the camera to consult. |
| `pop(node, amount, secs)` | Squash-and-stretch with one decaying overshoot, volume roughly conserved. Retriggers rather than stacking on a node already popping. Restores the captured base scale on completion or on `reset()`. |
| `burst(pos, colour, count, kind)` | Pooled `CPUParticles3D` (14 emitters, round-robin). Kinds: `debris`, `feathers`, `splash`, `sparkle`. Unknown kinds fall back to `debris`. One shared vertex-colour material for every particle in the game. |
| `floating_text(pos, text, colour)` | Pooled `Label`s (18) on their own `CanvasLayer`. World-anchored and re-projected every frame via `unproject_position`, culled when behind the camera or past 55 m, shrunk with distance, deterministic sideways drift so simultaneous numbers don't stack. |
| `reset()` | Drops all in-flight effects and releases the clock. |
| `debug_counts()` | Pool occupancy, for the dev overlay. |

`CPUParticles3D` rather than `GPUParticles3D` deliberately: the project runs
the `gl_compatibility` renderer, where CPU particles are the safe choice and
still cost one draw call per emitter.

---

## 4. Exact integration instructions

> **⚠ ALREADY DONE — do not apply this section again.** Verified 2026-08-04:
> `Juice` is registered in `project.godot`, and fourteen files call into it
> (`goose_controller.gd`, `goose_camera.gd`, `honk.gd`, `chaos_prop.gd`,
> `cat.gd`, `npc_human.gd`, `substance_pickup.gd`, `game.gd`, `main.gd`,
> `migration.gd`, `results_screen.gd`, `zone_cottage.gd`, `zone_finale.gd`,
> `boss_ranger.gd`).
>
> **The `project.godot` snippet in §4.1 is a historical snapshot and no longer
> matches the file.** The live autoload order is
> `Prefs Tex Sfx Subs Game Flock Unlocks Juice Mission Music` — ten of them, with
> `Juice` **after** `Unlocks`, not after `Subs`. Pasting §4.1's block over the
> real one would delete `Mission` and `Music`. Read `project.godot`.
>
> §6's note that Juice exposes no camera *kick* is still true — there is no
> `kick` anywhere in `juice.gd` or `goose_camera.gd`.

### 4.1 `project.godot`

Add **after** `Subs` (the ordering does not actually matter because Juice sets
`process_priority = 100`, but keeping it after Subs makes the dependency
obvious to the next reader):

```ini
[autoload]

Prefs="*res://scripts/core/prefs.gd"
Tex="*res://scripts/core/tex.gd"
Sfx="*res://scripts/core/sfx.gd"
Subs="*res://scripts/core/substance_manager.gd"
Juice="*res://scripts/core/juice.gd"          ; <-- add this line
Game="*res://scripts/core/game.gd"
Flock="*res://scripts/core/flock_state.gd"
Unlocks="*res://scripts/core/unlocks.gd"
```

### 4.2 `scripts/goose/goose_camera.gd` — route shake through the bus

Two edits. **`add_shake()` (line 88)** becomes a forwarder — note that Juice
applies the `screen_shake` pref itself, so the local `_shake_pref` multiply
must go or it is applied twice:

```gdscript
func add_shake(amount: float) -> void:
    Juice.shake(amount)
```

In **`_process()` (lines 174–178)**, drop the local decay and read the bus:

```gdscript
    # --- shake ---
    var jitter := 0.0
    if int(Subs.mods.get("fx_mode", 0)) == 2:
        jitter = float(Subs.mods.get("fx_strength", 0.0)) * 0.5 * _shake_pref
    var s: float = (Juice.shake_value() + jitter) * 0.06      # was (_shake + jitter)
    if s > 0.0001:
        camera.h_offset = randf_range(-s, s)
        camera.v_offset = randf_range(-s, s)
    else:
        camera.h_offset = 0.0
        camera.v_offset = 0.0
```

The `var _shake := 0.0` member and the `_shake = maxf(0.0, _shake - delta * 2.2)`
line can both be deleted.

### 4.3 `scripts/world/chaos_prop.gd`

**`_break()` (line 95)** — the biggest single win in the game. Insert at the
top of the function, after `_broken = true`:

```gdscript
    Juice.hitstop(0.07, 0.8)
    Juice.shake(clampf(mass / 60.0, 0.25, 0.7))
    Juice.burst(global_position, _color, 14, &"debris")
    Juice.floating_text(global_position + Vector3.UP * (_size.y * 0.6),
        "%s!!" % label, Color(1.0, 0.86, 0.32))
```

While you are in there: the five `RigidBody3D` debris chunks it spawns are now
redundant with the burst and are the more expensive half. Drop the loop to
**two** physical chunks and let `burst()` carry the rest — same read, a fifth of
the rigid bodies during a pile-up.

**`_maybe_score()` (line 81)** — non-fatal hits. After `Game.score(points, label)`:

```gdscript
    Juice.shake(clampf(force / 45.0, 0.04, 0.30))
    var vis := get_node_or_null("Model")
    if vis == null:
        vis = get_node_or_null("Mesh")
    if vis is Node3D:
        Juice.pop(vis, 0.16, 0.15)
```

(`"Model"` is what `PropModels.build()` names its node; `"Mesh"` is the old
box. Checking both means this works before and after the art pass lands.)

Deliberately **no hitstop here** — a freeze on every glancing contact is
exactly the inflation failure described in section 1.

### 4.4 `scripts/goose/goose_controller.gd`

**`_do_land()` (line 318)**, inside the `hard` branches. Put it right after
`landed.emit(hard, impact)` so it fires regardless of which scoring branch
runs:

```gdscript
    if hard:
        Juice.hitstop(0.05, 0.55)
        Juice.shake(clampf(impact / 20.0, 0.15, 0.9))
        Juice.burst(global_position + Vector3.DOWN * 0.35,
            Color(0.58, 0.56, 0.50), 10, &"debris")
```

**`_start_tumble()` (line 349)** — the faceplant, which should be the loudest
feedback in the game:

```gdscript
    Juice.hitstop(0.09, 1.0)
    Juice.shake(0.9)
    Juice.burst(global_position + Vector3.UP * 0.4,
        Color(0.94, 0.94, 0.92), 16, &"feathers")
```

**`_on_water_enter()` (line 125)**, in the `_water_bodies == 1` branch:

```gdscript
        Juice.burst(global_position, Color(0.55, 0.78, 0.92), 16, &"splash")
        Juice.shake(0.18)
```

**`_tick_eat()` (line ~455)**, where the sweet-spot label is decided. The
sparkle is the reward signal for the game's core skill expression, so it should
be unmistakable:

```gdscript
        if in_band:
            Juice.burst(_eating.global_position + Vector3.UP * 0.4,
                res.tint, 12, &"sparkle")
            Juice.pop(_eating, 0.30, 0.22)
```

⚠ **Do not `pop()` the goose's own visual.** Substances already drive its scale
(`_tick_size`, `scale_amp`) and the two would fight. Pop the pickup instead.

### 4.5 `scripts/core/game.gd` — floating numbers everywhere, for one line

`score()` has no position, so give it an optional one. This is the cheapest way
to get world-anchored score popups across the whole game without touching
twenty call sites:

```gdscript
func score(base: int, label: String = "", at := Vector3.INF) -> void:
    combo += 1
    combo_timer = 3.0
    var mult: float = Subs.mods.get("chaos_mult", 1.0) * (1.0 + 0.12 * float(combo - 1))
    var amount := int(round(float(base) * mult))
    chaos += amount
    leg_chaos += amount
    chaos_scored.emit(amount, chaos, combo, label)
    if at.is_finite():
        var warm := Color(1.0, 0.88, 0.40).lerp(Color(1.0, 0.45, 0.25),
            clampf(float(combo - 1) / 8.0, 0.0, 1.0))
        Juice.floating_text(at + Vector3.UP * 0.8, "+%d" % amount, warm)
```

Existing calls are unaffected. Then pass a position from the ones that have
one — `chaos_prop._maybe_score()` (`global_position`), the trampoline bounce
and roof/pool bonuses in `zone_suburbia.gd` (`body.global_position`).

The colour ramp is doing real work: the number goes from yellow to hot orange
as the combo climbs, which is a free readout of combo state that never occludes
anything.

**`start_zone()`** — add `Juice.reset()` next to `Subs.reset_for_new_leg()`, so
a hitstop or a pop cannot survive a scene swap holding a stale node reference.

### 4.6 `scripts/world/substance_pickup.gd`

In `consumed()` (line 123):

```gdscript
    Juice.burst(global_position, substance.tint if substance else Color.WHITE,
        10, &"sparkle")
```

### 4.7 `scripts/world/npc_human.gd`

In `startle()` (line 79) — a small pop sells the reaction far better than the
existing movement alone:

```gdscript
    Juice.pop(self, 0.22, 0.20)
```

### 4.8 Both zone files — remove the now-duplicated shake

`zone_strip_mall.gd` (lines 492–497) and `zone_suburbia.gd` (lines 1023–1028)
connect `landed`/`tumbled` to `camera_rig.add_shake(...)`. Once 4.4 is in, the
controller triggers those itself, so **delete both lambdas** — otherwise the
shake is applied twice.

### 4.9 Audio layering (no code in Juice)

`Sfx` already exists and does this job, so Juice deliberately owns no audio.
The one change worth making is at the impact sites: layer a low "body" sample
under the existing "detail" one rather than pitching a single sample. In
`chaos_prop._break()`, alongside the existing `smash`:

```gdscript
    _sfx.play_at(&"crash_heavy", self, -6.0, 0.6)   # sub layer, pitched down
```

That low layer is what Nijman's "more bass" step is actually doing, and it is
the single cheapest audio change available here.

---

## 5. Recommended intensity defaults

`Prefs.DEFAULTS` already has `screen_shake: 1.0` and `fx_intensity: 1.0`, which
is the right default. No pref changes are needed. Confirm the pause menu's two
sliders write the full `0.0 … 1.0` range (Juice clamps to `0..2`, so a slider
that goes to 2.0 for "more" also works and is a nice option).

---

## 6. Known limitations

* `burst()` recycles emitters round-robin, so more than 14 simultaneous bursts
  steals the oldest. That is the correct failure mode, but if the strip mall's
  eleven minivans ever break at once you will see it; raise `POOL_BURSTS`.
* `floating_text()` uses one font size with a theme override rather than the
  game's HUD theme — it will not automatically follow a future restyle.
* `pop()` captures the node's scale at the moment it starts. If something else
  changes that node's scale mid-pop, the pop restores the captured value.
  Documented in the function, and the reason the goose body is off-limits.
* Juice does not currently expose a camera *kick* (directional push opposing an
  impact) — a genuinely effective technique from the Nijman talk that would suit
  the goose's landings. It needs a direction argument and a camera-side offset,
  and was left out rather than half-built.
