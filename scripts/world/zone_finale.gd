extends Node3D
## LEG 8 — THE 18TH GREEN. North Florida, first light.
##
## The ending. `docs/CAMPAIGN_SPEC.md` Part 5 is the spec; `docs/FINALE_NOTES.md`
## records where this file departs from it and why.
##
## ---------------------------------------------------------------------------
## THE RULE THIS WHOLE FILE IS DOWNSTREAM OF
## ---------------------------------------------------------------------------
##     THE COMEDY DOES NOT STOP. THE STAKES DO.
##
## So: no clock, no HUD, no objectives, no chaos counter, no Goose Brain, no
## grade, no results card, no cutscene, and no moment where the game stops
## being funny in order to be sincere. The sincere thing happens INSIDE the
## joke — which is why the one sincere beat in Geeked Geese is a sound effect
## (§5.3 beat 4) and the run summary is delivered as objects you can smash.
##
## This is the only zone in the project that deliberately takes the HUD away,
## and it does it itself rather than asking main.gd to, so the guarantee holds
## no matter how the zone is loaded. See _take_over().
##
## ---------------------------------------------------------------------------
## WHAT IS ACTUALLY HERE
## ---------------------------------------------------------------------------
## 1. THE COURSE. One flat mown plane, a green, a bunker, a water hazard with a
##    fountain, a cart path, palms, live oaks with Spanish moss, an unreachable
##    clubhouse, and sixteen sprinklers that never stop. Geometrically trivial
##    on purpose: the expensive part of this zone was never the geometry.
##
## 2. THIRTY RESIDENT GEESE who were here before you and do not react to you.
##    They are the same objects the Stopover uses, twenty minutes earlier in
##    the run, which is what makes this a RETURN rather than a first
##    appearance. They do not stop, they do not look up, they have no dialogue.
##
## 3. YOUR SURVIVORS. Everyone in `Flock.alive_birds()`, physically, by name,
##    with their scars. They land beside you, they stand around for a bit, and
##    then one by one they walk off and join a resident. Each departure floats
##    that bird's name once, in world space — the only time in the entire game
##    a flock member's name is rendered in the world during play. If you kept a
##    Designated Driver, it goes last and it does not join anybody: it stands
##    next to you.
##
## 4. THE CREDITS, as knockable slabs that walk up the fairway at you. The run
##    summary is IN them. A goose that has spent forty-five minutes destroying
##    suburbia gets to destroy the credits too, including its own roster — and
##    including the Almanac, which walks past as one slab per substance you
##    found, saying what it actually was. See _almanac_section().
##
## ---------------------------------------------------------------------------
## THE HEIGHT TABLE
## ---------------------------------------------------------------------------
##     y =  0.00   the course. Every walkable surface. There is exactly one.
##     y =  0.46   a standing goose's origin (see STAND_HEIGHT)
##     y =  0.06   the water hazard's surface decal
##     y =  4.60   the clubhouse roof ridge (the one resident up there)
##
## THE COURSE IS ONE PLANE AND EVERY SURFACE VARIATION IS A DECAL. The green,
## the fringe, the bunker, the cart path and the wet patches under the
## sprinklers are all non-colliding discs and slabs lying on it. That is the
## suburbia pattern rather than the cottage one, and it is the right one here:
## there is nothing in this zone worth a physical seam, and a 15 cm lip on the
## edge of a green is a CharacterBody3D snag that would be entirely
## indistinguishable from the game being broken.

const COURSE := 150.0          ## the playable square, centred on the origin
const STAND_HEIGHT := 0.46     ## goose hips above ground — see flock_pen.gd

## Preloaded rather than referenced by class_name: global class registration
## only exists after an editor import pass, so a `class_name` reference breaks
## in a fresh checkout or a headless CI run. A preload const always resolves.
const PROPS := preload("res://scripts/world/prop_models.gd")
const COTTAGE := preload("res://scripts/world/prop_models_cottage.gd")
const GREEN := preload("res://scripts/world/prop_models_finale.gd")
const CHAOS_PROP := preload("res://scripts/world/chaos_prop.gd")
const FLOCK_PEN := preload("res://scripts/world/flock_pen.gd")

## Both goose scripts expose an identical API (animate / set_bank / set_tint /
## body / neck), so nothing here cares which one is live. Same table the goose
## controller and the flock pen use, for the same reason.
const MODEL_SCRIPTS := {
	"classic": "res://scripts/goose/goose_visual.gd",
	"lowpoly": "res://scripts/goose/goose_visual_lowpoly.gd",
}

# ── the places on the course ────────────────────────────────────────────────
const GREEN_C := Vector3(-1.0, 0.0, -34.0)
const GREEN_R := 13.5
const PIN := Vector3(-3.5, 0.0, -36.5)
const BUNKER_C := Vector3(15.0, 0.0, -24.0)
const BUNKER_R := 7.4
const POND_C := Vector3(-25.0, 0.0, -14.0)
const POND_R := 10.5
const CLUBHOUSE := Vector3(30.0, 0.0, -64.0)
const COOLER_C := Vector3(9.0, 0.0, 2.0)
const LAP_PALM := Vector3(-16.0, 0.0, 8.0)
const LAP_PALM_2 := Vector3(20.0, 0.0, 10.0)
const BALL := Vector3(-9.0, 0.0, -8.0)
const NORTHWARD := Vector3(4.0, 0.0, -66.0)

const C_FAIRWAY := Color(0.36, 0.50, 0.22)
const C_GREEN := Color(0.31, 0.52, 0.24)
const C_ROUGH := Color(0.29, 0.38, 0.18)
const C_SAND := Color(0.86, 0.79, 0.60)
const C_PATH := Color(0.72, 0.70, 0.65)

## Which flock members exist, as data, resolved once in _ready(). The finale
## must never re-read Flock mid-scene: `Flock.leg` is already past the end of
## the route and a restart rebuilds the flock underneath us.
var goose: Goose
var camera_rig: Node3D

var _tex: Node = null   ## /root/Tex — may not exist, always guard.
var _sfx: Node = null   ## /root/Sfx — may not exist, always guard.

var _t := 0.0
var _geese: Array[Dictionary] = []      ## residents AND survivors, one tick
var _survivors: Array[Dictionary] = []  ## the subset that is yours
var _spray: Array[Node3D] = []
var _cart: Node3D = null
var _cart_a := 0.0
var _flag: Node3D = null

## Beat 3 — the settling. One survivor peels off every SETTLE_EVERY seconds.
const SETTLE_EVERY := 7.0
var _settle_cd := 12.0
var _settle_next := 0
var _all_settled_t := -1.0

## Beat 4 — the honk wave.
const WAVE_SPAN := 2.5      ## seconds from the nearest goose to the furthest
var _wave_cd := 0.0
var _wave_count := 0
var _last_wave_t := -99.0
var _honk_queue: Array[Dictionary] = []

## Beat 5 — the credits.
const CREDIT_SPEED := 2.15   ## m/s up the fairway, toward the camera
const CREDIT_EVERY := 2.55   ## seconds between slabs
const CREDIT_START_Z := -74.0
var _credit_lines: Array[String] = []
var _credit_next := 0
var _credit_cd := 0.0
var _credit_rolling := false
var _credit_done := false

## The only two pieces of interface in the whole zone, and both of them leave.
var _ui: CanvasLayer = null
var _pin_label: Label = null
var _esc_label: Label = null


# ═══════════════════════════════════════════════════════════════ INTEGRATION

## The one-line hook for main.gd. Replace the body of `_finish_run()` with:
##
##     preload("res://scripts/world/zone_finale.gd").install(self)
##
## Everything else — clearing the flight, taking the mouse back, killing the
## clock, silencing the HUD — happens in here or in _ready(), so the director
## keeps exactly one line of knowledge about the ending.
static func install(host: Node) -> Node3D:
	if host.has_method("_clear"):
		host.call("_clear")
	# `_clear()` only QUEUES the old zone for deletion, so it is still sitting in
	# the tree holding the name "Zone" — and add_child() responds to that
	# collision by throwing the requested name away and calling the new node
	# "@Node3D@927". honk.gd looks its shockwave host up by the literal name
	# "Zone", so get this wrong and every honk in the ending parents its ring to
	# the scene root instead. Move the corpse out of the way first.
	var stale := host.get_node_or_null(NodePath("Zone"))
	if stale != null:
		stale.name = "ZoneOutgoing"
	var zone: Node3D = load("res://scripts/world/zone_finale.gd").new()
	zone.name = "Zone"
	host.add_child(zone)
	# `current` is what main.gd frees on the next phase change. If the ending
	# is not in it, a restart leaks the entire golf course.
	if "current" in host:
		host.set("current", zone)
	if host.has_method("_capture_mouse"):
		host.call("_capture_mouse", true)
	return zone


func _ready() -> void:
	_tex = get_node_or_null("/root/Tex")
	_sfx = get_node_or_null("/root/Sfx")

	_take_over()
	_environment()
	_ground()
	_course()
	_water()
	_planting()
	_clubhouse()
	_sprinklers()
	_props()
	_spawn_goose()
	_residents()
	_survivor_flight()
	_build_ui()
	_credit_lines = _compose_credits()


## Everything the ending has to switch OFF, in one place.
##
## This is deliberately the zone's job and not the director's. The spec's
## hardest requirement is a negative one — "No clock. No HUD. No score. Nothing
## in any corner." — and a negative requirement enforced from somewhere else is
## a requirement that comes back the first time somebody reorders a phase.
func _take_over() -> void:
	# The clock. Without this, Game._process runs the leg-8 timer down and
	# fires Phase.MIGRATION under the credits.
	Game.zone_running = false
	Game.zone_time_left = 0.0
	# The score. Every prop here is built worth 0, and that was not enough: the
	# honk scores for what it shoves whatever the prop is worth, and honking a
	# credit slab floated "+20" over the goose (D-079). From here the run's
	# total is fixed, and it is the number `_compose_credits()` prints.
	Game.scoring = false
	Engine.time_scale = 1.0
	# Whatever the player was on when they landed. The epilogue is sober: the
	# uber-shader lives on the HUD we are about to hide, so a substance still
	# running would leave its post-processing stranded on screen with no way to
	# see the timer that ends it.
	var subs := get_node_or_null("/root/Subs")
	if subs != null and subs.has_method("reset_for_new_leg"):
		subs.reset_for_new_leg()
	_hide_hud()
	# ...and again once the director has finished building this leg. main.gd
	# creates the HUD AFTER it adds the zone, so the call above finds nothing
	# on the intended path and everything on the route path. A deferred call
	# runs at the end of this frame's idle work, which is after `add_child(hud)`
	# — and, unlike _process, it still runs while a briefing card has the tree
	# paused, which is exactly the state the first render was in when it came
	# back with the clock and the objective list sitting over the ending.
	_hide_hud.call_deferred()
	# The band. There are no `mus_green` stems yet (see FINALE_NOTES), so the
	# ending borrows the lake set, which is the warmest and the least
	# percussive of the three. The first call is not a typo: set_zone() clears
	# the migration watchdog only on its way INTO the flight cue, and without
	# that the watchdog drags the flight music back over the ending.
	var music := get_node_or_null("/root/Music")
	if music != null and music.has_method("set_zone"):
		music.set_zone(&"migration")
		music.set_zone(&"cottage")
		music.set_intensity(0.26)

	if _sfx != null:
		# The ending is installed by main.gd::_finish_run() -> install(), which
		# calls host._clear() but never _load_zone() — so the 18th green is the
		# one place nothing ever chose an ambience bed, and it played in silence.
		# Same hand-driven ownership as the music above, for the same reason.
		_sfx.set_ambience(&"green")


