extends RefCounted
## THE SUBSTANCE GATE — the seventh, and the one that checks the design rule.
##
## `scripts/core/substance.gd` opens with the rule the whole game is built on:
##
##   > "a substance must never be only a number that goes up. Every entry here
##   > must include at least one CONTROL MUTATION — something that changes how
##   > the player's hands work. If you find yourself adding a substance that
##   > only edits speed_mult, delete it."
##
## `tools/selftest.gd` already enforces that rule — **by reading the `.tres`.**
## It checks that each substance sets at least one key from its `CONTROL_KEYS`
## list. That is a check on the DATA, and it is worth having, but it cannot tell
## you that the mutation reaches the bird. A field can be set to the right
## number and still do nothing: aggregated wrong in `_aggregate()`, read under a
## different name in the controller, cancelled by a clamp, or scaled to nothing
## by `resolve()`.
##
## THE PRECEDENT IS EXACT AND EXPENSIVE. The input-lag buffer bug made ELEVEN OF
## THE SIXTEEN substances unplayable — a four-second delay where 0.10 to 0.28
## was asked for — and every `.tres` involved was correct the whole time. The
## data said one thing, the bird did another, and no gate in the project
## compared them. This one does: it doses each substance and MEASURES the bird.
##
##     godot --headless --path . -- --probe --substancetest 2>&1 | grep '^\[subs\]'
##
## WHAT IT ASSERTS, per substance, and it is deliberately stronger than "the
## bird moved differently":
##
##   1. Every motion-observable mutation the `.tres` declares must show up in
##      the channel that mutation drives, **in the predicted direction.** Faster
##      turning must measure as faster turning. A `flap_mult` under 1 must lower
##      the climb. Wrong-signed and zeroed fields are the bug this catches.
##   2. A substance whose only control mutations change the WORLD rather than
##      the hands is exempt, must be named in EXEMPT with a reason, and the
##      reason is printed on every run so the exemption cannot rot quietly.
##
## `speed_mult` IS NOT EVIDENCE and is deliberately not one of the channels a
## substance can satisfy this gate with. It is one of the two keys
## `selftest.gd`'s own comment calls "the two the design rule at the top of
## scripts/core/substance.gd exists to forbid". A thing that only makes you
## faster is the number that goes up.

const COMMON := preload("res://tools/probe_common.gd")

const TICK := 1.0 / 60.0

## The dose every measurement uses. Inside the sweet band of every substance in
## the shelf, so `resolve()` returns quality 1.0 and the numbers below are the
## substance at its stated strength rather than at some partial dose.
const DOSE := 0.6

## Smallest change in `turn_mult` the 180-degree measurement can honestly tell
## from noise. Anything under this is printed and not asserted; see _one().
const TURN_RESOLUTION := 0.10

## How far the measured one-flap climb ratio may sit from the predicted one.
## Generous because the brain chemistry is still easing toward its target while
## the flap fires, so `power` is sampled a frame before it is used.
const CLIMB_TOL := 0.18

## How far the measured peak-turn-rate ratio may sit from the declared
## `turn_mult`. Wider than CLIMB_TOL because the peak is a single frame's
## angular step and input lag moves which frame that is.
const TURN_TOL := 0.25

## How far the bird may stray from the pad during the walk channel before it is
## snapped back. Comfortably inside `probe_common.PAD_RADIUS` (9.0), because the
## turn channel that follows starts from wherever the walk left off and travels
## the other way. See the leash argument in `_fingerprint()`.
const LEASH := 6.0


## Substances whose only control mutation changes the WORLD, not the hands, and
## which therefore cannot be seen by a controller measurement. Each one needs a
## reason, and the reason is printed on every run.
##
## THIS DICTIONARY IS THE DANGEROUS PART OF THIS FILE. It is an allowlist, and
## an allowlist is how a real failure gets reclassified as an expected one. A
## substance goes in here only when its mutation is genuinely somewhere else in
## the game, never because the measurement was inconvenient to write.
## IT IS CURRENTLY EMPTY, AND THAT IS WHERE AN ALLOWLIST SHOULD BE.
##
## Catnip was the one entry. Its only control mutation is `aggro_cats` — the
## cats in the zone come for you — which no measurement of the GOOSE can see,
## and its `speed_mult` of 1.06 is emphatically not what makes it legal under
## the design rule; a +6% walk is the number-that-goes-up the rule forbids.
##
## The exemption was honest and it was also an admission: this file said, in as
## many words, that if `aggro_cats` stopped working nothing in the project would
## notice. So rather than keep the admission, `_the_cats()` below measures the
## CATS instead of the goose, and catnip is asserted like everything else.
const EXEMPT := {}

