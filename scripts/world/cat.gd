extends CharacterBody3D
class_name Cat
## A parking-lot cat.
##
## Cats exist so that CATNIP has something to command. Catnip is the one
## substance that does almost nothing to the goose — it turns every cat in the
## zone into your artillery. It's a summon, not a buff, and that's what makes it
## mechanically different from everything else in the game.
##
## Roughly two thirds of cats respond to catnip at all; the rest are genetically
## indifferent. So one cat in three here will simply refuse to help you, which
## is both accurate and much funnier than all of them working.

const WANDER_SPEED := 2.6
const FRENZY_SPEED := 11.0

@export var responds_to_nip := true

## Whether _ready() rolls the dice for `responds_to_nip`, which it used to do
## unconditionally. That made the exported value above decorative: a caller
## doing the normal code-built-tree thing — set the property, then add_child()
## — had it silently overwritten a frame later, and there was no way to place a
## cat that is guaranteed to respond (a scripted catnip beat) or guaranteed not
## to. Set this false BEFORE add_child() and `responds_to_nip` is yours.
@export var randomise_nip := true

var _wander_dir := Vector3.FORWARD
var _wander_t := 0.0
var _target: Node3D = null
var _retarget_t := 0.0
var _frenzy := false
var _vis: Node3D
## Faceted variant, used when settings ask for the low-poly art style. When
## this is set it owns all animation and _vis is never built.
var _lp: Node3D
var _sfx: Node
var _meow_t := 0.0


func _ready() -> void:
	_sfx = get_node_or_null("/root/Sfx")
	_meow_t = randf_range(4.0, 14.0)
	add_to_group("cat")
	# ~1 in 3 cats is a dud. Genetics.
	if randomise_nip:
		responds_to_nip = randf() < 0.67
	_new_wander()


const LP_PATTERNS := [&"tabby", &"grey", &"tuxedo"]


## Cats are authored twice: a smooth-primitive version and a faceted one, so
## the world stays stylistically consistent with whichever goose model is live.
func _use_lowpoly() -> bool:
	var prefs := get_node_or_null("/root/Prefs")
	if prefs == null:
		return true
	return str(prefs.get_pref(&"goose_model", "lowpoly")) == "lowpoly"


func setup(fur: Color) -> void:
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.16
	cap.height = 0.5
	cs.shape = cap
	cs.rotation_degrees = Vector3(90, 0, 0)
	cs.position.y = 0.24
	add_child(cs)

	if _use_lowpoly():
		_lp = preload("res://scripts/world/cat_visual_lowpoly.gd").new()
		_lp.name = "VisLP"
		# Coat pattern is picked from the requested fur colour so a zone that
		# asks for five different cats still gets five different cats.
		var idx := int(absf(fur.h * 977.0 + fur.v * 331.0)) % LP_PATTERNS.size()
		# setup() BEFORE add_child(). add_child() runs the visual's _ready(),
		# which builds a default tabby because _built is false; setup() then
		# queue_free()d that and rebuilt all 350-550 triangles. Seven cats in
		# the strip mall alone were each being built twice, for nothing.
		_lp.setup(LP_PATTERNS[idx])
		add_child(_lp)
		return

	_vis = Node3D.new()
	_vis.name = "Vis"
	add_child(_vis)

	var m := StandardMaterial3D.new()
	m.albedo_color = fur
	m.roughness = 0.9

	var body := MeshInstance3D.new()
	var bm := CapsuleMesh.new()
	bm.radius = 0.15
	bm.height = 0.62
	body.mesh = bm
	body.material_override = m
	body.rotation_degrees = Vector3(90, 0, 0)
	body.position.y = 0.26
	_vis.add_child(body)

	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.13
	hm.height = 0.24
	head.mesh = hm
	head.material_override = m
	head.position = Vector3(0, 0.34, -0.30)
	_vis.add_child(head)

	# Ears — the whole silhouette, same as the goose's chinstrap.
	for sx in [-1.0, 1.0]:
		var ear := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(0.10, 0.13, 0.03)
		ear.mesh = pm
		ear.material_override = m
		ear.position = Vector3(sx * 0.07, 0.45, -0.28)
		_vis.add_child(ear)

	var tail := MeshInstance3D.new()
	var tm := CapsuleMesh.new()
	tm.radius = 0.035
	tm.height = 0.44
	tail.mesh = tm
	tail.material_override = m
	tail.rotation_degrees = Vector3(28, 0, 0)
	tail.position = Vector3(0, 0.38, 0.30)
	_vis.add_child(tail)

	for sx in [-1.0, 1.0]:
		for sz in [-0.18, 0.18]:
			var leg := MeshInstance3D.new()
			var lm := BoxMesh.new()
			lm.size = Vector3(0.06, 0.22, 0.06)
			leg.mesh = lm
			leg.material_override = m
			leg.position = Vector3(sx * 0.09, 0.11, sz)
			_vis.add_child(leg)


