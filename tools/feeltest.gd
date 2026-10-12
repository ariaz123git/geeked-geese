extends RefCounted
## THE FEEL HARNESS — the sixth gate, and the first one with an OPINION.
##
## THE GAP THIS EXISTS TO CLOSE. `tools/inputtest.gd` says so itself, in its own
## header: "WHAT THIS CANNOT DO: judge whether any of it FEELS good. That is a
## playtester's job and this file does not have an opinion about it. Every
## threshold below is deliberately loose — they are there to catch 'broken',
## never 'not tuned'."
##
## That sentence is why the project's next step kept being a request to go and
## play it, and why `docs/HANDOFF.md` §3 has said "Play it" at the top of the
## list twice in a row. The project could prove the bird MOVES.
## It could not prove the bird moves WELL, so the only available move was to
## defer — and deferring is what made the loop stall.
##
## THE ARGUMENT FOR MEASURING FEEL. "Feel" is not one thing. It decomposes:
##
##   * Things that are pure taste — is a waddling goose funny, is the honk timed
##     right, is the Ranger's voice good. **This file has nothing to say about
##     those and never will.** They are left to playtesting, permanently.
##   * Things that are a NUMBER with a defensible window — how long the bird
##     takes to reach top speed, how far it slides after you let go, whether
##     holding the flap button converges on a climb rate or diverges into orbit.
##     Those are measurable, they are the ones that make a controller feel
##     broken rather than merely unfunny, and **nothing in this project was
##     measuring them.**
##
## This file does the second kind. Its windows are not vibes: every one of them
## cites a number this project already wrote down somewhere, or a consequence
## that follows from the geometry the zones are built to. The reasoning for each
## lives in `docs/FEEL_TARGETS.md`, next to the number, so it can be ARGUED WITH
## rather than merely obeyed. A window nobody can argue with is a vibe wearing a
## lab coat.
##
##     godot --headless --path . -- --probe --feeltest 2>&1 | grep '^\[feel\]'
##
## Exit 0 = every asserted metric is inside its window. Exit 1 = at least one is
## not, and the failing line prints the value, the window and the one-sentence
## reason the window is where it is.
##
## TWO CLASSES OF METRIC, and the distinction is load-bearing:
##
##   ASSERTED — has a window, fails the build. Only ever added once the value
##              has been measured, reasoned about, and written up in
##              FEEL_TARGETS.md.
##   OBSERVED — measured and printed, no window, does not fail anything. This is
##              where a metric lives while it is still being understood. It is
##              NOT a weakened assertion; it is an honest "we are watching this
##              and have not earned an opinion yet". Promoting one to ASSERTED
##              is a deliberate act with a written reason.
##
## Adding a metric here is cheap. Adding a WINDOW is not, and should not be.

const COMMON := preload("res://tools/probe_common.gd")

const TICK := 1.0 / 60.0

## Result rows: {name, value, unit, lo, hi, asserted, why}
static var _rows: Array[Dictionary] = []
static var _fails: Array[String] = []

## Ticks during a GROUND measurement on which the bird was actually in water.
## Must be zero. See _ground_tests().
static var _wet_ticks := 0