static var _fails: Array[String] = []
static var _checks := 0


static func run(tree: SceneTree, main: Node) -> void:
	_fails.clear()
	_checks = 0
	COMMON.reset()

	var goose: CharacterBody3D = await COMMON.fresh_goose(tree, main)
	if goose == null:
		print("[subs] FAIL — no goose in the zone")
		tree.quit(1)
		return
	var subs: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Subs")
	if subs == null:
		print("[subs] FAIL — no Subs autoload")
		tree.quit(1)
		return

	# THE NOISE FLOOR, MEASURED, NOT ASSUMED. Sober twice. Every threshold below
	# has to clear the difference between two runs of the same thing, or the
	# gate is reporting its own jitter as a substance effect.
	var sober := await _fingerprint(tree, goose, subs)
	var sober2 := await _fingerprint(tree, goose, subs)
	# THE PRECONDITION, ASSERTED DIRECTLY. `_fingerprint()` counts the frames the
	# bird spent in State.WATER during the two ground channels; the ground model
	# is the only thing those channels are allowed to be measuring.
	_wet_check("sober", sober)
	_wet_check("repeat", sober2)
	print("[subs] sober   speed %.2f m/s  offaxis %.3f rad  turnrate %.2f rad/s  climb %.2f m"
		% [sober.speed, sober.offaxis, sober.turnrate, sober.climb])
	print("[subs] repeat  speed %.2f m/s  offaxis %.3f rad  turnrate %.2f rad/s  climb %.2f m"
		% [sober2.speed, sober2.offaxis, sober2.turnrate, sober2.climb])
	var noise := {
		"speed": absf(sober2.speed - sober.speed),
		"offaxis": absf(sober2.offaxis - sober.offaxis),
		"turnrate": absf(sober2.turnrate - sober.turnrate),
		"climb": absf(sober2.climb - sober.climb),
	}
	print("[subs] noise   speed %.3f m/s  offaxis %.3f rad  turnrate %.3f rad/s  climb %.3f m"
		% [noise.speed, noise.offaxis, noise.turnrate, noise.climb])
	# A NOISE FLOOR IS ONLY USEFUL IF SOMETHING CHECKS IT. Every threshold below
	# is built from these; if the harness itself is jittering, the thresholds it
	# derives are meaningless and it must say so rather than quietly widening.
	noise["ok"] = (float(noise.offaxis) < 0.05 and float(noise.turnrate) < 1.5
		and float(noise.climb) < 0.05)
	_ok(bool(noise.ok),
		("the harness does not agree with itself between two SOBER runs (offaxis %.3f, turnrate "
		+ "%.3f, climb %.3f). Every threshold below is derived from this floor, so nothing it "
		+ "reports about a substance can be trusted. Fix the measurement, not the substances.")
			% [noise.offaxis, noise.turnrate, noise.climb])
	# AND THEN IT HAS TO ACT ON WHAT IT JUST SAID.
	#
	# This file used to print the sentence above and then run every ratio check
	# anyway. On 2026-08-18 that turned ONE harness fault into EIGHT failures:
	# the first sober fingerprint had waded into leg 1's pond and measured
	# `swim_speed`, so the sober turn rate came back 0.7x low, and seven
	# substances — berries, bars, fly_agaric, molly, grass, nitrous and
	# double_double — were each accused of a broken `turn_mult` for being
	# exactly 1/0.7 = 1.43x out. Every one of those numbers was the pond.
	#
	# `probe_common._drop()` has the fix for the cause. This is the second wall:
	# the two channels that DIVIDE BY SOBER go quiet when sober is not
	# reproducible, and every channel that stands on its own — drift, the
	# macropsia pulse, `cannot_idle`, the clock, the cats — keeps running. The
	# build still fails, on the one line that is true.
	if not bool(noise.ok):
		print("[subs] SUPPRESSED for every substance below: peak turn rate and one-flap climb. "
			+ "Both are ratios against a sober baseline this harness has just said it cannot "
			+ "reproduce, so both would report the harness's own jitter as a broken substance. "
			+ "Nothing printed below is evidence about a substance.")

	var ids: Array = subs.library.keys()
	ids.sort()
	print("[subs] %d substances in the shelf" % ids.size())

	for id: StringName in ids:
		var res: Substance = subs.library[id]
		if res == null:
			_ok(false, "%s is in the library as null" % id)
			continue
		await _one(tree, goose, subs, res, sober, noise)

	if _fails.is_empty():
		print("[subs] PASS — %d checks across %d substances" % [_checks, ids.size()])
		tree.quit(0)
		return
	print("[subs] FAIL — %d of %d checks:" % [_fails.size(), _checks])
	for f in _fails:
		print("[subs]   %s" % f)
	tree.quit(1)


