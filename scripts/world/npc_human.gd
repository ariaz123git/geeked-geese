extends CharacterBody3D
class_name NpcHuman
## A person in a parking lot. Wanders, complains, flees from honking.
## Deliberately not a threat — the comedy is that you are the aggressor and
## nothing can be done about it, which is also true of real Canada geese.

const WANDER_SPEED := 2.0
const FLEE_SPEED := 6.5

var _flee_time := 0.0
var _flee_dir := Vector3.ZERO
var _wander_dir := Vector3.FORWARD
var _wander_t := 0.0
var _startle_cd := 0.0
var _home := Vector3.ZERO
var _sfx: Node
## Faceted variant, used when settings ask for the low-poly art style.
var _lp: Node3D


func _ready() -> void:
	_sfx = get_node_or_null("/root/Sfx")
	add_to_group("npc")
	_home = global_position
	_new_wander()


## People are authored twice, same as the cats, so the crowd matches whichever
## goose model is live. The old primitive version is kept because "classic"
## mode should be internally consistent too.
func _use_lowpoly() -> bool:
	var prefs := get_node_or_null("/root/Prefs")
	if prefs == null:
		return true
	return str(prefs.get_pref(&"goose_model", "lowpoly")) == "lowpoly"


func setup(shirt: Color) -> void:
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.7
	cs.shape = cap
	cs.position.y = 0.85
	add_child(cs)

	if _use_lowpoly():
		_lp = preload("res://scripts/world/human_visual_lowpoly.gd").new()
		_lp.name = "VisLP"
		# setup() BEFORE add_child(), and the order is the whole point.
		# add_child() puts the visual in the tree, which runs its _ready(),
		# which builds a default-coloured person because _built is false; the
		# next line then called setup(), which queue_free()s all of that and
		# builds the entire eight-mesh body a second time. Every NPC in every
		# zone was paying for two full SurfaceTool commits, and for one frame
		# both copies were in the tree fighting over the same node names.
		# setup() is documented safe out of tree and sets _built itself, so
		# _ready() now finds the work done and skips.
		_lp.setup(shirt)
		add_child(_lp)
		return

	var vis := Node3D.new()
	vis.name = "Vis"
	add_child(vis)

	# torso
	var torso := MeshInstance3D.new()
	var tb := BoxMesh.new()
	tb.size = Vector3(0.48, 0.72, 0.28)
	torso.mesh = tb
	var m1 := StandardMaterial3D.new()
	m1.albedo_color = shirt
	torso.material_override = m1
	torso.position.y = 1.12
	vis.add_child(torso)

	# legs
	var legs := MeshInstance3D.new()
	var lb := BoxMesh.new()
	lb.size = Vector3(0.4, 0.78, 0.26)
	legs.mesh = lb
	var m2 := StandardMaterial3D.new()
	m2.albedo_color = Color(0.16, 0.18, 0.26)
	legs.material_override = m2
	legs.position.y = 0.39
	vis.add_child(legs)

	# head
	var head := MeshInstance3D.new()
	var hs := SphereMesh.new()
	hs.radius = 0.17
	hs.height = 0.34
	head.mesh = hs
	var m3 := StandardMaterial3D.new()
	m3.albedo_color = Color(0.85, 0.68, 0.55)
	head.material_override = m3
	head.position.y = 1.66
	vis.add_child(head)


func _new_wander() -> void:
	_wander_t = randf_range(1.8, 4.5)
	_wander_dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()


func startle(from: Vector3) -> void:
	if _startle_cd > 0.0:
		return
	_startle_cd = 0.5
	# TIER 0. A jump, no shake, no particles: there can be a dozen people in a
	# lot and a honk startles all of them at once, so anything that touched the
	# camera here would multiply by the crowd size. The pop sells the reaction
	# far better than the flee animation alone did, and it costs one Dictionary.
	# It rides the existing 0.5 s cooldown, so held-down honking can't turn the
	# crowd into a strobe.
	#
	# The pop goes on the VISUAL, never on `self`. This was `Juice.pop(self,
	# ...)`, and `self` is a CharacterBody3D: for 0.2 s that scaled the 1.7 m
	# capsule to roughly 2.07 m and dropped its bottom 19 cm through the floor,
	# on every person in the lot, on every honk — and depenetration then shoved
	# the whole crowd. cat.gd has carried the comment explaining exactly this
	# for as long as this line has been wrong, and boss_ranger.gd cites it.
	var vis: Node3D = _lp if _lp != null else (get_node_or_null("Vis") as Node3D)
	if vis != null and is_instance_valid(vis):
		Juice.pop(vis, 0.22, 0.20)
	if _sfx:
		_sfx.play_var([&"human_yelp_1", &"human_yelp_2"], -3.0, 0.14)
	_flee_time = randf_range(1.6, 3.0)
	_flee_dir = (global_position - from)
	_flee_dir.y = 0
	_flee_dir = _flee_dir.normalized()
	if _flee_dir.length() < 0.1:
		_flee_dir = Vector3.FORWARD


func _physics_process(delta: float) -> void:
	_startle_cd = maxf(0.0, _startle_cd - delta)
	var speed := WANDER_SPEED
	var dir := _wander_dir

	if _flee_time > 0.0:
		_flee_time -= delta
		speed = FLEE_SPEED
		dir = _flee_dir
		# Flailing run.
		var vis := get_node_or_null("Vis")
		if vis:
			vis.rotation.z = sin(Time.get_ticks_msec() * 0.02) * 0.3
		if _lp:
			_lp.animate(delta, speed / FLEE_SPEED, 1.0)
	else:
		_wander_t -= delta
		if _wander_t <= 0.0:
			_new_wander()
		# Drift back toward home so they don't all end up in one corner.
		if global_position.distance_to(_home) > 22.0:
			dir = (_home - global_position).normalized()
		var vis := get_node_or_null("Vis")
		if vis:
			vis.rotation.z = lerpf(vis.rotation.z, 0.0, 1.0 - pow(0.01, delta))
		if _lp:
			_lp.animate(delta, speed / FLEE_SPEED, 0.0)

	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	velocity.y -= 22.0 * delta
	if is_on_floor():
		velocity.y = 0.0

	if dir.length() > 0.05:
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), clampf(8.0 * delta, 0.0, 1.0))

	move_and_slide()
