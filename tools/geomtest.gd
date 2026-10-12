extends RefCounted
## THE FOOTPRINT GATE — the eleventh, and the first thing ever to compare
## `prop_models.FOOTPRINTS` against the meshes it describes.
##
##     godot --headless --path . -- --probe --geomtest 2>&1 | grep '^\[geom\]'
##
## ═══════════════════════════════════════════════════════════════════════════
## FOOTPRINTS IS NOT DOCUMENTATION. IT IS LOAD-BEARING.
## ═══════════════════════════════════════════════════════════════════════════
##
## `prop_models.gd::build()` sizes every model it is asked for with
##
##     model.scale = want / footprint(kind)
##
## so a declared box that disagrees with the mesh makes **every `size:`-scaled
## placement wrong by exactly that ratio**, in every zone that asks for one. A
## prop declared 8% small comes out 8% large, forever, everywhere, and nothing
## says so — the model still looks like itself, just slightly the wrong size
## next to the collider it is hung on. `docs/HANDOFF.md` has suspected
## `down_bale` of being 8–12% small for two sessions and nothing could check it.
##
## ═══════════════════════════════════════════════════════════════════════════
## WHY THIS MEASURES BUILT ZONES AND NOT `build(kind, {})`
## ═══════════════════════════════════════════════════════════════════════════
##
## A previous attempt built every kind through `build(kind, {})` and crashed
## inside the builders, which want params an empty dictionary does not supply.
## `docs/HANDOFF.md` §4 records the attempt and the wall.
##
## The way past it is to stop constructing props and start measuring **the ones
## the zones already built**, with the params the zones actually pass. That also
## makes the coverage honest rather than theoretical: a kind no zone builds is
## reported as UNBUILT rather than silently passing.
##
## ═══════════════════════════════════════════════════════════════════════════
## THE ARITHMETIC
## ═══════════════════════════════════════════════════════════════════════════
##
## For a prop built with `size:`, `build()` sets `scale = want / declared`. The
## mesh under it is built at its NATURAL size, so:
##
##     natural = (world AABB of the model's meshes) / model.scale
##
## and `natural` is what `FOOTPRINTS[kind]` claims to be. The world size the
## player sees is `want * natural / declared`, so the error in the declaration
## is the error in the placement, one for one.
##
## Y IS CHECKED MORE LOOSELY THAN X AND Z, DELIBERATELY. Several kinds declare a
## height that is a design intent rather than a measurement — `fly_agaric`'s own
## comment says its 0.88 is "0.879 across the three variants", i.e. deliberately
## rounded — and a model with a droopy antenna or a leaning sign is taller than
## its useful box on purpose. The horizontal footprint is what `size:` scaling
## and every collider comparison actually depend on.

const COMMON := preload("res://tools/probe_common.gd")

