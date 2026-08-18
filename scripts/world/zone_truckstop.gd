extends Node3D
## LEG 7 — THE TRUCK STOP
##
## Somewhere off I-95 in Georgia. Three in the morning, warm rain, wet asphalt
## reflecting orange. Built procedurally so it runs correctly the first time you
## open the project with no import step and no missing references.
##
## TODO(art pass): same caveat as the other zones — once this plays right,
## rebuild it as a real .tscn. Procedural is the right call for a first playable
## and the wrong call for level design.
##
## ---------------------------------------------------------------------------
## WHY THIS ZONE EXISTS — CAMPAIGN_SPEC §2.7
## ---------------------------------------------------------------------------
## It is **the breath before the peak**, and the run's secondary rest beat. The
## player has just come through the hardest zone in the game (leg 6) and is
## about to fly the hardest flight (flight 7, THE INTERSTATE). This is where
## they get to stand still in the rain under a sodium light for three minutes.
## Intensity 4, between two 7s and a 9.
##
## Three things follow from that, and every decision in this file is one of them:
##
## 1. IT IS LEAN. `rest()` at leg 7 restores 0.35 intox / 0.25 stamina — the
##    leanest numbers in the game — and there are **four substances**, all ones
##    you have had before, all at roughly half the dose size of the cottage's.
##    Nothing here works properly any more. Nobody says that out loud.
##
##    So the objectives are written to need **no chemistry at all** (§602):
##    honking, wrecking, riding a truck, the dumpster corral, the diner window,
##    getting on top of a rig. `required_primaries(7)` is 5 of 6, and 5 of 6 on
##    a zone with four weak substances is the single most likely place in the
##    campaign for the mission system to feel unfair. It is only fair if the
##    primaries are free, so they are.
##
## 2. IT IS QUIET, NOT SMALL. A zone whose joke is that there is nothing here
##    has to be interesting to have nothing *in*. So the lot is full of empty:
##    props are in four tight clusters (the corral, the diner walk, the fuel
##    island, the truck row) with sixty metres of wet nothing between them, and
##    the only human in eighty square metres is one night cook behind glass.
##    The strip mall has nine people. The cottage has eight. This has one.
##
## 3. THE RIGS LEAVE. §1511: *"night, rain, four substances, rigs that leave."*
##    Six tractor-trailers, parked with their engines running, each on a timer.
##    A parked rig is a launch pad. A rolling rig is a ride and a hazard. Riding
##    one out of the lot and having to fly back is the leg's identity joke.
##    And because they never come back, the lot is measurably emptier at 2:00
##    than it was at 0:00 — which is the whole zone's argument, made in physics
##    rather than in text.
##
## ---------------------------------------------------------------------------
## THE HEIGHT TABLE — read before moving anything
## ---------------------------------------------------------------------------
##     y = -0.80 .. -0.30   sub-base slab (also the flooded corner's bed)
##     y =  0.00            lot grade — the asphalt everything stands on
##     y =  0.20            top of the flood Area3D — the swim/wade transition
##     y =  1.15            trailer deck
##     y =  3.50            the walk awning (landable)
##     y =  4.05            TRAILER ROOF — the zone's high ground and launch pad
##     y =  4.90            the travel centre roof (landable)
##     y =  6.20            the fuel canopy roof (landable)
##     y = 11.60            the top of the pylon sign
##
## The two load-bearing numbers are borrowed from the cottage, where they were
## set by measurement rather than by eye, and they should not be re-guessed:
##
## * THE WADE LINE. The goose's body collider is a capsule lying along Z, so its
##   vertical half-extent is the 0.34 radius and its water probe is a 0.22
##   sphere on the origin. A bed at -0.30 with an Area3D top at +0.20 floats the
##   bird with its origin at 0.04 — waterline just under halfway up the body —
##   and switches to the swim state when the asphalt under its feet drops about
##   a hand's width below the surface.
##
## * ONE FLAP IS 1.86 m (`flap_impulse^2 / (2 * glide_gravity)` = 6.4^2 / 22).
##   The trailer roof is 4.05, so it is three flaps from the asphalt or one from
##   the fuel-island kerb; the travel centre roof is 0.85 above a trailer roof,
##   which is one flap from a rig you are already standing on. Every piece of
##   high ground in the zone is reachable by a bird with almost nothing left,
##   because a bird arriving at leg 7 has almost nothing left.

const LOT := 80.0

## Preloaded rather than referenced by class_name: global class registration
## only exists after an editor import pass, so a `class_name` reference breaks
## in a fresh checkout or a headless CI run. A preload const always resolves.
const PROPS := preload("res://scripts/world/prop_models.gd")
const TS := preload("res://scripts/world/prop_models_truckstop.gd")

# ── the height table, as constants ──────────────────────────────────────────
const GRADE := 0.0
const BED_Y := -0.30
const PAVE_T := 0.30          ## pavement slab thickness (grade down to the bed)
const TRAILER_ROOF := 4.05
const ROOF_Y := 4.90          ## travel centre roof deck
const CANOPY_Y := 6.20        ## fuel canopy roof deck
const CANOPY_UNDER := 5.40

## The flooded corner. Tile-aligned to nothing in particular — the asphalt is
## laid as four rectangles AROUND this hole rather than as one grid with a gap
## punched in it, which is why there is no half-tile of pavement floating over
## the water. See _lot().
const FLOOD_X0 := -32.0
const FLOOD_X1 := -16.0
const FLOOD_Z0 := -20.0
const FLOOD_Z1 := -4.0

## Where the departing rigs turn west and run for the ramp.
const EXIT_Z := -30.0

## The truck row. Six bays, 6.4 m apart, noses pointing -Z at the exit.
const BAY_X := [4.0, 10.4, 16.8, 23.2, 29.6, 36.0]
const BAY_Z := -2.0

## When each rig pulls out, in seconds from the top of the leg.
##
## Spread across the whole 180 s clock rather than bunched, because the point is
## that the lot thins out *continuously*. The last one goes at 2:46 of 3:00,
## which leaves fourteen seconds of a completely empty parking lot — and that
## fourteen seconds is the most honest thing in the game.
const DEPART_AT := [22.0, 48.0, 76.0, 106.0, 138.0, 166.0]

## Air-brake warning before the rig actually moves. Long enough to sprint for,
## short enough to be a decision.
const ARM_TIME := 3.2

## Trailer names, painted on both flanks. Six real-sounding nobodies; a truck
## stop full of famous logos reads as advertising, and a truck stop full of
## companies you have never heard of reads as 3 a.m.
const RIG_NAMES := ["PILGRIM", "MERIDIAN", "COMET", "OLD ROUTE", "ARROW", "TIDEWATER"]
const RIG_COLOURS := [
	Color(0.58, 0.13, 0.13), Color(0.14, 0.24, 0.42), Color(0.62, 0.55, 0.16),
	Color(0.16, 0.34, 0.26), Color(0.34, 0.32, 0.36), Color(0.52, 0.28, 0.12),
]

## Sodium orange. Everything in the zone that is not the fuel canopy is this
## colour, and the fuel canopy is deliberately the only cold light on the lot —
## which is exactly what a real one looks like from the interstate.
const C_SODIUM := Color(1.00, 0.62, 0.22)
const C_CANOPY := Color(0.86, 0.92, 1.00)

## Wet asphalt. Very dark on purpose: it is multiplied into the asphalt texture
## and everything readable in this zone is readable because it is BRIGHTER than
## the ground, not because the ground is lit.
const C_ASPHALT := Color(0.130, 0.125, 0.135)

## Chaos-prop label -> model kind, across BOTH libraries. Keyed off the label
## the prop already carries — the same string scoring and objectives match on —
## so there is one place to look and no call site repeats itself.
const PROP_KIND := {
	# this zone's own library
	"PALLET": &"pallet",
	"GATOR": &"gator",
	"CONE": &"traffic_cone",
	"PAPER BOX": &"newspaper_box",
	"ICE": &"ice_box",
	"PROPANE": &"propane_cage",
	"CHOCK": &"wheel_chock",
	# the shared library
	"DUMPSTER": &"dumpster",
	"GARBAGE": &"garbage_bag",
	"RECYCLING": &"recycling_bin",
	"VEHICLE": &"minivan",
	"CART": &"shopping_cart",
	"PATIO CHAIR": &"patio_chair",
}

## Sodium lamp placements: x, z, yaw. The model's mast arm runs along +X, so the
## yaw is which way the head is cocked, and it matters — a lamp is placed so its
## POOL lands somewhere the player has to walk, not so its pole looks tidy.
const LAMPS := [
	[-3.0, 21.0, PI],      ## the spawn, the flock pen, the diner walk
	[-24.0, 21.0, 0.0],    ## the car park
	[1.0, 4.0, PI],        ## mid lot — the long empty walk
	[14.0, 19.0, 0.0],     ## the truck row, tail end
	[30.0, 6.0, 0.0],      ## the truck row, east
	[16.0, -12.0, PI],     ## the truck row, noses
	[-16.0, -12.0, PI],    ## the flooded corner's east shore
	[4.0, -30.0, 0.0],     ## the exit lane
	[22.0, 24.0, 0.0],     ## the dumpster corral
]

var goose: Goose
var camera_rig: Node3D

var _tex: Node = null   ## /root/Tex — may not exist, always guard.
var _sfx: Node = null   ## /root/Sfx — may not exist, always guard.

var _t := 0.0
var _clock := 0.0       ## seconds since the leg started, drives the departures
var _probe := false

# ── the rigs ────────────────────────────────────────────────────────────────
# Parallel typed arrays rather than an array of Dictionaries, and that is not a
# style preference: every read out of a Dictionary is a Variant and needs an
# explicit annotation, and this file would otherwise have forty of them in one
# function. Typed arrays make the same code impossible to get wrong.
enum RigState { PARKED, ARMED, ROLLING, GONE }

var _rig_body: Array[AnimatableBody3D] = []
var _rig_roof: Array[Area3D] = []
var _rig_glow: Array[Node3D] = []
var _rig_state: Array[int] = []
var _rig_arm: Array[float] = []
var _rig_speed: Array[float] = []
var _rig_yaw: Array[float] = []
var _rig_ride: Array[float] = []
var _rig_boarded: Array[bool] = []
var _rig_rode: Array[bool] = []
var _rigs_left := 0

var _head_light: OmniLight3D = null
var _tail_light: OmniLight3D = null
var _long_ride_given := false
var _last_call_given := false

# ── the diner window ────────────────────────────────────────────────────────
var _pane_area: Array[Area3D] = []
var _pane_mesh: Array[MeshInstance3D] = []
var _pane_body: Array[StaticBody3D] = []
var _pane_gone: Array[bool] = []

# ── cosmetics ───────────────────────────────────────────────────────────────
var _rain: CPUParticles3D = null
## Seconds between "is there a roof over the bird" raycasts. A goose does 14 m/s
## flat out, so an eighth of a second is under two metres of travel — well
## inside the smallest shelter in the zone (the diner awning is 3.6 m deep) and
## a fifteenth of the cost of probing every frame.
const RAIN_PROBE_EVERY := 0.125
var _rain_probe_t := 0.0
var _moths: Array[Node3D] = []
var _lamp_lights: Array[OmniLight3D] = []


