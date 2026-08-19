extends Node3D
## LEG 6 — THE CUT CORN, AT HARD MIDDAY
##
## Sampson County, North Carolina. A half-harvested field of field corn: a wall
## of standing dry corn on the east side, forty metres of open red-clay stubble
## on the west, a farmyard in the north-west corner, and a combine working the
## line between the two at five and a half metres a second.
##
## Graybox-plus-models, built procedurally so it runs correctly the first time
## you open the project with no import step and no missing references.
##
## TODO(art pass): same caveat as the other zones — once this plays right,
## rebuild it as a real .tscn. Procedural is the right call for a first playable
## and the wrong call for level design.
##
## ---------------------------------------------------------------------------
## WHY THIS ZONE EXISTS — the one thing it does that no other zone can
## ---------------------------------------------------------------------------
## CAMPAIGN_SPEC §1.3 fixes what each leg contributes to the teaching order, and
## leg 6's contribution is **cover and open ground**. §2.6 states the inversion
## it is built on:
##
##   > Every zone before this one has a safe ground and a dangerous sky. This
##   > one inverts it.
##
## Three mechanics carry that, and they are the only three things in this file
## that are load-bearing:
##
## 1. THE STANDING CORN IS COVER, AND COVER IS BLINDNESS. It is a two-metre wall
##    with NO COLLIDERS — you walk straight into it and the world disappears.
##    It is three metres tall rather than two for a reason that only a render
##    could have found; see CORN_H.
##    Nothing can see you and you can see nothing, including the combine. The
##    only thing that reaches you in there is sound. It is also the only place
##    in the game where GAINING ALTITUDE COSTS YOU SOMETHING: three metres up
##    and you can see the whole field, and the whole field can see you.
##
## 2. THE OPEN STUBBLE IS EXPOSURE, AND EXPOSURE IS THE PRICE OF EVERYTHING.
##    The layout is the mechanic: the corn (cover) is east, the farmyard
##    (the grain bin, the trucks, five of the eight pickups, the flock pen) is
##    north-west, and between them is fifteen to twenty-five metres of nothing
##    with the combine's lane running down the middle of it. You cannot get what
##    you want without crossing, and you cannot cross without timing the machine.
##    That is the whole zone, and it is done with geometry rather than with a
##    new system.
##
## 3. THE COMBINE EATS THE COVER. Every pass takes one more row, so `_cut_x`
##    marches east all leg and the wall you were hiding behind is smaller every
##    time you come back to it. Nobody says this.
##
##    MEASURED, not estimated: a pass is 62 m at 5.4 m/s plus a 1.7 s headland
##    turn, so 13.2 s, so about 13 passes in a 180 s leg, so 13 x 1.05 = ~14 m
##    of the 39 m of standing corn — a bit over a third of the cover, gone, by
##    the buzzer. `_advance_cut()` also refuses to take the last four rows, so
##    the mechanic can never be deleted by waiting.
##
## ---------------------------------------------------------------------------
## THE COMBINE IS AN AREA, NOT A BODY — read this before "fixing" it
## ---------------------------------------------------------------------------
## The machine has NO solid collider. It is a model, a hazard Area3D and a punt.
##
## That is deliberate and it is the safe choice, not the lazy one. A five-metre
## kinematic body crossing the map at 5.5 m/s is the exact shape of this
## project's two most expensive bugs: a CharacterBody3D squeezed between a
## moving StaticBody3D and the ground has nowhere to be resolved to, and a
## RigidBody3D that starts a frame inside one gets ejected to an absurd
## coordinate. (Recycling bins in this project once launched to y = -1120.)
##
## The Area3D reaches every body the machine's volume touches on the frame it
## touches it, and punts it clear before penetration is a concept. Nothing can
## be crushed, nothing can be ejected, and the read to the player — you got hit
## by a combine and you are now thirty metres away — is identical.
##
## The cost is that you cannot stand on it. That is not in the spec and it is
## not missed.
##
## ---------------------------------------------------------------------------
## THE HEIGHT TABLE
## ---------------------------------------------------------------------------
##     y =  0.00   the field. Dead flat, everywhere, deliberately.
##     y =  3.10   the top of the standing corn — the cover ceiling
##     y =  3.20   the top of a parked grain truck (landable)
##     y =  4.30   the top of the combine
##     y =  8.40   the grain bin's eave
##     y =  9.10   the grain bin's landing pad (landable, invisible collider)
##
## The zone is flat on purpose. Cottage Country already owns verticality; this
## one owns the horizontal plane, and a bump in it would give the player a place
## to break line of sight that is not the corn, which is the one thing that must
## stay unique.

const LOT := 88.0                ## the play square, +/- 44

## Preloaded rather than referenced by class_name: global class registration
## only exists after an editor import pass, so a `class_name` reference breaks
## in a fresh checkout or a headless CI run. A preload const always resolves.
const PROPS := preload("res://scripts/world/prop_models.gd")
const CORN := preload("res://scripts/world/prop_models_corn.gd")
## The zone's own score labels. They live in the objective file, once, so a
## rename is a parse error in both places instead of a silently dead objective —
## the fix `mission_defs.gd` already adopted after suburbia's labels drifted.
const MDEF := preload("res://scripts/core/mission_defs_corn.gd")

# ── the field, as constants ─────────────────────────────────────────────────
const GROUND_Y := 0.0
## THE COVER CEILING, AND THE NUMBER THAT WAS WRONG IN THE FIRST BUILD.
##
## Field corn is 2.1 m in a seed catalogue and this zone had it at 2.1. Then the
## render showed why that does not work: `goose_camera.gd` parks the rig at the
## goose plus `height` (2.2) and swings a 6 m arm up behind it, so the CAMERA
## sits at about three metres. At 2.1 m corn the bird is hidden and the player is
## looking straight over the top of the field — the cover mechanic exists for the
## goose and not for the person playing, which is the same as it not existing.
##
## At 3.10 m the camera is inside the canopy. That is a tall crop but not a lying
## one (modern hybrids run past three metres), it makes the wall read far harder
## from outside, and it still only costs two flaps to clear — one flap from a
## standstill is flap_impulse^2 / (2 * glide_gravity) = 1.86 m.
const CORN_H := 3.10             ## cover ceiling: above this you are visible
const CUT_X0 := 2.0              ## where the standing corn starts at t = 0
const CORN_X1 := 41.0            ## the east edge of the field
const CORN_Z0 := -41.0
const CORN_Z1 := 27.0
## DENSITY IS THE MECHANIC, not the dressing. The first render used 1.30 x 1.15
## and the standing corn rendered as a scatter of dry weeds you could see the
## treeline straight through — which is not cover, it is decoration. At 1.05 x
## 0.85 it is 2960 stalks and it closes. Raising the density is also raising the
## triangle count by the same factor, so if this ever needs to come back down,
## take it out of the LEAF SIZE first (prop_models_corn.gd::_corn_stalk) — a
## wider leaf occludes far more per triangle than another whole plant does.
const ROW_DX := 1.05             ## row spacing — one combine swath
const ROW_DZ := 0.85             ## plant spacing down a row

## The farmyard, as a rectangle, because three separate systems need to ask
## "is this in the yard?" and none of them should be asking about buildings.
const YARD_X1 := -13.0
const YARD_Z0 := 17.0

## The combine's lane sits this far into the CUT side of the boundary, so the
## header overlaps the standing edge the way a real one does.
const LANE_OFFSET := 2.40
const COMBINE_SPEED := 5.40
const COMBINE_Z0 := -38.0
const COMBINE_Z1 := 24.0
const COMBINE_TURN := 1.70       ## seconds spent stopped at each headland

## CLOSE PASS geometry. The hazard box is 5.8 m across and 7.6 m deep, so this
## radius leaves a band roughly two to four metres wide where you are scoring
## and not yet being hit. Narrow that and the objective becomes "be run over";
## widen it and it becomes "be in the same county".
const CLOSE_PASS_R := 7.0
const CLOSE_PASS_CD := 2.00

## OPEN GROUND. You must be this far from any cover, on your feet, for this
## long, and you must have been near cover since the last time it scored.
## Together those three make it mean "crossed" rather than "stood in a field".
const OPEN_MARGIN := 8.00
const OPEN_HOLD := 3.00
const OPEN_REARM := 4.50

# ── the palette ─────────────────────────────────────────────────────────────
## Carolina coastal-plain soil is RED — Norfolk and Orangeburg series, iron
## oxide, the colour of a clay tennis court. This is the single decision that
## makes the zone unmistakable from the air after five legs of grey asphalt,
## green lawn and black granite, and it is worth more than any prop in the file.
## First render came out the colour of a running track: the `dirt` texture is
## multiplied in and its mean is high, so the tint has to sit well below the
## value you actually want on screen.
const C_SOIL := Color(0.395, 0.235, 0.160)
const C_STUBBLE := Color(0.760, 0.680, 0.440)
## Harvest-ready field corn in October is DEAD — tan, brittle, rustling. Green
## corn on red clay reads as a hedge maze; tan corn on red clay reads as
## harvest, which is the whole point of setting the leg here.
## Pulled down and browned off the first render's values, where the corn and the
## stubble were within a few percent of each other and the boundary between the
## two halves of the field — the single most important line in the zone — did
## not read at distance.
const C_CORN := Color(0.545, 0.450, 0.230)
const C_LEAF := Color(0.620, 0.525, 0.270)
const C_WEED := Color(0.420, 0.440, 0.240)

