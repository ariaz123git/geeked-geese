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
##   6. **A barrier is not a place.** Every zone rings itself with four
##      invisible boundary walls, 80 m long and 1 m thick, and the first run of
##      this file called all four "the most dangerous drop in the game" in all
##      seven zones at once. They are excluded by SHAPE — long and thin — and
##      `_surfaces()` records why the two more obvious tests (area, visibility)
##      were both wrong, the second one dangerously so.
##
## Every one of those pushes the same way: **the counts below are ceilings.** If
## a ratio does not open much here, it certainly does not open much in the game.

const COMMON := preload("res://tools/probe_common.gd")

## Today's measured glide, and the candidates worth costing. 3.0 is the number
## D-006's own argument names ("a 3:1 glide crosses one from a single flap
## stack"); 1.5 and 2.0 are between, because the decision is not binary and the
## interesting question is where the cliff is.
const RATIOS := [0.85, 1.5, 2.0, 3.0]

## A surface at least this long in one axis and at most this thick in the other
## is a wall or a fence run, not somewhere anyone stands. See `_surfaces()` for
## the three tries it took to land on this test.
const BARRIER_LEN := 30.0
const BARRIER_THICK := 2.0

## The goose capsule's width. A top face narrower than this in EITHER horizontal
## axis is not somewhere the bird can stand, whatever its area — see `_surfaces`.
const CAPSULE_W := 0.68

## Goose capsule 0.68 x 1.10. Anything smaller than this is a prop, not a place.
const MIN_STANDABLE_AREA := 0.75

## Above this, a surface is "elevated" — somewhere the player had to get to.
## 1.73 m is one flap, so this is a little under one flap of height.
const ELEVATED_Y := 1.5

## ═══════════════════════════════════════════════════════════════════════════
## AND THE SAME WALK ANSWERS D-005, WHICH IS WHY IT IS IN THIS FILE
## ═══════════════════════════════════════════════════════════════════════════
##
## `docs/DECISIONS.md` **D-005** is the other `Open (human)` traversal decision:
## a plain descent arrives above `hard_landing_speed`, and on the seven
## substances that set `ragdoll_landings` that is an unavoidable faceplant.
## `docs/FEEL_TARGETS.md` §5.2 now carries the closed form —
##
##     h = v² / 2g = 13.0² / (2 × 11.0) = 7.68 m
##
## — and what it was still missing was **how much of the built game is above
## that line**. That is the same enumeration of standable surfaces this file
## already does, so doing it anywhere else would be a second copy of the walk.
##
## Both numbers are read out of `goose_controller.gd`'s exports rather than
## copied, so if either is tuned this report follows it instead of quietly
## describing a game that no longer exists.
const CONTROLLER := "res://scripts/goose/goose_controller.gd"

## The document that publishes this report's totals. Bound to them at the end of
## `_totals()` so the table cannot outlive the measurement.
const DOC_FEEL := "res://docs/FEEL_TARGETS.md"

## How far a surface may be from a lower one and still count as "somewhere you
## could step down to" rather than a separate structure. One flap of horizontal
## travel at `air_speed` 14.0 over the 0.30 s cooldown is 4.2 m; 4.0 is a round
## number just under it, and the census prints its own sensitivity so the choice
## can be argued with.
const GENTLE_GAP := 4.0

## Zone scripts, in route order. Read off main.gd's ROUTE rather than listed
## here, so a new zone joins this report by existing.
## Every zone builder rings its level with four invisible boundary walls. This
## is a fact about the eight builders, asserted rather than assumed — see the
## check at the end of `_totals()`.
const EXPECTED_BARRIERS := 4

## The emptiest built zone (the cut corn) keeps 5. Three is a floor with room,
## and a walk that returns fewer has eaten something.
const MIN_KEPT := 3

static var _filter_ok := true
static var _rows: Array[Dictionary] = []

## WHAT EACH ZONE WALK THREW AWAY, PRINTED ON EVERY RUN.
##
## This is not diagnostics, it is the check that would have caught the mistake
## that produced this file's first published conclusion. A filter that quietly
## eats the level design looks exactly like a filter that works: the report
## still prints confident, specific numbers. The one that ate 73 of 158
## surfaces — every landable roof in the game — would have been obvious in one
## glance at a line saying so.
static var _dropped := {}


