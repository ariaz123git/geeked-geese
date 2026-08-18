extends Node3D
## LOW-POLY HUMAN — polygons only.
##
## Same rules as the goose and the cat: no SphereMesh, no CapsuleMesh, no
## CylinderMesh, no curved primitives. A lofted torso, a separate head, two
## arm chains (upper arm -> forearm, with a block hand riding on the
## forearm), two leg chains (thigh -> shin, with a block shoe riding on the
## shin), and a faceted hair cap. Flat normals throughout, one material, all
## colour carried in vertex colours.
##
## These people exist to be terrorised by a bird. Build them a little chunky
## and a little goofy — that's the joke, not a bug.
##
## ORIENTATION: faces -Z, matching Node3D's forward. If you add a part, put
## its front at NEGATIVE Z.
##
## FACET BUDGET: roughly 400-650 triangles. See triangle_count().

## Preloaded rather than referenced by class_name: global class registration
## only exists after an editor import pass, so a `class_name` reference breaks
## in a fresh checkout or a headless CI run. A preload const always resolves.
const LPB := preload("res://scripts/goose/lowpoly_builder.gd")

const C_SHOE := Color(0.09, 0.08, 0.09)
const C_EYE := Color(0.05, 0.05, 0.06)

## Hardcoded hair palette, picked deterministically from the shirt's hue so a
## crowd of NPCs looks varied without a hair parameter of their own.
const HAIR_COLOURS := [
	Color(0.085, 0.065, 0.055),  # near-black brown
	Color(0.42, 0.26, 0.14),     # brown
	Color(0.74, 0.56, 0.28),     # blonde
	Color(0.55, 0.14, 0.10),     # auburn
	Color(0.72, 0.72, 0.75),     # grey
]

const TORSO_SIDES := 8
const HEAD_SIDES := 8
const HAIR_SIDES := 8
const LIMB_SIDES := 6

const LEG_TOTAL := 0.92
const THIGH_LEN := 0.46
const SHIN_LEN := 0.46
const UPPER_ARM_LEN := 0.27
const FOREARM_LEN := 0.25

## Shoe block, as constants, because the STANDING HEIGHT is derived from them.
## The shoe hangs off the bottom of the shin, so the leg does not end at the
## ankle — it ends at the sole, SOLE_DROP lower.
const SHOE_DROP := 0.024       ## ankle -> shoe centre
const SHOE_HALF_Y := 0.042     ## shoe centre -> sole
const SOLE_DROP := SHOE_DROP + SHOE_HALF_Y

## Where `body` sits so the SOLES land on y = 0. The shared origin convention
## for every creature in this project is "origin = ground".
##
## NOT LEG_TOTAL. That was the bug: it put the ankles on the floor and buried
## every shoe 6.6 cm in the pavement — all eight Suburbia NPCs, the strip-mall
## crowd, the cottage crowd and the Ranger. boss_ranger.gd carried a
## `_lp.position.y = 0.066` to compensate; that compensator has been removed,
## so do not add a new one anywhere. If you change the shoe, change it through
## SHOE_DROP / SHOE_HALF_Y and this stays correct.
const HIP_Y := LEG_TOTAL + SOLE_DROP

const WAIST_Y := 0.045
const COLLAR_Y := 0.50

## Eight cross-sections, hips to neck base. Chunky and a bit paunchy — this
## is a comedy game, not an anatomy reference. [y, z-offset, half-width, half-depth]
const TORSO_PROFILE := [
	[0.000,  0.000, 0.145, 0.100],
	[0.070,  0.000, 0.158, 0.118],
	[0.140, -0.012, 0.168, 0.132],
	[0.230, -0.010, 0.176, 0.120],
	[0.330, -0.004, 0.182, 0.108],
	[0.420,  0.000, 0.188, 0.100],
	[0.480,  0.000, 0.192, 0.098],
	[0.550,  0.000, 0.076, 0.070],
]

## Local to the head node, stacked straight up. Deliberately blocky: width
## and height are close to 1:1 so it reads as a chunky skull, not a dunce cap.
## [y, rx, rz]
const HEAD_PROFILE := [
	[0.000, 0.082, 0.082],
	[0.045, 0.096, 0.093],
	[0.130, 0.099, 0.096],
	[0.195, 0.086, 0.083],
	[0.235, 0.060, 0.058],
]

var body: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var tint_targets: Array[StandardMaterial3D] = []

var _forearm_l: Node3D
var _forearm_r: Node3D
var _shin_l: Node3D
var _shin_r: Node3D

var _mat: StandardMaterial3D
var _shirt := Color(0.55, 0.35, 0.30)
var _pants := Color(0.17, 0.19, 0.26)
var _skin := Color(0.86, 0.69, 0.56)
var _hair := Color(0.09, 0.07, 0.06)
var _built := false
var _tri_total := 0

