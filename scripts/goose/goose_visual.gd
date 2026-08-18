extends Node3D
## A recognisable Canada goose built from primitives — no art assets needed.
## Black head and neck, white chinstrap, brown body, black bill, orange webbed
## feet. The chinstrap is the entire silhouette; don't remove it.
##
## ORIENTATION — READ THIS BEFORE EDITING:
## The bird faces -Z, because -Z is Node3D's forward in Godot. Every offset
## below is authored in that frame: head and bill at negative Z, tail at
## positive Z. An earlier version built the model facing +Z, which made the
## goose fly tail-first while still "correctly" turning toward its heading.
## If you add a part, put the front of it at NEGATIVE Z.

const C_BODY := Color(0.42, 0.35, 0.27)
const C_BREAST := Color(0.74, 0.68, 0.58)
const C_DARK := Color(0.06, 0.06, 0.07)
const C_WHITE := Color(0.95, 0.95, 0.93)
const C_FEET := Color(0.86, 0.46, 0.12)

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

var _flap_phase := 0.0
var _waddle_phase := 0.0
var _fold := 1.0
var _tex: Node


func _ready() -> void:
	_tex = get_node_or_null("/root/Tex")
	_build()


func _mat(c: Color, rough := 0.85, tex_key: StringName = &"") -> StandardMaterial3D:
	## Uses a feather texture when the Tex autoload is available, and degrades
	## to flat colour when it isn't, so the goose is never invisible.
	var m: StandardMaterial3D = null
	if _tex != null and tex_key != &"":
		m = _tex.surface(tex_key, 2.0, rough, c)
		if m != null:
			# surface() caches its materials, so take a copy before we start
			# writing per-goose tint into it.
			m = m.duplicate()
	if m == null:
		m = StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = rough
	tint_targets.append(m)
	m.set_meta("base_color", m.albedo_color)
	return m


