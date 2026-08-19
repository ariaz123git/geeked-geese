extends RefCounted
## THE STOPOVER MODEL LIBRARY — leg 5, a National Wildlife Refuge impoundment
## in upstate New York, at dawn.
##
## Same idiom and the same public API as scripts/world/prop_models.gd,
## prop_models_cottage.gd, prop_models_corn.gd, prop_models_truckstop.gd and
## prop_models_finale.gd:
##
##     PropModelsStopover.build(kind, parent, params) -> Node3D
##     PropModelsStopover.has_model(kind) -> bool
##     PropModelsStopover.footprint(kind, params) -> Vector3
##
## Polygons only. No SphereMesh, no CylinderMesh, no curved primitives. All
## colour lives in VERTEX COLOURS against one white material, so the whole
## marsh is one draw material and a per-face paint decision costs nothing.
##
## ===========================================================================
## WHAT THIS ZONE IS, AND WHY THAT DICTATES EVERY NUMBER BELOW
## ===========================================================================
## CAMPAIGN_SPEC §2.5: "A drowned marsh: open shallow water, cattails, dead
## standing timber, a gravel dyke road, a wooden observation tower, a
## birdwatcher with a scope and a folding chair." Time: "Dawn. Mist on the
## water, low pink light, the first warm palette since golden hour."
## Intensity 2 — the deep trough of the whole campaign, the one full mechanical
## heal in the back half, and a 150-second clock.
##
## Everything in here is therefore built to be LOOKED AT and STOOD ON, not
## knocked over. There is no vehicle, nothing that pursues, nothing that
## punishes. The only moving parts in the library are a spotting scope that
## tracks the goose and a gate that swings, and both of those are gags.
##
## ===========================================================================
## THE ANCHORING CONTRACT — identical to the other five libraries, repeated
## because it is the one thing that breaks a zone
## ===========================================================================
## Every model here is BASE-ANCHORED: local origin on the ground at the centre
## of the footprint, growing up +Y. BoxShape3D colliders are CENTRED. So a
## model hung under a collider of height h always drops by -h * 0.5. Miss it
## and the whole marsh hovers.
##
## Three kinds bend that contract on purpose and say so at their own header:
##   observation_tower  origin is the DECK centre; the stair runs out to +Z,
##                      so the model is not centred on its own bounding box.
##   dyke_section       extends from y = 0 (the marsh BED) up to the crown at
##                      DYKE_CROWN_Y; place it at bed level, not at the water.
##   water_control      origin is the footing on the bed, for the same reason.
## None of those three may be passed a `size` param — their heights are
## measured in flaps and rescaling them silently breaks the traversal.
##
## ===========================================================================
## THE DAWN PALETTE — chosen here, published as constants, do not re-derive
## ===========================================================================
## This is the first warm palette since leg 3's golden hour, and it has to be
## unmistakable at a glance from the two zones on either side of it:
##
##   leg 4, COTTAGE COUNTRY   night. Cold blue-grey granite, a 0.42 moon, three
##                            small warm point sources in a black field.
##   leg 5, THE STOPOVER      dawn. THIS ZONE.
##   leg 6, THE CUT CORN      hard midday. Saturated harvest gold and dust.
##
## The rule that separates it from both: **everything here is DESATURATED and
## warm-tinted, and there is exactly one saturated object in the zone** — the
## birdwatcher's folding chair, which is a too-blue nylon navy because that is
## what a camp chair actually is and because one saturated thing in a pale
## field is worth more than twenty.
##
## Concretely: greys carry a rose bias (red channel above green above blue by
## roughly 0.04 each), the browns are warm and light rather than the corn's
## saturated harvest brown, and NOTHING in the library is pure white — the
## brightest value in here is C_SIGN_WHITE at 0.90/0.88/0.83, because a true
## white face under a low pink sun renders as a hole.
##
## The lighting constants at the bottom of the palette block are NOT used by
## any model in this file. They are published so the zone and the library agree
## on what "dawn" means; the zone owns the WorldEnvironment.
##
## ===========================================================================
## THE SECOND MATERIAL — why this file has one, and why it is not a glow
## ===========================================================================
## The cottage and truckstop libraries carry an UNSHADED GLOW material because
## they are night zones full of things that emit. This one is not a night zone
## and nothing in a refuge emits at dawn. What it has instead is MIST, and mist
## is the one thing in this project that is neither opaque nor emissive: it
## needs ALPHA, and it needs to exist from both sides because a mist sheet is a
## single surface and the goose walks through it.
##
## So the second builder here is `w` — the HAZE shell: unshaded, alpha-blended,
## CULL_DISABLED, DEPTH_DRAW_OPAQUE_ONLY. It is copied deliberately from
## prop_models_finale.gd::spray_material() (the sprinkler fans), which is the
## only other place in the project culling is off, and for the same reason.
## Depth TEST stays on; depth WRITE does not, because four overlapping mist
## sheets that each wrote depth would punch holes in each other.
##
## Three models use it: the mist bank (all of it), the spotting scope's
## objective lens (a dawn glint), and the water control structure's spill.
##
## ===========================================================================
## WHAT THIS LIBRARY DELIBERATELY DOES NOT BUILD
## ===========================================================================
## * A CATTAIL. `prop_models.gd` already has `&"cattail"` (FOOTPRINTS at :79,
##   `_cattail()` at :1641) and zone_strip_mall.gd:322 already plants 26 of
##   them. Building a second one is exactly the failure CLAUDE.md names — the
##   toad that got built twice. What the marsh needs is not a different reed,
##   it is a way to plant SIX HUNDRED of them for the cost of one draw call, so
##   this file supplies `cattail_mesh()` / `cattail_bed()` / `bed_spots_band()`
##   / `bed_spots_ring()` instead, and the geometry they instance is literally
##   prop_models.gd's. See the CATTAIL BEDS section.
## * A BOARDWALK. `prop_models_cottage.gd` has `&"dock_section"` (:757),
##   tileable end to end along Z with its deck top at y = 1.905. A marsh
##   boardwalk is that at a lower deck height; the zone can place it directly
##   or pass a `size` with a squashed Y.
## * A HUMAN. The birdwatcher is npc_human.gd + human_visual_lowpoly.gd. This
##   library builds their KIT — the scope, the tripod and the chair — and
##   nothing else.
## * IDLE NPC GEESE. See the note at the head of the OBSERVATION TOWER section
##   and the handoff: the ~40 residents are welded into zone_finale.gd and have
##   to be lifted out of it, which is not a model-library job.
## * A HERON, an egret, a muskrat. All tempting, none in the spec, and the
##   zone's animal budget is spent on forty geese who do nothing.
##
## ===========================================================================
## DETERMINISM
## ===========================================================================
## No randf()/randi() anywhere, including in the bed-scatter helpers, which are
## the one place in this file where a random number would look right. The build
## verification renders and diffs frames, so a random number in here is a bug
## and a non-reproducible one. Every irregularity — the ragged snag break, the
## slumped rip-rap, the scattered reeds — is a sin() of the element indices:
## organic-looking and bit-identical every run. Zones may use randf for
## placement; libraries may not.

## Preloaded rather than referenced by class_name: global class registration
## only exists after an editor import pass, so a `class_name` reference breaks
## in a fresh checkout or a headless CI run. A preload const always resolves.
const LPB := preload("res://scripts/goose/lowpoly_builder.gd")

## The ONE legal cross-library dependency in this file, and it exists for a
## single call: `PROPS.build(&"cattail", ...)`. The stated policy
## (prop_models_truckstop.gd:380) is that libraries re-declare private helpers
## rather than reach across — and every helper below is re-declared, forty
## duplicated lines and all. But `build()` is the public surface, and reaching
## for it is the whole point: the marsh's reeds must be the SAME OBJECT the
## strip-mall pond uses, or the game has two cattails.
const PROPS := preload("res://scripts/world/prop_models.gd")


# ===========================================================================
# THE DAWN PALETTE
# ===========================================================================

## Weathered pressure-treated timber: the tower, the dyke posts, the sign
## posts, the nest box. Warm grey, never brown — this wood has been in a marsh
## for fifteen years.
const C_TIMBER := Color(0.58, 0.53, 0.47)
## The same timber below the waterline: darker, greener, permanently soaked.
const C_TIMBER_WET := Color(0.34, 0.33, 0.29)

## Dead standing timber. Bark long gone, silvered, but warm-silvered — a cold
## grey snag reads as leg 4's granite and the whole trick fails.
const C_SNAG := Color(0.64, 0.60, 0.55)
## The wet collar at the base of every drowned trunk, and its root flare. Not
## as dark as it wants to be: the first pass used 0.31 and every snag in a
## stand grew a black spike at the waterline, which is a silhouette the eye
## reads before it reads the tree.
const C_SNAG_WET := Color(0.38, 0.35, 0.31)

## Cattail foliage at dawn in autumn: olive that has gone pale and dry. Passed
## through to prop_models.gd's `_cattail` as its "colour".
const C_REED := Color(0.53, 0.53, 0.34)
## The seed head. The warmest brown in the zone and the only one repeated
## six hundred times, which is what makes the marsh read warm from the air.
const C_REED_HEAD := Color(0.44, 0.27, 0.16)

## The dyke road. Crushed limestone, pale, dusty, one value off the water.
const C_GRAVEL := Color(0.63, 0.59, 0.53)
## Rip-rap along the toe of the dyke — bigger stone, damper, darker.
const C_RIPRAP := Color(0.46, 0.44, 0.42)
## The bank itself: wet soil and dead thatch on the slope.
const C_BANK := Color(0.42, 0.39, 0.31)

## Poured concrete, thirty years old, algae-stained at the waterline.
const C_CONCRETE := Color(0.67, 0.65, 0.60)
## Painted steel: bollard shafts, gate frames, catwalk grating.
const C_STEEL := Color(0.40, 0.41, 0.42)
## Hot-dip galvanised: the handwheel, the predator guard, the tripod.
const C_GALV := Color(0.60, 0.62, 0.63)

## US Fish & Wildlife brown. This is THE colour of the zone's signage and the
## only place a strong value is allowed.
const C_REFUGE_BROWN := Color(0.28, 0.19, 0.12)
## Sign white. Deliberately NOT (1,1,1): under a low pink sun a true white face
## renders as a hole with no form in it.
const C_SIGN_WHITE := Color(0.90, 0.88, 0.83)

## THE ONE SATURATED OBJECT IN THE ZONE. A birdwatcher's folding chair is navy
## nylon and it should look faintly absurd against six hundred metres of pale
## grey marsh. That contrast is doing real work: it is how the player finds the
## birdwatcher, and the birdwatcher is standing next to the flock pen.
const C_CHAIR := Color(0.15, 0.22, 0.38)
## Its anodised aluminium frame.
const C_ALU := Color(0.66, 0.67, 0.69)

## The scope body: matte olive-black optics housing.
const C_SCOPE := Color(0.17, 0.18, 0.16)
## The objective lens, catching the sunrise. The brightest opaque face here.
const C_LENS := Color(0.82, 0.78, 0.86)

## Mist. Rose-white, and always used at low alpha on the haze material.
const C_MIST := Color(0.93, 0.86, 0.85, 0.13)
## Falling water at the weir, on the same haze material.
const C_SPILL := Color(0.86, 0.87, 0.90, 0.42)


# ── LIGHTING REFERENCE ──────────────────────────────────────────────────────
#
# NOT used by anything in this file. Published so the zone's WorldEnvironment
# and this library's vertex colours are describing the same morning. The zone
# owns the light; these are the values the palette above was picked against.

const DAWN_SUN := Color(1.00, 0.74, 0.62)        ## key light, low sun in mist
const DAWN_SUN_ENERGY := 0.85
const DAWN_SUN_ELEVATION := 4.0                  ## degrees above the horizon
const DAWN_AMBIENT := Color(0.60, 0.58, 0.70)    ## cool fill against the warm key
const DAWN_FOG := Color(0.87, 0.78, 0.75)
const DAWN_HORIZON := Color(0.98, 0.76, 0.68)
const DAWN_ZENITH := Color(0.44, 0.51, 0.68)


# ===========================================================================
# MEASURED HEIGHTS
# ===========================================================================
#
# ONE FLAP IS 1.86 m. That is `flap_impulse^2 / (2 * glide_gravity)` =
# 6.4^2 / 22, the rise a goose gets from a standstill, and it is the number
# every climbable height in this project is set against (zone_cottage.gd:65,
# zone_truckstop.gd:73, zone_corn.gd:118). A bird arriving at the Stopover has
# just been healed to stamina 0.90 — but the goose the PLAYER is driving has
# not, and the rest beat is worthless if the one piece of high ground in the
# zone is a place you cannot get to.
#
# So every step up in this library is comfortably inside one flap, with the
# margin the cottage zone learned to leave (it first put a ledge at 2.10 and
# the jitter pushed the worst case to 1.77 — "technically possible, and exactly
# the kind of margin that turns into 'I'm stuck at the bottom'").

const ONE_FLAP := 1.86

## OBSERVATION TOWER — the zone's only high ground, and a four-rung climb where
## every rung is a comfortable flap:
##
##     ground        0.00
##     stair landing 1.60   (0.86 flaps from the ground)
##     deck          3.20   (1.60 above the landing — 0.86 flaps)
##     rail cap      4.30   (1.10 above the deck — 0.59 flaps)
##     roof ridge    5.55   (1.25 above the rail — 0.67 flaps)
##
## The deck is 1.72 flaps off the ground, which is DELIBERATELY not one flap:
## the tower should cost something. It is two easy hops via the landing, or a
## walk up the stair, and the stair exists so a bird with nothing left can
## still get up there. From the ridge at 5.55 m you are looking down on the
## whole impoundment, which is the entire reason the tower is in the spec.
const TOWER_LANDING_Y := 1.60
const TOWER_DECK_Y := 3.20
const TOWER_RAIL_Y := 4.30
const TOWER_ROOF_Y := 5.55
## Where the bottom step meets the ground, measured from the deck centre.
const TOWER_STAIR_Z := 7.00
## Half-width of the deck. The deck is TOWER_DECK_HW * 2 square.
const TOWER_DECK_HW := 1.80

