extends CharacterBody3D
class_name Goose

## THE GOOSE CONTROLLER.
##
## This is 60% of the game. Everything else is decoration on top of it.
## If flying this bird around an empty grey box is not already fun, no substance
## and no shader will save the project — come back and fix these numbers first.
##
## The controller NEVER asks "am I on berries?". It only ever asks Subs.mods
## what its input lag / drift / flap power currently are. That indirection is
## what lets substance #40 be a data file instead of a code change.

signal landed(hard: bool, speed: float)
signal took_off()
signal tumbled()

enum State { GROUND, WATER, FLY, TUMBLE }

@export_group("Ground")
@export var waddle_speed := 4.2
@export var waddle_accel := 20.0
@export var waddle_friction := 14.0
@export var turn_rate := 9.0

@export_group("Water")
@export var swim_speed := 5.4
@export var swim_accel := 10.0
# THERE IS DELIBERATELY NO `float_height` HERE ANY MORE.
#
# It was exported at 0.28, read by nothing in the entire scripts/ tree, and could
# not be honestly wired up from this file. The exported numbers exist so a human
# can drag them while the game runs; a dial that cannot be connected to anything
# is worse than no dial, so it is gone rather than left as furniture.
#
# Two independent reasons buoyancy does not belong here as things are built:
#
#   1. There is no water SURFACE to float relative to. Every water volume in the
#      game is an Area3D sized for DETECTION, not for the waterline.
#      zone_cottage's box top genuinely is its wade line (0.20, and it says so in
#      a comment); zone_strip_mall's cylinder tops out at 1.70, which is 1.31 m
#      above the pond mesh it covers. "Shape top + float_height" would have
#      parked the goose two metres above leg 1's pond.
#   2. Even with a correct surface, 0.28 is taller than the detector. _build()'s
#      water probe is a 0.22-radius sphere at this node's origin, so a bird
#      floating 0.28 proud of the waterline leaves its own trigger, falls back to
#      GROUND, drops in again — and re-fires _on_water_enter()'s splash burst,
#      shake and SFX on every bob.
#
# What holds the bird up today is the pond floor: _tick_water() runs no gravity,
# the goose rests on the bed collider, and each zone picks its bed depth and wade
# line together so the capsule sits about half submerged. That tuning lives in
# six zone files, not in this one. If real buoyancy is wanted, the zones have to
# publish a surface height first — a `surface_y` meta on the water Area3D would
# do it — and then this dial comes back with something true behind it.

@export_group("Flight")
@export var flap_impulse := 6.4
@export var flap_cooldown := 0.30
@export var air_speed := 14.0
@export var air_accel := 10.0
@export var glide_gravity := 11.0
@export var dive_gravity := 30.0
@export var max_fall := 34.0
@export var takeoff_run_speed := 2.2
@export var air_turn_rate := 4.2

@export_group("Landing")
@export var hard_landing_speed := 13.0
@export var tumble_time := 1.15

@export_group("Stamina")
@export var flap_cost := 0.058
@export var regen_ground := 0.26
@export var regen_water := 0.34
@export var regen_glide := 0.05

var state: int = State.GROUND
var stamina := 1.0
var heading := 0.0                 ## yaw the bird is facing, radians
var visual: Node3D
var honker: Node
var cam: Node3D

var _flap_cd := 0.0
var _flap_anim := 0.0
var _tumble_t := 0.0
var _water_bodies := 0
var _drift := Vector2.ZERO
var _drift_seed := Vector2.ZERO
var _input_buffer: Array = []       ## [[age, Vector2], ...] for input_lag
var _last_y_speed := 0.0
## Speed the tick BEFORE `move_and_slide()` resolved it. `_resolve_collisions()`
## grades every prop hit on this; see the argument there.
var _last_speed := 0.0
## True while the bird is off the ground after leaving it WITHOUT upward speed —
## i.e. it walked off something rather than being launched off it. Gates the
## GROUND-state landing consequence; see _physics_process().
var _fell_off := false
var _eat_charge := 0.0
var _eating: Node = null
var _collider: CollisionShape3D
var _probe: Area3D
var _sfx: Node
var _step_t := 0.0
var _charging := false
var _bank := 0.0
var _bank_ref := 0.0
## Current body scale. 1.0 normal. Driven by macropsia substances.
var size := 1.0


func _ready() -> void:
	_sfx = get_node_or_null("/root/Sfx")
	_build()
	heading = rotation.y
	_drift_seed = Vector2(randf() * 100.0, randf() * 100.0)
	# The blackout is the game's biggest punish and it is fired by Subs, which
	# has no position. The goose does, so the goose owns the physical beat.
	if not Subs.blackout_started.is_connected(_on_blackout_started):
		Subs.blackout_started.connect(_on_blackout_started)
	if not Subs.blackout_ended.is_connected(_on_blackout_ended):
		Subs.blackout_ended.connect(_on_blackout_ended)


