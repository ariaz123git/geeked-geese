# GEEKED GEESE — MULTIPLAYER SPECIFICATION

### Two geese, one bloodstream

*Build-ready. The developer asked for "singleplayer and multiplayer, competitive
or collaborative or both, idk." This document answers the idk. It engages with
`GEEKED_GEESE_DESIGN.md` §9's "Multiplayer: don't" rather than overruling it —
that line was right about the thing it was talking about, and this spec keeps
it, narrowed. Where I disagree with an existing document I say so once and move
on.*

---

## 0. THE VERDICT, FIRST

> **Online multiplayer for the zone is a bad idea for this project and should
> not be attempted. Local split-screen multiplayer is not just possible, it is
> cheap — cheaper than any other feature of comparable size in the backlog —
> and the migration flight can be four-player co-op in under a week because it
> contains no physics at all.**

The design bible's warning is correct and should stay in the document, with one
word added:

> ~~Multiplayer: don't.~~ **Online** multiplayer: don't. Not in v1, not in v2.
> Physics-comedy netcode will eat the entire project. Local multiplayer is a
> different question with a different answer.

| | |
|---|---|
| **What ships** | Local split-screen. 2 players first, 2–4 by the end. |
| **First mode** | **THE LOT** — one zone, two geese, three minutes, competitive Chaos. |
| **Second mode** | **THE V** — 2–4 player co-op migration flight. Cheapest real multiplayer in the project. |
| **The structural idea** | **You compete on the ground and you cooperate in the air.** A round is a zone (versus) followed by a flight (co-op) whose result multiplies both players' scores. |
| **The MVP trick** | **SHARED BLOODSTREAM.** There is exactly one `Subs` and one `Engine.time_scale`. Don't fight it — ship it as a feature. Whatever one of you eats, you both get. Zero refactor, and it is funnier than the alternative. |
| **PvP dosing** | **Yes**, through the existing `[Q] SHARE` verb only, with five hard guardrails (§5). It is the best idea in the game and it needs exactly one of those guardrails to not be the worst. |
| **Online** | Never in v1. If people ask, the answer is **Steam Remote Play Together**, which costs zero code. |
| **Campaign co-op** | Post-launch, local, 2 players only, and only after the singleplayer attrition curve is verified. Not in scope for v1. |
| **Cost to first playable** | **A weekend.** Cost to a shippable mode: **~2 weeks.** Cost to everything recommended here: **~5 weeks**, and none of it blocks the campaign. |
| **Most urgent refactor** | Per-device input routing + a `by:` parameter on `Game.score()`. One day. Both improve singleplayer. Everything else waits. |

---

# PART 1 — THE TECHNICAL ASSESSMENT

## 1.1 What Godot 4 actually gives you

