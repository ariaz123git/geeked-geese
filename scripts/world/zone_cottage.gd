extends Node3D
## LEG 3 — COTTAGE COUNTRY, AT NIGHT
##
## Muskoka. A granite shelf with a cottage on it, a lake underneath, and about
## six metres of nothing in between. Graybox-plus-models, built procedurally so
## it runs correctly the first time you open the project with no import step
## and no missing references.
##
## TODO(art pass): same caveat as the other two zones — once this plays right,
## rebuild it as a real .tscn. Procedural is the right call for a first
## playable and the wrong call for level design.
##
## ---------------------------------------------------------------------------
## WHY THIS ZONE EXISTS — the three things it does that the others can't
## ---------------------------------------------------------------------------
## 1. IT IS DARK. The strip mall is flat overcast grey, suburbia is warm
##    horizontal golden hour. This is a black-blue sky, a 0.6 moon, and eleven
##    point lights doing all the real work. If it ever reads as "the parking
##    lot with the lights off", the zone has failed and the fix is more
##    SOURCES, not more ambient.
##
## 2. IT IS VERTICAL. The other two zones are flat planes with props on them;
##    the only height is a roof. Here the cottage sits on a shelf at y = 6.6
##    and the lake is at y = 0, so *every* traversal decision is a height
##    decision. You can walk the zigzag stairs, hop the granite ledges one
##    flap at a time, or dive off the cliff — and the way down is always
##    faster and funnier than the way up, which is exactly the pressure a
##    flight controller wants.
##
## 3. THE WATER IS A PLACE, NOT A DECORATION. The strip mall pond is an
##    eleven-metre disc. This is thirty-five metres of swimmable lake with a
##    dock, a boathouse and two loons on it, and the swim state is a genuine
##    third mode rather than a novelty you fall into once.
##
## ---------------------------------------------------------------------------
## ART PASS — faceted models over graybox colliders
## ---------------------------------------------------------------------------
## Identical split to the other two zones, and worth restating because it is
## the thing that goes wrong:
##
##   * PHYSICS is boxes. Every collider here is a BoxShape3D and nothing in
##     the art is allowed to move one.
##   * ART is a model hung off that box, base-anchored to the collider's floor.
##
## The two anchoring conventions do not agree: both model libraries build with
## the base at local y = 0, while BoxShape3D/BoxMesh are centred on the origin.
## So a model on a collider always drops by -height * 0.5. Miss it and the
## whole shoreline hovers.
##
## ---------------------------------------------------------------------------
## THE HEIGHT TABLE — the one thing to read before moving anything
## ---------------------------------------------------------------------------
##     y = -0.30   lake bed (solid, so nothing falls through the world)
##     y =  0.00   water surface
##     y =  0.20   top of the water Area3D — the swim/wade transition
##     y =  0.55   shore terrace, full width, always walkable
##     y =  1.95   granite ledge 1  (+/- 0.22 of per-segment jitter)
##     y =  3.55   granite ledge 2
##     y =  5.10   granite ledge 3
##     y =  6.60   the plateau: cottage, fire, everything
##
## TWO NUMBERS IN HERE ARE LOAD-BEARING AND WERE BOTH SET BY MEASUREMENT.
##
## 1. THE LEDGE SPACING. A single flap from a standstill is
##    flap_impulse^2 / (2 * glide_gravity) = 6.4^2 / 22 = 1.86 m of rise. The
##    largest gap on this face is terrace-to-ledge-1 at 1.62 m WITH the
##    worst-case per-segment jitter applied, so every step up is inside one
##    flap for a bird with almost no stamina left. First draft put ledge 1 at
##    2.10 and the jitter pushed the worst case to 1.77 — technically possible,
##    and exactly the kind of margin that turns into "I'm stuck at the bottom".
##
## 2. THE WADE LINE. The goose's body collider is a capsule lying along Z, so
##    its VERTICAL half-extent is the 0.34 radius, not the 0.55 half-length,
##    and its water probe is a 0.22 sphere on the origin. So:
##      * resting on the bed, the bird's origin is bed + 0.34,
##      * the probe reaches down to origin - 0.22 = bed + 0.12.
##    A bed at -0.30 and an Area3D top at 0.20 therefore means the bird floats
##    with its origin at 0.04 — waterline just under halfway up the body, which
##    is what a swimming goose looks like — and switches to the swim state when
##    the rock under its feet drops about a hand's width below the surface.
##    The first pass had the bed at -0.55 and the bird swam with 80% of itself
##    submerged, which reads as drowning.

const LOT := 80.0

## Preloaded rather than referenced by class_name: global class registration
## only exists after an editor import pass, so a `class_name` reference breaks
## in a fresh checkout or a headless CI run. A preload const always resolves.
const PROPS := preload("res://scripts/world/prop_models.gd")
const COTTAGE := preload("res://scripts/world/prop_models_cottage.gd")

# ── the height table, as constants ──────────────────────────────────────────
const WATER_Y := 0.0
const BED_Y := -0.30
const SHORE_Y := 0.55
const PLATEAU_Y := 6.60
const SHORE_Z := -2.0        ## where the shore terrace ends and the face begins
const FACE_Z := 4.60         ## where the face ends and the plateau begins
const WATER_Z := -5.00       ## the waterline
const LEDGE_Y := [1.95, 3.55, 5.10]

## The one stone colour everything on the face is derived from. Deliberately
## very dark: it is multiplied into the concrete texture, and the first pass
## used 0.30 here, which under a 0.46 blue ambient rendered as pale lavender
## poured concrete. Shield granite at night is almost black with a warm cast.
const C_GRANITE := Color(0.175, 0.165, 0.180)

## Loose stone is a SEPARATE, DARKER colour from the bedrock, and that is not
## an aesthetic choice. The face and the terrace are textured (concrete at
## ~0.55 mean, multiplied by C_GRANITE, so about 0.10 albedo); the boulder
## models are untextured vertex colour, so passing them the same 0.175 put
## every rock in the zone at roughly twice the value of the ground it was
## sitting on. From above, at night, that renders as litter.
const C_ROCK := Color(0.112, 0.106, 0.116)

## Chaos-prop label -> model kind, across BOTH libraries. Keyed off the label
## the prop already carries — the same string scoring and objectives match on —
## so there is one place to look and no call site repeats itself. A label with
## no entry keeps its BoxMesh, which is what "LIFE JACKET" and friends want.
const PROP_KIND := {
	"CANOE": &"canoe",
	"KAYAK": &"kayak",
	"MUSKOKA CHAIR": &"muskoka_chair",
	"COOLER": &"cooler",
	"PADDLE": &"paddle",
	"FIREWOOD": &"log",
	"TWO-FOUR": &"two_four",
	"PICNIC TABLE": &"picnic_table",
	# from the shared library
	"VEHICLE": &"minivan",
	"BBQ": &"bbq",
	"PATIO CHAIR": &"patio_chair",
	"RECYCLING": &"recycling_bin",
	"GARBAGE": &"garbage_bag",
}

## The shoreline, segment by segment along X. Style decides whether that stretch
## of rock face is climbable or not, which is what stops it reading as one
## eighty-metre staircase.
##   x0, x1, style (0 = three ledges, 1 = sheer cliff, 2 = one ledge halfway),
##   deterministic z-jitter seed
const FACE_SEGMENTS := [
	[-40.0, -30.0, 0, 0.0],
	[-30.0, -21.0, 2, 0.7],
	[-21.0, -9.0, 1, 0.0],     ## THE CLIFF, directly below the fire pit
	[-9.0, -1.0, 0, 1.3],
	[-1.0, 8.0, 0, 2.1],
	[8.0, 17.0, 2, 0.4],       ## the wooden staircase zigzags down this one
	[17.0, 27.0, 0, 1.7],
	[27.0, 40.0, 1, 0.0],      ## a second cliff at the far end, for variety
]

var goose: Goose
var camera_rig: Node3D

var _tex: Node = null   ## /root/Tex — may not exist, always guard.
var _sfx: Node = null   ## /root/Sfx — may not exist, always guard.

var _t := 0.0
var _fire_lights: Array[OmniLight3D] = []
var _zap_light: OmniLight3D = null
var _zap_cd := 3.0
var _loons: Array[Node3D] = []
var _loon_cd := 6.0
var _toad_node: Node3D = null
var _toad_seen := false
var _toad_croak := 1.5
var _dock_light_node: OmniLight3D = null


func _ready() -> void:
	_tex = get_node_or_null("/root/Tex")
	_sfx = get_node_or_null("/root/Sfx")

	_environment()
	_lake()
	_shore()
	_stairs()
	_dock()
	_boathouse()
	_the_cottage()
	_campfire()
	_yard()
	_forest()
	_boats()
	_wildlife()
	_sources()
	_props()
	_people()
	_cats()
	_spawn_goose()
	# Your flock, physically present up on the shelf where the light is. This
	# is the only place the Designated Driver can actually be chosen, and the
	# only in-zone feedback on how wrecked your geese are getting.
	add_child(preload("res://scripts/world/flock_pen.gd").new().setup(
		Vector3(-24.0, PLATEAU_Y + 0.2, 9.0)))


# ------------------------------------------------------------------ helpers

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
		var m: StandardMaterial3D = _tex.surface(key, uv_scale, rough, fallback)
		if m != null:
			return m
	return _mat(fallback, rough)


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


## Same as _static_box but with a textured material.
func _static_tex(pos: Vector3, size: Vector3, key: StringName, uv_scale: float,
		fallback: Color, rot_y := 0.0, rough := 0.92) -> StaticBody3D:
	var sb := _static_box(pos, size, fallback, rot_y)
	var mat := _surf(key, uv_scale, fallback, rough)
	for c in sb.get_children():
		if c is MeshInstance3D:
			c.material_override = mat
	return sb


## A ramp whose TOP SURFACE passes through (z0,y0) and (z1,y1), running along
## Z at a constant X width. Written as endpoints rather than as a centre and an
## angle because every ramp in this zone exists to join two known heights, and
## doing that trigonometry at the call site is how you end up with a 35 cm lip
## the goose trips over at the top of the beach.
##
## Pass the LOWER-Z end first. `thick` is the slab depth; the centre is pushed
## down by half of it along Y, which leaves a sin(pitch) * thick/2 error in Z
## that is under 20 cm on every ramp here and invisible under the rock dressing.
func _ramp_between(z0: float, y0: float, z1: float, y1: float, width: float,
		thick: float, key: StringName, uv: float, col: Color) -> StaticBody3D:
	var dz := z1 - z0
	var dy := y1 - y0
	var length := sqrt(dz * dz + dy * dy)
	# +Z end goes DOWN for a positive X rotation, so rising toward +Z is negative.
	var pitch := -atan2(dy, dz)
	var my := (y0 + y1) * 0.5 - (thick * 0.5) / maxf(cos(pitch), 0.25)
	var sb := _static_tex(Vector3(0, my, (z0 + z1) * 0.5), Vector3(width, thick, length),
		key, uv, col)
	sb.rotation = Vector3(pitch, 0.0, 0.0)
	return sb


