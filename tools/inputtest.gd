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

	await _eat_test(tree, goose)

	var honked := await _honk_test(tree, main, goose)
	print("[input] honk: chaos +%d" % honked)
	_ok(honked > 0, "honking next to the cart corral scored nothing. The honk's physical presence is gone.")

	# Read the cooldown off the instance's script rather than repeating it.
	# `preload()` on a file that declares `class_name` resolves to the TYPE,
	# not to a Script value, so `get_script_constant_map()` on it is a parse
	# error: "Cannot call non-static function ... on the class Goose directly."
	var share_cd: float = float(goose.get_script()
		.get_script_constant_map().get("SHARE_COOLDOWN", 0.0))
	var shared := await _share_test(tree, main, goose)
	print("[input] share: 3 presses in 6 frames fired %d time(s); a press with the flock saturated fired %d"
		% [shared.x, shared.y])
	_ok(shared.x > 0,
		"three share presses fired the verb zero times. It is dead, not merely rate-limited.")
	_ok(shared.x == 1,
		("three share presses inside a %.2f s cooldown fired the verb %d times. It pays 75 x combo "
		+ "every time, so without the cooldown the key is free chaos on repeat.")
			% [share_cd, shared.x])
	_ok(shared.y == 0,
		("sharing with every bird already at intox 1.0 fired the verb %d time(s). The dose is a "
		+ "no-op there — clampf eats it — so the player is paid for a keypress that did nothing.")
			% shared.y)

	await _pause_menu_test(tree, main)

	if _fails.is_empty():
		print("[input] PASS — %d controller checks" % _checks)
		tree.quit(0)
		return
	print("[input] FAIL — %d of %d controller checks:" % [_fails.size(), _checks])
	for f in _fails:
		print("[input]   %s" % f)
	tree.quit(1)




## ═══════════════════════════════════════════════════════════════════════════
## ESC, THROUGH THE VIEWPORT, LIKE A PLAYER
## ═══════════════════════════════════════════════════════════════════════════
##
## **The human pressed Escape and reported "there is still no pause menu."**
## Twelve gates were green at the time. NOTHING IN THIS PROJECT HAS EVER SENT
## AN INPUT EVENT THROUGH THE VIEWPORT — every harness either calls
## `Input.action_press()`, which sets action STATE and never produces an
## `InputEvent`, so no `_input()` anywhere fires; or it calls a handler
## directly. `main.gd`'s own restart probe does the latter — `_unhandled_input
## (rev)`, invoked on main — which proves the handler works and proves nothing
## about whether the event would ever reach it.
##
## `Input.parse_input_event()` is the whole difference. It pushes the event
## into the real dispatch, so every node's `_input()` runs, in the real order,
## under the real `process_mode` rules. That is where the bug lived.
##
## Three assertions, all of them things a player notices in one press: the
## menu opens, the tree actually stops, and a second press gives the game
## BACK. The last is not padding — `_open_menu()` sets `get_tree().paused` and
## `_close()` clears it, so a menu that strands the tree paused is the other
## half of this bug sitting one edit away.
static func _pause_menu_test(tree: SceneTree, main: Node) -> void:
	var menu: Node = main.get("pause_menu")
	_ok(menu != null and menu.has_method("is_open"),
		"main has no pause_menu with an is_open(), so Escape was never exercised at all")
	if menu == null or not menu.has_method("is_open"):
		return

	_release_all()
	var was_paused: bool = tree.paused
	tree.paused = false
	# Start from closed however we arrived here.
	if bool(menu.call("is_open")):
		await _escape(tree)
	for _i in 2:
		await tree.process_frame

	await _escape(tree)
	var opened: bool = bool(menu.call("is_open"))
	var paused: bool = tree.paused
	print("[input] escape: open=%s paused=%s" % [opened, paused])
	_ok(opened,
		("pressing Escape did not open the pause menu. It is built, it is on layer 30, "
		+ "and its `_input()` handles ui_cancel — so the event is not reaching it. First "
		+ "suspect is `process_mode`: PROCESS_MODE_WHEN_PAUSED gates `_input` as well as "
		+ "`_process`, which makes a pause menu that can close itself and never open."))
	_ok(paused,
		"the pause menu reported open and the tree is still running. Escape did not pause the game.")

	await _escape(tree)
	var still_open: bool = bool(menu.call("is_open"))
	print("[input] escape again: open=%s paused=%s" % [still_open, tree.paused])
	_ok(not still_open, "a second Escape did not close the pause menu.")
	_ok(not tree.paused,
		("the pause menu closed and left the tree PAUSED. Every zone, every flight and "
		+ "every timer is stopped, and the player has no way to start them again."))

	tree.paused = was_paused