static func run(tree: SceneTree, main: Node) -> void:
	_rows.clear()
	_fails.clear()
	_wet_ticks = 0
	COMMON.reset()

	var goose: CharacterBody3D = await COMMON.fresh_goose(tree, main)
	if goose == null:
		print("[feel] FAIL — no goose in the zone")
		tree.quit(1)
		return

	# THE CLOCK HAS TO BE HONEST OR EVERY NUMBER BELOW IS A LIE. Two autoloads
	# write Engine.time_scale (Subs sets the substance baseline, Juice multiplies
	# hitstop on top at process_priority 100). Every measurement here converts
	# physics frames to seconds at 1/60, so a time_scale that is not 1.0 silently
	# rescales the entire report. Checked, never assumed.
	if absf(Engine.time_scale - 1.0) > 0.02:
		print("[feel] FAIL — Engine.time_scale is %.3f, not 1.0. Every timing below would be wrong." % Engine.time_scale)
		tree.quit(1)
		return

	# HOLD THE ZONE STILL FOR ALL OF IT. Every metric in this file measures
	# the CONTROLLER answering the stick, so a cat at 2.6 m/s is noise in
	# every one of them. The retakes below stay — they still catch a rolling
	# cart, which `hold_actors()` does not touch — but they stopped being
	# sufficient on 2026-08-18, when a cat camped on the pad and four
	# consecutive sober runs disagreed on bearing while turn rate and climb
	# were bit-identical. `probe_common.gd::hold_actors()` lesson 6.
	var held := COMMON.hold_actors(tree, true)
	print("[feel] %d actors held still for the measurements" % held)

	await _ground_tests(tree, goose)
	await _flight_tests(tree, goose)
	await _stamina_tests(tree, goose)
	await _latency_tests(tree, goose)

	COMMON.hold_actors(tree, false)
	_report()
	if _fails.is_empty():
		var asserted := 0
		for r in _rows:
			if bool(r.asserted):
				asserted += 1
		print("[feel] PASS — %d measurements, %d asserted, all in window" % [_rows.size(), asserted])
		tree.quit(0)
		return
	print("[feel] FAIL — %d metric(s) outside their window:" % _fails.size())
	for f in _fails:
		print("[feel]   %s" % f)
	tree.quit(1)


# ---------------------------------------------------------------- recording

## A metric with a window. Fails the build when outside it.
static func _assert_window(name: String, value: float, unit: String, lo: float, hi: float, why: String) -> void:
	_rows.append({
		"name": name, "value": value, "unit": unit,
		"lo": lo, "hi": hi, "asserted": true, "why": why,
	})
	if value < lo or value > hi:
		_fails.append("%s = %.2f %s, want [%.2f..%.2f] — %s" % [name, value, unit, lo, hi, why])


## A hard pass/fail that is not a measurement — used for harness faults, where
## the honest report is "this run could not be trusted", not a number.
static func _ok(cond: bool, msg: String) -> void:
	if not cond:
		_fails.append(msg)


## A metric with no window yet. Printed, never fails. See the header.
static func _observe(name: String, value: float, unit: String, note: String) -> void:
	_rows.append({
		"name": name, "value": value, "unit": unit,
		"lo": 0.0, "hi": 0.0, "asserted": false, "why": note,
	})


static func _report() -> void:
	for r in _rows:
		var n: String = r.name
		var v: float = r.value
		var u: String = r.unit
		if bool(r.asserted):
			var lo: float = r.lo
			var hi: float = r.hi
			var verdict := "ok" if (v >= lo and v <= hi) else "OUT"
			print("[feel] %-26s %8.2f %-5s [%6.2f..%6.2f] %s" % [n, v, u, lo, hi, verdict])
		else:
			var note: String = r.why
			print("[feel] %-26s %8.2f %-5s (observed)      %s" % [n, v, u, note])


# ---------------------------------------------------------------- ground