func _new_wander() -> void:
	_wander_t = randf_range(1.2, 3.4)
	_wander_dir = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()


func _physics_process(delta: float) -> void:
	var nip: bool = Subs.mods.get("aggro_cats", false) and responds_to_nip
	if nip and not _frenzy:
		_frenzy = true
		_retarget_t = 0.0
		# TIER 0. Catnip landing is the moment the zone's cats become your
		# artillery, and it deserves to be visible from across the lot — but
		# there are up to a dozen of them and they all flip in the SAME FRAME.
		# So: no shake and no floating text, either of which would multiply by
		# the cat population into a screen-wide mess. A green pop and a puff
		# each, and the read comes from a dozen of them happening at once.
		#
		# The pop goes on the visual, not on `self`: the cat is a
		# CharacterBody3D with a 0.5 m capsule, and scaling the body would drag
		# the collider through the asphalt.
		var vis: Node3D = _lp if _lp != null else _vis
		if vis != null and is_instance_valid(vis):
			Juice.pop(vis, 0.34, 0.24)
		Juice.burst(global_position + Vector3.UP * 0.35,
			Color(0.55, 0.92, 0.42), 8, &"sparkle")
		if _sfx:
			_sfx.play_at(&"meow_frenzy", self, -2.0, randf_range(0.9, 1.15))
	elif not nip and _frenzy:
		_frenzy = false
		_target = null

	# Idle meows, sparse enough to stay charming instead of maddening.
	_meow_t -= delta
	if _meow_t <= 0.0:
		_meow_t = randf_range(7.0, 20.0)
		if _sfx and not _frenzy:
			_sfx.play_at(&"meow", self, -10.0, randf_range(0.85, 1.2))

	var dir := _wander_dir
	var speed := WANDER_SPEED

	if _frenzy:
		speed = FRENZY_SPEED
		_retarget_t -= delta
		if _retarget_t <= 0.0 or _target == null or not is_instance_valid(_target):
			_retarget_t = 1.1
			_target = _nearest_victim()
		if _target and is_instance_valid(_target):
			dir = (_target.global_position - global_position)
			dir.y = 0.0
			dir = dir.normalized()
			if global_position.distance_to(_target.global_position) < 1.3:
				_pounce(_target)
		if _vis:
			# Full berserk wiggle.
			_vis.rotation.z = sin(Time.get_ticks_msec() * 0.045) * 0.55
			_vis.position.y = absf(sin(Time.get_ticks_msec() * 0.03)) * 0.18
		if _lp:
			_lp.animate(delta, speed / FRENZY_SPEED, 1.0)
	else:
		_wander_t -= delta
		if _wander_t <= 0.0:
			_new_wander()
		if _vis:
			_vis.rotation.z = lerpf(_vis.rotation.z, 0.0, 1.0 - pow(0.02, delta))
			_vis.position.y = lerpf(_vis.position.y, 0.0, 1.0 - pow(0.02, delta))
		if _lp:
			_lp.animate(delta, speed / FRENZY_SPEED, 0.0)

	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	velocity.y -= 22.0 * delta
	if is_on_floor():
		velocity.y = 0.0

	if dir.length() > 0.05:
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), clampf(10.0 * delta, 0.0, 1.0))

	move_and_slide()


func _nearest_victim() -> Node3D:
	var best: Node3D = null
	var best_d := 1e9
	for group in ["npc", "chaos_prop"]:
		for n in get_tree().get_nodes_in_group(group):
			if n is Node3D:
				var d: float = n.global_position.distance_to(global_position)
				if d < best_d and d < 55.0:
					best_d = d
					best = n
	return best


## Cats score without the player touching anything, so the numbers are the only
## way the player learns catnip is working. They get a position; they do not get
## a shake, because a frenzied cat pounces roughly once a second and there can
## be a dozen of them.
func _pounce(victim: Node3D) -> void:
	if victim.is_in_group("npc") and victim.has_method("startle"):
		victim.startle(global_position)
		Game.score(30, "CAT ATTACK", victim.global_position)
	elif victim.is_in_group("chaos_prop") and victim.has_method("shove"):
		var away: Vector3 = (victim.global_position - global_position).normalized() + Vector3.UP * 0.5
		victim.shove(away * 6.0)
		Game.score(20, "CAT vs PROPERTY", victim.global_position)
	_target = null
	_retarget_t = 0.6
