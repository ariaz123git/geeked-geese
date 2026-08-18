extends RefCounted
## PROCEDURAL LOW-POLY ENVIRONMENT MODELS — polygons only.
##
## Every prop and building in the two zones was a BoxMesh. This replaces them
## with faceted geometry built through LowPolyBuilder, in exactly the same
## idiom as goose_visual_lowpoly.gd: cross-section tables lofted along a spine,
## per-face colour callbacks, flat normals, one material, all colour carried in
## VERTEX COLOURS.
##
## No SphereMesh, no CylinderMesh, no TorusMesh, no PrismMesh anywhere.
##
## ---------------------------------------------------------------------------
## THE ANCHORING CONTRACT — read this before integrating
## ---------------------------------------------------------------------------
## Every model is built BASE-ANCHORED: local origin sits on the ground at the
## centre of the footprint, and the model grows up +Y. That is the natural way
## to author a prop and it makes the collider match trivially checkable.
##
## The zones' colliders are BoxShape3D CENTRED on the body's origin, so when
## you hang one of these under a ChaosProp or a StaticBody3D you must drop it
## by half the footprint height:
##
##     var m := PropModels.build(&"shopping_cart", body)
##     m.position.y = -PropModels.footprint(&"shopping_cart").y * 0.5
##
## Get that wrong and the prop floats or sinks — which is exactly the failure
## the art pass is supposed to fix, so it is worth one line of care.
##
## ---------------------------------------------------------------------------
## SIZE VARIANTS
## ---------------------------------------------------------------------------
## Several props exist at two sizes across the zones (the strip-mall recycling
## bin is 1.0x1.2x0.8, suburbia's is 0.6x0.9x0.55). Pass `size` in `params` and
## the model is scaled so its footprint matches exactly:
##
##     PropModels.build(&"recycling_bin", body, {"size": Vector3(0.6, 0.9, 0.55)})
##
## ---------------------------------------------------------------------------
## DETERMINISM
## ---------------------------------------------------------------------------
## No randf()/randi() anywhere. The build verification renders and diffs frames,
## so a random number here is a bug. Every irregularity (the slumped garbage
## bag, the lumpy tree canopy) is a sin() of the vertex and ring indices, which
## looks organic and is bit-identical every run.

## Preloaded rather than referenced by class_name: global class registration
## only exists after an editor import pass, so a `class_name` reference breaks
## in a fresh checkout or a headless CI run. A preload const always resolves.
const LPB := preload("res://scripts/goose/lowpoly_builder.gd")

# ---------------------------------------------------------------------------
# Registry
# ---------------------------------------------------------------------------

## Bounding footprint of each model, base-anchored: (width_x, height_y, depth_z).
## These are matched to the BoxMesh/BoxShape3D sizes they replace in
## zone_strip_mall.gd and zone_suburbia.gd — see prop_models_notes.md for the
## line-by-line correspondence.
const FOOTPRINTS := {
	&"shopping_cart": Vector3(0.80, 1.00, 1.30),
	&"minivan": Vector3(2.10, 1.90, 4.60),
	&"recycling_bin": Vector3(1.00, 1.20, 0.80),
	&"garbage_bag": Vector3(0.48, 0.55, 0.50),
	&"patio_chair": Vector3(0.60, 0.90, 0.60),
	&"lawn_sign": Vector3(1.10, 0.80, 0.08),
	&"lamp_post": Vector3(1.40, 8.40, 0.70),
	&"dumpster": Vector3(3.50, 2.25, 2.10),
	&"tree_deciduous": Vector3(4.20, 6.00, 4.00),
	&"tree_conifer": Vector3(2.40, 6.00, 2.40),
	&"house": Vector3(10.00, 5.40, 8.00),
	&"fence_panel": Vector3(2.20, 1.70, 0.16),
	&"mailbox": Vector3(0.42, 0.30, 0.60),
	&"gnome": Vector3(0.32, 0.55, 0.32),
	&"trampoline": Vector3(3.95, 0.70, 3.95),
	&"kiddie_pool": Vector3(2.50, 0.32, 2.50),
	&"bbq": Vector3(1.00, 1.05, 0.55),
	&"hydrant": Vector3(0.40, 0.80, 0.40),
	&"bench": Vector3(1.80, 0.85, 0.62),
	&"cattail": Vector3(0.30, 1.40, 0.30),
	&"stop_sign": Vector3(0.72, 2.26, 0.16),
	&"hedge": Vector3(1.60, 0.74, 0.60),
	&"basketball_hoop": Vector3(1.20, 3.40, 0.95),
	&"basketball": Vector3(0.42, 0.42, 0.42),
	## 0.88, not the cap apex's 0.86: a spot sitting proud of the crown is the
	## tallest thing on the model. Measured 0.879 across the three variants.
	&"fly_agaric": Vector3(1.00, 0.88, 1.00),
}


## True if [param kind] has a dedicated model. Unknown kinds still build — they
## get a faceted crate so nothing in the world is ever invisible — but callers
## that want to fall back to their own box should test this first.
static func has_model(kind: StringName) -> bool:
	return FOOTPRINTS.has(kind)


## Base-anchored bounding size of [param kind]. For the house this is computed
## from the passed dimensions, because every house in the cul-de-sac is a
## different size.
static func footprint(kind: StringName, params := {}) -> Vector3:
	if kind == &"house":
		var w := _num(params, "w", 10.0)
		var d := _num(params, "d", 8.0)
		var wall_h := _num(params, "wall_h", 3.2)
		var roof_h := _num(params, "roof_h", 2.0)
		return Vector3(w * 1.08, wall_h + roof_h, d * 1.08)
	if FOOTPRINTS.has(kind):
		var f: Vector3 = FOOTPRINTS[kind]
		return f
	return Vector3.ONE


## One white, vertex-colour-driven material for the entire environment. Every
## prop in both zones ends up sharing it, which is the whole payoff of putting
## colour in the vertices: hundreds of props, one material.
##
## ---------------------------------------------------------------------------
## WINDING — CULL_BACK is correct and must stay CULL_BACK.
##
## This material used to force CULL_FRONT, to work around lowpoly_builder.gd
## emitting every face inside-out. That bug is FIXED, in the builder itself:
## `_emit()` submits its vertices reversed while keeping the computed normal —
## see lowpoly_builder.gd:63-71, which explains it and says not to "simplify"
## the loop. So the meshes arriving here are front-facing and the engine
## default is the right setting.
##
## The twenty-five lines that used to sit here described the old bug in the
## present tense and closed by telling the reader to change cull_mode "back to
## CULL_BACK if lowpoly_builder.gd is ever corrected" — which it already was.
## Anyone reading that in isolation would conclude the builder is still broken
## and either flip this line or "fix" _emit, and either one inverts every mesh
## in the project, the goose included. CLAUDE.md lists that as a bug that has
## already shipped once. It is not going to ship twice because of a comment.
static var _shared_mat: StandardMaterial3D = null

static func shared_material() -> StandardMaterial3D:
	if _shared_mat == null:
		_shared_mat = LPB.make_material(0.90)
		_shared_mat.cull_mode = BaseMaterial3D.CULL_BACK
	return _shared_mat


## Builds the model for [param kind] as a new "Model" Node3D under
## [param parent] and returns it.
##
## `params` keys, all optional:
##   size          Vector3  scale the model so its footprint matches this
##   body_colour   Color    minivan paint
##   wall_colour   Color    house siding
##   roof_colour   Color    house shingles
##   colour        Color    generic tint for bins, chairs, signs, fences
##   w/d/wall_h/roof_h  float   house dimensions
##   garage_side   float    house: +1 or -1, which side the garage is on
##   variant       int      deterministic shape variation (trees, bags, houses)
static func build(kind: StringName, parent: Node3D, params := {}) -> Node3D:
	var model := Node3D.new()
	model.name = "Model"
	parent.add_child(model)

	var b: RefCounted = LPB.new()
	match kind:
		&"shopping_cart":
			_shopping_cart(b, params)
		&"minivan":
			_minivan(b, params)
		&"recycling_bin":
			_recycling_bin(b, params)
		&"garbage_bag":
			_garbage_bag(b, params)
		&"patio_chair":
			_patio_chair(b, params)
		&"lawn_sign":
			_lawn_sign(b, params)
		&"lamp_post":
			_lamp_post(b, params)
		&"dumpster":
			_dumpster(b, params)
		&"tree_deciduous":
			_tree_deciduous(b, params)
		&"tree_conifer":
			_tree_conifer(b, params)
		&"house":
			_house(b, params)
		&"fence_panel":
			_fence_panel(b, params)
		&"mailbox":
			_mailbox(b, params)
		&"gnome":
			_gnome(b, params)
		&"trampoline":
			_trampoline(b, params)
		&"kiddie_pool":
			_kiddie_pool(b, params)
		&"bbq":
			_bbq(b, params)
		&"hydrant":
			_hydrant(b, params)
		&"bench":
			_bench(b, params)
		&"cattail":
			_cattail(b, params)
		&"stop_sign":
			_stop_sign(b, params)
		&"hedge":
			_hedge(b, params)
		&"basketball_hoop":
			_basketball_hoop(b, params)
		&"basketball":
			_basketball(b, params)
		&"fly_agaric":
			_fly_agaric(b, params)
		_:
			_fallback(b, params)

	model.set_meta("tri_count", b.tri_count)
	LPB.attach(model, b.commit(), shared_material(), "Shell")

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
# error ("Cannot infer the type of x"). Funnelling every read through these two
# helpers keeps that mistake out of the twenty build functions below.
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
# Cross-section helpers.
#
# Almost everything man-made in this file is a rectangle with the corners taken
# off, lofted between two sizes. Chamfering matters more than it sounds: a
# faceted box with square corners reads as a box no matter how you shade it,
# and one 3 cm chamfer per corner turns it into an object.
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


## Vertical cross-section at depth [param z]: a chamfered rectangle in XY, with
## independent bottom and top chamfers. The asymmetry is what lets a vehicle
## section have a soft sill and a hard shoulder in one call.
static func _ring_z(z: float, y_lo: float, y_hi: float, hw: float,
		cham_lo: float, cham_hi: float) -> PackedVector3Array:
	var span := maxf(y_hi - y_lo, 0.001)
	var cl := minf(cham_lo, minf(hw, span) * 0.45)
	var ch := minf(cham_hi, minf(hw, span) * 0.45)
	return PackedVector3Array([
		Vector3(-hw + cl, y_lo, z), Vector3(hw - cl, y_lo, z),
		Vector3(hw, y_lo + cl, z), Vector3(hw, y_hi - ch, z),
		Vector3(hw - ch, y_hi, z), Vector3(-hw + ch, y_hi, z),
		Vector3(-hw, y_hi - ch, z), Vector3(-hw, y_lo + cl, z)])


## Centroid of a ring, used as the `inside` reference for capping.
static func _centroid(r: PackedVector3Array) -> Vector3:
	var c := Vector3.ZERO
	for v in r:
		c += v
	return c / float(maxi(r.size(), 1))


## Loft a chain of rings with the faces pointing INWARD, toward the axis.
##
## LowPolyBuilder's loft() always turns faces away from the spine, which is
## right for the outside of an object and wrong for the inside of an open one.
## A basket, a bin and a pool are all hollow: you look down into them and, with
## backface culling on, an outward-facing far wall simply is not there. So the
## inner shell gets its winding reference mirrored through each face — the
## normal ends up pointing back at the axis and the cavity renders solid.
static func _loft_inward(b: RefCounted, rings: Array, axis: Array, col) -> void:
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
			var c: Color = col.call(cen) if col is Callable else col
			b.quad(p0, p1, p2, p3, c, cen + (cen - mid))


## Cap a ring that lies perpendicular to [param axis_dir], with the winding
## reference pushed far enough along that axis that the ring's own radius
## cannot overturn the sign.
##
## THIS IS THE SUBTLE ONE, AND IT COST TWO RENDER ROUNDS TO FIND.
##
## LowPolyBuilder picks a face's winding from dot(normal, centroid - inside).
## On a near-horizontal fan the normal is almost vertical while
## (centroid - inside) is dominated by the RADIUS, so a reference point one
## metre under a one-metre disc leaves the sign of that dot product up to
## which side of the ring the face happens to sit on. The result is a disc
## that is culled along a diameter: exactly half of it renders.
##
## The kiddie pool and the trampoline both lost their entire near side to
## this, and the failure is invisible from the far side, which is why it
## survived to round three. Put the reference two hundred radii away and the
## axial term wins on every face of the ring.
static func _cap_axial(b: RefCounted, r: PackedVector3Array, apex: Vector3,
		axis_dir: Vector3, col) -> void:
	b.cap(r, apex, _far_ref(r, axis_dir), col)


## A flat ring-to-ring band perpendicular to [param axis_dir] — a bin rim, a
## trampoline pad, a pool lip. Same winding hazard as _cap_axial, same cure.
static func _annulus(b: RefCounted, outer: PackedVector3Array, inner: PackedVector3Array,
		axis_dir: Vector3, col: Color) -> void:
	var n: int = mini(outer.size(), inner.size())
	var inside := _far_ref(outer, axis_dir)
	for j in n:
		var k := (j + 1) % n
		b.quad(outer[j], outer[k], inner[k], inner[j], col, inside)


## A point far enough behind [param r] along -axis_dir that every face of the
## ring agrees on which way is out.
static func _far_ref(r: PackedVector3Array, axis_dir: Vector3) -> Vector3:
	var c := _centroid(r)
	var far := 0.0
	for v in r:
		far = maxf(far, (v - c).length())
	return c - axis_dir.normalized() * (far * 200.0 + 10.0)


