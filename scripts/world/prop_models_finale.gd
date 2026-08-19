extends RefCounted
## THE 18TH GREEN MODEL LIBRARY — the props no other zone needs.
##
## Same idiom and the same public API as scripts/world/prop_models.gd and
## scripts/world/prop_models_cottage.gd:
##
##     PropModelsFinale.build(kind, parent, params) -> Node3D
##     PropModelsFinale.has_model(kind) -> bool
##     PropModelsFinale.footprint(kind, params) -> Vector3
##
## Polygons only. No SphereMesh, no CylinderMesh, no curved primitives. All
## colour lives in VERTEX COLOURS against one white material, so the whole
## course is one material and a per-face paint decision costs nothing.
##
## ---------------------------------------------------------------------------
## THE ANCHORING CONTRACT — identical to the other two libraries, repeated
## because it is the one thing that breaks a zone
## ---------------------------------------------------------------------------
## Every model here is BASE-ANCHORED: local origin on the ground at the centre
## of the footprint, growing up +Y. BoxShape3D colliders are CENTRED. So a
## model hung under a collider of height h always drops by -h * 0.5.
##
## ---------------------------------------------------------------------------
## THE THIRD MATERIAL — why this file has one the other two don't
## ---------------------------------------------------------------------------
## This zone's signature object is a sprinkler, and there are sixteen of them
## running forever. Water is the one thing in this project that is neither
## opaque nor emissive: it needs ALPHA, and it needs to be visible from both
## sides, because a spray fan is a single sheet and half the course is looking
## at its back. So there is a `spray_material()`: unshaded, alpha-blended,
## CULL_DISABLED. It is the only place in the project where culling is off,
## and it is off for a reason a comment can't fix — a one-sided sheet of water
## is invisible from behind.
##
## ---------------------------------------------------------------------------
## DETERMINISM
## ---------------------------------------------------------------------------
## No randf()/randi() anywhere. The build verification renders and diffs
## frames, so a random number in here is a bug. Every irregularity is a sin()
## of the vertex and ring indices: organic-looking and bit-identical every run.

## Preloaded rather than referenced by class_name: global class registration
## only exists after an editor import pass, so a `class_name` reference breaks
## in a fresh checkout or a headless CI run. A preload const always resolves.
const LPB := preload("res://scripts/goose/lowpoly_builder.gd")


# ---------------------------------------------------------------------------
# Registry
# ---------------------------------------------------------------------------

## Bounding footprint of each model, base-anchored: (width_x, height_y, depth_z).
## `credit_slab` is computed from its params instead — see footprint() — because
## a credit's slab is as wide as the credit is long.
const FOOTPRINTS := {
	&"palm": Vector3(4.60, 8.40, 4.60),
	&"flagstick": Vector3(0.86, 2.60, 0.20),
	&"sprinkler": Vector3(0.30, 0.24, 0.30),
	&"spray_fan": Vector3(2.00, 1.60, 7.60),
	&"fountain": Vector3(4.40, 4.20, 4.40),
	&"golf_cart": Vector3(1.50, 2.00, 2.75),
	&"golf_ball": Vector3(0.10, 0.10, 0.10),
	&"spanish_moss": Vector3(2.40, 2.90, 2.40),
	&"credit_slab": Vector3(3.20, 1.05, 0.30),
	&"ball_washer": Vector3(0.44, 1.05, 0.44),
}


## True if [param kind] has a dedicated model here. Unknown kinds still build —
## they get a faceted crate, so nothing in the world is ever invisible — but a
## caller that wants to fall back to another library should test this first.
static func has_model(kind: StringName) -> bool:
	return FOOTPRINTS.has(kind)


## Base-anchored bounding size of [param kind].
static func footprint(kind: StringName, params := {}) -> Vector3:
	if kind == &"credit_slab":
		return Vector3(_num(params, "w", 3.2), _num(params, "h", 1.05), 0.30)
	if FOOTPRINTS.has(kind):
		var f: Vector3 = FOOTPRINTS[kind]
		return f
	return Vector3.ONE


# ---------------------------------------------------------------------------
# Materials
# ---------------------------------------------------------------------------

