extends Node3D
## LEG 5 — THE STOPOVER, AT DAWN
##
## Montezuma National Wildlife Refuge, upstate New York. A drowned marsh at
## first light: ninety metres of shallow open water, a gravel dyke road running
## north to south across it, a low island at the end of the road with an
## observation tower on it, dead standing timber out in the pool, six hundred
## cattails, mist, and forty other Canada geese who are not doing anything.
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
## leg 5's contribution is not a mechanic. It is **a reason not to use the
## verbs**. §2.5 states it as plainly as the spec ever states anything:
##
##   > This is the harm-reduction thesis as level design, and it never says a
##   > word. The trough is only a trough if you take it.
##
## Three facts about this file follow from that, and they are the only three
## things in it that are load-bearing:
##
## 1. ALL SIXTEEN SUBSTANCES ARE HERE AND NOTHING MENTIONS IT. Seventeen
##    pickups, one of every substance in the game plus a second patch of grass,
##    scattered down the road and across the island where the player will walk
##    over most of them without trying. There is no briefing card, no toast, no
##    NPC line and no objective text anywhere in this zone or in
##    `mission_defs_stopover.gd` that suggests using them or not using them. The
##    two hidden objectives that grade the choice — `slept_on_it` and
##    `not_a_rest_stop` — are BOTH `late`, so they fire at the buzzer, after the
##    decision is spent. A nudge that arrives while the player can still change
##    their mind is advice, and advice deletes the level.
##
## 2. NOTHING IN HERE PURSUES, PUNISHES, OR MOVES FAST. Intensity 2, the deepest
##    trough on a sixteen-beat curve that peaks at 8 immediately before it
##    (CAMPAIGN_SPEC.md:684). There is no vehicle, no boss, no cat, no dog, no
##    timed window and no hazard. The only three things in the zone that move on
##    their own are a gate swinging in the wind, ten banks of mist drifting, and
##    a spotting scope tracking the player, and all three are jokes. If you are
##    reading this because you want to add "one small thing that chases you" —
##    that is the change this file exists to refuse.
##
## 3. THE FLOCK PEN IS THE CENTREPIECE, NOT A CORNER FIXTURE. CAMPAIGN_SPEC.md:
##    497: "the flock pen is the biggest thing in the level." It is at the dead
##    centre of the island, which is at the dead centre of the composition, at
##    the end of the only road. The birdwatcher stands beside it. TWO of the
##    four primaries are about your own flock, which is true in no other zone in
##    the game. See `mission_defs_stopover.gd`.
##
## ---------------------------------------------------------------------------
## THE OPENING SHOT, AND WHY THE ZONE IS LAID OUT ALONG Z
## ---------------------------------------------------------------------------
## `goose_camera.gd::_adopt_heading()` seeds the rig's yaw from `goose.heading`
## on the first frame, so a zone author now genuinely picks the opening shot.
## This one spawns at heading 0 — looking down world -Z — and everything the
## player needs to understand the level is on that axis, in depth order:
##
##   6 m   the gravel road under your feet, running away into mist
##   16 m  the gate, standing wide open, with AREA CLOSED on it
##   19 m  the refuge sign
##   24 m  the flock pen: your own geese, standing in a loose arc
##   28 m  the birdwatcher, found by a navy camp chair, the only saturated
##         object in the level
##   33 m  the observation tower
##   and either side of all of it, to the horizon, open water, dead trees,
##   mist and geese.
##
## The zone reads in one frame from a standing start, which is what a 150-second
## clock buys you and what a 150-second clock demands.
##
## ---------------------------------------------------------------------------
## THE HEIGHT TABLE — the one thing to read before moving anything
## ---------------------------------------------------------------------------
##     y = -0.30   the marsh bed. SOLID EVERYWHERE, so a diving bird has
##                 something to hit and the flock pen's ground raycast always
##                 gets an answer.
##     y =  0.00   the water surface — the whole map except the dyke and island
##     y =  0.02   the toe of the island's rim ramp
##     y =  0.05   the toe of the dyke berm
##     y =  0.20   top of the water Area3D — the swim/wade transition
##     y =  0.62   THE ISLAND: the pen, the tower, the birdwatcher, the signs
##     y =  0.70   THE DYKE ROAD CROWN — the only dry line across the marsh
##     y =  1.45   the weir catwalk, out in the west pool
##     y =  2.18   the roof of a nest box (there is a goose on one)
##     y =  2.22   the tower's stair landing
##     y =  3.82   the tower's deck
##     y =  4.92   the tower's rail cap (there is a goose on that too)
##     y =  6.17   the tower's roof ridge — the highest point in the zone
##
## EVERY ONE OF THOSE STEPS IS INSIDE ONE FLAP. A flap from a standstill is
## `flap_impulse^2 / (2 * glide_gravity)` = 6.4^2 / 22 = 1.86 m, the same number
## zone_cottage.gd:65, zone_truckstop.gd:73 and zone_corn.gd:118 are set
## against. Water (0.20) to island (0.62) is a step, island to landing is 1.60,
## landing to deck is 1.60, deck to rail is 1.10, rail to ridge is 1.25. A bird
## that has just flown the longest crossing in the front half of the run can get
## to the top of the tower without being good at anything.
##
## AND THE STEPS ARE RAMPED, WHICH IS NOT DECORATION. The dyke's shoulders and
## all five faces of the island are sloped StaticBody3D slabs hidden under the
## art (`_ramp()`), because a swimming goose meeting a vertical 0.42 m kerb is a
## swimming goose that cannot get out of the water, and the one place in the
## game where that must never happen is the zone whose entire proposition is
## that you can stop and stand still.
##
## ---------------------------------------------------------------------------
## WHAT THE ZONE DELIBERATELY DOES NOT HAVE
## ---------------------------------------------------------------------------
## * A briefing card. docs/ROUTE_DATA.md:130 sets leg 5's `brief` to &"" on
##   purpose. Do not write one.
## * Anything that says "rest". Not on the interpretive sign, not on the refuge
##   sign, not in a toast, not in an objective. The interpretive panel is about
##   invertebrates, which is what real refuge panels are about, and that is the
##   entire joke.
## * A cat, a dog, a human who reacts, a vehicle, a boss.
## * Its own ambience call. `Sfx.AMBIENCE_BEDS` already maps &"stopover" to
##   `amb_marsh_dawn_loop`; the director makes that call, not the zone.
##
## ---------------------------------------------------------------------------
## THE FORTY GEESE, AND THE ONE THING TO KNOW ABOUT THEM
## ---------------------------------------------------------------------------
## CAMPAIGN_SPEC.md:520 wants ~40 idle residents here BECAUSE the 18th green
## reuses the image twenty minutes later, so the ending reads as a return rather
## than a first appearance. The build order got inverted — `zone_finale.gd`
## shipped first and its `_make_goose` / `_tick_goose` pair is private to that
## node — so `_resident()` and `_tick_resident()` below are a deliberate,
## behaviour-compatible fork of zone_finale.gd:902-1004 and :1688-1876, with the
## same mode names, the same STAND_HEIGHT convention and the same
## "animate() first, neck second" ordering. THIS IS DUPLICATION AND IT IS KNOWN:
## the honest fix is to lift both out into `scripts/world/idle_geese.gd` and
## have the finale and this zone share it. That is a two-file change to a file
## this build does not own; it is written up in the handoff.
##
## They do not react to you. That is the point and it is also load-bearing for
## the intensity: a crowd that scatters is an activity, and this zone has no
## activities. The most they ever do is answer a honk, quietly, and not all of
## them, and not for long — see `_honk_answer()`.

const LOT := 96.0                ## the play square, +/- 48

## Preloaded rather than referenced by class_name: global class registration
## only exists after an editor import pass, so a `class_name` reference breaks
## in a fresh checkout or a headless CI run. A preload const always resolves.
const PROPS := preload("res://scripts/world/prop_models.gd")
const STOP := preload("res://scripts/world/prop_models_stopover.gd")
## Borrowed for ONE thing: the 4x5 bitmap font and its mirror-safe `sign_text`.
## `prop_models_stopover.gd` deliberately ships blank placards and says so at its
## LETTERING section — the library owns the sign, the zone owns the words. This
## project has shipped "POTS" and "ƎƆIVЯƎƧ" by laying glyphs along +X; every
## call below goes through `_sign_line()`, which takes its `right` from
## `up.cross(normal)` exactly once.
const TS := preload("res://scripts/world/prop_models_truckstop.gd")
## The zone's own score labels. They live in the objective file, once, so a
## rename is a parse error in both places instead of a silently dead objective —
## the fix `mission_defs.gd` adopted after suburbia's labels drifted.
const MDEF := preload("res://scripts/core/mission_defs_stopover.gd")
const FLOCK_PEN := preload("res://scripts/world/flock_pen.gd")

## Both goose visuals expose an identical API, so nothing here cares which is
## live. Same table `flock_pen.gd:55` and `zone_finale.gd:80` use, for the same
## reason: an idle resident must match whichever model the player is driving.
const MODEL_SCRIPTS := {
	"classic": "res://scripts/goose/goose_visual.gd",
	"lowpoly": "res://scripts/goose/goose_visual_lowpoly.gd",
}

# ── the height table, as constants ──────────────────────────────────────────
const WATER_Y := 0.0
const BED_Y := -0.30
## Top of the water Area3D. Copied from zone_cottage.gd:55 WITH its arithmetic:
## the goose's body capsule lies along Z so its vertical half-extent is the 0.34
## radius, and its water probe is a 0.22 sphere on the origin. A bed at -0.30
## and an area top at 0.20 float the bird with its origin at 0.04 — waterline
## just under halfway up the body, which is what a swimming goose looks like.
## Two zones now depend on that pair of numbers; change them together or not at
## all.
const WADE_Y := 0.20

## The dyke is anchored on the BED, not the waterline (the library says so at
## its own header), so the crown lands at BED_Y + DYKE_CROWN_Y.
const DYKE_CROWN := BED_Y + STOP.DYKE_CROWN_Y     ## 0.70
const DYKE_HALF_W := 2.20        ## crown half-width — the walkable road
## How close a drifting mist bank may come to the centre line of the dyke.
## The road is DYKE_HALF_W = 2.20 half-width and a bank is several metres across,
## so this has to clear the crown by more than a bank half-width or the edge
## still crosses the camera. See _tick_mist().
const MIST_KEEP_OUT := 11.0
const DYKE_TOE_X := 4.10         ## where the berm profile meets the water
const DYKE_TOE_Y := 0.05         ## and how high it is when it gets there
## And where the shoulder COLLIDER stops, which is not the same place. The berm
## art ends at (4.10, 0.05) and then drops 35 cm straight to the bed; a collider
## that stopped there would present a swimming goose with a 35 cm kerb all the
## way down both sides of the road. So the same straight line — the art's
## profile is a straight 0.342 slope from (2.20, 0.70) to (4.10, 0.05) — is
## simply carried on until it is BELOW the bed, and the last metre of it is
## buried. Verified by raycast, not by eye: see the handoff.
const DYKE_RAMP_X := 5.18
const DYKE_RAMP_Y := -0.32
const DYKE_Z0 := -10.0           ## the road's south end, at the island
const DYKE_Z1 := 46.0            ## and its north end, out in the fog

## The island. Deliberately LOW — the spec's "raised WATER_Y so the plateau
## becomes a low island" is the single silhouette decision that stops this
## reading as cottage country with the lights on, and an island you can see over
## is an island rather than a hill.
const ISLAND_Y := 0.62
const ISLAND_HW := 11.0          ## half-width in both X and Z
const ISLAND_CZ := -21.0         ## centre Z (centre X is 0)

## The weir is anchored on the bed too, so its catwalk lands at BED_Y + 1.75.
const WEIR_AT := Vector3(-13.0, BED_Y, 3.0)
const WEIR_DECK := BED_Y + STOP.WEIR_DECK_Y       ## 1.45

## Where the tower's DECK centre goes. Note the anchoring exception: the tower's
## origin is the deck centre at ground level and its stair runs out to +Z, so
## this is not the centre of its bounding box. Stair foot lands at z = -20.0.
const TOWER_AT := Vector3(-7.0, ISLAND_Y, -27.0)

## The flock pen. Dead centre of the island, dead centre of the frame, at the
## end of the only road. Everything else on the island is arranged around it.
const PEN_AT := Vector3(0.0, ISLAND_Y + 0.2, -18.0)

## The birdwatcher and their kit. The chair is 1.2 m from the person because a
## birdwatcher who is actually watching is standing up next to a chair they have
## not sat in for an hour.
const WATCHER_AT := Vector3(5.0, ISLAND_Y, -17.0)
const SCOPE_AT := Vector3(4.15, ISLAND_Y, -16.05)
const CHAIR_AT := Vector3(5.95, ISLAND_Y, -17.95)

## The goose's hips above the ground it is standing on. Both visuals put their
## origin there. Duplicated from flock_pen.gd:78 with the same warning: a bird
## dropped straight onto a surface height is buried to the waterline, and that
## is a render-only bug the compile gate cannot see. zone_finale.gd:948 records
## paying for it once already.
const STAND_HEIGHT := 0.46
## A FLOATING resident's base, so that base + STAND_HEIGHT lands the origin at
## 0.04 — the same waterline the player's own goose swims at. Pass this as the
## y of any resident on open water.
const FLOAT_BASE := WATER_Y + 0.04 - STAND_HEIGHT  ## -0.42

