extends RefCounted
## THE GLIDE'S COST, MEASURED ACROSS EVERY BUILT ZONE.
##
##     godot --headless --path . -- --probe --glidetest 2>&1 | grep '^\[glide\]'
##
## ═══════════════════════════════════════════════════════════════════════════
## THIS IS A REPORT, NOT A GATE. IT ASSERTS NOTHING AND FAILS NOTHING.
## ═══════════════════════════════════════════════════════════════════════════
##
## `docs/DECISIONS.md` **D-006** is `Open (human)` and must stay open: whether
## one metre forward per metre down is the right glide is taste, and no file in
## this repo will ever have an opinion about it. But the argument AGAINST
## widening it is not taste — it is a claim about cost:
##
##   > "a 3:1 glide crosses [a zone] from a single flap stack, which trivialises
##   > the ground traversal the chaos scoring is built around, and silently
##   > invalidates *the goose cannot reach that* in eight zone builders."
##
## **Nobody had counted it.** That is the highest form of help available here
## per `CLAUDE.md`'s *"Taste is the human's"*: give an open decision its number
## without closing it. So this walks every zone the director builds, finds every
## surface a goose could stand on, and reports how many of them can be reached
## from another surface **by gliding alone** at today's ratio and at three
## candidates. The deliverable is the DIFF of those sets.
##
## ═══════════════════════════════════════════════════════════════════════════
## WHY GLIDE-ONLY, AND WHAT THAT DELIBERATELY EXCLUDES
## ═══════════════════════════════════════════════════════════════════════════
##
## The glide ratio decides what you can reach going **down and forward**. It has
## no effect on getting UP: a flap lifts 1.73 m whatever the glide is, and the
## stamina bar is what bounds a climb. So a wider glide cannot make a high place
## newly climbable — it can only make a *distant* place newly arrivable from a
## high place you already stand on.
##
## That is exactly the assumption "the goose cannot reach that" encodes, and it
## is the only part of level design the ratio can silently invalidate. Reporting
## anything else here would pad the number and weaken it.
##
## ═══════════════════════════════════════════════════════════════════════════
## THE APPROXIMATIONS, NAMED, BECAUSE A NUMBER WITHOUT ITS ERROR BARS IS A GUESS
## ═══════════════════════════════════════════════════════════════════════════
##
##   1. **Only axis-ish box colliders on static bodies.** This project is boxes;
##      `_static_box()` is how every zone builds solid geometry. A box with a
##      `rot_y` is measured by its axis-aligned footprint, which OVERSTATES its
##      extent and therefore UNDERSTATES the gap to its neighbours. Errs toward
##      "reachable", which is the conservative direction for an argument about
##      things becoming reachable.
##   2. **A surface is its top face.** Height is `centre.y + half.y`.
##   3. **Standable means the goose fits.** The capsule is 0.68 m wide and
##      1.10 m long, so a top face smaller than 0.75 m² is not a place anyone
##      stands and is dropped. Without this, every fence post and sign is a
##      "surface" and the counts are noise.
##   4. **Gliding is a straight line.** Real flight has `air_turn_rate` 4.2 and
##      a corridor of obstacles between any two roofs. Straight-line reach is an
##      UPPER bound on what a ratio buys, which again errs toward "reachable".
##   5. **No flap, no dive, no thermal, no stamina.** Pure glide from a standing
##      start at the edge. The measured `fly.glide_ratio` is 0.85 and
##      `feeltest.gd` asserts it in [0.70, 1.10].
##
## Every one of those pushes the same way: **the counts below are ceilings.** If
## a ratio does not open much here, it certainly does not open much in the game.

const COMMON := preload("res://tools/probe_common.gd")

## Today's measured glide, and the candidates worth costing. 3.0 is the number
## D-006's own argument names ("a 3:1 glide crosses one from a single flap
## stack"); 1.5 and 2.0 are between, because the decision is not binary and the
## interesting question is where the cliff is.
const RATIOS := [0.85, 1.5, 2.0, 3.0]

