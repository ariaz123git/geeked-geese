extends RefCounted
## TRUCK STOP MODEL LIBRARY — the props the shared library doesn't have.
##
## Same idiom and the same public API as scripts/world/prop_models.gd:
##
##     PropModelsTruckstop.build(kind, parent, params) -> Node3D
##     PropModelsTruckstop.has_model(kind) -> bool
##     PropModelsTruckstop.footprint(kind, params) -> Vector3
##
## Plus one thing neither of the other libraries has, because neither of the
## other zones is made of signage:
##
##     PropModelsTruckstop.sign_text(parent, text, origin, normal, up, h, col)
##     PropModelsTruckstop.text_width(text, h)
##
## Polygons only. No SphereMesh, no CylinderMesh, no curved primitives. All
## colour lives in VERTEX COLOURS against one white material, so the whole lot
## is two materials and a per-face paint decision costs nothing.
##
## ---------------------------------------------------------------------------
## THE ANCHORING CONTRACT — identical to the other two libraries
## ---------------------------------------------------------------------------
## Every model here is BASE-ANCHORED: local origin on the ground at the centre
## of the footprint, growing up +Y. BoxShape3D colliders are CENTRED. So a
## model hung under a collider of height h always drops by -h * 0.5. Miss it
## and the whole lot hovers.
##
## ---------------------------------------------------------------------------
## -Z IS FORWARD, AND THAT IS WHY THIS FILE HAS A FONT IN IT
## ---------------------------------------------------------------------------
## The tractor's grille is at -Z. The trailer's kingpin is at -Z and its roll-up
## doors are at +Z. That much is the project convention and it is uncontroversial.
##
## The consequence is not. A sign's FRONT face has an outward normal of (0,0,-1),
## which means a viewer reading it is standing at -Z looking along +Z — and for
## that viewer, **world +X runs right to left across the screen.** Lay glyphs out
## along +X on that face and you ship a stop sign that reads POTS and a trailer
## that reads ƎƆIVЯƎƧ. Both of those have actually shipped in this project.
##
## `sign_text()` computes the advance direction as `up x normal`, which is the
## on-screen right of any flat face regardless of which way it points, and every
## lettered surface in the truck stop goes through it. There is exactly one place
## to get this wrong and it is eleven lines long.
##
## ---------------------------------------------------------------------------
## THE SECOND MATERIAL — same reason the cottage library has one
## ---------------------------------------------------------------------------
## This is a NIGHT zone, in rain, and the truck stop is the only light for eleven
## kilometres. A sodium lens, a diner window, a fuel-pump display, a trailer's
## conspicuity tape and forty amber marker lights are not objects that are lit,
## they are the objects doing the lighting. So every build function gets TWO
## builders:
##
##     b   the normal shell, vertex colour, shaded like everything else
##     e   the GLOW shell, vertex colour, SHADING_MODE_UNSHADED
##
## The glow mesh is only attached when it has triangles, so a model with no light
## source costs exactly one MeshInstance3D.
##
## The paired OmniLight3D that actually spills onto the world is the ZONE's job.
## Six rigs carrying their own lights would blow the GL Compatibility renderer's
## 32-light frame budget on marker lamps nobody navigates by.
##
## ---------------------------------------------------------------------------
## DETERMINISM
## ---------------------------------------------------------------------------
## No randf()/randi() anywhere. The build verification renders and compares
## frames, so a random number in here is a bug. Every irregularity is a sin() of
## the vertex and ring indices.

## Preloaded rather than referenced by class_name: global class registration
## only exists after an editor import pass, so a `class_name` reference breaks
## in a fresh checkout or a headless CI run. A preload const always resolves.
const LPB := preload("res://scripts/goose/lowpoly_builder.gd")


# ---------------------------------------------------------------------------
# Registry
# ---------------------------------------------------------------------------

## Bounding footprint of each model, base-anchored: (width_x, height_y, depth_z).
const FOOTPRINTS := {
	&"semi_tractor": Vector3(2.55, 3.95, 7.20),
	&"trailer": Vector3(2.60, 4.15, 14.60),
	&"fuel_pump": Vector3(0.92, 2.05, 0.72),
	&"sodium_lamp": Vector3(2.60, 9.00, 0.60),
	&"pallet": Vector3(1.20, 0.16, 1.00),
	&"gator": Vector3(1.30, 0.30, 0.72),
	&"traffic_cone": Vector3(0.42, 0.74, 0.42),
	&"newspaper_box": Vector3(0.52, 1.10, 0.46),
	&"ice_box": Vector3(1.70, 1.95, 0.90),
	&"propane_cage": Vector3(1.60, 1.50, 0.86),
	&"wheel_chock": Vector3(0.30, 0.24, 0.44),
	&"air_tower": Vector3(0.62, 1.85, 0.62),
}


## True if [param kind] has a dedicated model here. Unknown kinds still build —
## they get a faceted crate, so nothing in the world is ever invisible — but a
## caller that wants to fall back to the shared library should test this first.
static func has_model(kind: StringName) -> bool:
	return FOOTPRINTS.has(kind)


## Base-anchored bounding size of [param kind].
static func footprint(kind: StringName, params := {}) -> Vector3:
	if FOOTPRINTS.has(kind):
		var f: Vector3 = FOOTPRINTS[kind]
		return f
	return Vector3.ONE


# ---------------------------------------------------------------------------
# Materials
# ---------------------------------------------------------------------------

static var _shared_mat: StandardMaterial3D = null

static func shared_material() -> StandardMaterial3D:
	if _shared_mat == null:
		_shared_mat = LPB.make_material(0.62)
		_shared_mat.cull_mode = BaseMaterial3D.CULL_BACK
		# Lower roughness than the other two libraries on purpose: everything in
		# this zone is WET, and the only cue for wet that survives at 3 a.m. is a
		# specular highlight from a sodium lamp sliding along a trailer flank.
		_shared_mat.metallic = 0.12
	return _shared_mat