var _walk_phase := 0.0


func _ready() -> void:
	if not _built:
		_build()


## Clothing colours. Safe to call before or after the node enters the tree —
## if _ready() already built a default person, this tears it down and
## rebuilds with the requested colours.
func setup(shirt: Color, pants := Color(0.17, 0.19, 0.26), skin := Color(0.86, 0.69, 0.56)) -> void:
	_shirt = shirt
	_pants = pants
	_skin = skin
	var idx: int = int(shirt.h * float(HAIR_COLOURS.size())) % HAIR_COLOURS.size()
	_hair = HAIR_COLOURS[idx]
	_build()


func _build() -> void:
	_built = true
	for c in get_children():
		c.queue_free()

	_mat = LPB.make_material(0.94)
	tint_targets.clear()
	tint_targets.append(_mat)
	_tri_total = 0

	body = Node3D.new()
	body.name = "Body"
	body.position.y = HIP_Y
	add_child(body)

	_build_torso()
	_build_head()
	_build_hair()
	arm_l = _build_arm(-1.0)
	arm_r = _build_arm(1.0)
	leg_l = _build_leg(-1.0)
	leg_r = _build_leg(1.0)


# ---------------------------------------------------------------- torso

func _build_torso() -> void:
	var b: RefCounted = LPB.new()
	var rings := []
	var spine := []
	for row in TORSO_PROFILE:
		var y: float = row[0]
		var cz: float = row[1]
		var rx: float = row[2]
		var rz: float = row[3]
		var centre := Vector3(0, y, cz)
		spine.append(centre)
		rings.append(LPB.ring(centre, Vector3(0, 1, 0), Vector3(0, 0, -1),
			rx, rz, TORSO_SIDES, PI / float(TORSO_SIDES)))

	b.loft(rings, spine, Callable(self, "_torso_colour"))
	b.cap_flat(rings[0], spine[1], _pants)
	b.cap(rings[rings.size() - 1], Vector3(0, 0.610, 0.0), spine[spine.size() - 2],
		Callable(self, "_torso_colour"))

	_tri_total += b.tri_count
	LPB.attach(body, b.commit(), _mat, "Torso")


## Shirt above the waist, pants below, with a subtle collar band in a darker
## shade of the shirt right at the neck.
func _torso_colour(p: Vector3) -> Color:
	if p.y < WAIST_Y:
		return _pants
	if p.y > COLLAR_Y:
		return _shirt.darkened(0.30)
	return _shirt


# ---------------------------------------------------------------- head

func _build_head() -> void:
	head = Node3D.new()
	head.name = "Head"
	var neck_row: Array = TORSO_PROFILE[TORSO_PROFILE.size() - 1]
	var neck_y: float = neck_row[0]
	head.position = Vector3(0, neck_y, 0)
	body.add_child(head)

	var h: RefCounted = LPB.new()
	var rings := []
	var spine := []
	for row in HEAD_PROFILE:
		var y: float = row[0]
		var rx: float = row[1]
		var rz: float = row[2]
		var centre := Vector3(0, y, 0)
		spine.append(centre)
		rings.append(LPB.ring(centre, Vector3(0, 1, 0), Vector3(0, 0, -1),
			rx, rz, HEAD_SIDES, PI / float(HEAD_SIDES)))
	h.loft(rings, spine, _skin)
	h.cap_flat(rings[0], spine[1], _skin)
	h.cap(rings[rings.size() - 1], Vector3(0, 0.265, 0.0), spine[spine.size() - 2], _skin)

	# Nose: a simple faceted wedge, not a curve.
	var nose_base := PackedVector3Array([
		Vector3(-0.020, 0.095, -0.094),
		Vector3( 0.020, 0.095, -0.094),
		Vector3( 0.020, 0.140, -0.094),
		Vector3(-0.020, 0.140, -0.094),
	])
	h.wedge(nose_base, Vector3(0, 0.112, -0.145), Vector3(0, 0.122, -0.145),
		Vector3(0, 0.117, -0.075), _skin)

	# Eyes: dark blocks proud of the face so they don't z-fight the skull.
	for sx in [-1.0, 1.0]:
		h.box(Vector3(sx * 0.038, 0.140, -0.098), Vector3(0.013, 0.010, 0.006), C_EYE)

	_tri_total += h.tri_count
	LPB.attach(head, h.commit(), _mat, "Skull")


