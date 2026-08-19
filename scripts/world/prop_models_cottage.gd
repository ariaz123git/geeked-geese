extends RefCounted
## COTTAGE COUNTRY MODEL LIBRARY — the props the shared library doesn't have.
##
## Same idiom and the same public API as scripts/world/prop_models.gd:
##
##     PropModelsCottage.build(kind, parent, params) -> Node3D
##     PropModelsCottage.has_model(kind) -> bool
##     PropModelsCottage.footprint(kind, params) -> Vector3
##
## Polygons only. No SphereMesh, no CylinderMesh, no curved primitives. All
## colour lives in VERTEX COLOURS against one white material, so eighty props
## are one material and a per-face paint decision costs nothing.
##
## ---------------------------------------------------------------------------
## THE ANCHORING CONTRACT — identical to prop_models.gd, repeated because it is
## the one thing that breaks a zone
## ---------------------------------------------------------------------------
## Every model here is BASE-ANCHORED: local origin on the ground at the centre
## of the footprint, growing up +Y. BoxShape3D colliders are CENTRED. So a
## model hung under a collider of height h always drops by -h * 0.5. Miss it
## and the whole shoreline hovers.
##
## ---------------------------------------------------------------------------
## THE SECOND MATERIAL — why this file has one and prop_models.gd doesn't
## ---------------------------------------------------------------------------
## This is a NIGHT zone. A cottage window, a campfire, a bug zapper grid and a
## dock lamp are not objects that are lit — they are the things doing the
## lighting, and a lit-from-outside quad painted pale yellow reads as a grey
## rectangle at 0.4 ambient. So every build function gets TWO builders:
##
##     b   the normal shell, vertex colour, shaded like everything else
##     e   the GLOW shell, vertex colour, SHADING_MODE_UNSHADED
##
## An unshaded face renders at exactly its vertex colour regardless of what
## light reaches it, which is precisely "this surface is emitting". The glow
## mesh is only attached when it has triangles, so a model with no light source
## costs exactly one MeshInstance3D as before.
##
## The paired OmniLight3D that actually spills onto the world is the ZONE's
## job, not the model's — a model that carried its own light would put six
## lights inside one cottage and blow the GL Compatibility renderer's
## per-object light cap for free.
##
## ---------------------------------------------------------------------------
## DETERMINISM
## ---------------------------------------------------------------------------
## No randf()/randi() anywhere. The build verification renders and diffs
## frames, so a random number in here is a bug. Every irregularity — the lumpy
## granite, the ragged pine branch, the slumped firewood — is a sin() of the
## vertex and ring indices: organic-looking and bit-identical every run.

## Preloaded rather than referenced by class_name: global class registration
## only exists after an editor import pass, so a `class_name` reference breaks
## in a fresh checkout or a headless CI run. A preload const always resolves.
const LPB := preload("res://scripts/goose/lowpoly_builder.gd")


# ---------------------------------------------------------------------------
# Registry
# ---------------------------------------------------------------------------

## Bounding footprint of each model, base-anchored: (width_x, height_y, depth_z).
## `cottage` and `boathouse` are computed from their params instead — see
## footprint() — because they are authored to a size the zone chooses.
const FOOTPRINTS := {
	&"canoe": Vector3(0.94, 0.66, 5.00),
	&"kayak": Vector3(0.70, 0.46, 3.90),
	&"muskoka_chair": Vector3(0.92, 1.06, 1.10),
	&"fire_pit": Vector3(2.40, 1.05, 2.40),
	&"dock_section": Vector3(3.20, 2.10, 3.20),
	&"pine": Vector3(4.80, 12.00, 4.80),
	&"bug_zapper": Vector3(0.44, 0.92, 0.44),
	&"cooler": Vector3(0.80, 0.54, 0.48),
	&"loon": Vector3(0.44, 0.66, 1.15),
	&"toad": Vector3(0.40, 0.24, 0.50),
	&"dog": Vector3(0.62, 0.66, 1.55),
	&"rock": Vector3(1.90, 1.05, 1.70),
	&"scrub": Vector3(1.60, 0.72, 1.50),
	&"firewood": Vector3(2.30, 1.15, 0.90),
	&"log": Vector3(0.26, 0.26, 0.74),
	&"paddle": Vector3(0.26, 0.07, 1.65),
	&"two_four": Vector3(0.56, 0.40, 0.38),
	&"picnic_table": Vector3(2.00, 0.80, 1.80),
	&"dock_light": Vector3(0.34, 2.60, 0.34),
	&"cottage": Vector3(15.40, 5.40, 14.00),
	&"boathouse": Vector3(6.70, 4.40, 8.50),
}


## True if [param kind] has a dedicated model here. Unknown kinds still build —
## they get a faceted crate, so nothing in the world is ever invisible — but a
## caller that wants to fall back to the shared library should test this first.
static func has_model(kind: StringName) -> bool:
	return FOOTPRINTS.has(kind)


## Base-anchored bounding size of [param kind]. The two buildings compute theirs
## from the passed dimensions, exactly like prop_models.gd's house.
static func footprint(kind: StringName, params := {}) -> Vector3:
	if kind == &"cottage":
		var w := _num(params, "w", 14.0)
		var d := _num(params, "d", 10.0)
		var wall_h := _num(params, "wall_h", 3.0)
		var roof_h := _num(params, "roof_h", 2.4)
		var porch := _num(params, "porch_d", 2.8)
		return Vector3(w * 1.10, wall_h + roof_h, (d + porch) * 1.06)
	if kind == &"boathouse":
		var bw := _num(params, "w", 6.0)
		var bd := _num(params, "d", 8.0)
		var bwall := _num(params, "wall_h", 2.6)
		var broof := _num(params, "roof_h", 1.8)
		return Vector3(bw * 1.12, bwall + broof, bd * 1.06)
	if FOOTPRINTS.has(kind):
		var f: Vector3 = FOOTPRINTS[kind]
		return f
	return Vector3.ONE


# ---------------------------------------------------------------------------
# Materials
# ---------------------------------------------------------------------------

## One white, vertex-colour-driven material for every shaded surface in the
## zone. Shared with nothing — prop_models.gd keeps its own — but identical in
## construction, so the two libraries look like one world.
static var _shared_mat: StandardMaterial3D = null

static func shared_material() -> StandardMaterial3D:
	if _shared_mat == null:
		_shared_mat = LPB.make_material(0.88)
		_shared_mat.cull_mode = BaseMaterial3D.CULL_BACK
	return _shared_mat


## The glow material. UNSHADED on purpose: the face renders at exactly its
## vertex colour, which is the only way a window reads as lit when the scene's
## key light is a 0.42-energy moon. Emission is also switched on so that if a
## glow pass is ever enabled these surfaces feed it.
static var _glow_mat: StandardMaterial3D = null

static func glow_material() -> StandardMaterial3D:
	if _glow_mat == null:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color.WHITE
		m.vertex_color_use_as_albedo = true
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_BACK
		m.emission_enabled = true
		m.emission = Color(1, 1, 1)
		m.emission_energy_multiplier = 1.6
		_glow_mat = m
	return _glow_mat


# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

## Builds the model for [param kind] as a new "Model" Node3D under
## [param parent] and returns it.
##
## `params` keys, all optional:
##   size          Vector3  scale the model so its footprint matches this
##   colour        Color    the model's main colour
##   trim_colour   Color    secondary (gunwale, roof, frame)
##   glow_colour   Color    override the emissive colour
##   lit           bool     fire/lamp/window models: emit or not
##   variant       float    deterministic shape seed
##   w/d/wall_h/roof_h/porch_d   float   building dimensions
static func build(kind: StringName, parent: Node3D, params := {}) -> Node3D:
	var model := Node3D.new()
	model.name = "Model"
	parent.add_child(model)

	var b: RefCounted = LPB.new()
	var e: RefCounted = LPB.new()
	match kind:
		&"canoe":
			_canoe(b, e, params)
		&"kayak":
			_kayak(b, e, params)
		&"muskoka_chair":
			_muskoka_chair(b, e, params)
		&"fire_pit":
			_fire_pit(b, e, params)
		&"dock_section":
			_dock_section(b, e, params)
		&"dock_light":
			_dock_light(b, e, params)
		&"pine":
			_pine(b, e, params)
		&"bug_zapper":
			_bug_zapper(b, e, params)
		&"cooler":
			_cooler(b, e, params)
		&"loon":
			_loon(b, e, params)
		&"toad":
			_toad(b, e, params)
		&"dog":
			_dog(b, e, params)
		&"rock":
			_rock(b, e, params)
		&"scrub":
			_scrub(b, e, params)
		&"firewood":
			_firewood(b, e, params)
		&"log":
			_log(b, e, params)
		&"paddle":
			_paddle(b, e, params)
		&"two_four":
			_two_four(b, e, params)
		&"picnic_table":
			_picnic_table(b, e, params)
		&"cottage":
			_cottage(b, e, params)
		&"boathouse":
			_boathouse(b, e, params)
		_:
			_fallback(b, e, params)

	model.set_meta("tri_count", b.tri_count + e.tri_count)
	# THE MODEL CARRIES ITS OWN DECLARATION, so `tools/geomtest.gd` can compare
	# the box this builder PROMISED against the mesh it actually emitted without
	# knowing which of the seven FOOTPRINTS tables the kind came from. `build()`
	# sizes with `want / footprint(kind)`, so a declaration that disagrees with
	# the mesh makes every `size:` placement of that kind wrong by exactly that
	# ratio, in every zone that asks for one — and nothing could see it.
	model.set_meta("kind", kind)
	model.set_meta("declared", footprint(kind, params))
	LPB.attach(model, b.commit(), shared_material(), "Shell")
	# Only when there is something to glow: an empty SurfaceTool commits to
	# null, and a MeshInstance3D with a null mesh is a silent per-frame cost
	# for nothing.
	if e.tri_count > 0:
		LPB.attach(model, e.commit(), glow_material(), "Glow")

	if params.has("size"):
		var want: Vector3 = params["size"]
		var have := footprint(kind, params)
		model.scale = Vector3(
			want.x / maxf(have.x, 0.001),
			want.y / maxf(have.y, 0.001),
			want.z / maxf(have.z, 0.001))
	return model


# ---------------------------------------------------------------------------
# Typed parameter access.
#
# Dictionary lookups are Variant, so `var x := params.get(...)` is a parse
# error ("Cannot infer the type of x"). Funnelling every read through these
# three helpers keeps that mistake out of the eighteen build functions below.
# ---------------------------------------------------------------------------

static func _col(params: Dictionary, key: String, fallback: Color) -> Color:
	var v = params.get(key, fallback)
	if v is Color:
		return v
	return fallback


static func _num(params: Dictionary, key: String, fallback: float) -> float:
	var v = params.get(key, fallback)
	if v is float or v is int:
		return float(v)
	return fallback


static func _flag(params: Dictionary, key: String, fallback: bool) -> bool:
	var v = params.get(key, fallback)
	if v is bool:
		return v
	return fallback


# ---------------------------------------------------------------------------
# Cross-section and winding helpers.
#
# Deliberately re-implemented here rather than reached for across the preload
# into prop_models.gd: those are underscore-private statics on a file this one
# has no other reason to depend on, and duplicating forty lines is cheaper than
# a coupling nobody expects.
# ---------------------------------------------------------------------------

## Horizontal cross-section at height [param y]: a chamfered rectangle in XZ.
## One 3 cm chamfer per corner is the difference between "a box" and "an
## object" at every distance the camera ever sits at.
static func _ring_y(y: float, hx: float, hz: float, cham: float) -> PackedVector3Array:
	var c := minf(cham, minf(hx, hz) * 0.49)
	if c <= 0.002:
		return PackedVector3Array([
			Vector3(-hx, y, -hz), Vector3(hx, y, -hz),
			Vector3(hx, y, hz), Vector3(-hx, y, hz)])
	return PackedVector3Array([
		Vector3(-hx + c, y, -hz), Vector3(hx - c, y, -hz),
		Vector3(hx, y, -hz + c), Vector3(hx, y, hz - c),
		Vector3(hx - c, y, hz), Vector3(-hx + c, y, hz),
		Vector3(-hx, y, hz - c), Vector3(-hx, y, -hz + c)])


