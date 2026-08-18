extends RefCounted
class_name PickupModels

## Procedural low-poly models for Geeked Geese pickups. Most are built from
## Godot primitive meshes (Box/Sphere/Cylinder/Capsule/Prism/Torus).
## No randf()/randi() is used anywhere so a given pickup renders identically
## every run (the project's build verification renders and diffs frames).
##
## ---------------------------------------------------------------------------
## TWO OF THEM ARE FACETED NOW, AND WHY
## ---------------------------------------------------------------------------
## `fly_agaric` and `molly` sit in zone_suburbia.gd's backyards next to objects
## that were rebuilt as faceted geometry — the fly agaric pickup floats in the
## middle of a fairy ring of faceted mushrooms, and the molly pickup floats
## half a metre over Molly the golden retriever. Rendered, both came back as
## the only smooth thing in the shot: a glossy hemisphere among six polygonal
## caps, and a sphere-headed dog beside a real one.
##
## Both now REUSE the model that was already there — prop_models.gd's
## `fly_agaric` and boss_ranger_visual.gd's dog — rather than growing a third
## mushroom and a third dog. The other fourteen pickups are still primitives;
## they are consistent with each other and none of them stands next to a
## faceted twin. Converting the rest is a real job, not a footnote.

## Preloaded rather than referenced by class_name: global class registration
## only exists after an editor import pass, so a `class_name` reference breaks
## in a fresh checkout or a headless CI run. A preload const always resolves.
const PROPS := preload("res://scripts/world/prop_models.gd")
const DOG_VIS := preload("res://scripts/world/boss_ranger_visual.gd")

const _KNOWN_IDS: Array[StringName] = [
	&"berries", &"double_double", &"nitrous", &"math", &"grass",
	&"special_k", &"robo", &"molly", &"darts", &"catnip",
	&"toad_slime", &"fly_agaric", &"gravy", &"bars", &"percs",
	&"acid",
]

## True if [param id] has a dedicated model (otherwise build() falls back to
## a generic glowing sphere).
static func has_model(id: StringName) -> bool:
	return _KNOWN_IDS.has(id)

## Builds the model for [param id] as a new "Model" Node3D under [param parent]
## and returns it. Unknown ids get a small glowing sphere so nothing is ever
## invisible in the world.
static func build(id: StringName, parent: Node3D) -> Node3D:
	var model := Node3D.new()
	model.name = "Model"
	parent.add_child(model)
	match id:
		&"berries":
			_build_berries(model)
		&"double_double":
			_build_double_double(model)
		&"nitrous":
			_build_nitrous(model)
		&"math":
			_build_math(model)
		&"grass":
			_build_grass(model)
		&"special_k":
			_build_special_k(model)
		&"robo":
			_build_robo(model)
		&"molly":
			_build_molly(model)
		&"darts":
			_build_darts(model)
		&"catnip":
			_build_catnip(model)
		&"toad_slime":
			_build_toad_slime(model)
		&"fly_agaric":
			_build_fly_agaric(model)
		&"gravy":
			_build_gravy(model)
		&"bars":
			_build_bars(model)
		&"percs":
			_build_percs(model)
		&"acid":
			_build_acid(model)
		_:
			_build_fallback(model)
	return model

## Idle animation applied every frame to a built model. [param t] is an
## accumulated time value (seconds) owned by the caller. [param delta] is kept
## for signature symmetry with per-frame callers and possible future styles.
## Safe to call with a null or freed [param model].
static func animate(model: Node3D, delta: float, t: float, style: StringName = &"bob") -> void:
	if model == null or not is_instance_valid(model):
		return
	match style:
		&"breathe":
			var s := 1.0 + sin(t * 2.2) * 0.035
			model.scale = Vector3(s, s, s)
		&"sway":
			model.rotation.z = sin(t * 1.3) * 0.07
		_:
			model.position.y = sin(t * 2.0) * 0.035
			model.rotation.y = fmod(t * 0.6, TAU)

# ---------------------------------------------------------------------------
# Small helpers everything below is built from.
# ---------------------------------------------------------------------------