func _build() -> void:
	# Body collider: a capsule lying along Z so the goose is longer than it is wide.
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.34
	cap.height = 1.10
	col.shape = cap
	col.rotation_degrees = Vector3(90, 0, 0)
	col.position = Vector3(0, 0.0, 0)
	add_child(col)
	_collider = col

	_build_visual()

	honker = preload("res://scripts/goose/honk.gd").new()
	honker.name = "Honker"
	add_child(honker)

	# Water probe — reports overlap with Area3Ds in the "water" group.
	var probe := Area3D.new()
	probe.name = "WaterProbe"
	var pshape := CollisionShape3D.new()
	var psph := SphereShape3D.new()
	psph.radius = 0.22
	pshape.shape = psph
	probe.add_child(pshape)
	probe.monitorable = false
	probe.area_entered.connect(_on_water_enter)
	probe.area_exited.connect(_on_water_exit)
	add_child(probe)
	_probe = probe

	up_direction = Vector3.UP
	floor_snap_length = 0.4


## Which goose mesh to build, from settings. Both scripts expose an identical
## API (animate / set_bank / set_tint), so nothing downstream cares which one
## is live — that is the whole reason the switch is cheap.
const MODEL_SCRIPTS := {
	"classic": "res://scripts/goose/goose_visual.gd",
	"lowpoly": "res://scripts/goose/goose_visual_lowpoly.gd",
}

var _model_key := ""


func _build_visual() -> void:
	var prefs := get_node_or_null("/root/Prefs")
	var key := "lowpoly"
	if prefs:
		key = str(prefs.get_pref(&"goose_model", "lowpoly"))
	if not MODEL_SCRIPTS.has(key):
		key = "lowpoly"
	_model_key = key

	if visual and is_instance_valid(visual):
		visual.queue_free()
	visual = load(MODEL_SCRIPTS[key]).new()
	visual.name = "Visual"
	add_child(visual)
	# Re-apply the current body scale so a mid-run swap doesn't reset a goose
	# that happens to be halfway through a macropsia pulse.
	visual.scale = Vector3.ONE * size

	if prefs and prefs.has_signal("pref_changed") and not prefs.pref_changed.is_connected(_on_pref_changed):
		prefs.pref_changed.connect(_on_pref_changed)


func _on_pref_changed(key: StringName, _value) -> void:
	if key == &"goose_model":
		var prefs := get_node_or_null("/root/Prefs")
		var want := str(prefs.get_pref(&"goose_model", "lowpoly")) if prefs else "lowpoly"
		if want != _model_key:
			_build_visual()


func _on_water_enter(a: Area3D) -> void:
	if a.is_in_group("water"):
		_water_bodies += 1
		if _water_bodies == 1:
			# TIER 1. Hitting water is not violence, it is a transition, so it
			# gets a wide wet burst and only enough shake (0.18) to sell the
			# weight of a bird arriving. The count is deliberately outside the
			# `if _sfx` it used to share, so the splash is visible in builds
			# with no audio.
			Juice.burst(global_position, Color(0.55, 0.78, 0.92), 16, &"splash")
			Juice.shake(0.18)
			if _sfx:
				_sfx.play_at(&"splash_in", self, -2.0, randf_range(0.92, 1.1))
				_sfx.loop(&"swim_loop", &"swim", -16.0)


func _on_water_exit(a: Area3D) -> void:
	if a.is_in_group("water"):
		_water_bodies = maxi(0, _water_bodies - 1)
		if _water_bodies == 0 and _sfx:
			_sfx.stop_loop(&"swim")


# ---------------------------------------------------------------- input

## Raw stick, camera-relative.
func _raw_input() -> Vector2:
	var v := Input.get_vector("gg_left", "gg_right", "gg_forward", "gg_back")
	if cam and cam.has_method("get_yaw"):
		v = v.rotated(-cam.get_yaw())
	return v


## Stick after input lag + drift. This is what the goose actually obeys.
func _wanted() -> Vector2:
	var m: Dictionary = Subs.mods
	var raw := _raw_input()

	# --- input lag: push into a buffer, read out of the past ---
	#
	# READ THE BUFFER NEWEST-FIRST. This loop used to run front-to-back and
	# `break` on the first entry old enough — and the front of the buffer is the
	# OLDEST entry, because new samples are appended at the tail and everything
	# ages together in _age_buffer(). So it did not return the sample from
	# `lag` seconds ago; it returned the sample from as long ago as the buffer
	# happened to reach, which the old size-240 trim capped at FOUR SECONDS.
	#
	# The effect: every substance with input lag ramped from 0 to a four-second
	# delay over its first four seconds and then stayed there. The largest lag
	# any substance actually asks for is toad slime's 0.28 s. Fermented berries
	# ask for 0.22 and got 4.0. That is not "drunk", it is "disconnected", and
	# it applied to eleven of the sixteen substances — which is to say, to most
	# of what this game is about.
	var lag: float = m.input_lag
	if lag > 0.001:
		_input_buffer.append([0.0, raw])
		var out := raw
		for i in range(_input_buffer.size() - 1, -1, -1):
			var e: Array = _input_buffer[i]
			if float(e[0]) >= lag:
				out = e[1]
				break
		raw = out
	else:
		_input_buffer.clear()

	# --- drift: a slow random walk the player has to fight ---
	var d: float = m.drift
	if d > 0.001:
		var t := float(Time.get_ticks_msec()) * 0.0009
		_drift = Vector2(
			sin(t * 1.7 + _drift_seed.x) + 0.5 * sin(t * 3.1 + _drift_seed.y),
			cos(t * 1.3 + _drift_seed.y) + 0.5 * cos(t * 2.7 + _drift_seed.x)
		) * d * 0.55
		raw += _drift
	else:
		_drift = Vector2.ZERO

	# --- caffeine: letting go doesn't stop you ---
	if m.cannot_idle and raw.length() < 0.2:
		raw = Vector2(sin(Time.get_ticks_msec() * 0.004), cos(Time.get_ticks_msec() * 0.0052)) * 0.55

	# --- DXM: movement snaps to 90°. You are now a robot goose. ---
	if m.grid_snap and raw.length() > 0.25:
		var a := snappedf(raw.angle(), PI * 0.5)
		raw = Vector2.RIGHT.rotated(a) * raw.length()

	return raw.limit_length(1.4)