## One white, vertex-colour-driven material for every opaque surface on the
## course. Shared with nothing — the other two libraries keep their own — but
## identical in construction, so the three look like one world.
static var _shared_mat: StandardMaterial3D = null

static func shared_material() -> StandardMaterial3D:
	if _shared_mat == null:
		_shared_mat = LPB.make_material(0.86)
		_shared_mat.cull_mode = BaseMaterial3D.CULL_BACK
	return _shared_mat


## Water. Unshaded so a spray fan reads at dawn without needing a light on it,
## alpha so it is water rather than plastic, and CULL_DISABLED because a fan is
## one sheet and it has to exist from both sides.
static var _spray_mat: StandardMaterial3D = null

static func spray_material() -> StandardMaterial3D:
	if _spray_mat == null:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color.WHITE
		m.vertex_color_use_as_albedo = true
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		# No depth WRITE, but depth TEST stays on: sixteen overlapping fans that
		# each wrote depth would punch holes in each other, and a fan that
		# ignored depth entirely would draw straight through the clubhouse.
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
		_spray_mat = m
	return _spray_mat


# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

## Builds the model for [param kind] as a new "Model" Node3D under
## [param parent] and returns it.
##
## `params` keys, all optional:
##   size          Vector3  scale the model so its footprint matches this
##   colour        Color    the model's main colour
##   trim_colour   Color    secondary (frond, canopy, flag)
##   variant       float    deterministic shape seed
##   w / h         float    credit slab dimensions
static func build(kind: StringName, parent: Node3D, params := {}) -> Node3D:
	var model := Node3D.new()
	model.name = "Model"
	parent.add_child(model)

	var b: RefCounted = LPB.new()
	var w: RefCounted = LPB.new()   ## the water builder — alpha, unshaded
	match kind:
		&"palm":
			_palm(b, params)
		&"flagstick":
			_flagstick(b, params)
		&"sprinkler":
			_sprinkler(b, params)
		&"spray_fan":
			_spray_fan(w, params)
		&"fountain":
			_fountain(b, w, params)
		&"golf_cart":
			_golf_cart(b, params)
		&"golf_ball":
			_golf_ball(b, params)
		&"spanish_moss":
			_spanish_moss(b, params)
		&"credit_slab":
			_credit_slab(b, params)
		&"ball_washer":
			_ball_washer(b, params)
		_:
			_fallback(b, params)

	model.set_meta("tri_count", b.tri_count + w.tri_count)
	# THE MODEL CARRIES ITS OWN DECLARATION, so `tools/geomtest.gd` can compare
	# the box this builder PROMISED against the mesh it actually emitted without
	# knowing which of the seven FOOTPRINTS tables the kind came from. `build()`
	# sizes with `want / footprint(kind)`, so a declaration that disagrees with
	# the mesh makes every `size:` placement of that kind wrong by exactly that
	# ratio, in every zone that asks for one — and nothing could see it.
	model.set_meta("kind", kind)
	model.set_meta("declared", footprint(kind, params))
	if b.tri_count > 0:
		LPB.attach(model, b.commit(), shared_material(), "Shell")
	# Only when there is something wet: an empty SurfaceTool commits to null,
	# and a MeshInstance3D with a null mesh is a silent per-frame cost for
	# nothing.
	if w.tri_count > 0:
		LPB.attach(model, w.commit(), spray_material(), "Spray")

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
# three helpers keeps that mistake out of the build functions below.
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


# ---------------------------------------------------------------------------
# Cross-section and winding helpers.
#
# Deliberately re-implemented here rather than reached for across a preload
# into the other two libraries: those are underscore-private statics on files
# this one has no other reason to depend on, and duplicating forty lines is
# cheaper than a coupling nobody expects. Same call the cottage library made.
# ---------------------------------------------------------------------------

## Deterministic pseudo-noise in roughly [-1, 1]. Stands in for randf() so the
## lumpy things stay bit-identical between runs.
static func _wobble(a: int, c: int, seed_v: float) -> float:
	return sin(float(a) * 2.399 + float(c) * 1.117 + seed_v * 3.77) \
		* cos(float(a) * 0.813 - float(c) * 1.937 + seed_v * 1.31)


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
## cost each of them two render rounds; it is here so it costs this one none.
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