## WATER CONTROL STRUCTURE — the standable catwalk over the weir, out in the
## open water. 1.75 m above the structure's footing, which with the marsh bed
## at -0.30 puts it 1.45 m above the waterline: 0.78 of a flap from a swimming
## goose, and the only thing to stand on away from the dyke.
const WEIR_DECK_Y := 1.75

## DYKE SECTION — the crown of the gravel road above the section's base. The
## section is anchored at the MARSH BED, so with a bed at -0.30 the road
## surface lands at +0.70: dry, walkable, and half a flap above the water.
const DYKE_CROWN_Y := 1.00
## Tile length along Z. Sections butt end to end with no gap.
const DYKE_SPAN := 8.00

## The spotting scope's pan-head pivot, in the model's local space. This is
## where the "Head" node sits — see scope_head() / aim_scope().
const SCOPE_PIVOT := Vector3(0.0, 1.19, 0.0)
## The gate leaf's hinge, in the model's local space, and how far it swings.
const GATE_PIVOT := Vector3(-1.66, 0.28, 0.0)
const GATE_OPEN_ANGLE := -1.40


# ---------------------------------------------------------------------------
# Registry
# ---------------------------------------------------------------------------

## Bounding footprint of each model, base-anchored: (width_x, height_y, depth_z).
##
## Read the three exceptions at the top of the file before using these to place
## anything: the tower is anchored on its deck rather than its bounding box,
## and the dyke and the weir are anchored on the marsh bed.
## Every number in here was READ OFF A RENDER, not guessed: each model was
## built headless and its merged MeshInstance3D AABB printed. Four of the
## twelve were wrong on the first pass by 8-15%, which is exactly enough for a
## `size` rescale to look almost right.
const FOOTPRINTS := {
	&"snag": Vector3(3.60, 9.40, 3.60),   ## overridden by footprint(), per form
	&"observation_tower": Vector3(4.32, 5.63, 9.20),
	&"spotting_scope": Vector3(0.86, 1.42, 0.86),
	&"folding_chair": Vector3(0.78, 0.94, 0.72),
	## Z is 8.10, not DYKE_SPAN's 8.00: the rip-rap straddles the tile join by
	## 5 cm either side on purpose, so a run of sections has no visible seam.
	&"dyke_section": Vector3(8.90, 1.19, 8.10),
	&"interp_sign": Vector3(1.18, 1.30, 0.54),
	&"bollard": Vector3(0.19, 0.98, 0.20),
	&"gate": Vector3(3.85, 1.52, 0.36),
	&"water_control": Vector3(4.20, 2.75, 2.25),
	&"refuge_sign": Vector3(2.48, 1.96, 0.20),
	&"nest_box": Vector3(0.68, 2.52, 0.68),
	&"mist_bank": Vector3(11.00, 0.90, 11.00),
}


## True if [param kind] has a dedicated model here. Unknown kinds still build —
## they get a faceted crate, so nothing in the world is ever invisible — but a
## caller that wants to fall back to another library should test this first.
static func has_model(kind: StringName) -> bool:
	return FOOTPRINTS.has(kind)


## Base-anchored bounding size of [param kind]. `snag` computes its own from
## the silhouette it was asked for, exactly like prop_models.gd's house does.
static func footprint(kind: StringName, params := {}) -> Vector3:
	if kind == &"snag":
		var row: Array = SNAG_FORMS[_form_index(params)]
		var h: float = row[0]
		var r: float = row[1]
		var limbs: Array = row[4]
		var reach := 0.0
		for i in range(limbs.size()):
			var lm: Array = limbs[i]
			var lr: float = lm[2]
			reach = maxf(reach, lr)
		# The overshoot past the trunk scales with the BASE RADIUS, not with the
		# height: the splinters above the break are r * (1.1 .. 2.0) long. A
		# flat "h * 1.08" was right for the 9 m spar and 13% short for the 3.6 m
		# stump, which is the short fat one — exactly the case a proportional
		# guess gets wrong. Measured against the built AABB of all four forms.
		var span := maxf(r * 4.0, reach * 1.5 + r * 2.0)
		return Vector3(span, h + r * 2.6, span)
	if FOOTPRINTS.has(kind):
		var f: Vector3 = FOOTPRINTS[kind]
		return f
	return Vector3.ONE


# ---------------------------------------------------------------------------
# Materials
# ---------------------------------------------------------------------------

## One white, vertex-colour-driven material for every opaque surface in the
## refuge. Shared with nothing — the other five libraries keep their own — but
## identical in construction, so all six look like one world.
##
## Roughness 0.84, a shade glossier than the cottage's 0.88 and well short of
## the truckstop's 0.62. Everything here is either wet, weathered or both, and
## a low sun raking across a marsh puts a long specular sheen on wet timber
## that a fully matte surface throws away.
static var _shared_mat: StandardMaterial3D = null

static func shared_material() -> StandardMaterial3D:
	if _shared_mat == null:
		_shared_mat = LPB.make_material(0.84)
		_shared_mat.cull_mode = BaseMaterial3D.CULL_BACK
	return _shared_mat


## Mist, and the water falling over the weir.
##
## Copied deliberately from prop_models_finale.gd::spray_material(). Unshaded,
## so a mist sheet reads at dawn without needing a light aimed at it; alpha, so
## it is mist rather than a plastic sheet; and CULL_DISABLED because a mist
## bank is a single surface and the goose walks THROUGH it — a one-sided sheet
## vanishes the instant you cross it, which is the single most obvious possible
## bug in a zone whose signature image is fog on water.
##
## No depth WRITE, but depth TEST stays on: four overlapping sheets that each
## wrote depth would punch holes in each other, and a sheet that ignored depth
## entirely would draw straight through the observation tower.
static var _haze_mat: StandardMaterial3D = null

static func haze_material() -> StandardMaterial3D:
	if _haze_mat == null:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color.WHITE
		m.vertex_color_use_as_albedo = true
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
		_haze_mat = m
	return _haze_mat


# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

## Builds the model for [param kind] as a new "Model" Node3D under
## [param parent] and returns it.
##
## `params` keys, all optional:
##   size          Vector3  scale the model so its footprint matches this.
##                          NOT legal on observation_tower / dyke_section /
##                          water_control / spotting_scope — see the header.
##   colour        Color    the model's main colour
##   trim_colour   Color    secondary (rails, frames, roof, fabric)
##   variant       float    deterministic shape seed
##   form          int      snag silhouette, 0-3 (see SNAG_FORMS)
##   thermos       bool     folding_chair: is there a thermos in the holder
##   open          bool     water_control: is the top stoplog pulled
##
## Two kinds get a real moving child node rather than baked-in geometry:
##   spotting_scope  ->  "Head"  (see scope_head / aim_scope)
##   gate            ->  "Leaf"  (see gate_leaf / swing_gate)
static func build(kind: StringName, parent: Node3D, params := {}) -> Node3D:
	var model := Node3D.new()
	model.name = "Model"
	parent.add_child(model)

	var b: RefCounted = LPB.new()
	var w: RefCounted = LPB.new()   ## the haze builder — alpha, unshaded
	match kind:
		&"snag":
			_snag(b, params)
		&"observation_tower":
			_observation_tower(b, params)
		&"spotting_scope":
			_spotting_scope(b, params)
		&"folding_chair":
			_folding_chair(b, params)
		&"dyke_section":
			_dyke_section(b, params)
		&"interp_sign":
			_interp_sign(b, params)
		&"bollard":
			_bollard(b, params)
		&"gate":
			_gate(b, params)
		&"water_control":
			_water_control(b, w, params)
		&"refuge_sign":
			_refuge_sign(b, params)
		&"nest_box":
			_nest_box(b, params)
		&"mist_bank":
			_mist_bank(w, params)
		_:
			_fallback(b, params)

	model.set_meta("tri_count", b.tri_count + w.tri_count)
	# THE MODEL CARRIES ITS OWN DECLARATION, so `tools/geomtest.gd` can compare
	# the box this builder PROMISED against the mesh it actually emitted without
	# knowing which of the seven FOOTPRINTS tables the kind came from. `build()`
	# sizes with `want / footprint(kind)`, so a declaration that disagrees with
	# the mesh makes every `size:` placement of that kind wrong by exactly that
	# ratio, in every zone that asks for one — and nothing could see it.
	model.set_meta("kind", kind)
	model.set_meta("declared", footprint(kind, params))
	if b.tri_count > 0:
		LPB.attach(model, b.commit(), shared_material(), "Shell")
	# Only when there is something to see through: an empty SurfaceTool commits
	# to null, and a MeshInstance3D with a null mesh is a silent per-frame cost
	# for nothing.
	if w.tri_count > 0:
		LPB.attach(model, w.commit(), haze_material(), "Haze")

	# The two models with a moving part get it as a separate child node, built
	# by its own pair of builders, so the zone can rotate it without touching
	# the rest of the model.
	if kind == &"spotting_scope":
		_build_scope_head(model, params)
	elif kind == &"gate":
		_build_gate_leaf(model, params)

	if params.has("size"):
		var want: Vector3 = params["size"]
		var have := footprint(kind, params)
		model.scale = Vector3(
			want.x / maxf(have.x, 0.001),
			want.y / maxf(have.y, 0.001),
			want.z / maxf(have.z, 0.001))
	return model


# ---------------------------------------------------------------------------
# Typed parameter access.
#
# Dictionary lookups are Variant, so `var x := params.get(...)` is a parse
# error ("Cannot infer the type of x"). Funnelling every read through these
# three helpers keeps that mistake out of the twelve build functions below.
# ---------------------------------------------------------------------------

static func _col(params: Dictionary, key: String, fallback: Color) -> Color:
	var v = params.get(key, fallback)
	if v is Color:
		return v
	return fallback


static func _num(params: Dictionary, key: String, fallback: float) -> float:
	var v = params.get(key, fallback)
	if v is float or v is int:
		return float(v)
	return fallback


static func _flag(params: Dictionary, key: String, fallback: bool) -> bool:
	var v = params.get(key, fallback)
	if v is bool:
		return v
	return fallback


# ---------------------------------------------------------------------------
# Cross-section and winding helpers.
#
# Deliberately re-implemented here rather than reached for across a preload
# into the other libraries: those are underscore-private statics on files this
# one has no other reason to depend on, and duplicating forty lines is cheaper
# than a coupling nobody expects. Same call all four previous libraries made.
# ---------------------------------------------------------------------------

## Horizontal cross-section at height [param y]: a chamfered rectangle in XZ.
## One 3 cm chamfer per corner is the difference between "a box" and "an
## object" at every distance the camera ever sits at.
static func _ring_y(y: float, hx: float, hz: float, cham: float) -> PackedVector3Array:
	var c := minf(cham, minf(hx, hz) * 0.49)
	if c <= 0.002:
		return PackedVector3Array([
			Vector3(-hx, y, -hz), Vector3(hx, y, -hz),
			Vector3(hx, y, hz), Vector3(-hx, y, hz)])
	return PackedVector3Array([
		Vector3(-hx + c, y, -hz), Vector3(hx - c, y, -hz),
		Vector3(hx, y, -hz + c), Vector3(hx, y, hz - c),
		Vector3(hx - c, y, hz), Vector3(-hx + c, y, hz),
		Vector3(-hx, y, hz - c), Vector3(-hx, y, -hz + c)])


## Centroid of a ring, used as the `inside` reference for capping.
static func _centroid(r: PackedVector3Array) -> Vector3:
	var c := Vector3.ZERO
	for v in r:
		c += v
	return c / float(maxi(r.size(), 1))


## A point far enough behind [param r] along -axis_dir that every face of the
## ring agrees on which way is out.
##
## LowPolyBuilder picks a face's winding from dot(normal, centroid - inside).
## On a near-horizontal fan the normal is almost vertical while
## (centroid - inside) is dominated by the RADIUS, so a reference one metre
## under a one-metre disc leaves the sign of that dot product up to which side
## of the ring the face happens to sit on — and the disc renders along exactly
## half a diameter, invisibly wrong from the far side. Put the reference two
## hundred radii away and the axial term wins on every face. Documented at
## length in three other libraries because it cost each of them two render
## rounds; it is here so it costs this one none.
static func _far_ref(r: PackedVector3Array, axis_dir: Vector3) -> Vector3:
	var c := _centroid(r)
	var far := 0.0
	for v in r:
		far = maxf(far, (v - c).length())
	return c - axis_dir.normalized() * (far * 200.0 + 10.0)


## Cap a ring that lies perpendicular to [param axis_dir].
static func _cap_axial(b: RefCounted, r: PackedVector3Array, apex: Vector3,
		axis_dir: Vector3, col: Color) -> void:
	b.cap(r, apex, _far_ref(r, axis_dir), col)