## A short faceted cylinder lying on the X axis: a wheel, a castor, a roller.
## Capped with a dished hub so the wheel face catches light instead of reading
## as a flat disc.
static func _wheel(b: RefCounted, centre: Vector3, radius: float, half_width: float,
		sides: int, tyre: Color, hub: Color, detailed := false) -> void:
	var ci := centre + Vector3(-half_width, 0, 0)
	var co := centre + Vector3(half_width, 0, 0)
	var phase := PI / float(sides)
	var ri := LPB.ring(ci, Vector3.RIGHT, Vector3.UP, radius, radius, sides, phase)
	var ro := LPB.ring(co, Vector3.RIGHT, Vector3.UP, radius, radius, sides, phase)
	b.loft([ri, ro], [ci, co], tyre)
	# Winding reference sits well inboard of each face, so `inside` is dominated
	# by its axial component. Put it on the wheel centre instead and the radius
	# wins, and every sidewall face turns to point outward radially.
	var in_out := co - Vector3(4.0, 0, 0)
	var in_in := ci + Vector3(4.0, 0, 0)
	if not detailed:
		b.cap(ro, co + Vector3(half_width * 0.25, 0, 0), in_out, hub)
		b.cap(ri, ci - Vector3(half_width * 0.25, 0, 0), in_in, hub)
		return
	# Outboard face gets the real treatment: a dark sidewall down to the rim,
	# then a small dished hub cap. The inboard face is never seen, so it stays
	# a flat fan and costs `sides` triangles instead of three times that.
	var rim := LPB.ring(co + Vector3(0.012, 0, 0), Vector3.RIGHT, Vector3.UP,
		radius * 0.50, radius * 0.50, sides, phase)
	b.loft([ro, rim], [in_out, in_out], tyre.lightened(0.05))
	b.cap(rim, co + Vector3(half_width * 0.40, 0, 0), in_out, hub)
	b.cap(ri, ci - Vector3(half_width * 0.20, 0, 0), in_in, tyre)


## A raised wheel-arch eyebrow: an arc swept over the wheel and extruded
## outward from the body side. Four steps is enough — this is a silhouette cue
## read at 15 m, not a piece of close-up modelling.
static func _arch(b: RefCounted, centre: Vector3, radius: float,
		x_in: float, x_out: float, steps: int, col: Color) -> void:
	var pin := PackedVector3Array()
	var pout := PackedVector3Array()
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var a := PI * t
		var y := centre.y + sin(a) * radius
		var z := centre.z + cos(a) * radius
		pin.append(Vector3(x_in, y, z))
		pout.append(Vector3(x_out, y, z))
	var ref := Vector3((x_in + x_out) * 0.5, centre.y, centre.z)
	for i in steps:
		b.quad(pin[i], pin[i + 1], pout[i + 1], pout[i], col, ref)


## A square-section strut between two arbitrary points. Boxes can only be axis
## aligned or basis-rotated about one axis; a strut following a wall that
## tapers in two directions at once needs a real lofted tube, and that is what
## made the first pass of the shopping cart's wire ribs float off the basket.
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


# ===========================================================================
# 1. SHOPPING CART — the game's signature prop
# ===========================================================================

const C_STEEL := Color(0.74, 0.75, 0.78)
const C_STEEL_DARK := Color(0.52, 0.54, 0.58)
const C_CART_HANDLE := Color(0.72, 0.18, 0.16)

## The basket in four stations, nose (-Z) to handle (+Z). A real cart's basket
## is a wedge: narrow and shallow at the nose so carts nest, wide and deep at
## the handle end. That taper IS the read — a straight-sided basket looks like
## a milk crate on wheels no matter how good the handle is.
##   z, floor y, rim y, floor half-width, rim half-width
const CART_BASKET := [
	[-0.600, 0.370, 0.575, 0.225, 0.288],
	[-0.200, 0.388, 0.680, 0.268, 0.338],
	[ 0.230, 0.406, 0.756, 0.296, 0.372],
	[ 0.590, 0.418, 0.792, 0.302, 0.384],
]

const CART_WALL := 0.038


static func _shopping_cart(b: RefCounted, params: Dictionary) -> void:
	var steel := _col(params, "colour", C_STEEL)
	var dark := steel.darkened(0.28)
	var lip := steel.lightened(0.12)

	# Eight corner points per station. Written out rather than built from the
	# ring helpers because the basket is a container, not a tube: the outside,
	# the rim and the inside all need different winding, and naming the corners
	# is the only way to keep that legible.
	var fl := []   # outer floor, left
	var fr := []   # outer floor, right
	var rl := []   # outer rim, left
	var rr := []   # outer rim, right
	var ifl := []  # inner floor, left
	var ifr := []
	var irl := []  # inner rim, left
	var irr := []
	var axis := []
	for row in CART_BASKET:
		var z: float = row[0]
		var fy: float = row[1]
		var ry: float = row[2]
		var fw: float = row[3]
		var rw: float = row[4]
		fl.append(Vector3(-fw, fy, z))
		fr.append(Vector3(fw, fy, z))
		rl.append(Vector3(-rw, ry, z))
		rr.append(Vector3(rw, ry, z))
		ifl.append(Vector3(-(fw - CART_WALL), fy + CART_WALL, z))
		ifr.append(Vector3(fw - CART_WALL, fy + CART_WALL, z))
		irl.append(Vector3(-(rw - CART_WALL), ry, z))
		irr.append(Vector3(rw - CART_WALL, ry, z))
		axis.append(Vector3(0, (fy + ry) * 0.5, z))

	var n := CART_BASKET.size()
	for i in range(n - 1):
		var a0: Vector3 = axis[i]
		var a1: Vector3 = axis[i + 1]
		var mid := (a0 + a1) * 0.5
		var below := Vector3(mid.x, mid.y - 3.0, mid.z)
		var above := Vector3(mid.x, mid.y + 3.0, mid.z)
		# Outer skin.
		b.quad(fr[i], fr[i + 1], rr[i + 1], rr[i], steel, mid)
		b.quad(fl[i], fl[i + 1], rl[i + 1], rl[i], steel, mid)
		b.quad(fl[i], fr[i], fr[i + 1], fl[i + 1], steel.darkened(0.14), above)
		# Inner skin: winding reference mirrored through the wall so the cavity
		# renders solid when you look down into it.
		var cr: Vector3 = (ifr[i] + ifr[i + 1] + irr[i + 1] + irr[i]) * 0.25
		b.quad(ifr[i], ifr[i + 1], irr[i + 1], irr[i], dark, cr + (cr - mid))
		var cl: Vector3 = (ifl[i] + ifl[i + 1] + irl[i + 1] + irl[i]) * 0.25
		b.quad(ifl[i], ifl[i + 1], irl[i + 1], irl[i], dark, cl + (cl - mid))
		b.quad(ifl[i], ifr[i], ifr[i + 1], ifl[i + 1], dark, below)
		# Rim lip — the brightest line on the cart and most of the basket read.
		b.quad(rr[i], rr[i + 1], irr[i + 1], irr[i], lip, below)
		b.quad(rl[i], rl[i + 1], irl[i + 1], irl[i], lip, below)

	# Nose and tail end walls.
	for e in [0, n - 1]:
		var i: int = e
		var out_dir := -1.0 if i == 0 else 1.0
		var mid: Vector3 = axis[i]
		var outside := mid + Vector3(0, 0, out_dir * 3.0)
		var below := Vector3(0, mid.y - 3.0, mid.z)
		b.quad(fl[i], fr[i], rr[i], rl[i], steel, mid)
		b.quad(ifl[i], ifr[i], irr[i], irl[i], dark, outside)
		b.quad(rl[i], rr[i], irr[i], irl[i], lip, below)
		b.quad(fl[i], fr[i], ifr[i], ifl[i], dark, below)

	# --- corner posts, built from the real corner points so they lie ON the
	# sloped wall instead of floating off it ---
	for e in [0, n - 1]:
		var i: int = e
		for sx in [-1.0, 1.0]:
			var bot: Vector3 = fr[i] if sx > 0.0 else fl[i]
			var top: Vector3 = rr[i] if sx > 0.0 else rl[i]
			_strut(b, bot, top, 0.017, lip)

	# --- two horizontal wire bands, offset outward along the wall ---
	# The bands are what turn a solid trough into a wire basket at a distance.
	for band in [0.34, 0.72]:
		var t: float = band
		for i in range(n - 1):
			for sx in [-1.0, 1.0]:
				var f0: Vector3 = fr[i] if sx > 0.0 else fl[i]
				var r0v: Vector3 = rr[i] if sx > 0.0 else rl[i]
				var f1: Vector3 = fr[i + 1] if sx > 0.0 else fl[i + 1]
				var r1v: Vector3 = rr[i + 1] if sx > 0.0 else rl[i + 1]
				_strut(b, f0.lerp(r0v, t) + Vector3(sx * 0.011, 0, 0),
					f1.lerp(r1v, t) + Vector3(sx * 0.011, 0, 0), 0.013, lip)

	# --- chassis: two side rails under the basket, carrying the castors ---
	for sx in [-1.0, 1.0]:
		var xx: float = sx
		b.box(Vector3(xx * 0.268, 0.330, 0.02), Vector3(0.020, 0.024, 0.520), C_STEEL_DARK)
		for sz in [-1.0, 1.0]:
			var zz: float = sz
			b.box(Vector3(xx * 0.268, 0.205, zz * 0.470),
				Vector3(0.019, 0.130, 0.019), C_STEEL_DARK)
		# Diagonal brace from the rear castor up to the basket, the classic
		# cart profile line.
		_strut(b, Vector3(xx * 0.268, 0.100, 0.470), Vector3(xx * 0.290, 0.400, 0.180),
			0.016, C_STEEL_DARK)

	# --- lower rack, hung off the rails ---
	b.box(Vector3(0, 0.200, 0.02), Vector3(0.268, 0.014, 0.470), steel.darkened(0.14))
	for i in 4:
		b.box(Vector3(-0.20 + float(i) * 0.135, 0.216, 0.02),
			Vector3(0.011, 0.010, 0.462), steel)

	# --- castors ---
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var zz: float = sz
			_wheel(b, Vector3(sx * 0.275, 0.062, zz * 0.455), 0.062, 0.022, 6,
				Color(0.16, 0.16, 0.18), Color(0.60, 0.62, 0.64))

	# --- handle: two uprights and a red grip bar, raked back over the tail ---
	for sx in [-1.0, 1.0]:
		b.box(Vector3(sx * 0.330, 0.875, 0.578), Vector3(0.016, 0.115, 0.016), steel)
	b.box(Vector3(0, 0.978, 0.594), Vector3(0.360, 0.024, 0.024), C_CART_HANDLE)
	# Child-seat flap, folded down against the back of the basket.
	b.box(Vector3(0, 0.700, 0.516), Vector3(0.250, 0.100, 0.014), steel.darkened(0.06),
		Basis(Vector3.RIGHT, deg_to_rad(-18.0)))


# ===========================================================================
# 2. MINIVAN — the biggest visual win in the lot
# ===========================================================================

## Lower body, front bumper (-Z) to rear bumper (+Z). Eight stations: the nose
## tuck, the pull over the front arches, the long flat door run, and the slight
## narrowing into the tail. Get this table wrong and no amount of wheels or
## glass rescues it.
##   z, sill y, shoulder y, half-width, sill chamfer, shoulder chamfer
const VAN_BODY := [
	[-2.30, 0.42, 0.80, 0.80, 0.10, 0.16],
	[-2.12, 0.30, 0.92, 0.92, 0.12, 0.14],
	[-1.70, 0.26, 1.00, 1.01, 0.14, 0.12],
	[-0.80, 0.24, 1.04, 1.05, 0.14, 0.10],
	[ 0.60, 0.24, 1.05, 1.05, 0.14, 0.10],
	[ 1.62, 0.26, 1.04, 1.03, 0.14, 0.12],
	[ 2.12, 0.32, 0.98, 0.95, 0.12, 0.14],
	[ 2.30, 0.44, 0.86, 0.84, 0.10, 0.16],
]

## The greenhouse. The rake comes from the 0.62 m of run between station 0 (the
## cowl, low and forward) and station 1 (the top of the A-pillar) — that is a
## ~45 degree windscreen and it is most of what says "van" rather than "brick".
##   z, base y, roof y, half-width, base chamfer, roof chamfer
const VAN_CABIN := [
	[-1.42, 0.94, 1.08, 0.78, 0.04, 0.06],
	[-0.80, 0.94, 1.66, 0.90, 0.04, 0.14],
	[ 0.30, 0.94, 1.86, 0.95, 0.04, 0.18],
	[ 1.48, 0.94, 1.84, 0.94, 0.04, 0.18],
	[ 2.04, 0.94, 1.54, 0.87, 0.04, 0.14],
]

const C_GLASS := Color(0.20, 0.26, 0.30)
const C_TYRE := Color(0.11, 0.11, 0.12)
const C_TRIM := Color(0.17, 0.17, 0.19)