func _decal_box(pos: Vector3, size: Vector3, color: Color, rot_y := 0.0) -> MeshInstance3D:
	## Visual only — no collider. For paint, flat detail, water surfaces.
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
	return mi


## A flat, non-colliding textured slab. Ground dressing goes through here
## rather than through _decal_box so it picks up a real material.
##
## THE TILING IS NOT COSMETIC. This project renders on GL Compatibility, where
## a single MeshInstance3D is lit by at most eight lights (the engine default).
## An eighty-metre plateau as ONE mesh therefore picks eight of the zone's
## eleven point lights and drops the rest — and which eight it picks changes
## as things move, so the ground flickers. Every large surface in this zone is
## split into tiles for exactly that reason, and the tile count is chosen so a
## tile is never within range of more than about four sources.
func _flat_tiles(centre: Vector3, size: Vector3, nx: int, nz: int, key: StringName,
		fallback: Color, uv_scale: float, rough := 0.94) -> void:
	var mat := _surf(key, uv_scale, fallback, rough)
	var tw := size.x / float(nx)
	var td := size.z / float(nz)
	for ix in nx:
		for iz in nz:
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(tw, size.y, td)
			mi.mesh = bm
			mi.material_override = mat
			add_child(mi)
			mi.global_position = centre + Vector3(
				-size.x * 0.5 + tw * (float(ix) + 0.5), 0.0,
				-size.z * 0.5 + td * (float(iz) + 0.5))


func _prop(pos: Vector3, size: Vector3, color: Color, mass_kg: float, pts: int,
		lbl: String, extra := {}) -> ChaosProp:
	var p := ChaosProp.new()
	add_child(p)
	var kind: StringName = PROP_KIND.get(lbl, &"")
	var params: Dictionary = extra.duplicate()
	if kind != &"":
		params[_colour_key(kind)] = color

	if COTTAGE.has_model(kind):
		# ChaosProp.setup() only knows the SHARED library, so anything from
		# this zone's own library is built here instead and the graybox hidden.
		# `_visual` has to be repointed or _break() would hide the invisible
		# box and leave a fully intact canoe standing in its own debris.
		p.setup(size, color, mass_kg, pts, lbl)
		_hide_meshes(p)
		params["size"] = size
		var m: Node3D = COTTAGE.build(kind, p, params)
		m.position.y = -size.y * 0.5
		p._visual = m
	else:
		p.setup(size, color, mass_kg, pts, lbl, kind, params)

	p.global_position = pos
	p.rotation.y = randf_range(-PI, PI)
	return p


## Which params key a model takes its main colour under. Only the minivan is
## odd — it has a body colour and a lot of trim that must NOT follow it.
func _colour_key(kind: StringName) -> String:
	if kind == &"minivan":
		return "body_colour"
	return "colour"


## Hide a body's box mesh and hang a faceted model off it instead. The collider
## is untouched — this is a visual swap only.
##
## `base_y` is the model's base in the body's LOCAL frame, which for a box
## collider of height h centred on the body is always -h * 0.5.
func _model_body(sb: StaticBody3D, kind: StringName, base_y: float, params := {},
		uniform := 1.0) -> Node3D:
	_hide_meshes(sb)
	var m: Node3D = COTTAGE.build(kind, sb, params) if COTTAGE.has_model(kind) \
		else PROPS.build(kind, sb, params)
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
	if COTTAGE.has_model(kind):
		COTTAGE.build(kind, n, params)
	else:
		PROPS.build(kind, n, params)
	if not is_equal_approx(uniform, 1.0):
		n.scale = Vector3.ONE * uniform
	return n


func _hide_meshes(sb: Node) -> void:
	for c in sb.get_children():
		if c is MeshInstance3D:
			c.visible = false


func _source(pos: Vector3, res: Substance, size := 0.5, infinite := false) -> void:
	if res == null:
		return
	var s := SubstancePickup.new()
	add_child(s)
	s.setup(res, size)
	s.infinite = infinite
	s.global_position = pos


## Every point light in the zone goes through here, so the budget is countable
## in one place and nothing accidentally ships with shadows on.
##
## SHADOWS ARE OFF ON EVERY OMNI. On GL Compatibility an omni shadow is a cube
## render; eleven of them at 60 fps on the integrated GPUs this project
## targets is not a trade worth making for a shadow the player reads as noise
## at night. The moon carries all the shadowing in this zone.
func _lamp(pos: Vector3, col: Color, energy: float, rng: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = 1.15
	l.shadow_enabled = false
	add_child(l)
	l.global_position = pos
	return l


# ══════════════════════════════════════════════════════════════ ENVIRONMENT
#
# THE NIGHT VISIBILITY SOLUTION, in the order the render tests forced it:
#
#   1. AMBIENT IS THE FLOOR, NOT THE MOON. A colour ambient at 0.55 means no
#      surface in the zone is ever darker than a legible deep blue. This is
#      the single line that decides whether the zone is playable, and it is
#      deliberately far above what a night sky actually delivers.
#   2. THE MOON IS THE SHAPE. A 0.62 directional with shadows on is what makes
#      the granite read as granite and the pines cast across the rock. Without
#      it the ambient alone renders the world as flat cardboard.
#   3. THE POINT LIGHTS ARE THE PLACE. Eleven warm/violet/white sources say
#      "cottage" in a way no amount of blue ambient can, and they are what the
#      player actually navigates by.
#   4. THE PICKUPS ARE THE BREADCRUMBS. Every SubstancePickup already carries
#      its own OmniLight3D — at night that stops being findability polish and
#      becomes the zone's wayfinding layer, so sources are spread deliberately
#      along the routes rather than clustered.
#   5. FOG IS AERIAL PERSPECTIVE, NOT MURK. 0.0045 density in a blue that
#      matches the sky, so the far shore separates from the near one and the
#      lake reads as thirty-five metres deep instead of as a hole.

func _environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	# Not black. A clear September night over a lake is a very deep blue with
	# a green-grey band left in the west, and that band is what keeps the
	# horizon line readable — which is what keeps a flying player oriented.
	sm.sky_top_color = Color(0.020, 0.035, 0.090)
	sm.sky_horizon_color = Color(0.115, 0.155, 0.245)
	sm.ground_bottom_color = Color(0.012, 0.020, 0.045)
	sm.ground_horizon_color = Color(0.085, 0.115, 0.185)
	sm.sky_curve = 0.18
	# The moon. ProceduralSkyMaterial draws a disc per DirectionalLight3D, so
	# a small angle and a hard curve give an actual moon in the sky rather
	# than a smear — and the player can navigate by it.
	sm.sun_angle_max = 3.5
	sm.sun_curve = 0.06
	sky.sky_material = sm

	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# COLOR, not SKY. Sky ambient at this sky is essentially zero, and a zone
	# lit by essentially zero is the failure mode this whole file is written
	# against. An explicit lift, in a blue that reads as moonlight.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.34, 0.44, 0.68)
	env.ambient_light_energy = 0.46
	env.fog_enabled = true
	env.fog_density = 0.0045
	env.fog_light_color = Color(0.10, 0.145, 0.245)
	env.fog_light_energy = 0.9
	env.fog_sky_affect = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.22
	env.tonemap_white = 3.0
	we.environment = env
	add_child(we)

	# ── the moon ────────────────────────────────────────────────────────
	# Low in the north-west, over the far shore, so its glare path on the
	# water runs toward the dock and the whole lake has a bright side and a
	# dark side instead of being uniformly dim.
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-26.0, 196.0, 0.0)
	moon.light_energy = 0.82
	moon.light_color = Color(0.66, 0.76, 1.00)
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 90.0
	moon.light_angular_distance = 0.6
	add_child(moon)

	# A second, shadowless directional from behind the cottage. Not realism —
	# a rim on the far side of every pine and every rock, so the silhouettes
	# separate from the sky. Without it the treeline is one black mass.
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-14.0, 16.0, 0.0)
	rim.light_energy = 0.17
	rim.light_color = Color(0.44, 0.56, 0.86)
	rim.shadow_enabled = false
	add_child(rim)


# ══════════════════════════════════════════════════════════════════ LAKE

func _lake() -> void:
	var lake_z0 := -LOT * 0.5      ## -40
	var lake_z1 := WATER_Z         ## -5
	var lake_d := lake_z1 - lake_z0
	var lake_c := (lake_z0 + lake_z1) * 0.5

	# ── the bed ─────────────────────────────────────────────────────────
	# Solid, so a bird that dives hard has something to hit instead of the
	# void, and so the flock pen's ground raycast finds an answer everywhere.
	_static_tex(Vector3(0, BED_Y - 2.0, lake_c), Vector3(LOT, 4.0, lake_d),
		&"dirt", 12.0, Color(0.055, 0.075, 0.075))

	# ── the surface ─────────────────────────────────────────────────────
	# Tiled for the light-cap reason in _flat_tiles, and because one 80 x 35
	# quad with a normal map gets exactly one specular highlight for the whole
	# lake, which is the least convincing water in any game ever shipped.
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.045, 0.085, 0.145, 0.88)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.roughness = 0.045
	wm.metallic = 0.85
	# Emission, low and cold. A lake at night is not self-luminous, but a lake
	# rendered at true zero is a hole in the world and the player flies into
	# it. This is the smallest lie that makes the water surface legible from
	# the top of the cliff.
	wm.emission_enabled = true
	wm.emission = Color(0.10, 0.19, 0.30)
	wm.emission_energy_multiplier = 0.42
	if _tex != null:
		var nrm: Texture2D = _tex.get_tex(&"water_normal")
		if nrm != null:
			wm.normal_enabled = true
			wm.normal_texture = nrm
			wm.normal_scale = 0.85
			wm.uv1_scale = Vector3(9.0, 9.0, 9.0)
	for ix in 6:
		for iz in 4:
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(LOT / 6.0, 0.10, lake_d / 4.0)
			mi.mesh = bm
			mi.material_override = wm
			add_child(mi)
			mi.global_position = Vector3(
				-LOT * 0.5 + (LOT / 6.0) * (float(ix) + 0.5),
				WATER_Y - 0.05,
				lake_z0 + (lake_d / 4.0) * (float(iz) + 0.5))

	# ── the moon path ───────────────────────────────────────────────────
	# A band of brighter water running from under the moon toward the dock.
	# Physically it is the specular glare of a low moon on a rippled surface;
	# practically it is the only thing that gives thirty-five metres of black
	# water a READABLE DIRECTION, and without it a player out over the lake at
	# night has no cue at all for which way the shore is. Faked as a strip of
	# additive tiles rather than left to the specular highlight, because a
	# single flat quad with a normal map produces exactly one hotspot for the
	# whole lake.
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.62, 0.74, 0.96, 0.16)
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if _tex != null:
		var gnrm: Texture2D = _tex.get_tex(&"water_normal")
		if gnrm != null:
			gm.albedo_texture = gnrm
			gm.uv1_scale = Vector3(5.0, 7.0, 1.0)
	for i in 9:
		var t := float(i) / 8.0
		var gz := lerpf(-38.0, -6.5, t)
		# Widens and dims with distance, the way a glare path actually does.
		var gw := lerpf(9.5, 3.2, t)
		var mi2 := MeshInstance3D.new()
		var bm2 := BoxMesh.new()
		bm2.size = Vector3(gw, 0.04, 3.9)
		mi2.mesh = bm2
		mi2.material_override = gm
		add_child(mi2)
		mi2.global_position = Vector3(lerpf(-17.0, -8.0, t), WATER_Y + 0.035, gz)

	# ── the swimmable volume ────────────────────────────────────────────
	# One box Area3D over the whole lake. Its TOP EDGE is the wade line — see
	# the height table at the top of this file for the capsule arithmetic that
	# picked 0.20. Set it higher and the bird "swims" while visibly standing on
	# dry granite; set it lower and it walks along the lake bed.
	var water := Area3D.new()
	water.add_to_group("water")
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(LOT + 4.0, 2.4, lake_d + 0.5)
	cs.shape = bs
	water.add_child(cs)
	water.monitoring = false
	add_child(water)
	water.global_position = Vector3(0, 0.20 - 1.2, lake_c - 0.25)

	# ── the far shore ───────────────────────────────────────────────────
	# A ridge of black pines across the top of the lake at the map edge. It is
	# the horizon line the player orients on when they are out over the water
	# with nothing else in frame, and it costs eleven models.
	for i in 11:
		var x := -38.0 + float(i) * 7.6 + 1.8 * sin(float(i) * 2.1)
		var z := -38.5 + 1.4 * cos(float(i) * 1.7)
		_model_at(&"pine", Vector3(x, -0.4, z), float(i) * 0.9,
			{"colour": Color(0.10, 0.11, 0.14),
			"leaf_colour": Color(0.045, 0.075, 0.105),
			"variant": float(i) * 1.6}, 0.75 + 0.22 * sin(float(i) * 3.3))

	# Invisible walls, tall enough to matter now that the play space is
	# fourteen metres deep rather than flat.
	for i in 4:
		var a := float(i) * PI * 0.5
		_hide_meshes(_static_box(
			Vector3(sin(a) * LOT * 0.5, 9.0, cos(a) * LOT * 0.5),
			Vector3(LOT, 26.0, 1.0), Color(1, 1, 1), a))


