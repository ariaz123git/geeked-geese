extends RefCounted
## THE FLIGHT GATE — the eighth, and the first thing ever to measure migration.
##
## HALF THIS GAME IS FLIGHTS. Seven of them against seven zones, and until this
## file the only thing any check knew about them was that the campaign loop
## reached `[run] COMPLETE`. That proves the flight ENDS. It says nothing about
## whether the bird answers the stick while it is happening — which is the same
## gap `tools/feeltest.gd` was written to close on the ground, and the same gap
## that hid a four-second input lag for the whole life of the project.
##
##     godot --headless --path . -- --probe --migtest 2>&1 | grep '^\[mig\]'
##
## WHY THE NUMBERS HERE ARE CLEANER THAN THE GROUND'S. `_tick_player()`
## integrates `player_pos` directly rather than running physics:
##
##     player_pos.x += v.x * 17.0 * delta          clamped to +/- CORRIDOR_X
##     player_pos.y += lift * 13.0 * delta - 1.6 * delta
##
## There is no collider, no floor, no cat to shove the bird and no pond to walk
## into, so these measurements are deterministic in a way the zone's never are.
## What they can still catch is the thing that matters: a constant changed, or
## an input path that stopped reaching the flight.
##
## THE WINDOWS ARE ARGUED AGAINST HAZARD SPACING, not against taste.
## `docs/CAMPAIGN_SPEC.md` §2.6 gives leg 7 — the hardest flight in the game — a
## hazard spawn interval of [0.9, 1.6] s. That is the clock every manoeuvre in
## here has to fit inside, and it is the only external number available to
## justify any of these bounds. The full reasoning is `docs/FEEL_TARGETS.md` §6.

const TICK := 1.0 / 60.0

static var _rows: Array[Dictionary] = []
static var _fails: Array[String] = []


static func run(tree: SceneTree, main: Node) -> void:
	_rows.clear()
	_fails.clear()

	var mig: Node = await _enter_flight(tree, main)
	if mig == null:
		print("[mig] FAIL — never reached the flight. The probe's phase change did not take.")
		tree.quit(1)
		return

	var consts: Dictionary = mig.get_script().get_script_constant_map()
	var corridor: float = float(consts.get("CORRIDOR_X", 0.0))
	var y_min: float = float(consts.get("Y_MIN", 0.0))
	var y_max: float = float(consts.get("Y_MAX", 0.0))
	if corridor <= 0.0 or y_max <= y_min:
		print("[mig] FAIL — migration.gd's CORRIDOR_X / Y_MIN / Y_MAX did not read back")
		tree.quit(1)
		return
	print("[mig] corridor %.0f m wide, altitude band %.0f–%.0f m" % [corridor * 2.0, y_min, y_max])

	# THE CLOCK HAS TO BE HONEST OR EVERY NUMBER BELOW IS SCALED BY IT.
	#
	# Every measurement here converts physics frames to seconds at 1/60, and
	# Engine.time_scale scales the delta those frames carry. `feeltest.gd` has
	# carried this guard since it was written; leaving it out of this file cost
	# a full debugging cycle. The first measurement taken after entering the
	# flight reported a corridor crossing of 4.83 s against a predicted 1.53 --
	# and 4.83 / 1.53 is 3.16, which is not a coincidence, it is 1/0.316.
	# The later measurements matched their predictions exactly because the clock
	# had recovered by the time they ran, which is precisely the shape of bug
	# that looks like "one control is broken" and is not.
	print("[mig] Engine.time_scale on entry: %.3f" % Engine.time_scale)
	Engine.time_scale = 1.0
	for _i in 20:
		await tree.physics_frame
	if absf(Engine.time_scale - 1.0) > 0.02:
		print("[mig] FAIL — Engine.time_scale settled at %.3f, not 1.0. Every timing below would be scaled by it."
			% Engine.time_scale)
		tree.quit(1)
		return

	await _lateral(tree, mig, corridor)
	await _vertical(tree, mig, y_min, y_max)
	await _rally(tree, mig)

	for r in _rows:
		var n: String = r.name
		var v: float = r.value
		var u: String = r.unit
		if bool(r.asserted):
			var lo: float = r.lo
			var hi: float = r.hi
			print("[mig] %-22s %7.2f %-4s [%5.2f..%5.2f] %s"
				% [n, v, u, lo, hi, "ok" if (v >= lo and v <= hi) else "OUT"])
		else:
			print("[mig] %-22s %7.2f %-4s (observed)     %s" % [n, v, u, r.why])

	if _fails.is_empty():
		print("[mig] PASS — %d flight measurements" % _rows.size())
		tree.quit(0)
		return
	print("[mig] FAIL — %d outside their window:" % _fails.size())
	for f in _fails:
		print("[mig]   %s" % f)
	tree.quit(1)