## Loft a chain of rings with the faces pointing INWARD, toward the axis. A
## hollow thing that is looked into — a cup holder, a predator guard, a tin
## shade — has a far wall that with backface culling on simply is not there.
static func _loft_inward(b: RefCounted, rings: Array, axis: Array, col: Color) -> void:
	for i in range(rings.size() - 1):
		var r0: PackedVector3Array = rings[i]
		var r1: PackedVector3Array = rings[i + 1]
		var n: int = mini(r0.size(), r1.size())
		var a0: Vector3 = axis[i]
		var a1: Vector3 = axis[i + 1]
		var mid: Vector3 = (a0 + a1) * 0.5
		for j in n:
			var k := (j + 1) % n
			var p0: Vector3 = r0[j]
			var p1: Vector3 = r0[k]
			var p2: Vector3 = r1[k]
			var p3: Vector3 = r1[j]
			var cen: Vector3 = (p0 + p1 + p2 + p3) * 0.25
			b.quad(p0, p1, p2, p3, col, cen + (cen - mid))


## A square-section strut between two arbitrary points. Boxes can only be axis
## aligned or basis-rotated about one axis; anything that runs diagonally in
## two directions at once — a tripod leg, a tower brace, a snag limb — needs a
## real lofted tube.
static func _strut(b: RefCounted, a: Vector3, c: Vector3, r: float, col: Color) -> void:
	var d := c - a
	if d.length_squared() < 1e-8:
		return
	var dir := d.normalized()
	var up := Vector3.UP if absf(dir.y) < 0.92 else Vector3.FORWARD
	var r0 := LPB.ring(a, dir, up, r, r, 4, PI * 0.25)
	var r1 := LPB.ring(c, dir, up, r, r, 4, PI * 0.25)
	b.loft([r0, r1], [a, c], col)


## An n-sided tapered tube between two points, capped at neither end. Posts,
## scope barrels, snag trunks, handrails.
static func _cyl(b: RefCounted, a: Vector3, c: Vector3, r0: float, r1: float,
		sides: int, col: Color, phase := 0.0) -> void:
	var d := c - a
	if d.length_squared() < 1e-8:
		return
	var dir := d.normalized()
	var up := Vector3.UP if absf(dir.y) < 0.92 else Vector3.FORWARD
	var ra := LPB.ring(a, dir, up, r0, r0, sides, phase)
	var rb := LPB.ring(c, dir, up, r1, r1, sides, phase)
	b.loft([ra, rb], [a, c], col)


## Deterministic pseudo-noise in roughly [-1, 1]. Stands in for randf() so the
## ragged things stay bit-identical between runs.
static func _wobble(a: int, c: int, seed_v: float) -> float:
	return sin(float(a) * 2.399 + float(c) * 1.117 + seed_v * 3.77) \
		* cos(float(a) * 0.813 - float(c) * 1.937 + seed_v * 1.31)


## A horizontal ring with every vertex kicked off the circle. This is what
## stops a lofted trunk from reading as a lathe-turned dowel; a dead tree is
## the one thing in the zone with no straight lines anywhere on it.
##
## [param y_amp] scales the VERTICAL kick relative to the radial one, and it is
## a separate knob because the radius here ranges from 0.4 m (a snag ring) to
## 5.3 m (a mist sheet). At the default 0.5 a mist bank got 1.3 m of vertical
## relief and dipped half a metre under its own origin — pass something near
## 0.05 for anything wide and flat.
static func _rough_ring(centre: Vector3, r: float, sides: int, phase: float,
		seed_v: float, band: int, amp: float, y_amp := 0.5) -> PackedVector3Array:
	var base := LPB.ring(centre, Vector3.UP, Vector3.FORWARD, r, r, sides, phase)
	var out := PackedVector3Array()
	for j in base.size():
		var p: Vector3 = base[j]
		var d := p - centre
		var k := 1.0 + amp * _wobble(band, j, seed_v)
		out.append(centre + Vector3(d.x * k,
			d.y + r * amp * y_amp * _wobble(band + 5, j, seed_v), d.z * k))
	return out


## A pyramid cap on a square post — the chamfer that stops a bollard, a gate
## post or a sign post from ending in a flat slab that catches the low sun and
## turns into a row of white dots across the dyke.
static func _post_cap(b: RefCounted, centre: Vector3, hx: float, hz: float,
		rise: float, col: Color) -> void:
	var r := _ring_y(centre.y, hx, hz, minf(hx, hz) * 0.28)
	var moved := PackedVector3Array()
	for v in r:
		moved.append(v + Vector3(centre.x, 0.0, centre.z))
	_cap_axial(b, moved, centre + Vector3(0, rise, 0), Vector3.UP, col.lightened(0.06))


# ===========================================================================
# CATTAIL BEDS — reuse, not a second cattail
# ===========================================================================
#
# prop_models.gd already has the reed. What it does not have is a way to put
# six hundred of them in a marsh, because the shared library never grew a
# `mesh_for()` the way prop_models_corn.gd did for its 1,770 corn stalks. So
# this section is the missing half of that: it lifts the cattail's ArrayMesh
# out of a throwaway build and hands it to a MultiMesh.
#
# Cost: one cattail is roughly 68 triangles, so a six-hundred-stalk marsh is
# ~41k triangles in ONE draw call, sharing prop_models.gd's material with every
# other shared prop in the zone. Placing them as six hundred MeshInstance3Ds
# instead would be six hundred draw calls for the same picture, which is the
# mistake zone_corn.gd:660 documents having already avoided once.
#
# The two spot generators are deterministic on purpose even though a ZONE is
# allowed to use randf: a marsh whose reed line moves every run cannot be
# render-diffed, and the whole verification story for this zone is a render.

## The shared library's cattail, as a raw ArrayMesh, for MultiMesh use.
##
## Returns null if the build failed — check it, the way zone_corn.gd:623 does.
## `params` is passed straight through, so {"colour": C_REED} tints the stems.
##
## Deliberately NOT cached in a static var: the marsh wants at least two tints
## (the dry stand along the dyke and the wetter, greener stand in the pool) and
## a one-slot cache would silently hand the second bed the first bed's colour.
## Two extra SurfaceTool runs at zone build time cost nothing.
static func cattail_mesh(params := {}) -> ArrayMesh:
	var host := Node3D.new()
	var model: Node3D = PROPS.build(&"cattail", host, params)
	var mesh: ArrayMesh = null
	if model != null:
		var shell := model.get_node_or_null("Shell")
		if shell is MeshInstance3D:
			var mi: MeshInstance3D = shell
			mesh = mi.mesh as ArrayMesh
	# `mesh` is a Resource and now has a reference, so it outlives the node it
	# was built into. Freeing the host here is what keeps a zone build from
	# leaking one orphan Node3D per bed.
	host.free()
	return mesh


## Plant a whole bed of cattails under [param parent] as ONE MultiMeshInstance3D
## and return it.
##
## [param spots] is an Array of Vector3 base positions in [param parent]'s local
## space — use bed_spots_band() / bed_spots_ring() below, or hand it your own.
## The parameter is a plain `Array` rather than `Array[Vector3]` so an untyped
## array from a zone is accepted; every read out of it is annotated.
##
## `params`, all optional:
##   colour      Color   stem/leaf tint, passed to prop_models.gd's _cattail
##   scale_min   float   default 0.78
##   scale_max   float   default 1.30
##   variant     float   deterministic scatter seed — change it per bed
##   name        String  node name, default "CattailBed"
static func cattail_bed(parent: Node3D, spots: Array, params := {}) -> MultiMeshInstance3D:
	if parent == null or spots.is_empty():
		return null
	var mesh := cattail_mesh(params)
	if mesh == null:
		push_warning("prop_models_stopover: cattail mesh failed to build")
		return null

	var lo := _num(params, "scale_min", 0.78)
	var hi := _num(params, "scale_max", 1.30)
	var seed_v := _num(params, "variant", 0.0)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = spots.size()

	var mn := Vector3(INF, INF, INF)
	var mx := Vector3(-INF, -INF, -INF)
	for i in spots.size():
		var p: Vector3 = spots[i]
		var k := lerpf(lo, hi, absf(_wobble(i, 11, seed_v)))
		var yaw := _wobble(i, 5, seed_v) * PI
		# A reed bed leans. Half a radian would be storm damage; 0.11 is wind.
		var tilt := _wobble(i, 7, seed_v) * 0.11
		var bas := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, tilt)
		mm.set_instance_transform(i, Transform3D(bas.scaled(Vector3(k, k, k)), p))
		# The shared cattail's footprint is (0.30, 1.40, 0.30); the leaves arch
		# a little past that, hence the generous pad.
		mn = Vector3(minf(mn.x, p.x - 0.5 * hi), minf(mn.y, p.y - 0.2),
			minf(mn.z, p.z - 0.5 * hi))
		mx = Vector3(maxf(mx.x, p.x + 0.5 * hi), maxf(mx.y, p.y + 1.7 * hi),
			maxf(mx.z, p.z + 0.5 * hi))
	mm.visible_instance_count = spots.size()

	var mmi := MultiMeshInstance3D.new()
	mmi.name = str(params.get("name", "CattailBed"))
	mmi.multimesh = mm
	mmi.material_override = PROPS.shared_material()
	# An explicit AABB, stated generously once. A MultiMesh derives its own from
	# the instance transforms, and one that is ever driven by
	# visible_instance_count pops the whole bed out of frame at a shallow camera
	# angle — which is every camera angle in a zone played from water level.
	mmi.custom_aabb = AABB(mn, mx - mn)
	parent.add_child(mmi)
	return mmi


## Scatter positions in a band along the segment a -> c, [param half_w] either
## side. This is the shoreline generator: run it down the toe of the dyke, or
## along the edge of an island, and hand the result to cattail_bed().
static func bed_spots_band(a: Vector3, c: Vector3, half_w: float, count: int,
		seed_v := 0.0) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if count <= 0:
		return out
	var d := c - a
	var side := Vector3(-d.z, 0.0, d.x)
	if side.length_squared() < 1e-8:
		side = Vector3.RIGHT
	side = side.normalized()
	var step := 1.0 / float(count)
	for i in count:
		var t := clampf((float(i) + 0.5) * step + _wobble(i, 3, seed_v) * step * 0.45, 0.0, 1.0)
		var off := _wobble(i, 9, seed_v) * half_w
		out.append(a + d * t + side * off)
	return out


## Scatter positions in an annulus around [param centre]. This is the island
## and open-pool generator: reeds crowd the shallow rim of an impoundment and
## stop dead where it gets deep, which is exactly an annulus.
static func bed_spots_ring(centre: Vector3, r_in: float, r_out: float, count: int,
		seed_v := 0.0) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if count <= 0:
		return out
	var step := TAU / float(count)
	for i in count:
		var ang := (float(i) + 0.5) * step + _wobble(i, 2, seed_v) * step * 0.45
		var r := lerpf(r_in, r_out, absf(_wobble(i, 6, seed_v)))
		out.append(centre + Vector3(cos(ang) * r, 0.0, sin(ang) * r))
	return out


# ===========================================================================
# MOVING PARTS — the scope head and the gate leaf
# ===========================================================================
#
# Two models in this library have a part the zone needs to rotate at runtime.
# Both are built as a real child Node3D rather than baked into the shell, so
# the zone rotates a node and never touches a mesh.

## The spotting scope's rotating head, or null. The barrel lives under here and
## it is authored facing -Z, like every other model in this project.
static func scope_head(model: Node3D) -> Node3D:
	if model == null:
		return null
	return model.get_node_or_null("Head") as Node3D


## Point the scope at [param target] (a GLOBAL position), smoothly.
##
## THE GAG (CAMPAIGN_SPEC.md:526): "The birdwatcher says nothing, but their
## scope tracks you, and if you honk at them they write something down. That's
## the whole gag and it costs one Label3D." Call this from the zone's
## _process with the goose's global_position and the gag is done.
##
## The zone is welcome to skip this and set `scope_head(m).rotation` itself —
## this is a convenience, not a contract. What it gets you is the two things
## that are easy to get wrong:
##   1. -Z IS FORWARD. want_yaw is atan2(-to.x, -to.z), not atan2(to.x, to.z).
##      Get that backwards and the scope points its eyepiece at the goose,
##      which is both wrong and, infuriatingly, almost convincing.
##   2. Framerate-independent smoothing, lerp(a, b, 1 - exp(-rate * delta)).
##      Never lerp(a, b, 0.1) — that tracks at a different speed on every
##      machine.
##
## The aim is computed in the HEAD'S PARENT SPACE, so a scope the zone has
## yawed to face the pond still tracks correctly.
static func aim_scope(model: Node3D, target: Vector3, delta: float, rate := 4.0) -> void:
	var head := scope_head(model)
	if head == null or not head.is_inside_tree():
		return
	var host := head.get_parent() as Node3D
	var local_target := target
	if host != null:
		local_target = host.to_local(target)
	var to := local_target - head.position
	var flat := Vector2(to.x, to.z).length()
	if flat < 1e-4 and absf(to.y) < 1e-4:
		return
	var want_yaw := atan2(-to.x, -to.z)
	# A tripod head does not do gymnastics. Clamped so a goose flying directly
	# overhead makes the scope crane back, not flip.
	var want_pitch := clampf(atan2(to.y, maxf(flat, 0.001)), -0.60, 0.85)
	var t := clampf(1.0 - exp(-maxf(rate, 0.01) * delta), 0.0, 1.0)
	head.rotation.y = lerp_angle(head.rotation.y, want_yaw, t)
	head.rotation.x = lerp_angle(head.rotation.x, want_pitch, t)


## The gate's swinging leaf, or null. Hinged at GATE_PIVOT, closed at
## rotation.y == 0.
static func gate_leaf(model: Node3D) -> Node3D:
	if model == null:
		return null
	return model.get_node_or_null("Leaf") as Node3D