## Chaos-prop label -> model kind, across BOTH libraries. Keyed off the label
## the prop already carries — the same string scoring and objectives match on —
## so there is one place to look and no call site repeats itself. A label with
## no entry keeps its BoxMesh.
##
## NOTE the split: "BALE" is the round one and "HAY BALE" is the small square
## one, and `bale_out` prefix-matches "BALE". "HAY BALE" does not begin with
## "BALE", so the square ones deliberately do not count toward it.
const PROP_KIND := {
	"BALE": &"round_bale",
	"HAY BALE": &"square_bale",
	"FEED SACK": &"feed_sack",
	"PALLET": &"pallet",
	"SCARECROW": &"scarecrow",
	# from the shared library
	"RECYCLING": &"recycling_bin",
	"GARBAGE": &"garbage_bag",
	"PATIO CHAIR": &"patio_chair",
	"FENCE": &"fence_panel",
	"BBQ": &"bbq",
}

var goose: Goose
var camera_rig: Node3D

var _tex: Node = null   ## /root/Tex — may not exist, always guard.
var _sfx: Node = null   ## /root/Sfx — may not exist, always guard.

var _t := 0.0

# ── the corn ────────────────────────────────────────────────────────────────
var _corn_mm: MultiMesh = null
var _corn_rows := 0              ## how many columns the MultiMesh holds
var _corn_per_row := 0
var _cut_rows := 0               ## how many the combine has eaten
var _cut_x := CUT_X0

# ── the combine ─────────────────────────────────────────────────────────────
var _combine: Node3D = null
var _combine_dir := 1.0
var _combine_wait := 0.0
var _punt_cd := 0.0
var _close_cd := 0.0
var _chug := 0.0
var _dust: Array[MeshInstance3D] = []

# ── cover and exposure ──────────────────────────────────────────────────────
var _in_cover := false
var _cover_reported := false
var _cover_cd := 0.0
var _open_t := 0.0
var _open_armed := true
var _silo_bonus_given := false
## The rig's authored defaults, captured rather than hardcoded, so that pulling
## the camera in for cover and letting it back out afterwards cannot fight a
## future retune of goose_camera.gd.
var _cam_dist := 6.0
var _cam_height := 2.2

# ── ambience ────────────────────────────────────────────────────────────────
var _crows: Array[Node3D] = []
var _dog_node: Node3D = null
var _bark_cd := 5.0


func _ready() -> void:
	_tex = get_node_or_null("/root/Tex")
	_sfx = get_node_or_null("/root/Sfx")

	_environment()
	_ground()
	_standing_corn()
	_stubble()
	_treeline()
	_farmyard()
	_grain_bin()
	_scarecrow()
	_lane_litter()
	_sources()
	_props()
	_people()
	_cats()
	_combine_build()
	_spawn_goose()
	# Your flock, parked at the south edge of the yard where there is shade and
	# where a player heading for the grain bin walks past them anyway. It is
	# also the only fixed landmark on the OPEN side of the map, which makes it
	# the thing you aim at when you break cover.
	add_child(preload("res://scripts/world/flock_pen.gd").new().setup(
		Vector3(-25.0, GROUND_Y + 0.2, 13.0)))


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


## Visual only — no collider. For paint, flat detail, row lines.
func _decal_box(pos: Vector3, size: Vector3, color: Color, rot_y := 0.0) -> MeshInstance3D:
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


## A flat, non-colliding textured slab, split into tiles.
##
## Unlike the cottage, this zone has ONE key light and no omnis, so the GL
## Compatibility eight-lights-per-object cap is not why the tiling exists here.
## It exists because an 88-metre quad with a 40x-tiled dirt texture on it is one
## draw call whose UVs the depth precision cannot hold, and because splitting it
## lets the field carry three different surfaces (worked soil, weedy headland,
## the yard's bare dirt) without a second material.
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
		params["colour"] = color

	if CORN.has_model(kind):
		# ChaosProp.setup() only knows the SHARED library, so anything from this
		# zone's own library is built here instead and the graybox hidden.
		# `_visual` has to be repointed or _break() would hide the invisible box
		# and leave a fully intact bale standing in its own debris.
		p.setup(size, color, mass_kg, pts, lbl)
		_hide_meshes(p)
		params["size"] = size
		var m: Node3D = CORN.build(kind, p, params)
		m.position.y = -size.y * 0.5
		p._visual = m
	else:
		p.setup(size, color, mass_kg, pts, lbl, kind, params)

	p.global_position = pos
	p.rotation.y = randf_range(-PI, PI)
	return p


## Hide a body's box mesh and hang a faceted model off it instead. The collider
## is untouched — this is a visual swap only.
##
## `base_y` is the model's base in the body's LOCAL frame, which for a box
## collider of height h centred on the body is always -h * 0.5.
func _model_body(sb: StaticBody3D, kind: StringName, base_y: float, params := {},
		uniform := 1.0) -> Node3D:
	_hide_meshes(sb)
	var m: Node3D = CORN.build(kind, sb, params) if CORN.has_model(kind) \
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
	if CORN.has_model(kind):
		CORN.build(kind, n, params)
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


# ══════════════════════════════════════════════════════════════ ENVIRONMENT
#
# THE BRIGHTEST ZONE IN THE GAME, and the notes that got it there:
#
#   1. THE SUN IS ALMOST OVERHEAD. -74 degrees of pitch. That is the whole
#      brief — "hot midday, high hard sun" — and it has one consequence worth
#      knowing: at this angle the shadows are short, so the field gets almost
#      none of its shape from shadow. All of the shape comes from the corn's own
#      silhouette and from the row lines on the ground, which is why both of
#      those are built rather than textured.
#   2. THE AMBIENT IS A WARM BOUNCE, NOT A BLUE SKY. Forty metres of red clay
#      and dry straw under a vertical sun throws a lot of light back up, and it
#      is the colour of the ground, not the colour of the sky. AMBIENT_SOURCE_
#      COLOR at a dirty gold. Sky ambient here rendered as a cold blue fill and
#      the whole field went to lilac.
#   3. THE HAZE IS THE POINT. Fog at 0.0032 in a pale dust colour with a high
#      sky_affect, so the treeline at forty metres is washed out and the far end
#      of the field disappears. It is also load-bearing for the COVER mechanic:
#      the standing corn has to feel like it goes on forever, and haze is what
#      hides the fact that it stops at x = 41.
#   4. EXPOSURE 1.05, WHITE 5.0. The temptation is to crank exposure to make it
#      "hot". Doing that clips the stubble to white and the field loses its rows.
#      Hot is a WHITE POINT decision, not an exposure one.

func _environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	# A Carolina sky at noon in October: deep at the zenith, and bleached almost
	# to white at the horizon by humidity and by the dust the combine is putting
	# into it. That bleach band is what sells the heat.
	sm.sky_top_color = Color(0.210, 0.400, 0.730)
	sm.sky_horizon_color = Color(0.815, 0.795, 0.730)
	sm.ground_bottom_color = Color(0.360, 0.255, 0.190)
	sm.ground_horizon_color = Color(0.680, 0.560, 0.430)
	# 0.14, not the 0.32 the first render used. The chase camera sits about nine
	# degrees below horizontal, so almost all the sky the player ever sees is the
	# bottom third of it — at 0.32 the bleach band filled the frame and the zone
	# had no sky colour at all, just a grey ceiling.
	sm.sky_curve = 0.14
	sm.sun_angle_max = 6.0
	sm.sun_curve = 0.10
	sky.sky_material = sm

	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.780, 0.690, 0.520)
	env.ambient_light_energy = 0.42
	env.fog_enabled = true
	env.fog_density = 0.0032
	env.fog_light_color = Color(0.840, 0.790, 0.690)
	env.fog_light_energy = 1.0
	# 0.28, not the first render's 0.55. Fog blended into the sky at 55% turned
	# the whole upper half of the frame into one flat grey band and the zone read
	# as OVERCAST — which is leg 2's light and the exact opposite of the brief.
	# The haze belongs on the treeline at forty metres, not on the zenith.
	env.fog_sky_affect = 0.28
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.tonemap_white = 5.0
	we.environment = env
	add_child(we)

	# ── the sun ─────────────────────────────────────────────────────────
	# Nearly vertical, tipped a little south-west so the corn casts a short hard
	# edge onto the stubble and the boundary between the two halves is a line
	# the player can read from anywhere on the map.
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-74.0, 214.0, 0.0)
	sun.light_energy = 1.28
	sun.light_color = Color(1.00, 0.965, 0.895)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	# Small angular distance = hard-edged shadows. It is noon; a soft shadow
	# here would read as overcast, which is leg 2's light, not this one's.
	sun.light_angular_distance = 0.25
	add_child(sun)

	# A shadowless bounce from below-ish the opposite side. Not realism — the
	# corn is a vertical wall lit from directly above, so without this every
	# stalk's sides go to a flat dark tan and 1700 of them read as one brown
	# mass. This is what keeps the wall looking like individual plants.
	var bounce := DirectionalLight3D.new()
	bounce.rotation_degrees = Vector3(-8.0, 34.0, 0.0)
	bounce.light_energy = 0.30
	bounce.light_color = Color(0.98, 0.86, 0.66)
	bounce.shadow_enabled = false
	add_child(bounce)


