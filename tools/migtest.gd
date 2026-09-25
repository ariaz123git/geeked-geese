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
const COMMON := preload("res://tools/probe_common.gd")

## Physics frames spent with the tree PAUSED while a measurement was running.
static var _paused_ticks := 0


## Advance one measured tick. Returns false if the tree was paused for it, in
## which case the flight did not move and the tick must not be counted.
##
## THE BUG THIS EXISTS BECAUSE OF, and it is the best one of the session.
##
## `migtest` reported a corridor crossing of 4.50 s against a predicted 1.53,
## an effective 5.78 m/s where `_tick_player()` plainly says 17.0. Everything
## checked out: the input vector was exactly (1.0000, 0.0000), Engine.time_scale
## was 1.000 on every frame, physics time and wall clock agreed to 2 ms, and the
## vertical channels measured the same way in the same run were correct to a
## hundredth. It went into HANDOFF as "the top open question in the project".
##
## **The tree was PAUSED.** `_enter_flight()` unpauses once, and a card pauses it
## again behind the harness's back; `migration.gd`'s process_mode is INHERIT, so
## its `_process` — and therefore all of `_tick_player` — simply stops. Holding
## right for a full second from the centre of the corridor moved the bird
## 0.000 m, and the position series read `0.00 0.00 0.00 0.00 0.00 0.00`. The
## 4.50 s was about three seconds of frozen game plus the 1.53 s the arithmetic
## always predicted. 4.50 - 1.53 = 2.97.
##
## The lesson is not "unpause harder", it is that **a measurement must know
## whether the thing it is measuring was running.** So this un-pauses, counts
## the frames it had to, and does not bill them to the game.
static func _tick(tree: SceneTree) -> bool:
	if tree.paused:
		tree.paused = false
		_paused_ticks += 1
		return false
	return true

static var _rows: Array[Dictionary] = []
static var _fails: Array[String] = []


static func run(tree: SceneTree, main: Node) -> void:
	_rows.clear()
	_fails.clear()
	_paused_ticks = 0
	await COMMON.settled(tree)   # probe_common lesson 10: it builds seven flights below

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
	_the_seven_flights(main, mig)

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

	if _paused_ticks > 0:
		print("[mig] %d physics frames were spent PAUSED and were not billed to the flight" % _paused_ticks)
	if _fails.is_empty():
		print("[mig] PASS — %d flight measurements" % _rows.size())
		tree.quit(0)
		return
	print("[mig] FAIL — %d outside their window:" % _fails.size())
	for f in _fails:
		print("[mig]   %s" % f)
	tree.quit(1)