## The glow material. UNSHADED on purpose: the face renders at exactly its
## vertex colour whatever light reaches it, which is precisely "this surface is
## emitting". At this zone's ambient a pale-amber *lit* quad is a grey rectangle.
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
##   trim_colour   Color    secondary (chrome, frame, deck boards)
##   glow_colour   Color    override the emissive colour
##   lit           bool     lamps and markers: emit or not
##   variant       float    deterministic shape seed
static func build(kind: StringName, parent: Node3D, params := {}) -> Node3D:
	var model := Node3D.new()
	model.name = "Model"
	parent.add_child(model)

	var b: RefCounted = LPB.new()
	var e: RefCounted = LPB.new()
	match kind:
		&"semi_tractor":
			_semi_tractor(b, e, params)
		&"trailer":
			_trailer(b, e, params)
		&"fuel_pump":
			_fuel_pump(b, e, params)
		&"sodium_lamp":
			_sodium_lamp(b, e, params)
		&"pallet":
			_pallet(b, e, params)
		&"gator":
			_gator(b, e, params)
		&"traffic_cone":
			_traffic_cone(b, e, params)
		&"newspaper_box":
			_newspaper_box(b, e, params)
		&"ice_box":
			_ice_box(b, e, params)
		&"propane_cage":
			_propane_cage(b, e, params)
		&"wheel_chock":
			_wheel_chock(b, e, params)
		&"air_tower":
			_air_tower(b, e, params)
		_:
			_fallback(b, e, params)

	model.set_meta("tri_count", b.tri_count + e.tri_count)
	LPB.attach(model, b.commit(), shared_material(), "Shell")
	# Only when there is something to glow: an empty SurfaceTool commits to null,
	# and a MeshInstance3D with a null mesh is a silent per-frame cost for nothing.
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


# ═══════════════════════════════════════════════════════════════════ LETTERING
#
# A 4x5 bitmap font, painted as merged boxes into ONE mesh per sign.
#
# 4x5 rather than the more usual 3x5 because M, N, W and V are genuinely
# ambiguous at three pixels wide, and this zone's whole job is to be READ: a
# truck stop that says something illegible is just a warehouse.
#
# Rows run TOP to BOTTOM, so row 0 is the cap line. "1" is ink.

const FONT := {
	"A": ["0110", "1001", "1111", "1001", "1001"],
	"B": ["1110", "1001", "1110", "1001", "1110"],
	"C": ["0111", "1000", "1000", "1000", "0111"],
	"D": ["1110", "1001", "1001", "1001", "1110"],
	"E": ["1111", "1000", "1110", "1000", "1111"],
	"F": ["1111", "1000", "1110", "1000", "1000"],
	"G": ["0111", "1000", "1011", "1001", "0111"],
	"H": ["1001", "1001", "1111", "1001", "1001"],
	"I": ["1110", "0100", "0100", "0100", "1110"],
	"J": ["0011", "0001", "0001", "1001", "0110"],
	"K": ["1001", "1010", "1100", "1010", "1001"],
	"L": ["1000", "1000", "1000", "1000", "1111"],
	"M": ["1001", "1111", "1111", "1001", "1001"],
	"N": ["1001", "1101", "1111", "1011", "1001"],
	"O": ["0110", "1001", "1001", "1001", "0110"],
	"P": ["1110", "1001", "1110", "1000", "1000"],
	"Q": ["0110", "1001", "1001", "1011", "0111"],
	"R": ["1110", "1001", "1110", "1010", "1001"],
	"S": ["0111", "1000", "0110", "0001", "1110"],
	"T": ["1111", "0100", "0100", "0100", "0100"],
	"U": ["1001", "1001", "1001", "1001", "0110"],
	"V": ["1001", "1001", "1001", "1010", "0100"],
	"W": ["1001", "1001", "1111", "1111", "1001"],
	"X": ["1001", "1001", "0110", "1001", "1001"],
	"Y": ["1001", "1001", "0110", "0100", "0100"],
	"Z": ["1111", "0001", "0110", "1000", "1111"],
	"0": ["0110", "1011", "1101", "1001", "0110"],
	"1": ["0100", "1100", "0100", "0100", "1110"],
	"2": ["1110", "0001", "0110", "1000", "1111"],
	"3": ["1110", "0001", "0110", "0001", "1110"],
	"4": ["1001", "1001", "1111", "0001", "0001"],
	"5": ["1111", "1000", "1110", "0001", "1110"],
	"6": ["0110", "1000", "1110", "1001", "0110"],
	"7": ["1111", "0001", "0010", "0100", "0100"],
	"8": ["0110", "1001", "0110", "1001", "0110"],
	"9": ["0110", "1001", "0111", "0001", "0110"],
	"-": ["0000", "0000", "1111", "0000", "0000"],
	".": ["0000", "0000", "0000", "0000", "0100"],
	"'": ["0100", "0100", "0000", "0000", "0000"],
	"/": ["0001", "0010", "0100", "1000", "0000"],
}

## Glyph cell is 4 px wide; the advance is 5, so there is one blank column
## between letters and a space is exactly one blank cell.
const GLYPH_ADVANCE := 5.0
const GLYPH_ROWS := 5.0


## On-screen width of [param text] at cap height [param h], in metres. Includes
## the trailing inter-letter gap, so centre a sign with
## `origin -= right * (text_width(t, h) - h / 5.0) * 0.5`.
static func text_width(text: String, h: float) -> float:
	var px := h / GLYPH_ROWS
	return float(text.length()) * GLYPH_ADVANCE * px