## One Escape, through the viewport rather than at a handler.
static func _escape(tree: SceneTree) -> void:
	var down := InputEventAction.new()
	down.action = "ui_cancel"
	down.pressed = true
	Input.parse_input_event(down)
	await tree.process_frame
	var up := InputEventAction.new()
	up.action = "ui_cancel"
	up.pressed = false
	Input.parse_input_event(up)
	for _i in 3:
		await tree.process_frame

## ═══════════════════════════════════════════════════════════════════════════
## THE EATING VERB, THROUGH THE KEY THE PLAYER PRESSES
## ═══════════════════════════════════════════════════════════════════════════
##
## `docs/HANDOFF.md` §4: *"Every harness reaches into `Subs.take()` directly, so
## `_tick_eat`'s charge arc, the sweet-spot band, the abort, the pickup's
## `consumed()` and the SWEET SPOT / OVERDOSE / BARELY ANYTHING scoring have
## never been driven by a key."* That is the game's CORE SKILL EXPRESSION — the
## controller's own comment calls letting go at the right moment "its only real
## input-timing test" — and it is the reason `stamina_restore` could be dead in
## six `.tres` files with every gate green.
##
## GRASS, and the choice is load-bearing. It is `infinite` in leg 1 (the zone's
## own comment says so, and says why: "the dose ARC — charge, release, overdose
## — is the thing leg 1 has to teach"), so the same pickup survives all three
## releases; it is in the tutorial shelf, so it is there at leg 1; its band is
## wide (0.35–0.85) so the three doses are far apart; and it restores 0.25
## stamina, which is the field nothing has ever been able to check behaviourally.
##
## THE HOLDS ARE TO A CHARGE, NOT TO A FRAME COUNT, and the first draft got this
## wrong in a way worth keeping. `_eat_charge += delta / charge_time` looks like
## 1/84 per frame at 60 Hz — and the first dose measures exactly that, 0.202 in
## 17 frames. The second and third do not: they came in at 0.545 and 0.838 where
## the frame count predicted 0.607 and 0.952, and the harness called the game
## broken. **Grass sets `time_scale` to 0.88.** Once the first dose lands, every
## `delta` the controller sees is 12% shorter, so the arc is still a clock — in
## GAME time, which is the only clock the player is in. Holding until the charge
## reaches a target is immune to that; the clock is then checked separately
## against game time accumulated the same way.
##
## Targets 0.20 / 0.60 / 0.95 against a [0.35, 0.85] band: clear of both edges.
static func _eat_test(tree: SceneTree, goose: CharacterBody3D) -> void:
	var pick: Node3D = null
	for n in tree.get_nodes_in_group("substance_source"):
		var cand := n as Node3D
		if cand == null or not is_instance_valid(cand):
			continue
		var sub: Object = cand.get("substance")
		if sub != null and str(sub.get("id")) == "grass":
			pick = cand
			break
	_ok(pick != null,
		"leg 1 has no grass source to eat, so the eating verb was not exercised at all.")
	if pick == null:
		return
	var res: Substance = pick.get("substance")

	# WALK INTO IT. `SubstancePickup` is an Area3D whose `body_entered` calls
	# `set_eat_target()`; nothing else sets `_eating`, so being in range is part
	# of what is under test rather than something to fake.
	_release_all()
	goose.global_position = pick.global_position + Vector3.UP * 0.5
	goose.velocity = Vector3.ZERO
	var in_range := false
	for _i in 30:
		await tree.physics_frame
		if goose.get("_eating") != null:
			in_range = true
			break
	_ok(in_range,
		("standing on the grass never set the goose's eat target. `body_entered` -> "
		+ "`set_eat_target()` is the only path that arms the verb, so nothing below "
		+ "this ran."))
	if not in_range:
		return

	# EVERY LABEL THE DOSE SCORES. `Game.score()` emits `chaos_scored` with the
	# label as its fourth argument, which is the only observable that separates
	# the three outcomes — they all call `Subs.take()` and they all succeed.
	var labels: Array = []
	var watch := func(_amount: int, _total: int, _combo: int, label: String) -> void:
		labels.append(label)
	Game.chaos_scored.connect(watch)

	for row in [[0.20, "BARELY ANYTHING"], [0.60, "SWEET SPOT"], [0.95, "OVERDOSE"]]:
		var spec: Array = row
		var target: float = spec[0]
		var want: String = spec[1]
		labels.clear()
		var game_time := 0.0
		var held := 0
		Input.action_press("gg_eat")
		for _f in 240:
			await tree.physics_frame
			# The clock the CONTROLLER is on. `Engine.time_scale` scales the delta
			# handed to `_physics_process`, and grass sets it to 0.88.
			game_time += TICK * Engine.time_scale
			held += 1
			if float(goose.get("_eat_charge")) >= target:
				break
		var charged: float = float(goose.get("_eat_charge"))
		# Set the stamina ON THE FRAME BEFORE THE RELEASE, so the gain measured
		# below is the restore and not a second of `regen_ground` — which over an
		# 80-frame hold is larger than the restore being looked for, and would
		# have satisfied a laxer check on its own.
		goose.set("stamina", 0.20)
		var before: float = float(goose.get("stamina"))
		Input.action_release("gg_eat")
		await tree.physics_frame
		await tree.physics_frame
		var after: float = float(goose.get("stamina"))

		_ok(charged >= target,
			("holding gg_eat for %d frames never reached a charge of %.2f (got %.3f). The "
			+ "arc does not fill.") % [held, target, charged])

		# THE ARC IS A CLOCK. A charge that saturated instantly would score SWEET
		# SPOT on all three of these holds and look perfect.
		var expect := game_time / res.charge_time
		_ok(absf(charged - expect) <= 0.06,
			("%d frames of gg_eat is %.3f s of game time and charge_time is %.2f s, so the "
			+ "charge should be %.3f. It is %.3f. The dose arc is not a clock.")
				% [held, game_time, res.charge_time, expect, charged])

		var in_band: bool = charged >= res.sweet_min and charged <= res.sweet_max
		var deserved := "SWEET SPOT" if in_band else ("OVERDOSE" if charged > res.sweet_max else "BARELY ANYTHING")
		_ok(deserved == want,
			("the harness aimed for %s and the charge landed at %.3f, which its band "
			+ "[%.2f, %.2f] calls %s. The three targets no longer straddle the band — fix "
			+ "the targets, not the game.") % [want, charged, res.sweet_min, res.sweet_max, deserved])
		_ok(labels.has(want),
			("a %.3f dose of grass scored %s, not %s. Its band is [%.2f, %.2f], and these "
			+ "three labels are the game's whole readout of the only input-timing skill "
			+ "it has.") % [charged, str(labels), want, res.sweet_min, res.sweet_max])

		_ok(Subs.is_active(res.id),
			"a %.3f dose of grass released through gg_eat left the substance inactive." % charged)

		# stamina_restore, BEHAVIOURALLY. It was dead in six .tres files and
		# nothing noticed, because it is applied at exactly this moment and no
		# harness had ever reached this moment. `selftest` can only see that the
		# field is named in the controller.
		var gained := after - before
		_ok(gained >= res.stamina_restore * 0.8 and gained <= res.stamina_restore * 1.2 + 0.03,
			("grass declares stamina_restore %.2f and a dose through the key moved stamina "
			+ "%.3f (%.2f -> %.2f) across the release frame. It is applied inside the "
			+ "`if Subs.take(...)` branch of _tick_eat(), so this is that line.")
				% [res.stamina_restore, gained, before, after])
		print("[input] eat: %3d frames -> %.3f charge (%.3f s game time), %s, stamina +%.3f"
			% [held, charged, game_time, str(labels), gained])
	# AND THE ABORT. Walking off mid-hold has to drop the charge on the floor:
	# `clear_eat_target()` nulls `_eating` and zeroes `_eat_charge` together, and
	# a version of `_tick_eat` that trusted a stale charge left the dose loop
	# ringing in the player's ears for the rest of the leg.
	labels.clear()
	var away := pick.global_position + Vector3(40.0, 0.5, 40.0)
	Input.action_press("gg_eat")
	for _f in 30:
		await tree.physics_frame
	goose.global_position = away
	for _f in 20:
		await tree.physics_frame
	Input.action_release("gg_eat")
	await tree.physics_frame
	Game.chaos_scored.disconnect(watch)
	_ok(float(goose.get("_eat_charge")) <= 0.001,
		("walking out of range mid-hold left %.3f of charge on the bird. It has to be "
		+ "dropped, or the next pickup starts part-charged.") % float(goose.get("_eat_charge")))
	_ok(labels.is_empty(),
		"walking away mid-hold still scored %s. An abort is not a dose." % str(labels))
	print("[input] eat: abort mid-hold dropped the charge and scored nothing")

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
	for a in ["gg_forward", "gg_back", "gg_left", "gg_right", "gg_flap", "gg_dive", "gg_honk", "gg_share"]:
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

