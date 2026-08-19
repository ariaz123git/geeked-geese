extends Node3D

## HOW FAR THE LOWEST VERTEX OF THIS MODEL SITS BELOW ITS OWN ORIGIN.
##
## `goose_controller.gd` uses it to stand the bird ON the ground instead of
## IN it: the capsule contacts at -CAPSULE_RADIUS, so the visual is lifted by
## `FOOT_DROP - CAPSULE_RADIUS` and the feet land exactly on the surface the
## physics rests on. Before this existed the webbed feet were underground
## whenever the bird stood still — LegL/LegR sit at -0.235 and the tarsus and web go down from there.
##
## MEASURED, NOT ESTIMATED, and it does not get to drift: `geomtest.gd` pass
## 3 builds the bird through the real pref path and asserts the lowest vertex
## lands on the contact point. Change the model and this number changes with
## it or the gate says so.
const FOOT_DROP := 0.441
## LOW-POLY CANADA GOOSE — polygons only.
##
## No SphereMesh, no CylinderMesh, no CapsuleMesh, no TorusMesh. Every surface
## here is authored as explicit faceted geometry through LowPolyBuilder: rings
## lofted along a spine, flat plates for the wings and feet, and boxes for the
## blocky details. Flat normals throughout, one material, all colour carried in
## vertex colours.
##
## Drop-in replacement for goose_visual.gd — identical public API
## (animate / set_bank / set_tint / tint_targets), so the controller doesn't
## know or care which one it's driving.
##
## ORIENTATION: the bird faces -Z, matching Node3D's forward. Head and bill at
## negative Z, tail at positive Z. If you add a part, put its front at NEGATIVE Z.
##
## FACET BUDGET: about 620 triangles. That is the right neighbourhood — under
## ~300 the neck stops reading as a curve, over ~1200 the facets stop reading as
## facets and you've built a smooth model badly.

## Preloaded rather than referenced by class_name: global class registration
## only exists after an editor import pass, so a `class_name` reference breaks
## in a fresh checkout or a headless CI run. A preload const always resolves.
const LPB := preload("res://scripts/goose/lowpoly_builder.gd")

const C_BODY := Color(0.44, 0.36, 0.27)
const C_RUMP := Color(0.41, 0.35, 0.27)
const C_BREAST := Color(0.78, 0.72, 0.62)
const C_FLANK := Color(0.62, 0.56, 0.47)
const C_DARK := Color(0.075, 0.075, 0.085)
const C_WHITE := Color(0.94, 0.94, 0.92)
const C_FEET := Color(0.87, 0.47, 0.13)
const C_BILL := Color(0.055, 0.055, 0.065)

const BODY_SIDES := 8
const NECK_SIDES := 6
const HEAD_SIDES := 6

var wing_l: Node3D
var wing_r: Node3D
var hand_l: Node3D
var hand_r: Node3D
var neck: Node3D
var head: Node3D
var body: Node3D
var tail: Node3D
var foot_l: Node3D
var foot_r: Node3D
var tint_targets: Array[StandardMaterial3D] = []

var _mat: StandardMaterial3D
var _flap_phase := 0.0
var _waddle_phase := 0.0
var _fold := 1.0
var _tri_total := 0


func _ready() -> void:
	_build()


func _build() -> void:
	_mat = LPB.make_material(0.93)
	tint_targets.append(_mat)

	body = Node3D.new()
	body.name = "Body"
	add_child(body)

	_build_body()
	_build_tail()
	_build_neck_and_head()
	_build_wings()
	_build_legs()


# ---------------------------------------------------------------- body

