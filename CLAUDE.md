# Geeked Geese — project rules

3D physics-comedy game. **Godot 4.7.1**, GDScript, Windows 11.
You play a Canada goose. Design doc: `GEEKED_GEESE_DESIGN.md`.

> **Read order for a fresh session** — and when two disagree, the earlier wins:
> **(0)** the code and `.\verify.ps1`, the only things that cannot lie about what
> is built; **(1)** `docs/HANDOFF.md` for current state and the queue;
> **(2)** `docs/DECISIONS.md` for what is settled and what is still the human's
> call; **(3)** this file for the stable rules; **(4)** `docs/FEEL_TARGETS.md` and
> the specs for why a number is what it is. Full lifecycle, and the mistakes that
> cost real time here: `docs/SESSION_PROTOCOL.md`.
>
> **This file is deliberately below HANDOFF and DECISIONS.** It changes rarely,
> which is its value and its risk: **a constraint recorded as prose keeps
> applying after it stops being true.** That has blocked this project at least
> three times (`docs/DECISIONS.md`, "Why this file exists"), once through this
> very banner. If you are about to leave a reason in a comment, ask whether it can
> be an assertion instead — and if it cannot, date it and log it in DECISIONS.

**What to work on is in `docs/HANDOFF.md` §3, not here.** The campaign is built —
seven legs, seven flights, two bosses and an ending — and measured by the gates
below. What is *not* an agent's is taste: see *"Taste is the human's"* at the end,
and the `Open (human)` entries in DECISIONS. Design docs: route and ending in
`docs/CAMPAIGN_SPEC.md`, bosses in `docs/BOSS_DESIGN.md`, architecture in
`docs/ARCHITECTURE.md`. Multiplayer (`docs/MULTIPLAYER_SPEC.md`) is **not started,
and deliberately not next.**

---

## Verify before you claim anything

**NEVER state that something works, compiles, or is tested unless you ran a
command and pasted its real output.** "I've implemented and tested this" without
a command trace is a lie, and it is the single most expensive failure mode here.

Exit code 0 is NOT sufficient. **Treat any `SCRIPT ERROR:` on stderr as a
failure.** A property write on a native type (`slider.custom_step = …`) compiles
and raises only when it runs, so the compile gate is not the last word:

```
godot --headless --path . -- --gate 2>&1 | grep '^\[gate\]'    # check ${PIPESTATUS[0]}
```

`[gate] PASS — N scripts, M resources, 0 failures` with exit 0. **A compile gate
is not "verified":** an input-lag bug that made *eleven of the sixteen substances
unplayable* passed it, and the whole campaign run, and would have passed any
review that did not press a key. There are now 13 gates. One script runs them all, and is the last two:

```
.\verify.ps1                     # all of them; the docs' counts; YOUR SAVE untouched
godot --headless --path . -- --gate                # it compiles
godot --headless --path . -- --selftest            # it agrees with itself
godot --headless --path . -- --probe --inputtest   # the bird, the menus and the pad obey
godot --headless --path . -- --probe --feeltest    # the bird obeys WELL
godot --headless --path . -- --probe --substancetest  # all 17 substances bite
godot --headless --path . -- --probe --migtest     # the flight answers the stick
godot --headless --path . -- --probe --rolltest    # the credit roll actually travels
godot --headless --path . -- --probe --loop-test   # seven legs and the ending
godot --headless --path . -- --doctest             # the DOCS still tell the truth
godot --headless --path . -- --audiotest           # the WAVs are what they claim
godot --headless --path . -- --probe --geomtest    # the models are the size they claim
```

What each gate is the only thing able to see is `docs/HANDOFF.md` §1 and §6, and
each tool's own header. The rules that come with them:

- **Any number you write into a document gets a row in `docs/CLAIMS.md`, or gets
  deleted.** `--doctest` recomputes every one from the booted project.
- **Every assertion is a bug that already got through once.** When you fix
  something a gate could not see, add the assertion that would have — then break
  it on purpose and watch it fail. A check nobody has watched fail is worse than
  none: it launders a guess into a claim.
- **Drive the path, not the handler.** `Input.parse_input_event()`, not
  `Input.action_press()` (which never fires an `_input()`); `Button.pressed`, not
  the callback; the pref, not `.new()`. This repo's most repeated bug is a control
  wired to nothing that every gate called green.
- **Before writing another harness, read the header of `tools/probe_common.gd`.**
  Every measuring gate here spent its first runs accusing a healthy game.
- **Runs with arguments after `--` are hermetic** (`prefs.gd::hermetic`): they
  neither read nor write the player's save, and `verify.ps1` fails if one does.

