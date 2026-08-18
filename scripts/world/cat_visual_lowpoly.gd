extends Node3D
## LOW-POLY DOMESTIC CAT — polygons only.
##
## Same rules as the goose: no SphereMesh, no CapsuleMesh, no CylinderMesh,
## no curved primitives. Every surface is authored through LowPolyBuilder —
## a lofted body, a separate head, four separate legs, and a segmented tail
## chain so it can be whipped by animation. Flat normals throughout, one
## material, all colour carried in vertex colours.
##
## ORIENTATION: the cat faces -Z, matching Node3D's forward. Nose at negative
## Z, rump/tail at positive Z. If you add a part, put its front at NEGATIVE Z.
##
## FACET BUDGET: roughly 350-550 triangles. See triangle_count().

## Preloaded rather than referenced by class_name: global class registration
## only exists after an editor import pass, so a `class_name` reference breaks
## in a fresh checkout or a headless CI run. A preload const always resolves.
## This file and human_visual_lowpoly.gd were the last two mesh files in
## scripts/world/ still going through the global name; every other one — the
## four prop libraries and flock_pen.gd — has looked like this for a while.
const LPB := preload("res://scripts/goose/lowpoly_builder.gd")

const C_TABBY_BASE := Color(0.80, 0.50, 0.22)
const C_TABBY_STRIPE := Color(0.40, 0.23, 0.10)
const C_TABBY_BELLY := Color(0.92, 0.80, 0.58)

const C_TUX_BLACK := Color(0.045, 0.045, 0.055)
const C_TUX_WHITE := Color(0.93, 0.93, 0.91)

const C_GREY_BASE := Color(0.52, 0.53, 0.56)
const C_GREY_BELLY := Color(0.74, 0.74, 0.73)

const C_NOSE := Color(0.86, 0.40, 0.50)
const C_IRIS := Color(0.42, 0.50, 0.20)
const C_PUPIL := Color(0.05, 0.05, 0.06)
const C_EAR_INNER := Color(0.75, 0.52, 0.52)

const BODY_SIDES := 6
const HEAD_SIDES := 6
const LEG_SIDES := 4
const TAIL_SIDES := 5

const LEG_LEN := 0.20
const SEG_LEN := 0.095
const TAIL_SEGMENTS := 4

## Where each leg node hangs off the body — the leg chain starts below the
## body's centre line, not on it.
const LEG_HIP_Y := -0.030

## Where `body` sits so the PAWS land on y = 0. The shared origin convention
## for every creature in this project is "origin = ground".
##
## NOT LEG_LEN. That was the bug: the leg starts LEG_HIP_Y *below* the body
## origin and then runs LEG_LEN down, so a body parked at LEG_LEN buries every
## paw 3 cm in the lawn. Nothing that spawns a cat compensated for it, so this
## is the only place it needed fixing. boss_ranger_visual.gd's collie has the
## same relationship and states it as STAND_Y for the same reason.
const STAND_Y := LEG_LEN - LEG_HIP_Y

## Nine cross-sections, tail root to neck base. Deeper chest than hips is the
## whole point of this table: compare ry at row 1 (hips) to row 4 (chest).
const BODY_PROFILE := [
	# z,      cy,    rx,    ry
	[ 0.220,  0.010, 0.040, 0.040],
	[ 0.145,  0.028, 0.090, 0.080],
	[ 0.045,  0.022, 0.100, 0.090],
	[-0.045,  0.016, 0.098, 0.100],
	[-0.100,  0.010, 0.090, 0.118],
	[-0.145,  0.010, 0.064, 0.090],
	[-0.180,  0.016, 0.034, 0.056],
]

## Local to the head node. Small, wide skull with a blunt muzzle — the width
## barely tapers until the very last row, which is what reads as "blunt"
## instead of "pointed like a fox."
const HEAD_PROFILE := [
	# y,      z,      rx,    ry
	[ 0.000,  0.020, 0.052, 0.050],
	[ 0.024, -0.032, 0.076, 0.068],
	[ 0.014, -0.078, 0.078, 0.064],
	[ 0.000, -0.114, 0.054, 0.050],
	[-0.006, -0.148, 0.032, 0.030],
]

## Legs, hips, standing pose. Expose in this fixed order so animate() can pair
## diagonals: 0=front-left, 1=front-right, 2=back-left, 3=back-right.
var body: Node3D
var head: Node3D
var legs: Array[Node3D] = []
var tail_segments: Array[Node3D] = []
var tint_targets: Array[StandardMaterial3D] = []

var _mat: StandardMaterial3D
var _pattern: StringName = &"tabby"
var _built := false
var _tri_total := 0

var _walk_phase := 0.0
var _tail_phase := 0.0
var _wiggle_phase := 0.0