## NINE cross-sections from the tail root to the breast. (It said "Ten" for as
## long as the table has had nine rows. Count matters here: _build_body() caps
## both ends by hand at rings[0]/spine[1] and rings[-1]/spine[-2], with the two
## apex points — (0, 0.215, 0.70) and (0, 0.135, -0.76) — typed to sit just off
## THESE first and last rows. Add a row to reach a documented count that was
## never real and the breast cap lands inside the chest.)
##
## The profile matters more than the polygon count: deep chest, widest just
## behind the shoulder, rising to a tail-high rump. Get this table wrong and no
## amount of facets help.
const BODY_PROFILE := [
	# z,      centre y, half-width, half-height
	[ 0.66,   0.21,  0.055, 0.055],
	[ 0.50,   0.17,  0.170, 0.155],
	[ 0.32,   0.095, 0.275, 0.245],
	[ 0.12,   0.025, 0.350, 0.305],
	[-0.08,  -0.010, 0.380, 0.340],
	[-0.28,  -0.020, 0.370, 0.340],
	[-0.46,   0.005, 0.320, 0.310],
	[-0.60,   0.045, 0.240, 0.250],
	[-0.70,   0.105, 0.130, 0.150],
]


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
		# Half a facet of phase offset puts a flat panel on the top and bottom
		# of the body rather than a ridge, which reads much better on a bird.
		rings.append(LPB.ring(centre, Vector3(0, 0, 1), Vector3.UP,
			rx, ry, BODY_SIDES, PI / float(BODY_SIDES)))

	b.loft(rings, spine, Callable(self, "_body_colour"))
	# Breast cap at the front, tail-root cap at the back.
	b.cap(rings[rings.size() - 1], Vector3(0, 0.135, -0.76), spine[spine.size() - 2],
		Callable(self, "_body_colour"))
	b.cap(rings[0], Vector3(0, 0.215, 0.70), spine[1], C_RUMP)

	_tri_total += b.tri_count
	LPB.attach(body, b.commit(), _mat, "Torso")


## Painted per face from where the face sits, so the pale breast and flanks are
## part of the same mesh instead of extra geometry stuck on top.
func _body_colour(p: Vector3) -> Color:
	# Underside: pale buff belly.
	if p.y < -0.09:
		return C_BREAST
	# Front-lower: the breast proper.
	if p.z < -0.40 and p.y < 0.13:
		return C_BREAST
	# Rump and upper tail area, a shade darker than the back.
	if p.z > 0.34:
		return C_RUMP
	# Side transition band, so the belly doesn't end in a hard line.
	if p.y < 0.02 and absf(p.x) > 0.22:
		return C_FLANK
	return C_BODY


# ---------------------------------------------------------------- tail

func _build_tail() -> void:
	tail = Node3D.new()
	tail.name = "Tail"
	tail.position = Vector3(0, 0.205, 0.60)
	# Cocked up: a Canada goose carries its tail high and short.
	tail.rotation = Vector3(deg_to_rad(-16), 0, 0)
	body.add_child(tail)

	var b: RefCounted = LPB.new()
	# Fanned rectrices, authored flat in XZ then given thickness and a crease.
	var outline := PackedVector3Array([
		Vector3(-0.205, 0, -0.04),
		Vector3(-0.150, 0,  0.22),
		Vector3(-0.055, 0,  0.36),
		Vector3( 0.055, 0,  0.36),
		Vector3( 0.150, 0,  0.22),
		Vector3( 0.205, 0, -0.04),
	])
	b.plate(outline, 0.062, 0.034, C_DARK)

	# The white upper-tail covert band. Real, and it's the brightest thing on
	# the back half of the bird, so it's worth its own geometry.
	# Wide enough to break up the dark rear cap, which otherwise reads as a
	# hole punched in the back of the bird from directly behind.
	var band := PackedVector3Array([
		Vector3(-0.215, 0, -0.17),
		Vector3(-0.205, 0, -0.02),
		Vector3( 0.205, 0, -0.02),
		Vector3( 0.215, 0, -0.17),
	])
	b.plate(band, 0.105, 0.018, C_WHITE)

	_tri_total += b.tri_count
	LPB.attach(tail, b.commit(), _mat, "TailFan")


# ---------------------------------------------------------------- neck + head

