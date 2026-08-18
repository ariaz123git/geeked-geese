extends RefCounted
## THE INVARIANT HARNESS — the second gate.
##
## `tools/gate.gd` proves every file COMPILES. It cannot prove the game AGREES
## WITH ITSELF, and every expensive bug in this project's history has been a
## disagreement rather than a compile error:
##
##   * The clock lie, three times. `mission.gd` assumed a hardcoded 180 s base
##     while `main.gd` read `ROUTE`; the card promised 3:00 and the game gave
##     2:30. Fixed. Then the clamp was written out by hand in two places, drifted
##     to different ranges, and the card spent a build promising a number the
##     game would not honour. Fixed. Then leg 1 — the only leg that never passes
##     through `_on_migration_done()` — turned out to have been running 180 s
##     against a route that says 240 for the entire life of the project.
##   * `ROUTE[i].name` was read by NOTHING. Leg 1 called itself the strip mall
##     lot; the route, the campaign spec and the ending's own credit roll all
##     call it the retention pond.
##   * A zone id with no entry in `mission_defs.for_zone()` does not error. It
##     falls through to `_generic()` and the leg is quietly playable-but-wrong.
##
## Not one of those is findable by compiling. All of them are one assertion each.
##
## Run it:
##     godot --headless --path . -- --selftest 2>&1 | grep '^\[selftest\]'
## Exit 0 = every invariant holds. Exit 1 = at least one does not, and the
## failing lines say which. Like the gate, it runs INSIDE the booted project,
## because half of what it checks lives in an autoload.
##
## THE RULE FOR ADDING TO THIS FILE: an assertion goes in here when a bug got
## through once. Do not add aspirational checks; add regressions.

const SUBSTANCE_DIR := "res://data/substances"

## The keys in `Substance.resolve()` that are CONTROL MUTATIONS — things that
## change how the player's hands work — as opposed to numbers that go up.
## `speed_mult` and `chaos_mult` are deliberately NOT in this list: they are the
## two the design rule at the top of scripts/core/substance.gd exists to forbid.
const CONTROL_KEYS := [
	"input_lag", "drift", "flap_mult", "gravity_mult", "turn_mult",
	"ragdoll_landings", "cannot_idle", "time_scale", "smash_through",
	"camera_detach", "grid_snap", "hud_amnesia", "hallucinate",
	"no_fall_damage", "scale_amp", "aggro_cats", "no_early_exit",
]

## Zone ids for each ROUTE leg, in order. Collected once by _the_objectives()
## and reused by _the_ambience(), because instantiating every zone builder twice
## per run is expensive enough to matter.
static var _route_zone_ids: Array[StringName] = []

static var _fails: Array[String] = []
static var _checks := 0


static func run(tree: SceneTree, main: Node) -> void:
	_fails.clear()
	_checks = 0
	_route_zone_ids.clear()

	_the_route(main)
	_the_clock(main)
	_the_titles(main)
	_the_substances(main)
	_the_objectives(main)
	_the_overrides(main)
	_the_defs_are_wired()
	_the_labels_are_emitted()
	_the_ambience(main)
	_the_rig_schedule(main)
	_the_assets()
	_the_time_scale()

	if _fails.is_empty():
		print("[selftest] PASS — %d invariants hold" % _checks)
		tree.quit(0)
		return
	print("[selftest] FAIL — %d of %d invariants broken:" % [_fails.size(), _checks])
	for f in _fails:
		print("[selftest]   %s" % f)
	tree.quit(1)


static func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_fails.append(msg)


# ─────────────────────────────────────────────────────────────── the route