## Trimmed by AGE, not by a sample count. The old `size() > 240` cap held four
## seconds of history at 60 Hz and one and a half at 160 — a buffer whose depth
## depended on the frame rate, feeding a mechanic measured in seconds.
##
## MAX_LAG is the ceiling any substance may ask for; the deepest in
## data/substances/ is toad slime at 0.28. The extra second is headroom for a
## future .tres, and one stale sample past the cutoff is kept deliberately —
## that is the one the newest-first read in _wanted() returns.
const MAX_LAG := 1.25

## The node a squash-and-stretch may safely be applied to.
##
## `SubstancePickup.visual_node()` was added to fix exactly this and then never
## called from anywhere, so the defect it was written for stayed live and
## bit-for-bit unchanged. Falls back to the node itself for anything that has no
## separate visual — which is worse than popping a visual and better than
## crashing on a pickup built before the accessor existed.
func _pop_target(n: Node) -> Node:
	if n != null and is_instance_valid(n) and n.has_method("visual_node"):
		var v: Node = n.call("visual_node")
		if v != null and is_instance_valid(v):
			return v
	return n


func _age_buffer(delta: float) -> void:
	for e in _input_buffer:
		e[0] += delta
	while _input_buffer.size() > 1 and float(_input_buffer[1][0]) >= MAX_LAG:
		_input_buffer.pop_front()


# ---------------------------------------------------------------- main loop

func _physics_process(delta: float) -> void:
	_age_buffer(delta)
	var m: Dictionary = Subs.mods
	_flap_cd = maxf(0.0, _flap_cd - delta)
	_tick_size(delta, m)

	if state == State.TUMBLE:
		_tick_tumble(delta)
	else:
		if _water_bodies > 0 and state != State.FLY:
			state = State.WATER
		elif state == State.WATER and _water_bodies == 0:
			state = State.GROUND

		match state:
			State.GROUND: _tick_ground(delta, m)
			State.WATER: _tick_water(delta, m)
			State.FLY: _tick_fly(delta, m)

	_last_y_speed = velocity.y
	# Sampled here for the same reason `_last_y_speed` is: `move_and_slide()`
	# slides velocity along every contact normal, so after it the speed of an
	# impact is the speed you have LEFT, not the speed you arrived with.
	# `_resolve_collisions()` grades prop hits on this.
	_last_speed = velocity.length()
	move_and_slide()
	# THE LANDING CHECK LIVES HERE, not in _tick_fly().
	#
	# `is_on_floor()` is only true once move_and_slide() has resolved THIS tick's
	# motion — CLAUDE.md states the rule outright and _tick_fly() broke it, since
	# every _tick_* runs above this line. The goose therefore stayed in State.FLY
	# for one physics frame after it had already stopped moving, which is the
	# frame a held flap button gets to fire on: you touch down, the game has not
	# noticed, and your held SPACE spends stamina on a flap from the ground.
	#
	# `_last_y_speed` is still sampled BEFORE the slide, because the floor zeroes
	# velocity.y — that is the fall speed _do_land() grades the impact on.
	if state == State.FLY and is_on_floor():
		_do_land(m)
	# A FALL THAT DID NOT BEGIN WITH A TAKEOFF STILL HAS TO LAND.
	#
	# `State.FLY` is only ever entered by `_launch()`, so walking off a roof, a
	# minivan, the trampoline or the awning left the bird in `State.GROUND` for
	# the whole descent — `_tick_ground()` applies gravity, so it fell correctly
	# and then arrived in total silence. No impact, no faceplant, no tumble, no
	# `landed` signal, and Mission never heard about it. In a leg whose primary
	# objective is "Get on a roof. Ideally not your own." that is the most
	# likely fall in the game.
	#
	# Deliberately NOT fixed by putting the bird into State.FLY when it leaves
	# the ground: FLY has its own gravity, its own air control and a stamina
	# drain, and handing all three to somebody who stepped off a kerb is a
	# change to how the game FEELS, which is not mine to make. This fires the
	# consequence and nothing else.
	#
	# IT MUST BE A FALL, NOT A LAUNCH — and the first version of this got both
	# halves of that wrong.
	#
	# The threshold was documented as "about a 1.8 m drop", sized with real-world
	# gravity. THE CONTROLLER'S GROUND GRAVITY IS 28.0 m/s², not 9.8, so -6.0 was
	# a 0.64 m drop: nearly three times more sensitive than the comment claimed,
	# and low enough to catch stepping off a kerb. `2 * 28 * 1.8` gives 10.0 m/s,
	# so that is the number.
	#
	# Worse, the check could not tell a fall from a bounce. Suburbia's trampoline
	# writes `velocity.y = 20.0` directly and does NOT change state, so the bird
	# arcs 7 m and comes back down at 20 m/s while still in State.GROUND — and
	# every single bounce became a hard landing with a faceplant, a 0.9 shake and
	# a hitstop, on the leg whose bonus objective is "Use the trampoline like it
	# owes you money" seven times. That is exactly the inflation juice.gd's own
	# budget exists to forbid.
	#
	# `_fell_off` is the discriminator and it is the honest one: a fall LEAVES
	# the ground with no upward speed, a launch leaves it with plenty.
	elif state == State.GROUND and is_on_floor() and _fell_off and _last_y_speed < -10.0:
		_do_land(m)
	# Book-keeping for the above, after the slide so `is_on_floor()` is this
	# tick's truth. Leaving the floor while already moving up is a launcher —
	# a trampoline, a departing rig, a shove — and whatever happens next is not
	# a fall the player authored by walking off something.
	if is_on_floor():
		_fell_off = false
	elif state == State.GROUND and velocity.y <= 0.5:
		_fell_off = true
	_resolve_collisions()
	_tick_footsteps(delta)
	_animate(delta)
	_tick_eat(delta)