static func _ground_tests(tree: SceneTree, goose: CharacterBody3D) -> void:
	# --- top speed, time to reach it, and the latency before anything happens ---
	#
	# RETRIED, BECAUSE THE ZONE IS ALIVE WHILE THIS RUNS.
	#
	# Leg 1 builds seven cats that wander at 2.6 m/s and a lot of loose shopping
	# carts, and none of them stop just because something is being measured. One
	# run of this reported a top speed of 7.37 m/s -- faster than waddle_speed
	# (4.2) AND faster than swim_speed (5.4), because the bird had been shoved --
	# and failed the build on a controller that was fine.
	#
	# A speed above waddle_speed by more than a small margin is not a controller
	# result, it is a collision, so the measurement is thrown away and retaken.
	# Three attempts, and if all three are disturbed it says so as a HARNESS
	# fault rather than reporting the shove as a feel verdict.
	var latency := -1
	var top := 0.0
	var samples: Array[float] = []
	var attempts := 0
	# 1.06, not 1.25. Sober top speed is DETERMINISTIC — `waddle_speed` exactly,
	# 4.20 — so any excess at all is the world pushing the bird, and a generous
	# cap just lets small shoves through unretried: one run reported 5.10 m/s,
	# a 21% disturbance, and passed because the window is [3, 6]. 6% is room for
	# numerical noise and nothing else.
	var cap: float = float(goose.get("waddle_speed")) * 1.06

	while attempts < 3:
		attempts += 1
		await _settle(tree, goose)
		latency = -1
		top = 0.0
		samples.clear()
		var wet_before := _wet_ticks
		Input.action_press("gg_forward")
		# 90 ticks. At waddle_speed that covers about 6.3 m, which has to stay
		# inside COMMON.PAD_RADIUS; top speed arrives at 0.2 s so more only buys
		# travel.
		for i in 90:
			await tree.physics_frame
			_watch_dry(goose)
			var s := _flat_speed(goose)
			samples.append(s)
			if latency < 0 and s > 0.01:
				latency = i + 1
			top = maxf(top, s)
		Input.action_release("gg_forward")

		# AND THE RAMP HAS TO START FROM REST, or `time_to_top` is measured
		# from partway up it. One run reported 0.17 s against an analytic
		# `waddle_speed / waddle_accel` of 0.21: the bird still carried
		# velocity from the previous channel, so 0.95 x top arrived three
		# ticks early. A clean ramp is 0.33 m/s per tick — 20 m/s^2 at 60 Hz
		# — and its first sample is one tick of that, not a third of the way
		# up. `_settle()` normally leaves the bird still; this is what says
		# so rather than assuming it.
		var started_at: float = samples[0] if not samples.is_empty() else 0.0
		var rest_cap: float = float(goose.get("waddle_accel")) * TICK * 1.5
		if top <= cap and _wet_ticks == wet_before and started_at <= rest_cap:
			break
		if started_at > rest_cap:
			print("[feel] walk attempt %d began at %.2f m/s, not from rest (one tick of "
				+ "waddle_accel is %.2f) — retaking" % [attempts, started_at, rest_cap])
		else:
			print("[feel] walk attempt %d disturbed (top %.2f m/s against a %.2f cap) — retaking"
				% [attempts, top, cap])
		# The retry must not inherit the discarded attempt's wet ticks either.
		_wet_ticks = wet_before

	_ok(top <= cap,
		("the walk was disturbed on all %d attempts (top %.2f m/s against a %.2f cap). Something "
		+ "in the zone is pushing the bird — cats wander and carts roll. This is a HARNESS fault; "
		+ "do not read the ground rows below as a controller verdict.") % [attempts, top, cap])

	var t_to_top := 0.0
	for i in samples.size():
		if samples[i] >= top * 0.95:
			t_to_top = float(i + 1) * TICK
			break

	# -1.0, not 0.0, when the bird never moved at all. A bare zero reads as
	# "responded instantly" and means the exact opposite here; the same trap is
	# commented on cam.catch_up below.
	_assert_window("ground.latency", (float(latency) if latency > 0 else -1.0), "tick", 1.0, 3.0,
		"a press must move the bird on the next physics tick; 3 ticks is 50 ms and already reads as lag. -1 means it never moved")
	_assert_window("ground.top_speed", top, "m/s", 3.0, 6.0,
		"below 3 m/s an 80 m zone takes half a minute to cross; above 6 it stops reading as a waddle")
	_assert_window("ground.time_to_top", t_to_top, "s", 0.10, 0.40,
		"under 0.10 s the bird has no weight at all; over 0.40 s it feels like pushing a fridge")

	# --- stop distance: let go at speed and see how far it coasts ---
	#
	# RETRIED, AND THE PRECONDITION IS THE POINT: this measures a COAST, so it is
	# meaningless unless the bird was actually at speed when the key came up. A
	# goose pinned against a shopping cart releases at 0 m/s and coasts 0.00 m,
	# which the window reads as a controller that stops dead. That failed a build.
	var slide_len := 0.0
	var slide_try := 0
	while slide_try < 3:
		slide_try += 1
		await _settle(tree, goose)
		Input.action_press("gg_forward")
		for _i in 60:
			await tree.physics_frame
		var release_speed := _flat_speed(goose)
		Input.action_release("gg_forward")
		var p0 := goose.global_position
		for _i in 90:
			await tree.physics_frame
			_watch_dry(goose)
			if _flat_speed(goose) < 0.05:
				break
		var slide := goose.global_position - p0
		slide.y = 0.0
		slide_len = slide.length()
		# Released at very near top speed, and not shoved past it on the way.
		if release_speed > cap * 0.80 and release_speed <= cap:
			break
		print("[feel] stop attempt %d released at %.2f m/s (want %.2f–%.2f) — retaking"
			% [slide_try, release_speed, cap * 0.80, cap])

	_assert_window("ground.stop_distance", slide_len, "m", 0.05, 0.80,
		"the goose capsule is about 0.7 m; coasting more than a body length past the key reads as ice")

	# --- 180 degrees: how long to turn round ---
	#
	# RETRIED ON THE SAME SIGNAL AS THE WALK. A shove does not only change speed;
	# `_face()` steers toward the direction of TRAVEL, so a cat that knocks the
	# bird sideways moves the target it is turning toward and the turn never
	# converges. One run in five measured 1.42 s against a normal 0.30 and failed
	# the build.
	#
	# The disturbance signal is deliberately metric-independent: the bird
	# exceeding `waddle_speed` at any point is the world touching it, whichever
	# measurement happens to be running. That generalises to the next one added.
	var turn_t := 0.0
	var turn_try := 0
	while turn_try < 3:
		turn_try += 1
		await _settle(tree, goose)
		var shoved := false
		Input.action_press("gg_forward")
		for _i in 60:
			await tree.physics_frame
			if _flat_speed(goose) > cap:
				shoved = true
		var h0: float = float(goose.get("heading"))
		Input.action_release("gg_forward")
		Input.action_press("gg_back")
		turn_t = 0.0
		for i in 180:
			await tree.physics_frame
			if _flat_speed(goose) > cap:
				shoved = true
			var h: float = float(goose.get("heading"))
			if absf(angle_diff(h, h0)) > PI - deg_to_rad(10.0):
				turn_t = float(i + 1) * TICK
				break
		Input.action_release("gg_back")
		if not shoved and turn_t > 0.0:
			break
		print("[feel] turn attempt %d disturbed (%.2f s, shoved=%s) — retaking"
			% [turn_try, turn_t, str(shoved)])

	_assert_window("ground.turn_180", turn_t, "s", 0.15, 0.80,
		"chasing a rolling cart is the core comedy verb; over 0.8 s to turn round makes it misery")

	# A CONTAMINATED MEASUREMENT MUST NOT BE REPORTED AS A CONTROLLER VERDICT.
	#
	# Every row above describes _tick_ground(). If the bird was in the pond for
	# any of it, the rows describe _tick_water() instead, and they will accuse a
	# perfectly healthy controller of being slow and slidey with real numbers
	# that mean nothing. That happened, and it turned verify.ps1 red.
	#
	# The distinction the message has to carry: this is the HARNESS failing to
	# get a clean read, not the game failing. The fix is in probe_common.find_dry_ground(),
	# never in goose_controller.gd.
	if _wet_ticks > 0:
		_fails.append(("ground metrics are CONTAMINATED - the goose was in water for %d "
			+ "measurement ticks, so the rows above describe _tick_water(), not "
			+ "_tick_ground(). This is a HARNESS fault: probe_common.find_dry_ground() found a pad "
			+ "too near the pond. Fix the search. Do not tune the controller from these "
			+ "numbers.") % _wet_ticks)


