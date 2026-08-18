extends RefCounted
## THE CUT CORN MODEL LIBRARY — leg 6's props, the ones no other zone needs.
##
## Same idiom and the same public API as scripts/world/prop_models.gd and
## scripts/world/prop_models_cottage.gd:
##
##     PropModelsCorn.build(kind, parent, params) -> Node3D
##     PropModelsCorn.has_model(kind) -> bool
##     PropModelsCorn.footprint(kind, params) -> Vector3
##     PropModelsCorn.mesh_for(kind, params) -> ArrayMesh     <- new here
##
## Polygons only. No SphereMesh, no CylinderMesh, no curved primitives. All
## colour lives in VERTEX COLOURS against one white material, so the whole zone
## is one material and a per-face paint decision costs nothing.
##
## ---------------------------------------------------------------------------
## THE ANCHORING CONTRACT — identical to both other libraries
## ---------------------------------------------------------------------------
## Every model here is BASE-ANCHORED: local origin on the ground at the centre
## of the footprint, growing up +Y. BoxShape3D colliders are CENTRED. So a
## model hung under a collider of height h always drops by -h * 0.5.
##
## ---------------------------------------------------------------------------
## -Z IS FORWARD
## ---------------------------------------------------------------------------
## The combine, the grain truck and the dog are all authored nose-at--Z, the
## same as every other directional model in this project. The combine drives
## along Z and its yaw is set to 0 or PI accordingly; if you ever find it
## reversing up the field with its header behind it, the bug is in the ZONE's
## yaw, not in here.
##
## Nothing in this file carries painted text or an asymmetric decal, and that is
## deliberate: on a face at -Z, ascending +X runs right-to-left on screen, so a
## painted brand name on the combine's flank would come out mirrored. (A stop
## sign in this project once shipped reading "POTS".) The grain bin's only
## marking is a horizontal band, which has no handedness.
##
## ---------------------------------------------------------------------------
## mesh_for(): why this library has an extra entry point
## ---------------------------------------------------------------------------
## The corn is a MultiMesh — one draw call for ~1500 stalks — and a MultiMesh
## needs a bare Mesh, not a Node3D with a MeshInstance3D under it. So the two
## instanced models (`corn_stalk`, `corn_stubble`) are also reachable as a raw
## ArrayMesh. `build()` still works on them, which is what the zone uses for the
## handful of hero stalks it places individually.
##
## ---------------------------------------------------------------------------
## TRIANGLE BUDGET — the one number that matters in this file
## ---------------------------------------------------------------------------
## `corn_stalk` is instanced ~2960 times, so every triangle in it costs 2960.
## It is 36 triangles: a 3-sided stem lofted twice (12), five double-sided leaf
## blades (20) and a tassel (4). That is ~107k triangles for the standing corn,
## in ONE draw call, which the GL Compatibility renderer does not notice (it
## does slow a software render down noticeably — use --frames:4).
##
## If it ever has to come down, take it out of the INSTANCE COUNT and not out of
## the leaves. A wider leaf occludes several times more per triangle than
## another whole plant does, and occlusion is the entire job. Do not add an ear
## of corn: at this distance it is four triangles nobody will ever resolve.
##
## ---------------------------------------------------------------------------
## DETERMINISM
## ---------------------------------------------------------------------------
## No randf()/randi() anywhere. The build verification renders and diffs frames,
## so a random number in here is a bug. Every irregularity is a sin() of the
## vertex and ring indices: organic-looking and bit-identical every run.

## Preloaded rather than referenced by class_name: global class registration
## only exists after an editor import pass, so a `class_name` reference breaks
## in a fresh checkout or a headless CI run. A preload const always resolves.
const LPB := preload("res://scripts/goose/lowpoly_builder.gd")


# ---------------------------------------------------------------------------
# Registry
# ---------------------------------------------------------------------------

## Bounding footprint of each model, base-anchored: (width_x, height_y, depth_z).
## MEASURED FROM THE GEOMETRY, not guessed. These are used for two things:
## `size`-driven rescaling, and — much more importantly — as the collider box a
## ChaosProp is given in zone_corn.gd. A footprint that lies by 30 cm is a prop
## that either floats or spawns inside the ground, and a prop that spawns inside
## a collider gets ejected to an absurd coordinate. (This project has done that:
## recycling bins once launched to y = -1120.)
##
## The combine's unloading auger deliberately overhangs the stated width; the
## combine is never `size`-scaled and never given a box collider, so the number
## here describes the machine's body and header, which is what the zone measures
## its hazard volume against.
const FOOTPRINTS := {
	&"corn_stalk": Vector3(1.30, 3.45, 1.30),
	&"corn_stubble": Vector3(0.36, 0.30, 0.36),
	&"combine": Vector3(5.60, 4.30, 7.40),
	&"grain_truck": Vector3(2.50, 3.20, 7.30),
	&"silo": Vector3(8.00, 11.30, 8.00),
	&"round_bale": Vector3(1.90, 1.55, 1.55),
	&"square_bale": Vector3(0.46, 0.41, 0.97),
	&"scarecrow": Vector3(1.70, 2.20, 0.50),
	&"feed_sack": Vector3(0.58, 0.34, 0.82),
	&"pallet": Vector3(1.16, 0.14, 1.00),
	&"kennel": Vector3(1.24, 0.92, 1.46),
	&"farm_dog": Vector3(0.56, 0.85, 1.30),
	&"crow": Vector3(0.24, 0.28, 0.54),
}


## True if [param kind] has a dedicated model here. Unknown kinds still build —
## they get a faceted crate, so nothing in the world is ever invisible — but a
## caller that wants to fall back to another library should test this first.
static func has_model(kind: StringName) -> bool:
	return FOOTPRINTS.has(kind)


## Base-anchored bounding size of [param kind].
static func footprint(kind: StringName, _params := {}) -> Vector3:
	if FOOTPRINTS.has(kind):
		var f: Vector3 = FOOTPRINTS[kind]
		return f
	return Vector3.ONE


# ---------------------------------------------------------------------------
# Materials
# ---------------------------------------------------------------------------

## One white, vertex-colour-driven material for every shaded surface in the
## zone. Its own instance rather than a shared one — the other two libraries
## keep theirs — but identical in construction, so the three look like one world.
##
## Roughness 0.86 rather than the cottage's 0.88: this is the only zone with a
## hard directional key light, and a slightly tighter highlight is what makes
## the grain bin's corrugations and the combine's sheet metal read as metal at
## noon instead of as painted cardboard.
static var _shared_mat: StandardMaterial3D = null

static func shared_material() -> StandardMaterial3D:
	if _shared_mat == null:
		_shared_mat = LPB.make_material(0.86)
		_shared_mat.cull_mode = BaseMaterial3D.CULL_BACK
	return _shared_mat


## The glow material. UNSHADED, exactly as in prop_models_cottage.gd.
##
## A daylight zone barely needs one — but the combine's amber beacon and the
## grain bin's obstruction light are the two things on this map that have to
## read at 60 metres through dust haze, and at noon a lit-from-outside amber
## quad is just a brown quad. Unshaded means the face renders at exactly its
## vertex colour whatever the sun is doing.
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
##   trim_colour   Color    secondary (frame, header, twine, roof)
##   glow_colour   Color    override the emissive colour
##   variant       float    deterministic shape seed
static func build(kind: StringName, parent: Node3D, params := {}) -> Node3D:
	var model := Node3D.new()
	model.name = "Model"
	parent.add_child(model)

	var b: RefCounted = LPB.new()
	var e: RefCounted = LPB.new()
	_dispatch(kind, b, e, params)

	model.set_meta("tri_count", b.tri_count + e.tri_count)
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