## Local to the neck node, which pivots at the shoulders. Rises, leans forward,
## then straightens — the Canada goose S. Seven sections; six reads as a pipe.
const NECK_PROFILE := [
	[0.000,  0.000, 0.118],
	[0.150, -0.060, 0.106],
	[0.300, -0.100, 0.095],
	[0.450, -0.117, 0.086],
	[0.600, -0.110, 0.078],
	[0.740, -0.088, 0.071],
	[0.860, -0.058, 0.065],
]

## Local to the head node. Small skull, blunt forehead, tapering to the bill.
const HEAD_PROFILE := [
	[ 0.020, -0.010, 0.086, 0.090],
	[ 0.080, -0.075, 0.116, 0.126],
	[ 0.098, -0.150, 0.129, 0.139],
	[ 0.070, -0.228, 0.112, 0.118],
	[ 0.030, -0.288, 0.074, 0.078],
]


func _build_neck_and_head() -> void:
	neck = Node3D.new()
	neck.name = "Neck"
	neck.position = Vector3(0, 0.185, -0.445)
	body.add_child(neck)

	var b: RefCounted = LPB.new()
	var rings := []
	var spine := []
	for row in NECK_PROFILE:
		var y: float = row[0]
		var z: float = row[1]
		var r: float = row[2]
		var centre := Vector3(0, y, z)
		spine.append(centre)
		# Orient each ring along the local tangent so the tube doesn't pinch on
		# the inside of the curve.
		rings.append(LPB.ring(centre, Vector3(0, 1, 0), Vector3(0, 0, -1),
			r, r, NECK_SIDES, PI / float(NECK_SIDES)))
	b.loft(rings, spine, C_DARK)
	_tri_total += b.tri_count
	LPB.attach(neck, b.commit(), _mat, "NeckTube")

	# --- head ---
	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.860, -0.058)
	neck.add_child(head)

	var h: RefCounted = LPB.new()
	var hrings := []
	var hspine := []
	for row in HEAD_PROFILE:
		var y: float = row[0]
		var z: float = row[1]
		var rx: float = row[2]
		var ry: float = row[3]
		var centre := Vector3(0, y, z)
		hspine.append(centre)
		hrings.append(LPB.ring(centre, Vector3(0, 0, -1), Vector3.UP,
			rx, ry, HEAD_SIDES, PI / float(HEAD_SIDES)))
	h.loft(hrings, hspine, Callable(self, "_head_colour"))
	h.cap(hrings[0], Vector3(0, -0.02, 0.055), hspine[1], C_DARK)
	h.cap(hrings[hrings.size() - 1], Vector3(0, 0.012, -0.330), hspine[hspine.size() - 2],
		Callable(self, "_head_colour"))

	# --- bill: a flattened faceted wedge, four-sided ---
	var brings := []
	var bspine := []
	var bill_prof := [
		[-0.300, -0.014, 0.064, 0.050],
		[-0.395, -0.020, 0.059, 0.041],
		[-0.480, -0.028, 0.049, 0.032],
	]
	for row in bill_prof:
		var z: float = row[0]
		var y: float = row[1]
		var rx: float = row[2]
		var ry: float = row[3]
		var centre := Vector3(0, y, z)
		bspine.append(centre)
		brings.append(LPB.ring(centre, Vector3(0, 0, -1), Vector3.UP,
			rx, ry, 4, PI * 0.25))
	h.loft(brings, bspine, C_BILL)
	# Blunt, slightly hooked tip — not a point. A pointed bill reads as a duck.
	h.cap(brings[brings.size() - 1], Vector3(0, -0.040, -0.530), bspine[bspine.size() - 2], C_BILL)

	# --- eyes: a pale ring with a dark pupil, as blocks ---
	# Dark eye with a tiny pale catchlight. A white sclera block reads as a
	# square sticker at this facet density; real waterfowl eyes are just dark.
	for sx in [-1.0, 1.0]:
		h.box(Vector3(sx * 0.118, 0.080, -0.140), Vector3(0.018, 0.024, 0.024), Color(0.02, 0.02, 0.03))
		h.box(Vector3(sx * 0.130, 0.090, -0.150), Vector3(0.008, 0.009, 0.009), C_WHITE)

	_tri_total += h.tri_count
	LPB.attach(head, h.commit(), _mat, "Skull")


