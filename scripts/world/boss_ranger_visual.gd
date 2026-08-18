extends Node3D
## LOW-POLY BORDER COLLIE — "PIPER", and the Ranger's kit.
##
## The dog is a fork of cat_visual_lowpoly.gd in the same sense that the design
## doc means it: same vocabulary, same builder, same conventions, different
## animal. Longer, taller, a plumed tail, a dropped head when it is working, and
## a two-tone coat that is the whole silhouette read.
##
## Polygons only — no SphereMesh, no CapsuleMesh, no CylinderMesh. Flat normals,
## one material, all colour in vertex colours so a tint is one multiply.
##
## ORIENTATION: faces -Z, matching Node3D's forward. Nose at negative Z, tail at
## positive Z. If you add a part, put its front at NEGATIVE Z.
##
## TWO COATS, ONE DOG. `setup(&"collie")` is Piper, the Ranger's working dog.
## `setup(&"golden")` is Molly, the retriever asleep in a Suburbia backyard —
## same build, retriever colouring, ears dropped. zone_suburbia.gd used to
## carry its own CapsuleMesh-and-SphereMesh dog for Molly, which is exactly the
## "this project has repeatedly grown a second copy of something that already
## existed" failure CLAUDE.md names. A palette is cheaper than a second animal.
##
## FACET BUDGET: roughly 500-700 triangles. See triangle_count().
##
## ---------------------------------------------------------------------------
## The bottom of this file is the Ranger's kit — the hi-vis vest, the ball cap,
## the clipboard and the truck's light bar — as static builders. They live here
## rather than in boss_ranger.gd for the same reason the goose's mesh does not
## live in goose_controller.gd: geometry and behaviour are different jobs and
## boss_ranger.gd is already the long one.

const LPB := preload("res://scripts/goose/lowpoly_builder.gd")

# ---------------------------------------------------------------- the coat

const C_BLACK := Color(0.075, 0.072, 0.080)
const C_WHITE := Color(0.925, 0.920, 0.900)
const C_TAN := Color(0.52, 0.36, 0.20)
const C_NOSE := Color(0.055, 0.050, 0.055)
const C_IRIS := Color(0.42, 0.28, 0.12)
const C_PUPIL := Color(0.04, 0.04, 0.05)
const C_EAR_INNER := Color(0.62, 0.44, 0.42)
const C_TONGUE := Color(0.86, 0.36, 0.42)

const BODY_SIDES := 6
const HEAD_SIDES := 6
const LEG_SIDES := 4
const TAIL_SIDES := 5

## The coat palettes. `main` is the saddle, `light` is everything a collie
## carries in white (chest, belly, collar, socks, tail tip) and a retriever
## carries in cream. `ear_drop` is 0 for a collie's semi-prick ear and 1 for a
## retriever's pendant one.
const COATS := {
	&"collie": {
		"main": C_BLACK, "light": C_WHITE, "brow": C_TAN, "ear_drop": 0.0,
	},
	&"golden": {
		"main": Color(0.82, 0.60, 0.28), "light": Color(0.94, 0.86, 0.66),
		"brow": Color(0.64, 0.44, 0.20), "ear_drop": 1.0,
	},
}

const LEG_LEN := 0.34
const SEG_LEN := 0.098
const TAIL_SEGMENTS := 4

## Where the body node sits so the PAWS land on y = 0.
##
## Not LEG_LEN. The leg chain hangs from the body at -0.052, runs LEG_LEN down,
## and then the paw block adds another 0.034 under that — so a body parked at
## LEG_LEN buries every foot 8.6 cm in the asphalt. cat_visual_lowpoly.gd has
## the same off-by-a-paw and it is much less visible on a shorter animal.
const STAND_Y := 0.426