## The raw shaded mesh for [param kind], for MultiMeshInstance3D.
##
## Returns only the shell — a MultiMesh has exactly one mesh and one material,
## so a model with a glow shell cannot be instanced this way. Neither instanced
## model has one, and neither should acquire one: 1500 unshaded quads is 1500
## surfaces the depth pre-pass cannot help with.
static func mesh_for(kind: StringName, params := {}) -> ArrayMesh:
	var b: RefCounted = LPB.new()
	var e: RefCounted = LPB.new()
	_dispatch(kind, b, e, params)
	return b.commit()


static func _dispatch(kind: StringName, b: RefCounted, e: RefCounted, params: Dictionary) -> void:
	match kind:
		&"corn_stalk":
			_corn_stalk(b, e, params)
		&"corn_stubble":
			_corn_stubble(b, e, params)
		&"combine":
			_combine(b, e, params)
		&"grain_truck":
			_grain_truck(b, e, params)
		&"silo":
			_silo(b, e, params)
		&"round_bale":
			_round_bale(b, e, params)
		&"square_bale":
			_square_bale(b, e, params)
		&"scarecrow":
			_scarecrow(b, e, params)
		&"feed_sack":
			_feed_sack(b, e, params)
		&"pallet":
			_pallet(b, e, params)
		&"kennel":
			_kennel(b, e, params)
		&"farm_dog":
			_farm_dog(b, e, params)
		&"crow":
			_crow(b, e, params)
		_:
			_fallback(b, e, params)


# ---------------------------------------------------------------------------
# Typed parameter access.
#
# Dictionary lookups are Variant, so `var x := params.get(...)` is a parse
# error ("Cannot infer the type of x"). Funnelling every read through these
# three helpers keeps that mistake out of the thirteen build functions below.
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
# Deliberately re-implemented here rather than reached for across a preload into
# one of the other two libraries: those are underscore-private statics on files
# this one has no other reason to depend on, and duplicating fifty lines is
# cheaper than a coupling nobody expects. prop_models_cottage.gd says the same
# thing about prop_models.gd for the same reason.
# ---------------------------------------------------------------------------

## Horizontal cross-section at height [param y]: a chamfered rectangle in XZ.
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
## wins on every face. Documented at length in both other libraries because it
## cost each of those art passes two render rounds.
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


## A flat ring-to-ring band perpendicular to [param axis_dir] — a bin eave, a
## tyre sidewall, a truck box lip. Same winding hazard as _cap_axial, same cure.
static func _annulus(b: RefCounted, outer: PackedVector3Array, inner: PackedVector3Array,
		axis_dir: Vector3, col: Color) -> void:
	var n: int = mini(outer.size(), inner.size())
	var inside := _far_ref(outer, axis_dir)
	for j in n:
		var k := (j + 1) % n
		b.quad(outer[j], outer[k], inner[k], inner[j], col, inside)


## Loft a chain of rings with the faces pointing INWARD, toward the axis. A
## hollow thing — a truck's grain box, a kennel, a bin you look down into — is
## looked INTO, and with backface culling on, an outward-facing far wall is
## simply not there.
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


## A square-section strut between two arbitrary points. Boxes can only be axis
## aligned or basis-rotated about one axis; anything running diagonally in two
## directions at once needs a real lofted tube. 8 triangles.
static func _strut(b: RefCounted, a: Vector3, c: Vector3, r: float, col: Color) -> void:
	var d := c - a
	if d.length_squared() < 1e-8:
		return
	var dir := d.normalized()
	var up := Vector3.UP if absf(dir.y) < 0.92 else Vector3.FORWARD
	var r0 := LPB.ring(a, dir, up, r, r, 4, PI * 0.25)
	var r1 := LPB.ring(c, dir, up, r, r, 4, PI * 0.25)
	b.loft([r0, r1], [a, c], col)


## A cylinder lying along an arbitrary axis, capped at both ends. The wheels,
## the reel, the bale and the bin all want this.
static func _tube(b: RefCounted, a: Vector3, c: Vector3, r: float, sides: int,
		col: Color, cap_col: Color) -> void:
	var d := c - a
	if d.length_squared() < 1e-8:
		return
	var dir := d.normalized()
	var up := Vector3.UP if absf(dir.y) < 0.92 else Vector3.FORWARD
	var r0 := LPB.ring(a, dir, up, r, r, sides)
	var r1 := LPB.ring(c, dir, up, r, r, sides)
	b.loft([r0, r1], [a, c], col)
	_cap_axial(b, r1, c, dir, cap_col)
	_cap_axial(b, r0, a, -dir, cap_col.darkened(0.18))


## A DOUBLE-SIDED quad. Emitted twice at the same four corners with opposite
## winding, so it is visible from both faces.
##
## THIS IS THE WHOLE REASON THE CORN WORKS. A corn leaf is a flat blade, and a
## single quad against a CULL_BACK material is a blade that vanishes the moment
## you walk round it — which for a goose standing UNDER a two-metre canopy is
## most of the time. Two coplanar faces with opposite winding do not z-fight,
## because from any given viewpoint exactly one of them is front-facing.
##
## The back face is darkened: a corn leaf's underside genuinely is paler and
## flatter, and more usefully it stops a leaf that happens to be edge-on to the
## sun from flickering between two identical values as the camera swings.
static func _blade(b: RefCounted, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3,
		col: Color) -> void:
	var cen := (p0 + p1 + p2 + p3) * 0.25
	var n := (p1 - p0).cross(p3 - p0)
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	b.quad(p0, p1, p2, p3, col, cen - n)
	b.quad(p0, p1, p2, p3, col.darkened(0.16), cen + n)


## Deterministic pseudo-noise in roughly [-1, 1]. Stands in for randf() so the
## lumpy things stay bit-identical between runs.
static func _wobble(a: int, c: int, seed_v: float) -> float:
	return sin(float(a) * 2.399 + float(c) * 1.117 + seed_v * 3.77) \
		* cos(float(a) * 0.813 - float(c) * 1.937 + seed_v * 1.31)


# ===========================================================================
# 1. CORN STALK — the zone's whole identity, at 32 triangles
# ===========================================================================
#
# Harvest-ready field corn in eastern North Carolina in October is DEAD. It is
# not the green stuff on a seed-catalogue cover; it is dry, tan, brittle,
# rustling, and the leaves hang. That matters more than any other decision in
# this file, because a green corn field on a red clay ground reads as a hedge
# maze and a tan one reads as harvest.
#
# Geometry, and why each piece is here:
#   * A 3-SIDED stem. Four sides costs 50% more and the difference is invisible
#     at the one distance this is ever seen from, which is inside a crowd of
#     1500 of them.
#   * FOUR leaves, alternating sides, drooping. Two would not close the wall;
#     six would not close it any better and costs 1500 x 8 triangles.
#   * A tassel, which is the thing that makes the TOP of the wall ragged. A
#     field of flat-topped stalks reads as a fence.
#
# The stalk leans. `variant` rotates the leaf phase AND tips the whole plant by
# up to 7 degrees, which is what stops 1500 identical verticals reading as a
# barcode. The zone passes a per-instance seed.