## THE CHINSTRAP, painted straight onto the head's faces.
##
## This is the single most important function in the file. A Canada goose is a
## black head and neck with a broad white strap under the chin that climbs the
## cheeks toward the eye. Lose it and you have built a generic waterfowl. The
## classic model needed three extra pieces of geometry to fake it; here it is
## just a colour decision per face, which is the whole argument for vertex
## colours on a low-poly model.
func _head_colour(p: Vector3) -> Color:
	# The crown stays black no matter what — that contrast IS the marking.
	if p.y > 0.105:
		return C_DARK
	# Broad white bib across the chin and throat. The first version of this
	# rule used p.y < 0.005, which given the head profile caught almost no
	# faces at all and rendered as a postage stamp. Check the profile's actual
	# y range before tightening these numbers.
	if p.y < 0.050 and p.z > -0.265:
		return C_WHITE
	# Cheek patches climbing behind the bill toward the eye.
	if absf(p.x) > 0.055 and p.y < 0.095 and p.z > -0.255 and p.z < -0.020:
		return C_WHITE
	return C_DARK


# ---------------------------------------------------------------- wings

func _build_wings() -> void:
	wing_l = Node3D.new()
	wing_l.name = "WingL"
	wing_l.position = Vector3(-0.285, 0.150, -0.055)
	body.add_child(wing_l)

	wing_r = Node3D.new()
	wing_r.name = "WingR"
	wing_r.position = Vector3(0.285, 0.150, -0.055)
	body.add_child(wing_r)

	hand_l = Node3D.new()
	hand_l.name = "HandL"
	hand_l.position = Vector3(-0.430, 0, -0.010)
	wing_l.add_child(hand_l)

	hand_r = Node3D.new()
	hand_r.name = "HandR"
	hand_r.position = Vector3(0.430, 0, -0.010)
	wing_r.add_child(hand_r)

	for side in [-1.0, 1.0]:
		var arm_node: Node3D = wing_l if side < 0.0 else wing_r
		var hand_node: Node3D = hand_l if side < 0.0 else hand_r

		# Upper arm: swept back at the leading edge, deeper at the root.
		var a: RefCounted = LPB.new()
		a.plate(_mirror(PackedVector3Array([
			Vector3(0.00, 0, -0.215),
			Vector3(0.40, 0, -0.180),
			Vector3(0.44, 0,  0.120),
			Vector3(0.05, 0,  0.250),
		]), side), 0.058, 0.048, C_BODY)
		_tri_total += a.tri_count
		LPB.attach(arm_node, a.commit(), _mat, "WingArm")

		# Hand: narrower, and the dark primaries are their own plate so the tip
		# reads as feathers rather than as a painted stripe.
		var hd: RefCounted = LPB.new()
		hd.plate(_mirror(PackedVector3Array([
			Vector3(0.00, 0, -0.165),
			Vector3(0.30, 0, -0.120),
			Vector3(0.34, 0,  0.130),
			Vector3(0.02, 0,  0.205),
		]), side), 0.050, 0.038, C_BODY)
		hd.plate(_mirror(PackedVector3Array([
			Vector3(0.30, 0, -0.115),
			Vector3(0.56, 0, -0.020),
			Vector3(0.54, 0,  0.115),
			Vector3(0.33, 0,  0.132),
		]), side), 0.038, 0.022, C_DARK)
		_tri_total += hd.tri_count
		LPB.attach(hand_node, hd.commit(), _mat, "WingHand")


func _mirror(pts: PackedVector3Array, side: float) -> PackedVector3Array:
	if side >= 0.0:
		return pts
	var out := PackedVector3Array()
	for p in pts:
		out.append(Vector3(-p.x, p.y, p.z))
	return out


