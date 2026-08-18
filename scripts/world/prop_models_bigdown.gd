extends RefCounted
## BIG DOWN MODEL LIBRARY — the distribution centre across the interstate.
##
## Same idiom and the same public API as the other four prop libraries:
##
##     PropModelsBigdown.build(kind, parent, params) -> Node3D
##     PropModelsBigdown.has_model(kind) -> bool
##     PropModelsBigdown.footprint(kind, params) -> Vector3
##     PropModelsBigdown.mesh_for(kind, params) -> ArrayMesh
##
## Plus three things no other library has needed, because no other library has
## had to hand a *building* to somebody else's encounter script:
##
##     PropModelsBigdown.collider_boxes(kind, params) -> Array[Dictionary]
##     PropModelsBigdown.climb_ramps(kind, params) -> Array[Dictionary]
##     PropModelsBigdown.shutter_set_closed(model, t)
##
## Polygons only. No SphereMesh, no CylinderMesh, no curved primitives. All
## colour lives in VERTEX COLOURS against three white materials, so the whole
## warehouse is three draw materials and a per-face paint decision is free.
##
## ---------------------------------------------------------------------------
## THE ANCHORING CONTRACT — identical to the other four libraries
## ---------------------------------------------------------------------------
## Every model here is BASE-ANCHORED: local origin on the ground at the centre
## of the footprint, growing up +Y. BoxShape3D colliders are CENTRED. So a model
## hung under a collider of height h always drops by -h * 0.5. Miss it and the
## whole lot hovers. `down_bale` is the one that matters — it is wrapped in a
## ChaosProp by the encounter, and ChaosProp.setup() cannot see this file
## (chaos_prop.gd preloads prop_models.gd and nothing else), so the encounter
## must build the model itself, hide the graybox, and repoint `p._visual`.
##
## ---------------------------------------------------------------------------
## THIS LIBRARY BUILDS NO COLLIDERS, AND THAT IS WHY collider_boxes() EXISTS
## ---------------------------------------------------------------------------
## A model library returns meshes. A warehouse is only interesting if you can
## get inside it and land on top of it, which is collision, which is the zone's
## job. The obvious failure mode is the encounter agent eyeballing wall
## positions off this file's constants and getting one of them wrong by the
## wall thickness — at which point the goose walks through a wall in exactly one
## corner and nobody finds it for three builds.
##
## So the warehouse and atrium layouts are computed ONCE, in `_warehouse_boxes`
## and `_atrium_boxes`, and both the mesh builder and `collider_boxes()` read
## the same array. They cannot drift. Same argument for `climb_ramps()`: the
## visual treads and the ramp collider come off one call to `_atrium_flights`.
##
## The treads are DECORATION. A CharacterBody3D does not climb a 0.18 m riser —
## the vertical face of a step is a 90° wall and the goose stops dead against
## it — so the ramp from `climb_ramps()` is not optional dressing, it IS the
## stair. zone_cottage.gd:877 already ships exactly this trick and calls it
## "a ramp collider with step decals".
##
## ---------------------------------------------------------------------------
## SIZES, ARGUED AGAINST THE GOOSE
## ---------------------------------------------------------------------------
## The goose is a 1.10 m capsule of radius 0.34 (goose_controller.gd:96-98) and
## ONE FLAP IS 1.86 m of altitude (flap_impulse² / 2·glide_gravity = 6.4²/22).
## Every vertical number below was picked against that and not against a
## photograph of a real distribution centre.
##
##   Dock height 1.15 m. Not the American standard 1.22 m: the truck stop's
##   trailer deck is at exactly 1.15 (prop_models_truckstop.gd:581), so a rig
##   backed onto this dock has a floor flush with the apron, and the "ride one
##   in on a trailer" route works without a lip. That agreement is worth more
##   than the 7 cm of realism it costs. It is also 0.6 of a flap, so a goose
##   gets onto the dock from the yard without the ramp — the ramp is for a
##   goose that has spent its stamina, not a goose that has not found it.
##
##   Rack level pitch 1.70 m, first beam at 1.80 m. Deliberately under one
##   flap. A goose can climb the racking one level per flap, which turns six
##   levels of inventory into a ladder instead of a wall, and it is the reason
##   the top of the racking is reachable at all without the atrium.
##
##   Warehouse clear height 11.0 m. Six flaps. Nobody flaps six times in a row
##   from the floor, and they should not: this is a room you cross, not a room
##   you climb. The 11 m is there so the racking reads as "racked to the
##   ceiling" and so the roof — which the leg ends on — is somewhere you arrive
##   from the atrium rather than somewhere you hop onto.
##
##   Atrium floor-to-floor 3.60 m, four storeys, roof deck at 14.40 m, parapet
##   to 15.60 m. 3.60 is a real office floor-to-floor (2.9 clear + 0.7 of slab
##   and plenum) and it is 1.94 flaps: a goose standing on floor N CANNOT reach
##   floor N+1 in one flap, ever, by five centimetres. That number is the whole
##   encounter. It is why the stair is load-bearing, why a man with a briefcase
##   can outrun a bird up four flights, and why breaking the curtain wall from
##   outside and gliding in is a genuine shortcut rather than a flourish. Four
##   metres per storey would have been 16 m and nine flaps, and a goose that
##   simply cannot participate in the vertical is a goose watching a cutscene.
##
##   Stair pitch 31.0° (3.60 m rise over the 6.00 m atrium void). The cottage's
##   two shipped, played flights are 31.6° and 27.8° (zone_cottage.gd:849-863),
##   so this is inside the range the controller is already known to handle.
##
##   Curtain-wall module 1.72 m (a 1.60 m pane in a 0.06 mullion each side).
##   The honk's radius is 7.5 m at pitch 1.0 (honk.gd:8), so a single honk
##   stands in front of about eight modules. That is the size of the hole.
##
## ---------------------------------------------------------------------------
## THE COLOUR THAT IS NOT NEGOTIABLE
## ---------------------------------------------------------------------------
## C_DOWN is Color(0.94, 0.94, 0.92) and it is the colour of Juice's
## `&"feathers"` burst — the one the game has spent on faceplants, wire strikes
## and WAYNE IS DOWN for six legs (juice.gd:134). The bales are that colour
## because they are that thing. Do not tune it toward "warehouse white" or
## "plastic wrap" or anything else; the equivalence is the entire joke and it is
## delivered by a particle system that shipped months ago.
##
## Everything else is the truck stop's palette, because this is the truck stop's
## night: C_SODIUM off the lot, C_CANOPY for the only cold light, C_ASPHALT for
## the wet. The warehouse interior is dark and stays dark. The racking lights
## are the only reason you can see the inventory, which is correct, because at
## 3 a.m. they are the only reason anybody could.
##
## ---------------------------------------------------------------------------
## THE THIRD MATERIAL
## ---------------------------------------------------------------------------
## `b` is the shell (shaded, wet, metallic 0.12 like the truck stop's).
## `e` is the glow shell (UNSHADED — at this ambient a pale lit quad that is
##     merely *lit* renders as a grey rectangle).
## `g` is the GLASS shell: unshaded, TRANSPARENCY_ALPHA, CULL_DISABLED,
##     DEPTH_DRAW_OPAQUE_ONLY. Copied from prop_models_finale.gd:107-120, which
##     is the only other place in the project that needed it. Depth WRITE is off
##     and depth TEST stays on: four storeys of curtain wall that each wrote
##     depth would punch holes in each other, and glass that ignored depth
##     entirely would draw straight through the racking behind it.
##
## Each is only attached when it has triangles. An empty SurfaceTool commits to
## null and a MeshInstance3D with a null mesh is a silent per-frame cost.
##
## ---------------------------------------------------------------------------
## WHY THE GLASS PANE IS A VISUAL AND NOTHING ELSE
## ---------------------------------------------------------------------------
## Because a pane of glass modelled as a rigid body falls over the moment the
## physics starts. zone_truckstop.gd:1001-1006 says so in as many words and the
## diner's five windows are a StaticBody3D + an unshaded quad + a trigger Area3D
## for exactly that reason. `&"glass_pane"` here is the quad and the frame. The
## collider, the trigger, the group membership and the break belong to the
## encounter, and it should copy `_diner_panes` / `_break_pane` rather than
## invent a second glass system.
##
## ---------------------------------------------------------------------------
## DETERMINISM
## ---------------------------------------------------------------------------
## No randf()/randi() anywhere. The build verification renders and compares
## frames, so a random number in here is a bug that only appears in a diff.
## Every irregularity is `_wobble()`, a sin×cos of the two indices and a seed.

## Preloaded rather than referenced by class_name: global class registration
## only exists after an editor import pass, so a `class_name` reference breaks
## in a fresh checkout or a headless CI run. A preload const always resolves.
const LPB := preload("res://scripts/goose/lowpoly_builder.gd")

## The ONE cross-library dependency in this file, and it is deliberate.
##
## prop_models_truckstop.gd owns the project's only correct lettering path: a
## 4x5 bitmap font and a `sign_text()` that computes screen-right as
## `up × normal` instead of assuming +X. This project has shipped a stop sign
## reading POTS and a trailer reading ƎƆIVЯƎƧ, both from that one line. A fill
## power number and a lot code stencilled backwards on ten thousand bales would
## be the third.
##
## Only the PUBLIC surface is touched — `sign_text` and `text_width`, both
## documented at the top of that file as its public API. Every private helper
## (_far_ref, _cap_axial, _cyl, _strut, _wobble) is re-declared below instead,
## per the policy at prop_models_truckstop.gd:380-387: forty duplicated lines
## are cheaper than a coupling nobody expects.
const TS := preload("res://scripts/world/prop_models_truckstop.gd")


# ---------------------------------------------------------------------------
# Palette. The truck stop's, plus the one colour that is an argument.
# ---------------------------------------------------------------------------

const C_SODIUM := Color(1.00, 0.62, 0.22)     ## the lot, seen from in here
const C_CANOPY := Color(0.86, 0.92, 1.00)     ## the only cold light in the zone
const C_ASPHALT := Color(0.130, 0.125, 0.135) ## wet
const C_DOWN := Color(0.94, 0.94, 0.92)       ## Juice's &"feathers". Do not change.
const C_DARK := Color(0.145, 0.150, 0.165)    ## the warehouse skin at 3 a.m.
const C_CONCRETE := Color(0.285, 0.285, 0.295)
const C_STEEL := Color(0.42, 0.44, 0.47)
const C_GLASS := Color(0.50, 0.68, 0.66, 0.30)


# ---------------------------------------------------------------------------
# The numbers the encounter will need. Public on purpose — an encounter that
# re-derives the dock height from a screenshot gets it wrong by 7 cm and the
# trailer route stops working.
# ---------------------------------------------------------------------------

const FLAP := 1.86            ## one flap of altitude, for arguing with
const DOCK_Y := 1.15          ## dock/apron top = the truck stop's trailer deck
const DOOR_W := 2.80          ## dock door clear opening
const DOOR_H := 3.10
const DOOR_PITCH := 5.60      ## dock door centre-to-centre

const RACK_BAY := 2.70        ## racking bay width, upright centre to centre
const RACK_DEPTH := 1.10      ## racking frame depth
const RACK_FIRST := 1.80      ## first beam level — just under one flap
const RACK_LEVEL := 1.70      ## beam pitch above that — also under one flap

const WH_W := 40.0            ## warehouse default outside width
const WH_D := 30.0            ## warehouse default outside depth
const WH_H := 11.0            ## warehouse roof deck height (walkable)
const WH_WALL := 0.30

const AT_W := 14.0            ## atrium default outside width
const AT_D := 12.0
const AT_FLOOR := 3.60        ## floor to floor. 1.94 flaps. See the header.
const AT_VOID_W := 6.00       ## the atrium hole in every slab
const AT_VOID_D := 6.00
const AT_SLAB := 0.30
const STAIR_W := 1.60

const PANE_W := 1.60          ## curtain-wall pane, glass only
const PANE_H := 2.40
const MULLION := 0.06         ## frame each side
const MODULE := 1.72          ## PANE_W + 2 * MULLION — the curtain-wall grid


# ---------------------------------------------------------------------------
# Registry
# ---------------------------------------------------------------------------

## Bounding footprint of each model, base-anchored: (width_x, height_y, depth_z).
##
## The five parametric kinds carry their DEFAULT size here and are recomputed
## from params by footprint() — same trick prop_models.gd:59-110 plays with
## &"house", for the same reason: every one of them is a different size every
## time it is placed.
const FOOTPRINTS := {
	&"down_bale": Vector3(1.20, 0.90, 0.90),
	&"racking": Vector3(8.20, 10.40, 1.10),
	&"aisle_light": Vector3(0.86, 1.40, 0.86),
	&"glass_pane": Vector3(1.72, 2.52, 0.12),
	&"roller_shutter": Vector3(3.64, 3.62, 0.62),
	&"dock_door": Vector3(3.70, 4.65, 0.66),
	&"dock_apron": Vector3(9.00, 2.10, 8.60),
	&"warehouse_shell": Vector3(40.00, 12.20, 30.00),
	&"atrium_shell": Vector3(14.00, 15.60, 12.00),
	&"lit_skyline_box": Vector3(16.00, 20.35, 14.00),
	&"fill_power_sign": Vector3(1.60, 2.10, 0.22),
	&"briefcase": Vector3(0.46, 0.40, 0.14),
}


## True if [param kind] has a dedicated model here. Unknown kinds still build —
## they get a faceted crate, so nothing in the world is ever invisible — but a
## caller deciding which library owns a kind should test this first.
static func has_model(kind: StringName) -> bool:
	return FOOTPRINTS.has(kind)


