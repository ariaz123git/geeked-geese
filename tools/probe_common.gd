extends RefCounted
## SHARED SETUP FOR THE MEASURING HARNESSES, AND THE LESSONS THEY COST.
##
## `tools/feeltest.gd` and `tools/substancetest.gd` both have to put a goose
## somewhere it can be measured, and both grew their own copy of that code on
## the same night. `CLAUDE.md` warns about exactly this — *"this project has
## repeatedly grown a second copy of something that already existed"* — and the
## two copies had already drifted (one used a named constant for the pad radius,
## the other a bare `9.0`) before either had shipped.
##
## ═══════════════════════════════════════════════════════════════════════════
## READ THIS BEFORE WRITING A NEW HARNESS. It is the expensive part.
## ═══════════════════════════════════════════════════════════════════════════
##
## Four gates were written in one session. **Every one of them spent its first
## runs accusing a healthy game, and every one of those was the instrument.**
## The list, so the fifth harness does not rediscover it:
##
##   1. **The zone is not empty and it does not hold still.** Leg 1 is the
##      RETENTION POND and the goose spawns in it, so "ground" metrics measured
##      `_tick_water()` — top speed came back 5.40, which is `swim_speed`.
##      It also builds seven cats that wander at 2.6 m/s and a lot of loose
##      shopping carts: one run measured a top speed of 7.37 m/s because the
##      bird had been shoved. *Find dry ground, and retake a measurement the
##      world interfered with.*
##   2. **The tree pauses behind your back.** `migration.gd`'s `process_mode` is
##      INHERIT, so a paused tree freezes it; a card paused it mid-measurement
##      and a corridor crossing came back 4.50 s against a true 1.53. Holding
##      right for a second moved the bird 0.000 m. *Check `tree.paused` on every
##      tick you count.*
##   3. **`Engine.time_scale` is not always 1.** Two autoloads write it. Every
##      harness that converts frames to seconds has to check it first.
##   4. **The thing you are measuring can end while you measure it.** Nitrous
##      lasts 7.0 s; the substance fingerprint took 12.2 s. *Assert the subject
##      is still alive at the end.*
##   5. **Phase-dependent drivers need a full period, and rotating ones need
##      path length.** Drift is a ~4 s sine, so a 1 s sample can see nothing;
##      `cannot_idle` ROTATES, so end-minus-start cancels the motion. Both were
##      measured wrong, in three different costumes.
##
## The habit that caught all of them: **measure the baseline twice and refuse to
## report anything if the two runs disagree.** A harness that cannot reproduce
## itself cannot accuse anything else.

## How far the bird may travel from the start pose during a ground measurement.
## The longest is the walk test: 1.2 s of held forward at `waddle_speed` covers
## about 5 m, and stop-distance coasts a little past that.
const PAD_RADIUS := 9.0

## Physics frames a probe drop may take to ARRIVE before the spot is written off
## as unanswerable. The controller's ground gravity is 28 m/s², so a 2 m drop
## lands in 0.38 s — 23 frames — and 40 leaves room for ground a metre lower
## than the bird started. It is a ceiling, not a wait: `_drop()` returns the
## moment it touches down or the moment it touches water.
const DROP_BUDGET := 40

## Cached dry pad, found once per run. Shared by every caller in this process.
static var _dry := Vector3.ZERO
static var _dry_ok := false


## Forget the cached pad. Call at the top of a run so repeat runs in one process
## do not inherit a pad found under different conditions.
static func reset() -> void:
	_dry = Vector3.ZERO
	_dry_ok = false


## The goose in the current zone, with the clock running. Null if there isn't one.
static func fresh_goose(tree: SceneTree, main: Node) -> CharacterBody3D:
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