## Centroid of a ring, used as the `inside` reference for capping.
static func _centroid(r: PackedVector3Array) -> Vector3:
	var c := Vector3.ZERO
	for v in r:
		c += v
	return c / float(maxi(r.size(), 1))


## A point far enough behind [param r] along -axis_dir that every face of the
## ring agrees on which way is out.
##
## LowPolyBuilder picks a face's winding from dot(normal, centroid - inside).
## On a near-horizontal fan the normal is almost vertical while
## (centroid - inside) is dominated by the RADIUS, so a reference one metre
## under a one-metre disc leaves the sign of that dot product up to which side
## of the ring the face happens to sit on — and the disc renders along exactly
## half a diameter. Put the reference two hundred radii away and the axial term
## wins on every face. This is documented at length in prop_models.gd because
## it cost that art pass two render rounds; it is repeated here because it
## would cost this one exactly the same two.
static func _far_ref(r: PackedVector3Array, axis_dir: Vector3) -> Vector3:
	var c := _centroid(r)
	var far := 0.0
	for v in r:
		far = maxf(far, (v - c).length())
	return c - axis_dir.normalized() * (far * 200.0 + 10.0)


## Cap a ring that lies perpendicular to [param axis_dir].
static func _cap_axial(b: RefCounted, r: PackedVector3Array, apex: Vector3,
		axis_dir: Vector3, col: Color) -> void:
	b.cap(r, apex, _far_ref(r, axis_dir), col)


## Loft a chain of rings with the faces pointing INWARD, toward the axis. A
## hollow thing — a canoe, a cooler, a fire pit — is looked down into, and with
## backface culling on, an outward-facing far wall simply is not there.
static func _loft_inward(b: RefCounted, rings: Array, axis: Array, col: Color) -> void:
	for i in range(rings.size() - 1):
		var r0: PackedVector3Array = rings[i]
		var r1: PackedVector3Array = rings[i + 1]
		var n: int = mini(r0.size(), r1.size())
		var a0: Vector3 = axis[i]
		var a1: Vector3 = axis[i + 1]
		var mid: Vector3 = (a0 + a1) * 0.5
		for j in n:
			var k := (j + 1) % n
			var p0: Vector3 = r0[j]
			var p1: Vector3 = r0[k]
			var p2: Vector3 = r1[k]
			var p3: Vector3 = r1[j]
			var cen: Vector3 = (p0 + p1 + p2 + p3) * 0.25
			b.quad(p0, p1, p2, p3, col, cen + (cen - mid))


## A flat ring-to-ring band perpendicular to [param axis_dir] — a bin rim, a
## gunwale, a cooler lip. Same winding hazard as _cap_axial, same cure.
static func _annulus(b: RefCounted, outer: PackedVector3Array, inner: PackedVector3Array,
		axis_dir: Vector3, col: Color) -> void:
	var n: int = mini(outer.size(), inner.size())
	var inside := _far_ref(outer, axis_dir)
	for j in n:
		var k := (j + 1) % n
		b.quad(outer[j], outer[k], inner[k], inner[j], col, inside)


## A square-section strut between two arbitrary points. Boxes can only be axis
## aligned or basis-rotated about one axis; anything that runs diagonally in
## two directions at once needs a real lofted tube.
static func _strut(b: RefCounted, a: Vector3, c: Vector3, r: float, col: Color) -> void:
	var d := c - a
	if d.length_squared() < 1e-8:
		return
	var dir := d.normalized()
	var up := Vector3.UP if absf(dir.y) < 0.92 else Vector3.FORWARD
	var r0 := LPB.ring(a, dir, up, r, r, 4, PI * 0.25)
	var r1 := LPB.ring(c, dir, up, r, r, 4, PI * 0.25)
	b.loft([r0, r1], [a, c], col)


## Deterministic pseudo-noise in roughly [-1, 1]. Stands in for randf() so the
## lumpy things stay bit-identical between runs.
static func _wobble(a: int, c: int, seed_v: float) -> float:
	return sin(float(a) * 2.399 + float(c) * 1.117 + seed_v * 3.77) \
		* cos(float(a) * 0.813 - float(c) * 1.937 + seed_v * 1.31)


## An angular lump: four stacked rings plus caps, every vertex kicked around by
## _wobble so no two share a silhouette. `flat` squashes it in Y, which is what
## turns a canopy blob into a pine bough or a boulder.
static func _blob(b: RefCounted, centre: Vector3, rx: float, ry: float, phase: float,
		seed_v: float, col: Color, sides: int) -> void:
	var rings := []
	var spine := []
	var levels := [-0.64, -0.20, 0.24, 0.64]
	for i in range(levels.size()):
		var lv: float = levels[i]
		var y := centre.y + lv * ry
		var shrink := sqrt(maxf(1.0 - lv * lv, 0.05))
		var c := Vector3(centre.x, y, centre.z)
		spine.append(c)
		var base := LPB.ring(c, Vector3.UP, Vector3.FORWARD, rx * shrink, rx * shrink,
			sides, phase + float(i) * 0.42)
		var out := PackedVector3Array()
		for j in base.size():
			var p: Vector3 = base[j]
			var d := p - c
			var k := 1.0 + 0.26 * _wobble(i, j, seed_v)
			out.append(c + Vector3(d.x * k, d.y + ry * 0.18 * _wobble(i + 3, j, seed_v), d.z * k))
		rings.append(out)
	b.loft(rings, spine, col)
	# +0.10 on the top cap was the tuned value for a DAYLIT zone. Here the key
	# light is a low moon, so the top cap of every blob is the one face
	# pointing straight at it, and a hundred bedded boulders across a granite
	# shelf all lit up like paper plates. +0.03 keeps the form read and stops
	# the confetti.
	_cap_axial(b, rings[rings.size() - 1], centre + Vector3(rx * 0.08, ry * 0.96, rx * 0.05),
		Vector3.UP, col.lightened(0.03))
	_cap_axial(b, rings[0], centre + Vector3(0, -ry * 0.92, 0), Vector3.DOWN, col.darkened(0.20))


# ===========================================================================
# 1. CANOE — the zone's signature prop
# ===========================================================================
#
# A 16-foot cedar-canvas canoe, bow at -Z. The read is entirely in the SHEER
# LINE: a canoe is not a boat-shaped box, it is a hull whose gunwale sweeps up
# at both ends and whose beam is widest just aft of amidships. Get the station
# table wrong and no amount of thwarts rescues it.
#
# The hull is lofted as a CLOSED prism whose top edge is the open deck. That
# gives a flat "interior floor" plane at sheer level for free, which is then
# covered by an inset dark plate — much cheaper than a true inner shell and
# indistinguishable from one at every angle a goose ever sees it from.
#
#   z, keel y, sheer y, half-beam
const CANOE_STATIONS := [
	[-2.50, 0.395, 0.660, 0.030],
	[-2.16, 0.235, 0.560, 0.105],
	[-1.55, 0.105, 0.455, 0.245],
	[-0.75, 0.035, 0.405, 0.400],
	[ 0.10, 0.020, 0.395, 0.470],
	[ 0.95, 0.038, 0.410, 0.425],
	[ 1.70, 0.110, 0.462, 0.280],
	[ 2.22, 0.240, 0.568, 0.120],
	[ 2.50, 0.400, 0.665, 0.032],
]


static func _canoe(b: RefCounted, e: RefCounted, params: Dictionary) -> void:
	var hull := _col(params, "colour", Color(0.72, 0.50, 0.28))
	var trim := _col(params, "trim_colour", Color(0.80, 0.72, 0.52))
	var inside := hull.darkened(0.52)

	var rings := []
	var spine := []
	for row in CANOE_STATIONS:
		var st: Array = row
		var z: float = st[0]
		var ky: float = st[1]
		var sy: float = st[2]
		var hw: float = st[3]
		# Port sheer, port turn-of-bilge, keel, starboard bilge, starboard sheer.
		# The closing edge of the polygon (sheer to sheer, straight across) is
		# what the loft turns into the deck plane.
		var bilge_y := lerpf(ky, sy, 0.30)
		rings.append(PackedVector3Array([
			Vector3(-hw, sy, z),
			Vector3(-hw * 0.86, bilge_y, z),
			Vector3(-hw * 0.30, ky + (sy - ky) * 0.045, z),
			Vector3(hw * 0.30, ky + (sy - ky) * 0.045, z),
			Vector3(hw * 0.86, bilge_y, z),
			Vector3(hw, sy, z),
		]))
		spine.append(Vector3(0, lerpf(ky, sy, 0.45), z))
	b.loft(rings, spine, hull)
	# Stem caps: the bow and stern are a knife edge, so the cap apex sits on the
	# centreline rather than at the ring centroid.
	_cap_axial(b, rings[0], Vector3(0, 0.53, -2.56), Vector3.FORWARD, hull.darkened(0.10))
	_cap_axial(b, rings[rings.size() - 1], Vector3(0, 0.53, 2.56), Vector3.BACK,
		hull.darkened(0.10))

	# Interior floor, inset and dark. Two triangles per bay is plenty — this
	# plane is the "inside" and it is only ever seen from above.
	for i in range(CANOE_STATIONS.size() - 1):
		var s0: Array = CANOE_STATIONS[i]
		var s1: Array = CANOE_STATIONS[i + 1]
		var z0: float = s0[0]
		var z1: float = s1[0]
		var w0: float = float(s0[3]) * 0.90
		var w1: float = float(s1[3]) * 0.90
		var y0: float = float(s0[2]) - 0.075
		var y1: float = float(s1[2]) - 0.075
		b.quad(Vector3(-w0, y0, z0), Vector3(w0, y0, z0), Vector3(w1, y1, z1),
			Vector3(-w1, y1, z1), inside, Vector3(0, -2.0, (z0 + z1) * 0.5))

	# Gunwales: a proud rail along each sheer. The single detail that separates
	# a canoe from a bathtub in silhouette.
	for sx in [-1.0, 1.0]:
		var xs: float = sx
		for i in range(CANOE_STATIONS.size() - 1):
			var s0: Array = CANOE_STATIONS[i]
			var s1: Array = CANOE_STATIONS[i + 1]
			var a := Vector3(xs * float(s0[3]), float(s0[2]) + 0.018, float(s0[0]))
			var c := Vector3(xs * float(s1[3]), float(s1[2]) + 0.018, float(s1[0]))
			_strut(b, a, c, 0.030, trim)

	# Two thwarts and a yoke, at the stations where a real canoe puts them.
	for tz in [-1.05, 1.35]:
		var z: float = tz
		var hw := _beam_at(z) * 0.97
		b.box(Vector3(0, 0.400, z), Vector3(hw, 0.020, 0.042), trim)
	var yoke_hw := _beam_at(0.12) * 0.96
	b.box(Vector3(0, 0.402, 0.12), Vector3(yoke_hw, 0.024, 0.075), trim)
	b.box(Vector3(0, 0.430, 0.12), Vector3(0.13, 0.030, 0.055), trim.darkened(0.15))

	# Bow and stern seats: caned frames slung under the gunwale.
	for sz in [-1.72, 1.86]:
		var z: float = sz
		var hw := _beam_at(z) * 0.90
		b.box(Vector3(0, 0.330, z), Vector3(hw, 0.018, 0.135), trim.darkened(0.08))
		for sx in [-1.0, 1.0]:
			b.box(Vector3(sx * hw * 0.86, 0.372, z), Vector3(0.022, 0.062, 0.022), trim)

	# Deck plates in the ends, and a painter line eye through each.
	for sz in [-1.0, 1.0]:
		var s: float = sz
		var z_in := s * 1.90
		var z_out := s * 2.44
		var hw := _beam_at(z_in) * 0.98
		b.quad(Vector3(-hw, _sheer_at(z_in) + 0.010, z_in),
			Vector3(hw, _sheer_at(z_in) + 0.010, z_in),
			Vector3(0.02, _sheer_at(z_out) + 0.010, z_out),
			Vector3(-0.02, _sheer_at(z_out) + 0.010, z_out),
			trim.lightened(0.05), Vector3(0, -2.0, z_in))


## Interpolated half-beam at an arbitrary z, so thwarts and seats land ON the
## hull instead of inside or outside it. Written out because a thwart that
## floats 4 cm proud of the gunwale is the exact failure this file is trying
## to avoid everywhere else.
static func _beam_at(z: float) -> float:
	return _station_lerp(z, 3)