# ── the interactions, as constants ──────────────────────────────────────────
## How close a resident has to be to count as honked at. honk.gd's own RADIUS is
## 7.5 m at normal pitch and scales with it, so this is a shade generous on
## purpose: the objective is "go and meet the neighbours", not "measure 7.5 m".
const MEET_R := 9.0
## And how far the answer carries. Smaller than MEET_R * 2 deliberately — see
## `_honk_answer()` for why this wave is a fraction of the finale's.
const ANSWER_R := 13.0
const ANSWER_SPAN := 1.15        ## seconds from nearest bird to furthest
const ANSWER_CD := 2.4

## The scope. You have to be inside this and stay there for a moment before the
## birdwatcher counts as having seen you — a scope that scores you the instant
## you enter the level is not observation, it is a trigger volume.
##
## FIFTEEN, NOT TWENTY-SIX, AND THE RENDER IS WHY. At 26 m the spawn point is
## already inside it: the first probe pass fired a +220 into the sky 1.4 seconds
## into the leg, before the player had touched a key, for a bonus whose text is
## "Be observed". At 15 m you have to walk past the gate and onto the island,
## which is where the level wants you anyway — so it still costs nothing, and it
## now happens somewhere you can see the barrel swing onto you.
const SCOPE_SEE_R := 15.0
const SCOPE_HOLD := 1.4
## And how close a honk has to be before they write it down.
const NOTE_R := 18.0
const NOTE_CD := 3.2
const NOTE_LIFE := 4.0

# ── the palette ─────────────────────────────────────────────────────────────
## The zone owns the light and the ground; `prop_models_stopover.gd` owns
## everything standing on it and publishes seven DAWN_* constants so the two
## agree about what "dawn" means. These four are the surfaces the library does
## not build.
##
## THE RULE THE LIBRARY SET AND THIS FILE KEEPS: everything is desaturated and
## warm-tinted, greys carry a rose bias, and there is exactly ONE saturated
## object in the level — the birdwatcher's navy camp chair. Nothing here is
## pure white or pure black.
##
## Water at dawn is not blue. It is a mirror of a pink sky over dark silt, which
## on a rippled surface averages to a cool grey with a warm lift — and almost
## all of its actual colour arrives through `metallic`, not through albedo. The
## first value tried here was a cottage-country blue and it made the marsh read
## as leg 4 with the lights turned up, which is the one thing this zone must
## never do (WIN_CONDITIONS.md:417: "players notice reskins in about nine
## seconds").
const C_WATER := Color(0.205, 0.215, 0.250)
## The bed under it: warm dark silt, seen through the water and at the toe of
## every bank.
const C_SILT := Color(0.235, 0.212, 0.180)
## The island and the dyke shoulders: dead autumn marsh grass. Olive that has
## gone tan and dry — the same family as the library's C_REED so the reed beds
## sit on ground the same colour they are.
const C_SWARD := Color(0.352, 0.348, 0.252)

## Chaos-prop label -> model kind. Every one of these is from the SHARED
## library, which is the whole reason this table is short: `ChaosProp.setup()`
## can only resolve `prop_models.gd` (chaos_prop.gd:21), so a prop from any
## other library has to be built by the zone and have `p._visual` repointed by
## hand. This zone has nothing worth that: a wildlife refuge's loose junk is a
## bin, a bag, two camp chairs and a bench, and all four already exist.
const PROP_KIND := {
	"RECYCLING": &"recycling_bin",
	"GARBAGE": &"garbage_bag",
	"PATIO CHAIR": &"patio_chair",
	"BENCH": &"bench",
	"NOTICE": &"lawn_sign",
	"FENCE": &"fence_panel",
}

var goose: Goose
var camera_rig: Node3D

var _tex: Node = null   ## /root/Tex — may not exist, always guard.
var _sfx: Node = null   ## /root/Sfx — may not exist, always guard.

var _t := 0.0

# ── the moving parts, all three of them ─────────────────────────────────────
var _gate: Node3D = null
var _scope: Node3D = null
var _mist: Array[Node3D] = []
var _mist_vel: Array[Vector3] = []
## Each bank's authored size, kept here because `_tick_mist()` assigns `scale`
## ABSOLUTELY every frame. Writing the build-time size onto the same property
## something else stomps per frame is the bug substance_pickup.gd:64 documents
## paying for twice; this is the same shape and it is not being paid for again.
var _mist_scale: Array[float] = []

# ── the residents ───────────────────────────────────────────────────────────
var _geese: Array[Dictionary] = []
var _answer_q: Array[Dictionary] = []
var _answer_cd := 0.0

# ── the birdwatcher ─────────────────────────────────────────────────────────
var _watcher: Node3D = null
var _note_lbl: Label3D = null
var _note_pad: Node3D = null
var _note_cd := 0.0
var _note_t := 0.0
var _note_i := 0
var _scope_t := 0.0
var _scope_scored := false

# ── the flock ───────────────────────────────────────────────────────────────
var _pen: Node = null
## Flock indices the player has already walked up to. A Dictionary used as a
## set, because GDScript has no set and `has()` on a 6-entry Array is not worth
## the difference.
var _counted := {}

var _tower_scored := false
var _weir_scored := false

## What the birdwatcher writes down. Deadpan, timestamped, and about NOTHING —
## no substance is named, no behaviour is judged, and the joke is entirely that
## somebody is keeping a record of a goose having a bad morning. If you add a
## line, keep it to observed fact: the moment this list has an opinion about
## what the player is doing, the level has told them what to do.
const NOTES := [
	"0714  1 CANADA GOOSE. VOCAL.",
	"0716  SAME GOOSE. LOUDER.",
	"0719  STILL HERE.",
	"0721  BEHAVIOUR ATYPICAL.",
	"0724  NOW ON THE TOWER.",
	"0727  I HAVE STOPPED COUNTING.",
]


func _ready() -> void:
	_tex = get_node_or_null("/root/Tex")
	_sfx = get_node_or_null("/root/Sfx")

	_environment()
	_marsh()
	_dyke()
	_island()
	_tower()
	_timber()
	_reeds()
	_open_water()
	_signs()
	_birdwatcher()
	_props()
	_sources()
	_residents()
	_spawn_goose()
	# THE CENTREPIECE, and it goes in last because `flock_pen.gd:162` finds the
	# player by reading its parent's `goose` property in _ready() — so the pen
	# must be added AFTER _spawn_goose() or it never finds anybody and the [G]
	# prompt never appears. zone_corn.gd:270 has the same ordering for the same
	# reason.
	_pen = FLOCK_PEN.new().setup(PEN_AT)
	add_child(_pen)

	# AND THE PRIMARY THAT PAYS FOR IT.
	#
	# `name_a_driver` is one of this leg's four primaries and its condition is
	# the score label LBL_DRIVER — which NOTHING IN THE PROJECT EMITTED. The pen
	# names a driver, sobers the bird, puts a vest on it, plays two sounds,
	# throws DESIGNATED DRIVER into the air and emits `dd_designated`, and then
	# the objective sat there unticked. That is the silently-dead-objective bug
	# this codebase has already shipped once, on a REQUIRED primary, on the leg
	# whose entire design is "go and look at your flock".
	#
	# Scored here rather than in flock_pen.gd because the pen is in every zone in
	# the game and only this one has an objective for it — moving the payout into
	# the pen would hand every leg free chaos for pressing G. Same reasoning
	# boss_ranger.gd uses when it sniffs the pen out of the zone's children
	# instead of teaching the pen about bosses.
	if _pen.has_signal("dd_designated"):
		_pen.dd_designated.connect(_on_dd_designated)


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


## A SLOPED walkable slab whose TOP FACE runs from [param a] to [param c].
##
## THE MOST IMPORTANT HELPER IN THE FILE, and the reason is in the height table:
## every land surface here is 0.42 to 0.65 m above the waterline, and a swimming
## goose meeting a vertical kerb of that height is a goose that cannot get out
## of the water. In a chase zone that is a mistake; in the zone whose entire
## proposition is standing still it is the level failing to work at all.
##
## Orientation is built explicitly rather than with `look_at()`, because
## `look_at` needs the node in the tree with a resolved global transform and
## silently does nothing on a degenerate up-vector. Local +Z runs along a -> c,
## local +X is `UP x fwd` (so `width` is measured ACROSS the slope), local +Y is
## the slope normal; the centre drops by half the thickness along that normal so
## the top face — not the middle of the box — passes through a and c.
func _ramp(a: Vector3, c: Vector3, width: float, color: Color,
		thick := 0.30) -> StaticBody3D:
	var d := c - a
	var length := d.length()
	if length < 0.001:
		return null
	var fwd := d / length
	var right := Vector3.UP.cross(fwd)
	if right.length_squared() < 1e-6:
		right = Vector3.RIGHT
	right = right.normalized()
	var up := fwd.cross(right).normalized()

	var sb := StaticBody3D.new()
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(width, thick, length)
	mi.mesh = bm
	mi.material_override = _mat(color)
	sb.add_child(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = bm.size
	cs.shape = bs
	sb.add_child(cs)
	add_child(sb)
	sb.global_transform = Transform3D(Basis(right, up, fwd),
		(a + c) * 0.5 - up * (thick * 0.5))
	return sb


## Visual only — no collider. For paint, flat detail, a clipboard.
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


## A flat, non-colliding textured slab, split into tiles. Same reasoning as
## zone_corn.gd:347: a ninety-metre quad with a 30x-tiled texture is one draw
## call whose UVs the depth precision cannot hold.
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


func _hide_meshes(sb: Node) -> void:
	if sb == null:
		return
	for c in sb.get_children():
		if c is MeshInstance3D:
			c.visible = false


## A free-standing model with no collider at all. `pos` is where the model's
## BASE goes, so pass surface height, not centre. Falls back to the shared
## library for anything the refuge library does not own — the same two-library
## dispatch zone_truckstop.gd:417 uses.
func _model_at(kind: StringName, pos: Vector3, rot_y := 0.0, params := {},
		uniform := 1.0) -> Node3D:
	var n := Node3D.new()
	add_child(n)
	n.global_position = pos
	n.rotation.y = rot_y
	var m: Node3D = STOP.build(kind, n, params) if STOP.has_model(kind) \
		else PROPS.build(kind, n, params)
	if m == null:
		return n
	if not is_equal_approx(uniform, 1.0):
		n.scale = Vector3.ONE * uniform
	return n


## The Model node under a `_model_at()` holder, or null. Needed because
## `aim_scope`/`swing_gate` want the MODEL, not the holder the zone rotated.
func _model_of(holder: Node3D) -> Node3D:
	if holder == null:
		return null
	return holder.get_node_or_null("Model") as Node3D


func _prop(pos: Vector3, size: Vector3, color: Color, mass_kg: float, pts: int,
		lbl: String, extra := {}) -> ChaosProp:
	var p := ChaosProp.new()
	add_child(p)
	var kind: StringName = PROP_KIND.get(lbl, &"")
	var params: Dictionary = extra.duplicate()
	if kind != &"":
		params["colour"] = color
	p.setup(size, color, mass_kg, pts, lbl, kind, params)
	p.global_position = pos
	p.rotation.y = randf_range(-PI, PI)
	return p


func _source(pos: Vector3, res: Substance, size := 0.5, infinite := false) -> void:
	if res == null:
		return
	var s := SubstancePickup.new()
	add_child(s)
	s.setup(res, size)
	s.infinite = infinite
	s.global_position = pos


## One line of text on one of the library's blank placards.
##
## THE MIRROR RULE, applied in exactly one place in this zone so it can only be
## wrong once: screen-right on a face is `up.cross(normal)`, never +X. This
## project has shipped a stop sign reading POTS and a trailer reading ƎƆIVЯƎƧ,
## and both were a `+X` in a function like this one.
##
## `field` is whatever `STOP.text_field(kind)` returned; `y_off` moves the line
## up or down the face from the field's centre, in metres, so a placard can
## carry two or four lines without a second entry point.
##
## `unshaded = false` on the sign_text call is deliberate and is the library's
## own instruction: this is a dawn zone and a refuge sign is lit by the sunrise
## like everything else. The default `true` makes the lettering the single
## brightest thing in the level.
func _sign_line(parent: Node3D, field: Dictionary, text: String, h: float,
		y_off: float, col: Color, thickness := 0.014) -> void:
	if parent == null or field.is_empty() or text == "":
		return
	var centre: Vector3 = field["origin"]
	var normal: Vector3 = field["normal"]
	var up: Vector3 = field["up"]
	var right := up.cross(normal).normalized()
	var wdt: float = TS.text_width(text, h)
	var origin: Vector3 = centre + up * (y_off + h * 0.5) \
		- right * (wdt - h / 5.0) * 0.5
	TS.sign_text(parent, text, origin, normal, up, h, col, false, thickness)


# ══════════════════════════════════════════════════════════════ ENVIRONMENT
#
# THE FIRST WARM PALETTE SINCE GOLDEN HOUR, and the four notes that got it
# there. `prop_models_stopover.gd` publishes seven DAWN_* constants that no
# model reads — they exist so the light and the vertex colours describe the same
# morning, and every value below either IS one of them or says why it is not.
#
#   1. THE SUN IS ALMOST ON THE HORIZON AND IT IS AHEAD OF YOU. Seven degrees
#      of elevation, azimuth set so the light arrives from -Z and +X — over the
#      far end of the marsh and a little to the right of the opening shot. That
#      does three things at once: it back-lights every mist bank between the
#      player and the horizon, it lays a specular path down ninety metres of
#      water toward the camera, and it throws the tower's shadow forty-five
#      metres across the pool. A low sun BEHIND the camera would light the same
#      geometry perfectly and produce a photograph of a pond.
#
#      The library's DAWN_SUN_ELEVATION is 4.0 and this is 7.0. At four degrees
#      the tower's shadow is seventy-nine metres — longer than the shadow map
#      can hold at any sane `directional_shadow_max_distance` — and the whole
#      marsh goes to mush. Seven keeps the rake and keeps the shadows.
#
#   2. THE AMBIENT IS COOL AND IT IS DOING MOST OF THE WORK. DAWN_AMBIENT, a
#      blue-lilac, at 0.55 against a key of 0.85. Before the sun clears the
#      treeline the sky IS the light source and it is the coldest light of the
#      day; the warm key is a thin rim on top of it. Getting this backwards —
#      warm fill, strong key — produces midday with an orange filter, which is
#      leg 6's light.
#
#   3. THE FOG IS THE ZONE. 0.0060, nearly twice the corn field's, in
#      DAWN_FOG's warm grey. At ninety metres it is half opacity, so the far
#      shore does not exist and the marsh reads as going on forever. It is also
#      what stops forty-two geese and six hundred cattails from looking like a
#      countable number of objects.
#
#   4. EXPOSURE 1.0, WHITE 4.0. Filmic. The temptation with a sunrise is to
#      crank exposure; doing that clips the mist to a flat white sheet and the
#      four alpha layers in each bank stop reading as layers. Dawn is a WHITE
#      POINT decision, not an exposure one — the same lesson zone_corn.gd:462
#      learned in the other direction.

func _environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = STOP.DAWN_ZENITH
	sm.sky_horizon_color = STOP.DAWN_HORIZON
	# The far shore of an impoundment is a black treeline. It reads as ground
	# colour rather than as sky, and it is what the fog dissolves into.
	sm.ground_bottom_color = Color(0.150, 0.140, 0.130)
	sm.ground_horizon_color = Color(0.470, 0.395, 0.360)
	# 0.13 for the reason zone_corn.gd:479 found the hard way: the chase camera
	# sits about nine degrees below horizontal, so almost all the sky the player
	# ever sees is the bottom third of it. A high curve puts the horizon band in
	# the whole frame and the zone has no sky colour at all.
	sm.sky_curve = 0.13
	sm.sun_angle_max = 5.0
	sm.sun_curve = 0.07
	sky.sky_material = sm

	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = STOP.DAWN_AMBIENT
	env.ambient_light_energy = 0.55
	env.fog_enabled = true
	env.fog_density = 0.0060
	env.fog_light_color = STOP.DAWN_FOG
	env.fog_light_energy = 1.0
	# 0.35: enough that the horizon band and the fog are the same substance,
	# not so much that the zenith turns grey and the zone reads as overcast —
	# which is leg 2's light and the exact opposite of the brief.
	env.fog_sky_affect = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# 0.96 / 4.8, pulled back from 1.0 / 4.0 after the first render: pale gravel
	# under a grazing sun clipped the near two metres of road to a flat pink and
	# took the wheel tracks with it. The zone's brightest surface is the one the
	# camera is closest to for the whole leg, so the white point has to be set
	# for the road and not for the sky.
	env.tonemap_exposure = 0.96
	env.tonemap_white = 4.8
	we.environment = env
	add_child(we)

	# ── the sun ─────────────────────────────────────────────────────────
	# Y = 152 degrees puts the light travelling toward (-0.47, -0.12, +0.88),
	# i.e. arriving from ahead and to the right of a bird facing -Z.
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-STOP.DAWN_SUN_ELEVATION - 3.0, 152.0, 0.0)
	sun.light_energy = STOP.DAWN_SUN_ENERGY
	sun.light_color = STOP.DAWN_SUN
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	# Wide angular distance = soft shadow edges. The sun is being read through
	# forty metres of ground mist; a hard-edged shadow here would read as noon.
	sun.light_angular_distance = 1.60
	add_child(sun)

	# A cold shadowless fill from behind and above, standing in for the half of
	# the sky the ambient term does not shape. Without it the north faces of the
	# snags and the tower go to one flat value and the stand of dead timber —
	# the zone's signature silhouette — loses all of its depth.
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-38.0, -22.0, 0.0)
	fill.light_energy = 0.30
	fill.light_color = Color(0.62, 0.68, 0.86)
	fill.shadow_enabled = false
	add_child(fill)