## Paint [param text] onto a flat face as one merged mesh, and return it.
##
## `origin`  world position of the TOP-LEFT corner of the first glyph cell, as
##           seen by a viewer looking AT the face.
## `normal`  the face's outward normal. Letters stand `thickness` proud of it.
## `up`      which way is up on the face. Almost always Vector3.UP; pass
##           Vector3.FORWARD for text painted flat on the ground.
## `h`       cap height in metres.
##
## ── THE MIRROR RULE ─────────────────────────────────────────────────────────
## Screen-right on a face is `up x normal`, NOT +X.
##
## A sign's front face points at -Z (this project authors everything facing -Z),
## so its reader stands at -Z looking along +Z, and for that reader world +X runs
## RIGHT TO LEFT. Advancing the pen along +X there produces mirrored text that
## looks completely fine in the source and completely wrong on screen. A stop
## sign shipped reading POTS and a trailer shipped reading ƎƆIVЯƎƧ; both were
## this line.
##
## `up x normal` is correct for every facing without a special case:
##   normal -Z  ->  right -X       normal +Z  ->  right +X
##   normal +X  ->  right -Z       normal -X  ->  right +Z
static func sign_text(parent: Node3D, text: String, origin: Vector3, normal: Vector3,
		up: Vector3, h: float, col: Color, unshaded := true,
		thickness := 0.05) -> MeshInstance3D:
	var n := normal.normalized()
	var u := up.normalized()
	var r := u.cross(n).normalized()
	var px := h / GLYPH_ROWS
	# Zero jitter: the builder's per-face brightness variation is what stops a
	# lamp post looking like a cylinder, and it is exactly what stops six-inch
	# letters looking like letters.
	var b: RefCounted = LPB.new(0.0)
	var pen := 0.0
	var upper := text.to_upper()
	for i in upper.length():
		var ch := upper.substr(i, 1)
		if FONT.has(ch):
			var rows: Array = FONT[ch]
			for row in int(GLYPH_ROWS):
				var bits: String = rows[row]
				var c0 := 0
				while c0 < bits.length():
					if bits[c0] != "1":
						c0 += 1
						continue
					# Merge a horizontal run of lit pixels into one box. A solid
					# "1111" row is one quad-set instead of four, which is most
					# of why a whole sign fits in one mesh.
					var c1 := c0
					while c1 + 1 < bits.length() and bits[c1 + 1] == "1":
						c1 += 1
					var run := float(c1 - c0 + 1)
					var cx := pen + (float(c0) + run * 0.5) * px
					var cy := -(float(row) + 0.5) * px
					b.box(origin + r * cx + u * cy + n * (thickness * 0.5),
						Vector3(run * px * 0.5, px * 0.5, thickness * 0.5),
						col, Basis(r, u, n))
					c0 = c1 + 1
		pen += GLYPH_ADVANCE * px
	# `b` is typed RefCounted (LPB is a preload, not a class_name), so commit()
	# is a Variant and `var mesh := ...` is the project's signature parse error.
	var mesh: ArrayMesh = b.commit()
	if mesh == null:
		return null
	return LPB.attach(parent, mesh, glow_material() if unshaded else shared_material(),
		"Sign")


# ---------------------------------------------------------------------------
# Typed parameter access.
#
# Dictionary lookups are Variant, so `var x := params.get(...)` is a parse error
# ("Cannot infer the type of x"). Funnelling every read through these three
# helpers keeps that mistake out of the twelve build functions below.
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
# Geometry helpers.
#
# Re-implemented here rather than reached for across a preload into the other
# two libraries: those are underscore-private statics on files this one has no
# other reason to depend on, and forty duplicated lines are cheaper than a
# coupling nobody expects. Same call the cottage library made.
# ---------------------------------------------------------------------------

static func _centroid(r: PackedVector3Array) -> Vector3:
	var c := Vector3.ZERO
	for v in r:
		c += v
	return c / float(maxi(r.size(), 1))


## A point far enough behind [param r] along -axis_dir that every face of the
## ring agrees on which way is out.
##
## LowPolyBuilder picks a face's winding from dot(normal, centroid - inside). On
## a near-flat fan the normal is almost axial while (centroid - inside) is
## dominated by the RADIUS, so a reference one metre behind a one-metre disc
## leaves the sign of that dot product up to which side of the ring the face
## happens to sit on — and the disc renders along exactly half a diameter. Put
## the reference two hundred radii away and the axial term wins every time.
## Documented at length in prop_models.gd because it cost that art pass two
## render rounds; repeated here because it would cost this one the same two.
static func _far_ref(r: PackedVector3Array, axis_dir: Vector3) -> Vector3:
	var c := _centroid(r)
	var far := 0.0
	for v in r:
		far = maxf(far, (v - c).length())
	return c - axis_dir.normalized() * (far * 200.0 + 10.0)


static func _cap_axial(b: RefCounted, r: PackedVector3Array, apex: Vector3,
		axis_dir: Vector3, col: Color) -> void:
	b.cap(r, apex, _far_ref(r, axis_dir), col)


## A capped faceted tube between two points. Every wheel, stack, cylinder,
## bollard and hose in this file is one of these.
static func _cyl(b: RefCounted, a: Vector3, c: Vector3, r: float, sides: int,
		col: Color, phase := 0.0) -> void:
	var d := c - a
	if d.length_squared() < 1e-8:
		return
	var dir := d.normalized()
	var up := Vector3.UP if absf(dir.y) < 0.92 else Vector3.FORWARD
	var r0 := LPB.ring(a, dir, up, r, r, sides, phase)
	var r1 := LPB.ring(c, dir, up, r, r, sides, phase)
	b.loft([r0, r1], [a, c], col)
	_cap_axial(b, r0, a - dir * r * 0.06, -dir, col.darkened(0.16))
	_cap_axial(b, r1, c + dir * r * 0.06, dir, col.lightened(0.04))


## A square-section strut between two arbitrary points, for anything that runs
## diagonally in two directions at once.
static func _strut(b: RefCounted, a: Vector3, c: Vector3, r: float, col: Color) -> void:
	_cyl(b, a, c, r, 4, col, PI * 0.25)


## A truck wheel: tyre, rim face, hub. Axis along X, so `x` is the outer face.
static func _wheel(b: RefCounted, x: float, y: float, z: float, sgn: float,
		radius: float, width: float, tyre: Color, rim: Color) -> void:
	var inner := Vector3(x - sgn * width, y, z)
	var outer := Vector3(x, y, z)
	_cyl(b, inner, outer, radius, 8, tyre)
	# The rim, inset, so the wheel reads as a wheel and not as a black puck.
	_cyl(b, outer - Vector3(sgn * width * 0.12, 0, 0),
		outer + Vector3(sgn * 0.012, 0, 0), radius * 0.62, 8, rim, PI / 8.0)


## Deterministic pseudo-noise in roughly [-1, 1]. Stands in for randf() so the
## lumpy things stay bit-identical between runs.
static func _wobble(a: int, c: int, seed_v: float) -> float:
	return sin(float(a) * 2.399 + float(c) * 1.117 + seed_v * 3.77) \
		* cos(float(a) * 0.813 - float(c) * 1.937 + seed_v * 1.31)