## Hide, don't free: main.gd holds references to both of these and calls
## `hud.toast()` on its own reference with no validity guard, so freeing them
## from out here would turn the ending into a runtime error.
##
## BY SCRIPT, NOT BY NAME. `get_node("HUD")` does not work here and neither
## does a name prefix, and it took three renders to find out why:
## `_load_zone()` queue_frees the old HUD and adds the new one in the SAME
## frame, so the corpse is still in the tree holding the name. `add_child()`
## with the default `force_readable_name = false` responds to that collision by
## throwing the requested name away entirely and calling the new node
## `@CanvasLayer@1233`. Looking up "HUD" finds the corpse; looking up "HUD*"
## finds nothing at all. The script reference is the only identity these nodes
## reliably keep.
##
## (CanvasLayer is also NOT a CanvasItem — it derives straight from Node — so
## an `is CanvasItem` test matches neither of them either. Two traps, one
## function, both paid for by a render.)
const HUD_SCRIPTS := [
	preload("res://scripts/ui/hud.gd"),
	preload("res://scripts/ui/mission_hud.gd"),
]

func _hide_hud() -> void:
	var host := get_parent()
	if host == null:
		return
	for c in host.get_children():
		if not (c is CanvasLayer):
			continue
		var lay: CanvasLayer = c
		if lay == _ui:
			continue
		if HUD_SCRIPTS.has(lay.get_script()):
			lay.visible = false


# ------------------------------------------------------------------ helpers

func _mat(c: Color, rough := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


## Textured surface when the Tex service is available, flat colour when it
## isn't. Every large surface goes through here so the zone still renders
## correctly if the textures are ever missing.
func _surf(key: StringName, uv_scale: float, fallback: Color, rough := 0.94) -> StandardMaterial3D:
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


func _hide_meshes(sb: Node) -> void:
	for c in sb.get_children():
		if c is MeshInstance3D:
			c.visible = false


## A flat, non-colliding disc lying on the course. Every surface on this golf
## course except the ground itself is one of these.
func _disc(pos: Vector3, radius: float, height: float, color: Color,
		tex_key: StringName = &"", uv := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	# 34, not the default 64 and not the 22 the first pass used: at 22 the
	# bunker's outer collar and its sand disc are two nested 22-gons a metre
	# apart, and the ring between them renders as a dashed line all the way
	# round. 34 is smooth at every distance the camera actually sits at.
	cm.radial_segments = 34
	mi.mesh = cm
	if tex_key != &"":
		mi.material_override = _surf(tex_key, uv if uv > 0.0 else radius * 0.5, color)
	else:
		mi.material_override = _mat(color)
	add_child(mi)
	mi.global_position = pos
	return mi


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


## A flat, non-colliding textured rectangle — the large-surface form of
## _decal_box. Tiled, for the GL Compatibility eight-lights-per-mesh reason
## documented at length in zone_cottage.gd.
func _flat_tiles(centre: Vector3, size: Vector3, nx: int, nz: int, key: StringName,
		fallback: Color, uv_scale: float, rough := 0.95) -> void:
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


## A free-standing model with no collider at all. `pos` is where the model's
## FEET go, so pass ground height, not centre.
func _model_at(kind: StringName, pos: Vector3, rot_y := 0.0, params := {},
		uniform := 1.0) -> Node3D:
	var n := Node3D.new()
	add_child(n)
	n.global_position = pos
	n.rotation.y = rot_y
	if GREEN.has_model(kind):
		GREEN.build(kind, n, params)
	elif COTTAGE.has_model(kind):
		COTTAGE.build(kind, n, params)
	else:
		PROPS.build(kind, n, params)
	if not is_equal_approx(uniform, 1.0):
		n.scale = Vector3.ONE * uniform
	return n


## A knockable prop, with a model from whichever library has one.
func _prop(pos: Vector3, size: Vector3, color: Color, mass_kg: float, pts: int,
		lbl: String, kind: StringName = &"", extra := {}) -> ChaosProp:
	var p := ChaosProp.new()
	add_child(p)
	var params: Dictionary = extra.duplicate()
	if kind != &"":
		params["colour"] = color
	if GREEN.has_model(kind) or COTTAGE.has_model(kind):
		# ChaosProp.setup() only knows the SHARED library, so anything from
		# another one is built here and the graybox hidden. `_visual` has to be
		# repointed or _break() would hide the invisible box and leave a fully
		# intact cooler standing in its own debris.
		p.setup(size, color, mass_kg, pts, lbl)
		_hide_meshes(p)
		params["size"] = size
		var m: Node3D = GREEN.build(kind, p, params) if GREEN.has_model(kind) \
			else COTTAGE.build(kind, p, params)
		m.position.y = -size.y * 0.5
		p._visual = m
	else:
		p.setup(size, color, mass_kg, pts, lbl, kind, params)
	p.global_position = pos
	p.rotation.y = randf_range(-PI, PI)
	return p


# ══════════════════════════════════════════════════════════════ ENVIRONMENT
#
# FIRST LIGHT, NORTH FLORIDA. The warmest lighting in the game, and the only
# zone lit from very nearly the horizon.
#
# Three things make it read as dawn rather than as the suburbia golden hour,
# and all three matter:
#
#   1. THE SUN IS AT 9 DEGREES, not 22. Shadows are four metres long off a
#      goose, the palms stripe the fairway, and the ground plane picks up a
#      grazing highlight that a higher sun flattens out completely.
#   2. THE FILL IS PINK, NOT BLUE. At golden hour the sky opposite the sun is
#      cold; at first light it is still holding the pink of the sunrise all the
#      way round. A cold fill here made the grass read as evening.
#   3. THERE IS MIST ON THE GROUND. Fog at 0.0075 with a warm colour and a very
#      low sky_affect: it separates the clubhouse from the treeline, it makes
#      the sprinklers legible from across the course, and it is the single
#      cheapest way to say "nobody has been out here yet today".

func _environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.28, 0.42, 0.68)
	sm.sky_horizon_color = Color(0.99, 0.76, 0.60)
	# These two are not scenery — they are what the player sees BELOW the
	# horizon line past the end of the course, and the first render put a hard
	# grey stripe under the treeline because they were much darker than the
	# fog in front of them. Matched to the fog colour, the course simply fades
	# out and there is no edge.
	sm.ground_bottom_color = Color(0.72, 0.60, 0.54)
	sm.ground_horizon_color = Color(0.97, 0.78, 0.64)
	sm.sky_curve = 0.13
	# A big low sun disc, sitting in the horizon band. On a course this flat
	# the sun is a landmark, and it is the one that tells you which way east is
	# on a map screen that has just stopped existing.
	sm.sun_angle_max = 12.0
	sm.sun_curve = 0.10
	sky.sky_material = sm

	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	# THESE FIVE NUMBERS WERE ALL HALVED AFTER THE FIRST RENDER. A warm sky at
	# 0.72 contribution and 1.05 energy, plus fog at 0.0075 of nearly the same
	# colour, plus a 1.45 sun, bleached the entire course to cream: the dark
	# green conifers on the treeline came back the same value as the sand. Dawn
	# is LOW-CONTRAST IN HUE and HIGH-CONTRAST IN VALUE — a bright warm key and
	# genuinely dim everything-else — and the mistake was reading "warm" as
	# "bright" and lifting the floor to match the key.
	env.ambient_light_sky_contribution = 0.55
	env.ambient_light_energy = 0.62
	env.fog_enabled = true
	env.fog_density = 0.0032
	env.fog_light_color = Color(0.97, 0.79, 0.66)
	env.fog_light_energy = 0.85
	env.fog_sky_affect = 0.16
	env.fog_aerial_perspective = 0.22
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.96
	env.tonemap_white = 3.2
	we.environment = env
	add_child(we)

	# The sun, very low, from behind and to the left of the spawn so it rakes
	# straight down the fairway toward the green.
	var sun := DirectionalLight3D.new()
	# 12 degrees, not 9. At 9 a standing goose threw a six-metre shadow and the
	# render was more shadow than fairway.
	sun.rotation_degrees = Vector3(-12.0, 24.0, 0.0)
	sun.light_energy = 1.30
	sun.light_color = Color(1.00, 0.80, 0.58)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 110.0
	sun.light_angular_distance = 0.9
	add_child(sun)

	# Warm fill from the opposite side. Shadowless, and deliberately not blue.
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-30.0, 24.0 - 180.0, 0.0)
	fill.light_energy = 0.20
	fill.light_color = Color(0.84, 0.70, 0.74)
	fill.shadow_enabled = false
	add_child(fill)


# ══════════════════════════════════════════════════════════════════ GROUND