# ══════════════════════════════════════════════════════════════════ GROUND

func _ground() -> void:
	# ── the collider ────────────────────────────────────────────────────
	# One box for the whole field. Physics does not care how many surfaces the
	# art has, and one broadphase entry is one broadphase entry.
	var floor_body := _static_box(Vector3(0, -1.0, 0), Vector3(LOT, 2.0, LOT),
		C_SOIL)
	_hide_meshes(floor_body)

	# ── worked soil, everywhere ─────────────────────────────────────────
	# Sits so its TOP is exactly at GROUND_Y. The cottage lets its dressing ride
	# 3 cm proud of the collider and gets away with it; here the goose spends the
	# whole leg on the flat and a 3 cm lip under its feet is visible.
	_flat_tiles(Vector3(0, GROUND_Y - 0.03, 0), Vector3(LOT, 0.06, LOT),
		6, 6, &"dirt", C_SOIL, 26.0)

	# ── the rows ────────────────────────────────────────────────────────
	# THE SINGLE MOST IMPORTANT PIECE OF ART IN THE ZONE. A harvested field seen
	# from ten metres up is corduroy, and those lines are what tell a flying
	# player which way the field runs, where the boundary is, and — because the
	# standing corn is planted on the SAME grid — that the two halves are the
	# same field. Without them the cut side is a brown rectangle.
	#
	# One thin decal per row across the cut side only; under standing corn they
	# would never be seen. They extend a little past the current boundary so
	# that the ground the combine has just exposed already has rows on it.
	var n_rows := int((CUT_X0 + 6.0 + 42.0) / ROW_DX)
	for i in n_rows:
		var x := CUT_X0 + 6.0 - (float(i) + 0.5) * ROW_DX
		if x < -42.0:
			break
		_decal_box(Vector3(x, GROUND_Y + 0.005, -7.0), Vector3(0.40, 0.02, 70.0),
			C_SOIL.darkened(0.14))
		_decal_box(Vector3(x + ROW_DX * 0.5, GROUND_Y + 0.004, -7.0),
			Vector3(0.14, 0.02, 70.0), C_SOIL.lightened(0.05))

	# ── the headland ────────────────────────────────────────────────────
	# The strip of un-cropped grass round the outside that every field has,
	# because a combine has to turn somewhere. Also the only green in the zone,
	# which is what stops eighty metres of tan and red reading as a desert.
	_flat_tiles(Vector3(0, GROUND_Y + 0.005, -42.0), Vector3(LOT, 0.05, 4.0),
		4, 1, &"grass", C_WEED, 9.0)
	_flat_tiles(Vector3(-42.0, GROUND_Y + 0.005, 0), Vector3(4.0, 0.05, LOT),
		1, 4, &"grass", C_WEED, 9.0)
	_flat_tiles(Vector3(42.0, GROUND_Y + 0.005, 0), Vector3(4.0, 0.05, LOT),
		1, 4, &"grass", C_WEED, 9.0)

	# ── the yard ────────────────────────────────────────────────────────
	# Bare packed dirt, paler and greyer than the field: it is driven on, not
	# ploughed. The change of surface is how the player knows they have arrived.
	_flat_tiles(Vector3(-27.0, GROUND_Y + 0.01, 30.0), Vector3(30.0, 0.05, 24.0),
		3, 3, &"dirt", Color(0.520, 0.445, 0.375), 12.0)
	# The track out of the yard to the field, running south then east. It is the
	# route the player's eye follows from the yard back to the corn, and it is
	# the only thing in the middle of the map that is not stubble.
	_flat_tiles(Vector3(-20.0, GROUND_Y + 0.008, 21.0), Vector3(6.0, 0.05, 14.0),
		1, 2, &"dirt", Color(0.545, 0.430, 0.335), 6.0)

	# ── invisible walls ─────────────────────────────────────────────────
	for i in 4:
		var a := float(i) * PI * 0.5
		_hide_meshes(_static_box(
			Vector3(sin(a) * LOT * 0.5, 11.0, cos(a) * LOT * 0.5),
			Vector3(LOT, 30.0, 1.0), Color(1, 1, 1), a))


# ══════════════════════════════════════════════════════════ THE STANDING CORN
#
# ~1770 stalks in ONE MultiMesh and ONE draw call.
#
# THE COLUMN ORDER IS LOAD-BEARING AND IS THE ONLY CLEVER THING IN THIS FILE.
# Instances are generated FAR SIDE FIRST — column 0 sits at x = 40.35 and the
# last column sits at x = 2.65, on the boundary. So "the combine ate a row" is
# a single integer write:
#
#     _corn_mm.visible_instance_count = (rows - eaten) * per_row
#
# No per-instance transform rewrite, no scan, no allocation, and it is correct
# for free every frame. Generating them the other way round would have needed
# an O(n) pass every swath, and building the corn as N MeshInstance3Ds would
# have needed 1770 draw calls.
#
# NO COLLIDERS. Not one. That is the mechanic: you walk INTO the corn, not up
# against it. The moment the corn is solid it stops being cover and becomes a
# wall, and this zone already has walls.

func _standing_corn() -> void:
	var mesh := CORN.mesh_for(&"corn_stalk", {"colour": C_CORN, "trim_colour": C_LEAF})
	if mesh == null:
		push_warning("zone_corn: corn stalk mesh failed to build")
		return

	_corn_rows = int((CORN_X1 - CUT_X0) / ROW_DX)
	_corn_per_row = int((CORN_Z1 - CORN_Z0) / ROW_DZ)
	var total := _corn_rows * _corn_per_row

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = total

	var i := 0
	for c in _corn_rows:
		# c = 0 is the FAR column. See the note above.
		var x := CORN_X1 - (float(c) + 0.5) * ROW_DX
		for r in _corn_per_row:
			var z := CORN_Z0 + (float(r) + 0.5) * ROW_DZ
			# Deterministic jitter. randf() here would make the field different
			# every run, which breaks the render-and-diff verification and,
			# worse, means a bug in the corn is not reproducible.
			var ph := float(c) * 1.913 + float(r) * 0.771
			var jx := 0.16 * sin(ph * 3.1)
			var jz := 0.20 * cos(ph * 2.3)
			var yaw := ph * 1.7
			var scl := 0.86 + 0.26 * absf(sin(ph * 1.31))
			var b := Basis(Vector3.UP, yaw).scaled(Vector3(scl, scl, scl))
			mm.set_instance_transform(i, Transform3D(b, Vector3(x + jx, GROUND_Y, z + jz)))
			i += 1

	mm.visible_instance_count = total

	var mmi := MultiMeshInstance3D.new()
	mmi.name = "StandingCorn"
	mmi.multimesh = mm
	mmi.material_override = CORN.shared_material()
	# An explicit AABB. A MultiMesh derives its own from the instance
	# transforms, but this one is going to have its visible count driven down
	# every ten seconds and an AABB that shrinks with it would pop the whole
	# field out of frame at a shallow camera angle. Stating it once, generously,
	# costs nothing and cannot go wrong.
	mmi.custom_aabb = AABB(
		Vector3(CUT_X0 - 2.0, GROUND_Y - 0.5, CORN_Z0 - 2.0),
		Vector3(CORN_X1 - CUT_X0 + 4.0, 5.0, CORN_Z1 - CORN_Z0 + 4.0))
	add_child(mmi)
	_corn_mm = mm


## What the combine leaves. Same grid as the standing corn, half density along
## the rows, over the WHOLE field — including under the standing corn, where it
## is invisible and free, so that a freshly cut row already has stubble on it
## the instant the corn above it disappears.
func _stubble() -> void:
	var mesh := CORN.mesh_for(&"corn_stubble", {"colour": C_STUBBLE})
	if mesh == null:
		return
	# Collected first, then allocated, because the yard has to be skipped and a
	# MultiMesh's instance_count has to be exact — every slot you allocate and
	# do not write is an identity transform, which is a corn stub standing at
	# the world origin. (That is a real failure mode: the first pass left 300 of
	# them stacked inside the goose's spawn point.)
	var xf: Array[Transform3D] = []
	var cols := int(83.0 / ROW_DX)
	var per := int(82.0 / (ROW_DZ * 3.0))
	for c in cols:
		var x := CORN_X1 - (float(c) + 0.5) * ROW_DX
		for r in per:
			var z := -41.0 + (float(r) + 0.5) * ROW_DZ * 3.0
			if x < YARD_X1 and z > YARD_Z0 - 1.0:
				continue                       ## the yard is driven on, not cropped
			var ph := float(c) * 2.117 + float(r) * 1.331
			var yaw := ph * 2.1
			var scl := 0.75 + 0.5 * absf(cos(ph * 1.7))
			var b := Basis(Vector3.UP, yaw).scaled(Vector3(scl, scl, scl))
			xf.append(Transform3D(b,
				Vector3(x + 0.22 * sin(ph * 4.1), GROUND_Y, z + 0.30 * cos(ph * 3.3))))

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])

	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Stubble"
	mmi.multimesh = mm
	mmi.material_override = CORN.shared_material()
	mmi.custom_aabb = AABB(Vector3(-44.0, GROUND_Y - 0.5, -44.0), Vector3(88.0, 2.0, 88.0))
	add_child(mmi)