# ===========================================================================
# 1. SEMI TRACTOR — a long-nose conventional, grille at -Z
# ===========================================================================
#
# The read is entirely in the PROPORTION: a truck is a tall square box (the
# sleeper) behind a long low box (the hood), with a gap of daylight under the
# frame between the steer axle and the drives. Get the gap wrong and it is a
# bus. The stacks are what make it a truck at silhouette distance and they are
# four quads each.

static func _semi_tractor(b: RefCounted, e: RefCounted, params: Dictionary) -> void:
	var paint := _col(params, "colour", Color(0.60, 0.13, 0.13))
	var chrome := _col(params, "trim_colour", Color(0.72, 0.74, 0.78))
	var amber := _col(params, "glow_colour", Color(1.00, 0.62, 0.16))
	var lit := _flag(params, "lit", true)
	var dark := paint.darkened(0.55)
	var tyre := Color(0.085, 0.085, 0.095)

	# ── frame rails, the daylight gap ───────────────────────────────────
	for sx in [-1.0, 1.0]:
		var xs: float = sx
		b.box(Vector3(xs * 0.52, 0.92, 0.10), Vector3(0.09, 0.13, 3.30), dark)
	# Cross members, visible from the side through the gap.
	for i in 3:
		b.box(Vector3(0, 0.92, -1.6 + float(i) * 1.7), Vector3(0.52, 0.07, 0.09), dark)

	# ── hood ────────────────────────────────────────────────────────────
	# Tapered: narrower and lower at the grille, which is what stops a
	# conventional reading as a shipping container on wheels.
	var hood_rings := [
		LPB.ring(Vector3(0, 1.52, -3.40), Vector3.FORWARD, Vector3.UP, 0.98, 0.42, 6, 0.0),
		LPB.ring(Vector3(0, 1.56, -2.60), Vector3.FORWARD, Vector3.UP, 1.06, 0.48, 6, 0.0),
		LPB.ring(Vector3(0, 1.62, -1.50), Vector3.FORWARD, Vector3.UP, 1.14, 0.56, 6, 0.0),
	]
	b.loft(hood_rings, [Vector3(0, 1.52, -3.40), Vector3(0, 1.56, -2.60),
		Vector3(0, 1.62, -1.50)], paint)
	_cap_axial(b, hood_rings[0], Vector3(0, 1.50, -3.52), Vector3.FORWARD,
		paint.darkened(0.10))

	# ── grille and bumper, the front face (normal -Z) ───────────────────
	b.box(Vector3(0, 1.42, -3.50), Vector3(0.86, 0.44, 0.06), chrome.darkened(0.35))
	for i in 6:
		b.box(Vector3(0, 1.06 + float(i) * 0.145, -3.54), Vector3(0.82, 0.045, 0.05), chrome)
	b.box(Vector3(0, 0.78, -3.58), Vector3(1.12, 0.20, 0.10), chrome)
	# Headlights. Off in the bay, on when it rolls — the zone flips `lit`.
	for sx in [-1.0, 1.0]:
		var hx: float = sx
		b.box(Vector3(hx * 0.86, 1.30, -3.50), Vector3(0.16, 0.13, 0.05), chrome.darkened(0.5))
		if lit:
			e.box(Vector3(hx * 0.86, 1.30, -3.56), Vector3(0.13, 0.10, 0.02),
				Color(1.00, 0.96, 0.86))

	# ── cab and sleeper ─────────────────────────────────────────────────
	b.box(Vector3(0, 2.10, -0.42), Vector3(1.16, 1.06, 1.02), paint)
	b.box(Vector3(0, 2.22, 1.62), Vector3(1.18, 1.18, 1.06), paint)
	# The roof fairing, which is most of a modern truck's silhouette.
	b.box(Vector3(0, 3.48, 0.90), Vector3(1.12, 0.28, 1.90), paint.lightened(0.06))
	# Windscreen and side glass. Dark, with the dash glow behind it — a cab at
	# 3 a.m. with the engine running has an instrument cluster on.
	b.box(Vector3(0, 2.54, -1.44), Vector3(0.99, 0.40, 0.05), Color(0.05, 0.07, 0.09))
	# The dash. It has to sit PROUD of the glass (z -1.53 against the glass's
	# -1.49 front face) or it is inside an opaque box and renders as nothing;
	# the first pass had it at -1.42 and the cab was simply dark.
	if lit:
		e.box(Vector3(0, 2.18, -1.53), Vector3(0.60, 0.05, 0.015), Color(0.30, 0.82, 0.55))
	for sx in [-1.0, 1.0]:
		var gx: float = sx
		b.box(Vector3(gx * 1.18, 2.36, -0.44), Vector3(0.04, 0.42, 0.66),
			Color(0.05, 0.07, 0.09))
		# Mirror on its arm — small, and the single most recognisable piece of
		# a truck's front three-quarter silhouette.
		_strut(b, Vector3(gx * 1.14, 2.60, -1.28), Vector3(gx * 1.46, 2.60, -1.28), 0.035,
			chrome.darkened(0.3))
		b.box(Vector3(gx * 1.50, 2.42, -1.28), Vector3(0.05, 0.30, 0.13), Color(0.12, 0.12, 0.14))

	# ── stacks ──────────────────────────────────────────────────────────
	for sx in [-1.0, 1.0]:
		var px: float = sx
		_cyl(b, Vector3(px * 1.24, 1.05, 0.72), Vector3(px * 1.24, 3.92, 0.72), 0.11, 6, chrome)

	# ── fuel tanks ──────────────────────────────────────────────────────
	for sx in [-1.0, 1.0]:
		var fx: float = sx
		_cyl(b, Vector3(fx * 1.10, 1.02, -0.40), Vector3(fx * 1.10, 1.02, 1.30), 0.40, 8,
			chrome.darkened(0.12))

	# ── marker lights: five across the roof lip ─────────────────────────
	for i in 5:
		var mx := -0.72 + float(i) * 0.36
		b.box(Vector3(mx, 3.74, -0.02), Vector3(0.07, 0.05, 0.10), amber.darkened(0.5))
		if lit:
			e.box(Vector3(mx, 3.78, -0.02), Vector3(0.055, 0.035, 0.085), amber)

	# ── wheels and the fifth wheel ──────────────────────────────────────
	for sx in [-1.0, 1.0]:
		var wx: float = sx
		_wheel(b, wx * 1.14, 0.55, -2.45, wx, 0.55, 0.20, tyre, chrome.darkened(0.25))
		_wheel(b, wx * 1.16, 0.55, 1.40, wx, 0.55, 0.19, tyre, chrome.darkened(0.25))
		_wheel(b, wx * 1.16, 0.55, 2.60, wx, 0.55, 0.19, tyre, chrome.darkened(0.25))
	b.box(Vector3(0, 1.10, 2.05), Vector3(0.62, 0.06, 0.60), Color(0.20, 0.20, 0.22))