## ═══════════════════════════════════════════════════════════════════════════
## WHAT IS ASSERTED, AND WHAT IS ONLY REPORTED — D-009’S SHAPE, ON PURPOSE
## ═══════════════════════════════════════════════════════════════════════════
##
## **ASSERTED: the meshes do not move.** Every kind’s measured extent is locked
## against the table below, which is what the builders emit today. Edit
## `_gnome()` and change its size and this says so. The spread across
## instances is 0.000 for fourteen of the fifteen kinds the zones build, so
## this is a tight, meaningful lock rather than a wide one.
##
## **REPORTED, NOT ASSERTED: the FOOTPRINTS declarations disagree with those
## meshes.** Eight of fifteen are out by more than 6% on a horizontal axis —
## `hydrant` by ‒28.5%, `gnome` by ‒23.7%, `stop_sign`’s depth by **+75%** —
## and `build()` scales with `want / footprint`, so each of those renders at
## the wrong size against the collider it is hung on.
##
## **The gate does not fix them, and that is deliberate.** Correcting a
## declaration changes `model.scale` NON-UNIFORMLY: `stop_sign` would go to
## (1.07, 1.01, 0.57), squashing a model somebody authored to look right into
## the box its collider promises. Whether a prop should be squashed to fit its
## hitbox or the hitbox resized to fit the prop is a LOOK, and looks are a
## design call, not a gate’s (`CLAUDE.md`, on taste). The same reasoning D-009
## used to lock the glide ratio as a regression guard without endorsing it.
## The disagreement is printed in full on every run and logged as D-036.
##
## To act on it: change the FOOTPRINTS entry to the measured value, run
## `verify.ps1 -Shots`, and look at the zone. That is a person’s afternoon, not
## a gate’s.
const MESH_BASELINE := {
	&"basketball": Vector3(0.390, 0.410, 0.400),
	&"bbq": Vector3(0.880, 0.975, 0.467),
	&"bench": Vector3(1.810, 0.857, 0.506),
	&"dumpster": Vector3(3.520, 2.241, 2.106),
	&"fence_panel": Vector3(2.288, 1.731, 0.176),
	&"garbage_bag": Vector3(0.504, 0.584, 0.454),
	&"gnome": Vector3(0.244, 0.545, 0.257),
	&"hydrant": Vector3(0.286, 0.800, 0.300),
	&"lawn_sign": Vector3(1.060, 0.780, 0.094),
	&"mailbox": Vector3(0.384, 0.295, 0.599),
	&"minivan": Vector3(2.130, 1.906, 4.615),
	&"patio_chair": Vector3(0.548, 0.913, 0.577),
	# 0.792 and not the 0.841 that stood here until 2026-08-19. The old figure
	# was the tub PLUS a chevron badge hanging 8.6 cm off the front of it, so
	# nearly a tenth of this kind's declared depth was a bug. Moving the badge
	# onto the tub took the declaration error from +5.1% to -1.0%.
	&"recycling_bin": Vector3(1.016, 1.215, 0.792),
	&"shopping_cart": Vector3(0.791, 1.002, 1.230),
	&"stop_sign": Vector3(0.665, 2.233, 0.280),
}

## How far a mesh may move from its baseline before it is a change rather than
## a rounding difference. 3% of the smallest thing here (a 0.24 m gnome) is
## 7 mm.
const DRIFT_TOL := 0.03

## The horizontal disagreement with FOOTPRINTS worth naming in the summary.
const REPORT_XZ := 0.06
## How far a declared footprint may sit from the mesh before it is wrong.
## 6% on the horizontal axes: `size:`-scaled placements inherit this error
## directly, and 6% of a 4.6 m minivan is 28 cm, which is a visible gap.
const TOL_XZ := 0.06

## 20% on the vertical, for the reason in the header: several heights are
## intents rather than measurements.
const TOL_Y := 0.20

## Below this a mesh is a decal or a marker, not a prop with a footprint.
const MIN_SIZE := 0.02

## How far the lowest vertex of a goose model may miss the capsule's contact
## point. 5 mm: small enough that the 101 mm and 180 mm this was written to
## catch cannot come back, and large enough to absorb the last digit of a
## FOOT_DROP written to three decimals. It is a placement error, not a
## measurement one — the mesh builders are deterministic and pass 1 reports
## 0.000 spread for fourteen of fifteen kinds, so there is no noise to leave
## room for.
const STANCE_TOL := 0.005

static var _fails: Array[String] = []
static var _checks := 0
static var _seen := {}
static var _off := 0
static var _worst := 0.0
static var _buried: Array[String] = []
static var _pickups := 0
static var _shape_skips := {}
static var _modelless := 0
static var _zone_tally: Array[String] = []
static var _stance: Array[String] = []


static func run(tree: SceneTree, main: Node) -> void:
	_fails.clear()
	_checks = 0
	_seen.clear()
	_off = 0
	_worst = 0.0
	_buried.clear()
	_pickups = 0
	_shape_skips.clear()
	_modelless = 0
	_zone_tally.clear()
	_stance.clear()
	await COMMON.settled(tree)   # probe_common lesson 10

	var route: Array = main.get_script().get_script_constant_map().get("ROUTE", [])
	if route.is_empty():
		print("[geom] FAIL — could not read main.gd's ROUTE")
		tree.quit(1)
		return

	var built := {}
	var was_leg: int = Flock.leg
	for i in route.size():
		var path := str(route[i].get("zone", ""))
		if path == "" or built.has(path):
			continue
		built[path] = true
		await _walk_zone(tree, main, i + 1, path)
	Flock.leg = was_leg

	await _stance_pass(tree, main)

	_report()
	if _fails.is_empty():
		print("[geom] PASS — %d footprint assertions across %d kinds, %d pickups clear of solids"
			% [_checks, _seen.size(), _pickups])
		tree.quit(0)
		return
	print("[geom] FAIL — %d, across %d footprint assertions and %d pickups:"
		% [_fails.size(), _checks, _pickups])
	for f in _fails:
		print("[geom]   %s" % f)
	tree.quit(1)