# ---------------------------------------------------------------- legs

func _build_legs() -> void:
	foot_l = Node3D.new()
	foot_l.name = "LegL"
	foot_l.position = Vector3(-0.130, -0.235, -0.055)
	body.add_child(foot_l)

	foot_r = Node3D.new()
	foot_r.name = "LegR"
	foot_r.position = Vector3(0.130, -0.235, -0.055)
	body.add_child(foot_r)

	for f in [foot_l, foot_r]:
		var b: RefCounted = LPB.new()
		# Tarsus: a short four-sided taper. Geese have almost no visible leg.
		var rings := []
		var spine := []
		for i in 3:
			var t := float(i) / 2.0
			var centre := Vector3(0, -t * 0.155, 0)
			spine.append(centre)
			rings.append(LPB.ring(centre, Vector3(0, 1, 0), Vector3(0, 0, -1),
				lerpf(0.048, 0.036, t), lerpf(0.048, 0.036, t), 4, PI * 0.25))
		b.loft(rings, spine, C_FEET)

		# Webbed foot: three toes joined by webbing, as one flat faceted plate.
		# The forward-splayed shape is a big part of the waddle read.
		b.plate(PackedVector3Array([
			Vector3(-0.105, -0.185,  0.030),
			Vector3(-0.048, -0.185, -0.090),
			Vector3(-0.014, -0.185, -0.205),
			Vector3( 0.014, -0.185, -0.205),
			Vector3( 0.048, -0.185, -0.090),
			Vector3( 0.105, -0.185,  0.030),
			Vector3( 0.000, -0.185,  0.062),
		]), 0.032, 0.014, C_FEET)

		_tri_total += b.tri_count
		LPB.attach(f, b.commit(), _mat, "Leg")


# ---------------------------------------------------------------- animation
# Identical behaviour to the classic model so the controller can't tell them
# apart. If you change one, change both.