# ===========================================================================
# 2. TRAILER — 53 ft dry van. Kingpin at -Z, roll-up doors at +Z.
# ===========================================================================
#
# THE ROOF IS THE POINT. Everything else about this model is dressing on a very
# large box; the flat 2.4 x 13 m plate at y = 4.05 is the zone's only real piece
# of high ground, it is the launch pad, and when the rig pulls out it is the
# thing the player is standing on.
#
# The conspicuity tape is on the GLOW builder. Retroreflective tape at night
# under a sodium lamp is genuinely brighter than the paint around it, and it is
# the cheapest possible cue for "that shape over there is a vehicle".

static func _trailer(b: RefCounted, e: RefCounted, params: Dictionary) -> void:
	var body := _col(params, "colour", Color(0.78, 0.78, 0.80))
	var frame := _col(params, "trim_colour", Color(0.22, 0.22, 0.25))
	var amber := _col(params, "glow_colour", Color(1.00, 0.60, 0.16))
	var lit := _flag(params, "lit", true)
	var tyre := Color(0.085, 0.085, 0.095)
	var deck := 1.15
	var top := 4.05
	var hz := 7.30
	var hx := 1.30

	# ── the box ─────────────────────────────────────────────────────────
	b.box(Vector3(0, (deck + top) * 0.5, 0.0), Vector3(hx, (top - deck) * 0.5, hz), body)
	# Roof, a shade paler and slightly proud, so the landing surface reads as a
	# separate plane from the flanks when you are looking down at it from a lamp.
	b.box(Vector3(0, top + 0.03, 0.0), Vector3(hx * 0.99, 0.04, hz * 0.995),
		body.lightened(0.10))
	# Roof bows. Three shallow ribs — enough to say "this is a roof you are
	# standing on" without ever being tall enough to trip a goose.
	for i in 3:
		b.box(Vector3(0, top + 0.07, -4.4 + float(i) * 4.4), Vector3(hx * 0.98, 0.03, 0.10),
			body.darkened(0.14))
	# Side posts, every 1.2 m. A dry van's flank is not flat and the posts are
	# the only thing that gives 14 m of white panel a scale.
	for i in 12:
		var pz := -6.6 + float(i) * 1.2
		for sx in [-1.0, 1.0]:
			var px: float = sx
			b.box(Vector3(px * (hx + 0.015), (deck + top) * 0.5, pz),
				Vector3(0.02, (top - deck) * 0.5 - 0.06, 0.055), body.darkened(0.13))
	# Scuff rail along the bottom of each flank.
	for sx in [-1.0, 1.0]:
		var rx: float = sx
		b.box(Vector3(rx * (hx + 0.02), deck + 0.12, 0.0), Vector3(0.03, 0.10, hz * 0.99), frame)

	# ── conspicuity tape: red / white alternating, on the glow builder ───
	for sx in [-1.0, 1.0]:
		var tx: float = sx
		for i in 24:
			var tz := -7.0 + float(i) * 0.60
			var c := Color(0.92, 0.14, 0.12) if i % 2 == 0 else Color(0.94, 0.94, 0.90)
			e.box(Vector3(tx * (hx + 0.045), deck + 0.30, tz), Vector3(0.012, 0.055, 0.27), c)

	# ── rear doors (+Z face) ────────────────────────────────────────────
	for sx in [-1.0, 1.0]:
		var dx: float = sx
		b.box(Vector3(dx * 0.64, (deck + top) * 0.5, hz + 0.05),
			Vector3(0.62, (top - deck) * 0.5 - 0.02, 0.05), body.darkened(0.06))
		# Lock bars, the two vertical rods that say "doors" from fifty metres.
		_cyl(b, Vector3(dx * 0.30, deck + 0.10, hz + 0.12), Vector3(dx * 0.30, top - 0.10, hz + 0.12),
			0.035, 6, frame.lightened(0.30))
		_cyl(b, Vector3(dx * 1.00, deck + 0.10, hz + 0.12), Vector3(dx * 1.00, top - 0.10, hz + 0.12),
			0.035, 6, frame.lightened(0.30))
	# Rear tape band and the tail lights.
	for i in 8:
		var bz := -0.98 + float(i) * 0.28
		e.box(Vector3(bz, deck + 0.04, hz + 0.10), Vector3(0.13, 0.045, 0.012),
			Color(0.92, 0.14, 0.12) if i % 2 == 0 else Color(0.94, 0.94, 0.90))
	for sx in [-1.0, 1.0]:
		var lx: float = sx
		b.box(Vector3(lx * 1.05, deck + 0.34, hz + 0.10), Vector3(0.13, 0.12, 0.04), frame)
		if lit:
			e.box(Vector3(lx * 1.05, deck + 0.34, hz + 0.14), Vector3(0.10, 0.09, 0.015),
				Color(0.94, 0.16, 0.12))
	# Roof-line markers along the top rear edge.
	for i in 5:
		var mx := -0.80 + float(i) * 0.40
		if lit:
			e.box(Vector3(mx, top - 0.06, hz + 0.09), Vector3(0.06, 0.04, 0.015), amber)

	# ── landing gear, just aft of the kingpin ───────────────────────────
	for sx in [-1.0, 1.0]:
		var gx: float = sx
		b.box(Vector3(gx * 0.86, deck * 0.5, -4.60), Vector3(0.10, deck * 0.5, 0.10), frame)
		b.box(Vector3(gx * 0.86, 0.04, -4.60), Vector3(0.20, 0.04, 0.20), frame.darkened(0.2))
	b.box(Vector3(0, deck - 0.08, -6.40), Vector3(0.34, 0.08, 0.34), frame)

	# ── bogie ───────────────────────────────────────────────────────────
	b.box(Vector3(0, 0.98, 5.30), Vector3(1.06, 0.12, 1.60), frame.darkened(0.2))
	for sx in [-1.0, 1.0]:
		var wx: float = sx
		_wheel(b, wx * 1.22, 0.52, 4.55, wx, 0.52, 0.18, tyre, frame.lightened(0.18))
		_wheel(b, wx * 1.22, 0.52, 6.05, wx, 0.52, 0.18, tyre, frame.lightened(0.18))
	# Mudflaps, which hang and which everyone recognises.
	for sx in [-1.0, 1.0]:
		var fx: float = sx
		b.box(Vector3(fx * 0.72, 0.30, 6.80), Vector3(0.42, 0.30, 0.02), Color(0.10, 0.10, 0.11))