func _ready() -> void:
	_tex = get_node_or_null("/root/Tex")
	_sfx = get_node_or_null("/root/Sfx")
	# Same dev hook `main.gd` gives the Ranger with `--boss`: a departure
	# schedule spread over three minutes cannot be photographed by a probe that
	# renders twenty frames at two frames a second. Compressed under --probe and
	# nowhere else.
	_probe = OS.get_cmdline_user_args().has("--probe")

	_environment()
	_lot()
	_flood()
	_building()
	_corral()
	_canopy()
	_pylon()
	_lamps()
	_truck_row()
	_paint()
	_sources()
	_props()
	_people()
	_cats()
	_rain_setup()
	_spawn_goose()
	# Your flock, physically present under the nearest light. This is the only
	# place the Designated Driver can be chosen, and the last chance to do it
	# before the flight that decides who arrives.
	# OUT IN THE OPEN, AND THAT IS NOT AESTHETIC. `flock_pen.gd` grounds each
	# bird with a raycast that starts FOUR METRES ABOVE the centre it was given,
	# so a pen placed under anything lower than that snaps the whole flock onto
	# the roof of it. The first render had four of six geese standing on top of
	# the diner awning (3.5 m) reading their own name tags. Nothing within four
	# metres of vertical clearance of this point.
	add_child(preload("res://scripts/world/flock_pen.gd").new().setup(
		Vector3(-7.0, GRADE, 0.0)))

	# THE RAIN USED TO BE `_sfx.loop(&"hiss", &"rain", -21.0)` HERE, AND IT WAS
	# NEVER RAIN AND NEVER LOOPED.
	#
	# `hiss` is the goose's 0.700 s threat hiss — the same file the rigs use for
	# their air brakes at :1629 — and `Sfx` only forces forward-looping on keys
	# whose name ends in `_loop` (sfx.gd::_configure_loop_if_needed). So the
	# wettest zone in the game opened with seven tenths of a second of a goose
	# hissing and then three minutes of silence, under a visible 300-particle
	# downpour. Nobody could hear that it was wrong because nobody had listened.
	#
	# `amb_truckstop_loop` — rain on metal, an idling diesel, the interstate a
	# long way off — now carries it, chosen by zone id in main.gd::_load_zone()
	# and stopped in _clear() with every other loop. There is nothing left for
	# this zone to start or to tear down, which is why _exit_tree() is gone.
	pass


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


func _static_tex(pos: Vector3, size: Vector3, key: StringName, uv_scale: float,
		fallback: Color, rot_y := 0.0, rough := 0.72) -> StaticBody3D:
	var sb := _static_box(pos, size, fallback, rot_y)
	var mat := _surf(key, uv_scale, fallback, rough)
	for c in sb.get_children():
		if c is MeshInstance3D:
			c.material_override = mat
	return sb


## Visual only — no collider. For paint, lines, flat detail.
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