# ---------------------------------------------------------------- flight

static func _flight_tests(tree: SceneTree, goose: CharacterBody3D) -> void:
	# --- ONE FLAP, from level flight. The design's own number. ---
	#
	# docs/HANDOFF.md:302 argues from "a goose climbs the racking one level per
	# flap" and BIG DOWN's racking is built on a 1.70 m beam pitch to suit it.
	# That makes 1.70 m the single most load-bearing feel number in the project:
	# a level of warehouse racking is a unit of climb the player is meant to be
	# able to spend one flap on.
	await _aloft(tree, goose, 60.0)
	var y0 := goose.global_position.y
	Input.action_press("gg_flap")
	await tree.physics_frame
	Input.action_release("gg_flap")
	var peak := 0.0
	for _i in 90:
		await tree.physics_frame
		peak = maxf(peak, goose.global_position.y - y0)
		if goose.velocity.y < 0.0 and peak > 0.01:
			break
	_assert_window("fly.one_flap_climb", peak, "m", 1.30, 2.30,
		"one flap is one level of BIG DOWN's racking (1.70 m beam pitch, docs/HANDOFF.md:302)")

	# --- HELD FLAP. Does it converge, or does the goose become a helicopter? ---
	#
	# THE ASSERTION THIS FILE WAS WRITTEN FOR. `_flap()` does
	#     velocity.y = maxf(velocity.y, 0.0) + power
	# which ADDS the impulse to an already-positive climb. Gravity only takes
	# glide_gravity * flap_cooldown back between flaps, so if power exceeds that
	# product the climb rate compounds without bound and the only thing between
	# the player and orbit is the stamina bar. There is a max_fall. There is no
	# max_rise.
	# MEASURED AS ALTITUDE GAINED PER SECOND, NOT AS vy AT AN INSTANT.
	#
	# A flap that does not compound produces a SAWTOOTH: vy jumps to the impulse,
	# decays for one cooldown, jumps again. Sampling vy at exactly t=1 s and
	# t=3 s then reads two arbitrary points on that sawtooth, and the ratio
	# between them swings with nothing but the phase — a healthy controller could
	# report 1.7 and fail. Integrating over a whole second removes the phase
	# entirely, and metres-climbed-per-second is also the quantity the player
	# actually experiences.
	await _aloft(tree, goose, 160.0)
	var y_start := goose.global_position.y
	var y_at_1 := 0.0
	var y_at_2 := 0.0
	var y_at_3 := 0.0
	var climb_peak := 0.0
	Input.action_press("gg_flap")
	for i in 180:
		await tree.physics_frame
		climb_peak = maxf(climb_peak, goose.velocity.y)
		if i == 59:
			y_at_1 = goose.global_position.y
		if i == 119:
			y_at_2 = goose.global_position.y
		if i == 179:
			y_at_3 = goose.global_position.y
	Input.action_release("gg_flap")

	var gain_first := y_at_1 - y_start
	var gain_third := y_at_3 - y_at_2

	_assert_window("fly.climb_peak", climb_peak, "m/s", 1.0, 14.0,
		"above 14 m/s the bird clears any rooftop in the game in under two seconds and zone geometry stops meaning anything")
	# Guarded so a zero first second cannot produce a divide-by-zero ratio.
	_assert_window("fly.climb_convergence", gain_third / maxf(gain_first, 0.001), "x", 0.55, 1.40,
		"metres climbed in the 3rd second of held flap over the 1st; above 1.40 the flap compounds and altitude is free")
	_observe("fly.climb_1st_second", gain_first, "m", "altitude gained in the 1st second of held flap")
	_observe("fly.climb_3rd_second", gain_third, "m", "altitude gained in the 3rd second of held flap")

	# --- THE GLIDE AND THE DIVE, OVER A DROP A PLAYER WOULD ACTUALLY TAKE. ---
	#
	# THE MEASUREMENT BUG THIS REPLACES. The first version sampled sink rate at
	# three and four seconds and compared them. Both came back 34.00 m/s and the
	# dive/glide ratio came back exactly 1.00, which reads as a damning finding
	# and is nothing of the kind: `max_fall` is 34 and BOTH branches clamp to it,
	# so any measurement taken after terminal velocity compares a constant to
	# itself. Sampling at terminal cannot see the difference between the two
	# verbs, because at terminal there isn't one.
	#
	# What a player experiences is not a terminal velocity. It is a DROP: I am on
	# that roof, I want to be on that other roof, how long does it take and how
	# hard do I hit. So the drop is what gets measured — 20 m, roughly the tall
	# geometry in this game (the distribution centre's atrium is four storeys).
	var glide := await _descend(tree, goose, 20.0, false)
	_observe("fly.glide_20m_time", glide.x, "s", "seconds to lose 20 m gliding, forward held, no flap")
	_observe("fly.glide_20m_run", glide.y, "m", "horizontal distance covered over that 20 m of descent")
	# ASSERTED AS A REGRESSION GUARD, NOT AS AN ENDORSEMENT.
	#
	# The window is wide and centred on what the game does today, deliberately.
	# It is here to catch `glide_gravity`, `air_speed` or `max_fall` moving
	# without anyone noticing that roof-to-roof traversal moved with them — not
	# to assert that 0.86 : 1 is the RIGHT glide. It is not obviously right:
	# GEEKED_GEESE_DESIGN.md:130 promises "chain it into a safe glide and you're
	# fine", and at roughly one metre forward per metre down there is not much
	# glide to chain into. That question is taste, it changes traversal in eight
	# zone builders, and it is written up as an open decision in
	# docs/FEEL_TARGETS.md §5.1 rather than settled here.
	_assert_window("fly.glide_ratio", glide.y / 20.0, ":1", 0.70, 1.10,
		"metres forward per metre down over a real 20 m drop; this decides roof-to-roof, and the window guards it against silent change (see FEEL_TARGETS.md 5.1)")
	_observe("fly.glide_impact", glide.z, "m/s",
		"arrival speed after a 20 m glide; hard_landing_speed is 13.0, so above that a plain glide lands hard")

	var dive := await _descend(tree, goose, 20.0, true)
	_observe("fly.dive_20m_time", dive.x, "s", "seconds to lose the same 20 m with dive held")
	_assert_window("fly.dive_beats_glide", glide.x / maxf(dive.x, 0.001), "x", 1.15, 4.0,
		"the dive has its own button; if it does not measurably beat falling over a real drop it is not a verb")

	# --- turning in the air, which is deliberately slower than on the ground ---
	await _aloft(tree, goose, 90.0)
	Input.action_press("gg_forward")
	for _i in 60:
		await tree.physics_frame
	var h0: float = float(goose.get("heading"))
	Input.action_release("gg_forward")
	Input.action_press("gg_back")
	var turn_t := 0.0
	for i in 240:
		await tree.physics_frame
		if absf(angle_diff(float(goose.get("heading")), h0)) > PI - deg_to_rad(10.0):
			turn_t = float(i + 1) * TICK
			break
	Input.action_release("gg_back")
	_observe("fly.turn_180", turn_t, "s", "air_turn_rate is 4.2 against the ground's 9.0 — banking, on purpose")