static func _the_route(main: Node) -> void:
	var route: Array = main.get_script().get_script_constant_map().get("ROUTE", [])
	var final_leg: int = int(main.get_script().get_script_constant_map().get("FINAL_LEG", -1))

	_ok(route.size() > 0, "ROUTE is empty")
	_ok(final_leg == route.size(),
		"FINAL_LEG (%d) != ROUTE.size() (%d). The run either ends a leg early or awards a leg that does not exist — the phantom leg 8 bug." % [final_leg, route.size()])

	for i in route.size():
		var e: Dictionary = route[i]
		var leg := i + 1
		var path := str(e.get("zone", ""))
		_ok(path != "", "ROUTE leg %d has no zone path" % leg)
		_ok(path.begins_with("res://"), "ROUTE leg %d zone path is not a res:// path: %s" % [leg, path])
		_ok(not path.contains("\\"),
			"ROUTE leg %d zone path contains a backslash — 'res://scripts\\x.gd' parses as res://scripts + newline: %s" % [leg, path])
		_ok(ResourceLoader.exists(path), "ROUTE leg %d zone script does not exist: %s" % [leg, path])
		_ok(str(e.get("name", "")) != "",
			"ROUTE leg %d has no name. The HUD banner, the results card and the credit roll all read it." % leg)
		_ok(float(e.get("seconds", 0.0)) > 0.0, "ROUTE leg %d has no clock" % leg)


# ─────────────────────────────────────────────────────────────── the clock

static func _the_clock(main: Node) -> void:
	var route: Array = main.get_script().get_script_constant_map().get("ROUTE", [])
	var mission := main.get_node_or_null("/root/Mission")
	var game := main.get_node_or_null("/root/Game")
	if mission == null or game == null:
		_ok(false, "Mission or Game autoload missing — the boot order in project.godot is wrong")
		return

	for i in route.size():
		var leg := i + 1
		var e: Dictionary = route[i]
		var declared: float = float(e.get("seconds", 0.0))

		# 1. main.gd's public accessor must return what the route says.
		var from_main: float = float(main.leg_seconds(leg))
		_ok(is_equal_approx(from_main, declared),
			"leg %d: Main.leg_seconds() says %.0f s, ROUTE says %.0f s" % [leg, from_main, declared])

		# 2. Mission must agree. It has a three-tier fallback and the lower two
		#    tiers are how the clock lie survived twice.
		var from_mission: float = float(mission.leg_seconds(leg))
		_ok(is_equal_approx(from_mission, declared),
			"leg %d: Mission.leg_seconds() says %.0f s, ROUTE says %.0f s — the two clocks have drifted apart again" % [leg, from_mission, declared])

		# 3. THE PROMISE MUST BE PAYABLE. The results card promises next leg's
		#    clock; the director pays it through clamp_zone_seconds(). A route
		#    entry outside the clamp is a promise the game cannot honour.
		var clamped: float = float(mission.clamp_zone_seconds(declared))
		_ok(is_equal_approx(clamped, declared),
			"leg %d: ROUTE promises %.0f s but Mission.clamp_zone_seconds() will only pay %.0f s" % [leg, declared, clamped])

	# 4. LEG 1 IS DEALT ITS ROUTE CLOCK. This is the one leg that never passes
	#    through _on_migration_done(), which is exactly why it ran 60 s short for
	#    the whole life of the project without anyone noticing.
	var before: float = float(game.zone_time_left)
	var was_running: bool = bool(game.zone_running)
	game.start_zone(main.leg_seconds(1))
	_ok(is_equal_approx(float(game.zone_time_left), main.leg_seconds(1)),
		"a fresh run does not start leg 1 on its route clock (%.0f s)" % main.leg_seconds(1))
	game.zone_time_left = before
	game.zone_running = was_running


# ──────────────────────────────────────────────── the truck stop's rig schedule

