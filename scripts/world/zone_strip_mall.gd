extends Node3D
## LEG 1 — THE STRIP MALL LOT
##
## Graybox, built procedurally so it runs correctly the first time you open the
## project with no import step and no missing references.
##
## TODO(art pass): once the controller feels right, rebuild this as a real
## .tscn you can drag around in the editor. Procedural was the right call for
## a first-playable; it is the wrong call for level design.
##
## ---------------------------------------------------------------------------
## ART PASS — faceted models over graybox colliders
## ---------------------------------------------------------------------------
## Every collider in this file is exactly where it was. What changed is what
## you see: the BoxMeshes are gone, replaced by the hand-built models in
## prop_models.gd. The split is deliberate and worth keeping:
##
##   * PHYSICS is boxes. Cheap, predictable, tuned, and the reason the goose
##     feels the way it does. Nothing here touches a collider size or position.
##   * ART is a model hung off that box, base-anchored to the collider's floor.
##
## The two anchoring conventions do not agree, and that is the one thing to get
## right: prop_models.gd builds every model with its base at local y = 0, while
## BoxShape3D/BoxMesh are centred on the origin. So a model always drops by
## half the box height. Miss it and the whole lot hovers.

const LOT := 80.0

## Preloaded rather than referenced by class_name: global class registration
## only exists after an editor import pass, so a `class_name` reference breaks
## in a fresh checkout or a headless CI run. A preload const always resolves.
const PROPS := preload("res://scripts/world/prop_models.gd")

## Chaos-prop label -> model kind. Keyed off the label the prop already carries
## (the same string the scoring and the objectives match on) so there is one
## place to look and no call site has to repeat itself. A label with no entry
## keeps the old BoxMesh, which is what "STOP SIGN" and friends want.
const PROP_KIND := {
	"CART": &"shopping_cart",
	"VEHICLE": &"minivan",
	"RECYCLING": &"recycling_bin",
	"PATIO CHAIR": &"patio_chair",
	"LAWN SIGN": &"lawn_sign",
	"GARBAGE": &"garbage_bag",
}

## How far a SubstancePickup's model rides above its Area3D origin.
## substance_pickup.gd:64 sets `_model.position.y = 0.15` once, and the
## `breathe` and `sway` idle styles only touch scale and rotation.z, so for
## those two the lift survives. A source whose model is supposed to be SITTING
## on something therefore goes at `surface - PICKUP_LIFT`, not at `surface` —
## which is why the toad, the mushrooms and Molly below all read as a
## subtraction. (The `bob` style overwrites position.y outright; every bob
## source in this file is a hovering object at y ≈ 0.5 and stays that way.)
const PICKUP_LIFT := 0.15

## Top of the grass verge: a 0.06 m decal slab centred at y = -0.02, laid over
## asphalt whose top is y = 0.0. Anything standing in the grass anchors here.
const VERGE_Y := 0.01

## THE POND, AS A CONSTANT, BECAUSE THREE THINGS NEED TO AGREE ABOUT IT.
##
## `_pond()` builds it, the cattail ring is sized off it, and `_props()` has
## to keep the lawn signs out of it. Those were three separate literals, and
## the third one did not exist at all: **9 lawn signs were placed uniformly
## over x [-30, 30] * z [-30, -18], of which 27.1% of the area is inside the
## 11 m water cylinder** — 2.4 signs in the pond on an average run, measured
## over 2,000,000 samples. The campaign gate (`main.gd --loop-test`) now counts
## LAWN SIGN props inside POND_RADIUS on the zone the DIRECTOR built and fails
## the run if any is wet, reading the geometry off these constants.
const POND_CENTRE := Vector3(-24, 0, -22)
const POND_RADIUS := 11.0

## Outside the cattail ring (r 11.2–12.6), which is where dry land actually
## starts. A sign at r = 11.5 is standing in the reeds, not on the verge.
const POND_CLEAR := 13.0

## ───────────────────────────────────────────────────────────────────────────
## THE SHELF, AND WHY LEG 1 IS NOT LEG 2
## ───────────────────────────────────────────────────────────────────────────
## Legs 1 and 2 are the same place, which is the joke. They were also the same
## GAME, which is not: `_sources()` built all sixteen unconditionally and this
## file had no leg branch anywhere, so the first 420 seconds of the campaign
## were one zone served twice at the same intensity.
##
## `docs/CAMPAIGN_SPEC.md` §2.1 gives leg 1 **three** substances; §2.2 gives
## leg 2 "all sixteen — this is where the lid comes off", and the spec's own
## intensity column goes 2 → 4 across that boundary. The contrast IS the first
## rise of the campaign's escalation curve, and it had never been built.
##
## Three, and specifically these three, because the set is a tutorial rather
## than a sample:
##
##   * `berries` is the plain one — slower, floatier, `ragdoll_landings`. It
##     teaches that a substance is a control mutation and not a score bonus.
##   * `double_double` is the one that makes you FASTER and turn harder, which
##     is the reason aiming for the sweet spot is worth the risk.
##   * `grass` is `infinite`, so the dose ARC — charge, release, overdose —
##     can be practised as many times as it takes without spending a pickup.
##
## And the set is closed under the game's own mixing rule rather than being
## three arbitrary picks: `Subs.MAX_STACK` is 2, `mission_defs.gd`'s leg-1
## primary `double_parked` requires two substances at once, and
## `berries|double_double` is THE WOBBLER — so the tutorial shelf contains
## exactly one discoverable named combo, and it is the flagship one.
##
## **And bread is the fourth**, §2.1's *"the obvious food is the trap"*. It
## removes the game's main verb for twenty seconds and halves your chaos while
## it does, which is a stronger claim on the design rule than any multiplier
## makes. D-037; it was D-020's deferral until the same day.
const TUTORIAL_SHELF: Array[StringName] = [&"berries", &"double_double", &"grass", &"bread"]

