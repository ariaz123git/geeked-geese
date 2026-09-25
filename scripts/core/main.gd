extends Node
## Scene director. Owns the loop: BRIEF → ZONE → BRIEF → MIGRATION → next leg.
##
## Swaps child scenes rather than calling change_scene_to_file, so autoload
## state (tolerance, flock condition, unlocks, mission progress) survives
## across phases.
##
## Also owns the things that must be global rather than per-zone: mouse
## capture, the pause / almanac / controls overlays, and the briefing cards.
## Zones come and go; those don't.

const BRIEF_DEFS := preload("res://scripts/ui/briefing_defs.gd")

## THE FLYWAY — a finite route, not a rotation.
##
## The game used to wrap `ZONE_ROTATION` modulo 3, which meant leg 40 was the
## strip mall again and the run had no ending, no failure, and no reason to
## start a second one. This is the fixed eight-leg journey from a suburban
## retention pond to a Florida golf course. See docs/CAMPAIGN_SPEC.md.
##
## ROUTE holds the seven FLOWN legs. Leg 8 — the 18th green — is not in here,
## because it is not a leg: there is no clock, no objectives and no flight out
## of it. It is the arrival, and it lives in `_finish_run()`.
##
## Every leg now has its own zone. Legs 1 and 2 deliberately share
## `zone_strip_mall.gd` — one place, two visits, which is the joke — and that is
## the only reuse left. Leg 5 stopped being a second helping of cottage country
## when `zone_stopover.gd` landed.
const ROUTE := [
	{"zone": "res://scripts/world/zone_strip_mall.gd", "name": "THE RETENTION POND", "seconds": 240.0},
	{"zone": "res://scripts/world/zone_strip_mall.gd", "name": "THE STRIP MALL LOT", "seconds": 180.0},
	{"zone": "res://scripts/world/zone_suburbia.gd",   "name": "SUBURBIA",           "seconds": 180.0},
	{"zone": "res://scripts/world/zone_cottage.gd",    "name": "COTTAGE COUNTRY",    "seconds": 180.0},
	{"zone": "res://scripts/world/zone_stopover.gd",   "name": "THE STOPOVER",       "seconds": 150.0},
	{"zone": "res://scripts/world/zone_corn.gd",       "name": "THE CUT CORN",       "seconds": 180.0},
	# 230, which is what docs/BOSS_DESIGN.md §2.2.2 asks for: 110 in the truck
	# stop, then the tower, then the roof.
	#
	# THIS SAID 180 FOR A REASON THAT HAD STOPPED BEING TRUE. The comment here
	# used to forbid 230 because "the truck stop's departure schedule
	# (`DEPART_AT`) is written against a 180 s clock, and a rig that leaves after
	# the leg ends is a rig that never leaves." That was correct when written and
	# was made obsolete by `zone_truckstop.gd::_clock_scale()`, which rescales
	# the whole schedule proportionally to whatever clock the leg is handed.
	# Nobody noticed, because a comment cannot run: the constraint sat here as
	# prose, blocking a change it no longer described, and `docs/HANDOFF.md`
	# carried it forward as an open item.
	#
	# It is now an assertion instead — `tools/selftest.gd::_the_rig_schedule()`
	# reproduces the scaling and checks the last rig still departs, with the
	# zone's closing beat intact, on EVERY clock this leg can legally be dealt.
	# Measured at 230: scale 1.278, last rig gone at 216 s, 13.8 s of empty lot,
	# the same 6.0% of the leg the schedule leaves at every other clock.
	#
	# BIG DOWN needed no change. It opens the dock when the leg has
	# DOCK_OPENS_WITH (118 s) LEFT rather than at a fixed elapsed time, precisely
	# so it would survive this: t=62 on the old clock, t=112 on this one, which
	# is the 110 s truck-stop phase §2.2.2 specifies, to within two seconds.
	{"zone": "res://scripts/world/zone_truckstop.gd",  "name": "THE TRUCK STOP",     "seconds": 230.0},
]

## Completing THIS leg's flight ends the run. It is 7, not 8, and that is the
## whole shape of the ending: the climax is flight 7 — the longest, meanest
## crossing in the game — and what follows it is the epilogue rather than
## another leg. See the intensity curve in docs/CAMPAIGN_SPEC.md.
##
## The run used to award a leg 8 that reused cottage country and was named "THE
## 18TH GREEN", and then ran the real 18th green after it, so the arrival
## happened twice and the first one was a lake in Ontario.
const FINAL_LEG := 7

## R restarts a forty-five minute run. It now asks twice: the first press arms
## it and puts a prompt on screen, a second press inside this window does it.
## Chosen over a modal because the mis-press this guards against happens mid
## flight, and a modal that stops the game to ask is a worse interruption than
## the thing it is preventing.
const RESTART_CONFIRM_MS := 1500

var current: Node = null
var hud: CanvasLayer = null
var mission_hud: CanvasLayer = null
var pause_menu: CanvasLayer = null
var almanac: CanvasLayer = null
var control_card: CanvasLayer = null
var briefing: CanvasLayer = null
var results: CanvasLayer = null
var roster: CanvasLayer = null
var restart_prompt: CanvasLayer = null
var halluc: Node3D = null

var _mouse_was_captured := true
var _hud_hidden := false

## Seconds into leg 3 before the Ranger's truck pulls up. Only the dev probe
## ever changes it (`--boss`), so an encounter that takes 80 s to begin can be
## photographed without burning 80 s of software-rendered wall clock.
var _ranger_delay := 80.0
## Negative means "open the dock when the leg has BIG DOWN's own
## DOCK_OPENS_WITH seconds left", which is the shipping behaviour. Only the dev
## probe (`--boss`) sets a literal countdown, for the same reason the Ranger's
## delay drops to 3 s: an encounter that begins two minutes in cannot otherwise
## be photographed.
var _big_down_delay := -1.0
## Ticks, not a countdown float: this has to survive a paused tree and an
## Engine.time_scale a substance parked at 0.3, and a wall clock does both for
## free.
var _restart_armed_ms := -1_000_000
## Names lost since the roster last showed them. Drained at the first natural
## stopping point, which is normally the end of the flight that cost them.
var _unseen_losses: Array[String] = []
var _restart_prompt_ctl: Control = null
## `migration.gd` emits `finished` on EVERY gg_skip press once the flight is
## over, not just the first. That was harmless while _on_migration_done() ran to
## completion inside the emit — but it now awaits the roster, so the press that
## dismisses the roster can reach the still-alive migration's _process in the
## same frame and emit a second time, advancing the leg twice. One boolean.
var _migration_done := false


func _ready() -> void:
	randomize()
	# Read before the first zone loads — `--boss` has to be in effect by the
	# time _load_zone() spawns the Ranger, which happens inside Game.new_run()
	# below, well before the probe body runs.
	if OS.get_cmdline_user_args().has("--boss"):
		_ranger_delay = 3.0
		_big_down_delay = 3.0
	# THE DEADLINE, BEFORE ANYTHING THAT COULD HANG. This used to be armed inside
	# `_probe_if_headless()`, which is the LAST statement of this function — so a
	# stall in `_build_overlays()` or in the first zone `Game.new_run()` builds
	# happened with no deadline running at all, and became exactly the invisible
	# process the failsafe exists to prevent. Zone construction is the largest
	# single body of code in this project and the likeliest place to hang.
	# `tools/selftest.gd::_the_failsafe_is_first()` asserts this order.
	_arm_headless_deadline()
	_build_overlays()
	Game.phase_changed.connect(_on_phase)
	Game.chaos_scored.connect(_on_chaos_scored)
	Mission.leg_decided.connect(_on_leg_decided)
	Flock.bird_lost.connect(_on_bird_lost)
	# Not `_process`: this node pauses with the tree, and every menu pauses it.
	get_tree().process_frame.connect(_poll_menus)
	# Capture before the first phase loads, so the briefing card can hand the
	# cursor back to a known state when it closes.
	_capture_mouse(true)
	Game.new_run(leg_seconds(1))
	_probe_if_headless()


# ---------------------------------------------------------------- overlays