## THE SHARE VERB, AND THE TWO WAYS IT USED TO PAY FOR NOTHING.
##
## `gg_share` doses the whole flock and scores 75 chaos. It had no cooldown
## and no check that the dose landed, so mashing it paid 75 a press forever —
## and once every bird sat at intox 1.0 the dose was a no-op that still paid.
## Both are fixed in `goose_controller.gd::_unhandled_input`; this is what
## proves it, by pressing the key.
##
## COUNTS SCORING EVENTS, NOT CHAOS. The first version asserted that three
## presses paid no more than 75 and it failed on a correct build at 92:
## `Game.score()` multiplies by the live combo, so one share is worth 75 x
## whatever chain the run is on. The amount is not the thing being tested —
## how many times the verb FIRED is — so this counts `chaos_scored` emissions
## carrying the share label.
##
## Returns [fires_on_mash, fires_when_saturated] as a Vector2i.
static func _share_test(tree: SceneTree, main: Node, goose: CharacterBody3D) -> Vector2i:
	await _settle(tree, goose)
	var game := main.get_node_or_null("/root/Game")
	var subs := main.get_node_or_null("/root/Subs")
	if game == null or subs == null:
		return Vector2i(-1, -1)

	# The verb needs something to share. Any substance will do.
	var res = subs.get_substance(&"grass")
	if res == null:
		return Vector2i(-1, -1)
	subs.take(res, 0.5)
	for _i in 4:
		await tree.physics_frame

	# Sober the flock first, so the first share definitely has room to land.
	for b in Flock.birds:
		b.intox = 0.0

	# THREE PRESSES IN SIX FRAMES. One should fire.
	var fires := [0]
	var tally := func(_amount: int, _total: int, _combo: int, label: String) -> void:
		if label == "SHARED WITH THE FLOCK":
			fires[0] += 1
	game.chaos_scored.connect(tally)
	for _i in 3:
		var ev := InputEventAction.new()
		ev.action = "gg_share"
		ev.pressed = true
		Input.parse_input_event(ev)
		await tree.physics_frame
		var up := InputEventAction.new()
		up.action = "gg_share"
		up.pressed = false
		Input.parse_input_event(up)
		await tree.physics_frame
	var mashed: int = int(fires[0])

	# Now saturate the flock and wait out the cooldown. A press that moves
	# nothing must pay nothing.
	for b2 in Flock.birds:
		b2.intox = 1.0
	for _i in 80:
		await tree.physics_frame
	fires[0] = 0
	var ev2 := InputEventAction.new()
	ev2.action = "gg_share"
	ev2.pressed = true
	Input.parse_input_event(ev2)
	for _i in 6:
		await tree.physics_frame
	var up2 := InputEventAction.new()
	up2.action = "gg_share"
	up2.pressed = false
	Input.parse_input_event(up2)
	var saturated: int = int(fires[0])
	game.chaos_scored.disconnect(tally)

	subs.call("reset_for_new_leg")
	return Vector2i(mashed, saturated)


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