static func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_fails.append(msg)


## THE WALK TEST HAS TO HAVE BEEN A WALK.
##
## Named as a HARNESS fault in as many words, because that is what it is and
## because this project's four measuring gates spent most of their first runs
## accusing a healthy game. `probe_common.find_dry_ground()` certifies the pad;
## this is the receipt that the certificate was good on the day.
static func _wet_check(who: String, fp: Dictionary) -> void:
	_ok(int(fp.wet) == 0,
		("HARNESS FAULT — the %s fingerprint spent %d of its 170 ground frames in State.WATER. "
		+ "The walk and turn channels measure `swim_speed` (5.4) and `turn_rate * 0.7` in that "
		+ "state instead of `waddle_speed` (4.2) and `turn_rate`, so this baseline is a "
		+ "measurement of a different model and every ratio derived from it is wrong by 1/0.7. "
		+ "The pad `probe_common.find_dry_ground()` chose is not dry across the ground the walk "
		+ "covers. Fix the pad, not the substances.") % [who, int(fp.wet)])


# ---------------------------------------------------------------- one substance

static func _one(tree: SceneTree, goose: CharacterBody3D, subs: Node,
		res: Substance, sober: Dictionary, noise: Dictionary) -> void:
	var id: StringName = res.id

	# What does this substance CLAIM, once resolve() has scaled it for the dose?
	# Read the resolved values, not the raw exports: `resolve()` is where dose
	# quality and tolerance are applied, and it is the resolved dictionary the
	# aggregator and then the controller actually see.
	var r: Dictionary = res.resolve(DOSE, 0)

	var want_turn: float = float(r.turn_mult)
	var want_flap: float = float(r.flap_mult)
	var want_grav: float = float(r.gravity_mult)
	var want_tscale: float = float(r.time_scale)
	var want_scale: bool = float(r.scale_amp) > 0.05
	var want_idle: bool = bool(r.cannot_idle)
	var want_cats: bool = bool(r.aggro_cats)
	var needs_climb: bool = not is_equal_approx(want_flap, 1.0) or not is_equal_approx(want_grav, 1.0)

	var observable := (float(r.drift) > 0.001 or not is_equal_approx(want_turn, 1.0) or needs_climb
		or not is_equal_approx(want_tscale, 1.0) or want_scale or want_idle
		or float(r.input_lag) > 0.001 or bool(r.grid_snap) or want_cats)

	# 1. THE DESIGN RULE ITSELF.
	if EXEMPT.has(id):
		var why: String = EXEMPT[id]
		print("[subs] %-14s EXEMPT — %s" % [id, why])
		_ok(not observable,
			("%s is in EXEMPT but DOES have a motion-observable mutation. The exemption is "
			+ "stale and is now hiding a real measurement. Remove it from EXEMPT.") % id)
		return
	_ok(observable,
		("%s declares no motion-observable control mutation at all. Either it violates the "
		+ "design rule at the top of scripts/core/substance.gd (a substance must never be only "
		+ "a number that goes up), or its mutation is a world mutation and it belongs in EXEMPT "
		+ "with a written reason.") % id)
	if not observable:
		return

	# 2. DOSE IT AND MEASURE THE BIRD.
	await _sober_up(tree, goose, subs)
	var took: bool = bool(subs.take(res, DOSE))
	_ok(took, "%s: Subs.take() refused a %.2f dose on a clean slate" % [id, DOSE])
	if not took:
		return
	for _i in 40:
		await tree.physics_frame
	# One substance at a time, or this is measuring a combo. Three at once rolls
	# the bad table and would black the bird out mid-measurement.
	var actives: Array = subs.actives
	_ok(actives.size() == 1,
		"%s: %d substances active during its measurement — a previous dose leaked" % [id, actives.size()])

	var fp := await _fingerprint(tree, goose, subs)

	print("[subs] %-14s speed %5.2f  drift %.3f (%.3f rad off)  turnrate %5.2f  climb %5.2f"
		% [id, fp.speed, fp.driftmag, fp.offaxis, fp.turnrate, fp.climb])
	_wet_check(String(id), fp)

	# THE MEASUREMENT IS ONLY VALID IF THE SUBSTANCE WAS STILL ON THE BIRD.
	#
	# Nitrous lasts 7.0 s and darts 8.0. An earlier fingerprint took 12.2 s of
	# game time, so those two expired part way through and the leftovers were
	# reported as the substance failing -- nitrous "declared time_scale 0.40 but
	# Engine.time_scale is 1.000", which was Subs correctly restoring a clock
	# after a substance that had legitimately ended. Never infer from a
	# measurement taken after the thing being measured stopped existing.
	_ok(bool(subs.call("is_active", id)),
		("%s wore off DURING its own measurement (duration %.0f s). Every channel above is "
		+ "partly or wholly sober. This is a HARNESS fault: shorten _fingerprint() until it "
		+ "fits inside the shortest substance in the shelf.") % [id, res.duration])

	# 3. EVERY DECLARED MUTATION MUST SHOW UP, IN THE RIGHT DIRECTION.

	if float(r.drift) > 0.001:
		# Gated on the drift VECTOR, which is deterministic. The off-axis ANGLE
		# it produced is printed beside it as black-box corroboration, but it is
		# far too phase-dependent to fail a build on -- see _fingerprint().
		_ok(float(fp.driftmag) > float(r.drift) * 0.15,
			("%s declares drift %.2f but the largest drift vector the controller computed all "
			+ "measurement was %.4f. It is not reaching _wanted(); check the .tres, resolve(), "
			+ "and the `m.drift += r.drift` line in _aggregate().")
				% [id, float(r.drift), fp.driftmag])

	# ONLY ASSERT WHAT THE INSTRUMENT CAN RESOLVE.
	#
	# Darts declares turn_mult 1.05. That is a 5% change against a turn time of
	# 0.28 s -- under a single physics frame, and inside the run-to-run noise.
	# Asserting it would be asserting past the resolution of the measurement,
	# which produces a check that fails for reasons unrelated to the thing it
	# names. Darts is covered anyway: its flap_mult of 1.12 puts its climb 68%
	# above sober, which is enormous.
	if absf(want_turn - 1.0) > TURN_RESOLUTION and bool(noise.ok):
		# `_face()` moves the heading by error * turn_rate * turn_mult * delta, so
		# the peak rate just after the stick reverses scales with turn_mult
		# directly. Asserted as a ratio against sober rather than as a direction.
		var got_turn: float = float(fp.turnrate) / maxf(float(sober.turnrate), 0.001)
		_ok(absf(got_turn - want_turn) <= maxf(TURN_TOL, want_turn * TURN_TOL),
			("%s declares turn_mult %.2f, so its peak turn rate should be %.2fx sober, but "
			+ "measured %.2fx -- %.2f rad/s against %.2f.")
				% [id, want_turn, want_turn, got_turn, fp.turnrate, sober.turnrate])
	elif not is_equal_approx(want_turn, 1.0) and absf(want_turn - 1.0) <= TURN_RESOLUTION:
		print("[subs]   %s turn_mult %.2f is under the %.0f%% the turn measurement resolves; not asserted"
			% [id, want_turn, TURN_RESOLUTION * 100.0])

	if needs_climb and bool(noise.ok):
		# ONE FLAP'S PEAK CLIMB IS power^2 / (2 * glide_gravity * gravity_mult),
		# and `power` is flap_impulse * flap_mult * (0.75 + 0.5 * adrenaline).
		# So the predicted ratio against sober is
		#
		#     (flap_mult * power_now / power_sober)^2 / gravity_mult
		#
		# and it is asserted as a RATIO rather than a direction. That is a much
		# stronger claim than "it went up": it says the flight model, the
		# substance data and the brain chemistry all agree to within a tolerance,
		# and it caught nothing but its own earlier omission -- every one of the
		# sixteen matches its prediction.
		var pf: float = float(fp.power) / maxf(float(sober.power), 0.001)
		var expect: float = (want_flap * pf) * (want_flap * pf) / maxf(want_grav, 0.01)
		var got: float = float(fp.climb) / maxf(float(sober.climb), 0.001)
		_ok(absf(got - expect) <= maxf(CLIMB_TOL, expect * CLIMB_TOL),
			("%s: one flap should climb %.2fx sober (flap_mult %.2f, gravity_mult %.2f, "
			+ "adrenaline putting flap power at %.2fx) but measured %.2fx -- %.2f m against "
			+ "%.2f m.") % [id, expect, want_flap, want_grav, pf, got, fp.climb, sober.climb])

	if not is_equal_approx(want_tscale, 1.0):
		# Subs eases Engine.time_scale toward the target rather than snapping, so
		# this asserts it has MOVED that way, not that it has arrived.
		var ts := Engine.time_scale
		_ok(ts < 0.99,
			("%s declares time_scale %.2f but Engine.time_scale is %.3f. Either Subs is not "
			+ "driving the clock or Juice is fighting it — they have a documented contract and "
			+ "this is what breaks when a third owner appears.") % [id, want_tscale, ts])

	if want_scale:
		_ok(fp.size > 0.04,
			("%s declares scale_amp %.2f but the bird's size never moved more than %.3f from 1.0. "
			+ "The macropsia pulse is not reaching _tick_size().") % [id, float(r.scale_amp), fp.size])

	if want_idle:
		_ok(fp.idle > 0.80,
			("%s declares cannot_idle but the bird travelled only %.2f m of PATH in 1.2 s of NO "
			+ "input. Letting go is supposed to not stop you.") % [id, fp.idle])

	if want_cats:
		await _the_cats(tree, subs, res)

	await _sober_up(tree, goose, subs)