## Seven cross-sections, tail root to neck base. A collie is deep-chested and
## tucked at the waist; compare ry at row 3 (waist) with row 4 (chest). That
## difference is what stops this reading as a big cat.
const BODY_PROFILE := [
	# z,      cy,     rx,    ry
	[ 0.380,  0.014,  0.052, 0.058],
	[ 0.288,  0.030,  0.104, 0.104],
	[ 0.166,  0.026,  0.118, 0.118],
	[ 0.030,  0.016,  0.108, 0.126],
	[-0.112,  0.012,  0.122, 0.156],
	[-0.234,  0.014,  0.100, 0.128],
	[-0.330,  0.034,  0.062, 0.082],
]

## Local to the head node. Broad skull, a real stop, then a tapering muzzle.
const HEAD_PROFILE := [
	# y,      z,      rx,    ry
	[ 0.000,  0.042,  0.078, 0.076],
	[ 0.030, -0.030,  0.096, 0.092],
	[ 0.016, -0.100,  0.075, 0.071],
	[-0.002, -0.166,  0.052, 0.050],
	[-0.014, -0.224,  0.038, 0.036],
]

var body: Node3D
var neck: Node3D
var head: Node3D
var legs: Array[Node3D] = []
var tail_segments: Array[Node3D] = []
var tint_targets: Array[StandardMaterial3D] = []

var _mat: StandardMaterial3D
## Live coat colours, resolved from COATS in setup(). Every marking callback
## reads these rather than the C_BLACK/C_WHITE constants, which is the whole
## mechanism behind the second coat.
var _c_main := C_BLACK
var _c_light := C_WHITE
var _c_brow := C_TAN
var _ear_drop := 0.0
var _built := false
var _tri_total := 0

var _walk_phase := 0.0
var _tail_phase := 0.0
var _stalk := 0.0


func _ready() -> void:
	if not _built:
		_build()


## Kept for symmetry with cat_visual_lowpoly.gd / human_visual_lowpoly.gd —
## every creature model in this project is safe to `setup()` before or after it
## enters the tree.
##
## [param coat] picks a palette out of COATS. An unknown name falls back to the
## collie rather than to an untinted dog.
func setup(coat: StringName = &"collie") -> void:
	var pal: Dictionary = COATS.get(coat, COATS[&"collie"])
	_c_main = pal["main"]
	_c_light = pal["light"]
	_c_brow = pal["brow"]
	_ear_drop = pal["ear_drop"]
	_build()


func _build() -> void:
	_built = true
	for c in get_children():
		c.queue_free()
	legs.clear()
	tail_segments.clear()

	_mat = LPB.make_material(0.94)
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
	b.cap(rings[0], Vector3(0, 0.040, 0.420), spine[1], Callable(self, "_body_colour"))
	b.cap(rings[rings.size() - 1], Vector3(0, 0.040, -0.372), spine[spine.size() - 2],
		Callable(self, "_body_colour"))

	var tc: int = b.tri_count
	_tri_total += tc
	LPB.attach(body, b.commit(), _mat, "Torso")


## Border collie markings, painted per face from where the face sits: black
## saddle, white belly, white chest blaze, and the collar ring that is the one
## marking everybody can name.
func _body_colour(p: Vector3) -> Color:
	# The collar: a full white ring around the neck.
	if p.z < -0.255:
		return _c_light
	# Chest and belly.
	if p.y < -0.052:
		return _c_light
	if p.z < -0.150 and p.y < 0.030:
		return _c_light
	# A white tip on the rump, where the tail joins.
	if p.z > 0.340:
		return _c_light
	return _c_main


# ---------------------------------------------------------------- head