func _ground() -> void:
	var sb := StaticBody3D.new()
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(COURSE, 1.0, COURSE)
	mi.mesh = bm
	mi.material_override = _surf(&"grass", 46.0, C_FAIRWAY)
	sb.add_child(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(COURSE, 1.0, COURSE)
	cs.shape = bs
	sb.add_child(cs)
	add_child(sb)
	sb.global_position = Vector3(0, -0.5, 0)

	# Invisible walls. Low-ish: the player can and should be able to fly, and
	# there is nothing out there, but a bird that leaves the course entirely
	# during the credits has left the ending.
	for i in 4:
		var a := float(i) * PI * 0.5
		_hide_meshes(_static_box(
			Vector3(sin(a) * COURSE * 0.5, 11.0, cos(a) * COURSE * 0.5),
			Vector3(COURSE, 30.0, 1.0), Color(1, 1, 1), a))


# ═══════════════════════════════════════════════════════════════ THE COURSE

func _course() -> void:
	# ── mowing stripes ──────────────────────────────────────────────────
	# The single most golf-course thing available for the money.
	#
	# TWO THINGS THE RENDER CHANGED. First they are TEXTURED, with the same
	# grass material as the ground under them: the first pass used flat colours,
	# and a flat-colour slab lying on a textured plane does not read as a
	# different cut of the same grass, it reads as a different material —
	# every stripe came back as a pale plastic panel. Second they cover the
	# WHOLE COURSE rather than a 74-metre box around the fairway, because the
	# edge of the striped region was plainly visible as a hard line across the
	# grass in three of the first four shots.
	for i in 23:
		var x := -71.5 + float(i) * 6.5
		var c := C_FAIRWAY.lightened(0.075) if i % 2 == 0 else C_FAIRWAY.darkened(0.055)
		_flat_tiles(Vector3(x, 0.022, 0.0), Vector3(6.3, 0.045, COURSE), 1, 6,
			&"grass", c, 5.0)

	# ── the rough, down both sides ──────────────────────────────────────
	for sx in [-1.0, 1.0]:
		var s: float = sx
		_flat_tiles(Vector3(s * 58.0, 0.030, -8.0), Vector3(30.0, 0.05, 120.0),
			3, 6, &"grass", C_ROUGH, 22.0)

	# ── the green ───────────────────────────────────────────────────────
	# Three rings: collar, fringe, putting surface. A green is the only place
	# on a golf course with a hard visual edge and it is what the whole zone
	# points at.
	# The three rings are 1.5 cm apart in Y, not 1 cm: at 1 cm the collar's rim
	# z-fought with the fringe under it and the green came back with a dashed
	# outline round the whole thing.
	_disc(GREEN_C + Vector3(0, 0.040, 0), GREEN_R + 2.6, 0.05, C_ROUGH.lightened(0.10),
		&"grass", 9.0)
	_disc(GREEN_C + Vector3(0, 0.055, 0), GREEN_R + 1.1, 0.05, C_GREEN.darkened(0.06),
		&"grass", 14.0)
	_disc(GREEN_C + Vector3(0, 0.070, 0), GREEN_R, 0.05, C_GREEN.lightened(0.09),
		&"grass", 26.0)
	# The cup, and the pin in it.
	_disc(PIN + Vector3(0, 0.098, 0), 0.30, 0.05, Color(0.05, 0.05, 0.05))
	# Scaled up by a third. A real flagstick is 2.1 m and 12 mm across, which
	# from the tee is nothing at all — and the pin is the one thing on this
	# course the whole fairway points at. The render made that decision.
	_flag = _model_at(&"flagstick", PIN + Vector3(0, 0.06, 0), 0.4,
		{"colour": Color(0.94, 0.24, 0.18)}, 1.45)
	# Two ball marks nobody repaired.
	for i in 3:
		var a := 1.1 + float(i) * 2.3
		_decal_box(PIN + Vector3(cos(a) * (2.2 + float(i)), 0.098, sin(a) * (2.6 + float(i))),
			Vector3(0.34, 0.03, 0.30), C_GREEN.darkened(0.30), a)

	# ── the bunker, unraked ─────────────────────────────────────────────
	# NO TEXTURE ON THE SAND. The first pass ran the `dirt` texture over it at
	# uv 4 and the bunker came back as a disc of brown mud with pebbles in it —
	# it read as a filled-in pond, not as sand. Bunker sand is close to a flat
	# value in this light and everything that makes it read as sand is the
	# stuff lying ON it: the footprints, the drag mark and the broken rim.
	_disc(BUNKER_C + Vector3(0, 0.036, 0), BUNKER_R + 1.5, 0.05, C_SAND.darkened(0.16))
	_disc(BUNKER_C + Vector3(0, 0.068, 0), BUNKER_R, 0.05, C_SAND)
	# UNRAKED is the entire characterisation. Footprints, a plough line where
	# somebody dragged themselves out, and a heel scuff on the lip.
	for i in 9:
		var t := float(i) / 8.0
		var p := BUNKER_C + Vector3(lerpf(-4.2, 3.6, t) + 0.5 * sin(float(i) * 2.1),
			0.086, lerpf(3.4, -3.0, t) + 0.4 * cos(float(i) * 1.7))
		_decal_box(p, Vector3(0.42, 0.03, 0.30), C_SAND.darkened(0.26), float(i) * 0.8)
	_decal_box(BUNKER_C + Vector3(0.5, 0.086, 0.4), Vector3(0.7, 0.03, 6.6),
		C_SAND.darkened(0.18), 0.35)
	# The rim, broken so the bunker isn't a circle. The first pass used the
	# shared `rock` model at 0.55 scale for this and got a ring of pale angular
	# slabs that read as broken polystyrene round a mud pit. Overlapping discs
	# of the same sand cost less and read as sand, because they ARE sand.
	for i in 7:
		var a2 := PI * (0.08 + 0.84 * float(i) / 6.0)
		var rr := 1.6 + 1.1 * absf(sin(float(i) * 2.3))
		_disc(BUNKER_C + Vector3(cos(a2) * (BUNKER_R - 0.2), 0.052,
			sin(a2) * (BUNKER_R - 0.2)), rr, 0.05,
			C_SAND.lightened(0.05 * float(i % 2)))

	# ── the cart path ───────────────────────────────────────────────────
	# Down the right-hand side and round behind the green. Built as straight
	# segments rather than a spline: nothing follows it, it is scenery, and a
	# PathFollow3D for a footpath is a node nobody will ever need again.
	var path := [
		Vector3(34.0, 0.0, 46.0), Vector3(31.0, 0.0, 8.0), Vector3(28.0, 0.0, -18.0),
		Vector3(20.0, 0.0, -40.0), Vector3(6.0, 0.0, -52.0), Vector3(-14.0, 0.0, -54.0),
	]
	for i in range(path.size() - 1):
		var a3: Vector3 = path[i]
		var b3: Vector3 = path[i + 1]
		var d := b3 - a3
		var mid := (a3 + b3) * 0.5
		_decal_box(mid + Vector3(0, 0.048, 0), Vector3(2.6, 0.05, d.length() + 1.2),
			C_PATH, atan2(d.x, d.z))
		# Cracks, one per segment, because a Florida cart path is 30 years old.
		_decal_box(mid + Vector3(0.4, 0.062, 0), Vector3(0.10, 0.03, d.length() * 0.7),
			C_PATH.darkened(0.32), atan2(d.x, d.z) + 0.06)

	# ── the tee you arrived over ────────────────────────────────────────
	_disc(Vector3(2.0, 0.046, 40.0), 7.0, 0.05, C_GREEN.darkened(0.02))
	for sx2 in [-1.0, 1.0]:
		var s2: float = sx2
		_model_at(&"golf_ball", Vector3(2.0 + s2 * 2.4, 0.06, 40.0), 0.0,
			{"colour": Color(0.86, 0.32, 0.24)}, 1.6)

	# ── 150-yard marker, because the joke writes itself ─────────────────
	_model_at(&"ball_washer", Vector3(29.0, 0.0, 4.0), 0.6)


# ══════════════════════════════════════════════════════════════════ WATER
#
# Flat. There is no depression under this pond and there does not need to be:
# the strip mall's retention pond is built exactly this way, and the goose
# controller's water state is entered from an Area3D rather than from a
# height, so a shallow disc of water over the same flat ground reads and plays
# correctly while being impossible to get stuck in.

func _water() -> void:
	# A dark basin UNDER the surface. Without something dark behind it,
	# translucent water over green grass just reads as more grass — the exact
	# failure the strip mall pond hit on its first build.
	#
	# THE HEIGHTS HERE ARE THE WHOLE OBJECT. First pass: basin centred at -0.06
	# with height 0.6, so its top face sat at +0.24 — ABOVE the water surface at
	# +0.11 — and the render came back with a perfect disc of brown mud and a
	# three-centimetre ring of blue round the outside. The basin's top must be
	# under the water's top and over the mowing stripes, in that order, and the
	# window is eight centimetres wide.
	var basin := MeshInstance3D.new()
	var bmesh := CylinderMesh.new()
	bmesh.top_radius = POND_R - 0.25
	bmesh.bottom_radius = POND_R - 2.6
	bmesh.height = 0.6
	bmesh.radial_segments = 22
	basin.mesh = bmesh
	basin.material_override = _surf(&"dirt", 5.0, Color(0.13, 0.17, 0.15))
	add_child(basin)
	basin.global_position = POND_C + Vector3(0, -0.24, 0)   ## top face at +0.06

	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.16, 0.34, 0.42, 0.78)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.05
	m.metallic = 0.6
	if _tex != null:
		var nrm: Texture2D = _tex.get_tex(&"water_normal")
		if nrm != null:
			m.normal_enabled = true
			m.normal_texture = nrm
			m.normal_scale = 0.7
			m.uv1_scale = Vector3(7.0, 7.0, 7.0)
	var surf := _disc(POND_C + Vector3(0, 0.16, 0), POND_R, 0.22, Color.WHITE)
	surf.material_override = m

	# The swimmable volume. Top at 0.62, which is above a standing bird's
	# origin (0.46) and well below a flying one — you have to come down to it.
	var water := Area3D.new()
	water.add_to_group("water")
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = POND_R
	sh.height = 1.4
	cs.shape = sh
	water.add_child(cs)
	water.monitoring = false
	add_child(water)
	water.global_position = POND_C + Vector3(0, -0.08, 0)

	# Cattails round the near edge only, so the far side stays open and the
	# fountain has a clean silhouette against the mist.
	for i in 18:
		var a := PI * (0.05 + 1.15 * float(i) / 17.0)
		var r := POND_R + 0.5 + 0.7 * sin(float(i) * 2.3)
		_model_at(&"cattail", POND_C + Vector3(cos(a) * r, 0.0, sin(a) * r),
			float(i) * 1.3, {}, 0.85 + 0.3 * absf(sin(float(i) * 1.9)))

	_model_at(&"fountain", POND_C + Vector3(1.5, 0.05, -1.0), 0.0, {}, 1.5)


# ═══════════════════════════════════════════════════════════════ PLANTING

func _planting() -> void:
	# Palms. Two rows down the outside of the fairway plus a clump behind the
	# green, so there is always one in frame and the low sun always has
	# something to throw a shadow off.
	var palms := [
		Vector3(-34.0, 0, 30.0), Vector3(-38.0, 0, 12.0), Vector3(-36.0, 0, -6.0),
		Vector3(-40.0, 0, -26.0), Vector3(-30.0, 0, -46.0), Vector3(-12.0, 0, -56.0),
		Vector3(38.0, 0, 34.0), Vector3(42.0, 0, 14.0), Vector3(39.0, 0, -8.0),
		Vector3(44.0, 0, -30.0), Vector3(34.0, 0, -48.0), Vector3(14.0, 0, -58.0),
		LAP_PALM, LAP_PALM_2, Vector3(-20.0, 0, 26.0), Vector3(26.0, 0, 24.0),
	]
	for i in palms.size():
		var p: Vector3 = palms[i]
		_model_at(&"palm", p, float(i) * 1.37,
			{"variant": float(i) * 2.1}, 0.86 + 0.26 * absf(sin(float(i) * 1.7)))

	# Live oaks with moss on them. Two, both off to the side, both enormous —
	# the moss is the thing that says Florida rather than California, and it
	# only reads if the tree it hangs off is big enough to hang it from.
	for i in 2:
		var pos := Vector3(-46.0 + float(i) * 92.0, 0.0, -2.0 - float(i) * 22.0)
		_model_at(&"tree_deciduous", pos, float(i) * 2.2,
			{"colour": Color(0.30, 0.26, 0.20), "leaf_colour": Color(0.22, 0.34, 0.19)},
			1.9)
		# THE MOSS MODEL IS BASE-ANCHORED LIKE EVERYTHING ELSE, which means it
		# occupies y 0.4 to 2.9 ABOVE wherever you put it — it does not hang
		# DOWN from its origin. The first pass put it at y = 5.4 expecting it to
		# fall from there, and the render came back with two bundles of pale
		# vertical sticks floating a clear two metres OVER the tops of the oaks.
		# The placement height is therefore (canopy underside) - 2.9 * scale.
		for k in 5:
			var a := TAU * float(k) / 5.0 + float(i)
			_model_at(&"spanish_moss", pos + Vector3(cos(a) * 4.4, 2.2, sin(a) * 4.4),
				a, {"variant": float(i) * 3.0 + float(k)}, 1.5)

	# The treeline: a wall of dark palms and conifers around the edge, which is
	# what stops the course reading as a plane that stops. It WRAPS DOWN BOTH
	# SIDES as well as across the far end — the first render had a clean line
	# of trees ahead and the bare cut edge of the ground plane to the left and
	# right of it.
	for i in 44:
		var x := 0.0
		var z := 0.0
		if i < 22:
			x = -70.0 + float(i) * 6.4 + 2.0 * sin(float(i) * 2.3)
			z = -72.0 + 2.5 * cos(float(i) * 1.9)
		else:
			var k := i - 22
			var side := -1.0 if k < 11 else 1.0
			x = side * (70.0 - 2.4 * absf(cos(float(k) * 1.7)))
			z = -62.0 + float(k % 11) * 13.0 + 2.0 * sin(float(k) * 2.1)
		if i % 3 == 0:
			_model_at(&"palm", Vector3(x, 0, z), float(i) * 0.7,
				{"variant": float(i) * 1.3, "colour": Color(0.34, 0.30, 0.25),
				"trim_colour": Color(0.19, 0.29, 0.16)}, 0.9)
		else:
			_model_at(&"tree_conifer", Vector3(x, 0, z), float(i) * 1.1,
				{"colour": Color(0.24, 0.21, 0.17), "leaf_colour": Color(0.17, 0.26, 0.16)},
				1.2 + 0.35 * absf(sin(float(i) * 2.7)))