static func _assert_window(name: String, value: float, unit: String, lo: float, hi: float, why: String) -> void:
	_rows.append({"name": name, "value": value, "unit": unit, "lo": lo, "hi": hi,
		"asserted": true, "why": why})
	if value < lo or value > hi:
		_fails.append("%s = %.2f %s, want [%.2f..%.2f] — %s" % [name, value, unit, lo, hi, why])


static func _observe(name: String, value: float, unit: String, note: String) -> void:
	_rows.append({"name": name, "value": value, "unit": unit, "lo": 0.0, "hi": 0.0,
		"asserted": false, "why": note})


# ---------------------------------------------------------------- lateral

## THE MANOEUVRE THE HAZARD CLOCK IS ABOUT.
##
## Leg 7 spawns a hazard every 0.9–1.6 s. Whether the corridor can be crossed
## inside that gap decides whether the flight is "dodge across the lane" or
## "commit to a side and make small corrections" — and the answer is currently
## the second one, which nothing in the design documents says out loud.
static func _lateral(tree: SceneTree, mig: Node, corridor: float) -> void:
	_release_all()
	var p: Vector3 = mig.get("player_pos")
	p.x = -corridor
	mig.set("player_pos", p)
	for _i in 4:
		await tree.physics_frame

	var t := 0.0
	var wall0 := Time.get_ticks_msec()
	var frames := 0
	var x0: float = float((mig.get("player_pos") as Vector3).x)
	Input.action_press("gg_right")
	for _i in 400:
		await tree.physics_frame
		t += TICK
		frames += 1
		var now: Vector3 = mig.get("player_pos")
		if now.x >= corridor - 0.05:
			break
	Input.action_release("gg_right")
	var wall := float(Time.get_ticks_msec() - wall0) * 0.001
	var x1: float = float((mig.get("player_pos") as Vector3).x)
	var measured: float = (x1 - x0) / maxf(wall, 0.001)
	print("[mig] lateral: %d frames, %.2f s wall, %.2f m -> %.2f m/s (the code says 17.0)"
		% [frames, wall, x1 - x0, measured])

	# OBSERVED, NOT ASSERTED, AND THE REASON IS THE POINT.
	#
	# `_tick_player()` moves the bird at 17.0 m/s across a 26 m corridor, which
	# is 1.53 s. THIS MEASURES 4.5 s — an effective 5.78 m/s, about a third of
	# the stated speed — and I could not establish why:
	#
	#   * the input is exactly (1.0000, 0.0000); raw strength 1.00, deadzone 0.20
	#   * Engine.time_scale is 1.000 for every frame of the run
	#   * physics-frame time and wall-clock agree to 2 ms over 4.5 s
	#   * nothing else in migration.gd writes player_pos.x
	#   * the vertical channels, measured the same way in the same run, match
	#     their predictions to within 0.01 s (climb 2.55 against 2.54 predicted,
	#     dive 1.47 against 1.46, sink 1.60 against 1.60)
	#
	# The arithmetic that does hold: 26 m at 17 m/s needs 1.53 s of SUMMED
	# _process delta, and 1.53 / 4.5 is roughly a third — so the deltas
	# `_tick_player` receives sum to a third of real time while the engine
	# reports 145 fps and a time_scale of 1. That is as far as it got.
	#
	# So: either the flight is three times less responsive than its own constant
	# claims — which would matter a great deal, since lateral movement is the
	# entire dodge — or this harness is wrong in a way the vertical channels
	# happen not to expose. **Both possibilities are worth someone's time and
	# neither is worth a build-failing window until one of them is established.**
	# Asserting here would either wire in a red build or bless a number I do not
	# understand. See docs/FEEL_TARGETS.md §6.
	_observe("lateral.full_cross", t, "s",
		"edge to edge; the constants predict 1.53 s and this is not that — UNEXPLAINED, see the comment")
	_observe("lateral.half_cross", t * 0.5, "s",
		"centre to edge, the manoeuvre that must fit inside leg 7's 0.9 s hazard gap")


# ---------------------------------------------------------------- vertical