static func _sheer_at(z: float) -> float:
	return _station_lerp(z, 2)


static func _station_lerp(z: float, col: int) -> float:
	var n := CANOE_STATIONS.size()
	var first: Array = CANOE_STATIONS[0]
	if z <= float(first[0]):
		return float(first[col])
	for i in range(n - 1):
		var a: Array = CANOE_STATIONS[i]
		var c: Array = CANOE_STATIONS[i + 1]
		var za: float = a[0]
		var zc: float = c[0]
		if z <= zc:
			var t: float = (z - za) / maxf(zc - za, 0.001)
			return lerpf(float(a[col]), float(c[col]), t)
	var last: Array = CANOE_STATIONS[n - 1]
	return float(last[col])


# ===========================================================================
# 2. KAYAK
# ===========================================================================
#
# Same construction as the canoe but decked over, with a cockpit hole. The
# whole difference in silhouette is that the top surface is a curved deck
# rather than an open sheer, so it gets a raised centreline ridge.

const KAYAK_STATIONS := [
	[-1.95, 0.055, 0.330, 0.040],
	[-1.45, 0.032, 0.320, 0.155],
	[-0.80, 0.018, 0.330, 0.260],
	[-0.10, 0.014, 0.345, 0.300],
	[ 0.62, 0.020, 0.340, 0.278],
	[ 1.30, 0.038, 0.325, 0.190],
	[ 1.95, 0.062, 0.330, 0.045],
]


static func _kayak(b: RefCounted, e: RefCounted, params: Dictionary) -> void:
	var hull := _col(params, "colour", Color(0.86, 0.62, 0.14))
	var deck := hull.lightened(0.10)
	var rings := []
	var spine := []
	for row in KAYAK_STATIONS:
		var st: Array = row
		var z: float = st[0]
		var ky: float = st[1]
		var dy: float = st[2]
		var hw: float = st[3]
		rings.append(PackedVector3Array([
			Vector3(0, dy + 0.045, z),
			Vector3(-hw * 0.72, dy - 0.010, z),
			Vector3(-hw, dy * 0.52, z),
			Vector3(-hw * 0.62, ky + 0.020, z),
			Vector3(0, ky, z),
			Vector3(hw * 0.62, ky + 0.020, z),
			Vector3(hw, dy * 0.52, z),
			Vector3(hw * 0.72, dy - 0.010, z),
		]))
		spine.append(Vector3(0, dy * 0.5, z))
	b.loft(rings, spine, hull)
	_cap_axial(b, rings[0], Vector3(0, 0.20, -2.00), Vector3.FORWARD, deck)
	_cap_axial(b, rings[rings.size() - 1], Vector3(0, 0.21, 2.00), Vector3.BACK, deck)

	# Cockpit coaming and the dark hole inside it.
	var coam_o := _ring_y(0.352, 0.235, 0.360, 0.085)
	var coam_i := _ring_y(0.352, 0.185, 0.300, 0.070)
	_annulus(b, coam_o, coam_i, Vector3.UP, deck.lightened(0.14))
	_cap_axial(b, coam_i, Vector3(0, 0.150, 0), Vector3.DOWN, Color(0.05, 0.06, 0.07))
	# Deck rigging: two bungees fore and aft.
	for dz in [-1.05, 1.05]:
		var z: float = dz
		b.box(Vector3(0, 0.352, z), Vector3(0.24, 0.012, 0.014), Color(0.10, 0.11, 0.12))


# ===========================================================================
# 3. MUSKOKA CHAIR
# ===========================================================================
#
# Two curved side stringers carrying a slatted seat that falls away to the
# back, a tall fanned back, and arms wide enough to hold a beer. The rake is
# the whole joke of the object: you cannot get out of one quickly.

static func _muskoka_chair(b: RefCounted, e: RefCounted, params: Dictionary) -> void:
	var paint := _col(params, "colour", Color(0.72, 0.26, 0.22))
	var shade := paint.darkened(0.22)
	var lit := paint.lightened(0.10)

	# Side stringers: a long board running from the front foot up and back,
	# built as a lofted slab so it can be a real wedge rather than a box.
	for sx in [-1.0, 1.0]:
		var xs: float = sx
		var x := xs * 0.395
		var pts := PackedVector3Array([
			Vector3(x, 0.000, -0.480),
			Vector3(x, 0.330, -0.470),
			Vector3(x, 0.415, 0.020),
			Vector3(x, 0.300, 0.430),
			Vector3(x, 0.000, 0.470),
		])
		var inner := PackedVector3Array()
		for p in pts:
			inner.append(Vector3(x - xs * 0.045, p.y, p.z))
		b.loft([pts, inner], [Vector3(x, 0.2, 0), Vector3(x - xs * 0.045, 0.2, 0)], shade)
		_cap_axial(b, pts, Vector3(x, 0.20, -0.02), Vector3.RIGHT * xs, shade.lightened(0.06))
		_cap_axial(b, inner, Vector3(x - xs * 0.045, 0.20, -0.02), Vector3.LEFT * xs, shade)

	# Seat slats, raked back so you sink into it.
	var seat_rake := Basis(Vector3.RIGHT, deg_to_rad(-9.0))
	for i in 5:
		var t := float(i) / 4.0
		var z := lerpf(-0.415, 0.360, t)
		var y := lerpf(0.400, 0.318, t)
		b.box(Vector3(0, y, z), Vector3(0.360, 0.020, 0.068), paint, seat_rake)

	# Back: seven slats fanning out and leaning 26 degrees. The fan is what
	# makes it a Muskoka chair rather than a deck chair — the top edge is a
	# shallow arc, not a straight line.
	var lean := Basis(Vector3.RIGHT, deg_to_rad(24.0))
	for i in 7:
		var f := float(i) - 3.0
		var x := f * 0.098
		var spread := 1.0 + absf(f) * 0.055
		var h := 0.330 - absf(f) * 0.021
		var mid := Vector3(x * spread, 0.640, 0.395 + absf(f) * 0.012)
		b.box(mid, Vector3(0.044, h, 0.018), paint if i % 2 == 0 else lit, lean)
	# Back uprights the slats are screwed to.
	for sx in [-1.0, 1.0]:
		b.box(Vector3(sx * 0.310, 0.470, 0.430), Vector3(0.030, 0.150, 0.024), shade, lean)
	b.box(Vector3(0, 0.900, 0.300), Vector3(0.330, 0.030, 0.020), shade, lean)

	# Arms — wide, flat, and the reason nobody ever uses the coasters.
	for sx in [-1.0, 1.0]:
		var xs: float = sx
		b.box(Vector3(xs * 0.415, 0.585, -0.070), Vector3(0.100, 0.019, 0.360), lit)
		# Front arm post.
		b.box(Vector3(xs * 0.400, 0.470, -0.380), Vector3(0.028, 0.130, 0.028), shade)


# ===========================================================================
# 4. FIRE PIT — the hero light of the zone
# ===========================================================================

static func _fire_pit(b: RefCounted, e: RefCounted, params: Dictionary) -> void:
	var stone := _col(params, "colour", Color(0.46, 0.45, 0.44))
	var lit := _flag(params, "lit", true)
	var seed_v := _num(params, "variant", 0.0)

	# A ring of nine field stones, each a different lump. Deterministic, so the
	# pit is identical between runs and still looks like somebody stacked it.
	for i in 9:
		var a := TAU * float(i) / 9.0
		var r := 0.94 + 0.06 * _wobble(i, 1, seed_v)
		var h := 0.20 + 0.075 * _wobble(i, 2, seed_v)
		var tint := stone.lightened(0.09 * _wobble(i, 3, seed_v))
		_blob(b, Vector3(cos(a) * r, h, sin(a) * r), 0.29, h * 1.15,
			float(i) * 0.7, seed_v + float(i), tint, 5)

	# Ash bed, dished so the fire sits IN something.
	var rim := LPB.ring(Vector3(0, 0.075, 0), Vector3.UP, Vector3.FORWARD, 0.80, 0.80, 8, 0.2)
	var low := LPB.ring(Vector3(0, 0.020, 0), Vector3.UP, Vector3.FORWARD, 0.55, 0.55, 8, 0.2)
	b.loft([rim, low], [Vector3(0, 0.075, 0), Vector3(0, 0.02, 0)], Color(0.13, 0.12, 0.12))
	_cap_axial(b, low, Vector3(0, 0.012, 0), Vector3.UP, Color(0.09, 0.08, 0.08))

	# Four logs, a tipi over the ash, charred at the inboard end.
	for i in 4:
		var a := TAU * float(i) / 4.0 + 0.4
		var foot := Vector3(cos(a) * 0.62, 0.075, sin(a) * 0.62)
		var head := Vector3(cos(a) * 0.13, 0.60, sin(a) * 0.13)
		_strut(b, foot, head.lerp(foot, 0.35), 0.075, Color(0.34, 0.25, 0.18))
		_strut(b, head.lerp(foot, 0.35), head, 0.062, Color(0.11, 0.10, 0.10))

	if not lit:
		return

	# ── THE FIRE ────────────────────────────────────────────────────────
	# Three nested tapered spikes, from a deep ember orange at the base to
	# near-white at the tip. All unshaded, so this is the one thing in the zone
	# whose brightness does not depend on the moon.
	var flames := [
		[0.00, 0.00, 0.34, 1.05, Color(1.00, 0.42, 0.09)],
		[0.13, 0.07, 0.24, 1.44, Color(1.00, 0.61, 0.17)],
		[-0.11, -0.09, 0.20, 1.18, Color(1.00, 0.52, 0.13)],
		[0.02, -0.02, 0.13, 0.82, Color(1.00, 0.87, 0.55)],
	]
	for fi in range(flames.size()):
		var row: Array = flames[fi]
		var fx: float = row[0]
		var fz: float = row[1]
		var fr: float = row[2]
		var fh: float = row[3]
		var fc: Color = row[4]
		var base := Vector3(fx, 0.055, fz)
		var r0 := LPB.ring(base, Vector3.UP, Vector3.FORWARD, fr, fr, 6, float(fi) * 0.5)
		var r1 := LPB.ring(base + Vector3(fx * 0.9, fh * 0.40, fz * 0.9), Vector3.UP,
			Vector3.FORWARD, fr * 0.80, fr * 0.62, 5, float(fi) * 0.7 + 0.3)
		var r2 := LPB.ring(base + Vector3(fx * 2.1, fh * 0.76, fz * 2.1), Vector3.UP,
			Vector3.FORWARD, fr * 0.26, fr * 0.20, 5, float(fi) * 0.7 + 0.9)
		e.loft([r0, r1, r2], [base, base + Vector3(0, fh * 0.42, 0),
			base + Vector3(0, fh * 0.74, 0)], fc)
		_cap_axial(e, r2, base + Vector3(fx * 3.4, fh, fz * 3.4), Vector3.UP,
			fc.lightened(0.35))

	# Embers glowing between the logs.
	for i in 5:
		var a := TAU * float(i) / 5.0 + 1.1
		var r := 0.20 + 0.16 * absf(_wobble(i, 7, seed_v))
		e.box(Vector3(cos(a) * r, 0.062, sin(a) * r), Vector3(0.055, 0.014, 0.055),
			Color(1.00, 0.36, 0.08))


# ===========================================================================
# 5. DOCK SECTION — tileable end to end along Z
# ===========================================================================