static func _corn_stalk(b: RefCounted, e: RefCounted, params: Dictionary) -> void:
	var stalk := _col(params, "colour", Color(0.60, 0.52, 0.30))
	var leaf := _col(params, "trim_colour", Color(0.66, 0.58, 0.33))
	var seed_v := _num(params, "variant", 0.0)

	# 3.10 m, not the 2.10 the first pass used. The zone drives this — see
	# zone_corn.gd::CORN_H for the render that forced it — and the leaf spread
	# below is a FRACTION of h, so raising it keeps the lowest leaf at roughly
	# goose eye height automatically.
	var h := 3.10
	var lean := Vector3(0.10 * _wobble(1, 0, seed_v), 0.0, 0.09 * _wobble(2, 0, seed_v))

	# ── the stem ────────────────────────────────────────────────────────
	# Three rings, so it tapers and bends rather than being a pole. 12 tris.
	# 6.5 cm at the base rather than the first pass's 5.2: at 2960 instances the
	# stems ARE the vertical texture of the wall, and thin ones read as wire.
	var a0 := Vector3.ZERO
	var a1 := lean * 0.45 + Vector3(0, h * 0.52, 0)
	var a2 := lean + Vector3(0, h * 0.92, 0)
	var r0 := LPB.ring(a0, Vector3.UP, Vector3.FORWARD, 0.065, 0.065, 3, seed_v)
	var r1 := LPB.ring(a1, Vector3.UP, Vector3.FORWARD, 0.050, 0.050, 3, seed_v)
	var r2 := LPB.ring(a2, Vector3.UP, Vector3.FORWARD, 0.030, 0.030, 3, seed_v)
	b.loft([r0, r1, r2], [a0, a1, a2], stalk)

	# ── the leaves ──────────────────────────────────────────────────────
	# Each is one double-sided blade: it leaves the stem, arches out, and the tip
	# falls below the point it left from. That droop is the single cue that says
	# "dry" — a leaf held out straight reads as a healthy plant.
	#
	# FIVE, STARTING LOW, AND HALF AS WIDE AGAIN AS THE FIRST PASS. This is the
	# single change that turned the standing corn from a scatter of weeds into a
	# wall you cannot see through, and it is much better value than more plants:
	# one extra leaf is 4 triangles and occludes about as much as a whole extra
	# stalk at 36. The lowest one is at 0.38 m, which is roughly a goose's eye
	# height — if the leaves start above that, the bird can see out along the
	# ground under the canopy and the cover does not work at the one height that
	# matters.
	for i in 5:
		var t := 0.18 + float(i) * 0.165
		var base := lean * t + Vector3(0, h * t, 0)
		var ang := seed_v * 1.7 + float(i) * 2.51
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		var span := 0.62 + 0.08 * _wobble(i, 1, seed_v)
		var rise := 0.20 + 0.06 * _wobble(i, 2, seed_v)
		var droop := -0.42 - 0.12 * _wobble(i, 3, seed_v)
		var side := Vector3(-dir.z, 0.0, dir.x) * 0.075
		_blade(b,
			base - side,
			base + side,
			base + dir * span * 0.60 + Vector3(0, rise, 0) + side * 0.70,
			base + dir * span + Vector3(0, rise + droop, 0),
			leaf.lightened(0.05 * _wobble(i, 4, seed_v)))

	# ── the tassel ──────────────────────────────────────────────────────
	# One blade standing almost straight up out of the top, splayed. It is what
	# gives the wall a ragged upper edge from the air.
	var tip := a2 + Vector3(0.05 * _wobble(5, 1, seed_v), 0.30,
		0.05 * _wobble(6, 1, seed_v))
	_blade(b, a2 + Vector3(-0.03, 0, 0), a2 + Vector3(0.03, 0, 0),
		tip + Vector3(0.07, 0.10, 0.03), tip + Vector3(-0.09, 0.14, -0.04),
		stalk.darkened(0.12))


# ===========================================================================
# 2. CORN STUBBLE — what the combine leaves behind
# ===========================================================================
#
# Twelve triangles, instanced across the cut side. Two things it has to do:
#   1. Be sharp and pale, so the cut ground reads as SHORN rather than as mown
#      grass. Stubble is the colour of straw and it catches the noon sun on the
#      cut ends, which is why the cap colour is lifted so hard.
#   2. Line up in rows. The zone spaces these on exactly the same grid as the
#      standing corn, so from the air the harvested half is corduroy and the
#      relationship between the two halves is legible at a glance. That
#      alignment is done at the zone, not here — but if you change the model's
#      footprint, check it still reads.

static func _corn_stubble(b: RefCounted, e: RefCounted, params: Dictionary) -> void:
	var straw := _col(params, "colour", Color(0.76, 0.68, 0.44))
	var seed_v := _num(params, "variant", 0.0)

	for i in 2:
		var ang := seed_v * 2.1 + float(i) * 2.6
		var lean := Vector3(cos(ang), 0.0, sin(ang)) * 0.055
		var h := 0.20 + 0.07 * absf(_wobble(i, 1, seed_v))
		var w := 0.032
		_blade(b,
			Vector3(-w, 0.0, 0.0), Vector3(w, 0.0, 0.0),
			Vector3(w, h, 0.0) + lean, Vector3(-w, h, 0.0) + lean,
			straw)
	# One shattered leaf lying flat, which is most of what covers the ground
	# behind a combine.
	var la := seed_v * 3.3
	var d := Vector3(cos(la), 0.0, sin(la))
	var s := Vector3(-d.z, 0.0, d.x) * 0.055
	_blade(b, -d * 0.16 - s, -d * 0.16 + s, d * 0.17 + s * 0.7, d * 0.17 - s * 0.7,
		straw.darkened(0.14))


# ===========================================================================
# 3. THE COMBINE — the thing that makes this zone the thing it is
# ===========================================================================
#
# A class-7 rotary combine, nose (header) at -Z, drawn at roughly 0.8 scale so
# it is enormous next to a goose without being enormous next to the field.
#
# The read, in priority order, from a goose's eye height at forty metres:
#   1. THE HEADER. A five-metre wide bar of teeth at knee height with a reel
#      turning above it. Everything else on the machine could be a shed; the
#      header is what says "this will kill you".
#   2. THE SILHOUETTE BREAK. Cab glass high and forward, grain tank behind, and
#      the unloading auger sticking out sideways over nothing. A combine that
#      is one box reads as a bus.
#   3. THE BEACON. An amber flash on the cab roof, on the GLOW shell so it is a
#      colour and not a lit surface. It is how you track the machine when it is
#      behind the standing corn — which, given that the corn is cover for it
#      too, is the difference between the zone being tense and being unfair.
#
# The reel is a separate node in the ZONE (it spins), so what is authored here
# is the reel's bats in a fixed position; see zone_corn.gd::_combine().