static func run(tree: SceneTree, main: Node) -> void:
	_rows.clear()
	_filter_ok = true
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

	var hard_drop := _hard_drop()
	if hard_drop <= 0.0:
		print("[glide] FAIL — could not read hard_landing_speed / glide_gravity out of")
		print("[glide]   %s. This report has gone blind rather than guessing." % CONTROLLER)
		tree.quit(1)
		return
	print("[glide] a descent lands HARD above %.2f m  (v^2/2g, off the controller's own exports)"
		% hard_drop)
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
		await _one_zone(tree, main, leg, path, str(route[i].get("name", "?")), hard_drop)
	Flock.leg = was_leg

	_totals(hard_drop)
	tree.quit(0 if _filter_ok else 1)


## The height above which a no-flap descent arrives faster than
## `hard_landing_speed`, read out of the controller's exports rather than
## copied. Returns 0.0 if either export cannot be parsed, which the caller
## treats as a failure — a report that silently invents a threshold is worse
## than no report.
static func _hard_drop() -> float:
	var f := FileAccess.open(CONTROLLER, FileAccess.READ)
	if f == null:
		return 0.0
	var src := f.get_as_text()
	f.close()
	var speed := _export_float(src, "hard_landing_speed")
	var grav := _export_float(src, "glide_gravity")
	if speed <= 0.0 or grav <= 0.0:
		return 0.0
	return speed * speed / (2.0 * grav)