func _tick_ground(delta: float, m: Dictionary) -> void:
	var want := _wanted()
	var target: Vector3 = Vector3(want.x, 0, want.y) * waddle_speed * m.speed_mult * _move_scale()

	if target.length() > 0.05:
		velocity.x = move_toward(velocity.x, target.x, waddle_accel * delta)
		velocity.z = move_toward(velocity.z, target.z, waddle_accel * delta)
		_face(atan2(-target.x, -target.z), turn_rate * m.turn_mult, delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, waddle_friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, waddle_friction * delta)

	velocity.y -= 28.0 * m.gravity_mult * delta

	stamina = minf(1.0, stamina + regen_ground * delta)

	if Input.is_action_pressed("gg_flap") and _flap_cd <= 0.0 and stamina > 0.06:
		var run := Vector2(velocity.x, velocity.z).length()
		if run >= takeoff_run_speed:
			_launch(m, 1.0)
		else:
			# No run-up: a pathetic, funny little hop. Real geese need a runway.
			_launch(m, 0.45)


func _tick_water(delta: float, m: Dictionary) -> void:
	var want := _wanted()
	var target: Vector3 = Vector3(want.x, 0, want.y) * swim_speed * m.speed_mult * _move_scale()
	velocity.x = move_toward(velocity.x, target.x, swim_accel * delta)
	velocity.z = move_toward(velocity.z, target.z, swim_accel * delta)
	velocity.y = lerpf(velocity.y, 0.0, 1.0 - pow(0.02, delta))

	if target.length() > 0.05:
		_face(atan2(-target.x, -target.z), turn_rate * 0.7 * m.turn_mult, delta)

	stamina = minf(1.0, stamina + regen_water * delta)

	if Input.is_action_just_pressed("gg_flap") and stamina > 0.10:
		_launch(m, 0.85)


func _tick_fly(delta: float, m: Dictionary) -> void:
	var want := _wanted()
	var diving := Input.is_action_pressed("gg_dive")

	# Horizontal: banking, not strafing. Geese carry momentum.
	var target: Vector3 = Vector3(want.x, 0, want.y) * air_speed * m.speed_mult * _move_scale()
	var accel := air_accel * (1.4 if diving else 1.0)
	velocity.x = move_toward(velocity.x, target.x, accel * delta)
	velocity.z = move_toward(velocity.z, target.z, accel * delta)

	if target.length() > 0.1:
		_face(atan2(-target.x, -target.z), air_turn_rate * m.turn_mult, delta)

	var g: float = (dive_gravity if diving else glide_gravity) * m.gravity_mult
	velocity.y = maxf(velocity.y - g * delta, -max_fall)

	if Input.is_action_pressed("gg_flap") and _flap_cd <= 0.0 and stamina > 0.04:
		_flap(m)
	else:
		_flap_anim = maxf(0.0, _flap_anim - delta * 2.2)
		if not diving:
			stamina = minf(1.0, stamina + regen_glide * delta)


