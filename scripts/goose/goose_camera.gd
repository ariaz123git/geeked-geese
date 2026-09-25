extends Node3D
## Third-person chase rig. Lives at scene root and follows the goose by
## position only, so the bird can spin without whipping the camera around.
##
## Two control modes, blended automatically:
##   - AUTO: yaw drifts to follow the direction of travel. Good for flying,
##     good for players who never touch the mouse.
##   - MANUAL: the moment the mouse moves, the player owns the yaw and pitch.
##     Auto-follow resumes after a few seconds of no mouse input, so you get
##     free look without having to fight the camera back.
##
## The FOV push at speed is doing a lot of unpaid labour here — it's most of
## why fast flight feels fast. Don't remove it.

@export var target: Node3D
@export var height := 2.2
@export var distance := 6.0
@export var distance_fly := 8.5
@export var follow_lag := 6.0
@export var yaw_lag := 2.6
@export var fov_base := 68.0
@export var fov_fast := 88.0

## Seconds of no mouse movement before auto-follow takes the yaw back.
const AUTO_RESUME_DELAY := 2.5
const PITCH_MIN := deg_to_rad(-72.0)
const PITCH_MAX := deg_to_rad(38.0)
## Radians a second at full right-stick deflection, up or down. Two thirds of
## the 2.4 the stick and J / K turn at, because the pitch range (110°) is a
## third of a turn and the whole of it in about 1.2 s is plenty. Decided
## without playing it (D-077); one number to revert.
const PAD_PITCH_RATE := 1.6
const ZOOM_MIN := 2.2
const ZOOM_MAX := 16.0

var arm: SpringArm3D
var camera: Camera3D
## Set by the goose when a macropsia substance is scaling it.
var size_mult := 1.0

var _yaw := 0.0
var _pitch := deg_to_rad(-9.0)
var _manual_t := 0.0
var _zoom := 1.0
var _sens := 0.25
var _invert := false
var _fov_pref := 68.0
## False until the first _process has adopted the goose's spawn heading. See
## _adopt_heading().
var _yaw_seeded := false


func _ready() -> void:
	arm = SpringArm3D.new()
	arm.spring_length = distance
	arm.margin = 0.35
	arm.collision_mask = 1
	add_child(arm)

	camera = Camera3D.new()
	camera.fov = fov_base
	camera.near = 0.05
	camera.far = 900.0
	arm.add_child(camera)

	if target:
		global_position = target.global_position + Vector3.UP * height
		# Never let the spring arm collide with the bird it's following, or the
		# camera slams into the goose's own capsule every time you slow down.
		arm.add_excluded_object(target.get_rid())
	# First read, so the controller has a sane camera yaw to steer against if a
	# physics tick beats the first _process. Deliberately does NOT set
	# `_yaw_seeded` — the authoritative adopt happens on the first _process, by
	# which time the zone has finished composing regardless of whether it set the
	# heading before or after it built this rig.
	_adopt_heading()

	_read_prefs()
	var prefs := get_node_or_null("/root/Prefs")
	if prefs and prefs.has_signal("pref_changed"):
		prefs.pref_changed.connect(func(_k, _v): _read_prefs())


func _read_prefs() -> void:
	var prefs := get_node_or_null("/root/Prefs")
	if prefs == null:
		return
	_sens = float(prefs.get_pref(&"mouse_sensitivity", 0.25))
	_invert = bool(prefs.get_pref(&"invert_y", false))
	_fov_pref = float(prefs.get_pref(&"fov", 68.0))
	fov_base = _fov_pref
	fov_fast = _fov_pref + 20.0


func get_yaw() -> float:
	return _yaw