## The leg the lid comes off at. Every leg from here up gets the whole shelf;
## only leg 1 is narrowed. A named constant rather than a bare `> 1` so
## `tools/selftest.gd` checks the same number this file obeys.
const FULL_SHELF_FROM_LEG := 2

var goose: Goose
var camera_rig: Node3D

## Substance ids this build of the zone will spawn, as a Dictionary used as a
## set. Written once in `_ready()` BEFORE `_sources()` runs, and read by the one
## function in this file that can create a pickup.
var _shelf: Dictionary = {}

var _berries: Substance
var _coffee: Substance
var _nitrous: Substance
var _tex: Node


func _ready() -> void:
	_tex = get_node_or_null("/root/Tex")
	_berries = Subs.get_substance(&"berries")
	_coffee = Subs.get_substance(&"double_double")
	_nitrous = Subs.get_substance(&"nitrous")
	# Before _sources(). Nothing else in the file may create a pickup, so this
	# one line is the whole leg branch.
	_shelf = shelf_for_leg(Flock.leg)

	_environment()
	_ground()
	_pond()
	_building()
	_parking()
	_trees()
	_sources()
	_props()
	_people()
	_cats()
	_spawn_goose()
	# Your flock, physically present at the pond. This is the only place the
	# Designated Driver can actually be chosen, and the only in-zone feedback
	# on how wrecked your geese are getting.
	add_child(preload("res://scripts/world/flock_pen.gd").new().setup(Vector3(-24, 0.6, -9)))


# ------------------------------------------------------------------ helpers