static func _minivan(b: RefCounted, params: Dictionary) -> void:
	var paint := _col(params, "body_colour", Color(0.62, 0.16, 0.16))

	# --- lower body ---
	var rings := []
	var spine := []
	for row in VAN_BODY:
		var z: float = row[0]
		var y_lo: float = row[1]
		var y_hi: float = row[2]
		var hw: float = row[3]
		var cl: float = row[4]
		var ch: float = row[5]
		rings.append(_ring_z(z, y_lo, y_hi, hw, cl, ch))
		spine.append(Vector3(0, (y_lo + y_hi) * 0.5, z))
	_loft_painted(b, rings, spine, paint, 0)
	_cap_painted(b, rings[0], Vector3(0, 0.62, -2.29), spine[1], paint, 0)
	_cap_painted(b, rings[rings.size() - 1], Vector3(0, 0.66, 2.29),
		spine[spine.size() - 2], paint, 0)

	# --- greenhouse ---
	var crings := []
	var cspine := []
	for row in VAN_CABIN:
		var z: float = row[0]
		var y_lo: float = row[1]
		var y_hi: float = row[2]
		var hw: float = row[3]
		var cl: float = row[4]
		var ch: float = row[5]
		crings.append(_ring_z(z, y_lo, y_hi, hw, cl, ch))
		cspine.append(Vector3(0, (y_lo + y_hi) * 0.5, z))
	_loft_painted(b, crings, cspine, paint, 1)
	# Cowl cap is buried in the bonnet; the tailgate cap is real glass.
	b.cap(crings[0], Vector3(0, 1.02, -1.48), cspine[1], paint)
	_cap_painted(b, crings[crings.size() - 1], Vector3(0, 1.26, 2.12),
		cspine[cspine.size() - 2], paint, 1)

	# --- wheels and arches ---
	for sz in [-1.0, 1.0]:
		var zz: float = sz
		for sx in [-1.0, 1.0]:
			var xx: float = sx
			_wheel(b, Vector3(xx * 0.90, 0.34, zz * 1.48), 0.34, 0.115, 7,
				C_TYRE, Color(0.68, 0.69, 0.72), true)
			_arch(b, Vector3(0, 0.34, zz * 1.48), 0.47, xx * 0.99, xx * 1.06, 5, C_TRIM)

	# --- door shut lines ---
	# Thin proud strips rather than a painted band: at 20 m a colour change on a
	# one-metre-wide facet is invisible, a geometric seam is not.
	for sx in [-1.0, 1.0]:
		var xx: float = sx
		for sz in [-0.28, 0.92]:
			var zz: float = sz
			_strut(b, Vector3(xx * 1.056, 0.28, zz), Vector3(xx * 0.952, 1.74, zz),
				0.013, C_TRIM)

	# --- lamps, mirrors, grille ---
	for sx in [-1.0, 1.0]:
		var xx: float = sx
		b.box(Vector3(xx * 0.60, 0.80, -2.27), Vector3(0.21, 0.09, 0.035), Color(0.92, 0.91, 0.84))
		b.box(Vector3(xx * 0.64, 0.88, 2.27), Vector3(0.15, 0.19, 0.035), Color(0.70, 0.10, 0.09))
		b.box(Vector3(xx * 0.99, 1.16, -0.76), Vector3(0.06, 0.06, 0.04), C_TRIM)
	b.box(Vector3(0, 0.64, -2.28), Vector3(0.54, 0.11, 0.03), C_TRIM)

	# --- roof rails ---
	for sx in [-1.0, 1.0]:
		var xx: float = sx
		b.box(Vector3(xx * 0.72, 1.885, 0.42), Vector3(0.035, 0.030, 1.05), C_TRIM)


## Loft with a per-face paint decision.
##
## LowPolyBuilder's loft() accepts a Callable for exactly this, and that is how
## goose_visual_lowpoly.gd paints the chinstrap. It cannot be used here: a
## Callable to a static method needs a reference to this script, and the only
## ways to get one — `class_name` or a self-`preload` — either depend on an
## editor import pass having run or introduce a cyclic dependency. Neither is
## safe in a fresh checkout, so the loop is written out and the paint function
## called directly. `mode` picks which one.
static func _loft_painted(b: RefCounted, rings: Array, spine: Array,
		paint: Color, mode: int) -> void:
	for i in range(rings.size() - 1):
		var r0: PackedVector3Array = rings[i]
		var r1: PackedVector3Array = rings[i + 1]
		var n: int = mini(r0.size(), r1.size())
		var s0: Vector3 = spine[i]
		var s1: Vector3 = spine[i + 1]
		var mid := (s0 + s1) * 0.5
		for j in n:
			var k := (j + 1) % n
			var p0: Vector3 = r0[j]
			var p1: Vector3 = r0[k]
			var p2: Vector3 = r1[k]
			var p3: Vector3 = r1[j]
			var cen := (p0 + p1 + p2 + p3) * 0.25
			b.quad(p0, p1, p2, p3, _van_colour(cen, paint, mode), mid)


static func _cap_painted(b: RefCounted, r: PackedVector3Array, apex: Vector3,
		inside: Vector3, paint: Color, mode: int) -> void:
	var n := r.size()
	for j in n:
		var a: Vector3 = r[j]
		var c: Vector3 = r[(j + 1) % n]
		b.tri(a, c, apex, _van_colour((a + c + apex) / 3.0, paint, mode), inside)


## The minivan's entire paint scheme, decided per face from where the face sits.
##
## mode 0 — lower body: dark bumpers and a dark rocker below the sill line.
## mode 1 — greenhouse: a glass band between the beltline and the roof, with
##          the B and C pillars left in body colour so it reads as separate
##          windows rather than one wraparound strip.
##
## This is the argument for vertex colours in one function: the windscreen, the
## side glass, the quarter-lights, the tailgate window, both bumpers and the
## rocker are all free, with not one extra triangle.
static func _van_colour(p: Vector3, paint: Color, mode: int) -> Color:
	if mode == 0:
		if p.y < 0.34:
			return C_TRIM
		if absf(p.z) > 2.16 and p.y < 0.64:
			return C_TRIM
		return paint
	if p.y > 1.72 or p.y < 1.08:
		return paint
	if absf(p.z - 0.64) < 0.11 or absf(p.z + 0.30) < 0.10:
		return paint
	return C_GLASS


# ===========================================================================
# 3. RECYCLING BIN
# ===========================================================================

static func _recycling_bin(b: RefCounted, params: Dictionary) -> void:
	var blue := _col(params, "colour", Color(0.14, 0.32, 0.58))
	var lid := blue.darkened(0.22)

	# Tapered tub: narrow at the base so they stack, flaring to the rim.
	var y0 := 0.02
	var y1 := 1.04
	var r0 := _ring_y(y0, 0.375, 0.290, 0.075)
	var r1 := _ring_y(y1, 0.470, 0.364, 0.090)
	b.loft([r0, r1], [Vector3(0, y0, 0), Vector3(0, y1, 0)], blue)
	# Foot.
	var rf := _ring_y(0.0, 0.355, 0.272, 0.070)
	b.loft([rf, r0], [Vector3(0, 0, 0), Vector3(0, y0, 0)], blue.darkened(0.30))
	_cap_axial(b, rf, _centroid(rf), Vector3.DOWN, blue.darkened(0.35))

	# Moulded ribs. Two shallow flares are enough to break up the taper — a
	# smooth tapered tub reads as a plant pot.
	for i in 1:
		var y := 0.51 + float(i) * 0.34
		var t := (y - y0) / (y1 - y0)
		var hx := lerpf(0.375, 0.470, t)
		var hz := lerpf(0.290, 0.372, t)
		var a := _ring_y(y - 0.030, hx + 0.014, hz + 0.014, 0.080)
		var c := _ring_y(y + 0.030, hx + 0.014, hz + 0.014, 0.080)
		b.loft([a, c], [Vector3(0, y - 0.03, 0), Vector3(0, y + 0.03, 0)], blue.lightened(0.10))

	# Lid: an overhanging lip, a slightly domed top, and a moulded grab handle.
	var lip_lo := _ring_y(1.04, 0.492, 0.386, 0.092)
	var lip_hi := _ring_y(1.115, 0.498, 0.392, 0.094)
	var top := _ring_y(1.165, 0.430, 0.336, 0.084)
	b.loft([lip_lo, lip_hi, top], [Vector3(0, 1.04, 0), Vector3(0, 1.115, 0), Vector3(0, 1.165, 0)], lid)
	_cap_axial(b, top, Vector3(0, 1.215, 0), Vector3.UP, lid.lightened(0.08))
	# Grab handle on the front face.
	b.box(Vector3(0, 1.075, -0.372), Vector3(0.150, 0.038, 0.028), lid.lightened(0.14))
	for sx in [-1.0, 1.0]:
		b.box(Vector3(sx * 0.478, 0.86, 0.0), Vector3(0.030, 0.055, 0.100), lid.lightened(0.10))

	# The recycling chevron, as a flat badge on the front.
	b.box(Vector3(0, 0.70, -0.437), Vector3(0.130, 0.130, 0.012), Color(0.88, 0.90, 0.92))


# ===========================================================================
# 4. GARBAGE BAG
# ===========================================================================

## A sack is the one thing in this file that must NOT look manufactured. Rings
## are pushed around per-vertex by _wobble() and the whole stack leans, so it
## slumps. Six sides: any more and the facets stop reading as creases in
## plastic and start reading as a badly tessellated sphere.
const BAG_PROFILE := [
	[0.000, 0.160, 0.00],
	[0.075, 0.222, 0.02],
	[0.175, 0.238, 0.04],
	[0.290, 0.222, 0.06],
	[0.385, 0.165, 0.06],
	[0.455, 0.085, 0.05],
]


static func _garbage_bag(b: RefCounted, params: Dictionary) -> void:
	var col := _col(params, "colour", Color(0.13, 0.13, 0.15))
	var seed_v := _num(params, "variant", 0.0)
	var rings := []
	var spine := []
	for i in range(BAG_PROFILE.size()):
		var row: Array = BAG_PROFILE[i]
		var y: float = row[0]
		var r: float = row[1]
		var lean: float = row[2]
		var centre := Vector3(lean * 0.6, y, lean)
		spine.append(centre)
		var base := LPB.ring(centre, Vector3.UP, Vector3.FORWARD, r, r * 0.92, 6,
			PI / 6.0 + float(i) * 0.16)
		var lumpy := PackedVector3Array()
		for j in base.size():
			var p: Vector3 = base[j]
			var d := p - centre
			var k := 1.0 + 0.20 * _wobble(i, j, seed_v)
			lumpy.append(centre + Vector3(d.x * k, d.y + 0.018 * _wobble(i + 5, j, seed_v), d.z * k))
		rings.append(lumpy)
	b.loft(rings, spine, col)
	_cap_axial(b, rings[0], _centroid(rings[0]), Vector3.DOWN, col.darkened(0.25))

	# The gathered neck and its twist-tie: the single detail that turns a lump
	# into a bag of garbage.
	var top: PackedVector3Array = rings[rings.size() - 1]
	var neck := Vector3(0.05, 0.520, 0.05)
	_cap_axial(b, top, neck, Vector3.UP, col.lightened(0.06))
	b.box(neck, Vector3(0.030, 0.026, 0.030), Color(0.86, 0.84, 0.30))
	# Two ears of plastic flopping off the knot.
	for sx in [-1.0, 1.0]:
		b.box(neck + Vector3(sx * 0.052, 0.014, sx * 0.020),
			Vector3(0.048, 0.016, 0.032), col.lightened(0.12),
			Basis(Vector3.FORWARD, deg_to_rad(sx * 26.0)))


# ===========================================================================
# 5. PATIO CHAIR
# ===========================================================================

static func _patio_chair(b: RefCounted, params: Dictionary) -> void:
	var wood := _col(params, "colour", Color(0.42, 0.30, 0.22))
	var dark := wood.darkened(0.22)

	# Legs. Splayed very slightly so the chair doesn't read as four dowels.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var zz: float = sz
			b.box(Vector3(sx * 0.235, 0.215, zz * 0.230), Vector3(0.028, 0.215, 0.028), dark,
				Basis(Vector3.FORWARD, deg_to_rad(-sx * 3.0)))
	# Seat frame and three slats.
	b.box(Vector3(0, 0.452, 0), Vector3(0.250, 0.026, 0.245), dark)
	for i in 2:
		b.box(Vector3(0, 0.484, -0.105 + float(i) * 0.210),
			Vector3(0.245, 0.020, 0.080), wood)
	# Back uprights, raked.
	for sx in [-1.0, 1.0]:
		b.box(Vector3(sx * 0.235, 0.660, 0.255), Vector3(0.028, 0.225, 0.028), dark,
			Basis(Vector3.RIGHT, deg_to_rad(9.0)))
	# Back slats.
	for i in 2:
		var y := 0.640 + float(i) * 0.190
		b.box(Vector3(0, y, 0.238 + float(i) * 0.030), Vector3(0.235, 0.058, 0.020), wood,
			Basis(Vector3.RIGHT, deg_to_rad(9.0)))
	# Top rail, chamfered so the crest catches light instead of going flat.
	b.box(Vector3(0, 0.872, 0.288), Vector3(0.250, 0.036, 0.026), wood.lightened(0.08),
		Basis(Vector3.RIGHT, deg_to_rad(9.0)))



# ===========================================================================
# 6. LAWN SIGN
# ===========================================================================

static func _lawn_sign(b: RefCounted, params: Dictionary) -> void:
	var panel := _col(params, "colour", Color(0.92, 0.86, 0.20))
	var ink := _col(params, "ink_colour", Color(0.16, 0.20, 0.34))

	# Corrugated panel: a chamfered slab so the edges catch light. Leaning back
	# a couple of degrees, because a perfectly upright lawn sign looks placed
	# rather than hammered in.
	# Leaning back four degrees, because a perfectly upright lawn sign looks
	# placed rather than hammered in. Authored flat from y=0 and then tilted, so
	# the lean is one transform instead of a rewrite of every coordinate.
	var lean := Basis(Vector3.RIGHT, deg_to_rad(-5.0))
	var xf := Transform3D(lean, Vector3(0, 0.360, 0))
	var lo := _ring_y(0.0, 0.530, 0.018, 0.016)
	var hi := _ring_y(0.420, 0.530, 0.018, 0.016)
	_transformed_loft(b, [lo, hi], [Vector3.ZERO, Vector3(0, 0.420, 0)], panel, xf)
	_transformed_cap(b, hi, Vector3(0, 0.420, 0), Vector3(0, -120.0, 0), panel.lightened(0.06), xf)
	_transformed_cap(b, lo, Vector3.ZERO, Vector3(0, 120.0, 0), panel.darkened(0.12), xf)

	# Printed block: two bars of "text", flush on the front face.
	b.box(xf * Vector3(0, 0.290, -0.024), Vector3(0.430, 0.070, 0.008), ink, lean)
	b.box(xf * Vector3(0, 0.140, -0.024), Vector3(0.320, 0.042, 0.008), ink, lean)

	# Two wire legs and the cross-strut.
	var wire := Color(0.40, 0.41, 0.44)
	for sx in [-1.0, 1.0]:
		var xx: float = sx
		b.box(Vector3(xx * 0.290, 0.185, 0.020), Vector3(0.011, 0.185, 0.011), wire)
	b.box(Vector3(0, 0.315, 0.020), Vector3(0.300, 0.010, 0.010), wire)