func _flap(m: Dictionary) -> void:
	if _sfx:
		_sfx.play_var([&"flap_1", &"flap_2", &"flap_3"], -5.0, 0.09)
	var power: float = flap_impulse * m.flap_mult * (0.75 + 0.25 * Subs.brain.adrenaline * 2.0)
	# THE FLAP SETS THE CLIMB. IT DOES NOT ADD TO IT.
	#
	# This line used to read `maxf(velocity.y, 0.0) + power`, which ADDS the
	# impulse on top of an already-positive climb. One flap costs 0.30 s of
	# cooldown, and glide_gravity only takes 11.0 * 0.30 = 3.3 m/s back over that
	# window — while power is 6.08 at resting adrenaline. So every held flap
	# netted +2.78 m/s on the last one, compounding, with no ceiling: there is a
	# `max_fall` in this file and there has never been a max_rise. The only thing
	# between the player and orbit was the stamina bar.
	#
	# Measured, not argued (tools/feeltest.gd, --feeltest):
	#     before   7.36 m climbed in the 1st second of held flap, 23.66 m in the
	#              3rd. Ratio 3.22x. Peak climb 29.5 m/s, which is faster than
	#              the terminal fall speed of 34 is far from, and enough to clear
	#              anything built in this game in about a second and a half.
	#     after    4.50 m in the 1st second and 4.45 m in the 3rd. Ratio 0.99.
	#              Peak climb 6.08 m/s, which is exactly `power` — the sawtooth
	#              never gets above one flap's worth, which is the point.
	#
	# `maxf(velocity.y, power)` leaves the SINGLE flap bit-for-bit unchanged —
	# from level flight both forms give exactly `power` — so the one number the
	# design actually committed to survives untouched: one flap still lifts the
	# bird 1.73 m, which is the level-per-flap the 1.70 m racking beam pitch in
	# BIG DOWN was built around (docs/HANDOFF.md, §4). What it removes is only
	# the stacking, and it self-limits across flap_mult: Double-Double's 2x flap
	# rate doubles power AND halves the cooldown, and still converges.
	velocity.y = maxf(velocity.y, power)
	stamina = maxf(0.0, stamina - flap_cost)
	_flap_cd = flap_cooldown / maxf(m.flap_mult, 0.4)
	_flap_anim = 1.0


func _launch(m: Dictionary, scale: float) -> void:
	if _sfx:
		_sfx.play_var([&"flap_1", &"flap_2", &"flap_3"], -2.0, 0.09)
	velocity.y = flap_impulse * m.flap_mult * scale * 1.25
	stamina = maxf(0.0, stamina - flap_cost * 1.6)
	_flap_cd = flap_cooldown
	_flap_anim = 1.0
	if scale > 0.6:
		state = State.FLY
		took_off.emit()
		# TIER 1. The flap that actually gets you off the ground is a real beat
		# and had nothing at all. It gets the downwash — grit kicked out from
		# under the bird — and the smallest shake in the table.
		#
		# NOT a pop() on the goose's own visual, tempting as that is:
		# _tick_size() rewrites visual.scale every physics frame from the
		# macropsia curve, so a pop would be fighting it for the whole 0.18 s
		# and would then restore whatever momentary size it happened to
		# capture. Blowing dirt around the bird reads as launch effort without
		# touching a transform something else owns.
		Juice.burst(global_position + Vector3.DOWN * 0.3,
			Color(0.62, 0.60, 0.54), 9, &"feathers")
		Juice.shake(0.10)


func _do_land(m: Dictionary) -> void:
	var impact := absf(_last_y_speed)
	var hard := impact > hard_landing_speed
	state = State.GROUND
	landed.emit(hard, impact)

	# TIER 3. Sited here, immediately after the signal, so it fires regardless
	# of which of the three scoring branches below runs — the opioid branch
	# returns early and would otherwise land in silence. One of the five
	# hitstop sites in the game.
	#
	# A soft landing gets nothing. That is not an oversight: landing is the
	# most repeated event in flight, and if the gentle ones shake too then the
	# hard ones have nothing left to say.
	if hard:
		Juice.hitstop(0.05, 0.55)
		Juice.shake(clampf(impact / 20.0, 0.15, 0.9))
		Juice.burst(global_position + Vector3.DOWN * 0.35,
			Color(0.58, 0.56, 0.50), 10, &"debris")

	if _sfx:
		if hard:
			_sfx.play_at(&"thud_land", self, -1.0, randf_range(0.9, 1.05))
		elif impact > 3.0:
			_sfx.play_var([&"waddle_1", &"waddle_2"], -6.0, 0.1)

	# Opioids: you feel nothing, so nothing happens to you. Slow, but unbreakable.
	if m.no_fall_damage:
		velocity.x *= 0.85
		velocity.z *= 0.85
		if hard:
			Game.score(20, "DIDN'T FEEL A THING", global_position)
		return

	if hard and m.ragdoll_landings:
		_start_tumble()
		Game.score(60, "FACEPLANT", global_position)
	elif hard:
		Game.score(15, "ROUGH LANDING", global_position)
		velocity.x *= 0.4
		velocity.z *= 0.4
	else:
		velocity.x *= 0.75
		velocity.z *= 0.75