func _ready() -> void:
	if not _built:
		_build()


## Coat pattern is chosen here. Safe to call before or after the node enters
## the tree — if _ready() already built a default cat, this tears it down and
## rebuilds with the requested pattern.
func setup(pattern: StringName = &"tabby") -> void:
	_pattern = pattern
	_build()


func _build() -> void:
	_built = true
	for c in get_children():
		c.queue_free()
	legs.clear()
	tail_segments.clear()

	_mat = LPB.make_material(0.90)
	tint_targets.clear()
	tint_targets.append(_mat)
	_tri_total = 0

	body = Node3D.new()
	body.name = "Body"
	body.position.y = STAND_Y
	add_child(body)

	_build_body()
	_build_head()
	_build_legs()
	_build_tail()


# ---------------------------------------------------------------- body

func _build_body() -> void:
	var b: RefCounted = LPB.new()
	var rings := []
	var spine := []
	for row in BODY_PROFILE:
		var z: float = row[0]
		var cy: float = row[1]
		var rx: float = row[2]
		var ry: float = row[3]
		var centre := Vector3(0, cy, z)
		spine.append(centre)
		rings.append(LPB.ring(centre, Vector3(0, 0, 1), Vector3.UP,
			rx, ry, BODY_SIDES, PI / float(BODY_SIDES)))

	b.loft(rings, spine, Callable(self, "_body_colour"))
	# Tail-root cap at the back, neck-base cap at the front.
	b.cap(rings[0], Vector3(0, 0.035, 0.255), spine[1], Callable(self, "_body_colour"))
	b.cap(rings[rings.size() - 1], Vector3(0, 0.020, -0.205), spine[spine.size() - 2],
		Callable(self, "_body_colour"))

	_tri_total += b.tri_count
	LPB.attach(body, b.commit(), _mat, "Torso")


## Painted per face from where the face sits, so markings need no extra
## geometry. This is where each of the three coat patterns actually happens.
func _body_colour(p: Vector3) -> Color:
	match _pattern:
		&"tuxedo":
			# Black everywhere except a white belly/chest bib.
			if p.y < -0.020 or (p.z < -0.030 and p.y < 0.030):
				return C_TUX_WHITE
			return C_TUX_BLACK
		&"grey":
			if p.y < -0.030:
				return C_GREY_BELLY
			return C_GREY_BASE
		_:
			# Tabby: dark bands across the body, derived from the face's
			# position along the spine, plus a pale belly underneath.
			if p.y < -0.040:
				return C_TABBY_BELLY
			if sin(p.z * 26.0) > 0.15:
				return C_TABBY_STRIPE
			return C_TABBY_BASE


# ---------------------------------------------------------------- head

func _build_head() -> void:
	head = Node3D.new()
	head.name = "Head"
	var neck_row: Array = BODY_PROFILE[BODY_PROFILE.size() - 1]
	var neck_z: float = neck_row[0]
	var neck_cy: float = neck_row[1]
	head.position = Vector3(0, neck_cy, neck_z)
	body.add_child(head)

	var h: RefCounted = LPB.new()
	var rings := []
	var spine := []
	for row in HEAD_PROFILE:
		var y: float = row[0]
		var z: float = row[1]
		var rx: float = row[2]
		var ry: float = row[3]
		var centre := Vector3(0, y, z)
		spine.append(centre)
		rings.append(LPB.ring(centre, Vector3(0, 0, -1), Vector3.UP,
			rx, ry, HEAD_SIDES, PI / float(HEAD_SIDES)))
	h.loft(rings, spine, Callable(self, "_head_colour"))
	h.cap(rings[0], Vector3(0, 0.012, 0.075), spine[1], Callable(self, "_head_colour"))
	h.cap(rings[rings.size() - 1], Vector3(0, -0.010, -0.170), spine[spine.size() - 2],
		Callable(self, "_head_colour"))

	# Ears: the whole silhouette read of "cat" lives here. Thin pointed
	# wedges, cheap (5 triangles apiece) and unmistakable.
	for sx in [-1.0, 1.0]:
		_build_ear(h, sx)

	# Eyes: iris block with a darker pupil block riding on top.
	for sx in [-1.0, 1.0]:
		h.box(Vector3(sx * 0.046, 0.026, -0.080), Vector3(0.011, 0.011, 0.007), C_IRIS)
		h.box(Vector3(sx * 0.051, 0.026, -0.085), Vector3(0.005, 0.007, 0.004), C_PUPIL)

	# Nose: tiny pink block at the muzzle tip.
	h.box(Vector3(0, -0.004, -0.150), Vector3(0.012, 0.008, 0.006), C_NOSE)

	# Cheek fluff either side of the muzzle, reinforcing the blunt-wide read.
	# Coloured through the same callback so it stays part of the coat.
	for sx in [-1.0, 1.0]:
		h.box(Vector3(sx * 0.052, -0.012, -0.108), Vector3(0.018, 0.016, 0.020),
			Callable(self, "_head_colour"))

	_tri_total += h.tri_count
	LPB.attach(head, h.commit(), _mat, "Skull")


