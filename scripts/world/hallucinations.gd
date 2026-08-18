extends Node3D
class_name Hallucinations
## Deliriant hallucinations, as a mechanic.
##
## Psychedelics make the real world look strange — that's the screen shader's
## job. DELIRIANTS are different, and the difference is the whole point of this
## file: they produce things that aren't there and that you cannot tell from
## things that are. So this spawns props and people that look completely
## ordinary, cast shadows, wander around, and simply do not exist.
##
## Design rules, learned the hard way from every game that has tried this:
##  1. Fakes must be visually IDENTICAL to real objects. If you tint them or
##     make them shimmer, the player learns the tell in ten seconds and the
##     mechanic evaporates.
##  2. Fakes have no collider and score nothing. Attacking one is a wasted
##     swing — that IS the cost, and it's enough. Don't add a penalty on top.
##  3. They dissolve when you get very close or when you look away, so the
##     player is never able to confirm one, only ever suspect it.
##  4. It has to end. Nothing here persists past the substance.

const MAX_FAKES := 14
const SPAWN_RING_MIN := 9.0
const SPAWN_RING_MAX := 30.0
const DISSOLVE_RANGE := 2.6

## Ground probe geometry, the same shape as flock_pen.gd's `_ground_at()` and
## for the same reason: a downward probe must never be able to return a surface
## ABOVE the point it was asked about, or a fake ends up standing on the roof of
## the building you are walking past. 0.6 m of up-margin covers the difference
## between the goose's origin and whatever it is actually resting on.
##
## The reach is much longer than the pen's 8 m because the pen never leaves the
## ground and the goose does. Probing from a bird twenty-five metres up still
## has to find the asphalt, and the cost of overshooting downward is nothing.
const GROUND_UP_MARGIN := 0.6
const GROUND_DOWN_REACH := 40.0

## Preloaded rather than referenced by class_name: global class registration
## only exists after an editor import pass, so a `class_name` reference breaks
## in a fresh checkout or a headless CI run. A preload const always resolves.
const HUMAN_LP := preload("res://scripts/world/human_visual_lowpoly.gd")
const PROP_MODELS := preload("res://scripts/world/prop_models.gd")

var goose: Node3D

var _fakes: Array[Node3D] = []
var _spawn_t := 0.0
var _strength := 0.0


## Physics, not process, and only because of the ground probe in `_spawn_one()`.
## `direct_space_state` is not queryable outside a physics frame — flock_pen.gd
## carries the same note where it drops the pen onto the zone's real surface.
## Nothing else here needed to move; the fakes have no colliders and the rest of
## this function is timers and a lerp.
func _physics_process(delta: float) -> void:
	var want: float = float(Subs.mods.get("hallucinate", 0.0))
	_strength = lerpf(_strength, want, 1.0 - pow(0.2, delta))

	if _strength < 0.04:
		if not _fakes.is_empty():
			_clear_all()
		return

	if goose == null or not is_instance_valid(goose):
		return

	_spawn_t -= delta
	var target_count := int(round(MAX_FAKES * clampf(_strength, 0.0, 1.0)))
	if _spawn_t <= 0.0 and _fakes.size() < target_count:
		_spawn_t = randf_range(0.35, 1.1)
		_spawn_one()

	# Cull: too close to inspect, too far to matter, or simply expired.
	for i in range(_fakes.size() - 1, -1, -1):
		var f := _fakes[i]
		if f == null or not is_instance_valid(f):
			_fakes.remove_at(i)
			continue
		var d := f.global_position.distance_to(goose.global_position)
		var life: float = f.get_meta("life", 8.0) - delta
		f.set_meta("life", life)

		if d < DISSOLVE_RANGE or d > SPAWN_RING_MAX * 1.7 or life <= 0.0:
			_dissolve(f)
			_fakes.remove_at(i)
			continue

		# Fake people shuffle about so they don't read as statues.
		if f.get_meta("walks", false):
			var dir: Vector3 = f.get_meta("dir", Vector3.FORWARD)
			f.global_position += dir * 1.5 * delta
			f.rotation.y = atan2(-dir.x, -dir.z)
			# AND THEY FOLLOW THE GROUND. Y was set once at spawn and then held
			# for a life of up to 16 s at 1.5 m/s — twenty-four metres of travel
			# on a fixed height. On the cottage plateau that is a fake person
			# who walks calmly off a 6.6 m granite shelf and keeps going at
			# shelf height, out over the lake, which is not a subtle tell.
			#
			# Re-probed on a cadence rather than every frame: the raycast is the
			# expensive part and a person at 1.5 m/s covers 12 cm between probes,
			# which no ground in this project changes height over. `move_toward`
			# rather than a snap so a kerb reads as a step up and not a teleport.
			var probe_t: float = float(f.get_meta("probe_t", 0.0)) - delta
			if probe_t <= 0.0:
				probe_t = 0.08
				f.set_meta("ground_y", _ground_y(f.global_position))
			f.set_meta("probe_t", probe_t)
			var want_y: float = float(f.get_meta("ground_y", f.global_position.y))
			f.global_position.y = move_toward(f.global_position.y, want_y, 4.0 * delta)
			# And their legs move, because the real crowd's do. A faceted
			# person gliding along in a fixed pose next to eight who are
			# walking is exactly the tell design rule 1 is about. Same call
			# npc_human.gd makes while wandering, with the same speed ratio.
			var lp := f.get_node_or_null("VisLP") as Node3D
			if lp != null:
				lp.animate(delta, 1.5 / 6.5, 0.0)