## THE INVARIANT A COMMENT WAS STANDING IN FOR, AND SHOULD NOT HAVE BEEN.
##
## `main.gd::ROUTE` shipped leg 7 at 180 s carrying a comment that forbade the
## 230 s `docs/BOSS_DESIGN.md` §2.2.2 asks for, because "the truck stop's
## departure schedule (`DEPART_AT`) is written against a 180 s clock, and a rig
## that leaves after the leg ends is a rig that never leaves."
##
## That was true when it was written. It STOPPED being true when
## `zone_truckstop.gd` grew `_clock_scale()`, which rescales `DEPART_AT`
## proportionally to whatever clock the leg is actually handed. Nobody noticed,
## because **a comment cannot run.** The constraint sat there as prose, blocking
## a change it no longer described.
##
## This is that constraint as an assertion instead. It reproduces
## `_clock_scale()`'s arithmetic and checks that the last rig still departs with
## a beat of empty lot after it — across EVERY clock this leg can legally be
## played on, not just the one in the route today. `Mission` can subtract 60 s
## for a bad leg 6, so the short end is real rather than hypothetical.
##
## What RIG_MARGIN defends is the zone's own thesis: the point of the place is
## that "the lot is measurably emptier at 2:00 than it was at 0:00", and the
## last departure leaving a few seconds of empty parking lot is called "the most
## honest thing in the game" fifty lines above `DEPART_AT`.
const TRUCKSTOP_PATH := "res://scripts/world/zone_truckstop.gd"

## THE CLOSING BEAT IS PROPORTIONAL, SO THE ASSERTION HAS TO BE.
##
## The first version of this check demanded an absolute 8 s of empty lot and
## failed at Mission's 110 s floor with 6.6 s. That was the check being wrong,
## not the game: `_clock_scale()` is proportional by construction, and the
## shipped schedule leaves exactly **6.0% of the leg** empty at EVERY clock in
## the legal range — 6.6 s at 110, 10.8 s at 180, 13.8 s at 230. Demanding a
## flat 8 s was demanding something the design never promised on a short clock.
##
## 5% is the floor: one percentage point of headroom under what ships, which is
## enough to catch the last `DEPART_AT` entry being dragged toward the end of
## the leg, or the [0.55, 1.35] clamp being hit and proportionality breaking,
## without failing on a rounding difference.
const RIG_TAIL_FRAC := 0.05


static func _the_rig_schedule(main: Node) -> void:
	var route: Array = main.get_script().get_script_constant_map().get("ROUTE", [])
	var mission := main.get_node_or_null("/root/Mission")
	if mission == null:
		return

	var zs: Resource = load(TRUCKSTOP_PATH)
	if zs == null:
		_ok(false, "the truck stop zone script did not load: %s" % TRUCKSTOP_PATH)
		return
	var consts: Dictionary = zs.get_script_constant_map()
	var depart: Array = consts.get("DEPART_AT", [])
	var base: float = float(consts.get("SCHEDULE_BASE", 0.0))
	var arm: float = float(consts.get("ARM_TIME", 0.0))

	_ok(depart.size() > 0, "zone_truckstop.gd has no DEPART_AT")
	_ok(base > 0.0, "zone_truckstop.gd has no SCHEDULE_BASE for DEPART_AT to be relative to")
	if depart.is_empty() or base <= 0.0:
		return

	# Ascending, or "the last one" is not the last one and every check below is
	# measuring the wrong rig.
	for i in range(1, depart.size()):
		var prev: float = depart[i - 1]
		var cur: float = depart[i]
		_ok(cur > prev,
			"zone_truckstop.gd DEPART_AT is not ascending at index %d (%.0f follows %.0f)" % [i, cur, prev])

	var last: float = depart[depart.size() - 1]

	for i in route.size():
		var leg := i + 1
		var e: Dictionary = route[i]
		if str(e.get("zone", "")) != TRUCKSTOP_PATH:
			continue

		# Both ends of the range this leg can actually be dealt: the floor Mission
		# will clamp a punished leg down to, and the route's own number.
		var declared: float = float(e.get("seconds", 0.0))
		var floor_secs: float = float(mission.clamp_zone_seconds(0.0))
		for secs: float in [floor_secs, declared]:
			# _clock_scale()'s arithmetic, reproduced. If that function changes,
			# this is the assertion that notices.
			#
			# ARM_TIME IS SCALED TOO. The zone sets `_rig_arm[i] = ARM_TIME *
			# scale`, so the whole departure costs (DEPART_AT + ARM_TIME) * scale.
			# Adding an unscaled ARM_TIME here made this check report 5.4 s of
			# tail where the game delivers 6.6, which is how a correct schedule
			# came to look broken.
			var scale: float = clampf(secs / base, 0.55, 1.35)
			var gone_at: float = (last + arm) * scale

			# 1. The constraint the ROUTE comment actually stated.
			_ok(gone_at < secs,
				("leg %d on a %.0f s clock: the last rig does not finish leaving until %.0f s and the "
				+ "leg ends at %.0f. A rig that leaves after the leg ends is a rig that never leaves.")
					% [leg, secs, gone_at, secs])

			# 2. And it has to leave a beat of empty lot behind it.
			var tail: float = (secs - gone_at) / maxf(secs, 1.0)
			_ok(tail >= RIG_TAIL_FRAC,
				("leg %d on a %.0f s clock: the last rig is gone at %.0f s, leaving %.1f s (%.1f%%) of "
				+ "empty lot, under the %.0f%% floor. The schedule ships 6.0%% at every clock, so this "
				+ "is a real change: the zone's whole argument is that the lot is measurably emptier "
				+ "at the end than at the start.")
					% [leg, secs, gone_at, secs - gone_at, tail * 100.0, RIG_TAIL_FRAC * 100.0])


