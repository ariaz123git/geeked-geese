extends RefCounted
## THE CONTROLLER SMOKE TEST — the third gate, and the only one that presses a key.
##
## `tools/gate.gd` proves the code compiles. `tools/selftest.gd` proves the game
## agrees with itself. Neither of them can tell you that the goose does not move
## when you hold W, and that is the only category of bug that matters, because
## CLAUDE.md's own rule is that the controller has to feel good before anything
## else does.
##
## THE BUG THIS EXISTS BECAUSE OF. `_wanted()`'s input-lag buffer read the
## OLDEST sample instead of the newest one old enough, so every substance with
## input lag — eleven of the sixteen — ramped from 0 to a FOUR SECOND delay over
## its first four seconds and then stayed there. Fermented berries ask for 0.22 s
## and got 4.0. The gate passed. The selftest would have passed. The campaign
## loop test passed. Nothing in this project could see it, because nothing in
## this project had ever pressed a key.
##
## It works headless: `Input.action_press()` sets real action state, physics
## ticks at the project's 60 Hz whether or not anything is drawn, and
## `await tree.physics_frame` is one deterministic 1/60 s step. So this is cheap
## enough to run on every build.
##
##     godot --headless --path . -- --inputtest 2>&1 | grep '^\[input\]'
##
## Exit 0 = the bird obeys. Exit 1 = it does not, and the failing line says how.
##
## WHAT THIS CANNOT DO: judge whether any of it FEELS good. That is the human's
## job and this file does not have an opinion about it. Every threshold below is
## deliberately loose — they are there to catch "broken", never "not tuned".

const TICK := 1.0 / 60.0

static var _fails: Array[String] = []
static var _checks := 0


static func run(tree: SceneTree, main: Node) -> void:
	_fails.clear()
	_checks = 0

	var goose: CharacterBody3D = await _fresh_goose(tree, main)
	if goose == null:
		print("[input] FAIL — no goose in the zone")
		tree.quit(1)
		return

	var sober := await _walk_test(tree, goose, 1.0)
	print("[input] sober walk: %.2f m in 1.0 s" % sober)
	_ok(sober > 1.0,
		"holding forward for a second moved the goose %.2f m. It does not obey the stick at all." % sober)

	# BARS, SPECIFICALLY, and the choice is the whole test.
	#
	# It is the only substance in the shelf with input lag and ZERO DRIFT
	# (0.10 s, drift 0.0, time_scale 1.0), so the distance it covers is a clean
	# measurement of the lag and nothing else. Berries were tried first and are
	# useless here: their 0.36 drift is a random walk that pushes the bird a
	# metre in a random direction every second, so the same test swung between
	# 49% and 105% of sober across two runs.
	#
	# With drift at zero the discriminator is total. A goose obeying input from
	# 0.10 s ago covers about 80% of the sober distance. A goose obeying input
	# from four seconds ago — which is what the buffer bug delivered — has no
	# drift to carry it and covers NOTHING AT ALL.
	var dosed := await _dosed_walk_test(tree, goose, &"bars", 1.0)
	print("[input] bars walk: %.2f m in 1.0 s (%.0f%% of sober)" % [dosed, 100.0 * dosed / maxf(sober, 0.001)])
	_ok(dosed > sober * 0.50,
		"on bars the goose covered %.2f m against %.2f m sober (%.0f%%). Bars ask for 0.10 s of input lag and zero drift, so this is the lag and nothing else — check the buffer read in _wanted()."
			% [dosed, sober, 100.0 * dosed / maxf(sober, 0.001)])

	var flight := await _takeoff_test(tree, goose)
	print("[input] takeoff: peak +%.2f m, reached FLY = %s" % [flight.x, flight.y > 0.5])
	_ok(flight.y > 0.5, "a run-up and a flap never reached State.FLY. The bird cannot take off.")
	_ok(flight.x > 0.8, "the takeoff gained %.2f m of altitude. The flap does nothing." % flight.x)

	var honked := await _honk_test(tree, main, goose)
	print("[input] honk: chaos +%d" % honked)
	_ok(honked > 0, "honking next to the cart corral scored nothing. The honk's physical presence is gone.")

	if _fails.is_empty():
		print("[input] PASS — %d controller checks" % _checks)
		tree.quit(0)
		return
	print("[input] FAIL — %d of %d controller checks:" % [_fails.size(), _checks])
	for f in _fails:
		print("[input]   %s" % f)
	tree.quit(1)


static func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_fails.append(msg)


## Put the bird on the ground, sober, stationary, with the clock running.
static func _fresh_goose(tree: SceneTree, main: Node) -> CharacterBody3D:
	var game := main.get_node_or_null("/root/Game")
	if game != null:
		game.zone_running = true
	for _i in 30:
		await tree.physics_frame
	var cur: Node = main.get("current")
	if cur == null or not is_instance_valid(cur):
		return null
	var g = cur.get("goose")
	return g as CharacterBody3D