# ===========================================================================
# 3. FUEL PUMP
# ===========================================================================

static func _fuel_pump(b: RefCounted, e: RefCounted, params: Dictionary) -> void:
	var shell := _col(params, "colour", Color(0.80, 0.78, 0.72))
	var trim := _col(params, "trim_colour", Color(0.16, 0.30, 0.46))
	var glow := _col(params, "glow_colour", Color(0.42, 0.94, 0.62))
	var lit := _flag(params, "lit", true)

	b.box(Vector3(0, 0.10, 0), Vector3(0.46, 0.10, 0.36), trim.darkened(0.35))
	b.box(Vector3(0, 0.92, 0), Vector3(0.38, 0.72, 0.28), shell)
	b.box(Vector3(0, 1.72, 0), Vector3(0.42, 0.10, 0.32), trim)
	b.box(Vector3(0, 1.92, 0), Vector3(0.40, 0.11, 0.30), shell.darkened(0.10))
	# The display, on the -Z face, where the driver stands.
	b.box(Vector3(0, 1.34, -0.30), Vector3(0.30, 0.22, 0.03), Color(0.07, 0.09, 0.08))
	if lit:
		e.box(Vector3(0, 1.34, -0.33), Vector3(0.26, 0.18, 0.015), glow)
		e.box(Vector3(0, 1.92, 0), Vector3(0.34, 0.045, 0.31), Color(0.96, 0.86, 0.42))
	# Nozzle boots, one per side.
	for sx in [-1.0, 1.0]:
		var nx: float = sx
		b.box(Vector3(nx * 0.42, 1.10, 0.06), Vector3(0.07, 0.22, 0.09), trim.darkened(0.15))
		_cyl(b, Vector3(nx * 0.42, 1.30, 0.06), Vector3(nx * 0.30, 1.55, 0.14), 0.035, 5,
			Color(0.10, 0.10, 0.11))


# ===========================================================================
# 4. SODIUM LAMP — the zone's whole colour identity, on a 9 m pole
# ===========================================================================
#
# The lens is a DOWNWARD-facing glow quad. It has to be on the glow builder: a
# lit-from-outside pale quad under a lamp head is a grey rectangle, and the one
# thing this zone cannot afford is lamps that don't look on.

static func _sodium_lamp(b: RefCounted, e: RefCounted, params: Dictionary) -> void:
	var pole := _col(params, "colour", Color(0.24, 0.235, 0.25))
	var glow := _col(params, "glow_colour", Color(1.00, 0.68, 0.26))
	var lit := _flag(params, "lit", true)

	b.box(Vector3(0, 0.16, 0), Vector3(0.30, 0.16, 0.30), pole.darkened(0.25))
	# Tapered pole: three segments, each a shade narrower.
	_cyl(b, Vector3(0, 0.28, 0), Vector3(0, 3.40, 0), 0.14, 6, pole)
	_cyl(b, Vector3(0, 3.30, 0), Vector3(0, 6.40, 0), 0.115, 6, pole.lightened(0.03))
	_cyl(b, Vector3(0, 6.30, 0), Vector3(0, 8.40, 0), 0.095, 6, pole.lightened(0.05))
	# The mast arm, out along +X, with the head cocked over the lot.
	_strut(b, Vector3(0, 8.34, 0), Vector3(0.62, 8.68, 0), 0.065, pole)
	_strut(b, Vector3(0.62, 8.68, 0), Vector3(1.55, 8.74, 0), 0.055, pole)
	# Cobrahead: a wedge, wider at the back, flat glass underneath.
	b.box(Vector3(1.80, 8.72, 0), Vector3(0.46, 0.12, 0.22), pole.lightened(0.10))
	b.box(Vector3(1.44, 8.80, 0), Vector3(0.16, 0.14, 0.16), pole)
	if lit:
		e.box(Vector3(1.80, 8.59, 0), Vector3(0.40, 0.02, 0.18), glow)
		# A short halo skirt so the head reads as lit from three-quarter angles
		# rather than only from directly below.
		e.box(Vector3(1.80, 8.63, 0), Vector3(0.43, 0.03, 0.20), glow.darkened(0.35))


# ===========================================================================
# 5. PALLET — the cheapest toy in the zone
# ===========================================================================
#
# THERE IS A SECOND PALLET, in prop_models_corn.gd (_pallet, and &"pallet" in
# its FOOTPRINTS). Same real-world object, independently built, and neither
# copy acknowledged the other until this comment: corn's is 1.16 x 0.14 x 1.00
# with two stringers' worth of deck, this one is 1.20 x 0.16 x 1.00 with three
# stringers, six deck boards, three bottom boards and a `variant` wobble. Four
# centimetres of disagreement in two axes about a standardised object, which is
# exactly the kind of magic-number drift that gets tuned once and stays wrong in
# the other file forever.
#
# This one is the better model and should be the one that survives. Doing that
# means either corn delegating here or both moving into prop_models.gd, and
# prop_models_corn.gd is not this file's to edit — so for now the duplication is
# WRITTEN DOWN rather than silent, which is the difference between this and the
# two dogs (prop_models_corn.gd:1059 states why the dogs are deliberately not
# shared; there is no such reason here).