# ─────────────────────────────────────────────────────────────── the titles

static func _the_titles(main: Node) -> void:
	var route: Array = main.get_script().get_script_constant_map().get("ROUTE", [])
	for i in route.size():
		var leg := i + 1
		var e: Dictionary = route[i]
		var want := "LEG %d — %s" % [leg, str(e.get("name", ""))]
		# The HUD banner and the results card must resolve to ONE string. They
		# used to be two independent expressions and disagreed on legs 1 and 5,
		# the two legs whose zone script is reused and therefore cannot know
		# which leg it is standing in.
		var got: String = str(main._title_for(null, leg))
		_ok(got == want, "leg %d title is \"%s\", route says \"%s\"" % [leg, got, want])


# ─────────────────────────────────────────────────────── the substance data

static func _the_substances(main: Node) -> void:
	var subs := main.get_node_or_null("/root/Subs")
	if subs == null:
		_ok(false, "Subs autoload missing")
		return

	var d := DirAccess.open(SUBSTANCE_DIR)
	_ok(d != null, "%s is unreadable" % SUBSTANCE_DIR)
	if d == null:
		return

	var ids := {}
	d.list_dir_begin()
	var fname := d.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			var path := SUBSTANCE_DIR + "/" + fname
			var res: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
			_ok(res != null, "%s did not load" % path)
			if res != null:
				_one_substance(res, path, ids)
		fname = d.get_next()
	d.list_dir_end()

	# EVERY SUBSTANCE NEEDS A HUD ICON, AND THE FILE HAS TO BE THERE.
	#
	# `Tex.icon_for()` answers a miss with one push_warning and a null, which is
	# invisible in a release build and nearly invisible in a debug one. The table
	# held twelve of sixteen for most of the project's life: acid, bars, gravy
	# and percs had no icon at all.
	var tex := main.get_node_or_null("/root/Tex")
	if tex != null:
		var icons: Dictionary = tex.get_script().get_script_constant_map().get("SUBSTANCE_ICONS", {})
		for sid in ids.keys():
			var key := StringName(sid)
			_ok(icons.has(key), "substance \"%s\" has no entry in Tex.SUBSTANCE_ICONS — it shows on the HUD as nothing at all" % sid)
			if icons.has(key):
				var f := "res://textures/%s.png" % str(icons[key])
				_ok(ResourceLoader.exists(f), "substance \"%s\" maps to %s, which is not on disk" % [sid, f])

	# Every file on disk must be a substance the manager actually loaded, or the
	# folder and the game disagree about what exists.
	var loaded: Array = subs.all() if subs.has_method("all") else []
	if loaded.is_empty():
		# `Subs` exposes its table under different names across versions; fall
		# back to the count rather than failing on the accessor's name.
		_ok(ids.size() > 0, "no substances found in %s" % SUBSTANCE_DIR)
	else:
		_ok(loaded.size() == ids.size(),
			"Subs loaded %d substances but %s holds %d files" % [loaded.size(), SUBSTANCE_DIR, ids.size()])