func _build_overlays() -> void:
	pause_menu = preload("res://scripts/ui/pause_menu.gd").new()
	pause_menu.name = "PauseMenu"
	# NO `layer =` IN THIS FUNCTION, AND THAT IS THE FIX.
	#
	# Every overlay script already sets its own layer in `_ready()`, which
	# runs on `add_child()` — so every assignment here was either a duplicate
	# or a silent loser. `almanac.layer = 20` was the loser: `almanac.gd`
	# sets 40, so the 20 never took effect, and if it ever HAD the Almanac
	# would have opened underneath the pause menu (30) that opens it.
	#
	# The stack, owned one file each, checked by
	# `tools/selftest.gd::_the_layers()`:
	#   1  hud.gd fx    2  hud     3  mission_hud   25 briefing
	#   28 results      30 pause   32 roster        40 almanac
	#   41 control card 44 restart prompt (built here, so it keeps its own)
	add_child(pause_menu)

	almanac = preload("res://scripts/ui/almanac.gd").new()
	almanac.name = "Almanac"
	add_child(almanac)

	control_card = preload("res://scripts/ui/control_card.gd").new()
	control_card.name = "ControlCard"
	add_child(control_card)

	# Briefing is added AFTER the pause menu on purpose: Godot delivers _input in
	# reverse tree order, so this guarantees a briefing card swallows Escape
	# before the pause menu can open behind it. The roster and the restart prompt
	# are added later still, which is safe — the prompt has no _input at all, and
	# the roster's returns immediately unless it is open, which never overlaps a
	# briefing (every path that opens one awaits the other).
	briefing = preload("res://scripts/ui/briefing.gd").new()
	briefing.name = "Briefing"
	add_child(briefing)

	results = preload("res://scripts/ui/results_screen.gd").new()
	results.name = "Results"
	add_child(results)

	roster = preload("res://scripts/ui/flock_roster.gd").new()
	roster.name = "FlockRoster"
	add_child(roster)

	restart_prompt = _build_restart_prompt()
	restart_prompt.name = "RestartPrompt"
	# 44: over every menu. It is a warning about the thing the player is
	# currently doing, so nothing may cover it.
	restart_prompt.layer = 44
	add_child(restart_prompt)

	# The pause menu hands the screen to the Almanac and takes it back after,
	# keeping the tree paused across the whole handoff.
	if pause_menu.has_signal("almanac_requested"):
		pause_menu.almanac_requested.connect(func():
			if pause_menu.has_method("hide_for_overlay"):
				pause_menu.hide_for_overlay()
			_set_hud_visible(false)
			almanac.open())
	if almanac.has_signal("closed"):
		almanac.closed.connect(func():
			if pause_menu.has_method("show_after_overlay"):
				pause_menu.show_after_overlay())
	if pause_menu.has_signal("controls_requested"):
		pause_menu.controls_requested.connect(func():
			if pause_menu.has_method("hide_for_overlay"):
				pause_menu.hide_for_overlay()
			_set_hud_visible(false)
			control_card.open())
	if control_card.has_signal("closed"):
		control_card.closed.connect(func():
			if pause_menu.has_method("show_after_overlay"):
				pause_menu.show_after_overlay())
	if pause_menu.has_signal("flock_requested"):
		pause_menu.flock_requested.connect(func():
			if pause_menu.has_method("hide_for_overlay"):
				pause_menu.hide_for_overlay()
			_set_hud_visible(false)
			# Deliberate open, so no headline — nobody just died, the player is
			# checking on their geese.
			roster.open())
	if roster.has_signal("closed"):
		roster.closed.connect(func():
			if pause_menu != null and is_instance_valid(pause_menu) \
					and pause_menu.is_open() and pause_menu.has_method("show_after_overlay"):
				pause_menu.show_after_overlay())
	if pause_menu.has_signal("resumed"):
		pause_menu.resumed.connect(func(recapture: bool):
			_set_hud_visible(true)
			_capture_mouse(recapture and _mouse_was_captured))
	if pause_menu.has_signal("restart_requested"):
		pause_menu.restart_requested.connect(func():
			_capture_mouse(true)
			Engine.time_scale = 1.0
			# A loss that was never shown belongs to a run that no longer
			# exists; carrying it over would headline the next run's first
			# results screen with a stranger's name.
			_unseen_losses.clear()
			Game.new_run(leg_seconds(1)))


## Gameplay HUD is hidden while a menu owns the screen. Two reasons: the
## backdrop can't fully dim a layer drawn above it, and a paused clock sitting
## behind the Almanac just looks broken.
func _set_hud_visible(v: bool) -> void:
	if hud and is_instance_valid(hud):
		hud.visible = v
	# Through the panel, not onto its `visible`: the panel also answers to the
	# "Show hints" setting, and writing `visible` here undid that setting on
	# every menu close. See mission_hud.gd::set_host_visible().
	if mission_hud and is_instance_valid(mission_hud):
		mission_hud.set_host_visible(v)


## Mouse capture is a global concern: the camera only steers while captured,
## and menus must always be clickable. Tracked so closing a menu restores what
## the player was actually doing rather than forcing capture on someone playing
## entirely on the keyboard.
func _capture_mouse(on: bool) -> void:
	if on:
		_mouse_was_captured = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE


# ---------------------------------------------------------------- phases

func _on_phase(phase: int) -> void:
	match phase:
		Game.Phase.ZONE: _load_zone()
		Game.Phase.MIGRATION: _load_migration()


## Tear down the current phase.
##
## The renames are load-bearing, not tidiness. `queue_free()` does not free
## until the end of the frame, so the outgoing nodes still hold the names
## "Zone", "HUD" and "MissionHUD" when `_load_zone()` adds the replacements in
## the same frame — and `add_child()` with the default `force_readable_name =
## false` responds to a name collision by DISCARDING the requested name
## entirely, producing `@Node3D@927`. Anything that looks a node up by literal
## name then finds the dying one or nothing: `honk.gd::_ring()` does exactly
## that and was silently falling back to the scene root. Renaming the corpses
## first frees the names immediately.
func _clear() -> void:
	if current and is_instance_valid(current):
		current.name = "ZoneOutgoing"
		current.queue_free()
	current = null
	if hud and is_instance_valid(hud):
		hud.name = "HUDOutgoing"
		hud.queue_free()
	hud = null
	if mission_hud and is_instance_valid(mission_hud):
		mission_hud.name = "MissionHUDOutgoing"
		mission_hud.queue_free()
	mission_hud = null
	halluc = null
	Juice.reset()
	var sfx := get_node_or_null("/root/Sfx")
	if sfx:
		sfx.stop_loop(&"swim")
		sfx.stop_loop(&"charge")
		sfx.stop_loop(&"wind")
		# Ambience joins the list. It is the only loop bus in the game nothing
		# ever stopped, and Sfx's loop players are PROCESS_MODE_ALWAYS — so the
		# parking lot used to keep running under the results card, under the
		# flight, and under the 18th green.
		sfx.stop_ambience()


func _route_entry(leg: int) -> Dictionary:
	var i: int = clampi(leg - 1, 0, ROUTE.size() - 1)
	return ROUTE[i]


func _zone_script_for_leg(leg: int) -> String:
	return str(_route_entry(leg).zone)


## THE public accessor for a leg's clock, in seconds, before any mission
## modifier. Requested by name in docs/CLOCK_AND_CAMERA_NOTES.md and already
## preferred by `Mission.leg_seconds()`, which until now fell through to reading
## the ROUTE constant off this script's constant map because this did not exist.
##
## Everything that wants to know how long a leg is asks here. That is the whole
## point: the clock has shipped the same lie twice because two files each decided
## it independently.
func leg_seconds(leg: int) -> float:
	return float(_route_entry(leg).seconds)


## The name the route gives a leg. Zones may override it with `zone_title()`,
## but a zone reused across two legs (leg 1 and leg 2 are both
## `zone_strip_mall.gd`) cannot know which leg it is standing in, so the route
## wins when it has an opinion.
##
## `ROUTE.name` used to be read by nothing at all. The result was that leg 1
## announced itself as "LEG 1 — STRIP MALL LOT" while the route, the campaign
## spec and the ending's own credit roll all call it THE RETENTION POND — the
## player is told the name of a place only in the credits, twenty legs after
## they left it.
func leg_title(leg: int) -> String:
	var nm := str(_route_entry(leg).get("name", ""))
	if nm == "":
		return "LEG %d" % leg
	return "LEG %d — %s" % [leg, nm]


## What this leg is called, on the HUD banner and on the results card — one
## source, because those two disagreeing is how nobody noticed for six months.
##
## The route wins where it has a name; a zone's own `zone_title()` is the
## fallback for anything installed outside the route (the finale) or authored
## without a route entry. Every zone in the route today returns exactly the
## string the route does, EXCEPT the two reused ones — which is the bug.
func _title_for(zone: Node, leg: int) -> String:
	var nm := str(_route_entry(leg).get("name", ""))
	if nm != "" and leg >= 1 and leg <= ROUTE.size():
		return "LEG %d — %s" % [leg, nm]
	if zone != null and is_instance_valid(zone) and zone.has_method("zone_title"):
		return str(zone.zone_title())
	return "LEG %d" % leg