## An UNSHADED box. This is the zone's other half: a "lit" fascia band, a
## window, a neon tube and a lamp lens are all things that emit, and a
## lit-from-outside pale quad at this ambient renders as a grey rectangle.
func _glow_box(pos: Vector3, size: Vector3, color: Color, rot_y := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 1.4
	mi.material_override = m
	add_child(mi)
	mi.global_position = pos
	mi.rotation.y = rot_y
	return mi


## A ramp whose TOP SURFACE runs from `a` to `b`. Both are points ON the
## finished surface, because every ramp in this zone exists to join two known
## heights and doing that trigonometry at the call site is how you get a lip the
## goose trips over.
func _ramp(a: Vector3, b: Vector3, width: float, thick: float, col: Color) -> StaticBody3D:
	var d := b - a
	var flat := Vector2(d.x, d.z).length()
	var pitch := atan2(-d.y, flat)
	var yaw := atan2(d.x, d.z)
	var sb := _static_box((a + b) * 0.5 + Vector3(0, -thick * 0.5, 0),
		Vector3(width, thick, d.length()), col)
	sb.basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
	_hide_meshes(sb)
	return sb


## THE TILING IS NOT COSMETIC. This project renders on GL Compatibility, where a
## single MeshInstance3D is lit by at most eight lights (the engine default). An
## eighty-metre lot as ONE mesh therefore picks eight of the zone's nineteen
## lights and drops the rest — and *which* eight changes as things move, so the
## ground flickers. Learned the hard way in the cottage; every large surface
## here is split for the same reason.
func _flat_tiles(centre: Vector3, size: Vector3, nx: int, nz: int, key: StringName,
		fallback: Color, uv_scale: float, rough := 0.62) -> void:
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


func _hide_meshes(sb: Node) -> void:
	for c in sb.get_children():
		if c is MeshInstance3D:
			c.visible = false


func _prop(pos: Vector3, size: Vector3, color: Color, mass_kg: float, pts: int,
		lbl: String, extra := {}) -> ChaosProp:
	var p := ChaosProp.new()
	add_child(p)
	var kind: StringName = PROP_KIND.get(lbl, &"")
	var params: Dictionary = extra.duplicate()
	if kind != &"":
		params[_colour_key(kind)] = color

	if TS.has_model(kind):
		# ChaosProp.setup() only knows the SHARED library, so anything from this
		# zone's own library is built here instead and the graybox hidden.
		# `_visual` has to be repointed or _break() would hide the invisible box
		# and leave a fully intact pallet standing in its own debris.
		p.setup(size, color, mass_kg, pts, lbl)
		_hide_meshes(p)
		params["size"] = size
		var m: Node3D = TS.build(kind, p, params)
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
	var m: Node3D = TS.build(kind, sb, params) if TS.has_model(kind) \
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
	if TS.has_model(kind):
		TS.build(kind, n, params)
	else:
		PROPS.build(kind, n, params)
	if not is_equal_approx(uniform, 1.0):
		n.scale = Vector3.ONE * uniform
	return n


func _source(pos: Vector3, res: Substance, size := 0.28, infinite := false) -> void:
	if res == null:
		return
	var s := SubstancePickup.new()
	add_child(s)
	s.setup(res, size)
	s.infinite = infinite
	s.global_position = pos


## Every point light in the zone goes through here so the budget is countable in
## one place and nothing accidentally ships with shadows on. On GL Compatibility
## an omni shadow is a cube render; nineteen of them is not a trade worth making
## for shadows a player reads as noise in the rain.
func _lamp(pos: Vector3, col: Color, energy: float, rng: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = 1.10
	l.shadow_enabled = false
	add_child(l)
	l.global_position = pos
	return l


## THE WET ASPHALT SOLUTION, and it is deliberately not the obvious one.
##
## The obvious one is a translucent dark sheen plane over the asphalt with a
## normal map on it. That is the exact trap this project has already fallen into
## twice: **a translucent coloured plane over similarly-coloured ground renders
## as nothing.** The strip mall's pond needed a dark basin behind it before the
## water was visible at all.
##
## So wet is built the other way round — as light rather than as surface. Under
## each sodium head goes an ADDITIVE, unshaded pool of three rings plus a long
## thin smear running away from the pole, which is what a lamp reflected in
## standing water actually looks like from a low camera. Additive over dark
## asphalt cannot fail to be brighter than what is under it, and the smear is
## the only thing giving sixty metres of black tarmac a readable direction.
## Same trick, and the same reasoning, as the cottage's moon path.
func _pool(centre: Vector3, radius: float, col: Color, smear_dir: Vector3) -> void:
	for i in 3:
		var t := float(i) / 2.0
		var r := lerpf(radius, radius * 0.34, t)
		var a := lerpf(0.035, 0.13, t)
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(col.r, col.g, col.b, a)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(r * 2.0, 0.02, r * 2.0)
		mi.mesh = bm
		mi.material_override = m
		add_child(mi)
		mi.global_position = centre + Vector3(0, 0.012 + 0.004 * float(i), 0)
		# Yawed 22.5 degrees apart. Three concentric SQUARES read as a square,
		# and the first render had unmistakably rectangular puddles of light
		# with corners on them; three squares at 0 / 22.5 / 45 read as a rosette
		# and cost nothing.
		mi.rotation.y = float(i) * 0.3927
	# The smear. Nine tiles, narrowing and dimming with distance, the way a
	# specular glare path on a rippled surface actually behaves.
	var d := smear_dir.normalized()
	for i in 4:
		var t2 := float(i) / 3.0
		var m2 := StandardMaterial3D.new()
		m2.albedo_color = Color(col.r, col.g, col.b, lerpf(0.075, 0.012, t2))
		m2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m2.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var mi2 := MeshInstance3D.new()
		var bm2 := BoxMesh.new()
		# Depth EQUALS the step, so consecutive tiles abut instead of overlapping.
		# Overlapping additive tiles double their alpha in the overlap and the
		# smear renders as corduroy.
		bm2.size = Vector3(lerpf(1.9, 0.5, t2), 0.02, radius * 0.34)
		mi2.mesh = bm2
		mi2.material_override = m2
		add_child(mi2)
		mi2.global_position = centre + d * (radius * 0.34 * float(i + 1)) \
			+ Vector3(0, 0.018, 0)


# ══════════════════════════════════════════════════════════════ ENVIRONMENT
#
# THE 3 A.M. VISIBILITY SOLUTION. The cottage solved "can the player see at
# night" with a moon; this zone cannot, because it is RAINING and there is no
# moon. Everything the player navigates by is man-made, which is both the
# correct answer physically and a completely different-looking zone:
#
#   1. AMBIENT IS THE FLOOR. A colour ambient means no surface is ever darker
#      than legible. Warm-grey rather than the cottage's blue, because the thing
#      filling in the shadows here is nine sodium lamps bouncing off wet tarmac
#      and low cloud, not the sky.
#   2. THERE IS NO KEY LIGHT, SO THE SKY IS ONE. A single very weak downward
#      directional WITH SHADOWS stands in for overcast: it gives every object a
#      contact shadow and a top face, which is the entire difference between a
#      lot full of objects and a lot full of stickers. It is not the moon and it
#      must never look like one.
#   3. THE SODIUM LAMPS ARE THE PLACE. Nine of them, and the pools they throw
#      are the zone's only real landmarks.
#   4. THE FUEL CANOPY IS THE ONLY COLD LIGHT. Four cool-white sources under a
#      roof, in a zone that is otherwise entirely orange. That contrast is what
#      makes the canopy read as a destination from anywhere on the lot, and it
#      is what a real truck stop looks like from the interstate.
#   5. FOG IS DISTANCE, NOT MURK. Rain fog at 0.010 in a warm grey, so the far
#      end of the lot separates from the near end and the treeline reads.

func _environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	# Overcast at 3 a.m. over a lit lot: black overhead, and a dirty orange
	# smear at the horizon where the lot's own light bounces off the cloud base.
	# That smear is real light pollution and it is also the only horizon line a
	# flying player gets, so it is not negotiable.
	sm.sky_top_color = Color(0.020, 0.020, 0.028)
	sm.sky_horizon_color = Color(0.150, 0.105, 0.070)
	sm.ground_bottom_color = Color(0.014, 0.013, 0.016)
	sm.ground_horizon_color = Color(0.105, 0.075, 0.055)
	sm.sky_curve = 0.10
	# No sun disc. There is no moon tonight and a procedural sky will happily
	# draw one for any directional light in the scene.
	sm.sun_angle_max = 0.0
	sm.sun_curve = 1.0
	sky.sky_material = sm

	env.background_mode = Environment.BG_SKY
	env.sky = sky
	# COLOR, not SKY. Sky ambient against a 0.02 sky is essentially zero, and a
	# zone lit by essentially zero is the failure mode the cottage was written
	# against. An explicit lift, warm, because everything lifting the shadows in
	# this lot is a sodium lamp.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# NEARLY NEUTRAL, very slightly cool. The first render had this at a warm
	# (0.56, 0.46, 0.40) on the theory that everything filling the shadows here
	# is sodium — and the result was a lot in which the tarmac, the trailers,
	# the sky and the lamps were all the same brown. Sodium only reads as sodium
	# if the things it is NOT hitting are cold. The ambient is the cold now; the
	# nine lamps supply every warm pixel in the zone.
	env.ambient_light_color = Color(0.42, 0.43, 0.50)
	env.ambient_light_energy = 0.44
	env.fog_enabled = true
	# 0.0105 was 57% fog at the far wall and the back half of the lot went to
	# mud. Rain reads from the streaks and the reflections, not from haze.
	env.fog_density = 0.0062
	env.fog_light_color = Color(0.115, 0.098, 0.098)
	env.fog_light_energy = 1.0
	env.fog_sky_affect = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.20
	env.tonemap_white = 3.2
	we.environment = env
	add_child(we)

	# The overcast. Straight down and weak, with shadows on. Its entire job is
	# to give things a top face and a contact shadow — without it the lot is a
	# collection of flat cutouts standing in orange soup.
	var sky_light := DirectionalLight3D.new()
	sky_light.rotation_degrees = Vector3(-72.0, 24.0, 0.0)
	sky_light.light_energy = 0.30
	sky_light.light_color = Color(0.62, 0.62, 0.72)
	sky_light.shadow_enabled = true
	sky_light.directional_shadow_max_distance = 70.0
	add_child(sky_light)

	# A second, shadowless directional raking in from the interstate side, at a
	# sodium colour. Not realism — a warm rim on the north face of every trailer
	# and every pole, so the silhouettes separate from a black sky.
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-9.0, 168.0, 0.0)
	rim.light_energy = 0.20
	rim.light_color = Color(1.00, 0.70, 0.36)
	rim.shadow_enabled = false
	add_child(rim)


# ══════════════════════════════════════════════════════════════════ THE LOT

func _lot() -> void:
	# ── sub-base ────────────────────────────────────────────────────────
	# One slab under everything, top at BED_Y. It is also the flooded corner's
	# bed, which is why it is dark: the water surface is translucent and a
	# translucent plane over pale ground is invisible.
	_static_tex(Vector3(0, BED_Y - 0.5, 0), Vector3(LOT, 1.0, LOT), &"dirt", 26.0,
		Color(0.055, 0.050, 0.048))

	# ── pavement, as four rectangles AROUND the flood ───────────────────
	# Not one grid with a hole punched in it. A grid with a hole leaves half a
	# tile of asphalt floating over the water wherever the flood edge does not
	# land on a tile boundary, and it is the sort of thing that only shows up in
	# a render taken from the water.
	var regions := [
		[-40.0, FLOOD_X0, -40.0, 40.0, 1, 8],
		[FLOOD_X1, 40.0, -40.0, 40.0, 6, 8],
		[FLOOD_X0, FLOOD_X1, -40.0, FLOOD_Z0, 2, 2],
		[FLOOD_X0, FLOOD_X1, FLOOD_Z1, 40.0, 2, 4],
	]
	for row in regions:
		var r: Array = row
		var x0: float = r[0]
		var x1: float = r[1]
		var z0: float = r[2]
		var z1: float = r[3]
		var nx: int = r[4]
		var nz: int = r[5]
		var cx := (x0 + x1) * 0.5
		var cz := (z0 + z1) * 0.5
		var w := x1 - x0
		var d := z1 - z0
		var sb := _static_box(Vector3(cx, GRADE - PAVE_T * 0.5, cz),
			Vector3(w, PAVE_T, d), C_ASPHALT)
		_hide_meshes(sb)
		_flat_tiles(Vector3(cx, GRADE - 0.02, cz), Vector3(w, 0.06, d), nx, nz,
			&"asphalt", C_ASPHALT, 4.5)

	# ── the treeline and the interstate beyond it ───────────────────────
	# Black pines along the back and the west, at the map edge. They are the
	# horizon line a flying player orients on and they cost twelve models. The
	# interstate itself is a berm with headlights on it — see _paint().
	for i in 13:
		var x := -38.0 + float(i) * 6.4 + 1.6 * sin(float(i) * 2.1)
		_model_at(&"tree_conifer", Vector3(x, GRADE - 0.2, 39.2), float(i) * 0.9,
			{"colour": Color(0.075, 0.070, 0.065),
			"leaf_colour": Color(0.045, 0.055, 0.048),
			"variant": float(i) * 1.7}, 1.3 + 0.45 * sin(float(i) * 3.3))
	for i in 7:
		var z := -34.0 + float(i) * 5.6
		_model_at(&"tree_conifer", Vector3(-38.6, GRADE - 0.2, z), float(i) * 1.3,
			{"colour": Color(0.075, 0.070, 0.065),
			"leaf_colour": Color(0.045, 0.055, 0.048),
			"variant": float(i) * 2.3}, 1.2 + 0.4 * cos(float(i) * 2.7))

	# Invisible walls, with the exit lane deliberately still inside them: a rig
	# is an AnimatableBody3D (a StaticBody subclass), so it drives straight
	# through these and out of the world, while the goose riding it does not.
	# Being scraped off the roof at the property line is the correct end to that
	# joke — the ride puts you sixty metres from where you started either way.
	for i in 4:
		var a := float(i) * PI * 0.5
		_hide_meshes(_static_box(
			Vector3(sin(a) * LOT * 0.5, 11.0, cos(a) * LOT * 0.5),
			Vector3(LOT, 30.0, 1.0), Color(1, 1, 1), a))


# ══════════════════════════════════════════════════════════ THE FLOODED CORNER
#
# The spec replaces the strip mall's retention pond with "a flooded corner of
# the lot". Sixteen metres square and thirty centimetres deep, which is enough
# for the swim state (see the wade-line arithmetic in the header) and not so
# much that it stops reading as a parking lot with a drainage problem.
#
# It is also the zone's darkest surface by a long way, which is the whole point:
# the sodium lamp on its east shore lands a pool on it, and standing water is
# the only thing in the lot that reflects.

func _flood() -> void:
	var cx := (FLOOD_X0 + FLOOD_X1) * 0.5
	var cz := (FLOOD_Z0 + FLOOD_Z1) * 0.5
	var w := FLOOD_X1 - FLOOD_X0
	var d := FLOOD_Z1 - FLOOD_Z0

	# ── the surface ─────────────────────────────────────────────────────
	# Tiled for the light-cap reason in _flat_tiles, and because one 16 m quad
	# with a normal map gets exactly one specular highlight for the whole
	# puddle, which is the least convincing water anyone has ever shipped.
	var wm := StandardMaterial3D.new()
	# 0.52, not the cottage lake's 0.88. That lake is thirty-five metres of black
	# water and wants to be nearly opaque; this is THIRTY CENTIMETRES of standing
	# rain over painted asphalt, and the painted asphalt showing through is the
	# only reason anybody can tell it is water at all.
	wm.albedo_color = Color(0.030, 0.032, 0.040, 0.52)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.roughness = 0.05
	wm.metallic = 0.90
	# Emission, low and warm. Standing water at night is not self-luminous, but
	# water rendered at true zero is a hole in the world and the player flies
	# into it. This is the smallest lie that keeps the surface legible from the
	# top of a trailer.
	wm.emission_enabled = true
	wm.emission = Color(0.28, 0.18, 0.09)
	wm.emission_energy_multiplier = 0.55
	if _tex != null:
		var nrm: Texture2D = _tex.get_tex(&"water_normal")
		if nrm != null:
			wm.normal_enabled = true
			wm.normal_texture = nrm
			wm.normal_scale = 0.70
			wm.uv1_scale = Vector3(7.0, 7.0, 7.0)
	for ix in 4:
		for iz in 4:
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(w / 4.0, 0.06, d / 4.0)
			mi.mesh = bm
			mi.material_override = wm
			add_child(mi)
			mi.global_position = Vector3(
				FLOOD_X0 + (w / 4.0) * (float(ix) + 0.5), GRADE - 0.03,
				FLOOD_Z0 + (d / 4.0) * (float(iz) + 0.5))

	# ── the swimmable volume ────────────────────────────────────────────
	# Inset by 0.7 m so a bird standing on dry pavement at the very lip is never
	# told it is swimming.
	var water := Area3D.new()
	water.add_to_group("water")
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(w - 1.4, 2.4, d - 1.4)
	cs.shape = bs
	water.add_child(cs)
	water.monitoring = false
	add_child(water)
	water.global_position = Vector3(cx, 0.20 - 1.2, cz)

	# ── wade ramps on all four sides ────────────────────────────────────
	# There is deliberately no edge of this puddle you can swim up to and be
	# unable to get out of. A thirty-centimetre kerb is right at the limit of
	# what a horizontal capsule will climb, and "I am stuck in a puddle" is not
	# difficulty, it is a bug with a story. Same rule the cottage's shoreline
	# follows for the same reason.
	var col := C_ASPHALT.darkened(0.15)
	_ramp(Vector3(cx, GRADE, FLOOD_Z1), Vector3(cx, BED_Y, FLOOD_Z1 - 1.8), w, 0.26, col)
	_ramp(Vector3(cx, GRADE, FLOOD_Z0), Vector3(cx, BED_Y, FLOOD_Z0 + 1.8), w, 0.26, col)
	_ramp(Vector3(FLOOD_X1, GRADE, cz), Vector3(FLOOD_X1 - 1.8, BED_Y, cz), d, 0.26, col)
	_ramp(Vector3(FLOOD_X0, GRADE, cz), Vector3(FLOOD_X0 + 1.8, BED_Y, cz), d, 0.26, col)

	# ── THE ONE UNAMBIGUOUS "THIS IS WATER" CUE ─────────────────────────
	# Four painted stall lines that walk off the dry lot and carry on under the
	# surface, dimmer and colder. The first render of this corner was legible as
	# "a slightly darker rectangle of tarmac" and nothing else, which is the
	# exact trap this project has hit twice: a translucent dark plane over dark
	# ground renders as nothing, and the strip mall's pond needed a mud basin
	# behind it before anybody could see there was water in it. A line that
	# crosses the boundary and goes dim cannot be misread.
	for i in 4:
		var lx := -30.0 + float(i) * 4.0
		_decal_box(Vector3(lx, GRADE + 0.02, FLOOD_Z1 + 4.0), Vector3(0.14, 0.04, 8.0),
			Color(0.58, 0.56, 0.42))
		_decal_box(Vector3(lx, BED_Y + 0.03, cz + 1.0), Vector3(0.14, 0.04, 13.6),
			Color(0.52, 0.50, 0.40))

	# A storm drain in the middle of it, doing nothing. It is the joke and it is
	# four boxes.
	_decal_box(Vector3(cx + 2.0, GRADE - 0.26, cz - 1.0), Vector3(1.1, 0.06, 0.7),
		Color(0.045, 0.045, 0.050))
	for i in 4:
		_decal_box(Vector3(cx + 1.6 + float(i) * 0.26, GRADE - 0.22, cz - 1.0),
			Vector3(0.06, 0.05, 0.62), Color(0.16, 0.16, 0.17))

	# Weeds through the cracks along the flood's dry margin — the only green in
	# the zone, and it is where the grass source lives.
	for i in 14:
		var a := float(i) * 2.39
		_model_at(&"cattail", Vector3(FLOOD_X1 + 0.9 + 0.7 * absf(sin(a)), GRADE,
			FLOOD_Z0 + 1.4 + float(i) * 1.05), a,
			{"colour": Color(0.20, 0.24, 0.14)}, 0.55 + 0.25 * absf(cos(a)))


# ══════════════════════════════════════════════ THE TRAVEL CENTRE AND DINER
#
# One long low building across the north side, with the store at the west end
# and the diner at the east. The lot-facing wall is at z = +26, so every sign on
# it has an outward normal of -Z, which is the exact facing that ships mirrored
# text. All of them go through TS.sign_text().

const BLD_X0 := -34.0
const BLD_X1 := 4.0
const BLD_Z0 := 26.0
const BLD_Z1 := 38.0
const WALK_Z0 := 21.6
const DINER_X0 := -9.0     ## the diner occupies x -9 .. +4 of the facade

func _building() -> void:
	var cx := (BLD_X0 + BLD_X1) * 0.5
	var cz := (BLD_Z0 + BLD_Z1) * 0.5
	var w := BLD_X1 - BLD_X0
	var d := BLD_Z1 - BLD_Z0

	# ── the shell ───────────────────────────────────────────────────────
	# The store half is solid to the facade. The diner half is recessed 1.4 m,
	# which is the window bay you can see into (and, once the glass is gone,
	# stand in).
	_static_tex(Vector3((BLD_X0 + DINER_X0) * 0.5, ROOF_Y * 0.5, cz),
		Vector3(DINER_X0 - BLD_X0, ROOF_Y, d), &"stucco", 3.4, Color(0.30, 0.28, 0.25))
	_static_tex(Vector3((DINER_X0 + BLD_X1) * 0.5, ROOF_Y * 0.5, (BLD_Z0 + 1.4 + BLD_Z1) * 0.5),
		Vector3(BLD_X1 - DINER_X0, ROOF_Y, BLD_Z1 - BLD_Z0 - 1.4), &"stucco", 3.4,
		Color(0.30, 0.28, 0.25))
	# Brick base course, and brick end caps, so 38 m of stucco has a scale.
	_static_tex(Vector3(cx, 0.55, BLD_Z0 - 0.12), Vector3(w, 1.10, 0.30), &"brick", 2.2,
		Color(0.30, 0.19, 0.16))
	for sx in [BLD_X0 + 0.4, BLD_X1 - 0.4]:
		var ex: float = sx
		_static_tex(Vector3(ex, ROOF_Y * 0.5, cz), Vector3(0.9, ROOF_Y + 0.1, d + 0.2),
			&"brick", 2.4, Color(0.30, 0.19, 0.16))

	# ── the roof, landable ──────────────────────────────────────────────
	var roof := _static_box(Vector3(cx, ROOF_Y - 0.15, cz), Vector3(w, 0.30, d),
		Color(0.16, 0.16, 0.17))
	_hide_meshes(roof)
	_flat_tiles(Vector3(cx, ROOF_Y - 0.01, cz), Vector3(w, 0.08, d), 4, 2,
		&"asphalt", Color(0.115, 0.112, 0.115), 3.0)
	# Parapet. Visual only — a 40 cm lip that catches a goose mid-landing is the
	# difference between a roof and a trap.
	for e in [[cx, BLD_Z0 - 0.1, w, 0.24], [cx, BLD_Z1 + 0.1, w, 0.24]]:
		var r: Array = e
		_decal_box(Vector3(r[0], ROOF_Y + 0.22, r[1]), Vector3(r[2], 0.44, r[3]),
			Color(0.26, 0.25, 0.23))
	for ex2 in [BLD_X0 - 0.1, BLD_X1 + 0.1]:
		var px: float = ex2
		_decal_box(Vector3(px, ROOF_Y + 0.22, cz), Vector3(0.24, 0.44, d),
			Color(0.26, 0.25, 0.23))
	# Rooftop units, the one thing that stops a flat roof reading as a table.
	for i in 4:
		_decal_box(Vector3(BLD_X0 + 6.0 + float(i) * 9.0, ROOF_Y + 0.75, cz + 1.5),
			Vector3(2.6, 1.5, 2.6), Color(0.36, 0.36, 0.38))

	# ── the walk and its awning ─────────────────────────────────────────
	_flat_tiles(Vector3(cx, GRADE + 0.04, (WALK_Z0 + BLD_Z0) * 0.5),
		Vector3(w, 0.08, BLD_Z0 - WALK_Z0), 4, 1, &"concrete", Color(0.30, 0.29, 0.28), 5.0)
	var awn := _static_box(Vector3(cx, 3.42, (WALK_Z0 + BLD_Z0) * 0.5 + 0.2),
		Vector3(w - 1.0, 0.22, BLD_Z0 - WALK_Z0 - 0.4), Color(0.22, 0.22, 0.24))
	_hide_meshes(awn)
	_decal_box(Vector3(cx, 3.42, (WALK_Z0 + BLD_Z0) * 0.5 + 0.2),
		Vector3(w - 1.0, 0.20, BLD_Z0 - WALK_Z0 - 0.4), Color(0.20, 0.20, 0.22))
	# The lit soffit strip under the awning. Cheap, and it is what makes the
	# walk read as somewhere you can shelter.
	_glow_box(Vector3(cx, 3.30, (WALK_Z0 + BLD_Z0) * 0.5 + 0.2),
		Vector3(w - 2.4, 0.05, 0.5), Color(0.72, 0.74, 0.66))
	for i in 6:
		var px2 := BLD_X0 + 3.0 + float(i) * 6.4
		_decal_box(Vector3(px2, 1.66, WALK_Z0 + 0.5), Vector3(0.14, 3.32, 0.14),
			Color(0.24, 0.24, 0.26))

	# ── the window band ─────────────────────────────────────────────────
	# The store's windows are one continuous fluorescent glow. The diner's are
	# five separate breakable panes — see _diner_panes().
	_glow_box(Vector3((BLD_X0 + DINER_X0) * 0.5 + 0.4, 2.05, BLD_Z0 - 0.28),
		Vector3(DINER_X0 - BLD_X0 - 3.0, 2.2, 0.06), Color(0.74, 0.77, 0.74))
	_decal_box(Vector3((BLD_X0 + DINER_X0) * 0.5 + 0.4, 2.05, BLD_Z0 - 0.20),
		Vector3(DINER_X0 - BLD_X0 - 2.6, 2.36, 0.10), Color(0.19, 0.19, 0.20))
	for i in 5:
		_decal_box(Vector3(BLD_X0 + 3.4 + float(i) * 4.4, 2.05, BLD_Z0 - 0.30),
			Vector3(0.16, 2.36, 0.12), Color(0.22, 0.22, 0.23))

	_diner_bay()
	_diner_panes()

	# ── signage ─────────────────────────────────────────────────────────
	# Every one of these is on the z = 26 facade, normal -Z. `sign_text` puts the
	# pen on `up x normal`, which for this face is -X, so they read.
	var facade := BLD_Z0 - 0.34
	_decal_box(Vector3((BLD_X0 + DINER_X0) * 0.5, 4.05, BLD_Z0 - 0.16),
		Vector3(DINER_X0 - BLD_X0 - 1.0, 1.5, 0.16), Color(0.11, 0.13, 0.20))
	# Both lines live ABOVE y = 3.6. The awning is a solid slab at 3.32-3.53
	# spanning four metres of Z, so anything painted lower than that on the
	# facade is occluded from everywhere in the lot except directly underneath
	# it — which is where the first render put "SHOWERS / SCALE", invisibly.
	_sign_centred("TRAVEL CENTER", Vector3(-21.5, 4.70, facade), 0.68,
		Color(0.98, 0.90, 0.62))
	_sign_centred("SHOWERS  /  SCALE", Vector3(-21.5, 3.92, facade), 0.28,
		Color(0.55, 0.86, 1.00))

	# The diner sign, in red, over the bay.
	_decal_box(Vector3(-2.4, 4.05, BLD_Z0 - 0.16), Vector3(12.0, 1.5, 0.16),
		Color(0.18, 0.07, 0.07))
	_sign_centred("EAT", Vector3(-2.4, 4.74, facade), 1.02, Color(1.00, 0.28, 0.22))
	# Neon in the window, so it hangs off the glass rather than floating a metre
	# and a half in front of it.
	_sign_centred("OPEN 24 HRS", Vector3(-2.4, 1.05, BLD_Z0 - 0.42), 0.30,
		Color(0.40, 1.00, 0.62))


## Centre a string on `centre` (which is the MIDDLE of the cap line) on a face
## whose normal is -Z. Sign layout is done in one place because the offset that
## centres a string is `-right * width * 0.5`, and `right` is the thing this
## project keeps getting backwards.
func _sign_centred(text: String, centre: Vector3, h: float, col: Color) -> void:
	var right := Vector3.UP.cross(Vector3(0, 0, -1))   # = -X
	var w: float = TS.text_width(text, h)
	TS.sign_text(self, text, centre - right * (w * 0.5), Vector3(0, 0, -1),
		Vector3.UP, h, col)


## The diner interior, as a 1.4 m diorama rather than a room. At night, through
## glass, from outside, a bay this deep is indistinguishable from a real
## interior and costs about fifteen boxes. It also gives the one human in the
## zone somewhere to be, and — once the glass is gone — gives the goose a place
## to end up that it very obviously should not be.
func _diner_bay() -> void:
	var floor_y := GRADE + 0.30
	var f := _static_box(Vector3(-2.4, floor_y - 0.15, BLD_Z0 + 0.70),
		Vector3(13.0, 0.30, 1.40), Color(0.42, 0.40, 0.36))
	_hide_meshes(f)
	_flat_tiles(Vector3(-2.4, floor_y - 0.01, BLD_Z0 + 0.70), Vector3(13.0, 0.06, 1.40),
		3, 1, &"concrete", Color(0.52, 0.50, 0.46), 3.0)
	# The counter, a coffee urn, and four stools with nobody on them.
	_static_box(Vector3(-2.4, floor_y + 0.50, BLD_Z0 + 1.15), Vector3(12.4, 1.00, 0.55),
		Color(0.44, 0.34, 0.26))
	_decal_box(Vector3(-2.4, floor_y + 1.03, BLD_Z0 + 1.15), Vector3(12.6, 0.06, 0.66),
		Color(0.62, 0.58, 0.50))
	for i in 4:
		var sx := -6.6 + float(i) * 2.8
		_decal_box(Vector3(sx, floor_y + 0.32, BLD_Z0 + 0.42), Vector3(0.09, 0.64, 0.09),
			Color(0.52, 0.52, 0.54))
		_decal_box(Vector3(sx, floor_y + 0.68, BLD_Z0 + 0.42), Vector3(0.38, 0.09, 0.38),
			Color(0.62, 0.18, 0.16))
	_decal_box(Vector3(2.0, floor_y + 1.22, BLD_Z0 + 1.20), Vector3(0.42, 0.32, 0.32),
		Color(0.70, 0.70, 0.72))
	_glow_box(Vector3(2.0, floor_y + 1.42, BLD_Z0 + 1.20), Vector3(0.16, 0.05, 0.16),
		Color(1.00, 0.42, 0.30))
	# The strip light in the ceiling of the bay, which is what actually makes the
	# window read as "there is a room behind this".
	_glow_box(Vector3(-2.4, floor_y + 2.30, BLD_Z0 + 0.80), Vector3(11.0, 0.06, 0.40),
		Color(0.92, 0.92, 0.84))


## Five panes of diner glass. Each is a real collider plus an unshaded warm
## quad, with a trigger volume in front of it; hit one at speed and it goes.
##
## Deliberately NOT ChaosProps: a pane of glass modelled as a rigid body falls
## over the moment the physics starts, and a 4 x 2 m sheet that has toppled onto
## the walk is a much worse object than one that is either there or gone. This is
## suburbia's bespoke-moment pattern, with the bug that suburbia has fixed —
## `_break_pane()` calls Game.score() with a label the objectives actually watch
## for, so the primary can complete.
func _diner_panes() -> void:
	for i in 5:
		var px := -8.0 + float(i) * 2.8
		var sb := _static_box(Vector3(px, 1.90, BLD_Z0 - 0.14), Vector3(2.55, 2.5, 0.10),
			Color(0.10, 0.13, 0.14))
		_hide_meshes(sb)
		var g := _glow_box(Vector3(px, 1.90, BLD_Z0 - 0.16), Vector3(2.5, 2.46, 0.05),
			Color(0.98, 0.80, 0.46))
		# Mullions between the panes, so the band reads as glazing and not as one
		# lit slab. These stay when the glass goes, which is the correct look.
		_decal_box(Vector3(px - 1.40, 1.90, BLD_Z0 - 0.22), Vector3(0.14, 2.60, 0.14),
			Color(0.20, 0.20, 0.21))
		var area := Area3D.new()
		add_child(area)
		area.global_position = Vector3(px, 1.90, BLD_Z0 - 0.55)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(2.5, 2.5, 0.9)
		cs.shape = bs
		area.add_child(cs)
		area.monitoring = true
		area.monitorable = false
		_pane_area.append(area)
		_pane_mesh.append(g)
		_pane_body.append(sb)
		_pane_gone.append(false)
	_decal_box(Vector3(-4.6, 1.90, BLD_Z0 - 0.22), Vector3(0.14, 2.60, 0.14),
		Color(0.20, 0.20, 0.21))


# ══════════════════════════════════════════════════════════ THE DUMPSTER CORRAL
#
# §2.7 names the dumpster corral as one of the five things a leg-7 primary has
# to be writable from. So it is a real place: three skips inside a three-sided
# block wall behind the diner, with the week's cardboard stacked against it. The
# wall is 2.0 m — one flap from the asphalt, and low enough that the whole thing
# is visible from above, which is how the player finds it.

func _corral() -> void:
	var cx := 17.0
	var cz := 31.0
	var wall := Color(0.34, 0.32, 0.30)
	# Three sides: back (+Z), east (+X), west (-X). Open to the lot at -Z.
	_static_tex(Vector3(cx, 1.0, cz + 4.4), Vector3(14.4, 2.0, 0.4), &"concrete", 3.0, wall)
	_static_tex(Vector3(cx - 7.0, 1.0, cz), Vector3(0.4, 2.0, 9.2), &"concrete", 3.0, wall)
	_static_tex(Vector3(cx + 7.0, 1.0, cz), Vector3(0.4, 2.0, 9.2), &"concrete", 3.0, wall)
	_flat_tiles(Vector3(cx, GRADE + 0.03, cz), Vector3(14.0, 0.06, 9.0), 2, 1,
		&"concrete", Color(0.26, 0.25, 0.24), 4.0)
	# One caged light on the back wall. It is the only light in the corral and it
	# is what makes three skips in a dark box worth flying into.
	_lamp(Vector3(cx, 2.35, cz + 3.9), Color(0.92, 0.86, 0.58), 3.2, 14.0)
	_glow_box(Vector3(cx, 2.16, cz + 4.16), Vector3(0.44, 0.22, 0.10),
		Color(0.98, 0.92, 0.70))

	for i in 3:
		var d := _prop(Vector3(cx - 4.6 + float(i) * 4.6, 1.12, cz + 2.4),
			Vector3(3.50, 2.25, 2.10), Color(0.20, 0.34, 0.26), 260.0, 110, "DUMPSTER")
		d.breakable = false
		d.break_force = 999.0
		d.rotation.y = 0.04 * float(i) - 0.04
	for i in 6:
		var a := float(i) * 1.9
		_prop(Vector3(cx - 5.0 + float(i) * 2.0, 0.30, cz - 2.6 + 1.2 * sin(a)),
			Vector3(0.48, 0.55, 0.50), Color(0.10, 0.10, 0.12), 3.0, 18, "GARBAGE",
			{"variant": float(i) * 1.3})
	for i in 6:
		_prop(Vector3(cx + 4.2 + 0.35 * float(i % 2), 0.10 + float(i) * 0.18, cz - 0.6),
			Vector3(1.20, 0.16, 1.00), Color(0.46, 0.36, 0.24), 6.0, 26, "PALLET",
			{"variant": float(i) * 2.1})
	for i in 2:
		_prop(Vector3(cx - 6.0, 0.64, cz - 3.4 + float(i) * 1.6),
			Vector3(1.00, 1.20, 0.80), Color(0.15, 0.30, 0.52), 8.0, 40, "RECYCLING")


# ══════════════════════════════════════════════════════════════ THE FUEL CANOPY
#
# The only cold light in an orange zone, and the only piece of architecture the
# player can stand on top of. Two pump islands under a 20 x 13 roof at 6.2 m.

const CANOPY_X := -21.0
const CANOPY_Z := 10.0

func _canopy() -> void:
	# Roof slab, landable.
	var roof := _static_box(Vector3(CANOPY_X, (CANOPY_UNDER + CANOPY_Y) * 0.5, CANOPY_Z),
		Vector3(20.0, CANOPY_Y - CANOPY_UNDER, 13.0), Color(0.30, 0.30, 0.32))
	_hide_meshes(roof)
	_flat_tiles(Vector3(CANOPY_X, CANOPY_Y - 0.02, CANOPY_Z), Vector3(20.0, 0.08, 13.0),
		3, 2, &"metal_panel", Color(0.28, 0.28, 0.30), 3.0)
	# The underside — pale, because a canopy soffit is a giant reflector and it
	# is most of why the light under one is so much brighter than the lot.
	_decal_box(Vector3(CANOPY_X, CANOPY_UNDER + 0.04, CANOPY_Z), Vector3(19.6, 0.10, 12.6),
		Color(0.60, 0.62, 0.64))
	# The lit fascia band, all four sides. The single most recognisable thing
	# about a fuel canopy at night.
	for e in [[0.0, -6.6, 20.2, 0.16], [0.0, 6.6, 20.2, 0.16]]:
		var r: Array = e
		_decal_box(Vector3(CANOPY_X + r[0], CANOPY_UNDER - 0.30, CANOPY_Z + r[1]),
			Vector3(r[2], 0.72, r[3] + 0.10), Color(0.24, 0.24, 0.26))
		_glow_box(Vector3(CANOPY_X + r[0], CANOPY_UNDER - 0.30, CANOPY_Z + r[1] * 1.02),
			Vector3(r[2] - 0.6, 0.44, r[3]), Color(0.92, 0.95, 1.00))
	for sx in [-10.1, 10.1]:
		var ex: float = sx
		_decal_box(Vector3(CANOPY_X + ex, CANOPY_UNDER - 0.30, CANOPY_Z),
			Vector3(0.26, 0.72, 13.2), Color(0.24, 0.24, 0.26))
		_glow_box(Vector3(CANOPY_X + ex * 1.02, CANOPY_UNDER - 0.30, CANOPY_Z),
			Vector3(0.16, 0.44, 12.6), Color(0.92, 0.95, 1.00))
	# FUEL, on the lot-facing fascia (normal -Z).
	# +/-7.0, not -6.78: the fascia's own glow band reaches to 6.73 and the first
	# pass buried the letters inside it. Both faces, because half the lot
	# approaches this from the north. And a bright blue rather than a corporate
	# one — these are UNSHADED faces, so an unshaded dark blue renders as exactly
	# dark blue, at 3 a.m., against a white band.
	for sgn2 in [-1.0, 1.0]:
		var sz2: float = sgn2
		var n2 := Vector3(0, 0, sz2)
		var r2 := Vector3.UP.cross(n2)
		var fw: float = TS.text_width("FUEL", 0.34)
		TS.sign_text(self, "FUEL",
			Vector3(CANOPY_X, CANOPY_UNDER - 0.14, CANOPY_Z + sz2 * 7.0) - r2 * (fw * 0.5),
			n2, Vector3.UP, 0.34, Color(0.24, 0.56, 0.98))

	# Six columns.
	for ix in 3:
		for iz in 2:
			var px := CANOPY_X - 8.0 + float(ix) * 8.0
			var pz := CANOPY_Z - 4.5 + float(iz) * 9.0
			_static_box(Vector3(px, CANOPY_UNDER * 0.5, pz),
				Vector3(0.7, CANOPY_UNDER, 0.7), Color(0.34, 0.34, 0.36))

	# Four cool-white sources under the roof. Deliberately much brighter than
	# anything else in the zone.
	for ix2 in 2:
		for iz2 in 2:
			_lamp(Vector3(CANOPY_X - 5.0 + float(ix2) * 10.0, CANOPY_UNDER - 0.45,
				CANOPY_Z - 3.2 + float(iz2) * 6.4), C_CANOPY, 6.2, 20.0)

	# Two pump islands, raised kerbs with two dispensers each.
	for iz3 in 2:
		var iz_z := CANOPY_Z - 3.4 + float(iz3) * 6.8
		_static_box(Vector3(CANOPY_X, GRADE + 0.09, iz_z), Vector3(13.0, 0.18, 1.5),
			Color(0.40, 0.39, 0.36))
		for ix3 in 2:
			var px3 := CANOPY_X - 3.6 + float(ix3) * 7.2
			var pump := _static_box(Vector3(px3, GRADE + 1.20, iz_z),
				Vector3(0.92, 2.05, 0.72), Color(0.72, 0.70, 0.66))
			_model_body(pump, &"fuel_pump", -1.025)
			# Bollards. Yellow, because they are always yellow, and they make the
			# island read as a hazard you can trip over — which it is.
			for sx4 in [-1.0, 1.0]:
				var bx: float = sx4
				_decal_box(Vector3(px3 + bx * 1.5, GRADE + 0.62, iz_z),
					Vector3(0.20, 1.24, 0.20), Color(0.78, 0.64, 0.16))

	# Under-canopy pool. It is white, not orange, and it is the one place on the
	# lot where the wet asphalt reads cold.
	_pool(Vector3(CANOPY_X, GRADE + 0.01, CANOPY_Z - 7.6), 5.2,
		Color(0.86, 0.92, 1.00), Vector3(0, 0, -1))


# ══════════════════════════════════════════════════════════════ THE PYLON SIGN
#
# The thing you see from the interstate, and the zone's tallest object. It is
# also the reason `sign_text()` exists: a pylon is two words and a number, on a
# face pointing -Z, eleven metres up, where being mirrored would be the most
# visible bug in the game.

func _pylon() -> void:
	var px := -30.0
	var pz := 2.0
	# 8.3, not 8.8. The panel's bottom edge is at 8.1 and the first render had
	# half a metre of pole standing in front of "3.79" and all of
	# "SHOWERS CB ICE", which had been written below the panel entirely.
	_static_box(Vector3(px, 4.15, pz), Vector3(1.1, 8.3, 1.1), Color(0.26, 0.26, 0.28))
	_decal_box(Vector3(px, 9.85, pz), Vector3(7.4, 3.5, 0.7), Color(0.10, 0.11, 0.16))
	_decal_box(Vector3(px, 9.85, pz + 0.36), Vector3(7.6, 3.7, 0.10), Color(0.30, 0.30, 0.32))
	_glow_box(Vector3(px, 9.85, pz - 0.36), Vector3(7.0, 3.1, 0.06), Color(0.16, 0.17, 0.26))
	_glow_box(Vector3(px, 9.85, pz + 0.36), Vector3(7.0, 3.1, 0.06), Color(0.16, 0.17, 0.26))
	# BOTH FACES. A pylon points at the road, which here is -Z, so a player
	# standing in the lot reads the BACK of it — which is exactly what the first
	# render showed: a blank grey billboard. Every real one is double-sided, and
	# doing it here is also the proof that `sign_text` handles the +Z facing as
	# well as the -Z one. `up x normal` is -X on one side and +X on the other.
	for sgn in [-1.0, 1.0]:
		var sz: float = sgn
		var n := Vector3(0, 0, sz)
		var face := pz + sz * 0.42
		var right := Vector3.UP.cross(n)
		var w1: float = TS.text_width("DIESEL", 1.15)
		TS.sign_text(self, "DIESEL", Vector3(px, 11.15, face) - right * (w1 * 0.5),
			n, Vector3.UP, 1.15, Color(1.00, 0.84, 0.30))
		var w2: float = TS.text_width("3.79", 0.95)
		TS.sign_text(self, "3.79", Vector3(px, 9.75, face) - right * (w2 * 0.5),
			n, Vector3.UP, 0.95, Color(1.00, 0.30, 0.24))
		var w3: float = TS.text_width("SHOWERS  CB  ICE", 0.30)
		TS.sign_text(self, "SHOWERS  CB  ICE", Vector3(px, 8.66, face) - right * (w3 * 0.5),
			n, Vector3.UP, 0.30, Color(0.68, 0.86, 1.00))
	_lamp(Vector3(px, 8.6, pz - 1.6), Color(0.98, 0.86, 0.60), 1.6, 9.0)


# ══════════════════════════════════════════════════════════════════ THE LAMPS

func _lamps() -> void:
	for i in range(LAMPS.size()):
		var row: Array = LAMPS[i]
		var x: float = row[0]
		var z: float = row[1]
		var yaw: float = row[2]
		# Collider is the pole only. Nothing should ever collide with a mast arm
		# nine metres up, and a goose that catches on one is a goose that stopped
		# being funny.
		var pole := _static_box(Vector3(x, 4.3, z), Vector3(0.34, 8.6, 0.34),
			Color(0.24, 0.235, 0.25))
		_model_body(pole, &"sodium_lamp", -4.3, {})
		# The head is 1.8 m out along the model's +X, rotated by the pole's yaw.
		var head := Vector3(x + cos(yaw) * 1.8, 8.62, z - sin(yaw) * 1.8)
		_lamp_lights.append(_lamp(head, C_SODIUM, 3.4, 26.0))
		# The pool it throws, and the smear running away from the pole — which is
		# what a lamp reflected in standing water looks like from a low camera.
		_pool(Vector3(head.x, GRADE + 0.01, head.z), 6.4, C_SODIUM,
			Vector3(head.x - x, 0, head.z - z))
		# Moths. Five per lamp on the three the player spends the most time
		# under. It is the single most 3 a.m. detail available and it costs
		# fifteen unshaded boxes.
		if i < 3:
			for k in 5:
				var m := _glow_box(head + Vector3(0, -0.4, 0), Vector3(0.075, 0.045, 0.075),
					Color(0.92, 0.88, 0.72))
				m.set_meta("anchor", head)
				m.set_meta("phase", float(i) * 2.3 + float(k) * 1.27)
				_moths.append(m)


# ══════════════════════════════════════════════════════════════ THE TRUCK ROW

func _truck_row() -> void:
	# Two lights that travel with whichever rig is rolling. Made once and moved,
	# rather than one pair per rig, because twelve headlights would eat half the
	# frame's light budget on lamps nobody navigates by.
	_head_light = _lamp(Vector3(0, -50, 0), Color(1.00, 0.96, 0.86), 3.6, 22.0)
	_head_light.visible = false
	# Small and short. The first render put a 2.2-energy red omni one metre from
	# the spawn point and a third of the frame was a red haze.
	_tail_light = _lamp(Vector3(0, -50, 0), Color(1.00, 0.22, 0.16), 0.95, 7.0)
	_tail_light.visible = false

	for i in range(BAY_X.size()):
		var bx: float = BAY_X[i]
		var body := AnimatableBody3D.new()
		body.sync_to_physics = true
		add_child(body)
		body.global_position = Vector3(bx, GRADE, BAY_Z)

		# ── colliders: the tractor and the box, nothing else ────────────
		# Physics is boxes here for the same reason it is boxes everywhere else
		# in this project: a goose landing on a trailer roof has to get a
		# collision normal it can stand on, and it has to be the same normal
		# every time.
		var cab := CollisionShape3D.new()
		var cabs := BoxShape3D.new()
		cabs.size = Vector3(2.56, 3.96, 7.0)
		cab.shape = cabs
		cab.position = Vector3(0, 1.98, -0.10)
		body.add_child(cab)
		var box := CollisionShape3D.new()
		var boxs := BoxShape3D.new()
		boxs.size = Vector3(2.60, 2.90, 14.60)
		box.shape = boxs
		box.position = Vector3(0, 2.60, 10.60)
		body.add_child(box)

		var col: Color = RIG_COLOURS[i]
		TS.build(&"semi_tractor", body, {"colour": col, "lit": true})
		var tnode := Node3D.new()
		body.add_child(tnode)
		tnode.position = Vector3(0, 0, 10.60)
		# 0.30 of the tractor's colour, not 0.12: at 0.12 the six trailers were
		# one indistinguishable pale wall under sodium, and a row you cannot
		# count is a row you cannot plan a route through.
		var tmodel: Node3D = TS.build(&"trailer", tnode, {
			"colour": Color(0.66, 0.66, 0.69).lerp(col, 0.30),
			"trim_colour": Color(0.20, 0.20, 0.23),
		})
		_rig_glow.append(tmodel.get_node_or_null("Glow"))

		# ── the name, on both flanks ────────────────────────────────────
		# THE decal hazard. A trailer flank has normal +/-X; `sign_text` puts the
		# pen on `up x normal`, which is -Z on the +X flank and +Z on the -X
		# flank. Hard-coding +X here is exactly how ƎƆIVЯƎƧ shipped.
		var nm: String = RIG_NAMES[i]
		var nw: float = TS.text_width(nm, 0.62)
		for sgn in [-1.0, 1.0]:
			var sx: float = sgn
			var n := Vector3(sx, 0, 0)
			var r := Vector3.UP.cross(n)
			TS.sign_text(tnode, nm,
				Vector3(sx * 1.36, 3.30, 0.0) - r * (nw * 0.5), n, Vector3.UP, 0.62,
				Color(0.94, 0.92, 0.88).lerp(col, 0.55), false, 0.03)

		# ── the roof trigger ────────────────────────────────────────────
		var roof := Area3D.new()
		body.add_child(roof)
		roof.position = Vector3(0, TRAILER_ROOF + 0.72, 10.60)
		var rcs := CollisionShape3D.new()
		var rbs := BoxShape3D.new()
		rbs.size = Vector3(2.50, 1.44, 14.00)
		rcs.shape = rbs
		roof.add_child(rcs)
		roof.monitoring = true
		roof.monitorable = false

		_rig_body.append(body)
		_rig_roof.append(roof)
		_rig_state.append(RigState.PARKED)
		_rig_arm.append(0.0)
		_rig_speed.append(0.0)
		_rig_yaw.append(0.0)
		_rig_ride.append(0.0)
		_rig_boarded.append(false)
		_rig_rode.append(false)

		# Chocks and cones around the wheels, which is both true and the cheapest
		# way to say "this thing is parked, for now".
		for k in 2:
			_prop(Vector3(bx - 1.3 + float(k) * 2.6, GRADE + 0.14, BAY_Z + 15.0),
				Vector3(0.30, 0.24, 0.44), Color(0.84, 0.68, 0.14), 1.5, 14, "CHOCK")
	_rigs_left = _rig_body.size()


# ══════════════════════════════════════════════════════════ PAINT AND THE BERM

func _paint() -> void:
	# ── car stalls, in front of the travel centre ───────────────────────
	for i in 13:
		_decal_box(Vector3(-34.0 + float(i) * 2.6, GRADE + 0.02, 18.4),
			Vector3(0.12, 0.04, 5.0), Color(0.62, 0.60, 0.44))
	# ── truck bay lines ─────────────────────────────────────────────────
	for i in range(BAY_X.size() + 1):
		_decal_box(Vector3(BAY_X[0] - 3.2 + float(i) * 6.4, GRADE + 0.02, 4.0),
			Vector3(0.16, 0.04, 22.0), Color(0.60, 0.58, 0.42))
	# ── the lane markings out to the exit ───────────────────────────────
	for i in 14:
		_decal_box(Vector3(14.0 - float(i) * 3.4, GRADE + 0.02, EXIT_Z),
			Vector3(2.0, 0.04, 0.16), Color(0.60, 0.58, 0.42))

	# ── the ground lettering ────────────────────────────────────────────
	# Read by somebody walking or driving toward -Z, so `up` on the painted plane
	# is -Z. Pass the wrong `up` here and it is upside down rather than mirrored,
	# which is a different bug with the same cause.
	_ground_text("TRUCKS", Vector3(20.0, GRADE + 0.04, 17.0), 2.2, Color(0.72, 0.70, 0.55))
	# The best joke available in a parking lot at 3 a.m. is a sign that everyone
	# is ignoring, and every engine in this row is running.
	_ground_text("NO IDLING", Vector3(20.0, GRADE + 0.04, -14.0), 1.5,
		Color(0.66, 0.64, 0.50))

	# ── the interstate, over the berm ───────────────────────────────────
	# A grass bank across the south end with two rivers of headlights on it. It
	# is out of reach, it is the only motion on the horizon, and it is where the
	# player is about to have to go.
	var berm := _static_box(Vector3(0, 1.1, -38.4), Vector3(LOT, 2.2, 4.0),
		Color(0.14, 0.16, 0.11))
	_hide_meshes(berm)
	_flat_tiles(Vector3(0, 2.16, -38.4), Vector3(LOT, 0.10, 4.0), 6, 1, &"grass",
		Color(0.11, 0.14, 0.09), 5.0)
	for i in 22:
		var x := -38.0 + float(i) * 3.5
		_glow_box(Vector3(x, 2.75, -39.4), Vector3(0.55, 0.11, 0.10),
			Color(1.00, 0.94, 0.82))
		_glow_box(Vector3(x + 1.6, 2.60, -39.9), Vector3(0.45, 0.10, 0.10),
			Color(0.94, 0.18, 0.14))


func _ground_text(text: String, centre: Vector3, h: float, col: Color) -> void:
	var up := Vector3(0, 0, -1)
	var right := up.cross(Vector3.UP)
	var w: float = TS.text_width(text, h)
	TS.sign_text(self, text, centre - right * (w * 0.5), Vector3.UP, up, h, col,
		false, 0.03)


# ══════════════════════════════════════════════════════════════ SUBSTANCES
#
# FOUR, all of them ones you have had before, all at roughly HALF the dose size
# the cottage hands out (0.24-0.30 against 0.34-0.52). Tolerance has been
# climbing for seven legs and nothing here works properly any more.
#
# The four are chosen for what they say rather than for what they do:
#
#   double_double  the diner has a pot on and the pumps have a machine. It is
#                  the only stimulant on the lot and it is the only thing here
#                  anyone would defend.
#   darts          half a pack by the door, and half a pack is what is always
#                  there. Does almost nothing. You will still take it.
#   grass          you are a goose. There is a weedy margin around a flooded
#                  corner of a parking lot in Georgia and it is free and it is
#                  infinite and it barely registers any more. This is the only
#                  infinite source in the zone and it is the truest object in
#                  the game.
#   nitrous        two cans in the corral behind a diner that serves pie.
#
# There is NO catnip, and there are still two cats. That is deliberate: the cats
# are here and you can no longer do anything about them.

func _sources() -> void:
	var coffee := Subs.get_substance(&"double_double")
	var darts := Subs.get_substance(&"darts")
	var grass := Subs.get_substance(&"grass")
	var nitrous := Subs.get_substance(&"nitrous")

	# A cup left on the window ledge by whoever is inside.
	_source(Vector3(-6.0, 1.05, BLD_Z0 - 0.75), coffee, 0.30)
	_decal_box(Vector3(-6.0, 0.82, BLD_Z0 - 0.75), Vector3(0.16, 0.24, 0.16),
		Color(0.86, 0.82, 0.74))
	# And one on the pump island, going cold.
	_source(Vector3(CANOPY_X - 3.6, GRADE + 0.85, CANOPY_Z + 3.4), coffee, 0.26)

	# Half a pack, and a sand-top receptacle nobody has emptied since June.
	_source(Vector3(-11.5, GRADE + 0.55, WALK_Z0 + 1.4), darts, 0.24)
	_decal_box(Vector3(-11.5, GRADE + 0.45, WALK_Z0 + 1.4), Vector3(0.34, 0.90, 0.34),
		Color(0.22, 0.22, 0.24))
	_source(Vector3(11.0, GRADE + 0.50, 29.0), darts, 0.24)

	# The weeds. One patch, infinite, in the dark at the edge of the water.
	_source(Vector3(FLOOD_X1 + 1.6, GRADE + 0.45, FLOOD_Z0 + 6.0), grass, 0.30, true)

	# Two cans in the corral, and one somebody dropped on the walk.
	_source(Vector3(21.5, GRADE + 0.60, 29.4), nitrous, 0.26)
	_decal_box(Vector3(21.5, GRADE + 0.16, 29.4), Vector3(0.5, 0.30, 0.5),
		Color(0.80, 0.80, 0.76))
	_source(Vector3(-16.5, GRADE + 0.50, WALK_Z0 + 1.0), nitrous, 0.24)


# ══════════════════════════════════════════════════════════════ POPULATION
#
# Four tight clusters and a great deal of nothing. That distribution IS the
# zone: emptiness is not a low prop count, it is sixty metres of wet asphalt
# between two places worth being.

func _props() -> void:
	# ── cluster: the diner walk ─────────────────────────────────────────
	for i in 5:
		_prop(Vector3(-14.5 + float(i) * 0.62, GRADE + 0.60, WALK_Z0 + 2.6),
			Vector3(0.52, 1.10, 0.46), [Color(0.18, 0.42, 0.60), Color(0.62, 0.16, 0.16),
			Color(0.24, 0.24, 0.26), Color(0.16, 0.42, 0.30), Color(0.66, 0.52, 0.14)][i],
			5.0, 30, "PAPER BOX")
	var ice := _prop(Vector3(1.2, GRADE + 0.98, WALK_Z0 + 2.2),
		Vector3(1.70, 1.95, 0.90), Color(0.80, 0.82, 0.84), 140.0, 90, "ICE")
	ice.break_force = 42.0
	ice.rotation.y = 0.0
	var pro := _prop(Vector3(-2.6, GRADE + 0.75, WALK_Z0 + 2.2),
		Vector3(1.60, 1.50, 0.86), Color(0.42, 0.44, 0.44), 220.0, 120, "PROPANE")
	pro.breakable = false
	pro.break_force = 999.0
	pro.rotation.y = 0.0
	for i in 2:
		_prop(Vector3(-19.0 - float(i) * 1.2, GRADE + 0.46, WALK_Z0 + 1.8),
			Vector3(0.60, 0.90, 0.60), Color(0.36, 0.30, 0.24), 6.0, 28, "PATIO CHAIR")
	# One shopping cart, nine hundred kilometres from the nearest store. Nobody
	# needs this explained.
	_prop(Vector3(-27.5, GRADE + 0.52, 15.0), Vector3(0.80, 1.00, 1.30),
		Color(0.62, 0.63, 0.66), 12.0, 35, "CART")

	# ── cluster: the fuel island ────────────────────────────────────────
	for i in 4:
		var a := float(i) * 1.7
		_prop(Vector3(CANOPY_X - 7.0 + float(i) * 4.6, GRADE + 0.38,
			CANOPY_Z - 6.0 + 1.4 * sin(a)), Vector3(0.42, 0.74, 0.42),
			Color(0.90, 0.36, 0.10), 2.0, 18, "CONE")
	for i in 2:
		_prop(Vector3(CANOPY_X + 7.6 + float(i) * 0.9, GRADE + 0.30, CANOPY_Z + 5.6),
			Vector3(0.48, 0.55, 0.50), Color(0.10, 0.10, 0.12), 3.0, 18, "GARBAGE",
			{"variant": float(i) * 2.1})
	# The air tower, bolted down, next to the vacuum nobody has used.
	var air := _static_box(Vector3(CANOPY_X + 11.5, GRADE + 0.93, CANOPY_Z - 1.0),
		Vector3(0.62, 1.85, 0.62), Color(0.62, 0.16, 0.14))
	_model_body(air, &"air_tower", -0.925)

	# ── cluster: the truck row ──────────────────────────────────────────
	for i in 6:
		var bx: float = BAY_X[i % BAY_X.size()]
		_prop(Vector3(bx + 2.6, GRADE + 0.14, BAY_Z - 2.0 - float(i) * 0.7),
			Vector3(0.30, 0.24, 0.44), Color(0.84, 0.68, 0.14), 1.5, 14, "CHOCK")
	for i in 5:
		var a2 := float(i) * 2.11
		_prop(Vector3(6.0 + float(i) * 6.6 + 1.4 * sin(a2), GRADE + 0.18,
			-18.0 + 4.5 * cos(a2)), Vector3(1.30, 0.30, 0.72),
			Color(0.155, 0.145, 0.150), 4.0, 22, "GATOR", {"variant": float(i) * 1.9})
	for i in 3:
		_prop(Vector3(8.0 + float(i) * 9.0, GRADE + 0.38, 19.5),
			Vector3(0.42, 0.74, 0.42), Color(0.90, 0.36, 0.10), 2.0, 18, "CONE")
	for i in 3:
		_prop(Vector3(33.0 + 0.4 * float(i % 2), GRADE + 0.10 + float(i) * 0.18, 18.5),
			Vector3(1.20, 0.16, 1.00), Color(0.44, 0.34, 0.23), 6.0, 26, "PALLET",
			{"variant": float(i) * 3.1})

	# ── the far corners: almost nothing, on purpose ─────────────────────
	for i in 2:
		_prop(Vector3(-6.0 + float(i) * 9.0, GRADE + 0.18, EXIT_Z + 2.5),
			Vector3(1.30, 0.30, 0.72), Color(0.155, 0.145, 0.150), 4.0, 22, "GATOR",
			{"variant": 7.0 + float(i)})

	# ── the car park ────────────────────────────────────────────────────
	# Four cars for a building with one person in it.
	var cols := [Color(0.46, 0.14, 0.14), Color(0.18, 0.24, 0.40), Color(0.66, 0.66, 0.68),
		Color(0.14, 0.30, 0.24)]
	for i in 4:
		var v := _prop(Vector3(-31.0 + float(i) * 5.2, GRADE + 1.0, 19.0),
			Vector3(2.10, 1.90, 4.60), cols[i], 900.0, 120, "VEHICLE")
		v.breakable = false
		v.break_force = 999.0
		v.rotation.y = randf_range(-0.05, 0.05)


func _people() -> void:
	# ONE. The night cook, behind the glass, in a building with a car park for
	# forty. The strip mall has nine people and the cottage has eight; this is
	# the zone where there is nobody, and the population count is the joke.
	var n := NpcHuman.new()
	add_child(n)
	n.setup(Color(0.90, 0.90, 0.86))
	n.global_position = Vector3(-1.0, GRADE + 0.45, BLD_Z0 + 0.75)


func _cats() -> void:
	# Two truck-stop cats. There is no catnip in this zone, which means for the
	# first time in the run they are simply cats and there is nothing you can do
	# about them. Nobody says that out loud either.
	var furs := [Color(0.26, 0.24, 0.22), Color(0.72, 0.58, 0.34)]
	var spots := [Vector3(12.0, GRADE + 0.2, 27.5), Vector3(24.0, GRADE + 0.2, 26.0)]
	for i in 2:
		var c := Cat.new()
		add_child(c)
		c.setup(furs[i])
		c.global_position = spots[i]


# ══════════════════════════════════════════════════════════════════════ RAIN

func _rain_setup() -> void:
	# CPUParticles3D rather than GPUParticles3D: this project ships on the GL
	# Compatibility renderer and CPU particles are the option that is guaranteed
	# to be there. Three hundred streaks is plenty when they are only ever drawn
	# in a 24 m box around the bird.
	_rain = CPUParticles3D.new()
	add_child(_rain)
	var bm := BoxMesh.new()
	bm.size = Vector3(0.022, 0.62, 0.022)
	_rain.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.80, 0.84, 0.92, 0.42)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_rain.material_override = m
	_rain.amount = 300
	_rain.lifetime = 1.15
	_rain.local_coords = false
	_rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_rain.emission_box_extents = Vector3(13.0, 0.5, 13.0)
	_rain.direction = Vector3(0.12, -1, 0)
	_rain.spread = 2.0
	_rain.initial_velocity_min = 9.0
	_rain.initial_velocity_max = 13.0
	_rain.gravity = Vector3(1.6, -26.0, 0.0)
	_rain.position = Vector3(0, 12.0, 0)