## A faceted cap sitting over the crown — cheap, and it's the single biggest
## silhouette read that this is a person and not a mannequin. Sized with a
## generous margin over the skull profile (real hair has volume, and a
## skin-tight margin z-fights against the scalp and vanishes at this scale).
func _build_hair() -> void:
	var hcap: RefCounted = LPB.new()
	var rings := []
	var spine := []
	var rows := [
		[0.150, 0.115, 0.111],
		[0.205, 0.100, 0.097],
		[0.245, 0.075, 0.072],
	]
	for row in rows:
		var y: float = row[0]
		var rx: float = row[1]
		var rz: float = row[2]
		var centre := Vector3(0, y, 0)
		spine.append(centre)
		rings.append(LPB.ring(centre, Vector3(0, 1, 0), Vector3(0, 0, -1),
			rx, rz, HAIR_SIDES, PI / float(HAIR_SIDES)))
	hcap.loft(rings, spine, _hair)
	hcap.cap_flat(rings[0], spine[1], _hair)
	hcap.cap(rings[rings.size() - 1], Vector3(0, 0.300, 0.0), spine[spine.size() - 2], _hair)

	_tri_total += hcap.tri_count
	LPB.attach(head, hcap.commit(), _mat, "Hair")


# ---------------------------------------------------------------- arms

func _build_arm(side: float) -> Node3D:
	var shoulder_row: Array = TORSO_PROFILE[TORSO_PROFILE.size() - 2]
	var shoulder_y: float = shoulder_row[0]
	var shoulder_rx: float = shoulder_row[2]

	var upper := Node3D.new()
	upper.name = "ArmUpper"
	upper.position = Vector3(side * shoulder_rx * 0.94, shoulder_y - 0.02, 0.0)
	body.add_child(upper)

	var a: RefCounted = LPB.new()
	var rings := []
	var spine := []
	var radii := [0.060, 0.052]
	for i in 2:
		var t := float(i)
		var centre := Vector3(0, -t * UPPER_ARM_LEN, 0)
		spine.append(centre)
		var r: float = radii[i]
		rings.append(LPB.ring(centre, Vector3(0, 1, 0), Vector3(0, 0, -1),
			r, r, LIMB_SIDES, PI * 0.2))
	a.loft(rings, spine, _shirt)
	_tri_total += a.tri_count
	LPB.attach(upper, a.commit(), _mat, "UpperArm")

	var forearm := Node3D.new()
	forearm.name = "Forearm"
	forearm.position = Vector3(0, -UPPER_ARM_LEN, 0)
	upper.add_child(forearm)

	var fa: RefCounted = LPB.new()
	var frings := []
	var fspine := []
	var fradii := [0.050, 0.042]
	for i in 2:
		var t := float(i)
		var centre := Vector3(0, -t * FOREARM_LEN, 0)
		fspine.append(centre)
		var r: float = fradii[i]
		frings.append(LPB.ring(centre, Vector3(0, 1, 0), Vector3(0, 0, -1),
			r, r, LIMB_SIDES, PI * 0.2))
	fa.loft(frings, fspine, _skin)
	fa.cap_flat(frings[frings.size() - 1], fspine[fspine.size() - 1], _skin)

	# Hand: a simple block riding on the wrist end of the forearm.
	fa.box(Vector3(0, -FOREARM_LEN - 0.032, 0), Vector3(0.050, 0.058, 0.032), _skin)

	_tri_total += fa.tri_count
	LPB.attach(forearm, fa.commit(), _mat, "Forearm")

	if side < 0.0:
		_forearm_l = forearm
	else:
		_forearm_r = forearm
	return upper


# ---------------------------------------------------------------- legs