# ---------------------------------------------------------------- stamina

static func _stamina_tests(tree: SceneTree, goose: CharacterBody3D) -> void:
	# How many flaps does a full bar buy, and how long to earn it back? These
	# are the two numbers behind every "when do I spend" decision in flight.
	await _aloft(tree, goose, 200.0)
	goose.set("stamina", 1.0)
	var flaps := 0
	var last_cd := 0.0
	Input.action_press("gg_flap")
	for _i in 900:
		await tree.physics_frame
		var cd: float = float(goose.get("_flap_cd"))
		# A flap is the frame the cooldown gets re-armed from ~0.
		if cd > last_cd + 0.01:
			flaps += 1
		last_cd = cd
		if float(goose.get("stamina")) <= 0.05:
			break
	Input.action_release("gg_flap")
	_assert_window("stam.flaps_to_empty", float(flaps), "flap", 6.0, 24.0,
		"under 6 flaps a bar is not a resource, it is a hiccup; over 24 it is not a constraint at all")

	await _settle(tree, goose)
	goose.set("stamina", 0.0)
	var refill := 0.0
	for i in 900:
		await tree.physics_frame
		if float(goose.get("stamina")) >= 0.99:
			refill = float(i + 1) * TICK
			break
	_assert_window("stam.refill_ground", refill, "s", 1.5, 8.0,
		"this is the length of the pause the game forces on a grounded bird; over 8 s it is a punishment, not a rhythm")