## Is there anything solid over this point? Straight up, 24 m — taller than the
## pylon (11.6) and than anything BIG DOWN builds across the interstate.
##
## Starts 0.6 m up so a goose standing ON a trailer roof does not report the
## trailer it is standing on as cover, which would stop the rain on the one
## piece of high ground the leg is built around.
func _under_cover(at: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	if space == null:
		return false
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.6, at + Vector3.UP * 24.0)
	q.collide_with_areas = false
	if goose != null and is_instance_valid(goose):
		q.exclude = [goose.get_rid()]
	return not space.intersect_ray(q).is_empty()


func _spawn_goose() -> void:
	goose = Goose.new()
	goose.name = "Goose"
	add_child(goose)
	# In the middle of the lot between the canopy and the truck row, facing the
	# exit. The first frame of this zone has to sell all three of its ideas at
	# once: a row of rigs on your right with their lights on, a bright cold
	# canopy on your left, and sixty metres of empty wet asphalt in front of you
	# leading to a berm with an interstate on it.
	#
	# Clear of every pickup trigger and every prop cluster: the cottage's first
	# render spawned the bird inside a pickup's 1.6 m radius and the very first
	# frame of the zone was a HOLD [E] prompt instead of a view.
	goose.global_position = Vector3(-2.0, GRADE + 1.0, 14.0)
	goose.heading = 0.0
	goose.rotation.y = 0.0

	camera_rig = preload("res://scripts/goose/goose_camera.gd").new()
	camera_rig.name = "CameraRig"
	camera_rig.target = goose
	add_child(camera_rig)
	goose.cam = camera_rig

	# NO SHAKE WIRING HERE. Juice owns the shake bus and the goose controller
	# drives it; a zone that also connects landed/tumbled shakes the camera twice
	# for one landing and bypasses the screen_shake accessibility pref.