static func _dock_section(b: RefCounted, e: RefCounted, params: Dictionary) -> void:
	var wood := _col(params, "colour", Color(0.50, 0.48, 0.45))
	var wet := wood.darkened(0.28)
	var span := 3.20
	var hw := 1.60

	# Two stringers under the deck, running along Z.
	for sx in [-1.0, 1.0]:
		b.box(Vector3(sx * (hw - 0.16), 1.78, 0), Vector3(0.055, 0.115, span * 0.5), wet)
	b.box(Vector3(0, 1.78, 0), Vector3(0.055, 0.115, span * 0.5), wet)
	# Cross joists.
	for i in 5:
		var z := -span * 0.5 + span * (float(i) + 0.5) / 5.0
		b.box(Vector3(0, 1.78, z), Vector3(hw - 0.05, 0.095, 0.055), wet)

	# Decking: nine boards with a real gap between them. The gap is the read —
	# a solid slab is a jetty, a striped one is a dock.
	var boards := 9
	var pitch := span / float(boards)
	for i in boards:
		var z := -span * 0.5 + pitch * (float(i) + 0.5)
		# Each plank cups and greys slightly differently, keyed off its index.
		var k := 1.0 + 0.10 * _wobble(i, 4, 0.0)
		var col := wood.lightened(0.07 * _wobble(i, 2, 0.0))
		b.box(Vector3(0, 1.905, z), Vector3(hw - 0.02, 0.030, pitch * 0.40 * k), col)

	# Four cedar cribs down into the water, braced. The braces are what make a
	# dock look like it was built by somebody's uncle.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var xs: float = sx
			var zs: float = sz
			var top := Vector3(xs * (hw - 0.13), 1.72, zs * (span * 0.5 - 0.22))
			var bot := Vector3(xs * (hw - 0.02), 0.00, zs * (span * 0.5 - 0.10))
			_strut(b, top, bot, 0.085, wet.darkened(0.15))
	for sx in [-1.0, 1.0]:
		var xs2: float = sx
		_strut(b, Vector3(xs2 * (hw - 0.10), 0.70, -span * 0.5 + 0.2),
			Vector3(xs2 * (hw - 0.10), 0.70, span * 0.5 - 0.2), 0.045, wet.darkened(0.10))
		_strut(b, Vector3(xs2 * (hw - 0.10), 1.40, -span * 0.5 + 0.2),
			Vector3(xs2 * (hw - 0.06), 0.55, span * 0.5 - 0.2), 0.038, wet.darkened(0.10))

	# A cleat, because a dock without one has nothing to tie a canoe to.
	b.box(Vector3(hw - 0.20, 1.955, 0.55), Vector3(0.038, 0.022, 0.115), Color(0.34, 0.35, 0.37))
	for sz in [-1.0, 1.0]:
		b.box(Vector3(hw - 0.20, 1.985, 0.55 + sz * 0.085), Vector3(0.032, 0.030, 0.030),
			Color(0.34, 0.35, 0.37))


# ===========================================================================
# 6. DOCK LIGHT
# ===========================================================================
#
# A single bulb on a leaning cedar post at the end of the dock. It is the only
# light at the bottom of the zone that isn't the fire, so its lens is the
# brightest single face down there and it is what tells the player where the
# water ends.

static func _dock_light(b: RefCounted, e: RefCounted, params: Dictionary) -> void:
	var post := _col(params, "colour", Color(0.42, 0.40, 0.37))
	var glow := _col(params, "glow_colour", Color(0.96, 0.94, 0.80))
	var lit := _flag(params, "lit", true)

	var p0 := LPB.ring(Vector3(0, 0.00, 0), Vector3.UP, Vector3.FORWARD, 0.085, 0.085, 5, 0.3)
	var p1 := LPB.ring(Vector3(0.05, 1.30, 0.02), Vector3.UP, Vector3.FORWARD, 0.070, 0.070, 5, 0.3)
	var p2 := LPB.ring(Vector3(0.11, 2.20, 0.04), Vector3.UP, Vector3.FORWARD, 0.060, 0.060, 5, 0.3)
	b.loft([p0, p1, p2], [Vector3.ZERO, Vector3(0.05, 1.30, 0.02), Vector3(0.11, 2.20, 0.04)], post)
	_cap_axial(b, p0, _centroid(p0), Vector3.DOWN, post.darkened(0.30))

	# Conical tin shade, open at the bottom.
	var sh_hi := LPB.ring(Vector3(0.11, 2.44, 0.04), Vector3.UP, Vector3.FORWARD, 0.075, 0.075, 6, 0.0)
	var sh_lo := LPB.ring(Vector3(0.11, 2.28, 0.04), Vector3.UP, Vector3.FORWARD, 0.230, 0.230, 6, 0.0)
	b.loft([sh_hi, sh_lo], [Vector3(0.11, 2.44, 0.04), Vector3(0.11, 2.28, 0.04)],
		Color(0.28, 0.30, 0.30))
	_loft_inward(b, [sh_hi, sh_lo], [Vector3(0.11, 2.44, 0.04), Vector3(0.11, 2.28, 0.04)],
		Color(0.86, 0.84, 0.76))
	_cap_axial(b, sh_hi, Vector3(0.11, 2.52, 0.04), Vector3.UP, Color(0.30, 0.32, 0.32))
	b.box(Vector3(0.11, 2.56, 0.04), Vector3(0.026, 0.055, 0.026), post.darkened(0.2))

	if lit:
		# The bulb: a small unshaded lump hanging under the shade.
		var bulb := LPB.ring(Vector3(0.11, 2.24, 0.04), Vector3.UP, Vector3.FORWARD, 0.075, 0.075, 6, 0.0)
		var bulb_lo := LPB.ring(Vector3(0.11, 2.13, 0.04), Vector3.UP, Vector3.FORWARD, 0.045, 0.045, 6, 0.0)
		e.loft([bulb, bulb_lo], [Vector3(0.11, 2.24, 0.04), Vector3(0.11, 2.13, 0.04)], glow)
		_cap_axial(e, bulb_lo, Vector3(0.11, 2.09, 0.04), Vector3.DOWN, glow)


# ===========================================================================
# 7. EASTERN WHITE PINE
# ===========================================================================
#
# Deliberately NOT prop_models.gd's tree_conifer, which is a stacked cone —
# right for a nursery spruce on a traffic island, wrong for the Shield. A white
# pine is a long bare trunk with the crown pushed to the top, its boughs
# horizontal, asymmetric and gappy, and the whole tree leaning away from the
# prevailing wind. The gaps matter: at night the moon comes THROUGH a pine, and
# a solid cone silhouette just reads as a hill.
#
#   height, radial offset, angle, plate radius, plate thickness
const PINE_BOUGHS := [
	[5.10, 0.55, 0.00, 1.50, 0.68],
	[5.95, 0.75, 2.40, 1.88, 0.76],
	[6.85, 0.62, 4.60, 2.05, 0.72],
	[7.70, 0.80, 1.10, 1.95, 0.70],
	[8.50, 0.58, 3.60, 1.66, 0.62],
	[9.25, 0.66, 5.60, 1.30, 0.54],
	[9.95, 0.42, 0.90, 0.88, 0.46],
]


static func _pine(b: RefCounted, e: RefCounted, params: Dictionary) -> void:
	var bark := _col(params, "colour", Color(0.27, 0.21, 0.17))
	var needle := _col(params, "leaf_colour", Color(0.12, 0.24, 0.18))
	var seed_v := _num(params, "variant", 0.0)
	var lean := 0.020 + 0.014 * _wobble(1, 1, seed_v)

	# Trunk: six-sided, tapering hard, leaning.
	var prof := [[0.00, 0.36], [1.60, 0.27], [4.20, 0.205], [7.20, 0.145], [10.40, 0.075]]
	var rings := []
	var spine := []
	for i in range(prof.size()):
		var row: Array = prof[i]
		var y: float = row[0]
		var r: float = row[1]
		var c := Vector3(lean * y, y, -lean * 0.6 * y)
		spine.append(c)
		rings.append(LPB.ring(c, Vector3.UP, Vector3.FORWARD, r, r, 6, PI / 6.0 + float(i) * 0.13))
	b.loft(rings, spine, bark)
	_cap_axial(b, rings[0], _centroid(rings[0]), Vector3.DOWN, bark.darkened(0.35))

	# Root flare: three buttresses, because a pine on granite grips it.
	for i in 3:
		var a := TAU * float(i) / 3.0 + seed_v
		_strut(b, Vector3(cos(a) * 0.58, 0.02, sin(a) * 0.58),
			Vector3(cos(a) * 0.16, 1.05, sin(a) * 0.16), 0.10, bark.darkened(0.10))

	# Dead lower limbs, the stubs a white pine keeps for decades.
	for i in 3:
		var y := 2.5 + float(i) * 0.85
		var a := 1.7 + float(i) * 2.3 + seed_v
		var base := Vector3(lean * y, y, -lean * 0.6 * y)
		_strut(b, base, base + Vector3(cos(a) * 1.05, 0.28, sin(a) * 1.05), 0.045,
			bark.darkened(0.18))

	# The crown.
	for bi in range(PINE_BOUGHS.size()):
		var row: Array = PINE_BOUGHS[bi]
		var y: float = row[0]
		var off: float = row[1]
		var ang: float = row[2] + seed_v
		var rad: float = row[3]
		var thick: float = row[4]
		var trunk_at := Vector3(lean * y, y, -lean * 0.6 * y)
		var centre := trunk_at + Vector3(cos(ang) * off, 0.10, sin(ang) * off)
		# Branch out to the mass, so the bough is carried rather than floating.
		_strut(b, trunk_at, centre, 0.048, bark.darkened(0.12))
		# The mass itself, flattened so it is a plate not a ball.
		var shade := needle.lightened(0.035 * float(bi))
		_blob(b, centre, rad, thick, ang * 0.7, seed_v + float(bi) * 1.3, shade, 6)
		# A second, smaller lump on the opposite side of the trunk breaks the
		# symmetry that makes a low-poly conifer look like a Christmas decoration.
		if bi % 2 == 0:
			var opp := trunk_at + Vector3(cos(ang + 2.9) * off * 0.80, -0.14,
				sin(ang + 2.9) * off * 0.80)
			_blob(b, opp, rad * 0.62, thick * 0.85, ang, seed_v + float(bi) * 2.1,
				shade.darkened(0.08), 5)

	# Leader: the spike that says pine rather than shrub.
	var tip := Vector3(lean * 10.4, 10.4, -lean * 0.6 * 10.4)
	var lead := LPB.ring(tip, Vector3.UP, Vector3.FORWARD, 0.52, 0.52, 6, 0.4)
	b.cap(lead, tip + Vector3(0.10, 1.55, 0), tip + Vector3(0, -1.5, 0), needle.lightened(0.14))
	_cap_axial(b, lead, tip + Vector3(0, -0.22, 0), Vector3.DOWN, needle.darkened(0.20))


# ===========================================================================
# 8. BUG ZAPPER
# ===========================================================================
#
# The violet lantern hanging off the porch corner. Its light is the wrong
# colour for everything it touches, which is the point: it is the only cold
# artificial source at the top of the zone and it makes the warm ones read
# warmer by sitting next to them.

static func _bug_zapper(b: RefCounted, e: RefCounted, params: Dictionary) -> void:
	var shell := _col(params, "colour", Color(0.16, 0.17, 0.19))
	var glow := _col(params, "glow_colour", Color(0.60, 0.42, 1.00))
	var lit := _flag(params, "lit", true)

	# Hanging hook.
	b.box(Vector3(0, 0.885, 0), Vector3(0.016, 0.055, 0.016), shell.lightened(0.25))
	b.box(Vector3(0, 0.815, 0), Vector3(0.055, 0.020, 0.055), shell.lightened(0.15))

	# Domed cap.
	var cap_lo := _ring_y(0.700, 0.205, 0.205, 0.055)
	var cap_hi := _ring_y(0.790, 0.100, 0.100, 0.030)
	b.loft([cap_lo, cap_hi], [Vector3(0, 0.70, 0), Vector3(0, 0.79, 0)], shell)
	_cap_axial(b, cap_hi, Vector3(0, 0.815, 0), Vector3.UP, shell.lightened(0.10))

	# Cage: four corner posts and two hoops. The gaps between them are where
	# the grid shows through, so they stay thin.
	for i in 4:
		var a := TAU * float(i) / 4.0 + PI * 0.25
		_strut(b, Vector3(cos(a) * 0.185, 0.135, sin(a) * 0.185),
			Vector3(cos(a) * 0.185, 0.700, sin(a) * 0.185), 0.017, shell.lightened(0.10))
	for hy in [0.20, 0.63]:
		var y: float = hy
		var ho := _ring_y(y, 0.195, 0.195, 0.055)
		var hi := _ring_y(y, 0.170, 0.170, 0.048)
		_annulus(b, ho, hi, Vector3.UP, shell.lightened(0.14))

	# Base tray.
	var base_lo := _ring_y(0.000, 0.190, 0.190, 0.050)
	var base_hi := _ring_y(0.135, 0.215, 0.215, 0.055)
	b.loft([base_lo, base_hi], [Vector3.ZERO, Vector3(0, 0.135, 0)], shell)
	_cap_axial(b, base_lo, _centroid(base_lo), Vector3.DOWN, shell.darkened(0.25))

	if not lit:
		return
	# The grid: a stack of horizontal bars, unshaded violet, visible through the
	# cage from every angle.
	for i in 7:
		var y := 0.215 + float(i) * 0.066
		e.box(Vector3(0, y, 0), Vector3(0.130, 0.014, 0.130), glow)
	e.box(Vector3(0, 0.42, 0), Vector3(0.032, 0.215, 0.032), glow.lightened(0.30))