# ══════════════════════════════════════════════════════════════════ TREELINE
#
# A loblolly-pine windbreak round three sides. It does two jobs and neither is
# decoration: it is the horizon the player orients on from the air, and it is
# COVER, so the far edges of the map are somewhere you can get to rather than a
# wall you are pressed against. `_cover_dist()` knows about it by name.

func _treeline() -> void:
	var spots: Array = []
	for i in 13:
		spots.append([-41.0 + float(i) * 6.6, -41.5, float(i)])
	for i in 10:
		spots.append([-41.5, -34.0 + float(i) * 8.0, float(i) + 20.0])
	for i in 9:
		spots.append([41.5, -32.0 + float(i) * 8.2, float(i) + 40.0])
	for i in 5:
		spots.append([12.0 + float(i) * 6.4, 41.0, float(i) + 60.0])
	for row in spots:
		var e: Array = row
		var x: float = e[0]
		var z: float = e[1]
		var s: float = e[2]
		_model_at(&"tree_conifer", Vector3(x + 1.4 * sin(s * 2.1), GROUND_Y,
			z + 1.2 * cos(s * 1.7)), s * 0.9, {
			"colour": Color(0.34, 0.26, 0.20),
			"leaf_colour": Color(0.185, 0.290, 0.185),
			"variant": int(s) % 4,
		}, 1.15 + 0.45 * absf(sin(s * 1.3)))

	# Three broadleaf trees in the yard, because a farmhouse always has them and
	# because they are the only real shade on the map.
	#
	# PLACED EXPLICITLY, NOT ON A FORMULA. The first pass generated these from a
	# loop with a sin() offset and two of the three came out INSIDE the
	# farmhouse's footprint — a render from the farmhouse roof showed an oak
	# growing through the ridge. A tree is a `_model_at` with no collider, so
	# nothing was ejected and nothing errored; it was simply wrong, silently, and
	# only visible from a viewpoint nobody had photographed yet. Three literal
	# coordinates, all checked against the house box (x -39.5..-28.5,
	# z 30.5..39.5) and the grain bin's pad (x -22..-14, z 30..38).
	var yard_trees := [Vector3(-41.5, GROUND_Y, 37.5), Vector3(-41.0, GROUND_Y, 29.0),
		Vector3(-24.5, GROUND_Y, 40.5)]
	for i in yard_trees.size():
		var tp: Vector3 = yard_trees[i]
		_model_at(&"tree_deciduous", tp, float(i) * 1.9, {
			"colour": Color(0.36, 0.28, 0.21),
			"leaf_colour": Color(0.300, 0.360, 0.190),
			"variant": i,
		}, 1.25)


# ══════════════════════════════════════════════════════════════════ FARMYARD

func _farmyard() -> void:
	# ── the farmhouse ───────────────────────────────────────────────────
	var hw := 11.0
	var hd := 9.0
	var wall_h := 3.2
	var roof_h := 2.4
	var house := _static_box(Vector3(-34.0, wall_h * 0.5, 35.0),
		Vector3(hw, wall_h, hd), Color(0.72, 0.70, 0.66))
	_model_body(house, &"house", -wall_h * 0.5, {
		"w": hw, "d": hd, "wall_h": wall_h, "roof_h": roof_h,
		# Same clipping problem as the bin roof, one notch less severe: a white
		# clapboard farmhouse at noon is a white rectangle with no panel lines in
		# it. Authored at 0.70 so the sun brings it back up to reading as white.
		"wall_colour": Color(0.700, 0.665, 0.605),
		# Dark, because a pitched roof under a 74-degree sun is the second most
		# blown-out surface in the zone after the grain bin's cone. A render from
		# the roof itself showed 0.34 rendering as near-white.
		"roof_colour": Color(0.215, 0.185, 0.175),
		"garage_side": 1.0,
		"variant": 1,
	})
	# The landable roof plateau, same flat approximation of a pitched volume the
	# other two zones use.
	_hide_meshes(_static_box(Vector3(-34.0, wall_h + roof_h * 0.42, 35.0),
		Vector3(hw * 0.86, roof_h * 0.6, hd * 0.86), Color(0.34, 0.30, 0.28)))

	# ── two grain trucks, parked nose-out ───────────────────────────────
	# STATIC, not chaos props. Eight tonnes is not a thing a goose moves, and a
	# 900 kg rigid body that can be nudged is the worst of both readings. What
	# they are for is being climbed on: a flat 2.5 x 5 metre deck at y = 3.2 is
	# the only mid-height platform in a dead-flat zone, and the grain in the
	# open box is one of the two ethanol sources.
	for spec in [[-28.0, 25.0, 0.14, Color(0.74, 0.72, 0.68), Color(0.32, 0.42, 0.34)],
			[-19.0, 24.0, -0.22, Color(0.66, 0.30, 0.22), Color(0.40, 0.38, 0.34)]]:
		var s: Array = spec
		var tx: float = s[0]
		var tz: float = s[1]
		var yaw: float = s[2]
		var cab: Color = s[3]
		var boxc: Color = s[4]
		var tb := _static_box(Vector3(tx, 1.60, tz), Vector3(2.50, 3.20, 7.30),
			cab, yaw)
		_model_body(tb, &"grain_truck", -1.60, {"colour": cab, "trim_colour": boxc})

	# ── the kennel, and a dog on a chain ────────────────────────────────
	# The chain is the joke and the design. A loose farm dog would be a second
	# pursuer and this zone already has one; a CHAINED dog is a three-metre
	# circle of extremely loud danger sitting between the yard and the field
	# that you have to route around and that never actually catches you.
	_model_at(&"kennel", Vector3(-37.0, GROUND_Y, 27.5), 0.4,
		{"colour": Color(0.52, 0.40, 0.28), "trim_colour": Color(0.36, 0.27, 0.22)})
	_dog_node = _model_at(&"farm_dog", Vector3(-35.2, GROUND_Y, 26.2), -0.8,
		{"colour": Color(0.42, 0.31, 0.20)})
	# The chain, as a sag of four short segments from the kennel to the collar.
	for i in 4:
		var t := (float(i) + 0.5) / 4.0
		var p := Vector3(-37.0, GROUND_Y, 27.5).lerp(Vector3(-35.2, 0.52, 26.2), t)
		_decal_box(p + Vector3(0, 0.22 - 0.55 * sin(t * PI), 0),
			Vector3(0.05, 0.05, 0.46), Color(0.40, 0.40, 0.42), 0.9)

	# ── round bales, in a row along the yard's south edge ───────────────
	# Heavy, unbreakable, and ROUND. Their axis is set across the field so one
	# good shove sends them rolling south into the open, which is exactly what
	# `bale_out` is asking for and is the best physics gag in the zone.
	for i in 4:
		var bx := -40.0 + float(i) * 3.1
		var bale := _prop(Vector3(bx, 0.78, 17.0), Vector3(1.90, 1.55, 1.55),
			Color(0.74, 0.66, 0.42), 420.0, 90, "BALE", {"variant": float(i)})
		bale.breakable = false
		bale.break_force = 999.0
		bale.rotation.y = 0.0
	# Two more stranded out in the middle of the open ground, which is the only
	# reason to go and stand in the worst place on the map.
	for i in 2:
		var bale2 := _prop(Vector3(-24.0 + float(i) * 7.0, 0.78, -4.0 - float(i) * 9.0),
			Vector3(1.90, 1.55, 1.55), Color(0.72, 0.64, 0.40), 420.0, 90, "BALE",
			{"variant": float(i) + 4.0})
		bale2.breakable = false
		bale2.break_force = 999.0
		bale2.rotation.y = 0.0

	# ── fence along the yard's east side ────────────────────────────────
	for i in 7:
		var fz := 18.0 + float(i) * 3.2
		_prop(Vector3(-12.0, 0.86, fz), Vector3(2.20, 1.70, 0.16),
			Color(0.52, 0.42, 0.30), 26.0, 40, "FENCE").rotation.y = PI * 0.5