# ---------------------------------------------------------------- latency

static func _latency_tests(tree: SceneTree, goose: CharacterBody3D) -> void:
	# A dose has to LAND. Not how it feels — how many frames before the control
	# mutation the player paid for is actually in Subs.mods.
	await _settle(tree, goose)
	var subs: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Subs")
	if subs == null:
		return
	var res: Resource = subs.call("get_substance", &"bars")
	if res == null:
		return
	subs.call("take", res, 0.6)
	var ticks := -1
	for i in 120:
		await tree.physics_frame
		var m: Dictionary = subs.get("mods")
		var lag: float = m.input_lag
		if lag > 0.001:
			ticks = i + 1
			break
	# -1.0 = the dose never landed at all, which is a different failure from
	# "landed slowly" and has to read differently in the report.
	_assert_window("dose.latency", (float(ticks) if ticks > 0 else -1.0), "tick", 1.0, 12.0,
		"the dose is the game's core verb; more than 12 ticks (0.2 s) between eating and the world changing breaks cause and effect. -1 means it never landed")

	# The camera is the other half of "responsive". Snap the bird sideways and
	# time the rig catching up. Deliberately OBSERVED: the right answer depends
	# on how the shot is framed, which is taste, not physics.
	await _settle(tree, goose)
	var cam: Node3D = goose.get("cam") as Node3D
	if cam == null:
		return
	# A BARE ZERO IS NOT A MEASUREMENT. The first version of this initialised the
	# timer to 0.0 and only wrote it on success, so "never caught up in 300
	# frames" and "caught up instantly" both printed 0.00. -1.0 is the sentinel,
	# and the residual distance is reported alongside so the row says something
	# either way.
	print("[feel] camera rig is %s (parent %s)"
		% [cam.name, cam.get_parent().name if cam.get_parent() != null else "<none>"])
	goose.global_position += Vector3(20.0, 0.0, 0.0)
	var t0 := Time.get_ticks_msec()
	var settle_t := -1.0
	var resid := 0.0
	for _i in 600:
		await tree.process_frame
		resid = cam.global_position.distance_to(goose.global_position)
		if resid < 4.0:
			settle_t = float(Time.get_ticks_msec() - t0) * 0.001
			break
	_observe("cam.catch_up", settle_t, "s",
		"seconds for the rig to get within 4 m of a bird teleported 20 m; -1 means it never did")
	_observe("cam.residual", resid, "m", "rig-to-bird distance when that window closed")