func _load_zone() -> void:
	_clear()

	var path := _zone_script_for_leg(Flock.leg)
	var zone_script := load(path)
	var zone = zone_script.new()
	zone.name = "Zone"
	add_child(zone)
	current = zone

	hud = preload("res://scripts/ui/hud.gd").new()
	hud.name = "HUD"
	add_child(hud)
	hud.goose = zone.goose

	# Deliriant hallucinations live beside the zone, not inside it, so a zone
	# author never has to think about them.
	halluc = preload("res://scripts/world/hallucinations.gd").new()
	halluc.name = "Hallucinations"
	zone.add_child(halluc)
	halluc.goose = zone.goose

	# THE RANGER. Leg 3 only, arriving 80 s into a 180 s clock. He lives beside
	# the zone exactly like the hallucinations do — the zone script does not know
	# he exists and tears him down with itself. See docs/BOSS_RANGER_BUILD.md.
	if Flock.leg == 3 and zone.goose != null:
		preload("res://scripts/world/boss_ranger.gd").spawn_into(zone, zone.goose, _ranger_delay)

	# BIG DOWN. Leg 7 only. Same arrangement as the Ranger — it lives BESIDE the
	# truck stop, which does not know it exists and tears it down with itself —
	# but it opens on the CLOCK rather than on a fixed countdown: a negative
	# delay means "when the leg has DOCK_OPENS_WITH seconds left", which is the
	# only form that survives leg 7 being 180 s today and 230 s if the rig
	# departure schedule is ever rewritten for it. `--boss` shortens it so the
	# encounter can be photographed without burning two minutes of wall clock.
	# See docs/BOSS_DESIGN.md §2.2.
	if Flock.leg == 7 and zone.goose != null:
		preload("res://scripts/world/boss_big_down.gd").spawn_into(zone, zone.goose, _big_down_delay)

	mission_hud = preload("res://scripts/ui/mission_hud.gd").new()
	mission_hud.name = "MissionHUD"
	add_child(mission_hud)

	var zid: StringName = &"generic"
	if zone.has_method("mission_zone_id"):
		zid = zone.mission_zone_id()
	Mission.begin_leg(zid, Flock.leg)
	Mission.bind_goose(zone.goose)

	var sfx := get_node_or_null("/root/Sfx")
	if sfx:
		# The bed follows the ZONE ID, not the leg number. Leg numbers move — a
		# phantom leg 8 was deleted last session and leg 5 is about to stop being
		# cottage country — and zone ids do not. The table and the per-zone level
		# live in sfx.gd::AMBIENCE_BEDS / AMBIENCE_DB.
		#
		# This line used to be `sfx.loop(&"amb_parking_lot", ...)`, unconditionally,
		# for all seven legs: a cottage lake at night, a dawn marsh and a truck stop
		# in the rain all sounded like a strip mall parking lot.
		sfx.set_ambience(zid)

	var title := _title_for(zone, Flock.leg)
	if hud.has_method("set_zone_title"):
		hud.set_zone_title(title)

	await _brief_zone()
	# THE MOUSE HAS TO COME BACK, AND ONLY ONE PATH EVER GAVE IT BACK.
	#
	# `_show_roster_if_lost()` releases the cursor to let the player read who
	# died, and nothing on the zone-entry path recaptured it: `_brief_zone()`'s
	# only `_capture_mouse(true)` is gated on `briefing.show_once()`, which
	# returns false for every leg after the first. So from leg 2 onward, **every
	# flight that lost a goose handed the next zone a dead camera** —
	# `goose_camera.gd` discards all mouse motion while the cursor is visible, and
	# the player gets it back only by happening to left-click the window.
	#
	# Fixed here rather than in `_show_roster_if_lost()`, which is also awaited
	# from `_show_results()` where the free cursor is correct. `_menus_open()`
	# guards the case where the player opened something during the briefing.
	if not _menus_open():
		_capture_mouse(_mouse_was_captured)
	# Guarded because the await can outlive the HUD — a restart, or the player
	# quitting from the briefing card, frees it while this coroutine is parked.
	if hud and is_instance_valid(hud) and hud.has_method("toast"):
		hud.toast(title, Color(0.95, 0.9, 0.5), 2.2)


func _load_migration() -> void:
	Engine.time_scale = 1.0
	# _clear() deliberately happens AFTER the results card, so the frozen zone
	# is still visible behind it instead of the card floating over a void.
	var leg_result: Dictionary = Mission.end_leg()
	await _show_results(leg_result)
	_clear()

	var mig = preload("res://scripts/migration/migration.gd").new()
	mig.name = "Migration"
	_migration_done = false
	mig.finished.connect(_on_migration_done)
	add_child(mig)
	current = mig

	# The flight has a COMPLETELY different control scheme from the zone, and
	# it used to start the instant the zone clock expired with no warning. That
	# is the single most-cited beginner mistake in the book and it was in here.
	await _brief_flight()


# ---------------------------------------------------------------- briefings

## The only moment of reflection in the whole loop. It states the consequence
## explicitly — the clock you get next leg, and why — because otherwise the
## entire objective-gating system is invisible to the player.
func _show_results(leg_result: Dictionary) -> void:
	if results == null or not is_instance_valid(results):
		return
	_set_hud_visible(false)
	_capture_mouse(false)
	var title := _title_for(current, Flock.leg)
	results.show_result(leg_result, title)
	await results.continued
	# A loss should never be something the player has to go looking for. Normally
	# this fires at the end of the flight that caused it (see
	# _on_migration_done); this is the backstop for a loss authored anywhere
	# else, and it lands after the grade rather than over it so the two beats
	# don't fight.
	await _show_roster_if_lost()


## Both briefings pause the tree, but Game is PROCESS_MODE_ALWAYS so its clock
## drains straight through `paused` — hence the explicit zone_running hold.
func _brief_zone() -> void:
	if briefing == null or not is_instance_valid(briefing):
		return
	var was_running := Game.zone_running
	Game.zone_running = false
	var shown: bool = briefing.show_once(&"zone_first_run", BRIEF_DEFS.zone_first_run())
	if shown:
		_capture_mouse(false)
		await briefing.dismissed
		_capture_mouse(true)
	Game.zone_running = was_running


func _brief_flight() -> void:
	if briefing == null or not is_instance_valid(briefing):
		return
	_capture_mouse(false)
	var shown: bool = briefing.show_once(&"flight_first_run", BRIEF_DEFS.flight_first_run())
	if not shown:
		# Every subsequent migration gets the short recap, which auto-dismisses
		# so it's a reminder rather than an obstacle course by leg five.
		briefing.show_now(BRIEF_DEFS.flight_recap())
		shown = true
	if shown:
		await briefing.dismissed
	_capture_mouse(true)


# ---------------------------------------------------------------- mission

func _on_chaos_scored(_amount: int, total: int, _combo: int, _label: String) -> void:
	# Mission listens to Game.chaos_scored itself; the director only tracks the
	# high score here.
	var prefs := get_node_or_null("/root/Prefs")
	if prefs:
		var best: int = int(prefs.get_pref(&"best_chaos", 0))
		if total > best:
			prefs.set_pref(&"best_chaos", total)


func _on_leg_decided(result: Dictionary) -> void:
	if hud and is_instance_valid(hud) and hud.has_method("toast"):
		var grade: String = str(result.get("grade", "?"))
		var passed: bool = bool(result.get("passed", false))
		hud.toast("LEG %s — %s" % [grade, "CLEARED" if passed else "SCRAPED THROUGH"],
			Color(0.6, 0.95, 0.6) if passed else Color(0.98, 0.72, 0.35), 3.0)


## Somebody didn't make it. Recorded rather than shown immediately: the flight
## is still running when this fires, and a menu over a live formation is worse
## than a menu ten seconds later.
func _on_bird_lost(_index: int, bird_name: String) -> void:
	_unseen_losses.append(bird_name)


## Show the roster if the flock has lost anyone the player hasn't been shown.
## Drains the list, so a loss is announced exactly once no matter which of the
## two call sites gets there first.
func _show_roster_if_lost() -> void:
	if _unseen_losses.is_empty():
		return
	if roster == null or not is_instance_valid(roster):
		_unseen_losses.clear()
		return
	var names := _unseen_losses.duplicate()
	_unseen_losses.clear()
	_set_hud_visible(false)
	_capture_mouse(false)
	roster.open(names)
	await roster.closed


func _on_migration_done(dist: float, target: float) -> void:
	if _migration_done:
		return
	_migration_done = true

	# BEFORE Flock.rest(), and before the leg counter moves: the roster should
	# show the flock in the state the flight left it, not the state the next
	# leg's heal is about to paper over.
	await _show_roster_if_lost()

	var made_it := dist >= target * 0.999
	if made_it:
		Flock.leg += 1

	# THE END OF THE RUN. Everything above this line is a leg; this is the
	# journey finishing, which the game could not previously do at all.
	if Flock.leg > FINAL_LEG:
		_finish_run()
		return

	Flock.rest()

	# Two independent modifiers stack: landing short costs you clock, and so
	# does a weak leg. Soft fail on both — never a death, only a worse start.
	# zone_time_modifier is a value in SECONDS, not a multiplier. Treating it
	# as one made the results screen promise 2:20 and the game hand out 1:48.
	# The ROUTE sets each leg's clock — a tutorial pond needs longer than a
	# truck stop. Landing short still costs a minute, and the mission modifier
	# still applies on top.
	#
	# The clamp lives in `Mission.clamp_zone_seconds()` and NOWHERE ELSE. It was
	# written out by hand here once, drifted to a different range from the one
	# the results screen used, and the card spent a whole build promising a
	# number the game would not honour. There is now exactly one function that
	# decides how long a zone can be, and both the promise and the payment call
	# it.
	var base: float = leg_seconds(Flock.leg)
	if not made_it:
		base -= 60.0
	var res: Dictionary = Mission.last_result() if Mission.has_method("last_result") else {}
	var modifier: float = float(res.get("zone_time_modifier", 0.0))
	Game.start_zone(Mission.clamp_zone_seconds(base + modifier))


## Arrival — the 18th green. This used to print a line and show a toast, which
## is a poor thing to hand someone after forty-five minutes and six dead geese.
##
## The finale zone owns the whole ending itself: it kills the clock, hides every
## piece of interface, lands the surviving flock beside you by name, and rolls
## the credits as knockable slabs up the fairway. It is a zone, not a card, so
## the run ends inside the game rather than on top of it.
##
## Note what is deliberately NOT here:
## - No `Game.set_phase(Phase.RESULTS)`. RESULTS leaves Music's migration
##   watchdog armed, which drags the flight cue back over the ending twelve
##   seconds in. The zone stops the clock on its own.
## - No `Game.new_run()`. The player decides when the run is over; the finale
##   exits through the pause menu like anything else.
## See docs/FINALE_NOTES.md.
func _finish_run() -> void:
	Engine.time_scale = 1.0
	var survivors := Flock.alive_birds()
	var names: Array[String] = []
	for b in survivors:
		names.append(str(b.name))
	print("[run] COMPLETE — chaos=", Game.chaos, " survivors=", names)
	preload("res://scripts/world/zone_finale.gd").install(self)