# ══════════════════════════════════════════════════════════════════ THE MARSH
#
# The bed, the water, the swimmable volume and the walls. Everything else in
# the zone stands on or in this.

func _marsh() -> void:
	# ── the bed ─────────────────────────────────────────────────────────
	# Solid under the WHOLE map, including under the dyke and the island. Three
	# separate systems depend on that: a bird that dives hard has something to
	# hit instead of the void, the flock pen's ground raycast always gets an
	# answer, and a resident goose that somehow leaves its surface lands on mud
	# rather than falling out of the world.
	var bed := _static_tex(Vector3(0, BED_Y - 2.0, 0), Vector3(LOT, 4.0, LOT),
		&"dirt", 26.0, C_SILT)
	_hide_meshes(bed)
	# The visible bed, 2 cm proud of its collider so the silt reads under the
	# shallow water rather than z-fighting with it.
	_flat_tiles(Vector3(0, BED_Y - 0.01, 0), Vector3(LOT, 0.06, LOT),
		6, 6, &"dirt", C_SILT, 26.0)

	# ── the surface ─────────────────────────────────────────────────────
	# Tiled 8x8 for the reason zone_cottage.gd:519 gives: one ninety-metre quad
	# with a normal map gets exactly one specular highlight for the whole marsh,
	# which is the least convincing water anybody has ever shipped. Here it
	# matters more than it did at the cottage, because the ONE image this zone
	# exists to produce is a low sun raking across still water.
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(C_WATER.r, C_WATER.g, C_WATER.b, 0.87)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.roughness = 0.12
	wm.metallic = 0.72
	if _tex != null:
		var nrm: Texture2D = _tex.get_tex(&"water_normal")
		if nrm != null:
			wm.normal_enabled = true
			wm.normal_texture = nrm
			wm.normal_scale = 0.55
			wm.uv1_scale = Vector3(11.0, 11.0, 11.0)
	for ix in 8:
		for iz in 8:
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(LOT / 8.0, 0.08, LOT / 8.0)
			mi.mesh = bm
			mi.material_override = wm
			add_child(mi)
			mi.global_position = Vector3(
				-LOT * 0.5 + (LOT / 8.0) * (float(ix) + 0.5),
				WATER_Y - 0.04,
				-LOT * 0.5 + (LOT / 8.0) * (float(iz) + 0.5))

	# ── the swimmable volume ────────────────────────────────────────────
	# ONE Area3D over the entire map, because the entire map is water except
	# for two things that stick up out of it. Its TOP EDGE is the wade line —
	# see WADE_Y for the capsule arithmetic that picked 0.20. Everything
	# standable in the zone (island 0.62, road 0.70, catwalk 1.45, tower 3.82)
	# clears it by at least 0.42, which is more than the goose's 0.22 probe
	# radius, so nothing dry ever reports as wet.
	var water := Area3D.new()
	water.name = "Water"
	water.add_to_group("water")
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(LOT + 6.0, 2.4, LOT + 6.0)
	cs.shape = bs
	water.add_child(cs)
	water.monitoring = false
	add_child(water)
	water.global_position = Vector3(0, WADE_Y - 1.2, 0)

	# ── invisible walls ─────────────────────────────────────────────────
	# Tall, because the tower's ridge is the launch point for a ten-second glide
	# and a bird that clears the map at six metres up is a bird that falls out
	# of the world during the one objective the level wants you to attempt.
	for i in 4:
		var a := float(i) * PI * 0.5
		_hide_meshes(_static_box(
			Vector3(sin(a) * LOT * 0.5, 14.0, cos(a) * LOT * 0.5),
			Vector3(LOT, 34.0, 1.0), Color(1, 1, 1), a))


# ══════════════════════════════════════════════════════════════════ THE DYKE
#
# The gravel road, and the only dry line across the marsh. Seven tiled sections
# butted end to end along Z, ONE long collider under the crown, and two sloped
# shoulder slabs so the berm you can see is the berm you can walk down.
#
# It runs along Z rather than X because the library authored the section
# tileable along Z and because the opening shot is composed down -Z: a road that
# runs away from the camera into fog is worth more than any prop in the file,
# and it is the thing that tells a player who has never seen this zone which way
# the level goes.

func _dyke() -> void:
	var z := DYKE_Z0 + STOP.DYKE_SPAN * 0.5
	var i := 0
	while z < DYKE_Z1:
		_model_at(&"dyke_section", Vector3(0, BED_Y, z), 0.0,
			{"variant": float(i) * 1.7})
		z += STOP.DYKE_SPAN
		i += 1

	# ── the road itself ─────────────────────────────────────────────────
	# One box under the whole crown. Physics does not care how many sections the
	# art has, and one broadphase entry is one broadphase entry.
	var road_len := DYKE_Z1 - DYKE_Z0
	var road_cz := (DYKE_Z0 + DYKE_Z1) * 0.5
	var road_top := DYKE_CROWN
	var road_h := 1.50
	_hide_meshes(_static_box(Vector3(0, road_top - road_h * 0.5, road_cz),
		Vector3(DYKE_HALF_W * 2.0, road_h, road_len), C_SILT))

	# ── the shoulders ───────────────────────────────────────────────────
	# The berm's outer profile, as physics, and then some. Through (2.20, 0.70)
	# and (4.10, 0.05) the collider is the art to within a centimetre — a
	# raycast at x = 3.55 reads 0.238 against the model's 0.233 — and it then
	# keeps going to DYKE_RAMP_X / DYKE_RAMP_Y so that its bottom edge is buried
	# in the bed. That last metre is the whole reason this is a ramp: the first
	# pass stopped the collider at the visible toe and a probe found a 35 cm
	# vertical face there, which is a swimming goose that cannot get back on the
	# road. Hidden — the rip-rap is the art.
	for sx in [-1.0, 1.0]:
		var xs: float = sx
		_hide_meshes(_ramp(
			Vector3(xs * DYKE_RAMP_X, DYKE_RAMP_Y, road_cz),
			Vector3(xs * DYKE_HALF_W, DYKE_CROWN, road_cz),
			road_len, C_SILT))

	# ── the trailhead furniture ─────────────────────────────────────────
	# Bollards down the last few metres of road before the gate. A bollard stops
	# a truck and does not stop a goose, which is the entire joke and the reason
	# they have no colliders.
	for k in 5:
		var bz := -8.4 - float(k) * 5.6
		if bz < DYKE_Z0:
			bz = -8.4 + float(k) * 5.6
		_model_at(&"bollard", Vector3(-2.55, DYKE_TOE_Y + 0.34, -7.0 + float(k) * 6.2),
			float(k) * 0.4, {"variant": float(k) * 2.1})
	for k in 4:
		_model_at(&"bollard", Vector3(2.55, DYKE_TOE_Y + 0.34, -4.0 + float(k) * 7.4),
			float(k) * 0.7 + 0.3, {"variant": float(k) * 1.3 + 0.6})

	# ── the gate ────────────────────────────────────────────────────────
	# Standing wide open, because a refuge dyke gate is open at dawn, and
	# carrying a notice that says AREA CLOSED, because it also always does. The
	# leaf hinges at model-local x = -1.66, so the model sits a little to -X for
	# the shut position to cover the road; it is never shut.
	_gate = _model_at(&"gate", Vector3(-0.30, DYKE_CROWN, -9.60), 0.0)
	var gm := _model_of(_gate)
	if gm != null:
		# The notice lives on the LEAF, not on the model — it swings with the
		# gate. text_field(&"gate") says so; passing the model here would leave
		# the sign hanging in the air where the gate used to be.
		var leaf: Node3D = STOP.gate_leaf(gm)
		var gf: Dictionary = STOP.text_field(&"gate")
		if leaf != null and not gf.is_empty():
			_sign_line(leaf, gf, "AREA", 0.072, 0.052, STOP.C_REFUGE_BROWN, 0.008)
			_sign_line(leaf, gf, "CLOSED", 0.072, -0.070, STOP.C_REFUGE_BROWN, 0.008)


# ══════════════════════════════════════════════════════════════════ THE ISLAND
#
# Twenty-two metres square, sixty-two centimetres out of the water, and the
# only place in the level with more than one thing on it. The spec's phrase is
# "the plateau becomes a low island"; low is the operative word, because an
# island you can see over from the water is a destination and one you cannot is
# a wall.