# ---------------------------------------------------------------- helpers

static func angle_diff(a: float, b: float) -> float:
	return wrapf(a - b, -PI, PI)


## Fall `drop` metres from level flight. Returns (seconds, horizontal run, arrival speed).
##
## Deliberately measures a DROP rather than a sink rate: both branches clamp to
## `max_fall`, so any sample taken at terminal velocity compares 34.00 to 34.00
## and reports that the dive button does nothing.
static func _descend(tree: SceneTree, goose: CharacterBody3D, drop: float, diving: bool) -> Vector3:
	await _aloft(tree, goose, 40.0 + drop * 3.0)
	var p0 := goose.global_position
	Input.action_press("gg_forward")
	if diving:
		Input.action_press("gg_dive")
	var secs := 0.0
	var impact := 0.0
	for i in 600:
		await tree.physics_frame
		if p0.y - goose.global_position.y >= drop:
			secs = float(i + 1) * TICK
			impact = -goose.velocity.y
			break
	Input.action_release("gg_forward")
	if diving:
		Input.action_release("gg_dive")
	var run := goose.global_position - p0
	run.y = 0.0
	return Vector3(secs, run.length(), impact)


static func _flat_speed(goose: CharacterBody3D) -> float:
	return Vector2(goose.velocity.x, goose.velocity.z).length()