Godot's high-level multiplayer is `MultiplayerAPI` plus two configuration
nodes: `MultiplayerSpawner`, which controls "where nodes can be remotely
instantiated by which peer," and `MultiplayerSynchronizer`, which controls
"which node properties can be synchronized by which peer"
([Godot Engine, *Multiplayer in Godot 4.0: Scene Replication*](https://godotengine.org/article/multiplayer-in-godot-4-0-scene-replication/)).
Authority is per-node, defaults to the server, and is reassigned with
`set_multiplayer_authority()`. Transport is `ENetMultiplayerPeer` (UDP,
reliable/unreliable channels, exposed statistics), `WebSocketMultiplayerPeer`,
or `WebRTCMultiplayerPeer` — the last of which "requires a signaling server"
and port forwarding for mesh topologies
([Godot Engine, *ENet wrappers, WebRTC*](https://godotengine.org/article/multiplayer-changes-godot-4-0-report-3/)).
For a Steam release, `SteamMultiplayerPeer` / GodotSteam wraps Steam's relay and
lobby system and removes the NAT problem entirely
([godotsteam/multiplayerpeer](https://codeberg.org/godotsteam/multiplayerpeer)).

That is a solid, honest replication layer. What it is **not** is a netcode
framework. It contains no client-side prediction, no server reconciliation, no
rollback, no lag compensation and no interest management beyond a manual
visibility filter. A practical 2026 survey of Godot multiplayer states the
boundary plainly: use it "if your game has small sessions (2-8 players), you're
shipping on Steam… and you can live without client-side prediction," and
"think twice if you need competitive netcode with prediction," noting stability
problems past roughly 40 concurrent users
([Ziva, *Godot 4 Multiplayer: Best Practices & Benchmarks*](https://ziva.sh/blogs/godot-multiplayer)).
The standard Godot recipe for remote entities is not prediction at all: "You
don't predict what other players will do. Instead, you buffer their past states
and smoothly interpolate between them," at a cost of roughly 100 ms of visual
delay
([StraySpark, *Multiplayer Networking in Godot 4*](https://www.strayspark.studio/blog/godot-4-multiplayer-networking-authoritative-server)).

**That recipe works fine for a shooter and fails completely for this game**,
because 100 ms of interpolation delay on a shopping cart you just hit is the
difference between a joke and a bug.

## 1.2 The crux: is Godot's physics deterministic? No.

This one question decides everything, so here is the chain of reasoning
explicitly.

**Deterministic lockstep** — send only inputs, run identical simulations —
is the only networking model that makes 40 rigid bodies free. It requires
determinism that is "exact down to the bit-level. So exact, you could take a
checksum of your entire physics state at the end of each frame and it would be
identical." And it does not survive heterogeneous machines: "even though the
simulation above is deterministic on the same machine, that does not
necessarily mean it would also be deterministic across different compilers, a
different OS or different machine architectures… Floating point determinism is
a complicated subject and there's no silver bullet"
([Gaffer On Games, *Deterministic Lockstep*](https://gafferongames.com/post/deterministic_lockstep/)).

Godot 4.6 made **Jolt the default 3D physics engine for new projects**
([AlternativeTo, *Godot 4.6*](https://alternativeto.net/news/2026/1/godot-4-6-debuts-modern-theme-jolt-physics-node-ids-and-libgodot-embed)),
and the Jolt integration's maintainer is direct about what that buys you: on
the same binary, "given the exact same input… you will see the same simulation
play out, down to the bit level," but cross-platform determinism **cannot be
guaranteed**, because different platforms mean different binaries, different
compiler flags and different floating-point operation ordering, so results
"gradually diverge." The stated conclusion is that determinism "should not be
relied upon if determinism is a hard requirement"
([godot-jolt discussion #548](https://github.com/godot-jolt/godot-jolt/discussions/548)).

> **Therefore: deterministic lockstep is off the table for Geeked Geese. Not
> hard — unavailable.**

That leaves **state synchronization**: run the sim on both sides, send input
*and* state, extrapolate between updates, prioritise which bodies get bandwidth.
It is the industry answer for rigid-body physics, and it comes with a warning
that is fatal to a comedy game: "State synchronization is an approximate and
lossy synchronization strategy… you'll spend a lot of time tracking down
sources of extrapolation divergence and pops"
([Gaffer On Games, *State Synchronization*](https://gafferongames.com/post/state_synchronization/)).

**"Pops" is the entire problem.** In an FPS a pop is a rendering artefact. In a
game whose one verb is *knock things over and watch what happens*, a pop is the
punchline landing in the wrong place on the other player's screen. The comedy in
this project is 100% carried by shared witness to a physical event. Networking
it approximately does not degrade it — it deletes it.

The cost anchor, for scale: Fall Guys is the closest shipped analogue —
lightweight physics characters, many of them, shared props. Mediatonic hired a
dedicated external multiplayer studio and spent **18 months** on it, and one of
the specific outcomes was that they "had to write a new ragdoll system as the
third-party one just didn't network properly and was killing the frame rate"
([The Multiplayer Group, *Fall Guys case study*](https://www.themultiplayergroup.com/case-studies/fall-guys)).
That is what "network the physics comedy" costs when specialists do it in an
engine with a mature netcode stack. One developer with AI assistance, in Godot,
on a 45-minute campaign that is not finished, does not have that budget and
should not pretend to.

## 1.3 The network-hostility inventory, named

Asked for plainly: which parts of this codebase are hostile to being networked.

| System | File | Verdict | Why |
|---|---|---|---|
| **`Engine.time_scale`** | `substance_manager.gd:151`, `juice.gd:323` | **Fatal, and unfixable — so make it a feature** | It is an *engine-global* scalar, written every frame by `Subs` and dipped by `Juice.hitstop()`. There is exactly one clock per process. You cannot have one player on nitrous and another not, in any architecture, local or online, without abandoning `Engine.time_scale` entirely. See §1.5. |
| **~40–80 `RigidBody3D` chaos props per zone** | `chaos_prop.gd`, `zone_*.gd` | **Fatal for online. Free locally.** | The strip mall spawns 42 props (14 carts, 6 corral, 8 chairs, 5 bins, 9 signs); suburbia and cottage are larger. Each break spawns **2 more `RigidBody3D`** with a 6-second life. Networking that is the state-synchronization problem above, at full difficulty. |
| **`Subs` — one global substance state** | `substance_manager.gd` | **Hostile, but tractable** | 87 references across the codebase. But the design bible's best decision saves it: *the controller never asks "am I on berries?", it asks `Subs.mods` what its input lag is right now.* That indirection means per-player substances is a **mechanical** change (inject a state object) rather than a rewrite. Everything except `time_scale` is already per-player-shaped. |
| **`Game.chaos` / `combo` / `leg_chaos`** | `game.gd:33–36` | **Hostile, trivial to fix** | One counter, one combo timer. Every score in the game funnels through one function, `Game.score()`. Adding a `by:` parameter is 2 hours *now* and a day-long grep *later*. |
| **`Flock` — one shared flock** | `flock_state.gd` | **Not hostile. Arguably the best thing here.** | A shared flock is a *co-op design*, not a problem. `player_bird_index` is local to `migration.gd`; promoting it to `Flock` and making it an array is ~1 hour. |
| **`Mission` — one objective set, bound to one goose** | `mission.gd:126` `bind_goose()` | **Mildly hostile** | It is a *passive observer* of `Game.chaos_scored` and three goose signals, which is exactly the right architecture. Only the `when` predicates (`airborne`, `in_water`, `size_min`) poll a single bound goose. Making those "any player" is a day. |
| **Global `Input` polling** | `goose_controller.gd` (6 sites), `goose_camera.gd`, `migration.gd:334` | **The one real blocker on local co-op, and it is half a day** | `Input.get_vector()` and `Input.is_action_pressed()` read the global singleton. Two geese would both obey every stick. See §1.4. |
| **`Juice` global shake bus + hitstop** | `juice.gd` | **Not hostile once time is shared** | Shake is a global bus read by whichever camera exists. Under the "time is shared" rule (§1.5), a shared screen shake is *consistent*, not a bug. |
| **Screen FX shader** | `hud.gd:75–79`, `shaders/screen_fx.gdshader` | **Already per-player-shaped** | The FX is a `ColorRect` on the HUD `CanvasLayer`, and `hud.goose` is already assigned per goose in `main.gd:181`. Move the HUD inside each `SubViewport` and each player gets their own post-process for free. |
| **`hallucinations.gd`** | spawns fake props into the world | **Shared, and that is funny** | Gravy's fake props are world objects, so in split-screen both players see them. Keep it. "Wayne is on Gravy and now *I* can't tell either" is a better joke than the singleplayer version. |
| **The migration flight** | `migration.gd` | **NOT HOSTILE AT ALL. This is the surprise.** | See §1.6. |

## 1.4 Local input in Godot 4 is a known sharp edge, and this project is unusually well placed for it

Godot's `Input` singleton is global and its Input Map is not device-scoped. The
open engine issue titled *"Input system shortcomings make Godot unusable for
4-player splitscreen on controller"* documents the specifics: you must
"duplicate each of those dozens [of actions] 4 times for each device,"
identical controllers report blank `GetJoyInfo()` dictionaries and identical
GUIDs, and disconnect events report the wrong device index
([godotengine/godot#100491](https://github.com/godotengine/godot/issues/100491)).
A parallel proposal asks for per-player `InputEvent` tracking and UI focus
([godot-proposals#10070](https://github.com/godotengine/godot-proposals/issues/10070)).

The solved-problem answer is `godot-multiplayer-input`, which "duplicates all of
your Action Maps and assigns them the correct device" behind the scenes and
exposes `MultiplayerInput.is_action_pressed(device, "action")` plus a
`DeviceInput` wrapper object, with device `-1` reserved for keyboard
([matjlars/godot-multiplayer-input](https://github.com/matjlars/godot-multiplayer-input)).

> **Geeked Geese is in an unusually good position here, by accident.** Input
> actions are registered *in code*, in `game.gd:46 _setup_input()`, over a
> `const ACTIONS` dictionary. The same loop that registers 13 actions can
> register `0_gg_flap`, `1_gg_flap`, `2_gg_flap`… in four more lines. The README
> apologises for this ("Input actions are also registered in code… rather than
> in Project Settings") and calls it a shortcut. **It isn't. It is the single
> thing that makes local multiplayer half a day instead of three days.** Do not
> move `ACTIONS` into Project Settings.

## 1.5 The `Engine.time_scale` decision, which is the most important call in this document

Four substances and every hitstop write a global, engine-wide clock:

- **Whippet** — 7 seconds of slow-motion
- **THE OVERCLOCK** combo — `time_scale: 0.45`
- **Percs** — everything is slow
- `Juice.hitstop()` — five sites, dipping `Engine.time_scale` and restoring it

`juice.gd` already carries a 30-line comment describing the careful contract it
negotiated with `Subs` so the two do not fight over the clock. That contract is
good engineering and it is also a warning sign: two systems have already grown
into this global, and every future system that touches time will bind to it too.

There are two options and only two.

**Option A — rip it out.** Re-author the four time substances as controller-space
effects: scale the goose's own velocity, input rate and animation instead of the
world's clock. Cost: 3–4 days, and it makes Whippet *worse*, because "the world
is slow" and "I am slow" are different jokes and only one of them is nitrous.
Hitstop becomes per-player, which is a genuine loss — a shared freeze-frame on a
shared prop break is most of what sells a shared prop break.

**Option B — declare that time is shared, and make it content.**

> ### THE RULE: **TIME IS SHARED. CONTACT HIGH.**
> `Engine.time_scale` stays global, forever, in every mode. When any player hits
> a whippet, **everyone** goes into slow motion. When any player faceplants,
> **everyone** feels the hitstop. This is not a limitation the game is working
> around; it is announced in the mode's name and it is the funniest thing in the
> lobby.

**Take Option B.** It costs zero engineering, it deletes the project's single
most network-hostile property from the risk register by reclassifying it as a
feature, and it is straightforwardly better comedy. It also composes correctly
with the code that already exists: `substance_manager.gd:186` aggregates
`time_scale` with `minf()`, so four players stacking four slow-mos cannot go
below the slowest single one. **The stacking guard is already written.**

The only thing to add is a floor: clamp the aggregated `time_scale` to `0.30`
in multiplayer so a lobby cannot chain whippets into a permanent bullet-time.
One line.

## 1.6 The genuinely surprising finding: the migration flight is not a physics sequence

`migration.gd` is 792 lines and contains **zero physics bodies**.

- It runs in `_process`, not `_physics_process`.
- The player is `var player_pos := Vector3(0, 18, 0)` — three floats,
  hand-integrated and clamped into a corridor (`migration.gd:341–343`).
- The other birds are plain `Node3D`s lerped toward slot positions with a
  sine-wave drift term.
- Obstacles are `Dictionary` entries tested with axis-aligned comparisons
  (`_check_obstacle`, line 645). Not `Area3D`. Not collision layers. `absf(p.x -
  o.x) < o.half and p.y > o.ymin`.
- Thermals are a distance check.
- The entire authoritative state of a flight is: `distance`, `integrity`,
  `lead_index`, and one `Vector3` + two floats per bird.

> **The migration is a rail sequence wearing a flight simulator's clothes.** It
> would network over a dial-up modem. It is also, structurally, already an
> asymmetric multiplayer design that happens to be played by one person — the
> design bible says so without noticing: *"the bird at the point of the V gets
> no drafting benefit and burns far more energy… so you have to hand the point
> off."* That is a co-op economy with the second player replaced by a
> `lead_candidates()` filter.
>
> **Making the flight multiplayer is the highest value-per-day work in this
> entire document, and it is the one part of the game nobody would guess was
> ready for it.**

## 1.7 What split-screen actually costs here, and why the answer is "less than you think"

The standard setup is one `SubViewportContainer` + `SubViewport` per player,
with the level as a child of the first and every other viewport's `world_3d`
pointed at it — the GDQuest demo's stated critical caveat: "You need to share
the first viewport's world with other viewports for every view to display the
same level"
([gdquest-demos/godot-4-split-screen-coop](https://github.com/gdquest-demos/godot-4-split-screen-coop)).

The cost objection to split-screen is usually "you render the scene twice on a
machine that was already struggling." Two facts make this project the exception:

1. **Total pixel count is unchanged.** Two 1280×360 viewports rasterise exactly
   as many fragments as one 1280×720. Four 640×360 quadrants, likewise. The
   render cost that doubles is *scene traversal and draw calls*, not fill.
2. **This scene is tiny.** ~42 `ChaosProp`s, ~9 NPCs, 7 cats, and a few hundred
   procedural boxes with `StandardMaterial3D`. There are no imported meshes, no
   skeletal animation, no baked lighting, one shadow-casting directional light,
   and the renderer is GL Compatibility with MSAA 2×. Doubling the draw calls on
   *this* is affordable on the integrated-graphics target the README already
   claims.

The real split-screen costs are elsewhere and they are design costs:

- **Mouse look only works for one player.** `Input.mouse_mode` is global and
  `goose_camera.gd` steers on `InputEventMouseMotion`. P1 gets mouse+keyboard;
  P2–P4 get gamepads and right-stick camera. This is the normal couch-co-op
  answer and nobody will complain, but it must be said out loud in the mode's
  setup screen.
- **`get_viewport().set_input_as_handled()`** in `goose_camera.gd:108` behaves
  per-`SubViewport`. Verify early; this is the classic split-screen gotcha.
- **The HUD moves inside the viewport.** `hud.gd` is a `CanvasLayer` — that
  works inside a `SubViewport`, and it takes the screen-FX `ColorRect` with it,
  which is exactly what you want.
- **Godot has no 3D physics interpolation** — the tracking issue for
  `physics_interpolation` having no effect on 3D nodes remained open through the
  4.x line ([godotengine/godot#89846](https://github.com/godotengine/godot/issues/89846)).
  At 60 physics ticks/second (this project's setting) that is invisible. Do not
  raise the render framerate expectation past that without checking.

## 1.8 The verdict, restated

| Question | Answer |
|---|---|
| Can the zone be networked online? | Technically yes, honestly no. State sync is the only available model, it is "approximate and lossy," and the thing it approximates away is the entire product. |
| Can the flight be networked online? | **Yes, easily.** It is a rail with no physics. If online ever happens, it starts here. |
| Can the zone be split-screen? | **Yes, and it is cheap**, because the scene is tiny and the input actions are already registered in code. |
| What is the single blocker? | Per-device input routing. Half a day. |
| What is the single thing that can never be per-player? | `Engine.time_scale`. So don't try — ship it as CONTACT HIGH. |
| What should be told to anyone asking for online? | **Steam Remote Play Together.** It streams a local-co-op session to remote friends' machines with their controller input piped back, costs zero code, and is exactly how Untitled Goose Game answers this question ([GamesRadar](https://www.gamesradar.com/untitled-goose-game-two-player-mode-split-screen-multiplayer/), [Steam Remote Play guide](https://www.steamnavigator.com/blog/steam-remote-play-together-guide)). |

---

# PART 2 — THE MODES

## 2.0 The structural idea that ties them together

> **You compete on the ground and you cooperate in the air.**

A multiplayer *round* is the singleplayer loop with the polarity flipped
halfway through:

```
   THE LOT           →         THE V           →     THE LOT (leg 2)  → …
   3 min, versus              90 s, co-op            3 min, versus
   separate Chaos             one flock              separate Chaos
   sabotage rewarded          sabotage fatal         …with a grudge
   ↓                          ↓
   your score                 × formation integrity  = your round score
```

Three minutes of ruining each other's afternoon, then ninety seconds where the
only way either of you scores well is to hold a V and hand off the point. Then
back to ruining it. That is the whole mode and it is drawn entirely from parts
that already exist.

The research says this is the right shape. Overcooked's teamwork comes from
"the kitchen layout often changes halfway into a level, forcing players to keep
talking to each other," and from a single shared outcome
([SuperJump, *Overcooked: How Design Creates Teamwork*](https://www.superjumpmagazine.com/overcooked-how-design-creates-teamwork/)).
The flight *is* that layout change: the verbs invert, the score becomes shared,
and the two players who were sniping at each other now have to negotiate a lead
handoff with a two-key handshake and no UI.

## 2.1 MODE ONE — **THE LOT** *(local split-screen, versus and co-op)* — **ships first**

| | |
|---|---|
| **Players** | 2 at MVP. 3–4 by v1.1. Split horizontally for 2, quadrants for 3–4. |
| **Session** | One zone, one clock (3:00 default, adjustable 1:30–5:00), one shared sandbox. Round ends on the buzzer. |
| **Default posture** | **Versus.** A co-op toggle in the lobby swaps the scoring, not the level. |
| **Substances** | **SHARED BLOODSTREAM at MVP** (one `Subs`, everyone gets what anyone eats). **Per-player** from v1.1, with `time_scale` still global. Both are modes, and shared bloodstream stays as a lobby option forever, because it is funnier. |
| **Zones** | Strip Mall at MVP. All three built zones by v1.1. It is a ~~`ZONE_ROTATION` index~~ **`ROUTE` index** — `ZONE_ROTATION` was replaced by a fixed 8-entry `ROUTE` array when the campaign landed (`main.gd`, and see `HANDOFF.md` §2); nothing else. |

**How the session looks.** Two geese spawn 20 m apart in the lot. Two chaos
counters top-left and top-right of their own half. One shared clock, centred,
across the split. There is one shopping-cart corral and both of you want it.
At 0:00 the higher score wins the leg, and both scores carry into the flight.

**How the objective system adapts.** `Mission` is a passive observer of
`Game.chaos_scored` and three `Goose` signals — that architecture survives
multiplayer nearly untouched.

| Posture | Objectives |
|---|---|
| **Versus** | The *same* objective list, and **it is a race.** Whoever completes an objective first claims it and takes the reward; it greys out on the other player's HUD with their name on it. `Mission` gains `_claimed_by: Dictionary[StringName, int]` and `evaluate_leg()` runs twice, once per scorer. No new objective content. |
| **Co-op** | One shared list, either player advances it, one shared payout. Literally today's `Mission`, with `bind_goose()` taking an array and the `when` predicates (`airborne`, `in_water`, `size_min`) resolving as **any player**. |

The claim-race version is the better one and it is nearly free: it turns a
checklist into a contested resource, which is exactly the failure mode
`DESIGN_MISSIONS.md` §1.2 warned checklists have.

**Scoring.** `Game.score(base, label, at, by := 0)`. `chaos`, `leg_chaos`,
`combo` and `combo_timer` become 4-element arrays indexed by `by`. The combo
multiplier stays per-player — chains are personal, which is what makes stealing
a cart corral hurt. `results_screen.gd` (1,323 lines, already excellent) renders
two columns instead of one; the grade table, rank lines and par all apply per
player unchanged.

**What has to be built.**

| Thing | Cost |
|---|---|
| Per-device input routing (`Game._setup_input()` grows a device loop; controller/camera/migration take a `DeviceInput`) | 0.5–1 day |
| `Game.score(by:)` + per-player counters | 0.5 day |
| Split-screen rig: `SubViewportContainer` × N, shared `world_3d`, HUD moved inside each viewport | 1.5 days |
| Spawning N geese in a zone; `zone.goose` becomes `zone.geese: Array` | 0.5 day |
| Lobby / device-join screen ("PRESS A TO JOIN"), 3 settings, mode toggle | 1 day |
| `Mission` claim-race + array binding | 1 day |
| Two-column results | 0.5 day |
| **Total** | **≈ 6 days for a shippable 2-player versus mode** |

## 2.2 MODE TWO — **THE V** *(local co-op migration, 2–4 players)* — **best value in the document**

| | |
|---|---|
| **Players** | 2–4 humans occupying slots in a 6-bird V. Remaining slots are `Flock` AI birds as today. |
| **Session** | 60–130 s, one shared camera, **no split-screen** — the camera already frames the whole formation. |
| **Screen** | One viewport. The migration builds its own `Camera3D` (`migration.gd:113`) and frames the V. Two players in one shot is what the sequence was designed for. |

**How the flight works with more than one player.** Four changes, all small:

1. `player_bird_index: int` → `player_bird_indices: Array[int]`, and
   `player_pos: Vector3` → `player_pos: Array[Vector3]`. `_tick_player()` loops.
2. **Lead rotation becomes a two-key handshake.** `[Q]` while leading no longer
   auto-picks "the freshest eligible bird" — it *offers* the point. A prompt
   appears over the nearest eligible human for 2.0 s; they accept with their own
   `[Q]`. If nobody accepts, you keep burning. That is Overcooked's forced
   communication with zero UI, and it replaces ~8 lines with ~20.
3. **Drafting becomes a social contract.** `DRAIN_LEAD 0.028` /
   `DRAIN_DRAFT -0.020` already means the leader pays and everyone else
   recovers. With humans in those slots the numbers stop being a simulation and
   start being a negotiation. **Do not retune them for multiplayer.** They are
   correct.
4. **Honk-rally targets other players.** `_rally()` currently un-drifts the
   worst AI drifter. Extend it: honking near a human who is out of slot gives
   them a snap-to-slot assist. The `CAMPAIGN_SPEC.md` §4.4 stamina-rescue honk
   (+0.06 stamina to a bird below 0.20) becomes **the co-op verb**: you honk
   your friend back to life. That is the flight's only act of care and it is
   four lines.

**Scoring.** The flight is scored **cooperatively and only cooperatively**:
final `integrity` and distance produce a single **FORMATION** multiplier
(0.75×–1.30×) applied to *every* player's zone chaos. Nobody can win the flight;
everybody can lose it. That is what makes the ground-versus/air-co-op structure
close.

**What has to be built.** Index-to-array plumbing, the handshake, the rally
extension, a roster strip showing every player's stamina (which
`CAMPAIGN_SPEC.md` §4.7 already requires for singleplayer and calls "the single
highest-value UI in the build plan"). **≈ 4 days**, and roughly half of it is
work the campaign needs anyway.

> **This is the cheapest genuinely good multiplayer in the project, it requires
> no split-screen, no per-player substances, and no physics networking of any
> kind. If only one multiplayer thing is ever built, and it must be defensible
> on cost, build this one.**

## 2.3 MODE THREE — **THE NIGHT OUT** *(the round loop)*

Three legs: LOT → V → LOT → V → LOT → V → results. ~15 minutes. Zones cycle
through the three built ones. This is `main.gd`'s existing phase machine with
a mode flag, and it is the thing you actually put on a store page as
"Multiplayer."

**Cost: ~2 days on top of modes one and two**, because it is the loop that
already exists. Do not build a separate director; add `Game.mode` and branch
`_load_zone()` / `_load_migration()`.

**Note what this deliberately is not.** It is not the campaign. It has no
attrition, no named-goose deaths, no ending, no Ascension. It is Free Honk with
a scoreboard, which the design bible already predicted falls out for free (§1:
*"Building the zones this way means 'Free Honk' mode falls out for free"*). It
must not import the campaign's stakes, because the campaign's stakes are about
one player's relationship with six named birds and that does not divide by two.

## 2.4 MODE FOUR — **THE DAILY LOT** *(async competitive, no netcode at all)*

The multiplayer feel with zero networking. Phantom Abyss chose asynchronous
ghosts for exactly this reason: "Being asynchronous initially came from the
restriction of our team size… we were looking for ways to keep the scope
manageable," and the developer's follow-on is the relevant part — "restrictions
turn into blessings"
([Unreal Engine developer interview](https://www.unrealengine.com/en-US/developer-interviews/phantom-abyss-combines-battle-royal-asynchronous-multiplayer-and-procedural-generation)).

**Three tiers, in increasing cost:**

| Tier | What | Cost | Value |
|---|---|---|---|
| **Seeded daily** | One zone, one seed derived from the date, one 3-minute attempt, one score. Everyone in the world gets the same lot. | **0.5 day** — the only work is RNG discipline: every `randf_range` in the zone builders must draw from a seeded `RandomNumberGenerator` instead of the global one. | High. Also fixes a genuine singleplayer defect: today `main.gd:83 randomize()` means a zone is never reproducible, so **no bug is reproducible either**. |
| **Your own ghost** | A translucent goose replaying your best run on this seed. Record `position`, `rotation.y`, `state`, `size` at 20 Hz. 180 s × 20 Hz × ~20 bytes ≈ **72 KB per ghost**, before compression. | 2 days | High. A rival that costs nothing. |
| **Shared ghosts / leaderboard** | Any backend at all. | 3+ days plus an ongoing service, plus moderation, plus a cheating problem in a game with no server authority. | **Reject for v1.** `CAMPAIGN_SPEC.md` §7.2 already concluded that per-rung local bests are "the only leaderboard slice a backendless single-player game can honestly have." Agreed. |

**The honest caveat on ghosts.** In a physics sandbox a ghost is a liar — it
waddles through a cart that is no longer there. Do not try to replay prop state.
Replay the **goose and its score popups only**, and lean into it: the ghost is
*"how the run went, not what the lot looked like."* If it reads badly in
testing, cut the ghost and keep the seed; the seed is 80% of the value.

## 2.5 MODE FIVE — **THE DESIGNATED DRIVER** *(asymmetric, 2 players)* — **month two, and only if modes 1–3 landed**

This is the idea the brief correctly identified as available, and it is good.
It is also the most likely of everything here to be *not fun for player two*,
so it gets the most design and the latest slot.

The warning is specific: couch-co-op's classic failure is that "player two could
be anyone from your very skilled best friend to a younger sibling," and games
routinely hand them the door-unlocking droid instead of the Jedi
([*Justice for Player Two*](https://cjleo.com/blog/justice-for-player-two-balancing-couch-co-op-in-video-games/)).
**A DD with fewer verbs is a sidekick and will be resented within four minutes.**
So the DD does not get fewer verbs — it gets a *different economy*.

| | THE GOOSE (P1) | THE DD (P2) |
|---|---|---|
| **Can dose** | Yes, everything | **No, ever.** `Flock.set_dd()` already enforces refusal. |
| **Signature verb** | The dose arc | **CARRY.** The DD is the only bird in the game that can pick a prop or a pickup up and put it somewhere. Physically — a `PinJoint3D`-free "grab": zero the body's gravity, drive it to a hold point, release with an impulse. |
| **Second verb** | Honk | **HERD.** A held honk pushes props, cats, NPCs and P1 away in a cone. The catnip cat-artillery already ships; this is that, aimed. |
| **Third verb** | Share | **SOBER UP.** Standing on P1 for 1.5 s cancels one active substance instantly. Interrupts a bad trip. The only source of early exit for a `no_early_exit` substance in the entire game. |
| **Scores on** | CHAOS | **SETUP.** Points for props *delivered into position* that P1 then destroys, for cats placed, for a substance cancelled inside a comedown window, for keeping P1 out of the water. |
| **How the scores meet** | `ROUND = CHAOS × (1 + SETUP/SETUP_PAR)` | Same number. One score, two authors. |
| **In the flight** | Whatever slot | **The bird you can always hand the point to.** The DD's intox is 0, so `can_lead()` is always true and (per `CAMPAIGN_SPEC.md` §4.6) it cannot exhaust. |

The five asymmetric-design patterns — asymmetry of number, asymmetry of power,
hidden information, evolving strategy, and manipulation of the time element
([Game Developer, *Asymmetrical Gameplay*](https://www.gamedeveloper.com/design/asymmetrical-gameplay-as-a-new-trend-in-multiplayer-games-and-five-design-patterns-to-make-engaging-asymmetrical-games))
— this mode uses two of them cleanly (power, time) and deliberately skips hidden
information, because a comedy game where the players cannot see what each other
is doing is not a comedy game.

**Cost: ~2 weeks**, dominated by CARRY, which is a new physics interaction and
therefore the one thing in this document that could genuinely eat a month.
Prototype CARRY in singleplayer first, on a two-day timebox. If a goose holding
a shopping cart does not immediately look funny, the mode is dead and you have
spent two days.

## 2.6 MODE SIX — **CO-OP CAMPAIGN** — **post-launch, and here is the case against**

Two players fly the 8-leg Flyway together, sharing one flock.

**Why it is tempting:** the flock is already shared data; the DD becomes a
negotiation between two humans; `dose_flock(0.32)` becomes an argument; the
ending's "which geese arrived with you" becomes a thing two people did to each
other. That is genuinely a better ending than the singleplayer one.

**Why it does not ship in v1, in order of weight:**

1. **The campaign's balance is unverified.** `CAMPAIGN_SPEC.md` §4.9 specifies a
   headless harness to prove that careful/typical/reckless archetypes land on
   5–6 / 4 / 1–2 survivors, and that harness does not exist yet. Adding a second
   player doubles the input to a curve nobody has measured once.
2. **Leg 8 does not divide by two.** The ending is one player, one honk, forty
   geese answering, and their survivors settling one at a time with their names
   floating up. A second goose standing there is not a small change to that
   scene — and the DD-stands-next-to-you beat, which `CAMPAIGN_SPEC.md` calls
   "the best thing the DD mechanic will ever do," collides directly with a
   second human.
3. **The campaign is the priority and multiplayer must not compromise it.** That
   is a constraint from the brief and this is where it bites hardest.
4. `zone_time_modifier`, `required_primaries()` and `rest()` are all tuned
   against one player's throughput. Two geese in a lot roughly double the chaos
   rate, which makes every par in the game wrong.

**If it is ever built:** local only, 2 players only, shared flock, shared
objectives (never a race), sharing between players disabled by default (§5), and
`PAR_BASE` multiplied by ~1.7 rather than 2.0 — two players interfere with each
other, so throughput is sublinear.

## 2.7 Rejected outright

| Idea | Verdict | Why |
|---|---|---|
| **Online zone multiplayer** | **No.** | §1.2. Deterministic lockstep unavailable, state sync "approximate and lossy," and the lossy part is the comedy. |
| **Online co-op campaign** | **No.** | All of the above, plus §2.6. |
| **Dedicated servers / matchmaking** | **No.** | An ongoing operational cost with no revenue model for a single developer. |
| **Global online leaderboards** | **No for v1.** | No server authority means no anti-cheat means the board is fiction within a week. |
| **4-player brawler / arena PvP with combat** | **No.** | The goose cannot fight — `BOSS_DESIGN.md` §1.1 spends a whole section on this and is right. Chaos scores are the competition. Do not add a damage model. |
| **Shared-camera 2-player (Untitled Goose Game's model)** | **No, with regret.** | It is the cheapest option and it is wrong *here*. UGG's goose is grounded in a compact garden. This goose flies to 30 m, rides a trampoline onto a roof, and pulses between 0.35× and 2.8× body scale. A camera that must frame a goose on a roof and a goose under a dumpster frames neither. |

---

# PART 3 — RECOMMENDATION AND ORDERING

## 3.1 The order, and why

```
NOW      ──▶  R1  per-device input routing            0.5–1 d   (improves SP)
              R2  Game.score(by:)                     0.25 d    (improves SP)
              R7  seeded zone RNG                     0.5 d     (improves SP: bugs become reproducible)
                        ↓
STEP 1   ──▶  THE V — co-op migration, 2–4 players    4 d       ← ships first
                        ↓
STEP 2   ──▶  THE LOT — split-screen versus, 2p       6 d       ← the MVP mode
                        ↓
STEP 3   ──▶  co-op toggle + 3–4 players              3 d
              THE NIGHT OUT round loop                2 d
                        ↓
STEP 4   ──▶  per-player Subs (R4)                    3–4 d
              PvP sharing + guardrails (§5)           2 d
                        ↓
LATER    ──▶  THE DAILY LOT (seed + ghost)            2.5 d
              THE DESIGNATED DRIVER                   10 d
NEVER v1 ──▶  online anything · co-op campaign
```

**Why THE V ships before THE LOT**, even though "co-op flying sequence" is a
worse store-page bullet than "split-screen versus":

- It is 4 days against 6, for a mode that is arguably better.
- It requires **no split-screen at all** — one camera, one viewport — so it
  proves per-device input routing without also proving the viewport rig. Two
  risks, taken one at a time.
- Roughly half its work (the roster strip, `Flock.player_index`, the honk
  rescue) is work `CAMPAIGN_SPEC.md` already requires for singleplayer. It is
  the only multiplayer item in this document that **pays for itself if
  multiplayer is cancelled the next day.**
- If it is not fun, you have learned something enormous for four days, and
  nothing downstream was built on it.

## 3.2 The minimum viable version, stated exactly

> ## **SHARED BLOODSTREAM**
> **Two geese. One strip mall. Three minutes. One bloodstream. Highest Chaos
> wins.**
>
> - 2 players, horizontal split-screen. P1 keyboard+mouse, P2 gamepad.
> - **One `Subs`.** Whatever either of you eats, you *both* get — including the
>   slow-motion, including the camera detaching, including the blackout. This is
>   not a compromise, it is the mode's name and its joke.
> - Two chaos counters, one clock, one buzzer.
> - No objectives, no flight, no results grade. A number, a bigger number, and a
>   winner.

**Why this is the right MVP and not a stunted one.** It requires exactly three
changes to shipping code — device-routed input, `Game.score(by:)`, and a
viewport rig — and *zero* changes to the substance system, the mission system,
the flock, `Engine.time_scale`, or a single line of physics. It is the version
of this feature that embraces the singleton it cannot afford to remove, and it
is genuinely funnier than the per-player version. Per-player substances is a
**v1.1 option in the lobby, not a prerequisite**, and shared bloodstream should
remain selectable forever.

**Build it in a weekend. Hand it to two people who have never seen it. If they
are not laughing in 90 seconds, the mode is wrong and you have lost a weekend** —
which is the same gate the README already sets for the whole game, applied to
the same budget.

---

# PART 4 — WHAT SINGLEPLAYER MUST CHANGE

The brief is right that `Game`, `Flock`, `Mission` and `Subs` are singleton
autoloads holding per-player state, and that this is exactly the thing that
makes multiplayer painful later. Here is what to do about each, ranked by
urgency, with an honest note on which are worth doing **even if multiplayer
never ships**.

## 4.1 The table

| # | Change | Where | Urgency | Cost | Worth it without multiplayer? |
|---|---|---|---|---|---|
| **R1** | **Route input through a device-scoped object.** Extend `Game._setup_input()` to register `"%d_%s" % [device, action]` variants; give `Goose`, `GooseCamera` and `Migration` a `device: int` and read through a `DeviceInput` helper instead of the `Input` singleton. | `game.gd:46`, `goose_controller.gd` (6 sites), `goose_camera.gd`, `migration.gd:334` | **THIS WEEK** | 0.5–1 d | **Yes.** It makes rebinding real, makes the controls card data-driven, and is a prerequisite for every input feature the game will ever want. |
| **R2** | **`Game.score(base, label, at, by := 0)`** and `chaos`/`leg_chaos`/`combo`/`combo_timer` become 4-element arrays. Every existing call site keeps working. | `game.gd:116` | **THIS WEEK** | 2 h | **Yes, in the cheap sense.** It costs 2 hours now and a full-codebase grep across ~40 call sites later. The `at := Vector3.INF` parameter already proves this pattern works here. |
| **R7** | **Seed the zone RNG.** Replace global `randf_range` in zone builders with a `RandomNumberGenerator` seeded from a run seed. Keep `randomize()` for the seed itself. | `main.gd:83`, `zone_*.gd` | **SOON** | 0.5 d | **Yes, and this is a real defect today.** Nothing in the game is reproducible, so no zone-layout bug can be reproduced. It also unlocks the daily seed for free. |
| **R5** | **Promote `player_bird_index` onto `Flock`** as `player_index`. `CAMPAIGN_SPEC.md` §6.2 already requires this so the "player's bird can never be lost" guarantee lives with the data. Make it `Array[int]` when THE V is built. | `migration.gd:34` → `flock_state.gd` | With the campaign work | 1 h | **Yes** — the campaign spec asks for it independently. |
| **R6** | **`Mission.bind_goose(g)` → `bind_geese(Array)`**, and the `when` predicates (`airborne`, `in_water`, `size_min/max`) resolve as *any bound goose*. Add `_claimed_by` for versus. | `mission.gd:126, 916–927` | Only when THE LOT ships | 1 d | No. Pure multiplayer tax. Don't pre-build it. |
| **R4** | **`Subs` becomes a registry + N states.** Extract the per-player half (`actives`, `tolerance`, `brain`, `mods`, `_comedowns`, `active_combo`, `blacked_out`) into a `SubsState` object; `Subs` keeps `library`, `COMBOS`, and P1's state so all 87 existing references still resolve. `Goose` gains `subs: SubsState`. **`time_scale` stays global**, aggregated with the existing `minf()`. | `substance_manager.gd` | Before per-player substances, **not before the MVP** | 3–4 d | No — but it is *low risk*, because `goose_controller.gd` already only ever asks a dictionary for values. The design bible's §11 boast ("that indirection is why the substance count could quadruple in an afternoon") turns out to also be why this refactor is mechanical. |
| **R3** | ~~Decouple `Engine.time_scale`~~ | — | **DELETED. Do not do this.** | — | §1.5. Time is shared, forever, in every mode. Add one clamp: `m.time_scale = maxf(m.time_scale, 0.30)` in multiplayer. |

## 4.2 The three rules to hold from today onward

These cost nothing now and are expensive to retrofit:

1. **Never add a second global that holds per-player state.** The four that
   exist are survivable. A fifth is not. When a new system needs per-player
   data, it hangs off the `Goose`, not off an autoload.
2. **Never read the `Input` singleton from gameplay code.** Once R1 lands,
   `Input.is_action_pressed` in a controller is a bug. Add it to the review
   checklist; it is one grep.
3. **Never write `Engine.time_scale` from anywhere except `Subs` and `Juice`.**
   Those two already have a documented contract (`juice.gd:37–60`). A third
   writer breaks both. This is now a *design rule*, not a temporary constraint.

## 4.3 What is explicitly NOT worth pre-building

Do not build a `PlayerState` container "for later." Do not add a `peer_id`
field to anything. Do not make `Flock` support multiple flocks. Do not add a
network abstraction layer over `Input`. **Every one of those is speculative
generality against a feature that may never ship, on a project whose actual
priority is a 45-minute campaign that is not finished.** R1, R2 and R7 are on
this list only because each of them improves singleplayer on its own merits.

---

# PART 5 — GRIEFING AND THE SUBSTANCES

## 5.1 The question and the answer

**Can players dose each other?**

> **Yes — through the `[Q] SHARE` verb that already exists, and never through
> anything else. It is the best idea in the game and exactly one guardrail
> stands between it and being the worst.**

The verb is already written. `goose_controller.gd:657`:

```gdscript
elif e.is_action_pressed("gg_share"):
    if not Subs.actives.is_empty():
        Flock.dose_flock(0.32)
        Game.score(75, "SHARED WITH THE FLOCK", global_position)
```

In multiplayer it becomes: dose every **other player within 8 m**, plus the
flock, with *your current actives* at 0.32 of your dose, and pay you 75 chaos.
That is the whole implementation.

## 5.2 The five guardrails

**G1 — You can only give what you are on.**
Sharing transmits your *current actives*. You cannot carry a substance in
reserve to weaponise, because taking it is what loads the gun. Every dose you
inflict, you took first. **This is the guardrail that makes PvP dosing a
comedy mechanic rather than a weapon, and it is already how the code works.**
Do not add an inventory. Do not add a throwable. The moment a player can hold
a dose without being on it, this whole section collapses.

**G2 — Area, not aim.**
Share is a honk-shaped 8 m sphere, not a projectile and not a target lock.
No aiming means no sniping means no single player getting hunted across a lot.

**G3 — A share can never be the third.**
`Subs.MAX_STACK = 2` and the third substance is a 3-second blackout with a
hitstop, a 1.10 shake and total loss of control — the largest punish in the
game. Without this rule, "wait for them to be on two, then share" is a
repeatable 3-second stun lock, and that is the exact "one player ruins it for
everyone" failure.

> **A share that would be a recipient's third active is refused.** The
> recipient shows `FULL`, the sharer gets 25 chaos and the label
> `"THEY'RE FULL"`, and nothing happens to them.
>
> **This is the single guardrail that makes the feature shippable. If only one
> line of this section is implemented, implement this one.**

You can still blackout yourself. Triples remain a thing you do to *you*, which
is the entire harm-reduction lesson the design bible built the mechanic for
(§4: *"Players will teach each other 'never triple,' which is the entire lesson
delivered by other players for free."*). **A blackout you did not choose teaches
nothing.**

**G4 — An unchosen dose writes nothing permanent.**
Two things in this game persist beyond the round: **tolerance** and **Almanac
unlocks**. Neither may be written by another player.

- A shared dose builds **no tolerance** on the recipient. Otherwise force-feeding
  a friend Darts — which gains tolerance 3× faster than anything else — is a
  permanent sabotage with a delayed, invisible payload. That is the worst
  possible version of this mechanic.
- A shared dose grants **no Almanac unlock**. `unlocks.gd` unlocks by encounter,
  and `WIN_CONDITIONS.md` §4.9 is emphatic that "you unlock the page by *eating
  the thing*." Being dosed by someone else is not eating the thing. Discovery is
  yours.

**G5 — Consent is a lobby setting with a default per mode.**
The co-op literature's answer to jerks is "self-selected risk — you can choose
who to trust; if they choose to grief you, that was your mistake"
([Game Developer, *5 problems with co-op game design*](https://www.gamedeveloper.com/design/5-problems-with-co-op-game-design-and-possible-solutions-)),
and the practical developer answer to griefing has always included the
friendly-fire toggle ([Digital Trends, *How developers deal with griefers*](https://www.digitaltrends.com/gaming/how-developers-deal-with-griefers/)).
Both are correct and both are one dropdown:

| Setting | Effect | Default in |
|---|---|---|
| **EVERYONE** | Share doses all players in radius, and the flock | THE LOT (versus), THE NIGHT OUT |
| **FLOCK ONLY** | Share doses only the AI flock — today's behaviour | THE LOT (co-op), co-op campaign if it ever ships |
| **OFF** | Share does nothing but score | accessibility fallback |

## 5.3 The counterplay, which is the best part and costs one flag

`CAMPAIGN_SPEC.md` §2.1 introduces **BREAD** for leg 1, and its control mutation
is *"you are full — for 20 seconds you physically cannot take a substance,"* at
a ×0.5 chaos multiplier.

> **In multiplayer, bread is the shield.** Eat bread and you cannot be dosed by
> anyone for 20 seconds — at the cost of half your scoring rate and your own
> access to the shelf.

That is a complete, legible, tradeable answer to a player who keeps sharing at
you: you can always stop it, and stopping it costs you the lead. It requires
**one flag on a consumable that another document already specified**, it makes
the game's designated joke item mechanically load-bearing, and it is a genuinely
true fact about bread and geese doing real work in a scoring system. It is the
best value line in this document.

## 5.4 The one thing to watch in playtest

The failure mode is not griefing. It is **share spam becoming the dominant
strategy** — 75 chaos per press, on a 3-second combo timer, is a button you can
mash. Today the cost is paid in the *flight* (`dose_flock` wrecks your flock's
stamina), which is a delayed cost a versus player may not care about.

**Fix, if it shows up:** a per-player share cooldown that scales with how
recently you shared (8 s, then 16 s, then 32 s within a leg), and the payout
decaying with it. One `var`, one `maxf`. Do not fix it before it appears.

---

# PART 6 — THE HONEST CUT LIST

## A weekend (2 days) — the thing that proves the whole idea

**SHARED BLOODSTREAM, two players, one lot.**

| | |
|---|---|
| Day 1 AM | R1 — device-routed input. Extend `Game._setup_input()`; give `Goose` and `GooseCamera` a `device`. |
| Day 1 PM | R2 — `Game.score(by:)` and per-player counters. Spawn a second goose in `zone_strip_mall`. |
| Day 2 AM | Split-screen rig: two `SubViewportContainer`s, shared `world_3d`, HUD moved inside each. |
| Day 2 PM | Two chaos labels, one shared clock, a buzzer, a winner line. Play it. |

**Not in the weekend build:** objectives, results grade, the flight, per-player
substances, a lobby, 3–4 players, PvP sharing, sound mix changes. Hard-code
everything. Two players, one keyboard and one pad, launch straight into the lot
with a command-line flag.

**The gate:** two people, 90 seconds, no explanation. Same gate as the README's.

## A week (5 days) — a mode you could show someone

Everything above, plus:

- **THE V** — co-op migration for 2 players. The array plumbing and the two-key
  lead handshake. *(This is the best 4 days in the document; if the weekend
  build went badly, do this instead and skip the split-screen entirely.)*
- A device-join screen ("PRESS A TO JOIN") and a 3-setting lobby.
- Two-column results reusing `results_screen.gd`.
- PvP sharing with **G3 only** (the no-third rule). Skip the other four
  guardrails for now; G3 is the one that prevents a bad session.

## A month (20 days) — the shippable multiplayer feature

Everything above, plus:

| Days | Thing |
|---|---|
| 3 | Co-op toggle for THE LOT; `Mission` array binding + claim-race |
| 2 | 3–4 players (quadrant split), all three built zones |
| 2 | THE NIGHT OUT — the 3-round loop with the formation multiplier |
| 4 | R4 — per-player `SubsState`, with `time_scale` still global |
| 2 | The remaining four sharing guardrails, bread-as-shield, the share cooldown valve |
| 1 | R7 — seeded RNG |
| 2 | THE DAILY LOT — seed + local best |
| 4 | Buffer, mixing, and the thing that goes wrong. Something always does. |

**Explicitly out of the month:** THE DESIGNATED DRIVER (another 10 days, and it
needs a CARRY prototype first), ghosts, co-op campaign, and anything online.

## What to cut first when it slips, in order

1. **3–4 players.** Two is the mode. Four is a lobby-management project wearing
   a gameplay hat, and `godotengine/godot#100491` documents exactly how much fun
   four controllers is in Godot right now.
2. **Per-player substances.** SHARED BLOODSTREAM is not the fallback, it is the
   headline. Ship only it if you must.
3. **The versus/co-op toggle.** Pick versus. It needs no new objective content.
4. **The daily seed.** But do R7 anyway; it is a singleplayer bug fix that
   happens to enable a feature.
5. **Split-screen itself.** THE V needs no split-screen and is the better mode
   per day spent. If the viewport rig fights you for more than two days, ship the
   flight as the multiplayer and say so plainly.

## What must never be cut

- **G3, the no-third-substance rule.** A stun-lock in a comedy game ends
  sessions.
- **G4, no permanent state from another player's dose.** Tolerance and the
  Almanac are the two things that survive a run, and they belong to the player
  who earned them.
- **The rule that multiplayer never blocks the campaign.** Nothing in this
  document touches `mission_defs.gd`, `ROUTE_DATA.md`, leg 8, or the attrition
  curve. If any multiplayer task starts pulling on those, stop the task.

---

## Appendix A — Sources

**Godot engine and networking**
- [Godot Engine — *Multiplayer in Godot 4.0: Scene Replication*](https://godotengine.org/article/multiplayer-in-godot-4-0-scene-replication/) — MultiplayerSpawner / MultiplayerSynchronizer / authority model
- [Godot Engine — *Multiplayer in Godot 4.0: ENet wrappers, WebRTC*](https://godotengine.org/article/multiplayer-changes-godot-4-0-report-3/) — transports, mesh topologies, signalling requirement
- [Ziva — *Godot 4 Multiplayer: Best Practices & Benchmarks (2026)*](https://ziva.sh/blogs/godot-multiplayer) — "think twice if you need competitive netcode with prediction"; ~40 CCU ceiling
- [StraySpark — *Multiplayer Networking in Godot 4: Building an Authoritative Server*](https://www.strayspark.studio/blog/godot-4-multiplayer-networking-authoritative-server) — buffer-and-interpolate over prediction; "never trust anything the client sends except input"
- [godotsteam/multiplayerpeer](https://codeberg.org/godotsteam/multiplayerpeer) and [expressobits/steam-multiplayer-peer](https://github.com/expressobits/steam-multiplayer-peer) — Steam relay/lobby transports, if online is ever revisited

**Determinism and networked physics**
- [godot-jolt discussion #548 — determinism in Godot Jolt](https://github.com/godot-jolt/godot-jolt/discussions/548) — bit-level determinism on the same binary; **no** cross-platform guarantee
- [AlternativeTo — *Godot 4.6 debuts … Jolt Physics*](https://alternativeto.net/news/2026/1/godot-4-6-debuts-modern-theme-jolt-physics-node-ids-and-libgodot-embed) — Jolt is the default 3D physics engine for new projects
- [Gaffer On Games — *Deterministic Lockstep*](https://gafferongames.com/post/deterministic_lockstep/) — "Floating point determinism is a complicated subject and there's no silver bullet"
- [Gaffer On Games — *State Synchronization*](https://gafferongames.com/post/state_synchronization/) — "approximate and lossy… you'll spend a lot of time tracking down sources of extrapolation divergence and pops"
- [The Multiplayer Group — *Fall Guys* case study](https://www.themultiplayergroup.com/case-studies/fall-guys) — 18 months, a specialist studio, and a bespoke ragdoll system because the third-party one "just didn't network properly"
- [godotengine/godot#89846 — physics interpolation is not implemented for 3D](https://github.com/godotengine/godot/issues/89846)

**Local multiplayer in Godot**
- [godotengine/godot#100491 — *Input system shortcomings make Godot unusable for 4-player splitscreen on controller*](https://github.com/godotengine/godot/issues/100491)
- [godot-proposals#10070 — track `InputEvent`s and UI focus per player](https://github.com/godotengine/godot-proposals/issues/10070)
- [matjlars/godot-multiplayer-input](https://github.com/matjlars/godot-multiplayer-input) — per-device action maps, `MultiplayerInput` / `DeviceInput`
- [gdquest-demos/godot-4-split-screen-coop](https://github.com/gdquest-demos/godot-4-split-screen-coop) — SubViewport rig, and the `world_3d` sharing requirement

**Multiplayer design**
- [GamesRadar — *Untitled Goose Game two-player mode*](https://www.gamesradar.com/untitled-goose-game-two-player-mode-split-screen-multiplayer/) — shared screen not split, local only, "intended to be a couch co-op experience"
- [Steam Remote Play Together guide](https://www.steamnavigator.com/blog/steam-remote-play-together-guide) — how a local-co-op game answers "is there online?"
- [SuperJump — *Overcooked: How Design Creates Teamwork*](https://www.superjumpmagazine.com/overcooked-how-design-creates-teamwork/) — shared outcome, interdependent layout, mid-level change forcing communication
- [Game Developer — *5 problems with co-op game design (and possible solutions)*](https://www.gamedeveloper.com/design/5-problems-with-co-op-game-design-and-possible-solutions-) — knowledge mismatch, skill mismatch, jerks, and "self-selected risk"
- [Game Developer — *Asymmetrical Gameplay as A New Trend … Five Design Patterns*](https://www.gamedeveloper.com/design/asymmetrical-gameplay-as-a-new-trend-in-multiplayer-games-and-five-design-patterns-to-make-engaging-asymmetrical-games)
- [*Justice for Player Two: Balancing Couch Co-op in Video Games*](https://cjleo.com/blog/justice-for-player-two-balancing-couch-co-op-in-video-games/) — player two as partner vs. sidekick
- [Digital Trends — *How developers deal with griefers*](https://www.digitaltrends.com/gaming/how-developers-deal-with-griefers/) — systemic answers, and the honest limit of them
- [Unreal Engine — *Phantom Abyss* developer interview](https://www.unrealengine.com/en-US/developer-interviews/phantom-abyss-combines-battle-royal-asynchronous-multiplayer-and-procedural-generation) — asynchronous ghosts chosen because of team size; "restrictions turn into blessings"

---

## Appendix B — Measurements taken from the repo

| Thing | Value | Source |
|---|---|---|
| `ChaosProp` (`RigidBody3D`) in the strip mall | **42** (14 + 6 carts, 8 chairs, 5 bins, 9 signs) | `zone_strip_mall.gd:528–551` |
| Extra `RigidBody3D` per prop break | **2**, 6-second lifetime | `chaos_prop.gd:195–214` |
| NPCs / cats in the strip mall | 9 / 7 | `zone_strip_mall.gd:557, 593` |
| Physics bodies in the migration | **0** | `migration.gd` — `_process`, hand-integrated `player_pos`, AABB obstacle tests |
| Sites polling the global `Input` singleton | **3 files** (`goose_controller.gd`, `goose_camera.gd`, `migration.gd`) + `results_screen.gd` | grep |
| Autoload references | `Subs` 87 · `Juice` 62 · `Flock` 47 · `Game` 40 · `Mission` 14 | grep |
| Writers of `Engine.time_scale` | **2** — `substance_manager.gd:151`, `juice.gd:309/323` (plus 3 reset sites) | grep |
| `time_scale` aggregation | `minf()` — already cannot stack below the slowest single substance | `substance_manager.gd:186` |
| Input actions registered | 13, **in code**, from a `const` dictionary | `game.gd:16–30, 46` |
| Physics tick rate | 60 Hz | `project.godot` |
| Renderer | GL Compatibility, MSAA 2× | `project.godot` |
| `hud.gd` per-goose binding | already exists — `hud.goose = zone.goose` | `main.gd:181` |
| Screen FX | a `ColorRect` + `ShaderMaterial` on the HUD `CanvasLayer` | `hud.gd:75–79` |

---

*The tagline still applies, and it scales: **honk responsibly** is much funnier
when there are two of you and only one of you is going to.*