static func _combine(b: RefCounted, e: RefCounted, params: Dictionary) -> void:
	var body := _col(params, "colour", Color(0.66, 0.17, 0.13))
	var trim := _col(params, "trim_colour", Color(0.86, 0.80, 0.30))
	var glow := _col(params, "glow_colour", Color(1.00, 0.62, 0.10))
	var metal := Color(0.44, 0.44, 0.46)
	var dark := Color(0.13, 0.13, 0.15)

	# ── chassis ─────────────────────────────────────────────────────────
	# Base at y = 0; the machine's belly is at 1.05, which is head height on a
	# goose. Standing under a combine is legal and extremely stupid.
	var c0 := _ring_y(1.05, 1.55, 2.90, 0.30)
	var c1 := _ring_y(2.55, 1.62, 2.95, 0.34)
	var c2 := _ring_y(3.05, 1.30, 2.40, 0.30)
	b.loft([c0, c1, c2], [Vector3(0, 1.05, 0), Vector3(0, 2.55, 0), Vector3(0, 3.05, 0)],
		body)
	_cap_axial(b, c2, Vector3(0, 3.12, 0.2), Vector3.UP, body.lightened(0.10))
	_cap_axial(b, c0, Vector3(0, 1.00, 0), Vector3.DOWN, dark)

	# ── grain tank, sitting on the back half ────────────────────────────
	var t0 := _ring_y(3.05, 1.32, 1.55, 0.24)
	var t1 := _ring_y(3.70, 1.55, 1.70, 0.26)
	var tank_c := Vector3(0, 3.05, 1.15)
	var t0o := PackedVector3Array()
	var t1o := PackedVector3Array()
	for v in t0:
		t0o.append(v + Vector3(0, 0, 1.15))
	for v in t1:
		t1o.append(v + Vector3(0, 0, 1.15))
	b.loft([t0o, t1o], [tank_c, tank_c + Vector3(0, 0.65, 0)], trim)
	_cap_axial(b, t1o, tank_c + Vector3(0, 0.70, 0), Vector3.UP, trim.lightened(0.06))

	# ── cab, forward and high, glass on three sides ─────────────────────
	var k0 := _ring_y(3.05, 0.92, 1.05, 0.18)
	var k1 := _ring_y(3.88, 0.86, 0.98, 0.18)
	var kc := Vector3(0, 3.05, -1.35)
	var k0o := PackedVector3Array()
	var k1o := PackedVector3Array()
	for v in k0:
		k0o.append(v + Vector3(0, 0, -1.35))
	for v in k1:
		k1o.append(v + Vector3(0, 0, -1.35))
	b.loft([k0o, k1o], [kc, kc + Vector3(0, 0.83, 0)], Color(0.20, 0.28, 0.34))
	_cap_axial(b, k1o, kc + Vector3(0, 0.88, 0), Vector3.UP, body.darkened(0.10))

	# ── the header ──────────────────────────────────────────────────────
	# 5.6 m wide, hung off the front on two arms, its cutter bar at 0.42 — which
	# is below the top of a standing goose. The teeth are eleven little wedges
	# and they are the only aggressive silhouette on the machine.
	var hw := 2.80
	var hz := -3.55
	b.box(Vector3(0, 0.78, hz), Vector3(hw, 0.34, 0.42), trim)
	b.box(Vector3(0, 0.42, hz - 0.34), Vector3(hw, 0.10, 0.14), metal.lightened(0.16))
	for i in 11:
		var x := -hw + (2.0 * hw) * (float(i) + 0.5) / 11.0
		b.box(Vector3(x, 0.42, hz - 0.52), Vector3(0.10, 0.055, 0.16),
			metal.lightened(0.30))
	# Arms back to the chassis.
	for sx in [-1.0, 1.0]:
		var xs: float = sx
		_strut(b, Vector3(xs * 1.25, 1.10, -2.60), Vector3(xs * 1.05, 0.90, hz + 0.30),
			0.13, body.darkened(0.14))
	# Dividers at each end of the header — the pointed snouts that part the rows.
	for sx2 in [-1.0, 1.0]:
		var xs2: float = sx2
		b.box(Vector3(xs2 * (hw - 0.10), 0.72, hz - 0.55), Vector3(0.12, 0.20, 0.60),
			trim.darkened(0.10))

	# ── the reel ────────────────────────────────────────────────────────
	# Six bats on a shaft above the cutter bar. Authored fixed; the zone spins
	# the whole model's reel node. Kept as flat bats rather than tubes because
	# a bat is a paddle in real life and because six tubes is 48 triangles.
	_tube(b, Vector3(-hw + 0.1, 1.42, hz - 0.30), Vector3(hw - 0.1, 1.42, hz - 0.30),
		0.09, 5, metal, metal.lightened(0.10))
	for i in 6:
		var a := TAU * float(i) / 6.0
		var rr := 0.52
		var p := Vector3(0, 1.42 + sin(a) * rr, hz - 0.30 + cos(a) * rr)
		_blade(b,
			Vector3(-hw + 0.12, p.y, p.z), Vector3(hw - 0.12, p.y, p.z),
			Vector3(hw - 0.12, p.y - sin(a) * 0.16, p.z - cos(a) * 0.16),
			Vector3(-hw + 0.12, p.y - sin(a) * 0.16, p.z - cos(a) * 0.16),
			metal.lightened(0.06))

	# ── the unloading auger, out to the left over nothing ───────────────
	_tube(b, Vector3(-1.0, 3.55, 1.30), Vector3(-4.30, 3.30, 0.60), 0.20, 5,
		trim.darkened(0.08), metal)
	b.box(Vector3(-4.30, 3.05, 0.60), Vector3(0.24, 0.22, 0.24), dark)

	# ── wheels ──────────────────────────────────────────────────────────
	# Front pair enormous, rear pair small and steered. That size difference is
	# a combine's most recognisable feature after the header.
	for sx3 in [-1.0, 1.0]:
		var xs3: float = sx3
		_tube(b, Vector3(xs3 * 1.42, 1.00, -1.55), Vector3(xs3 * 1.86, 1.00, -1.55),
			1.00, 9, dark, dark.lightened(0.16))
		_tube(b, Vector3(xs3 * 1.20, 0.58, 2.55), Vector3(xs3 * 1.48, 0.58, 2.55),
			0.58, 8, dark, dark.lightened(0.16))

	# ── the beacon ──────────────────────────────────────────────────────
	b.box(Vector3(0.62, 4.00, -1.75), Vector3(0.05, 0.11, 0.05), dark)
	e.box(Vector3(0.62, 4.16, -1.75), Vector3(0.11, 0.10, 0.11), glow)
	# And a second one low on the header frame, because the beacon on the roof
	# is invisible when the machine is coming at you over a header.
	e.box(Vector3(-hw + 0.35, 1.05, hz + 0.20), Vector3(0.10, 0.07, 0.06), glow)
	e.box(Vector3(hw - 0.35, 1.05, hz + 0.20), Vector3(0.10, 0.07, 0.06), glow)


# ===========================================================================
# 4. GRAIN TRUCK
# ===========================================================================
#
# A tandem-axle farm truck with a high-sided grain box, cab at -Z. The box is
# lofted INWARD so you can look down into it and find grain (and, in this zone,
# something else) rather than finding the outside of the far wall.