## THE CAMERA STARTS BEHIND THE GOOSE, FACING WHERE THE GOOSE IS FACING.
##
## `_yaw` used to start at 0 and only ever chase VELOCITY, so a stationary bird
## at spawn was photographed from world +Z looking down -Z no matter what the
## zone set `goose.heading` to. That is a silent trap for zone authors and it has
## now caught two of them: `zone_corn.gd` composed its opening shot, rendered it,
## found the camera somewhere else, and recomposed the whole field around -Z with
## a twenty-line comment explaining why the heading "is not a free choice";
## `zone_cottage.gd` shipped a spawn heading that was flatly wrong (PI, commented
## "facing the water", with the water at -Z) for three builds, and nobody could
## see it BECAUSE the camera was hiding it.
##
## Documenting the convention was the alternative and it is the worse fix: the
## bug it prevents is invisible, it costs a render cycle every time somebody
## rediscovers it, and it makes `goose.heading` a field that means something in
## the physics and nothing in the picture. A chase camera that starts anywhere
## other than behind its target is not a convention, it is a defect.
##
## `heading` is the controller's authoritative yaw (`_face()` writes it and then
## copies it into `rotation.y`, and `_ready()` seeds it FROM `rotation.y`), so it
## is read first and the node rotation is only the fallback for a target that
## isn't the goose. Same `get()`-returns-null idiom `boss_ranger.gd` uses for the
## same property, because `heading` is not on Node3D.
func _adopt_heading() -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var h := 0.0
	var raw: Variant = target.get("heading")
	if raw != null:
		h = float(raw)
	else:
		h = target.global_rotation.y
	_yaw = h
	rotation.y = _yaw
	return true


## Kept as a forwarder so any caller that still holds a rig reference keeps
## working — but the rig no longer owns an accumulator. Juice applies the
## `screen_shake` pref itself, so there is deliberately no local multiply here;
## doing it in both places applied the pref twice and made a slider at 0.5 read
## as 0.25.
func add_shake(amount: float) -> void:
	Juice.shake(amount)


# ---------------------------------------------------------------- input

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		# Only steer while the cursor is actually captured, otherwise moving the
		# mouse over a menu would yank the camera around behind it.
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			return
		var rel: Vector2 = e.relative
		_yaw -= rel.x * _sens * 0.006
		var dy := rel.y * _sens * 0.006
		_pitch += dy if _invert else -dy
		_pitch = clampf(_pitch, PITCH_MIN, PITCH_MAX)
		_manual_t = AUTO_RESUME_DELAY
		get_viewport().set_input_as_handled()

	elif e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = clampf(_zoom * 0.88, ZOOM_MIN / distance, ZOOM_MAX / distance)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = clampf(_zoom * 1.14, ZOOM_MIN / distance, ZOOM_MAX / distance)


# ---------------------------------------------------------------- loop