# ===========================================================================
# 9. COOLER
# ===========================================================================

static func _cooler(b: RefCounted, e: RefCounted, params: Dictionary) -> void:
	var body := _col(params, "colour", Color(0.16, 0.34, 0.62))
	var lid := _col(params, "trim_colour", Color(0.90, 0.90, 0.88))

	# Tub: slightly tapered so they stack, with a moulded foot.
	var f0 := _ring_y(0.000, 0.355, 0.205, 0.045)
	var f1 := _ring_y(0.045, 0.375, 0.220, 0.050)
	var f2 := _ring_y(0.400, 0.395, 0.235, 0.055)
	b.loft([f0, f1, f2], [Vector3.ZERO, Vector3(0, 0.045, 0), Vector3(0, 0.40, 0)], body)
	_cap_axial(b, f0, _centroid(f0), Vector3.DOWN, body.darkened(0.35))
	# Moulded rib around the belly.
	var rb_lo := _ring_y(0.185, 0.401, 0.241, 0.055)
	var rb_hi := _ring_y(0.245, 0.403, 0.243, 0.055)
	b.loft([rb_lo, rb_hi], [Vector3(0, 0.185, 0), Vector3(0, 0.245, 0)], body.lightened(0.10))

	# Lid: overhanging, slightly domed.
	var l0 := _ring_y(0.400, 0.410, 0.248, 0.055)
	var l1 := _ring_y(0.480, 0.412, 0.250, 0.056)
	var l2 := _ring_y(0.535, 0.350, 0.205, 0.048)
	b.loft([l0, l1, l2], [Vector3(0, 0.40, 0), Vector3(0, 0.48, 0), Vector3(0, 0.535, 0)], lid)
	_cap_axial(b, l2, Vector3(0, 0.545, 0), Vector3.UP, lid.lightened(0.06))
	# Recessed grab handle across the lid, and a latch on the front.
	b.box(Vector3(0, 0.548, 0), Vector3(0.145, 0.020, 0.055), lid.darkened(0.18))
	b.box(Vector3(0, 0.415, -0.255), Vector3(0.070, 0.038, 0.020), lid.darkened(0.30))
	# End handles.
	for sx in [-1.0, 1.0]:
		b.box(Vector3(sx * 0.415, 0.290, 0.0), Vector3(0.024, 0.048, 0.115), body.darkened(0.22))


# ===========================================================================
# 10. LOON
# ===========================================================================
#
# The design bible asks for loons and it is right to: the call is the single
# most recognisable sound in this landscape, and a lake with nothing on it is
# a car park that happens to be wet. Low in the water, black head, white
# necklace, chequered back, dagger bill. Built low and long — a loon sits
# deeper than a duck, and that profile is most of the recognition.

static func _loon(b: RefCounted, e: RefCounted, params: Dictionary) -> void:
	var black := _col(params, "colour", Color(0.07, 0.08, 0.10))
	var white := Color(0.90, 0.92, 0.94)
	var seed_v := _num(params, "variant", 0.0)

	# Body: a long low hull, waterline at about y = 0.08.
	var body := [
		[-0.52, 0.055, 0.075],
		[-0.30, 0.120, 0.160],
		[ 0.00, 0.140, 0.195],
		[ 0.28, 0.125, 0.170],
		[ 0.50, 0.085, 0.105],
	]
	var rings := []
	var spine := []
	for i in range(body.size()):
		var row: Array = body[i]
		var z: float = row[0]
		var ry: float = row[1]
		var rx: float = row[2]
		var c := Vector3(0, 0.115, z)
		spine.append(c)
		rings.append(LPB.ring(c, Vector3.BACK, Vector3.UP, rx, ry, 6, PI / 6.0))
	b.loft(rings, spine, black)
	_cap_axial(b, rings[0], Vector3(0, 0.105, -0.60), Vector3.FORWARD, black)
	# Tail: short and pointed, cocked up a touch.
	_cap_axial(b, rings[rings.size() - 1], Vector3(0, 0.155, 0.66), Vector3.BACK,
		black.lightened(0.05))

	# The chequered back: eight pale tiles laid over the dorsal surface. This is
	# the whole identification and it costs sixteen triangles.
	for i in 4:
		for sx in [-1.0, 1.0]:
			var z := -0.24 + float(i) * 0.17
			var xs: float = sx
			b.box(Vector3(xs * 0.075, 0.246 - absf(z) * 0.10, z),
				Vector3(0.042, 0.010, 0.048), white)

	# Neck: rising forward, then the head.
	var neck_base := Vector3(0, 0.20, -0.40)
	var head := Vector3(0, 0.44, -0.52)
	var n0 := LPB.ring(neck_base, (head - neck_base).normalized(), Vector3.UP, 0.070, 0.070, 5, 0.2)
	var n1 := LPB.ring(head, (head - neck_base).normalized(), Vector3.UP, 0.078, 0.088, 5, 0.2)
	b.loft([n0, n1], [neck_base, head], black)
	# The white necklace, halfway up the neck.
	var band := neck_base.lerp(head, 0.42)
	b.box(band, Vector3(0.079, 0.030, 0.079), white)
	b.box(band + Vector3(0, 0.055, 0), Vector3(0.076, 0.014, 0.076), black)

	# Head and dagger bill.
	_blob(b, head + Vector3(0, 0.045, -0.02), 0.098, 0.088, 0.3, seed_v, black, 5)
	var bill_a := head + Vector3(0, 0.055, -0.09)
	var bill_b := head + Vector3(0, 0.030, -0.30)
	_strut(b, bill_a, bill_b, 0.030, black.lightened(0.06))
	# Red eye — small, unshaded, and the only warm thing on the lake.
	for sx in [-1.0, 1.0]:
		e.box(head + Vector3(sx * 0.085, 0.062, -0.055), Vector3(0.018, 0.018, 0.018),
			Color(0.92, 0.16, 0.12))


# ===========================================================================
# 11. TOAD
# ===========================================================================
#
# American toad. Warty, squat, unbothered. The eyes are on the glow shell so
# that the one thing you can see of it in the dark is two little coins looking
# back at you, which is exactly how you actually find a toad at night.

static func _toad(b: RefCounted, e: RefCounted, params: Dictionary) -> void:
	var skin := _col(params, "colour", Color(0.30, 0.31, 0.21))
	var belly := skin.lightened(0.30)
	var seed_v := _num(params, "variant", 0.0)

	# Body: wide, flat, tapering to the rump.
	var prof := [
		[-0.22, 0.075, 0.115],
		[-0.06, 0.098, 0.160],
		[ 0.10, 0.090, 0.150],
		[ 0.24, 0.058, 0.092],
	]
	var rings := []
	var spine := []
	for i in range(prof.size()):
		var row: Array = prof[i]
		var z: float = row[0]
		var ry: float = row[1]
		var rx: float = row[2]
		var c := Vector3(0, ry * 0.92, z)
		spine.append(c)
		var base := LPB.ring(c, Vector3.BACK, Vector3.UP, rx, ry, 6, PI / 6.0)
		var lumpy := PackedVector3Array()
		for j in base.size():
			var p: Vector3 = base[j]
			var d := p - c
			var k := 1.0 + 0.16 * _wobble(i, j, seed_v)
			lumpy.append(c + d * k)
		rings.append(lumpy)
	b.loft(rings, spine, skin)
	_cap_axial(b, rings[0], Vector3(0, 0.085, -0.28), Vector3.FORWARD, belly.darkened(0.10))
	_cap_axial(b, rings[rings.size() - 1], Vector3(0, 0.050, 0.28), Vector3.BACK,
		skin.darkened(0.15))

	# Warts. Nine of them, deterministic, because a smooth toad is a frog and
	# a frog is a completely different joke.
	for i in 9:
		var a := TAU * float(i) / 9.0
		var z := -0.14 + 0.30 * (float(i % 3) / 2.0)
		var r := 0.085 + 0.045 * absf(_wobble(i, 5, seed_v))
		b.box(Vector3(cos(a) * r, 0.140 + 0.028 * _wobble(i, 2, seed_v), z),
			Vector3(0.026, 0.020, 0.026), skin.darkened(0.16))

	# Legs, folded.
	for sx in [-1.0, 1.0]:
		var xs: float = sx
		_strut(b, Vector3(xs * 0.115, 0.055, 0.115), Vector3(xs * 0.185, 0.045, -0.020),
			0.032, skin.darkened(0.08))
		b.box(Vector3(xs * 0.175, 0.022, -0.075), Vector3(0.055, 0.020, 0.038),
			belly.darkened(0.05))
		b.box(Vector3(xs * 0.125, 0.028, -0.185), Vector3(0.030, 0.024, 0.045),
			belly.darkened(0.05))

	# Parotoid glands behind the eyes — the bit the National Park Service is
	# talking about.
	for sx in [-1.0, 1.0]:
		b.box(Vector3(sx * 0.095, 0.150, -0.155), Vector3(0.036, 0.026, 0.055),
			skin.lightened(0.12))
	# Eyes: gold, unshaded, half-lidded.
	for sx in [-1.0, 1.0]:
		var xs2: float = sx
		e.box(Vector3(xs2 * 0.078, 0.182, -0.198), Vector3(0.036, 0.030, 0.032),
			_col(params, "glow_colour", Color(0.95, 0.82, 0.24)))
		b.box(Vector3(xs2 * 0.078, 0.208, -0.198), Vector3(0.040, 0.014, 0.036),
			skin.darkened(0.10))


## The cottage dog, asleep on her side by the fire, which is where she has been
## since four o'clock and where she intends to remain.
##
## She is here because `molly` needs a body and the placeholder was two peach
## boxes with the pickup's own model floating over them — a shape the render
## showed reading as a stack of cardboard rather than as an animal. A dog is
## four boxes and a snout more than a crate; it is worth the four boxes.
static func _dog(b: RefCounted, e: RefCounted, params: Dictionary) -> void:
	var fur := _col(params, "colour", Color(0.62, 0.44, 0.20))
	var pale := fur.lightened(0.22)
	var seed_v := _num(params, "variant", 0.0)

	# Body: a long low loaf lying along Z, deeper at the chest than the hip.
	var prof := [
		[-0.62, 0.20, 0.20],
		[-0.30, 0.27, 0.26],
		[ 0.10, 0.28, 0.25],
		[ 0.48, 0.23, 0.20],
		[ 0.72, 0.15, 0.13],
	]
	var rings := []
	var spine := []
	for i in range(prof.size()):
		var row: Array = prof[i]
		var z: float = row[0]
		var ry: float = row[1]
		var rx: float = row[2]
		var c := Vector3(0, 0.245, z)
		spine.append(c)
		rings.append(LPB.ring(c, Vector3.BACK, Vector3.UP, rx, ry, 6, PI / 6.0 + float(i) * 0.2))
	b.loft(rings, spine, fur)
	_cap_axial(b, rings[0], Vector3(0, 0.24, -0.70), Vector3.FORWARD, fur.darkened(0.10))
	_cap_axial(b, rings[rings.size() - 1], Vector3(0, 0.20, 0.78), Vector3.BACK, fur)
	# Pale chest and belly.
	b.box(Vector3(0, 0.075, -0.20), Vector3(0.16, 0.055, 0.34), pale)

	# Head, laid flat on the ground with the muzzle stretched out front.
	var head := Vector3(0.05, 0.20, -0.80)
	_blob(b, head, 0.20, 0.17, 0.4, seed_v, fur, 5)
	b.box(head + Vector3(0, -0.045, -0.20), Vector3(0.085, 0.070, 0.145), pale)
	b.box(head + Vector3(0, -0.055, -0.335), Vector3(0.048, 0.040, 0.028), Color(0.10, 0.09, 0.09))
	# Ears, flopped.
	for sx in [-1.0, 1.0]:
		var xs: float = sx
		b.box(head + Vector3(xs * 0.175, 0.005, 0.010), Vector3(0.032, 0.105, 0.075),
			fur.darkened(0.16), Basis(Vector3.BACK, deg_to_rad(-xs * 22.0)))
	# One eye visible, shut. A dog asleep with its eyes open is a different game.
	b.box(head + Vector3(0.085, 0.045, -0.115), Vector3(0.050, 0.010, 0.030),
		fur.darkened(0.34))

	# Legs, folded and stacked the way a dog on its side actually lies.
	for sz in [-0.30, 0.34]:
		var z: float = sz
		for sx in [-1.0, 1.0]:
			var xs2: float = sx
			_strut(b, Vector3(xs2 * 0.13, 0.14, z), Vector3(xs2 * 0.26, 0.055, z - 0.22),
				0.055, fur.lightened(0.06))
			b.box(Vector3(xs2 * 0.30, 0.045, z - 0.30), Vector3(0.055, 0.045, 0.075), pale)
	# Tail, curled round.
	_strut(b, Vector3(0, 0.22, 0.70), Vector3(0.26, 0.10, 0.90), 0.055, fur.lightened(0.10))
	_strut(b, Vector3(0.26, 0.10, 0.90), Vector3(0.44, 0.06, 0.66), 0.042, pale)


