extends Node
## Autoload: Game
##
## Run state, scoring, and the input map.
##
## NOTE ON INPUT: actions are registered here in code rather than baked into
## project.godot. That's deliberate — it's version-proof and readable in a diff.
## If you'd rather edit them in Project Settings > Input Map, copy them in there
## and delete _setup_input(); nothing else depends on it.

signal chaos_scored(amount: int, total: int, combo: int, label: String)
signal phase_changed(phase: int)

enum Phase { ZONE, MIGRATION, RESULTS }

const ACTIONS := {
	"gg_forward": [KEY_W, KEY_UP],
	"gg_back": [KEY_S, KEY_DOWN],
	"gg_left": [KEY_A, KEY_LEFT],
	"gg_right": [KEY_D, KEY_RIGHT],
	"gg_flap": [KEY_SPACE],
	"gg_dive": [KEY_SHIFT],
	"gg_honk": [KEY_H, KEY_F],
	"gg_eat": [KEY_E],
	"gg_share": [KEY_Q],
	"gg_restart": [KEY_R],
	"gg_skip": [KEY_ENTER, KEY_KP_ENTER],
	"gg_cam_left": [KEY_J],
	"gg_cam_right": [KEY_K],
	# Pad only — the right stick's vertical. The keyboard looks up and down
	# with the mouse; see the right-stick block in _setup_input().
	"gg_cam_up": [],
	"gg_cam_down": [],
}

var phase: int = Phase.ZONE
var chaos: int = 0
var leg_chaos: int = 0
var combo: int = 0
var combo_timer: float = 0.0
var zone_time_left: float = 180.0
var zone_running := false


func _ready() -> void:
	_setup_input()
	process_mode = Node.PROCESS_MODE_ALWAYS


func _setup_input() -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for code in ACTIONS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = code
			InputMap.action_add_event(action, ev)

	# Gamepad: left stick move, A flap, B honk, X eat, RB dive.
	_pad("gg_flap", JOY_BUTTON_A)
	_pad("gg_honk", JOY_BUTTON_B)
	_pad("gg_eat", JOY_BUTTON_X)
	_pad("gg_dive", JOY_BUTTON_RIGHT_SHOULDER)
	_pad("gg_share", JOY_BUTTON_Y)
	_axis("gg_left", JOY_AXIS_LEFT_X, -1.0)
	_axis("gg_right", JOY_AXIS_LEFT_X, 1.0)
	_axis("gg_forward", JOY_AXIS_LEFT_Y, -1.0)
	_axis("gg_back", JOY_AXIS_LEFT_Y, 1.0)

	# MENUS AND CARDS, ON A PAD — which had none. Godot 4.7.1 binds `ui_cancel`
	# to Escape ALONE and `ui_accept` to Enter / Keypad Enter / Space alone
	# (printed from the engine on 2026-09-25, not remembered), and `gg_skip`
	# above had no pad button. So a pad player could not pause, could not close
	# the roster or the control card, and met a wall at the end of flight 1: the
	# flight's own card waits on `gg_skip` with no timeout. D-055.
	#
	# Start pauses, which is the convention. A confirms — it is also what a
	# focused menu Button answers to, through `ui_accept`. B deliberately stays
	# the honk and is NOT a back button: `pause_menu.gd` opens and closes on the
	# same action, so B on `ui_cancel` would pause the game on every honk.
	# `tools/inputtest.gd::_gamepad_walk()` drives all of it with pad events.
	_pad("ui_cancel", JOY_BUTTON_START)
	_pad("ui_accept", JOY_BUTTON_A)
	_pad("gg_skip", JOY_BUTTON_A)

	# THE CAMERA, ON A PAD — which had none. The README's gamepad scheme gave the
	# right stick nothing, so a pad player could not look around at all: J / K
	# and the mouse were the only ways to turn the view. The right stick drives
	# the same actions J and K do (`goose_camera.gd` reads their strength, so the
	# stick is analog for free) plus a vertical pair the keyboard never needed.
	# D-077. `tools/inputtest.gd` pushes the stick through `parse_input_event`.
	_axis("gg_cam_left", JOY_AXIS_RIGHT_X, -1.0)
	_axis("gg_cam_right", JOY_AXIS_RIGHT_X, 1.0)
	_axis("gg_cam_up", JOY_AXIS_RIGHT_Y, -1.0)
	_axis("gg_cam_down", JOY_AXIS_RIGHT_Y, 1.0)