## Swing the gate. [param open] is 0 (shut) to 1 (fully open), smoothed the
## same framerate-independent way as aim_scope.
static func swing_gate(model: Node3D, open: float, delta: float, rate := 3.0) -> void:
	var leaf := gate_leaf(model)
	if leaf == null:
		return
	var want := GATE_OPEN_ANGLE * clampf(open, 0.0, 1.0)
	var t := clampf(1.0 - exp(-maxf(rate, 0.01) * delta), 0.0, 1.0)
	leaf.rotation.y = lerp_angle(leaf.rotation.y, want, t)


# ===========================================================================
# LETTERING — where the words go, and who puts them there
# ===========================================================================
#
# Three models here are signs with a blank field on them: the refuge entrance
# sign, the interpretive panel and the gate's notice plate. NONE of them
# contains a letter.
#
# The project's only bitmap font lives in prop_models_truckstop.gd (a 4x5 FONT
# dictionary, `text_width()` and `sign_text()` at :277 and :304). Preloading the
# TRUCK STOP library from the REFUGE library to borrow a font is exactly the
# "coupling nobody expects" the stated policy rejects — and it would drag the
# truckstop's unshaded glow material onto a dawn sign as a side effect.
#
# So the split is: this library owns the PLACARD, the zone owns the WORDS. The
# zone already preloads whatever it likes. Ask this function where the field
# is and paint into it:
#
#     const TS := preload("res://scripts/world/prop_models_truckstop.gd")
#     var m: Node3D = STOP.build(&"refuge_sign", self)
#     m.global_position = ...
#     var f := STOP.text_field(&"refuge_sign")
#     var normal: Vector3 = f["normal"]
#     var up: Vector3 = f["up"]
#     var right: Vector3 = up.cross(normal)          # NOT +X. See below.
#     var h := 0.20
#     var wdt: float = TS.text_width("MONTEZUMA", h)
#     var origin: Vector3 = f["origin"] + up * (h * 0.5) \
#         - right * (wdt - h / 5.0) * 0.5
#     TS.sign_text(m, "MONTEZUMA", origin, normal, up, h, STOP.C_SIGN_WHITE, false)
#
# Note `unshaded = false` on that call: this is a dawn zone and a refuge sign is
# lit by the sunrise like everything else. Passing the default `true` makes the
# lettering the brightest thing in the level.
#
# THE MIRROR RULE, restated because this project has shipped "POTS" and
# "ƎƆIVЯƎƧ": screen-right on a face is `up.cross(normal)`, never +X.
# text_field() returns the normal and up you need; do not guess them.

## Where the words go on a sign, in the MODEL's local space.
##
## Returns {} for a kind with no text field. Otherwise:
##   origin  Vector3  the CENTRE of the field (sign_text wants a top-left —
##                    convert with the recipe above)
##   normal  Vector3  the face's outward normal
##   up      Vector3  which way is up ON the face
##   width   float    usable field width in metres
##   height  float    usable field height in metres
##
## Because these are model-local, do NOT pass `size` to a sign kind — a scaled
## model puts the words in the wrong place and at the wrong size.
static func text_field(kind: StringName, params := {}) -> Dictionary:
	match kind:
		&"refuge_sign":
			# The emblem sits at +X, which is the READER'S LEFT on a -Z-facing
			# panel, so the text field is offset to -X — the reader's right.
			# Capacity: the truckstop font's text_width is length * h, so the
			# 1.60 m field takes 9 characters at h = 0.17, or 11 at h = 0.14.
			return {
				"origin": Vector3(-0.18, 1.42, -0.064),
				"normal": Vector3(0, 0, -1),
				"up": Vector3(0, 1, 0),
				"width": 1.60,
				"height": 0.66,
			}
		&"interp_sign":
			# The panel leans back 40 degrees, so neither the normal nor the up
			# is an axis: sin(0.70) = 0.6442, cos(0.70) = 0.7648. The field
			# centre is the panel centre (0, 0.98, 0.10) pushed 0.038 out along
			# the face normal, which clears the brown field's own thickness.
			return {
				"origin": Vector3(0.0, 1.0045, 0.0709),
				"normal": Vector3(0.0, 0.6442, -0.7648),
				"up": Vector3(0.0, 0.7648, 0.6442),
				"width": 0.98,
				"height": 0.58,
			}
		&"gate":
			# On the LEAF, not the model: the plate swings with the gate. Pass
			# gate_leaf(model) as sign_text's parent, not the model.
			return {
				"origin": Vector3(1.66, 0.32, -0.046),
				"normal": Vector3(0, 0, -1),
				"up": Vector3(0, 1, 0),
				"width": 0.52,
				"height": 0.26,
			}
	return {}


# ===========================================================================
# 1. DEAD STANDING TIMBER — the zone's signature silhouette
# ===========================================================================
#
# When a refuge floods an impoundment it kills the trees standing in it, and
# they stay up for decades: bare, silver, limbless, leaning. A stand of them is
# the single image that says "drowned marsh" and not "pond", and it is the only
# vertical in the level besides the tower.
#
# FOUR SILHOUETTES, because a copy-pasted stand reads as wallpaper in about
# nine seconds. Pick with {"form": 0..3}; jitter within a form with
# {"variant": <float>}.
#
# Each row is:  height, base radius, lean, TOP FRACTION, [limb rows]
# and each limb row is:  y fraction, angle, horizontal reach, rise, radius
#
# TOP FRACTION is the trunk radius at the break as a fraction of the base, and
# it is what separates a spar from a stump. The first pass shared one hard
# taper across all four forms and the "stump" rendered as a tipi — a broken-off
# stump is BLUNT, and a tapered one is a spike no matter how short you make it.
const SNAG_FORMS := [
	# 0 — THE SPAR. Tall, near-straight, snapped clean high up, two stub limbs.
	#     The heron perch. Use this one most.
	[9.40, 0.42, 0.012, 0.22, [
		[0.62, 0.40, 2.10, 0.35, 0.100],
		[0.78, 3.50, 1.55, 0.20, 0.085],
	]],
	# 1 — THE STUMP. A third of the height, broad and blunt, one broken side
	#     limb. Reads as the oldest thing in the marsh and fills middle distance.
	[3.60, 0.50, 0.006, 0.62, [
		[0.66, 2.20, 1.25, -0.20, 0.095],
	]],
	# 2 — THE LEANER. Reaching out over the water on one long low limb. This is
	#     the one to put where the player will walk under it.
	[7.60, 0.38, 0.055, 0.26, [
		[0.52, 1.20, 3.20, -0.45, 0.120],
		[0.74, 4.40, 1.20, 0.10, 0.070],
	]],
	# 3 — THE FORK. Splits at 45% and both leads are broken off short.
	[8.20, 0.46, 0.018, 0.34, [
		[0.46, 0.90, 1.60, 3.10, 0.170],
		[0.46, 4.00, 1.30, 2.60, 0.150],
	]],
]


static func _form_index(params: Dictionary) -> int:
	return clampi(int(_num(params, "form", 0.0)), 0, SNAG_FORMS.size() - 1)


static func _snag(b: RefCounted, params: Dictionary) -> void:
	var dry := _col(params, "colour", C_SNAG)
	var wet := _col(params, "trim_colour", C_SNAG_WET)
	var seed_v := _num(params, "variant", 0.0)
	var row: Array = SNAG_FORMS[_form_index(params)]
	var h: float = row[0]
	var base_r: float = row[1]
	var lean: float = row[2]
	var top_frac: float = row[3]
	var limbs: Array = row[4]

	# ── the trunk ───────────────────────────────────────────────────────────
	# Five bands, every ring kicked off round. The profile is fractions of the
	# total height so a stump and a spar share one routine; `top_frac` remaps
	# the radius column so the two do not share a taper.
	var prof := [[0.00, 1.00], [0.09, 0.86], [0.34, 0.68], [0.66, 0.48], [1.00, 0.22]]
	var rings := []
	var spine := []
	for i in range(prof.size()):
		var pr: Array = prof[i]
		var fy: float = pr[0]
		var raw: float = pr[1]
		# Remap [0.22, 1.00] onto [top_frac, 1.00] so ring 0 is always the full
		# base radius and the top ring is always top_frac of it.
		var fr := top_frac + (raw - 0.22) * (1.0 - top_frac) / 0.78
		var y := h * fy
		# The lean is quadratic, not linear: a dead tree bends over its own
		# length rather than tipping like a post.
		var c := Vector3(lean * y * y * 0.35, y, -lean * y * y * 0.18)
		spine.append(c)
		rings.append(_rough_ring(c, base_r * fr, 6, float(i) * 0.37 + seed_v, seed_v, i, 0.16))

	# Two lofts, split at ring 1, so the permanently-soaked collar at the
	# waterline gets its own colour without a per-face callback.
	b.loft(rings.slice(0, 2), spine.slice(0, 2), wet)
	b.loft(rings.slice(1), spine.slice(1), dry)

	# Root flare. A tree standing in water grips the bed with buttresses, and
	# without them the trunk reads as a dowel pushed into mud.
	for i in 4:
		var a := TAU * float(i) / 4.0 + seed_v * 0.7
		var out_r := base_r * (1.7 + 0.35 * _wobble(i, 1, seed_v))
		_strut(b, Vector3(cos(a) * out_r, -0.05, sin(a) * out_r),
			Vector3(cos(a) * base_r * 0.45, h * 0.14, sin(a) * base_r * 0.45),
			base_r * 0.24, wet.lightened(0.05))

	# ── the break ───────────────────────────────────────────────────────────
	# NOT a flat cap. A snapped trunk ends in splinters, and the difference
	# between a jagged top and a flat one is the difference between a dead tree
	# and a fence post.
	var top: PackedVector3Array = rings[rings.size() - 1]
	var top_c: Vector3 = spine[spine.size() - 1]
	var apex := top_c + Vector3(base_r * 0.30 * _wobble(9, 1, seed_v), base_r * 0.55,
		base_r * 0.30 * _wobble(9, 2, seed_v))
	_cap_axial(b, top, apex, Vector3.UP, dry.lightened(0.10))
	for i in 3:
		var a := TAU * float(i) / 3.0 + seed_v * 1.9
		var rr := base_r * 0.16
		var lift := base_r * (1.1 + 0.9 * absf(_wobble(i, 4, seed_v)))
		_strut(b, top_c + Vector3(cos(a) * rr, 0.0, sin(a) * rr),
			top_c + Vector3(cos(a) * rr * 1.4, lift, sin(a) * rr * 1.4),
			base_r * 0.10, dry.lightened(0.06))

	# ── the limbs ───────────────────────────────────────────────────────────
	# Each is two segments with a kink, because a limb that is one straight tube
	# is a broom handle. The outer segment is thinner and ends in a stub.
	for li in range(limbs.size()):
		var lm: Array = limbs[li]
		var fy: float = lm[0]
		var ang: float = lm[1] + seed_v
		var reach: float = lm[2]
		var rise: float = lm[3]
		var r: float = lm[4]
		var y := h * fy
		var root := Vector3(lean * y * y * 0.35, y, -lean * y * y * 0.18)
		var mid := root + Vector3(cos(ang) * reach * 0.55, rise * 0.62,
			sin(ang) * reach * 0.55)
		var tip := root + Vector3(cos(ang + 0.28) * reach, rise, sin(ang + 0.28) * reach)
		_strut(b, root, mid, r, dry.darkened(0.06))
		_strut(b, mid, tip, r * 0.62, dry.darkened(0.02))
		# A short broken sub-limb off the kink, on every other limb.
		if li % 2 == 0:
			var sub := mid + Vector3(cos(ang - 1.4) * reach * 0.32, rise * 0.18 + 0.35,
				sin(ang - 1.4) * reach * 0.32)
			_strut(b, mid, sub, r * 0.45, dry.darkened(0.10))


# ===========================================================================
# 2. OBSERVATION TOWER — the zone's one piece of high ground
# ===========================================================================
#
# HEIGHTS ARE LOAD-BEARING. See the MEASURED HEIGHTS block near the top of the
# file; the short version is landing 1.60, deck 3.20, rail cap 4.30, ridge
# 5.55, and every one of those is under one 1.86 m flap from the surface below
# it. Do NOT pass `size` to this model.
#
# ANCHORING: the origin is the centre of the DECK at ground level, and the
# stair runs out along +Z to z = +7.00. The model is deliberately not centred
# on its own bounding box — a tower is placed by where its deck is, and the
# stair goes wherever there is room for it.
#
# WHAT THE ZONE STILL HAS TO DO:
#   * Colliders. This is geometry, not physics. The tower wants FOUR shapes and
#     no more: one box for the deck (2 x TOWER_DECK_HW square, ~0.2 thick, top
#     at TOWER_DECK_Y), one box for the landing, and one ROTATED box per stair
#     flight used as a ramp. Do not give each of the sixteen treads its own
#     collider — a goose walking up a staircase of individual steps at this
#     scale catches on every nosing.
#   * The bonus objective. ROUTE_DATA §7.2 has `tower` / "Get on the
#     observation tower" with the label ON THE TOWER and `no_scale`. That is an
#     Area3D on the deck, and it belongs to the zone.

