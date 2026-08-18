# Geeked Geese — project rules

3D physics-comedy game. **Godot 4.7.1**, GDScript, Windows 11.
You play a Canada goose. Design doc: `GEEKED_GEESE_DESIGN.md`.

> **Read order for a fresh session** — and when two disagree, the earlier wins:
> **(0)** the code and `.\verify.ps1`, the only things that cannot lie about what
> is built; **(1)** `docs/HANDOFF.md` for current state; **(2)** `docs/DECISIONS.md`
> for what is settled and what is still the human's call; **(3)** this file for
> the stable rules; **(4)** `docs/FEEL_TARGETS.md` and the specs for why a number
> is what it is. Full lifecycle, and the mistakes that cost real time here:
> `docs/SESSION_PROTOCOL.md`.
>
> **This file is deliberately below HANDOFF and DECISIONS in that order.** It
> changes rarely, which is its value and also its risk — see the banner note
> below.

**Current goal: make it feel good.** The campaign is built — seven legs, seven
flights, **two bosses** and an ending, verified end to end — and as of the
2026-08-17/18 session it is *measured* too: eight gates, including a feel
harness that caught the flap compounding and a substance gate that doses all
sixteen and watches what the bird does.
The next real work is still tuning rather than content — `docs/HANDOFF.md` §3 —
but tuning is now something an agent can do and show receipts for. What is
*not* an agent's is taste; see *"Taste is the human's"* below, and the
`Open (human)` entries in `docs/DECISIONS.md`.