func _island() -> void:
	# The block. Hidden, because the dressing below is the art.
	_hide_meshes(_static_box(Vector3(0, ISLAND_Y - 1.2, ISLAND_CZ),
		Vector3(ISLAND_HW * 2.0, 2.4, ISLAND_HW * 2.0), C_SWARD))

	# ── the rim ─────────────────────────────────────────────────────────
	# Five ramps: the west, east and south faces full width, and two on the
	# north face either side of where the road arrives. Without these the island
	# is a 42 cm kerb all the way round and a swimming goose is stuck in the
	# water, in the rest beat, next to its own flock.
	#
	# THE TOE GOES BELOW THE BED, and that is the fix rather than a detail. The
	# first pass put it at +0.02 — under the wade line, which felt like enough —
	# and a raycast found a 32 cm vertical face at the ramp's leading edge,
	# because a box with thickness has an edge. Starting at BED_Y - 0.05 buries
	# that edge in the mud: the surface simply emerges from the bed 19 cm in and
	# there is nothing to climb anywhere. It also makes a proper shelving beach —
	# the slope crosses the 0.20 wade line 1.6 m out, so there is a metre and a
	# half of standing-depth shallows round the whole island.
	#
	# AND THEY ARE THE ONLY RAMPS IN THE ZONE THAT STAY VISIBLE. Everywhere else
	# a model covers the collider — the dyke's rip-rap, the tower's treads — but
	# nothing in the library builds an island bank, so a hidden ramp here left a
	# 62 cm cliff of nothing that the goose visibly walked UP through thin air.
	# So the ramp IS the bank: wet marsh mud between the sward and the water,
	# and its top edge is coplanar with the sward tiles along one line, which is
	# why it does not z-fight.
	var rim := 3.45
	var toe := BED_Y - 0.05
	# Wet silt, and LIGHTER than the value it wants to be. The bank faces every
	# direction, so at a 7-degree sunrise two of its five faces are always in
	# shadow — and at 0.298 albedo under a 0.55 ambient the west bank rendered as
	# a flat black void between bright water and a lit island. It is a marsh
	# bank; it is allowed to be pale.
	var bank := Color(0.400, 0.362, 0.284)
	_ramp(Vector3(-ISLAND_HW - rim, toe, ISLAND_CZ),
		Vector3(-ISLAND_HW, ISLAND_Y, ISLAND_CZ), ISLAND_HW * 2.0, bank)
	_ramp(Vector3(ISLAND_HW + rim, toe, ISLAND_CZ),
		Vector3(ISLAND_HW, ISLAND_Y, ISLAND_CZ), ISLAND_HW * 2.0, bank)
	_ramp(Vector3(0, toe, ISLAND_CZ - ISLAND_HW - rim),
		Vector3(0, ISLAND_Y, ISLAND_CZ - ISLAND_HW), ISLAND_HW * 2.0, bank)
	for sx in [-1.0, 1.0]:
		var xs: float = sx
		var half := (ISLAND_HW - DYKE_HALF_W) * 0.5
		_ramp(
			Vector3(xs * (DYKE_HALF_W + half), toe, ISLAND_CZ + ISLAND_HW + rim),
			Vector3(xs * (DYKE_HALF_W + half), ISLAND_Y, ISLAND_CZ + ISLAND_HW),
			half * 2.0, bank)

	# ── the sward ───────────────────────────────────────────────────────
	# Dead autumn marsh grass. Its top sits exactly on ISLAND_Y: the cottage
	# lets its dressing ride 3 cm proud of the collider and gets away with it,
	# but the whole point of this island is that the player stands still on it
	# and a 3 cm lip under a stationary bird is visible.
	_flat_tiles(Vector3(0, ISLAND_Y - 0.03, ISLAND_CZ),
		Vector3(ISLAND_HW * 2.0, 0.06, ISLAND_HW * 2.0), 3, 3,
		&"grass", C_SWARD, 9.0)
	# The path the road turns into once it is on the island: bare, trodden, and
	# it points at the pen.
	_flat_tiles(Vector3(0, ISLAND_Y - 0.02, -14.5), Vector3(3.0, 0.06, 10.0),
		1, 2, &"dirt", Color(0.415, 0.372, 0.300), 6.0)


# ══════════════════════════════════════════════════════════ THE TOWER
#
# The zone's only high ground, its only climb, and — the part that is not
# obvious from the model — its launch pad. `take_the_air` asks for ten unbroken
# seconds of flight and the ridge at 6.17 m over ninety metres of open water
# with nothing in the way is the longest clean glide line in the game. The
# objective list points at the tower twice and never joins the two up.
#
# COLLIDERS ARE THE ZONE'S JOB and the library says exactly how many: a box for
# the deck, a box for the landing, and one ramp per stair flight. NOT one per
# tread — sixteen individual steps at this scale is sixteen nosings for a goose
# to catch on.

func _tower() -> void:
	var holder := _model_at(&"observation_tower", TOWER_AT, 0.0, {"variant": 0.8})
	var base := TOWER_AT

	# The deck. TOWER_DECK_HW is the half-width; the top face lands on
	# base.y + TOWER_DECK_Y = 3.82.
	var deck_y: float = base.y + STOP.TOWER_DECK_Y
	_hide_meshes(_static_box(Vector3(base.x, deck_y - 0.10, base.z),
		Vector3(STOP.TOWER_DECK_HW * 2.0, 0.20, STOP.TOWER_DECK_HW * 2.0), C_SWARD))

	# The half-landing, at model-local (0, 1.60, 4.45).
	var land_y: float = base.y + STOP.TOWER_LANDING_Y
	_hide_meshes(_static_box(Vector3(base.x, land_y - 0.09, base.z + 4.45),
		Vector3(1.46, 0.18, 0.88), C_SWARD))

	# The two flights, as ramps. Model-local endpoints, straight out of
	# `_observation_tower`: (0, 0, 7.00) -> (0, 1.60, 4.80) and
	# (0, 1.60, 4.10) -> (0, 3.20, 1.90).
	_hide_meshes(_ramp(base + Vector3(0, 0.02, STOP.TOWER_STAIR_Z),
		base + Vector3(0, STOP.TOWER_LANDING_Y, 4.80), 1.36, C_SWARD, 0.22))
	_hide_meshes(_ramp(base + Vector3(0, STOP.TOWER_LANDING_Y, 4.10),
		base + Vector3(0, STOP.TOWER_DECK_Y, 1.90), 1.36, C_SWARD, 0.22))

	# ── the bonus ───────────────────────────────────────────────────────
	# ROUTE_DATA §7.2's `tower` objective, and it belongs to the zone rather
	# than to the library. A trigger volume sitting on the deck, tall enough
	# that a bird landing hard and bouncing still trips it.
	var area := Area3D.new()
	area.name = "TowerDeck"
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(STOP.TOWER_DECK_HW * 2.0 - 0.2, 1.8,
		STOP.TOWER_DECK_HW * 2.0 - 0.2)
	cs.shape = bs
	area.add_child(cs)
	area.monitoring = true
	area.monitorable = false
	add_child(area)
	area.global_position = Vector3(base.x, deck_y + 0.9, base.z)
	area.body_entered.connect(_on_tower_deck)

	if holder != null:
		holder.set_meta("stopover_role", "tower")


func _on_tower_deck(body: Node3D) -> void:
	if _tower_scored or not (body is Goose):
		return
	_tower_scored = true
	Game.score(240, MDEF.LBL_TOWER, body.global_position + Vector3(0, 0.9, 0))
	if _sfx != null:
		_sfx.play(&"score_blip_hi", -3.0, 1.06)


# ══════════════════════════════════════════════════ DEAD STANDING TIMBER
#
# When a refuge floods an impoundment it kills the trees standing in it and they
# stay up for decades. A stand of them is the single image that says "drowned
# marsh" rather than "pond", and after four legs of houses, rock and asphalt it
# is the thing that makes this zone unmistakable at a glance from the air.
#
# All four silhouettes get used and the tall SPAR is used most, because a stand
# of one shape reads as wallpaper in about nine seconds. Anchored on the BED,
# not the waterline: a drowned trunk goes into the mud.
#
# NO COLLIDERS. Not one, on any of them. That is not laziness — a nine-metre
# pole with a collider in the middle of open water is a thing a gliding bird
# clips at speed, and the one objective this zone wants attempted is a
# ten-second glide across that water.

func _timber() -> void:
	# [x, z, form, yaw, variant, scale]
	var stand := [
		# The west pool stand — the one in the opening shot, off the player's
		# left shoulder, with the low sun behind it.
		[-19.0, -9.0, 0, 0.4, 0.0, 1.00],
		[-24.5, -14.0, 2, 2.1, 1.3, 0.92],
		[-16.0, -18.5, 1, 1.2, 0.6, 1.06],
		[-28.0, -5.0, 0, 3.0, 2.2, 0.86],
		[-22.0, -25.0, 3, 0.8, 1.9, 0.98],
		[-31.5, -17.0, 0, 1.7, 3.1, 1.10],
		[-14.5, -30.0, 1, 2.6, 0.9, 0.90],
		[-35.0, -27.0, 2, 0.2, 2.7, 1.02],
		# Two out in the middle of the north half, so the road has something to
		# run past.
		[-9.0, 15.0, 0, 1.1, 1.5, 0.94],
		[-13.5, 28.0, 3, 2.4, 0.4, 0.88],
		# The east pool stand — smaller, further out, mostly silhouette.
		[17.0, -4.0, 0, 2.9, 1.1, 1.04],
		[23.0, 6.0, 2, 0.6, 2.5, 0.96],
		[15.5, 14.0, 1, 1.9, 3.4, 0.92],
		[27.0, -14.0, 0, 0.9, 0.7, 1.08],
		[21.0, 24.0, 3, 2.2, 1.8, 0.90],
		[31.0, 12.0, 0, 1.4, 2.9, 0.98],
	]
	for i in stand.size():
		var row: Array = stand[i]
		var x: float = row[0]
		var z: float = row[1]
		var form: int = int(row[2])
		var yaw: float = row[3]
		var seed_v: float = row[4]
		var scl: float = row[5]
		_model_at(&"snag", Vector3(x, BED_Y, z), yaw,
			{"form": form, "variant": seed_v}, scl)


# ══════════════════════════════════════════════════════════════════ THE REEDS
#
# Six hundred cattails in THREE draw calls.
#
# The geometry is `prop_models.gd`'s `&"cattail"` — the same reed the strip-mall
# pond has had since leg 1, not a second one. `prop_models_stopover.gd` supplies
# the missing half: `cattail_mesh()` lifts its ArrayMesh out of a throwaway
# build and `cattail_bed()` hands it to a MultiMesh with an explicit AABB.
# Six hundred MeshInstance3Ds would be six hundred draw calls for the same
# picture, which is the mistake zone_corn.gd:660 records having avoided once
# already for its 1,770 corn stalks.
#
# NO COLLIDERS, same as the corn: you walk into reeds, not up against them. Here
# it does not even buy a mechanic — there is nothing to hide from — it is purely
# that a marsh whose edges push you around is not restful.
#
# Both tints come from the library's published palette, and the wetter bed out
# in the east pool is a shade greener than the dry stand along the road, which
# is the only thing making two halves of one marsh read as two places.

func _reeds() -> void:
	# ── the dyke toe, both sides, the full length of the road ───────────
	var toe: Array[Vector3] = []
	toe.append_array(STOP.bed_spots_band(
		Vector3(-3.55, WATER_Y, DYKE_Z0 - 1.0), Vector3(-3.55, WATER_Y, DYKE_Z1),
		1.35, 120, 0.0))
	toe.append_array(STOP.bed_spots_band(
		Vector3(3.55, WATER_Y, DYKE_Z0 - 1.0), Vector3(3.55, WATER_Y, DYKE_Z1),
		1.35, 120, 3.3))
	STOP.cattail_bed(self, toe, {
		"colour": STOP.C_REED, "variant": 1.0, "name": "ReedsDyke",
		"scale_min": 0.74, "scale_max": 1.22})

	# ── the island rim, three sides ─────────────────────────────────────
	# Not the north side: that is where the road arrives and where the player
	# walks in, and a wall of reeds across the entrance hides the pen.
	var rim: Array[Vector3] = []
	rim.append_array(STOP.bed_spots_band(
		Vector3(-ISLAND_HW - 1.9, WATER_Y, ISLAND_CZ - ISLAND_HW - 1.0),
		Vector3(-ISLAND_HW - 1.9, WATER_Y, ISLAND_CZ + ISLAND_HW - 1.0),
		1.15, 60, 0.7))
	rim.append_array(STOP.bed_spots_band(
		Vector3(ISLAND_HW + 1.9, WATER_Y, ISLAND_CZ - ISLAND_HW - 1.0),
		Vector3(ISLAND_HW + 1.9, WATER_Y, ISLAND_CZ + ISLAND_HW - 1.0),
		1.15, 60, 2.4))
	rim.append_array(STOP.bed_spots_band(
		Vector3(-ISLAND_HW, WATER_Y, ISLAND_CZ - ISLAND_HW - 1.9),
		Vector3(ISLAND_HW, WATER_Y, ISLAND_CZ - ISLAND_HW - 1.9),
		1.15, 60, 4.1))
	STOP.cattail_bed(self, rim, {
		"colour": STOP.C_REED.darkened(0.06), "variant": 2.0, "name": "ReedsIsland",
		"scale_min": 0.78, "scale_max": 1.30})

	# ── the east pool bed ───────────────────────────────────────────────
	# A wide band the road runs alongside. This is the "drowned marsh" half of
	# the level: it has no island, no structure and nothing to do in it, and it
	# is where most of the forty geese are.
	var pool: Array[Vector3] = []
	pool.append_array(STOP.bed_spots_band(
		Vector3(19.0, WATER_Y, -30.0), Vector3(33.0, WATER_Y, 22.0),
		6.5, 150, 5.5))
	STOP.cattail_bed(self, pool, {
		"colour": STOP.C_REED.lightened(0.05), "variant": 3.0, "name": "ReedsPool",
		"scale_min": 0.80, "scale_max": 1.34})


# ══════════════════════════════════════════════════════════ THE OPEN WATER
#
# The weir, three nest boxes, and ten banks of mist. Between them they are the
# entire reason the water is worth looking at, and none of them does anything.