static func _observation_tower(b: RefCounted, params: Dictionary) -> void:
	var wood := _col(params, "colour", C_TIMBER)
	var trim := _col(params, "trim_colour", C_TIMBER.darkened(0.18))
	var seed_v := _num(params, "variant", 0.0)
	var hw := TOWER_DECK_HW
	var post_hw := 0.088
	var post_x := hw - 0.18
	var eave_y := TOWER_ROOF_Y - 0.65
	var plate_y := 4.95

	# ── four legs ───────────────────────────────────────────────────────────
	# Driven 0.25 into the mud, and carried all the way to the roof plate: a
	# tower whose roof stands on its own separate posts always looks like two
	# models sitting on each other.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var xs: float = sx
			var zs: float = sz
			# NO `- 0.125` ON THE CENTRE. A box's centre and half-height have to
			# move together; this one carried a spare -0.125 with no matching
			# change to the half, which slid every leg down 125 mm without
			# lengthening it. The legs are meant to run from -0.25 ("driven into
			# the mud", per the comment above) to `plate_y`; they ran -0.375 to
			# 4.825 instead, leaving a 70 mm gap under the roof plate at every
			# corner and burying the posts twice as deep as the MEASURED HEIGHTS
			# block claims. Centre = (top + bottom) / 2 = (plate_y - 0.25) / 2.
			b.box(Vector3(xs * post_x, (plate_y - 0.25) * 0.5, zs * post_x),
				Vector3(post_hw, (plate_y + 0.25) * 0.5, post_hw), wood)

	# ── bracing ─────────────────────────────────────────────────────────────
	# The X-brace is the whole reason this reads as a tower and not as a table.
	# Two tiers, on three sides — the +Z side is the stair approach and stays
	# open, which is also how you can tell from a distance where the stair is.
	var tiers := [[0.15, 1.55], [1.55, TOWER_DECK_Y - 0.22]]
	for ti in range(tiers.size()):
		var tr: Array = tiers[ti]
		var y0: float = tr[0]
		var y1: float = tr[1]
		# -X and +X faces.
		for sx in [-1.0, 1.0]:
			var xs2: float = sx
			_strut(b, Vector3(xs2 * post_x, y0, -post_x), Vector3(xs2 * post_x, y1, post_x),
				0.042, trim)
			_strut(b, Vector3(xs2 * post_x, y1, -post_x), Vector3(xs2 * post_x, y0, post_x),
				0.042, trim)
		# -Z face only.
		_strut(b, Vector3(-post_x, y0, -post_x), Vector3(post_x, y1, -post_x), 0.042, trim)
		_strut(b, Vector3(-post_x, y1, -post_x), Vector3(post_x, y0, -post_x), 0.042, trim)
		# Horizontal girt at the tier line, all four sides.
		b.box(Vector3(0, y0, -post_x), Vector3(post_x, 0.042, 0.038), trim)
		b.box(Vector3(0, y0, post_x), Vector3(post_x, 0.042, 0.038), trim)
		for sx2 in [-1.0, 1.0]:
			var xs3: float = sx2
			b.box(Vector3(xs3 * post_x, y0, 0), Vector3(0.038, 0.042, post_x), trim)

	# ── the deck ────────────────────────────────────────────────────────────
	# Joists across X, then boards across X with a real gap between them. Same
	# read as the cottage dock: a solid slab is a platform, a striped one is
	# something somebody built out of lumber.
	for i in 5:
		var jz := -hw + (float(i) + 0.5) * (hw * 2.0 / 5.0)
		b.box(Vector3(0, TOWER_DECK_Y - 0.10, jz), Vector3(hw, 0.070, 0.050), trim)
	var boards := 13
	var pitch := (hw * 2.0) / float(boards)
	for i in boards:
		var bz := -hw + pitch * (float(i) + 0.5)
		var k := 1.0 + 0.09 * _wobble(i, 4, seed_v)
		var col := wood.lightened(0.06 * _wobble(i, 2, seed_v))
		b.box(Vector3(0, TOWER_DECK_Y - 0.015, bz), Vector3(hw, 0.028, pitch * 0.40 * k), col)

	# ── the railing ─────────────────────────────────────────────────────────
	# Cap at TOWER_RAIL_Y, mid rail halfway, balusters at 0.30. The +Z side
	# leaves a 1.40 m gap for the stair to arrive through.
	var rail_mid := (TOWER_DECK_Y + TOWER_RAIL_Y) * 0.5
	for sz in [-1.0, 1.0]:
		var zs2: float = sz
		if zs2 > 0.0:
			# Split rail: two short runs either side of the stair opening.
			for sx3 in [-1.0, 1.0]:
				var xs4: float = sx3
				b.box(Vector3(xs4 * (hw * 0.66), TOWER_RAIL_Y, zs2 * hw),
					Vector3(hw * 0.34, 0.045, 0.055), wood)
				b.box(Vector3(xs4 * (hw * 0.66), rail_mid, zs2 * hw),
					Vector3(hw * 0.34, 0.030, 0.030), trim)
		else:
			b.box(Vector3(0, TOWER_RAIL_Y, zs2 * hw), Vector3(hw, 0.045, 0.055), wood)
			b.box(Vector3(0, rail_mid, zs2 * hw), Vector3(hw, 0.030, 0.030), trim)
	for sx4 in [-1.0, 1.0]:
		var xs5: float = sx4
		b.box(Vector3(xs5 * hw, TOWER_RAIL_Y, 0), Vector3(0.055, 0.045, hw), wood)
		b.box(Vector3(xs5 * hw, rail_mid, 0), Vector3(0.030, 0.030, hw), trim)
	# Balusters.
	var bal := 11
	for i in bal:
		var t := (float(i) + 0.5) / float(bal)
		var p := -hw + t * hw * 2.0
		b.box(Vector3(p, rail_mid + 0.02, -hw), Vector3(0.024, (TOWER_RAIL_Y - TOWER_DECK_Y) * 0.5,
			0.024), trim)
		for sx5 in [-1.0, 1.0]:
			var xs6: float = sx5
			b.box(Vector3(xs6 * hw, rail_mid + 0.02, p),
				Vector3(0.024, (TOWER_RAIL_Y - TOWER_DECK_Y) * 0.5, 0.024), trim)
		if absf(p) > 0.72:
			b.box(Vector3(p, rail_mid + 0.02, hw),
				Vector3(0.024, (TOWER_RAIL_Y - TOWER_DECK_Y) * 0.5, 0.024), trim)

	# ── the roof ────────────────────────────────────────────────────────────
	# A gable running along X, eaves overhanging 0.35 all round. The overhang is
	# the whole silhouette: a roof flush with its posts reads as a lid.
	var over := 0.35
	var rx := hw + over
	b.box(Vector3(0, plate_y, -post_x), Vector3(post_x + 0.05, 0.055, 0.055), trim)
	b.box(Vector3(0, plate_y, post_x), Vector3(post_x + 0.05, 0.055, 0.055), trim)
	# Rafters, visible from underneath, which is where the player will be.
	for i in 5:
		var rz := -hw + (float(i) + 0.5) * (hw * 2.0 / 5.0)
		_strut(b, Vector3(-rx, eave_y, rz), Vector3(0, TOWER_ROOF_Y - 0.10, rz), 0.038, trim)
		_strut(b, Vector3(rx, eave_y, rz), Vector3(0, TOWER_ROOF_Y - 0.10, rz), 0.038, trim)
	# The two roof planes, as boarded strips so the shingle lines read.
	var strips := 5
	for sx6 in [-1.0, 1.0]:
		var xs7: float = sx6
		for i in strips:
			var t0 := float(i) / float(strips)
			var t1 := float(i + 1) / float(strips)
			var xa := xs7 * lerpf(rx, 0.0, t0)
			var xb := xs7 * lerpf(rx, 0.0, t1)
			var ya := lerpf(eave_y, TOWER_ROOF_Y, t0)
			var yb := lerpf(eave_y, TOWER_ROOF_Y, t1)
			var mid_c := Vector3((xa + xb) * 0.5, (ya + yb) * 0.5, 0.0)
			var inside := Vector3(0.0, eave_y - 2.0, 0.0)
			var shade := trim.lightened(0.05 + 0.03 * float(i % 2))
			b.quad(Vector3(xa, ya, -hw - over), Vector3(xb, yb, -hw - over),
				Vector3(xb, yb, hw + over), Vector3(xa, ya, hw + over), shade, inside)
			# Underside, so the roof is not a hole when you stand on the deck.
			b.quad(Vector3(xa, ya - 0.06, hw + over), Vector3(xb, yb - 0.06, hw + over),
				Vector3(xb, yb - 0.06, -hw - over), Vector3(xa, ya - 0.06, -hw - over),
				trim.darkened(0.22), mid_c + Vector3(0, 2.0, 0))
	# Gable ends and the ridge cap.
	for sz3 in [-1.0, 1.0]:
		var zs4: float = sz3
		b.tri(Vector3(-rx, eave_y, zs4 * (hw + over)), Vector3(rx, eave_y, zs4 * (hw + over)),
			Vector3(0, TOWER_ROOF_Y, zs4 * (hw + over)), wood.darkened(0.06),
			Vector3(0, eave_y, 0))
	# The ridge cap is a CAP — 0.20 m of capping board along the ridge line. The
	# first pass gave it half-extent `rx`, which is a 4.3 m slab lying flat at
	# ridge height across the entire roof; it renders as an unlit grey plane
	# floating above the gable and it is invisible to the compile gate.
	b.box(Vector3(0, TOWER_ROOF_Y + 0.02, 0), Vector3(0.10, 0.045, hw + over + 0.02), wood)

	# ── the stair ───────────────────────────────────────────────────────────
	_tower_flight(b, Vector3(0, 0.00, TOWER_STAIR_Z), Vector3(0, TOWER_LANDING_Y, 4.80),
		wood, trim, seed_v)
	# The landing, and the two posts holding it up.
	b.box(Vector3(0, TOWER_LANDING_Y - 0.045, 4.45), Vector3(0.72, 0.045, 0.42), wood)
	for sx7 in [-1.0, 1.0]:
		var xs8: float = sx7
		# Same spare -0.125 as the main legs, same fix — see the note there.
		b.box(Vector3(xs8 * 0.66, (TOWER_LANDING_Y - 0.25) * 0.5, 4.45),
			Vector3(0.062, (TOWER_LANDING_Y + 0.25) * 0.5, 0.062), wood)
	_tower_flight(b, Vector3(0, TOWER_LANDING_Y, 4.10), Vector3(0, TOWER_DECK_Y, 1.90),
		wood, trim, seed_v + 1.3)


## One flight of stairs from [param a] to [param c]. Eight treads, two
## stringers, a handrail down each side. Split out because the tower has two
## flights and they are identical apart from where they start.
static func _tower_flight(b: RefCounted, a: Vector3, c: Vector3, wood: Color,
		trim: Color, seed_v: float) -> void:
	var half_w := 0.68
	# Stringers: the diagonal beams the treads sit on.
	for sx in [-1.0, 1.0]:
		var xs: float = sx
		_strut(b, a + Vector3(xs * half_w, 0.04, 0.0), c + Vector3(xs * half_w, -0.02, 0.0),
			0.055, trim)
	var treads := 8
	for i in treads:
		var t := (float(i) + 1.0) / float(treads)
		var p := a.lerp(c, t)
		b.box(Vector3(0, p.y - 0.028, p.z + 0.06), Vector3(half_w, 0.028, 0.150),
			wood.lightened(0.05 * _wobble(i, 3, seed_v)))
	# Handrail, 0.95 above the nosings, with three balusters a side.
	for sx2 in [-1.0, 1.0]:
		var xs2: float = sx2
		_strut(b, a + Vector3(xs2 * half_w, 0.95, 0.0), c + Vector3(xs2 * half_w, 0.95, 0.0),
			0.032, wood)
		for i in 3:
			var t2 := (float(i) + 0.5) / 3.0
			var p2 := a.lerp(c, t2)
			b.box(Vector3(xs2 * half_w, p2.y + 0.48, p2.z), Vector3(0.024, 0.48, 0.024), trim)


# ===========================================================================
# 3. SPOTTING SCOPE ON A TRIPOD — the gag, in two parts
# ===========================================================================
#
# The tripod is baked into the shell. The BARREL is a separate child Node3D
# called "Head", pivoting at SCOPE_PIVOT, because the joke is that it tracks
# the goose (CAMPAIGN_SPEC.md:526) and a joke that costs a mesh rebuild every
# frame is not a joke, it is a stutter.
#
#     var m: Node3D = STOP.build(&"spotting_scope", self)
#     ...
#     func _process(delta): STOP.aim_scope(m, goose.global_position, delta)
#
# The barrel is authored facing -Z, like every model in this project. Do not
# pass `size` — a non-uniformly scaled parent makes aim_scope's to_local()
# skew, and the scope will point somewhere plausible and wrong.

static func _spotting_scope(b: RefCounted, params: Dictionary) -> void:
	var metal := _col(params, "trim_colour", C_GALV)
	var hub := SCOPE_PIVOT + Vector3(0, -0.13, 0)

	# Three legs, each in two sections with a clamp at the joint. The clamp is
	# what makes it a tripod and not three sticks.
	for i in 3:
		var ang := TAU * float(i) / 3.0 + 0.52
		var foot := Vector3(cos(ang) * 0.40, 0.0, sin(ang) * 0.40)
		var knee := foot.lerp(hub, 0.55)
		_cyl(b, foot, knee, 0.019, 0.023, 4, metal.darkened(0.10), PI * 0.25)
		_cyl(b, knee, hub, 0.028, 0.030, 4, metal, PI * 0.25)
		# Clamp collar.
		b.box(knee + Vector3(0, 0.015, 0), Vector3(0.034, 0.026, 0.034), C_STEEL)
		# Rubber foot.
		b.box(foot + Vector3(0, 0.014, 0), Vector3(0.030, 0.014, 0.030), Color(0.14, 0.14, 0.15))
		# Spreader arm back to the centre column, low down.
		_strut(b, foot.lerp(hub, 0.28), Vector3(0, hub.y * 0.34, 0), 0.010, metal.darkened(0.18))

	# Centre column and the pan head the barrel sits on.
	var col_top := SCOPE_PIVOT + Vector3(0, -0.055, 0)
	_cyl(b, hub, col_top, 0.032, 0.030, 6, metal.lightened(0.05))
	_cap_axial(b, LPB.ring(col_top, Vector3.UP, Vector3.FORWARD, 0.030, 0.030, 6, 0.0),
		col_top + Vector3(0, 0.012, 0), Vector3.UP, metal.lightened(0.10))
	b.box(SCOPE_PIVOT + Vector3(0, -0.030, 0), Vector3(0.045, 0.030, 0.055), C_SCOPE)
	# The pan handle, trailing back and down. Nobody ever puts it away.
	_strut(b, SCOPE_PIVOT + Vector3(0.02, -0.03, 0.05),
		SCOPE_PIVOT + Vector3(0.05, -0.24, 0.28), 0.011, C_STEEL)
	b.box(SCOPE_PIVOT + Vector3(0.055, -0.26, 0.31), Vector3(0.014, 0.035, 0.014),
		Color(0.12, 0.12, 0.13))