## Base-anchored bounding size of [param kind], derived from `params` for the
## parametric kinds.
static func footprint(kind: StringName, params := {}) -> Vector3:
	match kind:
		&"racking":
			var bays := maxi(1, _int(params, "bays", 3))
			var rh := _num(params, "height", 10.40)
			return Vector3(float(bays) * RACK_BAY + 0.10, rh, RACK_DEPTH)
		&"glass_pane":
			var pw := _num(params, "pane_w", PANE_W)
			var ph := _num(params, "pane_h", PANE_H)
			var fr := _num(params, "frame", MULLION)
			return Vector3(pw + fr * 2.0, ph + fr * 2.0, 0.12)
		&"roller_shutter":
			var sw := _num(params, "width", 3.20)
			var sh := _num(params, "height", 3.00)
			return Vector3(sw + 0.44, sh + 0.62, 0.62)
		&"dock_door":
			# NOT CENTRED IN Z, and it cannot be: this is dressing bolted to a
			# wall plane at z = 0 that grows toward -Z. Do not pass
			# params["size"] to it — the rescale assumes a centred footprint and
			# would drag the seal through the wall. The number below is the real
			# extent, for placement arithmetic only.
			var dw := _num(params, "width", DOOR_W)
			var dh := _num(params, "height", DOOR_H)
			var dy := _num(params, "dock_y", DOCK_Y)
			return Vector3(dw + 0.90, dy + dh + 0.40, 0.66)
		&"dock_apron":
			# Height is the BOUNDING height, which includes the 0.9 m safety
			# posts along the lip. The walking DECK is at `dock_y`, which is
			# what collider_boxes() returns and what the encounter wants.
			var aw := _num(params, "width", 9.00)
			var ad := _num(params, "depth", 5.20)
			var ay := _num(params, "dock_y", DOCK_Y)
			var run := _num(params, "ramp_run", 3.40)
			return Vector3(aw, ay + 0.95, ad + run)
		&"warehouse_shell":
			# +1.20 not +0.70: the parapet tops out at h + 0.70 but the roof
			# plant units are 1.12 m proud, and a footprint that forgets them
			# squashes the whole building when someone passes a size.
			return Vector3(
				_num(params, "width", WH_W),
				_num(params, "height", WH_H) + 1.20,
				_num(params, "depth", WH_D))
		&"atrium_shell":
			var floors := clampi(_int(params, "floors", 4), 1, 8)
			return Vector3(
				_num(params, "width", AT_W),
				float(floors) * _num(params, "floor_h", AT_FLOOR) + 1.20,
				_num(params, "depth", AT_D))
		&"lit_skyline_box":
			# +1.35 clears the aircraft warning lights on the parapet corners.
			return Vector3(
				_num(params, "width", 16.0),
				_num(params, "height", 19.0) + 1.35,
				_num(params, "depth", 14.0))
	if FOOTPRINTS.has(kind):
		var f: Vector3 = FOOTPRINTS[kind]
		return f
	return Vector3.ONE


# ---------------------------------------------------------------------------
# Materials
# ---------------------------------------------------------------------------

static var _shared_mat: StandardMaterial3D = null

## Same roughness and the same metallic fudge as the truck stop's: this is the
## same night and the same rain, forty metres further from the lamps.
static func shared_material() -> StandardMaterial3D:
	if _shared_mat == null:
		_shared_mat = LPB.make_material(0.62)
		_shared_mat.cull_mode = BaseMaterial3D.CULL_BACK
		_shared_mat.metallic = 0.12
	return _shared_mat


static var _glow_mat: StandardMaterial3D = null

## UNSHADED on purpose: the face renders at exactly its vertex colour whatever
## light reaches it, which is precisely "this surface is emitting". Inside an
## unlit warehouse that is the difference between a racking light and a grey
## rectangle glued to a beam.
static func glow_material() -> StandardMaterial3D:
	if _glow_mat == null:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color.WHITE
		m.vertex_color_use_as_albedo = true
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_BACK
		m.emission_enabled = true
		m.emission = Color(1, 1, 1)
		m.emission_energy_multiplier = 1.6
		_glow_mat = m
	return _glow_mat


static var _glass_mat: StandardMaterial3D = null

## The third material, and the whole reason the atrium can exist.
##
## CULL_DISABLED because you look at a curtain wall from both sides — from the
## lot at 3 a.m. and, forty seconds later, from inside it. DEPTH_DRAW_OPAQUE_ONLY
## because sixty panes that each wrote depth would punch holes in each other,
## while a pane that ignored depth entirely would draw through the racking.
## Copied wholesale from prop_models_finale.gd:107-120; this is the second and
## last place in the project that gets to do this.
static func glass_material() -> StandardMaterial3D:
	if _glass_mat == null:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color.WHITE
		m.vertex_color_use_as_albedo = true
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
		_glass_mat = m
	return _glass_mat


# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------

## Builds the model for [param kind] as a new "Model" Node3D under
## [param parent] and returns it.
##
## `params` keys, all optional:
##   size          Vector3  scale the model so its footprint matches this
##   colour        Color    the model's main colour
##   trim_colour   Color    secondary (frame, beams, slabs, straps)
##   glow_colour   Color    override the emissive colour
##   ink_colour    Color    stencilled lettering
##   lit           bool     lamps, racking lights, lit panes: emit or not
##   variant       float    deterministic shape seed
##   text / code   String   stencilled strings
##   plus the per-kind geometry keys documented on each builder below.
##
## Child node names, all load-bearing for the encounter:
##   "Shell"       the shaded mesh
##   "Glow"        the unshaded emissive mesh, only if there is one
##   "Glass"       the alpha mesh, only if there is one
##   "Sign"        stencilled lettering (from TS.sign_text)
##   "Curtain"     roller_shutter only — the moving part, see shutter_set_closed
##   "Strobe"      roller_shutter only — the 0.9 s amber telegraph, starts hidden
##   "FloorLights" atrium_shell only — holds "Bank0".."BankN", one per storey
##   "LitWindow"   atrium_shell only — the one lit window at the top
static func build(kind: StringName, parent: Node3D, params := {}) -> Node3D:
	var model := Node3D.new()
	model.name = "Model"
	parent.add_child(model)

	var b: RefCounted = LPB.new()
	var e: RefCounted = LPB.new()   ## the glow builder — unshaded
	var g: RefCounted = LPB.new()   ## the glass builder — alpha, unshaded
	_dispatch(kind, b, e, g, params)

	model.set_meta("tri_count", b.tri_count + e.tri_count + g.tri_count)
	if b.tri_count > 0:
		LPB.attach(model, b.commit(), shared_material(), "Shell")
	if e.tri_count > 0:
		LPB.attach(model, e.commit(), glow_material(), "Glow")
	if g.tri_count > 0:
		LPB.attach(model, g.commit(), glass_material(), "Glass")

	# Sub-nodes that have to move, blink or be switched off independently, plus
	# every stencilled string. Anything in the single "Shell" mesh is welded to
	# everything else in it; anything the encounter needs a handle on lives here.
	_post_build(kind, model, params)

	if params.has("size"):
		var want: Vector3 = params["size"]
		var have := footprint(kind, params)
		model.scale = Vector3(
			want.x / maxf(have.x, 0.001),
			want.y / maxf(have.y, 0.001),
			want.z / maxf(have.z, 0.001))
	return model


## The raw shaded mesh for [param kind], for MultiMeshInstance3D.
##
## Returns only the shell — a MultiMesh has exactly one mesh and one material,
## so a kind with a glow or glass shell cannot be instanced this way. In
## practice this is for `&"racking"` with `{"lit": false}` repeated down an
## aisle; a lit rack has to be N MeshInstance3Ds or the strip lights vanish.
static func mesh_for(kind: StringName, params := {}) -> ArrayMesh:
	var b: RefCounted = LPB.new()
	var e: RefCounted = LPB.new()
	var g: RefCounted = LPB.new()
	_dispatch(kind, b, e, g, params)
	return b.commit()


static func _dispatch(kind: StringName, b: RefCounted, e: RefCounted, g: RefCounted,
		params: Dictionary) -> void:
	match kind:
		&"down_bale":
			_down_bale(b, e, g, params)
		&"racking":
			_racking(b, e, g, params)
		&"aisle_light":
			_aisle_light(b, e, g, params)
		&"glass_pane":
			_glass_pane(b, e, g, params)
		&"roller_shutter":
			_roller_shutter(b, e, g, params)
		&"dock_door":
			_dock_door(b, e, g, params)
		&"dock_apron":
			_dock_apron(b, e, g, params)
		&"warehouse_shell":
			_warehouse_shell(b, e, g, params)
		&"atrium_shell":
			_atrium_shell(b, e, g, params)
		&"lit_skyline_box":
			_lit_skyline_box(b, e, g, params)
		&"fill_power_sign":
			_fill_power_sign(b, e, g, params)
		&"briefcase":
			_briefcase(b, e, g, params)
		_:
			_fallback(b, e, g, params)


static func _post_build(kind: StringName, model: Node3D, params: Dictionary) -> void:
	match kind:
		&"down_bale":
			_bale_stencil(model, params)
		&"fill_power_sign":
			_sign_board_text(model, params)
		&"dock_door":
			_dock_door_text(model, params)
		&"roller_shutter":
			_shutter_parts(model, params)
		&"atrium_shell":
			_atrium_parts(model, params)


# ---------------------------------------------------------------------------
# Typed parameter access.
#
# Dictionary lookups are Variant, so `var x := params.get(...)` is a parse error
# ("Cannot infer the type of x"). Funnelling every read through these five
# helpers keeps that mistake out of the twelve build functions below.
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


static func _int(params: Dictionary, key: String, fallback: int) -> int:
	var v = params.get(key, fallback)
	if v is int or v is float:
		return int(v)
	return fallback


static func _flag(params: Dictionary, key: String, fallback: bool) -> bool:
	var v = params.get(key, fallback)
	if v is bool:
		return v
	return fallback


static func _str(params: Dictionary, key: String, fallback: String) -> String:
	var v = params.get(key, fallback)
	if v is String:
		return v
	if v is StringName:
		return String(v)
	return fallback


# ---------------------------------------------------------------------------
# Geometry helpers.
#
# Re-implemented here rather than reached for across a preload into the other
# libraries: those are underscore-private statics on files this one has no other
# reason to depend on, and forty duplicated lines are cheaper than a coupling
# nobody expects. Same call the cottage, corn, truckstop and finale libraries
# each made in turn.
# ---------------------------------------------------------------------------

## Deterministic pseudo-noise in roughly [-1, 1]. Stands in for randf() so the
## lumpy things stay bit-identical between runs, because the build verification
## renders frames and diffs them.
static func _wobble(a: int, c: int, seed_v: float) -> float:
	return sin(float(a) * 2.399 + float(c) * 1.117 + seed_v * 3.77) \
		* cos(float(a) * 0.813 - float(c) * 1.937 + seed_v * 1.31)


static func _centroid(r: PackedVector3Array) -> Vector3:
	var c := Vector3.ZERO
	for v in r:
		c += v
	return c / float(maxi(r.size(), 1))


## A point far enough behind [param r] along -axis_dir that every face of the
## ring agrees on which way is out.
##
## LowPolyBuilder picks a face's winding from dot(normal, centroid - inside). On
## a near-flat fan the normal is almost axial while (centroid - inside) is
## dominated by the RADIUS, so a reference one metre behind a one-metre disc
## leaves the sign of that dot product up to which side of the ring the face
## happens to sit on — and the disc renders along exactly half a diameter. Put
## the reference two hundred radii away and the axial term wins every time.
## This cost the original art pass two render rounds; it is repeated in every
## library because it would cost each of them the same two.
static func _far_ref(r: PackedVector3Array, axis_dir: Vector3) -> Vector3:
	var c := _centroid(r)
	var far := 0.0
	for v in r:
		far = maxf(far, (v - c).length())
	return c - axis_dir.normalized() * (far * 200.0 + 10.0)


static func _cap_axial(b: RefCounted, r: PackedVector3Array, apex: Vector3,
		axis_dir: Vector3, col: Color) -> void:
	b.cap(r, apex, _far_ref(r, axis_dir), col)


## Horizontal cross-section at height [param y]: a chamfered rectangle in XZ.
## A faceted box with square corners reads as a box no matter how you shade it,
## and one 3 cm chamfer per corner turns it into an object.
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


## A capped faceted tube between two points. Every bollard, stem, handrail and
## lock bar in this file is one of these.
static func _cyl(b: RefCounted, a: Vector3, c: Vector3, r: float, sides: int,
		col: Color, phase := 0.0) -> void:
	var d := c - a
	if d.length_squared() < 1e-8:
		return
	var dir := d.normalized()
	var up := Vector3.UP if absf(dir.y) < 0.92 else Vector3.FORWARD
	var r0 := LPB.ring(a, dir, up, r, r, sides, phase)
	var r1 := LPB.ring(c, dir, up, r, r, sides, phase)
	b.loft([r0, r1], [a, c], col)
	_cap_axial(b, r0, a - dir * r * 0.06, -dir, col.darkened(0.16))
	_cap_axial(b, r1, c + dir * r * 0.06, dir, col.lightened(0.04))


## A square-section strut between two arbitrary points, for anything that runs
## diagonally in two directions at once. All the racking bracing is this.
static func _strut(b: RefCounted, a: Vector3, c: Vector3, r: float, col: Color) -> void:
	_cyl(b, a, c, r, 4, col, PI * 0.25)


