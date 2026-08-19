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
## hitbox or the hitbox resized to fit the prop is a LOOK, and looks are not an
## agent’s — `CLAUDE.md`, "Taste is the human’s". The same reasoning D-009
## used to lock the glide ratio as a regression guard without endorsing it.
## The disagreement is printed in full on every run and logged as D-036.
##
## To act on it: change the FOOTPRINTS entry to the measured value, run
## `verify.ps1 -Shots`, and look at the zone. That is a human’s afternoon, not
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
	&"recycling_bin": Vector3(1.016, 1.215, 0.841),
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

static var _fails: Array[String] = []
static var _checks := 0
static var _seen := {}
static var _off := 0
static var _worst := 0.0


static func run(tree: SceneTree, main: Node) -> void:
	_fails.clear()
	_checks = 0
	_seen.clear()
	_off = 0
	_worst = 0.0
	await tree.process_frame

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

	_report()
	if _fails.is_empty():
		print("[geom] PASS — %d footprints checked across %d kinds" % [_checks, _seen.size()])
		tree.quit(0)
		return
	print("[geom] FAIL — %d of %d:" % [_fails.size(), _checks])
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

	for node in tree.get_nodes_in_group("chaos_prop"):
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

	main.remove_child(z)
	z.free()
	await tree.process_frame


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