# ══════════════════════════════════════════════════════════ SHORE AND FACE

func _shore() -> void:
	# ── the wade-in ramp, full width ────────────────────────────────────
	# 30 degrees, comfortably inside the goose's 45-degree floor limit, and it
	# runs the WHOLE eighty metres. There is deliberately no stretch of this
	# shoreline you can swim up to and be unable to get out of: this zone
	# already asks the player to solve a six-metre cliff, and stacking "and
	# also you are stuck in the lake" on top of that is not difficulty, it is
	# a bug with a story.
	_ramp_between(-6.90, BED_Y, WATER_Z, SHORE_Y, LOT, 0.70, &"concrete", 22.0,
		C_GRANITE)

	# ── the shore terrace ───────────────────────────────────────────────
	_static_tex(Vector3(0, SHORE_Y - 0.6, (WATER_Z + SHORE_Z) * 0.5),
		Vector3(LOT, 1.2, SHORE_Z - WATER_Z), &"concrete", 26.0, C_GRANITE)

	# ── the face, segment by segment ────────────────────────────────────
	# `lips` accumulates (x, top y, lip z) for every horizontal edge the face
	# produces. Everything in _dress_face() hangs off that list, which is the
	# only reason the dressing survives a change to FACE_SEGMENTS.
	var lips: Array = []
	for si in range(FACE_SEGMENTS.size()):
		var seg: Array = FACE_SEGMENTS[si]
		var x0: float = seg[0]
		var x1: float = seg[1]
		var style: int = seg[2]
		var jitter: float = seg[3]
		var w := x1 - x0
		var cx := (x0 + x1) * 0.5
		# Every segment gets its own stone colour. Shield granite is pink,
		# grey and near-black within one outcrop, and eight identical grey
		# boxes in a row is what made the first pass look like stadium seating.
		var tint := C_GRANITE.lightened(0.055 * sin(jitter * 2.3 + float(si)))
		tint = Color(tint.r * (1.0 + 0.10 * sin(float(si) * 1.7)), tint.g,
			tint.b * (1.0 + 0.08 * cos(float(si) * 2.1)))
		match style:
			1:
				# Sheer. One slab from the terrace to the plateau. This is the
				# thing you dive off, so it is deliberately clean — a face with
				# ledges in it is a face you bounce down.
				_static_tex(Vector3(cx, (SHORE_Y + PLATEAU_Y) * 0.5 - 3.0,
					(SHORE_Z + FACE_Z) * 0.5),
					Vector3(w, PLATEAU_Y + 6.0, FACE_Z - SHORE_Z),
					&"concrete", 9.0, tint.darkened(0.06))
				lips.append([cx, PLATEAU_Y, SHORE_Z, w, true])
			2:
				# One broad ledge halfway up: a landing, not a staircase.
				var mid_y: float = LEDGE_Y[1]
				var mid_z: float = SHORE_Z + (FACE_Z - SHORE_Z) * (0.34 + 0.10 * sin(jitter))
				_static_tex(Vector3(cx, mid_y * 0.5 - 3.0, (SHORE_Z + mid_z) * 0.5),
					Vector3(w, mid_y + 6.0, mid_z - SHORE_Z), &"concrete", 11.0, tint)
				_static_tex(Vector3(cx, PLATEAU_Y * 0.5 - 3.0, (mid_z + FACE_Z) * 0.5),
					Vector3(w, PLATEAU_Y + 6.0, FACE_Z - mid_z),
					&"concrete", 9.0, tint.darkened(0.05))
				lips.append([cx, mid_y, SHORE_Z, w, false])
				lips.append([cx, PLATEAU_Y, mid_z, w, true])
			_:
				# Three ledges. Each rise is 1.4-1.6 m, which is one flap.
				var prev_z := SHORE_Z
				for li in 3:
					var t := (float(li) + 1.0) / 4.0
					var lz: float = SHORE_Z + (FACE_Z - SHORE_Z) * t \
						+ 0.55 * sin(jitter + float(li) * 1.9)
					var ly: float = LEDGE_Y[li] + 0.22 * sin(jitter * 1.6 + float(li))
					_static_tex(Vector3(cx, ly * 0.5 - 3.0, (prev_z + lz) * 0.5),
						Vector3(w, ly + 6.0, lz - prev_z), &"concrete", 13.0,
						tint.lightened(0.03 * float(li)))
					lips.append([cx, ly, prev_z, w, false])
					prev_z = lz
				_static_tex(Vector3(cx, PLATEAU_Y * 0.5 - 3.0, (prev_z + FACE_Z) * 0.5),
					Vector3(w, PLATEAU_Y + 6.0, FACE_Z - prev_z), &"concrete", 11.0,
					tint.darkened(0.04))
				lips.append([cx, PLATEAU_Y, prev_z, w, true])

	# ── the plateau ─────────────────────────────────────────────────────
	# One collider, many visual tiles. The collider is a single box because
	# physics does not care about the light cap and a hundred small static
	# bodies is a hundred broadphase entries for no gain.
	var plat_d := LOT * 0.5 - FACE_Z
	var plat_c := (FACE_Z + LOT * 0.5) * 0.5
	var plat := _static_box(Vector3(0, PLATEAU_Y - 3.0, plat_c),
		Vector3(LOT, 6.0, plat_d), Color(0.16, 0.15, 0.13))
	_hide_meshes(plat)
	# Pine-needle duff over the whole shelf...
	_flat_tiles(Vector3(0, PLATEAU_Y - 0.02, plat_c), Vector3(LOT, 0.10, plat_d),
		6, 4, &"dirt", Color(0.135, 0.115, 0.092), 16.0)
	# ...with the mown patch around the cottage and the fire, and bare granite
	# where the shelf breaks through. Three surfaces, so the shelf reads as a
	# place somebody maintains rather than as a texture.
	_flat_tiles(Vector3(-8.0, PLATEAU_Y + 0.01, 14.0), Vector3(30.0, 0.08, 16.0),
		4, 2, &"grass", Color(0.105, 0.175, 0.100), 6.0)
	_flat_tiles(Vector3(6.0, PLATEAU_Y + 0.02, 7.4), Vector3(26.0, 0.06, 7.0),
		3, 1, &"concrete", C_GRANITE.lightened(0.05), 9.0)
	_flat_tiles(Vector3(-24.0, PLATEAU_Y + 0.02, 8.0), Vector3(16.0, 0.06, 7.0),
		2, 1, &"concrete", C_GRANITE, 9.0)

	_dress_face(lips)