## Loft a ring chain through a transform. Used where a part is easier to author
## upright and then tilt than to write out rotated by hand.
static func _transformed_loft(b: RefCounted, rings: Array, spine: Array, col, xf: Transform3D) -> void:
	var tr := []
	var ts := []
	for r in rings:
		var src: PackedVector3Array = r
		var out := PackedVector3Array()
		for p in src:
			out.append(xf * p)
		tr.append(out)
	for s in spine:
		var sp: Vector3 = s
		ts.append(xf * sp)
	b.loft(tr, ts, col)


static func _transformed_cap(b: RefCounted, r: PackedVector3Array, apex: Vector3,
		inside: Vector3, col, xf: Transform3D) -> void:
	var out := PackedVector3Array()
	for p in r:
		out.append(xf * p)
	b.cap(out, xf * apex, xf * inside, col)


# ===========================================================================
# 7. LAMP POST
# ===========================================================================

static func _lamp_post(b: RefCounted, params: Dictionary) -> void:
	var metal := _col(params, "colour", Color(0.34, 0.34, 0.36))
	var lamp := Color(0.95, 0.92, 0.74)

	# Base flare, then a long taper. The taper is the point: a constant-width
	# column is a stick, a tapered one is a lamp post even in silhouette.
	var b0 := LPB.ring(Vector3(0, 0.00, 0), Vector3.UP, Vector3.FORWARD, 0.185, 0.185, 6, PI / 6.0)
	var b1 := LPB.ring(Vector3(0, 0.30, 0), Vector3.UP, Vector3.FORWARD, 0.135, 0.135, 6, PI / 6.0)
	var b2 := LPB.ring(Vector3(0, 4.20, 0), Vector3.UP, Vector3.FORWARD, 0.105, 0.105, 6, PI / 6.0)
	var b3 := LPB.ring(Vector3(0, 7.70, 0), Vector3.UP, Vector3.FORWARD, 0.080, 0.080, 6, PI / 6.0)
	b.loft([b0, b1, b2, b3],
		[Vector3(0, 0, 0), Vector3(0, 0.30, 0), Vector3(0, 4.20, 0), Vector3(0, 7.70, 0)],
		metal)
	_cap_axial(b, b0, _centroid(b0), Vector3.DOWN, metal.darkened(0.35))
	# Access hatch near the base, where the real ones always are.
	b.box(Vector3(0, 0.85, -0.155), Vector3(0.070, 0.150, 0.020), metal.darkened(0.18))

	# Luminaire: a shallow trapezoidal head with a pale lens underside, sat on
	# a short arm. A cobra head is the wrong shape for a parking lot; this is
	# the flat "shoebox" fixture those lots actually use.
	b.box(Vector3(0, 7.86, 0), Vector3(0.075, 0.090, 0.075), metal)
	var head_lo := _ring_y(7.94, 0.560, 0.290, 0.070)
	var head_hi := _ring_y(8.14, 0.480, 0.250, 0.060)
	var head_top := _ring_y(8.22, 0.300, 0.170, 0.045)
	b.loft([head_lo, head_hi, head_top],
		[Vector3(0, 7.94, 0), Vector3(0, 8.14, 0), Vector3(0, 8.22, 0)], metal.darkened(0.12))
	_cap_axial(b, head_top, _centroid(head_top), Vector3.UP, metal.darkened(0.05))
	# The lens, facing down at the asphalt.
	_cap_axial(b, head_lo, _centroid(head_lo), Vector3.DOWN, lamp)


# ===========================================================================
# 8. DUMPSTER
# ===========================================================================

static func _dumpster(b: RefCounted, params: Dictionary) -> void:
	var steel := _col(params, "colour", Color(0.20, 0.36, 0.28))
	var lid := steel.darkened(0.32)

	# Straight skirt, then sides that slope outward all the way to the rim.
	var s0 := _ring_y(0.00, 1.44, 0.86, 0.10)
	var s1 := _ring_y(0.22, 1.46, 0.87, 0.10)
	var s2 := _ring_y(1.92, 1.74, 1.03, 0.14)
	b.loft([s0, s1, s2], [Vector3(0, 0, 0), Vector3(0, 0.22, 0), Vector3(0, 1.92, 0)], steel)
	_cap_axial(b, s0, _centroid(s0), Vector3.DOWN, steel.darkened(0.40))
	# Dark interior, so a raised lid shows a void rather than daylight.
	var inner := _ring_y(1.72, 1.66, 0.98, 0.13)
	_cap_axial(b, inner, _centroid(inner), Vector3.UP, Color(0.07, 0.07, 0.07))

	# Vertical stiffening ribs along the long sides.
	for i in 2:
		var z := -0.50 + float(i) * 1.00
		for sx in [-1.0, 1.0]:
			b.box(Vector3(sx * 1.63, 1.06, z), Vector3(0.030, 0.860, 0.075), steel.lightened(0.09),
				Basis(Vector3.FORWARD, deg_to_rad(-sx * 5.4)))
	# Top rail all the way round.
	var t0 := _ring_y(1.92, 1.76, 1.05, 0.14)
	var t1 := _ring_y(2.02, 1.76, 1.05, 0.14)
	b.loft([t0, t1], [Vector3(0, 1.92, 0), Vector3(0, 2.02, 0)], steel.lightened(0.14))

	# Forklift pockets on the long face.
	for sx in [-1.0, 1.0]:
		b.box(Vector3(sx * 0.62, 0.60, -1.00), Vector3(0.230, 0.100, 0.055), Color(0.10, 0.10, 0.11))

	# Two plastic lid halves hinged along the spine, the near one left ajar
	# because nobody has ever closed a dumpster lid properly.
	b.box(Vector3(0, 2.045, -0.51), Vector3(1.74, 0.045, 0.520), lid,
		Basis(Vector3.RIGHT, deg_to_rad(-2.5)))
	b.box(Vector3(0, 2.115, 0.53), Vector3(1.74, 0.045, 0.520), lid,
		Basis(Vector3.RIGHT, deg_to_rad(9.0)))
	for sx in [-1.0, 1.0]:
		var xx: float = sx
		b.box(Vector3(xx * 0.90, 2.075, -0.98), Vector3(0.150, 0.028, 0.042), lid.lightened(0.18))


# ===========================================================================
# 9. DECIDUOUS TREE
# ===========================================================================

## Three interpenetrating blobs, not one sphere. A single lump reads as a
## lollipop from every angle; three overlapping ones give the canopy an
## outline that changes as you orbit it, which is the only thing that makes a
## low-poly tree look like a tree.
##   centre x, y, z, radius x, radius y, phase
const CANOPY_BLOBS := [
	[ 0.10, 4.35, -0.05, 1.72, 1.62, 0.00],
	[-0.95, 3.80, 0.50, 1.32, 1.28, 0.62],
	[ 0.90, 3.95, -0.60, 1.26, 1.22, 1.24],
]


static func _tree_deciduous(b: RefCounted, params: Dictionary) -> void:
	var bark := _col(params, "colour", Color(0.34, 0.26, 0.20))
	var leaf := _col(params, "leaf_colour", Color(0.28, 0.36, 0.22))
	var seed_v := _num(params, "variant", 0.0)

	# Trunk: five-sided, tapering, with a slight lean so it isn't a pole.
	var trunk := []
	var tspine := []
	var prof := [[0.00, 0.30], [1.10, 0.22], [2.20, 0.175], [3.10, 0.145]]
	for i in range(prof.size()):
		var row: Array = prof[i]
		var y: float = row[0]
		var r: float = row[1]
		var centre := Vector3(0.055 * y, y, -0.035 * y)
		tspine.append(centre)
		trunk.append(LPB.ring(centre, Vector3.UP, Vector3.FORWARD, r, r, 5, PI / 5.0 + float(i) * 0.10))
	b.loft(trunk, tspine, bark)
	_cap_axial(b, trunk[0], _centroid(trunk[0]), Vector3.DOWN, bark.darkened(0.35))

	# Two branch stubs. They exist so the canopy has something to sit on — a
	# canopy floating above a bare trunk is the classic low-poly tree failure.
	var stubs := [
		[Vector3(0.13, 2.30, -0.08), Vector3(-1.05, 3.10, 0.42)],
		[Vector3(0.15, 2.62, -0.09), Vector3(0.95, 3.35, -0.55)],
	]
	for s in stubs:
		var pair: Array = s
		var a: Vector3 = pair[0]
		var c: Vector3 = pair[1]
		var dir := (c - a).normalized()
		var r0 := LPB.ring(a, dir, Vector3.UP, 0.11, 0.11, 4, PI * 0.25)
		var r1 := LPB.ring(c, dir, Vector3.UP, 0.055, 0.055, 4, PI * 0.25)
		b.loft([r0, r1], [a, c], bark)
		b.cap(r1, c + dir * 0.10, a, bark)

	# Canopy.
	for bi in range(CANOPY_BLOBS.size()):
		var row: Array = CANOPY_BLOBS[bi]
		var cx: float = row[0]
		var cy: float = row[1]
		var cz: float = row[2]
		var rx: float = row[3]
		var ry: float = row[4]
		var ph: float = row[5]
		_blob(b, Vector3(cx, cy, cz), rx, ry, ph, seed_v + float(bi), leaf, 5)


## An angular lump: two stacked rings plus a top and bottom cap, every vertex
## kicked around by _wobble so no two blobs share a silhouette.
static func _blob(b: RefCounted, centre: Vector3, rx: float, ry: float, phase: float,
		seed_v: float, col: Color, sides: int) -> void:
	var rings := []
	var spine := []
	var levels := [-0.62, -0.20, 0.22, 0.62]
	for i in range(levels.size()):
		var lv: float = levels[i]
		var y := centre.y + lv * ry
		var shrink := sqrt(maxf(1.0 - lv * lv, 0.04))
		var c := Vector3(centre.x, y, centre.z)
		spine.append(c)
		var base := LPB.ring(c, Vector3.UP, Vector3.FORWARD, rx * shrink, rx * shrink,
			sides, phase + float(i) * 0.42)
		var out := PackedVector3Array()
		for j in base.size():
			var p: Vector3 = base[j]
			var d := p - c
			var k := 1.0 + 0.24 * _wobble(i, j, seed_v)
			out.append(c + Vector3(d.x * k, d.y + ry * 0.16 * _wobble(i + 3, j, seed_v), d.z * k))
		rings.append(out)
	b.loft(rings, spine, col)
	_cap_axial(b, rings[rings.size() - 1], centre + Vector3(rx * 0.10, ry * 0.98, rx * 0.06),
		Vector3.UP, col.lightened(0.10))
	_cap_axial(b, rings[0], centre + Vector3(0, -ry * 0.92, 0), Vector3.DOWN, col.darkened(0.18))


# ===========================================================================
# 10. CONIFER
# ===========================================================================

static func _tree_conifer(b: RefCounted, params: Dictionary) -> void:
	var bark := _col(params, "colour", Color(0.30, 0.23, 0.18))
	var needle := _col(params, "leaf_colour", Color(0.16, 0.30, 0.19))

	# Trunk, mostly hidden but visible between the lowest tiers.
	var t0 := LPB.ring(Vector3(0, 0, 0), Vector3.UP, Vector3.FORWARD, 0.20, 0.20, 5, PI / 5.0)
	var t1 := LPB.ring(Vector3(0, 4.40, 0), Vector3.UP, Vector3.FORWARD, 0.09, 0.09, 5, PI / 5.0)
	b.loft([t0, t1], [Vector3.ZERO, Vector3(0, 4.40, 0)], bark)
	_cap_axial(b, t0, _centroid(t0), Vector3.DOWN, bark.darkened(0.35))

	# Four stacked tiers. Each overhangs the one above, which is what makes a
	# stepped cone read as a spruce instead of a traffic cone.
	#   base y, top y, base radius, top radius
	var tiers := [
		[0.75, 1.95, 1.30, 0.72],
		[1.80, 3.00, 1.12, 0.60],
		[2.85, 3.95, 0.90, 0.46],
		[3.80, 4.75, 0.66, 0.30],
	]
	for i in range(tiers.size()):
		var row: Array = tiers[i]
		var y0: float = row[0]
		var y1: float = row[1]
		var r0: float = row[2]
		var r1: float = row[3]
		var ph := PI / 6.0 + float(i) * 0.33
		var a := LPB.ring(Vector3(0, y0, 0), Vector3.UP, Vector3.FORWARD, r0, r0, 6, ph)
		var c := LPB.ring(Vector3(0, y1, 0), Vector3.UP, Vector3.FORWARD, r1, r1, 6, ph)
		var shade := needle.lightened(float(i) * 0.045)
		b.loft([a, c], [Vector3(0, y0, 0), Vector3(0, y1, 0)], shade)
		# Underside of the skirt, so you see dark green from below not daylight.
		_cap_axial(b, a, _centroid(a), Vector3.DOWN, needle.darkened(0.30))
	# Leader.
	var top := LPB.ring(Vector3(0, 4.75, 0), Vector3.UP, Vector3.FORWARD, 0.30, 0.30, 6, PI / 6.0)
	b.cap(top, Vector3(0, 5.95, 0), Vector3(0, 4.4, 0), needle.lightened(0.16))


# ===========================================================================
# 11. HOUSE — the second-biggest visual win
# ===========================================================================
#
# ORIENTATION: the front facade is at LOCAL -Z, matching zone_suburbia.gd,
# where `_static_box(pos, size, wall, rot)` with rot = atan2(pos.x, pos.z) puts
# the node's -Z along `front` (toward the road). The gable ridge runs front to
# back along Z, so the pitched triangle faces the street — same as the
# PrismMesh it replaces.