func _build_head() -> void:
	# A separate neck node so the stalk (head down, level with the shoulders)
	# is one rotation rather than a second head model.
	neck = Node3D.new()
	neck.name = "Neck"
	var neck_row: Array = BODY_PROFILE[BODY_PROFILE.size() - 1]
	var neck_z: float = neck_row[0]
	var neck_cy: float = neck_row[1]
	neck.position = Vector3(0, neck_cy + 0.046, neck_z - 0.020)
	body.add_child(neck)

	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.098, -0.078)
	neck.add_child(head)

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
	h.cap(rings[0], Vector3(0, 0.012, 0.098), spine[1], Callable(self, "_head_colour"))
	h.cap(rings[rings.size() - 1], Vector3(0, -0.018, -0.256), spine[spine.size() - 2],
		Callable(self, "_head_colour"))

	for sx in [-1.0, 1.0]:
		_build_ear(h, sx)

	# Eyes. A collie's eyes are the working end of the animal, so they get an
	# iris block and a pupil block proud of the skull rather than a painted face.
	for sx in [-1.0, 1.0]:
		h.box(Vector3(sx * 0.058, 0.034, -0.080), Vector3(0.015, 0.014, 0.009), C_IRIS)
		h.box(Vector3(sx * 0.064, 0.034, -0.086), Vector3(0.007, 0.008, 0.006), C_PUPIL)
		# Tan eyebrow pips — the marking that makes a black dog have a face.
		h.box(Vector3(sx * 0.055, 0.064, -0.068), Vector3(0.018, 0.008, 0.016), _c_brow)

	# Nose: a blunt block at the muzzle tip, not a point.
	h.box(Vector3(0, 0.002, -0.246), Vector3(0.027, 0.019, 0.015), C_NOSE)
	# Tongue. It is always out. That is the joke and it costs six triangles.
	h.box(Vector3(0, -0.034, -0.204), Vector3(0.018, 0.011, 0.052), C_TONGUE)

	var tc: int = h.tri_count
	_tri_total += tc
	LPB.attach(head, h.commit(), _mat, "Skull")


## Semi-prick: a wedge standing off the skull, leaning back and outward, with
## the tip tilted forward so it reads as folded rather than as a cat's spike.
func _build_ear(h: RefCounted, sx: float) -> void:
	var cx := sx * 0.070
	var cy := 0.072
	var cz := 0.008
	var base := PackedVector3Array([
		Vector3(cx - 0.030, cy, cz),
		Vector3(cx, cy, cz - 0.034),
		Vector3(cx + 0.030, cy, cz),
		Vector3(cx, cy, cz + 0.032),
	])
	# A collie's ear stands up and leans back; a retriever's hangs down and
	# forward off the same base, so one lerp covers both.
	var tip_a := Vector3(cx + sx * 0.032, cy + 0.086, cz + 0.022).lerp(
		Vector3(cx + sx * 0.048, cy - 0.070, cz - 0.010), _ear_drop)
	var tip_b := Vector3(cx + sx * 0.036, cy + 0.078, cz + 0.032).lerp(
		Vector3(cx + sx * 0.054, cy - 0.078, cz + 0.026), _ear_drop)
	h.wedge(base, tip_a, tip_b, Vector3(0, cy - 0.03, cz), Callable(self, "_ear_colour").bind(cz))


## On a semi-prick ear the one forward-facing facet of the wedge is the inner
## ear. On a PENDANT ear that same facet swings out to become the whole lateral
## flap, so the collie's threshold painted Molly's entire ear pink — the render
## caught it. The threshold moves with the ear, which retires the face for a
## drop ear and leaves the collie exactly as it was.
func _ear_colour(p: Vector3, cz: float) -> Color:
	if p.z < cz - lerpf(0.010, 0.030, _ear_drop):
		return C_EAR_INNER
	return _c_main


## White blaze straight down the middle of the face, white muzzle, black
## everywhere else. This is the single most recognisable dog marking there is.
func _head_colour(p: Vector3) -> Color:
	if absf(p.x) < 0.027 and p.z < -0.010:
		return _c_light
	if p.z < -0.134:
		return _c_light
	if p.y < -0.030:
		return _c_light
	return _c_main


# ---------------------------------------------------------------- legs