## Everything that turns eight grey boxes into a shoreline.
##
## The face is built from box colliders because physics has to be predictable
## and a goose has to be able to land on a ledge without the collision normal
## arguing with it. That leaves the ART with a problem the first render made
## very plain: straight full-width horizontal edges, at night, from below, read
## as CONCRETE STADIUM SEATING and nothing else. So every edge the face
## produces is broken here — boulders straddling the lip, talus piled at the
## foot, scrub along the top, and vertical fracture lines down the sheer bits.
##
## None of it collides. The player's mental model of the face stays exactly the
## boxes it actually is, which is what you want; only the silhouette lies.
func _dress_face(lips: Array) -> void:
	for i in range(lips.size()):
		var row: Array = lips[i]
		var cx: float = row[0]
		var ly: float = row[1]
		var lz: float = row[2]
		var w: float = row[3]
		var is_top: bool = row[4]
		# Boulders sitting ON the lip, half over the edge.
		var n: int = maxi(1, int(w / 5.5))
		for k in n:
			var t := (float(k) + 0.5) / float(n)
			var x := cx - w * 0.5 + w * t
			var ph := float(i) * 3.1 + float(k) * 1.9
			# Big, and few. Twenty boulders the size of a goose read as gravel;
			# six the size of a car read as an outcrop.
			var scl := 0.95 + 0.75 * absf(sin(ph))
			_model_at(&"rock", Vector3(x + 0.7 * sin(ph * 2.3), ly - 0.62 * scl,
				lz + 0.30 + 0.8 * absf(cos(ph))), ph,
				{"colour": C_ROCK.lightened(0.05), "variant": ph}, scl)
		# Fracture lines down the riser. Thin dark slots — one of the two cues
		# (with lichen) that says "this stone was here first".
		for k in maxi(1, n / 2):
			var ph2 := float(i) * 2.7 + float(k) * 4.1
			_decal_box(Vector3(cx - w * 0.5 + w * ((float(k) + 0.35) / float(maxi(n / 2, 1))),
				ly - 0.9, lz - 0.02), Vector3(0.10, 1.7, 0.06), Color(0.05, 0.05, 0.06),
				0.10 * sin(ph2))
		# A band of moss and needle litter along the lip. Two centimetres of
		# decal, and it is most of what stops a horizontal rock edge reading as
		# the top of a poured wall.
		_decal_box(Vector3(cx, ly + 0.035, lz + 0.55), Vector3(w * 0.94, 0.05, 1.25),
			Color(0.085, 0.115, 0.075))
		# Scrub along the top edge, where the only soil is.
		if is_top:
			for k in maxi(1, n / 2):
				var ph3 := float(i) * 1.3 + float(k) * 2.7
				_model_at(&"scrub", Vector3(cx - w * 0.5 + w * ((float(k) + 0.7) / float(maxi(n / 2, 1))),
					ly - 0.05, lz + 1.1 + 0.8 * absf(sin(ph3))), ph3,
					{"colour": Color(0.135, 0.205, 0.125), "variant": ph3},
					0.95 + 0.60 * absf(cos(ph3)))

	# The sheer sections get a talus cone piled against the foot instead of a
	# ledge. Nothing else breaks a six-metre unbroken vertical box, and a sheer
	# face is exactly where you cannot put a ledge without ruining the dive.
	#
	# The first attempt here was big flat rotated boxes standing against the
	# rock. Rendered, they were unmistakably grey CARDS propped up on the
	# beach — a box has one silhouette and it is a box, whatever you rotate it
	# to. Stacked boulder models have a broken outline and cost the same.
	for i in 10:
		var ph := float(i) * 1.93
		var seg: Array = FACE_SEGMENTS[2] if i < 5 else FACE_SEGMENTS[7]
		var x0: float = seg[0]
		var x1: float = seg[1]
		var t := (float(i % 5) + 0.5) / 5.0
		var x := lerpf(x0 + 1.6, x1 - 1.6, t) + 0.9 * sin(ph * 3.1)
		var scl := 1.5 + 1.3 * absf(sin(ph * 1.7))
		_model_at(&"rock", Vector3(x, SHORE_Y - 0.35 * scl, SHORE_Z - 0.9 * scl), ph,
			{"colour": C_ROCK.lightened(0.06), "variant": ph}, scl)
		if i % 2 == 0:
			_model_at(&"rock", Vector3(x + 1.1 * cos(ph), SHORE_Y + 0.55 * scl,
				SHORE_Z + 0.1), ph * 2.3,
				{"colour": C_ROCK.lightened(0.03), "variant": ph + 7.0}, scl * 0.72)

	# Talus at the foot of the whole face: the rubble that came off it. Sits on
	# the terrace, so it is also the thing that stops the terrace being a
	# featureless eighty-metre pavement.
	for i in 14:
		var ph := float(i) * 1.61
		var x := -38.0 + fmod(float(i) * 21.3, 76.0)
		_model_at(&"rock", Vector3(x, SHORE_Y - 0.55 - 0.25 * absf(sin(ph)),
			SHORE_Z - 0.45 - 1.3 * absf(sin(ph * 1.7))), ph * 2.0,
			{"colour": C_ROCK.lightened(0.04), "variant": ph}, 0.70 + 0.80 * absf(cos(ph)))
	# And a handful standing out of the shallows, which is what tells the
	# player from the air that the water there is ankle deep.
	for i in 9:
		var ph := float(i) * 2.39
		_model_at(&"rock", Vector3(-34.0 + fmod(float(i) * 17.3, 70.0), BED_Y,
			-7.6 - 2.4 * absf(sin(ph))), ph,
			{"colour": C_ROCK.lightened(0.02), "variant": ph + 4.0},
			0.75 + 0.45 * absf(sin(ph * 1.3)))

	# Scrub and loose stone across the plateau, so the shelf top has a texture
	# in silhouette as well as in albedo.
	for i in 18:
		var ph := float(i) * 2.07
		var x := -37.0 + fmod(float(i) * 9.7, 74.0)
		var z := FACE_Z + 1.5 + fmod(float(i) * 11.3, 32.0)
		# Keep out of the built half of the shelf.
		if x > -14.0 and x < 4.0 and z > 8.0 and z < 30.0:
			continue
		if i % 3 == 0:
			_model_at(&"rock", Vector3(x, PLATEAU_Y - 0.42, z), ph,
				{"colour": C_ROCK.lightened(0.07), "variant": ph},
				0.85 + 0.90 * absf(sin(ph)))
		else:
			_model_at(&"scrub", Vector3(x, PLATEAU_Y - 0.04, z), ph,
				{"colour": Color(0.135, 0.205, 0.125), "variant": ph},
				1.0 + 0.7 * absf(cos(ph * 1.4)))


# ══════════════════════════════════════════════════════════════ STAIRCASE
#
# The zigzag down the face at x ~ +12. Two flights and a landing, both under
# 33 degrees, so a bird with no stamina left can always walk home. The steps
# themselves are decals: the collider is one smooth ramp per flight, because a
# CharacterBody3D with a horizontal capsule catches on stacked boxes and the
# resulting stutter reads as the level being broken.

func _stairs() -> void:
	var wood := Color(0.40, 0.33, 0.25)
	var rail := Color(0.46, 0.39, 0.30)

	# ── upper flight: from the plateau lip, heading -Z ──────────────────
	var ua := Vector3(12.0, PLATEAU_Y, FACE_Z - 0.2)
	var ub := Vector3(12.0, LEDGE_Y[1] + 0.10, SHORE_Z + 1.6)
	_flight(ua, ub, 1.9, wood, rail, 12)

	# ── the landing ─────────────────────────────────────────────────────
	_static_tex(Vector3(12.0, ub.y - 0.09, ub.z - 0.85), Vector3(2.4, 0.18, 2.0),
		&"wood_bark", 2.0, wood)
	for sx in [-1.0, 1.0]:
		var xs: float = sx
		_post(Vector3(12.0 + xs * 1.1, ub.y - 0.18, ub.z - 1.7), 1.0, rail)

	# ── lower flight: turns and heads -X to the shore terrace ───────────
	var la := Vector3(11.1, ub.y, ub.z - 1.7)
	var lb := Vector3(5.4, SHORE_Y + 0.10, ub.z - 1.7)
	_flight(la, lb, 1.7, wood, rail, 10)

	# Two solar path lamps on the rail — the only reason the stairs are
	# findable from the water, and the reason a player at the bottom of the
	# zone has somewhere obvious to aim.
	_lamp(Vector3(12.0, PLATEAU_Y + 1.0, FACE_Z + 0.1), Color(1.00, 0.82, 0.52), 1.5, 7.0)
	_lamp(Vector3(11.4, ub.y + 0.9, ub.z - 1.0), Color(1.00, 0.82, 0.52), 1.4, 6.5)
	for p in [Vector3(12.0, PLATEAU_Y, FACE_Z + 0.1), Vector3(11.4, ub.y - 0.1, ub.z - 1.0)]:
		var lp: Vector3 = p
		_model_at(&"dock_light", lp, 0.0,
			{"colour": Color(0.34, 0.30, 0.26), "glow_colour": Color(1.0, 0.86, 0.58)},
			0.42)


## One straight run of stairs between two points, as a ramp collider with step
## decals and a handrail on top of it.
func _flight(a: Vector3, b: Vector3, width: float, wood: Color, rail: Color,
		steps: int) -> void:
	var d := b - a
	var flat := Vector2(d.x, d.z).length()
	var pitch := atan2(-d.y, flat)
	var yaw := atan2(d.x, d.z)
	var mid := (a + b) * 0.5
	var length := Vector3(d.x, d.y, d.z).length()

	# The ramp. Rotated about its own local X after the yaw, which is why this
	# builds the basis by hand instead of going through _ramp_between().
	var sb := _static_box(mid + Vector3(0, -0.12, 0), Vector3(width, 0.30, length),
		wood.darkened(0.3))
	sb.basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
	_hide_meshes(sb)

	# Step decals: tread and riser per step, walked over rather than onto.
	for i in steps:
		var t := (float(i) + 0.5) / float(steps)
		var p := a.lerp(b, t)
		var rise := absf(d.y) / float(steps)
		var run := flat / float(steps)
		_decal_box(p + Vector3(0, rise * 0.5 + 0.03, 0), Vector3(width, 0.07, run * 0.92),
			wood.lightened(0.06 * sin(float(i) * 2.2)), yaw)
		_decal_box(p + Vector3(0, 0.02, 0) - Vector3(d.x, 0, d.z).normalized() * run * 0.44,
			Vector3(width, rise, 0.06), wood.darkened(0.28), yaw)

	# Stringers and a handrail down one side, leaning where a cottage stair
	# always leans.
	var side := Vector3(cos(yaw), 0, -sin(yaw)) * (width * 0.5 + 0.04)
	for sgn in [-1.0, 1.0]:
		var s: float = sgn
		_decal_box((a + b) * 0.5 + side * s + Vector3(0, -0.22, 0),
			Vector3(0.09, 0.30, length), wood.darkened(0.34), yaw).rotation = \
			Vector3(pitch, yaw, 0.0)
	var posts := maxi(3, steps / 3)
	for i in range(posts + 1):
		var t2 := float(i) / float(posts)
		var p2 := a.lerp(b, t2)
		_post(p2 + side, 0.95, rail)
	var rail_a := a + side + Vector3(0, 0.95, 0)
	var rail_b := b + side + Vector3(0, 0.95, 0)
	var rm := _decal_box((rail_a + rail_b) * 0.5, Vector3(0.07, 0.07, length), rail, yaw)
	rm.rotation = Vector3(pitch, yaw, 0.0)


func _post(base: Vector3, h: float, col: Color) -> void:
	_decal_box(base + Vector3(0, h * 0.5, 0), Vector3(0.08, h, 0.08), col.darkened(0.10))


# ══════════════════════════════════════════════════════════════════ DOCK

func _dock() -> void:
	var dx := -6.0
	var deck_y := 0.90
	var z_from := WATER_Z + 0.4
	var z_to := -17.5
	var sections := 4
	var seg := (z_from - z_to) / float(sections)

	# One collider per section, deck-thickness only. The cribs are model, not
	# physics: a goose that catches on a dock post at speed is a goose that
	# stopped being funny.
	for i in sections:
		var z := z_from - seg * (float(i) + 0.5)
		var sb := _static_box(Vector3(dx, deck_y - 0.10, z), Vector3(3.2, 0.20, seg),
			Color(0.42, 0.40, 0.37))
		_hide_meshes(sb)
		_model_at(&"dock_section", Vector3(dx, deck_y - 1.90, z), 0.0,
			{"colour": Color(0.46, 0.45, 0.42), "size": Vector3(3.2, 2.10, seg)})

	# The ramp from the terrace onto the deck, so you can walk out without
	# flapping. Small, but it is the difference between the dock being a place
	# and the dock being scenery.
	var dock_ramp := _ramp_between(-4.90, deck_y, -2.60, SHORE_Y, 2.8, 0.30,
		&"wood_bark", 1.6, Color(0.42, 0.38, 0.32))
	dock_ramp.position.x = dx

	# The light at the end. Brightest thing at water level and the zone's
	# single most important navigation cue: from the top of the cliff it is
	# the only thing that tells you where the dock is.
	_model_at(&"dock_light", Vector3(dx + 1.35, deck_y, z_to + 0.6), 0.0,
		{"colour": Color(0.40, 0.38, 0.34)})
	_dock_light_node = _lamp(Vector3(dx + 1.45, deck_y + 2.25, z_to + 0.6),
		Color(0.86, 0.92, 1.00), 3.4, 17.0)

	# Two adirondack chairs on the dock, facing out, because that is what a
	# dock is for. And a paddle somebody left lying across it.
	_prop(Vector3(dx - 0.8, deck_y + 0.55, z_to + 2.2), Vector3(0.92, 1.06, 1.10),
		Color(0.22, 0.46, 0.58), 7.0, 45, "MUSKOKA CHAIR")
	_prop(Vector3(dx + 0.6, deck_y + 0.55, z_to + 3.4), Vector3(0.92, 1.06, 1.10),
		Color(0.74, 0.62, 0.20), 7.0, 45, "MUSKOKA CHAIR")
	_prop(Vector3(dx, deck_y + 0.15, z_to + 5.6), Vector3(0.26, 0.07, 1.65),
		Color(0.78, 0.64, 0.40), 1.2, 20, "PADDLE")


