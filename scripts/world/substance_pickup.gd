extends Area3D
class_name SubstancePickup
## A source of something. Stand in it and hold [E] to build a dose, release to
## commit. The skill is in letting go at the right moment, not in holding.
##
## Sources RESPAWN — this isn't an inventory game. The scarcity that matters is
## tolerance, not supply.
##
## Each substance gets its own little hand-built model (see pickup_models.gd)
## rather than a generic coloured sphere, because "what is that thing on the
## ground" is a question the player should be able to answer from ten metres.

@export var substance: Substance
@export var respawn_time := 9.0
@export var infinite := false

var available := true

var _visual_root: Node3D
var _model: Node3D
var _fallback: MeshInstance3D
var _glow: OmniLight3D
var _goose: Node = null
var _t := 0.0
var _anim_style: StringName = &"bob"

## Which idle animation suits which pickup. Living things breathe, plants sway.
const ANIM_STYLES := {
	&"molly": &"breathe",
	&"toad_slime": &"breathe",
	&"grass": &"sway",
	&"catnip": &"sway",
	&"fly_agaric": &"sway",
	&"gravy": &"bob",
	&"bars": &"bob",
	&"percs": &"bob",
	&"acid": &"bob",
}


func _ready() -> void:
	add_to_group("substance_source")
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)
	monitoring = true


func setup(res: Substance, size := 0.55) -> void:
	substance = res

	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 1.6
	cs.shape = sh
	add_child(cs)

	var tint: Color = res.tint if res != null else Color.MAGENTA
	var id: StringName = res.id if res != null else &""
	_anim_style = ANIM_STYLES.get(id, &"bob")

	# Everything you can see hangs off this holder rather than off the Area3D or
	# off the animated model. It fixes two separate versions of the same
	# mistake — a transform written once at build time onto a node something
	# else assigns every frame:
	#
	#   * the 0.15 m lift used to be written straight onto `_model`, and
	#     PickupModels.animate()'s default &"bob" branch assigns
	#     `model.position.y` ABSOLUTELY. The lift therefore survived exactly one
	#     frame, and eleven of the sixteen pickups sat 15 cm below where the
	#     zones do their arithmetic — zone_cottage.gd:1423 subtracts against
	#     that number by name. Only &"breathe" and &"sway", which touch scale
	#     and rotation.z instead, ever kept it. The lift now lives on a parent
	#     that no animation style touches, so all three styles agree.
	#   * Juice.pop() gets handed this pickup by the eat code, and the pickup is
	#     an Area3D with the 1.6 m eat trigger bolted directly to it — so a
	#     well-timed dose was briefly reshaping the volume that decides whether
	#     the goose is still allowed to eat. `visual_node()` exists so callers
	#     have something to pop that is not a physics volume.
	#
	# Do NOT move the model's own position/scale writes onto this node without
	# rendering first: &"breathe" also overwrites `_model.scale` absolutely, and
	# un-stomping that changes the visible size of the toad and Molly, which
	# zone_cottage.gd is tuned against.
	_visual_root = Node3D.new()
	_visual_root.name = "Visual"
	add_child(_visual_root)

	# Try for a real model first; fall back to the old glowing sphere so a
	# substance without a model is still visible and playable.
	if res != null and PickupModels.has_model(id):
		_visual_root.position.y = 0.15
		_model = PickupModels.build(id, _visual_root)
		# Scale the authored model toward the caller's requested size. Models are
		# authored around 0.8 units tall, so this stays close to 1.0 normally.
		var k: float = clampf(size / 0.5, 0.7, 1.8)
		_model.scale = Vector3.ONE * k
	else:
		_fallback = MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = size
		sm.height = size * 2.0
		_fallback.mesh = sm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = tint
		mat.emission_enabled = true
		mat.emission = tint * 0.6
		mat.emission_energy_multiplier = 0.9
		_fallback.material_override = mat
		# Holder stays at y = 0 on this branch: the fallback sphere drives its
		# own absolute height in _process (0.7 + a bob) and always did.
		_visual_root.add_child(_fallback)

	# A small coloured light so pickups read at distance and at dusk. This is
	# pure findability — without it players walk past things in the shadows.
	_glow = OmniLight3D.new()
	_glow.light_color = tint
	_glow.light_energy = 0.55
	_glow.omni_range = 3.4
	_glow.shadow_enabled = false
	_glow.position.y = 0.5
	add_child(_glow)


func _process(delta: float) -> void:
	_t += delta
	if _model and is_instance_valid(_model):
		PickupModels.animate(_model, delta, _t, _anim_style)
	elif _fallback and is_instance_valid(_fallback):
		_fallback.position.y = 0.7 + sin(_t * 3.0) * 0.12
		_fallback.rotate_y(delta * 1.1)
	if _glow:
		_glow.light_energy = 0.45 + sin(_t * 2.2) * 0.12


func _on_enter(body: Node3D) -> void:
	if body is Goose and available:
		_goose = body
		body.set_eat_target(self)


func _on_exit(body: Node3D) -> void:
	if body is Goose:
		body.clear_eat_target(self)
		if _goose == body:
			_goose = null


## The node to hand to Juice.pop(), or to anything else that wants to squash or
## flash this pickup for a frame. Deliberately NOT `self`: this is an Area3D
## whose only collision shape is the 1.6 m eat trigger, and scaling a physics
## body scales its collider — a reward for good timing has no business changing
## the radius at which the goose is allowed to eat. Null until setup() has run,
## so check it.
func visual_node() -> Node3D:
	return _visual_root


func _visible_state(v: bool) -> void:
	if _model and is_instance_valid(_model):
		_model.visible = v
	if _fallback and is_instance_valid(_fallback):
		_fallback.visible = v
	if _glow:
		_glow.visible = v


func consumed() -> void:
	# TIER 0, and deliberately before the `infinite` early-out so that every
	# successful dose gets it, not just the ones that drain a finite source.
	# This is the SOURCE reacting; the goose controller fires a second,
	# outcome-specific burst slightly above it (sparkle for a sweet spot,
	# falling debris for an overdose). Two small bursts 0.4 m apart read as one
	# event with a shape to it.
	Juice.burst(global_position, substance.tint if substance else Color.WHITE,
		10, &"sparkle")
	if infinite:
		return
	available = false
	_visible_state(false)
	if _goose and is_instance_valid(_goose):
		_goose.clear_eat_target(self)
	await get_tree().create_timer(respawn_time).timeout
	if not is_inside_tree():
		return
	available = true
	_visible_state(true)
	# Re-offer to a goose that never left the trigger while we were empty,
	# otherwise the player has to walk out and back in to eat again.
	for b in get_overlapping_bodies():
		if b is Goose:
			_goose = b
			b.set_eat_target(self)
			break