func _open_water() -> void:
	# ── the water control structure ─────────────────────────────────────
	# The literal mechanism that makes a drowned marsh a drowned marsh: a
	# concrete headwall, a stack of timber stoplogs, and a handwheel to pull
	# them. Its catwalk is the only standable thing out in the open water —
	# 1.45 m up, which is 0.78 of a flap from a swimming bird — and it is
	# thirteen metres off the road, so getting there is a decision rather than a
	# detour.
	var weir := _model_at(&"water_control", WEIR_AT, 0.0, {"open": true})
	# Two colliders, which is what the library asks for. The headwall spans the
	# bay because the goose cannot fit through it anyway and one box is one
	# broadphase entry.
	_hide_meshes(_static_box(WEIR_AT + Vector3(0, 0.90, 0),
		Vector3(3.24, 1.60, 0.46), C_SILT))
	_hide_meshes(_static_box(WEIR_AT + Vector3(0, STOP.WEIR_DECK_Y - 0.10, 0),
		Vector3(3.00, 0.20, 0.86), C_SILT))
	if weir != null:
		weir.set_meta("stopover_role", "weir")

	var wa := Area3D.new()
	wa.name = "WeirDeck"
	var wcs := CollisionShape3D.new()
	var wbs := BoxShape3D.new()
	wbs.size = Vector3(2.60, 1.5, 0.76)
	wcs.shape = wbs
	wa.add_child(wcs)
	wa.monitoring = true
	wa.monitorable = false
	add_child(wa)
	wa.global_position = WEIR_AT + Vector3(0, STOP.WEIR_DECK_Y + 0.75, 0)
	wa.body_entered.connect(_on_weir_deck)

	# ── nest boxes ──────────────────────────────────────────────────────
	# The cheapest possible "this is a wildlife refuge": a wood duck box on a
	# post with a galvanised predator cone under it. Forty triangles each and
	# they do more for the place than any amount of geometry. One of them has a
	# goose on the roof, which is what the library's perch rail was for.
	_model_at(&"nest_box", Vector3(16.0, BED_Y, -2.0), 0.6)
	_model_at(&"nest_box", Vector3(-24.0, BED_Y, 12.0), 2.4)
	_model_at(&"nest_box", Vector3(9.0, BED_Y, -37.0), 1.1)

	# ── the mist ────────────────────────────────────────────────────────
	# Ten banks, each four overlapping alpha sheets on the library's
	# CULL_DISABLED haze material, drifting at 0.12-0.30 m/s on independent
	# headings and wrapping at the map edge.
	#
	# THEY SIT AT THE WATER, NOT AT EYE HEIGHT. The library's own instruction,
	# and it is right: mist at eye height is fog, and fog belongs in the
	# WorldEnvironment where it costs nothing and does not sort. These are the
	# thing you fly THROUGH, which is why the material has culling off.
	#
	# TWENTY BANKS IN TEN OVERLAPPING PAIRS, AT ALPHA 0.15, AND ALL THREE OF
	# THOSE NUMBERS CAME OFF A RENDER.
	#
	# A bank is four HORIZONTAL alpha sheets. From a camera at water level it is
	# edge-on and has almost no screen area, so the library's default 0.13 was
	# invisible from the road and from the tower alike and the only mist in the
	# level was the WorldEnvironment fog. Raising it to 0.30 fixed the visibility
	# and broke something worse: from six metres up, a single sheet at that alpha
	# draws its own OUTLINE, and a wobbled polygon with a hard rim lying on water
	# reads as a sheet of paper, not as fog.
	#
	# Alpha was never the real lever — the rim was. Two banks per spot, offset,
	# counter-rotated and at different scales, compound to 1-(1-a)^2 = 0.28 where
	# they overlap and stay at 0.15 at the fringes, so the union has a soft edge
	# and no readable outline anywhere. Twenty banks is 720 triangles on one
	# material.
	#
	# The honest fix lives in the library rather than here: `_mist_bank`'s discs
	# want a feathered rim (an outer ring at alpha 0). Until then this is the
	# cheap approximation and it is written down as such.
	var haze := Color(0.95, 0.88, 0.86, 0.15)
	var spots := [
		Vector3(-11.0, 0.0, 8.0), Vector3(-24.0, 0.0, -2.0), Vector3(-18.0, 0.0, 22.0),
		Vector3(-33.0, 0.0, -19.0), Vector3(-8.0, 0.0, 34.0), Vector3(12.0, 0.0, 2.0),
		Vector3(22.0, 0.0, -18.0), Vector3(28.0, 0.0, 16.0), Vector3(14.0, 0.0, 30.0),
		Vector3(-20.0, 0.0, -34.0),
	]
	for i in spots.size():
		var p: Vector3 = spots[i]
		var ang := float(i) * 2.39 + 0.7
		var drift := Vector3(cos(ang), 0.0, sin(ang)) \
			* (0.12 + 0.18 * absf(sin(float(i) * 1.31)))
		for j in 2:
			var jf := float(j)
			# The second sheet is pushed a third of a radius off, turned the
			# other way and built from a different variant, so the two rims never
			# agree anywhere along their length.
			var off := Vector3(1.9 * jf * cos(ang + 1.9), 0.02 * jf,
				1.9 * jf * sin(ang + 1.9))
			var k0 := (1.30 + 0.40 * absf(sin(float(i) * 2.13))) * (1.0 - 0.22 * jf)
			var n := _model_at(&"mist_bank",
				Vector3(p.x, WATER_Y + 0.03, p.z) + off,
				float(i) * 0.9 + jf * 1.7,
				{"variant": float(i) * 1.6 + jf * 4.3, "colour": haze})
			if n == null:
				continue
			_mist.append(n)
			_mist_scale.append(k0)
			# The pair drifts together, so they stay a pair.
			_mist_vel.append(drift)


func _on_weir_deck(body: Node3D) -> void:
	if _weir_scored or not (body is Goose):
		return
	_weir_scored = true
	Game.score(180, MDEF.LBL_WEIR, body.global_position + Vector3(0, 0.9, 0))
	if _sfx != null:
		_sfx.play(&"score_blip_hi", -5.0, 0.98)


# ══════════════════════════════════════════════════════════════════ THE SIGNS
#
# Three placards, and the library ships all three of them BLANK on purpose: it
# owns the sign, the zone owns the words. Everything here goes through
# `_sign_line()`, which is the only place in the file that computes a text
# direction.
#
# WHAT IS ON THEM IS A DESIGN DECISION, NOT DRESSING. CAMPAIGN_SPEC.md:504 is
# blunt: the thesis "never says a word". So the entrance sign says where you
# are, the gate says the gate thing that gates say, and the interpretive panel
# is about invertebrates — because that is what real refuge panels are about,
# and because a panel at the exact spot where the game wants you to stop and do
# nothing, listing what lives in the mud, is the whole argument made without
# making it.

func _signs() -> void:
	# ── the entrance sign ───────────────────────────────────────────────
	# Brown field, white keyline, flying-goose emblem, name to the right of it.
	# Rotated PI so it faces +Z — the player arrives from the north and reads it
	# on the way in. The model is authored facing -Z like everything else here,
	# so the rotation is on the HOLDER and the text field's coordinates stay
	# model-local and correct.
	# THE TWO PLACARDS NEED COLLIDERS, AND NOT SO A GOOSE CAN WALK INTO THEM.
	#
	# `goose_camera.gd`'s rig is a SpringArm3D on `collision_mask = 1`: it pulls
	# the camera in when something SOLID gets between lens and bird, and it is
	# blind to pure visuals. `_model_at()` builds no collider at all, so a 2.5 m
	# board 1.4 m in front of the camera's rest position is simply not seen.
	#
	# The rig sits ~6 m at +Z of a goose facing -Z, and this sign is at z = -12.4
	# — which puts it between camera and goose for anyone standing on the
	# island's north-east quadrant. That quadrant contains the birdwatcher, the
	# folding chair, the east arc of the pen and the trodden path: i.e. the two
	# places both of this zone's bonus objectives send you. Walking up to the
	# birdwatcher filled the screen with a brown billboard and hid the bird.
	#
	# A thin hidden box is the cheapest fix and it is what the dyke, the island
	# and the tower already do. It also, incidentally, stops a goose walking
	# through a signpost.
	var sign := _model_at(&"refuge_sign", Vector3(3.60, ISLAND_Y, -12.40), PI)
	_hide_meshes(_static_box(Vector3(3.60, ISLAND_Y + 1.10, -12.40),
		Vector3(2.50, 2.20, 0.16), Color(1, 1, 1), PI))
	var sm := _model_of(sign)
	if sm != null:
		var f: Dictionary = STOP.text_field(&"refuge_sign")
		if not f.is_empty():
			# 0.155 and 0.052, not 0.170 and 0.058. The truckstop font's width is
			# `length * h`, so nine characters at 0.170 is 1.53 m in a 1.60 m
			# field — it fits, and the render showed it fitting the way a shoe
			# fits when it is exactly your size. These leave 10 cm either side.
			_sign_line(sm, f, "MONTEZUMA", 0.155, 0.120, STOP.C_SIGN_WHITE, 0.020)
			_sign_line(sm, f, "NATIONAL WILDLIFE REFUGE", 0.052, -0.110,
				STOP.C_SIGN_WHITE, 0.012)

	# ── the interpretive panel ──────────────────────────────────────────
	# -2.02 RADIANS, AND IT TOOK TWO RENDERS TO GET THERE. The panel stands four
	# and a half metres WEST of the path, so "facing the player" is not "facing
	# back up the road" — it is facing +X and a little +Z, the bearing from the
	# panel to a bird walking south past it. Both earlier guesses (PI - 0.45 and
	# PI + 0.45) photographed the thing edge-on, which is what a lectern looks
	# like from the side: a plank. Four lines, and not one of them is about the
	# player.
	var panel := _model_at(&"interp_sign", Vector3(-4.60, ISLAND_Y, -13.60), -2.02)
	# Same exposure on the west side, same fix — see the refuge sign above.
	# A lectern is shorter than the placard, so the box is too.
	_hide_meshes(_static_box(Vector3(-4.60, ISLAND_Y + 0.55, -13.60),
		Vector3(1.40, 1.10, 0.16), Color(1, 1, 1), -2.02))
	var pm := _model_of(panel)
	if pm != null:
		var pf: Dictionary = STOP.text_field(&"interp_sign")
		if not pf.is_empty():
			_sign_line(pm, pf, "WHAT IS DOWN THERE", 0.050, 0.198,
				STOP.C_SIGN_WHITE, 0.010)
			_sign_line(pm, pf, "MIDGE LARVAE", 0.062, 0.065,
				STOP.C_SIGN_WHITE, 0.010)
			_sign_line(pm, pf, "AMPHIPODS", 0.062, -0.040, STOP.C_SIGN_WHITE, 0.010)
			_sign_line(pm, pf, "SNAILS", 0.062, -0.145, STOP.C_SIGN_WHITE, 0.010)


# ══════════════════════════════════════════════════════════ THE BIRDWATCHER
#
# CAMPAIGN_SPEC.md:526, in full: "The birdwatcher says nothing, but their scope
# tracks you, and if you honk at them they write something down. That's the
# whole gag and it costs one Label3D."
#
# It costs one Label3D. Everything below is that sentence and nothing else:
#
#   * They are an `NpcHuman` with PROCESS MODE DISABLED and removed from the
#     "npc" group. Both halves matter. Disabled means they never wander, never
#     flee and never turn round — the joke is a person who does not react to a
#     goose. Out of the group means `honk.gd::_shove()` cannot startle them,
#     which would undo the first half from a system this file does not own.
#     They keep their capsule, so you can walk into them, which is funnier than
#     walking through them.
#   * They are placed at EXACTLY the island surface, not surface + 0.2 like the
#     other zones. Those zones let gravity settle the body; this one has gravity
#     switched off, and `human_visual_lowpoly.gd::HIP_Y` already puts the soles
#     on local y = 0. Add a margin here and the birdwatcher hovers forever.
#   * The scope is a real child node the zone rotates, so tracking costs a
#     transform write rather than a mesh rebuild.
#   * The chair is the ONE saturated object in the level and it is doing work:
#     navy nylon in a field of desaturated warm greys is how the player finds
#     the birdwatcher from sixty metres, and the birdwatcher is standing next to
#     the flock pen.