## The rotating half. Built into its own child node so the zone can aim it.
static func _build_scope_head(model: Node3D, params: Dictionary) -> void:
	var head := Node3D.new()
	head.name = "Head"
	head.position = SCOPE_PIVOT
	model.add_child(head)

	var hb: RefCounted = LPB.new()
	var hw: RefCounted = LPB.new()
	_scope_barrel(hb, hw, params)
	if hb.tri_count > 0:
		LPB.attach(head, hb.commit(), shared_material(), "Shell")
	if hw.tri_count > 0:
		LPB.attach(head, hw.commit(), haze_material(), "Haze")
	head.set_meta("tri_count", hb.tri_count + hw.tri_count)


## The barrel, in the Head node's local space. -Z IS FORWARD: the objective
## lens is at -Z and the eyepiece is at +Z, so a head yawed toward the goose is
## looking at it rather than away from it.
static func _scope_barrel(b: RefCounted, w: RefCounted, params: Dictionary) -> void:
	var body := _col(params, "colour", C_SCOPE)

	# Mounting foot onto the pan head.
	b.box(Vector3(0, -0.048, 0.02), Vector3(0.032, 0.026, 0.085), body.lightened(0.10))
	# The barrel: fat at the objective end, which is the read.
	_cyl(b, Vector3(0, 0, 0.14), Vector3(0, 0, -0.24), 0.048, 0.070, 6, body)
	_cap_axial(b, LPB.ring(Vector3(0, 0, 0.14), Vector3.BACK, Vector3.UP, 0.048, 0.048, 6, 0.0),
		Vector3(0, 0, 0.16), Vector3.BACK, body.darkened(0.18))
	# Retractable sunshade, always left out.
	_cyl(b, Vector3(0, 0, -0.24), Vector3(0, 0, -0.38), 0.072, 0.072, 6, body.darkened(0.12))
	# The objective, catching the sunrise. This is the brightest opaque face in
	# the whole zone and it is nine centimetres across, which is exactly the
	# right ratio.
	var lens := LPB.ring(Vector3(0, 0, -0.375), Vector3.FORWARD, Vector3.UP, 0.062, 0.062, 6, 0.0)
	_cap_axial(b, lens, Vector3(0, 0, -0.385), Vector3.FORWARD, C_LENS)
	# A faint alpha disc just in front of it: the flare a low sun puts on glass.
	var flare := LPB.ring(Vector3(0, 0, -0.392), Vector3.FORWARD, Vector3.UP, 0.088, 0.088, 6, 0.3)
	_cap_axial(w, flare, Vector3(0, 0, -0.394), Vector3.FORWARD,
		Color(1.0, 0.86, 0.74, 0.22))
	# Focus knob on the flank.
	_cyl(b, Vector3(0.062, 0.01, 0.0), Vector3(0.086, 0.01, 0.0), 0.028, 0.026, 6, C_STEEL)
	_cap_axial(b, LPB.ring(Vector3(0.086, 0.01, 0.0), Vector3.RIGHT, Vector3.UP, 0.026, 0.026,
		6, 0.0), Vector3(0.090, 0.01, 0.0), Vector3.RIGHT, C_STEEL.lightened(0.10))
	# 45-degree eyepiece, which is what a birdwatcher's scope actually has.
	var eye_a := Vector3(0, 0.02, 0.13)
	var eye_b := Vector3(0, 0.11, 0.22)
	_cyl(b, eye_a, eye_b, 0.036, 0.030, 6, body.lightened(0.05))
	_cyl(b, eye_b, eye_b + Vector3(0, 0.028, 0.028), 0.034, 0.038, 6,
		Color(0.10, 0.10, 0.11))
	_cap_axial(b, LPB.ring(eye_b + Vector3(0, 0.028, 0.028), (eye_b - eye_a).normalized(),
		Vector3.UP, 0.038, 0.038, 6, 0.0), eye_b + Vector3(0, 0.034, 0.034),
		(eye_b - eye_a).normalized(), Color(0.06, 0.06, 0.07))


# ===========================================================================
# 4. FOLDING CHAIR — the one saturated object in the zone
# ===========================================================================
#
# A nylon camp chair, navy, with a cup holder. It is deliberately the loudest
# colour for six hundred metres, and that is doing work: it is how the player
# finds the birdwatcher, and the birdwatcher stands next to the flock pen,
# which CAMPAIGN_SPEC.md:497 wants to be the biggest thing in the level.

static func _folding_chair(b: RefCounted, params: Dictionary) -> void:
	var fabric := _col(params, "colour", C_CHAIR)
	var frame := _col(params, "trim_colour", C_ALU)
	var seed_v := _num(params, "variant", 0.0)
	var thermos := _flag(params, "thermos", true)
	var hx := 0.29
	var seat_y := 0.44

	# Two X-frames, one per side. This is the entire structure of a camp chair.
	for sx in [-1.0, 1.0]:
		var xs: float = sx
		_strut(b, Vector3(xs * hx, 0.0, -0.27), Vector3(xs * hx, seat_y + 0.02, 0.27),
			0.017, frame)
		_strut(b, Vector3(xs * hx, 0.0, 0.27), Vector3(xs * hx, seat_y + 0.02, -0.27),
			0.017, frame)
		# Feet.
		for sz in [-1.0, 1.0]:
			var zs: float = sz
			b.box(Vector3(xs * hx, 0.016, zs * 0.27), Vector3(0.026, 0.016, 0.036),
				Color(0.13, 0.13, 0.14))
		# Back uprights, raked back over the rear feet.
		_strut(b, Vector3(xs * hx, seat_y, 0.24), Vector3(xs * (hx - 0.04), 0.90, 0.37),
			0.015, frame)
	# Cross tubes front and back.
	b.box(Vector3(0, seat_y + 0.02, -0.27), Vector3(hx, 0.015, 0.015), frame)
	b.box(Vector3(0, seat_y + 0.02, 0.27), Vector3(hx, 0.015, 0.015), frame)
	b.box(Vector3(0, 0.90, 0.37), Vector3(hx - 0.04, 0.016, 0.016), frame)

	# The seat, as five slats at slightly different heights. A flat slab is a
	# bench; a sag is a sling.
	for i in 5:
		var t := (float(i) + 0.5) / 5.0
		var z := lerpf(-0.25, 0.25, t)
		var sag := 0.052 * sin(t * PI)
		b.box(Vector3(0, seat_y - sag, z), Vector3(hx - 0.02, 0.013, 0.052),
			fabric.lightened(0.05 * _wobble(i, 2, seed_v)))
	# The back, same trick, raked.
	for i in 5:
		var t2 := (float(i) + 0.5) / 5.0
		var y := lerpf(seat_y + 0.06, 0.88, t2)
		var z2 := lerpf(0.26, 0.36, t2)
		var sag2 := 0.040 * sin(t2 * PI)
		b.box(Vector3(0, y, z2 + sag2), Vector3(hx - 0.045, 0.036, 0.013),
			fabric.lightened(0.04 * _wobble(i, 6, seed_v)))

	# Armrests, and the cup holder that makes it a birdwatcher's chair rather
	# than a chair.
	for sx2 in [-1.0, 1.0]:
		var xs2: float = sx2
		b.box(Vector3(xs2 * (hx + 0.02), 0.63, 0.02), Vector3(0.036, 0.014, 0.20),
			fabric.darkened(0.14))
		_strut(b, Vector3(xs2 * (hx + 0.02), 0.63, -0.17),
			Vector3(xs2 * hx, seat_y + 0.02, -0.16), 0.011, frame)
	var hc := Vector3(hx + 0.075, 0.60, 0.02)
	var cup_lo := LPB.ring(hc, Vector3.UP, Vector3.FORWARD, 0.052, 0.052, 6, 0.0)
	var cup_hi := LPB.ring(hc + Vector3(0, 0.085, 0), Vector3.UP, Vector3.FORWARD,
		0.056, 0.056, 6, 0.0)
	b.loft([cup_lo, cup_hi], [hc, hc + Vector3(0, 0.085, 0)], fabric.darkened(0.20))
	_loft_inward(b, [cup_lo, cup_hi], [hc, hc + Vector3(0, 0.085, 0)], fabric.darkened(0.36))
	_cap_axial(b, cup_lo, hc + Vector3(0, -0.004, 0), Vector3.DOWN, fabric.darkened(0.30))
	_strut(b, hc + Vector3(-0.05, 0.04, 0), Vector3(hx + 0.02, 0.62, 0.02), 0.010, frame)

	if thermos:
		var t0 := hc + Vector3(0, 0.02, 0)
		var t1 := hc + Vector3(0, 0.26, 0)
		_cyl(b, t0, t1, 0.042, 0.040, 6, Color(0.16, 0.28, 0.22))
		_cyl(b, t1, t1 + Vector3(0, 0.045, 0), 0.038, 0.034, 6, C_STEEL)
		_cap_axial(b, LPB.ring(t1 + Vector3(0, 0.045, 0), Vector3.UP, Vector3.FORWARD,
			0.034, 0.034, 6, 0.0), t1 + Vector3(0, 0.055, 0), Vector3.UP,
			C_STEEL.lightened(0.12))


# ===========================================================================
# 5. DYKE SECTION — the gravel road across the impoundment
# ===========================================================================
#
# ANCHORED ON THE MARSH BED, not the waterline. The section runs from y = 0 up
# to DYKE_CROWN_Y = 1.00, so with the bed at -0.30 the road surface lands at
# +0.70 — dry, walkable, and a comfortable half-flap above a swimming goose.
#
# TILEABLE along Z with span DYKE_SPAN = 8.00; sections butt end to end. The
# end caps are emitted anyway because they cost twelve triangles and the two
# ENDS of the road need them.
#
# THE ZONE OWNS THE COLLIDER. This is a vertex-coloured builder mesh with a
# junk planar UV — it cannot take a Tex albedo. Lay ONE long walkable box under
# the crown (half-width 2.20, top at DYKE_CROWN_Y) rather than one per section.
# If you want a real gravel texture on the road, put a thin textured BoxMesh
# from the zone's own `_surf()` helper on top at y = 1.005 and let this mesh be
# the shoulders.

static func _dyke_section(b: RefCounted, params: Dictionary) -> void:
	var gravel := _col(params, "colour", C_GRAVEL)
	var bank := _col(params, "trim_colour", C_BANK)
	var seed_v := _num(params, "variant", 0.0)
	var hz := DYKE_SPAN * 0.5

	# The berm cross-section, extruded along Z. Convex, so one loft does it.
	var prof := [
		Vector2(-4.10, 0.35), Vector2(-2.90, 0.75), Vector2(-2.20, 1.00),
		Vector2(2.20, 1.00), Vector2(2.90, 0.75), Vector2(4.10, 0.35),
		Vector2(4.10, 0.00), Vector2(-4.10, 0.00),
	]
	var r0 := PackedVector3Array()
	var r1 := PackedVector3Array()
	for i in range(prof.size()):
		var p: Vector2 = prof[i]
		r0.append(Vector3(p.x, p.y, -hz))
		r1.append(Vector3(p.x, p.y, hz))
	b.loft([r0, r1], [Vector3(0, 0.45, -hz), Vector3(0, 0.45, hz)], bank)
	# `axis_dir` is the OUTWARD direction, not the direction you are looking
	# from. The -Z end faces -Z, which is Vector3.FORWARD in this engine.
	_cap_axial(b, r0, Vector3(0, 0.45, -hz - 0.02), Vector3.FORWARD, bank.darkened(0.14))
	_cap_axial(b, r1, Vector3(0, 0.45, hz + 0.02), Vector3.BACK, bank.darkened(0.14))

	# The road surface proper, a slab of crushed limestone laid on the crown.
	b.box(Vector3(0, DYKE_CROWN_Y + 0.012, 0), Vector3(2.20, 0.020, hz), gravel)
	# Two wheel tracks, one value darker. Nobody drives down the middle.
	for sx in [-1.0, 1.0]:
		var xs: float = sx
		b.box(Vector3(xs * 0.86, DYKE_CROWN_Y + 0.026, 0), Vector3(0.54, 0.010, hz),
			gravel.darkened(0.11))
	# And a strip of weed down the crown between the tracks.
	b.box(Vector3(0, DYKE_CROWN_Y + 0.030, 0), Vector3(0.16, 0.012, hz), bank.lightened(0.10))

	# Rip-rap along both slopes: two staggered rows of quarried stone, each block
	# yawed AND pitched off-square by its own hash and sunk into the bank rather
	# than set on it. The first pass put one row of small cubes on top of the
	# slope and they rendered as dice scattered on a ramp — a stone that is not
	# bedded reads as a prop, and this is the one object in the zone the player
	# walks past at eye level.
	#
	# `_bank_y()` is the profile solved for the surface height at |x|, which is
	# what "bedded" needs: the stones follow the slope instead of a flat line.
	for sx2 in [-1.0, 1.0]:
		var xs2: float = sx2
		for i in 9:
			var z := -hz + (float(i) + 0.5) * (DYKE_SPAN / 9.0)
			for r in 2:
				# 0.17-0.27 half-extent, i.e. 35-55 cm of stone. The second pass
				# used 0.30-0.46 and the render came back as a heap of boulders
				# taller than half the berm — armour stone on a refuge dyke is
				# roughly a foot across, and scale is the whole read.
				var s := 0.17 + 0.10 * absf(_wobble(i, 4 + r, seed_v))
				var lane := 3.42 + float(r) * 0.44 + 0.14 * _wobble(i, 1 + r, seed_v)
				var surf := _bank_y(lane)
				var yaw := _wobble(i, 8 + r, seed_v) * 1.6
				b.box(Vector3(xs2 * lane, surf + s * 0.20,
						z + 0.30 * _wobble(i, 2 + r, seed_v)),
					Vector3(s, s * 0.70, s * 0.92),
					C_RIPRAP.lightened(0.09 * _wobble(i, 6 + r, seed_v)),
					Basis(Vector3.UP, yaw) * Basis(Vector3.FORWARD, yaw * 0.22))

	# Dead thatch tufts up the shoulder. Cheap, and they stop the slope reading
	# as a poured ramp.
	for sx3 in [-1.0, 1.0]:
		var xs3: float = sx3
		for i in 6:
			var z2 := -hz + (float(i) + 0.5) * (DYKE_SPAN / 6.0) + 0.4 * _wobble(i, 3, seed_v)
			var lane2 := 2.42 + 0.36 * absf(_wobble(i, 7, seed_v))
			b.box(Vector3(xs3 * lane2, _bank_y(lane2) + 0.09, z2),
				Vector3(0.095, 0.155, 0.085), bank.lightened(0.22),
				Basis(Vector3.UP, _wobble(i, 5, seed_v) * 1.4)
					* Basis(Vector3.FORWARD, 0.26 * xs3))