func _part(parent: Node3D, mesh: Mesh, mat: StandardMaterial3D, pos: Vector3,
		rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


func _build() -> void:
	var m_body := _mat(C_BODY, 0.85, &"feather_body")
	var m_breast := _mat(C_BREAST, 0.85, &"feather_breast")
	var m_dark := _mat(C_DARK, 0.55, &"feather_black")
	var m_white := _mat(C_WHITE, 0.7)
	var m_feet := _mat(C_FEET, 0.45)

	body = Node3D.new()
	body.name = "Body"
	add_child(body)

	# --- torso: long axis along Z, front (breast) toward -Z ---
	var torso := SphereMesh.new()
	torso.radius = 0.42
	torso.height = 0.84
	_part(body, torso, m_body, Vector3.ZERO, Vector3.ZERO, Vector3(0.94, 0.78, 1.62))
	# Pale breast, forward and low.
	_part(body, torso, m_breast, Vector3(0, -0.10, -0.20), Vector3.ZERO, Vector3(0.86, 0.62, 0.95))
	# Rump, slightly raised — geese sit tail-high.
	_part(body, torso, m_body, Vector3(0, 0.06, 0.30), Vector3.ZERO, Vector3(0.80, 0.62, 0.70))

	# --- tail: a short wedge at +Z, cocked up ---
	tail = Node3D.new()
	tail.position = Vector3(0, 0.10, 0.56)
	body.add_child(tail)
	var tail_mesh := PrismMesh.new()
	tail_mesh.size = Vector3(0.36, 0.28, 0.10)
	# Mirrored from the old +Z build, so the X rotation flips sign too.
	_part(tail, tail_mesh, m_dark, Vector3(0, 0, 0.06), Vector3(deg_to_rad(100), 0, 0))
	# White upper tail coverts — real Canada geese have a bright white band here.
	_part(tail, _thin_box(0.30, 0.08, 0.14), m_white, Vector3(0, -0.06, -0.02))

	# --- neck: segmented so it reads as a curve, sweeping up and forward ---
	neck = Node3D.new()
	neck.name = "Neck"
	neck.position = Vector3(0, 0.20, -0.42)
	body.add_child(neck)
	var seg := CylinderMesh.new()
	seg.top_radius = 0.058
	seg.bottom_radius = 0.100
	seg.height = 0.24
	# Seven short segments read as a curve; five read as a pipe. The taper from
	# a thick shoulder to a thin throat is what makes it a goose and not a swan.
	for i in 7:
		var t := float(i) / 6.0
		_part(neck, seg, m_dark,
			# Sweeps forward off the shoulders, then back up under the head:
			# the classic Canada goose S.
			Vector3(0, 0.08 + t * 0.78, -sin(t * 2.05) * 0.155),
			Vector3(deg_to_rad(lerpf(-26.0, 14.0, t)), 0, 0),
			Vector3(lerpf(1.10, 0.86, t), 1.0, lerpf(1.10, 0.86, t)))

	# --- head ---
	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 0.98, -0.10)
	neck.add_child(head)
	var skull := SphereMesh.new()
	skull.radius = 0.148
	skull.height = 0.296
	_part(head, skull, m_dark, Vector3.ZERO, Vector3.ZERO, Vector3(0.90, 1.0, 1.14))

	# THE CHINSTRAP. This is the whole species in one shape. Do not remove it,
	# and do not let it shrink — if you can't see the white from the front at
	# twenty metres, the bird stops reading as a Canada goose and becomes a duck.
	var strap := SphereMesh.new()
	strap.radius = 0.105
	strap.height = 0.210
	# Chin and throat: the broad white bib, visible head-on.
	_part(head, strap, m_white, Vector3(0, -0.072, -0.070), Vector3.ZERO, Vector3(1.44, 1.30, 0.72))
	# Under the jaw, wrapping back: what makes it read from the side.
	_part(head, strap, m_white, Vector3(0, -0.112, 0.010), Vector3.ZERO, Vector3(0.98, 0.52, 1.18))
	# Cheek crescents rising behind the bill toward the eye.
	for sx in [-1.0, 1.0]:
		_part(head, strap, m_white, Vector3(sx * 0.088, -0.030, -0.088),
			Vector3(0, 0, deg_to_rad(sx * 22.0)), Vector3(0.46, 0.86, 0.52))

	# --- bill: black, blunt, angled slightly down ---
	var bill := BoxMesh.new()
	bill.size = Vector3(0.092, 0.058, 0.25)
	_part(head, bill, m_dark, Vector3(0, -0.022, -0.225), Vector3(deg_to_rad(-6), 0, 0))
	_part(head, _thin_box(0.076, 0.018, 0.20), m_dark, Vector3(0, -0.048, -0.215))

	# --- eyes: tiny, but they aim the whole face ---
	var eye := SphereMesh.new()
	eye.radius = 0.028
	eye.height = 0.056
	for sx in [-1.0, 1.0]:
		_part(head, eye, m_white, Vector3(sx * 0.116, 0.030, -0.088), Vector3.ZERO, Vector3(1, 1, 0.7))

	# --- wings: pivots at the shoulders, blades extending outward in -X / +X ---
	wing_l = Node3D.new()
	wing_l.name = "WingL"
	wing_l.position = Vector3(-0.30, 0.14, -0.02)
	body.add_child(wing_l)
	wing_r = Node3D.new()
	wing_r.name = "WingR"
	wing_r.position = Vector3(0.30, 0.14, -0.02)
	body.add_child(wing_r)

	# Upper arm, then a hinged hand that sweeps back — a single flat slab reads
	# as a plank, but two segments with a slight bend read as a wing.
	var upper := BoxMesh.new()
	upper.size = Vector3(0.44, 0.075, 0.46)
	_part(wing_l, upper, m_body, Vector3(-0.22, 0, 0.04))
	_part(wing_r, upper, m_body, Vector3(0.22, 0, 0.04))

	hand_l = Node3D.new()
	hand_l.position = Vector3(-0.44, 0, 0.04)
	wing_l.add_child(hand_l)
	hand_r = Node3D.new()
	hand_r.position = Vector3(0.44, 0, 0.04)
	wing_r.add_child(hand_r)

	var fore := BoxMesh.new()
	fore.size = Vector3(0.34, 0.06, 0.38)
	_part(hand_l, fore, m_body, Vector3(-0.17, 0, 0.03))
	_part(hand_r, fore, m_body, Vector3(0.17, 0, 0.03))
	# Dark primaries at the tips, tapering.
	var tipm := BoxMesh.new()
	tipm.size = Vector3(0.30, 0.05, 0.26)
	_part(hand_l, tipm, m_dark, Vector3(-0.46, 0, 0.10))
	_part(hand_r, tipm, m_dark, Vector3(0.46, 0, 0.10))

	# --- legs and webbed feet ---
	foot_l = Node3D.new()
	foot_l.position = Vector3(-0.13, -0.26, -0.04)
	body.add_child(foot_l)
	foot_r = Node3D.new()
	foot_r.position = Vector3(0.13, -0.26, -0.04)
	body.add_child(foot_r)
	for f in [foot_l, foot_r]:
		_part(f, _thin_box(0.055, 0.16, 0.055), m_feet, Vector3(0, -0.07, 0))
		# The webbed foot: a flat triangle, splayed forward.
		var web := PrismMesh.new()
		web.size = Vector3(0.20, 0.035, 0.22)
		_part(f, web, m_feet, Vector3(0, -0.15, -0.07), Vector3(deg_to_rad(90), 0, 0))


func _thin_box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b