func _head_colour(p: Vector3) -> Color:
	match _pattern:
		&"tuxedo":
			# White muzzle blaze plus a white chin/throat.
			if p.z < -0.078 and absf(p.x) < 0.050:
				return C_TUX_WHITE
			if p.y < -0.028:
				return C_TUX_WHITE
			return C_TUX_BLACK
		&"grey":
			if p.y < -0.028:
				return C_GREY_BELLY
			return C_GREY_BASE
		_:
			if p.z < -0.020 and sin(p.z * 30.0) > 0.10:
				return C_TABBY_STRIPE
			return C_TABBY_BASE


## `h` is a LowPolyBuilder, typed as RefCounted for the same reason the const
## above is a preload — naming the class here would reintroduce the dependency
## on global class registration. prop_models*.gd type their builder arguments
## the same way.
func _build_ear(h: RefCounted, sx: float) -> void:
	var cx := sx * 0.058
	var cy := 0.062
	var cz := -0.010
	var base := PackedVector3Array([
		Vector3(cx - 0.026, cy, cz),
		Vector3(cx, cy, cz - 0.028),
		Vector3(cx + 0.026, cy, cz),
		Vector3(cx, cy, cz + 0.026),
	])
	# Ears lean outward and slightly forward — a triangle standing proud of
	# the skull rather than a lump glued on top.
	var tip_a := Vector3(cx + sx * 0.022, cy + 0.072, cz - 0.006)
	var tip_b := Vector3(cx + sx * 0.022, cy + 0.076, cz + 0.002)
	h.wedge(base, tip_a, tip_b, Vector3(0, cy - 0.02, cz), Callable(self, "_ear_colour").bind(cz))


## The forward-facing facet of the wedge (toward the muzzle) reads as the
## inner ear; the rest carries the coat colour like real fur does.
func _ear_colour(p: Vector3, cz: float) -> Color:
	if p.z < cz - 0.006:
		return C_EAR_INNER
	return _head_colour(p)


# ---------------------------------------------------------------- legs

func _build_legs() -> void:
	var hips_row: Array = BODY_PROFILE[1]
	var hips_z: float = hips_row[0]
	var chest_row: Array = BODY_PROFILE[4]
	var chest_z: float = chest_row[0]

	legs.append(_build_leg(-0.066, chest_z, "LegFL"))
	legs.append(_build_leg( 0.066, chest_z, "LegFR"))
	legs.append(_build_leg(-0.072, hips_z, "LegBL"))
	legs.append(_build_leg( 0.072, hips_z, "LegBR"))


func _build_leg(x: float, z: float, name_hint: String) -> Node3D:
	var leg := Node3D.new()
	leg.name = name_hint
	leg.position = Vector3(x, LEG_HIP_Y, z)
	body.add_child(leg)

	var b: RefCounted = LPB.new()
	var rings := []
	var spine := []
	var radii := [0.026, 0.020, 0.015]
	for i in 3:
		var t := float(i) / 2.0
		var centre := Vector3(0, -t * LEG_LEN, 0)
		spine.append(centre)
		var r: float = radii[i]
		rings.append(LPB.ring(centre, Vector3(0, 1, 0), Vector3(0, 0, -1),
			r, r, LEG_SIDES, PI * 0.25))
	b.loft(rings, spine, Callable(self, "_leg_colour"))
	b.cap_flat(rings[rings.size() - 1], spine[spine.size() - 2], Callable(self, "_leg_colour"))

	_tri_total += b.tri_count
	LPB.attach(leg, b.commit(), _mat, "Leg")
	return leg


func _leg_colour(p: Vector3) -> Color:
	match _pattern:
		&"tuxedo":
			if p.y < -0.115:
				return C_TUX_WHITE
			return C_TUX_BLACK
		&"grey":
			return C_GREY_BASE
		_:
			if sin(p.y * 46.0) > 0.25:
				return C_TABBY_STRIPE
			return C_TABBY_BASE


# ---------------------------------------------------------------- tail