# ===========================================================================
# 12. GRANITE BOULDER — the Canadian Shield, in one reusable lump
# ===========================================================================

static func _rock(b: RefCounted, e: RefCounted, params: Dictionary) -> void:
	var base := _col(params, "colour", Color(0.20, 0.19, 0.21))
	var seed_v := _num(params, "variant", 0.0)

	# Two interpenetrating masses rather than one lump: shield rock is bedded
	# and fractured, so a single blob reads as a potato.
	_blob(b, Vector3(0, 0.40, 0), 0.94, 0.44, seed_v * 0.7, seed_v, base, 6)
	_blob(b, Vector3(0.20 * _wobble(1, 2, seed_v), 0.64, 0.16 * _wobble(3, 1, seed_v)),
		0.64, 0.36, seed_v * 1.3 + 0.9, seed_v + 3.0, base.lightened(0.045), 5)

	# ── EVERY DETAIL BELOW HAS TO STAY INSIDE THE SILHOUETTE ────────────
	# The first version put the quartz veins at y 0.70-0.83 with endpoints at
	# ±0.85, and the lichen at y 0.86. The upper blob's actual radius at those
	# heights is about 0.55, so both details hung out past the rock — and
	# because a hundred of these are scattered across a dark shelf at glancing
	# angles, what the render showed was not "granite with veins" but a field
	# of thin white slivers and floating olive plates. Details on a small prop
	# have to be conservative: if it might poke through, it will, at the exact
	# scale and angle you never checked.
	for i in 2:
		var a := 0.7 + float(i) * 1.9 + seed_v
		var y := 0.44 + float(i) * 0.11
		_strut(b, Vector3(cos(a) * -0.56, y, sin(a) * -0.48),
			Vector3(cos(a) * 0.56, y + 0.05, sin(a) * 0.48), 0.042,
			base.lightened(0.16))
	# Lichen, a colour that only exists on rock. Sunk INTO the upper mass.
	for i in 3:
		var a := TAU * float(i) / 3.0 + seed_v * 2.0
		b.box(Vector3(cos(a) * 0.26, 0.80, sin(a) * 0.22), Vector3(0.115, 0.016, 0.100),
			base.lerp(Color(0.30, 0.33, 0.20), 0.34))


## Low scrub — blueberry, juniper, sweet fern. Whatever will grow in nine
## centimetres of soil on top of a billion-year-old rock.
##
## It exists for one reason: the plateau and the ledges are large flat boxes,
## and a large flat box with nothing on it reads as a floor tile at any hour
## but reads as a PARKING LOT at night, when the only cue you have to a
## surface's material is its silhouette against the sky. Six of these along a
## ledge edge and the ledge becomes ground.
static func _scrub(b: RefCounted, e: RefCounted, params: Dictionary) -> void:
	var leaf := _col(params, "colour", Color(0.16, 0.24, 0.15))
	var seed_v := _num(params, "variant", 0.0)
	for i in 3:
		var a := TAU * float(i) / 3.0 + seed_v
		var r := 0.30 + 0.16 * _wobble(i, 1, seed_v)
		var h := 0.26 + 0.10 * _wobble(i, 4, seed_v)
		_blob(b, Vector3(cos(a) * r, h * 1.05, sin(a) * r * 0.9),
			0.44 + 0.12 * _wobble(i, 2, seed_v), h,
			a, seed_v + float(i) * 1.7, leaf.lightened(0.05 * float(i)), 5)
	# A few bare twigs poking out of the top, so the silhouette isn't three
	# smooth lumps.
	for i in 4:
		var a := 1.3 + float(i) * 1.6 + seed_v
		_strut(b, Vector3(cos(a) * 0.16, 0.20, sin(a) * 0.16),
			Vector3(cos(a) * 0.62, 0.60 + 0.10 * _wobble(i, 3, seed_v), sin(a) * 0.62),
			0.018, Color(0.26, 0.22, 0.17))


# ===========================================================================
# 13. FIREWOOD STACK
# ===========================================================================

static func _firewood(b: RefCounted, e: RefCounted, params: Dictionary) -> void:
	var bark := _col(params, "colour", Color(0.33, 0.26, 0.20))
	var split := Color(0.72, 0.62, 0.47)
	var seed_v := _num(params, "variant", 0.0)

	var rows := 4
	var per := 7
	for r in rows:
		var n: int = per - int(r / 2)
		for i in n:
			var x := -1.05 + (2.10 / float(maxi(n - 1, 1))) * float(i)
			var y := 0.16 + float(r) * 0.245
			var z := 0.055 * _wobble(r, i, seed_v)
			var rot := deg_to_rad(6.0 * _wobble(r + 2, i, seed_v))
			var rad := 0.115 + 0.022 * _wobble(r, i + 3, seed_v)
			# A split log is a wedge: bark on one arc, pale face on the flat.
			var a := Vector3(x, y, z - 0.36)
			var c := Vector3(x, y, z + 0.36)
			var ra := LPB.ring(a, Vector3.BACK, Vector3.UP, rad, rad, 5, rot)
			var rc := LPB.ring(c, Vector3.BACK, Vector3.UP, rad, rad, 5, rot)
			b.loft([ra, rc], [a, c], bark)
			_cap_axial(b, rc, c + Vector3(0, 0, 0.012), Vector3.BACK, split)
			_cap_axial(b, ra, a - Vector3(0, 0, 0.012), Vector3.FORWARD, split.darkened(0.18))
	# The tarp somebody half threw over it, and the two rebar ends holding the
	# stack up. This is what a real woodpile looks like in September.
	b.box(Vector3(0.35, 1.075, 0.02), Vector3(0.80, 0.030, 0.42),
		Color(0.14, 0.24, 0.18), Basis(Vector3.RIGHT, deg_to_rad(4.0)))
	for sx in [-1.0, 1.0]:
		b.box(Vector3(sx * 1.16, 0.50, 0), Vector3(0.024, 0.50, 0.024), Color(0.30, 0.26, 0.24))


## ONE split log, for the loose ones lying around the pit.
##
## This exists because the first render pass used the `firewood` STACK as the
## chaos prop and passed it a 0.24 m box to fit into. `build()` obligingly
## scaled a four-row woodpile down by 90% in X, and eleven of those scattered
## around a campfire read on screen as the level having exploded. A prop model
## must be authored at the size of the collider it will hang on; a stack is a
## piece of set dressing and a log is a prop, and they are not the same object.
static func _log(b: RefCounted, e: RefCounted, params: Dictionary) -> void:
	var bark := _col(params, "colour", Color(0.36, 0.28, 0.21))
	var split := bark.lightened(0.44)
	var seed_v := _num(params, "variant", 0.0)
	var a := Vector3(0.012 * _wobble(1, 1, seed_v), 0.13, -0.37)
	var c := Vector3(-0.012 * _wobble(2, 1, seed_v), 0.13, 0.37)
	var ra := LPB.ring(a, Vector3.BACK, Vector3.UP, 0.128, 0.128, 5, seed_v * 0.4)
	var rm := LPB.ring((a + c) * 0.5, Vector3.BACK, Vector3.UP, 0.132, 0.132, 5, seed_v * 0.4)
	var rc := LPB.ring(c, Vector3.BACK, Vector3.UP, 0.126, 0.126, 5, seed_v * 0.4)
	b.loft([ra, rm, rc], [a, (a + c) * 0.5, c], bark)
	# The two sawn ends: pale, with growth rings suggested by one inset disc.
	_cap_axial(b, rc, c + Vector3(0, 0, 0.012), Vector3.BACK, split)
	_cap_axial(b, ra, a - Vector3(0, 0, 0.012), Vector3.FORWARD, split.darkened(0.14))
	b.box(c + Vector3(0, 0, 0.020), Vector3(0.055, 0.055, 0.008), split.darkened(0.22))
	# The split face — one flat plane down the side, which is what makes it
	# firewood rather than a branch.
	b.box(Vector3(0.104, 0.13, 0.0), Vector3(0.028, 0.086, 0.330), split.darkened(0.06),
		Basis(Vector3.BACK, deg_to_rad(8.0)))


# ===========================================================================
# 14. PADDLE
# ===========================================================================

static func _paddle(b: RefCounted, e: RefCounted, params: Dictionary) -> void:
	var wood := _col(params, "colour", Color(0.76, 0.63, 0.40))
	var tip := _col(params, "trim_colour", Color(0.24, 0.42, 0.56))
	# Shaft along Z, blade at +Z, grip at -Z.
	_strut(b, Vector3(0, 0.030, -0.72), Vector3(0, 0.030, 0.36), 0.020, wood)
	b.box(Vector3(0, 0.030, -0.80), Vector3(0.070, 0.022, 0.055), wood.darkened(0.10))
	# Blade: a tapered plate with a spine down the middle.
	var blade := PackedVector3Array([
		Vector3(0.000, 0.030, 0.34),
		Vector3(0.105, 0.030, 0.50),
		Vector3(0.118, 0.030, 0.72),
		Vector3(0.075, 0.030, 0.82),
		Vector3(-0.075, 0.030, 0.82),
		Vector3(-0.118, 0.030, 0.72),
		Vector3(-0.105, 0.030, 0.50),
	])
	b.plate(blade, 0.016, 0.012, wood)
	b.box(Vector3(0, 0.030, 0.79), Vector3(0.090, 0.014, 0.038), tip)


# ===========================================================================
# 15. TWO-FOUR
# ===========================================================================
#
# A case of twenty-four, sitting where somebody put it down. The bottle necks
# poking through the torn top are the whole read.

static func _two_four(b: RefCounted, e: RefCounted, params: Dictionary) -> void:
	var card := _col(params, "colour", Color(0.60, 0.16, 0.14))
	var glass := _col(params, "trim_colour", Color(0.32, 0.21, 0.09))

	var lo := _ring_y(0.000, 0.275, 0.185, 0.020)
	var hi := _ring_y(0.290, 0.278, 0.188, 0.020)
	b.loft([lo, hi], [Vector3.ZERO, Vector3(0, 0.29, 0)], card)
	_cap_axial(b, lo, _centroid(lo), Vector3.DOWN, card.darkened(0.35))
	# The label band.
	b.box(Vector3(0, 0.150, -0.190), Vector3(0.215, 0.070, 0.010), Color(0.90, 0.88, 0.82))
	b.box(Vector3(0, 0.150, 0.190), Vector3(0.215, 0.070, 0.010), Color(0.90, 0.88, 0.82))
	# Torn-open flaps.
	for sz in [-1.0, 1.0]:
		var zs: float = sz
		b.box(Vector3(0, 0.320, zs * 0.145), Vector3(0.270, 0.012, 0.100),
			card.lightened(0.18), Basis(Vector3.RIGHT, deg_to_rad(zs * 34.0)))
	# Six visible necks in a 3 x 2 grid, capped gold.
	for ix in 3:
		for iz in 2:
			var x := -0.145 + float(ix) * 0.145
			var z := -0.075 + float(iz) * 0.150
			b.box(Vector3(x, 0.335, z), Vector3(0.032, 0.050, 0.032), glass)
			b.box(Vector3(x, 0.382, z), Vector3(0.034, 0.014, 0.034), Color(0.78, 0.66, 0.24))