## A triangular prism whose TOP surface runs from (z0, y0) to (z1, y1), sitting
## on y = 0. Both ends are points ON the finished surface, same contract as
## zone_truckstop.gd's `_ramp()` — doing the trigonometry at the call site is
## how you get a lip the goose trips over.
##
## Built as six quads rather than a rotated box because a rotated box leaves a
## triangular void under the slope, which is invisible from above and a hole
## from every other angle. Degenerate faces (y0 == 0) are dropped silently by
## the builder, so a ramp that starts at grade costs two quads less.
static func _ramp_prism(b: RefCounted, x0: float, x1: float, z0: float, z1: float,
		y0: float, y1: float, col: Color) -> void:
	var a0 := Vector3(x0, y0, z0)
	var a1 := Vector3(x1, y0, z0)
	var a2 := Vector3(x1, y1, z1)
	var a3 := Vector3(x0, y1, z1)
	var e0 := Vector3(x0, 0.0, z0)
	var e1 := Vector3(x1, 0.0, z0)
	var e2 := Vector3(x1, 0.0, z1)
	var e3 := Vector3(x0, 0.0, z1)
	var inside := (a0 + a1 + a2 + a3 + e0 + e1 + e2 + e3) / 8.0
	b.quad(a0, a1, a2, a3, col, inside)                       # the slope
	b.quad(e0, e1, e2, e3, col.darkened(0.30), inside)        # underside
	b.quad(a0, a1, e1, e0, col.darkened(0.14), inside)        # the z0 end
	b.quad(a3, a2, e2, e3, col.darkened(0.10), inside)        # the z1 end
	b.quad(a0, a3, e3, e0, col.darkened(0.18), inside)        # -x flank
	b.quad(a1, a2, e2, e1, col.darkened(0.18), inside)        # +x flank


## A DOUBLE-SIDED quad: emitted twice at the same four corners with opposite
## winding, so it exists from both faces against a CULL_BACK material. A single
## quad is a sheet that vanishes the moment you walk round it — which for the
## escaped feathers on a bale, seen from every angle at once, is most of the
## time. Two coplanar faces with opposite winding do not z-fight, because from
## any viewpoint exactly one of them is front-facing.
static func _blade(b: RefCounted, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3,
		col: Color) -> void:
	var cen := (p0 + p1 + p2 + p3) * 0.25
	var n := (p1 - p0).cross(p3 - p0)
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	b.quad(p0, p1, p2, p3, col, cen - n)
	b.quad(p0, p1, p2, p3, col.darkened(0.16), cen + n)


## Vertical corrugation ribs across a flat face. `n` is the outward normal and
## must be axis-aligned; ribs run in Y and repeat along the face's other axis.
## Four hundred metres of blank steel panel has no scale until you do this.
static func _ribs(b: RefCounted, centre: Vector3, half_w: float, y0: float, y1: float,
		n: Vector3, pitch: float, depth: float, col: Color) -> void:
	var right := Vector3.UP.cross(n).normalized()
	var count := maxi(2, int(half_w * 2.0 / maxf(pitch, 0.05)))
	for i in count:
		var t := (float(i) + 0.5) / float(count) * 2.0 - 1.0
		b.box(centre + right * (t * half_w) + n * (depth * 0.5)
				+ Vector3(0.0, (y0 + y1) * 0.5, 0.0),
			Vector3(absf(right.x) * 0.045 + absf(n.x) * depth * 0.5 + 0.0,
				(y1 - y0) * 0.5,
				absf(right.z) * 0.045 + absf(n.z) * depth * 0.5 + 0.0),
			col)


# ===========================================================================
# 1. DOWN BALE — the best prop in the game, and the entire joke
# ===========================================================================
#
# 1.20 x 0.90 x 0.90 of compressed goose down under three poly straps, with a
# kraft label giving a fill power and a lot code and nothing else. mass_kg 22
# and the highest point value in the game are the encounter's numbers, not
# this file's; what this file owes is that it be SOFT — bulged, not boxy, so
# that a goose bouncing off it reads as bouncing off something that gave.
#
# Hence a five-ring loft rather than a b.box: the flanks swell by half a
# percent in the middle and the top ring pulls in, which is what a bale under
# strap tension actually does and is the difference between a bale and a crate.
#
# The colour is C_DOWN and it is Juice's &"feathers" burst exactly. Six legs of
# faceplants have been spending that colour on comedy. Here it is inventory.
# Nobody says a word about it and nobody should.

static func _down_bale(b: RefCounted, _e: RefCounted, _g: RefCounted, params: Dictionary) -> void:
	var down := _col(params, "colour", C_DOWN)
	var strap := _col(params, "trim_colour", Color(0.30, 0.33, 0.40))
	var seed_v := _num(params, "variant", 0.0)
	var hx := 0.60
	var hz := 0.45

	# ── the block ───────────────────────────────────────────────────────
	var ys := [0.015, 0.22, 0.50, 0.76, 0.892]
	var kk := [0.955, 1.000, 1.005, 0.985, 0.930]
	var rings := []
	var spine := []
	for i in ys.size():
		var yy: float = ys[i]
		var k: float = kk[i]
		var wob := 1.0 + 0.016 * _wobble(i, 3, seed_v)
		rings.append(_ring_y(yy, hx * k * wob, hz * k * wob, 0.075))
		spine.append(Vector3(0.0, yy, 0.0))
	b.loft(rings, spine, down)
	var top: PackedVector3Array = rings[rings.size() - 1]
	var bot: PackedVector3Array = rings[0]
	_cap_axial(b, top, Vector3(0.0, 0.900, 0.0), Vector3.UP, down.lightened(0.05))
	_cap_axial(b, bot, Vector3(0.0, 0.000, 0.0), Vector3.DOWN, down.darkened(0.24))

	# ── three straps, wrapped the short way: over the top and down both ends
	for i in 3:
		var sx := -0.34 + float(i) * 0.34 + 0.012 * _wobble(i, 2, seed_v)
		var tint := strap.lightened(0.06 * _wobble(i, 5, seed_v))
		b.box(Vector3(sx, 0.898, 0.0), Vector3(0.026, 0.012, 0.452), tint)
		# The under-strap sits at y 0.001..0.019, not straddling zero: a bale
		# dropped on a concrete floor would z-fight along its whole length.
		b.box(Vector3(sx, 0.010, 0.0), Vector3(0.026, 0.009, 0.452), tint.darkened(0.2))
		for sz in [-1.0, 1.0]:
			var zs: float = sz
			b.box(Vector3(sx, 0.450, zs * 0.456), Vector3(0.026, 0.450, 0.012), tint)
	# The ratchet buckle on the middle strap. One asymmetry stops three
	# identical straps reading as a printed texture.
	b.box(Vector3(0.0, 0.62, -0.462), Vector3(0.052, 0.062, 0.016),
		strap.lightened(0.34))

	# ── the label patch. The text goes on in _bale_stencil().
	b.box(Vector3(0.0, 0.585, -0.457), Vector3(0.40, 0.135, 0.006),
		Color(0.84, 0.80, 0.70))

	# ── escaped feathers. Four of them, at the seams, double-sided.
	for i in 4:
		var ax := 0.34 * _wobble(i, 9, seed_v)
		var az := 0.44 * (1.0 if i % 2 == 0 else -1.0)
		var lean := 0.10 + 0.05 * absf(_wobble(i, 13, seed_v))
		var base := Vector3(ax, 0.86 - 0.10 * absf(_wobble(i, 7, seed_v)), az)
		var tip := base + Vector3(0.03 * _wobble(i, 11, seed_v), lean, az * 0.16)
		_blade(b,
			base + Vector3(0.012, 0.0, 0.0), base - Vector3(0.012, 0.0, 0.0),
			tip - Vector3(0.004, 0.0, 0.0), tip + Vector3(0.004, 0.0, 0.0),
			down.lightened(0.03))


## The stencil. Two lines on the -Z face, through the truck stop's font, which
## is the only lettering path in this project that is not mirrored.
##
## Costs two extra MeshInstance3Ds per bale. A warehouse floor with forty loose
## bales is eighty meshes; pass {"stencil": false} on anything the player will
## only ever see from thirty metres.
static func _bale_stencil(model: Node3D, params: Dictionary) -> void:
	if not _flag(params, "stencil", true):
		return
	var ink := _col(params, "ink_colour", Color(0.20, 0.22, 0.28))
	var t1 := _str(params, "text", "850 FILL")
	var t2 := _str(params, "code", "LOT 4471")
	var n := Vector3(0.0, 0.0, -1.0)
	# Screen-right on this face. NOT +X — see the header of prop_models_truckstop.
	var right := Vector3.UP.cross(n)
	var h1 := 0.12
	var h2 := 0.075
	# sign_text names every mesh it makes "Sign", and two of them under one
	# parent means the engine renames the second to something nobody can look
	# up. Rename both to something the encounter can actually find.
	var m1 := TS.sign_text(model, t1,
		Vector3(0.0, 0.680, -0.464) - right * (TS.text_width(t1, h1) * 0.5),
		n, Vector3.UP, h1, ink, false, 0.010)
	if m1 != null:
		m1.name = "SignFill"
	var m2 := TS.sign_text(model, t2,
		Vector3(0.0, 0.530, -0.464) - right * (TS.text_width(t2, h2) * 0.5),
		n, Vector3.UP, h2, ink.lightened(0.10), false, 0.008)
	if m2 != null:
		m2.name = "SignLot"


# ===========================================================================
# 2. RACKING — six levels of the same thing, all the way up
# ===========================================================================
#
# Static scenery, never a ChaosProp: forty tonnes of selective pallet racking
# that a goose can shove is not a joke, it is a physics bug.
#
# The bay is 2.70 m and the frame is 1.10 m deep because that is what holds two
# 1.2 m pallets side by side, which is what a bale is. The beam pitch is the
# number that matters: 1.70 m, deliberately under one flap (1.86), so a goose
# climbs the racking one level per flap. Six storage levels then read as a
# ladder rather than as a wall, and the top of the rack is somewhere a player
# can actually get to without the atrium.
#
# `stock` fills every beam level with pale blocks. It defaults ON and it should
# stay on: the encounter puts real, breakable bales on the FLOOR, and the room
# only says what it needs to say if everything above head height is also down.

static func _racking(b: RefCounted, e: RefCounted, _g: RefCounted, params: Dictionary) -> void:
	var bays := maxi(1, _int(params, "bays", 3))
	var h := _num(params, "height", 10.40)
	var upright := _col(params, "colour", Color(0.58, 0.29, 0.12))
	var beam := _col(params, "trim_colour", Color(0.18, 0.32, 0.44))
	var stock := _flag(params, "stock", true)
	var lit := _flag(params, "lit", true)
	var glow := _col(params, "glow_colour", C_CANOPY)
	var seed_v := _num(params, "variant", 0.0)

	var levels := clampi(int((h - RACK_FIRST - 0.55) / RACK_LEVEL) + 1, 1, 8)
	var hx := (float(bays) * RACK_BAY + 0.10) * 0.5
	var hz := RACK_DEPTH * 0.5

	# ── frames: two uprights and their bracing, one line per bay boundary ──
	for f in bays + 1:
		var fx := -hx + 0.05 + float(f) * RACK_BAY
		for sz in [-1.0, 1.0]:
			var zs: float = sz
			b.box(Vector3(fx, h * 0.5, zs * (hz - 0.045)),
				Vector3(0.050, h * 0.5, 0.045), upright)
			b.box(Vector3(fx, 0.020, zs * (hz - 0.045)),
				Vector3(0.085, 0.020, 0.075), upright.darkened(0.30))
		# Zig-zag bracing between the two uprights of the frame. Three per
		# level, which is enough to read as a truss and cheap enough to repeat.
		var steps := levels * 2 + 2
		for i in steps:
			var y0 := 0.30 + float(i) * ((h - 0.60) / float(steps))
			var y1 := 0.30 + float(i + 1) * ((h - 0.60) / float(steps))
			var za := (hz - 0.06) * (1.0 if i % 2 == 0 else -1.0)
			_strut(b, Vector3(fx, y0, za), Vector3(fx, y1, -za), 0.020,
				upright.darkened(0.10))

	# ── beams, decking and stock, level by level ──────────────────────────
	for lv in levels:
		var by := RACK_FIRST + float(lv) * RACK_LEVEL
		for bay in bays:
			var cx := -hx + 0.05 + RACK_BAY * (float(bay) + 0.5)
			for sz2 in [-1.0, 1.0]:
				var zs2: float = sz2
				b.box(Vector3(cx, by, zs2 * (hz - 0.05)),
					Vector3(RACK_BAY * 0.5 - 0.055, 0.055, 0.035), beam)
			# Wire decking. Two cross slats per bay: any more and it is a floor.
			for k in 2:
				var kz := -hz + 0.34 + float(k) * 0.42
				b.box(Vector3(cx, by + 0.062, kz),
					Vector3(RACK_BAY * 0.5 - 0.07, 0.008, 0.020),
					beam.lightened(0.22))
			if stock:
				for s in 2:
					var sx := cx + (-0.62 + float(s) * 1.24)
					var wob := 1.0 + 0.03 * _wobble(lv * 7 + bay, s, seed_v)
					# A pallet, then the bale block on top of it. Both pale —
					# from the floor this is a white cliff, which is the point.
					b.box(Vector3(sx, by + 0.115, 0.0),
						Vector3(0.56, 0.045, 0.44), Color(0.44, 0.35, 0.24))
					b.box(Vector3(sx, by + 0.16 + 0.42 * wob, 0.0),
						Vector3(0.56, 0.42 * wob, 0.435),
						C_DOWN.darkened(0.06 + 0.05 * absf(_wobble(bay, lv, seed_v))))
					# Shrink wrap: one darker band round the middle.
					b.box(Vector3(sx, by + 0.16 + 0.42 * wob, -0.442),
						Vector3(0.55, 0.16, 0.010), Color(0.72, 0.74, 0.76))

	# ── the racking light: one strip under the top beam, facing the aisle ──
	var top_y := RACK_FIRST + float(levels - 1) * RACK_LEVEL
	b.box(Vector3(0.0, top_y + 0.16, -hz - 0.03),
		Vector3(hx * 0.92, 0.045, 0.035), C_STEEL.darkened(0.25))
	if lit:
		# In FRONT of the housing, not behind it: behind, the glow is inside an
		# opaque box and the rack is unlit.
		e.box(Vector3(0.0, top_y + 0.125, -hz - 0.05),
			Vector3(hx * 0.90, 0.022, 0.014), glow)