## The dyke's surface height at a distance [param ax] from the centreline, from
## the same profile the berm is lofted from. Anything dressed onto the slope
## has to go through this or it floats.
static func _bank_y(ax: float) -> float:
	var x := absf(ax)
	if x >= 4.10:
		return 0.35
	if x >= 2.90:
		return 0.35 + (4.10 - x) * (0.40 / 1.20)
	if x >= 2.20:
		return 0.75 + (2.90 - x) * (0.25 / 0.70)
	return 1.00


# ===========================================================================
# 6. INTERPRETIVE SIGN — the low lectern panel
# ===========================================================================
#
# Leaning back 40 degrees on two short posts, which is the angle every state
# and federal interpretive panel in North America uses and the reason they are
# instantly recognisable from behind.
#
# THE PANEL IS BLANK. Ask text_field(&"interp_sign") for where the words go and
# paint them from the zone. Under no circumstances give this one text that
# tells the player to rest — CAMPAIGN_SPEC.md:504: "This is the harm-reduction
# thesis as level design, and **it never says a word**." Real refuge panels are
# about invertebrates and water levels. Keep it about invertebrates.

static func _interp_sign(b: RefCounted, params: Dictionary) -> void:
	var wood := _col(params, "colour", C_TIMBER)
	var face := _col(params, "trim_colour", C_REFUGE_BROWN)
	var tilt := 0.70                              ## 40 degrees, in radians
	var bas := Basis(Vector3.RIGHT, tilt)
	var normal := Vector3(0.0, sin(tilt), -cos(tilt))
	var centre := Vector3(0.0, 0.98, 0.10)

	for sx in [-1.0, 1.0]:
		var xs: float = sx
		b.box(Vector3(xs * 0.50, 0.44, 0.13), Vector3(0.045, 0.44, 0.045), wood)
		_post_cap(b, Vector3(xs * 0.50, 0.88, 0.13), 0.045, 0.045, 0.035, wood)
	# A rail under the panel so it is carried rather than floating.
	b.box(Vector3(0, 0.80, 0.13), Vector3(0.50, 0.035, 0.035), wood.darkened(0.14))

	# Panel: carcass, white border, brown field. Three boxes, each a little in
	# front of the last along the face normal.
	b.box(centre, Vector3(0.59, 0.39, 0.020), wood.darkened(0.20), bas)
	b.box(centre + normal * 0.024, Vector3(0.555, 0.355, 0.006), C_SIGN_WHITE, bas)
	b.box(centre + normal * 0.032, Vector3(0.515, 0.315, 0.005), face, bas)


# ===========================================================================
# 7. BOLLARD — the thing that stops a truck and does not stop a goose
# ===========================================================================

static func _bollard(b: RefCounted, params: Dictionary) -> void:
	var wood := _col(params, "colour", C_TIMBER)
	var seed_v := _num(params, "variant", 0.0)
	var lean := 0.018 * _wobble(1, 2, seed_v)

	b.box(Vector3(lean * 0.9, 0.45, lean * 0.5), Vector3(0.080, 0.45, 0.080), wood,
		Basis(Vector3.FORWARD, lean * 0.9))
	_post_cap(b, Vector3(lean * 1.8, 0.90, lean), 0.080, 0.080, 0.075, wood)
	# The reflective band. Never pure white — see the palette note.
	b.box(Vector3(lean * 1.6, 0.80, lean * 0.9), Vector3(0.084, 0.055, 0.084), C_SIGN_WHITE)
	# A bolt and a chain eye, so it looks like it was installed rather than
	# spawned.
	b.box(Vector3(lean * 1.4, 0.62, -0.082), Vector3(0.020, 0.020, 0.012), C_STEEL)
	b.box(Vector3(0.084, 0.66, lean), Vector3(0.014, 0.030, 0.014), C_STEEL.darkened(0.10))


# ===========================================================================
# 8. GATE — a farm gate across the dyke road, with a leaf that swings
# ===========================================================================
#
# The leaf is a child Node3D called "Leaf", hinged at GATE_PIVOT. Closed at
# rotation.y == 0, open at GATE_OPEN_ANGLE. Use swing_gate(), or set the
# rotation yourself:
#
#     var m: Node3D = STOP.build(&"gate", self)
#     STOP.gate_leaf(m).rotation.y = STOP.GATE_OPEN_ANGLE   # propped open
#
# A refuge dyke road gate is normally standing wide open in the morning and
# padlocked at sunset, so "open" is the more truthful default for a dawn zone.
# The notice plate rides on the leaf — see text_field(&"gate").

static func _gate(b: RefCounted, params: Dictionary) -> void:
	var wood := _col(params, "colour", C_TIMBER)
	# Hinge post and latch post. Chunky, buried deep, capped.
	for sx in [-1.0, 1.0]:
		var xs: float = sx
		b.box(Vector3(xs * 1.75, 0.62, 0.0), Vector3(0.075, 0.82, 0.075), wood)
		_post_cap(b, Vector3(xs * 1.75, 1.44, 0.0), 0.075, 0.075, 0.075, wood)
		# A stone at the foot of each, where the mower never reaches.
		b.box(Vector3(xs * 1.75, 0.05, 0.14), Vector3(0.13, 0.05, 0.10), C_RIPRAP,
			Basis(Vector3.UP, xs * 0.4))
	# Hinge straps and the latch catch, on the posts rather than the leaf.
	for i in 2:
		b.box(Vector3(-1.68, 0.28 + float(i) * 0.52, 0.0), Vector3(0.030, 0.038, 0.048),
			C_STEEL)
	b.box(Vector3(1.70, 0.72, 0.0), Vector3(0.038, 0.042, 0.055), C_STEEL)


## The swinging half.
static func _build_gate_leaf(model: Node3D, params: Dictionary) -> void:
	var leaf := Node3D.new()
	leaf.name = "Leaf"
	leaf.position = GATE_PIVOT
	model.add_child(leaf)

	var lb: RefCounted = LPB.new()
	_gate_leaf_geom(lb, params)
	if lb.tri_count > 0:
		LPB.attach(leaf, lb.commit(), shared_material(), "Shell")
	leaf.set_meta("tri_count", lb.tri_count)


## Leaf geometry, in the Leaf node's local space: hinged at the origin, running
## out along +X, sitting on top of GATE_PIVOT.y.
static func _gate_leaf_geom(b: RefCounted, params: Dictionary) -> void:
	var steel := _col(params, "trim_colour", C_STEEL)
	var face := _col(params, "colour", C_REFUGE_BROWN)
	var span := 3.32

	# Five horizontal rails.
	for i in 5:
		var y := 0.05 + float(i) * 0.20
		b.box(Vector3(span * 0.5, y, 0.0), Vector3(span * 0.5, 0.030, 0.024), steel)
	# Two stiles.
	for x in [0.05, span - 0.06]:
		var xf: float = x
		b.box(Vector3(xf, 0.45, 0.0), Vector3(0.036, 0.46, 0.028), steel.lightened(0.05))
	# The diagonal brace. Without it a five-bar gate reads as a ladder lying on
	# its side.
	_strut(b, Vector3(0.10, 0.06, 0.0), Vector3(span - 0.12, 0.84, 0.0), 0.024,
		steel.darkened(0.08))
	# Hinge eyes at the pivot and a latch tongue at the far end.
	for i in 2:
		b.box(Vector3(-0.02, 0.00 + float(i) * 0.52, 0.0), Vector3(0.040, 0.034, 0.036),
			steel.darkened(0.14))
	b.box(Vector3(span + 0.02, 0.44, 0.0), Vector3(0.055, 0.026, 0.022),
		steel.lightened(0.10))

	# The notice plate, hung on the middle. Blank — see text_field(&"gate").
	var pc := Vector3(span * 0.5, 0.32, -0.030)
	b.box(pc, Vector3(0.30, 0.16, 0.010), face)
	b.box(pc + Vector3(0, 0, -0.011), Vector3(0.285, 0.145, 0.004), C_SIGN_WHITE)
	b.box(pc + Vector3(0, 0, -0.016), Vector3(0.262, 0.128, 0.004), face)


# ===========================================================================
# 9. WATER CONTROL STRUCTURE — the reason there is an impoundment at all
# ===========================================================================
#
# Every managed marsh in North America has one of these: a concrete headwall
# with a slot, a stack of timber stoplogs in the slot, and a screw stem with a
# handwheel to pull them. Refuge staff raise and lower the whole pool with it,
# which is the literal mechanism that makes a "drowned marsh" a drowned marsh.
#
# GAMEPLAY: the catwalk grating on top is at WEIR_DECK_Y = 1.75, and it is the
# only standable object out in the open water. Anchored on the marsh BED like
# the dyke, so with a bed at -0.30 the deck lands at +1.45 — 0.78 of a flap
# from a swimming goose. The zone must give it a collider; a box for the
# headwall and a box for the deck is enough.