# ══════════════════════════════════════════════════════════════════ THE RIGS

func _physics_process(delta: float) -> void:
	_clock += delta
	_tick_rigs(delta)
	_tick_panes()


## DEPART_AT was written against this many seconds. Everything in the table is
## relative to it.
const SCHEDULE_BASE := 180.0


## How much to squeeze (or stretch) the departure schedule so it still fits.
##
## Sampled once, from the clock the zone was handed, and cached — `zone_time_left`
## drains as the leg runs, so reading it live would make the scale shrink toward
## zero and fire every remaining rig at once.
##
## Clamped at the top so a longer leg (leg 7 goes to 230 s if the BIG DOWN clock
## in docs/BOSS_DESIGN.md is ever adopted) stretches the schedule rather than
## leaving the lot full for an extra minute; clamped at the bottom so a
## catastrophically short leg still gets a recognisable rhythm instead of six
## rigs leaving in the first ten seconds.
var _sched_scale := -1.0

func _clock_scale() -> float:
	if _sched_scale > 0.0:
		return _sched_scale
	var g := get_node_or_null("/root/Game")
	var secs: float = float(g.zone_time_left) if g != null else SCHEDULE_BASE
	if secs <= 1.0:
		return 1.0
	_sched_scale = clampf(secs / SCHEDULE_BASE, 0.55, 1.35)
	return _sched_scale