static func _walk_zone(tree: SceneTree, main: Node, leg: int, path: String) -> void:
	var zs = load(path)
	if zs == null:
		return
	Flock.leg = leg
	var z: Node = zs.new()
	main.add_child(z)
	# TWO FRAMES, BECAUSE A PICKUP'S MODEL IS NOT WHERE `setup()` PUT IT.
	# `substance_pickup.gd::setup()` writes `_model.position.y = 0.15` once, and
	# then `PickupModels.animate()` either preserves that (breathe, sway) or
	# overwrites it outright (bob, which assigns `position.y` absolutely), and a
	# substance with no model at all gets `_fallback` parked at y = 0.7. Measured
	# before the first `_process`, every pickup lies about where it renders — by
	# 0.15 m for the bob ones and by 0.55 m for the modelless ones, which is more
	# than the depths this pass is looking for.
	await tree.process_frame
	await tree.process_frame

	# THE ZONE, NOT THE TREE. `probe_common` boots the game to get a goose, and
	# booting builds leg 1 — so the strip mall is already in the tree, with all
	# its props and pickups, before the first walk starts, and it stays there for
	# the whole run. A `get_nodes_in_group()` here counts that zone once per walk
	# on top of the zone being measured. It did not move a median (the kinds are
	# identical per instance, spread 0.000 for fourteen of fifteen) but it made
	# every `n=` a fiction, and it made the pickup pass below report leg 1's bread
	# as buried in four zones that have never heard of it.
	for node in _in_group_under(z, "chaos_prop"):
		var prop := node as Node3D
		if prop == null or not is_instance_valid(prop):
			continue
		var model := prop.get_node_or_null("Mesh") as Node3D
		if model == null:
			continue
		var kind := StringName(str(model.get_meta("kind", "")))
		if kind == &"" or not model.has_meta("declared"):
			continue
		var natural := _natural_size(model)
		if natural == Vector3.ZERO or natural.x < MIN_SIZE:
			continue
		# EVERY instance, not the first. Several kinds take a `variant` seed that
		# changes the silhouette — `garbage_bag` is built with
		# `{"variant": i * 1.3}` seven times in leg 1 alone — so one sample is not
		# the kind. The spread is reported and the MEDIAN is what gets asserted.
		if not _seen.has(kind):
			_seen[kind] = {"declared": model.get_meta("declared"), "all": []}
		_seen[kind]["all"].append(natural)

	_bury_pass(z, path)

	main.remove_child(z)
	z.free()
	await tree.process_frame