# ══════════════════════════════════════════════════════════════ BOATHOUSE

func _boathouse() -> void:
	var bx := -20.0
	var bz := -10.5
	# Collision: the deck slab, the roof plateau you can land on, and the two
	# side walls. Nothing else — the slip mouth stays open so the goose can
	# swim in under the roof, which is the best hiding place in the zone.
	_hide_meshes(_static_box(Vector3(bx, 0.16, bz), Vector3(3.0, 0.32, 4.0),
		Color(0.30, 0.28, 0.24)))
	for sx in [-1.0, 1.0]:
		var xs: float = sx
		_hide_meshes(_static_box(Vector3(bx + xs * 3.0, 1.6, bz), Vector3(0.2, 2.9, 4.2),
			Color(0.30, 0.28, 0.24)))
	# The landable roof: a flat plateau under the pitched model, exactly like
	# suburbia's roofs. 3.2 x 8.4 of dead-flat cottage-country real estate at
	# y = 4.3, reachable from the water in three flaps or from the cliff in one
	# very committed dive.
	var roof := _static_box(Vector3(bx, 4.10, bz), Vector3(6.4, 0.9, 8.4),
		Color(0.17, 0.24, 0.22))
	_hide_meshes(roof)

	_model_at(&"boathouse", Vector3(bx, 0.0, bz), 0.0, {
		"w": 6.0, "d": 8.0, "wall_h": 2.6, "roof_h": 1.8,
		"colour": Color(0.26, 0.24, 0.21), "trim_colour": Color(0.15, 0.23, 0.21),
	})
	_lamp(Vector3(bx, 2.35, bz - 4.3), Color(1.00, 0.80, 0.46), 2.4, 13.0)

	# A bonus for landing on it. Same shape as suburbia's roof trigger, and it
	# feeds the zone's `on_the_roof` primary.
	var bonus := Area3D.new()
	add_child(bonus)
	bonus.global_position = Vector3(bx, 4.9, bz)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(5.6, 1.2, 7.6)
	cs.shape = bs
	bonus.add_child(cs)
	bonus.monitoring = true
	bonus.monitorable = false
	bonus.body_entered.connect(_on_boathouse_roof)


var _roof_bonus_given := false

func _on_boathouse_roof(body: Node3D) -> void:
	if body is Goose and not _roof_bonus_given:
		_roof_bonus_given = true
		Game.score(160, "ON THE ROOF", body.global_position)
		if _sfx != null:
			_sfx.play_at(&"score_blip_hi", body, 0.0, 1.0)


# ══════════════════════════════════════════════════════════════ THE COTTAGE

func _the_cottage() -> void:
	var cx := -6.0
	var cz := 22.0
	var w := 15.0
	var d := 10.0
	var wall_h := 3.1
	var roof_h := 2.6
	var porch_d := 3.0

	# Body collider — same convention as suburbia's houses.
	var body := _static_box(Vector3(cx, PLATEAU_Y + wall_h * 0.5, cz),
		Vector3(w, wall_h, d), Color(0.32, 0.22, 0.16))
	_model_body(body, &"cottage", -wall_h * 0.5, {
		"w": w, "d": d, "wall_h": wall_h, "roof_h": roof_h, "porch_d": porch_d,
		"colour": Color(0.27, 0.185, 0.135),
		"trim_colour": Color(0.085, 0.155, 0.135),
		"glow_colour": Color(1.00, 0.78, 0.42),
	})
	# Roof plateau, landable, invisible — the same flat approximation of a
	# pitched volume suburbia uses.
	_hide_meshes(_static_box(Vector3(cx, PLATEAU_Y + wall_h + roof_h * 0.42, cz),
		Vector3(w * 0.86, roof_h * 0.6, d * 0.86), Color(0.15, 0.26, 0.22)))
	# Porch floor and its roof, both walkable.
	_hide_meshes(_static_box(Vector3(cx, PLATEAU_Y + 0.18, cz - d * 0.5 - porch_d * 0.5),
		Vector3(w * 0.88, 0.36, porch_d), Color(0.30, 0.24, 0.18)))

	# ── the deck ────────────────────────────────────────────────────────
	# Out in front of the porch, cantilevered toward the drop. It is the
	# diving board of the zone: walk out, keep walking, and the cliff is
	# eleven metres further on with nothing in between.
	var deck_z := cz - d * 0.5 - porch_d - 2.4
	var deck := _static_box(Vector3(cx, PLATEAU_Y + 0.20, deck_z),
		Vector3(w * 0.72, 0.40, 4.6), Color(0.36, 0.29, 0.22))
	_hide_meshes(deck)
	_flat_tiles(Vector3(cx, PLATEAU_Y + 0.40, deck_z), Vector3(w * 0.72, 0.10, 4.6),
		3, 1, &"wood_bark", Color(0.56, 0.45, 0.33), 3.0)
	# Two more chairs, out on the deck facing the water. They exist so that a
	# player who never leaves the top of the zone can still get most of the way
	# through the chair objective, and so the deck is somewhere rather than a
	# platform.
	for i in 2:
		var ch := _prop(Vector3(cx - 2.4 + float(i) * 2.6, PLATEAU_Y + 0.95, deck_z - 1.3),
			Vector3(0.92, 1.06, 1.10), Color(0.30, 0.44, 0.52) if i == 0 \
			else Color(0.70, 0.52, 0.22), 7.0, 45, "MUSKOKA CHAIR")
		ch.rotation.y = PI
		ch.break_force = 8.0
	# Railing: posts and a top rail, on three sides.
	var dhw := w * 0.36
	for i in 11:
		var x := cx - dhw + (2.0 * dhw) * float(i) / 10.0
		_post(Vector3(x, PLATEAU_Y + 0.44, deck_z - 2.3), 0.95, Color(0.42, 0.34, 0.26))
	for sx in [-1.0, 1.0]:
		var xs: float = sx
		for i in 5:
			var z := deck_z - 2.3 + 4.6 * float(i) / 4.0
			_post(Vector3(cx + xs * dhw, PLATEAU_Y + 0.44, z), 0.95, Color(0.42, 0.34, 0.26))
	_decal_box(Vector3(cx, PLATEAU_Y + 1.42, deck_z - 2.3), Vector3(dhw * 2.0, 0.08, 0.08),
		Color(0.46, 0.38, 0.29))

	# ── window spill ────────────────────────────────────────────────────
	# The model paints glowing rectangles; these are the lights those windows
	# actually throw. Three, not eight: one per face that matters, positioned
	# just outside the wall so the spill lands on the deck and the duff.
	_lamp(Vector3(cx, PLATEAU_Y + 1.9, cz - d * 0.5 - porch_d * 0.55),
		Color(1.00, 0.79, 0.45), 2.6, 13.0)
	_lamp(Vector3(cx - w * 0.30, PLATEAU_Y + 2.0, cz - d * 0.5 - 0.6),
		Color(1.00, 0.74, 0.40), 1.9, 9.5)
	_lamp(Vector3(cx + w * 0.20, PLATEAU_Y + 2.0, cz + d * 0.5 + 0.6),
		Color(1.00, 0.76, 0.42), 1.5, 8.5)

	# ── the bug zapper ──────────────────────────────────────────────────
	# On a hook off the porch corner. The only cold artificial light up here,
	# which is what makes the fire and the windows read as warm.
	var zx := cx + w * 0.44
	var zz := cz - d * 0.5 - porch_d - 0.4
	_post(Vector3(zx, PLATEAU_Y, zz), 2.5, Color(0.34, 0.29, 0.23))
	_decal_box(Vector3(zx - 0.30, PLATEAU_Y + 2.46, zz), Vector3(0.62, 0.07, 0.07),
		Color(0.34, 0.29, 0.23))
	_model_at(&"bug_zapper", Vector3(zx - 0.58, PLATEAU_Y + 1.48, zz))
	_zap_light = _lamp(Vector3(zx - 0.58, PLATEAU_Y + 1.95, zz),
		Color(0.58, 0.40, 1.00), 2.4, 10.0)

	# The OTHER dog. Every cottage has a second one that has not stood up since
	# Friday, and this is where the zone's own sleeping-retriever model lives
	# now that Molly's pickup carries her own body. Collider is a real box, so
	# you can absolutely trip over her.
	var dog := _static_box(Vector3(cx + w * 0.30, PLATEAU_Y + 0.33, cz - d * 0.5 - 1.4),
		Vector3(0.62, 0.66, 1.55), Color(0.60, 0.42, 0.19), -0.5)
	_model_body(dog, &"dog", -0.33, {"colour": Color(0.60, 0.42, 0.19)})

	# A herb pot on the porch step and a couple of chairs on the deck.
	_static_box(Vector3(cx - w * 0.34, PLATEAU_Y + 0.55, cz - d * 0.5 - porch_d - 0.5),
		Vector3(0.55, 0.5, 0.55), Color(0.42, 0.30, 0.24))
	for i in 4:
		_decal_box(Vector3(cx - w * 0.34 - 0.18 + float(i) * 0.12,
			PLATEAU_Y + 1.05, cz - d * 0.5 - porch_d - 0.5),
			Vector3(0.10, 0.42, 0.10), Color(0.32, 0.52, 0.28))


# ══════════════════════════════════════════════════════════════ THE FIRE

