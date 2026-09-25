# Controls onboarding — research, build, and integration

Drop-in files (all new, nothing in `GeekedGeese/` was modified):

```
scripts/ui/briefing.gd        modal briefing card + animated diagrams
scripts/ui/briefing_defs.gd   all the copy, as static data
scripts/ui/control_card.gd    always-available two-scheme controls reference
```

Godot 4.7.1, tabs, parse-clean, rendered and eyeballed at 1280×720 and 1920×1080,
and test-integrated into a throwaway copy of the real project.

---

## 1. What the research said

| Source | What I took from it |
|---|---|
| [GDevelop — Why Game Tutorials Fail](https://gdevelop.io/blog/improve-game-tutorials) | People read ~20–28% of the words you put in front of them, and less in a game. Cognitive overload is the #1 failure: multiple instructions before the player can apply any of them. |
| [Roblox — Onboarding techniques](https://create.roblox.com/docs/production/game-design/onboarding-techniques) | "Players generally don't like to read instructions and skip through text prompts to get to gameplay." Teach incrementally; the more they have to learn at once, the likelier they quit. |
| [Game Developer — How to design a good tutorial for your indie game](https://www.gamedeveloper.com/business/gamedev-thoughts-how-to-design-a-good-tutorial-for-your-indie-game) | "Keep tutorials as short as possible, then shorter." Some games need no tutorial, just a **controls reference**. Always leave "a small reference somewhere" for the people who opt out. Unskippable = immediate player loss. |
| [NN/g — Mobile Tutorials: Wasted Effort or Efficiency Boost?](https://www.nngroup.com/articles/mobile-tutorials/) | Skippers scored **94%** task success vs **91%** for people who sat through the tutorial — statistically nothing. Never punish the skipper; put the effort into the UI instead. |
| [NN/g — Instructional Overlays and Coach Marks](https://www.nngroup.com/articles/mobile-instructional-overlay/) | Overlays get dismissed reflexively. If you use one, it must be *one screen*, and the thing it teaches must be needed *immediately after* it closes. |
| [PC Gamer — How developers build the tutorials you skip](https://www.pcgamer.com/how-developers-build-the-tutorials-you-skip/) | Zach Barth (Zachtronics): "textual explanations, which are always disappointingly ineffective." Kevin Zuhn (Octodad): "We have UI pop-ups to tell players the control input. The rest we teach through the level's design." Luca Redwood: "Some people will read your text, but most won't." |
| [Nerdy Teachers — Onboarding methods](https://nerdyteachers.com/PICO-8/Game_Design/106) | Instruction/control screens are legitimate — they're the standard answer for a small, intuitive game — and they belong on loading screens, pause menus, and options menus, not welded to the front of the game. |

### The seven rules I actually built to

1. **Never gate the fun.** Every card closes on Enter, Space, Escape, gamepad A, gamepad B,
   or a clicked button. A player who doesn't care is back in the game in under two seconds.
2. **Teach at the moment of use, not before it.** The flight card appears *in the air*, one
   frame before the flight starts, with the frozen flock visible behind it. Nothing is
   explained on a menu screen ten minutes earlier.
3. **One screen, no scrolling, no pagination.** Every card fits at 720p.
4. **Cut rows before you shrink type.** Four or five rows per card. `Q share`, `J/K camera`
   and `R restart` are deliberately *not* on the zone card — they're in the pause reference.
5. **Draw the keys.** Every glyph is a rendered key-cap (rounded rect, fat bottom border,
   drop shadow). A monospace list of `SPACE — flap` is the exact artefact research says
   people's eyes slide off.
6. **Picture the one hard rule.** Lead rotation gets an animated schematic. Everything else
   gets one line.
7. **Assume they skipped everything.** Hence the auto-dismissing recap on every later leg,
   and the permanent pause-menu reference. Those are the safety net, and they're the reason
   the up-front cards are allowed to be this short.

### On the mid-game control-scheme switch specifically

There is no clean prior art for "the whole scheme changes 90 seconds in" because most games
avoid the problem: they either keep one verb set, or they hand you the new one in a scripted,
consequence-free stretch (Octodad's approach — a UI pop-up for the input, level design for
everything else). Geeked Geese can't do that; the migration is scored from second one and
lasts 60–90 seconds, so there's no safe runway to learn in.

So the design here is the honest compromise: a **just-in-time card at the transition, not at
launch**, with the flight already loaded and frozen behind it, plus a **permanent reference**
for the safety net. That's the "hybrid" the indie-tutorial literature recommends — a short
optional-feeling briefing next to minimal reference material, letting the player self-select
their depth.

---

## 2. The cards, and why they're that short

### `zone_first_run` — once, ever
```
THE LOT
you are a Canada goose. this is your parking lot.
Nobody here is going to stop you. They have tried.

  W A S D   waddle
  SPACE     flap — get a run-up first, you are not a sparrow
  H         honk
  E         hold to eat whatever is on the ground
  Q         share it with the flock

  ONE THING
  When the clock runs out you fly the flock to the next leg —
  in exactly the condition you left them in.

  Gamepad: left stick move · A flap · B honk · X eat · Y share
  [ENTER · SPACE · ESC]                             ( HONK )
```
**Five rows because the zone has exactly five verbs that matter.** Camera, restart and skip
are omitted on purpose — they aren't needed to be successful in the first thirty seconds,
which is the bar the research sets ("players just want to know enough to be successful").
The callout does one job: it plants the flock-condition cause-and-effect *before* the player
starts feeding a substance to six geese, so the migration lands as a consequence rather than
a surprise.

### `flight_first_run` — once, ever, at the transition
```
MIGRATION
different bird. different controls.
Two thousand kilometres. One V. Nobody up here is sober but the sky doesn't care.

  W A S D   steer inside the corridor          [ animated V diagram ]
  SPACE     climb
  SHIFT     drop
  Q         hand off the point
  H         honk a drifter back into line

  LEAD ROTATION
  The goose at the point gets no draft and burns out, while everyone behind it
  gets their breath back. Q hands the point to someone else — but only to a goose
  sober and rested enough to take it. Party too hard in the lot and nobody can
  relieve you.
```
The subtitle is the single most load-bearing line in the whole feature: **"different bird.
different controls."** That's the sentence that stops a player from spending twenty seconds
wondering why their goose won't waddle.

The callout is the longest text anywhere in the build (three sentences) and it's earned —
it's the only thing that explains why the best mechanic in the game exists. It's also
directly reinforced by the diagram sitting next to it, so a player who reads nothing still
gets the rule from the picture.

### `flight_recap` — every migration after the first, auto-closes in 4s
```
MIGRATION
flight controls, in case you forgot

  W A S D   steer
  SPACE     climb
  SHIFT     drop
  Q         hand off the point before you burn out
                                                   ( YEAH YEAH )
  ▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬▬                      ← countdown
```
**Yes, it should auto-dismiss, and it does — 4 seconds.** A modal you've already read is
pure friction, and a modal you have to dismiss *every single leg* becomes an obstacle course
by leg five. Auto-dismiss turns it from a gate into a reminder. Any input still kills it
instantly, and the depleting rule along the bottom edge tells you it's temporary so you
don't reach for the keyboard. Four rows: `H` is dropped because rallying is optional and
the pause reference has it.

### `dose_hint` — contextual, once, honours the "Show hints" setting
```
THE SWEET SPOT
everything here has a dose. most of it has a bad one.

  E   hold to charge — let go to commit
                 [ animated arc, needle sweeping into the green ]
  READ THE ARC
  Green is the dose. Red is an overdose. Let go too early and you have
  eaten a cigarette butt for nothing.
```
The diagram is a **miniature of the HUD's own `DosePanel`** — same arc, same angles, same
colours. Teaching with a picture of the actual widget the player is about to look at is
strictly better than teaching with an abstraction of it. This is the only card gated behind
Settings → *Show hints*, because it's a hint rather than a control scheme; if the player
turned hints off, it's marked seen and never shown.

### `control_card.gd` — the pause-menu reference
Both schemes side by side, `ON FOOT` / `IN THE AIR`, eight and seven rows, one screen, no
scrolling, plus the lead-rotation rule in a footer box and one compact gamepad line. Content
comes from the same `briefing_defs.gd` arrays, so the reference and the briefings can never
drift apart.

---

## 3. The V-formation diagram, and whether it reads

Six geese seen from above, flying up the screen, apex at the point. Everything is a pure
function of a 6.7-second loop phase, so it never drifts and never needs resetting.

```
t 0.00 – 3.40   HOLD    lead is gold with a halo; its stamina bar drains red 0.90 → 0.20
                        while the five drafting birds sit on full green bars.
                        Dashed cyan "draft chain" lines crawl backwards down the V.
t 3.40 – 4.10   CUE     the [Q] cap in the corner flares and pulses, "hand off" brightens,
                        and the ghost of the handoff path fades in as an orange arc.
t 4.10 – 5.35   SWAP    the point banks out to the left along that arc and drops into the
                        near-left slot; the goose that was there slides up the inside line
                        to take the point. Gold crossfades between them at 40–75% of the move.
t 5.35 – 6.70   SETTLE  new point starts burning; the old point, now drafting, visibly
                        recovers from a nearly-empty red bar.
```

**Does it read?** Yes, and I have the render iterations to prove where it didn't:

- **Round 1** — geese drawn at scale 1.0 rendered as ~20px specks. The whole thing read as a
  dotted line with green dashes, not a formation. The stamina bars were *wider than the
  birds*. Fixed by a `GOOSE = 1.5` glyph scale (the single most important number in the
  diagram — it's commented as such) and shrinking the bars from 26×4 to 20×3.
- **Round 2** — the peeling goose was rotated ~90° mid-arc because the heading was sampled
  raw from the motion vector. At 30px it read as a dead bird falling, not a bird banking out
  of the point. Fixed by clamping heading to ±0.62 rad; geese bank, they don't pirouette.
  Also: a still frame of the swap looked like a rendering bug, so the ghost arc was added and
  boosted to α 0.55 — the *route* is now visible even in a screenshot.
- **Round 3** — the lone `[Q]` cap in the corner read as a stray UI element while idle, so
  its "hand off" caption is now always drawn, just dim (α 0.26 → 0.88 when it fires). The
  side diagram was top-aligned against a taller key column and looked like a mistake; it's
  now vertically centred in the band.

The mechanic-carrying detail is the **stamina bars**: one short red bar at the point and five
long green ones behind it, with the red one visibly emptying, is the entire rule stated
without a word. The handoff then swaps which bar is red. That's the bit that makes the
callout text redundant for anyone who watches for four seconds.

---

## 4. Verification

**Parse:** all three files pass `--check-only` under Godot 4.7.1 with zero output. No
`var x := <Variant>` anywhere — every Dictionary/Array read is explicitly annotated.

> **Corrected 2026-08-04.** `--check-only --script <file>` parses one file **in
> isolation**, so it cannot see autoloads: it reports
> `Compile Error: Identifier not found: Prefs` as a false failure on most of this
> project, and it does not check the project as a whole. "Zero output" from it is
> weaker evidence than it sounds. The project-wide gate is
> `godot --headless --path . -- --gate` (`tools/gate.gd`), which compiles every
> script inside the booted project where the singletons are registered. Re-run
> that, not `--check-only`. The second sentence above — no `var x := <Variant>` —
> is the claim that actually matters here and it still holds for these files.

**Render:** eight cards rendered per pass through an Xvfb + OpenGL3 probe, read back as PNGs
and inspected, at **1280×720 and 1920×1080**, across three iterations. The project uses
`stretch/mode="canvas_items"` so 1080p is a clean 1.5× upscale of the same layout — I
confirmed that rather than assuming it. Cards are positioned by explicit maths against
`get_viewport().get_visible_rect()` and re-laid-out on `size_changed`, with a
`minf(1.0, …)` downscale safety net so a small viewport shrinks the card instead of
clipping it.

Layout uses a single `_walk(do_draw: bool)` function that both measures and paints, so the
measured height and the drawn content can't disagree.

**Behaviour:** 23 assertions, run as two consecutive game sessions:

```
PASS  nothing seen yet                    PASS  gg_flap dismissed
PASS  show_once showed                    PASS  auto_dismiss fired
PASS  tree paused while up                PASS  auto unpaused
PASS  mouse released                      PASS  dismissed signal emitted
PASS  is_open true                        PASS  control card paused
PASS  lockout survived instant key        PASS  control card closed
PASS  ui_accept dismissed                 PASS  control card unpaused
PASS  tree unpaused                       — session 2 —
PASS  mouse handed back                   PASS  zone_first_run persisted across sessions
PASS  marked seen                         PASS  flight_first_run persisted across sessions
PASS  show_once refuses second time       PASS  unseen key still unseen
PASS  ui_cancel dismissed                 PASS  survives a foreign settings save
```

**Integration, against a copy of the real project:**

```
[probe] wrote int_zone                      ← card over the live zone, HUD dimmed behind
[probe] wrote int_flight  briefing_open=true
[probe] migration ticked while card up: 0.0     ← distance travelled: zero
[probe] migration ticked after dismiss: 124.1
[probe] zone clock drift during card: 179.35 / 180
[probe] card open=true paused=true              ← pause-menu → CONTROLS handoff
```

The migration advances **0.0 km** while the card is up and 124 km in the same number of
frames afterwards. The zone clock loses 0.65s across the whole boot, not the length of the
briefing.

> Pre-existing quirk, not caused by this work: the `--ui` probe's synthetic
> `InputEventAction("ui_cancel")` does not open the pause menu under Xvfb. I verified this on
> an **unmodified** checkout of `GeekedGeese` before touching anything. Real key events are
> unaffected; the briefing's own dismissal was verified with the same mechanism and works.

---

## 5. Integration

> **⚠ ALREADY DONE — do not apply this section again.** Verified 2026-08-04:
> `prefs.gd:23` has `"seen_briefings": []` in `DEFAULTS`; `main.gd` has
> `const BRIEF_DEFS`, builds `briefing` on layer 25 and `control_card` on layer
> 41, and drives both from `_show_zone_briefing()` / `_show_flight_briefing()`;
> `pause_menu.gd:334` has the CONTROLS button emitting `controls_requested`.
> This section is now a record of how it was wired, not a task.

### 5.1 Prefs (recommended one-liner)

`briefing.gd` persists a `seen_briefings` array through `Prefs`. Add it to `DEFAULTS` in
`scripts/core/prefs.gd`:

```gdscript
	"best_chaos": 0,
	"unlocked": [],
	"seen_briefings": [],   # <-- add
```

**This is optional.** `Prefs.load_prefs()` only restores keys listed in `DEFAULTS`, and
`save_prefs()` writes only what's in `_values` — so without the line, the key would round-trip
to disk once and then be silently dropped by the next settings save. `briefing.gd` already
defends against exactly that: on `_ready` it reads `user://geeked_geese.cfg` directly and
pushes the value back into `Prefs`, which re-registers it. Both paths are covered by the
"survives a foreign settings save" test above. Add the line anyway — it's cleaner.

**New Prefs keys introduced: `seen_briefings` (Array of String).** Nothing else.
Existing keys read: `show_hints` (for `dose_hint` only).

### 5.2 `scripts/core/main.gd`

**a) Header — add the defs const and two node refs:**

```gdscript
const BRIEF_DEFS := preload("res://scripts/ui/briefing_defs.gd")

var briefing: CanvasLayer = null
var control_card: CanvasLayer = null
var current: Node = null            # existing
```

**b) `_ready()` — capture the mouse BEFORE `new_run()`:**

```gdscript
func _ready() -> void:
	randomize()
	_build_overlays()
	Game.phase_changed.connect(_on_phase)
	Game.chaos_scored.connect(_on_chaos_scored)
	# BEFORE new_run(): the zone briefing opens inside new_run() and records the
	# mouse mode it has to hand back. Capturing after would steal the cursor
	# out from under the card.
	_capture_mouse(true)
	Game.new_run()
	_probe_if_headless()
```

**c) End of `_build_overlays()` — append. Order matters:**

```gdscript
	control_card = preload("res://scripts/ui/control_card.gd").new()
	control_card.name = "ControlCard"
	add_child(control_card)
	if pause_menu.has_signal("controls_requested"):
		pause_menu.controls_requested.connect(func():
			if pause_menu.has_method("hide_for_overlay"):
				pause_menu.hide_for_overlay()
			_set_hud_visible(false)
			control_card.open())
	control_card.closed.connect(func():
		# Guard: only hand the screen back if the pause menu actually owns it.
		if pause_menu.is_open() and pause_menu.has_method("show_after_overlay"):
			pause_menu.show_after_overlay())

	# LAST. Godot delivers _input() in reverse tree order, so the briefing has to
	# be added after the pause menu or Escape opens the menu behind the card.
	briefing = preload("res://scripts/ui/briefing.gd").new()
	briefing.name = "Briefing"
	add_child(briefing)
```

**d) `_load_zone()` — one line, immediately before the `var title := …` block** (i.e. after
the zone, HUD, hallucinations and objectives are built, so the lot is visible behind the card):

```gdscript
	await _brief_zone()

	var title := "LEG %d" % Flock.leg
```

**e) `_load_migration()` — one line at the end:**

```gdscript
	add_child(mig)
	current = mig
	await _brief_flight()
```

**f) The two helpers (new, put them next to `_load_migration`):**

```gdscript
## The zone clock lives on an autoload with PROCESS_MODE_ALWAYS, so it keeps
## draining through get_tree().paused. Hold it while a card is up or the
## briefing literally costs the player time.
func _brief_zone() -> void:
	if briefing == null:
		return
	var was_running: bool = Game.zone_running
	Game.zone_running = false
	if briefing.show_once(&"zone_first_run", BRIEF_DEFS.zone_first_run()):
		await briefing.dismissed
	Game.zone_running = was_running
	_capture_mouse(_mouse_was_captured)


func _brief_flight() -> void:
	if briefing == null:
		return
	if briefing.show_once(&"flight_first_run", BRIEF_DEFS.flight_first_run()):
		await briefing.dismissed
	else:
		briefing.show_now(BRIEF_DEFS.flight_recap())
		await briefing.dismissed
	_capture_mouse(_mouse_was_captured)
```

`_load_zone()` and `_load_migration()` become coroutines. That's fine — they're only ever
called from the `phase_changed` signal, and Godot is happy to await a signal handler.

**g) `_menus_open()` — prepend two checks** so the HUD hides and the director doesn't fight
the mouse while a card is up:

```gdscript
func _menus_open() -> bool:
	if briefing and is_instance_valid(briefing) and briefing.is_open():
		return true
	if control_card and is_instance_valid(control_card) and control_card.is_open():
		return true
	if pause_menu and is_instance_valid(pause_menu) and pause_menu.has_method("is_open"):
		...
```

**h) `_probe_if_headless()` — add one line at the top of the `--ui` branch,** or the probe's
synthetic Escape hits the zone briefing instead of the pause menu:

```gdscript
	if args.has("--ui"):
		briefing.force_close()
```

### 5.3 `scripts/ui/pause_menu.gd` — six lines, to add the CONTROLS button

```gdscript
signal almanac_requested()
signal controls_requested()      # <-- add
```

and in `_build_main_panel()`, above the ALMANAC button:

```gdscript
	vb.add_child(_menu_button("CONTROLS", func(): controls_requested.emit(), Color(0.6, 0.85, 0.8)))
	vb.add_child(_menu_button("ALMANAC", func(): almanac_requested.emit(), Color(0.55, 0.75, 0.95)))
```

Optionally also delete the nine-row `CONTROLS` dictionary and its loop at the bottom of
`_build_main_panel()` — the reference card replaces it and the pause menu gets ~120px shorter.
If you'd rather not touch `pause_menu.gd` at all, bind it from `main.gd` instead:

```gdscript
	if e.is_action_pressed("gg_controls") and not _menus_open():
		control_card.open()
```

### 5.4 `dose_hint` (optional, contextual)

Fire it the first time a pickup registers itself as an eat target. In
`scripts/world/substance_pickup.gd`, right after `body.set_eat_target(self)` (line ~104):

```gdscript
		var m := get_node_or_null("/root/Main")   # or however you reach the director
		if m and m.briefing:
			m.briefing.show_once(&"dose_hint", m.BRIEF_DEFS.dose_hint())
```