func _clubhouse() -> void:
	# In the middle distance, past the green, on the far side of the cart path.
	# You cannot reach anything about it and you never need to. It is scale.
	var n := Node3D.new()
	add_child(n)
	n.global_position = CLUBHOUSE
	n.rotation.y = -0.35
	PROPS.build(&"house", n, {
		"w": 26.0, "d": 15.0, "wall_h": 4.4, "roof_h": 2.6,
		# `wall_colour`, not `colour` — prop_models.gd::_house names it that and
		# silently keeps its beige default for anything else.
		"wall_colour": Color(0.95, 0.94, 0.90),
		"roof_colour": Color(0.40, 0.34, 0.30),
	})
	# A verandah: a canopy on eight posts along the fairway side.
	for i in 8:
		var x := -11.0 + float(i) * 3.1
		var p := CLUBHOUSE + Vector3(x, 0, 9.2).rotated(Vector3.UP, -0.35)
		_decal_box(p + Vector3(0, 1.5, 0), Vector3(0.16, 3.0, 0.16), Color(0.88, 0.87, 0.83))
	var canopy := _decal_box(CLUBHOUSE + Vector3(0, 3.15, 8.6).rotated(Vector3.UP, -0.35),
		Vector3(26.0, 0.22, 4.4), Color(0.88, 0.86, 0.82))
	canopy.rotation.y = -0.35
	# The one bit of the clubhouse the player will actually look at: a row of
	# parked carts under the canopy.
	for i in 4:
		var cp := CLUBHOUSE + Vector3(-8.0 + float(i) * 4.2, 0, 12.5).rotated(Vector3.UP, -0.35)
		_model_at(&"golf_cart", cp, -0.35 + 0.06 * float(i))


# ═════════════════════════════════════════════════════════════ SPRINKLERS
#
# "Florida. The promised land. Sprinklers forever." Taken literally: sixteen
# heads, every one of them running, and NOTHING in this zone ever turns them
# off — not the settling, not the honk wave, not the credits, not the end of
# the credits. They are the loudest thing in the ending and they are still
# going when the player finally puts the pad down.

func _sprinklers() -> void:
	var spots := [
		Vector3(-8.0, 0, 26.0), Vector3(12.0, 0, 22.0), Vector3(-18.0, 0, 14.0),
		Vector3(22.0, 0, 6.0), Vector3(-6.0, 0, 2.0), Vector3(6.0, 0, -10.0),
		Vector3(-20.0, 0, -22.0), Vector3(18.0, 0, -14.0), Vector3(-2.0, 0, -22.0),
		Vector3(-14.0, 0, -44.0), Vector3(10.0, 0, -46.0), Vector3(26.0, 0, -34.0),
		Vector3(-30.0, 0, -36.0), Vector3(30.0, 0, -2.0), Vector3(-34.0, 0, 2.0),
		Vector3(2.0, 0, 14.0),
	]
	for i in spots.size():
		var p: Vector3 = spots[i]
		# The wet patch. Darker grass in a ring, which is what actually sells a
		# sprinkler from thirty metres — the fan is small and the stain is not.
		_disc(p + Vector3(0, 0.012, 0), 6.4, 0.03, C_FAIRWAY.darkened(0.18))
		_model_at(&"sprinkler", p)
		var fan := _model_at(&"spray_fan", p + Vector3(0, 0.02, 0), float(i) * 0.9)
		# Each one turns at its own rate and its own phase, so the course never
		# pulses in unison — which is what happens if you drive them all off one
		# clock and it reads as a screensaver.
		fan.set_meta("rate", 0.42 + 0.30 * absf(sin(float(i) * 2.1)))
		fan.set_meta("phase", float(i) * 1.31)
		_spray.append(fan)


# ═══════════════════════════════════════════════════════════ THINGS TO RUIN
#
# Not many, and none of them scored. The chaos counter does not exist in this
# zone; what these are for is that a goose walking onto a golf course at dawn
# should find the same amount of stuff lying around as it found in every
# parking lot on the way here, and it should still be able to knock it over.

func _props() -> void:
	# The cooler four residents are standing around. Open, and empty.
	_prop(COOLER_C + Vector3(0, 0.27, 0), Vector3(0.80, 0.54, 0.48),
		Color(0.86, 0.88, 0.90), 6.0, 0, "COOLER", &"cooler")
	# The golf ball two of them are arguing over. Inert. Heavy enough that a
	# honk moves it about a metre, which is exactly long enough to be funny.
	_prop(BALL + Vector3(0, 0.05, 0), Vector3(0.10, 0.10, 0.10),
		Color(0.96, 0.96, 0.93), 0.9, 0, "BALL", &"golf_ball")
	# Chairs and a bin by the tee.
	_prop(Vector3(7.0, 0.45, 36.0), Vector3(0.60, 0.90, 0.60),
		Color(0.90, 0.90, 0.86), 4.0, 0, "PATIO CHAIR", &"patio_chair")
	_prop(Vector3(9.2, 0.45, 34.0), Vector3(0.60, 0.90, 0.60),
		Color(0.90, 0.90, 0.86), 4.0, 0, "PATIO CHAIR", &"patio_chair")
	_prop(Vector3(-4.0, 0.60, 33.0), Vector3(1.00, 1.20, 0.80),
		Color(0.24, 0.34, 0.26), 12.0, 0, "BIN", &"recycling_bin")
	# A bench beside the pond that somebody has already left a two-four under.
	_prop(Vector3(-15.0, 0.42, -4.0), Vector3(1.80, 0.85, 0.62),
		Color(0.58, 0.46, 0.32), 24.0, 0, "BENCH", &"bench")
	_prop(Vector3(-15.8, 0.20, -2.8), Vector3(0.56, 0.40, 0.38),
		Color(0.72, 0.24, 0.22), 5.0, 0, "TWO-FOUR", &"two_four")


# ═══════════════════════════════════════════════════════════════ THE GEESE
#
# One builder, one ticker, a behaviour tag per bird. Forked from
# flock_pen.gd::_build() exactly as the spec asks, minus everything the pen
# does that the ending must not: no state labels, no condition colours, no
# [G] prompt, no designation, no targeted share. A resident is a goose with a
# job and no interface.
#
# DELIBERATELY NOT PHYSICAL — same reason as the pen. A StaticBody goose is a
# bollard you get wedged behind and a RigidBody goose is a thing you punt
# across the green. They are ghosts you walk among.

func _model_path() -> String:
	var key := "lowpoly"
	var prefs := get_node_or_null("/root/Prefs")
	if prefs != null:
		key = str(prefs.get_pref(&"goose_model", "lowpoly"))
	if not MODEL_SCRIPTS.has(key):
		key = "lowpoly"
	var path: String = MODEL_SCRIPTS[key]
	return path


func _make_goose(pos: Vector3, yaw: float, mode: StringName, extra := {}) -> Dictionary:
	var root := Node3D.new()
	add_child(root)
	root.global_position = pos + Vector3(0, STAND_HEIGHT, 0)
	root.rotation.y = yaw

	var model_script: GDScript = load(_model_path())
	var visual: Node3D = model_script.new()
	visual.name = "Visual"
	root.add_child(visual)

	var rec := {
		"root": root,
		"visual": visual,
		"neck": visual.get("neck"),
		"mode": mode,
		"home": pos,
		"target": pos,
		"heading": yaw,
		"phase": randf() * TAU,
		"wander": randf_range(1.0, 4.0),
		"speed": 0.0,
		"flap": 0.0,
		"airborne": false,
		"cd": randf_range(2.0, 9.0),
		"is_survivor": false,
		"index": -1,
		"name": "",
	}
	for k in extra:
		rec[k] = extra[k]
	_geese.append(rec)
	return rec


## Thirty geese who were here before you, doing exactly what you have been
## doing for forty-five minutes. None of them react to the player: they do not
## stop, they do not look up, they do not have dialogue. That non-reaction is
## the joke and it is also the point — you have arrived somewhere that was
## already like this before you got here.
func _residents() -> void:
	# 1 — asleep in the bunker, on its back, feet up.
	_make_goose(BUNKER_C + Vector3(-1.2, 0.0, 1.0), 1.9, &"sleep_back")

	# 2 — on the cart, one at the wheel, driving slow circles forever.
	_cart = Node3D.new()
	add_child(_cart)
	_cart.global_position = Vector3(0, 0, 16.0)
	GREEN.build(&"golf_cart", _cart)
	var driver := _make_goose(Vector3.ZERO, 0.0, &"riding")
	var pass1 := _make_goose(Vector3.ZERO, 0.0, &"riding")
	# Y is (surface height + STAND_HEIGHT), not the surface height: the goose
	# visual's origin is at the hips and its feet are 0.46 below that. The first
	# pass put both birds at 0.66 and they were standing knee-deep in the floor
	# pan. The driver stands on the pan at the wheel; the passenger is up on the
	# bench, which is the only way you can tell there are two of them.
	_reparent_to(driver, _cart, Vector3(-0.22, 0.33 + STAND_HEIGHT, -0.34), 0.0)
	_reparent_to(pass1, _cart, Vector3(0.28, 0.66 + STAND_HEIGHT, 0.34), -0.6)

	# 1 — standing in the water hazard. Not swimming. Standing.
	_make_goose(POND_C + Vector3(-3.0, 0.0, 2.5), 2.4, &"stand")

	# 4 — clustered around a cooler that is open and empty.
	for i in 4:
		var a := TAU * float(i) / 4.0 + 0.9
		_make_goose(COOLER_C + Vector3(cos(a) * 2.0, 0.0, sin(a) * 2.0), a + PI, &"graze")

	# 1 — on the clubhouse roof, honking at nothing, every nine seconds.
	_make_goose(CLUBHOUSE + Vector3(-2.0, 5.6, 3.0), 2.9, &"roof")

	# 1 — doing laps of the same palm tree, in one direction, indefinitely.
	_make_goose(LAP_PALM + Vector3(3.2, 0, 0), 0.0, &"lap",
		{"pivot": LAP_PALM, "radius": 3.2, "rate": 0.30, "angle": 0.0})

	# 2 — fighting over a golf ball. The ball is inert. They keep at it.
	_make_goose(BALL + Vector3(-1.1, 0, 0.2), PI * 0.5, &"fight", {"pivot": BALL})
	_make_goose(BALL + Vector3(1.1, 0, -0.2), -PI * 0.5, &"fight", {"pivot": BALL})

	# 1 — wearing a tiny high-vis vest. A retired designated driver.
	var retired := _make_goose(Vector3(-6.5, 0, 12.0), 2.2, &"graze")
	_wear_vest(retired)

	# 1 — standing at the far edge of the course, facing north, in the idle
	# pose of the goose you were on leg 1. It is looking back up the flyway.
	_make_goose(NORTHWARD, PI, &"stand")

	# ~16 — grazing, preening, arguing, asleep. The Stopover crowd, reused.
	var crowd := [
		Vector3(-12.0, 0, 20.0), Vector3(-4.0, 0, 24.0), Vector3(16.0, 0, 16.0),
		Vector3(24.0, 0, 0.0), Vector3(-22.0, 0, 4.0), Vector3(-28.0, 0, -4.0),
		Vector3(-18.0, 0, -26.0), Vector3(-8.0, 0, -30.0), Vector3(4.0, 0, -28.0),
		Vector3(11.0, 0, -34.0), Vector3(-6.0, 0, -44.0), Vector3(20.0, 0, -44.0),
		Vector3(-32.0, 0, -18.0), Vector3(32.0, 0, -22.0), Vector3(14.0, 0, 30.0),
		Vector3(-24.0, 0, 32.0),
	]
	for i in crowd.size():
		var p: Vector3 = crowd[i]
		var mode: StringName = &"graze"
		if i % 5 == 3:
			mode = &"sleep"
		elif i % 5 == 1:
			mode = &"preen"
		_make_goose(p, float(i) * 1.9, mode)