static func _read(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var body := f.get_as_text()
	f.close()
	return body


static func _export_float(src: String, field: String) -> float:
	var re := RegEx.new()
	re.compile("@export var %s\\s*:=\\s*(-?[0-9]+(?:\\.[0-9]+)?)" % field)
	var m := re.search(src)
	return 0.0 if m == null else float(m.get_string(1))


static func _one_zone(tree: SceneTree, main: Node, leg: int, path: String, zone_name: String,
		hard_drop: float) -> void:
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

	# ── D-005: the drops, off the same enumeration ──────────────────────────
	#
	# For every standable surface, the GENTLEST way down: the highest other
	# surface within GENTLE_GAP horizontally, or the ground if there is none.
	# If even the gentlest descent from a surface exceeds `hard_drop`, then
	# EVERY way off that surface lands hard — and on the seven substances that
	# set `ragdoll_landings`, every way off it is a faceplant.
	var hard_surfaces := 0
	var worst_drop := 0.0
	var worst_at := Vector3.ZERO
	for s_i in surfaces.size():
		var s: Dictionary = surfaces[s_i]
		var sy: float = float(s.y)
		if sy <= hard_drop:
			continue  # cannot exceed the threshold even falling to y = 0
		var best_below := 0.0  # the ground
		for o_i in surfaces.size():
			if o_i == s_i:
				continue
			var o: Dictionary = surfaces[o_i]
			var oy: float = float(o.y)
			if oy >= sy:
				continue
			if _gap(s, o) > GENTLE_GAP:
				continue
			best_below = maxf(best_below, oy)
		var gentlest: float = sy - best_below
		if gentlest > hard_drop:
			hard_surfaces += 1
			if gentlest > worst_drop:
				worst_drop = gentlest
				worst_at = s.pos
	print("[glide]          D-005: %d of %d standable surfaces have NO soft way down (> %.2f m); worst gentlest drop %.1f m at (%.0f, %.0f, %.0f)"
		% [hard_surfaces, surfaces.size(), hard_drop, worst_drop, worst_at.x, worst_at.y, worst_at.z])
	print("[glide]          kept %d; dropped %d not-static, %d not-a-box, %d too narrow for the capsule, %d barriers, %d too small"
		% [surfaces.size(), int(_dropped.not_static), int(_dropped.not_box),
			int(_dropped.too_narrow), int(_dropped.barrier), int(_dropped.too_small)])

	_rows.append({
		"leg": leg, "name": zone_name, "standable": surfaces.size(),
		"elevated": elevated.size(), "reach": reach_sets.map(func(d: Dictionary) -> int: return d.size()),
		"newly": newly, "hard": hard_surfaces, "worst": worst_drop,
		"barriers": int(_dropped.barrier), "kept": surfaces.size(),
	})


static func _totals(hard_drop: float) -> void:
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
	var hard := 0
	var worst := 0.0
	for row in _rows:
		hard += int(row.hard)
		worst = maxf(worst, float(row.worst))
	print("[glide]")
	print("[glide] ── D-005: THE DROPS ──────────────────────────────────────")
	print("[glide] %d of %d standable surfaces have no soft way down at all —"
		% [hard, standable])
	print("[glide]   every descent from them exceeds %.2f m and lands hard. The worst" % hard_drop)
	print("[glide]   is %.1f m, which arrives at %.1f m/s against a threshold of %.1f." % [
		worst, sqrt(2.0 * 11.0 * worst), 13.0])
	print("[glide]   7 of the 16 substances set ragdoll_landings, so on 44%% of the")
	print("[glide]   shelf those are unavoidable faceplants.")
	print("[glide]")
	# ── THE FILTER HAS TO BE HONEST, AND THIS IS THE ONLY THING THAT SAYS SO ──
	#
	# A reporting probe that asserts nothing can publish a confident wrong
	# number into a decision document, and this one did: its first run counted
	# the four invisible boundary walls as glide platforms and argued close to
	# the opposite of the truth. `docs/RECENT_FAILURES.md` F-004 is the record,
	# and this is the check that retires it.
	#
	# Two facts about how every zone builder in this project works, and a report
	# whose filter has stopped matching them is not a report:
	#
	#   * EVERY zone rings itself with exactly four boundary walls. Zero
	#     dropped means the walls are being counted as level design again —
	#     which is precisely the original bug. More or fewer than four means a
	#     builder changed and this file's denominator moved without anyone
	#     deciding it should.
	#   * EVERY zone has SOMETHING standable in it. A walk that keeps almost
	#     nothing has eaten the level design, which is what the visibility
	#     filter did on try three: 73 of 158 surfaces gone, every landable roof
	#     among them, and the totals collapsed from +44 to +1.
	var filter_fails: Array[String] = []
	for row in _rows:
		if int(row.barriers) != EXPECTED_BARRIERS:
			filter_fails.append("leg %d (%s) dropped %d barriers, not %d — either a zone stopped building its four boundary walls, or they are being counted as level design again (which is the bug F-004 records)." % [
				int(row.leg), str(row.name), int(row.barriers), EXPECTED_BARRIERS])
		if int(row.kept) < MIN_KEPT:
			filter_fails.append("leg %d (%s) kept only %d standable surfaces. A filter that eats the level design still prints confident numbers; this is the line that says it did." % [
				int(row.leg), str(row.name), int(row.kept)])
	# AND THE DOCUMENT THAT PUBLISHES THESE NUMBERS HAS TO STILL AGREE WITH THEM.
	#
	# The other half of F-004: a decision document quoted this report's totals,
	# the report was later corrected, and nothing connected the two. `doctest.gd`
	# cannot claim these — it would have to build all seven zones to recompute
	# them — so the binding lives here, in the file that already has them.
	var doc := _read(DOC_FEEL)
	if doc == "":
		filter_fails.append("docs/FEEL_TARGETS.md is unreadable, so the published glide table cannot be checked against this run.")
	else:
		var re_tot := RegEx.new()
		re_tot.compile("[*][*]([0-9]+) standable surfaces across the seven zones, ([0-9]+) of them elevated")
		var m_tot := re_tot.search(doc)
		if m_tot == null:
			filter_fails.append("docs/FEEL_TARGETS.md §5.1 no longer states \"N standable surfaces across the seven zones, M of them elevated\" — the prose moved and this binding has gone blind.")
		else:
			var doc_standable := int(m_tot.get_string(1))
			var doc_elevated := int(m_tot.get_string(2))
			if doc_standable != standable or doc_elevated != elevated:
				filter_fails.append("docs/FEEL_TARGETS.md §5.1 says %d standable / %d elevated; this run measures %d / %d. The table is describing a game that has changed." % [
					doc_standable, doc_elevated, standable, elevated])
		var re_today := RegEx.new()
		re_today.compile("[*][*]([0-9]+) of ([0-9]+) — ([0-9]+)%[*][*]")
		var m_today := re_today.search(doc)
		if m_today == null:
			filter_fails.append("docs/FEEL_TARGETS.md §5.1's today-row no longer reads \"**N of M — P%**\" — the table format changed and this binding has gone blind.")
		elif int(m_today.get_string(1)) != reach[0] or int(m_today.get_string(2)) != elevated:
			filter_fails.append("docs/FEEL_TARGETS.md §5.1 publishes %s of %s reachable at today's glide; this run measures %d of %d." % [
				m_today.get_string(1), m_today.get_string(2), reach[0], elevated])

	if not filter_fails.is_empty():
		print("[glide]")
		print("[glide] FAIL — the surface filter is not behaving:")
		for ff in filter_fails:
			print("[glide]   %s" % ff)
		_filter_ok = false
		return

	print("[glide] THIS IS THE NUMBER D-006 WAS MISSING. It is an upper bound —")
	print("[glide] straight-line, no obstacles, axis-aligned footprints — so the")
	print("[glide] real figure is at most this. D-006 stays Open (human).")


# ────────────────────────────────────────────────────────────────── geometry

## Every top face in the zone big enough to stand on.
## `{pos: Vector3 (top-face centre), half: Vector2 (x,z extent), y: float}`
static func _surfaces(root: Node) -> Array[Dictionary]:
	_dropped = {"not_static": 0, "not_box": 0, "too_narrow": 0, "barrier": 0, "too_small": 0}
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
		var body := cs.get_parent() as StaticBody3D
		if body == null:
			_dropped.not_static += 1
			continue
		var box := cs.shape as BoxShape3D
		if box == null:
			_dropped.not_box += 1
			continue
		var xf := cs.global_transform
		var sz: Vector3 = box.size * 0.5
		# Axis-aligned footprint of a possibly-yawed box. Overstates extent,
		# which understates gaps — see approximation 1 in the header.
		var b := xf.basis
		var hx: float = absf(b.x.x) * sz.x + absf(b.y.x) * sz.y + absf(b.z.x) * sz.z
		var hz: float = absf(b.x.z) * sz.x + absf(b.y.z) * sz.y + absf(b.z.z) * sz.z
		var hy: float = absf(b.x.y) * sz.x + absf(b.y.y) * sz.y + absf(b.z.y) * sz.z
		# AREA IS NOT ENOUGH, AND THE FIRST RUN OF THIS FILE PROVED IT.
		#
		# Every zone reported exactly "4 of N surfaces have no soft way down",
		# and legs 1 and 3 named the SAME worst position, (-40, 6, -0). Four,
		# every time, in seven different zones: the invisible boundary walls.
		# A wall's top face is 80 x 0.5 = 40 m^2, which sails past an area test,
		# and it has no neighbour by construction, so it looked like the most
		# dangerous drop in the game in every zone at once.
		#
		# This is `probe_common.gd`'s lesson 1 in a new costume — the harness
		# accusing a healthy game — and the fix is to ask the question the area
		# test was standing in for: DOES THE BIRD FIT? The capsule is 0.68 wide,
		# so the top face has to contain a 0.68 x 0.68 square. A wall 0.5 m thick
		# does not, and neither does a fence rail or a sign edge.
		if minf(hx, hz) * 2.0 < CAPSULE_W:
			_dropped.too_narrow += 1
			continue
		# A BARRIER IS NOT A PLACE, AND FINDING THE RIGHT TEST FOR THAT TOOK
		# THREE TRIES. This is the instrument-accuses-the-game pattern that
		# `probe_common.gd`'s header is entirely about, and it cost two full
		# runs here.
		#
		#   1. Area alone. Every zone reported exactly "4 of N surfaces have no
		#      soft way down", legs 1 and 3 naming the SAME worst position
		#      (-40, 6, -0). Four, every time, in seven different zones: the
		#      invisible boundary walls, `Vector3(LOT, 14.0, 1.0)` boxes whose
		#      80 x 1 m top face 13 m up has nothing beside it. 40 m^2 sails
		#      past an area test.
		#   2. Capsule fit. They are a full metre thick. The bird fits. No help.
		#   3. Visibility — "you cannot plan to land on something you cannot
		#      see." **Wrong, and badly so.** `zone_suburbia.gd::_hide_meshes()`
		#      hides a body's graybox "wherever the visual is replaced by a
		#      model that spans several colliders at once (the fence run, the
		#      trampoline's ring of legs, THE ROOF PLATEAU)". That filter threw
		#      away 73 of 158 surfaces including every landable roof — the
		#      surfaces this report exists to count — and the totals collapsed
		#      from +44 newly reachable at 3:1 to +1, which would have argued
		#      the exact opposite conclusion.
		#
		# What actually separates a wall from a roof is its SHAPE. A boundary
		# wall is 80 m long and 1 m thick; a roof plateau is 12 x 8, racking is
		# 2.7 x 1.0, a truck trailer is 13 x 2.6. Nothing in this game that is
		# meant to be stood on is 30 m long and under 2 m wide.
		if maxf(hx, hz) * 2.0 >= BARRIER_LEN and minf(hx, hz) * 2.0 <= BARRIER_THICK:
			_dropped.barrier += 1
			continue
		if hx * hz * 4.0 < MIN_STANDABLE_AREA:
			_dropped.too_small += 1
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