## Count a tick on which a GROUND measurement was actually measuring water.
static func _watch_dry(goose: CharacterBody3D) -> void:
	if int(goose.get("_water_bodies")) != 0:
		_wet_ticks += 1


# THE LAST SURVIVING HALF OF THE DUPLICATION `probe_common.gd` WAS EXTRACTED TO
# END. `const PAD_RADIUS := 9.0` lived here, was read by nothing but a comment,
# and would have silently disagreed with `COMMON.PAD_RADIUS` the first time
# anyone changed one of them — which is the exact drift that file's own header
# records the two copies already having done once ("one used a named constant
# for the pad radius, the other a bare 9.0"). Deleted rather than kept in sync:
# there is one pad radius and `probe_common.gd` owns it.


static func _settle(tree: SceneTree, goose: CharacterBody3D) -> void:
	COMMON.release_all()
	# Annotated, not inferred: Engine.get_main_loop() is typed MainLoop, which has
	# no `root`, so the whole chain is a Variant and ':=' is a parse error.
	var subs: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Subs")
	if subs != null and subs.has_method("reset_for_new_leg"):
		subs.call("reset_for_new_leg")
	var pad := await COMMON.find_dry_ground(tree, goose, "[feel]")
	# Hand the camera back its auto-follow; _aloft() parks it to pin the stick's
	# world bearing and every measurement starts here.
	var cam0: Node3D = goose.get("cam") as Node3D
	if cam0 != null:
		cam0.set("_manual_t", 0.0)
	goose.global_position = pad
	goose.set("state", 0)          # State.GROUND
	goose.set("stamina", 1.0)
	goose.velocity = Vector3.ZERO
	for _i in 60:
		await tree.physics_frame


## In the air, level, motionless, with `height` metres of clear sky underneath.
##
## Teleporting rather than flying up there is deliberate: every flight metric
## below is about the FLIGHT MODEL, and starting each one from a real takeoff
## would fold the takeoff's launch impulse and whatever the run-up left in the
## horizontal into the number being measured.
static func _aloft(tree: SceneTree, goose: CharacterBody3D, height: float) -> void:
	await _settle(tree, goose)

	# FREEZE THE CAMERA YAW FOR THE WHOLE FLIGHT TEST.
	#
	# `_raw_input()` rotates the stick by -cam.get_yaw(), and the rig auto-follows
	# the direction of travel, so the world bearing "forward" means changes while
	# the bird is flying. That is correct for play and ruinous for measurement:
	# the horizontal glide rows moved 17.36, 17.40 and 19.54 m across three
	# identical runs, which is why they were never promoted out of OBSERVED.
	#
	# `goose_camera.gd` skips its auto-follow branch while `_manual_t` is warm,
	# so parking it pins the yaw. Restored by the next _settle().
	var cam: Node3D = goose.get("cam") as Node3D
	if cam != null:
		cam.set("_manual_t", 9999.0)

	goose.global_position += Vector3.UP * height
	goose.set("state", 2)          # State.FLY
	goose.velocity = Vector3.ZERO
	await tree.physics_frame
	goose.velocity = Vector3.ZERO