# ===========================================================================
# 16. PICNIC TABLE
# ===========================================================================

static func _picnic_table(b: RefCounted, e: RefCounted, params: Dictionary) -> void:
	var wood := _col(params, "colour", Color(0.46, 0.36, 0.25))
	var dark := wood.darkened(0.22)
	# Top: five boards with gaps.
	for i in 5:
		var z := -0.62 + float(i) * 0.31
		b.box(Vector3(0, 0.755, z), Vector3(0.98, 0.026, 0.135),
			wood.lightened(0.05 * _wobble(i, 1, 0.0)))
	b.box(Vector3(0, 0.715, 0), Vector3(0.94, 0.035, 0.68), dark)
	# A-frame legs, splayed.
	for sx in [-1.0, 1.0]:
		var xs: float = sx
		for sz in [-1.0, 1.0]:
			var zs: float = sz
			_strut(b, Vector3(xs * 0.68, 0.00, zs * 0.86), Vector3(xs * 0.30, 0.74, zs * 0.28),
				0.042, dark)
		# Bench planks hung off the legs.
		b.box(Vector3(xs * 0.60, 0.425, 0), Vector3(0.155, 0.026, 0.72), wood)
		_strut(b, Vector3(xs * 0.30, 0.40, -0.86), Vector3(xs * 0.30, 0.40, 0.86), 0.030, dark)
	b.box(Vector3(0, 0.36, 0), Vector3(0.62, 0.030, 0.045), dark)


# ===========================================================================
# 17. THE COTTAGE
# ===========================================================================
#
# ORIENTATION: the lake facade — screen porch, deck, the big windows — is at
# LOCAL -Z, matching prop_models.gd's house and the zones' convention that
# `front` is -Z. The gable ridge runs along X, so the LONG side faces the
# water, which is what every cottage on every lake in the district does for
# the obvious reason.
#
# The lighting job this model has to do: at 0.42 moonlight the walls are a
# dark mass, and everything the player reads about the building comes from
# the eight glowing rectangles on the glow shell. So the windows are large,
# they are unevenly lit (one room is dark, because one room is always dark),
# and the porch has a warm floor plate inside it so the screen glows from
# within rather than being a black hole under a roof.

static func _cottage(b: RefCounted, e: RefCounted, params: Dictionary) -> void:
	var w := _num(params, "w", 14.0)
	var d := _num(params, "d", 10.0)
	var wall_h := _num(params, "wall_h", 3.0)
	var roof_h := _num(params, "roof_h", 2.4)
	var porch_d := _num(params, "porch_d", 2.8)
	var wall := _col(params, "colour", Color(0.27, 0.185, 0.135))
	var roof := _col(params, "trim_colour", Color(0.085, 0.155, 0.135))
	var glow := _col(params, "glow_colour", Color(1.00, 0.78, 0.42))
	var lit := _flag(params, "lit", true)

	var hw := w * 0.5
	var hd := d * 0.5
	var eave_x := hw * 1.06
	var eave_z := hd * 1.10
	var ridge_y := wall_h + roof_h
	var trim := wall.lightened(0.38)
	var fz := -hd            # the lake wall

	# --- piers and skirt ---------------------------------------------------
	# A cottage stands on rock, on posts. The gap under it is a real read at
	# night because the fire throws light INTO it.
	b.box(Vector3(0, 0.14, 0), Vector3(hw * 0.98, 0.14, hd * 0.98), Color(0.16, 0.16, 0.17))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var xs: float = sx
			var zs: float = sz
			_blob(b, Vector3(xs * hw * 0.82, 0.16, zs * hd * 0.78), 0.42, 0.20,
				xs + zs, xs * 2.0 + zs, Color(0.42, 0.41, 0.42), 5)

	# --- walls -------------------------------------------------------------
	var wl := _ring_y(0.26, hw, hd, 0.10)
	var wh := _ring_y(wall_h, hw, hd, 0.10)
	b.loft([wl, wh], [Vector3(0, 0.26, 0), Vector3(0, wall_h, 0)], wall)
	# Board-and-batten: vertical battens down the two long walls. Cheap, and
	# the only scale cue on a fifteen-metre facade.
	var battens := 14
	for i in battens:
		var x := -hw + (2.0 * hw) * (float(i) + 0.5) / float(battens)
		for sz in [-1.0, 1.0]:
			var zs2: float = sz
			b.box(Vector3(x, (wall_h + 0.26) * 0.5, zs2 * (hd + 0.020)),
				Vector3(0.045, (wall_h - 0.26) * 0.5, 0.022), wall.lightened(0.10))
	# Corner boards.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var xs3: float = sx
			var zs3: float = sz
			b.box(Vector3(xs3 * hw, (wall_h + 0.26) * 0.5, zs3 * hd),
				Vector3(0.11, (wall_h - 0.26) * 0.5, 0.11), trim.darkened(0.10))

	# --- gable roof, ridge along X ----------------------------------------
	var thick := 0.16
	var drop := Vector3(0, -thick, 0)
	var bands := [0.0, 0.36, 0.72, 1.0]
	for sz in [-1.0, 1.0]:
		var sgn: float = sz
		for bi in range(bands.size() - 1):
			var t0: float = bands[bi]
			var t1: float = bands[bi + 1]
			var z0: float = sgn * eave_z * (1.0 - t0)
			var z1: float = sgn * eave_z * (1.0 - t1)
			var y0: float = wall_h + roof_h * t0
			var y1: float = wall_h + roof_h * t1
			var shade := roof.lightened(0.05 + float(bi) * 0.11)
			var a := Vector3(-eave_x, y0, z0)
			var c := Vector3(eave_x, y0, z0)
			var f := Vector3(eave_x, y1, z1)
			var g := Vector3(-eave_x, y1, z1)
			b.quad(a, c, f, g, shade, Vector3(0, wall_h * 0.5, 0))
			b.quad(a + drop, c + drop, f + drop, g + drop, roof.darkened(0.38),
				Vector3(0, ridge_y + 4.0, 0))
			# Rake edges.
			b.quad(a, g, g + drop, a + drop, roof.darkened(0.16),
				Vector3(0, wall_h + roof_h * 0.4, 0))
			b.quad(c, f, f + drop, c + drop, roof.darkened(0.16),
				Vector3(0, wall_h + roof_h * 0.4, 0))
			if bi == 0:
				b.quad(a, c, c + drop, a + drop, roof.lightened(0.10), Vector3(0, wall_h, 0))
		# Standing seams down each pitch: this is a steel roof, and the seams
		# are the only thing that catches the moon on it.
		for si in 9:
			var sx2 := -eave_x + (2.0 * eave_x) * (float(si) + 0.5) / 9.0
			_strut(b, Vector3(sx2, wall_h + 0.02, sgn * eave_z),
				Vector3(sx2, ridge_y - 0.01, 0.0), 0.030, roof.lightened(0.26))
	b.box(Vector3(0, ridge_y + 0.05, 0), Vector3(eave_x, 0.07, 0.13), roof.lightened(0.20))
	# Gable ends, in siding, flush with the walls.
	for sx in [-1.0, 1.0]:
		var x: float = sx * hw
		b.tri(Vector3(x, wall_h, -hd), Vector3(x, wall_h, hd), Vector3(x, ridge_y, 0),
			wall.lightened(0.06), Vector3(0, wall_h * 0.6, 0))

	# --- fieldstone chimney on the +X gable --------------------------------
	var cx := hw + 0.34
	for i in 5:
		var y := 0.10 + float(i) * 0.86
		var jitter := 0.05 * _wobble(i, 2, 1.0)
		b.box(Vector3(cx + jitter, y + 0.43, hd * 0.10), Vector3(0.44, 0.44, 0.52),
			Color(0.40, 0.39, 0.40).lightened(0.06 * _wobble(i, 5, 2.0)))
	b.box(Vector3(cx, ridge_y + 0.72, hd * 0.10), Vector3(0.52, 0.10, 0.60), Color(0.30, 0.30, 0.31))

	# --- windows -----------------------------------------------------------
	# Frame on the shell, pane on the glow shell. `on` is deterministic and
	# deliberately uneven: an evenly lit building looks like an office.
	var wins := [
		[-hw * 0.62, wall_h * 0.60, fz, 1.05, 0.62, 0.0, 1.0],
		[-hw * 0.12, wall_h * 0.60, fz, 0.72, 0.58, 0.0, 1.0],
		[ hw * 0.42, wall_h * 0.62, fz, 1.25, 0.66, 0.0, 0.0],
		[ hw * 0.76, wall_h * 0.58, fz, 0.52, 0.48, 0.0, 1.0],
		[-hw * 0.45, wall_h * 0.60, hd, 0.78, 0.55, PI, 1.0],
		[ hw * 0.40, wall_h * 0.58, hd, 0.60, 0.50, PI, 0.0],
		# yaw is +PI/2, not -PI/2. _window() offsets the pane along
		# basis * (0,0,-1), which for -PI/2 comes out as +X — i.e. INTO the
		# building on a -X wall. The first render showed it as a blank pale
		# panel: the frame with its glass buried behind it.
		[-hw - 0.02, wall_h * 0.62, hd * 0.30, 0.66, 0.52, PI * 0.5, 1.0],
		[ 0.0, wall_h + roof_h * 0.36, 0.0, 0.44, 0.36, PI, 1.0],
	]
	for wi in range(wins.size()):
		var row: Array = wins[wi]
		var px: float = row[0]
		var py: float = row[1]
		var pz: float = row[2]
		var whw: float = row[3]
		var whh: float = row[4]
		var yaw: float = row[5]
		var on: float = row[6]
		# The dormer window sits in the roof, so it needs a dormer.
		if wi == 7:
			b.box(Vector3(0, wall_h + roof_h * 0.34, -hd * 0.62),
				Vector3(0.86, 0.52, 0.72), wall.lightened(0.06))
			b.box(Vector3(0, wall_h + roof_h * 0.34 + 0.56, -hd * 0.62),
				Vector3(0.96, 0.09, 0.82), roof.lightened(0.14))
			pz = -hd * 0.62 - 0.74
			yaw = 0.0
		_window(b, e, Vector3(px, py, pz), whw, whh, yaw, trim, glow,
			lit and on > 0.5)

	# --- the screen porch --------------------------------------------------
	# Sixty per cent of the facade, pushed toward the door end rather than
	# centred. That asymmetry is doing real work at night: it leaves half the
	# lake wall as bare siding carrying two big lit windows, so the building
	# reads as PORCH + LIT ROOMS rather than as one long verandah, which is
	# what the first render showed and which made the whole cottage look like
	# a bus shelter.
	var pz0 := fz - porch_d
	var php := hw * 0.44
	var pox := -hw * 0.42
	var porch_y := 0.26
	var porch_h := wall_h * 0.80
	var pmid := (fz + pz0) * 0.5
	# Deck and decking.
	b.box(Vector3(pox, porch_y - 0.055, pmid), Vector3(php, 0.055, porch_d * 0.5),
		wall.darkened(0.28))
	for i in 12:
		var z := pz0 + porch_d * (float(i) + 0.5) / 12.0
		b.box(Vector3(pox, porch_y + 0.005, z), Vector3(php - 0.02, 0.020, porch_d / 26.0),
			Color(0.40, 0.33, 0.25).lightened(0.05 * _wobble(i, 3, 0.0)))
	# Knee wall.
	b.box(Vector3(pox, porch_y + 0.35, pz0), Vector3(php, 0.35, 0.06), wall.lightened(0.08))
	for sx in [-1.0, 1.0]:
		b.box(Vector3(pox + sx * php, porch_y + 0.35, pmid),
			Vector3(0.06, 0.35, porch_d * 0.5), wall.lightened(0.08))
	# Posts.
	for i in 4:
		var x := pox - php + (2.0 * php) * float(i) / 3.0
		b.box(Vector3(x, porch_y + porch_h * 0.5, pz0),
			Vector3(0.075, porch_h * 0.5, 0.075), trim.darkened(0.20))
	for sx in [-1.0, 1.0]:
		b.box(Vector3(pox + sx * php, porch_y + porch_h * 0.5, fz - 0.10),
			Vector3(0.075, porch_h * 0.5, 0.075), trim.darkened(0.20))
	# The screen: a thin dark panel, inset, spanning post to post on three sides.
	b.box(Vector3(pox, porch_y + porch_h * 0.68, pz0 + 0.02),
		Vector3(php - 0.10, porch_h * 0.31, 0.012), Color(0.09, 0.10, 0.10))
	for sx in [-1.0, 1.0]:
		b.box(Vector3(pox + sx * (php - 0.02), porch_y + porch_h * 0.68, pmid),
			Vector3(0.012, porch_h * 0.31, porch_d * 0.48), Color(0.09, 0.10, 0.10))
	# Shed roof over the porch, tucked under the main eave.
	var pr_hi := wall_h * 0.99
	var pr_lo := porch_y + porch_h + 0.14
	var pl := pox - php - 0.22
	var pr := pox + php + 0.22
	b.quad(Vector3(pl, pr_hi, fz + 0.05), Vector3(pr, pr_hi, fz + 0.05),
		Vector3(pr, pr_lo, pz0 - 0.30), Vector3(pl, pr_lo, pz0 - 0.30),
		roof.lightened(0.08), Vector3(0, 0, fz))
	b.quad(Vector3(pl, pr_hi - 0.10, fz + 0.05), Vector3(pr, pr_hi - 0.10, fz + 0.05),
		Vector3(pr, pr_lo - 0.10, pz0 - 0.30), Vector3(pl, pr_lo - 0.10, pz0 - 0.30),
		roof.darkened(0.40), Vector3(0, 20.0, fz))
	b.box(Vector3(pox, pr_lo - 0.05, pz0 - 0.28), Vector3(php + 0.22, 0.055, 0.055),
		trim.darkened(0.10))
	# Screen door, hanging slightly open because it always is.
	b.box(Vector3(pox + php * 0.55, porch_y + porch_h * 0.42, pz0 - 0.06),
		Vector3(0.34, porch_h * 0.42, 0.030), trim.darkened(0.24),
		Basis(Vector3.UP, deg_to_rad(-18.0)))
	# Two steps down off the porch, on the lake side.
	for i in 2:
		b.box(Vector3(pox + php * 0.55, porch_y - 0.06 - float(i) * 0.12, pz0 - 0.42 - float(i) * 0.26),
			Vector3(0.44, 0.055, 0.13), wall.lightened(0.16))

	if not lit:
		return
	# The porch interior glow: a warm plate just above the deck, plus a hanging
	# bulb. The plate is what makes the screen mesh read as a lit volume from
	# outside, which is the whole trick.
	# The porch interior. A floor plate ALONE was not enough: from outside, at
	# an oblique angle, a horizontal plate is edge-on and the porch renders as
	# a black hole under a roof. It needs a vertical surface too — the lit
	# doorway and the wall behind it — which is what actually makes a screened
	# room glow from the outside.
	e.box(Vector3(pox, porch_y + 0.09, pmid),
		Vector3(php - 0.14, 0.012, porch_d * 0.44), glow.darkened(0.18))
	e.box(Vector3(pox - php * 0.35, porch_y + porch_h * 0.42, fz - 0.06),
		Vector3(0.34, porch_h * 0.40, 0.020), glow.darkened(0.06))
	e.box(Vector3(pox + php * 0.45, porch_y + porch_h * 0.36, fz - 0.06),
		Vector3(0.26, porch_h * 0.30, 0.020), glow.darkened(0.34))
	e.box(Vector3(pox + php * 0.10, porch_y + porch_h * 0.80, pmid),
		Vector3(0.080, 0.080, 0.080), glow.lightened(0.30))
		# Porch light beside the door.
	e.box(Vector3(pox + php + 0.30, porch_y + porch_h * 0.72, pz0 - 0.02),
		Vector3(0.060, 0.085, 0.040), Color(1.0, 0.86, 0.55))