static func _grain_truck(b: RefCounted, e: RefCounted, params: Dictionary) -> void:
	var paint := _col(params, "colour", Color(0.72, 0.70, 0.66))
	var boxc := _col(params, "trim_colour", Color(0.34, 0.44, 0.36))
	var dark := Color(0.12, 0.12, 0.14)
	var glass := Color(0.24, 0.30, 0.34)
	var grain := Color(0.82, 0.70, 0.38)

	# ── frame ───────────────────────────────────────────────────────────
	b.box(Vector3(0, 0.86, 0.25), Vector3(0.95, 0.14, 3.55), dark.lightened(0.10))

	# ── cab ─────────────────────────────────────────────────────────────
	var cb0 := _ring_y(1.00, 1.20, 0.95, 0.16)
	var cb1 := _ring_y(2.55, 1.14, 0.90, 0.20)
	var cc := Vector3(0, 1.00, -2.55)
	var cb0o := PackedVector3Array()
	var cb1o := PackedVector3Array()
	for v in cb0:
		cb0o.append(v + Vector3(0, 0, -2.55))
	for v in cb1:
		cb1o.append(v + Vector3(0, 0, -2.55))
	b.loft([cb0o, cb1o], [cc, cc + Vector3(0, 1.55, 0)], paint)
	_cap_axial(b, cb1o, cc + Vector3(0, 1.60, 0), Vector3.UP, paint.darkened(0.10))
	# Windscreen and side glass, as flat panels sunk 3 cm into the shell.
	_blade(b, Vector3(-0.95, 1.62, -3.47), Vector3(0.95, 1.62, -3.47),
		Vector3(0.95, 2.46, -3.34), Vector3(-0.95, 2.46, -3.34), glass)
	for sx in [-1.0, 1.0]:
		var xs: float = sx
		_blade(b, Vector3(xs * 1.17, 1.66, -3.00), Vector3(xs * 1.17, 1.66, -2.20),
			Vector3(xs * 1.17, 2.42, -2.20), Vector3(xs * 1.17, 2.42, -3.00), glass)
	# Bumper and grille.
	b.box(Vector3(0, 0.86, -3.62), Vector3(1.16, 0.16, 0.10), dark.lightened(0.24))
	b.box(Vector3(0, 1.30, -3.60), Vector3(0.90, 0.36, 0.06), dark)

	# ── the grain box ───────────────────────────────────────────────────
	# Outer shell, then an inward-lofted liner, then a grain surface partway
	# down. Three steps rather than one so it is a container, not a lid.
	var bz := 1.05
	var bo0 := _ring_y(1.00, 1.24, 2.35, 0.10)
	var bo1 := _ring_y(3.10, 1.24, 2.35, 0.10)
	var bo0o := PackedVector3Array()
	var bo1o := PackedVector3Array()
	for v in bo0:
		bo0o.append(v + Vector3(0, 0, bz))
	for v in bo1:
		bo1o.append(v + Vector3(0, 0, bz))
	b.loft([bo0o, bo1o], [Vector3(0, 1.0, bz), Vector3(0, 3.1, bz)], boxc)
	var bi0 := _ring_y(1.10, 1.12, 2.23, 0.09)
	var bi1 := _ring_y(3.08, 1.12, 2.23, 0.09)
	var bi0o := PackedVector3Array()
	var bi1o := PackedVector3Array()
	for v in bi0:
		bi0o.append(v + Vector3(0, 0, bz))
	for v in bi1:
		bi1o.append(v + Vector3(0, 0, bz))
	_loft_inward(b, [bi0o, bi1o], [Vector3(0, 1.1, bz), Vector3(0, 3.08, bz)],
		boxc.darkened(0.28))
	_annulus(b, bo1o, bi1o, Vector3.UP, boxc.lightened(0.12))
	# The grain itself, a flat pale surface two-thirds up. Half a load.
	var g := _ring_y(2.42, 1.10, 2.21, 0.09)
	var go := PackedVector3Array()
	for v in g:
		go.append(v + Vector3(0, 0, bz))
	_cap_axial(b, go, Vector3(0, 2.50, bz), Vector3.UP, grain)

	# ── wheels: one steer axle, one tandem pair ─────────────────────────
	for sx2 in [-1.0, 1.0]:
		var xs2: float = sx2
		_tube(b, Vector3(xs2 * 0.92, 0.62, -2.60), Vector3(xs2 * 1.14, 0.62, -2.60),
			0.62, 8, dark, dark.lightened(0.18))
		for zz in [1.05, 2.20]:
			var z2: float = zz
			_tube(b, Vector3(xs2 * 0.92, 0.62, z2), Vector3(xs2 * 1.18, 0.62, z2),
				0.62, 8, dark, dark.lightened(0.18))

	# ── the step, which is where the thermos lives ──────────────────────
	b.box(Vector3(-1.22, 0.62, -2.05), Vector3(0.10, 0.04, 0.28), dark.lightened(0.30))


# ===========================================================================
# 5. THE GRAIN BIN — "the silo survives. It is just in North Carolina now."
# ===========================================================================
#
# NOT a concrete tower silo. Those are a northern dairy thing; a corn farm in
# Sampson County stores shelled corn in a CORRUGATED STEEL BIN — a squat
# galvanised drum with a shallow conical roof, a stiffener rib every metre or
# so, and a ladder up one side. That distinction is the difference between the
# zone reading as North Carolina and reading as Wisconsin.
#
# The corrugation is eleven stacked rings alternately inset by 3 cm. It is
# eleven rings instead of one loft for exactly one reason: at noon, with a hard
# key light, the horizontal shadow lines those steps throw are the ONLY thing
# that gives an eleven-metre grey drum any scale at all. A smooth cylinder of
# this size renders as a flat grey shape with no size cue whatsoever.
#
# The roof is walkable in the zone (a hidden collider does that job); the eave
# ring here is where its edge is, at y = 8.40.