## Hang the flock pen's own hi-vis vest on a bird.
##
## Reached for rather than re-modelled: this vest is the one the player's own
## Designated Driver has been wearing for six legs, and the retired DD standing
## on the eighteenth green is only a joke if it is visibly THE SAME VEST.
## `_make_vest()` builds a mesh and touches nothing else, so calling it on an
## orphan pen that never enters the tree is safe — `_ready()` only runs on
## entry. Guarded, so if the pen ever renames it the bird is simply a bird.
func _wear_vest(rec: Dictionary) -> void:
	var pen: Node = FLOCK_PEN.new()
	if not pen.has_method("_make_vest"):
		pen.free()
		return
	var vest = pen.call("_make_vest")
	pen.free()
	if not (vest is Node3D):
		return
	var visual: Node3D = rec["visual"]
	var host: Node3D = visual
	var body = visual.get("body")
	if body is Node3D:
		host = body
	host.add_child(vest)


## Move a built goose onto a moving parent (the cart) and stop the ticker
## touching its position.
func _reparent_to(rec: Dictionary, host: Node3D, offset: Vector3, yaw: float) -> void:
	var root: Node3D = rec["root"]
	root.get_parent().remove_child(root)
	host.add_child(root)
	root.position = offset
	root.rotation.y = yaw


# ══════════════════════════════════════════════════════════ YOUR SURVIVORS
#
# THE MOST IMPORTANT THING IN THE ZONE. Everyone still in the flock is here,
# physically, by name, with their scars, and everyone who isn't is named in the
# credits instead. The whole flock system pays off here or nowhere.

func _survivor_flight() -> void:
	var raw: Array = Flock.birds
	var dd: int = int(Flock.designated_driver())
	var order: Array[int] = []
	for i in raw.size():
		var rec: Dictionary = raw[i]
		if bool(rec.get("alive", true)):
			order.append(i)
	if order.is_empty():
		return

	# They come in low over the treeline behind the tee, in the loose line a
	# flock actually lands in — not the V. The V is over.
	var n := order.size()
	for slot in n:
		var index: int = order[slot]
		var bird: Dictionary = raw[index]
		var lane := (float(slot) - float(n - 1) * 0.5) * 3.4
		var land := Vector3(lane * 1.15 + 1.0, 0.0, 9.0 + 1.6 * absf(lane) * 0.3)
		var start := Vector3(lane * 0.8 + 1.0, 15.0, 44.0 + float(slot) * 2.0)
		var rec2 := _make_goose(start, PI, &"arrive", {
			"is_survivor": true,
			"index": index,
			"name": str(bird.get("name", "?")),
			"scars": int(bird.get("scars", 0)),
			"is_dd": index == dd,
			"from": start,
			"land": land,
			"t0": 1.2 + float(slot) * 0.55,
			"dur": 4.4,
			"clock": 0.0,
		})
		var root: Node3D = rec2["root"]
		root.global_position = start
		_survivors.append(rec2)

	# The DD settles last and never joins anybody, so it goes to the back of
	# the queue. One `if`. It is the payment for six legs of restraint and it
	# is the best thing the DD mechanic will ever do.
	_survivors.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["is_dd"]) < int(b["is_dd"]))


## Where the settling survivors go, in order. Each is a resident who is
## already doing the thing, which is the point: they do not start something
## new, they join something that was already happening.
func _settle_spot(i: int) -> Dictionary:
	var spots := [
		{"pos": BUNKER_C + Vector3(0.6, 0, 2.0), "mode": &"sleep"},
		{"pos": Vector3(0, 0, 0), "mode": &"riding"},
		{"pos": POND_C + Vector3(-1.4, 0, 3.4), "mode": &"stand"},
		{"pos": COOLER_C + Vector3(1.4, 0, -1.3), "mode": &"graze"},
		{"pos": LAP_PALM_2 + Vector3(-3.0, 0, 0), "mode": &"lap"},
		{"pos": BALL + Vector3(0.2, 0, 1.6), "mode": &"fight"},
		{"pos": NORTHWARD + Vector3(2.2, 0, 0.6), "mode": &"stand"},
	]
	var s: Dictionary = spots[i % spots.size()]
	return s


# ══════════════════════════════════════════════════════════════ THE PLAYER

func _spawn_goose() -> void:
	goose = Goose.new()
	goose.name = "Goose"
	add_child(goose)
	# On the fairway, short of the tee, facing down the course at the green.
	# The camera rig starts at yaw 0 looking toward -Z, so this is the frame
	# the ending opens on: mown grass, sprinklers, the pin, the clubhouse, and
	# thirty geese who were already here.
	goose.global_position = Vector3(1.0, 0.8, 16.0)
	goose.heading = 0.0
	goose.rotation.y = 0.0

	camera_rig = preload("res://scripts/goose/goose_camera.gd").new()
	camera_rig.name = "CameraRig"
	camera_rig.target = goose
	# "The camera pulls back slightly further than the zone rig's default and
	# stays there." Beat 1. It is the only camera instruction in the ending and
	# it is two numbers.
	camera_rig.distance = 8.4
	camera_rig.height = 2.7
	add_child(camera_rig)
	goose.cam = camera_rig

	# NO SHAKE WIRING HERE. Juice owns the shake bus and the goose controller
	# drives it; a zone that also connects landed/tumbled shakes the camera
	# twice for one landing and bypasses the screen_shake accessibility pref.


# ══════════════════════════════════════════════════════════════════════ UI
#
# There are exactly two pieces of interface in the ending and both of them
# leave. The route pin, which names the place once and fades; and [ESC], which
# only appears after the credits have finished and is the only thing in the
# game that ever tells you the game is over — by not saying so.

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.name = "FinaleUI"
	_ui.layer = 4
	add_child(_ui)

	_pin_label = Label.new()
	_pin_label.text = zone_title()
	_pin_label.add_theme_font_size_override("font_size", 26)
	_pin_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.86))
	_pin_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_pin_label.add_theme_constant_override("outline_size", 8)
	_pin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# TOP_WIDE, not CENTER_TOP: CENTER_TOP anchors both edges at 0.5, so a
	# centre-aligned label inside it centres itself in the right-hand half of
	# the screen. The first render put the only words in the ending a hundred
	# pixels off centre.
	_pin_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_pin_label.offset_top = 54.0
	_pin_label.offset_bottom = 96.0
	_pin_label.modulate = Color(1, 1, 1, 0)
	_ui.add_child(_pin_label)

	_esc_label = Label.new()
	_esc_label.text = "[ESC]"
	_esc_label.add_theme_font_size_override("font_size", 15)
	_esc_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.90, 0.5))
	_esc_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_esc_label.offset_left = -78.0
	_esc_label.offset_top = -40.0
	_esc_label.modulate = Color(1, 1, 1, 0)
	_ui.add_child(_esc_label)

	# The pin fades up two seconds after you land, holds, and goes. Named once,
	# as the last route pin, exactly as the spec asks — and then the corner is
	# empty for the rest of the game.
	var tw := create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(_pin_label, "modulate:a", 1.0, 1.1)
	tw.tween_interval(4.6)
	tw.tween_property(_pin_label, "modulate:a", 0.0, 2.2)


# ═══════════════════════════════════════════════════════════════ THE HONK
#
# Beat 4. The one sincere moment in Geeked Geese is a sound effect.
#
# There is one thing to do and nothing tells you to do it. When the player
# honks anywhere, every goose on the course honks back — once, in a ragged
# wave from nearest to furthest, over about two and a half seconds, including
# the ones asleep, including the one on the cart, including the one in the
# water. Then it is quiet again, except for the sprinklers.
#
# It can be re-triggered. It should be. It is slightly quieter each time for
# the first three, then settles. A player who honks eleven times has
# understood the game.
#
# `_input` rather than `_unhandled_input`, and it never marks the event
# handled: the goose's own honk MUST still fire. This only listens.

func _input(e: InputEvent) -> void:
	if goose == null or not is_instance_valid(goose):
		return
	if e.is_action_pressed("gg_honk") and _wave_cd <= 0.0:
		_honk_wave()


func _honk_wave() -> void:
	_wave_cd = 3.2
	_wave_count += 1
	_last_wave_t = _t
	# Quieter each time for the first three, then it settles. Not silent —
	# a course that stops answering is a course that got bored of you.
	var step := mini(_wave_count - 1, 3)
	## Array elements are Variant, so this needs the annotation — see CLAUDE.md.
	var trim: float = [0.0, -2.5, -4.5, -5.5][step]

	var here := goose.global_position
	var far := 1.0
	for g in _geese:
		var gr: Node3D = g["root"]
		if is_instance_valid(gr):
			far = maxf(far, gr.global_position.distance_to(here))

	for g2 in _geese:
		var rec: Dictionary = g2
		var root: Node3D = rec["root"]
		if not is_instance_valid(root):
			continue
		var d := root.global_position.distance_to(here)
		# Ragged, not a sweep: the jitter is what makes forty geese sound like
		# forty geese rather than like one delay line.
		var delay := (d / far) * WAVE_SPAN + randf_range(-0.16, 0.22)
		var mode: StringName = rec["mode"]
		var pitch := randf_range(0.88, 1.16)
		# The sleeping ones answer too, and they sound like it.
		if mode == &"sleep" or mode == &"sleep_back":
			pitch *= 0.72
			delay += 0.35
		_honk_queue.append({
			"t": maxf(delay, 0.0),
			"node": root,
			"db": trim - 4.0 - clampf(d * 0.10, 0.0, 8.0),
			"pitch": pitch,
		})


func _tick_honks(dt: float) -> void:
	if _honk_queue.is_empty():
		return
	var i := _honk_queue.size() - 1
	while i >= 0:
		var e: Dictionary = _honk_queue[i]
		var t: float = float(e["t"]) - dt
		if t <= 0.0:
			var node = e["node"]
			if is_instance_valid(node) and _sfx != null:
				var keys := [&"honk_a", &"honk_b", &"honk_c"]
				_sfx.play_at(keys[randi() % keys.size()], node,
					float(e["db"]), float(e["pitch"]))
			_honk_queue.remove_at(i)
		else:
			e["t"] = t
		i -= 1