**Never use `--headless --import | grep ERROR`** (it imports assets and never
compiles GDScript) **or `--check-only --script`** (parses outside the booted
project, so every autoload reference false-fails and typos pass). The argument
and the experiment are at the top of `tools/gate.gd`. The gate's 26 ×
`ERROR: Parameter "method" is null.` from `briefing.gd` is benign and attributed
there; it is why the command above filters to `^\[gate\]`.

**For anything visual, render it and look at it** (`docs/HANDOFF.md` §6). `_draw()`
code, UI layout and 3D models cannot be verified any other way, and the first
render is always wrong.

---

## The engine is newer than you are

Godot 4.7 shipped **18 June 2026**; 4.7.1 on 14 July 2026. Your training data
predates it. Before using any API you have not already used in this project,
check `docs/GODOT_4.7_RULES.md`; if it is not there, fetch
`https://docs.godotengine.org/en/4.7/`, or print it from `ClassDB`. **Do not
pattern-match an API from memory** — `Slider.custom_step` and pad buttons on
`ui_accept`/`ui_cancel` are both Godot 3, and both got into this repo.

**Instant-reject Godot 3 syntax:**
`yield()` · `KinematicBody*` · `Spatial` · `export var` · `onready var` ·
`connect("sig", self, "m")` · `move_and_slide(velocity)` with arguments ·
`.instance()` · `Pool*Array` · `Transform` · `Quat` · `OS.get_ticks_msec()` ·
`deg2rad`/`rad2deg` · `SCREEN_TEXTURE` in shaders · the `.shader` extension ·
`Tween` as a node · `ResourceSaver.save(path, res)` (args swapped in 4.x)

### When `--gate` prints nothing and never exits

**First, re-run without the `^\[gate\]` filter** — a parse error in `main.gd`
stops the scene loading, the gate never runs, and the filter throws away the
`Parse Error … main.gd:NNN` that says why. (`verify.ps1` kills a silent gate and
prints its last lines.) If it is genuinely silent, two causes are known: **a local
name reused inside one function** — never do that here — and **an escape sequence
GDScript does not define inside a string literal** (`"\*"`; write `"[*]"`). **The
last edit is the suspect**: `git stash push <file>` isolates it in one step.
`docs/SESSION_PROTOCOL.md` has both bisections.

### The single most common way this codebase breaks

```gdscript
var x := some_dictionary.key        # PARSE ERROR: cannot infer the type of x
var x: float = some_dictionary.key  # correct
```
**Anything out of a Dictionary, an Array element, an untyped Node property or
`.get()` is a Variant and CANNOT be inferred.** `Subs.mods`, `Subs.brain` and
`Flock.birds[i]` are Dictionaries. `if c is Foo:` does **not** narrow a Variant
loop variable either — annotate the property read.

Prefer `const X := preload("res://path.gd")` over `class_name` references: global
class registration only exists after an editor import pass, so it breaks in a
fresh checkout and in headless CI.

---

## Scenes and files

- **Prefer writing `.gd`.** This project is ~99% code-built node trees; that was
  deliberate (it always runs on first open, with no missing references) and it is
  **the wrong way to do level design.** Converting zones to `.tscn` is accepted
  debt — see HANDOFF.
- In a builder script, **every non-root node needs `.owner = root`** or it is
  silently dropped on save.
- **NEVER invent a `uid://` value.** Omit `uid=` from anything you author, and
  delete it from the header of any `.tscn`/`.tres` you copy.
- **NEVER hand-write `.import` files** (drop the asset in and run
  `godot --headless --path . --import`) and **NEVER write into `.godot/`**.
- `ExtResource("x")` / `SubResource("y")` ids: **duplicates are silent and bind
  the wrong resource.** Assert uniqueness before writing a file.
- `git mv` a `.gd` and its `.gd.uid` sidecar together, in the same commit.

## Paths and names

- **Forward slashes only.** `"res://scripts\new.gd"` parses as `res://scripts` +
  newline.
- **Never `sed -i` a file in this repo.** Much of the tree is CRLF and GNU sed
  rewrites it LF, so every line of the diff changes. Use the Edit tool, or Python
  on `'rb'`/`'wb'` bytes; `git diff --stat` showing the whole file changed means
  the line endings moved, not the code.
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
- Framerate-independent smoothing is `lerp(a, b, 1.0 - exp(-rate * delta))`
  (this codebase writes `1.0 - pow(k, delta)`). Never `lerp(a, b, 0.1)`. For a
  hard limit use `move_toward`; for angles `lerp_angle` / `rotate_toward`.