# ══════════════════════════════════════════════════════════ THE GRAIN BIN
#
# "The silo survives. It is just in North Carolina now." — CAMPAIGN_SPEC §2.6
#
# It is the only vertical thing on the map and it therefore does three jobs at
# once: it is the landmark you navigate the whole zone by, it is the objective
# (`silo_business`), and it is the only place you can see the entire field from,
# which is the other half of the zone's idea — altitude buys information and
# costs cover.

func _grain_bin() -> void:
	var bx := -18.0
	var bz := 34.0

	# ── the drum ────────────────────────────────────────────────────────
	# A cylinder collider, not a box: it is a round thing eleven metres tall and
	# the corners of a box would be invisible ledges the goose bounces off.
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 3.60
	cyl.height = 8.40
	cs.shape = cyl
	body.add_child(cs)
	add_child(body)
	body.global_position = Vector3(bx, 4.20, bz)

	# COOLED DELIBERATELY. The first render had this at a neutral grey (0.72,
	# 0.73, 0.74) and it came back the colour of sandstone: this zone's ambient
	# is a dirty gold bounce off forty metres of red clay, so anything neutral
	# lands warm. The bin is the one object on the map that has to read as
	# GALVANISED STEEL — it is the landmark, and a tan tower reads as a grain
	# elevator in a desert. Pushed blue by about 12% to come out neutral on
	# screen. If the ambient is ever retuned, retune this with it.
	_model_at(&"silo", Vector3(bx, GROUND_Y, bz), 0.0, {
		"colour": Color(0.615, 0.680, 0.775),
		# The roof is a cone pointing straight up at a 74-degree sun, so it is the
		# most strongly lit surface anywhere in the zone and it clipped to pure
		# white on the first render. It has to be authored MUCH darker than it
		# looks like it should be — this reads as mid-grey galvanise on screen.
		"trim_colour": Color(0.335, 0.385, 0.455),
		"glow_colour": Color(1.00, 0.32, 0.22),
	})

	# ── the landing pad ─────────────────────────────────────────────────
	# The roof is a cone, and a cone is not a place a bird can stand. This is a
	# flat invisible disc set into it at y = 9.10 — high enough that the model's
	# surface is below it everywhere inside its radius, low enough that the
	# player reads themselves as standing ON the roof rather than hovering.
	var pad := StaticBody3D.new()
	var pcs := CollisionShape3D.new()
	var pcyl := CylinderShape3D.new()
	pcyl.radius = 2.30
	pcyl.height = 0.40
	pcs.shape = pcyl
	pad.add_child(pcs)
	add_child(pad)
	pad.global_position = Vector3(bx, 9.10, bz)

	# ── the payout ──────────────────────────────────────────────────────
	var bonus := Area3D.new()
	add_child(bonus)
	bonus.global_position = Vector3(bx, 10.10, bz)
	var bcs := CollisionShape3D.new()
	var bsh := CylinderShape3D.new()
	bsh.radius = 2.60
	bsh.height = 1.80
	bcs.shape = bsh
	bonus.add_child(bcs)
	bonus.monitoring = true
	bonus.monitorable = false
	bonus.body_entered.connect(_on_silo_top)

	# ── the spilled heap under the discharge chute ──────────────────────
	# Waste grain on the ground under a bin is where geese actually are, and it
	# is the true fact this whole leg is built on: the twentieth-century spread
	# of corn agriculture measurably changed where geese winter. It is also
	# where the ethanol is, because spilled grain in the wet ferments.
	for i in 5:
		var a := 1.2 + float(i) * 1.27
		var r := 0.55 + 0.55 * float(i % 3)
		_decal_box(Vector3(bx + cos(a) * r, GROUND_Y + 0.045, bz - 4.2 + sin(a) * r * 0.7),
			Vector3(1.5 + 0.5 * float(i % 2), 0.09, 1.3), Color(0.84, 0.72, 0.40),
			a * 0.5)

	# ── pallets and sacks stacked against it ────────────────────────────
	for i in 3:
		_prop(Vector3(bx + 4.6, 0.09 + float(i) * 0.15, bz + 1.2 + float(i) * 0.2),
			Vector3(1.16, 0.14, 1.00), Color(0.62, 0.52, 0.38), 9.0, 30, "PALLET")
	for i in 3:
		_prop(Vector3(bx + 5.8 + float(i) * 0.7, 0.18, bz - 0.6 - float(i) * 0.8),
			Vector3(0.58, 0.34, 0.82), Color(0.76, 0.68, 0.50), 22.0, 35, "FEED SACK",
			{"variant": float(i) * 1.7})


func _on_silo_top(body: Node3D) -> void:
	if body is Goose and not _silo_bonus_given:
		_silo_bonus_given = true
		Game.score(200, MDEF.LBL_SILO, body.global_position)
		if _sfx != null:
			_sfx.play_at(&"score_blip_hi", body, 0.0, 1.0)


# ══════════════════════════════════════════════════════════════ THE SCARECROW
#
# Out alone in the middle of the open stubble, on the far side of the combine's
# lane from the spawn. It is the zone's only landmark between the corn and the
# yard, so it is what a player aims at the first time they break cover — which
# means the first crossing has a destination, which is the difference between
# "go stand in a field" and "go get that".
#
# It is a light, breakable chaos prop and it carries one of the two hidden
# objectives. Everyone is going to knock it over. That is fine. That is the gag.

func _scarecrow() -> void:
	var sc := _prop(Vector3(-10.0, 1.10, -6.0), Vector3(1.70, 2.20, 0.50),
		Color(0.66, 0.24, 0.22), 12.0, 150, "SCARECROW")
	sc.rotation.y = 0.25
	sc.break_force = 6.0
	# A crow on its hat, and two more on the fence. The joke writes itself and
	# it costs three models.
	_crows.append(_model_at(&"crow", Vector3(-10.0, 2.16, -6.0), 2.6,
		{"colour": Color(0.10, 0.10, 0.12)}))
	_crows.append(_model_at(&"crow", Vector3(-12.0, GROUND_Y, 18.6), 1.1,
		{"colour": Color(0.11, 0.11, 0.13)}))
	_crows.append(_model_at(&"crow", Vector3(-12.0, GROUND_Y, 25.0), -0.7,
		{"colour": Color(0.10, 0.10, 0.12)}))


# ══════════════════════════════════════════════════════════ THE LANE LITTER
#
# `harvest_festival` asks the player to put four things through the header, and
# this function is the only reason that objective cannot dead-end.
#
# TWO props start IN the lane. They are eaten in the first thirty seconds
# whether the player does anything or not, and that is the point: the objective
# ticks twice, unprompted, while the player is still working out what the noise
# is. It DEMONSTRATES the verb. The remaining ten sit two to six metres west of
# the lane — one shove from a goose — or just inside the standing corn where the
# advancing cut reaches them on its own if nobody bothers.
#
# That "show it twice for free, then charge for it" shape is the introduce /
# develop half of the four-step stage design in CAMPAIGN_SPEC §1.3, and it is
# also the cheapest possible insurance against a primary that can never
# complete, which this project has already shipped once in suburbia.

func _lane_litter() -> void:
	var lane := CUT_X0 - LANE_OFFSET

	# The two freebies, right in the path.
	_prop(Vector3(lane + 0.3, 0.21, 4.0), Vector3(0.46, 0.41, 0.97),
		Color(0.80, 0.72, 0.46), 14.0, 45, "HAY BALE", {"variant": 0.0})
	_prop(Vector3(lane - 0.4, 0.18, -19.0), Vector3(0.58, 0.34, 0.82),
		Color(0.74, 0.66, 0.48), 20.0, 40, "FEED SACK", {"variant": 1.0})

	# Shovable, west of the lane. Deliberately light — a goose has to be able to
	# move these, and ChaosProp caps impulse at 55 kg of effective mass.
	var west := [
		[-4.2, -30.0, "HAY BALE"], [-5.6, -12.0, "FEED SACK"],
		[-3.4, -2.0, "PALLET"], [-6.0, 9.0, "HAY BALE"],
		[-4.8, 16.0, "FEED SACK"], [-3.0, -25.0, "PALLET"],
	]
	for row in west:
		var e: Array = row
		var x: float = e[0]
		var z: float = e[1]
		var lbl: String = e[2]
		_place_litter(lane + x, z, lbl)

	# Just inside the standing corn. The advancing cut gets to these on its own
	# around the fourth and seventh passes.
	var inside := [[1.2, -22.0, "HAY BALE"], [2.4, 1.0, "PALLET"],
		[1.8, 13.0, "FEED SACK"], [3.1, -8.0, "HAY BALE"]]
	for row2 in inside:
		var e2: Array = row2
		var x2: float = e2[0]
		var z2: float = e2[1]
		var lbl2: String = e2[2]
		_place_litter(CUT_X0 + x2, z2, lbl2)