static func _silo(b: RefCounted, e: RefCounted, params: Dictionary) -> void:
	var steel := _col(params, "colour", Color(0.70, 0.71, 0.72))
	var roofc := _col(params, "trim_colour", Color(0.60, 0.62, 0.64))
	var glow := _col(params, "glow_colour", Color(1.00, 0.34, 0.24))
	var dark := Color(0.24, 0.24, 0.26)

	var sides := 12
	var r := 3.55
	var eave := 8.40

	# ── the concrete pad ────────────────────────────────────────────────
	var pad0 := LPB.ring(Vector3(0, 0.0, 0), Vector3.UP, Vector3.FORWARD, r + 0.45,
		r + 0.45, sides)
	var pad1 := LPB.ring(Vector3(0, 0.28, 0), Vector3.UP, Vector3.FORWARD, r + 0.45,
		r + 0.45, sides)
	b.loft([pad0, pad1], [Vector3.ZERO, Vector3(0, 0.28, 0)], Color(0.68, 0.64, 0.58))
	_cap_axial(b, pad1, Vector3(0, 0.28, 0), Vector3.UP, Color(0.72, 0.68, 0.62))

	# ── the corrugated wall ─────────────────────────────────────────────
	var rings: Array = []
	var spine: Array = []
	var steps := 11
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var y := 0.28 + (eave - 0.28) * t
		# Alternating radius: the rib. 11 cm, not the 5.5 the first pass used.
		# The sun in this zone is 74 degrees up, so a horizontal rib on a
		# vertical wall catches almost no shadow at all — the rib has to earn
		# its read from the SILHOUETTE instead, and at 5.5 cm the edge of an
		# eleven-metre drum was a straight line.
		var rr: float = r if (i % 2 == 0) else r - 0.110
		rings.append(LPB.ring(Vector3(0, y, 0), Vector3.UP, Vector3.FORWARD, rr, rr, sides))
		spine.append(Vector3(0, y, 0))
	# Two-tone: the lower third is dirtier. Dust and spilled grain live at the
	# bottom of every bin ever built.
	for i in range(rings.size() - 1):
		var t2 := float(i) / float(rings.size() - 1)
		var band := steel.darkened(0.16 * (1.0 - t2) * (1.0 - t2))
		# Per-course brightness alternation on top of that gradient. With no
		# shadow to work with (see the rib note above) this is the only thing
		# that says "stacked sheets" rather than "one rolled tube".
		band = band.lightened(0.05) if (i % 2 == 0) else band.darkened(0.05)
		b.loft([rings[i], rings[i + 1]], [spine[i], spine[i + 1]], band)

	# ── the eave and the conical roof ───────────────────────────────────
	var top: PackedVector3Array = rings[rings.size() - 1]
	var apex := Vector3(0, eave + 2.40, 0)
	b.cap(top, apex, _far_ref(top, Vector3.UP), roofc)
	# Roof seams, so the cone is faceted metal rather than a paper hat.
	for i in sides:
		var a := TAU * float(i) / float(sides)
		# Darker than the roof, not lighter. The first pass lightened these and
		# the whole cone went to a single blown-out white shape; a seam is a
		# shadow line, and on a surface facing straight up at the sun it is the
		# only shadow available.
		_strut(b, Vector3(cos(a) * (r - 0.05), eave + 0.02, sin(a) * (r - 0.05)),
			apex + Vector3(0, -0.10, 0), 0.035, roofc.darkened(0.22))
	# The fill cap and its little collar at the peak.
	_tube(b, Vector3(0, eave + 2.34, 0), Vector3(0, eave + 2.72, 0), 0.34, 6,
		roofc.darkened(0.10), roofc.lightened(0.14))

	# ── the ladder, up the -Z face ──────────────────────────────────────
	# On -Z because that is the face the farmyard looks at and because a ladder
	# you cannot see is a ladder that did not need modelling.
	var lz := -(r + 0.06)
	for sx in [-1.0, 1.0]:
		var xs: float = sx
		_strut(b, Vector3(xs * 0.26, 0.30, lz), Vector3(xs * 0.26, eave + 0.30, lz),
			0.035, dark.lightened(0.24))
	for i in 15:
		var y2 := 0.55 + float(i) * 0.55
		if y2 > eave + 0.20:
			break
		b.box(Vector3(0, y2, lz), Vector3(0.26, 0.022, 0.022), dark.lightened(0.34))

	# ── the discharge chute and the spilled heap ────────────────────────
	# The heap is the point. Waste grain on the ground under a bin is where the
	# geese actually are, and it is where this zone's ethanol source sits.
	b.box(Vector3(0, 0.70, -(r + 0.30)), Vector3(0.42, 0.42, 0.30),
		steel.darkened(0.22))
	b.box(Vector3(0, 0.30, -(r + 0.62)), Vector3(0.30, 0.30, 0.34),
		steel.darkened(0.30))

	# ── the obstruction light ───────────────────────────────────────────
	e.box(Vector3(0, eave + 2.82, 0), Vector3(0.10, 0.10, 0.10), glow)


# ===========================================================================
# 6. ROUND BALE
# ===========================================================================
#
# 5x4 net-wrapped round bale lying on its side, axis along X, so it rolls the
# way a round bale rolls: sideways, forever, into things. Which is what the
# zone wants from it.

static func _round_bale(b: RefCounted, e: RefCounted, params: Dictionary) -> void:
	var hay := _col(params, "colour", Color(0.74, 0.66, 0.42))
	var seed_v := _num(params, "variant", 0.0)
	var r := 0.775
	_tube(b, Vector3(-0.95, r, 0), Vector3(0.95, r, 0), r, 10, hay,
		hay.lightened(0.10))
	# Net wrap: four bands round the barrel, slightly proud, in a paler tone.
	for i in 4:
		var x := -0.72 + float(i) * 0.48
		var rr := r + 0.012
		var b0 := LPB.ring(Vector3(x - 0.03, r, 0), Vector3.RIGHT, Vector3.UP, rr, rr, 10)
		var b1 := LPB.ring(Vector3(x + 0.03, r, 0), Vector3.RIGHT, Vector3.UP, rr, rr, 10)
		b.loft([b0, b1], [Vector3(x - 0.03, r, 0), Vector3(x + 0.03, r, 0)],
			hay.lightened(0.20 + 0.05 * _wobble(i, 1, seed_v)))


# ===========================================================================
# 7. SQUARE BALE — the light one, the one that goes flying
# ===========================================================================

static func _square_bale(b: RefCounted, e: RefCounted, params: Dictionary) -> void:
	var hay := _col(params, "colour", Color(0.80, 0.72, 0.46))
	var seed_v := _num(params, "variant", 0.0)
	var lo := _ring_y(0.0, 0.23, 0.48, 0.04)
	var hi := _ring_y(0.40, 0.23, 0.48, 0.04)
	b.loft([lo, hi], [Vector3.ZERO, Vector3(0, 0.40, 0)], hay)
	_cap_axial(b, hi, Vector3(0, 0.41, 0), Vector3.UP, hay.lightened(0.12))
	_cap_axial(b, lo, Vector3(0, -0.01, 0), Vector3.DOWN, hay.darkened(0.26))
	# Two strings of orange baler twine over the top and down the ends.
	for i in 2:
		var x := -0.11 + float(i) * 0.22 + 0.01 * _wobble(i, 2, seed_v)
		b.box(Vector3(x, 0.405, 0.0), Vector3(0.014, 0.010, 0.48),
			Color(0.86, 0.46, 0.14))
		for sz in [-1.0, 1.0]:
			var zs: float = sz
			b.box(Vector3(x, 0.20, zs * 0.485), Vector3(0.014, 0.20, 0.010),
				Color(0.86, 0.46, 0.14))


# ===========================================================================
# 8. SCARECROW
# ===========================================================================
#
# A cross of two posts, a checked shirt stuffed with straw, a sack head and a
# hat. Faces -Z like everything else, which in this zone means it is looking
# down the rows at the standing corn and has its back to the goose. That is the
# right way round for the joke.
#
# Its arms are DOUBLE-SIDED blades rather than boxes: the shirt is meant to be
# a rag, and a rag with thickness is a plank.