## ═══════════════════════════════════════════════════════════════════════════
## PASS 2 — IS ANYTHING EDIBLE BURIED IN A SOLID?
## ═══════════════════════════════════════════════════════════════════════════
##
## Every pickup in this game is placed by hand-written arithmetic against a prop
## placed by other hand-written arithmetic, and **nothing has ever compared the
## two**. `zone_corn.gd::_sources()` carries a comment saying the first pass put
## a pickup "INSIDE the collider" and had to be moved; that was found by looking
## at a render, once. The thermos two lines below it was still inside the grain
## truck's cab afterwards, because the placement subtracts 1.3 m along world X
## and the truck is yawed 0.14 rad.
##
## WHAT IS WRONG WITH A BURIED PICKUP, stated honestly: it is not necessarily
## unreachable. `setup()` gives every pickup a 1.6 m SphereShape3D, wider than
## most props are thick, so one a handspan inside a wall can still be triggered
## from outside it. What is always true is that **the player cannot see what is
## on offer**, and recognising a substance before eating it is the one thing this
## game asks of them. Reachability is then an accident of whether the sphere
## happens to poke out, which is not a thing to leave to chance.
##
## ═══════════════════════════════════════════════════════════════════════════
## THE MESH, NOT THE Area3D. THE FIRST VERSION OF THIS PASS TESTED THE ORIGIN.
## ═══════════════════════════════════════════════════════════════════════════
##
## It reported nine, and **three of them were the instrument** — the newest
## entry in the long list at the top of `tools/probe_common.gd`. A pickup's
## Area3D origin is NOT where its model renders, and there are three different
## offsets in play:
##
##   * `breathe` and `sway` keep the `_model.position.y = 0.15` that `setup()`
##     writes, so those models ride 0.15 m ABOVE the origin — which is why
##     `zone_strip_mall.gd` places the toad and the mushrooms at
##     `VERGE_Y - PICKUP_LIFT` and is right to.
##   * `bob` assigns `model.position.y` outright every frame, destroying the
##     lift, so those sit AT the origin.
##   * a substance with no pickup model at all falls back to `_fallback`, which
##     `_animate()` parks at y = 0.7 — leg 1's bread, whose Area3D is 0.14 m
##     underground and whose visible blob is half a metre in the air.
##
## So the pass measures the world AABB of the meshes actually under the pickup,
## after two frames, and tests its CENTRE. The centre rather than the box
## because every pickup deliberately resting on a surface overlaps that surface.
static func _bury_pass(zone: Node, path: String) -> void:
	var solids := _solids_under(zone)
	var here := 0
	for node in _in_group_under(zone, "substance_source"):
		var pick := node as Node3D
		if pick == null or not is_instance_valid(pick):
			continue
		here += 1
		_pickups += 1
		var box := _mesh_box(pick)
		if box.size == Vector3.ZERO:
			_modelless += 1
			continue
		var p := box.get_center()
		var worst := -1.0
		var who := ""
		for sol in solids:
			var row: Dictionary = sol
			var xf: Transform3D = row.xform
			var sh: Shape3D = row.shape
			var d := _depth_inside(p, xf, sh)
			if d > worst:
				worst = d
				# "@StaticBody3D@873" identifies nothing. Where it is and how big it
				# is identifies it in one grep of the zone file.
				var centre := xf.origin
				var span := _extent_of(sh)
				who = "a solid at (%.1f, %.1f, %.1f) of %.2f x %.2f x %.2f" % [
					centre.x, centre.y, centre.z, span.x, span.y, span.z]
		if worst <= 0.0:
			continue
		var res: Object = pick.get("substance")
		var id := "?" if res == null else str(res.get("id"))
		_buried.append("%-20s %-14s at (%7.2f,%6.2f,%7.2f) is %.2f m inside %s"
			% [path.get_file(), id, p.x, p.y, p.z, worst, who])
	_zone_tally.append("%s %d" % [path.get_file(), here])