## A DETERMINISTIC RANDOM STREAM FOR ONE GROUP OF PLACEMENTS.
##
## THE BUG THIS EXISTS FOR, and it is `docs/RECENT_FAILURES.md` F-002. Every
## builder in this file drew from the ONE global RNG that `main._ready()`
## seeds with `randomize()`, so where a cat stood was a function of **how many
## `randf()` calls happened before it**. Narrowing leg 1's shelf removed
## thirteen `SubstancePickup` constructions and therefore moved every cat,
## camping one on the measuring pad; four consecutive sober fingerprints came
## back disagreeing on bearing while turn rate and climb were bit-identical in
## all four. The controller was perfect. A change with nothing to do with cats
## had moved every cat.
##
## Each group now draws from its own stream, seeded by the zone, the leg and
## the group's name. **Adding a pickup cannot move a cat, because the cats'
## stream does not know pickups exist.** The layout is a function of the seed,
## which is what F-002 asks for.
##
## It also makes the zone reproducible run to run, which is a second and
## smaller win: a harness failure caused by a prop is now something you can
## reproduce rather than something you wait for.
func _rng(tag: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash("strip_mall|%d|%s" % [Flock.leg, tag])
	return r

func _mat(c: Color, rough := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


## Textured surface when the Tex service is available, flat colour when it
## isn't. Every large surface goes through here so the zone still renders
## correctly if the textures are ever missing.
func _surf(key: StringName, uv_scale: float, fallback: Color, rough := 0.9) -> StandardMaterial3D:
	if _tex != null:
		var m: StandardMaterial3D = _tex.surface(key, uv_scale, rough)
		if m != null:
			return m
	return _mat(fallback, rough)


## Same as _static_box but with a textured material.
func _static_tex(pos: Vector3, size: Vector3, key: StringName, uv_scale: float,
		fallback: Color, rot_y := 0.0) -> StaticBody3D:
	var sb := _static_box(pos, size, fallback, rot_y)
	var mat := _surf(key, uv_scale, fallback)
	for c in sb.get_children():
		if c is MeshInstance3D:
			c.material_override = mat
	return sb


func _static_box(pos: Vector3, size: Vector3, color: Color, rot_y := 0.0) -> StaticBody3D:
	var sb := StaticBody3D.new()
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(color)
	sb.add_child(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	add_child(sb)
	sb.global_position = pos
	sb.rotation.y = rot_y
	return sb


func _decal_box(pos: Vector3, size: Vector3, color: Color, rot_y := 0.0) -> void:
	## Visual only — no collider. For paint, lines, flat detail.
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := _mat(color)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mi.material_override = m
	add_child(mi)
	mi.global_position = pos
	mi.rotation.y = rot_y


## `rng` is the caller's group stream. Without it the yaw would come off the
## global RNG and one extra prop anywhere would rotate every prop after it —
## the same F-002 shape as the cats, one step smaller. See `_rng()`.
func _prop(pos: Vector3, size: Vector3, color: Color, mass_kg: float, pts: int,
		lbl: String, extra := {}, rng: RandomNumberGenerator = null) -> ChaosProp:
	var p := ChaosProp.new()
	add_child(p)
	var kind: StringName = PROP_KIND.get(lbl, &"")
	var params: Dictionary = extra.duplicate()
	if kind != &"":
		params[_colour_key(kind)] = color
	p.setup(size, color, mass_kg, pts, lbl, kind, params)
	p.global_position = pos
	p.rotation.y = (rng.randf_range(-PI, PI) if rng != null else randf_range(-PI, PI))
	return p


## Which params key a model takes its main colour under. Only the minivan is
## odd — it has a body colour and a lot of trim that must NOT follow it.
func _colour_key(kind: StringName) -> String:
	if kind == &"minivan":
		return "body_colour"
	return "colour"


## Hide the box mesh of an existing StaticBody3D and hang a faceted model off
## it instead. The collider is untouched — this is a visual swap only.
##
## `base_y` is the model's base in the body's LOCAL frame, which for a box
## collider of height h centred on the body is always -h * 0.5.
func _model_body(sb: StaticBody3D, kind: StringName, base_y: float, params := {},
		uniform := 1.0) -> Node3D:
	for c in sb.get_children():
		if c is MeshInstance3D:
			c.visible = false
	var m: Node3D = PROPS.build(kind, sb, params)
	m.position.y = base_y
	if not is_equal_approx(uniform, 1.0):
		m.scale = Vector3.ONE * uniform
	return m


## A free-standing model with no collider at all — the _decal_box equivalent.
## `pos` is where the model's FEET go, so pass ground height, not centre.
func _model_at(kind: StringName, pos: Vector3, rot_y := 0.0, params := {},
		uniform := 1.0) -> Node3D:
	var n := Node3D.new()
	add_child(n)
	n.global_position = pos
	n.rotation.y = rot_y
	PROPS.build(kind, n, params)
	if not is_equal_approx(uniform, 1.0):
		n.scale = Vector3.ONE * uniform
	return n


## The set of substance ids a given leg of this zone spawns.
##
## Static, and called by `tools/selftest.gd` as well as by `_ready()`, so the
## invariant is checked against the expression `_sources()` actually obeys
## rather than against a second copy of the rule. `CLAUDE.md` — "prefer
## duplication over premature abstraction" — does not extend to duplicating the
## thing a gate is asserting; that is how a check ends up passing while the game
## is wrong.
static func shelf_for_leg(leg: int) -> Dictionary:
	var offered := {}
	if leg >= FULL_SHELF_FROM_LEG:
		for full_id in Subs.library.keys():
			offered[full_id] = true
		return offered
	for tut_id in TUTORIAL_SHELF:
		offered[tut_id] = true
	return offered


## THE ONLY PLACE IN THIS FILE THAT MAY CREATE A PICKUP. The grass patches used
## to build their own `SubstancePickup` inline because they needed `infinite`;
## that second construction path is now the `endless` argument, because a leg
## filter is only as good as its narrowest choke point and two of them is one
## too many.
## A point in the given XZ rectangle that is clear of the pond.
##
## Rejection sampling with a hard cap and a DETERMINISTIC fallback: an
## unbounded `while` here would hang the zone build if the rectangle ever
## ended up entirely inside the water, and a zone builder that can hang is a
## worse bug than a sign in a pond. 24 tries against a 73% dry area misses
## with probability 0.27^24, which is about 1 in 10^14.
func _dry_xz(x0: float, x1: float, z0: float, z1: float,
		rng: RandomNumberGenerator = null) -> Vector2:
	for _try in 24:
		var p := (Vector2(rng.randf_range(x0, x1), rng.randf_range(z0, z1)) if rng != null
			else Vector2(randf_range(x0, x1), randf_range(z0, z1)))
		if p.distance_to(Vector2(POND_CENTRE.x, POND_CENTRE.z)) >= POND_CLEAR:
			return p
	# Every try was wet. Push the last sample radially out to the clear ring
	# rather than returning something in the water.
	var c := Vector2(POND_CENTRE.x, POND_CENTRE.z)
	var away := Vector2(x0 - c.x, z0 - c.y)
	if away.length() < 0.01:
		away = Vector2(1.0, 0.0)
	return c + away.normalized() * POND_CLEAR


func _source(pos: Vector3, res: Substance, size := 0.5, endless := false) -> void:
	if res == null:
		return
	if not _shelf.has(res.id):
		return
	var s := SubstancePickup.new()
	add_child(s)
	s.setup(res, size)
	s.infinite = endless
	s.global_position = pos


# ------------------------------------------------------------------ build

func _environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	# Overcast southern-Ontario afternoon. Do not make this pretty.
	sm.sky_top_color = Color(0.42, 0.52, 0.66)
	sm.sky_horizon_color = Color(0.74, 0.76, 0.78)
	sm.ground_bottom_color = Color(0.28, 0.28, 0.30)
	sm.ground_horizon_color = Color(0.66, 0.66, 0.66)
	sm.sun_angle_max = 24.0
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.85
	env.fog_enabled = true
	env.fog_density = 0.006
	env.fog_light_color = Color(0.72, 0.75, 0.79)
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, 38, 0)
	sun.light_energy = 0.85
	sun.light_color = Color(1.0, 0.97, 0.92)
	sun.shadow_enabled = true
	add_child(sun)


func _ground() -> void:
	# Asphalt
	_static_tex(Vector3(0, -0.5, 0), Vector3(LOT, 1.0, LOT), &"asphalt", 16.0, Color(0.22, 0.22, 0.24))
	# Grass verge around the pond
	var verge := MeshInstance3D.new()
	var vm := BoxMesh.new()
	vm.size = Vector3(30, 0.06, 26)
	verge.mesh = vm
	verge.material_override = _surf(&"grass", 7.0, Color(0.30, 0.42, 0.22))
	add_child(verge)
	verge.global_position = Vector3(-24, -0.02, -22)
	# Concrete walk along the storefronts
	var walk := MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(52, 0.08, 5.0)
	walk.mesh = wm
	walk.material_override = _surf(&"concrete", 9.0, Color(0.62, 0.62, 0.60), 0.85)
	add_child(walk)
	walk.global_position = Vector3(0, 0.05, 20.6)
	# Invisible walls so you can't waddle into the void
	for i in 4:
		var a := float(i) * PI * 0.5
		var w := _static_box(Vector3(sin(a) * LOT * 0.5, 6.0, cos(a) * LOT * 0.5),
			Vector3(LOT, 14.0, 1.0), Color(1, 1, 1), a)
		for c in w.get_children():
			if c is MeshInstance3D:
				c.visible = false


func _pond() -> void:
	## The suburban stormwater retention pond: true natural habitat of the
	## modern Canada goose, and where the whole game starts.
	var centre := POND_CENTRE

	var mi := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 11.0
	pm.bottom_radius = 11.0
	pm.height = 0.5
	mi.mesh = pm
	# A dark mud basin UNDER the surface. Without something dark behind it,
	# translucent water over green grass just reads as more grass — which is
	# exactly what happened the first time this was built.
	var basin := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 10.7
	bm.bottom_radius = 8.4
	bm.height = 2.2
	basin.mesh = bm
	basin.material_override = _surf(&"dirt", 5.0, Color(0.12, 0.13, 0.11), 0.95)
	add_child(basin)
	basin.global_position = centre + Vector3(0, -1.0, 0)

	# The surface itself: deliberately NOT the shared algae texture, which is
	# too close in hue to the grass. Flat blue with the ripple normal map.
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.13, 0.30, 0.44, 0.80)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.06
	m.metallic = 0.55
	if _tex != null:
		var nrm: Texture2D = _tex.get_tex(&"water_normal")
		if nrm != null:
			m.normal_enabled = true
			m.normal_texture = nrm
			m.normal_scale = 0.65
			m.uv1_scale = Vector3(6.0, 6.0, 6.0)
	mi.material_override = m
	add_child(mi)
	mi.global_position = centre + Vector3(0, 0.14, 0)

	var water := Area3D.new()
	water.add_to_group("water")
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 11.0
	sh.height = 2.4
	cs.shape = sh
	water.add_child(cs)
	water.monitoring = false
	add_child(water)
	water.global_position = centre + Vector3(0, 0.5, 0)

	# Cattails. Base-anchored models, so they go in at ground height rather than
	# at the half-height the old decal boxes needed.
	var reeds := _rng("cattails")
	for i in 26:
		var a := reeds.randf_range(0, TAU)
		var r := reeds.randf_range(POND_RADIUS + 0.2, POND_CLEAR - 0.4)
		_model_at(&"cattail", centre + Vector3(cos(a) * r, 0.0, sin(a) * r),
			reeds.randf_range(0, TAU), {}, reeds.randf_range(0.82, 1.18))


func _building() -> void:
	# Strip mall
	_static_tex(Vector3(0, 4.0, 30.0), Vector3(52, 8, 14), &"stucco", 5.0, Color(0.62, 0.56, 0.48))
	# Brick end caps break up the long stucco face.
	_static_tex(Vector3(-26.4, 4.0, 30.0), Vector3(1.2, 8.2, 14.2), &"brick", 3.0, Color(0.48, 0.28, 0.22))
	_static_tex(Vector3(26.4, 4.0, 30.0), Vector3(1.2, 8.2, 14.2), &"brick", 3.0, Color(0.48, 0.28, 0.22))
	# Storefront glass band
	_decal_box(Vector3(0, 2.4, 22.9), Vector3(48, 3.2, 0.2), Color(0.36, 0.48, 0.52))
	# Two benches on the walk, backs to the glass. The bench model was the one
	# thing in prop_models.gd with no call site anywhere; a strip mall with
	# nowhere to sit was already slightly wrong, so it gets a home here.
	# The walk is a 0.08 m decal slab on top of the asphalt, so the bench sits at
	# 0.09 rather than 0 or its feet vanish into the concrete.
	for bx in [-14.0, 16.0]:
		var bench_x: float = bx
		var bench := _static_box(Vector3(bench_x, 0.515, 20.8), Vector3(1.8, 0.85, 0.62),
			Color(0.46, 0.32, 0.20))
		_model_body(bench, &"bench", -0.425)
	# Sign pylon
	_static_box(Vector3(-20, 5.0, 18.0), Vector3(1.0, 10, 1.0), Color(0.3, 0.3, 0.32))
	_decal_box(Vector3(-20, 10.5, 18.0), Vector3(7.0, 2.4, 0.4), Color(0.85, 0.16, 0.12))
	# Roof units
	for i in 5:
		_decal_box(Vector3(-18 + i * 9, 8.6, 30.0), Vector3(3, 1.2, 3), Color(0.5, 0.5, 0.52))


func _parking() -> void:
	# Stalls
	var park := _rng("parking")
	for row in 3:
		var z := -2.0 + row * 9.0
		for i in 17:
			var x := -38.0 + i * 4.6
			_decal_box(Vector3(x, 0.03, z), Vector3(0.14, 0.04, 5.0), Color(0.86, 0.84, 0.62))
	# Minivans — heavy, mostly immovable, good for bouncing off
	var colors := [Color(0.62, 0.16, 0.16), Color(0.20, 0.28, 0.48), Color(0.82, 0.82, 0.84),
		Color(0.14, 0.14, 0.16), Color(0.36, 0.46, 0.36)]
	for i in 11:
		var x := -34.0 + park.randf_range(0, 1) * 4.0 + i * 6.4
		var z: float = [-2.0, 7.0, 16.0][i % 3] + park.randf_range(-0.6, 0.6)
		var v := _prop(Vector3(x, 1.0, z), Vector3(2.1, 1.9, 4.6),
			colors[i % colors.size()], 900.0, 120, "VEHICLE")
		v.breakable = false
		v.break_force = 999.0
		# Nose-in along the stalls. The stall lines run along Z (0.14 x 5.0) and
		# the minivan model's long axis is Z with the bonnet at -Z, so a yaw of
		# about zero is already square in the bay — the couple of degrees of
		# slop is somebody parking badly, not a modelling error.
		v.rotation.y = park.randf_range(-0.05, 0.05)
	# Lamp posts. Collider stays the 0.3 x 8.0 x 0.3 pole it always was; the
	# model brings its own tapered column and shoebox luminaire, which is why
	# the separate head decal is gone.
	for i in 6:
		var x := -30.0 + i * 12.0
		var post := _static_box(Vector3(x, 4.0, 11.5), Vector3(0.3, 8.0, 0.3),
			Color(0.34, 0.34, 0.36))
		_model_body(post, &"lamp_post", -4.0)


func _trees() -> void:
	## Crabapple / mountain ash. In late winter the fruit ferments on the branch
	## — this is the real mechanism behind drunk waxwings, and it's why the
	## berries source is up in a tree instead of on the ground.
	##
	## The canopy used to be a SphereMesh, which is the one shape that reads as
	## "programmer art" from any angle. tree_deciduous is three interpenetrating
	## faceted blobs on a leaning trunk, and its outline changes as you orbit
	## it. Trunk collider (0.5 x 3.2 x 0.5 at y 1.6) is unchanged, so the berry
	## pickup at y 4.6 is still exactly where it was, still in the branches.
	var grove := _rng("trees")
	var spots := [Vector3(-12, 0, -8), Vector3(-34, 0, -6), Vector3(-16, 0, -32), Vector3(6, 0, -26)]
	for si in spots.size():
		var s: Vector3 = spots[si]
		var trunk := _static_box(s + Vector3(0, 1.6, 0), Vector3(0.5, 3.2, 0.5),
			Color(0.34, 0.26, 0.20))
		# `variant` is a deterministic shape seed, so the four trees differ from
		# each other but are bit-identical between runs.
		_model_body(trunk, &"tree_deciduous", -1.6, {
			"colour": Color(0.34, 0.26, 0.20),
			"leaf_colour": Color(0.28, 0.36, 0.22),
			"variant": float(si) * 1.7,
		})
		# Fruit clusters, pushed out to the canopy's real radius.
		for i in 8:
			var a := grove.randf_range(0, TAU)
			_decal_box(s + Vector3(cos(a) * 1.75, 4.0 + grove.randf_range(-0.7, 0.8), sin(a) * 1.75),
				Vector3(0.3, 0.3, 0.3), Color(0.72, 0.14, 0.18))


func _sources() -> void:
	# Berries under the crabapples — reachable on the ground, better up top.
	var litter := _rng("garbage")
	_source(Vector3(-12, 0.5, -8), _berries, 0.5)
	_source(Vector3(-16, 0.5, -32), _berries, 0.5)
	_source(Vector3(-12, 4.6, -8), _berries, 0.62)  # in the branches: full-strength

	# The dumpster behind the coffee place. Same 3.4 x 2.0 x 2.0 collider, but
	# now with a sloped skirt, stiffening ribs, forklift pockets and two plastic
	# lids — one of them left ajar, because nobody has ever closed one properly.
	# The lid decal is part of the model now.
	var skip := _static_box(Vector3(19, 1.0, 21.0), Vector3(3.4, 2.0, 2.0),
		Color(0.20, 0.36, 0.28))
	_model_body(skip, &"dumpster", -1.0, {"colour": Color(0.20, 0.36, 0.28)})
	_source(Vector3(19, 2.6, 21.0), _coffee, 0.5)

	# Party garbage: whipped cream cans.
	_source(Vector3(30, 0.6, -12.0), _nitrous, 0.45)
	# `variant` is a deterministic shape seed for the sack: same pile every run,
	# but no two bags slumped the same way.
	for i in 7:
		_prop(Vector3(30 + litter.randf_range(-2.5, 2.5), 0.4,
				-12 + litter.randf_range(-2.5, 2.5)),
			Vector3(0.5, 0.7, 0.5), Color(0.12, 0.12, 0.14), 3.0, 15, "GARBAGE",
			{"variant": float(i) * 1.3}, litter)

	# Grass. You're a goose — this is both lunch and a controlled substance,
	# which is the single funniest fact in the whole design.
	var grass := Subs.get_substance(&"grass")
	for p in [Vector3(-20, 0.4, -14), Vector3(-30, 0.4, -26), Vector3(-14, 0.4, -24)]:
		_source(p, grass, 0.42, true)

	# A page of grade 9 long division, blowing across the lot.
	_source(Vector3(12, 0.5, -20.0), Subs.get_substance(&"math"), 0.42)
	_decal_box(Vector3(12, 0.06, -20.0), Vector3(1.4, 0.02, 1.9), Color(0.95, 0.95, 0.92))

	# Half a pack behind the plaza. Does almost nothing. You'll be back.
	_source(Vector3(-26, 0.5, 20.0), Subs.get_substance(&"darts"), 0.34)

	# Cereal box in the recycling.
	# z was 24.0, which is INSIDE the storefront — the same mistake the bins
	# three functions down already had fixed and written up. The building is a
	# (52, 8, 14) box centred at (0, 4, 30), so its collider fills z 23..37;
	# (-18, 0.5, 24) put the model and its OmniLight a metre deep in stucco with
	# only 0.6 m of the 1.6 m trigger sphere poking back through the wall. On
	# legs 1 and 2 — the player's first two zones — the box was invisible and
	# could only be eaten by pressing flat against blank stucco.
	#
	# 21.6 rather than the bins' own 22.4: x = -18 IS the fifth bin, and a
	# cereal box co-located with a 1.0 × 1.2 × 0.8 RigidBody3D is buried just as
	# thoroughly as one inside the wall. 0.8 m in front of the row is "in the
	# recycling" as far as the comment and the player are concerned.
	_source(Vector3(-18, 0.5, 21.6), Subs.get_substance(&"special_k"), 0.44)

	# Cough syrup, dropped by the pharmacy end of the plaza.
	_source(Vector3(24, 0.5, 18.0), Subs.get_substance(&"robo"), 0.42)

	# Somebody's herb garden, in a planter outside the plaza.
	_static_box(Vector3(-8, 0.3, 21.0), Vector3(3.0, 0.6, 1.4), Color(0.46, 0.32, 0.24))
	for i in 5:
		_decal_box(Vector3(-9.2 + i * 0.6, 0.85, 21.0), Vector3(0.18, 0.5, 0.18), Color(0.52, 0.76, 0.42))
	_source(Vector3(-8, 1.1, 21.0), Subs.get_substance(&"catnip"), 0.4)

	# Fly agaric on the grass verge — red cap, white spots, storybook mushroom.
	#
	# NO hand-built mushroom here. There used to be one at each of these two
	# spots, at the same XZ as the source: a SphereMesh hemisphere cap, a box
	# stem and seven decal spots. pickup_models.gd routes &"fly_agaric" straight
	# to prop_models.gd's faceted mushroom, so each spot was two mushrooms
	# interpenetrating, one smooth and one faceted — the exact mismatch
	# pickup_models.gd:483-494 says it converted the pickup to stop having. The
	# pickup IS the mushroom. (The seven spots also used randf_range, so they
	# moved every run; prop_models.gd:39-44 makes determinism a policy.)
	#
	# The stem was the zone's worst floater as well: p.y was 0.4 and
	# `_static_box` is centre-anchored, so a 0.6 m SOLID collider hung with its
	# base 0.4 m above ground the goose then hit in mid-air. Deleting it costs
	# nothing — a mushroom you bump into is not what these two spots were for,
	# and every other pickup on this verge is walk-through.
	#
	# VERGE_Y - PICKUP_LIFT rather than 0.4: standing in the grass, not hovering
	# at goose chest height over it.
	#
	# AND OUT OF THE POND. The XZ was (-33, -18) and (-19, -30) — 9.85 m and
	# 9.43 m from the pond centre (-24, -22), both inside the 11 m water
	# cylinder. Floating, that passed for "mushroom near water"; the moment they
	# were sat on the verge the render came back with two red caps bobbing on
	# the surface and their stems under it. The verge slab is 30 × 26 but the
	# GRASS is only what is left of it once the pond is subtracted, so these are
	# pushed out past the cattail ring (r 11.2-12.6) to r ≈ 13.4 and 13.2 on the
	# same two bearings from the pond they always had.
	var agaric := Subs.get_substance(&"fly_agaric")
	for p in [Vector3(-36.0, VERGE_Y - PICKUP_LIFT, -16.0),
			Vector3(-18.5, VERGE_Y - PICKUP_LIFT, -34.0)]:
		_source(p, agaric, 0.42)

	# A toad in the cattails. Do not lick the toad.
	#
	# NO second toad model here. pickup_models._build_toad_slime already builds
	# the whole animal — flattened body, bulging top-mounted eyes, pupils,
	# tucked front legs, five warts — and this file used to stack a squashed
	# SphereMesh underneath it at the same XZ, 0.3 m apart. zone_cottage.gd:1360
	# found and deleted exactly that ("stacked on the same rock like a Russian
	# doll") and this zone is legs 1 and 2, so the doubled one is the one the
	# player met first. It was also the last SphereMesh left in the file, and a
	# fourth toad implementation in a project CLAUDE.md already cites for
	# growing toads.
	#
	# Sat in the grass rather than floating 0.8 m over it: the model rides
	# PICKUP_LIFT above the Area3D origin and the &"breathe" idle leaves that
	# alone, so the verge height minus the lift is where the trigger goes.
	_source(Vector3(-24, VERGE_Y - PICKUP_LIFT, -33.5),
		Subs.get_substance(&"toad_slime"), 0.38)

	# BREAD. THE OBVIOUS FOOD, AND THE TRAP.
	#
	# CAMPAIGN_SPEC §2.1 asks for this here and calls it "the perfect
	# first-90-seconds lesson": the thing everybody knows you feed a goose is
	# the one thing that takes the game away from you. Twenty seconds of FULL,
	# chaos at half, and nothing else goes down.
	#
	# On the verge by the water, where the people who bring it stand — r = 14.1
	# from POND_CENTRE, clear of POND_CLEAR and of the cattail ring — with the
	# sign nobody reads right beside it. The sign is a lawn_sign model and NOT a
	# chaos prop: it is scenery, and wrecking the notice would be a different
	# joke from ignoring it.
	_source(Vector3(-34.0, VERGE_Y - PICKUP_LIFT, -12.0), Subs.get_substance(&"bread"), 0.5)
	_model_at(&"lawn_sign", Vector3(-32.2, VERGE_Y, -12.7), 0.42)

	# A leaking car battery in the corner of the lot.
	_source(Vector3(36, 0.5, 26.0), Subs.get_substance(&"acid"), 0.44)
	_static_box(Vector3(36, 0.22, 26.0), Vector3(0.9, 0.45, 0.6), Color(0.16, 0.16, 0.2))
	_decal_box(Vector3(36, 0.03, 26.6), Vector3(1.6, 0.02, 1.2), Color(0.42, 0.46, 0.30))

	# A poutine container that is not poutine.
	_source(Vector3(4, 0.5, 18.0), Subs.get_substance(&"gravy"), 0.4)
	_decal_box(Vector3(4, 0.1, 18.0), Vector3(0.7, 0.2, 0.7), Color(0.86, 0.82, 0.72))

	# The laundromat end of the plaza.
	_source(Vector3(-32, 0.5, 20.0), Subs.get_substance(&"bars"), 0.36)
	_decal_box(Vector3(-32, 0.06, 20.0), Vector3(0.5, 0.16, 0.34), Color(0.92, 0.94, 0.96))

	# A dropped pill organiser by the pharmacy.
	_source(Vector3(26, 0.5, 20.5), Subs.get_substance(&"percs"), 0.36)
	_decal_box(Vector3(26, 0.06, 20.5), Vector3(0.72, 0.14, 0.3), Color(0.90, 0.86, 0.60))

	# Molly is a golden retriever. She is at the dog park. She loves you.
	#
	# NO dog-shaped boxes here. pickup_models._build_molly builds `molly` out of
	# boss_ranger_visual.gd's actual retriever in the &"golden" coat; the peach
	# `_static_box` body and `_decal_box` head that used to follow this line are
	# from before that conversion and were never taken out. The render showed
	# the real dog hovering half-sunk into a 0.9 m crate — the shape
	# prop_models_cottage.gd:1163 describes as "a stack of cardboard rather than
	# an animal". The pickup IS Molly.
	#
	# 0.02 - PICKUP_LIFT, not +0.6: the model rides PICKUP_LIFT above the Area3D
	# origin and _build_molly sets the dog 0.02 below the model, so this is the
	# number that lands her paws on the asphalt instead of leaving her at goose
	# chest height. zone_cottage.gd:1498 did this and named this zone as one of
	# the two that had not.
	_source(Vector3(34, 0.02 - PICKUP_LIFT, 6.0), Subs.get_substance(&"molly"), 0.5)


func _props() -> void:
	# Shopping carts — the ideal chaos prop: light, loud, rolls forever.
	var carts := _rng("props")
	for i in 14:
		_prop(Vector3(carts.randf_range(-36, 36), 0.5, carts.randf_range(-14, 20)),
			Vector3(0.8, 1.0, 1.3), Color(0.74, 0.75, 0.78), 12.0, 35, "CART")
	# Cart corral
	for i in 6:
		_prop(Vector3(-6 + i * 0.9, 0.5, 4.0), Vector3(0.8, 1.0, 1.3),
			Color(0.74, 0.75, 0.78), 12.0, 35, "CART")
	# Patio set outside the coffee place
	for i in 8:
		_prop(Vector3(8 + carts.randf_range(-5, 5), 0.45, 19.0 + carts.randf_range(-2, 2)),
			Vector3(0.6, 0.9, 0.6), Color(0.42, 0.30, 0.22), 6.0, 30, "PATIO CHAIR")
	# Recycling bins
	# z was 24.0, which is INSIDE the storefront volume (the building spans
	# z 23..37). Three of the five bins were being ejected to y = -1120 within
	# two seconds and were unreachable and unscoreable for the whole run.
	for i in 5:
		_prop(Vector3(-30 + i * 3.0, 0.6, 22.4), Vector3(1.0, 1.2, 0.8),
			Color(0.14, 0.32, 0.58), 8.0, 40, "RECYCLING")
	# Lawn signs, on the LAWN.
	#
	# The sampling window x [-30, 30] * z [-30, -18] overlaps the retention
	# pond, and 27.1% of its area is inside the 11 m water cylinder — so about
	# 2.4 of these 9 signs stood in the water on an average run, in the first
	# zone the player ever sees. Measured by sampling the two shapes, not
	# estimated. Rejection-sampled against POND_CLEAR now, so the signs land on
	# grass and the number of them stays 9.
	for i in 9:
		# ONE sample, held. Calling `_dry_xz()` once per axis would draw two
		# independent dry points and use x from one and z from the other, and
		# the pair is not guaranteed to be dry — which is the original bug with
		# extra steps.
		var sign_xz := _dry_xz(-30.0, 30.0, -30.0, -18.0, carts)
		_prop(Vector3(sign_xz.x, 0.6, sign_xz.y),
			Vector3(1.1, 0.8, 0.08), Color(0.92, 0.86, 0.20), 2.0, 25, "LAWN SIGN")


func _people() -> void:
	var folks := _rng("people")
	var shirts := [Color(0.78, 0.24, 0.22), Color(0.22, 0.34, 0.62), Color(0.90, 0.86, 0.42),
		Color(0.28, 0.52, 0.34), Color(0.56, 0.30, 0.62), Color(0.92, 0.92, 0.92)]
	for i in 9:
		var n := NpcHuman.new()
		add_child(n)
		n.setup(shirts[i % shirts.size()])
		n.global_position = Vector3(folks.randf_range(-32, 32), 0.1,
			folks.randf_range(-10, 22))


## Title shown by the HUD at the top of the leg.
## Which objective set the Mission autoload should load for this zone.
func mission_zone_id() -> StringName:
	return &"strip_mall"


func zone_title() -> String:
	return "LEG %d — STRIP MALL LOT" % Flock.leg


func _cats() -> void:
	## Cats exist so catnip has something to command. Roughly a third of them
	## will ignore you entirely, which is both accurate and funnier.
	var moggies := _rng("cats")
	var furs := [Color(0.24, 0.22, 0.21), Color(0.78, 0.62, 0.36), Color(0.92, 0.92, 0.90),
		Color(0.46, 0.42, 0.40), Color(0.62, 0.44, 0.24)]
	for i in 7:
		var c := Cat.new()
		add_child(c)
		c.setup(furs[i % furs.size()])
		c.global_position = Vector3(moggies.randf_range(-34, 34), 0.2,
			moggies.randf_range(-16, 24))


func _spawn_goose() -> void:
	goose = Goose.new()
	goose.name = "Goose"
	add_child(goose)
	# On the grass at the pond's edge, not in the water: the player should see
	# the bird clearly for the first few seconds and choose to get in.
	goose.global_position = Vector3(-24, 1.0, -6)

	camera_rig = preload("res://scripts/goose/goose_camera.gd").new()
	camera_rig.name = "CameraRig"
	camera_rig.target = goose
	add_child(camera_rig)
	goose.cam = camera_rig

	# NO SHAKE WIRING HERE. The zone used to connect landed/tumbled straight to
	# camera_rig.add_shake(); the Juice autoload owns the shake bus now and the
	# goose controller drives it, so leaving these lambdas in shook the camera
	# twice for one landing — and, worse, bypassed the screen_shake
	# accessibility pref that Juice gates every shake on.