## THE GROUND UNDER A SPAWN POINT.
##
## This used to be the literal `pos.y = 0.0`, which is true in five of the seven
## zones and catastrophically false in cottage country: there y = 0 is the LAKE
## SURFACE and the walkable plateau — the one holding the gravy, which is the
## only substance in the game with `hallucinate = 1.0` — sits at 6.60. Every
## fake spawned six and a half metres under the player's feet, inside the
## granite face or bobbing on the lake, for the entire leg. The close-range
## dissolve could not fire either, because the vertical offset alone was more
## than twice DISSOLVE_RANGE, so fourteen invisible fakes just sat underground
## burning their life timers.
##
## A miss keeps the goose's own Y. Falling back to 0.0 is what caused this.
func _ground_y(at: Vector3) -> float:
	var space := get_world_3d().direct_space_state
	if space == null:
		return at.y
	var q := PhysicsRayQueryParameters3D.create(
		Vector3(at.x, at.y + GROUND_UP_MARGIN, at.z),
		Vector3(at.x, at.y - GROUND_DOWN_REACH, at.z))
	var res: Dictionary = space.intersect_ray(q)
	if res.has("position"):
		var p: Vector3 = res["position"]
		return p.y
	return at.y


func _spawn_one() -> void:
	var a := randf_range(0.0, TAU)
	var r := randf_range(SPAWN_RING_MIN, SPAWN_RING_MAX)
	var pos: Vector3 = goose.global_position + Vector3(cos(a) * r, 0.0, sin(a) * r)
	pos.y = _ground_y(pos)

	var f := Node3D.new()
	add_child(f)
	f.global_position = pos
	f.set_meta("life", randf_range(6.0, 16.0))

	# Weight toward people — a person who isn't there is far more unsettling
	# than a bin that isn't there, and much funnier when you honk at it.
	if randf() < 0.55:
		_build_person(f)
		f.set_meta("walks", true)
		var wa := randf_range(0.0, TAU)
		f.set_meta("dir", Vector3(cos(wa), 0.0, sin(wa)))
	else:
		_build_prop(f)

	_fakes.append(f)
	# Every fake owns its materials before anything writes an alpha into them.
	_own_materials(f)
	# Fade in over a moment. A fake that pops into being announces itself.
	_set_alpha(f, 0.0)
	var tw := f.create_tween()
	tw.tween_method(func(v: float): _set_alpha(f, v), 0.0, 1.0, 0.7)


## Same art the real crowd is built from, chosen the same way.
##
## This used to hardcode the primitive box-and-sphere person, on the theory that
## it matched NpcHuman. It stopped matching NpcHuman when the low-poly pass
## landed: Prefs ships `goose_model` = "lowpoly", so npc_human.gd takes the
## faceted branch by default and the fakes were the only sphere-headed
## mannequins left in the zone. Design rule 1 at the top of this file is not a
## suggestion — a sphere head standing next to a faceted head is a louder tell
## than any tint would have been.
func _build_person(f: Node3D) -> void:
	var shirts := [Color(0.78, 0.24, 0.22), Color(0.22, 0.34, 0.62), Color(0.90, 0.86, 0.42),
		Color(0.28, 0.52, 0.34), Color(0.56, 0.30, 0.62), Color(0.92, 0.92, 0.92)]
	var shirt: Color = shirts[randi() % shirts.size()]

	if _use_lowpoly():
		var lp := HUMAN_LP.new()
		lp.name = "VisLP"
		# setup() before add_child(), same as npc_human.gd: entering the tree
		# runs _ready(), which builds a default person that setup() would throw
		# away and rebuild.
		lp.setup(shirt)
		f.add_child(lp)
		return

	_mesh(f, _box(Vector3(0.48, 0.72, 0.28)), shirt, Vector3(0, 1.12, 0))
	_mesh(f, _box(Vector3(0.4, 0.78, 0.26)), Color(0.16, 0.18, 0.26), Vector3(0, 0.39, 0))
	var head := SphereMesh.new()
	head.radius = 0.17
	head.height = 0.34
	_mesh(f, head, Color(0.85, 0.68, 0.55), Vector3(0, 1.66, 0))


## Same check npc_human.gd makes. Duplicated rather than shared: it is one line,
## and what a fake person has to match is whatever the crowd standing next to it
## is wearing.
func _use_lowpoly() -> bool:
	var prefs := get_node_or_null("/root/Prefs")
	if prefs == null:
		return true
	return str(prefs.get_pref(&"goose_model", "lowpoly")) == "lowpoly"