## ═══════════════════════════════════════════════════════════════════════════
## SEVEN FLIGHTS, SEVEN SHAPES — and every one of them built and read back.
## ═══════════════════════════════════════════════════════════════════════════
##
## `migration.gd` had one `TARGET_DISTANCE := 2000.0` and never read the leg, so
## every crossing in the campaign ran 85.3 s at full integrity and rolled the
## same hazards out of the same `randi() % 3`. Half the game was one flight
## served seven times, and no gate could see it: this file measured the flight's
## CONTROLS beautifully and never once asked which flight it was.
##
## Three kinds of check, and the third is the one that would have caught it.
##
##   1. THE TABLE IS WELL FORMED — seven entries, mixes that sum to 1, ordered
##      intervals, durations that are actually different from each other.
##   2. THE TABLE HAS THE SHAPE THE DESIGN ARGUES FOR — flight 1 the quietest
##      and non-lethal, flight 7 the densest, and flight 5 a genuine dip rather
##      than a monotonic ramp.
##   3. EACH LEG'S MIGRATION IS BUILT AND READ BACK. `_ready()` resolves
##      `target_distance` and `_spawn_t` from `Flock.leg`; a build that read the
##      leg at the wrong moment, or ignored it, would pass every check above
##      with the table perfectly correct. So this constructs one migration per
##      leg, reads the two fields the flight's length and opening depend on, and
##      frees it.
##
## Synchronous on purpose: `_ready()` runs inside `add_child()`, and the two
## fields are written there. Nothing here needs a frame, and letting seven
## migrations `_process` concurrently would put seven Camera3Ds in the tree.
static func _the_seven_flights(main: Node, live: Node) -> void:
	var mig_script := load("res://scripts/migration/migration.gd")
	if mig_script == null:
		_fails.append("migration.gd did not load — the flight table could not be read")
		return
	var consts: Dictionary = mig_script.get_script_constant_map()
	var flights: Array = consts.get("FLIGHTS", [])
	var per_sec: float = float(consts.get("DISTANCE_PER_SECOND", 0.0))

	if flights.size() != 7:
		_fails.append("migration.FLIGHTS has %d entries. The route flies seven." % flights.size())
		return
	if per_sec <= 0.0:
		_fails.append("migration.DISTANCE_PER_SECOND is %.3f" % per_sec)
		return

	# ── 1. the table is well formed ──────────────────────────────────────────
	var seconds_seen := {}
	for i in flights.size():
		var f: Dictionary = flights[i]
		var leg_no := i + 1
		var secs: float = float(f.seconds)
		var mix: Dictionary = f.mix
		var total: float = float(mix.wires) + float(mix.turbine) + float(mix.wind)
		var iv: Vector2 = f.interval
		var p: float = float(f.obstacle_p)
		seconds_seen[secs] = true
		if secs <= 0.0:
			_fails.append("flight %d has seconds %.1f" % [leg_no, secs])
		if absf(total - 1.0) > 0.001:
			_fails.append("flight %d's hazard mix sums to %.3f, not 1.0 — the remainder is a hazard that never spawns." % [leg_no, total])
		if iv.x <= 0.0 or iv.y < iv.x:
			_fails.append("flight %d's spawn interval is [%.2f, %.2f]" % [leg_no, iv.x, iv.y])
		if p <= 0.0 or p > 1.0:
			_fails.append("flight %d's obstacle_p is %.2f" % [leg_no, p])
		if float(f.first_spawn) < 0.0 or float(f.first_spawn) >= secs:
			_fails.append("flight %d opens with %.1f s of empty sky against a %.1f s crossing." % [leg_no, float(f.first_spawn), secs])
	if seconds_seen.size() < 6:
		_fails.append("the seven flights use only %d distinct durations. All seven being the same flight is the bug this check exists for." % seconds_seen.size())

	# ── 2. the table has the shape the design argues for ─────────────────────
	#
	# Expected hazards per crossing at integrity 1.0. Spawns are attempted every
	# `interval` seconds after `first_spawn`, and `obstacle_p` of them are
	# hazards rather than thermals:
	#
	#     (seconds - first_spawn) / mean(interval) * obstacle_p
	#
	# This formula reproduces the OLD uniform flight exactly — 85.3 s, [1.1,2.1],
	# 0.62 gives 33.1, and docs/HANDOFF.md §3 recorded "~33 obstacles" for it,
	# which is the corroboration that the arithmetic is right rather than
	# convenient.
	var hazards: Array[float] = []
	for i in flights.size():
		var f2: Dictionary = flights[i]
		var iv2: Vector2 = f2.interval
		var mean_iv: float = (iv2.x + iv2.y) * 0.5
		hazards.append((float(f2.seconds) - float(f2.first_spawn)) / mean_iv * float(f2.obstacle_p))
	print("[mig] hazards per crossing, by flight: %s" % [
		"  ".join(PackedStringArray(hazards.map(func(h: float) -> String: return "%.1f" % h)))])

	if bool(flights[0].lethal):
		_fails.append("flight 1 is LETHAL. CAMPAIGN_SPEC §2.1: \"lethal: false on flight 1 is not a nicety, it is the tutorial.\"")
	for i in range(1, flights.size()):
		if not bool(flights[i].lethal):
			_fails.append("flight %d is non-lethal. Only the tutorial crossing may be." % (i + 1))

	_assert_window("route.hazards_flight1", hazards[0], "n", 2.0, 7.0,
		"ROUTE_DATA §1.3 gives flight 1 one span of wires and frequent thermals — about four hazards in 45 s. More than seven is not a tutorial.")
	_assert_window("route.hazards_flight7", hazards[6], "n", 40.0, 110.0,
		"the Interstate is the climax: 0.9-1.6 s between attempts at 80% hazard over 110 s of live sky.")
	_assert_window("route.escalation", hazards[6] / maxf(hazards[0], 0.01), "x", 8.0, 40.0,
		"how much denser the last crossing is than the first. All seven flights being identical reads as exactly 1.0x here.")
	# The Stopover's dip. `zone_stopover.gd` exists so the back half has one
	# recovery beat; a crossing out of it that is harder than the one into it
	# would spend the beat and give nothing back.
	_assert_window("route.stopover_dip", hazards[4] / maxf(hazards[3], 0.01), "x", 0.20, 0.85,
		"flight 5 leaves the Stopover and must be EASIER than flight 4 into it, or the only rest in the back half is decorative.")
	# NO TWO CONSECUTIVE CROSSINGS MAY SIT IN THE SAME DENSITY BAND.
	#
	# This is the cheapest possible regression guard against "all seven are the
	# same flight" coming back, and it is a stronger statement than the ramp
	# checks above: a table could rise smoothly and still put two neighbouring
	# flights close enough together that a player cannot tell them apart. Lomas
	# et al. (n≈70,000) found engagement tracks NOVELTY and frequency of change
	# rather than raw difficulty, and Valve's intensity-curve practice asks for
	# rising troughs as well as rising peaks. Measured today, the smallest
	# consecutive change is 1.68x (flight 2 -> 3) and the largest is 4.20x
	# (flight 5 -> 6, out of the Stopover dip).
	var tightest := 999.0
	var tightest_at := 0
	for i in range(1, hazards.size()):
		var ratio: float = hazards[i] / maxf(hazards[i - 1], 0.01)
		var change: float = maxf(ratio, 1.0 / maxf(ratio, 0.01))
		if change < tightest:
			tightest = change
			tightest_at = i
	_assert_window("route.tightest_step", tightest, "x", 1.25, 8.00,
		"the smallest density change between consecutive flights (here at flight %d -> %d). Under 1.25x the two crossings are the same crossing; over 8x the run lurches." % [tightest_at, tightest_at + 1])

	if hazards[6] < hazards.max():
		_fails.append("flight 7 is not the densest crossing in the run (%.1f against a peak of %.1f)." % [hazards[6], hazards.max()])
	if hazards[0] > hazards.min():
		_fails.append("flight 1 is not the quietest crossing in the run (%.1f against a floor of %.1f)." % [hazards[0], hazards.min()])

	# ── 3. build each leg's flight and read it back ──────────────────────────
	var was_leg: int = Flock.leg
	var built: PackedStringArray = []
	for leg in range(1, 8):
		Flock.leg = leg
		var m: Node = mig_script.new()
		m.name = "MigProbe%d" % leg
		main.add_child(m)
		var td: float = float(m.get("target_distance"))
		var st: float = float(m.get("_spawn_t"))
		main.remove_child(m)
		m.free()
		var want_f: Dictionary = flights[leg - 1]
		var want_td: float = float(want_f.seconds) * per_sec
		built.append("%.0f" % td)
		if absf(td - want_td) > 0.5:
			_fails.append("the migration built at leg %d has target_distance %.1f, and its FLIGHTS entry asks for %.1f (%.0f s x %.2f m/s). _ready() is not resolving the leg." % [leg, td, want_td, float(want_f.seconds), per_sec])
		if absf(st - float(want_f.first_spawn)) > 0.01:
			_fails.append("the migration built at leg %d opens its spawn clock at %.2f s, not the %.2f its FLIGHTS entry asks for." % [leg, st, float(want_f.first_spawn)])
	Flock.leg = was_leg
	print("[mig] target_distance by leg, off the built node: %s" % [" ".join(built)])

	# And the flight the harness actually flew, which is the one thing above
	# that was not constructed by this file.
	var live_td: float = float(live.get("target_distance"))
	var live_want: float = float(flights[clampi(was_leg - 1, 0, 6)].seconds) * per_sec
	if absf(live_td - live_want) > 0.5:
		_fails.append("the LIVE flight (leg %d, built by main) has target_distance %.1f against the %.1f its leg asks for." % [was_leg, live_td, live_want])


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
	var x0: float = float((mig.get("player_pos") as Vector3).x)
	Input.action_press("gg_right")
	for _i in 400:
		await tree.physics_frame
		if _tick(tree):
			t += TICK
		var now: Vector3 = mig.get("player_pos")
		if now.x >= corridor - 0.05:
			break
	Input.action_release("gg_right")
	var x1: float = float((mig.get("player_pos") as Vector3).x)
	print("[mig] lateral: %.2f m in %.2f s -> %.2f m/s (the code says 17.0)"
		% [x1 - x0, t, (x1 - x0) / maxf(t, 0.001)])

	# ASSERTED. These were OBSERVED for exactly one commit, while the 4.50 s
	# crossing was unexplained; the cause turned out to be the tree pausing
	# mid-measurement (see _tick()), and with the paused frames no longer billed
	# to the game the measurement lands on the 1.53 s the constants predict.
	# WHAT FOLLOWS IS THE ARGUMENT FOR THE WINDOWS, WHICH IS UNCHANGED.
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
	_assert_window("lateral.full_cross", t, "s", 1.1, 2.4,
		"edge to edge of the corridor. Under 1.1 s the whole lane is dodgeable inside one hazard gap and the corridor stops being a commitment; over 2.4 s even a half crossing misses leg 7's tightest gap")

	# THE HALF CROSSING IS MEASURED, FROM THE CENTRE, NOT DIVIDED.
	#
	# It used to be `t * 0.5` — the full crossing halved — and its window
	# [0.45, 1.20] contains every half of the full window [1.10, 2.40], so it
	# could not fail unless `full_cross` failed first. HANDOFF §4 carried that as
	# the last unaddressed gate gap. Half is only half with no lateral
	# acceleration, a centred corridor and a symmetric clamp; `_tick_player()`
	# has all three today (17.0 m/s straight onto `player_pos.x`), and this is
	# what notices the day one of them changes. It is also the manoeuvre the
	# flight is actually played with.
	_release_all()
	var ph: Vector3 = mig.get("player_pos")
	ph.x = 0.0
	mig.set("player_pos", ph)
	for _i2 in 4:
		await tree.physics_frame
	var th := 0.0
	Input.action_press("gg_right")
	for _i3 in 400:
		await tree.physics_frame
		if _tick(tree):
			th += TICK
		var now2: Vector3 = mig.get("player_pos")
		if now2.x >= corridor - 0.05:
			break
	Input.action_release("gg_right")
	print("[mig] lateral: centre to edge in %.2f s (half the full crossing would be %.2f)" % [th, t * 0.5])
	_assert_window("lateral.half_cross", th, "s", 0.45, 1.2,
		"centre to edge — the manoeuvre that MUST fit inside leg 7's tightest 0.9 s hazard gap, and the one the flight is actually played with")


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
		if _tick(tree):
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
		if _tick(tree):
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
	#
	# RETAKEN IF A WIRE HITS IT. The flight runs its real hazard logic while this
	# measures, and `_check_obstacle()` answers a wire strike with
	# `player_pos.y -= 3.0` in a single frame. One run read a sink of 4.60 m/s,
	# which is the honest 1.60 plus exactly that 3.00 — the bird clipped a wire
	# mid-measurement and the gate billed it as a controller property.
	#
	# A strike is a step, not a slope: gravity moves the bird 1.6/60 = 0.027 m in
	# a frame and a wire moves it 3.0. Anything past half a metre in one frame is
	# the world, not the sink, so that attempt is thrown away and retaken.
	_release_all()
	var sink := 0.0
	var sink_attempts := 0
	while sink_attempts < 4:
		sink_attempts += 1
		var p2: Vector3 = mig.get("player_pos")
		p2.y = (y_min + y_max) * 0.5
		mig.set("player_pos", p2)
		var y0: float = p2.y
		var prev_y := y0
		var struck := false
		for _i in 60:
			await tree.physics_frame
			var yn: float = float((mig.get("player_pos") as Vector3).y)
			if absf(yn - prev_y) > 0.5:
				struck = true
			prev_y = yn
			if not _tick(tree):
				struck = true
		sink = y0 - prev_y
		if not struck:
			break
		print("[mig] idle-sink attempt %d hit something (sank %.2f m) — retaking" % [sink_attempts, sink])

	_assert_window("vertical.idle_sink", sink, "m/s", 0.4, 4.0,
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
			# THE FLIGHT'S OWN FIRST-RUN CARD IS UP BY NOW, and the close above
			# ran before it existed: `_load_migration()` builds the flight and
			# then awaits `_brief_flight()`, which presents the card in the same
			# continuation. This file only ever passed because the save on the
			# machine that ran it said the card had been seen. Made hermetic
			# (2026-09-25), it spent 1241 physics frames behind the card and
			# measured every channel of the flight at 0.00.
			if briefing != null and is_instance_valid(briefing) and briefing.has_method("force_close"):
				briefing.force_close()
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