## ═══════════════════════════════════════════════════════════════════════════
## PASS 3 — DOES THE BIRD STAND ON THE GROUND, OR IN IT?
## ═══════════════════════════════════════════════════════════════════════════
##
## `move_and_slide()` rests the CAPSULE on the ground, and the player watches
## the MODEL. Nothing has ever compared the two, and `docs/HANDOFF.md` has
## carried "the lowpoly goose's webbed feet sit 5–10 cm below the collider and
## are underground whenever the bird stands" for two sessions as an estimate
## nobody could tighten — the number came from reading the constants, not from
## measuring the mesh.
##
## The controller's capsule is radius 0.34 laid along Z, so the contact point
## is 0.34 m below the body origin and the visual is a direct child at the
## origin. The lowest vertex of the visual therefore has to sit at or above
## -radius, and how far below it sits is exactly how deep the feet sink.
##
## BOTH VISUALS, not the one the pref happens to select. `goose_visual.gd` and
## `goose_visual_lowpoly.gd` are interchangeable by design (CLAUDE.md), which
## means a check that only ever measures one of them is checking a setting
## rather than the game.
static func _stance_pass(tree: SceneTree, main: Node) -> void:
	var goose: CharacterBody3D = await COMMON.fresh_goose(tree, main)
	if goose == null:
		_ok(false, "the stance pass could not get a goose, so it measured nothing")
		return
	var bottom := _capsule_bottom(goose)
	_ok(bottom < 0.0,
		"the goose has no capsule collider this pass can read — the stance check has gone blind")
	if bottom >= 0.0:
		return
	var models: Dictionary = goose.get_script().get_script_constant_map().get("MODEL_SCRIPTS", {})
	_ok(models.size() >= 2,
		"could not read goose_controller.gd's MODEL_SCRIPTS; the stance pass sees one visual at most")
	var prefs := tree.root.get_node_or_null("Prefs")
	_ok(prefs != null, "the stance pass needs Prefs to switch models and cannot find it")
	if prefs == null:
		return
	var was: String = str(prefs.get_pref(&"goose_model", "lowpoly"))
	var keys: Array = models.keys()
	keys.sort()
	for k in keys:
		var key := str(k)
		# THROUGH THE PREF, NOT BY CONSTRUCTING ONE. `_build_visual()` is what
		# places the model, and a pass that instances the script itself would
		# measure FOOT_DROP and prove nothing about whether the controller uses
		# it. Prefs.set_pref emits pref_changed, which is the path a player takes
		# through the options menu.
		prefs.set_pref(&"goose_model", key)
		await tree.process_frame
		await tree.process_frame
		var vis: Node3D = goose.get("visual")
		_ok(vis != null, "%s: the goose has no visual after switching to it" % key)
		if vis == null:
			continue
		var declared: float = vis.get_script().get_script_constant_map().get("FOOT_DROP", -1.0)
		_ok(declared > 0.0,
			("%s declares no FOOT_DROP, so goose_controller.gd cannot lift it onto the ground "
			+ "and falls back to standing it on its own origin.") % key)
		var box := _mesh_box(vis)
		_ok(box.size != Vector3.ZERO, "%s built no meshes to measure" % key)
		if box.size == Vector3.ZERO:
			continue
		var low := box.position.y - goose.global_position.y
		var sunk := bottom - low
		_stance.append("%-8s lowest vertex %+.3f m, capsule contact %+.3f m, sunk %+.3f m (FOOT_DROP %.3f)"
			% [key, low, bottom, sunk, declared])
		# ASSERTED. The whole point is that the model the player watches touches
		# the surface the physics rests on; a metre of tolerance would let the
		# thing this was written to catch straight back in.
		_ok(absf(sunk) <= STANCE_TOL,
			("the %s goose stands %.3f m %s the ground: its lowest vertex is at %.3f and the "
			+ "capsule contacts at %.3f. goose_controller.gd::_stand_visual() lifts the visual by "
			+ "FOOT_DROP - CAPSULE_RADIUS, so either FOOT_DROP (%.3f) no longer matches the mesh "
			+ "or the lift is not being applied.")
				% [key, absf(sunk), "into" if sunk > 0.0 else "above", low, bottom, declared])
	prefs.set_pref(&"goose_model", was)
	await tree.process_frame

## How far below the body origin the goose's capsule touches down. The capsule
## is laid along Z, so it is the radius — read off the shape rather than
## written here, because a controller that changes shape must not leave this
## measuring against a number from a comment.
static func _capsule_bottom(goose: Node3D) -> float:
	var stack: Array[Node] = [goose]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var cs := n as CollisionShape3D
		if cs == null or cs.shape == null:
			continue
		var cap := cs.shape as CapsuleShape3D
		if cap == null:
			continue
		return cs.position.y - cap.radius
	return 0.0

## World AABB of every mesh under `pick`, or a zero AABB if it has none.
static func _mesh_box(pick: Node3D) -> AABB:
	var box := AABB()
	var any := false
	var stack: Array[Node] = [pick]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null or not mi.visible:
			continue
		var mb: AABB = mi.global_transform * mi.mesh.get_aabb()
		box = mb if not any else box.merge(mb)
		any = true
	return box if any else AABB()

## Members of `group` that are inside `root`'s subtree. See the note in
## `_walk_zone`: the tree holds more than the zone under measurement.
static func _in_group_under(root: Node, group: String) -> Array:
	var out: Array = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n.is_in_group(group):
			out.append(n)
	return out

## Every enabled collision shape under every StaticBody3D in the zone.
static func _solids_under(root: Node) -> Array:
	var out: Array = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var body := n as StaticBody3D
		if body == null:
			continue
		for c2 in body.get_children():
			var cs := c2 as CollisionShape3D
			if cs == null or cs.shape == null or cs.disabled:
				continue
			out.append({"xform": cs.global_transform, "shape": cs.shape, "body": body})
	return out