# ===========================================================================
# 3. AISLE LIGHT — a high bay on a stem, hung over the aisle
# ===========================================================================
#
# BASE-ANCHORED LIKE EVERYTHING ELSE, WHICH MEANS THE ORIGIN IS THE LENS.
# Place the model at the height you want the light to hang; the stem runs up
# 1.40 m from there to the roof steel. Placing it on the floor gets you a
# floor lamp, which is not a thing a distribution centre has.

static func _aisle_light(b: RefCounted, e: RefCounted, _g: RefCounted, params: Dictionary) -> void:
	var shell := _col(params, "colour", Color(0.30, 0.31, 0.33))
	var glow := _col(params, "glow_colour", C_CANOPY)
	var lit := _flag(params, "lit", true)

	# Shallow reflector: a wide ring lofted up to a narrow one.
	var r0 := _ring_y(0.055, 0.42, 0.42, 0.10)
	var r1 := _ring_y(0.300, 0.17, 0.17, 0.05)
	b.loft([r0, r1], [Vector3(0.0, 0.055, 0.0), Vector3(0.0, 0.300, 0.0)],
		shell.lightened(0.06))
	_cap_axial(b, r1, Vector3(0.0, 0.320, 0.0), Vector3.UP, shell)
	# The guard ring under the lens, so the fixture is not just a glowing lump.
	for i in 4:
		var a := TAU * float(i) / 4.0 + PI * 0.25
		b.box(Vector3(cos(a) * 0.40, 0.030, sin(a) * 0.40),
			Vector3(0.030, 0.030, 0.030), shell.darkened(0.25))
	_cyl(b, Vector3(0.0, 0.30, 0.0), Vector3(0.0, 1.34, 0.0), 0.035, 4, shell)
	b.box(Vector3(0.0, 1.375, 0.0), Vector3(0.11, 0.025, 0.11), shell.darkened(0.2))
	if lit:
		e.box(Vector3(0.0, 0.020, 0.0), Vector3(0.36, 0.020, 0.36), glow)
		# A dim skirt so the fixture reads as on from three-quarter angles and
		# not only from directly underneath it.
		e.box(Vector3(0.0, 0.070, 0.0), Vector3(0.39, 0.028, 0.39), glow.darkened(0.45))


# ===========================================================================
# 4. GLASS PANE — the load-bearing prop of the entire encounter
# ===========================================================================
#
# THE VISUAL ONLY. No collider, no Area3D, no group, no break. Glass in this
# project is a StaticBody3D with hidden meshes + an unshaded quad + a trigger
# Area3D, torn down by the zone (zone_truckstop.gd:1001-1034, 1775-1798), and
# the comment there states the reason: "a pane of glass modelled as a rigid
# body falls over the moment the physics starts". A ChaosProp curtain wall
# would be four storeys of sheet glass lying on the floor at t=0.
#
# So the encounter owns the collider and the shatter. What it gets from here is
# a frame on "Shell" and a pane on "Glass"; hide "Glass", disable the collider
# through set_deferred, keep the frame standing. A mullion that survives the
# break is not an oversight — it is what a broken curtain wall looks like.
#
# The streak is doing more work than the pane. A flat 30%-alpha rectangle at
# 3 a.m. against a dark interior is invisible, and a pane you cannot see is a
# pane you cannot aim a honk at. One brighter diagonal band is the whole cue.

static func _glass_pane(b: RefCounted, e: RefCounted, g: RefCounted, params: Dictionary) -> void:
	var pw := _num(params, "pane_w", PANE_W)
	var ph := _num(params, "pane_h", PANE_H)
	var fr := _num(params, "frame", MULLION)
	var frame := _col(params, "trim_colour", Color(0.15, 0.17, 0.20))
	var tint := _col(params, "colour", C_GLASS)
	var lit := _flag(params, "lit", false)
	var warm := _col(params, "glow_colour", Color(0.98, 0.88, 0.66))

	var hw := (pw + fr * 2.0) * 0.5
	var th := ph + fr * 2.0
	var hpw := pw * 0.5
	var cy := fr + ph * 0.5

	# ── the frame: four members, mitred by simply overlapping ─────────────
	b.box(Vector3(0.0, fr * 0.5, 0.0), Vector3(hw, fr * 0.5, 0.055), frame)
	b.box(Vector3(0.0, th - fr * 0.5, 0.0), Vector3(hw, fr * 0.5, 0.055), frame)
	for sx in [-1.0, 1.0]:
		var xs: float = sx
		b.box(Vector3(xs * (hw - fr * 0.5), th * 0.5, 0.0),
			Vector3(fr * 0.5, th * 0.5, 0.058), frame.lightened(0.06))
	# A gasket line where the glass meets the frame. Two millimetres of black
	# is what stops a pane looking like a hole cut in a wall.
	#
	# FOUR EDGES, NOT ONE PLATE. This was a single `b.box` with half-extents of
	# `hpw + 0.008` by `ph * 0.5 + 0.008` — which is not a gasket LINE, it is a
	# filled opaque panel exactly the size of the glass, sitting 30 mm behind it.
	# Every pane in the building was a solid wall.
	#
	# That is not a cosmetic miss. BOSS_DESIGN.md §2.2.4's argument for why the
	# encounter needs no health bar is that "the building's state is legible from
	# thirty metres because it is made of glass and you can see which floors
	# still have any" — and you could not see through any of it. The lit lobby,
	# the loose down and the Suit climbing his own stairs were all behind a dark
	# box, and the one readout the fight has was blank.
	var gk := Color(0.055, 0.060, 0.070)
	var gz := 0.030
	var ghw := hpw + 0.008
	var ghh := ph * 0.5 + 0.008
	b.box(Vector3(0.0, cy + ghh, gz), Vector3(ghw, 0.008, 0.010), gk)
	b.box(Vector3(0.0, cy - ghh, gz), Vector3(ghw, 0.008, 0.010), gk)
	for gs in [-1.0, 1.0]:
		var gsx: float = gs
		b.box(Vector3(gsx * ghw, cy, gz), Vector3(0.008, ghh, 0.010), gk)

	# ── the pane ──────────────────────────────────────────────────────────
	var behind := Vector3(0.0, cy, 0.6)
	g.quad(
		Vector3(-hpw, fr, 0.0), Vector3(hpw, fr, 0.0),
		Vector3(hpw, fr + ph, 0.0), Vector3(-hpw, fr + ph, 0.0),
		tint, behind)
	# The reflection streak: a parallelogram across the lower-left to
	# upper-right, slightly proud so it never z-fights with the pane.
	var sw := pw * 0.30
	var streak := Color(tint.r + 0.24, tint.g + 0.22, tint.b + 0.20,
		minf(tint.a * 1.9, 0.72))
	g.quad(
		Vector3(-hpw, fr + ph * 0.10, -0.012),
		Vector3(-hpw + sw, fr + ph * 0.10, -0.012),
		Vector3(hpw, fr + ph * 0.92, -0.012),
		Vector3(hpw - sw, fr + ph * 0.92, -0.012),
		streak, behind + Vector3(0.0, 0.0, 0.02))

	if lit:
		# In front of the glass, toward the reader at -Z. A warm quad behind an
		# alpha pane is a warm quad multiplied by 0.3 and then by the night.
		e.box(Vector3(0.0, cy, -0.022), Vector3(hpw * 0.97, ph * 0.48, 0.008), warm)


# ===========================================================================
# 5. ROLLER SHUTTER — the boss's only move, and the only thing here that moves
# ===========================================================================
#
# The frame, the hood and the amber strobe housing are static. The curtain is
# a "Curtain" Node3D holding one MeshInstance3D per slat, driven by
# `shutter_set_closed(model, t)` with t = 0 open, 1 seated.
#
# WHY PER-SLAT NODES AND NOT ONE MESH. A shutter has to roll UP into a 0.46 m
# hood, and a 3 m curtain does not fit in a 0.46 m hood. The two cheap answers
# both look wrong: scaling the curtain in Y squashes twenty slats into a
# stripey band, and translating one mesh leaves two and a half metres of steel
# standing above the frame in mid-air. Twenty MeshInstance3Ds and a visibility
# test costs twenty nodes for the one or two shutters this encounter has, and
# the bottom edge — the only edge the player is watching, because it is the
# thing about to cut them off — moves continuously and lands exactly on zero.
#
# The strobe starts HIDDEN. It is the 0.9 s telegraph, which is a reaction
# window, which means it is only ever on while the player still has a choice.

static func _roller_shutter(b: RefCounted, _e: RefCounted, _g: RefCounted, params: Dictionary) -> void:
	var w := _num(params, "width", 3.20)
	var h := _num(params, "height", 3.00)
	var steel := _col(params, "colour", C_STEEL)
	var frame := _col(params, "trim_colour", Color(0.26, 0.27, 0.29))

	var hw := w * 0.5
	var top := h + 0.62

	# ── guide channels, both sides, floor to hood ─────────────────────────
	for sx in [-1.0, 1.0]:
		var xs: float = sx
		b.box(Vector3(xs * (hw + 0.11), top * 0.5, 0.0),
			Vector3(0.110, top * 0.5, 0.100), frame)
		# The open face of the channel, so it reads as a track and not a post.
		b.box(Vector3(xs * (hw + 0.055), top * 0.5, -0.098),
			Vector3(0.055, top * 0.5 - 0.02, 0.012), frame.darkened(0.34))
		b.box(Vector3(xs * (hw + 0.11), 0.04, 0.0),
			Vector3(0.145, 0.040, 0.130), frame.darkened(0.28))

	# ── the hood, which is where the curtain claims to go ────────────────
	b.box(Vector3(0.0, top - 0.23, 0.0), Vector3(hw + 0.22, 0.230, 0.205), steel)
	b.box(Vector3(0.0, top - 0.23, -0.212), Vector3(hw + 0.20, 0.205, 0.014),
		steel.lightened(0.09))
	b.box(Vector3(0.0, top - 0.005, 0.0), Vector3(hw + 0.24, 0.020, 0.225),
		frame.darkened(0.2))
	# A hazard chevron band across the hood fascia. Six wedges, no texture.
	for i in 6:
		var t := (float(i) + 0.5) / 6.0
		b.box(Vector3(-hw + t * w, top - 0.30, -0.222),
			Vector3(w / 16.0, 0.045, 0.008),
			Color(0.92, 0.72, 0.14) if i % 2 == 0 else Color(0.10, 0.10, 0.11),
			Basis(Vector3.FORWARD, 0.55))

	# ── strobe housing. The lens is a separate node — see _shutter_parts. ──
	b.box(Vector3(hw - 0.24, h + 0.34, -0.245), Vector3(0.095, 0.075, 0.055),
		frame.darkened(0.15))
	b.box(Vector3(hw - 0.24, h + 0.44, -0.235), Vector3(0.075, 0.028, 0.045),
		frame.darkened(0.30))
	# The servo box, because the telegraph has a sound and a sound needs a
	# source you can point at.
	b.box(Vector3(-hw - 0.11, h + 0.30, -0.19), Vector3(0.085, 0.115, 0.075),
		frame.lightened(0.08))


## Builds the moving parts. Called from _post_build, never directly.
static func _shutter_parts(model: Node3D, params: Dictionary) -> void:
	var w := _num(params, "width", 3.20)
	var h := _num(params, "height", 3.00)
	var slat := maxf(_num(params, "slat", 0.15), 0.04)
	var steel := _col(params, "colour", C_STEEL)
	var amber := _col(params, "glow_colour", C_SODIUM)
	var n := maxi(1, ceili(h / slat))

	var curtain := Node3D.new()
	curtain.name = "Curtain"
	model.add_child(curtain)
	for i in n:
		var cb: RefCounted = LPB.new()
		var cy := -(float(i) + 0.5) * slat
		var tint := steel.lightened(0.045 * _wobble(i, 3, 0.0))
		cb.box(Vector3(0.0, cy, 0.0), Vector3(w * 0.5, slat * 0.47, 0.026), tint)
		# One rolled rib per slat, on the face the player sees.
		cb.box(Vector3(0.0, cy, -0.030), Vector3(w * 0.5 - 0.02, slat * 0.17, 0.012),
			tint.darkened(0.24))
		LPB.attach(curtain, cb.commit(), shared_material(), "Slat%d" % i)

	model.set_meta("shutter_h", h)
	model.set_meta("shutter_slat", slat)
	model.set_meta("shutter_slats", n)

	var sb: RefCounted = LPB.new()
	sb.box(Vector3(w * 0.5 - 0.24, h + 0.34, -0.305), Vector3(0.070, 0.052, 0.012), amber)
	var strobe := LPB.attach(model, sb.commit(), glow_material(), "Strobe")
	strobe.visible = false

	shutter_set_closed(model, _num(params, "closed", 0.0))