- **`-basis.z` is forward. `basis.z` is BACK**, whatever one sentence of the
  official "Using 3D transforms" page says. **Every model here is authored facing
  -Z**; one built facing +Z flew tail-first for three builds.
- Never accumulate rotation in Euler. Keep yaw/pitch as floats and rebuild.
- `is_on_floor()` **before** `move_and_slide()` returns last tick's state.
- `CollisionShape3D.disabled` must be set via `set_deferred`.
- `contact_monitor = true` does nothing until `max_contacts_reported > 0`.
- Never scale a physics body node — it resizes the collider. Scale the visual.
  (Macropsia deliberately scales the goose's collider *and* visual; that is the
  one intentional exception and it is commented as such.)
- **`process_mode` gates `_input()` and `_process()` alike.** A pausable node
  cannot react to a pause — the pause menu that could never open (D-050) and the
  director that could never see a menu (D-060) were both this.

**Mesh winding:** Godot's front faces are **CLOCKWISE**, the opposite of the
right-hand-rule normal a mesh routine naturally computes.
`scripts/goose/lowpoly_builder.gd::_emit()` reverses the vertex order and keeps
the normal on purpose; a mesh emitted in natural order is entirely back-facing.
This shipped once. Do not "simplify" that loop (`docs/GODOT_4.7_RULES.md` §5.2).

---

## Architecture — as built

**This describes the code that exists, not a plan**; `docs/ARCHITECTURE.md` has
every divergence from the old spec and its reason. Do not "fix" code toward it.

- **10 autoloads, in this order**: `Prefs Tex Sfx Subs Game Flock Unlocks Juice
  Mission Music`. Order matters — several resolve each other in `_ready()`.
- **Substances are `Resource` files** in `data/substances/`, loaded at boot by
  `Subs`. Adding one is a `.tres`, never a code change. **The rule: a substance
  must never be only a number that goes up.** Every one needs a *control
  mutation* — something that changes how the player's hands work.
- `Subs.mods` is a **flat aggregated Dictionary** rebuilt every frame: the goose
  never asks "am I on berries?", only "what is my input lag right now?".
- **Post-processing is one uber-shader** (`shaders/screen_fx.gdshader`), one
  branch per substance family, driven by uniform writes. Not N shaders.
- **`Engine.time_scale` has exactly two owners**: `Subs` (the baseline) and
  `Juice` (hitstop, a multiplier, `process_priority = 100`). Do not add a third.
- **The goose, cats and people each have two interchangeable visuals** (smooth
  and faceted) behind one API, chosen live by the `goose_model` pref.
- **All assets are procedural.** 23 textures and 17 substance icons from
  `tools/gen_textures.py`; 39 SFX and 7 zone ambience beds from
  `tools/gen_audio.py`; 22 music stems from `tools/gen_music.py`. No imported art
  or audio anywhere; `tools/selftest.gd` fails the build if any key the code asks
  for has no file behind it.

---

## Scope discipline

- **If a task would touch more than 3 files, stop and propose a plan first**,
  unless the human has explicitly asked for a large sprint.
- Prefer duplication over premature abstraction.
- Do not refactor, rename or "improve" code you were not asked to change.
- **Never weaken an assertion, delete a check, or lower a tolerance to make
  something pass.**
- Search for an existing implementation before writing a new one. This project
  has repeatedly grown a second copy of something that already existed — and a
  fix to one of two handlers for the same key is half a fix (D-057).
- **The controller has to feel good before anything else matters.**

## Taste is the human's. Everything measurable is yours.

**Do not end a session by asking the human to go and play it.** That instruction
used to live here, was followed exactly, and stalled the project for two sessions
(D-002). The human plays when they want to; they are not a subroutine you block on.

"Feel" is two things wearing one word. **RESPONSE is yours**: time to top speed,
slide after release, whether a held flap converges, frames between eating and the
world changing. It is arithmetic, measurable headless by `--feeltest`, and argued
window by window in `docs/FEEL_TARGETS.md`. **Measure it, decide it, change it,
record the before and the after** — one revert away if the human disagrees.
**TASTE is the human's, permanently**: whether a waddling goose is funny, whether
the honk lands, whether the ending earns itself, whether any of it is *fun*.

When a decision genuinely needs taste: **make the call** and say plainly why;
**write it down** (DECISIONS, and one line in HANDOFF §3) so it can be overruled
in one revert; **keep going.**

**Never fabricate a judgement about how something feels.** You cannot play this
game. *"That feels much snappier now"* is a lie. *"Time to top speed is 0.20 s
against a 0.10–0.40 window"* is not. Report what you measured, or say that you
decided without measuring and why. Never claim you felt it.