func _tick_rigs(delta: float) -> void:
	# Departure schedule, compressed under --probe so the moving parts can be
	# photographed. See _ready().
	#
	# AND SCALED TO THE CLOCK THE LEG ACTUALLY GOT. `DEPART_AT` is a list of
	# absolute elapsed seconds written against a 180 s leg, compared against this
	# zone's own `_clock`, and nothing ever reconciled the two. But leg 7's clock
	# is not fixed: `main.gd::_on_migration_done()` subtracts 60 s for landing
	# short and applies the mission modifier on top, so a player who has a bad
	# leg 6 arrives at a truck stop of 120 s or less — and the last two rigs,
	# scheduled at 138 s and 166 s, simply never leave.
	#
	# That silently deletes the zone's whole argument. Its own header says the
	# point is that "the lot is measurably emptier at 2:00 than it was at 0:00",
	# and the last departure at 2:46 of 3:00 leaving fourteen seconds of empty
	# parking lot is called "the most honest thing in the game" fifty lines up.
	# The player who most needs that beat — the one who just had a bad leg — was
	# the only one who never got it.
	#
	# Proportional, so the SHAPE of the schedule survives: spread across the
	# whole leg, last one near the end, same relative gaps.
	var scale := 0.06 if _probe else _clock_scale()
	for i in range(_rig_body.size()):
		if _rig_state[i] == RigState.GONE:
			continue
		var body: AnimatableBody3D = _rig_body[i]
		if body == null or not is_instance_valid(body):
			_rig_state[i] = RigState.GONE
			continue

		match _rig_state[i]:
			RigState.PARKED:
				var at: float = DEPART_AT[i] * scale
				if _clock >= at:
					_rig_state[i] = RigState.ARMED
					_rig_arm[i] = ARM_TIME * scale
					if _sfx != null:
						_sfx.play_at(&"hiss", body, -3.0, 1.55)

			RigState.ARMED:
				_rig_arm[i] -= delta
				if _rig_arm[i] <= 0.0:
					_rig_state[i] = RigState.ROLLING
					_rigs_left -= 1
					var g: Node3D = _rig_glow[i]
					if g != null and is_instance_valid(g):
						g.visible = true
					if _sfx != null:
						_sfx.play_at(&"crash_heavy", body, -7.0, 0.42)
					Juice.floating_text(body.global_position + Vector3(0, 4.6, 0),
						"that one's going", Color(1.00, 0.70, 0.30))
					_maybe_last_call(body)

			RigState.ROLLING:
				_roll(i, body, delta)

		# _roll() can retire the rig in the same frame, and `queue_free` is
		# deferred, so the body is still "valid" for the rest of this tick.
		# Boarding a truck that has already left the world is not a thing.
		if _rig_state[i] != RigState.GONE:
			_tick_roof(i, body, delta)

	# The travelling headlights, parked underground when nothing is moving.
	var rolling := -1
	for i2 in range(_rig_state.size()):
		if _rig_state[i2] == RigState.ROLLING:
			rolling = i2
			break
	if rolling < 0:
		_head_light.visible = false
		_tail_light.visible = false
	else:
		var rb: AnimatableBody3D = _rig_body[rolling]
		if is_instance_valid(rb):
			var f := -rb.global_transform.basis.z
			_head_light.visible = true
			_head_light.global_position = rb.global_position + f * 4.2 + Vector3(0, 1.3, 0)
			_tail_light.visible = true
			_tail_light.global_position = rb.global_position - f * 18.4 + Vector3(0, 1.4, 0)