## Draw the shutter down its frame. `t` is 0.0 fully open, 1.0 fully seated.
##
## The bottom edge sits at exactly `(1 - t) * height` above the sill, which is
## the number the encounter wants for "has it cut the route yet". Slats that
## have risen past the head are hidden rather than scaled, so nothing ever
## appears above the hood. Safe to call every frame and safe to call on a model
## that is not a shutter.
static func shutter_set_closed(model: Node3D, t: float) -> void:
	if model == null or not is_instance_valid(model):
		return
	var curtain := model.get_node_or_null("Curtain")
	if curtain == null or not (curtain is Node3D):
		return
	var c3: Node3D = curtain
	var tt := clampf(t, 0.0, 1.0)
	var h: float = float(model.get_meta("shutter_h", 3.0))
	var slat: float = maxf(float(model.get_meta("shutter_slat", 0.15)), 0.001)
	var n: int = int(model.get_meta("shutter_slats", 0))

	c3.visible = tt > 0.001
	c3.position.y = (2.0 - tt) * h
	var first := ceili(((1.0 - tt) * h - 0.02) / slat)
	for i in n:
		var s := c3.get_node_or_null("Slat%d" % i)
		if s is MeshInstance3D:
			var mi: MeshInstance3D = s
			mi.visible = i >= first


## The strobe lens, so the encounter can blink it through the 0.9 s telegraph.
## Returns null for anything that is not a roller_shutter.
static func shutter_strobe(model: Node3D) -> MeshInstance3D:
	if model == null or not is_instance_valid(model):
		return null
	var s := model.get_node_or_null("Strobe")
	if s is MeshInstance3D:
		return s
	return null


# ===========================================================================
# 6. DOCK DOOR — the dressing round a hole in the wall
# ===========================================================================
#
# This model does NOT contain the opening. The opening is a genuine gap in the
# warehouse's -Z wall, cut by `_warehouse_boxes`, because a hole you can fly
# through has to be an absence of collider and not a dark rectangle. What goes
# here is everything bolted round it: the seal, the bumpers, the leveller lip
# and the gooseneck lamp.
#
# The model sits on the OUTSIDE face of the wall and grows toward -Z. Place it
# at the same world z as the wall's outer skin.

static func _dock_door(b: RefCounted, e: RefCounted, _g: RefCounted, params: Dictionary) -> void:
	var w := _num(params, "width", DOOR_W)
	var h := _num(params, "height", DOOR_H)
	var dy := _num(params, "dock_y", DOCK_Y)
	var seal := _col(params, "colour", Color(0.085, 0.085, 0.095))
	var trim := _col(params, "trim_colour", C_STEEL)
	var lit := _flag(params, "lit", true)
	var glow := _col(params, "glow_colour", C_SODIUM)

	var hw := w * 0.5
	var mid := dy + h * 0.5

	# ── the foam dock seal: two jambs and a head pad ──────────────────────
	for sx in [-1.0, 1.0]:
		var xs: float = sx
		b.box(Vector3(xs * (hw + 0.14), mid, -0.13), Vector3(0.140, h * 0.5, 0.130), seal)
		# The wear stripe down the inside face of each pad.
		b.box(Vector3(xs * (hw + 0.02), mid, -0.135), Vector3(0.022, h * 0.5 - 0.05, 0.126),
			seal.lightened(0.22))
	b.box(Vector3(0.0, dy + h + 0.14, -0.13), Vector3(hw + 0.28, 0.140, 0.130), seal)

	# ── bumpers, laminated, one either side of the opening ───────────────
	for sx2 in [-1.0, 1.0]:
		var xb: float = sx2
		for i in 4:
			b.box(Vector3(xb * (hw - 0.10), dy - 0.40 + float(i) * 0.10 + 0.05, -0.12),
				Vector3(0.130, 0.046, 0.120),
				Color(0.075, 0.075, 0.082).lightened(0.05 * float(i % 2)))
		b.box(Vector3(xb * (hw - 0.10), dy - 0.44, -0.12),
			Vector3(0.140, 0.030, 0.130), trim.darkened(0.3))

	# ── the leveller lip, hinged at the sill and hanging a little ────────
	b.box(Vector3(0.0, dy - 0.030, -0.28), Vector3(hw - 0.22, 0.030, 0.290),
		trim.darkened(0.10), Basis(Vector3.RIGHT, -0.045))
	b.box(Vector3(0.0, dy - 0.10, -0.02), Vector3(hw - 0.10, 0.075, 0.030),
		trim.darkened(0.32))

	# ── guide stripes on the wall, either side. Yellow is the only colour a
	# reversing driver has ever needed and it is also how a goose finds the way in.
	for sx3 in [-1.0, 1.0]:
		var xg: float = sx3
		b.box(Vector3(xg * (hw + 0.36), mid, -0.012),
			Vector3(0.055, h * 0.5, 0.012), Color(0.88, 0.70, 0.16))

	# ── the gooseneck dock lamp, over the +X jamb ────────────────────────
	var arm_a := Vector3(hw + 0.34, dy + h + 0.24, -0.06)
	var arm_b := Vector3(hw + 0.02, dy + h + 0.36, -0.46)
	_cyl(b, Vector3(hw + 0.34, dy + h + 0.06, -0.06), arm_a, 0.035, 4, trim.darkened(0.2))
	_strut(b, arm_a, arm_b, 0.030, trim.darkened(0.1))
	b.box(arm_b + Vector3(0.0, -0.06, 0.0), Vector3(0.135, 0.075, 0.135),
		trim.lightened(0.06))
	if lit:
		e.box(arm_b + Vector3(0.0, -0.135, 0.0), Vector3(0.110, 0.016, 0.110), glow)


## The bay number, on the header above the opening.
static func _dock_door_text(model: Node3D, params: Dictionary) -> void:
	var t := _str(params, "text", "")
	if t == "":
		return
	var h := _num(params, "height", DOOR_H)
	var dy := _num(params, "dock_y", DOCK_Y)
	var ink := _col(params, "ink_colour", Color(0.86, 0.84, 0.78))
	var n := Vector3(0.0, 0.0, -1.0)
	var right := Vector3.UP.cross(n)
	var cap := 0.26
	TS.sign_text(model, t,
		Vector3(0.0, dy + h + 0.36, -0.026) - right * (TS.text_width(t, cap) * 0.5),
		n, Vector3.UP, cap, ink, false, 0.020)


# ===========================================================================
# 7. DOCK APRON — the way in, for a goose that is walking
# ===========================================================================
#
# A slab at dock height with a ramp off one end. The ramp exists because a
# goose that has spent its stamina on the interstate cannot flap 1.15 m, and a
# player who has to stand at the bottom of a kerb waiting for a stamina bar is
# a player who has stopped playing.
#
# The ramp's climbable surface is returned by climb_ramps() — the encounter
# MUST build that collider. This model is a picture of a ramp.

static func _dock_apron(b: RefCounted, e: RefCounted, _g: RefCounted, params: Dictionary) -> void:
	var w := _num(params, "width", 9.00)
	var d := _num(params, "depth", 5.20)
	var dy := _num(params, "dock_y", DOCK_Y)
	var run := _num(params, "ramp_run", 3.40)
	var rw := _num(params, "ramp_w", 2.60)
	var conc := _col(params, "colour", C_CONCRETE)
	var stripe := _col(params, "trim_colour", Color(0.86, 0.68, 0.16))
	var lit := _flag(params, "lit", false)
	var glow := _col(params, "glow_colour", C_SODIUM)

	var td := d + run
	var hd := td * 0.5
	var hw := w * 0.5
	var lip_z := hd - d          ## the apron's -Z edge, where the drop is

	# ── the slab ─────────────────────────────────────────────────────────
	b.box(Vector3(0.0, dy * 0.5, hd - d * 0.5), Vector3(hw, dy * 0.5, d * 0.5), conc)
	# Slab joints. Four scored lines, which is the only thing that gives nine
	# metres of grey any size at all.
	for i in 3:
		var jx := -hw + w * (float(i) + 1.0) / 4.0
		b.box(Vector3(jx, dy - 0.004, hd - d * 0.5), Vector3(0.016, 0.010, d * 0.5 - 0.05),
			conc.darkened(0.28))

	# ── the ramp, on the +X end ──────────────────────────────────────────
	var rx1 := hw - 0.10
	var rx0 := rx1 - rw
	_ramp_prism(b, rx0, rx1, -hd, lip_z, 0.0, dy, conc.lightened(0.04))
	# A kerb down the ramp's open side, so a goose that clips it slides rather
	# than falls. Rotated to the ramp's own pitch.
	var pitch := atan2(dy, run)
	b.box(Vector3(rx0 - 0.06, dy * 0.5 + 0.06, (-hd + lip_z) * 0.5),
		Vector3(0.060, 0.075, sqrt(run * run + dy * dy) * 0.5),
		conc.darkened(0.16), Basis(Vector3.RIGHT, -pitch))

	# ── the edge of dock: a yellow stripe on the lip, and the safety chain
	# posts either side of the drop. This is the most-fallen-off edge in the
	# encounter and it needs to be visible from above, not just from in front.
	b.box(Vector3(0.0, dy - 0.005, lip_z + 0.10), Vector3(hw, 0.014, 0.100), stripe)
	b.box(Vector3(0.0, dy - 0.16, lip_z + 0.02), Vector3(hw, 0.160, 0.022),
		stripe.darkened(0.35))
	for i in 4:
		var bx := -hw + w * (float(i) + 0.5) / 4.0
		if bx > rx0 - 0.3:
			continue
		_cyl(b, Vector3(bx, dy, lip_z + 0.34), Vector3(bx, dy + 0.86, lip_z + 0.34),
			0.055, 6, stripe.darkened(0.10))
		b.box(Vector3(bx, dy + 0.90, lip_z + 0.34), Vector3(0.070, 0.035, 0.070),
			Color(0.10, 0.10, 0.11))
	if lit:
		# Two recessed apron markers. When the dock opens at 110 s these are the
		# only thing that changes, and §2.2.2 is explicit that that is all the
		# announcement it gets.
		for sx in [-1.0, 1.0]:
			var xs: float = sx
			e.box(Vector3(xs * (hw - 0.55), dy + 0.004, lip_z + 0.55),
				Vector3(0.16, 0.012, 0.16), glow)


# ===========================================================================
# 8. WAREHOUSE SHELL — a very large dark box, which is the correct answer
# ===========================================================================
#
# BOSS_DESIGN.md:1188 calls this "the single cheapest-looking-most-impressive
# geometry ratio in the project" and it is not wrong. What makes it work is
# that every wall is a real box with real thickness rather than a plane: a box
# has an inside face, so standing in the middle of the room you are looking at
# geometry rather than through a back-face-culled hole into the sky. No
# _loft_inward, no CULL_DISABLED, no second shell.
#
# Interior clear span is (width - 0.60) x (depth - 0.60) x 11.0 high. The roof
# deck at y = 11.0 is walkable and the leg ends on it, which is why there is a
# 0.70 m parapet: a player standing on a flat black plane in the rain at 3 a.m.
# with no visible edge will walk off it, and that is not the beat.
#
# The -Z face is the DOCK FACE and its openings are genuine gaps — no geometry
# and, via collider_boxes(), no collider either. Rotate the whole model to aim
# the dock face; there is one convention here and it is the project's, which is
# that the front of anything points at -Z.

