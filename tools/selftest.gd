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

## Preloaded rather than referenced as `Substance`: CLAUDE.md prefers it, because
## global class registration only exists after an editor import pass and a bare
## `class_name` reference breaks in a fresh checkout and in headless CI.
const SUBSTANCE_SCRIPT := preload("res://scripts/core/substance.gd")

## The keys in `Substance.resolve()` that are CONTROL MUTATIONS — things that
## change how the player's hands work — as opposed to numbers that go up.
## `speed_mult` and `chaos_mult` are deliberately NOT in this list: they are the
## two the design rule at the top of scripts/core/substance.gd exists to forbid.
const CONTROL_KEYS := [
	"input_lag", "drift", "flap_mult", "gravity_mult", "turn_mult",
	"ragdoll_landings", "cannot_idle", "time_scale", "smash_through",
	"camera_detach", "grid_snap", "hud_amnesia", "hallucinate",
	"no_fall_damage", "scale_amp", "aggro_cats", "blocks_dosing",
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
	_the_shelf(main)
	_the_layers()
	_the_hitstops()
	_the_primitives_are_closed()
	_the_control_keys()
	_the_substance_fields()
	_the_overdose()
	_the_objectives(main)
	# AFTER _the_objectives(), which is what fills _route_zone_ids.
	_the_objectives_are_reachable(main)
	_the_overrides(main)
	_the_defs_are_wired()
	_the_labels_are_emitted()
	_the_ambience(main)
	_the_rig_schedule(main)
	_the_files()
	_the_dose_window(main)
	_the_docs()
	_the_assets()
	# Awaited: it lets the tree run for 20 frames, which is the only way a third
	# `Engine.time_scale` writer can be seen at all. `run()` is a coroutine
	# because of this one check, and `main.gd` awaits it.
	# LAST OF THE SYNCHRONOUS CHECKS. It calls `Mission.begin_leg()` seven
	# times, which resets the autoload's objective state — harmless because
	# the process quits straight after, and wrong if anything that reads
	# Mission runs after it.
	_the_result_clocks(main)
	await _the_time_scale(tree)

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
	#
	#    AND IT HAS TO ASSERT THE VALUE IT CAPTURED. This check used to read the
	#    boot clock into `before`, then call `start_zone(main.leg_seconds(1))` —
	#    writing the correct answer — and assert on THAT. It was testing
	#    `start_zone`'s one-line assignment, not the boot path, so `main.gd`
	#    reverting to a bare `Game.new_run()` (which defaults to 180 s) would run
	#    leg 1 sixty seconds short against a ROUTE that says 240 and `--selftest`
	#    would still print PASS. That is the exact bug this check is named for.
	#
	#    `before` is exact here: `run()` is synchronous and dispatched one
	#    statement after `new_run()`, so no frame has ticked the clock down.
	var before: float = float(game.zone_time_left)
	var was_running: bool = bool(game.zone_running)
	_ok(is_equal_approx(before, main.leg_seconds(1)),
		("a fresh run starts leg 1 on %.0f s, but the route says %.0f. Leg 1 is the one leg "
		+ "that never passes through _on_migration_done(), which is why it ran 60 s short for "
		+ "the whole life of the project.") % [before, main.leg_seconds(1)])
	# The setter is worth pinning too, but as its own assertion rather than as a
	# replacement for the one above.
	game.start_zone(main.leg_seconds(1))
	_ok(is_equal_approx(float(game.zone_time_left), main.leg_seconds(1)),
		"Game.start_zone() does not put its argument on the clock")
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


# ────────────────────────────────────────────── the files themselves

## TWO SILENT FAILURES THAT LIVE IN TEXT RATHER THAN IN CODE.
##
## `CLAUDE.md` warns about both by name and nothing checked either. Both are
## silent in the worst way — the project loads, every gate passes, and the wrong
## thing is bound:
##
##   1. **Duplicate `ExtResource`/`SubResource` ids inside one file.** The rule
##      is stated outright: "duplicates are silent and bind the wrong resource.
##      Assert uniqueness before writing a file." This is that assertion.
##   2. **Duplicate `class_name`.** One flat global namespace shared with every
##      engine class and every autoload — "grep before adding one; duplicates
##      are silent, last-wins."
##
## Both were swept by hand first and the tree was clean. That is exactly when to
## write the check: a clean sweep is worth nothing next month unless something
## keeps it clean.
##
## DirAccess rather than ResourceLoader.list_directory is deliberate and matches
## `tools/gate.gd` — dev tooling that never ships in an export, which is the
## exception CLAUDE.md carves out.
const FILE_SKIP_DIRS := [".godot", ".git", "_to_delete", "addons"]


static func _the_files() -> void:
	var scripts: Array[String] = []
	var resources: Array[String] = []
	_walk_files("res://", scripts, resources)

	_ok(scripts.size() > 0, "the file sweep found no scripts at all — the walk is broken")
	_ok(resources.size() > 0, "the file sweep found no scenes or resources at all")

	# ── AN INVALID ESCAPE HANGS THE PARSER, WITH NO OUTPUT AT ALL ───────
	#
	# `CLAUDE.md` documents the silent `--gate` stall — no "compiling N
	# scripts...", no error, no exit — and attributes it to a local name reused
	# inside one function. THAT IS NOT THE ONLY CAUSE. On 2026-08-18 the gate
	# went silent again with no repeated name anywhere in the file. The edit
	# had built a RegEx pattern containing \* , and \* is not a GDScript escape
	# sequence at all. Rewriting the identical pattern with a character class
	# instead compiled in 25 s. One change, two runs, same file.
	#
	# It is an easy mistake and an expensive diagnosis, because the symptom is
	# indistinguishable from a hung machine — which is exactly why this is a
	# check and not a paragraph. Every .gd is scanned for a backslash inside a
	# string literal that is not one of the escapes GDScript defines.
	# A DEBOUNCED WRITE NEEDS A FLUSH, and `prefs.gd` went the life of the
	# project without one. Writes go through a one-shot SAVE_DEBOUNCE timer
	# so a dragged slider does not rewrite the file every frame — correct,
	# and it means **any setting changed within SAVE_DEBOUNCE of quitting
	# never reached disk.** Turn the music down, close the game, come back
	# loud. `music.gd` has had an `_exit_tree()` since it was written and
	# `prefs.gd` never did, which is the same two-files-one-rule shape as
	# the water guard in the substance harness.
	#
	# A FLOOR, and named as one: this proves the flush is WIRED, not that it
	# writes the right bytes. Proving that needs a real process exit and a
	# re-read, which no gate here can do.
	var prefs_src := _read_text("res://scripts/core/prefs.gd")
	_ok(prefs_src.contains("func _exit_tree"),
		"scripts/core/prefs.gd debounces its writes through a timer and defines no _exit_tree(), so any setting changed in the last SAVE_DEBOUNCE seconds before quitting is lost.")
	_ok(prefs_src.split("func _exit_tree")[-1].contains("save_prefs"),
		"scripts/core/prefs.gd has an _exit_tree() that never calls save_prefs(). The flush is present and does nothing.")
	for spath in scripts:
		var sf := FileAccess.open(spath, FileAccess.READ)
		if sf == null:
			continue
		var body := sf.get_as_text()
		sf.close()
		var bad := _bad_escape(body)
		_ok(bad == "",
			("%s uses the escape sequence backslash-%s inside a string literal, and GDScript "
			+ "does not define it. An unknown escape can make the parser STALL SILENTLY — no "
			+ "output, no error, no exit — which is indistinguishable from a hung machine. "
			+ "Write it as a character class instead, or double the backslash.") % [spath, bad])


	for path in resources:
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			_ok(false, "could not open %s to check its resource ids" % path)
			continue
		var text := f.get_as_text()
		f.close()

		var seen := {}
		for line in text.split("\n"):
			if not (line.begins_with("[ext_resource") or line.begins_with("[sub_resource")):
				continue
			var rid := _quoted_after(line, "id=")
			if rid == "":
				continue
			_ok(not seen.has(rid),
				("%s declares the resource id '%s' twice. Duplicates are silent and bind the "
				+ "WRONG resource — the file loads and the game is quietly incorrect.")
					% [path, rid])
			seen[rid] = true

	var declared := {}
	for path in scripts:
		var f2 := FileAccess.open(path, FileAccess.READ)
		if f2 == null:
			continue
		var text2 := f2.get_as_text()
		f2.close()
		for line in text2.split("\n"):
			var t := line.strip_edges()
			if not t.begins_with("class_name "):
				continue
			var cn := t.substr(11).strip_edges()
			var sp := cn.find(" ")
			if sp > 0:
				cn = cn.substr(0, sp)
			_ok(not declared.has(cn),
				("class_name %s is declared in BOTH %s and %s. It is one flat global namespace "
				+ "shared with every engine class and every autoload, and a duplicate is silent: "
				+ "last one wins.") % [cn, declared.get(cn, "?"), path])
			declared[cn] = path
			break


## The contents of the first quoted string following `key` on this line, or ""
## if there isn't one. Deliberately a small helper rather than a regex: this
## runs over every scene in the project on every build.
static func _quoted_after(line: String, key: String) -> String:
	var at := line.find(key)
	if at < 0:
		return ""
	var rest := line.substr(at + key.length())
	var open_q := rest.find(QUOTE)
	if open_q < 0:
		return ""
	rest = rest.substr(open_q + 1)
	var close_q := rest.find(QUOTE)
	if close_q < 0:
		return ""
	return rest.substr(0, close_q)


## A double-quote as a named constant, so no string literal in this file has to
## contain an escaped one.
const QUOTE := '"'

## Companions to QUOTE, and they exist for the reason QUOTE does: this file
## scans every script for stray backslashes and quotes, so it must not spell
## any of them inline in a literal and match itself.
const TICK := "'"
const BACKSLASH := "\\"
const NEWLINE := "\n"


## THE OVERDOSE BRANCH, WHICH NO GATE HAD EVER LOOKED AT.
##
## `tools/substancetest.gd` doses everything at `DOSE = 0.6` and `resolve()`'s
## whole `overdosed` path — `quality = 1.0 + (dose - sweet_max) * 1.5` and then
## `bad = quality * 1.6` — was reached by no check in the project. Holding the
## eat key saturates `_eat_charge` at exactly 1.0, so a maximum dose is not an
## edge case: it is what happens when the player does not let go.
##
## Two shipped bugs lived in there, both sign flips out of an unbounded `bad`:
##
##   * **special_k resolved to NEGATIVE gravity** above dose 0.939 — at 1.0,
##     `gravity_mult` is -0.066, and both `_tick_ground` and `_tick_fly` read it
##     raw. The bird accelerates upward, no input brings it down, and it leaves
##     the level for the rest of the dose.
##   * **math and special_k resolved `turn_mult` to zero or below** at any
##     overdose (robo above 0.867, toad_slime above 0.787, percs above 0.955).
##     `_face()` clamps its step to `[0, 1]`, so a negative rate is an exact
##     no-op: the heading freezes while the bird keeps sliding.
##
## So this resolves every substance at the worst dose the game can hand it and
## asserts the four multipliers stay in a range the controller can survive.
## Fixed at `substance.gd`'s two `maxf()` floors; this is the check that would
## have seen it, and it fails if either floor is removed.
static func _the_overdose() -> void:
	var d := DirAccess.open(SUBSTANCE_DIR)
	if d == null:
		return
	d.list_dir_begin()
	var fname := d.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			var res: Resource = ResourceLoader.load(SUBSTANCE_DIR + "/" + fname, "",
				ResourceLoader.CACHE_MODE_IGNORE)
			if res != null:
				# Dose 1.0 with a clean tolerance is the strongest `bad` the game
				# can produce, because tolerance only ever shrinks `good`.
				var r: Dictionary = res.call("resolve", 1.0, 0)
				var sid := str(res.get("id"))
				_ok(float(r.gravity_mult) > 0.0,
					("%s resolves gravity_mult to %.3f at a full dose. Negative gravity makes the "
					+ "bird fall UPWARD out of the level with no input that brings it back.")
						% [sid, float(r.gravity_mult)])
				_ok(float(r.turn_mult) > 0.0,
					("%s resolves turn_mult to %.3f at a full dose. _face() clamps its step to "
					+ "[0, 1], so anything <= 0 freezes the heading for the whole duration while "
					+ "the Almanac still advertises a multiplier.") % [sid, float(r.turn_mult)])
				_ok(float(r.speed_mult) >= 0.0,
					"%s resolves speed_mult to %.3f at a full dose — a negative speed walks the bird backwards"
						% [sid, float(r.speed_mult)])
				_ok(float(r.flap_mult) >= 0.0,
					"%s resolves flap_mult to %.3f at a full dose" % [sid, float(r.flap_mult)])
		fname = d.get_next()
	d.list_dir_end()


## EVERY DIAL ON `Substance` HAS TO BE CONNECTED TO SOMETHING.
##
## `stamina_restore` was exported on `Substance`, set to a non-zero value by SIX
## of the sixteen substances — bars 0.20, darts 0.20, double_double 0.40, grass
## 0.25, math 0.50, molly 0.30 — and read by **nothing at all**. It is not a key
## in `resolve()`'s returned Dictionary, so it never reaches `Subs.mods` and
## never reaches the goose, and no file under `scripts/` so much as names it.
## Six substances have been promising the player a stamina refund the game has
## never once given, in a project whose gates already dose all sixteen and
## measure the bird.
##
## `goose_controller.gd` carries the precedent, in the long comment standing
## where `float_height` used to: *"a dial that cannot be connected to anything is
## worse than no dial, so it is gone rather than left as furniture."* That one
## was found by a human reading the file. This one is found by running.
##
## THE RULE, AND IT NEEDS NO ALLOWLIST — which is the point, because an
## allowlist is where a real failure gets reclassified as an expected one. An
## export on `Substance` is connected if EITHER:
##
##   * it is a key in `resolve()`'s returned Dictionary — the path through
##     `_aggregate()` into `Subs.mods` and out to the goose; or
##   * some file under `scripts/` names it — the path for a field read straight
##     off the resource, which is how `charge_time`, `sweet_min`,
##     `tolerance_gain` and `codex_fact` legitimately work.
##
## Neither means furniture. The check is deliberately a FLOOR: naming a field
## anywhere counts, so it cannot produce a false failure, only a false pass. It
## catches the field that is mentioned NOWHERE, which is the bug that happened.
static func _the_substance_fields() -> void:
	var scripts: Array[String] = []
	var resources: Array[String] = []
	_walk_files("res://scripts", scripts, resources)
	_ok(scripts.size() > 0, "the substance-field sweep found no scripts under res://scripts")

	var bodies: Array[String] = []
	for path in scripts:
		# The declaration is not a reader. Excluding the file the exports live in
		# is the whole reason this check can see anything at all.
		if path.ends_with("/substance.gd"):
			continue
		var fh := FileAccess.open(path, FileAccess.READ)
		if fh == null:
			continue
		bodies.append(fh.get_as_text())
		fh.close()

	var proto: Resource = SUBSTANCE_SCRIPT.new()
	var resolved: Dictionary = proto.call("resolve", 0.6, 0)
	_ok(resolved.size() > 0, "Substance.resolve() returned nothing — this check is blind")

	for p in proto.get_property_list():
		if int(p.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		var field := String(p.name)
		if resolved.has(field):
			continue
		var seen := false
		for body in bodies:
			if body.contains(field):
				seen = true
				break
		_ok(seen,
			("Substance.%s is exported, is NOT a key in resolve()'s dictionary, and is named by no "
			+ "file under scripts/. It is a dial connected to nothing: every .tres that sets it is "
			+ "promising the player something the game cannot deliver. Wire it, or delete it the "
			+ "way float_height was deleted from goose_controller.gd.") % field)


static func _walk_files(dir_path: String, scripts: Array[String], resources: Array[String]) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var fname := d.get_next()
	while fname != "":
		if not fname.begins_with("."):
			var full := dir_path.path_join(fname) if dir_path != "res://" else "res://" + fname
			if d.current_is_dir():
				if not FILE_SKIP_DIRS.has(fname):
					_walk_files(full, scripts, resources)
			elif fname.ends_with(".gd"):
				scripts.append(full)
			elif fname.ends_with(".tres") or fname.ends_with(".tscn"):
				resources.append(full)
		fname = d.get_next()
	d.list_dir_end()


# ──────────────────────────────────────────── the dose window

## THE ONLY TIMING SKILL GATE IN THE GAME, AND IT WAS NEVER MEASURED.
##
## `docs/DESIGN_MISSIONS.md` calls the sweet spot "the only real skill gate in
## the game; every substance runs through it", and `goose_controller.gd` agrees
## in `_tick_eat()`: *"Skill expression is STOPPING, not holding."*
##
## The skill is therefore a stopwatch problem. `_eat_charge` rises at
## `delta / charge_time`, so the band `[sweet_min, sweet_max]` is open for
##
##     (sweet_max - sweet_min) * charge_time   SECONDS
##
## and THAT is the number a player's thumb has to hit. Nothing in this project
## had ever computed it. It is a property of two fields in sixteen separate
## `.tres` files, which is exactly the shape of thing that drifts — and exactly
## the shape of thing the clock lie was, three times.
##
## Measured across the shelf on 2026-08-18: **0.252 s (percs) to 0.700 s
## (grass)**, a spread of 2.78x. Nothing is broken. The bounds below exist so it
## stays that way.
##
## AN EMERGENT DESIGN PROPERTY WORTH KNOWING ABOUT: sorted by window, the order
## is percs, math, nitrous, darts at the tight end and grass, fly agaric, catnip
## at the wide end. **The substances that punish you hardest are the hardest to
## dose correctly.** Nobody wrote that down; it fell out of sixteen independent
## choices, it is good, and it is now defended by the fact that this file will
## complain if a new substance breaks the pattern's floor or ceiling.
const DOSE_WINDOW_MIN := 0.15
const DOSE_WINDOW_MAX := 0.85


static func _the_dose_window(main: Node) -> void:
	var subs := main.get_node_or_null("/root/Subs")
	if subs == null:
		_ok(false, "no Subs autoload — the dose windows cannot be checked")
		return
	var library: Dictionary = subs.library
	_ok(library.size() > 0, "the substance library is empty")

	for id in library:
		var res: Substance = library[id]
		if res == null:
			continue
		var ct: float = res.charge_time
		var lo: float = res.sweet_min
		var hi: float = res.sweet_max

		_ok(ct > 0.05,
			"%s has a charge_time of %.2f s. _tick_eat() divides by it (clamped at 0.05), so anything at or below that makes the dose instant and deletes the skill gate." % [id, ct])
		_ok(lo < hi,
			"%s has sweet_min %.2f >= sweet_max %.2f, so its sweet spot is empty and every dose is either BARELY ANYTHING or an OVERDOSE." % [id, lo, hi])
		_ok(lo > 0.0 and hi <= 1.0,
			"%s's sweet band [%.2f, %.2f] is outside the 0..1 the charge can reach; _eat_charge is clamped to 1.0." % [id, lo, hi])

		# The band's width IN SECONDS, which is what the thumb has to hit.
		var window: float = (hi - lo) * ct
		_ok(window >= DOSE_WINDOW_MIN,
			("%s's sweet spot is open for %.3f s (%.0f frames at 60 Hz). Under %.2f s this stops "
			+ "being a skill and becomes a coin flip, and DESIGN_MISSIONS calls this the only real "
			+ "skill gate in the game.") % [id, window, window * 60.0, DOSE_WINDOW_MIN])
		_ok(window <= DOSE_WINDOW_MAX,
			("%s's sweet spot is open for %.3f s. Over %.2f s there is no timing test left — you "
			+ "cannot miss it, and every dose scores SWEET SPOT.") % [id, window, DOSE_WINDOW_MAX])

		# And the whole band has to be reachable before the charge saturates.
		_ok(hi * ct <= ct + 0.001,
			"%s's band closes at %.2f s but a full charge takes %.2f s" % [id, hi * ct, ct])


# ──────────────────────────────── the docs, checked against the code

## A COMMENT CANNOT RUN — SO CHECK THE ONES THAT MATTER.
##
## This project's most expensive recurring failure is not a crash. It is a
## constraint recorded as prose that keeps applying after it stops being true.
## Three counted so far: `main.gd::ROUTE` forbade a 230 s leg 7 for a reason
## `_clock_scale()` had already removed; `boss_ranger.gd` said leg 6's exam was
## unbuilt because "leg 6 does not exist yet" after the corn field shipped; and
## `CLAUDE.md`'s own banner told every session the game had never been measured,
## for a whole session after it had been.
##
## Most prose cannot be checked. **These two can**, and they are the two that go
## stale first, because they are counts that change whenever someone does the
## right thing:
##
##   1. Every gate flag `main.gd` dispatches must be documented in `CLAUDE.md`.
##      Adding a gate and not documenting it is the single easiest way to make
##      the verification story wrong, and it is invisible until someone needs it.
##   2. `docs/HANDOFF.md`'s claimed GDScript file count must match reality. It is
##      the first number a fresh session reads about the size of the project, it
##      was wrong twice in one session, and it is free to check.
##
## Deliberately NOT asserted: the invariant count. It is self-referential — every
## assertion added here changes the number the doc has to claim — and a check
## that fights its own author gets deleted rather than obeyed.
const DOC_CLAUDE := "res://CLAUDE.md"
const DOC_HANDOFF := "res://docs/HANDOFF.md"
const SRC_MAIN := "res://scripts/core/main.gd"


static func _the_docs() -> void:
	var claude := _read_text(DOC_CLAUDE)
	var handoff := _read_text(DOC_HANDOFF)
	var main_src := _read_text(SRC_MAIN)
	_ok(claude != "", "could not read CLAUDE.md to check it against the code")
	_ok(handoff != "", "could not read docs/HANDOFF.md to check it against the code")
	_ok(main_src != "", "could not read main.gd to check the docs against it")
	if claude == "" or handoff == "" or main_src == "":
		return

	# 1. Every gate flag the engine dispatches has to be written down.
	var flags := _tool_flags(main_src)
	_ok(flags.size() >= 4,
		"could not find main.gd's `tool_flags` list — this check has gone blind, fix the parse")
	for one_flag in flags:
		_ok(claude.contains(one_flag),
			("main.gd dispatches the gate flag `%s` and CLAUDE.md never mentions it. A gate nobody "
			+ "knows about is a gate nobody runs.") % one_flag)

	# 2. The script count HANDOFF advertises has to be the real one.
	var scripts: Array[String] = []
	var resources: Array[String] = []
	_walk_files("res://", scripts, resources)
	var claimed := _int_before(handoff, " GDScript files")
	if claimed > 0:
		_ok(claimed == scripts.size(),
			("docs/HANDOFF.md says %d GDScript files; there are %d. It is the first number a fresh "
			+ "session reads about the size of this project.") % [claimed, scripts.size()])


## The first undefined escape sequence used inside a string literal in `src`,
## or "" if there is none. Tracks string state properly rather than grepping:
## a backslash in a comment is prose, and a doubled backslash is a legal
## escaped backslash that must not be read as the start of another escape.
##
## The escapes GDScript defines, from the language reference: n t r a b f v,
## both quote characters, the backslash itself, uXXXX and UXXXXXXXX, plus a
## trailing backslash for line continuation. Anything else can stall the
## parser with no output — see `_the_files()`.
static func _bad_escape(src: String) -> String:
	const LEGAL := "ntrabfvuU"
	var i := 0
	var n := src.length()
	var quote := ""
	while i < n:
		var ch := src[i]
		if quote == "":
			if ch == "#":
				while i < n and src[i] != NEWLINE:
					i += 1
				continue
			if ch == QUOTE or ch == TICK:
				quote = ch
			i += 1
			continue
		if ch == quote:
			quote = ""
			i += 1
			continue
		if ch != BACKSLASH:
			i += 1
			continue
		if i + 1 >= n:
			return "<end of file>"
		var nxt := src[i + 1]
		if nxt == NEWLINE:
			i += 2
			continue
		if nxt != BACKSLASH and nxt != QUOTE and nxt != TICK and LEGAL.find(nxt) < 0:
			return nxt
		i += 2
	return ""


## The contents of `tool_flags := [ ... ]` in main.gd, as a list of "--flag".
static func _tool_flags(src: String) -> Array[String]:
	var out: Array[String] = []
	var at := src.find("tool_flags")
	if at < 0:
		return out
	var open_b := src.find("[", at)
	var close_b := src.find("]", open_b)
	if open_b < 0 or close_b < 0:
		return out
	for chunk in src.substr(open_b + 1, close_b - open_b - 1).split(","):
		var one := chunk.strip_edges().replace(QUOTE, "").strip_edges()
		if one.begins_with("--"):
			out.append(one)
	return out


## The integer immediately preceding `marker`, or -1. Used for "| Code | 69
## GDScript files" without caring where in the table it sits.
static func _int_before(text: String, marker: String) -> int:
	var at := text.find(marker)
	if at < 0:
		return -1
	var digits := ""
	var i := at - 1
	while i >= 0:
		var ch := text[i]
		if ch >= "0" and ch <= "9":
			digits = ch + digits
		elif digits != "":
			break
		elif ch != " ":
			break
		i -= 1
	return int(digits) if digits != "" else -1


static func _read_text(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var body := f.get_as_text()
	f.close()
	return body


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

## A CONTROL MUTATION HAS TO REACH THE CONTROLLER, NOT A LABEL.
##
## `CONTROL_KEYS` is the list a substance can satisfy the design rule with —
## *"a substance must never be only a number that goes up"* — so a key in it
## that nothing acts on is a hole straight through that rule. `no_early_exit`
## sat in the list for the life of the project: exported, aggregated through
## `_aggregate()`, and read by exactly one thing, `almanac.gd`, which printed
## **"Cannot end early — you finish the ride"**. There is no verb in
## single-player that ends a trip, so the line told the player about an option
## the other fifteen substances do not have either. A substance could have
## satisfied the whole design rule by setting a boolean that drew a sentence.
## Deleted in D-029; this is what stops the next one.
##
## The test is deliberately "read outside `scripts/ui/`" rather than "read by
## `goose_controller.gd`": `aggro_cats` is a legitimate control mutation that
## the GOOSE never reads — `cat.gd` does — and `substancetest::_the_cats()`
## measures it on the cats for exactly that reason.
static func _the_control_keys() -> void:
	var scripts: Array[String] = []
	var resources: Array[String] = []
	_walk_files("res://", scripts, resources)
	for key in CONTROL_KEYS:
		var used_in: Array[String] = []
		for path in scripts:
			if path.begins_with("res://scripts/ui/") or path.begins_with("res://tools/"):
				continue
			if path == "res://scripts/core/substance.gd":
				continue   # the declaration is not a use
			if _read_text(path).contains(str(key)):
				used_in.append(path)
		_ok(not used_in.is_empty(),
			("CONTROL_KEYS names \"%s\" and nothing outside scripts/ui and tools reads it. A "
			+ "substance could satisfy the design rule — never only a number that goes up — by "
			+ "setting a field that only draws a line in the Almanac. That is what no_early_exit "
			+ "did until D-029.") % key)

## ────────────────────────────────── objectives that can never appear

## AN OBJECTIVE GATED PAST ITS OWN ZONE IS AUTHORED CONTENT NOBODY WILL EVER
## SEE.
##
## `mission_defs.gd` entries carry `from_leg` / `until_leg`, and `for_zone()`
## filters on them — but a zone is only played on the legs `ROUTE` gives it.
## `strip_mall` runs at legs 1 and 2 and had three objectives gated at 3, 4
## and 5; `suburbia` runs at leg 3 alone and had two gated at 4 and 5. **Five
## authored objectives, including the game's only chain-length primary, that
## no player could ever be offered.** Nothing said so, because the filter is
## correct — it is the DATA that describes a leg the zone never reaches.
##
## Reuses `_route_zone_ids`, which `_the_objectives()` already collects, so no
## zone is instantiated twice for this.
static func _the_objectives_are_reachable(main: Node) -> void:
	var defs := load("res://scripts/core/mission_defs.gd")
	if defs == null or _route_zone_ids.is_empty():
		_ok(false, "the objective reachability check could not read the route — it has gone blind")
		return

	# zone id -> every leg ROUTE actually plays it on.
	var legs_of := {}
	for i in _route_zone_ids.size():
		var zid: StringName = _route_zone_ids[i]
		if not legs_of.has(zid):
			legs_of[zid] = []
		legs_of[zid].append(i + 1)

	for zid2 in legs_of.keys():
		var legs: Array = legs_of[zid2]
		# The union of what for_zone() offers across every leg this zone is
		# played on. Anything declared for the zone and absent from the union is
		# gated outside its own life.
		var offered := {}
		for leg in legs:
			for e in defs.for_zone(zid2, int(leg)):
				offered[str(e.get("id", "?"))] = true
		# Everything the zone declares at all, found by asking for a leg range
		# wide enough to clear any gate anyone would write.
		var declared := {}
		for leg2 in range(1, 40):
			for e2 in defs.for_zone(zid2, leg2):
				declared[str(e2.get("id", "?"))] = true
		for oid in declared.keys():
			_ok(offered.has(oid),
				("mission_defs declares \"%s\" for zone \"%s\", and its leg gate excludes every leg "
				+ "ROUTE plays that zone on (%s). It is authored content no player can ever be "
				+ "offered.") % [oid, zid2, str(legs)])

## ─────────────────────────────────────────── the two clocks the card promises

## THE RESULTS CARD PROMISES TWO FUTURES AND ONE OF THEM WAS THE WRONG LEG.
##
## It quotes "make the crossing and the next leg is X" and "land short and it
## is Y". Landing short does **not** advance the leg —
## `main.gd::_on_migration_done()` only increments on `made_it` — so the player
## replays THIS one. Both numbers were derived from `leg_seconds(leg + 1)`.
##
## On every leg whose clock differs from the next one's that is a lie to the
## player at the exact moment they are deciding whether to risk the crossing.
## Leg 1 is 240 s and leg 2 is 180, so failing flight 1 was advertised as a
## 120 s retry of a 240 s zone — a full minute wrong.
static func _the_result_clocks(main: Node) -> void:
	var mission := main.get_node_or_null("/root/Mission")
	if mission == null:
		_ok(false, "Mission autoload missing, so the results card's clocks cannot be checked")
		return
	var route: Array = main.get_script().get_script_constant_map().get("ROUTE", [])
	if route.is_empty():
		_ok(false, "could not read ROUTE to check the results card's clocks")
		return

	# At least one pair of adjacent legs must differ, or this check would pass
	# on the broken code too. Leg 1 (240) against leg 2 (180) is that pair, and
	# if the route is ever flattened to one clock this says so rather than
	# quietly becoming decorative.
	var differ := false
	for i in route.size() - 1:
		if not is_equal_approx(float(main.leg_seconds(i + 1)), float(main.leg_seconds(i + 2))):
			differ = true
			break
	_ok(differ,
		("every leg in ROUTE has the same clock, so this check cannot tell the short-landing "
		+ "clock from the next-leg clock and proves nothing. It needs one adjacent pair that "
		+ "differs — leg 1 is 240 and leg 2 is 180 today."))

	_ok(mission.has_method("begin_leg") and mission.has_method("evaluate_leg"),
		"Mission lost begin_leg/evaluate_leg, so this check has gone blind")
	if not (mission.has_method("begin_leg") and mission.has_method("evaluate_leg")):
		return
	for leg in range(1, route.size() + 1):
		# `evaluate_leg()` reads Mission's CURRENT leg rather than taking one, so
		# each leg has to be started before it can be evaluated. The zone id does
		# not matter here — only the clock arithmetic is under test — but it has
		# to be a real one or the objective set falls through to the generic.
		mission.begin_leg(_route_zone_ids[leg - 1] if leg <= _route_zone_ids.size()
			else &"strip_mall", leg)
		var r: Dictionary = mission.evaluate_leg()
		_ok(not r.is_empty(), "evaluate_leg() returned nothing for leg %d" % leg)
		if r.is_empty():
			continue
		_ok(r.has("short_zone_base"),
			("evaluate_leg(%d) returns no `short_zone_base`, so the card falls back to the NEXT "
			+ "leg's clock for a landing that replays THIS one.") % leg)
		if not r.has("short_zone_base"):
			continue
		_ok(is_equal_approx(float(r.short_zone_base), float(main.leg_seconds(leg))),
			("evaluate_leg(%d).short_zone_base is %.0f and leg %d is %.0f s. Landing short "
			+ "replays this leg, so that is the clock the card has to quote.")
				% [leg, float(r.short_zone_base), leg, float(main.leg_seconds(leg))])
		_ok(is_equal_approx(float(r.next_zone_base), float(main.leg_seconds(leg + 1))),
			("evaluate_leg(%d).next_zone_base is %.0f and leg %d is %.0f s.")
				% [leg, float(r.next_zone_base), leg + 1, float(main.leg_seconds(leg + 1))])

## ─────────────────────────────────────────────────── watertight primitives

## A SOLID HAS NO HOLES IN IT, AND ONE OF THESE DID.
##
## `LowPolyBuilder.wedge()` fans a base polygon to a ridge line, switching from
## `tip_a` to `tip_b` halfway round. That ridge meets the base at TWO seams —
## where the switch happens and where the loop wraps — and only the wrap was
## closed. Every wedge in the project therefore shipped with a triangular hole:
## both ears on the cat, both on the Ranger's retriever, and the human's nose.
##
## **It survived a render pass**, which is the part worth keeping. A hole in a
## closed model does not read as a hole; it reads as one dark facet, exactly
## the way `CLAUDE.md` says an inside-out mesh "shades plausibly". Looking at a
## picture is necessary and it is not sufficient, and this is the arithmetic
## that is.
##
## THE TEST IS EULER, NOT EYESIGHT. In a closed triangle mesh every edge is
## shared by exactly two faces. Count the edges that are not, and a watertight
## primitive scores zero. The vertices come back duplicated per face, so edges
## are keyed on quantised POSITIONS rather than indices.
static func _the_primitives_are_closed() -> void:
	var lpb := load("res://scripts/goose/lowpoly_builder.gd")
	if lpb == null:
		_ok(false, "lowpoly_builder.gd did not load")
		return

	# A 4-gon base and a ridge above it: the shape a cat's ear is.
	for sides in [4, 5, 6]:
		var b = lpb.new()
		var base := PackedVector3Array()
		for i in sides:
			var a := TAU * float(i) / float(sides)
			base.append(Vector3(cos(a) * 0.5, 0.0, sin(a) * 0.5))
		b.wedge(base, Vector3(-0.15, 0.6, 0.0), Vector3(0.15, 0.6, 0.0),
			Vector3(0.0, 0.1, 0.0), Color.WHITE)
		var open_edges := _boundary_edges(b.commit())
		# THE BASE RING IS SUPPOSED TO BE OPEN. A wedge is an ear or a nose: it
		# glues onto a head, so its base has no cap and contributes exactly
		# `sides` boundary edges. Anything MORE than that is a hole in the shell.
		# Measured both ways on the same file: with the switch seam unclosed this
		# returns sides + 3 (7, 8, 9 for a 4-, 5- and 6-gon), and with it closed it
		# returns exactly sides (4, 5, 6). Those three edges are the missing
		# triangle.
		_ok(open_edges == sides,
			("LowPolyBuilder.wedge() on a %d-gon base leaves %d boundary edges and should leave "
			+ "%d — the base ring and nothing else. The ridge meets the base at TWO seams and "
			+ "both have to be closed; %d extra means one is open. A hole in a closed model reads "
			+ "as one dark facet rather than as a hole, so a render will not tell you.")
				% [sides, open_edges, sides, open_edges - sides])

	# The box is the control: if this ever reports open edges the COUNTER is
	# broken, not the builder, and the wedge result above means nothing.
	var bx = lpb.new()
	bx.box(Vector3.ZERO, Vector3(0.5, 0.5, 0.5), Color.WHITE)
	var box_open := _boundary_edges(bx.commit())
	_ok(box_open == 0,
		("LowPolyBuilder.box() reports %d open edges. A box is watertight by construction, so "
		+ "this is the edge counter failing and every wedge result beside it is worthless.")
			% box_open)


## Edges adjacent to an odd number of faces in a non-indexed triangle mesh.
static func _boundary_edges(mesh: ArrayMesh) -> int:
	if mesh == null or mesh.get_surface_count() == 0:
		return -1
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var counts := {}
	var tri_total := verts.size() / 3
	for t in tri_total:
		var p := [verts[t * 3], verts[t * 3 + 1], verts[t * 3 + 2]]
		for e in 3:
			var u: Vector3 = p[e]
			var v: Vector3 = p[(e + 1) % 3]
			counts[_edge_key(u, v)] = counts.get(_edge_key(u, v), 0) + 1
	var odd := 0
	for k in counts.keys():
		if int(counts[k]) % 2 == 1:
			odd += 1
	return odd


## Order-independent key for an edge, quantised because the builder emits a
## fresh vertex per face and float equality across those is not guaranteed.
static func _edge_key(u: Vector3, v: Vector3) -> String:
	var a := "%.4f,%.4f,%.4f" % [u.x, u.y, u.z]
	var b := "%.4f,%.4f,%.4f" % [v.x, v.y, v.z]
	return (a + "|" + b) if a < b else (b + "|" + a)

## ────────────────────────────────────────────────── the hitstop budget

## THE ONE RULE THAT WAS A COUNT IN A COMMENT, AND WAS WRONG BY THREE.
##
## `juice.gd` opens with three rules it calls "not negotiable", and the first
## said **"HITSTOP HAS EXACTLY FIVE CALL SITES in the whole game"** and named
## them. There were eight. The three it did not name — the Ranger's HAZED, a
## storey of BIG DOWN's glass, and the truck stop's diner window — are each
## argued at length where they sit, so the SITES were fine and the RULE had
## rotted. A number in a comment cannot notice a fourth caller.
##
## So the rule is a table now, and this is what makes it a rule. The check is
## symmetric on purpose: a call the table does not list fails, and a row with
## no call fails too. A table that can quietly describe a site somebody
## deleted is the same rot wearing the other shoe.
static func _the_hitstops() -> void:
	var juice := load("res://scripts/core/juice.gd")
	if juice == null:
		_ok(false, "juice.gd did not load, so the hitstop budget cannot be checked")
		return
	var table: Array = juice.get_script_constant_map().get("HITSTOP_SITES", [])
	_ok(table.size() >= 4,
		"juice.gd::HITSTOP_SITES has %d rows — this check has gone blind, fix the parse" % table.size())

	# What the table says, as a bag of "path|seconds|strength".
	var declared := {}
	for row in table:
		var r: Array = row
		var key := "%s|%.2f|%.2f" % [str(r[0]), float(r[1]), float(r[2])]
		declared[key] = declared.get(key, 0) + 1

	# What the code does.
	var found := {}
	var scripts: Array[String] = []
	var resources: Array[String] = []
	_walk_files("res://", scripts, resources)
	var re := RegEx.new()
	re.compile("Juice\\.hitstop\\(\\s*(-?[0-9.]+)\\s*,\\s*(-?[0-9.]+)\\s*\\)")
	for path in scripts:
		if path.begins_with("res://tools/"):
			continue
		var rel := path.replace("res://", "")
		for m in re.search_all(_read_text(path)):
			var key2 := "%s|%.2f|%.2f" % [rel, float(m.get_string(1)), float(m.get_string(2))]
			found[key2] = found.get(key2, 0) + 1

	for k in found.keys():
		_ok(declared.has(k) and int(declared[k]) == int(found[k]),
			("Juice.hitstop is called %d time(s) as `%s` and juice.gd::HITSTOP_SITES declares it "
			+ "%d. Nothing the player can trigger more than a few times a minute may freeze the "
			+ "frame; if this one is right, add the row and write down what it is for.")
				% [int(found[k]), k, int(declared.get(k, 0))])
	for k2 in declared.keys():
		_ok(found.has(k2),
			("juice.gd::HITSTOP_SITES declares `%s` and no call site matches it. A table that can "
			+ "describe a hitstop somebody deleted is the same rot as a count that cannot see a "
			+ "new one.") % k2)

## ────────────────────────────────────────────── the overlay stack

## EVERY OVERLAY OWNS ITS OWN LAYER, AND NO TWO MAY SHARE ONE.
##
## `main.gd::_build_overlays()` used to set a layer on each overlay right
## before `add_child()` — and `add_child()` runs the widget's `_ready()`,
## which sets it again. Seven of the eight agreed, so seven were dead
## duplicates. The eighth did not: main said `almanac.layer = 20` and
## `almanac.gd` says 40. **40 won, which is the only reason the Almanac
## works** — it is opened FROM the pause menu at 30, so at 20 it would have
## rendered underneath the menu that opened it and read as a dead keypress.
## A contradiction that happens to be resolved the right way is still a
## contradiction, and nothing was checking it.
##
## Two rules, both mechanical:
##   1. `main.gd` does not assign `.layer` to anything it did not build
##      itself. One owner per number.
##   2. No two overlay scripts declare the same layer. A tie is resolved by
##      tree order, which is not a thing anyone reasons about correctly.
static func _the_layers() -> void:
	var dir := DirAccess.open("res://scripts/ui")
	_ok(dir != null, "res://scripts/ui is unreadable, so the overlay stack cannot be checked")
	if dir == null:
		return
	var seen := {}
	var re := RegEx.new()
	# `layer = 30` or `const LAYER := 32`, at any indent. Deliberately also
	# matches `fx_layer.layer = 1` — a nested CanvasLayer competes for the same
	# numbers as everything else and a collision there is just as silent.
	re.compile("(?m)^[\\t ]*(?:const LAYER :=|[a-z_]*\\.?layer =) *([0-9]+)")
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".gd"):
			var body := _read_text("res://scripts/ui/" + fname)
			for m in re.search_all(body):
				var n := int(m.get_string(1))
				_ok(not seen.has(n),
					("scripts/ui/%s and %s both draw on CanvasLayer %d. Which one covers the "
					+ "other is decided by tree order, which nobody reasons about correctly.")
						% [fname, seen.get(n, "?"), n])
				seen[n] = fname
		fname = dir.get_next()
	dir.list_dir_end()
	_ok(seen.size() >= 6,
		"found only %d CanvasLayer declarations under scripts/ui — this check has gone blind, fix the parse" % seen.size())

	# And the director does not get a second opinion.
	var main_src := _read_text(SRC_MAIN)
	var re2 := RegEx.new()
	re2.compile("(?m)^[\\t ]*([a-z_]+)\\.layer = ([0-9]+)")
	for m2 in re2.search_all(main_src):
		var who := m2.get_string(1)
		_ok(who == "restart_prompt",
			("main.gd sets %s.layer = %s, and %s's own _ready() sets it too — whichever runs "
			+ "last wins silently. The widget owns its layer; the only exception is "
			+ "restart_prompt, which main.gd builds itself.") % [who, m2.get_string(2), who])

## ────────────────────────────────────────────────────────── the leg-1 shelf

## LEG 1 AND LEG 2 ARE THE SAME PLACE, AND THEY WERE THE SAME GAME.
##
## `zone_strip_mall.gd::_sources()` built all sixteen substances unconditionally
## and the file had no leg branch anywhere, so the first 420 seconds of the
## campaign were one zone served twice at identical intensity — while
## `docs/CAMPAIGN_SPEC.md` §2.1 gives leg 1 three substances and §2.2 gives leg 2
## "all sixteen … this is where the lid comes off". The first rise of the whole
## escalation curve was specced, documented, and not built.
##
## THIS HALF ONLY READS THE DECLARATION, AND THAT IS NOT ENOUGH ON ITS OWN.
## A shelf can be filtered correctly by a function that no pickup site calls —
## the `stamina_restore` shape (D-017/D-018), where the data was right and
## nothing read it. **The behavioural half lives in the campaign gate**
## (`main.gd`, `--loop-test`), which counts the pickups in the zone THE
## DIRECTOR BUILT, on every one of the seven legs, and fails the run if leg 1
## is not narrow or leg 2 is not whole. Both halves are needed and neither is
## in the other's file, so this comment is the link.
##
## IT USED TO BUILD THE ZONES HERE AND THAT WAS WRONG TWICE OVER. `run()` is
## called from `main._ready()`, so the scene root is still "busy setting up
## children" and `add_child()` fails — silently, returning a zone with nothing
## in it, so the first version accused a correct filter of spawning zero
## pickups on both legs. Awaiting a frame fixed that and exposed the second
## problem: letting the tree run further inside `--selftest` left audio streams
## referenced at exit (`ERROR: 17 resources still in use`), which is a red
## build by this project's own rule. The campaign gate already builds all seven
## legs through the real path and tears down cleanly. Do not move it back.
static func _the_shelf(main: Node) -> void:
	var zs := load("res://scripts/world/zone_strip_mall.gd")
	if zs == null:
		_ok(false, "zone_strip_mall.gd did not load")
		return
	var subs := main.get_node_or_null("/root/Subs")
	if subs == null:
		_ok(false, "Subs autoload missing — the shelf cannot be counted")
		return

	var consts: Dictionary = zs.get_script_constant_map()
	var tutorial: Array = consts.get("TUTORIAL_SHELF", [])
	var from_leg: int = int(consts.get("FULL_SHELF_FROM_LEG", 0))
	var full: int = int(subs.library.size())

	_ok(from_leg == 2,
		"zone_strip_mall.FULL_SHELF_FROM_LEG is %d. Leg 1 is the only narrowed leg in the campaign; anything but 2 either widens leg 1 or narrows leg 2." % from_leg)
	_ok(tutorial.size() == 4,
		"CAMPAIGN_SPEC §2.1 gives leg 1 three substances PLUS bread; TUTORIAL_SHELF declares %d." % tutorial.size())
	for want in [&"berries", &"double_double", &"grass", &"bread"]:
		_ok(tutorial.has(want),
			"TUTORIAL_SHELF is missing %s, which CAMPAIGN_SPEC §2.1 names by hand." % want)
	for tut_id in tutorial:
		_ok(subs.get_substance(tut_id) != null,
			"TUTORIAL_SHELF names \"%s\" and no such substance is in the shelf." % tut_id)

	# The set has to be closed under the game's own mixing rule, not merely
	# small. `mission_defs.gd`'s leg-1 primary `double_parked` requires two
	# substances at once, so a tutorial shelf that cannot make a pair makes one
	# of leg 1's four primaries impossible — and a named combo is the reward
	# that teaches mixing is worth doing.
	_ok(tutorial.size() >= 2,
		"leg 1's `double_parked` primary needs two substances at once and the tutorial shelf offers %d." % tutorial.size())
	var combos: Dictionary = subs.get_script().get_script_constant_map().get("COMBOS", {})
	var reachable := 0
	for key in combos.keys():
		var pair: PackedStringArray = str(key).split("|")
		var both := true
		for half in pair:
			if not tutorial.has(StringName(half)):
				both = false
		if both:
			reachable += 1
	_ok(reachable >= 1,
		"no named combo in Subs.COMBOS can be mixed from the tutorial shelf, so leg 1 can teach that mixing exists but never that it pays.")

	# LEG 1 IS WHERE THE CONTROLS ARE LEARNED, SO ONE OF THEM HAS TO BE CLEAN.
	#
	# `input_lag` is added on top of the controller's sober latency, which
	# `feeltest.gd` measures at 1.00 tick. Liu and Claypool measured LOCAL
	# latency at roughly twice the performance impact of the same network
	# latency, and this project's most expensive bug of all time was an input
	# lag that made eleven of the sixteen substances unplayable. Measured across
	# the shelf: toad_slime 0.28 is the worst, percs 0.24, berries 0.22, and six
	# substances are at 0.00.
	#
	# TWO OF THE THREE TUTORIAL SUBSTANCES ADD LAG — berries 0.22 and grass
	# 0.10 — and that is deliberate rather than an oversight: fermented berries
	# ARE the drunk one, and CAMPAIGN_SPEC §2.1 names it. So the rule is not
	# "no lag on leg 1". It is the two things that would actually break the
	# lesson:
	#
	#   * at least one option with NO added lag, so the player has a baseline to
	#     learn the controls against and something to compare the others to;
	#   * never the worst control in the game as a first lesson.
	#
	# See docs/DECISIONS.md D-021.
	var worst_shelf := 0.0
	for lib_id in subs.library.keys():
		var lib_res: Resource = subs.library[lib_id]
		worst_shelf = maxf(worst_shelf, float(lib_res.get("input_lag")))
	var worst_tut := 0.0
	var clean_tut := 0
	for lag_id in tutorial:
		var lag_res: Resource = subs.get_substance(lag_id)
		if lag_res == null:
			continue
		var lag: float = float(lag_res.get("input_lag"))
		worst_tut = maxf(worst_tut, lag)
		if lag <= 0.0:
			clean_tut += 1
	_ok(clean_tut >= 1,
		"every substance on the tutorial shelf adds input lag (worst %.2f s). Leg 1 is where the controls are learned and the player needs one option that does not delay the stick." % worst_tut)
	_ok(worst_tut < worst_shelf,
		"the tutorial shelf carries the worst input lag in the game (%.2f s, and the shelf maximum is %.2f). The first lesson may not be the least responsive control in it." % [worst_tut, worst_shelf])

	var declared_1: Dictionary = zs.shelf_for_leg(1)
	var declared_2: Dictionary = zs.shelf_for_leg(from_leg)
	_ok(declared_1.size() == tutorial.size(),
		"shelf_for_leg(1) offers %d ids against a TUTORIAL_SHELF of %d." % [declared_1.size(), tutorial.size()])
	_ok(declared_2.size() == full,
		"shelf_for_leg(%d) offers %d of the shelf's %d substances. Leg 2 is where the lid comes off; it gets all of them." % [from_leg, declared_2.size(), full])


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
	#
	# THE COMPARISON USED TO BE UNREACHABLE. It was guarded on
	# `subs.has_method("all")` with a comment about `Subs` exposing its table
	# "under different names across versions" — and `Subs` has no `all()`. There
	# is one version of this project and one accessor. So the guard always fell
	# through to `ids.size() > 0`, which sixteen files on disk make trivially
	# true, and the only check that could see `_load_library()` silently dropping
	# a substance has never once run. Defensive coding against a variant that does
	# not exist is how a live assertion becomes a dead one.
	#
	# `library` is a plain public var on `substance_manager.gd` and needs no
	# accessor.
	var shelf: Dictionary = subs.library
	_ok(ids.size() > 0, "no substances found in %s" % SUBSTANCE_DIR)
	_ok(shelf.size() == ids.size(),
		("Subs loaded %d substances but %s holds %d files — _load_library() dropped one and "
		+ "nothing else in the project would notice.") % [shelf.size(), SUBSTANCE_DIR, ids.size()])


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

static func _the_time_scale(tree: SceneTree) -> void:
	# Engine.time_scale has exactly two owners, and a stranded write once left a
	# run in permanent 0.106x slow motion with no way out. After both owners
	# have been reset, the clock must be 1.0 — if a third writer ever appears,
	# this is where it shows up.
	#
	# IT COULD NOT SHOW UP HERE, AND FOR THE WHOLE LIFE OF THE CHECK. The
	# assertion read `Engine.time_scale` on the statement AFTER
	# `subs.reset_for_new_leg()`, whose body contains an unconditional
	# `Engine.time_scale = 1.0`. There was no await and no frame boundary between
	# the write and the read, so this passed for every possible state of the game
	# — including the exact 0.106x case its own comment cites, and including the
	# four places `main.gd` itself writes the clock.
	#
	# A third writer is by definition something that writes EVERY FRAME, or on a
	# signal. The only form of this check that can see one is: reset both owners,
	# then let the tree actually run, then look. Watched fail before it was
	# trusted — a temporary `Engine.time_scale = 0.5` in an autoload `_process`
	# trips it; the old form did not notice.
	var juice := Engine.get_main_loop().root.get_node_or_null("Juice") as Node
	var subs := Engine.get_main_loop().root.get_node_or_null("Subs") as Node
	if juice != null and juice.has_method("reset"):
		juice.reset()
	if subs != null and subs.has_method("reset_for_new_leg"):
		subs.reset_for_new_leg()
	var worst := 1.0
	for _i in 20:
		await tree.physics_frame
		await tree.process_frame
		if absf(Engine.time_scale - 1.0) > absf(worst - 1.0):
			worst = Engine.time_scale
	_ok(is_equal_approx(worst, 1.0),
		("Engine.time_scale reached %.3f over 20 frames after Subs and Juice had both reset — "
		+ "a third writer has appeared. They have a documented contract in docs/JUICE_NOTES.md "
		+ "and a stranded write once left a run in permanent 0.106x slow motion with no way out.")
			% worst)