## Goose capsule 0.68 x 1.10. Anything smaller than this is a prop, not a place.
const MIN_STANDABLE_AREA := 0.75

## Above this, a surface is "elevated" — somewhere the player had to get to.
## 1.73 m is one flap, so this is a little under one flap of height.
const ELEVATED_Y := 1.5

## Zone scripts, in route order. Read off main.gd's ROUTE rather than listed
## here, so a new zone joins this report by existing.
static var _rows: Array[Dictionary] = []


static func run(tree: SceneTree, main: Node) -> void:
	_rows.clear()
	# A frame, because `run()` is reached from main._ready() and the scene root
	# refuses add_child() until it has finished setting up its own children —
	# silently, handing back an empty node. See docs/RECENT_FAILURES.md F-003.
	await tree.process_frame

	var route: Array = main.get_script().get_script_constant_map().get("ROUTE", [])
	if route.is_empty():
		print("[glide] FAIL — could not read main.gd's ROUTE")
		tree.quit(1)
		return

	print("[glide] glide ratios costed: %s   (measured today: %.2f : 1)"
		% [str(RATIOS), float(RATIOS[0])])
	print("[glide] a surface is standable at >= %.2f m^2 and elevated above %.1f m"
		% [MIN_STANDABLE_AREA, ELEVATED_Y])
	print("[glide]")

	var seen := {}
	var was_leg: int = Flock.leg
	for i in route.size():
		var leg := i + 1
		var path := str(route[i].get("zone", ""))
		if path == "":
			continue
		# Legs 1 and 2 share a script and now build different shelves, but the
		# GEOMETRY is identical — same colliders, same everything this measures.
		# Counting it twice would double every number in the totals.
		if seen.has(path):
			print("[glide] leg %d reuses %s — geometry already counted" % [leg, path.get_file()])
			continue
		seen[path] = true
		await _one_zone(tree, main, leg, path, str(route[i].get("name", "?")))
	Flock.leg = was_leg

	_totals()
	tree.quit(0)


static func _one_zone(tree: SceneTree, main: Node, leg: int, path: String, zone_name: String) -> void:
	var zs = load(path)
	if zs == null:
		print("[glide] leg %d: %s did not load" % [leg, path])
		return
	Flock.leg = leg
	var z: Node = zs.new()
	main.add_child(z)
	var surfaces := _surfaces(z)
	main.remove_child(z)
	z.free()
	await tree.process_frame

	var elevated: Array[Dictionary] = []
	for s in surfaces:
		if float(s.y) > ELEVATED_Y:
			elevated.append(s)

	# For each ratio: which elevated surfaces are reachable from SOME other
	# surface by pure glide, and what is the longest reach available.
	var reach_sets: Array[Dictionary] = []
	var longest: Array[float] = []
	for r in RATIOS:
		var ratio: float = float(r)
		var reached := {}
		var far := 0.0
		for a in surfaces:
			for b_i in elevated.size():
				var b: Dictionary = elevated[b_i]
				if a == b:
					continue
				var drop: float = float(a.y) - float(b.y)
				if drop <= 0.0:
					continue  # cannot glide UP; that is what flaps are for
				var gap: float = _gap(a, b)
				if gap <= 0.0:
					continue  # touching or overlapping footprints
				if gap <= drop * ratio:
					reached[b_i] = true
					far = maxf(far, gap)
		reach_sets.append(reached)
		longest.append(far)

	var base: Dictionary = reach_sets[0]
	var line := "[glide] leg %d  %-22s  %3d standable, %3d elevated | reachable by glide:" % [
		leg, zone_name.substr(0, 22), surfaces.size(), elevated.size()]
	for ri in RATIOS.size():
		line += "  %.2f:%d" % [float(RATIOS[ri]), reach_sets[ri].size()]
	print(line)

	var newly: Array[int] = []
	for ri in RATIOS.size():
		var n := 0
		for k in reach_sets[ri].keys():
			if not base.has(k):
				n += 1
		newly.append(n)
	var newly_txt := ""
	for ri in range(1, RATIOS.size()):
		newly_txt += "  +%d at %.1f:1" % [newly[ri], float(RATIOS[ri])]
	print("[glide]          newly reachable vs today:%s   | longest glide available: %.1f m -> %.1f m"
		% [newly_txt, longest[0], longest[RATIOS.size() - 1]])

	_rows.append({
		"leg": leg, "name": zone_name, "standable": surfaces.size(),
		"elevated": elevated.size(), "reach": reach_sets.map(func(d: Dictionary) -> int: return d.size()),
		"newly": newly,
	})


