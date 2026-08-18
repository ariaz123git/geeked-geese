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


## A spot with `PAD_RADIUS` metres of dry, floored ground around it, found once
## and cached. Returns it; also leaves the goose standing on it.
##
## A DRY POINT IS NOT ENOUGH, IT HAS TO BE A DRY PAD. An earlier version took the
## first spot that was dry and floored WHILE STANDING STILL. On leg 1 that can be
## the pond shoreline: the walk test then holds forward, covers 8.4 m, wades in,
## and reports `swim_speed` against a window written for `waddle_speed`. **The
## measurement moves the bird, so the candidate has to be dry across the ground
## the bird will cover, not at the point it starts on.**
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
		goose.global_position = base + off + Vector3.UP * 2.0
		goose.velocity = Vector3.ZERO
		goose.set("state", 0)          # State.GROUND
		for _i in 16:
			await tree.physics_frame
		# `_water_bodies` is the goose's own count of overlapping water Area3Ds,
		# and it is what forces State.WATER every physics frame. Asking it
		# directly beats inferring from the state.
		if int(goose.get("_water_bodies")) != 0 or not goose.is_on_floor():
			continue
		var centre := goose.global_position

		var pad_ok := true
		for a2 in 4:
			var ang2 := TAU * float(a2) / 4.0
			goose.global_position = centre + Vector3(cos(ang2), 0.0, sin(ang2)) * PAD_RADIUS + Vector3.UP
			goose.velocity = Vector3.ZERO
			for _j in 6:
				await tree.physics_frame
			if int(goose.get("_water_bodies")) != 0:
				pad_ok = false
				break
		if not pad_ok:
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
