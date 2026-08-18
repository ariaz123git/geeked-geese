# Kickoff prompts

Do these in order. Steps 1–2 are yours; step 3 is the first thing you paste into the other chat.

---

## Step 1 — you, in the Godot editor (5 minutes)

Do **not** let the agent scaffold the project from nothing. A hand-written `project.godot` silently gets
GodotPhysics instead of Jolt and the wrong stretch defaults, and nobody notices for a month.

1. Open Godot 4.7.1 → **New Project**
   - Path: `C:/Projects/Geeked_Geese`
   - Renderer: **Forward+**
   - Leave "Create folder" unchecked — the folder already exists with your design doc in it.
2. Editor opens. **Close it** once, so `project.godot` is written to disk.
3. In a terminal:

```powershell
cd C:\Projects\Geeked_Geese
git init
git add -A
git commit -m "godot 4.7.1 project + design doc + agent kit"
```

The kit files (`CLAUDE.md`, `verify.ps1`, `docs/`, `tools/`, `.gitignore`) should already be sitting in
that folder.

---

## Step 2 — you, one sanity check

```powershell
godot --version
```

Expect `4.7.1.stable.official.<hash>`. If that fails, PATH isn't set — fix it before continuing, because
every verification step depends on it.

---

## Step 3 — paste this into the other chat as your first message

> I'm building a 3D physics-comedy game in Godot 4.7.1 called Geeked Geese. The project is at
> `C:\Projects\Geeked_Geese`.
>
> **Before you write any code, read these four files in this order:**
>
> 1. `CLAUDE.md` — the project rules. These are not suggestions.
> 2. `GEEKED_GEESE_DESIGN.md` — the full design. **Only §9, the vertical slice, is in scope.**
> 3. `docs/ARCHITECTURE.md` — the decisions already made and why.
> 4. `docs/GODOT_4.7_RULES.md` — the API reference. Godot 4.7 shipped in June 2026 and is newer than your
>    training data. Skim it now; consult it before every unfamiliar API.
>
> Context you need about me: I've vibecoded before but I have never used Godot and I don't know GDScript.
> I cannot catch your mistakes by reading the code. That means the verification loop is doing the job my
> code review would normally do, so treat it as load-bearing, not ceremony.
>
> **Your first task is deliberately small.** Do not build the goose yet.
>
> Set up the project skeleton and prove the verification loop works end to end:
>
> 1. Apply the `project.godot` settings block from `docs/GODOT_4.7_RULES.md` §8 — physics engine, physics
>    interpolation, the velocity clamps, and the entire `[debug]` warnings block. Add the input actions the
>    slice needs: `move_left`, `move_right`, `move_forward`, `move_back`, `flap`, `honk`, `eat`.
> 2. Create the folder layout from `docs/ARCHITECTURE.md` §7.
> 3. Create a minimal `scenes/main.tscn` — just a `Node3D` root, a `Camera3D`, a `DirectionalLight3D`, and a
>    `StaticBody3D` ground plane. Build it with a headless builder script in `tools/`, not by hand-writing
>    `.tscn` text. Set `run/main_scene` to point at it.
> 4. Run `.\verify.ps1` and **paste the full output**.
> 5. Then deliberately break something — add a call to a method that doesn't exist on a typed node — and run
>    `.\verify.ps1` again to prove it fails. Paste that output too. Then revert the break.
>
> Do not proceed past step 5 until I've seen both outputs. When you're done, tell me what the next task
> should be and wait.

---

## Step 4 — the second task, once step 3 passes

> Build the goose controller. Nothing else — no substances, no flock, no honk.
>
> Per `docs/ARCHITECTURE.md` §1: one `CharacterBody3D` (`GgGoose`) that switches `motion_mode` between
> `MOTION_MODE_GROUNDED` for waddling and `MOTION_MODE_FLOATING` for flight, plus a manual follow camera in
> `_process` that reads `get_global_transform_interpolated()`.
>
> Files you may touch: `goose/goose.gd`, `goose/goose.tscn`, `goose/follow_camera.gd`, and
> `scenes/main.tscn` to place the goose. Nothing else.
>
> Exported tuning values I can change in the inspector without editing code: walk speed, fly speed, turn
> rate, gravity, flap impulse, camera distance/height/follow rate.
>
> Represent the goose as a capsule for now. No model, no animation.
>
> When it's done: run `.\verify.ps1`, paste the output, then tell me exactly what to press to fly it.

The design doc calls the controller 60% of the work. Expect to spend several sessions on it, and expect the
numbers to be wrong at first — that part is yours, not the agent's.

---

## Prompt patterns to reuse

**Scoping.** Bad: *"add drift to the goose."* Good:

> Add a lateral drift force to `goose/goose.gd`. It should push the goose perpendicular to its facing
> direction, strength exported as `drift_strength` (default 3.0), applied before `move_and_slide()`, and
> zero when `drift_strength` is 0. Do not modify the camera, the flap logic, or anything in `systems/`.
> Run `.\verify.ps1` and paste the output.

**Demanding evidence.** If the agent says it works and you didn't see a command trace:

> You said this works. Show me the command you ran and its actual output. If you didn't run one, say so.

**When it's stuck.** After two failed attempts at the same bug, don't try a third:

> Stop. Revert your last two changes. Explain what you think is happening and what you'd need to know to be
> sure — don't propose a fix yet.

Then start a fresh session with that explanation as your opening context. A clean session with a better
prompt beats a long session full of corrections, reliably.

**Learning as you go.** You will need to understand this eventually:

> Walk me through `goose/goose.gd` line by line as if I've never seen GDScript. I want to understand what
> `move_and_slide()` actually does to `velocity`, not just that it moves the goose.