static func _one_substance(res: Resource, path: String, ids: Dictionary) -> void:
	var sid := str(res.get("id"))
	_ok(sid != "" and sid != "unnamed", "%s has no id" % path)
	_ok(not ids.has(sid), "duplicate substance id \"%s\" (%s) — Subs is keyed by id, so one of them is unreachable" % [sid, path])
	ids[sid] = true

	_ok(str(res.get("display_name")) != "", "%s has no display_name" % sid)
	_ok(str(res.get("mimics")) != "",
		"%s does not say what it mimics. substance.gd: \"if you can't name what it mimics, you don't know what you're designing.\"" % sid)
	_ok(str(res.get("codex_fact")).strip_edges() != "",
		"%s has no codex_fact. The Almanac's whole claim is that every fact in it is true and sourced; an empty one is a blank page in the codex." % sid)

	var smin: float = float(res.get("sweet_min"))
	var smax: float = float(res.get("sweet_max"))
	_ok(smin < smax, "%s has sweet_min %.2f >= sweet_max %.2f — the sweet spot is empty and cannot be hit" % [sid, smin, smax])
	_ok(smin >= 0.0 and smax <= 1.0, "%s sweet spot is outside the 0..1 dose range" % sid)
	_ok(float(res.get("duration")) > 0.0, "%s lasts no time at all" % sid)
	_ok(float(res.get("charge_time")) > 0.0, "%s cannot be charged" % sid)

	# THE INPUT-LAG CEILING. goose_controller.gd trims its input buffer by AGE
	# against MAX_LAG. A substance asking for more delay than the buffer keeps
	# would silently get MAX_LAG instead — a dial that stops responding partway
	# up, which is exactly the class of bug the buffer already shipped once.
	var lag: float = float(res.get("input_lag"))
	var ctrl := load("res://scripts/goose/goose_controller.gd")
	var max_lag: float = float(ctrl.get_script_constant_map().get("MAX_LAG", 1.25)) if ctrl != null else 1.25
	_ok(lag <= max_lag,
		"%s asks for %.2f s of input lag but goose_controller.MAX_LAG is %.2f — raise MAX_LAG or the dial silently stops here" % [sid, lag, max_lag])

	# THE DESIGN RULE, AS A BUILD CHECK. From the top of scripts/core/substance.gd:
	# "a substance must never be only a number that goes up. Every entry must
	# include at least one CONTROL MUTATION. If you find yourself adding a
	# substance that only edits speed_mult, delete it."
	var mutates := false
	for k in CONTROL_KEYS:
		var v: Variant = res.get(k)
		if typeof(v) == TYPE_BOOL:
			if bool(v):
				mutates = true
				break
		elif typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
			# The multipliers idle at 1.0; everything else idles at 0.0.
			var base := 1.0 if k.ends_with("_mult") or k == "time_scale" else 0.0
			if not is_equal_approx(float(v), base):
				mutates = true
				break
	_ok(mutates,
		"%s is only a number that goes up — it has no control mutation. substance.gd's design rule says delete it." % sid)


# ────────────────────────────────────────────────────────── the objectives

