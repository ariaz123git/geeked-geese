# Architecture — the build as it exists

**This file describes the code that is actually here.** It replaces an earlier
specification that the build never followed and that was cited by `CLAUDE.md`
and `HANDOFF.md` for months without existing on disk. The divergence was real
and is now decided rather than open; §7 records what was decided and why, so
nobody re-litigates it by accident.

---

## 1. The shape of a run

```
Game.new_run()
      │
      ▼
  ┌───────────────────────────── main.gd (the scene director) ───────────┐
  │                                                                      │
  │  ROUTE[leg] ──► _load_zone()  ──► briefing ──► play ──► clock out    │
  │                      ▲                                    │          │
  │                      │                                    ▼          │
  │                      │                            Mission.end_leg()  │
  │                      │                                    │          │
  │                      │                             results card      │
  │                      │                                    │          │
  │                      └──────────── _on_migration_done() ◄── flight   │
  │                                            │                         │
  │                            leg > FINAL_LEG │                         │
  │                                            ▼                         │
  │                                     _finish_run() ──► zone_finale.gd │
  └──────────────────────────────────────────────────────────────────────┘
```

`main.gd` **swaps child nodes** rather than calling `change_scene_to_file()`.
That is the load-bearing decision of the whole file: autoload state — tolerance,
flock condition, Almanac unlocks, mission progress — has to survive every phase
change, and a scene change would take it with it.

`ROUTE` holds the **seven flown legs**. Leg 8 is not in it, because it is not a
leg: the 18th green has no clock, no objectives and no flight out. It is the
arrival, and it lives in `_finish_run()`.

## 2. The ten autoloads, in load order

`Prefs · Tex · Sfx · Subs · Game · Flock · Unlocks · Juice · Mission · Music`

**Order matters** — several resolve each other in `_ready()`. `Prefs` is first
because four of the others read settings during boot; `Music` is last because it
subscribes to everything.

| Autoload | Owns |
|---|---|
| `Prefs` | the settings file, the best score, which briefings have been seen |
| `Tex` | the generated texture cache; hands out shared `ImageTexture`s |
| `Sfx` | one-shots, loops, and per-substance honk pitch |
| `Subs` | the 16 substances, the dose sweet-spot arc, tolerance, comedowns, `mods` |
| `Game` | phase, chaos score, combo, the zone clock |
| `Flock` | the geese as **data** — see §4 |
| `Unlocks` | which Almanac entries have been earned |
| `Juice` | hitstop, the shake bus, squash-and-stretch, particles, floating text |
| `Mission` | objectives, grading, and the next leg's clock |
| `Music` | the adaptive score: which stems play, at what volume |

Ten is a lot, and the original spec said one. §7 explains why they stayed.

## 3. Substances are data, not code

A substance is a `Resource` (`scripts/core/substance.gd`) saved as a `.tres` in
`data/substances/`. `Subs` enumerates the folder at boot. **Adding one is a file,
never a code change.**

Every frame, `Subs` calls `resolve(dose, tolerance)` on each active substance and
merges the results into **one flat Dictionary, `Subs.mods`**. The goose
controller never asks *"am I on berries?"* — only *"what is my input lag right
now?"*

That indirection is the reason the substance count went **3 → 16 without the
controller changing a line**, and it is why `data/substances/*.tres` is a format
a designer can edit.

> **The rule: a substance must never be only a number that goes up.** Every one
> needs a *control mutation* — something that changes how the player's hands
> work. If it only edits `speed_mult`, delete it.

Tolerance scales the *good* parts of a substance and never the bad ones. That
asymmetry is the entire economy: the fourth double-double gives you less speed
and the same jitter.

## 4. The flock is data during a zone and bodies during a flight

`Flock.birds` is an `Array[Dictionary]` — name, intox, stamina, alive, scars,
scar log, loss reason. **No flock AI has to survive the chaos sandbox**, which is
the single biggest scope saving in the project. The birds only become physical
`Node3D`s inside `migration.gd`.

`Flock.player_index` is the player's own bird and can never be lost. Without it a
run can reach zero geese, at which point the migration spawns nothing, finishes
at 0 km, awards a short zone, and repeats that forever — a soft-lock dressed as
difficulty.

## 5. Rendering and effects