static func _mi(parent: Node3D, mesh: Mesh, mat: StandardMaterial3D, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = mat
	parent.add_child(inst)
	inst.position = pos
	inst.rotation = rot
	inst.scale = scl
	return inst

static func _mi_xform(parent: Node3D, mesh: Mesh, mat: StandardMaterial3D, xform: Transform3D) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = mat
	parent.add_child(inst)
	inst.transform = xform
	return inst

static func _mat(color: Color, rough := 0.85, emis := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	if emis > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emis
	return m

## A vertex-colour material with a little emission, for the pickups built out
## of LowPolyBuilder geometry.
##
## Deliberately NOT PropModels.shared_material(): that one instance is shared
## by every prop in both zones, so enabling emission on it would set the whole
## street glowing. This makes a fresh one per pickup.
##
## The emission operator is MULTIPLY, not the default ADD. All the colour in a
## builder mesh lives in its vertex colours while `emission` is one flat value,
## so an additive white lights the red cap and the white spots identically and
## throws the model's entire palette away. Multiplying makes every face glow in
## its own colour. Same reason boss_ranger_visual.gd's light bar does it.
static func _lp_glow_material(rough := 0.62, energy := 0.30) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.WHITE
	mat.vertex_color_use_as_albedo = true
	mat.roughness = rough
	mat.emission_enabled = true
	mat.emission = Color(1, 1, 1)
	mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	mat.emission_energy_multiplier = energy
	return mat


static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b

static func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	return s

static func _hemi(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.is_hemisphere = true
	return s

static func _cyl(top: float, bot: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bot
	c.height = h
	return c

static func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	return c

static func _prism(size: Vector3) -> PrismMesh:
	var p := PrismMesh.new()
	p.size = size
	return p

static func _torus(inner: float, outer: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	return t

# ---------------------------------------------------------------------------
# 1. berries
# ---------------------------------------------------------------------------

## Cluster of fermented crabapples: 7 bunched dark magenta-red spheres on a
## thin brown stem with two small leaves. Two berries are shrivelled (scaled
## down on Y) to read as having spent winter on the branch.
static func _build_berries(m: Node3D) -> void:
	var berry_mat := _mat(Color(0.4, 0.05, 0.17), 0.6, 0.3)
	var shrivel_mat := _mat(Color(0.32, 0.08, 0.15), 0.75, 0.25)
	var stem_mat := _mat(Color(0.32, 0.21, 0.11), 0.9)
	var leaf_mat := _mat(Color(0.16, 0.38, 0.12), 0.8)
	var berries := [
		[Vector3(0.0, 0.33, 0.0), 0.09, false],
		[Vector3(0.09, 0.28, 0.05), 0.08, false],
		[Vector3(-0.1, 0.26, -0.02), 0.085, false],
		[Vector3(0.03, 0.19, 0.09), 0.075, true],
		[Vector3(-0.08, 0.16, -0.07), 0.08, false],
		[Vector3(0.07, 0.1, -0.03), 0.075, true],
		[Vector3(-0.02, 0.07, 0.06), 0.07, false],
	]
	for entry in berries:
		var pos: Vector3 = entry[0]
		var r: float = entry[1]
		var shr: bool = entry[2]
		var mat: StandardMaterial3D = shrivel_mat if shr else berry_mat
		var scl: Vector3 = Vector3(1.0, 0.6, 1.0) if shr else Vector3.ONE
		_mi(m, _sphere(r), mat, pos, Vector3.ZERO, scl)
	_mi(m, _cyl(0.014, 0.02, 0.24), stem_mat, Vector3(0.0, 0.46, 0.0), Vector3(0.15, 0.0, 0.05))
	_mi(m, _box(Vector3(0.09, 0.018, 0.05)), leaf_mat, Vector3(0.05, 0.56, -0.02), Vector3(0.3, 0.5, 0.2))
	_mi(m, _box(Vector3(0.07, 0.018, 0.04)), leaf_mat, Vector3(-0.04, 0.57, 0.02), Vector3(-0.2, -0.4, -0.1))

# ---------------------------------------------------------------------------
# 2. double_double
# ---------------------------------------------------------------------------

## Takeout double-double coffee cup, the most recognisable object in Canada.
## Tapered cup body, a cardboard sleeve band, and a dark lid with a raised
## sip-tab. The silhouette is the whole point; keep it clean and iconic.
static func _build_double_double(m: Node3D) -> void:
	var cup_mat := _mat(Color(0.87, 0.75, 0.53), 0.75, 0.3)
	var sleeve_mat := _mat(Color(0.56, 0.13, 0.11), 0.8)
	var lid_mat := _mat(Color(0.2, 0.13, 0.08), 0.55)
	var tab_mat := _mat(Color(0.13, 0.09, 0.06), 0.55)
	_mi(m, _cyl(0.16, 0.11, 0.52), cup_mat, Vector3(0.0, 0.26, 0.0))
	_mi(m, _cyl(0.166, 0.166, 0.15), sleeve_mat, Vector3(0.0, 0.28, 0.0))
	_mi(m, _cyl(0.172, 0.172, 0.045), lid_mat, Vector3(0.0, 0.545, 0.0))
	_mi(m, _box(Vector3(0.045, 0.02, 0.03)), tab_mat, Vector3(0.0, 0.575, -0.1))

# ---------------------------------------------------------------------------
# 3. nitrous
# ---------------------------------------------------------------------------

## Whipped cream can: pale blue-white body, a tapered shoulder, a small grey
## nozzle angled forward, and a bright label band around the middle.
static func _build_nitrous(m: Node3D) -> void:
	var body_mat := _mat(Color(0.85, 0.9, 0.95), 0.4, 0.3)
	var label_mat := _mat(Color(0.75, 0.15, 0.15), 0.7)
	var nozzle_mat := _mat(Color(0.55, 0.55, 0.58), 0.3)
	_mi(m, _cyl(0.11, 0.11, 0.4), body_mat, Vector3(0.0, 0.2, 0.0))
	_mi(m, _cyl(0.117, 0.117, 0.14), label_mat, Vector3(0.0, 0.23, 0.0))
	_mi(m, _cyl(0.08, 0.11, 0.07), body_mat, Vector3(0.0, 0.435, 0.0))
	_mi(m, _cyl(0.05, 0.05, 0.025), nozzle_mat, Vector3(0.0, 0.485, 0.0))
	_mi(m, _cyl(0.015, 0.02, 0.09), nozzle_mat, Vector3(0.0, 0.56, -0.02), Vector3(-0.5, 0.0, 0.0))

# ---------------------------------------------------------------------------
# 4. math
# ---------------------------------------------------------------------------

## A sheet of grade 9 math homework dropped on the asphalt: a thin sheet lying
## askew with scribbled equation-line strokes of varied length and one
## curled-up corner. Deliberately low-profile since it is a flat sheet, not an
## upright object.
static func _build_math(m: Node3D) -> void:
	var sheet := Node3D.new()
	m.add_child(sheet)
	sheet.rotation = Vector3(0.02, 0.35, 0.015)
	sheet.position = Vector3(0.0, 0.006, 0.0)
	var paper_mat := _mat(Color(0.93, 0.93, 0.87), 0.7, 0.28)
	var ink_mat := _mat(Color(0.2, 0.22, 0.3), 0.6)
	_mi(sheet, _box(Vector3(0.42, 0.006, 0.55)), paper_mat, Vector3.ZERO)
	var lines := [
		[0.16, Vector3(-0.02, 0.006, -0.2)],
		[0.28, Vector3(0.01, 0.006, -0.12)],
		[0.1, Vector3(-0.08, 0.006, -0.04)],
		[0.22, Vector3(0.0, 0.006, 0.04)],
		[0.3, Vector3(-0.01, 0.006, 0.12)],
		[0.14, Vector3(0.03, 0.006, 0.2)],
	]
	for entry in lines:
		var ln: float = entry[0]
		var pos: Vector3 = entry[1]
		_mi(sheet, _box(Vector3(ln, 0.004, 0.015)), ink_mat, pos)
	_mi(sheet, _box(Vector3(0.1, 0.005, 0.12)), paper_mat, Vector3(0.16, 0.02, -0.22), Vector3(0.5, 0.1, 0.2))

# ---------------------------------------------------------------------------
# 5. grass
# ---------------------------------------------------------------------------

## Tuft of grass: thin blades fanning out from a shared base at varied
## heights, yaws and lean angles, with slight per-blade colour variation.
static func _build_grass(m: Node3D) -> void:
	var c1 := _mat(Color(0.22, 0.5, 0.14), 0.9, 0.28)
	var c2 := _mat(Color(0.28, 0.56, 0.17), 0.9)
	var c3 := _mat(Color(0.18, 0.42, 0.11), 0.9)
	var blades := [
		[0.6, 0.0, 10.0, c1], [0.76, 40.0, 14.0, c2], [0.52, 80.0, 8.0, c1],
		[0.82, 120.0, 16.0, c3], [0.58, 160.0, 10.0, c2], [0.7, 200.0, 12.0, c1],
		[0.48, 240.0, 9.0, c3], [0.78, 280.0, 15.0, c2], [0.56, 320.0, 11.0, c1],
	]
	for entry in blades:
		var h: float = entry[0]
		var yaw: float = entry[1]
		var lean: float = entry[2]
		var mat: StandardMaterial3D = entry[3]
		var pivot := Node3D.new()
		m.add_child(pivot)
		pivot.rotation = Vector3(deg_to_rad(lean), deg_to_rad(yaw), 0.0)
		_mi(pivot, _box(Vector3(0.02, h, 0.006)), mat, Vector3(0.0, h * 0.5, 0.0))

# ---------------------------------------------------------------------------
# 6. special_k
# ---------------------------------------------------------------------------

## Cereal box: an upright bright-panel box with a lighter inset front panel
## and a metal spoon leaning against its side.
static func _build_special_k(m: Node3D) -> void:
	var box_mat := _mat(Color(0.86, 0.24, 0.1), 0.6, 0.3)
	var panel_mat := _mat(Color(0.95, 0.85, 0.55), 0.55)
	var metal_mat := _mat(Color(0.75, 0.76, 0.78), 0.3)
	_mi(m, _box(Vector3(0.32, 0.75, 0.14)), box_mat, Vector3(0.0, 0.375, 0.0))
	_mi(m, _box(Vector3(0.22, 0.42, 0.012)), panel_mat, Vector3(0.0, 0.42, -0.082))
	var pivot := Node3D.new()
	m.add_child(pivot)
	pivot.position = Vector3(0.21, 0.0, 0.05)
	pivot.rotation = Vector3(deg_to_rad(-14.0), 0.0, 0.0)
	_mi(pivot, _cyl(0.014, 0.014, 0.46), metal_mat, Vector3(0.0, 0.23, 0.0))
	_mi(pivot, _sphere(0.055), metal_mat, Vector3(0.0, 0.48, 0.0), Vector3.ZERO, Vector3(1.25, 0.5, 1.0))

# ---------------------------------------------------------------------------
# 7. robo
# ---------------------------------------------------------------------------

## Cough syrup bottle: a squat dark-amber body with a rounded shoulder, a
## white childproof cap, and a bright label on the front face.
static func _build_robo(m: Node3D) -> void:
	var glass_mat := _mat(Color(0.32, 0.16, 0.03), 0.35, 0.3)
	var cap_mat := _mat(Color(0.92, 0.92, 0.9), 0.5)
	var label_mat := _mat(Color(0.92, 0.15, 0.45), 0.6)
	_mi(m, _cyl(0.09, 0.1, 0.35), glass_mat, Vector3(0.0, 0.175, 0.0))
	_mi(m, _sphere(0.09), glass_mat, Vector3(0.0, 0.37, 0.0), Vector3.ZERO, Vector3(1.0, 0.5, 1.0))
	_mi(m, _cyl(0.035, 0.035, 0.12), glass_mat, Vector3(0.0, 0.45, 0.0))
	_mi(m, _cyl(0.045, 0.045, 0.08), cap_mat, Vector3(0.0, 0.55, 0.0))
	_mi(m, _box(Vector3(0.14, 0.16, 0.01)), label_mat, Vector3(0.0, 0.19, -0.096))

# ---------------------------------------------------------------------------
# 8. molly
# ---------------------------------------------------------------------------

## Golden retriever, head and shoulders, as if she's sitting and wagging just
## out of frame. A character, not an object: the floppy ears and tiny dark
## eyes do most of the "happy and dumb" work.
static func _build_molly(m: Node3D) -> void:
	## The molly pickup is a dog, and this project has exactly one dog model —
	## boss_ranger_visual.gd's, in the &"golden" coat that zone_suburbia gives
	## Molly herself.
	##
	## It used to be a CapsuleMesh body with a SphereMesh head and sphere eyes
	## and nose, and it floats half a metre over Molly in house 0's backyard:
	## two dogs in one frame, one faceted and one not. Rendered and caught.
	var d: Node3D = DOG_VIS.new()
	d.setup(&"golden")
	m.add_child(d)
	# The dog visual stands 0.76 m; the pickups here are authored around 0.8
	# tall including their float, and this one has to read as a puppy-sized
	# object hanging in the air rather than as a second full-sized dog.
	d.scale = Vector3.ONE * 0.62
	d.position.y = -0.02
	# Same findability glow the primitive pickups get, applied to the visual's
	# own material rather than to a shared one.
	var targets: Array = d.get("tint_targets")
	if targets != null:
		for t in targets:
			var mat: StandardMaterial3D = t
			mat.emission_enabled = true
			mat.emission = Color(1, 1, 1)
			mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
			mat.emission_energy_multiplier = 0.26

# ---------------------------------------------------------------------------
# 9. darts
# ---------------------------------------------------------------------------

## Crumpled pack of cigarettes: two overlapping, slightly misaligned boxes
## suggest a dent, with a torn-open top and two cigarettes poking out at
## different angles, dark filter tips first.
static func _build_darts(m: Node3D) -> void:
	var pack_mat := _mat(Color(0.93, 0.91, 0.86), 0.75, 0.3)
	var dent_mat := _mat(Color(0.66, 0.63, 0.56), 0.85)
	var tear_mat := _mat(Color(0.24, 0.23, 0.21), 0.7)
	var paper_mat := _mat(Color(0.95, 0.95, 0.92), 0.5)
	var filter_mat := _mat(Color(0.62, 0.4, 0.18), 0.6)
	_mi(m, _box(Vector3(0.24, 0.34, 0.1)), pack_mat, Vector3(0.0, 0.17, 0.0), Vector3(0.0, deg_to_rad(6.0), deg_to_rad(4.0)))
	_mi(m, _box(Vector3(0.22, 0.3, 0.095)), dent_mat, Vector3(0.035, 0.18, 0.018), Vector3(0.0, deg_to_rad(-4.0), deg_to_rad(-9.0)))
	_mi(m, _box(Vector3(0.17, 0.02, 0.07)), tear_mat, Vector3(0.0, 0.34, 0.0))
	var p1 := Node3D.new()
	m.add_child(p1)
	p1.position = Vector3(-0.02, 0.36, -0.03)
	p1.rotation = Vector3(deg_to_rad(-35.0), 0.0, deg_to_rad(10.0))
	_mi(p1, _cyl(0.017, 0.017, 0.24), paper_mat, Vector3(0.0, 0.12, 0.0))
	_mi(p1, _cyl(0.02, 0.02, 0.03), filter_mat, Vector3(0.0, 0.255, 0.0))
	var p2 := Node3D.new()
	m.add_child(p2)
	p2.position = Vector3(0.05, 0.36, -0.01)
	p2.rotation = Vector3(deg_to_rad(-20.0), 0.0, deg_to_rad(-18.0))
	_mi(p2, _cyl(0.016, 0.016, 0.2), paper_mat, Vector3(0.0, 0.1, 0.0))
	_mi(p2, _cyl(0.019, 0.019, 0.028), filter_mat, Vector3(0.0, 0.214, 0.0))

# ---------------------------------------------------------------------------
# 10. catnip
# ---------------------------------------------------------------------------

## Leafy catnip sprig in a small terracotta pot: tapered pot, dark soil,
## central stem, and 4 opposing leaf pairs spiralling up it.
static func _build_catnip(m: Node3D) -> void:
	var pot_mat := _mat(Color(0.72, 0.36, 0.21), 0.85, 0.25)
	var soil_mat := _mat(Color(0.24, 0.16, 0.1), 0.9)
	var stem_mat := _mat(Color(0.28, 0.46, 0.16), 0.8)
	var leaf_mat := _mat(Color(0.32, 0.55, 0.2), 0.75)
	_mi(m, _cyl(0.14, 0.1, 0.22), pot_mat, Vector3(0.0, 0.11, 0.0))
	_mi(m, _cyl(0.13, 0.13, 0.02), soil_mat, Vector3(0.0, 0.23, 0.0))
	_mi(m, _cyl(0.012, 0.016, 0.4), stem_mat, Vector3(0.0, 0.44, 0.0))
	var pairs := [
		[0.3, 0.0], [0.36, 50.0], [0.42, 100.0], [0.5, 150.0],
	]
	for entry in pairs:
		var h: float = entry[0]
		var yaw: float = entry[1]
		for side in [0.0, 180.0]:
			var pivot := Node3D.new()
			m.add_child(pivot)
			pivot.position = Vector3(0.0, h, 0.0)
			pivot.rotation = Vector3(deg_to_rad(-30.0), deg_to_rad(yaw + side), 0.0)
			_mi(pivot, _prism(Vector3(0.1, 0.016, 0.045)), leaf_mat, Vector3(0.06, 0.0, 0.0))

# ---------------------------------------------------------------------------
# 11. toad_slime
# ---------------------------------------------------------------------------

## Squat, smug toad: flattened body, bulging top-mounted eyes, tucked front
## legs, and a scatter of warty bumps on its back. Deliberately low and wide
## rather than tall; that is the point of a toad.
static func _build_toad_slime(m: Node3D) -> void:
	var skin_mat := _mat(Color(0.4, 0.48, 0.21), 0.7, 0.3)
	var belly_mat := _mat(Color(0.55, 0.58, 0.3), 0.75)
	var eye_mat := _mat(Color(0.58, 0.62, 0.26), 0.4)
	var pupil_mat := _mat(Color(0.05, 0.05, 0.04), 0.3)
	var wart_mat := _mat(Color(0.3, 0.37, 0.14), 0.8)
	_mi(m, _sphere(0.4), skin_mat, Vector3(0.0, 0.24, 0.0), Vector3.ZERO, Vector3(1.2, 0.6, 1.05))
	_mi(m, _sphere(0.26), skin_mat, Vector3(0.0, 0.26, -0.34), Vector3.ZERO, Vector3(1.0, 0.85, 0.9))
	_mi(m, _sphere(0.09), eye_mat, Vector3(-0.12, 0.42, -0.36))
	_mi(m, _sphere(0.09), eye_mat, Vector3(0.12, 0.42, -0.36))
	_mi(m, _sphere(0.032), pupil_mat, Vector3(-0.12, 0.42, -0.44))
	_mi(m, _sphere(0.032), pupil_mat, Vector3(0.12, 0.42, -0.44))
	_mi(m, _box(Vector3(0.14, 0.1, 0.2)), belly_mat, Vector3(-0.2, 0.08, -0.2), Vector3(0.0, 0.2, 0.0))
	_mi(m, _box(Vector3(0.14, 0.1, 0.2)), belly_mat, Vector3(0.2, 0.08, -0.2), Vector3(0.0, -0.2, 0.0))
	var warts: Array[Vector3] = [
		Vector3(0.2, 0.49, 0.12), Vector3(-0.23, 0.48, 0.15), Vector3(0.0, 0.51, -0.06),
		Vector3(0.27, 0.46, -0.18), Vector3(-0.27, 0.44, 0.23),
	]
	for pos in warts:
		_mi(m, _sphere(0.065), wart_mat, pos)

# ---------------------------------------------------------------------------
# 12. fly_agaric
# ---------------------------------------------------------------------------

## The classic red-and-white fairy-tale mushroom, the game's most iconic
## pickup. Cream stem flaring at the base, a scarlet hemisphere cap, pale
## gills peeking out from under the rim, and white spots computed directly on
## the hemisphere surface via spherical coordinates so they sit flush.
static func _build_fly_agaric(m: Node3D) -> void:
	## prop_models.gd's faceted fly agaric — the same mushroom zone_suburbia's
	## fairy ring is made of, so the source and the ring around it are one
	## object at two sizes.
	##
	## This was a CylinderMesh stem, a TorusMesh gill ring, a SphereMesh
	## hemisphere cap and nine SphereMesh spots. It read fine on its own and
	## badly the moment the ring stopped being smooth.
	##
	## Authored a metre across; the pickups in this file are authored around
	## 0.8 units tall, and substance_pickup.gd scales from there.
	var model: Node3D = PROPS.build(&"fly_agaric", m, {})
	model.scale = Vector3.ONE * 0.80
	for c in model.get_children():
		if c is MeshInstance3D:
			var mi: MeshInstance3D = c
			mi.material_override = _lp_glow_material(0.58, 0.34)

# ---------------------------------------------------------------------------
# 13. gravy
# ---------------------------------------------------------------------------

## Poutine takeout container that is very much not poutine: a rectangular
## clamshell with the lid propped ajar on its back hinge, a glossy brown
## "gravy" slick pooling out through the seam and dribbling down the front,
## and two pale chips poking free of the gap. It should look wrong.
static func _build_gravy(m: Node3D) -> void:
	var shell_mat := _mat(Color(0.92, 0.9, 0.85), 0.65)
	var shell_dark_mat := _mat(Color(0.8, 0.78, 0.72), 0.7)
	var gravy_mat := _mat(Color(0.32, 0.17, 0.05), 0.2, 0.35)
	var chip_mat := _mat(Color(0.93, 0.78, 0.42), 0.6)
	_mi(m, _box(Vector3(0.34, 0.18, 0.26)), shell_mat, Vector3(0.0, 0.09, 0.0))
	var lid := Node3D.new()
	m.add_child(lid)
	lid.position = Vector3(0.0, 0.18, 0.13)
	lid.rotation = Vector3(deg_to_rad(55.0), 0.0, 0.0)
	_mi(lid, _box(Vector3(0.34, 0.02, 0.26)), shell_dark_mat, Vector3(0.0, 0.0, -0.13))
	# Gravy slick pooling out of the seam and spreading across the ground,
	# built from overlapping flattened spheres so it reads as an irregular
	# puddle rather than a ball.
	_mi(m, _sphere(0.15), gravy_mat, Vector3(0.02, 0.01, -0.23), Vector3.ZERO, Vector3(1.3, 0.07, 0.9))
	_mi(m, _sphere(0.1), gravy_mat, Vector3(-0.14, 0.01, -0.15), Vector3.ZERO, Vector3(1.0, 0.07, 0.75))
	_mi(m, _sphere(0.08), gravy_mat, Vector3(0.15, 0.008, -0.09), Vector3.ZERO, Vector3(0.9, 0.06, 0.7))
	_mi(m, _box(Vector3(0.045, 0.18, 0.02)), gravy_mat, Vector3(0.0, 0.09, -0.135))
	# Two chips poking out of the gap at different angles.
	var c1 := Node3D.new()
	m.add_child(c1)
	c1.position = Vector3(-0.04, 0.18, -0.08)
	c1.rotation = Vector3(deg_to_rad(-45.0), 0.0, deg_to_rad(8.0))
	_mi(c1, _box(Vector3(0.032, 0.32, 0.032)), chip_mat, Vector3(0.0, 0.16, 0.0))
	var c2 := Node3D.new()
	m.add_child(c2)
	c2.position = Vector3(0.05, 0.18, -0.05)
	c2.rotation = Vector3(deg_to_rad(-32.0), 0.0, deg_to_rad(-14.0))
	_mi(c2, _box(Vector3(0.03, 0.26, 0.03)), chip_mat, Vector3(0.0, 0.13, 0.0))

# ---------------------------------------------------------------------------
# 14. bars
# ---------------------------------------------------------------------------

## A bar of soap left on a laundromat ledge, resting on a small folded-towel
## block. White-cream, gently rounded, an embossed panel on top. Deliberately
## unremarkable to look at — the joke is entirely that it looks innocent.
static func _build_bars(m: Node3D) -> void:
	var towel_mat := _mat(Color(0.88, 0.85, 0.78), 0.9)
	var soap_mat := _mat(Color(0.93, 0.91, 0.84), 0.4, 0.3)
	var panel_mat := _mat(Color(0.86, 0.88, 0.92), 0.35)
	_mi(m, _box(Vector3(0.28, 0.06, 0.18)), towel_mat, Vector3(0.0, 0.03, 0.0))
	_mi(m, _box(Vector3(0.24, 0.05, 0.16)), towel_mat, Vector3(0.015, 0.085, 0.0))
	_mi(m, _box(Vector3(0.2, 0.035, 0.14)), towel_mat, Vector3(-0.01, 0.1275, 0.0))
	# Soap bar: a plain low rectangular block, slightly yawed off-square from
	# the towel folds beneath it. Understated on purpose — no pill-shaped
	# rounding, just an embossed panel on the top face.
	var soap_rot := Vector3(0.0, deg_to_rad(8.0), 0.0)
	_mi(m, _box(Vector3(0.24, 0.065, 0.11)), soap_mat, Vector3(0.0, 0.1775, 0.0), soap_rot)
	_mi(m, _box(Vector3(0.13, 0.006, 0.055)), panel_mat, Vector3(0.0, 0.2135, 0.0), soap_rot)

# ---------------------------------------------------------------------------
# 15. percs
# ---------------------------------------------------------------------------

## A weekly pill organiser dropped in the lot, lid flipped open on its back
## hinge: seven shallow pastel compartments in a row and a scatter of small
## white tablets spilled beside it. Low-profile by nature — it is a tray
## lying on the ground, not an upright object.
static func _build_percs(m: Node3D) -> void:
	var pastel := [
		Color(0.95, 0.75, 0.75), Color(0.95, 0.85, 0.68), Color(0.95, 0.95, 0.7),
		Color(0.75, 0.95, 0.78), Color(0.72, 0.85, 0.95), Color(0.8, 0.76, 0.95),
		Color(0.95, 0.76, 0.9),
	]
	var lid_mat := _mat(Color(0.94, 0.9, 0.8), 0.3, 0.3)
	var tablet_mat := _mat(Color(0.97, 0.97, 0.95), 0.4)
	for i in range(7):
		var col: Color = pastel[i]
		var comp_mat := _mat(col, 0.4)
		var x := (float(i) - 3.0) * 0.082
		_mi(m, _box(Vector3(0.075, 0.045, 0.13)), comp_mat, Vector3(x, 0.0225, 0.0))
	# Hinge bar along the back edge, so the lid reads as attached rather than
	# a detached slab floating behind the tray.
	_mi(m, _cyl(0.01, 0.01, 0.58), lid_mat, Vector3(0.0, 0.045, 0.065), Vector3(0.0, 0.0, deg_to_rad(90.0)))
	var lid := Node3D.new()
	m.add_child(lid)
	lid.position = Vector3(0.0, 0.045, 0.065)
	lid.rotation = Vector3(deg_to_rad(108.0), 0.0, 0.0)
	_mi(lid, _box(Vector3(0.58, 0.015, 0.13)), lid_mat, Vector3(0.0, 0.0, -0.065))
	var tablets: Array[Vector3] = [
		Vector3(0.34, 0.012, 0.11), Vector3(0.41, 0.011, 0.03),
		Vector3(0.37, 0.011, -0.08), Vector3(0.46, 0.012, -0.02),
	]
	for pos in tablets:
		_mi(m, _sphere(0.024), tablet_mat, pos, Vector3.ZERO, Vector3(1.0, 0.55, 1.0))

# ---------------------------------------------------------------------------
# 16. acid
# ---------------------------------------------------------------------------

## A car battery leaking in the corner of the lot: a blocky black-grey case,
## two terminal posts, a warning label, a cracked corner, and a vivid
## iridescent puddle spreading out front. The puddle is built as overlapping
## flattened lobes rather than a sphere so it reads as spilled liquid.
static func _build_acid(m: Node3D) -> void:
	var case_mat := _mat(Color(0.1, 0.1, 0.11), 0.45)
	var chip_mat := _mat(Color(0.16, 0.16, 0.18), 0.55)
	var crack_mat := _mat(Color(0.02, 0.02, 0.02), 0.7)
	var pos_mat := _mat(Color(0.72, 0.14, 0.1), 0.4)
	var neg_mat := _mat(Color(0.14, 0.14, 0.16), 0.4)
	var label_mat := _mat(Color(0.95, 0.75, 0.1), 0.5)
	var puddle_mat := _mat(Color(0.98, 0.45, 0.92), 0.15, 0.35)
	_mi(m, _box(Vector3(0.34, 0.46, 0.2)), case_mat, Vector3(0.0, 0.23, 0.0))
	for i in range(6):
		var x := (float(i) - 2.5) * 0.05
		_mi(m, _cyl(0.018, 0.018, 0.02), case_mat, Vector3(x, 0.47, 0.03))
	_mi(m, _cyl(0.028, 0.032, 0.06), pos_mat, Vector3(-0.1, 0.49, 0.05))
	_mi(m, _cyl(0.028, 0.032, 0.06), neg_mat, Vector3(0.1, 0.49, 0.05))
	_mi(m, _box(Vector3(0.16, 0.12, 0.012)), label_mat, Vector3(0.02, 0.24, -0.106))
	# Cracked corner: a small displaced shard plus a dark seam line.
	_mi(m, _box(Vector3(0.09, 0.05, 0.07)), chip_mat, Vector3(0.15, 0.4, -0.07), Vector3(deg_to_rad(10.0), deg_to_rad(15.0), deg_to_rad(-12.0)))
	_mi(m, _box(Vector3(0.09, 0.008, 0.01)), crack_mat, Vector3(0.11, 0.42, -0.02), Vector3(0.0, 0.0, deg_to_rad(38.0)))
	# Puddle: overlapping flattened lobes plus a thin bridging trail from the
	# cracked corner down to the pool.
	_mi(m, _sphere(0.24), puddle_mat, Vector3(0.0, 0.006, -0.27), Vector3.ZERO, Vector3(1.3, 0.025, 1.0))
	_mi(m, _sphere(0.15), puddle_mat, Vector3(-0.2, 0.006, -0.15), Vector3.ZERO, Vector3(1.0, 0.025, 0.8))
	_mi(m, _sphere(0.12), puddle_mat, Vector3(0.23, 0.006, -0.07), Vector3.ZERO, Vector3(0.9, 0.022, 0.75))
	_mi(m, _sphere(0.08), puddle_mat, Vector3(0.06, 0.005, -0.11), Vector3.ZERO, Vector3(0.8, 0.02, 0.7))
	_mi(m, _box(Vector3(0.03, 0.01, 0.2)), puddle_mat, Vector3(0.09, 0.006, -0.19), Vector3(0.0, deg_to_rad(15.0), 0.0))

# ---------------------------------------------------------------------------
# fallback
# ---------------------------------------------------------------------------

## Fallback for an unrecognised id: a small glowing sphere so nothing in the
## world is ever invisible.
static func _build_fallback(m: Node3D) -> void:
	var mat := _mat(Color(0.8, 0.8, 0.9), 0.5, 0.5)
	_mi(m, _sphere(0.18), mat, Vector3(0.0, 0.18, 0.0))