func _build_legs() -> void:
	var chest_row: Array = BODY_PROFILE[4]
	var chest_z: float = chest_row[0]
	var hips_row: Array = BODY_PROFILE[2]
	var hips_z: float = hips_row[0]

	legs.append(_build_leg(-0.078, chest_z + 0.020, "LegFL"))
	legs.append(_build_leg( 0.078, chest_z + 0.020, "LegFR"))
	legs.append(_build_leg(-0.086, hips_z - 0.020, "LegBL"))
	legs.append(_build_leg( 0.086, hips_z - 0.020, "LegBR"))


func _build_leg(x: float, z: float, name_hint: String) -> Node3D:
	var leg := Node3D.new()
	leg.name = name_hint
	leg.position = Vector3(x, -0.052, z)
	body.add_child(leg)

	var b: RefCounted = LPB.new()
	var rings := []
	var spine := []
	var radii := [0.036, 0.026, 0.019]
	for i in 3:
		var t := float(i) / 2.0
		var centre := Vector3(0, -t * LEG_LEN, 0)
		spine.append(centre)
		var r: float = radii[i]
		rings.append(LPB.ring(centre, Vector3(0, 1, 0), Vector3(0, 0, -1),
			r, r, LEG_SIDES, PI * 0.25))
	b.loft(rings, spine, Callable(self, "_leg_colour"))
	b.cap_flat(rings[rings.size() - 1], spine[spine.size() - 2], _c_light)
	# Paw: a white block, nudged forward so the leg ends in a foot and not a
	# stick. Collies have white socks; this is where they live.
	b.box(Vector3(0, -LEG_LEN - 0.014, -0.018), Vector3(0.030, 0.020, 0.046), _c_light)

	var tc: int = b.tri_count
	_tri_total += tc
	LPB.attach(leg, b.commit(), _mat, "Leg")
	return leg


func _leg_colour(p: Vector3) -> Color:
	if p.y < -LEG_LEN * 0.52:
		return _c_light
	return _c_main


# ---------------------------------------------------------------- tail

## A plume, not a rope: the radius barely tapers for the first three links and
## the last one is white. A collie's tail is the readout on its mood and this
## one is animated hard, so it is worth the five links.
func _build_tail() -> void:
	var rump_row: Array = BODY_PROFILE[0]
	var rump_z: float = rump_row[0]
	var rump_cy: float = rump_row[1]

	var parent: Node3D = body
	var base_pos := Vector3(0, rump_cy + 0.030, rump_z)
	var radius := 0.058

	for i in TAIL_SEGMENTS:
		var seg := Node3D.new()
		seg.name = "TailSeg%d" % i
		seg.position = base_pos if i == 0 else Vector3(0, 0.0, SEG_LEN)
		parent.add_child(seg)
		tail_segments.append(seg)

		var next_radius: float = radius * (0.92 if i < 2 else 0.80)
		var tip := Vector3(0, 0.006, SEG_LEN)
		var b: RefCounted = LPB.new()
		var r0 := LPB.ring(Vector3.ZERO, Vector3(0, 0, 1), Vector3.UP, radius, radius, TAIL_SIDES)
		var r1 := LPB.ring(tip, Vector3(0, 0, 1), Vector3.UP, next_radius, next_radius, TAIL_SIDES)
		b.loft([r0, r1], [Vector3.ZERO, tip], Callable(self, "_tail_colour").bind(i))
		if i == TAIL_SEGMENTS - 1:
			b.cap(r1, tip + Vector3(0, 0.008, 0.034), tip * 0.5, _c_light)

		var tc: int = b.tri_count
		_tri_total += tc
		LPB.attach(seg, b.commit(), _mat, "TailSeg")

		radius = next_radius
		parent = seg


func _tail_colour(_p: Vector3, seg_index: int) -> Color:
	if seg_index >= TAIL_SEGMENTS - 1:
		return _c_light
	return _c_main


# ---------------------------------------------------------------- animation