## THE ONE MUTATION THAT IS NOT ABOUT THE GOOSE.
##
## `aggro_cats` is catnip's entire reason to exist, and it changes the WORLD:
## `cat.gd::_physics_process` reads `Subs.mods.aggro_cats` and flips the cat into
## `_frenzy`, at which point it hunts at FRENZY_SPEED instead of wandering at
## WANDER_SPEED. Nothing about the bird changes, so the fingerprint above is
## blind to it and this file used to say so and give up.
##
## `responds_to_nip` is rolled at random per cat (`randf() < 0.67`), and
## `cat.gd`'s own comment says the flag is there to be set deliberately before
## `add_child()`. Setting it here makes the check deterministic rather than
## leaving a one-in-2500 chance that all seven cats in leg 1 shrug.
static func _the_cats(tree: SceneTree, subs: Node, res: Substance) -> void:
	var cats := tree.get_nodes_in_group("cat")
	_ok(not cats.is_empty(),
		("%s's only control mutation is aggro_cats and there are no cats in the zone, so it "
		+ "cannot be checked at all. Leg 1 builds seven; if that changed, this gate went blind.")
			% res.id)
	if cats.is_empty():
		return

	subs.call("reset_for_new_leg")
	for c in cats:
		c.set("responds_to_nip", true)
	for _i in 8:
		await tree.physics_frame

	var before := 0
	for c in cats:
		if bool(c.get("_frenzy")):
			before += 1
	_ok(before == 0, "%d of %d cats were already in a frenzy before the catnip landed" % [before, cats.size()])

	subs.call("take", res, DOSE)
	for _i in 12:
		await tree.physics_frame
	var during := 0
	for c in cats:
		if bool(c.get("_frenzy")):
			during += 1
	print("[subs] %-14s cats in frenzy %d of %d" % [res.id, during, cats.size()])
	_ok(during == cats.size(),
		("%s declares aggro_cats but only %d of %d cats went into a frenzy. Subs.mods.aggro_cats "
		+ "is not reaching cat.gd.") % [res.id, during, cats.size()])

	# AND IT HAS TO LET GO AGAIN. `cat.gd` clears `_frenzy` on the `elif not nip
	# and _frenzy` branch; a cat that stays frenzied after the catnip ends is a
	# zone that never calms down.
	subs.call("reset_for_new_leg")
	for _i in 8:
		await tree.physics_frame
	var after := 0
	for c in cats:
		if bool(c.get("_frenzy")):
			after += 1
	_ok(after == 0,
		("%d of %d cats stayed in a frenzy after the catnip was cleared. The zone never calms "
		+ "down.") % [after, cats.size()])