func _place_litter(x: float, z: float, lbl: String) -> void:
	match lbl:
		"HAY BALE":
			_prop(Vector3(x, 0.21, z), Vector3(0.46, 0.41, 0.97),
				Color(0.80, 0.72, 0.46), 14.0, 45, lbl, {"variant": x})
		"FEED SACK":
			_prop(Vector3(x, 0.18, z), Vector3(0.58, 0.34, 0.82),
				Color(0.75, 0.67, 0.49), 20.0, 40, lbl, {"variant": z})
		_:
			_prop(Vector3(x, 0.08, z), Vector3(1.16, 0.14, 1.00),
				Color(0.62, 0.52, 0.38), 9.0, 30, lbl)


# ══════════════════════════════════════════════════════════════ THE COMBINE

func _combine_build() -> void:
	_combine = Node3D.new()
	_combine.name = "Combine"
	add_child(_combine)
	# STARTS AT THE FAR END, COMING TOWARD YOU. Not a detail: the camera opens
	# looking down -Z (see _spawn_goose), so a combine that starts at the near
	# headland is behind the player on frame one and the zone's whole thesis
	# object is off screen until they think to turn round. From -38 it is a hazy
	# shape with a dust plume forty-four metres out, it grows for eight seconds,
	# and then it is on top of you. That is the introduction the machine deserves
	# and it costs one constant.
	_combine.global_position = Vector3(CUT_X0 - LANE_OFFSET, GROUND_Y, COMBINE_Z0)
	_combine_dir = 1.0
	_combine.rotation.y = PI     ## nose at -Z when yaw is 0, so +Z travel is PI

	CORN.build(&"combine", _combine, {
		"colour": Color(0.66, 0.17, 0.13),
		"trim_colour": Color(0.87, 0.81, 0.30),
		"glow_colour": Color(1.00, 0.62, 0.10),
	})

	# ── the hazard volume ───────────────────────────────────────────────
	# Sized to the machine including its header, from the model's own measured
	# footprint plus the header's forward reach. See the header comment at the
	# top of this file for why there is no solid body.
	var area := Area3D.new()
	area.name = "Header"
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(5.80, 4.30, 7.60)
	cs.shape = bs
	cs.position = Vector3(0, 2.15, -0.50)
	area.add_child(cs)
	area.monitoring = true
	area.monitorable = false
	_combine.add_child(area)
	area.body_entered.connect(_on_combine_touch)

	# ── the dust ────────────────────────────────────────────────────────
	# Seven unshaded translucent slabs trailing off the back. It is the thing
	# you actually see at forty metres — long before you can resolve a machine,
	# you can see that something over there is making dust — and in a zone whose
	# whole mechanic is not being able to see, that is worth more than any
	# amount of detail on the model.
	var dm := StandardMaterial3D.new()
	# 0.30 alpha. At the first render's 0.20 the plume was invisible at the forty
	# metres that matter — the distance at which the dust is supposed to be the
	# ONLY thing telling you where the machine is.
	dm.albedo_color = Color(0.82, 0.70, 0.54, 0.30)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.cull_mode = BaseMaterial3D.CULL_DISABLED
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	for i in 7:
		var mi := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(4.0 + float(i) * 0.9, 3.0 + float(i) * 0.7)
		mi.mesh = qm
		mi.material_override = dm
		_combine.add_child(mi)
		mi.position = Vector3(0.4 * sin(float(i) * 2.1), 1.1 + 0.28 * float(i),
			2.6 + float(i) * 1.5)
		_dust.append(mi)


func _on_combine_touch(body: Node3D) -> void:
	if body is Goose:
		if _punt_cd > 0.0:
			return
		_punt_cd = 1.60
		_punt(body)
		return
	if body is ChaosProp and _combine != null:
		var fwd := -_combine.global_transform.basis.z
		# hit() applies the impulse AND scores the prop's own label, so a thing
		# the combine eats also counts toward `variety_pack` and, if it is a
		# round bale, toward `bale_out`. 28 is above every break_force in the
		# zone except the bales', which are unbreakable and simply launch.
		body.hit(28.0, fwd * 14.0 + Vector3.UP * 7.0)
		Game.score(120, MDEF.LBL_HARVESTED, body.global_position)
		if _sfx != null:
			_sfx.play_at(&"crash_heavy", body, -3.0, randf_range(0.72, 0.88))


## Thirty metres, as promised.
##
## The bird goes into TUMBLE, not into flight and not into a plain ballistic
## arc, and that is a numbers decision rather than a taste one. `_tick_ground()`
## bleeds horizontal speed at 14 m/s^2 and `_tick_fly()` at 10; `_tick_tumble()`
## bleeds it at 5. Punting into GROUND state at 22 m/s lands the bird about
## seventeen metres away, which reads as a shove. Punting into TUMBLE lands it
## past twenty and it keeps sliding, which reads as being hit by a combine.
##
## `_start_tumble()` is underscore-private on the controller. Calling it is the
## honest choice anyway: it is the one path that fires the hitstop, the feather
## burst and the tumble sound that this project has already tuned, and
## reimplementing those here would be a second, worse copy of a Tier-4 juice
## response. Guarded with has_method so a rename degrades to a plain punt rather
## than to a crash.
func _punt(body: Goose) -> void:
	var fwd := -_combine.global_transform.basis.z
	var side := _combine.global_transform.basis.x
	var away: float = signf((body.global_position - _combine.global_position).dot(side))
	if is_zero_approx(away):
		away = 1.0
	body.velocity = fwd * 18.0 + side * away * 9.0 + Vector3.UP * 13.5
	if body.has_method("_start_tumble"):
		body.call("_start_tumble")
	Game.score(140, "THIRTY METRES", body.global_position)
	Juice.burst(body.global_position + Vector3.UP * 0.4, Color(0.82, 0.70, 0.48),
		18, &"debris")
	Juice.floating_text(body.global_position + Vector3.UP * 1.2, "THIRTY METRES",
		Color(1.00, 0.72, 0.28))
	if _sfx != null:
		_sfx.play_at(&"crash_heavy", body, 0.0, 0.62)
		_sfx.play_at(&"honk_angry", body, -2.0, randf_range(1.05, 1.20))


# ══════════════════════════════════════════════════════════════ SUBSTANCES
#
# SIX, and eight pickups. CAMPAIGN_SPEC §2.6: "Deliberately thin." The cottage
# has seventeen; this has eight, and five of them are in the farmyard, which is
# on the far side of the open ground from where you spawn. That placement IS the
# leg's difficulty: the shelf is not thin because there is less of it, it is thin
# because getting to it costs you a crossing every time.
#
# The six are fixed by the spec: fermented berries (waste grain), double-double
# (a thermos in a truck), grass, math, darts, whippet.

func _sources() -> void:
	# ── fermented grain, under the bin's chute ──────────────────────────
	# The design bible's silo idea, landed. Spilled corn under a bin gets wet and
	# ferments, and that is not a joke — it is why waterfowl turn up drunk in
	# harvested fields, and it is the true fact this leg's Almanac entry wants.
	_source(Vector3(-18.0, GROUND_Y + 0.40, 29.8), Subs.get_substance(&"berries"), 0.52)
	# ── and a second load, in the back of the red truck ─────────────────
	# Sat just above the truck's collider deck so it is reachable by landing on
	# the truck. The first pass had it down in the grain at y = 2.5, INSIDE the
	# collider, where nothing can ever touch it.
	_source(Vector3(-19.0, 3.35, 25.4), Subs.get_substance(&"berries"), 0.48)

	# ── the thermos on the other truck's step ───────────────────────────
	# THE TRUCK IS YAWED 0.14 rad AND THIS USED TO IGNORE IT. The grey truck sits
	# at (-28, _, 25) with a 2.50 x 3.20 x 7.30 collider; subtracting 1.3 m along
	# WORLD x from its centre lands 1.008 m along its LOCAL x, which is inside a
	# box whose half-width is 1.25. The thermos spent the whole project inside the
	# cab, 0.24 m in, and was only takeable because a pickup's trigger sphere is
	# 1.6 m across. tools/geomtest.gd pass 2 found it.
	#
	# Written in the truck's own frame now, so the two cannot disagree again: 1.60
	# out along local -x is 0.35 m clear of the cab side, which is where a step is.
	var cab := Transform3D(Basis(Vector3.UP, 0.14), Vector3(-28.0, 0.0, 25.0))
	var step := cab * Vector3(-1.60, 0.95, -2.16)
	_source(step, Subs.get_substance(&"double_double"), 0.44)
	_decal_box(step - Vector3(0, 0.21, 0), Vector3(0.16, 0.30, 0.16),
		Color(0.16, 0.34, 0.24))

	# ── grass, infinite, on the headland ────────────────────────────────
	# The only two things in the zone that never run out, and they are both on
	# the weedy strip round the edge — which is also cover. A player who never
	# crosses the open ground can have exactly one substance all leg. That is
	# not a punishment, it is the leg stating its terms.
	var grass := Subs.get_substance(&"grass")
	_source(Vector3(-41.0, GROUND_Y + 0.40, -6.0), grass, 0.42, true)
	_source(Vector3(6.0, GROUND_Y + 0.40, -40.5), grass, 0.42, true)

	# ── the yield tallies nobody finished ───────────────────────────────
	_source(Vector3(-13.4, 0.42, 34.6), Subs.get_substance(&"math"), 0.42)
	_decal_box(Vector3(-13.4, 0.20, 34.6), Vector3(0.34, 0.03, 0.44),
		Color(0.90, 0.88, 0.82), 0.4)

	# ── half a pack on the fence post by the dog ────────────────────────
	_source(Vector3(-12.0, 1.30, 21.2), Subs.get_substance(&"darts"), 0.34)
	_decal_box(Vector3(-12.0, 1.12, 21.2), Vector3(0.16, 0.10, 0.24),
		Color(0.86, 0.14, 0.12))

	# ── the cooler on the tailgate ──────────────────────────────────────
	# Somebody brought lunch out to the field. The whipped cream is in it, and it
	# is the one pickup in the zone that is genuinely hidden behind a prop rather
	# than behind a distance.
	_static_box(Vector3(-26.2, 0.27, 21.4), Vector3(0.80, 0.54, 0.48),
		Color(0.18, 0.34, 0.58), 0.3)
	_decal_box(Vector3(-26.2, 0.56, 21.4), Vector3(0.84, 0.06, 0.52),
		Color(0.86, 0.88, 0.90), 0.3)
	_source(Vector3(-26.2, 0.80, 21.4), Subs.get_substance(&"nitrous"), 0.45)