# ---------------------------------------------------------------- input

## The pause menu opens itself on ui_cancel, so the director can't be told
## about it by a signal — poll instead. One boolean compare per frame.
##
## ON THE TREE'S CLOCK, NOT THIS NODE'S. This was `_process()`, and `main`
## inherits PAUSABLE — while every menu in the game pauses the tree. So the poll
## stopped on the very frame a menu opened and never once saw one open: the HUD
## it exists to hide stayed drawn behind the pause menu and behind every card,
## the first of them over a placeholder "3:00" on a 4:00 leg because the HUD's
## own `_process` had not run yet either. D-050's pause menu in a new place — a
## `process_mode` silently switching off the code meant to react to a pause.
## `SceneTree.process_frame` is emitted every frame, paused or not. D-060.
func _poll_menus() -> void:
	var open := _menus_open()
	if open != _hud_hidden:
		_hud_hidden = open
		_set_hud_visible(not open)
		if open:
			_capture_mouse(false)
	_tick_restart_prompt()


func _unhandled_input(e: InputEvent) -> void:
	# Clicking the window re-grabs the mouse after a menu or an alt-tab.
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not _menus_open():
			_capture_mouse(true)
			return

	if e.is_action_pressed("gg_restart") and not _menus_open():
		# TWO PRESSES. This used to throw away the whole run on one unconfirmed
		# tap of a key that sits one row above the movement hand, back when a run
		# was an endless rotation and losing it cost nothing. A run is now eight
		# legs and about forty-five minutes.
		var now := Time.get_ticks_msec()
		if now - _restart_armed_ms <= RESTART_CONFIRM_MS:
			_restart_armed_ms = -1_000_000
			_tick_restart_prompt()
			Engine.time_scale = 1.0
			_unseen_losses.clear()
			Game.new_run(leg_seconds(1))
			return
		_restart_armed_ms = now
		_tick_restart_prompt()
		var sfx := get_node_or_null("/root/Sfx")
		if sfx:
			sfx.play(&"score_blip", -14.0, 0.7)


## Probe helper: how much interface is on screen. The finale's whole claim is
## that it takes the HUD away, and "I looked at the screenshot" is a weaker
## check than counting the layers.
func _visible_layer_count() -> int:
	var n := 0
	for c in get_children():
		if c is CanvasLayer and (c as CanvasLayer).visible:
			n += 1
	return n


func _menus_open() -> bool:
	for m in [briefing, control_card, pause_menu, almanac, results, roster]:
		if m and is_instance_valid(m) and m.has_method("is_open"):
			if m.is_open():
				return true
	return false


# ------------------------------------------------------- the restart prompt
#
# Drawn rather than assembled out of containers: it is one plate with two lines
# and a draining bar, it has to sit at a fixed spot relative to the viewport,
# and a single full-rect Control that paints itself has no anchoring to get
# wrong. Same reasoning as the results card.

func _build_restart_prompt() -> CanvasLayer:
	var cl := CanvasLayer.new()
	# ALWAYS: the window can be armed while a substance has the world in slow
	# motion, and it must expire on a wall clock either way.
	cl.process_mode = Node.PROCESS_MODE_ALWAYS
	var ctl := RestartPrompt.new()
	ctl.name = "Prompt"
	ctl.set_anchors_preset(Control.PRESET_FULL_RECT)
	ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(ctl)
	_restart_prompt_ctl = ctl
	cl.visible = false
	return cl


func _tick_restart_prompt() -> void:
	if restart_prompt == null or not is_instance_valid(restart_prompt):
		return
	var left := float(RESTART_CONFIRM_MS - (Time.get_ticks_msec() - _restart_armed_ms))
	var frac: float = clampf(left / float(RESTART_CONFIRM_MS), 0.0, 1.0)
	var want := frac > 0.0
	if want != restart_prompt.visible:
		restart_prompt.visible = want
	if not want:
		return
	if _restart_prompt_ctl != null and is_instance_valid(_restart_prompt_ctl):
		_restart_prompt_ctl.frac = frac
		_restart_prompt_ctl.queue_redraw()


class RestartPrompt extends Control:
	const BOX := Vector2(560.0, 84.0)
	const UP_FROM_BOTTOM := 108.0

	var frac := 0.0
	var _plate: StyleBoxFlat = null

	func _ready() -> void:
		_plate = StyleBoxFlat.new()
		_plate.bg_color = Color(0.06, 0.035, 0.045, 0.96)
		_plate.set_corner_radius_all(12)
		_plate.border_width_left = 5
		_plate.border_color = Color(0.96, 0.40, 0.36)
		_plate.shadow_color = Color(0, 0, 0, 0.6)
		_plate.shadow_size = 18

	func _draw() -> void:
		if frac <= 0.0 or _plate == null:
			return
		var f := ThemeDB.fallback_font
		var vs := size
		var r := Rect2(Vector2(((vs.x - BOX.x) * 0.5), vs.y - UP_FROM_BOTTOM - BOX.y), BOX)
		draw_style_box(_plate, r)

		var col := Color(1.0, 0.80, 0.76)
		f.draw_string_outline(get_canvas_item(), Vector2(r.position.x + 20.0,
			r.position.y + 16.0 + f.get_ascent(21)), "PRESS  R  AGAIN TO RESTART THE RUN",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 21, 5, Color(0, 0, 0, 0.85))
		f.draw_string(get_canvas_item(), Vector2(r.position.x + 20.0,
			r.position.y + 16.0 + f.get_ascent(21)), "PRESS  R  AGAIN TO RESTART THE RUN",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 21, col)

		var sub := "this throws away the whole flyway and starts again at the pond"
		f.draw_string_outline(get_canvas_item(), Vector2(r.position.x + 20.0,
			r.position.y + 44.0 + f.get_ascent(13)), sub,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0, 0, 0, 0.85))
		f.draw_string(get_canvas_item(), Vector2(r.position.x + 20.0,
			r.position.y + 44.0 + f.get_ascent(13)), sub,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.72, 0.70, 0.76))

		# The window, draining. It is the only thing on screen that says the
		# offer expires.
		var bx := r.position.x + 20.0
		var bw := r.size.x - 40.0
		var by := r.position.y + r.size.y - 15.0
		draw_rect(Rect2(bx, by, bw, 4.0), Color(1, 1, 1, 0.12), true)
		draw_rect(Rect2(bx, by, bw * frac, 4.0), Color(0.96, 0.40, 0.36, 0.95), true)


# ---------------------------------------------------------------- dev probe

## Where render probes write their PNGs. `--out:<dir>` overrides it.
##
## This used to be the bare literal "/tmp" at twelve call sites. `/tmp` does not
## exist on Windows, `Image.save_png()` RETURNS an error rather than raising one,
## and every call site then printed `[probe] wrote /tmp/gg_x.png` unconditionally
## — so on Windows the project's entire visual verification loop reported success
## while writing nothing at all. That is the same failure mode as the dead
## compile gate: a check that cannot fail. `_save_shot()` checks the return.
var _shot_dir := ""
## Non-zero exit code if any shot failed to write, so a probe that produced no
## images cannot be mistaken for one that did.
var _shot_failures := 0


func _default_shot_dir() -> String:
	if OS.has_feature("windows"):
		# Absolute, so the path printed to stdout can be opened by anything.
		return OS.get_user_data_dir().replace("\\", "/") + "/shots"
	return "/tmp"


## Save a probe shot. Returns true on success. NEVER claims a write it did not do.
func _save_shot(img: Image, base: String) -> bool:
	if _shot_dir == "":
		_shot_dir = _default_shot_dir()
	if not DirAccess.dir_exists_absolute(_shot_dir):
		var mk := DirAccess.make_dir_recursive_absolute(_shot_dir)
		if mk != OK:
			_shot_failures += 1
			printerr("[probe] FAILED to create shot dir %s (err %d)" % [_shot_dir, mk])
			return false
	var path := "%s/%s" % [_shot_dir, base]
	var err := img.save_png(path)
	if err != OK:
		_shot_failures += 1
		printerr("[probe] FAILED to write %s (err %d)" % [path, err])
		return false
	print("[probe] wrote %s" % path)
	return true