## The full size of a shape this pass understands, for the report.
static func _extent_of(shape: Shape3D) -> Vector3:
	var box := shape as BoxShape3D
	if box != null:
		return box.size
	var sph := shape as SphereShape3D
	if sph != null:
		return Vector3.ONE * sph.radius * 2.0
	var cyl := shape as CylinderShape3D
	if cyl != null:
		return Vector3(cyl.radius * 2.0, cyl.height, cyl.radius * 2.0)
	return Vector3.ZERO

## How far `p` is inside `shape`, in metres, or -1.0 if it is outside. Only the
## three shapes the zones actually build are understood; anything else is
## counted in `_shape_skips` and printed, because a shape this cannot read is a
## hole in the check and a hole nobody prints is a hole nobody knows about.
static func _depth_inside(p: Vector3, xform: Transform3D, shape: Shape3D) -> float:
	var local := xform.affine_inverse() * p
	var box := shape as BoxShape3D
	if box != null:
		var half := box.size * 0.5
		var deep := INF
		for axis in 3:
			var slack: float = half[axis] - absf(local[axis])
			if slack <= 0.0:
				return -1.0
			deep = minf(deep, slack)
		return deep
	var sph := shape as SphereShape3D
	if sph != null:
		var reach := local.length()
		return sph.radius - reach if reach < sph.radius else -1.0
	var cyl := shape as CylinderShape3D
	if cyl != null:
		var radial: float = cyl.radius - Vector2(local.x, local.z).length()
		var axial: float = cyl.height * 0.5 - absf(local.y)
		if radial <= 0.0 or axial <= 0.0:
			return -1.0
		return minf(radial, axial)
	var kind := shape.get_class()
	_shape_skips[kind] = int(_shape_skips.get(kind, 0)) + 1
	return -1.0

## The model's mesh extent with its `size:` scaling divided back out, which is
## the number `FOOTPRINTS` claims to hold.
static func _natural_size(model: Node3D) -> Vector3:
	var box := AABB()
	var any := false
	var stack: Array[Node] = [model]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		# Into the model's own space, so a part offset inside the model counts
		# toward the extent exactly as it does on screen.
		var local := model.global_transform.affine_inverse() * mi.global_transform
		var mb: AABB = local * mi.mesh.get_aabb()
		box = mb if not any else box.merge(mb)
		any = true
	if not any:
		return Vector3.ZERO
	return box.size


