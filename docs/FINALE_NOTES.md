# THE ENDING — build notes

`scripts/world/zone_finale.gd` + `scripts/world/prop_models_finale.gd`.
Spec: `docs/CAMPAIGN_SPEC.md` Part 5. This file records what got built, where it
departs from the spec and why, and what is still missing.

---

## 1. Wiring it in

> **⚠ ALREADY DONE — do not apply this twice.** Confirmed 2026-08-04:
> `main.gd::_finish_run()` calls
> `preload("res://scripts/world/zone_finale.gd").install(self)`. It also resets
> `Engine.time_scale` and prints a `[run] COMPLETE` line with the survivor names
> before the `install()` call, which is a superset of what this section asked
> for and is correct. This section is now a record of *why* the wiring looks
> like that, not a task.

**One line.** Replace the entire body of `main.gd::_finish_run()` with:

```gdscript
func _finish_run() -> void:
	preload("res://scripts/world/zone_finale.gd").install(self)
```

`install()` calls the director's own `_clear()`, adds the zone as `current`
(so a later restart frees it), recaptures the mouse, and hands control straight
back. **Do not also call `Game.set_phase(Game.Phase.RESULTS)`** — the zone
stops the clock itself (`Game.zone_running = false`), and a RESULTS phase leaves
`Music`'s migration watchdog armed, which drags the flight cue back over the
ending twelve seconds later.

There is nothing else to change. The zone does not need a `ROUTE` entry and
should not get one: it is not a leg.

To render it during development, point the leg-8 `ROUTE` entry at
`res://scripts/world/zone_finale.gd` in a scratch copy. It survives that path
(it hides the HUD, kills the clock and never registers objectives), but it is
not how it should ship.

---

## 2. What is in the zone

| | |
|---|---|
| **Public surface** | `goose`, `camera_rig`, `zone_title()`, `install()` |
| **Deliberately absent** | `mission_zone_id()`, `objectives()` |
| **Geese** | 30 residents + every survivor in `Flock.alive_birds()` |
| **Course** | fairway, green + pin, unraked bunker, water hazard + fountain, cart path, tee, 16 sprinklers, palms, two moss oaks, wrap-around treeline, clubhouse |
| **New models** | palm, flagstick, sprinkler, spray_fan, fountain, golf_cart, golf_ball, spanish_moss, credit_slab, ball_washer |
| **Interface** | the route pin (fades in at 2 s, gone by 10 s) and `[ESC]` (appears 26 s after the roll ends). Nothing else, ever. |

The beats follow §5.3 exactly: you land with control; your survivors land beside
you in a loose line; every ~7 s one peels off and joins a resident with its name
floating up once in world space; the DD goes last and stands next to you; a honk
anywhere gets 36 honks back in a ragged wave from nearest to furthest; then the
credits walk up the fairway as knockable slabs; then nothing happens, forever.

---

## 3. Deviations from the spec, and why

**1. The lost geese say "somewhere north of here", not where and when.**
The spec's roster line is `WAYNE — put down over Lake Ontario · leg 4`.
`flock_state.gd` records `name / is_dd / intox / stamina / alive / scars` and
nothing else: there is no leg, no cause, and no `joined_at_leg`. Rather than
invent a plausible-looking leg number, every bird that did not arrive gets one
line — *"somewhere north of here"* — which is true of all of them, is not a
death (per §4.2 the copy must never imply one), and does not fabricate a fact
in a game whose whole credibility rests on its facts being real.
**To get the spec's version**, `Flock.lose_bird()` needs to write
`{lost_leg, lost_cause}` onto the record and `migration.gd` needs to pass which
of the two channels fired. That is a change to two files I did not own.

**2. No memorial across runs.** §5.3 item 6 wants every goose lost in every
previous run printed in small type. `prefs.gd::load_prefs()` only reads back
keys that exist in `DEFAULTS`, so a `memorial` key would be written and then
silently dropped on the next launch. Adding one line to `DEFAULTS` makes this
about twenty minutes of work in `_compose_credits()`.