static func _house(b: RefCounted, params: Dictionary) -> void:
	var w := _num(params, "w", 10.0)
	var d := _num(params, "d", 8.0)
	var wall_h := _num(params, "wall_h", 3.2)
	var roof_h := _num(params, "roof_h", 2.0)
	var wall := _col(params, "wall_colour", Color(0.74, 0.68, 0.60))
	var roof := _col(params, "roof_colour", Color(0.30, 0.22, 0.18))
	var garage_side := _num(params, "garage_side", 1.0)

	var hw := w * 0.5
	var hd := d * 0.5
	var eave_x := hw * 1.08
	var eave_z := hd * 1.08
	var ridge_y := wall_h + roof_h

	# --- foundation and walls ---
	b.box(Vector3(0, 0.17, 0), Vector3(hw + 0.07, 0.17, hd + 0.07), wall.darkened(0.42))
	var wl := _ring_y(0.30, hw, hd, 0.0)
	var wh := _ring_y(wall_h, hw, hd, 0.0)
	b.loft([wl, wh], [Vector3(0, 0.30, 0), Vector3(0, wall_h, 0)], wall)
	# Corner boards: four thin pilasters that give the siding a scale cue.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var zz: float = sz
			b.box(Vector3(sx * hw, (wall_h + 0.3) * 0.5, zz * hd),
				Vector3(0.10, (wall_h - 0.3) * 0.5, 0.10), wall.lightened(0.16))

	# --- gable roof ---
	# Ridge along Z, eaves overhanging the walls on all four sides.
	var thick := 0.14
	var drop := Vector3(0, -thick, 0)
	# Three bands up each slope with a small fold between them. A single flat
	# quad per slope is what turned the away-facing pitch into a black void on
	# the first pass; three facets guarantee at least one of them catches a
	# light, and the fold is what shingled roofs actually do anyway.
	var bands := [0.0, 0.34, 0.70, 1.0]
	var sag := [0.0, 0.050, 0.032, 0.0]
	for sx in [-1.0, 1.0]:
		var sgn: float = sx
		for bi in range(bands.size() - 1):
			var t0: float = bands[bi]
			var t1: float = bands[bi + 1]
			var g0: float = sag[bi]
			var g1: float = sag[bi + 1]
			var x0: float = sgn * eave_x * (1.0 - t0)
			var x1: float = sgn * eave_x * (1.0 - t1)
			var y0: float = wall_h + roof_h * t0 - roof_h * g0
			var y1: float = wall_h + roof_h * t1 - roof_h * g1
			var shade := roof.lightened(0.06 + float(bi) * 0.13)
			var a := Vector3(x0, y0, -eave_z)
			var c := Vector3(x1, y1, -eave_z)
			var e := Vector3(x1, y1, eave_z)
			var f := Vector3(x0, y0, eave_z)
			b.quad(a, c, e, f, shade, Vector3(0, wall_h * 0.5, 0))
			b.quad(a + drop, c + drop, e + drop, f + drop,
				roof.darkened(0.34), Vector3(0, ridge_y + 3.0, 0))
			# Rake edges on this band.
			b.quad(a, c, c + drop, a + drop, roof.darkened(0.14),
				Vector3(0, wall_h + roof_h * 0.4, 0))
			b.quad(f, e, e + drop, f + drop, roof.darkened(0.14),
				Vector3(0, wall_h + roof_h * 0.4, 0))
			if bi == 0:
				# Eave fascia, only on the bottom band.
				b.quad(a, f, f + drop, a + drop, roof.lightened(0.09),
					Vector3(0, wall_h, 0))
	# Ridge cap.
	b.box(Vector3(0, ridge_y + 0.04, 0), Vector3(0.14, 0.06, eave_z), roof.lightened(0.14))

	# --- gable ends, in siding, tucked INSIDE the roof deck ---
	#
	# THE SEAM. This used to be one triangle from (±hw, wall_h) straight up to
	# the ridge. That line and the roof are two different curves — the roof
	# pitches sag in the middle (see `sag` above) and start 8% further out
	# (`eave_x`) — so they cross, and between the folds the siding erupted
	# through the shingles by up to 16 mm along the whole rake. Close up that
	# reads as a wall-coloured pinstripe lying on the roof.
	#
	# So the gable's top edge is sampled from the roof's OWN profile, at the
	# same fold points, and parked on the slab's mid-plane: always half a
	# thickness under the shingles and half a thickness above the soffit, at
	# every x, on every roof pitch in the cul-de-sac. The wall cannot intersect
	# the roof because it is now defined by it.
	var gx := [hw, eave_x * (1.0 - float(bands[1])), eave_x * (1.0 - float(bands[2])), 0.0]
	for sz in [-1.0, 1.0]:
		var z: float = sz * hd
		for side in [-1.0, 1.0]:
			var sd: float = side
			for gi2 in range(gx.size() - 1):
				var gx0: float = sd * float(gx[gi2])
				var gx1: float = sd * float(gx[gi2 + 1])
				var gy0 := _roof_mid_y(gx0, eave_x, wall_h, roof_h, thick, bands, sag)
				var gy1 := _roof_mid_y(gx1, eave_x, wall_h, roof_h, thick, bands, sag)
				b.quad(Vector3(gx0, wall_h, z), Vector3(gx1, wall_h, z),
					Vector3(gx1, gy1, z), Vector3(gx0, gy0, z),
					wall.lightened(0.05), Vector3(0, wall_h * 0.6, 0))

	# --- chimney, set back toward the yard side ---
	var cx := hw * 0.56 * garage_side
	var cz := hd * 0.24
	var chim_top := ridge_y + roof_h * 0.30
	var c0 := _ring_y(wall_h + roof_h * 0.20, 0.33, 0.33, 0.05)
	var c1 := _ring_y(chim_top, 0.30, 0.30, 0.05)
	var brick := Color(0.44, 0.29, 0.24)
	_translated_loft(b, [c0, c1],
		[Vector3(0, wall_h + roof_h * 0.20, 0), Vector3(0, chim_top, 0)],
		brick, Vector3(cx, 0, cz))
	b.box(Vector3(cx, chim_top + 0.05, cz), Vector3(0.38, 0.05, 0.38), brick.darkened(0.35))

	# --- front door, on the side opposite the garage ---
	var door_x := -garage_side * (w * 0.08)
	var fz := -hd - 0.02
	b.box(Vector3(door_x, 0.30 + wall_h * 0.30, fz), Vector3(0.52, wall_h * 0.30, 0.05),
		Color(0.32, 0.18, 0.14))
	# Casing.
	b.box(Vector3(door_x, 0.30 + wall_h * 0.30, fz + 0.02), Vector3(0.60, wall_h * 0.32, 0.03),
		wall.lightened(0.30))
	b.box(Vector3(door_x + garage_side * 0.36, 0.30 + wall_h * 0.28, fz - 0.03),
		Vector3(0.05, 0.05, 0.03), Color(0.84, 0.72, 0.32))
	# Step.
	b.box(Vector3(door_x, 0.16, fz - 0.30), Vector3(0.72, 0.16, 0.32), Color(0.66, 0.65, 0.62))
	# Porch light.
	b.box(Vector3(door_x - garage_side * 0.78, 0.30 + wall_h * 0.52, fz),
		Vector3(0.07, 0.11, 0.05), Color(0.94, 0.90, 0.70))

	# --- garage door, the side facing the road ---
	var gar_x := garage_side * (w * 0.30)
	var gar_hw := w * 0.17
	var gar_h := wall_h * 0.31
	b.box(Vector3(gar_x, 0.30 + gar_h, fz), Vector3(gar_hw, gar_h, 0.05), Color(0.86, 0.84, 0.80))
	for gi in 4:
		b.box(Vector3(gar_x, 0.34 + float(gi) * gar_h * 0.50, fz - 0.03),
			Vector3(gar_hw - 0.04, 0.020, 0.02), Color(0.60, 0.58, 0.55))
	b.box(Vector3(gar_x, 0.30 + gar_h * 2.0 + 0.07, fz + 0.01),
		Vector3(gar_hw + 0.08, 0.07, 0.05), wall.lightened(0.28))

	# --- windows ---
	var win_y := 0.30 + wall_h * 0.52
	_window(b, Vector3(-garage_side * (w * 0.34), win_y, fz), 0.42, 0.38, 0.0, wall)
	_window(b, Vector3(-garage_side * (w * 0.20), win_y, fz), 0.28, 0.34, 0.0, wall)
	# Attic vent in the gable.
	b.box(Vector3(0, wall_h + roof_h * 0.40, -hd - 0.03), Vector3(0.26, 0.26, 0.04),
		Color(0.30, 0.40, 0.44))
	b.box(Vector3(0, wall_h + roof_h * 0.40, -hd - 0.05), Vector3(0.28, 0.04, 0.03),
		wall.lightened(0.30))
	# One side window per house.
	_window(b, Vector3(hw + 0.02, win_y, hd * 0.20), 0.34, 0.36, -PI * 0.5, wall)

	# --- shutters, flanking the big front window ---
	for sx in [-1.0, 1.0]:
		var xx: float = sx
		b.box(Vector3(-garage_side * (w * 0.34) + xx * 0.55, win_y, fz + 0.01),
			Vector3(0.10, 0.38, 0.04), roof.lightened(0.18))


## Height of the roof slab's MID-PLANE directly above [param x], following the
## same banded, slightly-sagging profile the pitches themselves are built from.
##
## `bands`/`sag` are the tables in _house(); the pitch between two folds is a
## straight quad, so interpolating them linearly reproduces the roof surface
## exactly rather than approximating it. Subtract half the deck thickness and
## anything capped to this line is guaranteed to sit inside the slab.
static func _roof_mid_y(x: float, eave_x: float, wall_h: float, roof_h: float,
		thick: float, bands: Array, sag: Array) -> float:
	var t := clampf(1.0 - absf(x) / maxf(eave_x, 0.001), 0.0, 1.0)
	var g := float(sag[sag.size() - 1])
	for i in range(bands.size() - 1):
		var t0: float = bands[i]
		var t1: float = bands[i + 1]
		if t <= t1 or i == bands.size() - 2:
			var u: float = clampf((t - t0) / maxf(t1 - t0, 0.0001), 0.0, 1.0)
			g = lerpf(float(sag[i]), float(sag[i + 1]), u)
			break
	return wall_h + roof_h * (t - g) - thick * 0.5


## A window: recessed glass, a white frame and a single mullion cross. Kept to
## four boxes because there are up to eighteen of these on screen at once.
static func _window(b: RefCounted, pos: Vector3, hw: float, hh: float, yaw: float,
		wall: Color) -> void:
	var basis := Basis(Vector3.UP, yaw)
	var out := basis * Vector3(0, 0, -1)
	b.box(pos, Vector3(hw + 0.07, hh + 0.07, 0.035), wall.lightened(0.34), basis)
	b.box(pos + out * 0.012, Vector3(hw, hh, 0.030), Color(0.36, 0.50, 0.55), basis)
	b.box(pos + out * 0.030, Vector3(hw, 0.022, 0.020), Color(0.92, 0.92, 0.90), basis)
	b.box(pos + out * 0.030, Vector3(0.022, hh, 0.020), Color(0.92, 0.92, 0.90), basis)


## Loft a ring chain shifted by a constant offset. Cheaper to read than
## rewriting every ring's centre inline.
static func _translated_loft(b: RefCounted, rings: Array, spine: Array, col,
		offset: Vector3) -> void:
	var tr := []
	var ts := []
	for r in rings:
		var src: PackedVector3Array = r
		var out := PackedVector3Array()
		for p in src:
			out.append(p + offset)
		tr.append(out)
	for s in spine:
		var sp: Vector3 = s
		ts.append(sp + offset)
	b.loft(tr, ts, col)


# ===========================================================================
# 12. FENCE PANEL — tileable end to end
# ===========================================================================

static func _fence_panel(b: RefCounted, params: Dictionary) -> void:
	var wood := _col(params, "colour", Color(0.72, 0.66, 0.52))
	var rail := wood.darkened(0.24)
	var span := 2.20
	var pickets := 4
	var pitch := span / float(pickets)

	for i in pickets:
		var x := -span * 0.5 + pitch * (float(i) + 0.5)
		# Every board sits a hair differently, keyed off its index — a fence
		# built from identical boards reads as wallpaper.
		var lean := deg_to_rad(_wobble(i, 1, 0.0) * 1.6)
		var h := 1.52 + 0.03 * _wobble(i, 2, 0.0)
		var lo := _ring_y(0.0, 0.055, 0.028, 0.012)
		var hi := _ring_y(h, 0.055, 0.028, 0.012)
		var xf := Transform3D(Basis(Vector3.FORWARD, lean), Vector3(x, 0, 0))
		_transformed_loft(b, [lo, hi], [Vector3.ZERO, Vector3(0, h, 0)], wood, xf)
		# The dog-ear point on top: a cap to an apex, four triangles.
		_transformed_cap(b, hi, Vector3(0, h + 0.15, 0), Vector3(0, h - 60.0, 0),
			wood.lightened(0.10), xf)

	# Two rails on the back face.
	for i in 2:
		var y := 0.42 + float(i) * 0.78
		b.box(Vector3(0, y, 0.048), Vector3(span * 0.5, 0.055, 0.024), rail)
	# One post per panel, on the left end, so panels butt without doubling up.
	var p0 := _ring_y(0.0, 0.075, 0.075, 0.018)
	var p1 := _ring_y(1.66, 0.070, 0.070, 0.016)
	_translated_loft(b, [p0, p1], [Vector3.ZERO, Vector3(0, 1.66, 0)], rail.darkened(0.10),
		Vector3(-span * 0.5, 0, 0))
	b.box(Vector3(-span * 0.5, 1.695, 0), Vector3(0.088, 0.035, 0.088), rail.darkened(0.24))


# ===========================================================================
# 13. MAILBOX
# ===========================================================================