> **THIS BANNER WAS WRONG FOR A WHOLE SESSION, AND THAT IS THE LESSON.** It used
> to end "What it has never had is a human playing it. The next real work is
> tuning" — and stayed there after a session had built the instruments to do
> that tuning, because nothing makes a rarely-edited file get re-read. **A
> constraint recorded as prose keeps applying after it stops being true**, which
> has now cost this project three separate blockages (this banner, `ROUTE`'s
> clock comment, `boss_ranger.gd`'s "leg 6 does not exist yet"). If you are
> about to leave a reason in a comment, ask whether it can be an assertion
> instead — and if it cannot, date it and log it in `docs/DECISIONS.md`.

Design docs: route and ending in `docs/CAMPAIGN_SPEC.md`, bosses in
`docs/BOSS_DESIGN.md`, architecture in `docs/ARCHITECTURE.md`. Multiplayer in
`docs/MULTIPLAYER_SPEC.md` — **not started, and deliberately not next.**

---

## Verify before you claim anything

**NEVER state that something works, compiles, or is tested unless you ran a
command and pasted its real output.** "I've implemented and tested this" without
a command trace is a lie, and it is the single most expensive failure mode in
this project.

Exit code 0 is NOT sufficient. **Treat any `ERROR:` or `SCRIPT ERROR:` on stderr
as a failure** — a scene with a dangling resource reference exits 0 while
printing errors.

The compile gate is:
```
godot --headless --path . -- --gate 2>&1 | grep '^\[gate\]'    # check ${PIPESTATUS[0]}
```
`[gate] PASS — N scripts, M resources, 0 failures` and **exit code 0** is the
only pass. It compiles every `.gd` and loads every `.tres`/`.tscn` in the
project. Source and rationale: `tools/gate.gd`.

**A compile gate is not "verified", and this project has the receipt.** An
input-lag bug that made *eleven of the sixteen substances unplayable* — the bird
obeying four-second-old input — passed the compile gate, passed the whole
headless campaign run, and would have passed any review that did not press a
key. There are now eight gates, and one script that runs all of them:

```
.\verify.ps1                                       # all eight. -Quick skips the slow three
godot --headless --path . -- --gate                # it compiles
godot --headless --path . -- --selftest            # it agrees with itself
godot --headless --path . -- --probe --inputtest   # the bird obeys
godot --headless --path . -- --probe --feeltest    # the bird obeys WELL
godot --headless --path . -- --probe --substancetest  # all 16 substances bite
godot --headless --path . -- --probe --migtest     # the flight answers the stick
godot --headless --path . -- --probe --rolltest    # the credit roll actually travels
godot --headless --path . -- --probe --loop-test   # seven legs and the ending
godot --headless --path . -- --doctest             # the DOCS still tell the truth
```

**`--doctest` is the ninth gate and the only one pointed at this repo's own
prose**: every number a doc states is recomputed from the booted project, and
every window `feeltest.gd` enforces is checked against the argument
`FEEL_TARGETS.md` makes for it. It found seven stale facts on the day it was
written. **Any number you write into a document gets a row in `docs/CLAIMS.md`,
or gets deleted.**

`tools/selftest.gd` asserts the things two files can disagree about: the route,
both clocks, the leg titles, every substance's data, the objective sets, the
ambience beds, and every audio and texture key the code asks for.
`tools/inputtest.gd` holds W, flaps, honks and doses, and measures what the bird
actually did. `tools/feeltest.gd` measures how WELL it did it — 22 metrics, 13 of
them asserted against windows argued in `docs/FEEL_TARGETS.md`. It caught a flap
that COMPOUNDED — 7.36 m of climb in the first second of holding the button and
23.66 m in the third, with a `max_fall` in the controller and no `max_rise`
anywhere — on a build where all four of the other gates passed.

`tools/substancetest.gd` doses all sixteen substances and measures the bird for
each one, because the design rule at the top of `scripts/core/substance.gd` —
*a substance must never be only a number that goes up* — was enforced only by
reading the `.tres`. The input-lag bug is the precedent: eleven of the sixteen
were unplayable while every `.tres` involved was correct. Data and behaviour
have to be compared, not each checked alone.

`tools/migtest.gd` is the first thing ever to measure a MIGRATION — half this
game is flights, and the only thing any check knew about one was that the
campaign reached `COMPLETE`.

**Before writing a fifth harness, read the header of `tools/probe_common.gd`.**
Every one of the four written in one session spent its first runs accusing a
healthy game, and every one of those was the instrument, not the game: the goose
spawns in a pond, the zone's cats shove it, the tree pauses behind your back,
the substance ends before the measurement does, and half these drivers are
sine-phased or rotating so a short sample or a net-displacement metric reads
zero. That file carries the list and the shared setup.

**Every assertion in all five is a bug that already got through once.** When you fix
something a gate could not see, add the assertion that would have seen it — and
then break it on purpose and watch it fail. A check nobody has watched fail is
worse than no check, because it launders a guess into a claim. That single
omission is what cost this project four shipped bugs and a dead gate.

### Two gates that do not work — do not go back to them

**Never use `--headless --import | grep ERROR`** (it imports *assets* and never
compiles GDScript — it was the documented gate for most of this project's life
and at least four shipped bugs walked through it) **or `--check-only --script`**
(parses in isolation, so every file touching an autoload false-fails on
`Identifier not found: Subs`, and typo'd method names pass). A gate has to run
**inside the booted project**, which is what `--gate` does. The full argument,
with the 2026-08-04 experiment that proved it, is at the top of `tools/gate.gd`
— read it there rather than re-deriving it.

Parsing `scripts/ui/briefing.gd` makes the engine print 26 × `ERROR: Parameter
"method" is null.` — benign, attributed, and explained at the top of
`tools/gate.gd`. It is why the documented command filters to `^\[gate\]`.

**For anything visual, render it and look at it.** The project has a built-in
probe (see `docs/HANDOFF.md` § Verifying). `_draw()` code, UI layout and 3D
models cannot be verified any other way, and the first render is always wrong.
Renders in this project have caught: an inside-out mesh builder, a goose flying
backwards, invisible mushroom spots, floating props, and text running off screen.

---

## The engine is newer than you are

Godot 4.7 shipped **18 June 2026**; 4.7.1 on 14 July 2026. Your training data
predates it. Before using any API you have not already used in this project,
check `docs/GODOT_4.7_RULES.md`. If it is not there, fetch
`https://docs.godotengine.org/en/4.7/`. Do not pattern-match an API from memory.

**Instant-reject Godot 3 syntax:**
`yield()` · `KinematicBody*` · `Spatial` · `export var` · `onready var` ·
`connect("sig", self, "m")` · `move_and_slide(velocity)` with arguments ·
`.instance()` · `Pool*Array` · `Transform` · `Quat` · `OS.get_ticks_msec()` ·
`deg2rad`/`rad2deg` · `SCREEN_TEXTURE` in shaders · the `.shader` extension ·
`Tween` as a node · `ResourceSaver.save(path, res)` (args swapped in 4.x)

### A local name reused in one function can HANG the parser, with no output

**Symptom: `--gate` prints nothing at all — not even `[gate] compiling N
scripts...` — and never exits.** Not an error, not a crash. Silence.

It happened twice in one session, both times within a minute of an edit:

- `tools/substancetest.gd::_fingerprint()` already declared `var prev` for its
  turn measurement; a second `var prev` was added lower down in the same
  function.
- `tools/selftest.gd::_the_files()` declared `var f` and `var text` in one loop
  and then again in the next loop in the same function.

Both were fixed by renaming (`last_pos`, `f2`/`text2`) and both were confirmed by
bisection: the same edit with a different local name compiles in 25 s, and with
the reused name never finishes. Reproduced twice for `prev`, and `previous`,
`prevd`, `d`, `step` and `delta_v` all pass in the identical position.

**A minimal two-`var prev` file does NOT hang** — with or without `await` it
gives the clean `Parse Error: There is already a variable named "prev" declared
in this scope.` So the root cause is not established and this is not a claim
about Godot in general. What is established is the rule and the diagnosis:

> **Never reuse a local name inside one function scope in this project.** If the
> gate goes silent, the last edit is the suspect — bisect it, and look for a
> name you have already used higher up in the same function.

`git` is the tool for that, which is why the safety net matters: `git stash push
<file>` and re-run the gate isolates it in one step.

### The single most common way this codebase breaks

```gdscript
var x := some_dictionary.key        # PARSE ERROR: cannot infer the type of x
var y := node.some_untyped_property # same
var z := TABLE[i][0]                # same
```
**Any value that comes out of a Dictionary, an Array element, an untyped Node
property, or `.get()` is a Variant and CANNOT be inferred.** Annotate it:
```gdscript
var x: float = some_dictionary.key
```
`Subs.mods`, `Subs.brain` and `Flock.birds[i]` are all Dictionaries. Every read
out of them needs a type. `if c is Foo:` does **not** narrow a Variant loop
variable either — annotate the property read.

Prefer `const X := preload("res://path.gd")` over `class_name` references.
Global class registration only exists after an editor import pass, so a
`class_name` reference breaks in a fresh checkout and in headless CI.

---

## Scenes and files

- **Prefer writing `.gd`.** This project is ~99% code-built node trees; that was
  deliberate (it always runs on first open, with no missing references) and it is
  **the wrong way to do level design.** Converting zones to real `.tscn` files is
  a known, accepted debt — see HANDOFF.
- In a builder script, **every non-root node needs `.owner = root`** or it is
  silently dropped on save.
- **NEVER invent a `uid://` value.** Omit `uid=` from anything you author.
- **NEVER copy a `.tscn`/`.tres` without deleting the `uid=` from its header.**
- **NEVER hand-write `.import` files.** Drop the asset in and run
  `godot --headless --path . --import`.
- **NEVER write into `.godot/`.**
- `ExtResource("x")` / `SubResource("y")` ids: **duplicates are silent and bind
  the wrong resource.** Assert uniqueness before writing a file.
- `git mv` a `.gd` and its `.gd.uid` sidecar together, in the same commit.

## Paths and names

- **Forward slashes only.** `"res://scripts\new.gd"` parses as `res://scripts` +
  newline.
- **Never `sed -i` a file in this repo.** Most of the tree is CRLF, GNU sed
  rewrites it LF, and the result is a diff in which every single line changed.
  It cost `verify.ps1` a 488-line diff for a 30-line edit on 2026-08-17 — a
  diff nobody can review. Use the Edit tool, or a Python read/replace on
  `'rb'`/`'wb'` bytes. `git diff --stat` catches it instantly: a changed-line
  count equal to the file length means the line endings moved, not the code.
- **snake_case every file and folder.** The exported PCK is case-sensitive even
  on Windows.
- `class_name` is one flat global namespace shared with every engine class and
  every autoload. **Grep before adding one — duplicates are silent, last-wins.**
- Never name a file `con.gd`, `aux.gd`, `nul.gd`, `prn.gd`, `com1.gd`.

---

## Physics rules (the top bug sources in this genre)

- `_physics_process` for gameplay. `_process` only for camera and cosmetics.
- **`velocity` is metres per second.** Never `velocity = dir * speed * delta` —
  `move_and_slide()` applies delta itself. `move_and_collide()` is the opposite.
- Framerate-independent smoothing is `lerp(a, b, 1.0 - exp(-rate * delta))`.
  This codebase uses the equivalent `1.0 - pow(k, delta)`. Never
  `lerp(a, b, 0.1)`. For a hard limit use `move_toward`; for angles
  `lerp_angle` / `rotate_toward`.
- **`-basis.z` is forward. `basis.z` is BACK.** The official "Using 3D
  transforms" page contains a sentence claiming Z is forward; it is wrong.
  **Every model in this project is authored facing -Z.** A goose was built
  facing +Z once and flew tail-first for three builds while "correctly" turning
  toward its heading.
- Never accumulate rotation in Euler. Keep yaw/pitch as floats and rebuild.
- `is_on_floor()` **before** `move_and_slide()` returns last tick's state.
- `CollisionShape3D.disabled` must be set via `set_deferred`.
- `contact_monitor = true` does nothing until `max_contacts_reported > 0`.
- Never scale a physics body node — it resizes the collider. Scale the visual.
  (The goose's macropsia scaling deliberately scales collider *and* visual; that
  is the one intentional exception and it is commented as such.)

### Mesh authoring

`scripts/goose/lowpoly_builder.gd` is the faceted-geometry toolkit. **Godot's
front faces are CLOCKWISE**, which is the opposite handedness from the
right-hand-rule normal every mesh routine naturally computes. The builder
handles this in `_emit()` by reversing vertex order while keeping the normal.
Emitting in natural order produces a mesh that is geometrically correct, shades
plausibly, and is entirely back-facing — invisible on open surfaces, silently
lit from the wrong side on closed ones. This bug shipped once. Do not
"simplify" that loop.

---

## Architecture — as built

> **This describes the code that exists, not a plan.** An earlier version of
> this file specified a different architecture and the build diverged from it;
> `docs/ARCHITECTURE.md` records each divergence with its reason. Do not
> silently "fix" code toward the old spec.

- **10 autoloads, in this order**: `Prefs Tex Sfx Subs Game Flock Unlocks Juice
  Mission Music`. Order matters — several resolve each other in `_ready()`.
- **Substances are `Resource` files** in `data/substances/`, loaded at boot by
  `Subs`. Adding one is a `.tres`, never a code change.
  > **The rule: a substance must never be only a number that goes up.** Every
  > one needs a *control mutation* — something that changes how the player's
  > hands work. If it only edits `speed_mult`, delete it.
- `Subs.mods` is a **flat aggregated Dictionary** rebuilt every frame. The goose
  controller never asks "am I on berries?", only "what is my input lag right
  now?". That indirection is why the substance count went 3 → 16 without the
  controller changing.
- **Post-processing is one uber-shader** (`shaders/screen_fx.gdshader`), one
  branch per substance family, driven by uniform writes. Not N shaders.
- **`Engine.time_scale` has exactly two owners**: `Subs` (substance slow-motion,
  the baseline) and `Juice` (hitstop, a multiplier, `process_priority = 100` so
  it writes last). They have a documented contract. Do not add a third.
- **The goose has two interchangeable visuals** (`goose_visual.gd` smooth,
  `goose_visual_lowpoly.gd` faceted) with an identical public API, chosen by the
  `goose_model` pref. Cats and humans follow the same switch.
- **All assets are procedural.** 23 textures and 16 substance icons from
  `tools/gen_textures.py`; 39 SFX and 7 zone ambience beds from
  `tools/gen_audio.py`; 22 music stems from `tools/gen_music.py`. No imported art
  or audio anywhere. `tools/selftest.gd` fails the build if a substance has no
  icon, or if any audio or texture key in the code has no file behind it.

---

## Scope discipline

- **If a task would touch more than 3 files, stop and propose a plan first**,
  unless the human has explicitly asked for a large sprint.
- Prefer duplication over premature abstraction.
- Do not refactor, rename or "improve" code you were not asked to change.
- **Never weaken an assertion, delete a check, or lower a tolerance to make
  something pass.**
- Search for an existing implementation before writing a new one. This project
  has repeatedly grown a second copy of something that already existed —
  `pickup_models.gd` and `zone_cottage.gd` both built a toad.
- **The controller has to feel good before anything else matters.**

## Taste is the human's. Everything measurable is yours.

**Do not end a session by asking the human to go and play it.** The instruction
that used to live here said to stop and hand feel back. It was followed exactly,
and it is what stalled this project: `docs/HANDOFF.md` §3 said **"Play it"** at
the top of the list for two sessions running, nothing behind it could move, and
the queue became a queue of one. The human plays this game when they want to.
They are not a subroutine you block on.

"Feel" is two things wearing one word, and only one of them is deferrable.

**RESPONSE — yours.** How long the bird takes to reach top speed, how far it
slides after you let go, whether a held flap converges on a climb rate or
compounds into orbit, how many frames pass between eating and the world
changing. This is arithmetic. It is what makes a controller feel *broken* rather
than merely unfunny, and it is measurable headless:

```
godot --headless --path . -- --probe --feeltest     # step 4 of verify.ps1
```

`tools/feeltest.gd` measures 22 of them, 13 asserted against windows;
`docs/FEEL_TARGETS.md` carries the argument for every window, so they can be
argued with rather than merely obeyed. **Measure it, decide it, change it,
record the before and the after.** A tuning change backed by a measurement and a
written reason is work, not a guess — and it is one revert away if the human
disagrees.

**TASTE — the human's, permanently.** Whether a waddling goose is funny. Whether
the honk lands. Whether the strip mall is a good first zone. Whether the ending
earns itself. Whether any of it is *fun*. No file in this repo will ever have an
opinion about those.

**But deferring taste does not mean stopping.** When a decision genuinely needs
taste:

1. **Make the call.** Pick the option you would defend, and say plainly that you
   picked it and why.
2. **Write it down** in `docs/HANDOFF.md` §3 — one line, what you chose and what
   the alternative was — so it can be overruled in one revert.
3. **Keep going.** Do not park the rest of the session behind it.

### The one rule that did not change

**Never fabricate a judgement about how something feels.** You cannot play this
game. *"That feels much snappier now"* is a lie. *"Time to top speed is 0.20 s
against a 0.10–0.40 window, and the held flap now converges at 0.99x where it
used to compound at 3.22x"* is not. Report what you measured, or say that you
decided without measuring and why. Never claim you felt it.