func _campfire() -> void:
	var fx := 7.0
	var fz := 9.5
	_model_at(&"fire_pit", Vector3(fx, PLATEAU_Y, fz), 0.3)

	# TWO lights, deliberately. The big one is the reach — it has to touch the
	# cottage, the chairs and the lip of the cliff so the whole social half of
	# the plateau is legible from anywhere on it. The small deep-orange one
	# sits inside the ring and only lights the stones and whoever is closest,
	# which is what gives the fire a hot core instead of a uniform glow.
	_fire_lights.append(_lamp(Vector3(fx, PLATEAU_Y + 1.15, fz),
		Color(1.00, 0.62, 0.26), 5.4, 22.0))
	_fire_lights.append(_lamp(Vector3(fx, PLATEAU_Y + 0.35, fz),
		Color(1.00, 0.36, 0.10), 2.6, 7.5))

	# Six Muskoka chairs in a ring, faded to six different colours, all facing
	# in. Light, high-value, and they cartwheel beautifully.
	var chair_cols := [
		Color(0.68, 0.24, 0.20), Color(0.22, 0.42, 0.56), Color(0.66, 0.58, 0.20),
		Color(0.26, 0.46, 0.28), Color(0.60, 0.44, 0.62), Color(0.72, 0.46, 0.20),
	]
	for i in 6:
		var a := TAU * float(i) / 6.0 + 0.35
		var r := 3.15 + 0.25 * sin(float(i) * 2.3)
		var c := _prop(Vector3(fx + cos(a) * r, PLATEAU_Y + 0.55, fz + sin(a) * r),
			Vector3(0.92, 1.06, 1.10), chair_cols[i], 7.0, 45, "MUSKOKA CHAIR")
		c.rotation.y = -a + PI * 0.5
		c.break_force = 8.0

	# Two coolers and the firewood, where they'd actually be.
	_prop(Vector3(fx - 3.9, PLATEAU_Y + 0.27, fz + 2.6), Vector3(0.80, 0.54, 0.48),
		Color(0.14, 0.32, 0.60), 22.0, 55, "COOLER")
	_prop(Vector3(fx - 3.2, PLATEAU_Y + 0.27, fz + 3.4), Vector3(0.80, 0.54, 0.48),
		Color(0.72, 0.20, 0.18), 22.0, 55, "COOLER")
	_model_at(&"firewood", Vector3(fx + 5.6, PLATEAU_Y, fz + 1.4), 0.5,
		{"variant": 1.0})
	# Loose splits by the ring, which are the cheapest chaos prop in the zone.
	for i in 7:
		var a := 1.1 + float(i) * 0.9
		_prop(Vector3(fx + cos(a) * (4.9 + 0.35 * float(i % 3)), PLATEAU_Y + 0.14,
			fz + sin(a) * (4.6 + 0.4 * float(i % 2))),
			Vector3(0.26, 0.26, 0.74), Color(0.40, 0.31, 0.23), 3.0, 22, "FIREWOOD",
			{"variant": float(i)})

	# The people around it. This is the one place in the zone with a crowd,
	# and it is directly uphill of a six-metre cliff.
	var shirts := [Color(0.74, 0.26, 0.22), Color(0.24, 0.34, 0.60), Color(0.88, 0.84, 0.44),
		Color(0.28, 0.50, 0.34)]
	for i in 4:
		var a := TAU * float(i) / 4.0 + 1.1
		var n := NpcHuman.new()
		add_child(n)
		n.setup(shirts[i])
		n.global_position = Vector3(fx + cos(a) * 4.2, PLATEAU_Y + 0.2, fz + sin(a) * 4.2)


# ══════════════════════════════════════════════════════════════════ YARD

func _yard() -> void:
	# ── the barbecue, off the porch ─────────────────────────────────────
	var bq := _prop(Vector3(-16.5, PLATEAU_Y + 0.52, 16.5), Vector3(1.0, 1.05, 0.55),
		Color(0.17, 0.17, 0.19), 16.0, 50, "BBQ")
	bq.break_force = 11.0
	bq.rotation.y = 0.3
	for i in 3:
		_prop(Vector3(-15.2 + float(i) * 0.3, PLATEAU_Y + 0.65, 16.0),
			Vector3(0.32, 0.13, 0.13), Color(0.68, 0.32, 0.24), 0.3, 12, "SAUSAGE")

	# ── the picnic table ────────────────────────────────────────────────
	_prop(Vector3(-19.0, PLATEAU_Y + 0.40, 9.0), Vector3(2.00, 0.80, 1.80),
		Color(0.44, 0.34, 0.24), 26.0, 60, "PICNIC TABLE").rotation.y = 0.15
	for i in 2:
		_prop(Vector3(-21.4 + float(i) * 4.6, PLATEAU_Y + 0.45, 9.0),
			Vector3(0.60, 0.90, 0.60), Color(0.40, 0.30, 0.22), 6.0, 28, "PATIO CHAIR")

	# ── bins, up on the shelf where the raccoons are ────────────────────
	for i in 2:
		_prop(Vector3(6.0 + float(i) * 1.4, PLATEAU_Y + 0.60, 18.0),
			Vector3(1.0, 1.2, 0.8), Color(0.16, 0.34, 0.56), 8.0, 40, "RECYCLING")
	for i in 3:
		_prop(Vector3(8.6 + float(i) * 0.7, PLATEAU_Y + 0.28, 19.2),
			Vector3(0.48, 0.55, 0.50), Color(0.13, 0.13, 0.15), 3.0, 18, "GARBAGE",
			{"variant": float(i) * 1.3})

	# ── the driveway, at the back ───────────────────────────────────────
	_flat_tiles(Vector3(17.0, PLATEAU_Y + 0.02, 28.0), Vector3(9.0, 0.06, 22.0),
		2, 3, &"dirt", Color(0.26, 0.21, 0.16), 5.0)
	var v := _prop(Vector3(17.0, PLATEAU_Y + 1.0, 24.0), Vector3(2.1, 1.9, 4.6),
		Color(0.20, 0.28, 0.44), 900.0, 120, "VEHICLE")
	v.breakable = false
	v.break_force = 999.0
	v.rotation.y = 0.05
	# One yard light on a pole over the parking spot, cool and unloved.
	_post(Vector3(21.5, PLATEAU_Y, 26.0), 4.4, Color(0.30, 0.29, 0.28))
	_model_at(&"dock_light", Vector3(21.5, PLATEAU_Y + 2.4, 26.0), 0.0,
		{"colour": Color(0.32, 0.31, 0.30), "glow_colour": Color(0.86, 0.92, 1.0)}, 0.9)
	_lamp(Vector3(21.5, PLATEAU_Y + 4.4, 26.0), Color(0.80, 0.88, 1.00), 1.8, 12.0)

	# ── canoe rack and paddles, at the top of the stairs ────────────────
	for sx in [-1.0, 1.0]:
		var xs: float = sx
		_post(Vector3(14.0 + xs * 1.6, PLATEAU_Y, 7.5), 1.3, Color(0.38, 0.31, 0.24))
	_decal_box(Vector3(14.0, PLATEAU_Y + 1.32, 7.5), Vector3(3.4, 0.10, 0.10),
		Color(0.40, 0.33, 0.26))
	for i in 2:
		_prop(Vector3(13.4 + float(i) * 1.1, PLATEAU_Y + 0.20, 6.6),
			Vector3(0.26, 0.07, 1.65), Color(0.74, 0.60, 0.38), 1.2, 20, "PADDLE")


# ══════════════════════════════════════════════════════════════════ FOREST

func _forest() -> void:
	# White pines across the back of the shelf and along the shoulders. Sparse
	# on purpose: a solid treeline at night is one black mass, and the point
	# of the pines here is the gaps the moon comes through.
	var spots := [
		Vector3(-30.0, 0, 15.0), Vector3(-24.0, 0, 24.0), Vector3(-33.0, 0, 30.0),
		Vector3(-16.0, 0, 31.0), Vector3(-6.0, 0, 34.0), Vector3(4.0, 0, 30.0),
		Vector3(10.0, 0, 35.0), Vector3(24.0, 0, 33.0), Vector3(31.0, 0, 22.0),
		Vector3(29.0, 0, 12.0), Vector3(22.0, 0, 7.0), Vector3(-21.0, 0, 7.5),
		Vector3(-31.0, 0, 6.0), Vector3(15.0, 0, 16.0),
	]
	for i in spots.size():
		var s: Vector3 = spots[i]
		var scale_v := 0.72 + 0.30 * absf(sin(float(i) * 1.9))
		# Trunk collider only, at the model's own trunk radius. The canopy is
		# eleven metres up and nothing should ever collide with it.
		var trunk := _static_tex(Vector3(s.x, PLATEAU_Y + 2.4 * scale_v, s.z),
			Vector3(0.62 * scale_v, 4.8 * scale_v, 0.62 * scale_v),
			&"wood_bark", 2.0, Color(0.24, 0.19, 0.15))
		_hide_meshes(trunk)
		_model_at(&"pine", Vector3(s.x, PLATEAU_Y, s.z), float(i) * 0.8, {
			"colour": Color(0.24, 0.19, 0.15),
			"leaf_colour": Color(0.095, 0.185, 0.145),
			"variant": float(i) * 1.31,
		}, scale_v)

	# Two leaning off the lip of the shelf, roots in the granite. These are the
	# ones you fly between on the way down.
	for i in 2:
		_model_at(&"pine", Vector3(-26.0 + float(i) * 44.0, PLATEAU_Y - 0.3, FACE_Z + 1.2),
			1.2 + float(i), {
			"colour": Color(0.24, 0.19, 0.15),
			"leaf_colour": Color(0.085, 0.17, 0.135),
			"variant": 4.4 + float(i) * 2.2,
		}, 0.82)


# ══════════════════════════════════════════════════════════════════ BOATS

func _boats() -> void:
	# Three hulls pulled up on the terrace, the way they actually sit — upside
	# down, side by side, one of them half in the water.
	var hulls := [
		[-1.0, -3.2, 0.25, Color(0.72, 0.50, 0.28)],
		[1.8, -3.6, 0.05, Color(0.60, 0.16, 0.15)],
		[4.6, -3.0, -0.18, Color(0.20, 0.38, 0.30)],
	]
	for i in range(hulls.size()):
		var row: Array = hulls[i]
		var x: float = row[0]
		var z: float = row[1]
		var yaw: float = row[2]
		var col: Color = row[3]
		var c := _prop(Vector3(x, SHORE_Y + 0.33, z), Vector3(0.94, 0.66, 5.00),
			col, 55.0, 90, "CANOE")
		c.rotation.y = yaw + PI * 0.5
		c.break_force = 26.0

	# The kayak, on the sand by the ramp.
	_prop(Vector3(9.5, SHORE_Y + 0.23, -3.4), Vector3(0.70, 0.46, 3.90),
		Color(0.88, 0.60, 0.14), 32.0, 75, "KAYAK").rotation.y = 0.4

	# One canoe tied alongside the dock, ACTUALLY FLOATING — not frozen and
	# animated, which is what the first pass did. It turns out no faking is
	# needed: the hull collider is 0.66 deep and the lake bed is 0.30 below the
	# surface, so a live rigid body dropped here settles with its centre 0.03
	# above the waterline. That is a canoe floating at its designed draught, by
	# accident, and it is worth far more than a sine wave because you can also
	# shove it, tip it, and score it.
	var tied := _prop(Vector3(-8.5, WATER_Y + 0.05, -13.0), Vector3(0.94, 0.66, 5.00),
		Color(0.24, 0.44, 0.58), 55.0, 90, "CANOE")
	tied.rotation.y = 0.03

	# Paddles and a life jacket in the pile.
	for i in 2:
		_prop(Vector3(6.4 + float(i) * 0.8, SHORE_Y + 0.20, -1.9),
			Vector3(0.26, 0.07, 1.65), Color(0.76, 0.62, 0.38), 1.2, 20, "PADDLE")
	_prop(Vector3(7.8, SHORE_Y + 0.20, -3.9), Vector3(0.5, 0.3, 0.4),
		Color(0.92, 0.44, 0.10), 1.0, 18, "LIFE JACKET")