## flap 0..1 how hard we're flapping, ground_speed normalised, airborne flag.
func animate(delta: float, flapping: float, ground_speed: float, airborne: bool) -> void:
	if wing_l == null:
		return

	# Wings FOLD against the back at rest and swing out to extend. Without this
	# the goose looks like a paper aeroplane at all times.
	# Folded means swept toward +Z (the tail), so the signs are mirrored from
	# the old +Z-facing build.
	var want_fold := 0.0 if (airborne or flapping > 0.01) else 1.0
	_fold = lerpf(_fold, want_fold, 1.0 - pow(0.0006, delta))

	# Nearly 90 degrees sweeps the blade straight back along the body, and the
	# scale pull-in stops the folded wing poking out past the flank.
	wing_l.rotation.y = lerpf(0.0, 1.52, _fold)
	wing_r.rotation.y = lerpf(0.0, -1.52, _fold)
	wing_l.scale = Vector3(lerpf(1.0, 0.56, _fold), 1.0, 0.86)
	wing_r.scale = Vector3(lerpf(1.0, 0.56, _fold), 1.0, 0.86)
	wing_l.position.x = lerpf(-0.30, -0.24, _fold)
	wing_r.position.x = lerpf(0.30, 0.24, _fold)

	if _fold < 0.98:
		_flap_phase += delta * lerpf(6.0, 20.0, flapping)
		var a := sin(_flap_phase) * lerpf(0.22, 0.86, flapping) * (1.0 - _fold)
		wing_l.rotation.z = -a
		wing_r.rotation.z = a
		wing_l.rotation.x = a * 0.18
		wing_r.rotation.x = a * 0.18
		# The hand lags a quarter cycle behind the arm. That phase offset is the
		# entire difference between "flapping" and "waving two boards".
		var b := sin(_flap_phase - 0.9) * lerpf(0.18, 0.62, flapping) * (1.0 - _fold)
		if hand_l:
			hand_l.rotation.z = -b
			hand_l.rotation.y = lerpf(0.0, 0.55, _fold)
		if hand_r:
			hand_r.rotation.z = b
			hand_r.rotation.y = lerpf(0.0, -0.55, _fold)
	else:
		wing_l.rotation.z = lerpf(wing_l.rotation.z, -0.30, 1.0 - pow(0.001, delta))
		wing_r.rotation.z = lerpf(wing_r.rotation.z, 0.30, 1.0 - pow(0.001, delta))
		wing_l.rotation.x = lerpf(wing_l.rotation.x, 0.0, 1.0 - pow(0.001, delta))
		wing_r.rotation.x = lerpf(wing_r.rotation.x, 0.0, 1.0 - pow(0.001, delta))
		# Folded: the hand tucks in against the flank.
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
		# Alternating legs. Cheap, and it sells the waddle more than the bob does.
		if foot_l:
			foot_l.position.y = -0.26 + maxf(0.0, sin(_waddle_phase)) * 0.09
		if foot_r:
			foot_r.position.y = -0.26 + maxf(0.0, -sin(_waddle_phase)) * 0.09
	else:
		body.position.y = lerpf(body.position.y, 0.0, 1.0 - pow(0.01, delta))
		# THE ROLL IS ONLY LEVELLED HERE IF NOBODY OWNS IT.
		#
		# This line and set_bank() both wrote body.rotation.z every frame, one
		# lerping toward 0 and the other toward the requested bank, and the caller
		# runs them back to back. Solving the fixed point at 60 Hz (k = 0.0739
		# here, 0.0631 there) leaves the bird at 0.477x the bank it was asked for
		# — and at a different fraction on every refresh rate, because two
		# competing exponentials do not compose framerate-independently even
		# though each one is. Banking is the only feedback that a flight input
		# landed, so half of it is most of it.
		#
		# Not simply deleted: zone_finale drives these visuals through animate()
		# alone and never calls set_bank, and its birds do go ground -> air, so
		# without a driver they would carry the last waddle frame's roll into
		# flight. set_bank claims the property; everyone else still gets levelled.
		if not _bank_driven:
			body.rotation.z = lerpf(body.rotation.z, 0.0, 1.0 - pow(0.01, delta))
		# Legs tuck back in flight.
		if foot_l:
			foot_l.position.y = lerpf(foot_l.position.y, -0.18, 1.0 - pow(0.02, delta))
		if foot_r:
			foot_r.position.y = lerpf(foot_r.position.y, -0.18, 1.0 - pow(0.02, delta))

	# Neck counter-bobs. Cheap, and it's most of the personality.
	if neck:
		neck.rotation.x = lerpf(neck.rotation.x, sin(_waddle_phase * 0.5) * 0.06, 1.0 - pow(0.02, delta))
	if tail:
		tail.rotation.x = lerpf(tail.rotation.x, sin(_waddle_phase * 0.7) * 0.10, 1.0 - pow(0.02, delta))


## Bank the whole bird into a turn. Called by the controller in flight.
##
## Calling this at all is a claim on body.rotation.z: it tells animate() to stop
## levelling the roll in the airborne branch, because the two of them writing the
## same property in the same frame is what cost this bird half its bank. Sticky
## on purpose — a visual either has a bank driver for its whole life or it does
## not, and the drivers (goose_controller, flock_pen) call this every frame.
var _bank_driven := false

func set_bank(amount: float, delta: float) -> void:
	if body == null:
		return
	_bank_driven = true
	body.rotation.z = lerpf(body.rotation.z, clampf(amount, -0.7, 0.7), 1.0 - pow(0.02, delta))


## Wash the whole bird toward a substance colour.
func set_tint(c: Color, amount: float) -> void:
	for m in tint_targets:
		var base: Color = m.get_meta("base_color")
		m.albedo_color = base.lerp(c, clampf(amount, 0.0, 0.65))