func _birdwatcher() -> void:
	var n := NpcHuman.new()
	add_child(n)
	# A field coat in the one colour nobody wears on purpose. Deliberately close
	# in value to the sward so the PERSON is not what catches your eye — the
	# chair is.
	n.setup(Color(0.38, 0.36, 0.30))
	n.global_position = WATCHER_AT
	# Facing WEST-NORTH-WEST, out over the pool with the dead timber in it —
	# which is where the birds are, and which is also three-quarters toward a
	# player walking in from the north. The first pass had them facing east and
	# the render showed the joke from behind: you cannot tell that somebody is
	# ignoring you if you cannot see their face.
	n.rotation.y = 2.05
	# STILL, BUT STILL SOLID.
	#
	# This was `process_mode = PROCESS_MODE_DISABLED`, which does the right thing
	# to the wandering and the wrong thing to the body: Godot removes a disabled
	# CollisionObject3D from the physics space entirely. The birdwatcher became a
	# hologram, and the player walked through the one person in the zone who is
	# pointedly refusing to react to them — which is the whole joke, and it is a
	# physical joke.
	#
	# Turning the callbacks off individually leaves the CharacterBody3D
	# registered, so it still occupies space and still stops a goose.
	n.set_process(false)
	n.set_physics_process(false)
	if n.is_in_group("npc"):
		n.remove_from_group("npc")
	_watcher = n

	# The notebook, at hand height and IN FRONT of them for that facing — the
	# offset is `forward * 0.28 + right * 0.16` for a yaw of 2.05, resolved once
	# here rather than recomputed. Two boxes and a spine: it exists to be the
	# thing the Label3D points at, and to give the honk gag a physical anchor.
	_note_pad = Node3D.new()
	add_child(_note_pad)
	_note_pad.global_position = WATCHER_AT + Vector3(-0.32, 1.06, -0.02)
	_note_pad.rotation.y = 2.05
	var pad := MeshInstance3D.new()
	var pb := BoxMesh.new()
	pb.size = Vector3(0.20, 0.015, 0.15)
	pad.mesh = pb
	pad.material_override = _mat(STOP.C_SIGN_WHITE, 0.86)
	_note_pad.add_child(pad)
	var spine := MeshInstance3D.new()
	var sb2 := BoxMesh.new()
	sb2.size = Vector3(0.21, 0.020, 0.026)
	spine.mesh = sb2
	spine.material_override = _mat(STOP.C_REFUGE_BROWN, 0.8)
	spine.position = Vector3(0, 0.004, -0.077)
	_note_pad.add_child(spine)

	# THE ONE LABEL3D. Hidden until they write something.
	_note_lbl = Label3D.new()
	_note_lbl.text = ""
	_note_lbl.font_size = 44
	_note_lbl.pixel_size = 0.0032
	_note_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_note_lbl.modulate = Color(0.94, 0.92, 0.86, 0.0)
	_note_lbl.outline_size = 10
	_note_lbl.outline_modulate = Color(0.10, 0.09, 0.10, 0.0)
	_note_lbl.no_depth_test = false
	add_child(_note_lbl)
	_note_lbl.global_position = WATCHER_AT + Vector3(0.0, 2.20, 0.0)
	_note_lbl.visible = false

	# ── the kit ─────────────────────────────────────────────────────────
	# The scope, aimed at the pool to start with so it has somewhere to swing
	# FROM the first time the player walks into view.
	_scope = _model_at(&"spotting_scope", SCOPE_AT, 2.05)
	var sh: Node3D = STOP.scope_head(_model_of(_scope))
	if sh != null:
		sh.rotation.y = 0.35

	_model_at(&"folding_chair", CHAIR_AT, 2.35, {"thermos": true})


# ══════════════════════════════════════════════════════════════ POPULATION
#
# A refuge trailhead accumulates exactly this much junk and no more. Six labels,
# nine objects, every one of them from the SHARED library so `ChaosProp.setup()`
# can build its own model — see PROP_KIND.
#
# There is deliberately nothing here worth a rampage. `variety_pack` is the only
# objective that looks at any of it, it is a bonus, and its target is low. A
# player who arrives at the rest beat and immediately starts breaking things is
# having a good time and should get paid a little for it; they should not be
# able to get paid a lot.

func _props() -> void:
	# The trailhead, on the last few metres of road before the gate.
	_prop(Vector3(-1.55, DYKE_CROWN + 0.61, -5.6), Vector3(1.00, 1.20, 0.80),
		Color(0.26, 0.33, 0.28), 10.0, 40, "RECYCLING")
	_prop(Vector3(-1.90, DYKE_CROWN + 0.28, -3.4), Vector3(0.48, 0.55, 0.50),
		Color(0.17, 0.17, 0.18), 3.0, 18, "GARBAGE", {"variant": 0.4})
	_prop(Vector3(1.70, DYKE_CROWN + 0.28, -6.8), Vector3(0.48, 0.55, 0.50),
		Color(0.19, 0.18, 0.17), 3.0, 18, "GARBAGE", {"variant": 2.2})
	# NO STAKED NOTICE. There was one, as a ChaosProp, and two renders in a row
	# photographed it lying flat on the road with its two pale stake-feet in the
	# air, six metres from the opening camera, reading unmistakably as a body. A
	# lawn sign is a thin tall RigidBody: it topples the instant physics starts,
	# which is correct behaviour and the wrong first frame. It is a static model
	# now, back up the road, standing where somebody put it.
	_model_at(&"lawn_sign", Vector3(2.02, DYKE_CROWN, 9.0), 3.35,
		{"colour": Color(0.72, 0.70, 0.64)})

	# The island: a bench facing the water, two camp chairs somebody carried out
	# and left, and a length of fence nobody finished.
	#
	# The bench is at -15.4 and not -19.2 because a raycast down the tower stair
	# found its top face at 1.5 m across the bottom two steps: a 1.8 m rigid body
	# with `rotation.y = randf_range(-PI, PI)` reaches 0.9 m in any direction,
	# and the stair foot is at z = -20.0. A bench at the bottom of a staircase is
	# not a hazard, but this zone's one climb should not open with a hurdle.
	_prop(Vector3(-8.6, ISLAND_Y + 0.43, -15.4), Vector3(1.80, 0.85, 0.62),
		Color(0.52, 0.46, 0.36), 22.0, 60, "BENCH")
	_prop(Vector3(7.9, ISLAND_Y + 0.46, -21.6), Vector3(0.60, 0.90, 0.60),
		Color(0.60, 0.58, 0.52), 5.0, 28, "PATIO CHAIR")
	_prop(Vector3(9.1, ISLAND_Y + 0.46, -23.4), Vector3(0.60, 0.90, 0.60),
		Color(0.56, 0.54, 0.50), 5.0, 28, "PATIO CHAIR")
	_prop(Vector3(-9.4, ISLAND_Y + 0.60, -30.2), Vector3(2.20, 1.20, 0.14),
		Color(0.50, 0.46, 0.40), 16.0, 45, "FENCE")
	_prop(Vector3(-6.9, ISLAND_Y + 0.60, -30.6), Vector3(2.20, 1.20, 0.14),
		Color(0.48, 0.45, 0.39), 16.0, 45, "FENCE")


# ══════════════════════════════════════════════════════════════ SUBSTANCES
#
# ALL SIXTEEN. Seventeen pickups — one of each, plus a second infinite patch of
# marsh grass, because a marsh is mostly plants and one lonely infinite source
# reads as a dispenser.
#
# CAMPAIGN_SPEC.md:489: "**All sixteen are present and the game says nothing
# about it.**" That sentence is the level. It is the deliberate inverse of leg 6
# (six substances, "deliberately thin") and leg 7 (four, at reduced dose size),
# and it only works if the placement is CASUAL. Nothing here is a set piece,
# nothing is behind a challenge, nothing is guarded, nothing is arranged in a
# row, and there is no cache. They are lying about the way things lie about in a
# car park at the end of a long weekend: on the road, on the chair, in the
# reeds, on the tower steps, at the foot of a nest box.
#
# The generosity IS the design. Everything the game has spent four legs teaching
# you to want is here, free, unguarded, at the exact moment the game most wants
# you to not want it — and it never once mentions that.
#
# THE ONE PLACEMENT RULE: nothing within four metres of the spawn. A pickup's
# trigger sphere is 1.6 m and the cottage's first render opened on a HOLD [E]
# prompt instead of a view of the lake.

func _sources() -> void:
	# ── down the road, north to south, as you walk in ────────────────────
	_source(Vector3(1.35, DYKE_CROWN + 0.36, 27.0), Subs.get_substance(&"special_k"), 0.42)
	_source(Vector3(-1.40, DYKE_CROWN + 0.36, 20.5), Subs.get_substance(&"robo"), 0.44)
	# Infinite, on the crown, in the weeds between the wheel tracks. At 16.5 and
	# not 14.0: the render put it inside a road resident and the goose came out
	# holding a sprig of grass, which is funny once and a clipping bug forever.
	_source(Vector3(0.0, DYKE_CROWN + 0.34, 16.5), Subs.get_substance(&"grass"), 0.42, true)
	_source(Vector3(1.20, DYKE_CROWN + 0.36, 10.8), Subs.get_substance(&"molly"), 0.40)
	_source(Vector3(-1.60, DYKE_CROWN + 0.38, 1.5), Subs.get_substance(&"gravy"), 0.46)
	_source(Vector3(-1.65, DYKE_CROWN + 0.40, -9.6), Subs.get_substance(&"bars"), 0.38)

	# ── in the reeds at the toe of the dyke, on both sides ───────────────
	# Below the road, so you have to go down the shoulder into the wet for them,
	# which is the only "effort" in the whole shelf and it is about six seconds.
	_source(Vector3(-4.20, 0.32, 5.0), Subs.get_substance(&"catnip"), 0.42)
	_source(Vector3(4.30, 0.32, 17.0), Subs.get_substance(&"berries"), 0.48)

	# ── the island ──────────────────────────────────────────────────────
	_source(Vector3(-3.10, ISLAND_Y + 0.36, -19.8), Subs.get_substance(&"grass"), 0.42, true)
	_source(Vector3(-4.60, ISLAND_Y + 0.58, -14.7), Subs.get_substance(&"math"), 0.40)
	_source(Vector3(3.55, ISLAND_Y + 0.36, -11.9), Subs.get_substance(&"percs"), 0.38)
	# Under the leaning snag on the island's west shoulder, in the damp.
	_source(Vector3(-9.20, ISLAND_Y + 0.34, -24.6), Subs.get_substance(&"fly_agaric"), 0.50)
	_source(Vector3(8.30, ISLAND_Y + 0.38, -27.8), Subs.get_substance(&"darts"), 0.36)

	# ── the birdwatcher's kit ───────────────────────────────────────────
	# In the chair's cup holder, which is what the library's `thermos` flag put
	# there, and in a cooler by the chair leg. Neither is remarked on by anybody.
	#
	# THE COOLER SITS BEHIND AND OUTBOARD OF THE CHAIR, and the render is why:
	# the first pass put it at +Z of the chair, which is the side the player
	# walks in from, and a 74 cm box in front of the one saturated object in the
	# level hides the only landmark that finds the birdwatcher for you.
	_source(CHAIR_AT + Vector3(0.30, 0.66, 0.06), Subs.get_substance(&"double_double"), 0.40)
	_static_box(CHAIR_AT + Vector3(0.92, 0.26, -0.62), Vector3(0.74, 0.50, 0.44),
		Color(0.44, 0.47, 0.50), 0.4)
	_decal_box(CHAIR_AT + Vector3(0.92, 0.52, -0.62), Vector3(0.78, 0.05, 0.48),
		Color(0.78, 0.79, 0.80), 0.4)
	_source(CHAIR_AT + Vector3(0.92, 0.76, -0.62), Subs.get_substance(&"nitrous"), 0.42)

	# ── out on the water, for the two people who go and look ────────────
	# On the weir's catwalk and at the foot of a nest box. Both are a swim.
	_source(WEIR_AT + Vector3(0.0, STOP.WEIR_DECK_Y + 0.40, 0.0),
		Subs.get_substance(&"toad_slime"), 0.44)
	_source(Vector3(16.0, 0.30, -2.9), Subs.get_substance(&"acid"), 0.40)


# ══════════════════════════════════════════════════════════ THE FORTY GEESE
#
# Forty-two, standing, paddling, preening, arguing and asleep, on the water, on
# the road, on the island, on a nest box, on the tower rail and on the weir.
#
# THEY DO NOT DO ANYTHING AND THEY DO NOT REACT TO YOU. That is the whole
# specification (CAMPAIGN_SPEC.md:520) and it is the load-bearing half of the
# intensity budget: a crowd that scatters is an activity, and this zone has no
# activities. They will answer a honk — quietly, some of them, once — because a
# marsh full of geese that are completely silent reads as a diorama rather than
# as a place.
#
# See the header for why `_resident()` and `_tick_resident()` are a fork of
# zone_finale.gd rather than a shared module, and what the honest fix is.

func _model_path() -> String:
	var key := "lowpoly"
	var prefs := get_node_or_null("/root/Prefs")
	if prefs != null:
		key = str(prefs.get_pref(&"goose_model", "lowpoly"))
	if not MODEL_SCRIPTS.has(key):
		key = "lowpoly"
	var path: String = MODEL_SCRIPTS[key]
	return path


## One resident. `pos` is where its FEET go — the root is lifted by
## STAND_HEIGHT, because both goose visuals put their origin at the hips and a
## bird dropped straight onto a surface stands in it up to the waterline.
func _resident(pos: Vector3, yaw: float, mode: StringName, extra := {}) -> Dictionary:
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
		"wander": randf_range(1.0, 5.0),
		"speed": 0.0,
		"cd": randf_range(2.0, 9.0),
		"met": false,
	}
	for k in extra:
		rec[k] = extra[k]
	_geese.append(rec)
	return rec