static func _scarecrow(b: RefCounted, e: RefCounted, params: Dictionary) -> void:
	var shirt := _col(params, "colour", Color(0.66, 0.24, 0.22))
	var wood := Color(0.40, 0.32, 0.23)
	var sack := Color(0.78, 0.70, 0.52)
	var straw := Color(0.84, 0.74, 0.44)

	# ── the frame ───────────────────────────────────────────────────────
	_strut(b, Vector3(0, 0.0, 0), Vector3(0, 1.72, 0), 0.055, wood)
	_strut(b, Vector3(-0.70, 1.34, 0.02), Vector3(0.70, 1.34, 0.02), 0.042, wood)

	# ── the shirt ───────────────────────────────────────────────────────
	# A slack rectangle hanging off the crossbar, blowing out at the hem.
	_blade(b, Vector3(-0.30, 0.72, -0.03), Vector3(0.30, 0.72, -0.03),
		Vector3(0.26, 1.44, 0.02), Vector3(-0.26, 1.44, 0.02), shirt)
	_blade(b, Vector3(-0.28, 0.70, 0.09), Vector3(0.28, 0.70, 0.09),
		Vector3(0.26, 1.42, 0.06), Vector3(-0.26, 1.42, 0.06), shirt.darkened(0.14))
	# Sleeves, drooping outward off the crossbar.
	for sx in [-1.0, 1.0]:
		var xs: float = sx
		_blade(b, Vector3(xs * 0.24, 1.40, -0.02), Vector3(xs * 0.24, 1.24, 0.06),
			Vector3(xs * 0.70, 1.14, 0.06), Vector3(xs * 0.70, 1.30, -0.02),
			shirt.lightened(0.06))
		# Straw coming out of the cuff.
		for i in 3:
			var ph := float(i) * 1.9 + xs
			_strut(b, Vector3(xs * 0.66, 1.22, 0.02),
				Vector3(xs * (0.80 + 0.05 * float(i)), 1.10 + 0.06 * sin(ph), 0.10 * cos(ph)),
				0.014, straw)

	# ── the head ────────────────────────────────────────────────────────
	var h0 := _ring_y(1.44, 0.17, 0.15, 0.05)
	var h1 := _ring_y(1.80, 0.15, 0.13, 0.05)
	b.loft([h0, h1], [Vector3(0, 1.44, 0), Vector3(0, 1.80, 0)], sack)
	_cap_axial(b, h1, Vector3(0, 1.83, 0), Vector3.UP, sack.darkened(0.08))
	# Two eyes, painted on the -Z face. Symmetrical, so they cannot mirror.
	for sx2 in [-1.0, 1.0]:
		var xs2: float = sx2
		b.box(Vector3(xs2 * 0.07, 1.66, -0.155), Vector3(0.030, 0.030, 0.012),
			Color(0.14, 0.12, 0.11))
	b.box(Vector3(0, 1.55, -0.155), Vector3(0.055, 0.014, 0.012), Color(0.14, 0.12, 0.11))

	# ── the hat ─────────────────────────────────────────────────────────
	var br0 := LPB.ring(Vector3(0, 1.83, 0), Vector3.UP, Vector3.FORWARD, 0.36, 0.34, 7)
	var br1 := LPB.ring(Vector3(0, 1.87, 0), Vector3.UP, Vector3.FORWARD, 0.34, 0.32, 7)
	b.loft([br0, br1], [Vector3(0, 1.83, 0), Vector3(0, 1.87, 0)], straw.darkened(0.10))
	_cap_axial(b, br0, Vector3(0, 1.82, 0), Vector3.DOWN, straw.darkened(0.28))
	var cr0 := LPB.ring(Vector3(0, 1.87, 0), Vector3.UP, Vector3.FORWARD, 0.18, 0.17, 7)
	var cr1 := LPB.ring(Vector3(0, 2.13, 0), Vector3.UP, Vector3.FORWARD, 0.16, 0.15, 7)
	b.loft([cr0, cr1], [Vector3(0, 1.87, 0), Vector3(0, 2.13, 0)], straw)
	_cap_axial(b, cr1, Vector3(0, 2.15, 0), Vector3.UP, straw.lightened(0.08))


# ===========================================================================
# 9. FEED SACK
# ===========================================================================
#
# A slumped 25 kg paper sack. Deliberately soft-shouldered: three rings, each
# wider than the one above, so it sits like something with grain in it rather
# than like a brick. Two of these have their corners torn open.

static func _feed_sack(b: RefCounted, e: RefCounted, params: Dictionary) -> void:
	var paper := _col(params, "colour", Color(0.76, 0.68, 0.50))
	var seed_v := _num(params, "variant", 0.0)
	var r0 := _ring_y(0.0, 0.29 + 0.02 * _wobble(0, 1, seed_v), 0.41, 0.09)
	var r1 := _ring_y(0.20, 0.27, 0.39 + 0.02 * _wobble(1, 1, seed_v), 0.10)
	var r2 := _ring_y(0.32, 0.19, 0.30, 0.08)
	b.loft([r0, r1, r2], [Vector3.ZERO, Vector3(0, 0.20, 0), Vector3(0, 0.32, 0)], paper)
	_cap_axial(b, r2, Vector3(0.03 * _wobble(2, 1, seed_v), 0.335, 0), Vector3.UP,
		paper.lightened(0.09))
	_cap_axial(b, r0, Vector3(0, -0.005, 0), Vector3.DOWN, paper.darkened(0.30))
	# The sewn seam across the top, and a horizontal stripe. No lettering — see
	# the -Z note at the top of this file.
	b.box(Vector3(0, 0.335, 0), Vector3(0.16, 0.014, 0.012), paper.darkened(0.34))
	b.box(Vector3(0, 0.13, -0.415), Vector3(0.25, 0.045, 0.010),
		Color(0.34, 0.42, 0.30))


# ===========================================================================
# 10. PALLET
# ===========================================================================

static func _pallet(b: RefCounted, e: RefCounted, params: Dictionary) -> void:
	var wood := _col(params, "colour", Color(0.62, 0.52, 0.38))
	for i in 3:
		var z := -0.40 + float(i) * 0.40
		b.box(Vector3(0, 0.045, z), Vector3(0.58, 0.045, 0.075), wood.darkened(0.14))
	for i in 5:
		var x := -0.48 + float(i) * 0.24
		b.box(Vector3(x, 0.115, 0), Vector3(0.085, 0.025, 0.50),
			wood.lightened(0.04 * float(i % 2)))


# ===========================================================================
# 11. KENNEL — the chained dog's house
# ===========================================================================
#
# Lofted INWARD through the doorway so the inside is a hole rather than the
# back of the far wall. The dog is never in it.

static func _kennel(b: RefCounted, e: RefCounted, params: Dictionary) -> void:
	var wood := _col(params, "colour", Color(0.52, 0.40, 0.28))
	var roofc := _col(params, "trim_colour", Color(0.38, 0.28, 0.22))
	var w := 0.55
	var d := 0.67
	# Walls as four boxes, so the doorway is a real gap and not a decal.
	b.box(Vector3(0, 0.32, d - 0.04), Vector3(w, 0.32, 0.04), wood)
	for sx in [-1.0, 1.0]:
		var xs: float = sx
		b.box(Vector3(xs * (w - 0.04), 0.32, 0), Vector3(0.04, 0.32, d), wood)
		b.box(Vector3(xs * (w - 0.17), 0.32, -(d - 0.04)), Vector3(0.17, 0.32, 0.04),
			wood.lightened(0.04))
	b.box(Vector3(0, 0.60, -(d - 0.04)), Vector3(w - 0.34, 0.04, 0.04), wood)
	# The dark inside, so the doorway reads as a hole from any angle.
	b.box(Vector3(0, 0.30, 0.10), Vector3(w - 0.10, 0.28, d - 0.20),
		Color(0.06, 0.05, 0.05))
	# Gable roof, two pitches.
	for sx2 in [-1.0, 1.0]:
		var xs2: float = sx2
		_blade(b, Vector3(xs2 * (w + 0.07), 0.62, -(d + 0.06)),
			Vector3(0, 0.90, -(d + 0.06)), Vector3(0, 0.90, d + 0.06),
			Vector3(xs2 * (w + 0.07), 0.62, d + 0.06), roofc)