## [param speed] 0..1 of top speed, [param chase] 0..1 of "working".
##
## The stalk is the characterisation and it is free: a working collie drops its
## head to shoulder height and locks on. At chase 0 the head is up and the tail
## sways; at chase 1 the head is level with the spine, the body leans in, and
## the tail streams out flat behind. Nothing else in this game moves like that.
func animate(delta: float, speed: float, chase: float) -> void:
	if body == null:
		return
	chase = clampf(chase, 0.0, 1.0)
	speed = clampf(speed, 0.0, 2.0)
	_stalk = lerpf(_stalk, chase, 1.0 - pow(0.02, delta))

	_walk_phase += delta * (2.2 + speed * 9.0)
	var stride := clampf(0.28 + speed * 1.05, 0.0, 1.5)
	if legs.size() == 4:
		# Diagonal pairs, same as the cat: a dog at a trot moves front-left with
		# back-right. At a flat gallop this reads as a gallop anyway because the
		# stride is long enough to over-rotate.
		var a := sin(_walk_phase) * 0.6 * stride
		var bp := sin(_walk_phase + PI) * 0.6 * stride
		legs[0].rotation.x = a
		legs[3].rotation.x = a
		legs[1].rotation.x = bp
		legs[2].rotation.x = bp

	_tail_phase += delta * (2.4 + speed * 6.0)
	if tail_segments.size() > 0:
		# Idle: a wide happy sway. Working: streamed out behind, barely moving.
		var sway := sin(_tail_phase) * lerpf(0.30, 0.07, _stalk)
		# NOTE THE SIGN. Positive rotation.x droops the chain. A working collie
		# carries its tail LOW and level; a pleased one carries it up. The first
		# render had this exactly backwards.
		var lift := lerpf(-0.30, 0.26, _stalk)
		for i in tail_segments.size():
			var damp := 1.0 - float(i) * 0.11
			tail_segments[i].rotation.y = sway * damp
			tail_segments[i].rotation.x = lift * 0.6 + sin(_tail_phase * 1.4 + float(i)) * 0.06 * damp

	if neck:
		# Head down and forward when working, up and cheerful when not.
		neck.rotation.x = lerpf(-0.14, 0.46, _stalk)
		neck.position.y = lerpf(0.064, 0.016, _stalk)
	if head:
		head.rotation.x = lerpf(0.10, -0.40, _stalk)
		head.rotation.z = sin(_walk_phase * 0.5) * 0.05 * (1.0 - _stalk)

	body.rotation.x = lerpf(0.0, 0.10, _stalk)
	body.rotation.z = sin(_walk_phase * 0.5) * 0.035 * (0.4 + speed)
	body.position.y = STAND_Y + absf(sin(_walk_phase)) * 0.028 * (0.3 + speed)


## Mouth-carrying pose: head up and proud, tail straight out and wagging like
## mad. Called every frame while the dog is carrying the goose.
func carry_pose(delta: float) -> void:
	_stalk = lerpf(_stalk, 0.0, 1.0 - pow(0.02, delta))
	_tail_phase += delta * 22.0
	if neck:
		neck.rotation.x = lerpf(neck.rotation.x, -0.34, 1.0 - pow(0.02, delta))
	if head:
		head.rotation.x = lerpf(head.rotation.x, 0.22, 1.0 - pow(0.02, delta))
	for i in tail_segments.size():
		tail_segments[i].rotation.y = sin(_tail_phase + float(i) * 0.5) * 0.5
		tail_segments[i].rotation.x = -0.30


func set_tint(c: Color, amount: float) -> void:
	if _mat == null:
		return
	_mat.albedo_color = Color.WHITE.lerp(c, clampf(amount, 0.0, 0.65))


func triangle_count() -> int:
	return _tri_total


# ===========================================================================
# THE RANGER'S KIT
#
# Static builders. Each returns a MeshInstance3D already parented, so the
# caller is one line. They all share the LowPolyBuilder material so the whole
# encounter is the same handful of draw calls as the rest of the street.
# ===========================================================================