## A chain of Node3Ds, each holding one short lofted section, so an
## animation can whip the tail by rotating individual links instead of
## fighting a single rigid mesh.
func _build_tail() -> void:
	var rump_row: Array = BODY_PROFILE[0]
	var rump_z: float = rump_row[0]
	var rump_cy: float = rump_row[1]

	var parent: Node3D = body
	var base_pos := Vector3(0, rump_cy + 0.012, rump_z)
	var radius := 0.030

	for i in TAIL_SEGMENTS:
		var seg := Node3D.new()
		seg.name = "TailSeg%d" % i
		seg.position = base_pos if i == 0 else Vector3(0, 0.012, SEG_LEN)
		parent.add_child(seg)
		tail_segments.append(seg)

		var next_radius: float = radius * 0.78
		var tip := Vector3(0, 0.012, SEG_LEN)
		var b: RefCounted = LPB.new()
		var r0 := LPB.ring(Vector3.ZERO, Vector3(0, 0, 1), Vector3.UP, radius, radius, TAIL_SIDES)
		var r1 := LPB.ring(tip, Vector3(0, 0, 1), Vector3.UP, next_radius, next_radius, TAIL_SIDES)
		b.loft([r0, r1], [Vector3.ZERO, tip], Callable(self, "_tail_colour").bind(i))
		if i == TAIL_SEGMENTS - 1:
			b.cap(r1, tip + Vector3(0, 0.012, 0.030), tip * 0.5, Callable(self, "_tail_colour").bind(i))

		_tri_total += b.tri_count
		LPB.attach(seg, b.commit(), _mat, "TailSeg")

		radius = next_radius
		parent = seg


func _tail_colour(p: Vector3, seg_index: int) -> Color:
	match _pattern:
		&"tuxedo":
			if seg_index >= TAIL_SEGMENTS - 1:
				return C_TUX_WHITE
			return C_TUX_BLACK
		&"grey":
			return C_GREY_BASE
		_:
			if seg_index % 2 == 1:
				return C_TABBY_STRIPE
			return C_TABBY_BASE


# ---------------------------------------------------------------- animation

## Leg cycling proportional to speed (alternating diagonal pairs, the way a
## cat actually walks), tail sway, and at high frenzy an unhinged tail whip
## plus a body wiggle. Catnip should look like it has genuinely broken them.
func animate(delta: float, speed: float, frenzy: float) -> void:
	if body == null:
		return
	frenzy = clampf(frenzy, 0.0, 1.0)
	speed = maxf(speed, 0.0)

	_walk_phase += delta * (2.0 + speed * 3.0 + frenzy * 9.0)
	var stride := clampf(speed * 0.6 + frenzy * 0.5, 0.0, 1.4)
	if legs.size() == 4:
		# Diagonal pairs: front-left+back-right together, front-right+back-left
		# together, half a cycle apart — the real feline gait.
		var a := sin(_walk_phase) * 0.5 * stride
		var bp := sin(_walk_phase + PI) * 0.5 * stride
		legs[0].rotation.x = a    # front-left
		legs[3].rotation.x = a    # back-right
		legs[1].rotation.x = bp   # front-right
		legs[2].rotation.x = bp   # back-left

	_tail_phase += delta * (1.6 + frenzy * 14.0)
	if tail_segments.size() > 0:
		var base_sway := sin(_tail_phase) * lerpf(0.20, 0.10, frenzy)
		if frenzy > 0.05:
			# Unhinged whip: layered fast sines instead of a clean sway, so it
			# looks like it's lost control of itself rather than just sped up.
			base_sway += (sin(_tail_phase * 3.3) + sin(_tail_phase * 5.7 + 1.3)) * 0.35 * frenzy
		for i in tail_segments.size():
			var damp := 1.0 - float(i) * 0.12
			tail_segments[i].rotation.y = base_sway * damp
			tail_segments[i].rotation.x = sin(_tail_phase * 1.3 + float(i)) * 0.08 * damp

	_wiggle_phase += delta * (3.0 + speed * 2.0 + frenzy * 16.0)
	body.rotation.z = sin(_wiggle_phase) * lerpf(0.03, 0.30, frenzy) * (0.3 + speed * 0.2 + frenzy)
	body.position.y = STAND_Y + absf(sin(_wiggle_phase * 0.5)) * lerpf(0.0, 0.05, frenzy)
	if head:
		head.rotation.y = sin(_wiggle_phase * 0.7) * lerpf(0.05, 0.55, frenzy)
		head.rotation.z = sin(_wiggle_phase * 1.1 + 0.6) * lerpf(0.02, 0.32, frenzy)


## All colour is in vertex colours and the material is white, so tinting the
## entire cat is one multiply — same trick as the goose.
func set_tint(c: Color, amount: float) -> void:
	if _mat == null:
		return
	_mat.albedo_color = Color.WHITE.lerp(c, clampf(amount, 0.0, 0.65))


## Triangle count, for the dev overlay and for keeping an eye on the budget.
func triangle_count() -> int:
	return _tri_total