## Drive rig `i` out of its bay: straight forward to the exit lane, then a long
## left onto it and away west.
##
## The rig is an AnimatableBody3D with `sync_to_physics` on, so setting its
## transform in _physics_process is what carries a CharacterBody3D standing on
## it. `constant_linear_velocity` is set as well: that is the value the
## character controller reads to work out platform velocity, and without it a
## goose on the roof is left behind by a trailer sliding out from under it.
func _roll(i: int, body: AnimatableBody3D, delta: float) -> void:
	_rig_speed[i] = move_toward(_rig_speed[i], 9.5, 2.6 * delta)
	var p := body.global_position
	# Two waypoints, and that is the whole path: out of the bay, then west.
	var target := Vector3(BAY_X[i], 0.0, EXIT_Z)
	if p.z < EXIT_Z + 9.0:
		target = Vector3(-90.0, 0.0, EXIT_Z)
	var d := target - p
	if d.length_squared() > 0.01:
		var want := atan2(-d.x, -d.z)
		_rig_yaw[i] = rotate_toward(_rig_yaw[i], want, 0.62 * delta)
	body.rotation.y = _rig_yaw[i]
	var fwd := Vector3(-sin(_rig_yaw[i]), 0.0, -cos(_rig_yaw[i]))
	var vel := fwd * _rig_speed[i]
	body.constant_linear_velocity = vel
	body.global_position = p + vel * delta
	if p.x < -48.0 or p.z < -56.0:
		_rig_state[i] = RigState.GONE
		body.queue_free()