# ===========================================================================
# 12. FARM DOG — chained, standing, extremely aware of you
# ===========================================================================
#
# Nose at -Z. Deliberately NOT the cottage library's dog: that one is a
# retriever asleep on her side, and this one's entire job is to be upright,
# tethered, and unable to reach you. Building a second dog is the cheaper of
# the two mistakes here — the alternative is preloading another zone's library
# across a dependency nobody expects.

static func _farm_dog(b: RefCounted, e: RefCounted, params: Dictionary) -> void:
	var fur := _col(params, "colour", Color(0.46, 0.34, 0.22))
	var belly := fur.lightened(0.24)

	# Body: a lofted tube along Z, deeper at the chest.
	var spine := [Vector3(0, 0.44, -0.30), Vector3(0, 0.46, 0.08), Vector3(0, 0.42, 0.40)]
	var rings := [
		LPB.ring(spine[0], Vector3.BACK, Vector3.UP, 0.15, 0.17, 5),
		LPB.ring(spine[1], Vector3.BACK, Vector3.UP, 0.16, 0.18, 5),
		LPB.ring(spine[2], Vector3.BACK, Vector3.UP, 0.12, 0.13, 5),
	]
	b.loft(rings, spine, fur)
	_cap_axial(b, rings[2], spine[2] + Vector3(0, -0.02, 0.08), Vector3.BACK,
		fur.darkened(0.12))
	b.box(Vector3(0, 0.31, 0.05), Vector3(0.11, 0.05, 0.28), belly)

	# Head and muzzle.
	var hc := Vector3(0, 0.58, -0.46)
	var h0 := LPB.ring(hc, Vector3.BACK, Vector3.UP, 0.11, 0.11, 5)
	var h1 := LPB.ring(hc + Vector3(0, -0.04, -0.16), Vector3.BACK, Vector3.UP,
		0.065, 0.055, 5)
	b.loft([h0, h1], [hc, hc + Vector3(0, -0.04, -0.16)], fur)
	_cap_axial(b, h1, hc + Vector3(0, -0.05, -0.22), Vector3.FORWARD, Color(0.10, 0.09, 0.09))
	_cap_axial(b, h0, hc + Vector3(0, 0.02, 0.05), Vector3.BACK, fur.darkened(0.10))
	# Ears, up and forward, which is the whole read: this dog has seen you.
	for sx in [-1.0, 1.0]:
		var xs: float = sx
		_blade(b, Vector3(xs * 0.05, 0.64, -0.42), Vector3(xs * 0.12, 0.64, -0.40),
			Vector3(xs * 0.15, 0.82, -0.44), Vector3(xs * 0.06, 0.80, -0.46),
			fur.darkened(0.16))
	# Eyes.
	for sx2 in [-1.0, 1.0]:
		var xs2: float = sx2
		b.box(Vector3(xs2 * 0.055, 0.60, -0.555), Vector3(0.022, 0.022, 0.012),
			Color(0.08, 0.07, 0.06))

	# Legs — four, straight, because a standing dog on a chain is braced.
	for sx3 in [-1.0, 1.0]:
		var xs3: float = sx3
		for zz in [-0.24, 0.30]:
			var z: float = zz
			_strut(b, Vector3(xs3 * 0.10, 0.0, z), Vector3(xs3 * 0.11, 0.36, z), 0.037,
				fur.darkened(0.10))

	# Tail, up.
	_strut(b, Vector3(0, 0.50, 0.44), Vector3(0.05, 0.74, 0.60), 0.032, fur)
	# Collar.
	var col_r := LPB.ring(Vector3(0, 0.52, -0.32), Vector3.BACK, Vector3.UP, 0.13, 0.14, 5)
	var col_r2 := LPB.ring(Vector3(0, 0.52, -0.27), Vector3.BACK, Vector3.UP, 0.13, 0.14, 5)
	b.loft([col_r, col_r2], [Vector3(0, 0.52, -0.32), Vector3(0, 0.52, -0.27)],
		Color(0.62, 0.16, 0.14))


# ===========================================================================
# 13. CROW — the scarecrow's problem, and the zone's only other bird
# ===========================================================================

static func _crow(b: RefCounted, e: RefCounted, params: Dictionary) -> void:
	var black := _col(params, "colour", Color(0.10, 0.10, 0.12))
	var spine := [Vector3(0, 0.14, -0.14), Vector3(0, 0.16, 0.02), Vector3(0, 0.13, 0.19)]
	var rings := [
		LPB.ring(spine[0], Vector3.BACK, Vector3.UP, 0.055, 0.060, 5),
		LPB.ring(spine[1], Vector3.BACK, Vector3.UP, 0.070, 0.075, 5),
		LPB.ring(spine[2], Vector3.BACK, Vector3.UP, 0.040, 0.042, 5),
	]
	b.loft(rings, spine, black)
	_cap_axial(b, rings[2], spine[2] + Vector3(0, -0.01, 0.05), Vector3.BACK,
		black.lightened(0.06))
	# Head and a heavy bill.
	var hc := Vector3(0, 0.22, -0.17)
	var h0 := LPB.ring(hc, Vector3.BACK, Vector3.UP, 0.045, 0.045, 5)
	b.loft([rings[0], h0], [spine[0], hc], black)
	_cap_axial(b, h0, hc + Vector3(0, 0.01, -0.04), Vector3.FORWARD, black.lightened(0.05))
	b.box(Vector3(0, 0.215, -0.235), Vector3(0.017, 0.017, 0.045), Color(0.16, 0.15, 0.14))
	# Folded wings, one blade each side.
	for sx in [-1.0, 1.0]:
		var xs: float = sx
		_blade(b, Vector3(xs * 0.055, 0.19, -0.09), Vector3(xs * 0.075, 0.17, 0.06),
			Vector3(xs * 0.055, 0.14, 0.20), Vector3(xs * 0.040, 0.16, -0.06),
			black.lightened(0.05))
	# Legs.
	for sx2 in [-1.0, 1.0]:
		var xs2: float = sx2
		_strut(b, Vector3(xs2 * 0.035, 0.0, 0.0), Vector3(xs2 * 0.035, 0.10, -0.01),
			0.011, Color(0.24, 0.22, 0.18))


# ===========================================================================
# FALLBACK — an unknown kind still gets a solid object, never nothing
# ===========================================================================

static func _fallback(b: RefCounted, e: RefCounted, params: Dictionary) -> void:
	var col := _col(params, "colour", Color(0.68, 0.60, 0.44))
	var lo := _ring_y(0.0, 0.40, 0.40, 0.06)
	var hi := _ring_y(0.80, 0.40, 0.40, 0.06)
	b.loft([lo, hi], [Vector3.ZERO, Vector3(0, 0.80, 0)], col)
	_cap_axial(b, hi, Vector3(0, 0.82, 0), Vector3.UP, col.lightened(0.10))
	_cap_axial(b, lo, _centroid(lo), Vector3.DOWN, col.darkened(0.25))