static func _the_objectives(main: Node) -> void:
	var route: Array = main.get_script().get_script_constant_map().get("ROUTE", [])
	var defs := load("res://scripts/core/mission_defs.gd")
	if defs == null:
		_ok(false, "mission_defs.gd did not load")
		return

	# What the fallback looks like. An unregistered zone id does not error — it
	# returns this, and the leg is playable, and wrong, and silent about it.
	var generic: Array = defs.for_zone(&"__no_such_zone__", 1)

	for i in route.size():
		var leg := i + 1
		var path := str(route[i].get("zone", ""))
		var zs := load(path)
		if zs == null:
			continue
		var z: Node = zs.new()
		var zid: StringName = z.mission_zone_id() if z.has_method("mission_zone_id") else &"generic"
		_route_zone_ids.append(zid)
		var list: Array = defs.for_zone(zid, leg)
		_ok(list.size() > 0, "leg %d (%s) has no objectives at all" % [leg, zid])
		_ok(_signature(list) != _signature(generic),
			"leg %d declares mission_zone_id \"%s\", which mission_defs.for_zone() does not know — it fell through to the generic set. The leg is playable and wrong." % [leg, zid])
		z.free()


## Every zone gets its own air, and every bed it names is on disk.
##
## `Sfx.AMBIENCE_BEDS` answers an unknown zone id with the parking lot rather
## than with silence — deliberately, because a missing bed is a zone with no air
## in it — which also means a new zone that nobody added to the table ships
## sounding like a strip mall and says nothing about it. That was the state of
## all seven legs until today.
static func _the_ambience(main: Node) -> void:
	var sfx := main.get_node_or_null("/root/Sfx")
	if sfx == null:
		return
	# Annotated, not inferred: `sfx.get_script()` is typed Variant off an untyped
	# node reference, so the whole chain is a Variant. The project's #1 parse
	# error, and it caught this file twice while it was being written.
	var cmap: Dictionary = sfx.get_script().get_script_constant_map()
	var beds: Dictionary = cmap.get("AMBIENCE_BEDS", {})
	if beds.is_empty():
		_ok(false, "Sfx.AMBIENCE_BEDS is empty — every zone is silent or on the fallback")
		return

	for k in beds.keys():
		var wav := "res://audio/%s.wav" % str(beds[k])
		_ok(ResourceLoader.exists(wav), "ambience bed for zone \"%s\" is %s, which is not on disk" % [k, wav])

	# And every zone the player actually visits must have its OWN entry, not the
	# fallback by accident.
	#
	# Uses the ids `_the_objectives()` already collected rather than
	# instantiating all seven zone scripts a second time. Building a zone twice
	# per run of this harness is a real cost — these are 600-to-1900 line
	# builders — and it made the whole selftest hang the first time it was tried.
	for i in _route_zone_ids.size():
		var zid: StringName = _route_zone_ids[i]
		_ok(beds.has(zid),
			"leg %d (zone id \"%s\") has no ambience bed of its own — it falls back to the parking lot" % [i + 1, zid])


## Mission's per-zone override tables must name zones that exist.
##
## `REQUIRED_OVERRIDE` and `PAR_SCALE` are keyed by zone id and are read with
## `.has()`, so a typo is not an error — it is a table entry that never matches
## and a feature that silently does not exist. Both of these were SPECIFIED in
## docs/ROUTE_DATA.md §7.2 and docs/CAMPAIGN_SPEC.md §2.5 long before they were
## implemented, and the leg they were written for was being graded against a par
## meant for a chaos level the whole time.
static func _the_overrides(main: Node) -> void:
	var mission := main.get_node_or_null("/root/Mission")
	if mission == null:
		return
	var cmap: Dictionary = mission.get_script().get_script_constant_map()
	var known := {}
	for z in _route_zone_ids:
		known[z] = true
	for table_name in ["REQUIRED_OVERRIDE", "PAR_SCALE"]:
		var t: Dictionary = cmap.get(table_name, {})
		for k in t.keys():
			_ok(known.has(k),
				"Mission.%s names zone id \"%s\", which no leg on the route uses — the override silently does nothing" % [table_name, k])