func _start_tumble() -> void:
	# TIER 4. The faceplant is the loudest thing in the zone and should be: it
	# is rare, it is entirely the player's own doing, and it takes control away
	# for over a second, so the feedback has to justify that. Full-depth
	# hitstop, 0.9 shake — three quarters of the ceiling — and an absurd
	# quantity of feathers.
	Juice.hitstop(0.09, 1.0)
	Juice.shake(0.9)
	Juice.burst(global_position + Vector3.UP * 0.4,
		Color(0.94, 0.94, 0.92), 16, &"feathers")
	if _sfx:
		_sfx.play_at(&"tumble", self, -2.0, randf_range(0.92, 1.12))
	state = State.TUMBLE
	_tumble_t = tumble_time
	tumbled.emit()


func _tick_tumble(delta: float) -> void:
	_tumble_t -= delta
	velocity.y -= 28.0 * delta
	velocity.x = move_toward(velocity.x, 0.0, 5.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 5.0 * delta)
	if visual:
		visual.rotate_z(delta * 14.0)
		visual.rotate_x(delta * 9.0)
	if _tumble_t <= 0.0:
		state = State.GROUND
		if visual:
			visual.rotation = Vector3.ZERO


## ---------------------------------------------------------------- size
##
## Fly agaric doesn't tint the screen — it changes how big you are, and it
## PULSES. Scaling the goose is the honest way to render "the world got
## bigger": a tiny goose genuinely fits under the dumpster, and a huge one
## genuinely steps over a minivan. Scale is a traversal tool.
func _tick_size(delta: float, m: Dictionary) -> void:
	var amp: float = m.scale_amp
	var want := 1.0
	if amp > 0.001:
		var per: float = maxf(m.scale_period, 0.5)
		var phase := sin(float(Time.get_ticks_msec()) * 0.001 * TAU / per)
		want = pow(2.0, phase * amp)
	size = lerpf(size, want, 1.0 - pow(0.06, delta))

	if visual:
		visual.scale = Vector3.ONE * size
	if _collider:
		_collider.scale = Vector3.ONE * size
	if _probe:
		_probe.scale = Vector3.ONE * size
	if cam:
		cam.set("size_mult", size)


## Bigger goose covers more ground per step; tiny goose feels the world grow.
## Square root, not linear — linear makes the small end unplayably slow.
func _move_scale() -> float:
	return sqrt(clampf(size, 0.18, 4.0))


func _face(target_yaw: float, rate: float, delta: float) -> void:
	heading = lerp_angle(heading, target_yaw, clampf(rate * delta, 0.0, 1.0))
	rotation.y = heading


# ---------------------------------------------------------------- collisions

func _resolve_collisions() -> void:
	var m: Dictionary = Subs.mods
	# THE SPEED OF THE HIT IS THE SPEED BEFORE THE HIT.
	#
	# This read `velocity.length()`, and it runs AFTER `move_and_slide()` — which
	# has already slid the velocity along every contact normal it resolved. So the
	# harder the impact, the smaller the number it reported, and a square-on hit
	# reported zero.
	#
	# Measured in Godot 4.7.1 with this exact capsule and this exact drive:
	# waddling into a prop head-on at full `waddle_speed` gives pre-slide 4.226 and
	# **post-slide 0.000**. `chaos_prop.gd` opens with `if force < 2.5: return`, so
	# the most frequent scoring event in the game — running into a shopping cart —
	# produced no score, no crash, no shake, no pop, and could never reach
	# `break_force`. A 45° glance measured 2.970 and scored, which is why this was
	# invisible: props DID break, just never when you hit them properly.
	#
	# A dive onto a prop was the same bug twice over: the floor normal zeroes
	# `velocity.y` before this line, so `_do_land()` graded that tick as a 34 m/s
	# hard landing while the prop underneath was told the force was nothing.
	#
	# `_last_speed` is sampled beside `_last_y_speed`, on the same line-before-the-
	# slide principle and for the same reason.
	var speed := _last_speed
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var other := c.get_collider()
		if other == null:
			continue
		if other.is_in_group("chaos_prop") and other.has_method("hit"):
			var force := speed
			if state == State.TUMBLE or m.smash_through:
				force = maxf(force, 16.0)
			other.hit(force, -c.get_normal() * maxf(speed, 3.0))


# ---------------------------------------------------------------- eating