func animate(delta: float, flapping: float, ground_speed: float, airborne: bool) -> void:
	if wing_l == null:
		return

	var want_fold := 0.0 if (airborne or flapping > 0.01) else 1.0
	_fold = lerpf(_fold, want_fold, 1.0 - pow(0.0006, delta))

	wing_l.rotation.y = lerpf(0.0, 1.52, _fold)
	wing_r.rotation.y = lerpf(0.0, -1.52, _fold)
	wing_l.scale = Vector3(lerpf(1.0, 0.56, _fold), 1.0, 0.86)
	wing_r.scale = Vector3(lerpf(1.0, 0.56, _fold), 1.0, 0.86)
	wing_l.position.x = lerpf(-0.285, -0.225, _fold)
	wing_r.position.x = lerpf(0.285, 0.225, _fold)

	if _fold < 0.98:
		_flap_phase += delta * lerpf(6.0, 20.0, flapping)
		var a := sin(_flap_phase) * lerpf(0.22, 0.86, flapping) * (1.0 - _fold)
		wing_l.rotation.z = -a
		wing_r.rotation.z = a
		wing_l.rotation.x = a * 0.18
		wing_r.rotation.x = a * 0.18
		# The hand trails the arm by a quarter cycle. That phase offset is the
		# whole difference between flapping and waving two boards.
		var hb := sin(_flap_phase - 0.9) * lerpf(0.18, 0.62, flapping) * (1.0 - _fold)
		if hand_l:
			hand_l.rotation.z = -hb
			hand_l.rotation.y = lerpf(0.0, 0.55, _fold)
		if hand_r:
			hand_r.rotation.z = hb
			hand_r.rotation.y = lerpf(0.0, -0.55, _fold)
	else:
		wing_l.rotation.z = lerpf(wing_l.rotation.z, -0.30, 1.0 - pow(0.001, delta))
		wing_r.rotation.z = lerpf(wing_r.rotation.z, 0.30, 1.0 - pow(0.001, delta))
		wing_l.rotation.x = lerpf(wing_l.rotation.x, 0.0, 1.0 - pow(0.001, delta))
		wing_r.rotation.x = lerpf(wing_r.rotation.x, 0.0, 1.0 - pow(0.001, delta))
		if hand_l:
			hand_l.rotation.z = lerpf(hand_l.rotation.z, 0.0, 1.0 - pow(0.001, delta))
			hand_l.rotation.y = lerpf(hand_l.rotation.y, 0.55, 1.0 - pow(0.001, delta))
		if hand_r:
			hand_r.rotation.z = lerpf(hand_r.rotation.z, 0.0, 1.0 - pow(0.001, delta))
			hand_r.rotation.y = lerpf(hand_r.rotation.y, -0.55, 1.0 - pow(0.001, delta))

	if not airborne:
		_waddle_phase += delta * ground_speed * 3.2
		body.position.y = absf(sin(_waddle_phase)) * 0.05
		body.rotation.z = sin(_waddle_phase) * 0.12
		body.rotation.x = lerpf(body.rotation.x, 0.0, 1.0 - pow(0.01, delta))
		if foot_l:
			foot_l.position.y = -0.235 + maxf(0.0, sin(_waddle_phase)) * 0.09
		if foot_r:
			foot_r.position.y = -0.235 + maxf(0.0, -sin(_waddle_phase)) * 0.09
	else:
		body.position.y = lerpf(body.position.y, 0.0, 1.0 - pow(0.01, delta))
		# THE ROLL IS ONLY LEVELLED HERE IF NOBODY OWNS IT. Same change, same
		# reasoning, same frame budget as goose_visual.gd — read the long version
		# there. Short version: this line and set_bank() both wrote
		# body.rotation.z every frame, toward 0 and toward the bank respectively,
		# and the fixed point at 60 Hz is 0.477x the requested bank, at a
		# different fraction on every refresh rate. zone_finale drives this visual
		# through animate() alone and never calls set_bank, so the levelling has
		# to stay for it; set_bank claims the property for everyone else.
		if not _bank_driven:
			body.rotation.z = lerpf(body.rotation.z, 0.0, 1.0 - pow(0.01, delta))
		if foot_l:
			foot_l.position.y = lerpf(foot_l.position.y, -0.165, 1.0 - pow(0.02, delta))
		if foot_r:
			foot_r.position.y = lerpf(foot_r.position.y, -0.165, 1.0 - pow(0.02, delta))

	if neck:
		neck.rotation.x = lerpf(neck.rotation.x, sin(_waddle_phase * 0.5) * 0.06, 1.0 - pow(0.02, delta))
	if head:
		# Counter-rotate the head so it stays level while the neck bobs. Birds
		# stabilise their heads and it's very noticeable when they don't.
		head.rotation.x = lerpf(head.rotation.x, -neck.rotation.x * 0.7, 1.0 - pow(0.02, delta))
	if tail:
		tail.rotation.x = lerpf(tail.rotation.x, deg_to_rad(-16) + sin(_waddle_phase * 0.7) * 0.10,
			1.0 - pow(0.02, delta))


## Calling this at all is a claim on body.rotation.z — it tells animate() to stop
## levelling the roll in the airborne branch. Sticky on purpose; see the sibling
## comment in goose_visual.gd.
var _bank_driven := false

func set_bank(amount: float, delta: float) -> void:
	if body == null:
		return
	_bank_driven = true
	body.rotation.z = lerpf(body.rotation.z, clampf(amount, -0.7, 0.7), 1.0 - pow(0.02, delta))


## All colour is in vertex colours and the material is white, so tinting the
## entire bird is one multiply.
func set_tint(c: Color, amount: float) -> void:
	if _mat == null:
		return
	_mat.albedo_color = Color.WHITE.lerp(c, clampf(amount, 0.0, 0.65))


## Triangle count, for the dev overlay and for keeping an eye on the budget.
func triangle_count() -> int:
	return _tri_total