## Board / ride detection. Polled rather than driven off body_entered, because
## the area is bolted to a body that is moving nine metres a second and the
## signal ordering around that is not worth trusting for the zone's headline
## objective.
func _tick_roof(i: int, body: AnimatableBody3D, delta: float) -> void:
	if goose == null or not is_instance_valid(goose):
		return
	var roof: Area3D = _rig_roof[i]
	if roof == null or not is_instance_valid(roof):
		return
	var on := roof.overlaps_body(goose) and goose.is_on_floor()
	if not on:
		_rig_ride[i] = 0.0
		return
	if not _rig_boarded[i]:
		_rig_boarded[i] = true
		Game.score(140, "ON THE RIG", goose.global_position)
		if _sfx != null:
			_sfx.play_at(&"score_blip_hi", goose, -2.0, 1.0)
	if _rig_state[i] != RigState.ROLLING:
		_rig_ride[i] = 0.0
		return
	_rig_ride[i] += delta
	if _rig_ride[i] >= 1.2 and not _rig_rode[i]:
		_rig_rode[i] = true
		Game.score(320, "RODE A RIG", goose.global_position)
		Juice.floating_text(goose.global_position + Vector3(0, 1.4, 0),
			"you are on a truck", Color(1.00, 0.82, 0.36))
	# 6.5 s, measured rather than guessed: a headless ride harness put the goose
	# on bay 0's roof and stepped physics until the map wall scraped it off at
	# 9.4 s. Eight seconds fired with 1.4 s to spare, which is not a margin, it
	# is a coin toss on a hidden objective.
	if _rig_ride[i] >= 6.5 and not _long_ride_given:
		_long_ride_given = true
		Game.score(500, "WENT WITH IT", goose.global_position)
	# Being carried out of the world is a real hazard: the map wall is at
	# z = -40 and the rig goes through it. Announce it once so the player
	# understands what happened rather than blaming the collision.
	if body.global_position.z < EXIT_Z + 1.0 and _rig_ride[i] > 2.0 and _rig_ride[i] < 2.0 + delta:
		Juice.floating_text(goose.global_position + Vector3(0, 1.6, 0),
			"this is the way out", Color(0.92, 0.86, 0.70))


## Awarded when the LAST rig pulls out. It is the zone's thesis with a number on
## it: everyone else had somewhere to be.
func _maybe_last_call(body: Node3D) -> void:
	if _rigs_left > 0 or _last_call_given:
		return
	_last_call_given = true
	Game.score(200, "LAST CALL", body.global_position)
	if goose != null and is_instance_valid(goose):
		Juice.floating_text(goose.global_position + Vector3(0, 1.8, 0),
			"that was the last one", Color(1.00, 0.64, 0.26))


# ══════════════════════════════════════════════════════════ THE DINER WINDOW

func _tick_panes() -> void:
	if goose == null or not is_instance_valid(goose):
		return
	var speed := goose.velocity.length()
	if speed < 4.0:
		return
	for i in range(_pane_area.size()):
		if _pane_gone[i]:
			continue
		var a: Area3D = _pane_area[i]
		if a == null or not is_instance_valid(a):
			continue
		if a.overlaps_body(goose):
			_break_pane(i)


func _break_pane(i: int) -> void:
	_pane_gone[i] = true
	var m: MeshInstance3D = _pane_mesh[i]
	var b: StaticBody3D = _pane_body[i]
	var at := Vector3.ZERO
	if m != null and is_instance_valid(m):
		at = m.global_position
		m.visible = false
	if b != null and is_instance_valid(b):
		for c in b.get_children():
			if c is CollisionShape3D:
				c.set_deferred("disabled", true)
	# Same label the objectives watch for. Suburbia's bespoke moments award
	# chaos against a label nothing listens to, which is why three of its
	# objectives can never complete; this one is spelled once and matched once.
	Game.score(260, "DINER WINDOW", at)
	Juice.hitstop(0.06, 0.8)
	Juice.shake(0.35)
	Juice.burst(at, Color(0.90, 0.94, 1.00), 18, &"debris")
	Juice.floating_text(at + Vector3(0, 0.8, 0), "DINER WINDOW!!",
		Color(1.0, 0.86, 0.32))
	if _sfx != null:
		_sfx.play_at(&"smash", self, 0.0, 1.22)


# ══════════════════════════════════════════════════════════════════════ TICK

func _process(delta: float) -> void:
	_t += delta

	# ── rain follows the bird, AND STOPS WHEN THERE IS A ROOF ───────────
	#
	# The emitter is parked 12 m over the goose and the streaks have no
	# collision, so for the whole life of this zone it rained THROUGH the fuel
	# canopy, THROUGH the travel-centre roof and THROUGH the diner awning — the
	# three places the zone offers specifically as shelter. Nobody had seen it
	# because the only thing that makes it obvious is standing under one and
	# looking up, and the zone had only ever been photographed from the lot.
	#
	# BIG DOWN made it undeniable: it added a warehouse across the interstate,
	# and the first render taken from inside that building is a downpour indoors.
	#
	# A raycast straight up is the whole fix, and it is deliberately ignorant of
	# what it hits — this zone does not know the boss exists and must not learn.
	# Anything solid overhead is a roof. `emitting` rather than a reparent so the
	# streaks already in the air finish falling instead of vanishing mid-frame.
	if _rain != null and goose != null and is_instance_valid(goose):
		_rain.global_position = Vector3(goose.global_position.x, GRADE + 12.0,
			goose.global_position.z)
		_rain_probe_t -= delta
		if _rain_probe_t <= 0.0:
			_rain_probe_t = RAIN_PROBE_EVERY
			_rain.emitting = not _under_cover(goose.global_position)

	# ── the lamps ───────────────────────────────────────────────────────
	# Sodium vapour hums and it does not flicker like a fire. A slow beat, out of
	# phase per lamp, plus a very occasional dropout on one of them — the lamp at
	# the end of its life that every lot has exactly one of.
	for i in range(_lamp_lights.size()):
		var l: OmniLight3D = _lamp_lights[i]
		if not is_instance_valid(l):
			continue
		var ph := float(i) * 1.7
		var e := 3.4 + 0.09 * sin(_t * 0.9 + ph)
		if i == 5:
			# This one is dying. It is the only thing in the zone that is not
			# working, in a zone where nothing is working.
			var f := sin(_t * 1.31) * sin(_t * 0.41)
			e *= 0.55 + 0.45 * clampf(f * 3.0 + 0.6, 0.0, 1.0)
		l.light_energy = e

	# ── the moths ───────────────────────────────────────────────────────
	for i2 in range(_moths.size()):
		var m: Node3D = _moths[i2]
		if not is_instance_valid(m):
			continue
		var anchor: Vector3 = m.get_meta("anchor", Vector3.ZERO)
		var ph2: float = m.get_meta("phase", 0.0)
		var r := 0.55 + 0.42 * sin(_t * 0.7 + ph2 * 1.9)
		m.global_position = anchor + Vector3(
			cos(_t * 2.3 + ph2) * r,
			-0.32 + sin(_t * 3.7 + ph2 * 2.1) * 0.24,
			sin(_t * 1.9 + ph2 * 1.3) * r)

	# ── the hazard flashers on a rig that is about to move ──────────────
	for i3 in range(_rig_state.size()):
		var g: Node3D = _rig_glow[i3]
		if g == null or not is_instance_valid(g):
			continue
		if _rig_state[i3] == RigState.ARMED:
			g.visible = sin(_t * 12.0) > 0.0
		elif not g.visible:
			g.visible = true


# ══════════════════════════════════════════════════════════════════ ZONE API

## Which objective set the Mission autoload should load for this zone.
func mission_zone_id() -> StringName:
	return &"truckstop"


## Title shown by the HUD at the top of the leg.
func zone_title() -> String:
	return "LEG %d — THE TRUCK STOP" % Flock.leg