## A four-sided beam between two points. Posts, rails, frond midribs, trunks.
static func _strut(b: RefCounted, a: Vector3, c: Vector3, r: float, col: Color) -> void:
	var d := c - a
	if d.length_squared() < 1e-8:
		return
	var dir := d.normalized()
	var up := Vector3.UP if absf(dir.y) < 0.92 else Vector3.FORWARD
	var r0 := LPB.ring(a, dir, up, r, r, 4, PI * 0.25)
	var r1 := LPB.ring(c, dir, up, r, r, 4, PI * 0.25)
	b.loft([r0, r1], [a, c], col)


## An angular lump. Four stacked rings plus caps, every vertex kicked around by
## _wobble so no two share a silhouette.
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
			var k := 1.0 + 0.22 * _wobble(i, j, seed_v)
			out.append(c + Vector3(d.x * k, d.y + ry * 0.16 * _wobble(i + 3, j, seed_v), d.z * k))
		rings.append(out)
	b.loft(rings, spine, col)
	_cap_axial(b, rings[rings.size() - 1], centre + Vector3(rx * 0.06, ry * 0.96, rx * 0.04),
		Vector3.UP, col.lightened(0.06))
	_cap_axial(b, rings[0], centre + Vector3(0, -ry * 0.92, 0), Vector3.DOWN, col.darkened(0.18))


# ===========================================================================
# 1. CABBAGE PALM
#
# Florida's state tree and the only vertical thing on a golf course that isn't
# a flag. Built as a leaning trunk plus nine drooping fronds.
#
# THE FRONDS ARE FOLDED, not flat. A palm frond modelled as a flat blade is a
# green rectangle from above and INVISIBLE edge-on — and the camera on this
# course spends most of its time at goose height, which is exactly edge-on to
# a horizontal leaf. Every blade here is a shallow V in cross-section, so it
# has a silhouette from every angle and catches the low sun on one half.
# ===========================================================================

static func _palm(b: RefCounted, params: Dictionary) -> void:
	var trunk := _col(params, "colour", Color(0.44, 0.38, 0.30))
	var frond := _col(params, "trim_colour", Color(0.26, 0.40, 0.20))
	var seed_v := _num(params, "variant", 0.0)

	# ── the trunk ───────────────────────────────────────────────────────
	# A palm never grows straight. The lean is a quarter-arc in a direction
	# picked off the seed, so a row of them along a cart path doesn't read as
	# a fence.
	var lean := Vector3(sin(seed_v * 1.7), 0.0, cos(seed_v * 2.3)) * 0.55
	var rings := []
	var spine := []
	var steps := 7
	var top := Vector3.ZERO
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var y := t * 6.30
		var c := lean * t * t + Vector3(0, y, 0)
		var r := lerpf(0.30, 0.165, t) * (1.0 + 0.055 * _wobble(i, 1, seed_v))
		spine.append(c)
		rings.append(LPB.ring(c, Vector3.UP, Vector3.FORWARD, r, r, 6, seed_v + t * 0.6))
		top = c
	b.loft(rings, spine, trunk)
	_cap_axial(b, rings[0], Vector3(0, -0.06, 0), Vector3.DOWN, trunk.darkened(0.25))

	# Leaf-boot scars up the trunk: the diamond pattern a cabbage palm keeps
	# for decades. Three per level, sunk in so they never break the silhouette.
	for i in 9:
		var t := 0.12 + float(i) * 0.093
		var c: Vector3 = lean * t * t + Vector3(0, t * 6.30, 0)
		var r := lerpf(0.30, 0.165, t)
		for k in 3:
			var a := TAU * float(k) / 3.0 + float(i) * 0.9 + seed_v
			b.box(c + Vector3(cos(a) * r * 0.86, 0.0, sin(a) * r * 0.86),
				Vector3(0.055, 0.048, 0.055), trunk.darkened(0.22))

	# ── the crown ───────────────────────────────────────────────────────
	var crown := top + Vector3(0, 0.10, 0)
	_blob(b, crown, 0.30, 0.26, seed_v, seed_v + 2.0, trunk.lightened(0.08), 5)
	for i in 9:
		var a := TAU * float(i) / 9.0 + seed_v * 0.8
		var droop := 0.72 + 0.30 * _wobble(i, 2, seed_v)
		_frond(b, crown, a, 2.25 + 0.45 * _wobble(i, 5, seed_v), droop,
			frond.lightened(0.06 * _wobble(i, 7, seed_v)))
	# Two dead fronds hanging straight down under the live ones. A cabbage palm
	# that has not been trimmed keeps a skirt, and it is the detail that says
	# "nobody maintains this side of the course".
	for i in 2:
		var a2 := 2.1 + float(i) * 3.0 + seed_v
		_frond(b, crown + Vector3(0, -0.12, 0), a2, 1.55, 2.35,
			Color(0.42, 0.35, 0.20))