## Every bespoke score label an objective waits on must have something that
## emits it.
##
## THIS BUG HAS NOW SHIPPED TWICE. CLAUDE.md records the first: Suburbia's
## bespoke moments and the objectives waiting on them drifted apart and two
## objectives died silently. The defs files answered it by hoisting the labels
## into `const LBL_*` so that "a rename is a parse error in both files instead
## of a silently dead objective" — which is a real improvement and does not
## cover the case that actually recurred, because a label that was NEVER wired
## has no rename to catch. `mission_defs_stopover.gd::LBL_DRIVER` was a REQUIRED
## primary on leg 5 whose condition nothing in the project could ever satisfy:
## the flock pen named a driver, sobered the bird, vested it, played two sounds
## and threw text in the air, and never scored.
##
## The rule this enforces: a label constant declared in a defs file must be
## REFERENCED from outside that file. The only thing that can reference it is a
## zone or an encounter, and the only reason to do so is to pass it to
## `Game.score()`. Cheap, and it is the exact shape of both failures.
static func _the_labels_are_emitted() -> void:
	var defs: Array[String] = []
	var all: Array[String] = []
	_walk_gd("res://", all)
	for p in all:
		if p.contains("mission_defs"):
			defs.append(p)

	var re := RegEx.new()
	re.compile("(?m)^const\\s+(LBL_[A-Z0-9_]+)\\s*:=")

	for dp in defs:
		var f := FileAccess.open(dp, FileAccess.READ)
		if f == null:
			continue
		var src := f.get_as_text()
		f.close()
		for m in re.search_all(src):
			var name := m.get_string(1)
			var referenced := false
			for other in all:
				if other == dp:
					continue
				var g := FileAccess.open(other, FileAccess.READ)
				if g == null:
					continue
				var osrc := g.get_as_text()
				g.close()
				if _mentions_in_code(osrc, name):
					referenced = true
					break
			_ok(referenced,
				"%s declares %s and no other file mentions it — the objective waiting on that label can never complete" % [dp.get_file(), name])


## Does `name` appear in this source OUTSIDE a comment?
##
## COMMENTS DO NOT COUNT, and the first version of the check above did not know
## that — it used a plain `contains()`, and the very comment explaining why the
## label needed an emitter was enough to satisfy it. The canary that was supposed
## to prove the assertion works passed instead, which is precisely the "a check
## nobody has watched fail" failure this whole file exists to answer.
##
## Naive on purpose: everything from the first `#` on a line is dropped. A `#`
## inside a string literal would truncate that line early, which can only ever
## cause a FALSE ALARM (a real reference missed), never a false pass.
static func _mentions_in_code(src: String, name: String) -> bool:
	for line in src.split("\n"):
		var l: String = line
		var hash_at := l.find("#")
		if hash_at >= 0:
			l = l.substr(0, hash_at)
		if l.contains(name):
			return true
	return false


## Every mission_defs_*.gd must be reachable from mission_defs.gd.
##
## An objective file that nothing preloads is an orphan: it compiles, the gate
## passes, and its whole zone silently plays the `_generic()` set instead. That
## is not hypothetical — `mission_defs_stopover.gd` and `mission_defs_bigdown.gd`
## both sat orphaned the moment they were written, because the agents that wrote
## them owned their own file and not the dispatcher.
static func _the_defs_are_wired() -> void:
	var hub := FileAccess.open("res://scripts/core/mission_defs.gd", FileAccess.READ)
	if hub == null:
		_ok(false, "mission_defs.gd is unreadable")
		return
	var src := hub.get_as_text()
	hub.close()

	var d := DirAccess.open("res://scripts/core")
	if d == null:
		return
	d.list_dir_begin()
	var nm := d.get_next()
	while nm != "":
		if nm.begins_with("mission_defs_") and nm.ends_with(".gd"):
			_ok(src.contains(nm),
				"scripts/core/%s is not preloaded by mission_defs.gd — its zone silently plays the generic objective set" % nm)
		nm = d.get_next()
	d.list_dir_end()


## A cheap identity for an objective list, so "did this fall through to generic"
## can be answered without caring about the schema.
static func _signature(list: Array) -> String:
	var parts: Array[String] = []
	for o in list:
		if o is Dictionary:
			parts.append(str((o as Dictionary).get("id", "?")))
	parts.sort()
	return ",".join(parts)