func _build_leg(side: float) -> Node3D:
	var hip_row: Array = TORSO_PROFILE[0]
	var hip_rx: float = hip_row[2]

	var thigh := Node3D.new()
	thigh.name = "Thigh"
	thigh.position = Vector3(side * hip_rx * 0.52, 0.0, 0.0)
	body.add_child(thigh)

	var t: RefCounted = LPB.new()
	var rings := []
	var spine := []
	var radii := [0.100, 0.082]
	for i in 2:
		var tt := float(i)
		var centre := Vector3(0, -tt * THIGH_LEN, 0)
		spine.append(centre)
		var r: float = radii[i]
		rings.append(LPB.ring(centre, Vector3(0, 1, 0), Vector3(0, 0, -1),
			r, r, LIMB_SIDES, PI * 0.2))
	t.loft(rings, spine, _pants)
	_tri_total += t.tri_count
	LPB.attach(thigh, t.commit(), _mat, "Thigh")

	var shin := Node3D.new()
	shin.name = "Shin"
	shin.position = Vector3(0, -THIGH_LEN, 0)
	thigh.add_child(shin)

	var s: RefCounted = LPB.new()
	var srings := []
	var sspine := []
	var sradii := [0.076, 0.056]
	for i in 2:
		var tt := float(i)
		var centre := Vector3(0, -tt * SHIN_LEN, 0)
		sspine.append(centre)
		var r: float = sradii[i]
		srings.append(LPB.ring(centre, Vector3(0, 1, 0), Vector3(0, 0, -1),
			r, r, LIMB_SIDES, PI * 0.2))
	s.loft(srings, sspine, Callable(self, "_shin_colour"))
	# Close the ankle off — otherwise the open ring peeks out past the shoe
	# box at low angles and reads as a stray stick.
	s.cap_flat(srings[srings.size() - 1], sspine[sspine.size() - 2], C_SHOE)

	# Shoe: a dark block, nudged forward so it reads as a foot, not a stump.
	# Its underside is the model's ground plane — see HIP_Y.
	s.box(Vector3(0, -SHIN_LEN - SHOE_DROP, -0.036), Vector3(0.072, SHOE_HALF_Y, 0.126), C_SHOE)

	_tri_total += s.tri_count
	LPB.attach(shin, s.commit(), _mat, "Shin")

	if side < 0.0:
		_shin_l = shin
	else:
		_shin_r = shin
	return thigh


## Pants colour down to the ankle, then a dark shoe takes over.
func _shin_colour(p: Vector3) -> Color:
	if p.y < -SHIN_LEN * 0.82:
		return C_SHOE
	return _pants


# ---------------------------------------------------------------- animation

## A walk cycle (opposed arm/leg swing) scaled by speed; at fleeing 1.0 the
## arms go up and flail and the stride doubles. Should read as "just saw a
## goose," not as a smooth jog.
func animate(delta: float, speed: float, fleeing: float) -> void:
	if body == null:
		return
	fleeing = clampf(fleeing, 0.0, 1.0)
	speed = maxf(speed, 0.0)

	_walk_phase += delta * (2.0 + speed * 3.4 + fleeing * 6.0)
	var stride := clampf(0.25 + speed * 0.55 + fleeing * 0.55, 0.0, 1.7)

	var swing := sin(_walk_phase) * stride
	var swing_op := sin(_walk_phase + PI) * stride

	if leg_l:
		leg_l.rotation.x = swing
	if leg_r:
		leg_r.rotation.x = swing_op
	# Opposed gait: left arm swings with right leg.
	if arm_l:
		arm_l.rotation.x = swing_op * 0.8
	if arm_r:
		arm_r.rotation.x = swing * 0.8

	if _forearm_l:
		_forearm_l.rotation.x = maxf(0.0, -swing_op) * 0.6
	if _forearm_r:
		_forearm_r.rotation.x = maxf(0.0, -swing) * 0.6
	if _shin_l:
		_shin_l.rotation.x = maxf(0.0, -swing) * 0.9
	if _shin_r:
		_shin_r.rotation.x = maxf(0.0, -swing_op) * 0.9

	if fleeing > 0.02:
		# Arms up and flailing, layered fast sines so it reads as panic
		# rather than a faster version of the walk cycle.
		var flail := (sin(_walk_phase * 2.6) + sin(_walk_phase * 4.1 + 1.0)) * 0.5
		if arm_l:
			arm_l.rotation.x = lerpf(arm_l.rotation.x, -2.3 + flail * 0.3, fleeing)
			arm_l.rotation.z = lerpf(arm_l.rotation.z, 0.5 + flail * 0.2, fleeing)
		if arm_r:
			arm_r.rotation.x = lerpf(arm_r.rotation.x, -2.3 - flail * 0.3, fleeing)
			arm_r.rotation.z = lerpf(arm_r.rotation.z, -0.5 - flail * 0.2, fleeing)
	else:
		if arm_l:
			arm_l.rotation.z = lerpf(arm_l.rotation.z, 0.0, 1.0 - pow(0.01, delta))
		if arm_r:
			arm_r.rotation.z = lerpf(arm_r.rotation.z, 0.0, 1.0 - pow(0.01, delta))

	body.position.y = HIP_Y + absf(sin(_walk_phase)) * 0.02 * (0.3 + speed * 0.3 + fleeing * 0.6)
	body.rotation.z = sin(_walk_phase * 0.5) * 0.03 * (speed + fleeing)


## All colour is in vertex colours and the material is white, so tinting the
## whole person is one multiply — same trick as the goose.
func set_tint(c: Color, amount: float) -> void:
	if _mat == null:
		return
	_mat.albedo_color = Color.WHITE.lerp(c, clampf(amount, 0.0, 0.65))


## Triangle count, for the dev overlay and for keeping an eye on the budget.
func triangle_count() -> int:
	return _tri_total