## One frond: a folded blade sweeping out from the crown along `yaw`, drooping
## by `droop`, with a midrib along the fold.
static func _frond(b: RefCounted, base: Vector3, yaw: float, reach: float,
		droop: float, col: Color) -> void:
	var dir := Vector3(sin(yaw), 0.0, cos(yaw))
	var steps := 5
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	var prev_c := Vector3.ZERO
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		# Ballistic droop: out fast, then down. A frond that falls linearly
		# reads as a plank.
		var p := base + dir * (reach * t) + Vector3(0, 0.34 * t - droop * t * t, 0)
		var half := sin(t * PI) * 0.34 + 0.03
		var side := Vector3(dir.z, 0.0, -dir.x) * half
		var l := p + side + Vector3(0, -0.05 * sin(t * PI), 0)
		var r := p - side + Vector3(0, -0.05 * sin(t * PI), 0)
		if i > 0:
			var shade := col.lightened(0.04 * float(i % 2))
			b.quad(prev_c, prev_l, l, p, shade, p + Vector3(0, -1.0, 0))
			b.quad(prev_c, p, r, prev_r, shade.darkened(0.10), p + Vector3(0, -1.0, 0))
		prev_l = l
		prev_r = r
		prev_c = p
	# The midrib, so the fold has an edge and the frond reads from underneath.
	_strut(b, base, prev_c, 0.028, col.darkened(0.22))


# ===========================================================================
# 2. THE PIN
#
# The flagstick, the flag, and the cup rim. The flag is a separate node in the
# zone's hands (it rotates), but the whole thing is one model — the pole is
# 2 cm across and nothing about it reads when it turns.
# ===========================================================================

static func _flagstick(b: RefCounted, params: Dictionary) -> void:
	var flag := _col(params, "colour", Color(0.90, 0.24, 0.20))
	var pole := _col(params, "trim_colour", Color(0.93, 0.93, 0.90))

	_strut(b, Vector3(0, 0.0, 0), Vector3(0, 2.30, 0), 0.021, pole)
	# Two black bands, because every flagstick has them and they are the only
	# thing that gives a two-metre white stick a sense of scale.
	for i in 2:
		b.box(Vector3(0, 1.28 + float(i) * 0.16, 0), Vector3(0.026, 0.035, 0.026),
			Color(0.12, 0.12, 0.13))
	# The flag: a triangular pennant with a fold in it, hanging off +X.
	var pts := [
		Vector3(0.02, 2.28, 0.0),
		Vector3(0.44, 2.24, -0.04),
		Vector3(0.80, 2.10, 0.02),
		Vector3(0.78, 1.86, 0.05),
		Vector3(0.40, 1.80, -0.02),
		Vector3(0.02, 1.86, 0.0),
	]
	b.quad(pts[0], pts[1], pts[4], pts[5], flag, Vector3(0.4, 2.05, -3.0))
	b.quad(pts[1], pts[2], pts[3], pts[4], flag.darkened(0.08), Vector3(0.4, 2.05, -3.0))
	# The number, as a white patch. Reads as "there is something printed on
	# this" at every distance the player will ever be at, and costs one quad.
	b.box(Vector3(0.30, 2.04, -0.012), Vector3(0.11, 0.085, 0.008), Color(0.96, 0.96, 0.94))