# ---------------------------------------------------------------- measurement

## THE WHOLE FINGERPRINT MUST FIT INSIDE THE SHORTEST SUBSTANCE.
##
## Nitrous lasts 7.0 seconds and darts 8.0. The first version of this function
## took 12.2 seconds of game time, so those two — and special_k at 12.0 —
## WORE OFF PART WAY THROUGH THEIR OWN MEASUREMENT, and the leftovers were duly
## reported as the substance being broken. Nitrous "declared time_scale 0.40 but
## Engine.time_scale is 1.000": it had expired, and Subs had correctly eased the
## clock back to normal.
##
## Everything below is one continuous sequence with no re-settling between
## channels, and it is budgeted at about 235 physics frames — 3.9 s of game time
## at time_scale 1.0, and less than that on anything that slows the clock, since
## a slower clock spends the duration slower too. `active` is returned so the
## caller can prove the substance was still on the bird when the last channel
## was read, rather than assuming it.
static func _fingerprint(tree: SceneTree, goose: CharacterBody3D, subs: Node) -> Dictionary:
	var out := {
		"speed": 0.0, "offaxis": 0.0, "driftmag": 0.0, "turnrate": 0.0,
		"climb": 0.0, "size": 0.0, "idle": 0.0, "power": 1.0, "active": true,
		"wet": 0,
	}
	var cam: Node3D = goose.get("cam") as Node3D

	await _reset(tree, goose)

	# --- hold forward: peak speed, body scale, and how far off the commanded
	#     bearing the bird actually travels ---
	# FREEZE THE CAMERA, OR THE STICK HAS NO FIXED BEARING.
	#
	# `goose_camera.gd` auto-follows the direction of travel unless `_manual_t`
	# is warm, and `_raw_input()` rotates the stick by -cam.get_yaw(). So the
	# world bearing the player is commanding ROTATES while the bird flies, and
	# the bird's velocity chases a moving target. Two SOBER runs of the off-axis
	# measurement returned 0.000 and 0.635 rad on that basis alone -- a noise
	# floor wider than the effect being measured.
	#
	# Parking `_manual_t` takes the auto-follow branch out and pins the yaw for
	# the whole hold, which makes "the bearing the stick asked for" a fixed
	# vector that drift can be measured against.
	if cam != null:
		cam.set("_manual_t", 9999.0)

	# A LEASH, BECAUSE THE FASTEST SUBSTANCE OUTRUNS THE PAD.
	#
	# `probe_common.PAD_RADIUS` is 9 m and its docstring sizes it for the walk in
	# `feeltest.gd`: "1.2 s of held forward at `waddle_speed` covers about 5 m."
	# THIS walk is 2.0 s and it is not at `waddle_speed`. `math` resolves to
	# speed_mult 1.90 and measures 9.75 m/s, which is **18.5 m** — twice the pad.
	# `fly_agaric` (11.8 m) and `double_double` (11.4 m) also clear it.
	#
	# On leg 1 the certified pad sits 21.5 m from the retention pond's centre
	# against an 11 m radius, so there are 10.5 m of grass and the pond subtends
	# 31° either side. Three substances can reach it and the bearing is whatever
	# yaw the camera was pinned at, so it is a coin toss: measured **two failures
	# in five runs**, which is close to the ~40% that geometry predicts.
	#
	# Extending PAD_RADIUS is the wrong fix — a 20 m clear ring may simply not
	# exist in a zone, and a harness that fails on level design is a harness
	# nobody keeps. Shortening the hold is also wrong: drift is a ~4 s sine and
	# needs the full window.
	#
	# So the bird is snapped back whenever it strays, WITH ITS VELOCITY INTACT.
	# Every channel this loop measures is velocity- or controller-derived — peak
	# speed, the angle between velocity and the commanded bearing, and `_drift`,
	# which `_wanted()` computes whether the bird moves or not. **Not one of them
	# reads position**, so the leash is invisible to all three. The idle channel
	# below is deliberately NOT leashed: it measures PATH LENGTH, and a teleport
	# would be summed straight into it as several metres of travel.
	var leash := goose.global_position

	Input.action_press("gg_forward")
	# 120 frames, not 60. Drift is a sine of period ~4 s (see below); a one
	# second window can land on one of its zero crossings and see nothing at all.
	# Two seconds is half a period and always catches some of the excursion.
	for i in 120:
		await tree.physics_frame
		if Vector2(goose.global_position.x - leash.x, goose.global_position.z - leash.z).length() > LEASH:
			var carry := goose.velocity
			goose.global_position = leash
			goose.velocity = carry
		# DID THE BIRD GO SWIMMING WHILE WE MEASURED ITS WALK?
		#
		# `tools/feeltest.gd` has counted exactly this since it was written —
		# `_watch_dry()` and `_wet_ticks` — and its own comment says the omission
		# "happened, and it turned verify.ps1 red". THIS FILE NEVER GOT IT, and
		# on 2026-08-18 it went red the same way, in the same zone, for the same
		# reason. Two harnesses over one controller, and only one was watching.
		#
		# It is the direct form of a question this file could otherwise only ask
		# by taking the baseline twice and noticing the two disagreed — which
		# works, but reports the SYMPTOM. It reported that symptom as SEVEN
		# substances with a broken `turn_mult`, because a contaminated sober
		# baseline divides into every ratio below.
		#
		# State.WATER swaps `waddle_speed` (4.2) for `swim_speed` (5.4) and the
		# turn rate for `turn_rate * 0.7`, so every ground channel here silently
		# becomes a measurement of a different model. One frame of it is a
		# harness fault, and this counts them. The cause was one line in
		# `probe_common.find_dry_ground()`; see `probe_common._drop()`.
		if int(goose.get("_water_bodies")) != 0:
			out.wet = int(out.wet) + 1
		out.size = maxf(float(out.size), absf(float(goose.get("size")) - 1.0))
		var v := Vector2(goose.velocity.x, goose.velocity.z)
		out.speed = maxf(float(out.speed), v.length())

		# DRIFT IS A BIAS OVER THIS WINDOW, NOT A WOBBLE.
		#
		# `_wanted()` builds drift from sines of `Time.get_ticks_msec() * 0.0009`,
		# so its slowest term has a period of about 4 seconds. Across a one
		# second sample it barely moves: it pushes the bird consistently off to
		# one side rather than shaking it. An earlier version measured the spread
		# of the heading about its own mean, which is exactly the statistic that
		# cancels a constant bias — gravy, which has the HIGHEST drift in the
		# game at 0.50, scored the lowest wander of any substance.
		#
		# So measure the bias directly: the angle between where the stick is
		# pointing and where the bird is actually going. The stick is
		# camera-relative (`_raw_input()` rotates it by -cam.get_yaw()) and the
		# camera turns as the bird does, so the commanded bearing is recomputed
		# every frame rather than assumed.
		if i >= 30 and v.length() > 1.0 and cam != null:
			var yaw: float = float(cam.call("get_yaw"))
			var want := Vector2(0.0, -1.0).rotated(-yaw)
			out.offaxis = maxf(float(out.offaxis), absf(v.angle_to(want)))

		# AND THE DRIFT VECTOR ITSELF, WHICH IS THE DETERMINISTIC ONE.
		#
		# `_wanted()` builds `_drift` from sines whose phase rides on
		# `Time.get_ticks_msec()`, seeded per goose by an unseeded `randf()`.
		# So HOW FAR off the bearing the bird ends up in any two-second window
		# is genuinely random: measured off-axis for percs ranged 0.15 to 0.99
		# rad across runs, and gating on it failed about one run in seven. A
		# gate that is usually green is not a gate.
		#
		# `_drift` is computed and then added to the stick on the very next
		# line of `_wanted()`, so a non-zero magnitude here IS the aggregation
		# path working: .tres -> resolve() -> mods.drift -> _wanted(). It does
		# not wander, so it can be asserted, and it resolves far smaller drifts
		# than the off-axis angle can — every substance that declares any drift
		# at all is now covered instead of only the five biggest.
		var dv: Vector2 = goose.get("_drift")
		out.driftmag = maxf(float(out.driftmag), dv.length())

	# --- reverse the stick: peak turn rate ---
	#
	# NOT time-to-180-degrees, which is not a well defined quantity here. The
	# stick is camera-relative and the camera yaw chases the bird's direction of
	# travel, so as the bird comes about, "back" comes about with it: the target
	# runs away from the turn. Two SOBER runs of that measurement returned 5.65 s
	# and 0.20 s, and the harness's own noise check refused the whole report.
	#
	# `_face()` moves the heading by `error * turn_rate * turn_mult * delta`, so
	# the peak rate right after the stick flips — while the error is still near
	# PI — is proportional to `turn_mult` and nothing else. It is over in a
	# tenth of a second, long before the camera can follow.
	Input.action_release("gg_forward")
	Input.action_press("gg_back")
	var prev: float = float(goose.get("heading"))
	for _i in 50:
		await tree.physics_frame
		if int(goose.get("_water_bodies")) != 0:  # see the walk loop
			out.wet = int(out.wet) + 1
		var h: float = float(goose.get("heading"))
		var d: float = goose.get_physics_process_delta_time()
		if d > 0.0001:
			out.turnrate = maxf(float(out.turnrate), absf(wrapf(h - prev, -PI, PI)) / d)
		prev = h
	Input.action_release("gg_back")
	if cam != null:
		cam.set("_manual_t", 0.0)

	# --- let go: does it stop? ---
	# SAMPLED ACROSS A FULL PERIOD OF THE DRIVER, AND AS PATH, NOT DISPLACEMENT.
	#
	# `cannot_idle` replaces a released stick with
	#     Vector2(sin(ticks * 0.004), cos(ticks * 0.0052)) * 0.55
	# whose two terms have DIFFERENT periods -- 1.57 s and 1.21 s -- so the
	# vector does not pulse along one axis, it ROTATES. Two consequences, and
	# this measurement got both wrong in turn:
	#
	#   1. Over the 0.33 s originally sampled, that vector can sit near one of
	#      its own zero crossings and the bird genuinely barely moves.
	#      Double-Double measured 0.17 m and failed the build on a working
	#      mechanic. 72 ticks is 1.2 s, a full period of the faster term.
	#   2. Because the direction rotates, the bird comes back on itself and
	#      END-MINUS-START CANCELS most of the motion: 0.33 m of displacement
	#      over 1.2 s of never once standing still. Summing the per-frame steps
	#      asks the question the mechanic actually poses -- did letting go of
	#      the stick stop you.
	#
	# Both are the same error the drift channel made, in two more costumes.
	#
	# `last_pos` is NOT called `prev`, and that is not a style choice: this
	# function already declares a `prev` for the turn measurement, and a second
	# one does not error, it HANGS THE PARSER. See CLAUDE.md.
	goose.velocity = Vector3.ZERO
	var last_pos := goose.global_position
	var travelled := 0.0
	for _i in 72:
		await tree.physics_frame
		var here := goose.global_position
		var hop := here - last_pos
		hop.y = 0.0
		travelled += hop.length()
		last_pos = here
	out.idle = travelled

	# --- one flap, from level flight, with the power factor it actually used ---
	goose.global_position += Vector3.UP * 70.0
	goose.set("state", 2)          # State.FLY
	goose.set("stamina", 1.0)
	goose.velocity = Vector3.ZERO
	await tree.physics_frame
	goose.velocity = Vector3.ZERO
	var y0 := goose.global_position.y

	# THE FLAP'S POWER DEPENDS ON BRAIN CHEMISTRY, NOT JUST flap_mult.
	#
	# `_flap()` computes power as `flap_impulse * flap_mult * (0.75 + 0.5 *
	# adrenaline)`, and most substances move adrenaline hard — percs, bars and
	# toad_slime bottom it out; math and Double-Double peg it. Predicting the
	# climb from flap_mult and gravity_mult alone called five substances broken
	# whose numbers were exactly right: fly_agaric's flap gained 1.42 m and the
	# complete model predicts 1.42.
	var brain: Dictionary = subs.get("brain")
	out.power = 0.75 + 0.5 * float(brain.adrenaline)

	Input.action_press("gg_flap")
	await tree.physics_frame
	Input.action_release("gg_flap")
	for _i in 90:
		await tree.physics_frame
		out.climb = maxf(float(out.climb), goose.global_position.y - y0)
		if goose.velocity.y < 0.0 and float(out.climb) > 0.01:
			break

	return out