## Install the ending, put one credit slab on the fairway, and measure how fast
## it actually travels. Exits 1 if the roll is crawling.
func _roll_test() -> void:
	Flock.leg = FINAL_LEG
	_finish_run()
	for _i in 20:
		await get_tree().physics_frame
	if current == null or not is_instance_valid(current) or not current.has_method("_spawn_credit"):
		printerr("[roll] FAIL — the finale did not install")
		get_tree().quit(1)
		return

	var before := current.get_child_count()
	current._spawn_credit("MEASUREMENT SLAB")
	var slab: Node3D = null
	for i in range(current.get_child_count() - 1, before - 1, -1):
		var c := current.get_child(i)
		if c is RigidBody3D:
			slab = c as Node3D
			break
	if slab == null:
		printerr("[roll] FAIL — no slab was spawned")
		get_tree().quit(1)
		return

	# Let it settle onto the grass before timing, so the sample is cruise speed
	# and not the first tick off the spawn.
	for _i in 30:
		await get_tree().physics_frame
	var z0: float = slab.global_position.z
	var ticks := 120
	for _i in ticks:
		await get_tree().physics_frame
		if not is_instance_valid(slab):
			break
	if not is_instance_valid(slab):
		print("[roll] slab despawned during the sample — it was moving")
		get_tree().quit(0)
		return

	var secs: float = float(ticks) / float(ProjectSettings.get_setting("physics/common/physics_ticks_per_second", 60))
	var measured: float = (slab.global_position.z - z0) / maxf(secs, 0.001)
	var want: float = float(current.get_script().get_script_constant_map().get("CREDIT_SPEED", 2.15))
	print("[roll] measured %.2f m/s over %.2f s (CREDIT_SPEED = %.2f)" % [measured, secs, want])
	# 70% of cruise is a generous floor: it passes a slab that is merely a bit
	# draggy and fails every version of the bug this exists for, all of which
	# landed between 0.3 and 0.6 m/s — under 30%.
	if measured < want * 0.70:
		printerr("[roll] FAIL — the roll is crawling at %.0f%% of CREDIT_SPEED. The ending takes minutes to say anything." % (100.0 * measured / maxf(want, 0.001)))
		get_tree().quit(1)
		return
	print("[roll] PASS — the credit roll travels")
	get_tree().quit(0)


## Point the probe at something that is not the goose.
##
## The chase camera starts behind the bird and faces where the bird faces, which
## is correct for the game and useless for photographing an encounter: the
## Ranger's truck arrives at the mouth of the cul-de-sac, which is BEHIND the
## goose, so `--probe --leg:3 --boss` produced a picture of an empty street with
## the entire encounter off-camera. Two builds of a boss were verified by
## inference because of it.
##
## This spawns a throwaway Camera3D on the goose→target line, pushed back past
## the goose so BOTH are in frame, and makes it current. It does not touch the
## rig — `goose_camera.gd` owns `_yaw` and rewrites it every frame, so borrowing
## the rig would fight the rig.
##
## Returns the node it found, or null.
func _look_at_named(want: String) -> Node3D:
	if current == null or not is_instance_valid(current):
		return null
	var target := _find_node_named(current, want)
	if target == null:
		printerr("[probe] --look:%s found no such node in the zone" % want)
		return null

	var goose_pos := target.global_position + Vector3(0, 0, 8)
	var g = current.get("goose")
	if g != null and is_instance_valid(g):
		goose_pos = (g as Node3D).global_position

	var mid := (goose_pos + target.global_position) * 0.5
	var span := goose_pos.distance_to(target.global_position)
	# Back off along the goose→target line, far enough that the pair fits.
	var away := (goose_pos - target.global_position)
	away.y = 0.0
	if away.length() < 0.1:
		away = Vector3(0, 0, 1)
	away = away.normalized()

	var cam := Camera3D.new()
	cam.name = "ProbeCam"
	cam.fov = 70.0
	current.add_child(cam)
	cam.global_position = mid + away * (span * 0.75 + 7.0) + Vector3.UP * (span * 0.28 + 3.2)
	cam.look_at(mid + Vector3.UP * 0.8, Vector3.UP)
	cam.current = true
	print("[probe] looking at %s (span %.1f m)" % [target.name, span])
	return target


func _find_node_named(root: Node, want: String) -> Node3D:
	for c in root.get_children():
		if c is Node3D and String(c.name).findn(want) >= 0:
			return c as Node3D
		var deeper := _find_node_named(c, want)
		if deeper != null:
			return deeper
	return null


## Wait between probe shots: seconds when `--secs:` was given, frames otherwise.
##
## `ignore_time_scale = true` because an `--fx` probe deliberately parks
## `Engine.time_scale` at 0.3 for a slow-motion substance, and a wall-clock wait
## must not be slowed down with the game it is photographing.
func _settle(n_frames: int, n_secs: float) -> void:
	if n_secs > 0.0:
		await get_tree().create_timer(n_secs, true, false, true).timeout
		return
	for _i in n_frames:
		await get_tree().process_frame


## Every probe path exits through here so the failure count reaches the shell.
func _probe_quit() -> void:
	if _shot_failures > 0:
		printerr("[probe] %d shot(s) failed to write" % _shot_failures)
		get_tree().quit(1)
		return
	get_tree().quit()


## Offscreen render probe — lets the build be verified without a human.
## godot --path . --rendering-driver opengl3 -- --probe [--migration|--fx|--ui]
##        [--sub:<id>] [--leg:N] [--close] [--shots:N] [--frames:N] [--out:<dir>]
## A HEADLESS RUN MUST NEVER OUTLIVE ITS JOB.
##
## Every tool branch below is `preload("res://tools/x.gd").run(...)` and the quit
## lives inside the tool. So when a tool fails to COMPILE — one Variant-inference
## typo is enough, and that is the single most common error in this codebase —
## the preload yields a broken GDScript, the call raises `Invalid call.
## Nonexistent function 'run'`, the branch never reaches a quit, and the engine
## falls through into an ordinary main loop with no window and no vsync.
##
## That is not a hypothetical. On 2026-08-17 a `--selftest` run did exactly this
## and ran for EIGHTEEN HOURS at 100% of a core — invisible, doing nothing, and
## holding open the shell that launched it, which in turn blocked its launcher
## from updating and could only be cleared with a reboot. The parse error was
## fixed in four minutes; the process outlived it by a day.
##
## So: arm a wall-clock deadline before dispatching anything. If the tool exits
## normally the process is gone long before this fires and the timer dies with
## it. If anything at all goes wrong — a failed compile, an exception, a genuine
## infinite loop in a tool — the run ends loudly with a non-zero code instead of
## becoming a permanent resident.
##
## `ignore_time_scale` is on because a substance probe parks `Engine.time_scale`
## at 0.3 and a deadline measured in game seconds is not a deadline.
func _arm_failsafe(secs: float, what: String) -> void:
	var t := get_tree().create_timer(secs, true, false, true)
	t.timeout.connect(func() -> void:
		printerr("[failsafe] %s has not exited after %.0f s. Quitting rather than " % [what, secs]
			+ "becoming an invisible process that outlives the shell that started it.")
		get_tree().quit(2))


## Two budgets, because a compile gate that takes 30 s and a software-rendered
## finale probe that takes 160 s are not the same job. `--failsafe:N` overrides
## both, and exists so the deadline itself can be tested without waiting four
## minutes for it.
##
## Called from the TOP of `_ready()`. `tool_flags` is also what
## `tools/doctest.gd` parses to check that every gate this dispatches is one
## `verify.ps1` runs, so it stays a plain literal array.
func _arm_headless_deadline() -> void:
	var args := OS.get_cmdline_user_args()
	var tool_flags := ["--gate", "--selftest", "--inputtest", "--rolltest", "--feeltest",
		"--substancetest", "--migtest", "--doctest", "--audiotest", "--geomtest"]
	var is_tool := false
	for f in tool_flags:
		if args.has(f):
			is_tool = true
			break
	if not (is_tool or args.has("--probe")):
		return
	var budget: float = 240.0 if is_tool else 900.0
	for a in args:
		if a.begins_with("--failsafe:"):
			budget = float(a.substr(11))
	if budget > 0.0:
		_arm_failsafe(budget, "this headless run")