# ───────────────────────────────────────────────────── the asset references

## Every sound and texture the CODE asks for must exist on DISK.
##
## Both loaders answer a miss the same way: `Sfx._get_stream()` and
## `Tex.get_tex()` push_warning once and return null. A null AudioStream plays
## silence and a null albedo renders untextured white — so a renamed .wav or a
## typo'd texture key is a bug you can only find by noticing that something is
## quiet, which nobody ever does. All 35 textures and 40 sounds in this project
## are generated by tools/gen_*.py, which means a key can drift away from its
## generator without anything failing.
##
## This scans the source rather than the running game because most of these call
## sites only fire in one zone, on one substance, at one moment.
static func _the_assets() -> void:
	var sounds := {}
	var textures := {}

	# First argument only. `Sfx.loop(key, bus, db)` and `Sfx.stop_loop(bus)` are
	# the trap here: the second argument and stop_loop's only argument are BUS
	# names, which are not files and must not be checked.
	var re_snd := RegEx.new()
	re_snd.compile("\\b(?:play|play_at|loop)\\(\\s*&\"([a-z0-9_]+)\"")
	# play_var takes a list of interchangeable variants, as StringName literals
	# inside a bracket list. (Not written out here as an example: this file gets
	# scanned by its own regexes, and an example would be reported as a missing
	# sound — which is a real thing that happened while writing it.)
	var re_var := RegEx.new()
	re_var.compile("play_var\\(\\s*\\[([^\\]]*)\\]")
	var re_lit := RegEx.new()
	re_lit.compile("&\"([a-z0-9_]+)\"")
	var re_tex := RegEx.new()
	re_tex.compile("\\b(?:get_tex|surface|surface_transparent)\\(\\s*&\"([a-z0-9_]+)\"")

	var files: Array[String] = []
	_walk_gd("res://", files)
	for path in files:
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		var src := f.get_as_text()
		f.close()
		for m in re_snd.search_all(src):
			sounds[m.get_string(1)] = path
		for m in re_var.search_all(src):
			for inner in re_lit.search_all(m.get_string(1)):
				sounds[inner.get_string(1)] = path
		for m in re_tex.search_all(src):
			textures[m.get_string(1)] = path

	for k in sounds.keys():
		_ok(ResourceLoader.exists("res://audio/%s.wav" % k),
			"audio key \"%s\" (%s) has no file — Sfx warns once and then plays silence forever" % [k, sounds[k]])
	for k in textures.keys():
		_ok(ResourceLoader.exists("res://textures/%s.png" % k),
			"texture key \"%s\" (%s) has no file — Tex warns once and then renders untextured white" % [k, textures[k]])


static func _walk_gd(dir_path: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var nm := d.get_next()
	while nm != "":
		if nm.begins_with("."):
			nm = d.get_next()
			continue
		var full := dir_path.path_join(nm) if dir_path != "res://" else "res://" + nm
		if d.current_is_dir():
			if nm != "_to_delete" and nm != "addons":
				_walk_gd(full, out)
		elif nm.ends_with(".gd"):
			out.append(full)
		nm = d.get_next()
	d.list_dir_end()


# ─────────────────────────────────────────────────────────── the time scale

static func _the_time_scale() -> void:
	# Engine.time_scale has exactly two owners, and a stranded write once left a
	# run in permanent 0.106x slow motion with no way out. After both owners
	# have been reset, the clock must be 1.0 — if a third writer ever appears,
	# this is where it shows up.
	var juice := Engine.get_main_loop().root.get_node_or_null("Juice") as Node
	var subs := Engine.get_main_loop().root.get_node_or_null("Subs") as Node
	if juice != null and juice.has_method("reset"):
		juice.reset()
	if subs != null and subs.has_method("reset_for_new_leg"):
		subs.reset_for_new_leg()
	_ok(is_equal_approx(Engine.time_scale, 1.0),
		"Engine.time_scale is %.3f after Subs and Juice have both reset — a third writer has appeared" % Engine.time_scale)