## Back to the dry pad, on the ground, still — WITHOUT clearing the substance.
static func _reset(tree: SceneTree, goose: CharacterBody3D) -> void:
	COMMON.release_all()
	var pad := await COMMON.find_dry_ground(tree, goose, "[subs]")
	goose.global_position = pad
	goose.set("state", 0)
	goose.set("stamina", 1.0)
	goose.velocity = Vector3.ZERO

	# SETTLE ON A CONDITION, NOT A FRAME COUNT.
	#
	# This was 30 frames, and shortening it to 15 to fit the fingerprint inside
	# a 7 s nitrous introduced a flake that failed the build: the FIRST sober
	# fingerprint of a run measured a top speed of 4.96 m/s against
	# waddle_speed's 4.20, because `probe_common.find_dry_ground()` leaves the bird a metre
	# up over its last pad probe and a quarter second is not always long enough
	# to land and stop sliding. The second sober run read 4.20 and the noise
	# guard refused the report, correctly.
	#
	# Waiting for "on the floor and not moving" costs about two frames when the
	# bird is already settled and takes as long as it needs when it is not, so
	# it is both faster in the common case and correct in the rare one.
	for _i in 45:
		await tree.physics_frame
		if goose.is_on_floor() and Vector2(goose.velocity.x, goose.velocity.z).length() < 0.05:
			break


## Clear every substance and wait for the clock to come back to 1.0.
static func _sober_up(tree: SceneTree, goose: CharacterBody3D, subs: Node) -> void:
	subs.call("reset_for_new_leg")
	Engine.time_scale = 1.0
	goose.velocity = Vector3.ZERO
	for _i in 20:
		await tree.physics_frame