static func _report() -> void:
	var kinds: Array = _seen.keys()
	kinds.sort()
	for k in kinds:
		var row: Dictionary = _seen[k]
		var declared: Vector3 = row.declared
		var samples: Array = row.all
		var natural := _median(samples)
		var spread := _spread(samples)
		var ex := _err(declared.x, natural.x)
		var ey := _err(declared.y, natural.y)
		var ez := _err(declared.z, natural.z)
		print("[geom] %-20s n=%-3d declared %6.2f %6.2f %6.2f   mesh %6.2f %6.2f %6.2f   err %+6.1f%% %+6.1f%% %+6.1f%%   spread %.3f"
			% [k, samples.size(), declared.x, declared.y, declared.z, natural.x, natural.y, natural.z,
				ex * 100.0, ey * 100.0, ez * 100.0, spread])
		# ASSERTED: the mesh has not moved.
		if MESH_BASELINE.has(k):
			var base: Vector3 = MESH_BASELINE[k]
			for axis in 3:
				var drift := _err(base[axis], natural[axis])
				_ok(absf(drift) <= DRIFT_TOL,
					("%s's mesh moved on axis %d: %.3f against a baseline of %.3f (%+.1f%%). The "
					+ "builders emit a fixed silhouette — spread across instances is 0.000 for "
					+ "fourteen of the fifteen kinds — so this is a change somebody made, not "
					+ "noise. If it was deliberate, update MESH_BASELINE in the same commit.")
						% [k, axis, natural[axis], base[axis], drift * 100.0])
		else:
			_ok(false,
				("%s is built by a zone and has no MESH_BASELINE entry, so nothing locks its "
				+ "size. Add the measured vector printed above.") % k)
		# REPORTED: the declaration disagrees. See the header for why this is not
		# asserted.
		if absf(ex) > REPORT_XZ or absf(ez) > REPORT_XZ:
			_off += 1
			_worst = maxf(_worst, maxf(absf(ex), absf(ez)))
	# A COPY-PASTE BASELINE, printed on every run. Transcribing these by hand
	# from the 2-dp table above is how the first version of MESH_BASELINE got
	# lawn_sign wrong by 4.7% and failed its own gate.
	print("[geom] MESH_BASELINE, as measured this run:")
	for k2 in kinds:
		var mrow: Dictionary = _seen[k2]
		var mm := _median(mrow.all)
		print("[geom]	&\"%s\": Vector3(%.3f, %.3f, %.3f)," % [k2, mm.x, mm.y, mm.z])

	# COVERAGE, STATED. A kind no zone builds has no measured mesh, so this gate
	# has nothing to say about it — and a gap nobody prints is a gap nobody
	# knows about. The seven builders declare more kinds than the zones use.
	print("[geom] %d kinds measured from built zones. Any kind no zone builds is not"
		% _seen.size())
	print("[geom] checked here at all; this gate measures what the game makes, not what")
	print("[geom] the tables offer.")
	print("[geom]")
	print("[geom] REPORTED, NOT ASSERTED: %d of %d kinds declare a horizontal footprint more"
		% [_off, _seen.size()])
	print("[geom]   than %.0f%% from the mesh they describe; the worst is %+.1f%%. build()"
		% [REPORT_XZ * 100.0, _worst * 100.0])
	print("[geom]   scales with want / footprint, so each of those renders at the wrong size")
	print("[geom]   against its collider. Correcting one rescales the model NON-UNIFORMLY,")
	print("[geom]   which is a look and therefore not an agent's call. docs/DECISIONS.md D-036.")

	print("[geom]")
	# ASSERTED, not merely reported. This started life as a report because the
	# first run found nine and three of them were the instrument; once those were
	# understood and the remaining six were fixed the list was empty, and an empty
	# list is the moment a report becomes a check. Six placements were wrong here
	# for the life of the project and nothing could see any of them.
	print("[geom] BURIED PICKUPS: %d of %d pickup models have their centre inside a"
		% [_buried.size(), _pickups])
	print("[geom]   static collider. Per zone: %s. %d had no mesh to measure."
		% [", ".join(_zone_tally), _modelless])
	for b in _buried:
		_fails.append(b + " — the player cannot see what is on offer, and whether it can"
			+ " be taken at all is left to whether the 1.6 m trigger sphere happens to poke out.")
	print("[geom]")
	print("[geom] STANCE: where each goose visual's lowest vertex sits against the")
	print("[geom]   capsule contact point the physics actually rests on.")
	for row in _stance:
		print("[geom]   %s" % row)
	if not _shape_skips.is_empty():
		print("[geom]   shapes this pass cannot read, so not covered: %s" % str(_shape_skips))

## Per-axis median of the samples for one kind. Median rather than mean
## because a `variant` seed can produce one outlier silhouette and the
## question is what the kind USUALLY is.
static func _median(samples: Array) -> Vector3:
	if samples.is_empty():
		return Vector3.ZERO
	var xs: Array[float] = []
	var ys: Array[float] = []
	var zs: Array[float] = []
	for v in samples:
		var s3: Vector3 = v
		xs.append(s3.x)
		ys.append(s3.y)
		zs.append(s3.z)
	xs.sort()
	ys.sort()
	zs.sort()
	var mid := xs.size() / 2
	return Vector3(xs[mid], ys[mid], zs[mid])


## Largest fractional spread on any axis across the samples, so a kind whose
## size genuinely varies is visible rather than averaged into a fiction.
static func _spread(samples: Array) -> float:
	if samples.size() < 2:
		return 0.0
	var lo: Vector3 = samples[0]
	var hi: Vector3 = samples[0]
	for v in samples:
		var s4: Vector3 = v
		lo = Vector3(minf(lo.x, s4.x), minf(lo.y, s4.y), minf(lo.z, s4.z))
		hi = Vector3(maxf(hi.x, s4.x), maxf(hi.y, s4.y), maxf(hi.z, s4.z))
	var worst := 0.0
	for axis in 3:
		if lo[axis] > 0.001:
			worst = maxf(worst, (hi[axis] - lo[axis]) / lo[axis])
	return worst

static func _err(declared: float, natural: float) -> float:
	if declared <= 0.001:
		return 0.0
	return (natural - declared) / declared


static func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_fails.append(msg)