# ══════════════════════════════════════════════════════════════ POPULATION

func _props() -> void:
	# Yard clutter: the loose stuff a farm accumulates, arranged so that a bird
	# flying a line from the grain bin back to the corn hits some of it whether
	# it meant to or not.
	for i in 2:
		_prop(Vector3(-31.0 + float(i) * 1.5, 0.61, 30.5), Vector3(1.00, 1.20, 0.80),
			Color(0.20, 0.34, 0.24), 8.0, 40, "RECYCLING")
	for i in 3:
		_prop(Vector3(-33.2 + float(i) * 0.8, 0.28, 31.8), Vector3(0.48, 0.55, 0.50),
			Color(0.14, 0.14, 0.16), 3.0, 18, "GARBAGE", {"variant": float(i) * 1.3})
	for i in 3:
		_prop(Vector3(-38.0 + float(i) * 1.4, 0.46, 32.5 + float(i) * 0.6),
			Vector3(0.60, 0.90, 0.60), Color(0.44, 0.34, 0.24), 6.0, 28, "PATIO CHAIR")
	var bq := _prop(Vector3(-30.0, 0.53, 33.4), Vector3(1.00, 1.05, 0.55),
		Color(0.18, 0.18, 0.20), 16.0, 50, "BBQ")
	bq.break_force = 11.0

	# A scatter of sacks and pallets out along the headland, so the far edges of
	# the map are not empty for a player who runs the perimeter.
	for i in 4:
		var a := float(i) * 2.3
		_prop(Vector3(-39.0 + 1.6 * sin(a), 0.18, -14.0 - float(i) * 6.0),
			Vector3(0.58, 0.34, 0.82), Color(0.74, 0.67, 0.48), 20.0, 40, "FEED SACK",
			{"variant": a})


func _people() -> void:
	# Two. A farm at harvest is not busy with PEOPLE, it is busy with one machine
	# and whoever is waiting for it, and a crowd here would flatten the loneliness
	# the open ground is supposed to have.
	var shirts := [Color(0.88, 0.86, 0.80), Color(0.30, 0.44, 0.62)]
	var spots := [Vector3(-27.0, GROUND_Y + 0.2, 21.5),
		Vector3(-18.5, GROUND_Y + 0.2, 30.0)]
	for i in spots.size():
		var n := NpcHuman.new()
		add_child(n)
		n.setup(shirts[i])
		n.global_position = spots[i]


func _cats() -> void:
	## Barn cats. There are always exactly two and they are always somewhere you
	## did not expect.
	var furs := [Color(0.78, 0.62, 0.36), Color(0.26, 0.24, 0.23)]
	var spots := [Vector3(-33.0, GROUND_Y + 0.2, 29.0),
		Vector3(-21.0, GROUND_Y + 0.2, 19.0)]
	for i in spots.size():
		var c := Cat.new()
		add_child(c)
		c.setup(furs[i])
		c.global_position = spots[i]


func _spawn_goose() -> void:
	goose = Goose.new()
	goose.name = "Goose"
	add_child(goose)
	# On the cut stubble, nine metres west of the standing corn, facing SOUTH
	# down the field.
	#
	# THE HEADING IS NOT A FREE CHOICE, AND THE FIRST RENDER IS WHY.
	# `goose_camera.gd` starts its yaw at 0 and only ever chases the goose's
	# VELOCITY, never its heading — so on the opening frame of every zone in this
	# game the camera looks down world -Z regardless of which way the bird is
	# pointed. (zone_cottage.gd gets its lake into frame by putting the lake at
	# -Z, not by setting a heading.) The first pass here spawned the bird facing
	# +Z at the farmyard and photographed the goose's face against forty metres
	# of empty stubble.
	#
	# So the opening shot is composed at -Z and the heading is 0 to match it:
	# the wall of dry corn fills the right of the screen, forty metres of open
	# red clay run away to the left, the scarecrow stands alone out in the middle
	# of it, and the combine is coming up the line between them from the far end
	# of the field with a dust plume behind it. The farmyard is deliberately
	# BEHIND you — it is the destination, not the establishing shot, and turning
	# round to find it is the first thing the zone asks you to do.
	#
	# Clear of every pickup trigger and every collider: the nearest pickup is
	# twenty metres away in the yard, the nearest prop is the lane litter at
	# z = 4, and the combine's lane is 8.6 m east. The cottage's first render
	# spawned the bird inside a pickup radius and the opening frame of that zone
	# was a HOLD [E] prompt instead of a view of the lake.
	goose.global_position = Vector3(-9.0, GROUND_Y + 0.9, 12.0)
	goose.heading = 0.0
	goose.rotation.y = 0.0

	camera_rig = preload("res://scripts/goose/goose_camera.gd").new()
	camera_rig.name = "CameraRig"
	camera_rig.target = goose
	add_child(camera_rig)
	goose.cam = camera_rig
	_cam_dist = float(camera_rig.distance)
	_cam_height = float(camera_rig.height)

	# NO SHAKE WIRING HERE. Juice owns the shake bus and the goose controller
	# drives it; a zone that also connects landed/tumbled shakes the camera
	# twice for one landing and bypasses the screen_shake accessibility pref.


# ══════════════════════════════════════════════════════════════════ COVER
#
# The three questions the whole zone is built on, answered with arithmetic
# rather than with physics queries. All three run every physics tick and all
# three are a handful of float compares, which is the right price for something
# that has to be correct while the cut boundary is moving.

## Inside the standing corn, below the canopy. THE HEIGHT TEST IS THE MECHANIC:
## three metres up and you are over the top of it, and you are not in cover any
## more even though your shadow is.
func _in_corn(p: Vector3) -> bool:
	return p.x >= _cut_x and p.x <= CORN_X1 \
		and p.z >= CORN_Z0 and p.z <= CORN_Z1 \
		and p.y <= GROUND_Y + CORN_H


## Straight-line distance to the nearest thing you could hide behind or in.
##
## Three rectangles: the standing corn, the farmyard, and the band inside the
## perimeter treeline. This is a heuristic, not a visibility query — it does not
## know about individual bales or the scarecrow, deliberately, because "I was
## behind a bale" is not the scale of cover this zone is about.
func _cover_dist(p: Vector3) -> float:
	var d := _box_dist(p, _cut_x, CORN_X1, CORN_Z0, CORN_Z1)
	d = minf(d, _box_dist(p, -42.0, YARD_X1, YARD_Z0, 42.0))
	d = minf(d, maxf(40.0 - maxf(absf(p.x), absf(p.z)), 0.0))
	return d


static func _box_dist(p: Vector3, x0: float, x1: float, z0: float, z1: float) -> float:
	var dx: float = maxf(maxf(x0 - p.x, p.x - x1), 0.0)
	var dz: float = maxf(maxf(z0 - p.z, p.z - z1), 0.0)
	return sqrt(dx * dx + dz * dz)


# ══════════════════════════════════════════════════════════════════ TICK
#
# _physics_process for the combine and for cover, because both are GAMEPLAY —
# the machine's position decides whether you get hit, and the cover test decides
# whether you get paid. _process for the dust, the crows and the dog, which are
# cosmetics and are allowed to run at whatever rate the display does.

func _physics_process(delta: float) -> void:
	_tick_combine(delta)
	_tick_cover(delta)