const C_HIVIS := Color(0.86, 0.94, 0.16)
const C_REFLECT := Color(0.90, 0.92, 0.95)
const C_CAP := Color(0.20, 0.28, 0.20)
const C_BOARD := Color(0.42, 0.28, 0.16)
const C_PAPER := Color(0.94, 0.94, 0.91)
const C_CLIP := Color(0.72, 0.74, 0.78)


## Hi-vis vest, built to sit OVER human_visual_lowpoly.gd's torso.
##
## That torso's widest half-width is 0.192 at the shoulders and its depth is
## ~0.13, and it spans y 0.0 (waist) to 0.55 (collar) in `body` local space. The
## vest is deliberately a size too big — municipal PPE always is — which also
## guarantees it never z-fights the shirt underneath.
static func build_vest(parent: Node3D) -> MeshInstance3D:
	var b: RefCounted = LPB.new()
	b.box(Vector3(0.0, 0.296, -0.006), Vector3(0.199, 0.164, 0.140), C_HIVIS)
	# Two reflective bands. Thin boxes rather than painted faces: at this facet
	# density a painted stripe on a box IS a box, which is the same note
	# flock_pen.gd's vest carries.
	b.box(Vector3(0.0, 0.366, -0.006), Vector3(0.205, 0.022, 0.146), C_REFLECT)
	b.box(Vector3(0.0, 0.216, -0.006), Vector3(0.205, 0.022, 0.146), C_REFLECT)
	# Shoulder yoke, so it reads from directly above — which is where this
	# game's camera actually is.
	for sx in [-1.0, 1.0]:
		b.box(Vector3(sx * 0.132, 0.452, -0.006), Vector3(0.056, 0.034, 0.112), C_HIVIS)
	return LPB.attach(parent, b.commit(), LPB.make_material(0.86), "Vest")


## Ball cap, built to sit on human_visual_lowpoly.gd's head node (crown at
## local y ~0.265, skull half-width ~0.099).
static func build_cap(parent: Node3D) -> MeshInstance3D:
	var b: RefCounted = LPB.new()
	# A band that grips the skull (widest skull half-width is 0.099), a smaller
	# crown on top of it, a button, and a SHORT peak. The first version was one
	# wide flat slab plus a long brim and rendered as a mortarboard.
	b.box(Vector3(0.0, 0.176, 0.004), Vector3(0.104, 0.060, 0.104), C_CAP)
	b.box(Vector3(0.0, 0.238, 0.002), Vector3(0.086, 0.034, 0.090), C_CAP)
	b.box(Vector3(0.0, 0.274, 0.000), Vector3(0.020, 0.014, 0.020), C_CAP)
	# The peak. Forward is -Z.
	b.box(Vector3(0.0, 0.136, -0.148), Vector3(0.086, 0.015, 0.058), C_CAP)
	return LPB.attach(parent, b.commit(), LPB.make_material(0.90), "Cap")


## The clipboard, as geometry. The live Label3D face is added by boss_ranger.gd
## because it has to be updated; this is only the object.
##
## Authored centred on its own origin (NOT base-anchored) because it is carried
## in a hand and dropped as a ChaosProp, and both of those want a centre.
## Deliberately oversized — 0.38 x 0.47 m, which is a good deal bigger than any
## real clipboard. BOSS_DESIGN.md §2.1.5 wants "a giant white rectangle held at
## chest height" that reads from across the zone, and it has to be wide enough
## for the live label not to overhang it. A rendered pass with a 0.30 m board
## had "CANADIAN GEESE" sticking out both sides.
static func build_clipboard(parent: Node3D) -> MeshInstance3D:
	var b: RefCounted = LPB.new()
	b.box(Vector3(0, 0, 0.010), Vector3(0.190, 0.235, 0.012), C_BOARD)
	b.box(Vector3(0, -0.014, -0.006), Vector3(0.170, 0.210, 0.006), C_PAPER)
	# The clip, at the top.
	b.box(Vector3(0, 0.208, -0.010), Vector3(0.070, 0.028, 0.013), C_CLIP)
	return LPB.attach(parent, b.commit(), LPB.make_material(0.80), "Clipboard")