# ══════════════════════════════════════════════════════════════ WILDLIFE

func _wildlife() -> void:
	# ── loons ───────────────────────────────────────────────────────────
	# Out on the water, well away from the dock, because that is where they
	# are. They bob and they call, and the call is the single strongest thing
	# in this zone at telling the player where they are without a HUD.
	for p in [Vector3(-15.0, WATER_Y + 0.05, -25.0), Vector3(8.0, WATER_Y + 0.05, -30.0),
			Vector3(-27.0, WATER_Y + 0.05, -18.0)]:
		var lp: Vector3 = p
		var l := _model_at(&"loon", lp, randf_range(0, TAU), {"variant": lp.x})
		_loons.append(l)

	# ── the toad ────────────────────────────────────────────────────────
	# UNDER the dock, on a wet rock, in the dark, at the exact edge of the
	# dock light's reach. Finding it is meant to be a moment, so:
	#   * it is not in the open — you have to go under or swim in,
	#   * its eyes are on the glow shell, so at fifteen metres it is two
	#     little coins and nothing else,
	#   * it croaks on a timer once you are close, which is how you actually
	#     find a toad at night, and
	#   * a proximity trigger says one line the first time.
	# It is worth this much fuss because the codex fact — the US National Park
	# Service formally asking people to stop licking toads — is the best true
	# thing in the entire game.
	var tp := Vector3(-10.6, SHORE_Y, -8.4)
	# The rock is REAL — a static body standing out of the lake, not a decal on
	# the water. The first audit had the toad hovering a metre over the beach
	# ramp with nothing under it, which is a very different animal.
	_hide_meshes(_static_box(Vector3(tp.x, 0.0, tp.z), Vector3(1.7, 1.1, 1.5),
		Color(0.32, 0.33, 0.32)))
	# Anchored to the COLLIDER's floor (-0.55 local), not to the lake bed: the
	# rock stands proud of the water and the bed is somewhere underneath it.
	# Scale so the model's 1.05 m height spans exactly the collider's -0.55 to
	# +0.55, or the toad sits on thin air over a rock that stops short.
	var rock_node := _model_at(&"rock", Vector3(tp.x, -0.55, tp.z), 0.7,
		{"colour": Color(0.20, 0.22, 0.20), "variant": 9.0}, 1.10 / 1.05)
	# NO second toad model here. pickup_models.gd already builds a toad for
	# toad_slime, and the render showed the two of them stacked on the same
	# rock like a Russian doll. The pickup IS the toad; this file's job is to
	# give it somewhere to be and a reason to be found.
	#
	# The model does get used, twice, as ambience further along the shore —
	# small ones, in the dark, whose only visible feature is a pair of glowing
	# eyes. Meeting one of those and then finding the big one on the rock is
	# the actual "moment"; a single glowing lump on its own is a pickup.
	_toad_node = rock_node
	for i in 2:
		var ap := Vector3(4.5 + float(i) * 12.5, SHORE_Y, -2.4 - float(i) * 0.7)
		_model_at(&"toad", ap, 1.1 + float(i) * 2.0, {}, 0.85)
	# Its own tiny light, so the wet rock under it glows faintly green and the
	# player has something to be curious about from the dock.
	_lamp(tp + Vector3(0, 0.5, 0), Color(0.36, 0.78, 0.50), 1.1, 5.0)

	var trig := Area3D.new()
	add_child(trig)
	trig.global_position = tp
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 7.0
	cs.shape = sh
	trig.add_child(cs)
	trig.monitoring = true
	trig.monitorable = false
	trig.body_entered.connect(_on_toad_near)


func _on_toad_near(body: Node3D) -> void:
	if not (body is Goose) or _toad_seen:
		return
	_toad_seen = true
	Juice.floating_text(_toad_node.global_position + Vector3(0, 0.9, 0),
		"something moved", Color(0.52, 0.92, 0.64))
	if _sfx != null:
		_sfx.play_at(&"goose_grumble", _toad_node, -10.0, 0.44)


# ══════════════════════════════════════════════════════════════ SUBSTANCES
#
# Placed where they would plausibly be at a cottage, and — because this is the
# dark zone — deliberately strung along the routes the player has to take.
# Every pickup carries its own OmniLight3D, so the source layout IS the
# lighting layout for the parts of the zone that have no lamps: the terrace,
# the ledges and the far end of the dock are all navigable at night largely
# because there is something glowing on them.

func _sources() -> void:
	var fx := 7.0
	var fz := 9.5

	# ── the two-four ────────────────────────────────────────────────────
	# Beside the chairs, lid torn open. The single most Canadian object in the
	# game and it is a full-strength ethanol source.
	_model_at(&"two_four", Vector3(fx - 1.0, PLATEAU_Y, fz - 4.6), 0.4)
	_source(Vector3(fx - 1.0, PLATEAU_Y + 0.65, fz - 4.6), Subs.get_substance(&"berries"), 0.52)
	# A second one down on the dock, because somebody always carries one down.
	_model_at(&"two_four", Vector3(-5.2, 0.90, -15.0), 1.1)
	_source(Vector3(-5.2, 1.55, -15.0), Subs.get_substance(&"berries"), 0.52)

	# ── the toad ────────────────────────────────────────────────────────
	# 0.25 rather than 0.55: pickup_models' toad is authored large and its
	# model sits 0.15 above the Area3D's origin, so the obvious "put it on top
	# of the rock" number leaves it visibly hovering.
	_source(Vector3(-10.6, SHORE_Y + 0.25, -8.4), Subs.get_substance(&"toad_slime"), 0.40)

	# ── grass ───────────────────────────────────────────────────────────
	# Infinite, and at a cottage it is genuinely everywhere. One on the mown
	# patch, one on the terrace, one on the middle granite ledge — that last
	# one is deliberate: it puts a light halfway up the face so the climb has
	# a waypoint.
	var grass := Subs.get_substance(&"grass")
	# Three, not four. Every SubstancePickup carries an OmniLight3D, and GL
	# Compatibility renders at most 32 lights in a frame by default; this zone
	# runs 12 fixed lamps, so the pickup budget is 20 and a fourth patch of
	# grass is the cheapest thing to spend it on. See ZONE3_NOTES.md.
	for p in [Vector3(-13.0, PLATEAU_Y + 0.45, 18.5), Vector3(15.5, SHORE_Y + 0.45, -3.0),
			Vector3(-4.0, 3.9, 0.7)]:
		var gp: Vector3 = p
		_source(gp, grass, 0.42, true)

	# ── darts, on the dock ──────────────────────────────────────────────
	# Half a pack left on the rail by whoever was out here at midnight.
	_source(Vector3(-7.0, 1.15, -11.0), Subs.get_substance(&"darts"), 0.34)
	_decal_box(Vector3(-7.0, 0.94, -11.0), Vector3(0.24, 0.10, 0.16), Color(0.86, 0.14, 0.12))

	# ── whipped cream, in the cooler ────────────────────────────────────
	_source(Vector3(fx - 3.9, PLATEAU_Y + 0.75, fz + 2.6), Subs.get_substance(&"nitrous"), 0.45)

	# ── a Tim's cup on the deck rail ────────────────────────────────────
	_source(Vector3(-9.0, PLATEAU_Y + 1.60, 9.4), Subs.get_substance(&"double_double"), 0.44)

	# ── fly agaric, in the moss under the pines ─────────────────────────
	# Storybook mushroom, real deliriant, and the reason to go into the dark
	# half of the shelf where there are no lamps at all.
	var agaric := Subs.get_substance(&"fly_agaric")
	# PLATEAU_Y, not PLATEAU_Y + 0.35. `_mushroom_cluster` base-anchors every
	# stem to the y it is handed, so the lifted value hung the whole ring — and
	# its 2.6 m moss decal — a third of a metre over the plateau, whose collider
	# top is exactly PLATEAU_Y (the `plat` box at :704 is 6.0 tall centred at
	# PLATEAU_Y - 3.0). Rendered as five posts standing on nothing.
	for p in [Vector3(-27.0, PLATEAU_Y, 19.5), Vector3(6.0, PLATEAU_Y, 32.0)]:
		var mp: Vector3 = p
		# The source goes in the moss in the middle of its own ring, not at
		# goose head height above it. It used to be PLATEAU_Y + 0.70 — the lift
		# above, plus another 0.35 here — and substance_pickup.gd adds a further
		# 0.15 to the model, which the &"sway" idle leaves alone. So the ring
		# floated and the mushroom in the middle of it floated twice as far.
		_source(mp - Vector3(0, 0.15, 0), agaric, 0.42)
		_mushroom_cluster(mp)

	# ── catnip in the herb pot on the porch step ────────────────────────
	_source(Vector3(-11.1, PLATEAU_Y + 1.25, 14.3), Subs.get_substance(&"catnip"), 0.40)

	# ── cereal box on the picnic table ──────────────────────────────────
	_source(Vector3(-19.0, PLATEAU_Y + 1.05, 9.0), Subs.get_substance(&"special_k"), 0.44)

	# ── the homework nobody did all summer ──────────────────────────────
	_source(Vector3(-20.4, PLATEAU_Y + 1.05, 9.6), Subs.get_substance(&"math"), 0.42)
	_decal_box(Vector3(-20.4, PLATEAU_Y + 0.82, 9.6), Vector3(0.9, 0.02, 1.2),
		Color(0.90, 0.90, 0.86))

	# ── cough syrup in the boathouse ────────────────────────────────────
	_source(Vector3(-18.4, 0.75, -8.0), Subs.get_substance(&"robo"), 0.42)

	# ── the boat battery, leaking on the boathouse deck ─────────────────
	_source(Vector3(-21.6, 0.75, -12.4), Subs.get_substance(&"acid"), 0.44)
	_static_box(Vector3(-21.6, 0.45, -12.4), Vector3(0.9, 0.45, 0.6), Color(0.14, 0.14, 0.18))

	# ── a container of gravy that came up with the poutine ──────────────
	_source(Vector3(fx + 4.3, PLATEAU_Y + 0.45, fz + 1.4), Subs.get_substance(&"gravy"), 0.40)
	_decal_box(Vector3(fx + 4.3, PLATEAU_Y + 0.12, fz + 1.4), Vector3(0.6, 0.18, 0.6),
		Color(0.84, 0.80, 0.70))

	# ── the medicine cabinet, on the windowsill ─────────────────────────
	_source(Vector3(-2.6, PLATEAU_Y + 1.35, 14.1), Subs.get_substance(&"bars"), 0.36)
	_source(Vector3(-1.4, PLATEAU_Y + 1.35, 14.1), Subs.get_substance(&"percs"), 0.36)
	_decal_box(Vector3(-2.0, PLATEAU_Y + 1.14, 14.1), Vector3(1.9, 0.08, 0.34),
		Color(0.86, 0.84, 0.80))

	# ── Molly, the cottage dog, asleep by the fire ──────────────────────
	# NO extra dog body here. pickup_models.gd already builds a small sitting
	# retriever for `molly`, and the render showed this zone's sleeping dog
	# with that one hovering over its ribs — the same duplication the toad had.
	# The pickup IS Molly; it just needed to be sat on the ground rather than
	# floating at chest height the way the other zones left it. This used to
	# say "the other two zones" — zone_strip_mall.gd has since deleted its own
	# peach-box placeholder and dropped its source to the asphalt, so
	# zone_suburbia.gd:778 (a full `_dog_static` retriever with the pickup's
	# retriever hovering 0.64 m behind it) is the last one.
	_source(Vector3(fx - 5.6, PLATEAU_Y + 0.05, fz - 1.2), Subs.get_substance(&"molly"), 0.48)