## Drop the bird at `where` and wait for it to ARRIVE, watching for water the
## whole way down. Returns `{"floored": bool, "wet": bool}`.
##
## A FIXED FRAME COUNT CANNOT ANSWER "IS THIS SPOT WET", AND THAT SHIPPED.
## The pad ring below used to teleport the bird a metre up and read
## `_water_bodies` six frames later. Ground gravity in this controller is
## 28 m/s², so six frames is **0.16 m of fall** — the probe is still in the air
## when the question is asked. Leg 1's pond is a `CylinderShape3D` of height 2.4
## centred at y = 0.5, so the water **stops at y = 1.70**: a probe hovering at
## 2.16 over open water reported *dry*, and the ring certified the retention
## pond as walkable ground.
##
## The measured consequence, on 2026-08-18: `find_dry_ground` accepted the pad at
## (-17.0, 1.3, -6.0), whose ring point at (-17, ·, -15) is **9.90 m from the
## pond centre against an 11 m radius**. The first sober fingerprint then held
## forward for two seconds, waded in, and returned `speed 5.40` — which is
## `swim_speed` exactly — and `turnrate 19.79`, which is `28.27 × 0.7` and the
## 0.7 lives in `_tick_water()` and nowhere else. The noise guard refused the
## report, correctly, and the build went red with **seven substances accused of
## a broken `turn_mult` because their ratios had been divided by a baseline
## measured in a pond.**
##
## This is lesson 1 at the top of this file, wearing a new hat, INSIDE THE
## FUNCTION WRITTEN TO PREVENT IT. Settle on a condition, never on a frame count.
static func _drop(tree: SceneTree, goose: CharacterBody3D, where: Vector3) -> Dictionary:
	goose.global_position = where
	goose.velocity = Vector3.ZERO
	goose.set("state", 0)          # State.GROUND
	var landed := false
	for _i in DROP_BUDGET:
		await tree.physics_frame
		# `_water_bodies` is the goose's own count of overlapping water Area3Ds,
		# and it is what forces State.WATER every physics frame. Asking it
		# directly beats inferring from the state. Checked EVERY frame of the
		# fall, so a spot over water answers as soon as the bird reaches it
		# rather than costing the whole budget.
		if int(goose.get("_water_bodies")) != 0:
			return {"floored": true, "wet": true}
		if goose.is_on_floor():
			landed = true
			break
	# Two frames of grace. Area overlaps are reported during the physics step, so
	# the frame the bird touches down is not always the frame the water it landed
	# in has been counted.
	for _j in 2:
		await tree.physics_frame
	return {"floored": landed, "wet": int(goose.get("_water_bodies")) != 0}


## A spot with `PAD_RADIUS` metres of dry, floored ground around it, found once
## and cached. Returns it; also leaves the goose standing on it.
##
## A DRY POINT IS NOT ENOUGH, IT HAS TO BE A DRY PAD. An earlier version took the
## first spot that was dry and floored WHILE STANDING STILL. On leg 1 that can be
## the pond shoreline: the walk test then holds forward, covers 8.4 m, wades in,
## and reports `swim_speed` against a window written for `waddle_speed`. **The
## measurement moves the bird, so the candidate has to be dry across the ground
## the bird will cover, not at the point it starts on.**
##
## AND THE PAD HAS TO BE PROVEN STANDING ON IT. Every probe below settles on a
## condition — see `_drop()` for the 2026-08-18 failure that rule was rewritten
## for — and the candidate is only accepted after the bird has been put back on
## the centre and found dry and floored there, which is the pose the measurement
## actually starts from.
static func find_dry_ground(tree: SceneTree, goose: CharacterBody3D, tag: String) -> Vector3:
	if _dry_ok:
		return _dry

	var base := goose.global_position
	var offsets: Array[Vector3] = [Vector3.ZERO]
	for radius: float in [7.0, 14.0, 21.0, 28.0]:
		for a in 8:
			var ang := TAU * float(a) / 8.0
			offsets.append(Vector3(cos(ang), 0.0, sin(ang)) * radius)

	for off in offsets:
		var here: Dictionary = await _drop(tree, goose, base + off + Vector3.UP * 2.0)
		if bool(here.wet) or not bool(here.floored):
			continue
		var centre := goose.global_position

		# EIGHT SPOKES, NOT FOUR. Four spokes at 9 m leave 12.7 m between
		# neighbours, which is wider than leg 1's pond is across — a water body
		# sitting in a gap is invisible to the ring and the walk finds it anyway.
		# The pond that got through on 2026-08-18 was a direct hit on a spoke, so
		# this is the near miss rather than the one that happened; it costs four
		# more drops, and only on a candidate that has already passed everything
		# else.
		var pad_ok := true
		for a2 in 8:
			var ang2 := TAU * float(a2) / 8.0
			var ring: Dictionary = await _drop(tree, goose,
				centre + Vector3(cos(ang2), 0.0, sin(ang2)) * PAD_RADIUS + Vector3.UP * 2.0)
			# A ring point the bird cannot reach the floor of is a ring point
			# this function cannot certify — a ledge, a hole, or the far side of
			# a wall. Rejected rather than assumed dry: an unanswered question
			# was exactly how the pond got through.
			if bool(ring.wet) or not bool(ring.floored):
				pad_ok = false
				break
		if not pad_ok:
			continue

		# BACK TO THE CENTRE, AND PROVE IT THERE. The ring walk leaves the bird
		# nine metres away; the measurement starts here.
		var home: Dictionary = await _drop(tree, goose, centre + Vector3.UP * 0.5)
		if bool(home.wet) or not bool(home.floored):
			continue

		_dry = centre
		_dry_ok = true
		print("%s dry ground at %.1f, %.1f, %.1f (%.1f m from spawn, %.0f m dry pad)"
			% [tag, _dry.x, _dry.y, _dry.z, Vector2(off.x, off.z).length(), PAD_RADIUS])
		return _dry

	_dry = base
	_dry_ok = true
	print("%s WARNING — no dry pad within 28 m; ground metrics measure the water model" % tag)
	return _dry


static func release_all() -> void:
	for a in ["gg_forward", "gg_back", "gg_left", "gg_right", "gg_flap", "gg_dive", "gg_honk"]:
		if InputMap.has_action(a):
			Input.action_release(a)