## CONSERVATION SERVICES on the truck's doors — BOTH flanks.
##
## Real vehicle lettering reads forwards from either side of the vehicle, which
## means the two sides are MIRROR IMAGES OF EACH OTHER. Duplicating one decal
## across X gets you a correct near side and a backwards far side; giving both
## sides the same yaw gets you the same thing. Each flank needs its own yaw,
## and this is the whole reason this is a function instead of two lines at the
## call site.
##
## WHY IT WAS BACKWARDS. A Label3D lays its text out along its own +X with its
## face on its own +Z, and `double_sided` defaults to TRUE — so a label whose
## front points INTO the vehicle is not culled, it is drawn from behind and
## reads "ƎƆIVЯƎƧ". That is exactly what shipped: one label at x = -1.09 with
## rotation.y = +PI/2, whose +Z pointed at +X, i.e. straight into the truck.
##
## The rule, for a body authored facing -Z (see CLAUDE.md § Physics):
##   -X flank: viewer is at -X looking toward +X, so screen-right is +Z.
##             Text must run along +Z   ->  rotation.y = -PI/2.
##   +X flank: viewer is at +X looking toward -X, so screen-right is -Z.
##             Text must run along -Z   ->  rotation.y = +PI/2.
## In both cases the label's own +Z ends up pointing OUT of the vehicle, and
## that is the one-glance check: front face outward means not mirrored.
##
## `double_sided` is switched off deliberately. It turns a future winding
## mistake from "silently mirrored" — which shipped once and survived a whole
## boss encounter — into "the decal is gone", which the first render catches.
## Nothing can see the inboard face anyway; the truck body is in the way.
static func build_door_decals(parent: Node3D, text := "CONSERVATION\nSERVICES",
		half_width := 1.09, y := 1.05, z := -0.6) -> Array[Label3D]:
	var out: Array[Label3D] = []
	for side in [-1.0, 1.0]:
		var l := Label3D.new()
		l.name = "DoorDecalNegX" if side < 0.0 else "DoorDecalPosX"
		l.text = text
		l.pixel_size = 0.0032
		l.modulate = Color(0.12, 0.28, 0.20)
		l.shaded = false
		l.double_sided = false
		l.outline_size = 0
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.position = Vector3(side * half_width, y, z)
		# side -1 -> -PI/2, side +1 -> +PI/2. The mirror is in the sign.
		l.rotation.y = side * PI * 0.5
		parent.add_child(l)
		out.append(l)
	return out


## The truck's light bar. Two lenses on a black base; boss_ranger.gd puts an
## OmniLight3D between them and alternates its colour.
static func build_light_bar(parent: Node3D) -> MeshInstance3D:
	var b: RefCounted = LPB.new()
	b.box(Vector3(0, 0, 0), Vector3(0.62, 0.045, 0.16), Color(0.12, 0.12, 0.14))
	b.box(Vector3(-0.30, 0.070, 0), Vector3(0.28, 0.070, 0.140), Color(0.90, 0.16, 0.16))
	b.box(Vector3( 0.30, 0.070, 0), Vector3(0.28, 0.070, 0.140), Color(0.20, 0.36, 0.92))
	var mat := LPB.make_material(0.42)
	# The lenses have to read at dusk from across the cul-de-sac, and this zone
	# is authored at golden hour. Emission on the shared vertex colours lights
	# both lenses in their own colour for free.
	mat.emission_enabled = true
	mat.emission = Color(1, 1, 1)
	# MULTIPLY, not ADD. A flat emission colour is not per-vertex, so an additive
	# white would light both lenses the same and throw the red/blue away — which
	# is the entire read. Multiplying against the vertex albedo makes each lens
	# glow in its own colour and leaves the black base dark for free.
	mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	mat.emission_energy_multiplier = 0.9
	return LPB.attach(parent, b.commit(), mat, "LightBar")