func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return

	# ONE-SHOT, on the first frame the rig ever runs, and then never again — from
	# here down this function behaves exactly as it did. See _adopt_heading().
	if not _yaw_seeded:
		_yaw_seeded = _adopt_heading()

	var sm: float = clampf(size_mult, 0.2, 4.0)

	# --- position follow ---
	# Ketamine detaches the camera from the bird. You still control the goose,
	# but you're watching from somewhere else, and it drifts. This is the whole
	# joke and it's mechanically brutal — do not soften it.
	var detach: float = Subs.mods.get("camera_detach", 0.0)
	var want := target.global_position + Vector3.UP * height * sm
	if detach > 0.01:
		var t := float(Time.get_ticks_msec()) * 0.0004
		want += Vector3(sin(t * 1.3), cos(t * 0.7) * 0.5, cos(t * 1.1)) * 9.0 * detach
	var lag := follow_lag * lerpf(1.0, 0.12, clampf(detach, 0.0, 1.0))
	global_position = global_position.lerp(want, clampf(lag * delta, 0.0, 1.0))

	# --- yaw: manual while the mouse is warm, auto-follow otherwise ---
	_manual_t = maxf(0.0, _manual_t - delta)
	var vel: Vector3 = target.velocity if target is CharacterBody3D else Vector3.ZERO
	var flat := Vector2(vel.x, vel.z)
	if _manual_t <= 0.0 and flat.length() > 1.2:
		var travel := atan2(-flat.x, -flat.y)
		_yaw = lerp_angle(_yaw, travel, clampf(yaw_lag * delta, 0.0, 1.0))

	# Keyboard nudge still works for anyone not using a mouse — and the right
	# stick's horizontal is bound to the same two actions, analog (D-077).
	var kb := Input.get_action_strength("gg_cam_right") - Input.get_action_strength("gg_cam_left")
	if absf(kb) > 0.01:
		_yaw -= kb * delta * 2.4
		_manual_t = AUTO_RESUME_DELAY
	# The right stick's vertical: the mouse's pitch, for a pad. Same sign as
	# the mouse (stick down looks down) and the same Invert Y pref.
	var kp := Input.get_action_strength("gg_cam_down") - Input.get_action_strength("gg_cam_up")
	if absf(kp) > 0.01:
		_pitch = clampf(_pitch + (kp if _invert else -kp) * delta * PAD_PITCH_RATE, PITCH_MIN, PITCH_MAX)
		_manual_t = AUTO_RESUME_DELAY

	rotation.y = _yaw

	# --- pull back and widen with speed ---
	var airborne: bool = target.has_method("is_airborne") and target.is_airborne()
	var speed := vel.length()
	var d := lerpf(distance, distance_fly, clampf(speed / 18.0, 0.0, 1.0)) * sm * _zoom
	arm.spring_length = lerpf(arm.spring_length, d, clampf(3.0 * delta, 0.0, 1.0))

	# Auto pitch when the player isn't steering; their pitch wins when they are.
	var auto_pitch := deg_to_rad(-14.0 if airborne else -8.0)
	var want_pitch := _pitch if _manual_t > 0.0 else lerpf(arm.rotation.x, auto_pitch, clampf(2.0 * delta, 0.0, 1.0))
	arm.rotation.x = lerpf(arm.rotation.x, want_pitch, clampf(10.0 * delta, 0.0, 1.0))
	if _manual_t <= 0.0:
		# Keep _pitch in sync so handing control back doesn't snap the view.
		_pitch = arm.rotation.x

	var want_fov := lerpf(fov_base, fov_fast, clampf(speed / 22.0, 0.0, 1.0))
	# Caffeine punches the FOV; nitrous pulls it in.
	#
	# `Subs.mods.time_scale`, NOT `Engine.time_scale`. The published clock is
	# Juice's OUTPUT — juice.gd rewrites it every frame of a hitstop as
	# `base * dip`, bottoming out around 0.04 x base — so reading it here handed
	# the lens a ~12% pull-in on every prop break, hard landing, faceplant and
	# blackout, none of which have anything to do with how fast the bird is
	# going. Juice itself refuses to read the live value for exactly this reason
	# (juice.gd::_substance_scale, "reading the live value would feed Juice's own
	# output back into itself"), and the doc-comment at the top of this file says
	# the FOV push is most of why fast flight feels fast. A channel that means
	# speed cannot also twitch on impacts, so it reads the same thing Juice does:
	# the substance system's unsmoothed intent for the clock.
	#
	# It only ever looked small because the hitstop's own scaled delta shrinks
	# this lerp's rate at the same time. That is an accident, not a design.
	var ts: float = Subs.mods.get("time_scale", 1.0)
	want_fov *= lerpf(1.0, 0.88, clampf(1.0 - ts, 0.0, 1.0))
	camera.fov = lerpf(camera.fov, want_fov, clampf(4.0 * delta, 0.0, 1.0))

	# --- shake ---
	# This rig is the ONLY consumer of Juice's global shake bus in the zone.
	# Everything that wants to shake the screen — a prop breaking on the far
	# side of the lot, a landing, a honk — calls Juice.shake() and lands here,
	# through one cap, one decay and one accessibility pref.
	#
	# The substance jitter is a second, continuous channel and is deliberately
	# NOT pushed into the bus: a per-frame top-up would sit inside the shared
	# 1.2 cap and swallow real impacts while a trip is running. It is still
	# gated on both prefs, read from Juice so there is exactly one place in the
	# codebase that interprets them.
	var jitter := 0.0
	if int(Subs.mods.get("fx_mode", 0)) == 2:
		jitter = float(Subs.mods.get("fx_strength", 0.0)) * 0.5 \
			* Juice.shake_scale() * clampf(Juice.fx_scale(), 0.0, 1.5)
	var s: float = (Juice.shake_value() + jitter) * 0.06
	if s > 0.0001:
		camera.h_offset = randf_range(-s, s)
		camera.v_offset = randf_range(-s, s)
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0