# ===========================================================================
# 3. SPRINKLER HEAD + SPRAY FAN
#
# "Florida. The promised land. Sprinklers forever." — taken literally: the
# heads never retract and the fans never stop for the whole ending, credits
# included.
# ===========================================================================

static func _sprinkler(b: RefCounted, params: Dictionary) -> void:
	var body := _col(params, "colour", Color(0.22, 0.26, 0.22))
	# The buried can, flush with the turf.
	var r0 := LPB.ring(Vector3(0, 0.0, 0), Vector3.UP, Vector3.FORWARD, 0.145, 0.145, 6, 0.2)
	var r1 := LPB.ring(Vector3(0, 0.055, 0), Vector3.UP, Vector3.FORWARD, 0.135, 0.135, 6, 0.2)
	b.loft([r0, r1], [Vector3.ZERO, Vector3(0, 0.055, 0)], body.darkened(0.25))
	_cap_axial(b, r1, Vector3(0, 0.058, 0), Vector3.UP, body.darkened(0.18))
	# The riser, up out of the can, with a brass nozzle on top.
	var r2 := LPB.ring(Vector3(0, 0.055, 0), Vector3.UP, Vector3.FORWARD, 0.058, 0.058, 5, 0.0)
	var r3 := LPB.ring(Vector3(0, 0.185, 0), Vector3.UP, Vector3.FORWARD, 0.050, 0.050, 5, 0.0)
	b.loft([r2, r3], [Vector3(0, 0.055, 0), Vector3(0, 0.185, 0)], body.lightened(0.10))
	_cap_axial(b, r3, Vector3(0, 0.195, 0), Vector3.UP, Color(0.62, 0.50, 0.22))
	b.box(Vector3(0, 0.205, -0.045), Vector3(0.022, 0.022, 0.038), Color(0.62, 0.50, 0.22))


## The fan of water, thrown out along -Z. Built as a folded trough so it has a
## silhouette from the side as well as from above, fading to nothing at the
## tip. The zone spins the whole model about Y; that IS the rotation.
static func _spray_fan(w: RefCounted, params: Dictionary) -> void:
	var tint := _col(params, "colour", Color(0.88, 0.95, 1.00))
	var reach := _num(params, "reach", 7.30)
	var steps := 8
	# TWO SHEETS, one wide and faint, one narrow and dense. The first pass was
	# a single 0.62-wide sheet at 0.42 alpha and the render came back with
	# sixteen thin white WIRES lying on the grass — at a hundred metres a
	# one-quad-thick sheet is a line. Nesting a second sheet inside the first
	# gives the fan a bright core and a soft edge, which is what reads as water
	# from across a golf course.
	for pass_i in 2:
		var wide := pass_i == 0
		var prev := []
		for i in range(steps + 1):
			var t := float(i) / float(steps)
			var z := -reach * t
			# A real arc: up out of the nozzle to about a metre and a half,
			# over, and into the grass exactly at the end of the reach.
			var y := 0.20 + 5.0 * t - 5.4 * t * t
			var half := lerpf(0.05, 0.98 if wide else 0.46, t)
			var fold := lerpf(0.03, 0.34, t) * (1.0 - t * 0.35)
			var row := [
				Vector3(-half, y, z),
				Vector3(0.0, y + fold, z),
				Vector3(half, y, z),
			]
			# Alpha is the whole read. Dense at the nozzle, gone at the tip, so
			# the fan ends in air rather than at a hard edge.
			var a0 := (1.0 - t) * (0.26 if wide else 0.52) + (0.05 if wide else 0.10)
			var col := Color(tint.r, tint.g, tint.b, a0)
			if i > 0:
				for k in 2:
					var p0: Vector3 = prev[k]
					var p1: Vector3 = prev[k + 1]
					var q1: Vector3 = row[k + 1]
					var q0: Vector3 = row[k]
					w.quad(p0, p1, q1, q0, col, Vector3(0, -50.0, 0))
			prev = row
	# Droplets past the end of the sheet, so the fan disintegrates instead of
	# stopping. Deterministic, all inside the arc's own footprint.
	for i in 7:
		var t2 := 0.70 + 0.042 * float(i)
		var z2 := -reach * t2
		var y2 := maxf(0.20 + 5.0 * t2 - 5.4 * t2 * t2, 0.05)
		var x2 := (0.95 * t2) * _wobble(i, 3, 1.0)
		# 3.5 cm, not 5.5, and at 0.30 alpha rather than 0.40. The render came
		# back with what were unmistakably six white DICE floating over the
		# green: a droplet has to be small enough that you never resolve it as
		# a shape, or it stops being water.
		w.box(Vector3(x2, y2, z2), Vector3(0.035, 0.035, 0.042),
			Color(tint.r, tint.g, tint.b, 0.30))