func _probe_if_headless() -> void:
	var args := OS.get_cmdline_user_args()

	# EVERY HARNESS STARTS FROM A CLEAR SCREEN, NOT FROM WHATEVER THIS MACHINE'S
	# SAVE SAYS. A run with arguments is hermetic (`prefs.gd::hermetic`), so it
	# boots as a first-time player does: with the first-run briefing up and the
	# tree paused behind it. Before that change, the controller gate passed only
	# because the save on the machine that ran it said the card had been seen —
	# made hermetic, it failed 8 of 36 on "holding forward moved the goose 0.00 m",
	# which is also exactly what its first run on any fresh checkout did. The
	# `--probe` branch below always silenced the card; the tool branches above it
	# never did, because on this machine they had never needed to.
	#
	# Closing it here marks it seen in memory only, so a harness that wants to
	# see a first-run card still gets the flight's, at the first migration.
	if not args.is_empty() and briefing and briefing.has_method("force_close"):
		briefing.force_close()
		# And the contextual hint, which a harness would otherwise meet the first
		# time any measurement put the bird within 1.6 m of a pickup — mid-run,
		# tree paused, every number after it zero. `inputtest` un-sees it on
		# purpose to drive it (D-059).
		if briefing.has_method("mark_seen"):
			briefing.mark_seen(&"dose_hint")


	# THE COMPILE GATE. Has to run from inside the booted project, because that
	# is the only context where the autoload singletons are registered and
	# `Identifier not found: Subs` is a real error rather than an artefact of
	# parsing a file in isolation. `--import` never compiled GDScript at all and
	# `--check-only` false-fails on most of the project; see tools/gate.gd.
	if args.has("--gate"):
		preload("res://tools/gate.gd").run(get_tree(), args.has("--gate-verbose"))
		return

	# THE SECOND GATE. The first one proves every file compiles; this one proves
	# the game agrees with itself — that the route, the two clocks, the titles,
	# the substance data and the objective sets all say the same thing. Every
	# assertion in it is a bug that already got through once. See tools/selftest.gd.
	if args.has("--selftest"):
		# AWAITED. `run()` became a coroutine when `_the_time_scale()` stopped
		# reading the clock on the statement after the reset that sets it — the
		# only form of that check which can see a third writer is one that lets
		# the tree run for a few frames first.
		await preload("res://tools/selftest.gd").run(get_tree(), self)
		return

	# THE NINTH GATE, and the only one pointed at the DOCUMENTS rather than at
	# the game. Every number a doc writes down is recomputed from the booted
	# project and compared; every feel window feeltest.gd enforces is compared
	# against the argument FEEL_TARGETS.md makes for it. A survey found seven
	# live stale facts across four root documents on the day it was written.
	# See tools/doctest.gd and docs/CLAIMS.md.
	if args.has("--doctest"):
		preload("res://tools/doctest.gd").run(get_tree(), self)
		return

	# THE TENTH GATE, and the only one that opens the WAVs. `selftest` proves a
	# file exists for every key the code asks for; the bug that got past that is
	# in the record -- the truck stop's "rain" was a 0.700 s goose hiss that
	# never looped. This checks that a bed loops, that a one-shot is short, that
	# nothing is silent or clipping, and that the layered stems share a length.
	# It cannot tell you anything SOUNDS good and says so. See tools/audiotest.gd.
	if args.has("--audiotest"):
		preload("res://tools/audiotest.gd").run(get_tree(), self)
		return

	# THE ELEVENTH GATE. `prop_models*.gd::build()` sizes every model with
	# `want / footprint(kind)`, so a declared box that disagrees with the mesh
	# makes every `size:` placement of that kind wrong by exactly that ratio, in
	# every zone that asks for one. Nothing had ever compared the two. This walks
	# the BUILT zones rather than constructing kinds from an empty params dict,
	# which is the wall the previous attempt hit. See tools/geomtest.gd.
	if args.has("--geomtest"):
		await preload("res://tools/geomtest.gd").run(get_tree(), self)
		return

	# A REPORT, NOT A GATE, and deliberately not in `tool_flags` or verify.ps1.
	# It gives docs/DECISIONS.md D-006 — the glide ratio, Open (human) — the cost
	# nobody had counted: how many surfaces in every built zone become reachable
	# by glide alone if the ratio widens. It asserts nothing, because the
	# decision is taste and an agent must not close it. See tools/glidetest.gd.
	if args.has("--glidetest"):
		await preload("res://tools/glidetest.gd").run(get_tree(), self)
		return

	# A REPORT, NOT A GATE, same arrangement as --glidetest. How findable each
	# leg's pickups are from where the goose starts: distance, height, and
	# whether the opening camera can see them. The human's "all I can find is
	# grass" on leg 1, given its numbers. See tools/findtest.gd.
	if args.has("--findtest"):
		await preload("res://tools/findtest.gd").run(get_tree(), self)
		return

	# THE THIRD GATE, and the only one that presses a key. Holds W, flaps, honks,
	# and doses, then asserts the bird actually did something. It exists because
	# an input-lag bug that made eleven of the sixteen substances unplayable got
	# past a compile gate, an invariant harness and a full campaign run — none of
	# which had ever touched an input. See tools/inputtest.gd.
	if args.has("--inputtest"):
		await preload("res://tools/inputtest.gd").run(get_tree(), self)
		return

	# THE SIXTH GATE, and the first one with an OPINION. inputtest proves the
	# bird MOVES; its own header says its thresholds are there to catch "broken,
	# never not tuned", and that judging feel "is the human's job". That sentence
	# is why this project's handoff has opened with "Play it" at the top of the
	# list two sessions running.
	#
	# feeltest measures the half of feel that is a NUMBER — time to top speed,
	# stop distance, whether held flap converges on a climb rate — against
	# windows that each cite something this project already wrote down. The taste
	# half (is a waddling goose funny) stays the human's, permanently. See
	# tools/feeltest.gd and docs/FEEL_TARGETS.md.
	if args.has("--feeltest"):
		await preload("res://tools/feeltest.gd").run(get_tree(), self)
		return

	# THE SEVENTH GATE, and the one that checks the design rule the whole game
	# is built on: "a substance must never be only a number that goes up".
	# selftest.gd already enforces that by READING THE .tres. This doses each
	# substance and measures the bird, because the input-lag bug proved the two
	# can disagree for a whole project's lifetime — eleven of sixteen substances
	# unplayable with every .tres correct. See tools/substancetest.gd.
	if args.has("--substancetest"):
		await preload("res://tools/substancetest.gd").run(get_tree(), self)
		return

	# THE EIGHTH GATE, and the first thing ever to measure the FLIGHT. Half this
	# game is migrations -- seven of them -- and until this file the only thing
	# any check knew about one was that the campaign loop reached COMPLETE. That
	# proves the flight ends; it says nothing about whether the bird answers the
	# stick while it is happening. See tools/migtest.gd.
	if args.has("--migtest"):
		await preload("res://tools/migtest.gd").run(get_tree(), self)
		return

	# THE CREDIT ROLL, MEASURED. Headless, because physics runs headless and the
	# thing that has been wrong twice is a SPEED, not a picture.
	#
	# The roll's drive has now had three implementations: an 8 m/s² ramp that
	# lost to friction, a 24 m/s² ramp that also lost to friction because the
	# ramp was never the problem, and a `_integrate_forces()` write that is the
	# correct API for a RigidBody3D. Each time, the symptom took four to six
	# minutes of real play to notice, which is why nobody noticed.
	if args.has("--rolltest"):
		await _roll_test()
		return

	if not args.has("--probe"):
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Briefing cards would block every probe behind a modal, so silence them.
	if briefing and briefing.has_method("force_close"):
		briefing.force_close()
	set_meta("probe", true)

	var migration_probe := args.has("--migration")
	var fx_probe := args.has("--fx")
	var shots_wanted := 3
	var frames := 22
	## Seconds between shots, as an alternative to `--frames`. THIS is the one to
	## use for anything that happens on a game timer.
	##
	## `--frames:N` counts frames, and every documented probe command in
	## docs/HANDOFF.md was calibrated against a container rendering this project
	## in software at roughly 2 fps — where 26 frames is thirteen seconds. On a
	## machine with a GPU the same command is four tenths of a second, so
	## `--probe --leg:3 --boss` photographed an empty cul-de-sac three seconds
	## before the Ranger's truck arrives and looked exactly like a boss that had
	## failed to spawn.
	var secs := 0.0
	## `--look:<NodeName>` — frame something other than the goose. `--boss`
	## implies it, because a boss you cannot photograph is a boss nobody has seen.
	var look_at := ""
	## `--goto:x,y,z`. Vector3.INF means "leave the goose where the zone put it".
	var goto_at := Vector3.INF
	var forced := ""
	for a in args:
		if a.begins_with("--out:"):
			_shot_dir = a.substr(6).replace("\\", "/").rstrip("/")
		elif a.begins_with("--sub:"):
			forced = a.substr(6)
		elif a.begins_with("--shots:"):
			shots_wanted = int(a.substr(8))
		elif a.begins_with("--frames:"):
			frames = int(a.substr(9))
		elif a.begins_with("--secs:"):
			secs = float(a.substr(7))
		elif a.begins_with("--look:"):
			look_at = a.substr(7)
		elif a.begins_with("--goto:"):
			# `--goto:x,y,z` — put the goose somewhere. A zone is 80 m across and
			# the interesting half of leg 7 is now 40 m off the south edge of it;
			# without this the only way to photograph the inside of a building is
			# to play there.
			var parts := a.substr(7).split(",")
			if parts.size() == 3:
				goto_at = Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
		elif a.begins_with("--leg:"):
			Flock.leg = maxi(1, int(a.substr(6)))
			# THE LEG'S OWN CLOCK, not a hardcoded 180.
			#
			# Every `--leg:N` probe ran on 180 s regardless, so the two legs whose
			# clocks are not 180 have never been photographed as they ship: the
			# retention pond is 240 and the Stopover is 150. That matters beyond
			# the number on the HUD — anything in a zone that schedules itself
			# against the clock (the truck stop's rig departures, BIG DOWN's dock
			# opening) was being photographed on the wrong timetable.
			Game.start_zone(leg_seconds(Flock.leg))
			# start_zone() alone is not enough: if the first-run briefing is
			# still parked on its await, `zone_running` stays false and every
			# time-delayed system in the zone silently never ticks. Under the
			# probe there is no human to dismiss the card, so force it.
			Game.zone_running = true

	# --loop-test drives a whole leg on a short clock and prints every phase
	# transition, so the zone -> results -> briefing -> migration chain can be
	# verified without a human sitting through three minutes.
	if args.has("--loop-test"):
		print("[loop] start phase=", Game.phase, " leg=", Flock.leg)
		Game.phase_changed.connect(func(p: int): print("[loop] phase -> ", p, " at t=", Time.get_ticks_msec()))
		Mission.leg_decided.connect(func(r: Dictionary):
			print("[loop] leg decided: passed=", r.get("passed"), " grade=", r.get("grade"),
				" next=", r.get("zone_time_modifier")))
		if briefing and briefing.has_method("force_close"):
			briefing.force_close()
		Game.zone_time_left = 2.0
		var ticks := 0
		var last_leg := 0
		# THE SHELF CENSUS. leg -> how many distinct substances that leg's zone
		# actually spawned, counted off the node tree of the zone THE DIRECTOR
		# BUILT rather than off any table.
		#
		# `zone_strip_mall.gd` serves legs 1 and 2 from one file and used to
		# build all sixteen substances on both, so the campaign's first
		# escalation — CAMPAIGN_SPEC §2.1's three against §2.2's "all sixteen,
		# this is where the lid comes off" — did not exist. `selftest.gd`
		# checks the declaration; nothing could check the build, because the
		# only place a zone is built by the game itself is right here.
		#
		# Keyed on the zone INSTANCE, not on the leg: landing short replays a
		# leg, and a census that re-counted the same leg would silently
		# overwrite the first reading with the second.
		var shelf_census := {}
		var pond_wet := {}
		var censused_ids := {}
		while ticks < 4200:
			ticks += 1
			if Flock.leg != last_leg:
				last_leg = Flock.leg
				print("[loop] leg ", Flock.leg, " geese=", Flock.alive_birds().size())
			if current and is_instance_valid(current) and current.has_method("mission_zone_id"):
				var cid := current.get_instance_id()
				if not censused_ids.has(cid):
					censused_ids[cid] = true
					var seen := {}
					for ch in current.get_children():
						# `.get()` on a node without the property returns null,
						# which is the cheapest way to ask "is this a pickup"
						# without a class_name reference. Walks children rather
						# than a group, because a source that forgot to join
						# the group is exactly what this is looking for.
						var sres = ch.get("substance")
						if sres != null:
							seen[sres.get("id")] = true
					shelf_census[Flock.leg] = seen.size()
					# AND NOTHING THAT BELONGS ON THE LAWN MAY BE IN THE POND.
					#
					# Leg 1's nine lawn signs were sampled uniformly over a
					# rectangle 27.1% of whose area is inside the 11 m water
					# cylinder — about 2.4 signs standing in the pond on an
					# average run, in the first zone the player ever sees.
					# Rejection sampling fixes it; this is what proves it, on
					# the zone the director built, with the pond geometry read
					# off the same constants the builder obeys.
					var zconsts: Dictionary = current.get_script().get_script_constant_map()
					if zconsts.has("POND_CENTRE") and zconsts.has("POND_RADIUS"):
						var pc: Vector3 = zconsts["POND_CENTRE"]
						var pr: float = float(zconsts["POND_RADIUS"])
						var wet := 0
						for pn in current.get_children():
							if str(pn.get("label")) != "LAWN SIGN":
								continue
							var xz := Vector2(pn.global_position.x - pc.x,
								pn.global_position.z - pc.z)
							if xz.length() < pr:
								wet += 1
						if wet > 0:
							pond_wet[Flock.leg] = wet
			if ticks % 400 == 0:
				print("[loop] t=", ticks, " phase=", Game.phase, " current=",
					current.name if (current and is_instance_valid(current)) else "<none>",
					" brief=", briefing.is_open(), " res=", results.is_open(),
					" roster=", roster.is_open(), " paused=", get_tree().paused)
			if Game.zone_running and Game.zone_time_left > 2.0:
				Game.zone_time_left = 2.0
			# The flight has to be compressed the same way the zone clock is.
			# `distance` accrues off `delta`, and headless with no vsync runs at
			# a delta of about a millisecond, so 4200 frames buy roughly four
			# seconds of flight out of the seventy-five a crossing takes. This
			# harness used to stop at leg 1 and report it as the route ending
			# there — a false failure that looked exactly like a real one.
			if current and is_instance_valid(current) and current.has_method("_finish"):
				if bool(current.get("over")):
					# The flight holds on its results card until gg_skip. Nothing
					# headless presses a key, so the harness has to.
					# Press AND release, alternating. A synthetic press that is
					# never released leaves the action held, and
					# `is_action_just_pressed` only fires on the edge — so a
					# press-only harness dismisses exactly one flight and then
					# hangs on the second, which is precisely how this looked.
					var skip := InputEventAction.new()
					skip.action = "gg_skip"
					skip.pressed = (ticks % 2 == 0)
					Input.parse_input_event(skip)
				else:
					var d: float = float(current.get("distance"))
					var tgt: float = float(current.get("target_distance"))
					current.set("distance", minf(d + tgt * 0.02, tgt))
			await get_tree().process_frame
			if briefing and briefing.has_method("is_open") and briefing.is_open():
				briefing.force_close()
			# The roster opens itself after any flight that cost a bird, and it
			# pauses the tree while it is up. Nothing in a headless loop test can
			# press Escape, so without this the harness stalls on the first
			# casualty and reports it as the run ending early.
			if roster and roster.has_method("is_open") and roster.is_open():
				roster.force_close()
			# `Input.parse_input_event` alone was not enough: headless delivers it,
			# but the results card only listens for it after its reveal timeline
			# has run, and that timeline is driven by a delta this loop never
			# gives it. `_load_migration()` therefore parked forever on
			# `await results.continued` and the whole harness reported the route
			# as ending at leg 1. force_close() emits `continued` directly.
			if results and results.has_method("is_open") and results.is_open():
				if results.has_method("force_close"):
					results.force_close()
				var ev := InputEventAction.new(); ev.action = "ui_accept"; ev.pressed = true
				Input.parse_input_event(ev)
		print("[loop] END phase=", Game.phase, " leg=", Flock.leg, " time_scale=", Engine.time_scale)

		# ── the shelf, as built ─────────────────────────────────────────────
		var census_legs := shelf_census.keys()
		census_legs.sort()
		var census_line := ""
		for cl in census_legs:
			census_line += " leg%d=%d" % [cl, int(shelf_census[cl])]
		print("[loop] shelf census:", census_line)

		var shelf_fails: Array[String] = []
		for wet_leg in pond_wet.keys():
			shelf_fails.append("leg %d built %d LAWN SIGN props inside the retention pond. They are sampled over a rectangle that overlaps the water; the placement has to reject wet points." % [int(wet_leg), int(pond_wet[wet_leg])])
		var full_shelf: int = Subs.library.size()
		var tutorial_size: int = int(load("res://scripts/world/zone_strip_mall.gd")
			.get_script_constant_map().get("TUTORIAL_SHELF", []).size())
		for want_leg in [1, 2]:
			if not shelf_census.has(want_leg):
				shelf_fails.append("leg %d was never censused — the run did not build it, so this gate proved nothing about it" % want_leg)
		if shelf_census.has(1) and int(shelf_census[1]) != tutorial_size:
			shelf_fails.append("leg 1 built %d distinct substances against a TUTORIAL_SHELF of %d. CAMPAIGN_SPEC §2.1 gives the retention pond three." % [int(shelf_census[1]), tutorial_size])
		if shelf_census.has(2) and int(shelf_census[2]) != full_shelf:
			shelf_fails.append("leg 2 built %d distinct substances against a shelf of %d. §2.2 is \"all sixteen — this is where the lid comes off\"." % [int(shelf_census[2]), full_shelf])
		if shelf_census.has(1) and shelf_census.has(2) and int(shelf_census[1]) >= int(shelf_census[2]):
			shelf_fails.append("legs 1 and 2 build the same shelf (%d vs %d). They are the same PLACE on purpose and were the same GAME by accident; that is the bug this census exists for." % [int(shelf_census[1]), int(shelf_census[2])])
		if not shelf_fails.is_empty():
			print("[loop] FAIL — the shelf census:")
			for sf in shelf_fails:
				print("[loop]   ", sf)
			get_tree().quit(1)
			return

		get_tree().quit()
		return

	await get_tree().process_frame

	if migration_probe:
		Flock.dose_flock(0.75)
		if Flock.birds.size() > 1:
			Flock.birds[1].is_dd = true
			Flock.birds[1].intox = 0.0
		Game.set_phase(Game.Phase.MIGRATION)
		await get_tree().process_frame
		if briefing and briefing.has_method("force_close"):
			briefing.force_close()
		# `_load_migration()` awaits the results card BEFORE spawning the flight,
		# so this flag used to photograph the results screen and label it "the
		# flight" — including in the HANDOFF's own list of verification commands.
		# Dismiss the card and wait for the flight to actually exist.
		for _i in 90:
			if results and is_instance_valid(results) and results.has_method("is_open") and results.is_open():
				results.force_close()
			if current and is_instance_valid(current) and current.name.begins_with("Migration"):
				break
			await get_tree().process_frame
		if briefing and briefing.has_method("force_close"):
			briefing.force_close()
		# The flight is paused behind the briefing await until the card closes.
		get_tree().paused = false

	# --finale renders the ending. It is the one phase with no route into it
	# short of playing eight legs, which is exactly why it needs a flag.
	if args.has("--finale"):
		Flock.leg = FINAL_LEG
		# Unlock a plausible run's worth of Almanac entries. The credit roll now
		# ends with what each substance ACTUALLY WAS, one line per thing the
		# player discovered, so a probe with an empty codex photographs an
		# ending that no real player ever sees.
		var un := get_node_or_null("/root/Unlocks")
		if un:
			for uid in [&"berries", &"double_double", &"fly_agaric", &"gravy", &"percs", &"math"]:
				un.unlock(uid)
		if Flock.birds.size() > 3:
			Flock.lose_bird(2, "flew into a wire over Buffalo")
			Flock.scar_bird(1, "clipped a turbine over Erie")
		var t0 := Time.get_ticks_msec()
		_finish_run()
		print("[fin] installed after ", Time.get_ticks_msec() - t0, " ms  current=", current)
		# `--frames:N` sets the gap between the two shots. Software rendering
		# this zone is slow (30 geese, 30 residents, a treeline), so the default
		# is short and you raise it when you want a later beat.
		await _settle(frames, secs)
		await RenderingServer.frame_post_draw
		_save_shot(get_viewport().get_texture().get_image(), "gg_finale_0.png")
		print("[probe] finale shot 0 at t=", Time.get_ticks_msec() - t0, " ms")
		await _settle(frames * 4, secs * 4.0)
		await RenderingServer.frame_post_draw
		_save_shot(get_viewport().get_texture().get_image(), "gg_finale_1.png")
		print("[probe] finale shot 1 at t=", Time.get_ticks_msec() - t0,
			" ms  current=", current, " visible_layers=", _visible_layer_count())
		_probe_quit()
		return

	if args.has("--close") and current:
		var rig = current.get("camera_rig")
		if rig:
			rig.distance = 2.6
			rig.distance_fly = 3.2
			rig.height = 1.15

	if (fx_probe or forced != "") and current:
		var g = current.get("goose")
		if g:
			g.global_position = Vector3(0, 1.5, 6)
		var id := StringName(forced if forced != "" else "berries")
		Subs.take(Subs.get_substance(id), 0.6)

	if args.has("--brief-zone") or args.has("--brief-flight") or args.has("--brief-recap") \
			or args.has("--brief-dose"):
		var data: Dictionary = BRIEF_DEFS.zone_first_run()
		var tag := "brief_zone"
		if args.has("--brief-flight"):
			data = BRIEF_DEFS.flight_first_run()
			tag = "brief_flight"
		elif args.has("--brief-recap"):
			data = BRIEF_DEFS.flight_recap()
			tag = "brief_recap"
		elif args.has("--brief-dose"):
			# Never shown to anyone until D-059 wired it; this is its first render.
			data = BRIEF_DEFS.dose_hint()
			tag = "brief_dose"
		briefing.show_now(data)
		for i in 30:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_save_shot(get_viewport().get_texture().get_image(), "gg_%s.png" % tag)
		_probe_quit()
		return

	# --roster: the flock screen, the armed RESTART button, and the R prompt.
	# Builds a flock that exercises every row state on purpose — a roster of six
	# healthy geese proves nothing, because the states that go wrong are the
	# struck-out one and the one at 88%.
	if args.has("--roster"):
		# The common case first: six geese, nothing wrong with any of them. It is
		# what the player sees most of the time and it is the layout most likely
		# to look empty rather than calm.
		Flock.leg = 2
		Flock.new_flock(6)
		for i in 8:
			await get_tree().process_frame
		_set_hud_visible(false)
		roster.open()
		for i in 14:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_save_shot(get_viewport().get_texture().get_image(), "gg_ui_roster_clean.png")
		roster.close()

		Flock.leg = 5
		Flock.new_flock(6)
		Flock.set_dd(2)
		var b0: Dictionary = Flock.birds[0]
		b0["stamina"] = 0.42
		Flock.scar_bird(0, "clipped a wire over Buffalo")
		Flock.dose_bird(1, 0.28)
		var b1: Dictionary = Flock.birds[1]
		b1["stamina"] = 0.81
		b1["joined_at_leg"] = 5
		Flock.dose_bird(4, 0.88)
		var b4: Dictionary = Flock.birds[4]
		b4["stamina"] = 0.13
		Flock.scar_bird(4, "flew the last of it on empty over the Susquehanna")
		Flock.scar_bird(4, "took a turbine blade over the fall line")
		var gone: Array[String] = []
		gone.append(str(Flock.birds[3].name))
		gone.append(str(Flock.birds[5].name))
		Flock.lose_bird(3, "flew into a wire over Buffalo")
		Flock.lose_bird(5, "went into a turbine over the Susquehanna")
		for i in 6:
			await get_tree().process_frame

		# Open it the way the pause menu does, so the shot also proves the
		# hide_for_overlay / show_after_overlay handoff and the "don't unpause a
		# tree you didn't pause" rule.
		pause_menu.open()
		pause_menu.flock_requested.emit()
		for i in 16:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_save_shot(get_viewport().get_texture().get_image(), "gg_ui_roster.png")
		roster.close()
		print("[probe] after roster close: paused=", get_tree().paused,
			" pause_menu_open=", pause_menu.is_open())

		# The pause menu with its restart button armed. It is only on screen at
		# all if show_after_overlay() brought it back.
		pause_menu._on_restart_pressed()
		for i in 8:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_save_shot(get_viewport().get_texture().get_image(), "gg_ui_pause_restart.png")
		pause_menu._close()

		# The R prompt. Re-armed every frame because software rendering is slow
		# enough to walk straight through a 1.5 s window.
		for i in 10:
			_restart_armed_ms = Time.get_ticks_msec()
			_tick_restart_prompt()
			await get_tree().process_frame
		_restart_armed_ms = Time.get_ticks_msec()
		_tick_restart_prompt()
		await RenderingServer.frame_post_draw
		_save_shot(get_viewport().get_texture().get_image(), "gg_ui_restart.png")

		# And the other opening: nobody has paused the tree, so the roster has to
		# pause it itself and hand it back. This is the pair of booleans that
		# would strand the game paused or resume it under a menu.
		_restart_armed_ms = -1_000_000
		_tick_restart_prompt()
		print("[probe] standalone open: before=", get_tree().paused)
		roster.open(gone)
		print("[probe] standalone open: during=", get_tree().paused)
		for i in 14:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_save_shot(get_viewport().get_texture().get_image(), "gg_ui_roster_loss.png")
		roster.close()
		print("[probe] standalone open: after=", get_tree().paused)

		# The confirm on R, exercised rather than described. One press must arm
		# and change nothing; a second inside the window must restart; a press
		# after the window has closed must arm again rather than fire.
		var rev := InputEventAction.new()
		rev.action = "gg_restart"
		rev.pressed = true
		Flock.leg = 4
		_restart_armed_ms = -1_000_000
		_unhandled_input(rev)
		print("[probe] R x1        -> leg=", Flock.leg, " prompt=", restart_prompt.visible)
		_unhandled_input(rev)
		print("[probe] R x2        -> leg=", Flock.leg, " prompt=", restart_prompt.visible)
		Flock.leg = 4
		_restart_armed_ms = Time.get_ticks_msec() - RESTART_CONFIRM_MS - 500
		_unhandled_input(rev)
		print("[probe] R after gap -> leg=", Flock.leg, " prompt=", restart_prompt.visible)
		_restart_armed_ms = -1_000_000
		_tick_restart_prompt()

		# And the path the flight actually uses: a bird is lost mid-flight, the
		# flight ends, and the roster must be up and the tree stopped BEFORE the
		# next leg's heal and the next zone load.
		Flock.new_flock(6)
		Flock.lose_bird(2, "flew into a wire over the QEW")
		_on_migration_done(2000.0, 2000.0)
		await get_tree().process_frame
		print("[probe] flight loss -> roster_open=", roster.is_open(),
			" paused=", get_tree().paused, " leg=", Flock.leg,
			" alive=", Flock.alive_birds().size())
		roster.force_close()
		await get_tree().process_frame
		print("[probe] dismissed    -> roster_open=", roster.is_open(),
			" paused=", get_tree().paused, " leg=", Flock.leg, " phase=", Game.phase)
		# A second `finished` from the same flight must do nothing at all.
		_on_migration_done(2000.0, 2000.0)
		await get_tree().process_frame
		print("[probe] second emit  -> leg=", Flock.leg, " (must be unchanged)")
		_probe_quit()
		return

	if args.has("--ui"):
		for id in [&"berries", &"double_double", &"fly_agaric", &"math", &"darts"]:
			var u := get_node_or_null("/root/Unlocks")
			if u:
				u.unlock(id)
		for i in 8:
			await get_tree().process_frame
		control_card.open()
		for i in 14:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_save_shot(get_viewport().get_texture().get_image(), "gg_ui_controls.png")
		control_card.close()
		almanac.open()
		for i in 14:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_save_shot(get_viewport().get_texture().get_image(), "gg_ui_almanac.png")
		_probe_quit()
		return

	if look_at == "" and args.has("--boss"):
		look_at = "Boss"

	if goto_at.is_finite() and current != null:
		var gg = current.get("goose")
		if gg != null and is_instance_valid(gg):
			(gg as Node3D).global_position = goto_at
			gg.set("velocity", Vector3.ZERO)
			print("[probe] goose moved to ", goto_at)

	var shots := 0
	while shots < shots_wanted:
		await _settle(frames, secs)
		# Re-framed before EVERY shot: the encounter walks around, and a camera
		# placed once photographs wherever the boss used to be.
		if look_at != "":
			_look_at_named(look_at)
		if not migration_probe and current and shots == 1:
			var g2 = current.get("goose")
			if g2:
				g2.velocity = Vector3(7, 10, -4)
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		# The leg is in the filename. `--probe --leg:6` is documented in
		# docs/HANDOFF.md as the way to photograph one zone, and every leg used to
		# write `gg_zone_0.png` — so photographing the route in a loop left one
		# image, of leg 7, and a shell script that looked like it had worked.
		var tag2 := forced if forced != "" else ("mig" if migration_probe
			else ("fx" if fx_probe else ("zone%d%s" % [Flock.leg, "_boss" if args.has("--boss") else ""])))
		_save_shot(img, "gg_%s_%d.png" % [tag2, shots])
		shots += 1
	_probe_quit()