func _residents() -> void:
	# ── on the west pool ────────────────────────────────────────────────
	var west := [
		Vector2(-8.5, 16.0), Vector2(-12.0, 22.5), Vector2(-9.5, 30.0),
		Vector2(-16.0, 9.0), Vector2(-20.5, 17.0), Vector2(-11.0, -2.0),
		Vector2(-17.5, -3.5), Vector2(-24.0, 5.0), Vector2(-28.5, 14.0),
		Vector2(-15.0, -14.5), Vector2(-21.0, -21.0), Vector2(-30.0, -8.0),
		Vector2(-34.0, 2.0), Vector2(-26.0, 26.0), Vector2(-13.0, 38.0),
		Vector2(-33.0, -23.0),
	]
	for i in west.size():
		var p: Vector2 = west[i]
		_resident(Vector3(p.x, FLOAT_BASE, p.y), float(i) * 1.37, _water_mode(i))

	# ── on the east pool ────────────────────────────────────────────────
	var east := [
		Vector2(8.5, 14.0), Vector2(12.0, 6.0), Vector2(9.0, 24.0),
		Vector2(15.5, 20.0), Vector2(20.0, 10.0), Vector2(13.0, -4.5),
		Vector2(19.0, -12.0), Vector2(26.0, 2.0), Vector2(30.0, 16.0),
		Vector2(24.0, -22.0), Vector2(14.0, 32.0), Vector2(34.0, -6.0),
	]
	for i in east.size():
		var p: Vector2 = east[i]
		_resident(Vector3(p.x, FLOAT_BASE, p.y), float(i) * 2.11 + 0.6,
			_water_mode(i + 3))

	# ── on the road ─────────────────────────────────────────────────────
	# Standing in the way, which is the only obstacle in the level and it moves
	# when you walk into it because it does not have a collider.
	var road := [
		Vector2(-1.2, 0.0), Vector2(1.4, 5.4), Vector2(-0.8, 12.6),
		Vector2(1.0, 19.4), Vector2(-1.5, 25.2), Vector2(0.6, 33.0),
	]
	for i in road.size():
		var p: Vector2 = road[i]
		var m: StringName = &"graze"
		if i % 3 == 1:
			m = &"sleep"
		elif i % 3 == 2:
			m = &"preen"
		# The crown is DYKE_HALF_W = 2.20 half-width and the furthest-out bird
		# here is homed at |x| = 1.5, so 0.65 keeps every one of them on the
		# gravel with a 5 cm margin. See the spread note in _tick_resident().
		_resident(Vector3(p.x, DYKE_CROWN, p.y), float(i) * 1.9 + 0.4, m,
			{"spread": 0.65})

	# ── on the island, around the pen but not in it ─────────────────────
	_resident(Vector3(-9.0, ISLAND_Y, -12.6), 1.1, &"graze")
	_resident(Vector3(8.6, ISLAND_Y, -25.4), 2.7, &"preen")
	_resident(Vector3(-3.4, ISLAND_Y, -29.6), 0.3, &"sleep")
	# 1.0, not the 1.8 default: the island's south edge is at
	# ISLAND_CZ - ISLAND_HW = -32.0 and this bird is homed at z = -30.8, so the
	# default spread walked it 0.6 m off the bank and left it hovering 0.17 m
	# over the south ramp.
	_resident(Vector3(2.2, ISLAND_Y, -30.8), 2.0, &"graze", {"spread": 1.0})
	_resident(Vector3(9.6, ISLAND_Y, -29.2), 1.6, &"stand")

	# Two of them, having the same disagreement they were having when you got
	# here, about nothing, for the whole leg.
	var pivot := Vector3(5.4, ISLAND_Y, -23.6)
	_resident(pivot + Vector3(-0.95, 0, 0.2), PI * 0.5, &"argue", {"pivot": pivot})
	_resident(pivot + Vector3(0.95, 0, -0.2), -PI * 0.5, &"argue", {"pivot": pivot})

	# ── the three absurd ones ───────────────────────────────────────────
	# On a nest box roof (2.18), on the tower's rail cap (4.92) and on the weir
	# catwalk (1.45). Each is a height off the table at the top of this file, and
	# each is a bird that got somewhere a goose has no business being and then
	# stopped. Nobody remarks on any of them.
	_resident(Vector3(16.0, BED_Y + 2.48, -2.0), 1.25, &"perch")
	_resident(Vector3(TOWER_AT.x + 0.9, ISLAND_Y + STOP.TOWER_RAIL_Y,
		TOWER_AT.z - STOP.TOWER_DECK_HW), 0.35, &"perch")
	_resident(WEIR_AT + Vector3(0.55, STOP.WEIR_DECK_Y, 0.0), 2.6, &"stand")


## Which idle behaviour a bird floating on open water gets. Split out so the two
## pools share one distribution and neither ends up all asleep.
func _water_mode(i: int) -> StringName:
	match i % 5:
		0:
			return &"paddle"
		1:
			return &"preen"
		2:
			return &"sleep"
		3:
			return &"paddle"
		_:
			return &"stand"


# ══════════════════════════════════════════════════════════════ THE GOOSE

func _spawn_goose() -> void:
	goose = Goose.new()
	goose.name = "Goose"
	add_child(goose)
	# On the road, six metres north of the gate, facing SOUTH down the dyke.
	#
	# THE HEADING IS THE SHOT. `goose_camera.gd::_adopt_heading()` seeds the
	# rig's yaw from this on the first frame, so unlike the older zones this is
	# a real authored camera rather than an accident of the world axis. Zero
	# means -Z, and everything the level is about is stacked along -Z from here:
	# gate, sign, pen, birdwatcher, tower, with ninety metres of misted water
	# either side. See the OPENING SHOT block at the top of the file.
	#
	# Clear of every pickup trigger: the nearest source is `bars` at the gate,
	# 15.6 m away, and the nearest prop is a garbage bag at 9.4 m. The cottage's
	# first render spawned the bird inside a pickup radius and the opening frame
	# of that zone was a HOLD [E] prompt instead of a view of the lake.
	goose.global_position = Vector3(0.0, DYKE_CROWN + 0.90, 6.0)
	goose.heading = 0.0
	goose.rotation.y = 0.0

	camera_rig = preload("res://scripts/goose/goose_camera.gd").new()
	camera_rig.name = "CameraRig"
	camera_rig.target = goose
	add_child(camera_rig)
	goose.cam = camera_rig

	# The three honk reactions hang off the honk itself rather than off the key.
	# See _on_goose_honked() for why that distinction is worth a signal.
	if goose.honker != null and goose.honker.has_signal("honked"):
		goose.honker.honked.connect(_on_goose_honked)
	else:
		# LOUD, not silent. A `has_signal` guard that quietly does nothing is how
		# a feature stops existing without anybody finding out, and this zone's
		# signature primary hangs off this connection. `honker` is built in
		# goose_controller.gd::_build() during _ready(), which Godot runs
		# synchronously inside add_child() — so if this ever fires, the spawn
		# order in this function changed.
		printerr("[stopover] the goose has no honk signal — meet_the_locals, ",
			"the flock's answer and the birdwatcher's notes are all dead")

	# NO SHAKE WIRING HERE. Juice owns the shake bus and the goose controller
	# drives it; a zone that also connects landed/tumbled shakes the camera
	# twice for one landing and bypasses the screen_shake accessibility pref.


# ══════════════════════════════════════════════════════════════════ INPUT
#
# `_input` rather than `_unhandled_input`, and it NEVER marks the event handled:
# the goose's own honk must still fire. This only listens. Same contract
# zone_finale.gd:1202 states for the same key.

## LISTEN TO THE HONK, NOT TO THE KEY.
##
## This used to be an `_input()` handler on `gg_honk`, which is not the same
## event. `honk.gd::do_honk()` returns immediately while its 0.22 s cooldown is
## running, and the button is spammable by design — so a press inside the
## cooldown made no sound, threw no ring and shoved nothing, and this still paid
## +90, still threw a floating number over a resident and still popped it.
##
## Mashing H in the island cluster (six residents inside MEET_R) therefore filled
## a chunk of an eight-goose PRIMARY in about a second, with fewer than half of
## those presses producing an audible honk — a reward with no verb under it, in
## the zone whose whole proposition is quiet. The objective's own comment in
## mission_defs_stopover.gd argues it "cannot be farmed by standing in one place
## mashing the key", and it could.
##
## `honked` fires after the cooldown check, so one signal is one honk.
func _on_goose_honked(_pitch: float) -> void:
	if goose == null or not is_instance_valid(goose):
		return
	_meet_nearest()
	_honk_answer()
	_field_note()


## ONE resident per honk, the nearest unmet one in range.
##
## Deliberately one rather than all. Scoring every unmet goose inside 9 m off a
## single honk would tick `meet_the_locals` five times in one frame, fire five
## floating numbers at once in the quietest zone in the game, and turn an
## objective about walking round a marsh meeting your neighbours into an
## objective about standing in a crowd and holding a key. One per honk means
## eight honks at eight geese, which is what the text says.
func _meet_nearest() -> void:
	var here := goose.global_position
	var best := MEET_R
	var pick := -1
	for i in _geese.size():
		var rec: Dictionary = _geese[i]
		if bool(rec["met"]):
			continue
		var root: Node3D = rec["root"]
		if not is_instance_valid(root):
			continue
		var d := root.global_position.distance_to(here)
		if d < best:
			best = d
			pick = i
	if pick < 0:
		return
	var got: Dictionary = _geese[pick]
	got["met"] = true
	var groot: Node3D = got["root"]
	Game.score(90, MDEF.LBL_LOCAL, groot.global_position + Vector3(0, 0.85, 0))
	Juice.pop(got["visual"], 0.14, 0.16)


## The marsh answers, a bit.
##
## A DELIBERATELY SMALL VERSION of zone_finale.gd::_honk_wave(). The ending's
## wave is the one sincere moment in the game — every goose on the course, in a
## ragged sweep, over two and a half seconds — and spending it here twenty
## minutes early would make the 18th green a repeat rather than a payoff. So
## this one is: half the birds, only inside thirteen metres, over about a
## second, quieter, on a cooldown. Enough that a marsh full of geese is audibly
## a marsh full of geese; not enough to be an event.
func _honk_answer() -> void:
	if _answer_cd > 0.0:
		return
	_answer_cd = ANSWER_CD
	var here := goose.global_position
	var far := 1.0
	var picks: Array[int] = []
	for i in _geese.size():
		var rec: Dictionary = _geese[i]
		var root: Node3D = rec["root"]
		if not is_instance_valid(root):
			continue
		var d := root.global_position.distance_to(here)
		if d > ANSWER_R:
			continue
		# Half of them, deterministically, so the same birds do not all answer
		# every time and the same birds are never the only ones that do.
		if (i + _note_i) % 2 != 0:
			continue
		far = maxf(far, d)
		picks.append(i)

	for i in picks:
		var rec2: Dictionary = _geese[i]
		var root2: Node3D = rec2["root"]
		var d2 := root2.global_position.distance_to(here)
		var mode: StringName = rec2["mode"]
		var pitch := randf_range(0.90, 1.14)
		var delay := (d2 / far) * ANSWER_SPAN + randf_range(-0.10, 0.16)
		if mode == &"sleep":
			# The sleeping ones answer too, and they sound like it.
			pitch *= 0.74
			delay += 0.30
		_answer_q.append({
			"t": maxf(delay, 0.0),
			"node": root2,
			"db": -10.0 - clampf(d2 * 0.35, 0.0, 7.0),
			"pitch": pitch,
		})


## The gag. They write something down.
##
## No score, no objective, no progress of any kind — CAMPAIGN_SPEC.md:526 says
## it "costs one Label3D" and that is exactly what it is allowed to cost. The
## `birdwatcher` bonus is paid by the SCOPE finding you, not by this.
func _field_note() -> void:
	if _watcher == null or _note_lbl == null or _note_cd > 0.0:
		return
	if goose.global_position.distance_to(WATCHER_AT) > NOTE_R:
		return
	_note_cd = NOTE_CD
	var line: String = NOTES[_note_i % NOTES.size()]
	_note_i += 1
	_note_lbl.text = line
	_note_lbl.visible = true
	_note_t = NOTE_LIFE
	if _note_pad != null:
		Juice.pop(_note_pad, 0.30, 0.20)
	if _sfx != null:
		_sfx.play_at(&"score_blip", _note_pad, -18.0, 1.5)


# ══════════════════════════════════════════════════════════════════ TICK
#
# `_physics_process` for the one thing here that is gameplay — whether the
# player is standing next to one of their own geese — and `_process` for
# everything else, all of which is cosmetic: mist, a gate in the wind, a scope,
# forty idle birds and a Label3D.

func _physics_process(_delta: float) -> void:
	_tick_head_count()


## `mind_the_flock`, the only flock-condition primary in the game.
##
## The pen already computes exactly the right thing every frame: `focus_index`
## is the nearest flock bird inside DESIGNATE_RANGE (3.4 m), which is the same
## proximity that puts the [G] prompt over its head. So "stand with" means the
## bird's name tag is in front of you.
##
## THE PLAYER'S OWN RECORD IS EXCLUDED. `Flock.player_index` (0) is a live
## entry in `Flock.birds` and `flock_pen.gd::_build()` renders a ghost for it
## along with everybody else, so without this check the objective could be
## half-completed by standing next to yourself. That exclusion is why
## `mission_defs_stopover.gd` caps the target at TWO and not three: the Stopover
## top-up floor is three birds INCLUDING the player, so a battered flock has
## exactly two other geese in it and any higher target is unreachable. Change
## one of those two numbers and you must change the other.
## The pen named a driver. Pay the primary that asked for it.
##
## `no_scale` in the def, so the target stays 1 at every leg — this fires once
## per run and only here. Scored at the goose rather than at the bird because
## `dd_designated` hands over an index and a name, not a position, and the pen
## has already thrown "DESIGNATED DRIVER" over the bird itself; a second popup
## in the same place would be two labels fighting over one goose.
func _on_dd_designated(_index: int, _bird_name: String) -> void:
	if goose == null or not is_instance_valid(goose):
		return
	Game.score(240, MDEF.LBL_DRIVER, goose.global_position + Vector3(0, 1.1, 0))