# ===========================================================================
# 4. THE FOUNTAIN
#
# The one in the water hazard. A concrete collar with seven arcs off it and a
# jet up the middle.
# ===========================================================================

static func _fountain(b: RefCounted, w: RefCounted, params: Dictionary) -> void:
	var stone := _col(params, "colour", Color(0.56, 0.55, 0.51))
	var tint := _col(params, "trim_colour", Color(0.84, 0.93, 1.00))

	var r0 := LPB.ring(Vector3(0, 0.0, 0), Vector3.UP, Vector3.FORWARD, 0.62, 0.62, 8, 0.0)
	var r1 := LPB.ring(Vector3(0, 0.34, 0), Vector3.UP, Vector3.FORWARD, 0.46, 0.46, 8, 0.0)
	b.loft([r0, r1], [Vector3.ZERO, Vector3(0, 0.34, 0)], stone)
	_cap_axial(b, r1, Vector3(0, 0.38, 0), Vector3.UP, stone.lightened(0.10))

	# The centre jet — a tapering column that frays at the top.
	var jr0 := LPB.ring(Vector3(0, 0.34, 0), Vector3.UP, Vector3.FORWARD, 0.13, 0.13, 5, 0.0)
	var jr1 := LPB.ring(Vector3(0, 2.20, 0), Vector3.UP, Vector3.FORWARD, 0.28, 0.28, 5, 0.4)
	var jr2 := LPB.ring(Vector3(0, 3.10, 0), Vector3.UP, Vector3.FORWARD, 0.10, 0.10, 5, 0.8)
	w.loft([jr0, jr1, jr2], [Vector3(0, 0.34, 0), Vector3(0, 2.2, 0), Vector3(0, 3.1, 0)],
		Color(tint.r, tint.g, tint.b, 0.30))

	# Seven falling arcs off the collar.
	for i in 7:
		var a := TAU * float(i) / 7.0
		var dir := Vector3(sin(a), 0.0, cos(a))
		var side := Vector3(dir.z, 0.0, -dir.x)
		var steps := 5
		var prev_l := Vector3.ZERO
		var prev_r := Vector3.ZERO
		for k in range(steps + 1):
			var t := float(k) / float(steps)
			var p := Vector3(0, 0.40, 0) + dir * (2.05 * t) \
				+ Vector3(0, 1.35 * t - 1.75 * t * t, 0)
			var half := lerpf(0.03, 0.16, t)
			var l := p + side * half
			var r := p - side * half
			if k > 0:
				w.quad(prev_l, prev_r, r, l,
					Color(tint.r, tint.g, tint.b, (1.0 - t) * 0.34 + 0.05),
					Vector3(0, -50.0, 0))
			prev_l = l
			prev_r = r


# ===========================================================================
# 5. THE GOLF CART
#
# It drives in slow circles on the fairway forever with a goose at the wheel.
# ===========================================================================