static func _mailbox(b: RefCounted, params: Dictionary) -> void:
	var body := _col(params, "colour", Color(0.20, 0.36, 0.58))

	# Tunnel section: flat floor, arched top, extruded front to back.
	var sect := PackedVector3Array([
		Vector3(-0.155, 0.000, 0), Vector3(0.155, 0.000, 0),
		Vector3(0.180, 0.075, 0), Vector3(0.140, 0.235, 0),
		Vector3(0.000, 0.290, 0), Vector3(-0.140, 0.235, 0),
		Vector3(-0.180, 0.075, 0),
	])
	var front := PackedVector3Array()
	var back := PackedVector3Array()
	for p in sect:
		front.append(p + Vector3(0, 0, -0.285))
		back.append(p + Vector3(0, 0, 0.285))
	b.loft([front, back], [Vector3(0, 0.14, -0.285), Vector3(0, 0.14, 0.285)], body)
	_cap_axial(b, back, _centroid(back), Vector3.BACK, body.darkened(0.14))
	# Hinged front door, set back a touch so it reads as a door.
	_cap_axial(b, front, _centroid(front), Vector3.FORWARD, body.lightened(0.10))
	b.box(Vector3(0, 0.135, -0.292), Vector3(0.115, 0.105, 0.012), body.darkened(0.28))
	b.box(Vector3(0, 0.055, -0.300), Vector3(0.045, 0.018, 0.014), Color(0.72, 0.72, 0.74))
	# The flag: up, because the joke only works if there is outgoing mail.
	b.box(Vector3(0.190, 0.150, 0.090), Vector3(0.014, 0.090, 0.014), Color(0.82, 0.16, 0.12))
	b.box(Vector3(0.190, 0.240, 0.115), Vector3(0.012, 0.055, 0.048), Color(0.82, 0.16, 0.12))


# ===========================================================================
# 14. GNOME
# ===========================================================================

static func _gnome(b: RefCounted, params: Dictionary) -> void:
	var coat := _col(params, "colour", Color(0.78, 0.16, 0.14))
	var skin := Color(0.90, 0.72, 0.60)
	var beard := Color(0.92, 0.92, 0.90)

	# Robe: a five-sided taper. A gnome is a cone with opinions.
	var g0 := LPB.ring(Vector3(0, 0.00, 0), Vector3.UP, Vector3.FORWARD, 0.135, 0.135, 5, PI / 5.0)
	var g1 := LPB.ring(Vector3(0, 0.17, 0), Vector3.UP, Vector3.FORWARD, 0.115, 0.115, 5, PI / 5.0)
	var g2 := LPB.ring(Vector3(0, 0.30, 0), Vector3.UP, Vector3.FORWARD, 0.078, 0.078, 5, PI / 5.0)
	b.loft([g0, g1, g2], [Vector3.ZERO, Vector3(0, 0.17, 0), Vector3(0, 0.30, 0)], coat)
	_cap_axial(b, g0, _centroid(g0), Vector3.DOWN, coat.darkened(0.40))

	# Head.
	var h0 := LPB.ring(Vector3(0, 0.32, 0), Vector3.UP, Vector3.FORWARD, 0.072, 0.072, 5, 0.3)
	var h1 := LPB.ring(Vector3(0, 0.40, 0), Vector3.UP, Vector3.FORWARD, 0.068, 0.068, 5, 0.3)
	b.loft([h0, h1], [Vector3(0, 0.32, 0), Vector3(0, 0.40, 0)], skin)
	# Beard, forward and down: it is the whole silhouette.
	b.box(Vector3(0, 0.315, -0.058), Vector3(0.062, 0.070, 0.028), beard)
	b.box(Vector3(0, 0.245, -0.048), Vector3(0.038, 0.048, 0.022), beard)
	b.box(Vector3(0, 0.385, -0.070), Vector3(0.014, 0.014, 0.014), skin.darkened(0.35))

	# Hat: a tall cone flopping forward.
	var hat := LPB.ring(Vector3(0, 0.405, 0), Vector3.UP, Vector3.FORWARD, 0.086, 0.086, 5, 0.3)
	b.cap(hat, Vector3(0.02, 0.545, -0.055), Vector3(0, 0.30, 0), coat)
	_cap_axial(b, hat, _centroid(hat), Vector3.DOWN, coat.darkened(0.30))


# ===========================================================================
# 15. TRAMPOLINE
# ===========================================================================

static func _trampoline(b: RefCounted, params: Dictionary) -> void:
	var frame := _col(params, "colour", Color(0.24, 0.25, 0.27))
	var mat_col := Color(0.13, 0.26, 0.42)
	var pad := Color(0.16, 0.34, 0.52)
	var radius := 1.90
	var sides := 10

	# Padded rim: an annulus with a short outer skirt.
	var outer_top := LPB.ring(Vector3(0, 0.66, 0), Vector3.UP, Vector3.FORWARD, radius, radius, sides, 0.0)
	var outer_bot := LPB.ring(Vector3(0, 0.54, 0), Vector3.UP, Vector3.FORWARD, radius * 0.99, radius * 0.99, sides, 0.0)
	var inner_top := LPB.ring(Vector3(0, 0.64, 0), Vector3.UP, Vector3.FORWARD, radius * 0.83, radius * 0.83, sides, 0.0)
	b.loft([outer_bot, outer_top], [Vector3(0, 0.54, 0), Vector3(0, 0.66, 0)], pad)
	_annulus(b, outer_top, inner_top, Vector3.UP, pad.lightened(0.12))

	# Mat, dished by 6 cm so it catches light as a surface rather than a hole.
	_cap_axial(b, inner_top, Vector3(0, 0.580, 0), Vector3.UP, mat_col)

	# Six angled legs and their feet.
	for i in 6:
		var a := TAU * float(i) / 6.0 + 0.26
		var rx := cos(a)
		var rz := sin(a)
		var top := Vector3(rx * radius * 0.93, 0.56, rz * radius * 0.93)
		var foot := Vector3(rx * radius * 1.02, 0.05, rz * radius * 1.02)
		var dir := (foot - top).normalized()
		var l0 := LPB.ring(top, dir, Vector3.UP, 0.050, 0.050, 4, PI * 0.25)
		var l1 := LPB.ring(foot, dir, Vector3.UP, 0.042, 0.042, 4, PI * 0.25)
		b.loft([l0, l1], [top, foot], frame)
		b.box(foot + Vector3(0, -0.020, 0), Vector3(0.090, 0.028, 0.090), frame.darkened(0.25))


# ===========================================================================
# 16. KIDDIE POOL
# ===========================================================================

static func _kiddie_pool(b: RefCounted, params: Dictionary) -> void:
	var shell := _col(params, "colour", Color(0.86, 0.30, 0.42))
	var water := Color(0.30, 0.62, 0.76)
	var radius := 1.25
	var sides := 10

	var floor_r := LPB.ring(Vector3(0, 0.01, 0), Vector3.UP, Vector3.FORWARD, radius * 0.76, radius * 0.76, sides, 0.0)
	var out_lo := LPB.ring(Vector3(0, 0.01, 0), Vector3.UP, Vector3.FORWARD, radius * 0.84, radius * 0.84, sides, 0.0)
	var out_hi := LPB.ring(Vector3(0, 0.27, 0), Vector3.UP, Vector3.FORWARD, radius, radius, sides, 0.0)
	var in_hi := LPB.ring(Vector3(0, 0.26, 0), Vector3.UP, Vector3.FORWARD, radius * 0.90, radius * 0.90, sides, 0.0)

	b.loft([out_lo, out_hi], [Vector3(0, 0.01, 0), Vector3(0, 0.27, 0)], shell)
	_annulus(b, out_hi, in_hi, Vector3.UP, shell.lightened(0.14))
	_loft_inward(b, [in_hi, floor_r], [Vector3(0, 0.26, 0), Vector3(0, 0.01, 0)], shell.darkened(0.14))
	_cap_axial(b, floor_r, Vector3(0, 0.005, 0), Vector3.UP, shell.darkened(0.24))
	# A shallow slick of water, just under the rim.
	var surf := LPB.ring(Vector3(0, 0.155, 0), Vector3.UP, Vector3.FORWARD, radius * 0.87, radius * 0.87, sides, 0.0)
	_cap_axial(b, surf, Vector3(0, 0.150, 0), Vector3.UP, water)


# ===========================================================================
# 17. BBQ
# ===========================================================================

static func _bbq(b: RefCounted, params: Dictionary) -> void:
	var body := _col(params, "colour", Color(0.18, 0.18, 0.20))
	var steel := Color(0.62, 0.63, 0.66)

	# Firebox.
	var f0 := _ring_y(0.44, 0.300, 0.180, 0.045)
	var f1 := _ring_y(0.68, 0.330, 0.200, 0.050)
	b.loft([f0, f1], [Vector3(0, 0.44, 0), Vector3(0, 0.68, 0)], body)
	_cap_axial(b, f0, _centroid(f0), Vector3.DOWN, body.darkened(0.30))

	# Domed lid: an arched section extruded across the width.
	var arc := PackedVector3Array([
		Vector3(0, 0.68, -0.200), Vector3(0, 0.80, -0.185),
		Vector3(0, 0.88, -0.110), Vector3(0, 0.905, 0.000),
		Vector3(0, 0.88, 0.110), Vector3(0, 0.80, 0.185),
		Vector3(0, 0.68, 0.200),
	])
	var la := PackedVector3Array()
	var lb := PackedVector3Array()
	for p in arc:
		la.append(p + Vector3(-0.330, 0, 0))
		lb.append(p + Vector3(0.330, 0, 0))
	b.loft([la, lb], [Vector3(-0.330, 0.76, 0), Vector3(0.330, 0.76, 0)], body.lightened(0.10))
	_cap_axial(b, la, _centroid(la), Vector3.LEFT, body)
	_cap_axial(b, lb, _centroid(lb), Vector3.RIGHT, body)
	b.box(Vector3(0, 0.945, -0.055), Vector3(0.140, 0.030, 0.030), steel)

	# Side shelf, control knobs, legs and a pair of wheels.
	b.box(Vector3(0.435, 0.700, 0), Vector3(0.115, 0.020, 0.170), steel.darkened(0.20))
	b.box(Vector3(0, 0.620, -0.215), Vector3(0.150, 0.026, 0.020), steel)
	for sx in [-1.0, 1.0]:
		b.box(Vector3(sx * 0.245, 0.230, -0.130), Vector3(0.026, 0.230, 0.026), body.darkened(0.20))
	b.box(Vector3(0, 0.230, 0.150), Vector3(0.250, 0.024, 0.026), body.darkened(0.20))
	for sx in [-1.0, 1.0]:
		_wheel(b, Vector3(sx * 0.245, 0.095, 0.150), 0.095, 0.028, 6, Color(0.12, 0.12, 0.13), steel)


# ===========================================================================
# 18. FIRE HYDRANT
# ===========================================================================

static func _hydrant(b: RefCounted, params: Dictionary) -> void:
	var red := _col(params, "colour", Color(0.82, 0.16, 0.10))
	var cap_c := red.darkened(0.22)

	# Base flange, barrel, shoulder.
	var r0 := LPB.ring(Vector3(0, 0.00, 0), Vector3.UP, Vector3.FORWARD, 0.150, 0.150, 6, PI / 6.0)
	var r1 := LPB.ring(Vector3(0, 0.07, 0), Vector3.UP, Vector3.FORWARD, 0.150, 0.150, 6, PI / 6.0)
	var r2 := LPB.ring(Vector3(0, 0.12, 0), Vector3.UP, Vector3.FORWARD, 0.105, 0.105, 6, PI / 6.0)
	var r3 := LPB.ring(Vector3(0, 0.52, 0), Vector3.UP, Vector3.FORWARD, 0.115, 0.115, 6, PI / 6.0)
	var r4 := LPB.ring(Vector3(0, 0.62, 0), Vector3.UP, Vector3.FORWARD, 0.088, 0.088, 6, PI / 6.0)
	b.loft([r0, r1, r2, r3, r4],
		[Vector3.ZERO, Vector3(0, 0.07, 0), Vector3(0, 0.12, 0), Vector3(0, 0.52, 0), Vector3(0, 0.62, 0)],
		red)
	_cap_axial(b, r0, _centroid(r0), Vector3.DOWN, red.darkened(0.40))
	# Bonnet and the pentagon operating nut.
	_cap_axial(b, r4, Vector3(0, 0.715, 0), Vector3.UP, cap_c)
	b.box(Vector3(0, 0.755, 0), Vector3(0.042, 0.045, 0.042), cap_c.darkened(0.20))
	# Steamer port at the front, two hose ports on the flanks.
	b.box(Vector3(0, 0.400, -0.118), Vector3(0.070, 0.070, 0.030), cap_c)
	for sx in [-1.0, 1.0]:
		b.box(Vector3(sx * 0.115, 0.330, 0.030), Vector3(0.028, 0.055, 0.055), cap_c)


# ===========================================================================
# 19. BENCH
# ===========================================================================

static func _bench(b: RefCounted, params: Dictionary) -> void:
	var wood := _col(params, "colour", Color(0.46, 0.32, 0.20))
	var iron := Color(0.20, 0.21, 0.23)

	# Three seat slats and two back slats, gapped so light gets through.
	for i in 3:
		b.box(Vector3(0, 0.430, -0.150 + float(i) * 0.150),
			Vector3(0.860, 0.024, 0.058), wood)
	for i in 2:
		b.box(Vector3(0, 0.600 + float(i) * 0.170, 0.215),
			Vector3(0.860, 0.062, 0.026), wood, Basis(Vector3.RIGHT, deg_to_rad(8.0)))
	# Cast-iron end frames.
	for sx in [-1.0, 1.0]:
		b.box(Vector3(sx * 0.845, 0.215, -0.150), Vector3(0.030, 0.215, 0.032), iron)
		b.box(Vector3(sx * 0.845, 0.215, 0.190), Vector3(0.030, 0.215, 0.032), iron)
		b.box(Vector3(sx * 0.845, 0.415, 0.020), Vector3(0.032, 0.026, 0.200), iron)
		b.box(Vector3(sx * 0.845, 0.640, 0.230), Vector3(0.030, 0.215, 0.026), iron,
			Basis(Vector3.RIGHT, deg_to_rad(8.0)))
		b.box(Vector3(sx * 0.845, 0.018, 0.020), Vector3(0.060, 0.018, 0.240), iron)


# ===========================================================================
# 20. CATTAIL
# ===========================================================================