func _tick_head_count() -> void:
	if _pen == null or not is_instance_valid(_pen):
		return
	var idx: int = int(_pen.focused_bird())
	if idx < 0 or idx == int(Flock.player_index):
		return
	if _counted.has(idx):
		return
	_counted[idx] = true
	var raw: Array = Flock.birds
	var at := goose.global_position + Vector3(0, 1.1, 0)
	Game.score(150, MDEF.LBL_HEAD_COUNT, at)
	if idx >= 0 and idx < raw.size():
		var rec: Dictionary = raw[idx]
		var nm := str(rec.get("name", ""))
		if nm != "":
			Juice.floating_text(at + Vector3(0, 0.45, 0), nm, Color(0.92, 0.90, 0.72))
	if _sfx != null:
		_sfx.play(&"score_blip", -6.0, 1.08)


func _process(delta: float) -> void:
	_t += delta
	_answer_cd = maxf(0.0, _answer_cd - delta)
	_note_cd = maxf(0.0, _note_cd - delta)

	_tick_gate(delta)
	_tick_scope(delta)
	_tick_mist(delta)
	_tick_answers(delta)
	_tick_note(delta)
	for g in _geese:
		var rec: Dictionary = g
		_tick_resident(rec, delta)


## The gate breathes. `swing_gate` smooths toward its target the
## framerate-independent way, so feeding it a slow sine gives a gate that is
## open, stays open, and moves — which is the difference between a level and a
## photograph of one, for the price of one lerp_angle a frame.
func _tick_gate(delta: float) -> void:
	var gm := _model_of(_gate)
	if gm == null:
		return
	STOP.swing_gate(gm, 0.94 + 0.06 * sin(_t * 0.55), delta, 1.4)


## THE SCOPE, and the smaller half of the birdwatcher gag.
##
## `aim_scope` does the two things that are easy to get wrong — the -Z-forward
## bearing and the framerate-independent smoothing — so this function only has
## to decide when "being tracked" turns into "having been observed".
##
## It is a HOLD, not a trigger. A scope that scores you the instant you enter
## its radius is a trigger volume with a lens on it; 1.4 continuous seconds is
## long enough that the player sees the barrel swing onto them first, which is
## the entire content of the bonus.
func _tick_scope(delta: float) -> void:
	var sm := _model_of(_scope)
	if sm == null or goose == null or not is_instance_valid(goose):
		return
	STOP.aim_scope(sm, goose.global_position + Vector3(0, 0.35, 0), delta, 3.2)

	if _scope_scored:
		return
	var d := goose.global_position.distance_to(SCOPE_AT)
	if d > SCOPE_SEE_R:
		_scope_t = 0.0
		return
	_scope_t += delta
	if _scope_t < SCOPE_HOLD:
		return
	_scope_scored = true
	Game.score(220, MDEF.LBL_SCOPE, WATCHER_AT + Vector3(0, 1.9, 0))
	if _sfx != null:
		_sfx.play_at(&"score_blip_hi", _watcher, -8.0, 1.22)


## Ten banks of mist drifting on independent headings, wrapping at the map edge.
##
## Wrapping rather than respawning, because a mist bank that pops out of
## existence at the boundary is the one thing in the level a player would
## actually notice. The edge is beyond the fog's half-opacity distance anyway,
## so the teleport happens where nothing can be seen.
func _tick_mist(delta: float) -> void:
	var lim := LOT * 0.5 + 6.0
	for i in _mist.size():
		var n: Node3D = _mist[i]
		if not is_instance_valid(n):
			continue
		var v: Vector3 = _mist_vel[i]
		var p := n.position + v * delta
		if p.x > lim:
			p.x = -lim
		elif p.x < -lim:
			p.x = lim
		if p.z > lim:
			p.z = -lim
		elif p.z < -lim:
			p.z = lim
		# AND IT STAYS OFF THE ROAD.
		#
		# The wrap above is the only thing that ever constrained a bank, and it
		# is 54 m out — so over a 150 s leg a bank drifting at 0.12–0.30 m/s
		# covers 18–45 m and simply walks onto the dyke. A bank is authored at
		# WATER_Y + 0.03 with a 0.90 m footprint, so on the crown (0.70) it
		# straddles the player's eye line: the view greys out behind a flat
		# translucent panel with a dead-straight edge across it, roughly once a
		# minute, on the one leg whose entire proposition is standing still and
		# looking at a marsh.
		#
		# Reflect rather than wrap here. The corridor is the road plus a margin
		# wider than a bank's own half-width, so a bank turns around before its
		# edge reaches the gravel instead of teleporting across the level — and
		# `_mist_vel` is the thing that changes, so it stays turned around.
		if absf(p.x) < MIST_KEEP_OUT:
			var away: float = signf(p.x) if not is_zero_approx(p.x) else 1.0
			p.x = away * MIST_KEEP_OUT
			var vel: Vector3 = _mist_vel[i]
			vel.x = absf(vel.x) * away
			_mist_vel[i] = vel
		# A slow breathing scale, out of phase per bank, so ten copies of one
		# mesh do not read as ten copies of one mesh. Multiplied INTO the
		# authored size rather than replacing it — see `_mist_scale`.
		var k0: float = _mist_scale[i]
		var k := k0 * (1.0 + 0.10 * sin(_t * 0.31 + float(i) * 1.7))
		n.position = p
		n.scale = Vector3(k, 1.0, k * 0.94)
		n.rotation.y += delta * 0.02 * (1.0 if i % 2 == 0 else -1.0)


func _tick_answers(delta: float) -> void:
	if _answer_q.is_empty():
		return
	var i := _answer_q.size() - 1
	while i >= 0:
		var e: Dictionary = _answer_q[i]
		var t: float = float(e["t"]) - delta
		if t <= 0.0:
			var node = e["node"]
			if is_instance_valid(node) and _sfx != null:
				var keys := [&"honk_a", &"honk_b", &"honk_c"]
				_sfx.play_at(keys[randi() % keys.size()], node,
					float(e["db"]), float(e["pitch"]))
			_answer_q.remove_at(i)
		else:
			e["t"] = t
		i -= 1


func _tick_note(delta: float) -> void:
	if _note_lbl == null or not _note_lbl.visible:
		return
	_note_t = maxf(0.0, _note_t - delta)
	if _note_t <= 0.0:
		_note_lbl.visible = false
		return
	# Fades in over the first fifth and out over the last third, so it does not
	# snap on and does not sit at full opacity waiting to disappear.
	var a := clampf(minf((NOTE_LIFE - _note_t) / 0.30, _note_t / 1.30), 0.0, 1.0)
	_note_lbl.modulate = Color(0.94, 0.92, 0.86, a)
	_note_lbl.outline_modulate = Color(0.10, 0.09, 0.10, a * 0.85)
	_note_lbl.position.y = WATCHER_AT.y + 2.20 + (NOTE_LIFE - _note_t) * 0.06


# ═══════════════════════════════════════════════════ ONE GOOSE, ONE BEHAVIOUR
#
# Seven behaviours, none of which achieves anything. Forked from
# zone_finale.gd::_tick_goose() with the same mode names, minus the modes the
# ending needs and this zone does not (arrive, walk, escort, riding, lap, roof,
# sleep_back) and plus one it does: `paddle`, a bird on open water.
#
# THE ONE NON-OBVIOUS RULE, and it is inherited: `_walk_toward()` never touches
# Y. It zeroes the vertical component of the move and leaves the root's height
# alone, which is what lets a floating goose wander on the water and a standing
# goose wander on the island using the same three lines. It also means a bird
# whose home is on a surface must never be given a wander spread that walks it
# off the edge of that surface — which is why every spread below is under two
# metres and every position is well inside its own ground.

func _tick_resident(bird: Dictionary, dt: float) -> void:
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
		&"graze":
			# SPREAD IS PER BIRD, because the surfaces are not the same size.
			#
			# The section header above states the rule: "a bird whose home is on
			# a surface must never be given a wander spread that walks it off the
			# edge of that surface". A single 1.8 m spread breaks it on the
			# narrowest ground in the zone — the dyke crown is DYKE_HALF_W = 2.20
			# half-width, so a grazer homed at x = -1.2 targets x = -3.0 and ends
			# up standing 0.27 m above the rip-rap, because `_wander()` moves in
			# XZ only and never re-probes Y. Same failure class as the
			# hallucination walkers in HANDOFF §4.
			#
			# The island grazers genuinely have room for 1.8 and keep it; the
			# road birds get a leash that fits the road.
			speed = _wander(bird, dt, float(bird.get("spread", 1.8)), 1.00)
			# The peck. Head all the way down for a second and a bit, on its own
			# clock, which is most of what makes a standing goose read as a
			# goose rather than as a statue of one.
			var cd: float = float(bird["cd"]) - dt
			if cd <= 0.0:
				cd = randf_range(2.6, 7.0)
			bird["cd"] = cd
			if cd < 1.3:
				neck_x = 0.95 * sin(clampf(cd, 0.0, 1.3) / 1.3 * PI)
		&"paddle":
			# Same wander, a third of the speed, and a low bow wave of a bob. A
			# goose on water moves like it is being pushed rather than walking.
			speed = _wander(bird, dt, 2.3, 0.34)
			body_y = sin(phase * 0.42) * 0.020
			neck_x = 0.05 + 0.05 * sin(phase * 0.37)
		&"preen":
			speed = _wander(bird, dt, 1.0, 0.6)
			neck_x = 0.55 + 0.45 * sin(phase * 1.9)
			body_roll = sin(phase * 0.8) * 0.16
		&"sleep":
			neck_x = 1.15
			body_y = -0.09 + sin(phase * 0.33) * 0.012
		&"stand":
			neck_x = 0.08 + 0.06 * sin(phase * 0.5)
			# A slow look around, so it is idle rather than frozen.
			root.rotation.y = float(bird["heading"]) + sin(phase * 0.21) * 0.5
		&"perch":
			# Absolutely motionless except for the head, because that is what a
			# bird standing somewhere ridiculous looks like. Honks about once
			# every ten seconds, at nothing.
			neck_x = -0.12 + 0.05 * sin(phase * 0.44)
			var pc: float = float(bird["cd"]) - dt
			if pc <= 0.0:
				pc = randf_range(8.0, 12.0)
				if _sfx != null:
					_sfx.play_at(&"honk_b", root, -16.0, randf_range(0.92, 1.06))
			bird["cd"] = pc
		&"argue":
			# Two geese and one disagreement about nothing. They lunge, they
			# retreat, they get nowhere. It never resolves.
			var piv: Vector3 = bird.get("pivot", bird["home"])
			var away := root.global_position - piv - Vector3(0, STAND_HEIGHT, 0)
			away.y = 0.0
			if away.length() < 0.01:
				away = Vector3.FORWARD
			var lunge := 0.60 + 0.38 * sin(phase * 2.4)
			root.global_position = piv + Vector3(0, STAND_HEIGHT, 0) \
				+ away.normalized() * lunge
			root.rotation.y = atan2(-away.x, -away.z) + PI
			neck_x = -0.35 + 0.25 * sin(phase * 2.4)
			speed = 1.2
			var ac: float = float(bird["cd"]) - dt
			if ac <= 0.0:
				ac = randf_range(3.5, 8.0)
				if _sfx != null:
					_sfx.play_at(&"goose_grumble", root, -17.0, randf_range(0.9, 1.2))
			bird["cd"] = ac

	bird["speed"] = lerpf(float(bird["speed"]), speed, 1.0 - pow(0.02, dt))
	visual.position.y = body_y
	visual.rotation.z = body_roll
	if visual.has_method("animate"):
		visual.animate(dt, 0.0, float(bird["speed"]), false)
	# AFTER animate(), never before: animate() writes the neck itself, so
	# setting it first just gets overwritten on the same frame. This cost the
	# flock pen twenty minutes and one render to find, and zone_finale.gd:1805
	# records not paying for it twice. It is not being paid for a third time.
	var neck = bird["neck"]
	if neck is Node3D:
		var nk: Node3D = neck
		nk.rotation.x = neck_x


## Pick a spot near home and walk to it. The whole of resident behaviour.
func _wander(bird: Dictionary, dt: float, spread: float, walk: float) -> float:
	var w: float = float(bird["wander"]) - dt
	if w <= 0.0:
		var home: Vector3 = bird["home"]
		bird["target"] = home + Vector3(randf_range(-spread, spread), 0.0,
			randf_range(-spread, spread))
		bird["wander"] = randf_range(2.6, 7.5)
	else:
		bird["wander"] = w
	var tgt: Vector3 = bird["target"]
	return _walk_toward(bird, dt, tgt, walk)


## Returns the speed actually walked, or 0.0 when it has arrived. NEVER touches
## Y — see the note at the head of this section.
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
	var head: float = lerp_angle(float(bird["heading"]), want, 1.0 - pow(0.004, dt))
	bird["heading"] = head
	root.rotation.y = head
	return walk


# ══════════════════════════════════════════════════════════════ ZONE API

## Which objective set the Mission autoload should load for this zone, which
## bed `Sfx` plays, and which stems `Music` uses. All three key off this one
## StringName; `music.gd` and `sfx.gd` already know &"stopover".
func mission_zone_id() -> StringName:
	return &"stopover"


## Title shown by the HUD at the top of the leg. `main.gd::_title_for()` gives
## the ROUTE entry's name priority over this, so it is the fallback rather than
## the source — but it has to agree with the route or a probe that loads this
## zone directly reads the wrong place name.
func zone_title() -> String:
	return "LEG %d — THE STOPOVER" % Flock.leg