- **One uber-shader.** `shaders/screen_fx.gdshader` has one branch per substance
  family (wobble / jitter / slowmo / trip / macropsia / acid / blackout), driven
  by uniform writes. Not N shaders: 2D shaders are not precompiled by Godot and
  each new one is a guaranteed frame hitch the first time it is used.
- **`Engine.time_scale` has exactly two owners.** `Subs` writes the baseline
  (substance slow-motion); `Juice` writes a multiplier on top and runs at
  `process_priority = 100` so it writes last. They have a documented contract in
  `docs/JUICE_NOTES.md`. **Do not add a third.** A stranded write once left a run
  in permanent 0.106× slow motion with no way out.
- **All assets are procedural.** 39 textures (23 surfaces plus 16 substance
  icons) from `tools/gen_textures.py`, 39 SFX and 7 zone ambience beds from
  `tools/gen_audio.py`, 22 music stems from `tools/gen_music.py`. No imported
  art or audio anywhere in the project. These counts are claims C-003 to C-007
  in `docs/CLAIMS.md` and the build fails if they drift.
- **Two interchangeable art styles.** `goose_visual.gd` (smooth primitives) and
  `goose_visual_lowpoly.gd` (faceted, ~570 triangles, no curved primitive
  anywhere) expose an identical public API and are chosen by the `goose_model`
  pref. Cats and humans follow the same switch. Switching is live.
- **Meshes go through `scripts/goose/lowpoly_builder.gd`.** Godot's front faces
  are **clockwise**, the opposite handedness from the right-hand-rule normal any
  mesh routine naturally computes; `_emit()` reverses winding while keeping the
  normal. Hand-rolled `SurfaceTool` code in this project has shipped invisible
  geometry twice.

## 6. Zones

A zone is a `.gd` that builds its own node tree. The contract is small:

| Member | Required | What |
|---|---|---|
| `goose` | yes | the player's `CharacterBody3D` |
| `camera_rig` | yes | the follow camera |
| `zone_title()` | no | the banner string |
| `mission_zone_id()` | no | which objective set to load |
| `objectives()` | no | zone-authored extras |

Everything else — hallucinations, the Ranger, the HUD, the mission HUD — is
attached *beside* the zone by `main.gd`, so a zone author never has to know those
systems exist and never has to tear them down.

Bespoke labels passed to `Game.score()` live in `mission_defs.gd` as constants
and are imported by the zone, so a rename is a parse error in both files instead
of a silently dead objective. That bug shipped once and cost two objectives in
Suburbia.

**Zones are built in code rather than as `.tscn` scenes.** That was deliberate
for a first-playable — the project runs correctly the first time it is opened,
with no missing references — and it is **the wrong way to do level design.**
Converting them is known, accepted debt.

## 7. The decisions that were open, and what they are now

The original spec called for a `Gg` prefix on every `class_name`, exactly one
autoload, substance behaviour composed from `GgSubstanceEffect` resources, and a
`GgDoseContext` holding mutable state. None of that is what got built. Decided:

| Question | Decision | Why |
|---|---|---|
| Composed effect resources vs. one flat `resolve()` Dictionary | **Keep the flat Dictionary.** | It is why the substance count went 3 → 16 without touching the controller, and why `.tres` files are designer-editable. This is the best decision in the codebase. |
| One autoload vs. ten | **Keep ten.** | They are load-bearing and ordered. Collapsing them into one god-object buys a smaller autoload list and costs every clean boundary in the project. The real cost of ten is boot-order fragility, which §2 documents rather than hides. |
| `Gg` prefix on `class_name` | **Do not rename.** | The stated risk — a bare `class_name` colliding with an engine class — is real but is caught immediately and loudly, and there are 12 of them. A rename touches every file for a hazard that has never fired. |
| `GgDoseContext` | **Dropped.** | Mutable dose state lives in `Subs`. There was never a second consumer. |
| Static typing everywhere | **Aspiration, not a gate.** | Mostly typed, not universally. The gate that matters is `tools/gate.gd`. |

The rule going forward: **do not silently "fix" code toward the old spec**, and
do not add a document that describes an architecture nobody built.

## 8. Verifying

See `docs/HANDOFF.md` § Verifying. The short version: `tools/gate.gd` is the only
real compile gate, and **anything visual has to be rendered and looked at** — the
first render is always wrong, and every bug in this project's history that a
human would have spotted in one second was found by reading a PNG rather than by
reading code.