# ═══════════════════════════════════════════════════════════════ THE ROLL
#
# Beat 5. The credits, and you are still playing.
#
# The player never loses control. The credits come up the fairway as physical,
# honkable, knockable slabs that pass the camera and keep going. You can land
# on them. You can honk them over. You can run through them, and if you hit
# one hard enough it breaks like every other prop in the game, with the same
# particles and the same sound.
#
# THEY DO NOT AWARD CHAOS. There is no chaos counter any more, which is why
# CreditSlab overrides the one place ChaosProp talks to the score — see the
# class below. A "+240" floating over your own roster would undo the entire
# ending for the price of one line nobody removed.
#
# The player can wreck all of it, including their own roster. That is
# permitted and it is the tone.

## A credit. A ChaosProp in every respect except that it walks, and that it is
## worth nothing.
class CreditSlab extends CHAOS_PROP:
	## Set false the moment anything touches it: after that it is furniture,
	## and physics owns it.
	var driving := true
	var speed := 2.15

	## THE DRIVE LIVES IN `_integrate_forces`, AND THAT IS THE WHOLE FIX.
	##
	## Two attempts got this wrong before, both by treating it as a NUMBER
	## problem. The first ramped `linear_velocity` from `_physics_process` at
	## 8 m/s², which lost to contact friction and settled the roll at about
	## 0.31 m/s instead of 2.15 — the whole thing piled into a wall 40 m short of
	## the camera. The second raised the ramp to 24 m/s² and it barely helped,
	## because the ramp was never the problem:
	##
	## **Writing `linear_velocity` from `_physics_process` is the wrong API for a
	## RigidBody3D.** That write lands BEFORE the physics step; the solver then
	## runs gravity, friction and contact resolution on top of it and takes most
	## of it straight back out. Raising the ramp just means losing a bigger
	## number every tick. `_integrate_forces()` runs INSIDE the step with the
	## body's real `PhysicsDirectBodyState3D`, and a velocity written there is
	## the velocity the body has.
	##
	## Measured symptom of getting it wrong, so the next person can recognise it:
	## the first credit reaches the camera around six minutes in instead of two,
	## and the slabs arrive BUNCHED and out of order — followers catch the
	## leaders, shove them, and `release()` tips them over, so the roster line
	## about the goose who did not make it can land sideways next to a stage
	## credit.
	func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
		if not driving:
			return
		# Steer, don't push. A force would fight grass friction and arrive at a
		# different speed on every slab; setting the state's velocity gives forty
		# credits that hold formation until something hits one.
		var lv := state.linear_velocity
		lv.x = 0.0
		lv.z = speed
		state.linear_velocity = lv

	func _physics_process(delta: float) -> void:
		# CHAIN IT. ChaosProp ticks its score cooldown in _physics_process, and
		# GDScript does not chain virtuals — this override replaced it outright,
		# so a slab that had been knocked over scored once and then went silent
		# for the rest of the roll. The base class's comment now says this too.
		super(delta)
		if driving and global_position.z > 34.0:
			queue_free()

	func release() -> void:
		if not driving:
			return
		driving = false
		# Furniture from here, so let it doze once it settles — see the note at
		# the spawn site for why a DRIVING slab must not.
		can_sleep = true
		# Let it fall over. Locked upright while it drives, because a slab that
		# tips on its own before the player has touched it reads as a bug.
		axis_lock_angular_x = false
		axis_lock_angular_z = false

	func shove(impulse: Vector3) -> void:
		release()
		super(impulse)

	func hit(force: float, impulse: Vector3) -> void:
		release()
		super(force, impulse)

	## ChaosProp's version, minus the one line that scores. Everything else —
	## the cooldown, the impact sound, the tier-1 shake, the pop, the break
	## threshold — is deliberately identical, because a credit that behaves
	## differently from a recycling bin is a credit the player stops trusting
	## as an object.
	func _maybe_score(force: float) -> void:
		if _cooldown > 0.0 or _broken:
			return
		if force < 2.5:
			return
		_cooldown = 0.6
		if _sfx:
			_sfx.play_at(_impact_sound(), self, clampf(-14.0 + force, -14.0, 0.0),
				randf_range(0.9, 1.12))
		Juice.shake(clampf(force / 45.0, 0.04, 0.30))
		var vis: Node3D = _visual
		if vis != null and is_instance_valid(vis):
			Juice.pop(vis, 0.16, 0.15)
		if breakable and force >= break_force:
			_break()


func _spawn_credit(line: String) -> void:
	var text := line.strip_edges()
	var slab := CreditSlab.new()
	add_child(slab)
	slab.speed = CREDIT_SPEED
	# A credit's slab is as wide as the credit is long, so a two-word line is a
	# kerbstone and the roster line about the goose who did not make it is two
	# and a half metres of marble.
	var w: float = clampf(0.148 * float(text.length()) + 1.1, 2.0, 9.0)
	var h: float = 1.05
	var size := Vector3(w, h, 0.30)
	# points = 0 is belt and braces: _maybe_score() is overridden and _break()'s
	# own Game.score() call gets multiplied by it, so the run total the slabs
	# are PRINTING can never be changed by knocking them down.
	slab.points = 0
	slab.break_force = 8.0
	slab.setup(size, Color(0.92, 0.91, 0.87), 16.0, 0, text.substr(0, 22))
	_hide_meshes(slab)
	var model: Node3D = GREEN.build(&"credit_slab", slab, {"w": w, "h": h})
	model.position.y = -h * 0.5
	slab._visual = model
	slab.axis_lock_angular_x = true
	slab.axis_lock_angular_z = true
	slab.linear_velocity = Vector3(0, 0, CREDIT_SPEED)
	# A SLEEPING BODY GETS NO `_integrate_forces`, AND THAT IS HOW A ROLL STOPS.
	#
	# `ChaosProp._ready()` sets `can_sleep = true`, which is right for a shopping
	# cart that has come to rest and wrong for a slab whose whole job is to keep
	# moving. A driving credit that dozes on the fairway never receives another
	# integrate callback, so it simply parks — and the slabs behind it arrive,
	# shove it, `release()` it, and the roll turns into a pile. `release()` hands
	# sleeping back the moment the player touches one, because after that it IS
	# furniture and dozing is exactly what it should do.
	slab.can_sleep = false

	# The text, parented to the MODEL rather than to the body, so _break()
	# hides the name in the same frame it hides the marble.
	var lbl := Label3D.new()
	lbl.text = text
	lbl.font_size = 64
	# Sized from the slab, not fixed: every line ends up the same height on
	# screen and every slab is exactly full of its own credit.
	lbl.pixel_size = (w - 0.34) / maxf(float(text.length()) * 64.0 * 0.52, 1.0)
	lbl.modulate = Color(0.16, 0.16, 0.18)
	lbl.shaded = false
	lbl.double_sided = false
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector3(0, h * 0.55, 0.17)
	model.add_child(lbl)

	slab.global_position = Vector3(randf_range(-9.0, 9.0), h * 0.5 + 0.02, CREDIT_START_Z)


## Everything the run was, as objects. The order is the spec's: the verdict,
## the route, the roster, the distance, the Almanac, then the credits.
##
## THERE IS NO GRADE, NO PERCENTAGE AND NO "COMPLETION" ANYWHERE IN HERE. The
## chaos total appears exactly once, as a number, in a list of facts next to
## how far you flew — which is the difference between a fact and a score.
func _compose_credits() -> Array[String]:
	var out: Array[String] = []
	var raw: Array = Flock.birds
	var dd: int = int(Flock.designated_driver())
	var alive := 0
	for b in raw:
		var rec: Dictionary = b
		if bool(rec.get("alive", true)):
			alive += 1

	# ── the verdict. One sentence, the only authored sentence in the ending.
	if alive >= 6:
		out.append("EVERYONE MADE IT. STATISTICALLY, THIS DOES NOT HAPPEN.")
	elif alive >= 4:
		out.append("MOST OF YOU MADE IT.")
	elif alive >= 2:
		out.append("SOME OF YOU MADE IT.")
	else:
		out.append("YOU MADE IT.")
	# And if the DD is alive, one more. If the DD did not make it, there is no
	# line at all. Implication.
	if dd >= 0 and dd < raw.size():
		var d: Dictionary = raw[dd]
		var dn := str(d.get("name", "?")).to_upper()
		out.append("%s NEVER TOUCHED A THING." % dn)
		out.append("%s IS STANDING RIGHT THERE." % dn)

	# ── the route.
	out.append("")
	out.append("THE FLYWAY")
	for i in ROUTE_KM.size():
		var leg: Array = ROUTE_KM[i]
		var nm: String = leg[0]
		var km: int = leg[1]
		if km > 0:
			out.append("%d.  %s  ·  %d KM" % [i + 1, nm, km])
		else:
			out.append("%d.  %s" % [i + 1, nm])

	# ── the roster. Every goose, alive or not.
	out.append("")
	out.append("WHO CAME")
	for i in raw.size():
		var rec2: Dictionary = raw[i]
		var nm2 := str(rec2.get("name", "?")).to_upper()
		var scars: int = int(rec2.get("scars", 0))
		var pips := ""
		if scars > 0:
			pips = " " + "·".repeat(mini(scars, 3))
		if not bool(rec2.get("alive", true)):
			# NOT a death. A bird that could not keep up lands and winters where
			# it fell, and the copy must never imply otherwise — see the spec's
			# two loss channels. Without a recorded leg and cause on the flock
			# record there is no honest way to say where, so it says where they
			# are relative to here, which is true of every one of them.
			out.append("%s%s   somewhere north of here" % [nm2, pips])
		elif i == dd:
			out.append("%s%s   arrived · designated driver" % [nm2, pips])
		else:
			out.append("%s%s   arrived" % [nm2, pips])

	# ── the facts. Distance, then chaos. Both are numbers, neither is a score.
	out.append("")
	out.append("2,270 KM FLOWN")
	out.append("1,850 KM IN A STRAIGHT LINE")
	out.append("THE DIFFERENCE IS MUSKOKA")
	out.append("%s CHAOS" % _thousands(Game.chaos))

	# ── the Almanac itself, as objects.
	#
	# NO COUNTER. There used to be a `YOU FOUND 6 OF 16` slab here and it is the
	# one thing this section may not be. The lines above it — 2,270 km flown, the
	# chaos total — are facts about the JOURNEY, and the register the ending is
	# written in tolerates those. `6 OF 16` is a completion score about the
	# PLAYER, and a completion score at the end of a forty-five minute run is an
	# invitation to go back and farm the other ten, which is the exact reading
	# docs/FINALE_NOTES.md and CAMPAIGN_SPEC §9.4 exist to refuse.
	#
	# What survives is better and says more: one slab per thing you actually
	# found, naming what it actually was, plus the two absences below that are
	# funny enough to state out loud. A player who found six walks through six
	# and is told nothing about the ten. That IS the number, and nobody had to
	# print it.
	_almanac_section(out)

	# ── and the credits.
	out.append("")
	for line in CREDITS:
		out.append(str(line))
	return out


