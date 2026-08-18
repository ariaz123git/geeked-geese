extends RigidBody3D
class_name ChaosProp
## Anything a goose can ruin. Shopping carts, garbage bags, patio furniture,
## lawn signs, the recycling. Award points generously — the game is a comedy,
## not an audit.

@export var points := 25
@export var break_force := 9.0
@export var label := "SMASH"
@export var breakable := true

## Impulse is capped as if nothing weighs more than this. Physically a shove
## should scale with mass to give the same velocity change — but that makes a
## 900 kg minivan launch like a shopping cart, which feels wrong and looks
## wrong. Capping the effective mass makes heavy things read as heavy.
const IMPULSE_MASS_CAP := 55.0

## Preloaded rather than referenced by class_name: global class registration
## only exists after an editor import pass, so a `class_name` reference breaks
## in a fresh checkout or a headless CI run. A preload const always resolves.
const PROP_MODELS := preload("res://scripts/world/prop_models.gd")

var _broken := false
var _cooldown := 0.0
var _sfx: Node
var _size := Vector3.ONE
var _color := Color(0.7, 0.7, 0.7)

## Whatever is currently standing in for this prop on screen — the faceted
## model when there is one for this kind, the fallback BoxMesh otherwise.
## _break() hides THIS, not a node looked up by name, because the art pass made
## the visual a Node3D holding a mesh rather than a MeshInstance3D itself.
var _visual: Node3D = null


func _ready() -> void:
	_sfx = get_node_or_null("/root/Sfx")
	add_to_group("chaos_prop")
	contact_monitor = false
	can_sleep = true


## Called by the zone builder. Builds visual + collider from a box spec.
##
## THE COLLIDER IS ALWAYS THE BOX. `size` is the physics truth and nothing in
## the art pass is allowed to change it — a prop that behaved a certain way
## before the models went in behaves identically after.
##
## `model_kind` is purely cosmetic. When it names a model prop_models.gd knows
## how to build, the BoxMesh is skipped entirely and the faceted model takes
## its place, scaled so its footprint is exactly `size` and dropped by half the
## height so its base lands on the bottom of the collider:
##
##   * models are BASE-anchored (origin on the ground, growing +Y)
##   * BoxShape3D is CENTRE-anchored (origin in the middle)
##
## so the model has to move down by size.y * 0.5 or every prop in the zone
## hovers half its own height off the asphalt.
func setup(size: Vector3, color: Color, mass_kg: float, pts: int, lbl: String,
		model_kind: StringName = &"", model_params: Dictionary = {}) -> void:
	_size = size
	_color = color
	mass = mass_kg
	points = pts
	label = lbl

	if model_kind != &"" and PROP_MODELS.has_model(model_kind):
		var params: Dictionary = model_params.duplicate()
		params["size"] = size
		var model: Node3D = PROP_MODELS.build(model_kind, self, params)
		model.position.y = -size.y * 0.5
		# Kept called "Mesh" so anything that still looks the visual up by name
		# — including older saves of this file — finds it.
		model.name = "Mesh"
		_visual = model
	else:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		mi.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.8
		mi.material_override = mat
		mi.name = "Mesh"
		add_child(mi)
		_visual = mi

	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	add_child(cs)


## The score cooldown is gameplay, so it ticks in _physics_process — the same
## place the contacts that consume it come from — and in REAL seconds, using
## the division game.gd:81, substance_manager.gd:133 and juice.gd:262 all use.
##
## It used to be `_process(delta)` with the raw delta, and every delta the
## engine hands out is already multiplied by Engine.time_scale. Under THE
## OVERCLOCK (time_scale 0.45) the 0.6 s window became 1.33 real seconds, so
## the substance sold as a chaos multiplier quietly cut the rate at which props
## could pay out by more than half — the exact opposite of what it advertises,
## and invisible to the player. Inside a hitstop the window barely advanced at
## all. That is a bug and not a feature: the cooldown exists to stop one cart
## billing twice for one shove, which is a question about the wall clock and
## has nothing to do with how fast the world is running.
##
## **ANY SUBCLASS THAT OVERRIDES `_physics_process` MUST CALL `super(delta)`.**
## GDScript does not chain virtuals: an override replaces this outright, and the
## prop then never cools down, so it scores once and stays silent for the rest of
## its life. There is exactly one subclass in the project — `CreditSlab` in
## zone_finale.gd, which drives itself up the fairway — and moving this tick out
## of `_process` broke it silently until an adversarial verifier grepped for
## `extends CHAOS_PROP`. Grep for it again before moving this line.
func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta / maxf(Engine.time_scale, 0.05))


func shove(impulse: Vector3) -> void:
	apply_central_impulse(impulse * minf(mass, IMPULSE_MASS_CAP) * 0.35)
	_maybe_score(impulse.length() * 0.7)


func hit(force: float, impulse: Vector3) -> void:
	apply_central_impulse(impulse * minf(mass, IMPULSE_MASS_CAP) * 0.5)
	_maybe_score(force)