static func _golf_cart(b: RefCounted, params: Dictionary) -> void:
	var body := _col(params, "colour", Color(0.90, 0.90, 0.87))
	var trim := _col(params, "trim_colour", Color(0.30, 0.34, 0.38))

	# Chassis and floor pan.
	b.box(Vector3(0, 0.42, 0.05), Vector3(0.60, 0.16, 1.16), body)
	b.box(Vector3(0, 0.30, 0.05), Vector3(0.52, 0.06, 1.04), trim.darkened(0.20))
	# Nose, sloping down toward -Z (forward).
	b.box(Vector3(0, 0.50, -1.02), Vector3(0.56, 0.13, 0.28), body.darkened(0.05))
	b.box(Vector3(0, 0.36, -1.24), Vector3(0.50, 0.10, 0.10), trim.darkened(0.30))
	# Bench seat: base and back.
	b.box(Vector3(0, 0.62, 0.32), Vector3(0.56, 0.09, 0.34), trim)
	b.box(Vector3(0, 0.86, 0.63), Vector3(0.56, 0.26, 0.08), trim)
	# Roof on four posts.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var x: float = sx
			var z: float = sz
			_strut(b, Vector3(x * 0.52, 0.50, z * 0.72 + 0.05),
				Vector3(x * 0.50, 1.62, z * 0.72 + 0.05), 0.030, body.darkened(0.12))
	b.box(Vector3(0, 1.68, 0.05), Vector3(0.62, 0.045, 0.90), body.lightened(0.04))
	# Windscreen — a pale, slightly tilted plate. Not transparent: an alpha
	# windscreen on the shared opaque material would need a fourth material for
	# one prop, and a pale grey plate reads as glass at any distance out here.
	b.box(Vector3(0, 1.10, -0.72), Vector3(0.50, 0.42, 0.02), Color(0.78, 0.84, 0.86))
	# Steering wheel and column.
	_strut(b, Vector3(-0.22, 0.72, -0.42), Vector3(-0.22, 1.02, -0.24), 0.022, trim)
	b.box(Vector3(-0.22, 1.05, -0.22), Vector3(0.13, 0.02, 0.13), trim.darkened(0.10))
	# Four wheels.
	for sx2 in [-1.0, 1.0]:
		for sz2 in [-1.0, 1.0]:
			var x2: float = sx2
			var z2: float = sz2
			var c := Vector3(x2 * 0.60, 0.26, z2 * 0.78 + 0.05)
			var axis := Vector3(1, 0, 0)
			var w0 := LPB.ring(c - axis * 0.06, axis, Vector3.UP, 0.25, 0.25, 6, 0.3)
			var w1 := LPB.ring(c + axis * 0.06, axis, Vector3.UP, 0.25, 0.25, 6, 0.3)
			b.loft([w0, w1], [c - axis * 0.06, c + axis * 0.06], Color(0.14, 0.14, 0.15))
			_cap_axial(b, w1, c + axis * 0.07, axis, Color(0.72, 0.72, 0.70))
			_cap_axial(b, w0, c - axis * 0.07, -axis, Color(0.72, 0.72, 0.70))
	# A bag of clubs strapped to the back, because of course there is.
	b.box(Vector3(0.22, 0.95, 0.92), Vector3(0.14, 0.34, 0.14), Color(0.24, 0.30, 0.44))
	for i in 4:
		_strut(b, Vector3(0.22 + 0.05 * float(i) - 0.07, 1.24, 0.92),
			Vector3(0.20 + 0.06 * float(i) - 0.09, 1.52, 0.98), 0.012,
			Color(0.72, 0.72, 0.74))


# ===========================================================================
# 6. SMALL THINGS
# ===========================================================================

static func _golf_ball(b: RefCounted, params: Dictionary) -> void:
	var col := _col(params, "colour", Color(0.96, 0.96, 0.93))
	_blob(b, Vector3(0, 0.05, 0), 0.05, 0.05, 0.0, 1.0, col, 5)


## Spanish moss, hung under a live oak. Base-anchored at the TOP of the strand
## cluster and growing downward is the natural way to author it, but the
## contract is the contract — so it is authored hanging from y = 2.90.
static func _spanish_moss(b: RefCounted, params: Dictionary) -> void:
	# Darker and much thinner than the first pass. At 0.56 grey-green and 7 cm
	# thick, fifteen metres up in a warm sky, this rendered as a bundle of
	# white STRAWS. Spanish moss is nearly a silhouette even in full sun.
	var col := _col(params, "colour", Color(0.40, 0.43, 0.33))
	var seed_v := _num(params, "variant", 0.0)
	for i in 13:
		var a := TAU * float(i) / 13.0 + seed_v
		var r := 0.30 + 0.80 * absf(_wobble(i, 1, seed_v))
		var x := cos(a) * r
		var z := sin(a) * r
		var drop := 1.30 + 1.35 * absf(_wobble(i, 4, seed_v))
		var segs := 4
		for k in segs:
			var t0 := float(k) / float(segs)
			var t1 := float(k + 1) / float(segs)
			var sway := 0.16 * _wobble(i, k, seed_v)
			var p0 := Vector3(x + sway * t0, 2.90 - drop * t0, z + sway * t0 * 0.6)
			var p1 := Vector3(x + sway * t1, 2.90 - drop * t1, z + sway * t1 * 0.6)
			_strut(b, p0, p1, lerpf(0.042, 0.011, t0),
				col.darkened(0.06 * float(k)))