static func _pallet(b: RefCounted, _e: RefCounted, params: Dictionary) -> void:
	var wood := _col(params, "colour", Color(0.52, 0.41, 0.28))
	var seed_v := _num(params, "variant", 0.0)
	for i in 3:
		b.box(Vector3(-0.44 + float(i) * 0.44, 0.045, 0), Vector3(0.05, 0.045, 0.48),
			wood.darkened(0.20))
	for i in 6:
		var t := wood.lightened(0.05 * _wobble(i, 1, seed_v))
		b.box(Vector3(0, 0.115, -0.44 + float(i) * 0.176), Vector3(0.58, 0.025, 0.055), t)
	for i in 3:
		b.box(Vector3(0, 0.012, -0.42 + float(i) * 0.42), Vector3(0.58, 0.014, 0.05),
			wood.darkened(0.30))


# ===========================================================================
# 6. GATOR — a shed retread, the true native fauna of the interstate shoulder
# ===========================================================================

static func _gator(b: RefCounted, _e: RefCounted, params: Dictionary) -> void:
	# Deliberately NOT tyre-black. A shed retread on wet asphalt at 3 a.m. in
	# tyre-black is a hole in the ground, and the first render had one lying
	# next to the goose that read as a shadow. Grey-brown, and the zone puts
	# them where a lamp can find them.
	var rubber := _col(params, "colour", Color(0.155, 0.145, 0.150))
	var seed_v := _num(params, "variant", 0.0)
	# Six segments in an arc, each kicked out of plane, so it lies on the
	# asphalt the way a shed cap actually does — curled, not flat.
	for i in 6:
		var t := float(i) / 5.0
		var a := -1.05 + t * 2.1 + 0.20 * _wobble(i, 2, seed_v)
		var y := 0.045 + 0.075 * sin(t * PI) + 0.03 * _wobble(i, 5, seed_v)
		b.box(Vector3(-0.52 + t * 1.04, y, 0.10 * sin(a)),
			Vector3(0.11, 0.045, 0.20 + 0.05 * _wobble(i, 7, seed_v)),
			rubber.lightened(0.06 * absf(_wobble(i, 3, seed_v))),
			Basis(Vector3.UP, a * 0.5) * Basis(Vector3.FORWARD, a * 0.35))
	# Steel belt whiskers. Thin, pale, and the single detail that identifies it.
	for i in 4:
		var w := 0.42 + 0.10 * _wobble(i, 11, seed_v)
		b.box(Vector3(0.44 + 0.06 * float(i % 2), 0.055 + 0.02 * float(i), 0.0),
			Vector3(w * 0.35, 0.006, 0.008), Color(0.42, 0.42, 0.44),
			Basis(Vector3.UP, 0.4 * _wobble(i, 13, seed_v)))


# ===========================================================================
# 7. TRAFFIC CONE
# ===========================================================================

static func _traffic_cone(b: RefCounted, e: RefCounted, params: Dictionary) -> void:
	var orange := _col(params, "colour", Color(0.92, 0.36, 0.10))
	b.box(Vector3(0, 0.022, 0), Vector3(0.21, 0.022, 0.21), orange.darkened(0.35))
	var r0 := LPB.ring(Vector3(0, 0.04, 0), Vector3.UP, Vector3.FORWARD, 0.13, 0.13, 4, PI * 0.25)
	var r1 := LPB.ring(Vector3(0, 0.40, 0), Vector3.UP, Vector3.FORWARD, 0.085, 0.085, 4, PI * 0.25)
	var r2 := LPB.ring(Vector3(0, 0.66, 0), Vector3.UP, Vector3.FORWARD, 0.045, 0.045, 4, PI * 0.25)
	b.loft([r0, r1, r2], [Vector3(0, 0.04, 0), Vector3(0, 0.40, 0), Vector3(0, 0.66, 0)], orange)
	_cap_axial(b, r2, Vector3(0, 0.72, 0), Vector3.UP, orange.lightened(0.05))
	# The reflective collar. On the glow builder, because that is what a cone in
	# a headlight actually does and it is how you see one at 3 a.m.
	e.box(Vector3(0, 0.47, 0), Vector3(0.082, 0.05, 0.082), Color(0.92, 0.92, 0.88))


# ===========================================================================
# 8. NEWSPAPER BOX — a rank of these outside a diner is a whole time period
# ===========================================================================

static func _newspaper_box(b: RefCounted, e: RefCounted, params: Dictionary) -> void:
	var shell := _col(params, "colour", Color(0.18, 0.42, 0.60))
	var lit := _flag(params, "lit", false)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var lx: float = sx
			var lz: float = sz
			b.box(Vector3(lx * 0.20, 0.16, lz * 0.16), Vector3(0.022, 0.16, 0.022),
				shell.darkened(0.4))
	b.box(Vector3(0, 0.66, 0), Vector3(0.26, 0.34, 0.23), shell)
	# Sloped display top, hinged at the back.
	b.box(Vector3(0, 1.02, -0.03), Vector3(0.26, 0.045, 0.24), shell.lightened(0.08),
		Basis(Vector3.RIGHT, 0.30))
	# The window with the front page behind it.
	b.box(Vector3(0, 0.72, -0.24), Vector3(0.19, 0.20, 0.02), Color(0.72, 0.70, 0.66))
	if lit:
		e.box(Vector3(0, 0.72, -0.26), Vector3(0.17, 0.18, 0.01), Color(0.82, 0.80, 0.74))
	b.box(Vector3(0, 0.42, -0.24), Vector3(0.07, 0.03, 0.02), Color(0.70, 0.70, 0.72))


# ===========================================================================
# 9. ICE BOX — the merchandiser freezer that lives outside every one of these
# ===========================================================================