## Pick the impact sound from what this thing is, not from how hard it was hit.
func _impact_sound() -> StringName:
	if mass >= 200.0:
		return &"crash_heavy"
	if label == "CART" or label == "RECYCLING" or label == "BBQ":
		return &"crash_cart"
	return &"crash_light"


func _maybe_score(force: float) -> void:
	if _cooldown > 0.0 or _broken:
		return
	if force < 2.5:
		return
	_cooldown = 0.6
	Game.score(points, label, global_position)
	if _sfx:
		_sfx.play_at(_impact_sound(), self, clampf(-14.0 + force, -14.0, 0.0),
			randf_range(0.9, 1.12))

	# --- TIER 1 (see the budget in juice.gd). A non-fatal hit is the single
	# most frequent event in the game: a player waddling through the cart
	# corral triggers one every few hundred milliseconds. So it gets the
	# smallest shake in the table (0.04 at the threshold, 0.30 flat out) and
	# DELIBERATELY NO HITSTOP. A freeze on every glancing contact is exactly
	# the inflation failure that makes a game read as dropping frames.
	Juice.shake(clampf(force / 45.0, 0.04, 0.30))
	# The visual carries the read instead. `_visual` is the authoritative
	# reference (the art pass made it a Node3D wrapping the mesh); the two
	# name lookups are the fallback for props built before that landed.
	var vis: Node3D = _visual
	if vis == null or not is_instance_valid(vis):
		vis = get_node_or_null("Model") as Node3D
	if vis == null:
		vis = get_node_or_null("Mesh") as Node3D
	if vis != null:
		Juice.pop(vis, 0.16, 0.15)

	if breakable and force >= break_force:
		_break()


func _break() -> void:
	_broken = true

	# --- TIER 3. Breaking a prop is the game's headline verb and the biggest
	# thing that happens on a routine basis, so it gets the biggest routine
	# response: a short freeze, a shake that scales with how heavy the thing
	# was (a garbage bag is 0.25, a minivan is 0.70), debris, and the prop's
	# own name thrown up in gold. It is one of only five hitstop sites in the
	# whole game — see the budget table in juice.gd before adding a sixth.
	Juice.hitstop(0.07, 0.8)
	Juice.shake(clampf(mass / 60.0, 0.25, 0.7))
	# Lightened rather than the prop's raw `_color`. A render pass caught this:
	# the debris from a black garbage bag or a charcoal bin is the same
	# luminance as the asphalt it lands on and effectively renders as nothing,
	# which is the single most likely way a burst fails. A one-way lift keeps
	# the prop's identity (a red bench still throws red) while guaranteeing the
	# chunks separate from the ground under every prop colour in the game.
	Juice.burst(global_position, _color.lightened(0.28), 14, &"debris")
	Juice.floating_text(global_position + Vector3.UP * (_size.y * 0.6),
		"%s!!" % label, Color(1.0, 0.86, 0.32))

	Game.score(points * 2, label + "!!")
	if _sfx:
		_sfx.play_at(&"smash", self, 0.0, randf_range(0.92, 1.1))
		# The sub layer. This is Nijman's "more bass" step and it is the single
		# cheapest audio change available here: a low body under the existing
		# detail sample, rather than pitching one sample down and losing the
		# top end that makes the break read as breakage.
		_sfx.play_at(&"crash_heavy", self, -6.0, 0.6)
	# Hide the visual by reference, not by name. The faceted models are Node3Ds
	# with the mesh nested inside them, so a get_node("Mesh") that misses would
	# leave a fully intact shopping cart standing in its own debris.
	var visual: Node3D = _visual
	if visual == null or not is_instance_valid(visual):
		visual = get_node_or_null("Mesh") as Node3D
	if visual != null:
		visual.visible = false
	# Physical debris, now that Juice.burst() carries most of the read. Two
	# rigid bodies instead of five: the burst above is a fifth of the cost and
	# lands in the same frame, and during a pile-up the difference is the
	# difference between a physics hitch and none. The two that remain are the
	# ones doing the job the particles can't — they collide, they settle, and
	# they are still lying there when the player comes back past.
	for i in 2:
		var d := RigidBody3D.new()
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = _size * randf_range(0.16, 0.32)
		mi.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = _color.darkened(randf_range(0.0, 0.35))
		mi.material_override = mat
		d.add_child(mi)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = bm.size
		cs.shape = bs
		d.add_child(cs)
		d.mass = 0.4
		get_parent().add_child(d)
		d.global_position = global_position + Vector3(randf_range(-0.3, 0.3), randf_range(0.0, 0.5), randf_range(-0.3, 0.3))
		d.apply_central_impulse(Vector3(randf_range(-3, 3), randf_range(2, 6), randf_range(-3, 3)))
		d.get_tree().create_timer(6.0).timeout.connect(d.queue_free)

	set_collision_layer_value(1, false)
	await get_tree().create_timer(0.2).timeout
	queue_free()