static func _warehouse_shell(b: RefCounted, e: RefCounted, _g: RefCounted, params: Dictionary) -> void:
	var w := _num(params, "width", WH_W)
	var d := _num(params, "depth", WH_D)
	var h := _num(params, "height", WH_H)
	var skin := _col(params, "colour", C_DARK)
	var roof_col := _col(params, "trim_colour", Color(0.115, 0.120, 0.132))
	var ribs := _flag(params, "ribs", true)
	var lit := _flag(params, "lit", false)
	var glow := _col(params, "glow_colour", C_SODIUM)
	var hw := w * 0.5
	var hd := d * 0.5

	# ── the shell itself, straight off the layout the colliders use ──────
	for entry in _warehouse_boxes(params):
		var tag: String = entry["tag"]
		var c: Vector3 = entry["c"]
		var s: Vector3 = entry["s"]
		var col := skin
		match tag:
			"roof":
				col = roof_col
			"parapet":
				col = roof_col.lightened(0.10)
			"column":
				col = skin.lightened(0.16)
		b.box(c, s * 0.5, col)

	# ── exterior corrugation, on the two long faces and the two ends ─────
	if ribs:
		_ribs(b, Vector3(0.0, 0.0, hd), hw - 0.2, 0.30, h - 0.40,
			Vector3(0.0, 0.0, 1.0), 1.20, 0.05, skin.lightened(0.05))
		_ribs(b, Vector3(0.0, 0.0, -hd), hw - 0.2, h - 3.60, h - 0.40,
			Vector3(0.0, 0.0, -1.0), 1.20, 0.05, skin.lightened(0.05))
		for sx in [-1.0, 1.0]:
			var xs: float = sx
			_ribs(b, Vector3(xs * hw, 0.0, 0.0), hd - 0.2, 0.30, h - 0.40,
				Vector3(xs, 0.0, 0.0), 1.20, 0.05, skin.lightened(0.05))
	# Two horizontal girt bands. A forty-metre wall with no horizon on it reads
	# as a backdrop; two paler stripes turn it into a building.
	for i in 2:
		var by := h * (0.36 + 0.34 * float(i))
		for sz in [-1.0, 1.0]:
			var zs: float = sz
			# NOT ACROSS THE DOORWAYS. The dock openings are genuine holes in
			# this wall — no geometry, no collider — running from `dy` to
			# `dy + dh`, and the lower girt lands at h*0.36 = 3.96 on an 11 m
			# shell, which is inside a 1.15..4.25 opening. So a steel bar ran
			# straight across all four open dock doors, 30 cm below the head,
			# supported by nothing, and it is the first thing you look at when
			# the dock opens. The rib pass twelve lines up already dodges the
			# doors (`h - 3.60` starts above them); this pass did not.
			#
			# The band is split around the openings rather than dropped, because
			# the wall still needs its horizon — without a stripe a forty-metre
			# face reads as a backdrop, which is what the band is for.
			# Read straight from params, the same way `_warehouse_boxes()` does,
			# so the band and the openings can never disagree about where the
			# doors are.
			var n_doors: int = maxi(0, _int(params, "doors", 4))
			var door_h: float = _num(params, "door_h", DOOR_H)
			var door_y: float = _num(params, "dock_y", DOCK_Y)
			var door_pitch: float = _num(params, "door_pitch", DOOR_PITCH)
			var door_w: float = _num(params, "door_w", DOOR_W)
			# The openings are centred on the front face and evenly pitched, so
			# the run they occupy is (n-1) pitches wide plus one door.
			var span_hw: float = 0.0
			if n_doors > 0:
				span_hw = (float(n_doors - 1) * door_pitch + door_w) * 0.5
			if n_doors > 0 and is_equal_approx(zs, -1.0) \
					and by > door_y and by < door_y + door_h:
				var seg: float = maxf(0.0, hw - span_hw) * 0.5
				if seg > 0.05:
					for sx2 in [-1.0, 1.0]:
						var xs2: float = sx2
						b.box(Vector3(xs2 * (hw - seg), by, zs * (hd + 0.035)),
							Vector3(seg, 0.075, 0.035), skin.lightened(0.13))
				continue
			b.box(Vector3(0.0, by, zs * (hd + 0.035)), Vector3(hw, 0.075, 0.035),
				skin.lightened(0.13))
		for sx2 in [-1.0, 1.0]:
			var xs2: float = sx2
			b.box(Vector3(xs2 * (hw + 0.035), by, 0.0), Vector3(0.035, 0.075, hd),
				skin.lightened(0.13))

	# ── the roof: corrugation you can land on, and three plant units ─────
	var runs := maxi(4, int(w / 1.60))
	for i in runs:
		var rx := -hw + w * (float(i) + 0.5) / float(runs)
		b.box(Vector3(rx, h + 0.025, 0.0), Vector3(w / float(runs) * 0.30, 0.025, hd - 0.30),
			roof_col.lightened(0.06))
	for i in 3:
		var ux := -w * 0.26 + float(i) * w * 0.26
		b.box(Vector3(ux, h + 0.55, hd * 0.30), Vector3(1.55, 0.55, 1.15),
			roof_col.lightened(0.16))
		b.box(Vector3(ux, h + 1.12, hd * 0.30), Vector3(1.35, 0.055, 0.95),
			roof_col.lightened(0.04))
	for i in 5:
		var vx := -w * 0.34 + float(i) * w * 0.17
		_cyl(b, Vector3(vx, h + 0.02, -hd * 0.36), Vector3(vx, h + 0.62, -hd * 0.36),
			0.28, 6, roof_col.lightened(0.20))

	# ── roof steel, seen from underneath. Six chords and their verticals is
	# enough to say "there is a structure up there" from the floor at night.
	var trusses := maxi(3, int(d / 5.0))
	for i in trusses:
		var tz := -hd + d * (float(i) + 0.5) / float(trusses)
		b.box(Vector3(0.0, h - 0.52, tz), Vector3(hw - 0.35, 0.075, 0.110),
			skin.lightened(0.10))
		b.box(Vector3(0.0, h - 1.05, tz), Vector3(hw - 0.35, 0.055, 0.085),
			skin.lightened(0.06))
		var webs := maxi(4, int(w / 6.0))
		for k in webs:
			var wx := -hw + w * (float(k) + 0.5) / float(webs)
			b.box(Vector3(wx, h - 0.79, tz), Vector3(0.045, 0.27, 0.070),
				skin.lightened(0.08))

	if lit:
		# The ground-floor lights coming on across the interstate is the ONLY
		# announcement the dock opening gets (§2.2.2). Keep it to this.
		for i in 4:
			var lx := -w * 0.30 + float(i) * w * 0.20
			e.box(Vector3(lx, DOCK_Y + DOOR_H + 0.55, -hd - 0.04),
				Vector3(0.30, 0.055, 0.020), glow)


## Every solid box in the warehouse, base-anchored local frame.
##
## The mesh builder above and collider_boxes() below both read this. They cannot
## drift apart, which is the entire reason it exists as a function rather than
## as two hundred literals in two places.
static func _warehouse_boxes(params: Dictionary) -> Array[Dictionary]:
	var w := _num(params, "width", WH_W)
	var d := _num(params, "depth", WH_D)
	var h := _num(params, "height", WH_H)
	var t := WH_WALL
	var doors := maxi(0, _int(params, "doors", 4))
	var dw := _num(params, "door_w", DOOR_W)
	var dh := _num(params, "door_h", DOOR_H)
	var dy := _num(params, "dock_y", DOCK_Y)
	var pitch := _num(params, "door_pitch", DOOR_PITCH)

	var out: Array[Dictionary] = []
	var hw := w * 0.5
	var hd := d * 0.5

	# Back wall, full height, no openings.
	out.append({"tag": "wall", "c": Vector3(0.0, h * 0.5, hd - t * 0.5),
		"s": Vector3(w, h, t)})
	# Side walls, inset so they butt into the front and back rather than
	# overlapping them — an overlap is a z-fighting seam eleven metres tall.
	for sx in [-1.0, 1.0]:
		var xs: float = sx
		out.append({"tag": "wall", "c": Vector3(xs * (hw - t * 0.5), h * 0.5, 0.0),
			"s": Vector3(t, h, d - t * 2.0)})

	# The -Z DOCK FACE.
	var lo := dy
	var hi := dy + dh
	if doors <= 0 or hi >= h:
		out.append({"tag": "wall", "c": Vector3(0.0, h * 0.5, -hd + t * 0.5),
			"s": Vector3(w, h, t)})
	else:
		out.append({"tag": "wall", "c": Vector3(0.0, lo * 0.5, -hd + t * 0.5),
			"s": Vector3(w, lo, t)})
		out.append({"tag": "wall", "c": Vector3(0.0, (hi + h) * 0.5, -hd + t * 0.5),
			"s": Vector3(w, h - hi, t)})
		# Piers. `edges` alternates gap-start / gap-end, so consecutive PAIRS
		# taken two at a time are exactly the solid strips between openings.
		var edges: Array[float] = [-hw]
		var x0 := -pitch * float(maxi(doors - 1, 0)) * 0.5
		for i in doors:
			var cx := x0 + pitch * float(i)
			edges.append(cx - dw * 0.5)
			edges.append(cx + dw * 0.5)
		edges.append(hw)
		var k := 0
		while k + 1 < edges.size():
			var ea: float = edges[k]
			var eb: float = edges[k + 1]
			if eb - ea > 0.02:
				out.append({"tag": "wall",
					"c": Vector3((ea + eb) * 0.5, (lo + hi) * 0.5, -hd + t * 0.5),
					"s": Vector3(eb - ea, hi - lo, t)})
			k += 2

	# Roof slab: walkable top at exactly y = h.
	out.append({"tag": "roof", "c": Vector3(0.0, h - 0.15, 0.0), "s": Vector3(w, 0.30, d)})
	# Parapet. Not decoration — see the note above about walking off a black plane.
	for sz in [-1.0, 1.0]:
		var zs: float = sz
		out.append({"tag": "parapet", "c": Vector3(0.0, h + 0.35, zs * (hd - 0.13)),
			"s": Vector3(w, 0.70, 0.26)})
	for sx2 in [-1.0, 1.0]:
		var xs2: float = sx2
		out.append({"tag": "parapet", "c": Vector3(xs2 * (hw - 0.13), h + 0.35, 0.0),
			"s": Vector3(0.26, 0.70, d - 0.52)})

	# Interior columns, one row down the middle. A forty-metre clear span is a
	# lie, and more usefully they are the only cover in the room.
	var cols := maxi(1, int(round(w / 10.0)) - 1)
	for i in cols:
		var cxp := -w * 0.5 + w * (float(i) + 1.0) / float(cols + 1)
		out.append({"tag": "column", "c": Vector3(cxp, h * 0.5, 0.0),
			"s": Vector3(0.34, h, 0.34)})
	return out


# ===========================================================================
# 9. ATRIUM SHELL — four storeys of glass with a hole down the middle
# ===========================================================================
#
# Slabs, mullions, stairs and one lit window. NOT the glass: every pane is a
# separate `&"glass_pane"` the encounter can shatter individually, because the
# building's state has to be legible from thirty metres — §2.2.4's whole
# argument for having no health bar is that it is made of glass and you can see
# which floors still have any.
#
# Floor to floor is 3.60 m, which is 1.94 flaps, which is the number this whole
# encounter turns on. See the header.
#
# The stair is a switchback across the void: flight f runs from the slab edge at
# +Z to the slab edge at -Z, and f+1 comes back. 3.60 m of rise over the 6.00 m
# void is 31.0°, which sits between the cottage's two shipped flights (31.6°
# and 27.8°). The treads here are DECAL GEOMETRY. Build the ramp from
# climb_ramps() or the goose walks into the first riser and stops.

static func _atrium_shell(b: RefCounted, _e: RefCounted, _g: RefCounted, params: Dictionary) -> void:
	var w := _num(params, "width", AT_W)
	var d := _num(params, "depth", AT_D)
	var floors := clampi(_int(params, "floors", 4), 1, 8)
	var fh := _num(params, "floor_h", AT_FLOOR)
	var frame := _col(params, "colour", Color(0.17, 0.19, 0.22))
	var slab_col := _col(params, "trim_colour", Color(0.255, 0.255, 0.265))
	var hw := w * 0.5
	var hd := d * 0.5
	var topy := float(floors) * fh

	# ── slabs, parapet and corner posts, from the shared layout ──────────
	for entry in _atrium_boxes(params):
		var tag: String = entry["tag"]
		var c: Vector3 = entry["c"]
		var s: Vector3 = entry["s"]
		var col := slab_col
		match tag:
			"parapet":
				col = frame.lightened(0.10)
			"post":
				col = frame
		b.box(c, s * 0.5, col)

	# ── curtain-wall grid: mullions every module, transoms at every slab
	# and one spandrel rail per storey. This is the cage the panes drop into.
	var mods_x := maxi(2, int(round(w / MODULE)))
	var mods_z := maxi(2, int(round(d / MODULE)))
	for i in mods_x + 1:
		var mx := -hw + w * float(i) / float(mods_x)
		for sz in [-1.0, 1.0]:
			var zs: float = sz
			b.box(Vector3(mx, topy * 0.5, zs * (hd - 0.05)),
				Vector3(0.055, topy * 0.5, 0.055), frame)
	for i in mods_z + 1:
		var mz := -hd + d * float(i) / float(mods_z)
		for sx in [-1.0, 1.0]:
			var xs: float = sx
			b.box(Vector3(xs * (hw - 0.05), topy * 0.5, mz),
				Vector3(0.055, topy * 0.5, 0.055), frame)
	for lv in (floors * 2) + 1:
		var thick := 0.075 if lv % 2 == 0 else 0.045
		# The sill transom sits ON the slab, not straddling it. Centred on zero
		# it would hang half its thickness below the model's own origin, which
		# is the one thing the base-anchoring contract forbids.
		var ty := maxf(float(lv) * fh * 0.5, thick)
		for sz2 in [-1.0, 1.0]:
			var zs2: float = sz2
			b.box(Vector3(0.0, ty, zs2 * (hd - 0.05)), Vector3(hw, thick, 0.052),
				frame.lightened(0.08))
		for sx2 in [-1.0, 1.0]:
			var xs2: float = sx2
			b.box(Vector3(xs2 * (hw - 0.05), ty, 0.0), Vector3(0.052, thick, hd),
				frame.lightened(0.08))

	# ── the stairs. Treads, stringers and a rail down the open side. ─────
	for flight in _atrium_flights(params):
		var a: Vector3 = flight["a"]
		var c2: Vector3 = flight["b"]
		var fw: float = flight["w"]
		_atrium_flight_geometry(b, a, c2, fw, slab_col, frame)

	# ── the top floor's office: a desk and a chair behind the lit window ──
	var oz := -hd + 1.05
	var ox := MODULE * 1.5
	var oy := (float(floors) - 1.0) * fh
	b.box(Vector3(ox, oy + 0.72, oz + 0.35), Vector3(0.72, 0.035, 0.36),
		Color(0.30, 0.26, 0.23))
	for sx3 in [-1.0, 1.0]:
		var xs3: float = sx3
		b.box(Vector3(ox + xs3 * 0.64, oy + 0.36, oz + 0.35),
			Vector3(0.035, 0.360, 0.330), Color(0.22, 0.20, 0.19))
	b.box(Vector3(ox, oy + 0.24, oz + 0.95), Vector3(0.22, 0.035, 0.22),
		Color(0.14, 0.15, 0.17))
	b.box(Vector3(ox, oy + 0.52, oz + 1.14), Vector3(0.22, 0.250, 0.035),
		Color(0.14, 0.15, 0.17))
	_cyl(b, Vector3(ox, oy, oz + 0.95), Vector3(ox, oy + 0.22, oz + 0.95),
		0.035, 4, Color(0.20, 0.20, 0.22))

	# ── the void's edge nosing. The floor lights themselves are a separate
	# node so they can be cut one bank at a time; this is the aluminium.
	var hvw := _atrium_void_x(params)
	var hvd := _atrium_void_z(params)
	for lv2 in range(1, floors + 1):
		var ny := float(lv2) * fh + 0.008
		for sz3 in [-1.0, 1.0]:
			var zs3: float = sz3
			b.box(Vector3(0.0, ny, zs3 * hvd), Vector3(hvw, 0.020, 0.050),
				frame.lightened(0.24))
		for sx4 in [-1.0, 1.0]:
			var xs4: float = sx4
			b.box(Vector3(xs4 * hvw, ny, 0.0), Vector3(0.050, 0.020, hvd),
				frame.lightened(0.24))
	# Nothing goes on the glow builder here. Every emissive thing in the atrium
	# — the floor light banks and the one lit window — has to be switchable
	# independently, so all of it lives on its own node in _atrium_parts().