## The ball washer nobody has used since March. A post, a green drum, a crank.
static func _ball_washer(b: RefCounted, params: Dictionary) -> void:
	var col := _col(params, "colour", Color(0.16, 0.34, 0.22))
	_strut(b, Vector3(0, 0, 0), Vector3(0, 0.62, 0), 0.045, Color(0.36, 0.30, 0.24))
	b.box(Vector3(0, 0.82, 0), Vector3(0.16, 0.20, 0.16), col)
	b.box(Vector3(0, 1.00, 0), Vector3(0.13, 0.03, 0.13), col.lightened(0.14))
	_strut(b, Vector3(0.16, 0.86, 0), Vector3(0.26, 0.94, 0), 0.018, Color(0.30, 0.30, 0.32))


# ===========================================================================
# 7. THE CREDIT SLAB
#
# A low white monolith that stands on the fairway and comes toward you at
# walking pace. Katamari's credits-as-a-bonus-stage, applied to a game whose
# core verb is knocking things over.
#
# It is chamfered on every edge for one reason: an un-chamfered white box in
# a low warm sun is a white box, and forty of them in a row read as a
# spreadsheet. One 2 cm bevel and they read as carved.
# ===========================================================================

static func _credit_slab(b: RefCounted, params: Dictionary) -> void:
	var stone := _col(params, "colour", Color(0.92, 0.91, 0.87))
	var w := _num(params, "w", 3.2)
	var h := _num(params, "h", 1.05)
	var hx := w * 0.5
	var hz := 0.15

	# Plinth: a slightly wider, darker foot, so the slab sits ON the grass
	# rather than being pushed through it.
	b.box(Vector3(0, 0.05, 0), Vector3(hx + 0.06, 0.05, hz + 0.05), stone.darkened(0.22))

	# The face, as a chamfered slab: four rings up the Y axis with the top and
	# bottom pulled in.
	var cham := 0.045
	var rings := []
	var spine := []
	var levels := [0.10, 0.10 + cham, h - cham, h]
	for i in range(levels.size()):
		var y: float = levels[i]
		var inset: float = cham if (i == 0 or i == levels.size() - 1) else 0.0
		var r := PackedVector3Array([
			Vector3(-hx + inset, y, -hz + inset * 0.6),
			Vector3(hx - inset, y, -hz + inset * 0.6),
			Vector3(hx - inset, y, hz - inset * 0.6),
			Vector3(-hx + inset, y, hz - inset * 0.6),
		])
		rings.append(r)
		spine.append(Vector3(0, y, 0))
	b.loft(rings, spine, stone)
	_cap_axial(b, rings[rings.size() - 1], Vector3(0, h + 0.012, 0), Vector3.UP,
		stone.lightened(0.05))
	_cap_axial(b, rings[0], Vector3(0, 0.09, 0), Vector3.DOWN, stone.darkened(0.30))

	# An inset panel on the +Z face — the plate the name is engraved on. The
	# Label3D the zone hangs on this model sits 1 cm proud of it.
	b.box(Vector3(0, (h + 0.10) * 0.5, hz - 0.012),
		Vector3(hx - 0.10, (h - 0.10) * 0.5 - 0.07, 0.012), stone.darkened(0.10))


static func _fallback(b: RefCounted, params: Dictionary) -> void:
	var col := _col(params, "colour", Color(0.62, 0.60, 0.58))
	b.box(Vector3(0, 0.5, 0), Vector3(0.5, 0.5, 0.5), col)