static func _cattail(b: RefCounted, params: Dictionary) -> void:
	var green := _col(params, "colour", Color(0.36, 0.44, 0.22))
	var brown := Color(0.36, 0.22, 0.12)

	# Stem, leaning very slightly.
	var s0 := LPB.ring(Vector3(0, 0.00, 0), Vector3.UP, Vector3.FORWARD, 0.022, 0.022, 3, 0.0)
	var s1 := LPB.ring(Vector3(0.03, 0.90, 0.01), Vector3.UP, Vector3.FORWARD, 0.016, 0.016, 3, 0.0)
	b.loft([s0, s1], [Vector3.ZERO, Vector3(0.03, 0.90, 0.01)], green)

	# The head: the brown sausage everyone actually pictures.
	var c := Vector3(0.04, 1.06, 0.013)
	var h0 := LPB.ring(c + Vector3(0, -0.16, 0), Vector3.UP, Vector3.FORWARD, 0.030, 0.030, 5, 0.0)
	var h1 := LPB.ring(c, Vector3.UP, Vector3.FORWARD, 0.048, 0.048, 5, 0.0)
	var h2 := LPB.ring(c + Vector3(0, 0.16, 0), Vector3.UP, Vector3.FORWARD, 0.032, 0.032, 5, 0.0)
	b.loft([h0, h1, h2], [c + Vector3(0, -0.16, 0), c, c + Vector3(0, 0.16, 0)], brown)
	b.cap(h0, c + Vector3(0, -0.21, 0), c, brown.darkened(0.20))
	b.cap(h2, c + Vector3(0.01, 0.24, 0), c, brown.lightened(0.10))
	# Two blade leaves, splaying out and arching over.
	for i in 2:
		var sgn := 1.0 if i == 0 else -1.0
		var base := Vector3(0, 0.02, 0)
		var tip := Vector3(sgn * 0.12, 0.86, sgn * 0.09)
		var dir := (tip - base).normalized()
		var l0 := LPB.ring(base, dir, Vector3.UP, 0.032, 0.008, 4, 0.0)
		var l1 := LPB.ring(base.lerp(tip, 0.55), dir, Vector3.UP, 0.026, 0.007, 4, 0.0)
		var l2 := LPB.ring(tip, dir, Vector3.UP, 0.008, 0.004, 4, 0.0)
		b.loft([l0, l1, l2], [base, base.lerp(tip, 0.55), tip], green.lightened(0.08))


# ===========================================================================
# 21. STOP SIGN — the one the goose spawns three metres from
# ===========================================================================
#
# ORIENTATION: the face is at local -Z, like every other model in this project.
# The zone yaws it to point back up the entrance corridor.
#
# The white ring is not decoration. A flat red octagon at 10 m reads as "a red
# thing"; the border is what makes the silhouette say STOP before the letters
# are legible, which is the entire design of the real sign.

const SIGN_R := 0.36            ## vertex radius of the octagon
const SIGN_Z := 0.024           ## half thickness of the placard
const SIGN_Y := 1.90            ## centre height above the base
## The placard is bolted to the FRONT of the post, not centred on it. The first
## render had the post running straight down the middle of the face, splitting
## the O from the P. 75 mm forward puts the whole octagon clear of it.
const SIGN_ZC := -0.075


static func _stop_sign(b: RefCounted, params: Dictionary) -> void:
	var red := _col(params, "colour", Color(0.78, 0.12, 0.10))
	var white := Color(0.96, 0.95, 0.93)
	var post := Color(0.44, 0.45, 0.48)
	var c := Vector3(0, SIGN_Y, SIGN_ZC)

	# --- post: a U-channel sign post, tapering, with a bolted foot ---
	var q0 := _ring_y(0.00, 0.062, 0.038, 0.014)
	var q1 := _ring_y(0.12, 0.050, 0.030, 0.012)
	var q2 := _ring_y(2.10, 0.042, 0.026, 0.010)
	b.loft([q0, q1, q2],
		[Vector3.ZERO, Vector3(0, 0.12, 0), Vector3(0, 2.10, 0)], post)
	_cap_axial(b, q0, _centroid(q0), Vector3.DOWN, post.darkened(0.40))
	_cap_axial(b, q2, _centroid(q2), Vector3.UP, post.darkened(0.20))
	# Ground collar — the little dome of dirt every roadside post is set in.
	var e0 := _ring_y(0.00, 0.150, 0.140, 0.045)
	var e1 := _ring_y(0.055, 0.105, 0.100, 0.032)
	b.loft([e0, e1], [Vector3.ZERO, Vector3(0, 0.055, 0)], Color(0.34, 0.31, 0.27))
	_cap_axial(b, e1, Vector3(0, 0.062, 0), Vector3.UP, Color(0.38, 0.35, 0.30))

	# --- the octagon ---
	# phase = PI/8 puts an EDGE at top, bottom, left and right. Without it the
	# sign stands on a point and stops being a stop sign.
	var ph := PI / 8.0
	var front := c + Vector3(0, 0, -SIGN_Z)
	var back := c + Vector3(0, 0, SIGN_Z)
	var f_out := LPB.ring(front, Vector3.BACK, Vector3.UP, SIGN_R, SIGN_R, 8, ph)
	var b_out := LPB.ring(back, Vector3.BACK, Vector3.UP, SIGN_R, SIGN_R, 8, ph)
	# Rim first: lofting back -> front puts the spine inside the placard, so the
	# eight edge faces turn outward on their own.
	b.loft([b_out, f_out], [back, front], red.darkened(0.30))
	# Back of the sign: bare galvanised aluminium, which is what you actually
	# see from three of the four approaches to this junction.
	_cap_axial(b, b_out, back, Vector3.BACK, Color(0.62, 0.63, 0.66))
	# Face: red field, white border ring, red centre.
	var f_mid := LPB.ring(front, Vector3.BACK, Vector3.UP, SIGN_R * 0.90, SIGN_R * 0.90, 8, ph)
	var f_in := LPB.ring(front, Vector3.BACK, Vector3.UP, SIGN_R * 0.79, SIGN_R * 0.79, 8, ph)
	_annulus(b, f_out, f_mid, Vector3.FORWARD, red)
	_annulus(b, f_mid, f_in, Vector3.FORWARD, white)
	_cap_axial(b, f_in, front, Vector3.FORWARD, red)

	# --- S T O P, in bars ---
	# Real glyphs would be forty triangles each. These are stroke rectangles at
	# the right weight and spacing, which is what the eye resolves at the only
	# distance anyone reads this from.
	#
	# MIRRORED ON PURPOSE. The face is at -Z, so a viewer standing in front of
	# it has +X on their LEFT: laying the word out in ascending x renders a
	# perfect "POTS". The first render read exactly that. `mx` flips the whole
	# block, glyph positions and stroke offsets together.
	var lz := SIGN_ZC - SIGN_Z - 0.010
	var lh := 0.082          # half letter height
	var lw := 0.045          # half letter width
	var st := 0.014          # half stroke
	var mx := -1.0
	var xs := [-0.1875, -0.0625, 0.0625, 0.1875]
	_glyph_s(b, Vector3(mx * float(xs[0]), SIGN_Y, lz), lw, lh, st, mx, white)
	_glyph_t(b, Vector3(mx * float(xs[1]), SIGN_Y, lz), lw, lh, st, mx, white)
	_glyph_o(b, Vector3(mx * float(xs[2]), SIGN_Y, lz), lw, lh, st, mx, white)
	_glyph_p(b, Vector3(mx * float(xs[3]), SIGN_Y, lz), lw, lh, st, mx, white)

	# The strap that closes the 25 mm gap between the placard and the post, and
	# two carriage-bolt heads on the face.
	b.box(Vector3(0, SIGN_Y, SIGN_ZC + SIGN_Z + 0.013), Vector3(0.052, 0.24, 0.014),
		post.darkened(0.15))
	for sy in [-0.20, 0.20]:
		var yy: float = sy
		b.box(c + Vector3(0, yy, -SIGN_Z - 0.012), Vector3(0.020, 0.020, 0.012),
			Color(0.55, 0.56, 0.58))


## Glyphs are authored in reading space and placed through [param m], which is
## -1 on a face that points at -Z. Only the x OFFSETS are mirrored; the half
## extents stay positive, because LowPolyBuilder.box() picks its winding from
## the corner order and a negative half turns the letter inside out.
static func _glyph_s(b: RefCounted, p: Vector3, w: float, h: float, s: float,
		m: float, col: Color) -> void:
	b.box(p + Vector3(0, h - s, 0), Vector3(w, s, 0.008), col)
	b.box(p, Vector3(w, s, 0.008), col)
	b.box(p + Vector3(0, -h + s, 0), Vector3(w, s, 0.008), col)
	b.box(p + Vector3(m * (-w + s), (h - s) * 0.5, 0),
		Vector3(s, (h - s) * 0.5 - s, 0.008), col)
	b.box(p + Vector3(m * (w - s), -(h - s) * 0.5, 0),
		Vector3(s, (h - s) * 0.5 - s, 0.008), col)


static func _glyph_t(b: RefCounted, p: Vector3, w: float, h: float, s: float,
		_m: float, col: Color) -> void:
	b.box(p + Vector3(0, h - s, 0), Vector3(w, s, 0.008), col)
	b.box(p, Vector3(s, h, 0.008), col)


static func _glyph_o(b: RefCounted, p: Vector3, w: float, h: float, s: float,
		_m: float, col: Color) -> void:
	b.box(p + Vector3(0, h - s, 0), Vector3(w, s, 0.008), col)
	b.box(p + Vector3(0, -h + s, 0), Vector3(w, s, 0.008), col)
	b.box(p + Vector3(-w + s, 0, 0), Vector3(s, h - s, 0.008), col)
	b.box(p + Vector3(w - s, 0, 0), Vector3(s, h - s, 0.008), col)


static func _glyph_p(b: RefCounted, p: Vector3, w: float, h: float, s: float,
		m: float, col: Color) -> void:
	b.box(p + Vector3(m * (-w + s), 0, 0), Vector3(s, h, 0.008), col)
	b.box(p + Vector3(0, h - s, 0), Vector3(w, s, 0.008), col)
	b.box(p + Vector3(0, 0.10 * h, 0), Vector3(w, s, 0.008), col)
	b.box(p + Vector3(m * (w - s), (h + 0.10 * h) * 0.5, 0),
		Vector3(s, (h - 0.10 * h) * 0.5 - s, 0.008), col)


# ===========================================================================
# 22. HEDGE — twelve of these line the front walks
# ===========================================================================

static func _hedge(b: RefCounted, params: Dictionary) -> void:
	var leaf := _col(params, "colour", Color(0.16, 0.32, 0.14))
	var seed_v := _num(params, "variant", 0.0)

	# Mulch bed, so the hedge grows out of something instead of resting on grass.
	b.box(Vector3(0, 0.028, 0), Vector3(0.74, 0.028, 0.27), Color(0.22, 0.16, 0.12))

	# The loaf. Wider in the middle than at either end, and every ring nudged
	# by _wobble so no two facets agree — a clipped hedge is nearly a box, and
	# the only thing separating it from one is that the surface is never flat.
	var ys := [0.045, 0.20, 0.40, 0.57, 0.68]
	var hxs := [0.68, 0.77, 0.80, 0.73, 0.46]
	var hzs := [0.21, 0.27, 0.30, 0.26, 0.15]
	var rings: Array = []
	var spine: Array = []
	for i in ys.size():
		var y: float = ys[i]
		var r := _ring_y(y, float(hxs[i]), float(hzs[i]), 0.09)
		rings.append(_lumpy(r, 0.034, seed_v + float(i) * 1.7))
		spine.append(Vector3(0, y, 0))
	# Sun on top, shade at the base, without a second material.
	b.loft(rings, spine, func(p: Vector3) -> Color:
		return leaf.lightened(clampf(p.y * 0.34, 0.0, 0.24)).darkened(
			clampf(0.18 - p.y * 0.26, 0.0, 0.18)))
	var top: PackedVector3Array = rings[rings.size() - 1]
	_cap_axial(b, top, Vector3(0, 0.735, 0), Vector3.UP, leaf.lightened(0.26))
	var bot: PackedVector3Array = rings[0]
	_cap_axial(b, bot, _centroid(bot), Vector3.DOWN, leaf.darkened(0.45))

	# Three sprigs nobody trimmed.
	for i in 3:
		var t := (float(i) + 0.5) / 3.0
		var x := lerpf(-0.58, 0.58, t) + _wobble(i, 5, seed_v) * 0.10
		var z := _wobble(i, 9, seed_v) * 0.12
		var base := Vector3(x, 0.64, z)
		var tip := base + Vector3(_wobble(i, 2, seed_v) * 0.09, 0.13, _wobble(i, 4, seed_v) * 0.07)
		_strut(b, base, tip, 0.014, leaf.lightened(0.14))


## Push every vertex of a ring out (or in) along its own radius by a
## deterministic amount, and jog it vertically. Keyed off the vertex index so
## the same hedge is the same hedge every run.
static func _lumpy(r: PackedVector3Array, amp: float, seed_v: float) -> PackedVector3Array:
	var c := _centroid(r)
	var out := PackedVector3Array()
	for i in r.size():
		var v: Vector3 = r[i]
		var d := Vector3(v.x - c.x, 0.0, v.z - c.z)
		var n := d.normalized() if d.length_squared() > 1e-6 else Vector3.ZERO
		out.append(v + n * (_wobble(i, 3, seed_v) * amp)
			+ Vector3(0, _wobble(i, 7, seed_v) * amp * 0.55, 0))
	return out


# ===========================================================================
# 23. BASKETBALL HOOP — pole, backboard, faceted rim, net
# ===========================================================================
#
# Replaces a 3.2 m grey box, a white decal slab and a TorusMesh. The torus was
# the only curved primitive left in the suburbia build and it shaded nothing
# like the rest of the street.
#
# ORIENTATION: board and rim at local -Z, matching the zone's `front`.