No `await` needed — it's fire-and-forget, the tree pauses, and the pickup is still there when
the card closes. It respects Settings → *Show hints* on its own.

### 5.5 API surface

```gdscript
signal dismissed

show_once(key: StringName, data: Dictionary) -> bool   # true = it's up, await dismissed
show_now(data: Dictionary) -> void                     # always shows, never records
is_open() -> bool
force_close() -> void                                  # emits dismissed, unblocks any await
has_seen(key: StringName) -> bool
reset_seen(key: StringName = &"") -> void              # dev / "replay the intro"
```

`control_card.gd`: `open()`, `close()`, `is_open()`, `signal closed()` — same contract as the
Almanac, so the pause menu's existing handoff pattern works unchanged.

### 5.6 Layers

| Node | layer |
|---|---|
| HUD | 2 |
| Almanac (as constructed in main) | 20 |
| **Briefing** | **25** |
| Pause menu (self-assigned in `_ready`) | 30 |
| Almanac (self-assigned in `_ready`) | 40 |
| **Control card** | **41** |

The briefing sits above the HUD and below the pause menu; it wins Escape by tree order, not
by layer, so it can never be buried. The control card sits above everything because it is
always opened *from* something else.

### 5.7 Two things worth knowing

- **The briefing owns `get_tree().paused` and re-asserts it every frame while open.** If
  anything else in the project unpauses mid-card, the phase behind it would start ticking
  unwatched; this is one boolean compare per frame to make that impossible.
- **There's a 0.22s input lockout** when a card opens. Without it, a player holding Space
  when the zone clock expires would never see the flight card at all — it would open and
  close in the same frame. Mouse events are deliberately *not* swallowed during the lockout,
  because marking them handled would make the dismiss button unclickable.