func _mushroom_cluster(pos: Vector3) -> void:
	_decal_box(pos + Vector3(0, 0.03, 0), Vector3(2.6, 0.03, 2.6), Color(0.14, 0.20, 0.13))
	for i in 5:
		var a := TAU * float(i) / 5.0 + 0.6
		var r := 0.45 + 0.35 * float(i % 2)
		var p := pos + Vector3(cos(a) * r, 0, sin(a) * r)
		var s := 0.30 + 0.16 * float(i % 3)
		# The stem collider is the same box it always was, so the ring bumps the
		# goose exactly as before. What changed is what sits on it. This used to
		# be a `_decal_box` cap with four `_decal_box` spots on top — five red
		# slabs on white posts — standing under a `fly_agaric` source that
		# builds prop_models.gd's faceted mushroom. Same object, two shapes, one
		# metre apart, in the darkest part of the zone the design most wants you
		# to walk into. zone_suburbia.gd:994-1005 already made this swap; this
		# is the same two lines, and this file already preloads PROPS.
		#
		# s / 0.88 because the model is authored 0.88 m tall (prop_models.gd:86),
		# so the scaled mushroom stands exactly as tall as the collider it hangs
		# on; `variant` makes this a cluster of five mushrooms rather than one
		# mushroom five times.
		var sb := _static_box(p + Vector3(0, s * 0.5, 0), Vector3(s * 0.32, s, s * 0.32),
			Color(0.92, 0.90, 0.84))
		_model_body(sb, &"fly_agaric", -s * 0.5, {"variant": float(i)}, s / 0.88)


# ══════════════════════════════════════════════════════════════ POPULATION

func _props() -> void:
	# Everything not already placed by a set-piece: the loose stuff a cottage
	# accumulates, scattered where a bird flying a line across the shelf will
	# hit some of it whether it meant to or not.
	for i in 5:
		var a := float(i) * 1.7
		_prop(Vector3(-27.0 + float(i) * 2.6, PLATEAU_Y + 0.45, 13.0 + 2.2 * sin(a)),
			Vector3(0.60, 0.90, 0.60), Color(0.38, 0.29, 0.21), 6.0, 28, "PATIO CHAIR")
	for i in 3:
		_prop(Vector3(24.0 + float(i) * 2.0, PLATEAU_Y + 0.27, 8.0 + float(i)),
			Vector3(0.80, 0.54, 0.48), Color(0.60, 0.62, 0.64), 22.0, 55, "COOLER")
	# A wheelbarrow-load of firewood by the stairs.
	for i in 4:
		_prop(Vector3(15.5 + 1.2 * sin(float(i) * 2.1), PLATEAU_Y + 0.16, 10.5 + float(i) * 0.7),
			Vector3(0.26, 0.26, 0.74), Color(0.40, 0.31, 0.23), 3.0, 22, "FIREWOOD",
			{"variant": float(i) + 3.0})


func _people() -> void:
	# Four more, away from the fire: two on the dock, two wandering the shelf.
	# They are kept off the deck on purpose — an NPC that wanders off a
	# six-metre cliff and lands in the lake is funny exactly once.
	var shirts := [Color(0.88, 0.86, 0.84), Color(0.34, 0.30, 0.52),
		Color(0.90, 0.56, 0.20), Color(0.24, 0.52, 0.48)]
	var spots := [
		Vector3(-6.6, 1.10, -12.0), Vector3(-5.4, 1.10, -14.6),
		Vector3(-22.0, PLATEAU_Y + 0.2, 19.0), Vector3(13.0, PLATEAU_Y + 0.2, 21.0),
	]
	for i in spots.size():
		var n := NpcHuman.new()
		add_child(n)
		n.setup(shirts[i])
		n.global_position = spots[i]


func _cats() -> void:
	## The cottage cats. Roughly a third will ignore you entirely, which is
	## both accurate and funnier.
	var furs := [Color(0.24, 0.22, 0.21), Color(0.76, 0.60, 0.34), Color(0.90, 0.90, 0.88),
		Color(0.44, 0.40, 0.38)]
	var spots := [
		Vector3(-16.0, PLATEAU_Y + 0.2, 19.0), Vector3(4.0, PLATEAU_Y + 0.2, 24.0),
		Vector3(-24.0, PLATEAU_Y + 0.2, 12.0), Vector3(8.0, SHORE_Y + 0.2, -3.0),
	]
	for i in spots.size():
		var c := Cat.new()
		add_child(c)
		c.setup(furs[i])
		c.global_position = spots[i]


func _spawn_goose() -> void:
	goose = Goose.new()
	goose.name = "Goose"
	add_child(goose)
	# On the granite between the fire and the cliff lip, facing the water. The
	# first frame of this zone has to sell all three of its ideas at once:
	# there is a fire behind your right shoulder, a lit cottage behind you, and
	# the ground stops a stride and a half in front of you.
	# Clear of every pickup trigger: the first render spawned the bird inside
	# Molly's 1.6 m radius and the very first frame of the zone was a HOLD [E]
	# prompt instead of a view of the lake.
	goose.global_position = Vector3(3.0, PLATEAU_Y + 1.0, 6.0)
	# HEADING 0 IS -Z. The controller faces with `_face(atan2(-x, -z))`, so a
	# direction of (0, -1) yields yaw 0 — heading 0 points down -Z, not up +Z.
	# The lake runs from z = -5 out to z = -40 and the cliff lip is at z = 4.6,
	# so 0 is the water and PI is the cottage. This was PI, commented "facing
	# the water", which spun the opening frame a full 180° off the shot the
	# comment describes: cliff and lake behind the camera, cottage wall filling
	# the screen. Verified by render, not by reading.
	goose.heading = 0.0
	goose.rotation.y = 0.0

	camera_rig = preload("res://scripts/goose/goose_camera.gd").new()
	camera_rig.name = "CameraRig"
	camera_rig.target = goose
	add_child(camera_rig)
	goose.cam = camera_rig

	# NO SHAKE WIRING HERE. Juice owns the shake bus and the goose controller
	# drives it; a zone that also connects landed/tumbled shakes the camera
	# twice for one landing and bypasses the screen_shake accessibility pref.


# ══════════════════════════════════════════════════════════════════ TICK

func _process(delta: float) -> void:
	_t += delta

	# ── firelight ───────────────────────────────────────────────────────
	# Two octaves of sine, deliberately not random: a fire that flickers on
	# noise reads as a broken light bulb. The two lamps flicker out of phase
	# so the core and the reach never dip together and the plateau never goes
	# momentarily dark.
	if _fire_lights.size() >= 2:
		var f := sin(_t * 7.3) * 0.5 + sin(_t * 2.9 + 1.7) * 0.32 + sin(_t * 17.1) * 0.14
		_fire_lights[0].light_energy = 5.4 + f * 0.85
		_fire_lights[1].light_energy = 2.6 - f * 0.55
		_fire_lights[0].position.x += (sin(_t * 5.1) * 0.06 - _fire_lights[0].position.x) * 0.0
	# ── the zapper ──────────────────────────────────────────────────────
	if _zap_light != null:
		_zap_cd -= delta
		if _zap_cd <= 0.0:
			_zap_cd = randf_range(1.6, 5.5)
			_zap_light.light_energy = 9.0
			if _sfx != null:
				_sfx.play_at(&"fx_jitter", _zap_light, -16.0, randf_range(1.6, 2.1))
		_zap_light.light_energy = lerpf(_zap_light.light_energy,
			2.4 + sin(_t * 31.0) * 0.25, 1.0 - pow(0.001, delta))
	# ── the dock light, with a moth problem ─────────────────────────────
	if _dock_light_node != null:
		_dock_light_node.light_energy = 3.4 + sin(_t * 1.7) * 0.12 \
			+ (0.5 if sin(_t * 23.0) > 0.985 else 0.0)

	# ── the lake ────────────────────────────────────────────────────────
	for i in _loons.size():
		var l: Node3D = _loons[i]
		if not is_instance_valid(l):
			continue
		var ph := float(i) * 2.1
		l.position.y = WATER_Y + 0.05 + sin(_t * 0.9 + ph) * 0.045
		l.rotation.y += delta * 0.09 * sin(_t * 0.31 + ph)
		l.rotation.z = sin(_t * 1.3 + ph) * 0.05

	# ── the calls ───────────────────────────────────────────────────────
	# A loon wail every few seconds from whichever one is furthest out. It is
	# the ambience of this zone in one sound and it also tells a lost player
	# which way the open water is.
	_loon_cd -= delta
	if _loon_cd <= 0.0 and _sfx != null and not _loons.is_empty():
		_loon_cd = randf_range(7.0, 15.0)
		var l2: Node3D = _loons[randi() % _loons.size()]
		if is_instance_valid(l2):
			_sfx.play_at(&"honk_c", l2, -6.0, randf_range(0.36, 0.46))

	# ── the toad, once you're close ─────────────────────────────────────
	if _toad_seen and _toad_node != null and is_instance_valid(_toad_node) \
			and goose != null and is_instance_valid(goose):
		_toad_croak -= delta
		var near := _toad_node.global_position.distance_to(goose.global_position) < 12.0
		if _toad_croak <= 0.0 and near:
			_toad_croak = randf_range(2.4, 5.0)
			if _sfx != null:
				_sfx.play_at(&"goose_grumble", _toad_node, -13.0, randf_range(0.40, 0.50))


# ══════════════════════════════════════════════════════════════ ZONE API

## Which objective set the Mission autoload should load for this zone.
func mission_zone_id() -> StringName:
	return &"cottage"


## Title shown by the HUD at the top of the leg.
func zone_title() -> String:
	return "LEG %d — COTTAGE COUNTRY" % Flock.leg