## THE ALMANAC, MADE PHYSICAL.
##
## The problem this solves: sixteen substances carry a true, sourced fact each,
## and until now the epilogue did not know the player had found any of them
## except as a tally three slabs earlier.
##
## The binding constraint is CAMPAIGN_SPEC §9.4 — discovery must not gate,
## branch or reward the ending, because the moment a true fact is something you
## *earn* the educational layer becomes homework. So this rewards nothing. It is
## a third list in a roll that already lists the route and lists the flock, cut
## from the same marble, walking at the same speed, knockable by the same goose.
## The run summary is already delivered as objects you are allowed to smash;
## this is the Almanac delivered the same way, and the player walks out through
## everything they found.
##
## WHAT IT SAYS is the one thing forty-five minutes of Double-Doubles and Gravy
## never said out loud: what the stuff actually was. Both halves of every line
## are authored fields on the Substance resource — `display_name` and `mimics` —
## printed verbatim. Nothing here is composed, compressed or inferred, because
## the entire credibility of this codex rests on it being true, and because a
## `codex_fact` is ~300 characters and a slab caps at 9 m (see _spawn_credit),
## which would render a real fact at about 5 cm tall.
##
## WHAT IT DOES NOT SAY is how many you missed. An entry you never found is
## simply not on the fairway. That is the whole counter: absence, at walking
## pace, with no number attached to it.
##
## Discovery is CROSS-RUN (see unlocks.gd), so every line is phrased in the past
## tense of the substance and not of the run — "GRAVY · DIMENHYDRINATE" is still
## true on a second playthrough in a way that "you learned" would not be.
func _almanac_section(out: Array[String]) -> void:
	var unlocks := get_node_or_null("/root/Unlocks")
	var subs := get_node_or_null("/root/Subs")
	if unlocks == null or subs == null:
		return
	if not unlocks.has_method("unlocked_ids"):
		return
	# Array elements are Variant, so nothing read out of this can use `:=`.
	var ids: Array = unlocks.unlocked_ids()
	if ids.is_empty():
		return

	out.append("")
	# The Almanac's own header over the true fact is "WHAT'S ACTUALLY TRUE"
	# (almanac.gd). This is that header one step further on, and past tense.
	out.append("WHAT IT ACTUALLY WAS")
	for raw_id in ids:
		var sid := StringName(str(raw_id))
		# The typed accessor, not `Subs.library[id]` — the Dictionary read is a
		# Variant and every property off it would need annotating.
		var res = subs.get_substance(sid)
		if res == null:
			continue
		var nm: String = str(res.display_name).to_upper()
		var real: String = str(res.mimics).to_upper()
		if nm == "" or real == "":
			continue
		# Same separator as the route lines, so this reads as one more list in
		# the same roll rather than as a new kind of thing.
		out.append("%s  ·  %s" % [nm, real])

	# One absence stated out loud, because it is the funniest one and because
	# §9.4 writes this exact line. Every other missing entry stays silent.
	if not bool(unlocks.is_unlocked(&"toad_slime")):
		out.append("YOU NEVER TOUCHED THE TOAD")

	# The one true fact the ending is allowed to speak, and only if the player
	# was actually told it. VERBATIM, minus the line breaks, from the last
	# sentence of `codex_fact` in data/substances/grass.tres — if that sentence
	# ever changes, change this with it. It is here rather than any of the other
	# fifteen because it is the sentence the whole codex was built to arrive at,
	# it explains every substance in the game including the ones you missed, and
	# it is drier and funnier than anything the credits say about themselves.
	if bool(unlocks.is_unlocked(&"grass")):
		out.append("ALMOST EVERY INTOXICANT IN THIS GAME")
		out.append("STARTED OUT AS A PLANT OR FUNGUS")
		out.append("WAGING CHEMICAL WARFARE ON ANIMALS")
		out.append("THAT AN ANIMAL THEN DECIDED IT ENJOYED")

	# ...and §9.4's reply to a completed Almanac, which is not a reward and is
	# deliberately the longest walk in the roll. The only thing finding all
	# sixteen buys you is sixteen more credits to knock over.
	var found: int = int(unlocks.unlocked_count())
	var total: int = int(unlocks.total_count())
	if total > 0 and found >= total:
		out.append("EVERY SINGLE ONE")
		out.append("THERE IS NO ACHIEVEMENT FOR THIS")
		out.append("AND THERE IS NOT GOING TO BE")


## The route, for the roll. Duplicated from main.gd's ROUTE and ROUTE_DATA.md
## rather than read off the director: a const on another script is not
## reachable through a node reference, and the ending must still print a route
## if it is ever loaded on its own.
const ROUTE_KM := [
	["THE RETENTION POND · MISSISSAUGA", 12],
	["THE STRIP MALL LOT · MISSISSAUGA", 38],
	["SUBURBIA · OAKVILLE", 190],
	["COTTAGE COUNTRY · MUSKOKA", 640],
	["THE STOPOVER · MONTEZUMA NWR", 690],
	["THE CUT CORN · SAMPSON COUNTY", 390],
	["THE TRUCK STOP · OFF I-95", 310],
	["THE 18TH GREEN · FLORIDA", 0],
]

## TODO: these are placeholders for the real names. Everything above them in
## the roll is generated from the run; this block is the only authored text in
## the credits, and real names must be written by hand, never generated.
const CREDITS := [
	"GEEKED GEESE",
	"BUILT IN GODOT",
	"EVERY TEXTURE MADE BY A PYTHON SCRIPT",
	"EVERY SOUND MADE BY A PYTHON SCRIPT",
	"EVERY GOOSE MADE OF TRIANGLES",
	"THE FACTS IN THE ALMANAC ARE TRUE",
	"NOTHING ELSE IN HERE IS",
	"NO GEESE WERE HARMED",
	"SEVERAL WERE INCONVENIENCED",
	"THANK YOU FOR FLYING",
]