static func _basketball_hoop(b: RefCounted, params: Dictionary) -> void:
	var metal := _col(params, "colour", Color(0.30, 0.30, 0.32))
	var board := Color(0.90, 0.90, 0.93)
	var paint := Color(0.80, 0.22, 0.16)
	var rim_c := Color(0.90, 0.38, 0.08)
	var net := Color(0.93, 0.93, 0.89)

	# --- pole ---
	var p0 := _ring_y(0.00, 0.100, 0.100, 0.028)
	var p1 := _ring_y(0.14, 0.078, 0.078, 0.022)
	var p2 := _ring_y(2.40, 0.066, 0.066, 0.019)
	var p3 := _ring_y(3.28, 0.056, 0.056, 0.016)
	b.loft([p0, p1, p2, p3],
		[Vector3.ZERO, Vector3(0, 0.14, 0), Vector3(0, 2.40, 0), Vector3(0, 3.28, 0)], metal)
	_cap_axial(b, p0, _centroid(p0), Vector3.DOWN, metal.darkened(0.40))
	_cap_axial(b, p3, _centroid(p3), Vector3.UP, metal.darkened(0.18))

	# --- two arms out to the board ---
	for sy in [2.80, 3.22]:
		var yy: float = sy
		_strut(b, Vector3(0, yy, -0.05), Vector3(0, yy - 0.04, -0.30), 0.032, metal)

	# --- backboard ---
	var bz := -0.345
	var f_back := _ring_z(bz + 0.026, 2.625, 3.375, 0.55, 0.045, 0.045)
	var f_front := _ring_z(bz - 0.026, 2.625, 3.375, 0.55, 0.045, 0.045)
	b.loft([f_back, f_front],
		[Vector3(0, 3.0, bz + 0.026), Vector3(0, 3.0, bz - 0.026)], board.darkened(0.10))
	_cap_axial(b, f_front, Vector3(0, 3.0, bz - 0.026), Vector3.FORWARD, board)
	_cap_axial(b, f_back, Vector3(0, 3.0, bz + 0.026), Vector3.BACK, board.darkened(0.28))
	# Painted border and the shooter's square.
	var fz := bz - 0.032
	for sy2 in [2.665, 3.335]:
		var yy2: float = sy2
		b.box(Vector3(0, yy2, fz), Vector3(0.545, 0.026, 0.008), paint)
	for sx in [-1.0, 1.0]:
		var xx: float = sx
		b.box(Vector3(xx * 0.524, 3.0, fz), Vector3(0.026, 0.345, 0.008), paint)
	for sy3 in [2.760, 3.075]:
		var yy3: float = sy3
		b.box(Vector3(0, yy3, fz), Vector3(0.175, 0.020, 0.008), paint)
	for sx2 in [-1.0, 1.0]:
		var xx2: float = sx2
		b.box(Vector3(xx2 * 0.156, 2.918, fz), Vector3(0.020, 0.178, 0.008), paint)

	# --- rim: ten struts round a circle, which is a torus you can actually
	# facet-shade. Hung off a short bracket so it isn't floating. ---
	var rim_c3 := Vector3(0, 2.700, bz - 0.255)
	var rr := 0.225
	var seg := 10
	b.box(Vector3(0, 2.712, bz - 0.045), Vector3(0.055, 0.030, 0.045), rim_c)
	var pts := PackedVector3Array()
	for i in seg:
		var a := TAU * float(i) / float(seg)
		pts.append(rim_c3 + Vector3(sin(a) * rr, 0, cos(a) * rr))
	for i in seg:
		_strut(b, pts[i], pts[(i + 1) % seg], 0.020, rim_c)
	# --- net: six strands drawn in to a small mouth ---
	for i in 6:
		var a2 := TAU * float(i) / 6.0 + 0.2
		var top := rim_c3 + Vector3(sin(a2) * rr * 0.94, -0.01, cos(a2) * rr * 0.94)
		var bot := rim_c3 + Vector3(sin(a2) * rr * 0.42, -0.34, cos(a2) * rr * 0.42)
		_strut(b, top, bot, 0.010, net)


# ===========================================================================
# 24. BASKETBALL
# ===========================================================================

static func _basketball(b: RefCounted, params: Dictionary) -> void:
	var skin := _col(params, "colour", Color(0.78, 0.36, 0.10))
	var r := 0.205
	var c := Vector3(0, 0.21, 0)
	var lats := [0.30, 0.62, 0.88, 1.0, 0.88, 0.62, 0.30]
	var rings: Array = []
	var spine: Array = []
	# CONSTANT ring phase. The first pass rotated each band by PI/7 so the
	# facets spiralled, and the painted seam then caught an arbitrary triangle
	# out of every quad — the ball rendered as orange-and-black harlequin. With
	# the phase fixed the quads stack into clean vertical columns, which is
	# what makes a seven-sided sphere read as round at all.
	for i in lats.size():
		var f: float = lats[i]
		var y := c.y - r * cos(PI * float(i + 1) / float(lats.size() + 1))
		var rad := r * f
		rings.append(LPB.ring(Vector3(0, y, 0), Vector3.UP, Vector3.FORWARD, rad, rad, 7,
			PI / 7.0))
		spine.append(Vector3(0, y, 0))
	b.loft(rings, spine, func(p: Vector3) -> Color:
		return skin.darkened(clampf((c.y - p.y) * 0.55, 0.0, 0.22)))
	var top: PackedVector3Array = rings[rings.size() - 1]
	var bot: PackedVector3Array = rings[0]
	b.cap(top, Vector3(0, c.y + r, 0), c, skin.lightened(0.08))
	b.cap(bot, Vector3(0, c.y - r, 0), c, skin.darkened(0.26))


# ===========================================================================
# 25. FLY AGARIC — the fairy ring, and the fly agaric SOURCE
# ===========================================================================
#
# Replaces the SphereMesh hemisphere + box stem + six flat decal slabs in
# zone_suburbia.gd::_mushroom(). It was the last curved primitive left in that
# zone and it is not background dressing: the fly agaric pickup sits in the
# middle of this ring, so the player walks right up to it.
#
# Authored at FULL SIZE — one metre across. The zone scales each mushroom in
# the ring down to 0.4-0.6, exactly as the old code scaled its SphereMesh.
#
# ---------------------------------------------------------------------------
# THE SPOTS HAVE A HISTORY — read this before you touch them
# ---------------------------------------------------------------------------
# An earlier pass emitted the white spots at exactly the cap radius. That put
# every one of them ON the cap's surface, which on a faceted cap means INSIDE
# it, and the render came back with a plain red mushroom. It is in
# docs/HANDOFF.md's list of bugs that only a render ever found.
#
# The cure here is not "nudge them out a bit". The cap is an 8-sided solid of
# revolution, so its flats sit up to one SAGITTA below the ideal surface:
#
#     sagitta = R * (1 - cos(PI / sides))          = 3.81 cm at R 0.50, 8 sides
#
# Every spot is therefore placed by evaluating the cap's own ellipsoid, and
# then pushed out by *more than the sagitta*, with its skirt buried by more
# than the sagitta as well so there is no gap around its edge. Retune the cap
# profile or the facet count and the spots follow, because both numbers are
# derived rather than typed in. See _agaric_spot().

## The cap is an analytic squashed ellipsoid of revolution rather than the
## profile table the rest of this file uses, and that is deliberate: it is what
## lets a spot be placed at a known point on the surface with a known normal
## instead of by eye.
const AGARIC_CAP_C := Vector3(0.0, 0.470, 0.0)
const AGARIC_CAP_R := 0.500      ## horizontal semi-axis
const AGARIC_CAP_H := 0.390      ## vertical semi-axis
## Ten, not eight. The facet sagitta is what a spot has to clear to stay
## visible (see _agaric_spot), and it falls from 3.8 cm to 2.5 cm between the
## two — which is the difference between a fleck and a fin.
const AGARIC_SIDES := 10

## Polar angle of each cap ring, skirt first so loft() runs bottom to top. The
## first entry is past 90 degrees on purpose — a rim that turns back under
## itself is the whole difference between a mushroom cap and a dome.
const AGARIC_RINGS := [104.0, 88.0, 68.0, 46.0, 24.0]


## A point on the cap. [param theta_deg] is measured from straight up.
static func _agaric_surface(theta_deg: float, phi: float) -> Vector3:
	var t := deg_to_rad(theta_deg)
	return AGARIC_CAP_C + Vector3(
		sin(t) * cos(phi) * AGARIC_CAP_R,
		cos(t) * AGARIC_CAP_H,
		sin(t) * sin(phi) * AGARIC_CAP_R)


## Outward normal at that point. This is the gradient of the ellipsoid, NOT the
## radial direction from the centre — on a cap squashed to 0.78 of its width
## those differ by up to 14 degrees, which is enough to tip a spot on the
## shoulder back into the skin.
static func _agaric_normal(theta_deg: float, phi: float) -> Vector3:
	var t := deg_to_rad(theta_deg)
	return Vector3(
		sin(t) * cos(phi) / AGARIC_CAP_R,
		cos(t) / AGARIC_CAP_H,
		sin(t) * sin(phi) / AGARIC_CAP_R).normalized()


## One raised white wart.
##
## The pad is a cone whose skirt is BURIED in the cap and whose apex stands
## PROUD of it, both by more than the facet sagitta. Burying the skirt is what
## stops a gap opening round the edge of the spot at low camera angles; the
## proud apex is what stops the spot vanishing into a flat.
static func _agaric_spot(b: RefCounted, theta_deg: float, phi: float, r: float,
		col: Color) -> void:
	var sag := AGARIC_CAP_R * (1.0 - cos(PI / float(AGARIC_SIDES)))
	var p := _agaric_surface(theta_deg, phi)
	var n := _agaric_normal(theta_deg, phi)
	# The skirt ring lies in the tangent plane, so its vertices climb back out
	# by about r*r/(2R) as they leave the contact point — hence the margin.
	var bury := sag + r * r / (2.0 * AGARIC_CAP_R) + 0.012
	var proud := sag + 0.010
	var base := p - n * bury
	var up := Vector3.UP if absf(n.y) < 0.90 else Vector3.FORWARD
	var ring := LPB.ring(base, n, up, r, r, 5, 0.4)
	b.cap(ring, p + n * proud, base - n * (r * 40.0 + 4.0), col)


static func _fly_agaric(b: RefCounted, params: Dictionary) -> void:
	var cap_c := _col(params, "colour", Color(0.84, 0.13, 0.10))
	var stem_c := Color(0.95, 0.93, 0.86)
	var gill_c := Color(0.90, 0.86, 0.76)
	var spot_c := Color(0.97, 0.97, 0.94)
	var seed_v := _num(params, "variant", 0.0)

	# --- stem: bulbous at the base, waisted, flaring back out into the cap ---
	var sy := [0.000, 0.090, 0.360, 0.500]
	var sr := [0.125, 0.098, 0.078, 0.098]
	var s_rings: Array = []
	var s_spine: Array = []
	for i in sy.size():
		var y: float = sy[i]
		var r: float = sr[i]
		s_rings.append(LPB.ring(Vector3(0, y, 0), Vector3.UP, Vector3.FORWARD, r, r, 6, PI / 6.0))
		s_spine.append(Vector3(0, y, 0))
	b.loft(s_rings, s_spine, stem_c)
	_cap_axial(b, s_rings[0], _centroid(s_rings[0]), Vector3.DOWN, stem_c.darkened(0.35))
	_cap_axial(b, s_rings[3], _centroid(s_rings[3]), Vector3.UP, gill_c.darkened(0.12))

	# --- cap ---
	var rings: Array = []
	var spine: Array = []
	for i in AGARIC_RINGS.size():
		var th: float = AGARIC_RINGS[i]
		var ring := PackedVector3Array()
		for j in AGARIC_SIDES:
			ring.append(_agaric_surface(th, TAU * float(j) / float(AGARIC_SIDES)))
		rings.append(ring)
		spine.append(Vector3(0, _agaric_surface(th, 0.0).y, 0))
	b.loft(rings, spine, func(p: Vector3) -> Color:
		# A little darker down in the turned-under rim, which is where a real
		# cap holds its colour, and paler over the crown where the sun hits.
		return cap_c.lightened(clampf((p.y - 0.40) * 0.34, 0.0, 0.14)))
	var top: PackedVector3Array = rings[rings.size() - 1]
	_cap_axial(b, top, Vector3(0, AGARIC_CAP_C.y + AGARIC_CAP_H, 0), Vector3.UP,
		cap_c.lightened(0.16))
	# Gills: the underside is a shallow dish, not a hole. It is genuinely
	# visible — a goose stands 0.6 m tall and these are 0.4 m mushrooms.
	_cap_axial(b, rings[0], Vector3(0, 0.455, 0), Vector3.DOWN, gill_c)

	# --- spots ---
	# Seven, spread by the golden angle so they never queue up along a facet
	# seam, and sized off _wobble so each mushroom in the ring is its own.
	# Theta is capped at 58 degrees on purpose: past the shoulder a raised pad
	# is seen edge-on and breaks the silhouette as a white fin instead of
	# reading as a fleck. It is also where the camera in this game never is.
	for i in 7:
		var th2 := 16.0 + 42.0 * fmod(float(i) * 0.37 + seed_v * 0.13, 1.0)
		var ph2 := TAU * fmod(float(i) * 0.6180339 + seed_v * 0.21, 1.0)
		_agaric_spot(b, th2, ph2, 0.078 + 0.022 * absf(_wobble(i, 5, seed_v)), spot_c)


# ===========================================================================
# Fallback
# ===========================================================================

## Unknown kind: a faceted crate. Never invisible, never mistaken for finished.
static func _fallback(b: RefCounted, params: Dictionary) -> void:
	var col := _col(params, "colour", Color(0.62, 0.58, 0.50))
	var lo := _ring_y(0.0, 0.42, 0.42, 0.07)
	var hi := _ring_y(0.84, 0.42, 0.42, 0.07)
	b.loft([lo, hi], [Vector3.ZERO, Vector3(0, 0.84, 0)], col)
	_cap_axial(b, hi, _centroid(hi), Vector3.UP, col.lightened(0.10))
	_cap_axial(b, lo, _centroid(lo), Vector3.DOWN, col.darkened(0.20))