static func _settle(tree: SceneTree, goose: CharacterBody3D) -> void:
	_release_all()
	# Annotated, not inferred: Engine.get_main_loop() is typed MainLoop, which has
	# no `root`, so the whole chain is a Variant and ':=' is a parse error. This
	# is the single most common mistake in the codebase and it caught this file.
	var subs: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Subs")
	if subs != null and subs.has_method("reset_for_new_leg"):
		subs.reset_for_new_leg()
	goose.velocity = Vector3.ZERO
	# Long enough for the input buffer to drain and for the bird to stop sliding.
	for _i in 90:
		await tree.physics_frame


static func _release_all() -> void:
	for a in ["gg_forward", "gg_back", "gg_left", "gg_right", "gg_flap", "gg_dive", "gg_honk"]:
		if InputMap.has_action(a):
			Input.action_release(a)


## Hold forward for `secs` and return the horizontal distance covered.
static func _walk_test(tree: SceneTree, goose: CharacterBody3D, secs: float) -> float:
	await _settle(tree, goose)
	var start := goose.global_position
	Input.action_press("gg_forward")
	for _i in int(secs / TICK):
		await tree.physics_frame
	Input.action_release("gg_forward")
	var moved := goose.global_position - start
	moved.y = 0.0
	return moved.length()


static func _dosed_walk_test(tree: SceneTree, goose: CharacterBody3D, id: StringName, secs: float) -> float:
	await _settle(tree, goose)
	# Annotated, not inferred: Engine.get_main_loop() is typed MainLoop, which has
	# no `root`, so the whole chain is a Variant and ':=' is a parse error. This
	# is the single most common mistake in the codebase and it caught this file.
	var subs: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Subs")
	if subs != null and subs.has_method("take") and subs.has_method("get_substance"):
		var res: Resource = subs.get_substance(id)
		if res != null:
			subs.take(res, 0.6)
	# Let the dose land and the buffer fill past the lag window. The old bug got
	# WORSE with time — the buffer had to fill before it could hand back
	# four-second-old input — so waiting here is what makes this test bite.
	for _i in 120:
		await tree.physics_frame
	goose.velocity = Vector3.ZERO
	var start := goose.global_position
	Input.action_press("gg_forward")
	for _i in int(secs / TICK):
		await tree.physics_frame
	Input.action_release("gg_forward")
	var moved := goose.global_position - start
	moved.y = 0.0
	return moved.length()


## Run up, then flap. Returns (peak altitude gained, 1.0 if State.FLY was seen).
static func _takeoff_test(tree: SceneTree, goose: CharacterBody3D) -> Vector2:
	await _settle(tree, goose)
	var y0 := goose.global_position.y
	var peak := 0.0
	var flew := 0.0
	Input.action_press("gg_forward")
	# The run-up requirement is real: takeoff_run_speed m/s of ground speed
	# before a flap becomes a launch instead of a pathetic little hop.
	for _i in 60:
		await tree.physics_frame
	Input.action_press("gg_flap")
	for _i in 150:
		await tree.physics_frame
		peak = maxf(peak, goose.global_position.y - y0)
		if int(goose.get("state")) == 2:   # State.FLY
			flew = 1.0
	_release_all()
	return Vector2(peak, flew)


## Honk and see whether the world reacted. Returns the chaos gained.
static func _honk_test(tree: SceneTree, main: Node, goose: CharacterBody3D) -> int:
	await _settle(tree, goose)
	var game := main.get_node_or_null("/root/Game")
	if game == null:
		return 0

	# Stand next to something breakable rather than trusting the spawn point to
	# have one in range — the honk's radius is 7.5 m and the zone is 80 m across.
	var props := tree.get_nodes_in_group("chaos_prop")
	if props.is_empty():
		return 0
	var target := props[0] as Node3D
	if target != null:
		goose.global_position = target.global_position + Vector3(0, 0.6, 2.0)
		goose.velocity = Vector3.ZERO
		for _i in 10:
			await tree.physics_frame

	var before: int = int(game.chaos)
	# THE HONK IS EVENT-DRIVEN, not polled. goose_controller.gd:730 tests
	# `e.is_action_pressed("gg_honk")` inside an input callback, while movement
	# and the flap are read with `Input.is_action_pressed` in _physics_process.
	# `Input.action_press()` sets action STATE without emitting an InputEvent, so
	# it drives the bird's legs and not its voice — the first version of this
	# test reported "the honk's physical presence is gone" and the honk was fine.
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
	for _i in 30:
		await tree.physics_frame
	return int(game.chaos) - before