## A window: recessed frame and mullions on the shaded shell, the pane itself
## on the glow shell so it renders at full brightness no matter what light
## reaches the wall. An unlit window gets a cold dark pane instead — a cottage
## where every room is on has nobody in it.
static func _window(b: RefCounted, e: RefCounted, pos: Vector3, hw: float, hh: float,
		yaw: float, trim: Color, glow: Color, lit: bool) -> void:
	var basis := Basis(Vector3.UP, yaw)
	var out := basis * Vector3(0, 0, -1)
	b.box(pos, Vector3(hw + 0.085, hh + 0.085, 0.045), trim, basis)
	if lit:
		e.box(pos + out * 0.024, Vector3(hw, hh, 0.030), glow, basis)
	else:
		b.box(pos + out * 0.024, Vector3(hw, hh, 0.030), Color(0.09, 0.11, 0.14), basis)
	# Mullions, on the shaded shell so they read as dark bars across the light.
	b.box(pos + out * 0.045, Vector3(hw + 0.01, 0.024, 0.022), trim.darkened(0.30), basis)
	b.box(pos + out * 0.045, Vector3(0.024, hh + 0.01, 0.022), trim.darkened(0.30), basis)
	# Sill.
	b.box(pos + out * 0.055 - Vector3(0, hh + 0.09, 0),
		Vector3(hw + 0.14, 0.040, 0.070), trim.lightened(0.10), basis)


# ===========================================================================
# 18. BOATHOUSE
# ===========================================================================
#
# Built out over the water on cribs, open to the lake at -Z. The roof is the
# only large flat surface at water level, which makes it the obvious thing to
# land on — so it is deliberately generous and deliberately reachable.

static func _boathouse(b: RefCounted, e: RefCounted, params: Dictionary) -> void:
	var w := _num(params, "w", 6.0)
	var d := _num(params, "d", 8.0)
	var wall_h := _num(params, "wall_h", 2.6)
	var roof_h := _num(params, "roof_h", 1.8)
	var wall := _col(params, "colour", Color(0.22, 0.20, 0.17))
	var roof := _col(params, "trim_colour", Color(0.075, 0.105, 0.100))
	var glow := _col(params, "glow_colour", Color(1.00, 0.80, 0.46))
	var lit := _flag(params, "lit", true)

	var hw := w * 0.5
	var hd := d * 0.5
	var trim := wall.lightened(0.34)

	# Cribs down into the water, at the four corners plus two amidships.
	for sx in [-1.0, 1.0]:
		for i in 3:
			var xs: float = sx
			var z := -hd + d * (float(i) + 0.5) / 3.0
			_strut(b, Vector3(xs * (hw - 0.12), 0.10, z), Vector3(xs * (hw - 0.02), -1.7, z),
				0.11, wall.darkened(0.30))
	# Deck platform.
	b.box(Vector3(0, 0.06, 0), Vector3(hw, 0.09, hd), wall.darkened(0.24))
	# Walkway planking down the +X side.
	for i in 14:
		var z := -hd + d * (float(i) + 0.5) / 14.0
		b.box(Vector3(hw - 0.42, 0.135, z), Vector3(0.40, 0.024, d / 32.0),
			Color(0.46, 0.44, 0.40).lightened(0.05 * _wobble(i, 2, 0.0)))

	# Three walls. -Z is the slip mouth and stays open.
	var t := 0.10
	b.box(Vector3(0, 0.16 + wall_h * 0.5, hd), Vector3(hw, wall_h * 0.5, t), wall)
	for sx in [-1.0, 1.0]:
		b.box(Vector3(sx * hw, 0.16 + wall_h * 0.5, 0), Vector3(t, wall_h * 0.5, hd), wall)
	# Board lines on the visible flanks.
	for i in 9:
		var y := 0.26 + wall_h * (float(i) + 0.5) / 9.0
		for sx2 in [-1.0, 1.0]:
			var xs2: float = sx2
			b.box(Vector3(xs2 * (hw + 0.03), y, 0), Vector3(0.020, 0.020, hd - 0.05),
				wall.lightened(0.12))

	# Header beam over the slip mouth, and the two posts carrying it.
	b.box(Vector3(0, 0.16 + wall_h - 0.22, -hd), Vector3(hw, 0.22, 0.14), trim.darkened(0.15))
	for sx in [-1.0, 1.0]:
		b.box(Vector3(sx * (hw - 0.16), 0.16 + wall_h * 0.5, -hd),
			Vector3(0.14, wall_h * 0.5, 0.14), trim.darkened(0.15))

	# Gable roof, ridge along Z so the gable faces the lake.
	var ridge_y := 0.16 + wall_h + roof_h
	var eave_x := hw * 1.14
	var eave_z := hd * 1.05
	var thick := 0.13
	var drop := Vector3(0, -thick, 0)
	for sx in [-1.0, 1.0]:
		var sgn: float = sx
		for bi in 3:
			var t0 := float(bi) / 3.0
			var t1 := float(bi + 1) / 3.0
			var x0: float = sgn * eave_x * (1.0 - t0)
			var x1: float = sgn * eave_x * (1.0 - t1)
			var y0: float = 0.16 + wall_h + roof_h * t0
			var y1: float = 0.16 + wall_h + roof_h * t1
			var shade := roof.lightened(0.02 + float(bi) * 0.055)
			var a := Vector3(x0, y0, -eave_z)
			var c := Vector3(x1, y1, -eave_z)
			var f := Vector3(x1, y1, eave_z)
			var g := Vector3(x0, y0, eave_z)
			b.quad(a, c, f, g, shade, Vector3(0, wall_h * 0.4, 0))
			b.quad(a + drop, c + drop, f + drop, g + drop, roof.darkened(0.38),
				Vector3(0, ridge_y + 4.0, 0))
			b.quad(a, g, g + drop, a + drop, roof.darkened(0.18), Vector3(0, ridge_y, 0))
			if bi == 0:
				b.quad(a, c, c + drop, a + drop, roof.lightened(0.10),
					Vector3(0, wall_h, 0))
				b.quad(g, f, f + drop, g + drop, roof.lightened(0.10),
					Vector3(0, wall_h, 0))
	b.box(Vector3(0, ridge_y + 0.05, 0), Vector3(0.12, 0.06, eave_z), roof.lightened(0.20))
	# Gable ends.
	for sz in [-1.0, 1.0]:
		var z: float = sz * hd
		b.tri(Vector3(-hw, 0.16 + wall_h, z), Vector3(hw, 0.16 + wall_h, z),
			Vector3(0, ridge_y, z), wall.lightened(0.05), Vector3(0, wall_h * 0.6, 0))

	# The dark slip: a black plate under the roof so the mouth reads as a void
	# with a boat somewhere in it rather than as daylight through the building.
	b.box(Vector3(0, 0.16 + wall_h * 0.55, hd - 0.12),
		Vector3(hw - 0.20, wall_h * 0.42, 0.020), Color(0.04, 0.05, 0.06))

	if not lit:
		return
	# One bulb over the slip mouth, and one small window on the +X flank.
	e.box(Vector3(0, 0.16 + wall_h - 0.42, -hd + 0.10), Vector3(0.075, 0.062, 0.045), glow)
	e.box(Vector3(hw + 0.02, 0.16 + wall_h * 0.62, hd * 0.35),
		Vector3(0.022, 0.22, 0.28), glow.darkened(0.34))
	b.box(Vector3(hw + 0.05, 0.16 + wall_h * 0.62, hd * 0.35),
		Vector3(0.020, 0.030, 0.38), trim.darkened(0.30))


# ===========================================================================
# FALLBACK
# ===========================================================================

## Unknown kind: a chamfered crate. Nothing in the world is ever invisible,
## and a crate is honest about being a placeholder in a way a wrong model
## isn't.
static func _fallback(b: RefCounted, e: RefCounted, params: Dictionary) -> void:
	var col := _col(params, "colour", Color(0.62, 0.58, 0.50))
	var lo := _ring_y(0.0, 0.40, 0.40, 0.06)
	var hi := _ring_y(0.80, 0.40, 0.40, 0.06)
	b.loft([lo, hi], [Vector3.ZERO, Vector3(0, 0.80, 0)], col)
	_cap_axial(b, hi, Vector3(0, 0.82, 0), Vector3.UP, col.lightened(0.10))
	_cap_axial(b, lo, _centroid(lo), Vector3.DOWN, col.darkened(0.25))