func _tick_eat(delta: float) -> void:
	# Pickups register themselves as `_eating` when we're in range.
	if _eating == null or not is_instance_valid(_eating):
		# UNCONDITIONALLY. This used to be `if _eat_charge > 0.0: _abort_charge()`
		# and that guard could never be true on the one path it was written for:
		# walking out of a pickup's range calls `clear_eat_target()`, which nulls
		# `_eating` and zeroes `_eat_charge` IN THE SAME STATEMENT. So by the time
		# this ran there was no charge left to notice, `_abort_charge()` never
		# fired, `_charging` stayed true — and the dose charge loop kept rising in
		# your ears for the rest of the leg, until main.gd::_clear() stopped the
		# bus at the leg change.
		#
		# `_abort_charge()` is already idempotent (it checks `_charging`), so the
		# guard bought nothing even when it did fire.
		_abort_charge()
		_eat_charge = 0.0
		return

	var res: Substance = _eating.substance
	if res == null:
		return

	if Input.is_action_pressed("gg_eat"):
		_eat_charge = minf(1.0, _eat_charge + delta / maxf(res.charge_time, 0.05))
		# Rising tension while you hold. The loop itself is flat; we bend it.
		if _sfx:
			if not _charging:
				_charging = true
				_sfx.loop(&"dose_charge_loop", &"charge", -14.0)
			_sfx.set_loop_pitch(&"charge", 0.75 + _eat_charge * 0.9)
			_sfx.set_loop_volume(&"charge", -16.0 + _eat_charge * 8.0)
	elif _eat_charge > 0.01:
		# Skill expression is STOPPING, not holding.
		var dose := _eat_charge
		_eat_charge = 0.0
		if _sfx and _charging:
			_charging = false
			_sfx.stop_loop(&"charge")
		var in_band: bool = dose >= res.sweet_min and dose <= res.sweet_max
		if _sfx:
			_sfx.play(&"dose_commit_good" if in_band else &"dose_commit_bad", -2.0)
		# Capture the position BEFORE consumed() runs: on a finite source that
		# call hides the model and starts a respawn timer, and on a leg change
		# the node can go away entirely.
		var pick := _eating as Node3D
		var at := global_position + Vector3.UP * 0.5
		if pick != null and is_instance_valid(pick):
			at = pick.global_position + Vector3.UP * 0.4

		if Subs.take(res, dose):
			# SIX SUBSTANCES HAVE BEEN PROMISING THIS AND NOTHING HAS EVER PAID IT.
			#
			# `Substance.stamina_restore` is exported, is set non-zero by bars
			# (0.20), darts (0.20), double_double (0.40), grass (0.25), math
			# (0.50) and molly (0.30) — and was read by NOTHING. It is not a key
			# in `resolve()`'s dictionary, so it never reached `Subs.mods`, and no
			# file under scripts/ named it. The `.tres` files are the design
			# record for this game; six of them recorded a stamina refund the
			# player has never once received.
			#
			# Wired here rather than deleted, and the distinction is the
			# `float_height` precedent above: that dial went because it could not
			# be honestly connected from this file — there was no water surface to
			# connect it to. This one can, in one statement, at the exact moment
			# the dose lands, with both the substance and the bird in scope.
			#
			# Flat and capped, not scaled by dose quality or tolerance: it is not
			# in `resolve()` and putting it there would make a stamina refund
			# something `_aggregate()` has to sum across actives, which is a
			# different and larger change. `tools/selftest.gd::_the_substance_fields()`
			# is the assertion that this stayed connected.
			#
			# THIS IS A BALANCE CHANGE AND IT IS ONE LINE. `flap_cost` is 0.058, so
			# math's 0.50 is about 8.6 extra flaps from one dose. Nothing in this
			# project measures whether that is too generous. See docs/DECISIONS.md.
			if res.stamina_restore > 0.0:
				stamina = minf(1.0, stamina + res.stamina_restore)
			if _eating.has_method("consumed"):
				_eating.consumed()
			var label := "SWEET SPOT" if in_band else \
				("OVERDOSE" if dose > res.sweet_max else "BARELY ANYTHING")
			Game.score(40 if label == "SWEET SPOT" else 20, label, at)

			# --- the three outcomes have to FEEL like three different things ---
			#
			# Letting go at the right moment is the game's core skill
			# expression and its only real input-timing test, so the reward and
			# the mistake cannot be the same effect at two sizes.
			if in_band:
				# TIER 0. Weightless, bright, rising, and no shake at all.
				# Shake is this game's vocabulary for violence; spending it on
				# a success blunts both readings.
				Juice.burst(at, res.tint, 12, &"sparkle")
				# POP THE VISUAL, NOT THE PICKUP. `pick` is a SubstancePickup,
				# which IS an Area3D — Juice.pop() writes node.scale, so popping
				# it squashed and stretched the trigger volume the goose is
				# standing in, momentarily changing the reach of the thing it was
				# celebrating. CLAUDE.md's rule about never scaling a physics
				# body covers areas for the same reason.
				if pick != null and is_instance_valid(pick):
					Juice.pop(_pop_target(pick), 0.30, 0.22)
			elif dose > res.sweet_max:
				# TIER 2. An overdose should read as a mistake, not as a
				# smaller reward, so it inverts every property of the sparkle:
				# heavy debris that falls instead of rising, the substance's
				# own colour soured, and a low shake. The player should wince.
				Juice.burst(at, res.tint.darkened(0.45), 14, &"debris")
				Juice.shake(0.30)
				if pick != null and is_instance_valid(pick):
					Juice.pop(_pop_target(pick), 0.16, 0.26)
			else:
				# TIER 0. Under-dosed. Four grey specks — the ABSENCE is the
				# feedback, and a player who sees this next to a sweet spot
				# knows immediately which one they got.
				Juice.burst(at, Color(0.62, 0.62, 0.58), 4, &"sparkle")


func set_eat_target(node: Node) -> void:
	_eating = node