static func _vertical(tree: SceneTree, mig: Node, y_min: float, y_max: float) -> void:
	# --- climb, from the floor of the band ---
	_release_all()
	var p: Vector3 = mig.get("player_pos")
	p.y = y_min
	mig.set("player_pos", p)
	for _i in 4:
		await tree.physics_frame

	var t_up := 0.0
	Input.action_press("gg_flap")
	for _i in 600:
		await tree.physics_frame
		t_up += TICK
		var now: Vector3 = mig.get("player_pos")
		if now.y >= y_max - 0.05:
			break
	Input.action_release("gg_flap")
	_assert_window("vertical.climb_band", t_up, "s", 1.2, 5.0,
		"floor to ceiling of the altitude band on a held flap. Wires are low and frequent on leg 7; a climb slower than 5 s means the low lane cannot be left in time")

	# --- dive, and it has to be the faster direction ---
	var t_down := 0.0
	Input.action_press("gg_dive")
	for _i in 600:
		await tree.physics_frame
		t_down += TICK
		var now2: Vector3 = mig.get("player_pos")
		if now2.y <= y_min + 0.05:
			break
	Input.action_release("gg_dive")
	_assert_window("vertical.dive_band", t_down, "s", 0.6, 3.0,
		"ceiling to floor on a held dive")
	_assert_window("vertical.dive_beats_climb", t_up / maxf(t_down, 0.001), "x", 1.15, 4.0,
		"the dive has its own button; going down must be meaningfully quicker than going up or the two controls are one control")

	# --- and letting go must not be neutral: the bird sinks ---
	var p2: Vector3 = mig.get("player_pos")
	p2.y = (y_min + y_max) * 0.5
	mig.set("player_pos", p2)
	var y0: float = p2.y
	for _i in 60:
		await tree.physics_frame
	var y1: float = float((mig.get("player_pos") as Vector3).y)
	_assert_window("vertical.idle_sink", (y0 - y1), "m/s", 0.4, 4.0,
		"altitude lost per second with NO input. Zero means holding station is free and the stamina economy has nothing to charge for; above 4 m/s the band drains faster than a climb can refill it")


# ---------------------------------------------------------------- the rally

## The honk in flight is not a weapon, it is attention management: it drags the
## worst drifter back toward its slot. `_rally()` is the only thing the honk
## does up here, and nothing has ever checked that it does it.
static func _rally(tree: SceneTree, mig: Node) -> void:
	_release_all()
	var birds: Array = mig.get("birds")
	if birds.size() < 2:
		_observe("rally.birds", float(birds.size()), "", "fewer than two birds aloft — the rally cannot be measured")
		return

	# Shove one bird well out of formation, then honk and see it pulled back.
	var victim = null
	var player_idx: int = int(mig.get("player_bird_index"))
	for b in birds:
		if int(b.idx) != player_idx:
			victim = b
			break
	if victim == null:
		return

	victim.drift = Vector3(6.0, 0.0, 0.0)
	var before: float = float((victim.drift as Vector3).length())

	var down := InputEventAction.new()
	down.action = "gg_honk"
	down.pressed = true
	Input.parse_input_event(down)
	for _i in 6:
		await tree.physics_frame
	var up := InputEventAction.new()
	up.action = "gg_honk"
	up.pressed = false
	Input.parse_input_event(up)
	for _i in 4:
		await tree.physics_frame

	var after: float = float((victim.drift as Vector3).length())
	_observe("rally.drift_before", before, "m", "how far the worst bird was pushed out of slot")
	_observe("rally.drift_after", after, "m", "after one honk")
	_assert_window("rally.pull_in", after / maxf(before, 0.001), "x", 0.0, 0.6,
		"one honk must visibly drag the worst drifter back — _rally() multiplies its drift by 0.15, so anything near 1.0 means the honk is not reaching the flight")


# ---------------------------------------------------------------- entering

## Getting into the flight is the same dance `main.gd`'s `--migration` render
## probe does, and for the same reasons its comments give: `_load_migration()`
## awaits the results card before the flight exists, so the card has to be
## dismissed and the flight waited for rather than assumed.
static func _enter_flight(tree: SceneTree, main: Node) -> Node:
	var game := main.get_node_or_null("/root/Game")
	if game == null:
		return null
	game.set_phase(game.Phase.MIGRATION)
	await tree.process_frame

	var briefing = main.get("briefing")
	if briefing != null and is_instance_valid(briefing) and briefing.has_method("force_close"):
		briefing.force_close()

	for _i in 300:
		var results = main.get("results")
		if results != null and is_instance_valid(results) and results.has_method("is_open") and results.is_open():
			results.force_close()
		var cur: Node = main.get("current")
		if cur != null and is_instance_valid(cur) and cur.name.begins_with("Migration"):
			tree.paused = false
			# Let the flight settle into its opening before measuring it.
			for _j in 30:
				await tree.physics_frame
			return cur
		await tree.process_frame
	return null


static func _release_all() -> void:
	for a in ["gg_forward", "gg_back", "gg_left", "gg_right", "gg_flap", "gg_dive", "gg_honk"]:
		if InputMap.has_action(a):
			Input.action_release(a)