static func _totals() -> void:
	if _rows.is_empty():
		return
	var standable := 0
	var elevated := 0
	var reach: Array[int] = []
	var newly: Array[int] = []
	for _i in RATIOS.size():
		reach.append(0)
		newly.append(0)
	for row in _rows:
		standable += int(row.standable)
		elevated += int(row.elevated)
		for ri in RATIOS.size():
			reach[ri] += int(row.reach[ri])
			newly[ri] += int(row.newly[ri])
	print("[glide]")
	print("[glide] ── ALL ZONES ─────────────────────────────────────────────")
	print("[glide] %d standable surfaces, %d of them elevated above %.1f m"
		% [standable, elevated, ELEVATED_Y])
	for ri in RATIOS.size():
		var pct := 0.0
		if elevated > 0:
			pct = 100.0 * float(reach[ri]) / float(elevated)
		print("[glide] %.2f : 1  ->  %3d of %d elevated surfaces glide-reachable (%.0f%%)%s"
			% [float(RATIOS[ri]), reach[ri], elevated, pct,
				"" if ri == 0 else "   [+%d vs today]" % newly[ri]])
	print("[glide]")
	print("[glide] THIS IS THE NUMBER D-006 WAS MISSING. It is an upper bound —")
	print("[glide] straight-line, no obstacles, axis-aligned footprints — so the")
	print("[glide] real figure is at most this. D-006 stays Open (human).")


# ────────────────────────────────────────────────────────────────── geometry

## Every top face in the zone big enough to stand on.
## `{pos: Vector3 (top-face centre), half: Vector2 (x,z extent), y: float}`
static func _surfaces(root: Node) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var cs := n as CollisionShape3D
		if cs == null or cs.shape == null or cs.disabled:
			continue
		# Static geometry only. A RigidBody3D is a prop: it rolls away, and a
		# surface you cannot rely on is not level design.
		if (cs.get_parent() as StaticBody3D) == null:
			continue
		var box := cs.shape as BoxShape3D
		if box == null:
			continue
		var xf := cs.global_transform
		var sz: Vector3 = box.size * 0.5
		# Axis-aligned footprint of a possibly-yawed box. Overstates extent,
		# which understates gaps — see approximation 1 in the header.
		var b := xf.basis
		var hx: float = absf(b.x.x) * sz.x + absf(b.y.x) * sz.y + absf(b.z.x) * sz.z
		var hz: float = absf(b.x.z) * sz.x + absf(b.y.z) * sz.y + absf(b.z.z) * sz.z
		var hy: float = absf(b.x.y) * sz.x + absf(b.y.y) * sz.y + absf(b.z.y) * sz.z
		if hx * hz * 4.0 < MIN_STANDABLE_AREA:
			continue
		out.append({
			"pos": xf.origin,
			"half": Vector2(hx, hz),
			"y": xf.origin.y + hy,
		})
	return out


## Horizontal gap between two footprints, edge to edge. Zero if they overlap.
static func _gap(a: Dictionary, b: Dictionary) -> float:
	var pa: Vector3 = a.pos
	var pb: Vector3 = b.pos
	var ha: Vector2 = a.half
	var hb: Vector2 = b.half
	var dx: float = maxf(0.0, absf(pa.x - pb.x) - ha.x - hb.x)
	var dz: float = maxf(0.0, absf(pa.z - pb.z) - ha.y - hb.y)
	return sqrt(dx * dx + dz * dz)