## One flight's worth of visible stair: stringers, treads and a handrail.
## `a` and `b_pt` are points ON the finished walking surface, foot and head.
static func _atrium_flight_geometry(b: RefCounted, a: Vector3, b_pt: Vector3,
		fw: float, tread_col: Color, rail_col: Color) -> void:
	var dz := b_pt.z - a.z
	var rise := b_pt.y - a.y
	var run := absf(dz)
	if run < 0.01:
		return
	# Rotation about +X sends +Z downward, so a flight whose HIGH end is at -Z
	# takes a positive angle and one whose high end is at +Z takes a negative.
	var ang := atan2(rise, run) * (1.0 if dz < 0.0 else -1.0)
	var mid := (a + b_pt) * 0.5

	# Two stringers, outside the walking width.
	#
	# They start 7% up the flight rather than at the foot, and that is not
	# cosmetic. A stringer hangs BELOW the walking line, and at the foot the
	# walking line is the floor — so a full-length stringer buries a fifth of a
	# metre of itself under the slab it is standing on. That is invisible on the
	# ground floor and a plank sticking through the ceiling on every floor
	# above it. Starting above the first tread costs one step's worth of
	# stringer and keeps the whole model on the correct side of y = 0.
	var s_a := a.lerp(b_pt, 0.07)
	var s_mid := (s_a + b_pt) * 0.5
	var s_len := s_a.distance_to(b_pt)
	var length := sqrt(run * run + rise * rise)
	for sx in [-1.0, 1.0]:
		var xs: float = sx
		b.box(s_mid + Vector3(xs * (fw * 0.5 + 0.05), -0.115, 0.0),
			Vector3(0.045, 0.105, s_len * 0.5), tread_col.darkened(0.28),
			Basis(Vector3.RIGHT, ang))

	# Treads. Walked OVER, not onto — the ramp collider is the real surface.
	#
	# Steps are indexed by their NOSING at t = (i+1)/steps rather than by their
	# middle at (i+0.5)/steps. The difference is half a riser, and half a riser
	# at the foot of the flight is a step face hanging under the floor.
	var steps := maxi(6, int(round(run / 0.32)))
	var going := dz / float(steps)
	var riser := rise / float(steps)
	for i in steps:
		var p := a.lerp(b_pt, float(i + 1) / float(steps))
		b.box(p + Vector3(0.0, 0.028, -going * 0.5),
			Vector3(fw * 0.5, 0.028, absf(going) * 0.44),
			tread_col.lightened(0.05 * sin(float(i) * 2.2)))
		b.box(p + Vector3(0.0, 0.028 - riser * 0.5, 0.0),
			Vector3(fw * 0.5, riser * 0.5, 0.022),
			tread_col.darkened(0.24))

	# Handrail down the -X side only: a rail on both sides of a 1.6 m flight
	# turns it into a tunnel and the goose is 0.68 m wide.
	var side := Vector3(-(fw * 0.5 + 0.10), 0.0, 0.0)
	var posts := maxi(3, steps / 3)
	for i in posts + 1:
		var t2 := float(i) / float(posts)
		var p2 := a.lerp(b_pt, t2) + side
		_cyl(b, p2, p2 + Vector3(0.0, 0.90, 0.0), 0.026, 4, rail_col.lightened(0.16))
	b.box(mid + side + Vector3(0.0, 0.90, 0.0),
		Vector3(0.032, 0.032, length * 0.5), rail_col.lightened(0.26),
		Basis(Vector3.RIGHT, ang))


static func _atrium_void_x(params: Dictionary) -> float:
	var w := _num(params, "width", AT_W)
	return minf(_num(params, "void_w", AT_VOID_W), w - 2.4) * 0.5


static func _atrium_void_z(params: Dictionary) -> float:
	var d := _num(params, "depth", AT_D)
	return minf(_num(params, "void_d", AT_VOID_D), d - 2.4) * 0.5


## Every solid box in the atrium, base-anchored local frame. Read by the mesh
## builder and by collider_boxes(), for the same reason as the warehouse's.
##
## Note there is no ground slab: the atrium's ground floor is the zone's floor,
## and §2.2.5 puts the loose down on it.
static func _atrium_boxes(params: Dictionary) -> Array[Dictionary]:
	var w := _num(params, "width", AT_W)
	var d := _num(params, "depth", AT_D)
	var floors := clampi(_int(params, "floors", 4), 1, 8)
	var fh := _num(params, "floor_h", AT_FLOOR)
	var hvw := _atrium_void_x(params)
	var hvd := _atrium_void_z(params)
	var hw := w * 0.5
	var hd := d * 0.5
	var topy := float(floors) * fh

	var out: Array[Dictionary] = []
	# Slabs 1..floors. The last one is the roof, and it keeps the hole: an
	# atrium with a skylight is an atrium, and the hole is how the down leaves.
	for lv in range(1, floors + 1):
		var y := float(lv) * fh - AT_SLAB * 0.5
		out.append({"tag": "slab", "c": Vector3(-(hw + hvw) * 0.5, y, 0.0),
			"s": Vector3(hw - hvw, AT_SLAB, d)})
		out.append({"tag": "slab", "c": Vector3((hw + hvw) * 0.5, y, 0.0),
			"s": Vector3(hw - hvw, AT_SLAB, d)})
		out.append({"tag": "slab", "c": Vector3(0.0, y, -(hd + hvd) * 0.5),
			"s": Vector3(hvw * 2.0, AT_SLAB, hd - hvd)})
		out.append({"tag": "slab", "c": Vector3(0.0, y, (hd + hvd) * 0.5),
			"s": Vector3(hvw * 2.0, AT_SLAB, hd - hvd)})
	# Roof parapet.
	for sz in [-1.0, 1.0]:
		var zs: float = sz
		out.append({"tag": "parapet", "c": Vector3(0.0, topy + 0.60, zs * (hd - 0.11)),
			"s": Vector3(w, 1.20, 0.22)})
	for sx in [-1.0, 1.0]:
		var xs: float = sx
		out.append({"tag": "parapet", "c": Vector3(xs * (hw - 0.11), topy + 0.60, 0.0),
			"s": Vector3(0.22, 1.20, d - 0.44)})
	# Corner posts, full height. The only thing holding the glass up.
	for sx2 in [-1.0, 1.0]:
		for sz2 in [-1.0, 1.0]:
			var xs2: float = sx2
			var zs2: float = sz2
			out.append({"tag": "post",
				"c": Vector3(xs2 * (hw - 0.16), topy * 0.5, zs2 * (hd - 0.16)),
				"s": Vector3(0.32, topy, 0.32)})
	return out


## The stair flights, foot to head, in the model's local frame.
## Keys: "a" Vector3 foot, "b" Vector3 head, "w" float walking width.
## Both points are ON the finished surface — the same contract as
## zone_truckstop.gd's `_ramp(a, b, width, thick, col)`, which is what the
## encounter should feed them to.
static func _atrium_flights(params: Dictionary) -> Array[Dictionary]:
	var floors := clampi(_int(params, "floors", 4), 1, 8)
	var fh := _num(params, "floor_h", AT_FLOOR)
	var hvw := _atrium_void_x(params)
	var hvd := _atrium_void_z(params)
	var sw := _num(params, "stair_w", STAIR_W)
	# Hard against the +X edge of the void, so the flight never crosses the
	# slab above it and the middle of the atrium stays open air.
	var sx := hvw - sw * 0.5 - 0.20
	var out: Array[Dictionary] = []
	for f in floors:
		var dir := 1.0 if f % 2 == 0 else -1.0
		out.append({
			"a": Vector3(sx, float(f) * fh, dir * hvd),
			"b": Vector3(sx, float(f + 1) * fh, -dir * hvd),
			"w": sw,
		})
	return out


## The floor-light banks and the one lit window at the top.
static func _atrium_parts(model: Node3D, params: Dictionary) -> void:
	var floors := clampi(_int(params, "floors", 4), 1, 8)
	var fh := _num(params, "floor_h", AT_FLOOR)
	var d := _num(params, "depth", AT_D)
	var hvw := _atrium_void_x(params)
	var hvd := _atrium_void_z(params)
	var cool := _col(params, "glow_colour", C_CANOPY)
	var warm := Color(0.98, 0.88, 0.66)

	# ── FloorLights/Bank0..N — the soffit ring under each slab. §2.2.4's
	# blackout cuts these "one bank at a time"; hide Bank(N-1) downward.
	var banks := Node3D.new()
	banks.name = "FloorLights"
	model.add_child(banks)
	for lv in floors:
		var y := float(lv + 1) * fh - AT_SLAB - 0.045
		var lb: RefCounted = LPB.new()
		var tint := cool.darkened(0.06 * float(lv))
		for sz in [-1.0, 1.0]:
			var zs: float = sz
			lb.box(Vector3(0.0, y, zs * (hvd - 0.075)), Vector3(hvw, 0.020, 0.045), tint)
		for sx in [-1.0, 1.0]:
			var xs: float = sx
			lb.box(Vector3(xs * (hvw - 0.075), y, 0.0), Vector3(0.045, 0.020, hvd), tint)
		LPB.attach(banks, lb.commit(), glow_material(), "Bank%d" % lv)

	# ── the one lit window. Top storey, -Z face, one module off centre. It has
	# been the only lit thing on the skyline since leg 6 and this is the same
	# window, seen from four metres instead of four hundred.
	var oy := (float(floors) - 1.0) * fh
	var ox := MODULE * 1.5
	var wb: RefCounted = LPB.new()
	wb.box(Vector3(ox, oy + fh * 0.5, -d * 0.5 - 0.035),
		Vector3(PANE_W * 0.5, fh * 0.40, 0.012), warm)
	# The spill onto the slab below it, which is what makes it a room with a
	# light on rather than a rectangle painted on a wall.
	wb.box(Vector3(ox, oy + 0.020, -d * 0.5 + 0.85),
		Vector3(PANE_W * 0.62, 0.012, 0.80), warm.darkened(0.62))
	LPB.attach(model, wb.commit(), glow_material(), "LitWindow")


# ===========================================================================
# 10. LIT SKYLINE BOX — the same building, twenty minutes early
# ===========================================================================
#
# CAMPAIGN_SPEC.md §2.5's Stopover manoeuvre: put the image in the world long
# before it matters so its arrival is a return rather than an introduction.
# This goes on the horizon during flight 6 and the whole of leg 7 and nothing
# ever mentions it.
#
# Cheap and hollow-free on purpose — it is never approached. One dark box, a
# sparse grid of dim windows, two red aircraft lights, and ONE bright window at
# the top of the -Z face in the same warm as the atrium's. That last one is the
# only detail that has to survive at four hundred metres, and it is the one the
# player will recognise when they finally stand in front of it.

static func _lit_skyline_box(b: RefCounted, e: RefCounted, _g: RefCounted, params: Dictionary) -> void:
	var w := _num(params, "width", 16.0)
	var h := _num(params, "height", 19.0)
	var d := _num(params, "depth", 14.0)
	var cols := clampi(_int(params, "cols", 7), 1, 24)
	var rows := clampi(_int(params, "rows", 6), 1, 24)
	var shell := _col(params, "colour", Color(0.075, 0.080, 0.095))
	var seed_v := _num(params, "variant", 0.0)
	var cool := _col(params, "glow_colour", Color(0.40, 0.50, 0.60))
	var warm := Color(0.98, 0.88, 0.66)
	var hw := w * 0.5
	var hd := d * 0.5

	b.box(Vector3(0.0, h * 0.5, 0.0), Vector3(hw, h * 0.5, hd), shell)
	# A setback at the top, so the silhouette is not one rectangle.
	b.box(Vector3(0.0, h + 0.30, 0.0), Vector3(hw - 0.9, 0.30, hd - 0.9),
		shell.lightened(0.10))
	for sz in [-1.0, 1.0]:
		var zs: float = sz
		b.box(Vector3(0.0, h + 0.72, zs * (hd - 0.12)), Vector3(hw, 0.42, 0.16),
			shell.lightened(0.16))
	for sx in [-1.0, 1.0]:
		var xs: float = sx
		b.box(Vector3(xs * (hw - 0.12), h + 0.72, 0.0), Vector3(0.16, 0.42, hd - 0.24),
			shell.lightened(0.16))

	# Window grid on the two faces the truck stop can see.
	var gw := w / float(cols)
	var gh := (h - 1.4) / float(rows)
	for r in rows:
		for c in cols:
			var on := _wobble(r * 3 + 1, c * 5 + 2, seed_v)
			if on < 0.18:
				continue
			var wy := 0.9 + (float(r) + 0.5) * gh
			var tint := cool.lightened(0.10 * _wobble(c, r, seed_v))
			if on > 0.72:
				tint = warm.darkened(0.30)
			e.box(Vector3(-hw + (float(c) + 0.5) * gw, wy, -hd - 0.03),
				Vector3(gw * 0.30, gh * 0.28, 0.012), tint)
			e.box(Vector3(-hw - 0.03, wy, -hd + (float(c) + 0.5) * (d / float(cols))),
				Vector3(0.012, gh * 0.28, d / float(cols) * 0.30), tint.darkened(0.18))

	# THE window. Bigger, warmer, top row, and the only one that is not random.
	e.box(Vector3(w * 0.18, h - 1.15, -hd - 0.05),
		Vector3(gw * 0.44, gh * 0.40, 0.014), warm)
	# Aircraft warning lights.
	for sx2 in [-1.0, 1.0]:
		var xs2: float = sx2
		e.box(Vector3(xs2 * (hw - 0.5), h + 1.20, 0.0), Vector3(0.11, 0.11, 0.11),
			Color(0.94, 0.16, 0.12))