func _thousands(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out


# ══════════════════════════════════════════════════════════════════ TICK

func _process(delta: float) -> void:
	# Wall clock. Nothing in the ending should ever be slowed by a substance,
	# and nothing in the ending should ever be stopped by a hitstop from a slab
	# breaking three metres away.
	var dt := delta / maxf(Engine.time_scale, 0.05)
	_t += dt
	# The clock and the HUD, held down for the whole ending. main.gd's _poll_menus
	# restores HUD visibility whenever a menu closes, so once is not enough.
	Game.zone_running = false
	_hide_hud()

	_tick_water_and_wind(dt)
	_tick_cart(dt)
	for g in _geese:
		_tick_goose(g, dt)
	_tick_settling(dt)
	_wave_cd = maxf(0.0, _wave_cd - dt)
	_tick_honks(dt)
	_tick_credits(dt)


func _tick_water_and_wind(dt: float) -> void:
	# Sixteen sprinklers, each on its own clock. See _sprinklers().
	for fan in _spray:
		if not is_instance_valid(fan):
			continue
		var rate: float = fan.get_meta("rate", 0.5)
		var phase: float = fan.get_meta("phase", 0.0)
		# Not a constant spin: a real impact head sweeps out and snaps back.
		# sin() gives the sweep; the cube gives the dwell at the ends.
		var s := sin(_t * rate + phase)
		fan.rotation.y = s * s * s * 1.5 + _t * rate * 0.35
	if _flag != null and is_instance_valid(_flag):
		_flag.rotation.y = 0.4 + sin(_t * 0.7) * 0.5 + sin(_t * 2.3) * 0.08


func _tick_cart(dt: float) -> void:
	if _cart == null or not is_instance_valid(_cart):
		return
	# Slow circles on the fairway, forever. No PathFollow3D: the path is a
	# circle, and a circle is two trig calls.
	_cart_a += dt * 0.085
	var r := 13.0
	var c := Vector3(-2.0, 0.0, 18.0)
	_cart.global_position = c + Vector3(cos(_cart_a) * r, 0.0, sin(_cart_a) * r)
	# The cart's model faces -Z, so its heading is the tangent, half a turn on.
	_cart.rotation.y = -_cart_a + PI * 0.5


# ══════════════════════════════════════════════════ ONE GOOSE, ONE BEHAVIOUR

func _tick_goose(bird: Dictionary, dt: float) -> void:
	var root: Node3D = bird["root"]
	var visual: Node3D = bird["visual"]
	if not is_instance_valid(root) or not is_instance_valid(visual):
		return

	var phase: float = float(bird["phase"]) + dt * 1.7
	bird["phase"] = phase
	var mode: StringName = bird["mode"]
	var speed := 0.0
	var neck_x := 0.0
	var body_y := 0.0
	var body_roll := 0.0

	match mode:
		&"arrive":
			speed = _tick_arrival(bird, dt)
		&"walk":
			var tgt: Vector3 = bird["target"]
			speed = _walk_toward(bird, dt, tgt, 1.35)
			if speed <= 0.0:
				# Arrived. Take on whatever the resident it joined is doing —
				# and take on the STATE that mode needs, which is the whole
				# reason this is a function rather than three lines. A survivor
				# that settled into the golf-ball argument without a `pivot`
				# key threw "Invalid access to property or key 'pivot'" once per
				# frame for the rest of the ending. Found by running the real
				# install() path for a hundred seconds, not by compiling.
				_adopt(bird, StringName(bird.get("then", &"graze")))
		&"escort":
			# The DD. Stands next to you, wherever you are, forever.
			if goose != null and is_instance_valid(goose):
				var want := goose.global_position + Vector3(1.9, 0, 1.2)
				if root.global_position.distance_to(want) > 3.0:
					var tgt2 := want - Vector3(0, STAND_HEIGHT, 0)
					bird["target"] = tgt2
					speed = _walk_toward(bird, dt, tgt2, 1.5)
		&"graze":
			speed = _wander(bird, dt, 1.9, 1.05)
			# The peck. Head all the way down for a second and a bit, on its
			# own clock, which is 80% of what makes a standing goose read as a
			# goose rather than as a statue of one.
			var cd: float = float(bird["cd"]) - dt
			if cd <= 0.0:
				cd = randf_range(2.6, 7.0)
			bird["cd"] = cd
			if cd < 1.3:
				neck_x = 0.95 * sin(clampf(cd, 0.0, 1.3) / 1.3 * PI)
		&"preen":
			speed = _wander(bird, dt, 1.1, 0.7)
			neck_x = 0.55 + 0.45 * sin(phase * 1.9)
			body_roll = sin(phase * 0.8) * 0.16
		&"sleep":
			neck_x = 1.15
			body_y = -0.10 + sin(phase * 0.35) * 0.012
		&"sleep_back":
			# On its back. Feet up. Nothing else in the game is upside down and
			# that is precisely why it is the first thing you see in the bunker.
			# 2.75 rad rather than a clean PI: at exactly 180 degrees the bird is
			# a symmetrical lump with two orange dots on top, and the render
			# could not tell it from a goose sitting down. Tipped 22 degrees off
			# the axis it has a belly, a side and a wing, and it reads instantly.
			body_roll = 2.75
			body_y = 0.30 + sin(phase * 0.4) * 0.02
			neck_x = -0.6
		&"stand":
			neck_x = 0.08 + 0.06 * sin(phase * 0.5)
			# A slow look around, so it is idle rather than frozen.
			root.rotation.y = float(bird["heading"]) + sin(phase * 0.23) * 0.5
		&"roof":
			neck_x = -0.15
			var rc: float = float(bird["cd"]) - dt
			if rc <= 0.0:
				rc = randf_range(8.0, 10.5)
				if _sfx != null:
					_sfx.play_at(&"honk_b", root, -13.0, randf_range(0.94, 1.06))
			bird["cd"] = rc
		&"lap":
			# Round and round the same palm, one direction, indefinitely.
			var ang: float = float(bird.get("angle", 0.0)) + dt * float(bird.get("rate", 0.3))
			bird["angle"] = ang
			var piv: Vector3 = bird.get("pivot", bird["home"])
			var rad: float = float(bird.get("radius", 3.0))
			root.global_position = piv + Vector3(cos(ang) * rad, STAND_HEIGHT, sin(ang) * rad)
			var rate: float = float(bird.get("rate", 0.3))
			root.rotation.y = -ang + (PI if rate > 0.0 else 0.0)
			speed = absf(rate) * rad
		&"fight":
			# Two geese and one inert ball. They lunge, they retreat, they get
			# nowhere. It never resolves.
			var piv2: Vector3 = bird.get("pivot", bird["home"])
			var away := (root.global_position - piv2 - Vector3(0, STAND_HEIGHT, 0))
			away.y = 0.0
			if away.length() < 0.01:
				away = Vector3.FORWARD
			var lunge := 0.55 + 0.42 * sin(phase * 2.6)
			root.global_position = piv2 + Vector3(0, STAND_HEIGHT, 0) \
				+ away.normalized() * lunge
			root.rotation.y = atan2(-away.x, -away.z) + PI
			neck_x = -0.35 + 0.25 * sin(phase * 2.6)
			speed = 1.4
			var fc: float = float(bird["cd"]) - dt
			if fc <= 0.0:
				fc = randf_range(3.0, 7.5)
				if _sfx != null:
					_sfx.play_at(&"goose_grumble", root, -15.0, randf_range(0.9, 1.2))
			bird["cd"] = fc
		&"riding":
			# Parented to the cart. It just sits there. That is the joke.
			neck_x = -0.12 + 0.05 * sin(phase * 0.6)

	bird["speed"] = lerpf(float(bird["speed"]), speed, 1.0 - pow(0.02, dt))
	visual.position.y = body_y
	visual.rotation.z = body_roll
	if visual.has_method("animate"):
		visual.animate(dt, float(bird["flap"]), float(bird["speed"]),
			bool(bird["airborne"]))
	# AFTER animate(), never before: animate() writes the neck itself, so
	# setting it first just gets overwritten on the same frame. This cost the
	# flock pen twenty minutes and one render to find; it is not being paid for
	# twice.
	var neck = bird["neck"]
	if neck is Node3D:
		var nk: Node3D = neck
		nk.rotation.x = neck_x


## Beat 2 — your survivors land with you. A glide down the line they came in
## on, wings out, and a thump.
func _tick_arrival(bird: Dictionary, dt: float) -> float:
	var clock: float = float(bird["clock"]) + dt
	bird["clock"] = clock
	var t0: float = float(bird["t0"])
	if clock < t0:
		return 0.0
	var root: Node3D = bird["root"]
	var dur: float = float(bird["dur"])
	var t: float = clampf((clock - t0) / dur, 0.0, 1.0)
	var from: Vector3 = bird["from"]
	var land: Vector3 = bird["land"] + Vector3(0, STAND_HEIGHT, 0)
	# Ease out of the descent so it flares into the landing instead of driving
	# into the turf at a constant angle.
	var e := 1.0 - pow(1.0 - t, 2.2)
	root.global_position = from.lerp(land, e) + Vector3(0, sin(t * PI) * 1.1, 0)
	root.rotation.y = PI
	bird["airborne"] = t < 0.99
	bird["flap"] = lerpf(0.55, 0.0, clampf(t * 1.4, 0.0, 1.0))
	if t >= 1.0:
		bird["mode"] = &"graze"
		bird["airborne"] = false
		bird["flap"] = 0.0
		bird["home"] = bird["land"]
		bird["heading"] = PI
		if _sfx != null:
			_sfx.play_at(&"thud_land", root, -12.0, randf_range(0.95, 1.1))
		Juice.burst(root.global_position - Vector3(0, STAND_HEIGHT, 0),
			Color(0.55, 0.62, 0.34), 6, &"debris")
	return 3.0 * (1.0 - t)


## Pick a spot near home and walk to it. The whole of resident behaviour.
func _wander(bird: Dictionary, dt: float, spread: float, walk: float) -> float:
	var w: float = float(bird["wander"]) - dt
	if w <= 0.0:
		var home: Vector3 = bird["home"]
		bird["target"] = home + Vector3(randf_range(-spread, spread), 0.0,
			randf_range(-spread, spread))
		bird["wander"] = randf_range(2.4, 6.5)
	else:
		bird["wander"] = w
	var tgt3: Vector3 = bird["target"]
	return _walk_toward(bird, dt, tgt3, walk)


## Returns the speed actually walked, or 0.0 when it has arrived.
func _walk_toward(bird: Dictionary, dt: float, target: Vector3, walk: float) -> float:
	var root: Node3D = bird["root"]
	var to := target + Vector3(0, STAND_HEIGHT, 0) - root.global_position
	to.y = 0.0
	var dist := to.length()
	if dist <= 0.22:
		return 0.0
	var dir := to / dist
	root.global_position += dir * minf(walk * dt, dist)
	var want := atan2(dir.x, dir.z) + PI
	var head: float = lerp_angle(float(bird["heading"]), want, 1.0 - pow(0.002, dt))
	bird["heading"] = head
	root.rotation.y = head
	return walk


## Beat 3 — they settle in. Every seven seconds one survivor peels away and
## picks a resident to join.
##
## Each departure floats that bird's NAME once, in world space, and fades. That
## is the only time in the entire game a flock member's name is rendered in the
## world during play. It is the entire emotional payload of the ending and it
## costs one Label3D and a tween.
func _tick_settling(dt: float) -> void:
	if _survivors.is_empty():
		# Unreachable by construction — Flock.lose_bird() refuses to drop
		# player_index, so there is always at least one survivor — but if it
		# ever happens, the credits must still roll. Without this line an empty
		# flock leaves _all_settled_t at -1 forever and the ending never
		# finishes, which is the same shape as the soft-lock the route table
		# already had once.
		if _all_settled_t < 0.0:
			_all_settled_t = _t
		return
	if _settle_next >= _survivors.size():
		if _all_settled_t < 0.0:
			_all_settled_t = _t
		return
	_settle_cd -= dt
	if _settle_cd > 0.0:
		return
	_settle_cd = SETTLE_EVERY

	var bird: Dictionary = _survivors[_settle_next]
	_settle_next += 1
	var root: Node3D = bird["root"]
	if not is_instance_valid(root):
		return

	# The DD does not join anybody. It stands next to you.
	if bool(bird.get("is_dd", false)):
		bird["mode"] = &"escort"
	else:
		var spot := _settle_spot(_settle_next - 1)
		bird["mode"] = &"walk"
		var dest: Vector3 = spot["pos"]
		bird["target"] = dest
		bird["then"] = spot["mode"]

	_float_name(root, str(bird["name"]).to_upper(), int(bird.get("scars", 0)))
	if _sfx != null:
		_sfx.play_at(&"honk_c", root, -11.0, randf_range(0.92, 1.08))


## The name, once, in the world, and then never again.
func _float_name(root: Node3D, text: String, scars: int) -> void:
	var lbl := Label3D.new()
	# The scar pips ride the name and are never explained. A bird that came
	# back from the edge of a flight carries a mark; the ending shows it and
	# says nothing about it, which is the only tone this game has for that.
	lbl.text = text if scars <= 0 else "%s %s" % [text, "·".repeat(mini(scars, 3))]
	lbl.font_size = 48
	lbl.pixel_size = 0.0075
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.shaded = false
	lbl.double_sided = true
	lbl.outline_size = 14
	lbl.outline_modulate = Color(0, 0, 0, 0.7)
	lbl.modulate = Color(1.0, 0.98, 0.92, 0.0)
	lbl.position = Vector3(0, 1.15, 0)
	root.add_child(lbl)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", 2.15, 4.2)
	tw.tween_property(lbl, "modulate:a", 1.0, 0.8)
	tw.chain().tween_interval(1.8)
	tw.chain().tween_property(lbl, "modulate:a", 0.0, 1.6)
	tw.chain().tween_callback(lbl.queue_free)


## When the roll starts, and then one slab at a time until it doesn't.
func _tick_credits(dt: float) -> void:
	if _credit_done:
		return
	if not _credit_rolling:
		if _all_settled_t < 0.0:
			return
		# The credits wait for the honk. They are the answer to it, and a roll
		# that starts while the player is still working out that there is one
		# thing to do here would step on the only sincere beat in the game.
		var honked := _wave_count > 0 and (_t - _last_wave_t) > 5.5
		# ...but they do not wait forever. A player who never honks still gets
		# an ending; they just get it forty seconds later.
		var patient := (_t - _all_settled_t) > 42.0
		if not (honked or patient):
			return
		_credit_rolling = true
		_credit_cd = 0.0
		return

	_credit_cd -= dt
	if _credit_cd > 0.0:
		return
	_credit_cd = CREDIT_EVERY
	if _credit_next >= _credit_lines.size():
		_credit_done = true
		# Beat 6 — after. Nothing happens. The course stays, the sprinklers keep
		# going, the residents keep doing their things, and the player can
		# waddle around indefinitely. One small line in the corner.
		if _esc_label != null and is_instance_valid(_esc_label):
			var tw := create_tween()
			tw.tween_interval(26.0)
			tw.tween_property(_esc_label, "modulate:a", 1.0, 2.4)
		return
	var line: String = _credit_lines[_credit_next]
	_credit_next += 1
	# A blank line in the payload is a beat of empty fairway, not a blank slab.
	if line.strip_edges() == "":
		_credit_cd = CREDIT_EVERY * 1.6
		return
	_spawn_credit(line)


## Hand a settled survivor the behaviour it just joined, with every key that
## behaviour reads. The modes are a state machine and this is its only entry
## point; anything that sets `mode` without coming through here is a bug.
func _adopt(bird: Dictionary, mode: StringName) -> void:
	var root: Node3D = bird["root"]
	bird["home"] = root.global_position - Vector3(0, STAND_HEIGHT, 0)
	bird["cd"] = randf_range(1.5, 5.0)
	match mode:
		&"lap":
			# The other way round the other palm. Spec's own line.
			bird["pivot"] = LAP_PALM_2
			bird["radius"] = 3.0
			bird["rate"] = -0.26
			bird["angle"] = PI
		&"fight":
			bird["pivot"] = BALL
		&"riding":
			if _cart == null or not is_instance_valid(_cart):
				mode = &"graze"
			else:
				_reparent_to(bird, _cart, Vector3(0.30, 0.66 + STAND_HEIGHT, -0.42), 0.2)
	bird["mode"] = mode


# ══════════════════════════════════════════════════════════════ ZONE API

## Named on screen once, as the last route pin. There is no leg number: the
## legs are over.
func zone_title() -> String:
	return "THE 18TH GREEN — FLORIDA · 0 KM"


## DELIBERATELY ABSENT: mission_zone_id() and objectives().
##
## An epilogue with a scored objective list would be a mistake, and it would be
## the specific mistake the spec names: "the moment the golf course has
## objectives, the sincere moment dies." Not defining mission_zone_id() means a
## director that loads this through the normal zone path falls back to
## `generic` and this zone's own _take_over() hides the mission HUD anyway —
## but the intended path is install(), which never starts a leg at all.