## The four kinds, and the sizes are the strip mall's real ChaosProp sizes —
## they match prop_models.gd's FOOTPRINTS exactly, so each one builds at scale
## 1.0 and is dimensionally identical to the thing it is pretending to be.
const FAKE_PROPS := [
	{"kind": &"shopping_cart", "size": Vector3(0.8, 1.0, 1.3), "col": Color(0.74, 0.75, 0.78)},
	{"kind": &"recycling_bin", "size": Vector3(1.0, 1.2, 0.8), "col": Color(0.14, 0.32, 0.58)},
	{"kind": &"patio_chair", "size": Vector3(0.6, 0.9, 0.6), "col": Color(0.42, 0.30, 0.22)},
	{"kind": &"lawn_sign", "size": Vector3(1.1, 0.8, 0.08), "col": Color(0.92, 0.86, 0.20)},
]


## And the same models as the real ChaosProps in the lot — which is not what a
## BoxMesh has been since the art pass. chaos_prop.gd builds the faceted model
## whenever prop_models.gd has one, with no pref check, so this doesn't make one
## either.
##
## No half-height drop here, unlike chaos_prop.gd: the models are base-anchored
## and a fake's origin IS the ground the probe found. A prop dropped by
## `size.y * 0.5` would be buried to its waist.
func _build_prop(f: Node3D) -> void:
	var k: Dictionary = FAKE_PROPS[randi() % FAKE_PROPS.size()]
	var kind: StringName = k.kind
	var size: Vector3 = k.size
	var col: Color = k.col
	if PROP_MODELS.has_model(kind):
		PROP_MODELS.build(kind, f, {"size": size, "colour": col})
	else:
		_mesh(f, _box(size), col, Vector3(0, size.y * 0.5, 0))
	f.rotation.y = randf_range(-PI, PI)


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _mesh(parent: Node3D, mesh: Mesh, col: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.9
	# No transparency flag here any more — see _set_alpha(). Everything else
	# about the material matches a real prop exactly: no tint, no emission.
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


## Every MeshInstance3D under a fake, at any depth. The old one-level loop was
## right when a fake was three boxes parented straight to the root; the faceted
## models and the low-poly person both nest their meshes two or three deep, so a
## flat scan now finds nothing at all.
func _mesh_parts(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c is MeshInstance3D:
			out.append(c)
		_mesh_parts(c, out)


## A fake owns its own copy of whatever material it was built with.
##
## prop_models.gd hands out ONE shared StandardMaterial3D for the entire
## environment — hundreds of props, one material, which is the whole payoff of
## putting colour in the vertices. Fading a fake through that material would
## fade every real bin, cart and minivan on screen with it. That is the loudest
## tell available and a one-line way to break the look of a whole zone.
func _own_materials(f: Node3D) -> void:
	var parts: Array = []
	_mesh_parts(f, parts)
	var copies := {}
	for p in parts:
		var mi: MeshInstance3D = p
		var m: Material = mi.material_override
		if m == null:
			continue
		if not copies.has(m):
			copies[m] = m.duplicate()
		mi.material_override = copies[m]


## Fade control for the spawn and dissolve tweens.
##
## A fake at rest is OPAQUE. The materials used to carry TRANSPARENCY_ALPHA
## permanently, just so the tween had somewhere to write, and that quietly cost
## this file the first thing its own docstring promises: alpha-blended geometry
## is skipped by the shadow pass and does not write depth, so a fake cast no
## shadow beside real props that do, and a person's own arms sorted through his
## own torso. Transparency is switched on only while one is actually appearing
## or dissolving, which is the only time it is wanted.
func _set_alpha(f: Node3D, a: float) -> void:
	if f == null or not is_instance_valid(f):
		return
	var solid := a >= 0.999
	var parts: Array = []
	_mesh_parts(f, parts)
	for p in parts:
		var mi: MeshInstance3D = p
		# `is` doesn't narrow a Variant loop variable in GDScript, so the
		# property read has to be annotated or the parser rejects it.
		var m: Material = mi.material_override
		if m is StandardMaterial3D:
			var sm: StandardMaterial3D = m
			var col: Color = sm.albedo_color
			col.a = a
			sm.albedo_color = col
			sm.transparency = (BaseMaterial3D.TRANSPARENCY_DISABLED if solid
				else BaseMaterial3D.TRANSPARENCY_ALPHA)


func _dissolve(f: Node3D) -> void:
	if f == null or not is_instance_valid(f):
		return
	var tw := f.create_tween()
	tw.tween_method(func(v: float): _set_alpha(f, v), 1.0, 0.0, 0.35)
	tw.tween_callback(f.queue_free)


func _clear_all() -> void:
	for f in _fakes:
		if f and is_instance_valid(f):
			f.queue_free()
	_fakes.clear()


## How many fakes are currently out. Only for debug readouts — never show this
## to the player, the entire mechanic depends on them not knowing.
func fake_count() -> int:
	return _fakes.size()