static func _ice_box(b: RefCounted, e: RefCounted, params: Dictionary) -> void:
	var shell := _col(params, "colour", Color(0.80, 0.82, 0.84))
	var trim := _col(params, "trim_colour", Color(0.14, 0.30, 0.52))
	var lit := _flag(params, "lit", true)

	b.box(Vector3(0, 0.09, 0), Vector3(0.84, 0.09, 0.44), trim.darkened(0.4))
	b.box(Vector3(0, 0.95, 0), Vector3(0.84, 0.80, 0.44), shell)
	b.box(Vector3(0, 1.82, 0), Vector3(0.86, 0.11, 0.46), trim)
	# Two doors on the -Z face, with a lit interior behind them.
	for sx in [-1.0, 1.0]:
		var dx: float = sx
		b.box(Vector3(dx * 0.40, 1.00, -0.45), Vector3(0.36, 0.56, 0.03),
			Color(0.10, 0.16, 0.20))
		b.box(Vector3(dx * 0.40, 1.00, -0.47), Vector3(0.38, 0.58, 0.012), trim.darkened(0.1))
		# In FRONT of the door glass and the frame, not behind them. Behind, the
		# glow is inside an opaque box and the freezer is an unlit white cabinet.
		if lit:
			e.box(Vector3(dx * 0.40, 1.00, -0.50), Vector3(0.32, 0.50, 0.01),
				Color(0.68, 0.84, 0.96))
	b.box(Vector3(0, 1.00, -0.44), Vector3(0.04, 0.60, 0.04), trim.darkened(0.2))


# ===========================================================================
# 10. PROPANE CAGE
# ===========================================================================

static func _propane_cage(b: RefCounted, _e: RefCounted, params: Dictionary) -> void:
	var cage := _col(params, "colour", Color(0.42, 0.44, 0.44))
	var tank := _col(params, "trim_colour", Color(0.86, 0.86, 0.82))

	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var px: float = sx
			var pz: float = sz
			b.box(Vector3(px * 0.76, 0.74, pz * 0.40), Vector3(0.035, 0.74, 0.035), cage)
	# Mesh: horizontal rails and a few verticals. Enough to read as a cage from
	# eight metres without paying for a real grid.
	for i in 4:
		var y := 0.16 + float(i) * 0.44
		b.box(Vector3(0, y, -0.40), Vector3(0.76, 0.018, 0.018), cage)
		b.box(Vector3(0, y, 0.40), Vector3(0.76, 0.018, 0.018), cage)
		for sx2 in [-1.0, 1.0]:
			var mx: float = sx2
			b.box(Vector3(mx * 0.76, y, 0), Vector3(0.018, 0.018, 0.40), cage)
	for i in 5:
		b.box(Vector3(-0.60 + float(i) * 0.30, 0.74, -0.40), Vector3(0.016, 0.72, 0.016), cage)
	b.box(Vector3(0, 0.02, 0), Vector3(0.78, 0.02, 0.42), cage.darkened(0.4))
	# Six cylinders, two rows.
	for i in 6:
		var cx := -0.50 + float(i % 3) * 0.50
		var cz := -0.18 + float(i / 3) * 0.36
		_cyl(b, Vector3(cx, 0.05, cz), Vector3(cx, 0.62, cz), 0.15, 6, tank)
		_cyl(b, Vector3(cx, 0.62, cz), Vector3(cx, 0.72, cz), 0.10, 6, tank.darkened(0.10))
		b.box(Vector3(cx, 0.78, cz), Vector3(0.09, 0.07, 0.09), Color(0.55, 0.14, 0.12))


# ===========================================================================
# 11. WHEEL CHOCK
# ===========================================================================

static func _wheel_chock(b: RefCounted, _e: RefCounted, params: Dictionary) -> void:
	var yellow := _col(params, "colour", Color(0.86, 0.70, 0.14))
	# A wedge: a base plate plus a leaning slab. Two boxes, and from anywhere a
	# goose stands it is unmistakably a chock.
	b.box(Vector3(0, 0.025, 0), Vector3(0.15, 0.025, 0.22), yellow.darkened(0.20))
	b.box(Vector3(0, 0.11, 0.02), Vector3(0.14, 0.11, 0.13), yellow,
		Basis(Vector3.RIGHT, 0.55))
	b.box(Vector3(0, 0.16, -0.13), Vector3(0.14, 0.02, 0.05), yellow.darkened(0.35))


# ===========================================================================
# 12. AIR TOWER — free air, in theory
# ===========================================================================

static func _air_tower(b: RefCounted, e: RefCounted, params: Dictionary) -> void:
	var red := _col(params, "colour", Color(0.62, 0.16, 0.14))
	var trim := _col(params, "trim_colour", Color(0.60, 0.62, 0.64))
	var lit := _flag(params, "lit", true)

	b.box(Vector3(0, 0.07, 0), Vector3(0.31, 0.07, 0.31), trim.darkened(0.4))
	b.box(Vector3(0, 0.86, 0), Vector3(0.20, 0.80, 0.20), red)
	b.box(Vector3(0, 1.72, 0), Vector3(0.26, 0.10, 0.26), red.darkened(0.15))
	# The head, with a gauge on the -Z face.
	b.box(Vector3(0, 1.60, -0.21), Vector3(0.13, 0.13, 0.03), Color(0.10, 0.10, 0.11))
	if lit:
		e.box(Vector3(0, 1.60, -0.24), Vector3(0.10, 0.10, 0.012), Color(0.94, 0.90, 0.62))
	# Hose reel and a coil of hose hanging off it.
	_cyl(b, Vector3(-0.22, 1.12, 0), Vector3(0.22, 1.12, 0), 0.10, 6, trim)
	for i in 5:
		var a := float(i) * 1.05
		_cyl(b, Vector3(0.20, 1.12 - float(i) * 0.05, 0.0),
			Vector3(0.20 + 0.12 * cos(a), 1.02 - float(i) * 0.11, 0.12 * sin(a)),
			0.022, 4, Color(0.10, 0.10, 0.12))


# ===========================================================================
# FALLBACK
# ===========================================================================

## An unknown kind still builds something. A faceted crate is never right but it
## is never invisible either, which is the failure mode that costs a render.
static func _fallback(b: RefCounted, _e: RefCounted, params: Dictionary) -> void:
	var c := _col(params, "colour", Color(0.62, 0.58, 0.52))
	b.box(Vector3(0, 0.5, 0), Vector3(0.5, 0.5, 0.5), c)
	for sx in [-1.0, 1.0]:
		var px: float = sx
		b.box(Vector3(px * 0.5, 0.5, 0), Vector3(0.02, 0.5, 0.5), c.darkened(0.2))