func _pad(action: String, button: int) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _axis(action: String, axis: int, dir: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = dir
	InputMap.action_add_event(action, ev)


func _process(delta: float) -> void:
	var real := delta / maxf(Engine.time_scale, 0.05)
	if combo_timer > 0.0:
		combo_timer -= real
		if combo_timer <= 0.0:
			combo = 0
	# THE LEG CLOCK STOPS WHEN THE GAME DOES. It did not, and this node is
	# `PROCESS_MODE_ALWAYS`, so `_process` kept running behind every menu: ninety
	# seconds in Settings cost ninety seconds of a 240 s leg, and the Almanac —
	# which the game actively encourages you to read — was the most expensive
	# thing in it.
	#
	# The second-order failure is worse than the lost time. If the menu is still
	# open when the clock runs out, `set_phase(MIGRATION)` fires from behind it:
	# `main._on_phase` loads the migration and opens the results card at layer 28,
	# UNDER the pause menu at 30, where `results_screen._input` swallows the
	# dismissing keypress with `set_input_as_handled()` and `_dismiss()` then
	# writes `get_tree().paused = false` unconditionally — so the leg teardown and
	# the flight briefing run underneath a pause menu that still thinks it is open.
	#
	# `main.gd::_brief_zone()` already documents this exact mechanism and holds
	# the clock by hand for the briefings only. This is the general case.
	#
	# The combo timer above is deliberately left alone: it is a two-second window
	# on a scoring flourish, and freezing it would let a player park a combo in a
	# menu indefinitely.
	if zone_running and not get_tree().paused:
		zone_time_left = maxf(0.0, zone_time_left - real)
		if zone_time_left <= 0.0:
			zone_running = false
			set_phase(Phase.MIGRATION)


func set_phase(p: int) -> void:
	phase = p
	phase_changed.emit(p)


func start_zone(seconds: float = 180.0) -> void:
	zone_time_left = seconds
	zone_running = true
	leg_chaos = 0
	Subs.reset_for_new_leg()
	# Next to the substance reset, and for the same reason: a hitstop or a pop
	# must not survive a scene swap. A pop that outlives its node holds a stale
	# reference; a hitstop that outlives the leg strands Engine.time_scale.
	Juice.reset()
	set_phase(Phase.ZONE)


## Award chaos.
##
## [param at] is optional and is the cheapest possible way to get world-anchored
## score popups across the entire game: every existing call site keeps working
## untouched, and any site that happens to know where the thing happened opts in
## by passing one extra argument.
func score(base: int, label: String = "", at := Vector3.INF) -> void:
	combo += 1
	combo_timer = 3.0
	var mult: float = Subs.mods.get("chaos_mult", 1.0) * (1.0 + 0.12 * float(combo - 1))
	var amount := int(round(float(base) * mult))
	chaos += amount
	leg_chaos += amount
	chaos_scored.emit(amount, chaos, combo, label)

	if at.is_finite():
		# The colour ramp is doing real work: the number runs from yellow to hot
		# orange as the combo climbs, which is a free readout of combo state
		# that occludes nothing and costs nothing.
		var warm := Color(1.0, 0.88, 0.40).lerp(Color(1.0, 0.45, 0.25),
			clampf(float(combo - 1) / 8.0, 0.0, 1.0))
		Juice.floating_text(at + Vector3.UP * 0.8, "+%d" % amount, warm)

	_combo_milestone(at)


## TIER 2. A long chain should build, but combos tick over constantly, so the
## escalation is deliberately quantised: nothing at all for four scores in a
## row, then one beat on every fifth. That way the feedback marks a threshold
## the player crossed instead of smearing across every hit — and it stays out of
## the way of the prop break happening in the same frame.
##
## No hitstop here under any circumstances. A combo milestone is reachable
## several times a minute by a competent player, which puts it far outside the
## five sites allowed to freeze the frame.
func _combo_milestone(at: Vector3) -> void:
	if combo < 5 or combo % 5 != 0:
		return
	var step := float(combo) / 5.0
	Juice.shake(clampf(0.10 + 0.03 * step, 0.10, 0.30))
	if not at.is_finite():
		return
	var hot := Color(1.0, 0.72, 0.30).lerp(Color(1.0, 0.34, 0.30),
		clampf((step - 1.0) / 3.0, 0.0, 1.0))
	# Higher than the "+N" from the same frame so the two read as a stack
	# rather than a collision.
	Juice.floating_text(at + Vector3.UP * 1.9, "x%d CHAIN" % combo, hot)
	Juice.burst(at + Vector3.UP * 0.9, hot, 8 + mini(combo, 12), &"sparkle")


## Start a fresh run at leg 1.
##
## [param seconds] is leg 1's clock. It is a parameter rather than the 180 s
## default because THE ROUTE decides how long a leg is, and leg 1 — the tutorial
## pond, which `main.gd::ROUTE` gives 240 s precisely because it is the one leg
## where the player does not yet know what any of the buttons do — was the one
## leg that never went through `_on_migration_done()` and so never read the
## route at all. It quietly ran 60 s short for the whole life of the project.
## That is the clock lie a third time; see docs/CLOCK_AND_CAMERA_NOTES.md.
func new_run(seconds: float = 180.0) -> void:
	chaos = 0
	leg_chaos = 0
	combo = 0
	Flock.leg = 1
	Flock.new_flock(6)
	Subs.tolerance.clear()
	start_zone(seconds)