## Release the charge loop if the player wanders off mid-hold.
func _abort_charge() -> void:
	if _charging and _sfx:
		_charging = false
		_sfx.stop_loop(&"charge")


func clear_eat_target(node: Node) -> void:
	if _eating == node:
		_eating = null
		_eat_charge = 0.0


func get_eat_charge() -> float:
	return _eat_charge


func get_eat_substance() -> Substance:
	if _eating and is_instance_valid(_eating):
		return _eating.substance
	return null


# ---------------------------------------------------------------- misc

## Webbed-foot slaps, paced by how fast we're actually moving. Silent in the
## air and silent when idle, which is most of what makes it read as walking.
func _tick_footsteps(delta: float) -> void:
	if state != State.GROUND or _sfx == null:
		return
	var spd := Vector2(velocity.x, velocity.z).length()
	if spd < 0.6:
		_step_t = 0.0
		return
	_step_t -= delta * clampf(spd / 3.0, 0.4, 3.2)
	if _step_t <= 0.0:
		_step_t = 0.34
		_sfx.play_var([&"waddle_1", &"waddle_2"], -13.0, 0.16)


## Radians of bank per radian-per-second of turn rate.
##
## This used to be 11.0 applied to a RAW PER-FRAME heading delta, which is not a
## turn rate — it is a turn rate multiplied by frame time. The same stick input
## therefore asked for 2.4x less bank at 144 Hz than at 60 Hz, so the tuning only
## ever meant anything on the monitor it was typed on, and it is exactly the
## framerate-coupling CLAUDE.md forbids.
##
## 0.183 is that same 11.0 carried across the division at 60 Hz (11.0 / 60), so
## the number the tuning always *claimed* is what is asked for now. The bank you
## actually SEE still roughly doubles, because until the matching change in the
## two visuals' animate() it was losing 52% of itself in a fight over
## body.rotation.z. This is the first honest reading of these numbers; it is a
## tuning dial and a human should drag it.
const BANK_PER_RATE := 0.183

func _animate(delta: float) -> void:
	if visual and visual.has_method("animate"):
		var gs := Vector2(velocity.x, velocity.z).length() / maxf(waddle_speed, 0.1)
		visual.animate(delta, _flap_anim, gs, state == State.FLY)
		visual.set_tint(Subs.primary_tint(), 0.0 if Subs.actives.is_empty() else 0.30)
		# Bank into turns while flying. Reads as intent and costs nothing.
		if visual.has_method("set_bank"):
			if state == State.FLY:
				# rad/s, not rad-per-frame. See BANK_PER_RATE above.
				var rate := wrapf(heading - _bank_ref, -PI, PI) / maxf(delta, 0.0001)
				_bank = lerpf(_bank, clampf(rate * BANK_PER_RATE, -0.7, 0.7), 1.0 - pow(0.02, delta))
				visual.set_bank(_bank, delta)
			else:
				_bank = lerpf(_bank, 0.0, 1.0 - pow(0.02, delta))
				visual.set_bank(_bank, delta)
		_bank_ref = heading


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("gg_honk") and honker:
		# Honk pitch tracks body size. Tiny goose squeaks, giant goose foghorns.
		# Free, and it's exactly the kind of detail that makes a clip.
		var pitch: float = Subs.mods.honk_pitch * pow(clampf(size, 0.2, 4.0), -0.55)
		honker.do_honk(pitch)
	elif e.is_action_pressed("gg_share"):
		# Share what you're on with the flock. Fun now, expensive in the air.
		if not Subs.actives.is_empty():
			Flock.dose_flock(0.32)
			Game.score(75, "SHARED WITH THE FLOCK", global_position)
			Juice.burst(global_position + Vector3.UP * 0.6,
				Subs.primary_tint(), 10, &"sparkle")


# ---------------------------------------------------------------- blackout

## TIER 5 — THE PEAK OF THE ENTIRE BUDGET, and the only thing allowed up here.
##
## Three substances at once wipes your actives, takes your speed to zero and
## costs you three seconds of the clock. It is the largest single punish in the
## game, so it gets the largest single beat: 1.10 shake against a 1.20 ceiling,
## and the longest hitstop the system will issue. Everything else in the table
## is measured against this — a prop break is deliberately less than two thirds
## of it, and a routine cart-bump is a twentieth.
##
## Nothing else may ever ask for these numbers.
func _on_blackout_started() -> void:
	Juice.hitstop(0.11, 1.0)
	Juice.shake(1.10)
	Juice.burst(global_position + Vector3.UP * 0.5,
		Color(0.20, 0.16, 0.26), 18, &"feathers")
	Juice.floating_text(global_position + Vector3.UP * 1.4, "BLACKOUT",
		Color(0.82, 0.36, 0.98))


## Coming round gets text and nothing else. After three seconds of a black
## screen the player needs information, not another effect.
func _on_blackout_ended() -> void:
	Juice.floating_text(global_position + Vector3.UP * 1.2, "...ow.",
		Color(0.72, 0.74, 0.82))


func is_airborne() -> bool:
	return state == State.FLY


func state_name() -> String:
	return ["GROUND", "WATER", "FLYING", "TUMBLING"][state]