func _tick_combine(delta: float) -> void:
	if _combine == null or not is_instance_valid(_combine):
		return
	_punt_cd = maxf(0.0, _punt_cd - delta)
	_close_cd = maxf(0.0, _close_cd - delta)

	var pos := _combine.position

	# ── the headland turn ───────────────────────────────────────────────
	if _combine_wait > 0.0:
		_combine_wait -= delta
		if _combine_wait <= 0.0:
			_combine_dir = -_combine_dir
			_combine.rotation.y = 0.0 if _combine_dir < 0.0 else PI
			_advance_cut()
		_combine.position = pos
		return

	pos.z += _combine_dir * COMBINE_SPEED * delta
	if _combine_dir < 0.0 and pos.z <= COMBINE_Z0:
		pos.z = COMBINE_Z0
		_combine_wait = COMBINE_TURN
	elif _combine_dir > 0.0 and pos.z >= COMBINE_Z1:
		pos.z = COMBINE_Z1
		_combine_wait = COMBINE_TURN

	# ── the lean ────────────────────────────────────────────────────────
	# The machine's lane is fixed by the cut, but a driver steers, and this
	# machine steers a little toward a goose standing in the open near it. It is
	# bounded to about four and a half metres, so it can reach the crossing strip
	# and it can NEVER follow you across the field. This is not a pursuit — a
	# pursuit boss is a genre this controller does not have (BOSS_DESIGN.md), and
	# the moment the combine chases, the corn stops being a decision and becomes
	# the only correct answer.
	var lane := _cut_x - LANE_OFFSET
	var want := lane
	if goose != null and is_instance_valid(goose):
		var g := goose.global_position
		if not _in_cover and g.x < _cut_x and absf(g.z - pos.z) < 26.0:
			want = lane + clampf(g.x - lane, -4.50, 1.50)
	pos.x = move_toward(pos.x, want, 2.60 * delta)
	_combine.position = pos

	# ── close passes ────────────────────────────────────────────────────
	if goose != null and is_instance_valid(goose) and _close_cd <= 0.0:
		var d := _combine.global_position.distance_to(goose.global_position)
		if d < CLOSE_PASS_R:
			_close_cd = CLOSE_PASS_CD
			Game.score(60, MDEF.LBL_CLOSE_PASS, goose.global_position)
			if _sfx != null:
				_sfx.play_at(&"score_blip", goose, -6.0, 1.15)


## One more row gone. The whole of "the combine eats the cover" is these four
## lines, because the MultiMesh's columns were generated far-side-first.
func _advance_cut() -> void:
	if _cut_rows >= _corn_rows - 4:
		# Leave four rows standing, always. A leg that can end with NO cover on
		# the map is a leg whose entire mechanic can be deleted by waiting, and
		# the combine would then be working an empty field, which is worse than
		# a small liberty with agronomy.
		return
	_cut_rows += 1
	_cut_x = CUT_X0 + float(_cut_rows) * ROW_DX
	if _corn_mm != null:
		_corn_mm.visible_instance_count = (_corn_rows - _cut_rows) * _corn_per_row


func _tick_cover(delta: float) -> void:
	if goose == null or not is_instance_valid(goose):
		return
	var p := goose.global_position
	var inside := _in_corn(p)
	_in_cover = inside

	# ── entering and leaving, debounced ─────────────────────────────────
	# 1.2 s of debounce, because the boundary is a line and a goose walking
	# along it would otherwise emit forty transitions a second. `_cover_reported`
	# is separate from `_in_cover` on purpose: the combine's lean and the open
	# ground test both want the RAW answer every tick, and only the SCORING
	# wants the debounced one.
	# ── the camera closes in ────────────────────────────────────────────
	# Inside the corn the chase arm comes from six metres to three and a half.
	# `distance` is an @export the rig re-reads every frame and lerps its spring
	# length toward, so this is a smooth pull rather than a cut, and main.gd's
	# own probe already writes it the same way.
	#
	# It is not only a legibility fix, though it is that — at six metres in a
	# three-metre crop the player loses their own bird. It is also the strongest
	# single cue that the corn is a different PLACE: the frame tightens, the
	# leaves crowd in, and the field you were just looking at is gone. Cover
	# should feel like putting a bag on your head, because that is what it is.
	if camera_rig != null and is_instance_valid(camera_rig):
		camera_rig.distance = 3.50 if inside else _cam_dist
		camera_rig.height = 1.90 if inside else _cam_height

	_cover_cd = maxf(0.0, _cover_cd - delta)
	if inside != _cover_reported and _cover_cd <= 0.0:
		_cover_reported = inside
		_cover_cd = 1.20
		if inside:
			Game.score(45, MDEF.LBL_INTO_CORN, p)
		else:
			Game.score(45, MDEF.LBL_BROKE_COVER, p)

	# ── the open ground ─────────────────────────────────────────────────
	# On your feet, a long way from anything, for three seconds, and only once
	# per trip out. `_open_armed` is what makes it mean "crossed": it only comes
	# back when you get near cover again, so a player who parks in the middle of
	# the field scores exactly one and then has to go somewhere.
	var far := _cover_dist(p)
	var grounded := true
	if goose.has_method("is_airborne"):
		grounded = not bool(goose.is_airborne())
	if grounded and not inside and far >= OPEN_MARGIN:
		_open_t += delta
		if _open_t >= OPEN_HOLD and _open_armed:
			_open_armed = false
			_open_t = 0.0
			Game.score(160, MDEF.LBL_OPEN_GROUND, p)
			if _sfx != null:
				_sfx.play_at(&"score_blip_hi", goose, -3.0, 0.92)
	else:
		_open_t = 0.0
		if inside or far <= OPEN_REARM:
			_open_armed = true


func _process(delta: float) -> void:
	_t += delta

	# ── the dust ────────────────────────────────────────────────────────
	# Two octaves of sine per slab, out of phase, so the plume boils rather than
	# pulsing. Alpha falls off with distance behind the machine and the whole
	# thing dies while it is stopped at the headland, which is a surprisingly
	# strong cue that it has turned round.
	var moving := _combine_wait <= 0.0
	for i in _dust.size():
		var q: MeshInstance3D = _dust[i]
		if not is_instance_valid(q):
			continue
		var ph := float(i) * 1.37
		var s := 1.0 + 0.22 * sin(_t * 1.9 + ph) + 0.10 * sin(_t * 5.3 + ph * 2.1)
		q.scale = Vector3(s, s * 0.85, 1.0)
		q.position.y = 1.1 + 0.28 * float(i) + 0.16 * sin(_t * 1.3 + ph)
		q.visible = moving

	# ── the engine ──────────────────────────────────────────────────────
	# PLACEHOLDER, AND IT IS THE FIRST THING A HUMAN SHOULD REPLACE. There is no
	# engine sample in this project (HANDOFF: "No zone-specific SFX anywhere"),
	# so this is `crash_heavy` at a very low pitch on a 0.9 s cycle standing in
	# for a diesel lug.
	#
	# It is not cosmetic even though it lives in _process. The corn is cover for
	# the COMBINE as well as for the goose, and sound is the only channel the
	# player has for locating it while they are inside the wall. If this cue is
	# wrong, the cover mechanic is unfair rather than tense.
	if _sfx != null and _combine != null and is_instance_valid(_combine):
		_chug -= delta
		if _chug <= 0.0:
			_chug = 0.90 if moving else 1.60
			_sfx.play_at(&"crash_heavy", _combine, -26.0 if moving else -30.0,
				randf_range(0.26, 0.30))

	# ── the crows ───────────────────────────────────────────────────────
	for i in _crows.size():
		var c: Node3D = _crows[i]
		if not is_instance_valid(c):
			continue
		var ph2 := float(i) * 2.7
		c.rotation.y += delta * 0.5 * sin(_t * 0.6 + ph2)
		c.position.y += (sin(_t * 3.1 + ph2) * 0.012 - (c.position.y - _crow_rest(i))) * 0.2

	# ── the dog ─────────────────────────────────────────────────────────
	# It barks when you are close and it never gets any closer. Both halves of
	# that are the joke.
	if _dog_node != null and is_instance_valid(_dog_node) \
			and goose != null and is_instance_valid(goose):
		var gd := _dog_node.global_position.distance_to(goose.global_position)
		_bark_cd -= delta
		if _bark_cd <= 0.0 and gd < 16.0:
			_bark_cd = randf_range(1.1, 2.6)
			if _sfx != null:
				_sfx.play_at(&"honk_angry", _dog_node, -8.0, randf_range(1.5, 1.8))
		_dog_node.rotation.y = lerp_angle(_dog_node.rotation.y,
			atan2(-(goose.global_position.x - _dog_node.global_position.x),
				-(goose.global_position.z - _dog_node.global_position.z)),
			1.0 - pow(0.02, delta))


## Resting height of crow `i`. The one on the scarecrow's hat sits at 2.16; the
## two on the fence sit on the ground. Stored as a function rather than an array
## because it is two numbers and an array of two numbers is a thing to keep in
## sync.
func _crow_rest(i: int) -> float:
	return 2.16 if i == 0 else GROUND_Y


# ══════════════════════════════════════════════════════════════ ZONE API

## Which objective set the Mission autoload should load for this zone.
func mission_zone_id() -> StringName:
	return &"corn"


## Title shown by the HUD at the top of the leg.
func zone_title() -> String:
	return "LEG %d — THE CUT CORN" % Flock.leg