# ===========================================================================
# 11. FILL POWER SIGN — a placard that answers a question nobody asked
# ===========================================================================
#
# An aisle placard on two posts. It exists so that at least once, at goose
# height, the room states in words what is in it: a fill power and a lot code
# and nothing else. Everything else in the warehouse is white bales; this is
# the only object that is text.

static func _fill_power_sign(b: RefCounted, e: RefCounted, _g: RefCounted, params: Dictionary) -> void:
	var post := _col(params, "colour", Color(0.34, 0.35, 0.37))
	var board := _col(params, "trim_colour", Color(0.90, 0.89, 0.85))
	var lit := _flag(params, "lit", false)

	for sx in [-1.0, 1.0]:
		var xs: float = sx
		b.box(Vector3(xs * 0.62, 0.99, 0.0), Vector3(0.045, 0.990, 0.045), post)
		b.box(Vector3(xs * 0.62, 0.025, 0.0), Vector3(0.100, 0.025, 0.090),
			post.darkened(0.30))
	b.box(Vector3(0.0, 1.565, 0.0), Vector3(0.760, 0.415, 0.030), board)
	b.box(Vector3(0.0, 1.565, 0.032), Vector3(0.775, 0.430, 0.012), post.darkened(0.2))
	# Hazard chevrons along the bottom rail, because a thing on two legs in an
	# aisle full of forklifts gets painted whether it wants to be or not.
	for i in 8:
		b.box(Vector3(-0.66 + float(i) * 0.19, 1.085, -0.014),
			Vector3(0.058, 0.045, 0.010),
			Color(0.90, 0.70, 0.14) if i % 2 == 0 else Color(0.11, 0.11, 0.12),
			Basis(Vector3.FORWARD, 0.5))
	if lit:
		e.box(Vector3(0.0, 1.565, -0.034), Vector3(0.740, 0.395, 0.010),
			Color(0.86, 0.88, 0.84))


static func _sign_board_text(model: Node3D, params: Dictionary) -> void:
	var t1 := _str(params, "text", "FILL 850")
	var t2 := _str(params, "code", "LOT 4471-B")
	var ink := _col(params, "ink_colour", Color(0.13, 0.14, 0.17))
	var n := Vector3(0.0, 0.0, -1.0)
	var right := Vector3.UP.cross(n)
	var m1 := TS.sign_text(model, t1,
		Vector3(0.0, 1.880, -0.032) - right * (TS.text_width(t1, 0.16) * 0.5),
		n, Vector3.UP, 0.16, ink, false, 0.014)
	if m1 != null:
		m1.name = "SignFill"
	var m2 := TS.sign_text(model, t2,
		Vector3(0.0, 1.640, -0.032) - right * (TS.text_width(t2, 0.085) * 0.5),
		n, Vector3.UP, 0.085, ink.lightened(0.18), false, 0.010)
	if m2 != null:
		m2.name = "SignLot"


# ===========================================================================
# 12. BRIEFCASE — he keeps it
# ===========================================================================
#
# He runs up four flights of stairs holding this, in a suit, in Georgia, in
# August. It is 0.46 x 0.34 x 0.12 and it is not breakable and it never leaves
# his hand; if it ever does, that is a joke somebody else gets to write.

static func _briefcase(b: RefCounted, _e: RefCounted, _g: RefCounted, params: Dictionary) -> void:
	var hide_col := _col(params, "colour", Color(0.235, 0.125, 0.105))
	var brass := _col(params, "trim_colour", Color(0.72, 0.60, 0.28))

	b.box(Vector3(0.0, 0.170, 0.0), Vector3(0.230, 0.170, 0.055), hide_col)
	# The seam, one shade down, all the way round.
	b.box(Vector3(0.0, 0.172, 0.0), Vector3(0.236, 0.008, 0.058), hide_col.darkened(0.34))
	# Corner caps.
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var xs: float = sx
			var ys: float = sy
			b.box(Vector3(xs * 0.212, 0.170 + ys * 0.152, 0.0),
				Vector3(0.022, 0.020, 0.058), brass.darkened(0.22))
	# Two latches.
	for sx2 in [-1.0, 1.0]:
		var xs2: float = sx2
		b.box(Vector3(xs2 * 0.105, 0.178, -0.058), Vector3(0.038, 0.026, 0.010), brass)
	# The handle: a squared-off arch, because a curved one is not available and
	# a straight bar reads as a suitcase.
	b.box(Vector3(0.0, 0.394, 0.0), Vector3(0.078, 0.014, 0.014), hide_col.darkened(0.18))
	for sx3 in [-1.0, 1.0]:
		var xs3: float = sx3
		b.box(Vector3(xs3 * 0.070, 0.362, 0.0), Vector3(0.014, 0.032, 0.014),
			hide_col.darkened(0.18))
		b.box(Vector3(xs3 * 0.070, 0.336, 0.0), Vector3(0.026, 0.012, 0.022), brass)


# ===========================================================================
# 13. FALLBACK — a faceted crate, so nothing is ever invisible
# ===========================================================================

static func _fallback(b: RefCounted, _e: RefCounted, _g: RefCounted, params: Dictionary) -> void:
	var col := _col(params, "colour", Color(0.52, 0.50, 0.48))
	var lo := _ring_y(0.02, 0.44, 0.44, 0.06)
	var hi := _ring_y(0.86, 0.44, 0.44, 0.06)
	b.loft([lo, hi], [Vector3(0.0, 0.02, 0.0), Vector3(0.0, 0.86, 0.0)], col)
	_cap_axial(b, hi, Vector3(0.0, 0.88, 0.0), Vector3.UP, col.lightened(0.10))
	_cap_axial(b, lo, Vector3(0.0, 0.00, 0.0), Vector3.DOWN, col.darkened(0.25))


# ===========================================================================
# PUBLIC QUERIES — what the encounter needs that a mesh cannot carry
# ===========================================================================

## Every box the encounter should turn into a StaticBody3D + BoxShape3D, in the
## model's own base-anchored LOCAL frame.
##
## Keys, both of which need an explicit type on read because a Dictionary
## lookup is a Variant:
##   "tag"  String   "wall" | "roof" | "parapet" | "column" | "slab" | "post"
##   "c"    Vector3  centre of the box, local
##   "s"    Vector3  FULL size of the box (BoxShape3D.size takes this directly)
##
## `c` is the box CENTRE and the model is BASE-anchored, so a body placed at
## `model_origin + c` with `BoxShape3D.size = s` lines up with the mesh exactly.
## Returns an empty array for every kind that owns no collision — the bale, the
## panes and the shutter are all the encounter's to decide.
##
##     for entry in BD.collider_boxes(&"warehouse_shell", p):
##         var c: Vector3 = entry["c"]
##         var s: Vector3 = entry["s"]
##         _hide_meshes(_static_box(origin + c, s, Color(1, 1, 1)))
static func collider_boxes(kind: StringName, params := {}) -> Array[Dictionary]:
	match kind:
		&"warehouse_shell":
			return _warehouse_boxes(params)
		&"atrium_shell":
			return _atrium_boxes(params)
		&"dock_apron":
			var w := _num(params, "width", 9.00)
			var d := _num(params, "depth", 5.20)
			var dy := _num(params, "dock_y", DOCK_Y)
			var run := _num(params, "ramp_run", 3.40)
			var hd := (d + run) * 0.5
			var out: Array[Dictionary] = []
			out.append({"tag": "slab", "c": Vector3(0.0, dy * 0.5, hd - d * 0.5),
				"s": Vector3(w, dy, d)})
			return out
		&"racking":
			# One thin deck per beam level, full width. A goose that flaps up to
			# a rack level and falls through it has learned the wrong lesson
			# about racking, and one box per level is cheaper than honesty.
			var bays := maxi(1, _int(params, "bays", 3))
			var h := _num(params, "height", 10.40)
			var levels := clampi(int((h - RACK_FIRST - 0.55) / RACK_LEVEL) + 1, 1, 8)
			var hx := (float(bays) * RACK_BAY + 0.10) * 0.5
			var racks: Array[Dictionary] = []
			for lv in levels:
				racks.append({"tag": "slab",
					"c": Vector3(0.0, RACK_FIRST + float(lv) * RACK_LEVEL + 0.03, 0.0),
					"s": Vector3(hx * 2.0, 0.14, RACK_DEPTH * 0.92)})
			return racks
	var empty: Array[Dictionary] = []
	return empty


## Every climbable slope in the model, in its own base-anchored LOCAL frame.
##
## Keys, each needing an explicit type on read:
##   "a"  Vector3  the FOOT, a point on the finished walking surface
##   "b"  Vector3  the HEAD, a point on the finished walking surface
##   "w"  float    walking width
##
## Same contract as zone_truckstop.gd's `_ramp(a, b, width, thick, col)`, which
## is what these are for. THIS IS NOT OPTIONAL DRESSING on the atrium: the
## stair treads in the mesh are decals, a CharacterBody3D does not climb a
## 0.18 m riser, and without these ramps the goose walks into the first step of
## every flight and stops there for the rest of the encounter.
static func climb_ramps(kind: StringName, params := {}) -> Array[Dictionary]:
	match kind:
		&"atrium_shell":
			return _atrium_flights(params)
		&"dock_apron":
			var w := _num(params, "width", 9.00)
			var d := _num(params, "depth", 5.20)
			var dy := _num(params, "dock_y", DOCK_Y)
			var run := _num(params, "ramp_run", 3.40)
			var rw := _num(params, "ramp_w", 2.60)
			var hd := (d + run) * 0.5
			var cx := w * 0.5 - 0.10 - rw * 0.5
			var out: Array[Dictionary] = []
			out.append({
				"a": Vector3(cx, 0.0, -hd),
				"b": Vector3(cx, dy, hd - d),
				"w": rw,
			})
			return out
	var empty: Array[Dictionary] = []
	return empty


## Paint the company mark on a flat face and return the node holding it.
##
## `centre` is the CENTRE of the whole mark (emblem + wordmark) as the reader
## sees it, not the top-left of the first glyph — the encounter is placing this
## on a trailer flank it already has the middle of, and making it derive a
## corner is how a decal ends up half off the end of a trailer.
##
## `normal` is the face's outward normal and `up` is which way is up on it. The
## advance direction is computed as `up × normal` inside sign_text; do not pass
## +X yourself. On a -Z-facing trailer flank that would ship NWOD GIB.
##
## This is BOSS_DESIGN.md §2.2.1's "it costs one prop to set up": the reveal is
## a decal on the side of a truck the player has been climbing on for a hundred
## seconds, and it is already painted twice per rig by zone_truckstop.gd:1296.
static func company_decal(parent: Node3D, centre: Vector3, normal: Vector3, up: Vector3,
		h: float, col: Color, unshaded := false, thickness := 0.03) -> Node3D:
	var node := Node3D.new()
	node.name = "Decal"
	parent.add_child(node)

	var n := normal.normalized()
	var u := up.normalized()
	var right := u.cross(n).normalized()
	var text := "BIG DOWN"
	var vis := TS.text_width(text, h) - h / 5.0
	var mark := h * 1.30
	var total := mark + h * 0.45 + vis
	var left := centre - right * (total * 0.5)

	# The emblem: an eight-sided puff with three short quills, which is as close
	# to "a tuft of down" as a faceted library gets and reads at forty metres as
	# a blob, which is also what a real logo does.
	var eb: RefCounted = LPB.new(0.0)
	var ec := left + right * (mark * 0.5) + n * (thickness * 0.5)
	var basis := Basis(right, u, n)
	var puff := LPB.ring(ec, n, u, mark * 0.40, mark * 0.40, 8, PI / 8.0)
	eb.loft([puff, LPB.ring(ec + n * thickness, n, u, mark * 0.40, mark * 0.40, 8, PI / 8.0)],
		[ec, ec + n * thickness], col)
	_cap_axial(eb, puff, ec - n * 0.001, -n, col)
	for i in 3:
		var a := -0.7 + float(i) * 0.7
		eb.box(ec + basis * Vector3(cos(a) * mark * 0.46, sin(a) * mark * 0.46, 0.0),
			Vector3(mark * 0.16, mark * 0.055, thickness * 0.5), col, basis * Basis(Vector3.BACK, a))
	LPB.attach(node, eb.commit(), glow_material() if unshaded else shared_material(), "Mark")

	TS.sign_text(node, text, left + right * (mark + h * 0.45) + u * (h * 0.5),
		n, u, h, col, unshaded, thickness)
	return node