static func _water_control(b: RefCounted, w: RefCounted, params: Dictionary) -> void:
	var conc := _col(params, "colour", C_CONCRETE)
	var timber := _col(params, "trim_colour", C_TIMBER_WET)
	var open := _flag(params, "open", true)
	var stain := conc.darkened(0.34)

	# Footing.
	b.box(Vector3(0, 0.10, 0), Vector3(1.72, 0.10, 1.12), conc.darkened(0.18))
	# Headwall, in two halves with a 0.70 m bay between them for the stoplogs.
	for sx in [-1.0, 1.0]:
		var xs: float = sx
		b.box(Vector3(xs * 0.98, 0.90, 0), Vector3(0.62, 0.80, 0.22), conc)
		# The algae collar every concrete face in a marsh has at the waterline.
		b.box(Vector3(xs * 0.98, 0.34, 0), Vector3(0.625, 0.20, 0.225), stain)
		# Slot guide channels, facing into the bay.
		b.box(Vector3(xs * 0.42, 0.95, 0), Vector3(0.060, 0.75, 0.26), conc.darkened(0.10))
		# Wingwalls, angled back upstream and stepping DOWN from the headwall.
		# The first pass had them as tall as the wall, splayed 0.55 and pushed
		# 0.34 upstream, and they read as two doors standing open rather than as
		# part of the structure. A wingwall is lower than what it wings.
		b.box(Vector3(xs * 1.62, 0.62, 0.16), Vector3(0.46, 0.52, 0.15), conc.darkened(0.06),
			Basis(Vector3.UP, xs * 0.40))

	# Stoplogs: four stacked timbers, the top one pulled if `open`. The gap is
	# the read — a full slot is a wall, a slot with one log out is a machine
	# somebody operates.
	var logs := 3 if open else 4
	for i in logs:
		var y := 0.32 + float(i) * 0.28
		b.box(Vector3(0, y, 0), Vector3(0.36, 0.13, 0.11), timber.lightened(0.04 * float(i)))
	var lip := 0.32 + float(logs) * 0.28 - 0.14

	# The catwalk: joists, then grating bars with real gaps, then a kick rail.
	b.box(Vector3(0, WEIR_DECK_Y - 0.075, 0), Vector3(1.50, 0.045, 0.40), C_STEEL)
	var bars := 13
	for i in bars:
		var z := -0.40 + (float(i) + 0.5) * (0.80 / float(bars))
		b.box(Vector3(0, WEIR_DECK_Y - 0.018, z), Vector3(1.48, 0.018, 0.022),
			C_STEEL.lightened(0.10))
	for sz in [-1.0, 1.0]:
		var zs: float = sz
		b.box(Vector3(0, WEIR_DECK_Y + 0.02, zs * 0.41), Vector3(1.50, 0.045, 0.016),
			C_STEEL.darkened(0.10))
	# Handrails, 0.95 above the deck, both sides.
	for sz2 in [-1.0, 1.0]:
		var zs2: float = sz2
		for sx2 in [-1.0, 1.0]:
			var xs2: float = sx2
			_strut(b, Vector3(xs2 * 1.32, WEIR_DECK_Y, zs2 * 0.40),
				Vector3(xs2 * 1.32, WEIR_DECK_Y + 0.95, zs2 * 0.40), 0.024, C_GALV)
		_strut(b, Vector3(-1.32, WEIR_DECK_Y + 0.95, zs2 * 0.40),
			Vector3(1.32, WEIR_DECK_Y + 0.95, zs2 * 0.40), 0.024, C_GALV)
		_strut(b, Vector3(-1.32, WEIR_DECK_Y + 0.52, zs2 * 0.40),
			Vector3(1.32, WEIR_DECK_Y + 0.52, zs2 * 0.40), 0.019, C_GALV)

	# The screw stem stand and its handwheel — the icon of the whole object.
	for sx3 in [-1.0, 1.0]:
		var xs3: float = sx3
		_strut(b, Vector3(xs3 * 0.16, WEIR_DECK_Y, 0.0), Vector3(xs3 * 0.10, 2.32, 0.0),
			0.026, C_GALV)
	b.box(Vector3(0, 2.40, 0), Vector3(0.13, 0.10, 0.11), C_STEEL)
	# The stem itself, running down through the deck into the bay.
	_cyl(b, Vector3(0, 2.40, 0), Vector3(0, lip + 0.10, 0), 0.026, 0.026, 6, C_GALV)
	# Handwheel: eight rim segments and four spokes, which is a wheel at this
	# scale and costs nothing.
	var wc := Vector3(0, 2.62, 0)
	for i in 8:
		var a0 := TAU * float(i) / 8.0
		var a1 := TAU * float(i + 1) / 8.0
		_strut(b, wc + Vector3(cos(a0) * 0.20, 0, sin(a0) * 0.20),
			wc + Vector3(cos(a1) * 0.20, 0, sin(a1) * 0.20), 0.020, C_GALV.darkened(0.10))
	for i in 4:
		var a := TAU * float(i) / 4.0 + 0.4
		_strut(b, wc, wc + Vector3(cos(a) * 0.20, 0, sin(a) * 0.20), 0.014, C_GALV)
	b.box(wc, Vector3(0.045, 0.035, 0.045), C_STEEL)

	# ── the spill ───────────────────────────────────────────────────────────
	# Water going over the top log, on the haze material. This is what makes
	# the structure read as DOING something rather than being a lump of
	# concrete in a pond.
	var spill_top := Vector3(0, lip, -0.11)
	w.quad(Vector3(-0.34, lip, -0.12), Vector3(0.34, lip, -0.12),
		Vector3(0.36, 0.24, -0.52), Vector3(-0.36, 0.24, -0.52), C_SPILL,
		spill_top + Vector3(0, 0, 2.0))
	# The white water where it lands — AT the surface, not under it.
	#
	# This model is anchored on the marsh BED and the zone places it at
	# `WEIR_AT.y = BED_Y = -0.30` with `WATER_Y = 0.0`, so local y = 0.30 IS the
	# waterline. The splash used to span local 0.20..0.26: four to ten
	# centimetres beneath an opaque water plane, i.e. never drawn. The comment
	# above calls the spill "what makes the structure read as DOING something
	# rather than being a lump of concrete in a pond", and the half of it that
	# says the water is arriving was the half that was invisible.
	#
	# Now 0.30..0.36, so it breaks the surface. The falling sheet above it is
	# left alone: a sheet that runs a few centimetres past the waterline is what
	# water pouring INTO water looks like.
	w.quad(Vector3(-0.44, 0.36, -0.50), Vector3(0.44, 0.36, -0.50),
		Vector3(0.52, 0.30, -0.90), Vector3(-0.52, 0.30, -0.90),
		Color(0.95, 0.94, 0.94, 0.30), Vector3(0, -2.0, -0.7))


# ===========================================================================
# 10. REFUGE ENTRANCE SIGN — brown and white, with room for a name
# ===========================================================================
#
# The US Fish & Wildlife Service sign: a brown field, a white keyline, the
# flying-goose emblem on the left, and the refuge's name to the right of it.
# It is the single object that tells the player where they are, and its shape
# is recognisable from the road before a word of it is legible — which is why
# the white border is geometry rather than a texture.
#
# THE NAME IS NOT IN HERE. Ask text_field(&"refuge_sign") and paint it from the
# zone; the recipe is in the LETTERING section above. Leave room: the field is
# 1.72 m wide, which is 15 characters at h = 0.20 through the truckstop font.

static func _refuge_sign(b: RefCounted, params: Dictionary) -> void:
	var wood := _col(params, "colour", C_TIMBER)
	var brown := _col(params, "trim_colour", C_REFUGE_BROWN)
	var panel_c := Vector3(0, 1.42, 0)

	for sx in [-1.0, 1.0]:
		var xs: float = sx
		b.box(Vector3(xs * 1.05, 0.95, 0.06), Vector3(0.065, 0.95, 0.065), wood)
		_post_cap(b, Vector3(xs * 1.05, 1.90, 0.06), 0.065, 0.065, 0.060, wood)

	# Carcass, white keyline, brown field. Each a little in front of the last.
	b.box(panel_c, Vector3(1.24, 0.52, 0.045), brown.darkened(0.25))
	b.box(panel_c + Vector3(0, 0, -0.048), Vector3(1.20, 0.48, 0.006), C_SIGN_WHITE)
	b.box(panel_c + Vector3(0, 0, -0.056), Vector3(1.13, 0.41, 0.005), brown)

	# ── the flying goose ────────────────────────────────────────────────────
	# The Service's emblem, at sign scale. Rotated boxes rather than flat
	# plates, because a box renders from every side and a 4 mm plate is a coin
	# toss on winding.
	#
	# IT IS AT +X, AND THAT IS THE READER'S *LEFT*. The face normal is -Z and
	# up is +Y, so screen-right is up.cross(normal) = (0,1,0) x (0,0,-1) =
	# (-1,0,0). The first pass put the emblem at -0.86 "on the left" and it came
	# out on the right of every render. This is the same mirror rule that has
	# shipped "POTS" in this project, in its other guise.
	var e := Vector3(0.86, 1.42, -0.062)
	# Body.
	b.box(e, Vector3(0.088, 0.032, 0.004), C_SIGN_WHITE)
	# Tail, swept back (-X) and down.
	b.box(e + Vector3(-0.105, -0.014, 0.0), Vector3(0.040, 0.017, 0.004), C_SIGN_WHITE,
		Basis(Vector3.BACK, -0.30))
	# Neck, rising forward (+X), then the head and bill.
	b.box(e + Vector3(0.098, 0.040, 0.0), Vector3(0.060, 0.017, 0.004), C_SIGN_WHITE,
		Basis(Vector3.BACK, 0.58))
	b.box(e + Vector3(0.158, 0.082, 0.0), Vector3(0.027, 0.020, 0.004), C_SIGN_WHITE)
	b.box(e + Vector3(0.196, 0.076, 0.0), Vector3(0.017, 0.009, 0.004), C_SIGN_WHITE)
	# Wings, both swept back: the upper one long and shallow, the lower one
	# shorter and steeper. Two symmetric wings and a stub head is not a goose,
	# it is an arrowhead — which is exactly what the first render produced.
	b.box(e + Vector3(-0.048, 0.086, 0.0), Vector3(0.118, 0.027, 0.004), C_SIGN_WHITE,
		Basis(Vector3.BACK, -0.52))
	b.box(e + Vector3(-0.040, -0.082, 0.0), Vector3(0.098, 0.025, 0.004), C_SIGN_WHITE,
		Basis(Vector3.BACK, 0.62))

	# A weathered timber apron under the panel, where a refuge bolts the hours.
	b.box(Vector3(0, 0.82, 0.02), Vector3(1.10, 0.055, 0.030), wood.darkened(0.12))


# ===========================================================================
# 11. NEST BOX — the cheapest possible "this is a wildlife refuge"
# ===========================================================================
#
# A wood duck box on a post out in the water, with a galvanised predator cone
# under it. One of these in frame does more to establish the place than any
# amount of geometry, and it is forty triangles.

static func _nest_box(b: RefCounted, params: Dictionary) -> void:
	var wood := _col(params, "colour", C_TIMBER)
	var wet := _col(params, "trim_colour", C_TIMBER_WET)

	# Post, wet for the first 0.7 m.
	b.box(Vector3(0, 0.35, 0), Vector3(0.052, 0.35, 0.052), wet)
	b.box(Vector3(0, 1.28, 0), Vector3(0.048, 0.58, 0.048), wood)

	# Predator guard: an inverted galvanised cone. Looked at from underneath by
	# anything shorter than a goose, so it is lofted inward as well.
	var g_hi := LPB.ring(Vector3(0, 1.14, 0), Vector3.UP, Vector3.FORWARD, 0.085, 0.085, 8, 0.0)
	var g_lo := LPB.ring(Vector3(0, 0.82, 0), Vector3.UP, Vector3.FORWARD, 0.335, 0.335, 8, 0.0)
	b.loft([g_hi, g_lo], [Vector3(0, 1.14, 0), Vector3(0, 0.82, 0)], C_GALV)
	_loft_inward(b, [g_hi, g_lo], [Vector3(0, 1.14, 0), Vector3(0, 0.82, 0)],
		C_GALV.darkened(0.30))
	_cap_axial(b, g_hi, Vector3(0, 1.17, 0), Vector3.UP, C_GALV.lightened(0.08))

	# The box.
	b.box(Vector3(0, 2.13, 0), Vector3(0.155, 0.30, 0.135), wood.lightened(0.04))
	# Sloped roof with a front overhang, hinged at the back.
	b.box(Vector3(0, 2.455, -0.02), Vector3(0.200, 0.020, 0.185), wood.darkened(0.10),
		Basis(Vector3.RIGHT, -0.20))
	# The entrance: an oval hole, recessed and near-black, on the -Z face.
	b.box(Vector3(0, 2.26, -0.138), Vector3(0.052, 0.038, 0.014), Color(0.06, 0.06, 0.06))
	# Kerf grooves under the hole — the ladder that lets a duckling climb out.
	for i in 3:
		b.box(Vector3(0, 2.13 - float(i) * 0.045, -0.137), Vector3(0.038, 0.006, 0.008),
			wood.darkened(0.30))
	# Side latch and hinge.
	b.box(Vector3(0.157, 2.02, 0.0), Vector3(0.012, 0.028, 0.020), C_STEEL)
	b.box(Vector3(0, 2.42, 0.140), Vector3(0.070, 0.014, 0.012), C_STEEL)
	# A perch rail, because a real one has one and because the zone will want
	# somewhere for one idle goose to be absurdly perched.
	b.box(Vector3(0, 2.36, -0.150), Vector3(0.090, 0.012, 0.012), wood.darkened(0.16))


# ===========================================================================
# 12. MIST BANK — the zone's signature image, and the reason for the haze pass
# ===========================================================================
#
# "Dawn. Mist on the water, low pink light" (CAMPAIGN_SPEC.md:485). This is
# four overlapping alpha sheets, each a wobbled polygon, each slightly domed so
# it catches the light differently from the one under it, stacked from y = 0.10
# to y = 0.72.
#
# HOW THE ZONE USES IT: scatter eight or ten of these across the open water,
# each with its own `variant`, and drift them at 0.15-0.35 m/s on independent
# headings. Do NOT put them on the goose's own y — mist that is at eye height
# is fog, and fog belongs in the WorldEnvironment where it costs nothing.
#
# It is on the CULL_DISABLED haze material specifically so the goose can walk
# and swim THROUGH a bank and it still exists from the other side.

static func _mist_bank(w: RefCounted, params: Dictionary) -> void:
	var col := _col(params, "colour", C_MIST)
	var seed_v := _num(params, "variant", 0.0)
	var layers := [
		[0.10, 5.30, 1.00],
		[0.26, 4.60, 0.82],
		[0.46, 3.70, 0.62],
		[0.72, 2.80, 0.44],
	]
	for li in range(layers.size()):
		var row: Array = layers[li]
		var y: float = row[0]
		var r: float = row[1]
		var a: float = row[2]
		var c := Vector3(0.55 * _wobble(li, 1, seed_v), y, 0.55 * _wobble(li, 2, seed_v))
		var ring := _rough_ring(c, r, 9, float(li) * 0.61 + seed_v, seed_v, li + 2, 0.24, 0.05)
		var tint := Color(col.r, col.g, col.b, col.a * a)
		# Domed very slightly, so the four layers do not z-fight into one flat
		# grey disc when the camera drops to water level.
		_cap_axial(w, ring, c + Vector3(0, 0.07, 0), Vector3.UP, tint)


# ===========================================================================
# FALLBACK
# ===========================================================================
#
# An unknown kind still builds something. Nothing in the world is ever
# invisible, because an invisible prop is a bug that survives a render pass.

static func _fallback(b: RefCounted, params: Dictionary) -> void:
	var col := _col(params, "colour", C_TIMBER)
	var lo := _ring_y(0.0, 0.28, 0.28, 0.045)
	var hi := _ring_y(0.56, 0.28, 0.28, 0.045)
	b.loft([lo, hi], [Vector3.ZERO, Vector3(0, 0.56, 0)], col)
	_cap_axial(b, hi, Vector3(0, 0.57, 0), Vector3.UP, col.lightened(0.10))
	_cap_axial(b, lo, Vector3(0, -0.01, 0), Vector3.DOWN, col.darkened(0.24))