**3. The credits use the cottage/lake stems, not `mus_green`.** §5.6 budgets a
new stem set ("the game's theme, played straight, fiddle through a blown speaker
but in tune"). `tools/gen_music.py` is not mine and generating 33 MB of audio was
out of scope. The lake set is the warmest and least percussive of the three and
holds at a fixed 0.26 intensity floor. **This is the single biggest thing still
missing from the ending** — the sincere beat is carried entirely by the honk
wave and the sprinklers right now.

**4. The chaos total is in the roll.** The spec's credit payload has no score in
it at all, deliberately. The brief asked for the run summary (chaos, legs,
survivors, Almanac) to be delivered in the scene, so `41,200 CHAOS` appears once,
as a bare number, in a block of three facts between `1,850 KM IN A STRAIGHT LINE`
and `YOU FOUND 13 OF 16`. No grade, no percentage, no comparison, no "best".
The legs are covered by the eight route slabs. **The reason it is a slab and not
a card**: a card admits that the ending stopped to tell you something. A slab you
can knock over does not — and a run summary you are allowed to destroy is a much
better statement of what this game thinks of scores than any wording would be.

**5. The credits wait for the honk, but not forever.** §5.3 has beat 5 follow
beat 4. If the player never works out that honking does anything, the roll
starts 42 s after the last survivor settles anyway. A player who never honks
still gets an ending.

**6. The residents' behaviour table is the spec's, with two additions.**
Spots 6 and 7 in the settling table (the golf-ball argument, and standing next
to the goose that faces north) exist because a 6/6 run has six survivors and the
spec lists five destinations.

**7. Scars are rendered as unexplained pips.** `WAYNE ··  arrived`, and in the
world-space name float. Nothing anywhere says what a pip is. Note that right now
the ONLY writer of `scars` is `Flock._top_up_to()`, so in practice a pip
currently means "joined at the Stopover" — §4.8's three real writers are not
built yet, and the pips will start meaning the right thing for free when they
are.

---

## 4. Things that were wrong until they were rendered

Every one of these compiled clean and looked fine in the code.

1. **The HUD would not go away.** Three separate causes stacked: `CanvasLayer`
   is not a `CanvasItem`, so an `is CanvasItem` test matches neither HUD; the
   HUD is created *after* the zone in `_load_zone()`, so hiding it in `_ready()`
   is too early; and `_load_zone()` queue_frees the old HUD and adds the new one
   in the same frame, so `add_child()` hits a name collision and renames the new
   node to `@CanvasLayer@1233` — `get_node("HUD")` finds the corpse.
   Now matched **by script reference**, which is the only identity those nodes
   keep.
2. **The water hazard was a disc of brown mud.** The basin's top face sat 13 cm
   above the water surface. Only a 3 cm ring of blue was visible.
3. **The bunker was also brown mud**, from running the `dirt` texture over it,
   with a ring of pale angular `rock` models round the rim that read as broken
   polystyrene.
4. **The Spanish moss floated two metres above the oaks.** The model is
   base-anchored like everything else in the project — it occupies y 0.4–2.9
   *above* its origin. It does not hang down from where you put it.
5. **The whole course was bleached cream** — dark green conifers rendered the
   same value as bunker sand. Warm ≠ bright: the ambient, the fog and the fill
   were all roughly halved.
6. **The mowing stripes were flat-colour slabs on a textured plane**, so they
   read as plastic panels rather than as a different cut of the same grass, and
   the edge of the striped region was a visible line across the fairway in three
   of the first four shots.
7. **Both geese on the golf cart were knee-deep in the floor pan** — the goose
   visual's origin is at the hips, 0.46 above its feet.
8. **The route pin rendered a hundred pixels right of centre.**
   `PRESET_CENTER_TOP` anchors both edges at 0.5.
9. **The goose asleep on its back was unreadable at exactly 180°** — a
   symmetrical lump with two orange dots. Tipped to 2.75 rad it reads instantly.
10. **A survivor that settled into the golf-ball argument threw
    `Invalid access to key 'pivot'` once per frame** for the rest of the ending.
    Found by driving the real `install()` path for 100 simulated seconds.

---

## 5. Verification actually run

> **Updated 2026-08-04.** This section was right that `--import` is not a gate
> and was the first place in the repo to say so. Its proposed replacement —
> per-file `--check-only` — has since been superseded by a real project-wide
> gate, `tools/gate.gd`. The text below is kept because the *reasoning* is still
> the reasoning; only the recommended command changed.

**The old gate does not catch GDScript parse errors:**

```
$ godot --headless --path . --import 2>&1 | grep -iE "SCRIPT ERROR|Parse Error|ERROR:"
(blank)
```

Verified: a file containing `var x := some_dict.key` — the exact failure
`CLAUDE.md` warns about — imports with completely blank output, and then fails to
load at runtime. It caught none of the five parse errors in this zone.

**Use this instead:**

```
$ godot --headless --path . -- --gate
```

It force-loads every `.gd`, `.tres` and `.tscn` *inside the booted project*, so
the autoload singletons are registered and `Identifier not found: Game` is a real
error rather than an artefact. Exit 0 is the only pass. See `tools/gate.gd`.

The per-file form this section originally recommended —
`godot --headless --path . --check-only --script scripts/world/zone_finale.gd` —
still works for a single file, but it parses in isolation, so
`Compile Error: Identifier not found: Game` is a **false positive on most of this
project**. Only `Parse Error` is real there. Prefer `--gate`.

Rendered from a scratch copy at `/tmp/gg_finale` with a throwaway harness
(`tools/_finale_probe.gd`, never committed) that drives the zone past the beats a
normal probe cannot reach, plus the standard probe at `--leg:8`. Twelve shots:
arrival, fairway, green, pond, bunker, sprinkler, cooler, cart, clubhouse,
settled, credits, slab, and one of the real `install()` path.

Runtime checks on that path, with pasted output in the build report: no script
errors over 100 simulated seconds; 36 geese; 6/6 survivors settled; roll
started; **0 visible CanvasLayers on Main**; `zone_running=false`;
`time_scale=1.0`; mouse captured; honk wave queues 36 and drains to 0 and
re-triggers; a credit slab is in `chaos_prop`, is angular-locked while it walks,
unlocks and topples on `shove()`, breaks on a force-30 hit, and moves
`Game.chaos` by **0**.

---

## 6. Still missing

- `mus_green` stems (§3.3 above). The biggest gap.
- The real credit names. `CREDITS` at the bottom of `zone_finale.gd` is ten
  placeholder lines marked `TODO`; everything above them in the roll is
  generated from the run. Names of actual people are the one thing that must
  never be generated.
- Per-goose loss data for the roster (§3.1) and the cross-run memorial (§3.2).
- Zone-specific SFX. The sprinklers are silent; the ending's ambience is
  currently the honks and nothing else. A looping water bed would do more for
  this zone than any geometry left in it.
- These notes were written from measurements and renders, not from play.
  Every judgement in here about how it *feels* — the 7 s
  settling cadence, the 2.55 s credit spacing, the 2.15 m/s walk speed of a
  slab, whether the honk wave lands — is inference from a still image, and
  playtesting is what settles it.
