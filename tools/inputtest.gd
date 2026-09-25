extends RefCounted
## THE CONTROLLER SMOKE TEST — the third gate, and the only one that presses a key.
##
## `tools/gate.gd` proves the code compiles. `tools/selftest.gd` proves the game
## agrees with itself. Neither of them can tell you that the goose does not move
## when you hold W, and that is the only category of bug that matters, because
## CLAUDE.md's own rule is that the controller has to feel good before anything
## else does.
##
## THE BUG THIS EXISTS BECAUSE OF. `_wanted()`'s input-lag buffer read the
## OLDEST sample instead of the newest one old enough, so every substance with
## input lag — eleven of the sixteen — ramped from 0 to a FOUR SECOND delay over
## its first four seconds and then stayed there. Fermented berries ask for 0.22 s
## and got 4.0. The gate passed. The selftest would have passed. The campaign
## loop test passed. Nothing in this project could see it, because nothing in
## this project had ever pressed a key.
##
## It works headless: `Input.action_press()` sets real action state, physics
## ticks at the project's 60 Hz whether or not anything is drawn, and
## `await tree.physics_frame` is one deterministic 1/60 s step. So this is cheap
## enough to run on every build.
##
##     godot --headless --path . -- --inputtest 2>&1 | grep '^\[input\]'
##
## Exit 0 = the bird obeys. Exit 1 = it does not, and the failing line says how.
##
## WHAT THIS CANNOT DO: judge whether any of it FEELS good. That is the human's
## job and this file does not have an opinion about it. Every threshold below is
## deliberately loose — they are there to catch "broken", never "not tuned".

const TICK := 1.0 / 60.0

static var _fails: Array[String] = []
static var _checks := 0


static func run(tree: SceneTree, main: Node) -> void:
	_fails.clear()
	_checks = 0

	var goose: CharacterBody3D = await _fresh_goose(tree, main)
	if goose == null:
		print("[input] FAIL — no goose in the zone")
		tree.quit(1)
		return

	var sober := await _walk_test(tree, goose, 1.0)
	print("[input] sober walk: %.2f m in 1.0 s" % sober)
	_ok(sober > 1.0,
		"holding forward for a second moved the goose %.2f m. It does not obey the stick at all." % sober)

	# BARS, SPECIFICALLY, and the choice is the whole test.
	#
	# It is the only substance in the shelf with input lag and ZERO DRIFT
	# (0.10 s, drift 0.0, time_scale 1.0), so the distance it covers is a clean
	# measurement of the lag and nothing else. Berries were tried first and are
	# useless here: their 0.36 drift is a random walk that pushes the bird a
	# metre in a random direction every second, so the same test swung between
	# 49% and 105% of sober across two runs.
	#
	# With drift at zero the discriminator is total. A goose obeying input from
	# 0.10 s ago covers about 80% of the sober distance. A goose obeying input
	# from four seconds ago — which is what the buffer bug delivered — has no
	# drift to carry it and covers NOTHING AT ALL.
	var dosed := await _dosed_walk_test(tree, goose, &"bars", 1.0)
	print("[input] bars walk: %.2f m in 1.0 s (%.0f%% of sober)" % [dosed, 100.0 * dosed / maxf(sober, 0.001)])
	_ok(dosed > sober * 0.50,
		"on bars the goose covered %.2f m against %.2f m sober (%.0f%%). Bars ask for 0.10 s of input lag and zero drift, so this is the lag and nothing else — check the buffer read in _wanted()."
			% [dosed, sober, 100.0 * dosed / maxf(sober, 0.001)])

	var flight := await _takeoff_test(tree, goose)
	print("[input] takeoff: peak +%.2f m, reached FLY = %s" % [flight.x, flight.y > 0.5])
	_ok(flight.y > 0.5, "a run-up and a flap never reached State.FLY. The bird cannot take off.")
	_ok(flight.x > 0.8, "the takeoff gained %.2f m of altitude. The flap does nothing." % flight.x)

	await _eat_test(tree, goose)

	var honked := await _honk_test(tree, main, goose)
	print("[input] honk: chaos +%d" % honked)
	_ok(honked > 0, "honking next to the cart corral scored nothing. The honk's physical presence is gone.")

	# Read the cooldown off the instance's script rather than repeating it.
	# `preload()` on a file that declares `class_name` resolves to the TYPE,
	# not to a Script value, so `get_script_constant_map()` on it is a parse
	# error: "Cannot call non-static function ... on the class Goose directly."
	var share_cd: float = float(goose.get_script()
		.get_script_constant_map().get("SHARE_COOLDOWN", 0.0))
	# TWICE: WHEREVER THE BIRD HAPPENS TO BE, AND AT THE FLOCK PEN ON PURPOSE.
	#
	# The share key has TWO handlers. `flock_pen.gd::_share_nearby()` runs in
	# `_input` and takes the key first whenever a pen goose is within
	# SHARE_RANGE; the controller's blanket share only sees what the pen lets
	# fall through. D-032 gave the controller a cooldown and a "moved somebody"
	# check and gave the pen neither, so this test passed or failed depending on
	# where the previous test had left the bird — it failed once on 2026-09-25,
	# 3 fires in 6 frames, in a run that changed nothing near it. D-057. The
	# invariant has to hold everywhere, so it is asserted at both.
	var pen_at := _pen_spot(main)
	for where in ["wherever the bird is", "at the flock pen"]:
		var spot: Vector3 = Vector3.INF if where == "wherever the bird is" else pen_at
		if where == "at the flock pen" and not spot.is_finite():
			_ok(false, "leg 1 has no flock pen with a non-DD goose in it, so the pen's share path was not tested")
			continue
		var shared := await _share_test(tree, main, goose, spot)
		print("[input] share (%s, %.1f m from the nearest pen goose): 3 presses in 6 frames fired %d time(s); saturated fired %d"
			% [where, _pen_distance(main, goose.global_position), shared.x, shared.y])
		_ok(shared.x > 0,
			"three share presses %s fired the verb zero times. It is dead, not merely rate-limited." % where)
		_ok(shared.x == 1,
			("three share presses %s inside a %.2f s cooldown fired the verb %d times. It pays chaos "
			+ "and a combo link every time, so without the cooldown the key is free chaos on repeat. "
			+ "Both handlers — the controller's and flock_pen.gd's — have to honour the one cooldown.")
				% [where, share_cd, shared.x])
		_ok(shared.y == 0,
			("sharing %s with every bird already at intox 1.0 fired the verb %d time(s). The dose is a "
			+ "no-op there — clampf eats it — so the player is paid for a keypress that did nothing.")
				% [where, shared.y])

	await _pause_menu_test(tree, main)
	await _ui_sweep_report(tree, main, goose)
	await _menu_buttons_report(tree, main)
	await _settings_walk(tree, main, goose)
	# LAST, because it ends the leg: everything above needs the zone it leaves.
	await _gamepad_walk(tree, main)

	if _fails.is_empty():
		print("[input] PASS — %d controller checks" % _checks)
		tree.quit(0)
		return
	print("[input] FAIL — %d of %d controller checks:" % [_fails.size(), _checks])
	for f in _fails:
		print("[input]   %s" % f)
	tree.quit(1)




## ═══════════════════════════════════════════════════════════════════════════
## ESC, THROUGH THE VIEWPORT, LIKE A PLAYER
## ═══════════════════════════════════════════════════════════════════════════
##
## **The human pressed Escape and reported "there is still no pause menu."**
## Twelve gates were green at the time. NOTHING IN THIS PROJECT HAS EVER SENT
## AN INPUT EVENT THROUGH THE VIEWPORT — every harness either calls
## `Input.action_press()`, which sets action STATE and never produces an
## `InputEvent`, so no `_input()` anywhere fires; or it calls a handler
## directly. `main.gd`'s own restart probe does the latter — `_unhandled_input
## (rev)`, invoked on main — which proves the handler works and proves nothing
## about whether the event would ever reach it.
##
## `Input.parse_input_event()` is the whole difference. It pushes the event
## into the real dispatch, so every node's `_input()` runs, in the real order,
## under the real `process_mode` rules. That is where the bug lived.
##
## Three assertions, all of them things a player notices in one press: the
## menu opens, the tree actually stops, and a second press gives the game
## BACK. The last is not padding — `_open_menu()` sets `get_tree().paused` and
## `_close()` clears it, so a menu that strands the tree paused is the other
## half of this bug sitting one edit away.
static func _pause_menu_test(tree: SceneTree, main: Node) -> void:
	var menu: Node = main.get("pause_menu")
	_ok(menu != null and menu.has_method("is_open"),
		"main has no pause_menu with an is_open(), so Escape was never exercised at all")
	if menu == null or not menu.has_method("is_open"):
		return

	_release_all()
	var was_paused: bool = tree.paused
	tree.paused = false

	# A CLEAN SCREEN FIRST, OR THIS MEASURES THE WRONG OVERLAY.
	#
	# Every overlay in this game consumes ui_cancel and marks it handled, and
	# `briefing.gd` lists it in DISMISS_ACTIONS outright. If a briefing card is
	# up when the Escape below is sent, the card eats it and closes itself, the
	# pause menu never sees the event, and this reports the menu as broken on a
	# build where it is fine — two failures, `opened` and `paused`, which is
	# exactly the signature seen once before this guard existed.
	#
	# So: clear the screen, and if it will not clear, say HARNESS FAULT rather
	# than deliver a verdict on the menu. Same idiom as `feeltest.gd`'s
	# disturbed-walk retry.
	var clear := false
	for _attempt in 6:
		if not bool(main.call("_menus_open")):
			clear = true
			break
		await _escape(tree)
	_ok(clear,
		("could not reach a screen with no overlay up, so Escape was never tested against "
		+ "the pause menu. This is a HARNESS fault; do not read the rows below it as a "
		+ "verdict on the menu."))
	if not clear:
		tree.paused = was_paused
		return
	for _i in 2:
		await tree.process_frame

	await _escape(tree)
	var opened: bool = bool(menu.call("is_open"))
	var paused: bool = tree.paused
	print("[input] escape: open=%s paused=%s" % [opened, paused])
	_ok(opened,
		("pressing Escape did not open the pause menu. It is built, it is on layer 30, "
		+ "and its `_input()` handles ui_cancel — so the event is not reaching it. First "
		+ "suspect is `process_mode`: PROCESS_MODE_WHEN_PAUSED gates `_input` as well as "
		+ "`_process`, which makes a pause menu that can close itself and never open."))
	_ok(paused,
		"the pause menu reported open and the tree is still running. Escape did not pause the game.")

	await _escape(tree)
	var still_open: bool = bool(menu.call("is_open"))
	print("[input] escape again: open=%s paused=%s" % [still_open, tree.paused])
	_ok(not still_open, "a second Escape did not close the pause menu.")
	_ok(not tree.paused,
		("the pause menu closed and left the tree PAUSED. Every zone, every flight and "
		+ "every timer is stopped, and the player has no way to start them again."))

	tree.paused = was_paused



## ═══════════════════════════════════════════════════════════════════════════
## THE REST OF THE KEYS, REPORTED AND NOT YET ASSERTED
## ═══════════════════════════════════════════════════════════════════════════
##
## The pause menu was dead for the life of the project because nothing had
## ever pressed Escape. It is not the only key a player presses that no
## harness has: `gg_restart` (R) and `gg_objectives` (TAB) both go through
## `_unhandled_input`, which only runs on events that reached the viewport and
## were not consumed — exactly the path that was broken.
##
## IT SHIPPED AS A REPORT AND IS NOW ASSERTED, which is the order this project
## uses for a new instrument: print, read the output, then arm. The first run of
## a new pass is usually wrong about something — the buried-pickup pass called
## three healthy placements broken — and an assertion written before anyone has
## read the output is a guess with an `_ok()` around it.
##
## Read across five runs: TAB cycled [0, 1, 2, 0] every time, R took the restart
## prompt false -> true every time, and J moved the camera yaw 0.331 rad in 20
## frames. All three are real, so all three are checks now.
##
## TAB is not in the README control list, which is its own small finding.
static func _ui_sweep_report(tree: SceneTree, main: Node, goose: CharacterBody3D) -> void:
	_release_all()
	var was_paused: bool = tree.paused
	tree.paused = false
	for _i in 2:
		await tree.process_frame

	# TAB — mission_hud cycles FULL / compact / off. Three presses must return
	# it to where it started, so the sweep leaves no state behind.
	var mh: Node = main.get("mission_hud")
	if mh == null:
		print("[input] sweep: main has no mission_hud")
	else:
		var seen: Array = []
		seen.append(int(mh.get("mode")))
		for _i in 3:
			await _press(tree, "gg_objectives")
			seen.append(int(mh.get("mode")))
		print("[input] sweep: TAB x3 -> mission_hud mode %s" % str(seen))
		# Three modes, so three presses is a full lap: every press must move it
		# and the last must land back where it started. A toggle that changed
		# nothing and a toggle stuck on one mode both read as "TAB does nothing"
		# to a player, and only the lap catches the second one.
		_ok(seen.size() == 4 and int(seen[0]) == int(seen[3]),
			("TAB three times left mission_hud on mode %s having started at %s. It cycles "
			+ "three modes through `_unhandled_input`, so three presses is one lap.")
				% [str(seen[-1]), str(seen[0])])
		_ok(int(seen[0]) != int(seen[1]),
			("the first TAB did not change mission_hud's mode (%s -> %s). The action is "
			+ "registered at runtime in mission_hud.gd::_ensure_action(), and it is handled "
			+ "in `_unhandled_input`, so anything that consumes the event first kills it.")
				% [str(seen[0]), str(seen[1])])

	# R — one press must ARM the confirmation and change nothing else. The
	# second press inside the window throws the run away, so it is not sent
	# here; the armed state is disarmed again before leaving.
	var prompt: Node = main.get("restart_prompt")
	if prompt == null:
		print("[input] sweep: main has no restart_prompt")
	else:
		var before: bool = bool(prompt.get("visible"))
		await _press(tree, "gg_restart")
		var after: bool = bool(prompt.get("visible"))
		print("[input] sweep: R x1 -> restart prompt %s -> %s" % [before, after])
		# ONE press ARMS and must not restart. The confirmation exists because a
		# run is eight legs and about forty-five minutes, and R sits one row
		# above the movement hand.
		_ok(not before, "the restart prompt was already showing before R was pressed")
		_ok(after,
			("pressing R did not raise the restart confirmation. main.gd handles it in "
			+ "`_unhandled_input` behind `not _menus_open()`, so either the event is being "
			+ "consumed first or the game thinks a menu is open."))
		main.set("_restart_armed_ms", -1000000)
		if main.has_method("_tick_restart_prompt"):
			main.call("_tick_restart_prompt")

	# J / K — camera orbit. In the ACTIONS table, absent from the README.
	var cam: Node = null if goose == null else goose.get("cam") as Node
	if cam == null or not cam.has_method("get_yaw"):
		print("[input] sweep: no camera to measure a yaw on")
	else:
		var y0: float = float(cam.call("get_yaw"))
		Input.action_press("gg_cam_left")
		for _i in 20:
			await tree.process_frame
		Input.action_release("gg_cam_left")
		var y1: float = float(cam.call("get_yaw"))
		print("[input] sweep: J held 20 frames -> yaw %.3f -> %.3f (moved %.3f)"
			% [y0, y1, absf(y1 - y0)])
		# 0.05 rad is a floor, not a target: the measured move is 0.331 over 20
		# frames and the only failure worth catching is "the key does nothing".
		# J and K are in the ACTIONS table and are NOT in the README's control
		# list, so a player finds them by accident or not at all.
		_ok(absf(y1 - y0) > 0.05,
			("holding J for 20 frames moved the camera yaw %.3f rad. gg_cam_left is bound to "
			+ "KEY_J in Game.ACTIONS; if this is zero the orbit keys are dead.")
				% absf(y1 - y0))

	tree.paused = was_paused
	_release_all()



## ═══════════════════════════════════════════════════════════════════════════
## THE PAUSE MENU'S BUTTONS, WHICH NOBODY HAS EVER BEEN ABLE TO PRESS
## ═══════════════════════════════════════════════════════════════════════════
##
## Until D-050 the menu could not open, so **not one of its seven buttons had
## ever been clicked** — not by a player, not by a probe, not once. ALMANAC,
## CONTROLS and FLOCK each emit a signal that `main.gd` wires to an overlay,
## and that whole handoff (suppress the menu, open the overlay, hand the screen
## back when it closes) has never run outside the render probe.
##
## Pressed through `Button.pressed`, which is the signal the real click emits,
## rather than by calling the callback: the wiring in `_build_overlays()` is
## the part most likely to be wrong, and calling the lambda directly would
## skip it.
##
## Shipped as a report and read before it was armed. All three handoffs were
## already correct — overlay opens, menu hides, tree stays paused, Escape brings
## the menu back — so the wiring was never the bug. It was simply unreachable,
## which is the whole point: this is a surface the game HAS and nobody could get
## to, and it is one edit away from breaking without anyone noticing.
static func _menu_buttons_report(tree: SceneTree, main: Node) -> void:
	var menu: Node = main.get("pause_menu")
	if menu == null:
		return
	_release_all()
	var was_paused: bool = tree.paused
	tree.paused = false
	for _attempt in 6:
		if not bool(main.call("_menus_open")):
			break
		await _escape(tree)

	var wiring := [
		["ALMANAC", "almanac"],
		["CONTROLS", "control_card"],
		["FLOCK", "roster"],
	]
	for row in wiring:
		var spec: Array = row
		var label: String = spec[0]
		var overlay_name: String = spec[1]
		var overlay: Node = main.get(overlay_name)
		if overlay == null:
			print("[input] menu: %s -> main has no %s" % [label, overlay_name])
			continue

		await _escape(tree)
		if not bool(menu.call("is_open")):
			print("[input] menu: %s -> could not open the pause menu to press it" % label)
			continue
		var btn: Button = _find_button(menu, label)
		if btn == null:
			print("[input] menu: %s -> no button with that label exists" % label)
			await _escape(tree)
			continue

		btn.emit_signal("pressed")
		for _i in 4:
			await tree.process_frame
		var opened: bool = overlay.has_method("is_open") and bool(overlay.call("is_open"))
		var menu_hidden: bool = not bool(menu.get("visible"))
		print("[input] menu: %s -> %s open=%s, menu hidden=%s, paused=%s"
			% [label, overlay_name, opened, menu_hidden, tree.paused])
		_ok(opened,
			("the pause menu's %s button did not open %s. The button emits a signal that "
			+ "`main.gd::_build_overlays()` connects; nothing else does, so an unwired "
			+ "signal is a dead button with no error anywhere.") % [label, overlay_name])
		_ok(menu_hidden,
			("%s opened and the pause menu is still drawn underneath it. `hide_for_overlay()` "
			+ "is what hands the screen over, and without it the player reads two menus at "
			+ "once.") % overlay_name)
		_ok(tree.paused,
			("%s opened and the tree is RUNNING. The game is live behind a menu the player "
			+ "thinks has stopped it.") % overlay_name)

		# Close the overlay the way a player would, and see the menu come back.
		await _escape(tree)
		var back: bool = bool(menu.get("visible"))
		var overlay_shut: bool = not (overlay.has_method("is_open") and bool(overlay.call("is_open")))
		print("[input] menu:   after escape -> %s closed=%s, menu back=%s"
			% [overlay_name, overlay_shut, back])
		_ok(overlay_shut, "Escape did not close %s." % overlay_name)
		_ok(back,
			("%s closed and the pause menu did not come back. `show_after_overlay()` runs off "
			+ "that overlay's `closed` signal; without it the player is left on a paused game "
			+ "with no menu and nothing to press.") % overlay_name)

		# Leave the screen clear for the next row.
		for _attempt2 in 4:
			if not bool(main.call("_menus_open")):
				break
			await _escape(tree)

	tree.paused = was_paused
	_release_all()


## ═══════════════════════════════════════════════════════════════════════════
## THE WHOLE LOOP, ON A PAD, WITH NO KEYBOARD ANYWHERE
## ═══════════════════════════════════════════════════════════════════════════
##
## The README advertises a gamepad scheme — "left stick move, A flap, B honk, X
## eat, Y share, RB dive" — and every one of those verbs works. What nobody had
## checked is whether a pad can get a player THROUGH the game rather than
## around one zone. Measured on 2026-09-25 by printing the engine's own
## defaults: Godot 4.7.1 binds `ui_cancel` to Escape ALONE and `ui_accept` to
## Enter / Keypad Enter / Space alone, and `Game.ACTIONS` gives `gg_skip` no pad
## button. So on a pad the pause menu cannot open; the roster and the control
## card, which close on those three actions, cannot close; and the flight's own
## results card, which prints `[ENTER]` and waits on `gg_skip` with no timeout,
## is a wall at the end of flight 1.
##
## (The first hypothesis was the opposite bug — that B would open the pause menu
## and eat every honk, because older Godot bound `ui_cancel` to a pad button.
## The same printout refuted it. Neither was assumed.)
##
## So this walks the real loop pressing ONLY `InputEventJoypadButton`s through
## the viewport: Start pauses, the D-pad and A drive the menu, Start backs out,
## and then the leg is ended and every card between leg 1 and the next zone —
## the results card, the first-flight briefing, the flight's own card and the
## roster after a loss — is cleared with A. A card nobody can close is not a
## menu problem. It is the end of the game.
static func _gamepad_walk(tree: SceneTree, main: Node) -> void:
	var menu: Node = main.get("pause_menu")
	var almanac: Node = main.get("almanac")
	var results: Node = main.get("results")
	var briefing: Node = main.get("briefing")
	var roster: Node = main.get("roster")
	if menu == null or almanac == null or results == null or briefing == null or roster == null:
		_ok(false, "main is missing an overlay the pad walk needs, so the pad was never exercised")
		return

	_release_all()
	tree.paused = false
	for _attempt in 6:
		if not bool(main.call("_menus_open")):
			break
		await _escape(tree)
	for _i in 4:
		await tree.process_frame

	# ── the pause menu ─────────────────────────────────────────────────────
	await _pad(tree, JOY_BUTTON_START)
	var opened: bool = bool(menu.call("is_open"))
	var focus0 := _focus_text(menu)
	print("[input] pad: Start -> menu open=%s paused=%s focus=%s" % [opened, tree.paused, focus0])
	_ok(opened,
		("Start did not open the pause menu. The menu listens for `ui_cancel` and nothing "
		+ "else, and Godot 4.7 binds that to Escape alone — so on a pad there is no pause, "
		+ "no settings, no Almanac and no way to quit. `Game._setup_input()` owns the pad map."))
	_ok(focus0 == "RESUME",
		("the pause menu opened with focus on %s, not RESUME. With nothing focused a pad "
		+ "cannot press any button in it: the D-pad moves focus only once something has it.")
			% focus0)
	if opened:
		await _pad(tree, JOY_BUTTON_DPAD_DOWN)
		var focus1 := _focus_text(menu)
		await _pad(tree, JOY_BUTTON_A)
		var alm_open: bool = bool(almanac.call("is_open"))
		print("[input] pad: D-pad down -> focus=%s, A -> almanac open=%s" % [focus1, alm_open])
		_ok(focus1 == "ALMANAC",
			"D-pad down from RESUME put focus on %s, not ALMANAC. The menu cannot be walked on a pad." % focus1)
		_ok(alm_open,
			("A on the focused ALMANAC button did not open the Almanac. `ui_accept` is what a "
			+ "Button answers to, and it needs a pad binding for A to press anything."))
		await _pad(tree, JOY_BUTTON_START)
		var alm_shut: bool = not bool(almanac.call("is_open"))
		var menu_back: bool = bool(menu.get("visible"))
		await _pad(tree, JOY_BUTTON_START)
		var menu_shut: bool = not bool(menu.call("is_open"))
		print("[input] pad: Start -> almanac closed=%s menu back=%s; Start -> menu closed=%s paused=%s"
			% [alm_shut, menu_back, menu_shut, tree.paused])
		_ok(alm_shut and menu_back, "Start did not back out of the Almanac to the pause menu.")
		_ok(menu_shut and not tree.paused, "Start did not close the pause menu and give the game back.")
		# REPORTED, NOT ASSERTED. A focused Button answers `ui_accept` — Space,
		# the flap — so a closed menu still holding focus would be a hazard. It
		# was going to be a check, and its canary said no: with the explicit
		# release removed, the engine released focus on its own when the layer
		# hid. There is no code here that could regress it, so the line stays as
		# an observation that would say so if the engine ever changed.
		var holder: Control = menu.get_viewport().gui_get_focus_owner()
		var held_inside: bool = holder != null and (menu as Node).is_ancestor_of(holder)
		print("[input] pad: after closing, focus is on %s"
			% ("<nothing>" if holder == null else "%s (inside the menu: %s)" % [str(holder.get("text")), held_inside]))
	for _attempt2 in 6:
		if not bool(main.call("_menus_open")):
			break
		await _escape(tree)
	tree.paused = false

	# ── the end of the leg, and every card between here and the next zone ──
	var game := main.get_node_or_null("/root/Game")
	if game == null:
		_ok(false, "no Game autoload, so the leg could not be ended")
		return
	game.set("zone_running", true)
	game.set("zone_time_left", 0.05)

	var got_results := false
	for _i in 180:
		await tree.physics_frame
		if bool(results.call("is_open")):
			got_results = true
			break
	_ok(got_results, "the leg clock ran out and the results card never opened, so nothing after it was tested")
	if not got_results:
		return
	var presses := 0
	while bool(results.call("is_open")) and presses < 10:
		await _pad(tree, JOY_BUTTON_A)
		presses += 1
		# GRADE_LOCKOUT is 0.34 s of wall clock; 30 physics frames is half a second.
		for _i2 in 30:
			await tree.physics_frame
	print("[input] pad: results card closed=%s after %d press(es) of A" % [not bool(results.call("is_open")), presses])
	_ok(not bool(results.call("is_open")), "ten presses of A did not get past the leg's results card.")

	# The first-flight briefing. Hermetic runs never saw it, so it shows here —
	# and it is dismissed with B, NOT A, on purpose. `docs/ONBOARDING_NOTES.md`
	# rule 1 says every card closes on "Enter, Space, Escape, gamepad A, gamepad
	# B, or a clicked button", and `briefing.gd` carried a comment saying
	# `ui_cancel` was "Escape/pad-B". Neither was true in Godot 4.7: B is the
	# honk and nothing else. A rule in prose is only true while nobody checks.
	#
	# The roster is handled here too, though nothing below expects it: a leg that
	# cost a bird opens it straight after the results card, and the first draft of
	# this walk — which killed a bird BEFORE ending the leg — stalled right here,
	# unable to see why. That was the soft-lock itself, found by accident.
	var mig: Node = null
	var brief_seen := false
	var brief_presses := 0
	var stray_roster := 0
	for _i3 in 360:
		await tree.physics_frame
		if bool(briefing.call("is_open")) and brief_presses < 10:
			brief_seen = true
			# INPUT_LOCKOUT swallows presses for the card's first 0.22 s.
			for _w in 20:
				await tree.physics_frame
			await _pad(tree, JOY_BUTTON_B)
			brief_presses += 1
			continue
		if bool(roster.call("is_open")) and stray_roster < 10:
			for _w2 in 20:
				await tree.physics_frame
			await _pad(tree, JOY_BUTTON_A)
			stray_roster += 1
			continue
		var cur: Node = main.get("current")
		if cur != null and is_instance_valid(cur) and cur.has_method("_finish") and not tree.paused:
			mig = cur
			break
	print("[input] pad: flight briefing seen=%s, B pressed %d time(s); stray roster presses %d; flight running=%s"
		% [brief_seen, brief_presses, stray_roster, mig != null])
	_ok(brief_seen, "the first-flight briefing never appeared in a hermetic run, so B was never tested against a card")
	_ok(brief_presses == 1,
		("the flight briefing took %d presses of B to close. ONBOARDING_NOTES rule 1 promises "
		+ "every card closes on gamepad B, and `briefing.gd::DISMISS_ACTIONS` is the list "
		+ "that has to contain whatever B is bound to.") % brief_presses)
	_ok(mig != null, "never reached a running flight after the results card. A card between them did not close on a pad.")
	if mig == null:
		return

	# A BIRD LOST IN THE FLIGHT, which is where the game loses them. The roster
	# then opens after the flight's card: the one card that appears only when
	# something went wrong, and it pauses the tree until someone closes it.
	var flock := main.get_node_or_null("/root/Flock")
	var had_loss := false
	if flock != null and flock.has_method("lose_bird") and flock.has_method("alive_birds"):
		var alive: Array = flock.call("alive_birds")
		if alive.size() > 1:
			flock.call("lose_bird", 1, "was driven into a lamp post by the gamepad test")
			had_loss = true

	# The flight's own card. `_finish()` is what the flight calls at its end;
	# the crossing itself is migtest's business, the card is this file's.
	var fired := [0]
	var count_it := func(_d: float, _t: float) -> void:
		fired[0] += 1
	mig.connect("finished", count_it)
	mig.call("_finish")
	for _i4 in 4:
		await tree.process_frame
	await _pad(tree, JOY_BUTTON_A)
	for _i5 in 4:
		await tree.process_frame
	print("[input] pad: flight card [ENTER] -> A fired finished %d time(s)" % fired[0])
	_ok(int(fired[0]) == 1,
		("pressing A on the flight's results card fired `finished` %d times. The card waits on "
		+ "`gg_skip` and nothing else, with no timeout — so if a pad cannot send it, a pad "
		+ "player finishes flight 1 and never leaves it.") % fired[0])
	if int(fired[0]) != 1:
		return

	if had_loss:
		var got_roster := false
		for _i6 in 120:
			await tree.physics_frame
			if bool(roster.call("is_open")):
				got_roster = true
				break
		print("[input] pad: roster opened after the loss = %s" % got_roster)
		if got_roster:
			for _i7 in 20:
				await tree.physics_frame
			await _pad(tree, JOY_BUTTON_A)
			print("[input] pad: A -> roster closed=%s" % (not bool(roster.call("is_open"))))
			_ok(not bool(roster.call("is_open")),
				("the roster that opens after a loss did not close on A. It closes on ui_cancel, "
				+ "ui_accept, gg_skip or a mouse click, and a pad sent none of them."))

	var back_in_zone := false
	for _i8 in 240:
		await tree.physics_frame
		var cur2: Node = main.get("current")
		if cur2 != null and is_instance_valid(cur2) and cur2.get("goose") != null \
				and not tree.paused and int(game.get("phase")) == 0:
			back_in_zone = true
			break
	print("[input] pad: next zone running = %s" % back_in_zone)
	_ok(back_in_zone, "after the flight the next zone never started running. The pad walk stopped somewhere between them.")


## ═══════════════════════════════════════════════════════════════════════════
## EVERY ROW OF SETTINGS, MOVED BY HAND, AND THE FAR END OF EACH ONE
## ═══════════════════════════════════════════════════════════════════════════
##
## D-053 proved one thing about the Settings panel: that a volume PREF reaches
## a bus. It did not prove that moving the control writes the pref, and it did
## not look at the other nine rows at all. The last session's commit recorded
## `screen_shake`, `fx_intensity` and `show_hints` as "checked and innocent —
## all three re-read on pref_changed", which checks that a listener exists and
## not that nothing else writes the same property afterwards.
##
## So: focus each row with the D-pad the way a pad or keyboard player does,
## move it with left / right or toggle it with A, and then read the CONSUMER —
## the camera's sensitivity, the bus, Juice's shake scale, the HUD, the goose,
## and the cats and people the Art style row promises "follow the goose. Takes
## effect immediately." Every pref is put back afterwards.
##
## SHIPPED AS A REPORT AND READ BEFORE IT WAS ARMED. Its first run found four
## things, all real (D-056): the D-pad walked straight past both checkboxes, so
## Invert Y and Show hints could not be reached on a pad; every slider took 95 to
## 100 presses end to end; the Art style row switched the goose and left all 7
## cats and all 9 people in leg 1 in the old style; and Show hints OFF held only
## until the menu closed. It also found one error of its own — pressing right
## from 0.9 hit the ceiling after two presses and reported 50 presses end to end
## — so it now presses toward whichever side of the range has room.
static func _settings_walk(tree: SceneTree, main: Node, goose: CharacterBody3D) -> void:
	var menu: Node = main.get("pause_menu")
	var prefs := main.get_node_or_null("/root/Prefs")
	var mh: Node = main.get("mission_hud")
	_ok(menu != null and prefs != null and mh != null,
		"main has no pause menu, Prefs or mission HUD, so the Settings panel was never walked")
	if menu == null or prefs == null or mh == null:
		return
	_release_all()
	tree.paused = false
	for _attempt in 6:
		if not bool(main.call("_menus_open")):
			break
		await _escape(tree)

	var keys := ["goose_model", "mouse_sensitivity", "invert_y", "fov", "master_volume",
		"sfx_volume", "music_volume", "screen_shake", "fx_intensity", "show_hints"]
	var before := {}
	for k in keys:
		before[k] = prefs.call("get_pref", StringName(k), null)

	await _escape(tree)
	var sbtn := _find_button(menu, "SETTINGS")
	_ok(sbtn != null and bool(menu.call("is_open")), "could not open the pause menu and find SETTINGS")
	if sbtn == null or not bool(menu.call("is_open")):
		return
	sbtn.emit_signal("pressed")
	for _i in 4:
		await tree.process_frame

	# ── the panel, walked with the D-pad: every row has to be reachable ──
	var sliders: Dictionary = menu.get("_slider_refs")
	var boxes: Dictionary = menu.get("_checkbox_refs")
	var order: Array[String] = [_settings_focus(menu, sliders, boxes)]
	for _i2 in 16:
		await _pad(tree, JOY_BUTTON_DPAD_DOWN)
		var d := _settings_focus(menu, sliders, boxes)
		order.append(d)
		if d == "BACK":
			break
	print("[input] settings: D-pad walk -> %s" % ", ".join(order))
	var unreached: Array[String] = []
	for k3 in sliders.keys():
		if not order.has("slider:%s" % k3):
			unreached.append(str(k3))
	for k4 in boxes.keys():
		if not order.has("check:%s" % k4):
			unreached.append(str(k4))
	_ok(unreached.is_empty() and order[0] == "option:art style" and order[-1] == "BACK",
		("walking the Settings panel top to bottom with the D-pad never reached %s. A row a pad "
		+ "cannot focus is a setting a pad player does not have. `pause_menu.gd::_chain_focus()` "
		+ "sets the order; without it Godot guesses geometrically and skips the checkboxes.")
			% ", ".join(unreached))

	# ── every slider, moved five presses, then its pref and its consumer ──
	for key in sliders.keys():
		var s: HSlider = sliders[key]
		s.grab_focus()
		await tree.process_frame
		var v0: float = s.value
		# Toward the side with room, so five presses never meet a bound.
		var mid := (s.min_value + s.max_value) * 0.5
		var dir := JOY_BUTTON_DPAD_RIGHT if v0 <= mid else JOY_BUTTON_DPAD_LEFT
		for _p in 5:
			await _pad(tree, dir)
		var v1: float = s.value
		var pv: float = float(prefs.call("get_pref", key, -1.0))
		var per_press: float = absf(v1 - v0) / 5.0
		var presses_full: float = INF if per_press <= 0.0 else (s.max_value - s.min_value) / per_press
		var got := _far_value(main, goose, str(key))
		var want: float = pv
		if str(key).ends_with("_volume"):
			want = linear_to_db(clampf(pv, 0.0001, 1.0))
		print("[input] settings: %-18s %.3f -> %.3f (pref %.3f)  %.0f presses end to end  far end: %s"
			% [key, v0, v1, pv, presses_full, _far_end(main, goose, str(key))])
		_ok(absf(pv - v1) < 0.0005,
			"moving the %s slider left the setting at %.3f while the slider reads %.3f. The control does not write its pref." % [key, pv, v1])
		_ok(presses_full <= 25.0,
			("the %s slider takes %.0f D-pad presses end to end. Pad buttons do not auto-repeat, so "
			+ "every one is a separate press; `pause_menu.gd::_step_focused_slider()` moves a "
			+ "twentieth of the range.") % [key, presses_full])
		_ok(absf(got - want) < 0.01,
			"the %s slider set the pref to %.3f and its consumer reads %.3f (wanted %.3f): %s"
				% [key, pv, got, want, _far_end(main, goose, str(key))])
	var hud: Node = main.get("hud")
	var fx_pref: float = float(prefs.call("get_pref", &"fx_intensity", -1.0))
	var fx_hud: float = float(hud.get("_fx_intensity")) if hud != null else -1.0
	_ok(absf(fx_hud - fx_pref) < 0.001,
		"FX intensity is %.3f and the HUD's post-processing still reads %.3f" % [fx_pref, fx_hud])

	# ── the two checkboxes: A on each ──
	for key2 in boxes.keys():
		var cb: CheckBox = boxes[key2]
		cb.grab_focus()
		await tree.process_frame
		var b0: bool = cb.button_pressed
		await _pad(tree, JOY_BUTTON_A)
		var bp: bool = bool(prefs.call("get_pref", key2, null))
		print("[input] settings: %-18s %s -> %s (pref %s)  far end: %s"
			% [key2, b0, cb.button_pressed, bp, _far_end(main, goose, str(key2))])
		_ok(cb.button_pressed != b0 and bp == cb.button_pressed,
			"A on the focused %s checkbox left it %s and the pref %s. It did not toggle the setting." % [key2, cb.button_pressed, bp])
	var cam: Node = null if goose == null else goose.get("cam") as Node
	var inv_pref: bool = bool(prefs.call("get_pref", &"invert_y", false))
	var inv_cam: bool = cam != null and bool(cam.get("_invert"))
	_ok(cam != null and inv_cam == inv_pref,
		"Invert Y is %s and the camera's own flag is %s" % [inv_pref, inv_cam])

	# ── Art style, through its popup, on the pad ──
	var opt: OptionButton = menu.get("_model_opt")
	var styled := false
	if opt != null:
		opt.grab_focus()
		await tree.process_frame
		await _pad(tree, JOY_BUTTON_A)
		var popup_up: bool = opt.get_popup().visible
		if popup_up:
			await _pad(tree, JOY_BUTTON_DPAD_DOWN)
			await _pad(tree, JOY_BUTTON_A)
		styled = str(prefs.call("get_pref", &"goose_model", "")) == "classic"
		for _i3 in 6:
			await tree.process_frame
		print("[input] settings: goose_model -> %s through the popup on the pad (popup opened=%s)  far end: %s"
			% [str(prefs.call("get_pref", &"goose_model", "")), popup_up, _far_end(main, goose, "goose_model")])
	_ok(styled, "A, D-pad down, A on the Art style row did not select Classic. Its popup cannot be driven from a pad.")
	if styled:
		var counts := _style_counts(main)
		var gkey: String = str(goose.get("_model_key")) if goose != null else "?"
		_ok(gkey == "classic", "Art style is Classic and the goose is still %s" % gkey)
		_ok(counts.x > 0 and counts.y == 0,
			("Art style says \"Cats and people follow the goose. Takes effect immediately.\" After "
			+ "switching to Classic, %d of %d cats are still low-poly.") % [counts.y, counts.x])
		_ok(counts.z > 0 and counts.w == 0,
			"...and %d of %d people are still low-poly." % [counts.w, counts.z])

	# ── Show hints, AFTER the menu closes: that is where it used to come undone ──
	await _escape(tree)
	for _i4 in 6:
		await tree.process_frame
	var hints: bool = bool(prefs.call("get_pref", &"show_hints", true))
	var panel_up: bool = bool(mh.get("visible"))
	print("[input] settings: menu closed; show_hints=%s and the objectives panel is visible=%s" % [hints, panel_up])
	_ok(not hints and not panel_up,
		("Show hints is %s and the objectives panel is %s now the menu has closed. It hides while "
		+ "the menu is up either way, so the only moment the setting means anything is after a "
		+ "close — which is exactly when main.gd used to put the panel back.")
			% [hints, "visible" if panel_up else "hidden"])

	# Put everything back, through the same pref path the controls use.
	for k2 in keys:
		if before[k2] != null:
			prefs.call("set_pref", StringName(k2), before[k2])
	for _i5 in 6:
		await tree.process_frame
	_ok(bool(mh.get("visible")) == bool(prefs.call("get_pref", &"show_hints", true)),
		"Show hints was turned back on with no menu up and the objectives panel did not come back.")
	var back := _style_counts(main)
	_ok(back.y == back.x and back.w == back.z,
		"Art style went back to low-poly and %d of %d cats, %d of %d people did not follow."
			% [back.x - back.y, back.x, back.z - back.w, back.z])
	tree.paused = false


## (cats, low-poly cats, people, low-poly people) in the tree right now.
static func _style_counts(main: Node) -> Vector4i:
	var out := Vector4i.ZERO
	for c in main.get_tree().get_nodes_in_group("cat"):
		out.x += 1
		if c.get("_lp") != null:
			out.y += 1
	for n in main.get_tree().get_nodes_in_group("npc"):
		var sc: Script = n.get_script()
		if sc == null or not sc.resource_path.ends_with("npc_human.gd"):
			continue
		out.z += 1
		if n.get("_lp") != null:
			out.w += 1
	return out


## The consumer of a setting, as the one number it should equal. -INF when it
## cannot be read, which no assertion above will mistake for a match.
static func _far_value(main: Node, goose: CharacterBody3D, key: String) -> float:
	var cam: Node = null if goose == null else goose.get("cam") as Node
	var juice := main.get_node_or_null("/root/Juice")
	match key:
		"mouse_sensitivity":
			return float(cam.get("_sens")) if cam != null else -INF
		"fov":
			return float(cam.get("fov_base")) if cam != null else -INF
		"master_volume", "sfx_volume", "music_volume":
			var bus := {"master_volume": "Master", "sfx_volume": "SFX", "music_volume": "Music"}[key] as String
			var idx := AudioServer.get_bus_index(bus)
			return AudioServer.get_bus_volume_db(idx) if idx >= 0 else -INF
		"screen_shake":
			return float(juice.call("shake_scale")) if juice != null else -INF
		"fx_intensity":
			return float(juice.call("fx_scale")) if juice != null else -INF
	return -INF


## What has focus in the settings panel, named by the pref it drives.
static func _settings_focus(menu: Node, sliders: Dictionary, boxes: Dictionary) -> String:
	var f: Control = menu.get_viewport().gui_get_focus_owner()
	if f == null:
		return "<nothing>"
	for k in sliders.keys():
		if sliders[k] == f:
			return "slider:%s" % k
	for k2 in boxes.keys():
		if boxes[k2] == f:
			return "check:%s" % k2
	if f is OptionButton:
		return "option:art style"
	if f is Button:
		return (f as Button).text.to_upper()
	return "<%s>" % f.get_class()


## The CONSUMER of a setting, read back, as one short string.
static func _far_end(main: Node, goose: CharacterBody3D, key: String) -> String:
	var cam: Node = null if goose == null else goose.get("cam") as Node
	var juice := main.get_node_or_null("/root/Juice")
	match key:
		"mouse_sensitivity":
			return "camera _sens=%.3f" % float(cam.get("_sens")) if cam != null else "no camera"
		"invert_y":
			return "camera _invert=%s" % str(cam.get("_invert")) if cam != null else "no camera"
		"fov":
			return "camera fov_base=%.1f" % float(cam.get("fov_base")) if cam != null else "no camera"
		"master_volume", "sfx_volume", "music_volume":
			var bus := {"master_volume": "Master", "sfx_volume": "SFX", "music_volume": "Music"}[key] as String
			var idx := AudioServer.get_bus_index(bus)
			return "bus %s %.1f dB" % [bus, AudioServer.get_bus_volume_db(idx)] if idx >= 0 else "bus %s MISSING" % bus
		"screen_shake":
			return "Juice.shake_scale()=%.3f" % float(juice.call("shake_scale")) if juice != null else "no Juice"
		"fx_intensity":
			var hud: Node = main.get("hud")
			return "Juice.fx_scale()=%.3f hud._fx_intensity=%.3f" % [
				float(juice.call("fx_scale")) if juice != null else -1.0,
				float(hud.get("_fx_intensity")) if hud != null else -1.0]
		"show_hints":
			var mh: Node = main.get("mission_hud")
			return "objectives panel visible=%s" % (mh != null and bool(mh.get("visible")))
		"goose_model":
			var cats_lp := 0
			var cats_classic := 0
			for c in main.get_tree().get_nodes_in_group("cat"):
				if c.get("_lp") != null:
					cats_lp += 1
				else:
					cats_classic += 1
			var ppl_lp := 0
			var ppl_classic := 0
			for n in main.get_tree().get_nodes_in_group("npc"):
				var sc: Script = n.get_script()
				if sc == null or not sc.resource_path.ends_with("npc_human.gd"):
					continue
				if n.get("_lp") != null:
					ppl_lp += 1
				else:
					ppl_classic += 1
			return "goose=%s, cats lowpoly/classic=%d/%d, people lowpoly/classic=%d/%d" % [
				str(goose.get("_model_key")) if goose != null else "?", cats_lp, cats_classic, ppl_lp, ppl_classic]
	return "?"


## One press-and-release of a pad button, through the viewport.
static func _pad(tree: SceneTree, button: JoyButton) -> void:
	var down := InputEventJoypadButton.new()
	down.device = 0
	down.button_index = button
	down.pressed = true
	Input.parse_input_event(down)
	await tree.process_frame
	var up := InputEventJoypadButton.new()
	up.device = 0
	up.button_index = button
	up.pressed = false
	Input.parse_input_event(up)
	for _i in 3:
		await tree.process_frame


## The text of whichever Button holds GUI focus in `n`'s viewport, or a word
## saying there is none.
static func _focus_text(n: Node) -> String:
	var f: Control = n.get_viewport().gui_get_focus_owner()
	if f == null:
		return "<nothing>"
	var b := f as Button
	if b == null:
		return "<%s>" % f.get_class()
	return b.text.to_upper()


## The first Button under `root` whose text matches, case-insensitively.
static func _find_button(root: Node, label: String) -> Button:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		var btn := n as Button
		if btn != null and btn.text.to_upper() == label.to_upper():
			return btn
	return null

## One press-and-release of an action, through the viewport.
static func _press(tree: SceneTree, action: String) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	await tree.process_frame
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	for _i in 3:
		await tree.process_frame

## One press-and-release of a real key, through the viewport. `InputEventKey`,
## not `InputEventAction`: several overlays (the results card among them) only
## count a key, a pad button or a click as a press.
static func _key(tree: SceneTree, code: Key) -> void:
	var down := InputEventKey.new()
	down.keycode = code
	down.physical_keycode = code
	down.pressed = true
	Input.parse_input_event(down)
	await tree.process_frame
	var up := InputEventKey.new()
	up.keycode = code
	up.physical_keycode = code
	up.pressed = false
	Input.parse_input_event(up)
	for _i in 3:
		await tree.process_frame

## One Escape, through the viewport rather than at a handler.
static func _escape(tree: SceneTree) -> void:
	var down := InputEventAction.new()
	down.action = "ui_cancel"
	down.pressed = true
	Input.parse_input_event(down)
	await tree.process_frame
	var up := InputEventAction.new()
	up.action = "ui_cancel"
	up.pressed = false
	Input.parse_input_event(up)
	for _i in 3:
		await tree.process_frame

## ═══════════════════════════════════════════════════════════════════════════
## THE EATING VERB, THROUGH THE KEY THE PLAYER PRESSES
## ═══════════════════════════════════════════════════════════════════════════
##
## `docs/HANDOFF.md` §4: *"Every harness reaches into `Subs.take()` directly, so
## `_tick_eat`'s charge arc, the sweet-spot band, the abort, the pickup's
## `consumed()` and the SWEET SPOT / OVERDOSE / BARELY ANYTHING scoring have
## never been driven by a key."* That is the game's CORE SKILL EXPRESSION — the
## controller's own comment calls letting go at the right moment "its only real
## input-timing test" — and it is the reason `stamina_restore` could be dead in
## six `.tres` files with every gate green.
##
## GRASS, and the choice is load-bearing. It is `infinite` in leg 1 (the zone's
## own comment says so, and says why: "the dose ARC — charge, release, overdose
## — is the thing leg 1 has to teach"), so the same pickup survives all three
## releases; it is in the tutorial shelf, so it is there at leg 1; its band is
## wide (0.35–0.85) so the three doses are far apart; and it restores 0.25
## stamina, which is the field nothing has ever been able to check behaviourally.
##
## THE HOLDS ARE TO A CHARGE, NOT TO A FRAME COUNT, and the first draft got this
## wrong in a way worth keeping. `_eat_charge += delta / charge_time` looks like
## 1/84 per frame at 60 Hz — and the first dose measures exactly that, 0.202 in
## 17 frames. The second and third do not: they came in at 0.545 and 0.838 where
## the frame count predicted 0.607 and 0.952, and the harness called the game
## broken. **Grass sets `time_scale` to 0.88.** Once the first dose lands, every
## `delta` the controller sees is 12% shorter, so the arc is still a clock — in
## GAME time, which is the only clock the player is in. Holding until the charge
## reaches a target is immune to that; the clock is then checked separately
## against game time accumulated the same way.
##
## Targets 0.20 / 0.60 / 0.95 against a [0.35, 0.85] band: clear of both edges.
static func _eat_test(tree: SceneTree, goose: CharacterBody3D) -> void:
	var pick: Node3D = null
	for n in tree.get_nodes_in_group("substance_source"):
		var cand := n as Node3D
		if cand == null or not is_instance_valid(cand):
			continue
		var sub: Object = cand.get("substance")
		if sub != null and str(sub.get("id")) == "grass":
			pick = cand
			break
	_ok(pick != null,
		"leg 1 has no grass source to eat, so the eating verb was not exercised at all.")
	if pick == null:
		return
	var res: Substance = pick.get("substance")

	# The dose hint is marked seen for every harness run (main.gd), so no other
	# measurement is ambushed by it. This one wants it: un-see it, the way a
	# first-time player has never seen it.
	var brief: Node = tree.current_scene.get("briefing") if tree.current_scene != null else null
	if brief != null and brief.has_method("reset_seen"):
		brief.call("reset_seen", &"dose_hint")

	# WALK INTO IT. `SubstancePickup` is an Area3D whose `body_entered` calls
	# `set_eat_target()`; nothing else sets `_eating`, so being in range is part
	# of what is under test rather than something to fake.
	_release_all()
	goose.global_position = pick.global_position + Vector3.UP * 0.5
	goose.velocity = Vector3.ZERO
	var in_range := false
	for _i in 30:
		await tree.physics_frame
		if goose.get("_eating") != null:
			in_range = true
			break
	_ok(in_range,
		("standing on the grass never set the goose's eat target. `body_entered` -> "
		+ "`set_eat_target()` is the only path that arms the verb, so nothing below "
		+ "this ran."))
	if not in_range:
		return

	# THE DOSE HINT, which is the card that teaches the arc this test is about to
	# drive. It was designed, built and specced to fire here on leg 1 — and
	# nothing called it (D-059). A first-time player standing on the grass meets
	# it; so does this, and dismisses it with Enter the way they would.
	var hint_up := false
	for _h in 10:
		await tree.process_frame
		if brief != null and bool(brief.call("is_open")) and str(brief.get("_pending_key")) == "dose_hint":
			hint_up = true
			break
	print("[input] eat: standing on the grass raised the dose hint = %s (tree paused = %s)" % [hint_up, tree.paused])
	_ok(hint_up,
		("a first-time player stood on the grass and no dose hint appeared. `briefing_defs.gd::"
		+ "dose_hint()` is the card that teaches the arc, `CAMPAIGN_SPEC.md` §2.1 says it fires "
		+ "here, and `substance_pickup.gd::_on_enter()` is where it is raised."))
	if hint_up:
		for _l in 20:
			await tree.physics_frame   # past INPUT_LOCKOUT, which swallows the first 0.22 s
		await _key(tree, KEY_ENTER)
		_ok(not bool(brief.call("is_open")) and not tree.paused,
			"Enter did not close the dose hint, or it left the tree paused behind it.")
		_ok(goose.get("_eating") != null,
			"closing the dose hint dropped the eat target. The card is supposed to leave the bird standing on the grass, ready.")

	# EVERY LABEL THE DOSE SCORES. `Game.score()` emits `chaos_scored` with the
	# label as its fourth argument, which is the only observable that separates
	# the three outcomes — they all call `Subs.take()` and they all succeed.
	var labels: Array = []
	var watch := func(_amount: int, _total: int, _combo: int, label: String) -> void:
		labels.append(label)
	Game.chaos_scored.connect(watch)

	for row in [[0.20, "BARELY ANYTHING"], [0.60, "SWEET SPOT"], [0.95, "OVERDOSE"]]:
		var spec: Array = row
		var target: float = spec[0]
		var want: String = spec[1]
		labels.clear()
		var game_time := 0.0
		var held := 0
		Input.action_press("gg_eat")
		for _f in 240:
			await tree.physics_frame
			# The clock the CONTROLLER is on. `Engine.time_scale` scales the delta
			# handed to `_physics_process`, and grass sets it to 0.88.
			game_time += TICK * Engine.time_scale
			held += 1
			if float(goose.get("_eat_charge")) >= target:
				break
		var charged: float = float(goose.get("_eat_charge"))
		# Set the stamina ON THE FRAME BEFORE THE RELEASE, so the gain measured
		# below is the restore and not a second of `regen_ground` — which over an
		# 80-frame hold is larger than the restore being looked for, and would
		# have satisfied a laxer check on its own.
		goose.set("stamina", 0.20)
		var before: float = float(goose.get("stamina"))
		Input.action_release("gg_eat")
		await tree.physics_frame
		await tree.physics_frame
		var after: float = float(goose.get("stamina"))

		_ok(charged >= target,
			("holding gg_eat for %d frames never reached a charge of %.2f (got %.3f). The "
			+ "arc does not fill.") % [held, target, charged])

		# THE ARC IS A CLOCK. A charge that saturated instantly would score SWEET
		# SPOT on all three of these holds and look perfect.
		var expect := game_time / res.charge_time
		_ok(absf(charged - expect) <= 0.06,
			("%d frames of gg_eat is %.3f s of game time and charge_time is %.2f s, so the "
			+ "charge should be %.3f. It is %.3f. The dose arc is not a clock.")
				% [held, game_time, res.charge_time, expect, charged])

		var in_band: bool = charged >= res.sweet_min and charged <= res.sweet_max
		var deserved := "SWEET SPOT" if in_band else ("OVERDOSE" if charged > res.sweet_max else "BARELY ANYTHING")
		_ok(deserved == want,
			("the harness aimed for %s and the charge landed at %.3f, which its band "
			+ "[%.2f, %.2f] calls %s. The three targets no longer straddle the band — fix "
			+ "the targets, not the game.") % [want, charged, res.sweet_min, res.sweet_max, deserved])
		_ok(labels.has(want),
			("a %.3f dose of grass scored %s, not %s. Its band is [%.2f, %.2f], and these "
			+ "three labels are the game's whole readout of the only input-timing skill "
			+ "it has.") % [charged, str(labels), want, res.sweet_min, res.sweet_max])

		_ok(Subs.is_active(res.id),
			"a %.3f dose of grass released through gg_eat left the substance inactive." % charged)

		# stamina_restore, BEHAVIOURALLY. It was dead in six .tres files and
		# nothing noticed, because it is applied at exactly this moment and no
		# harness had ever reached this moment. `selftest` can only see that the
		# field is named in the controller.
		var gained := after - before
		_ok(gained >= res.stamina_restore * 0.8 and gained <= res.stamina_restore * 1.2 + 0.03,
			("grass declares stamina_restore %.2f and a dose through the key moved stamina "
			+ "%.3f (%.2f -> %.2f) across the release frame. It is applied inside the "
			+ "`if Subs.take(...)` branch of _tick_eat(), so this is that line.")
				% [res.stamina_restore, gained, before, after])
		print("[input] eat: %3d frames -> %.3f charge (%.3f s game time), %s, stamina +%.3f"
			% [held, charged, game_time, str(labels), gained])
	# AND THE ABORT. Walking off mid-hold has to drop the charge on the floor:
	# `clear_eat_target()` nulls `_eating` and zeroes `_eat_charge` together, and
	# a version of `_tick_eat` that trusted a stale charge left the dose loop
	# ringing in the player's ears for the rest of the leg.
	labels.clear()
	var away := pick.global_position + Vector3(40.0, 0.5, 40.0)
	Input.action_press("gg_eat")
	for _f in 30:
		await tree.physics_frame
	goose.global_position = away
	for _f in 20:
		await tree.physics_frame
	Input.action_release("gg_eat")
	await tree.physics_frame
	Game.chaos_scored.disconnect(watch)
	_ok(float(goose.get("_eat_charge")) <= 0.001,
		("walking out of range mid-hold left %.3f of charge on the bird. It has to be "
		+ "dropped, or the next pickup starts part-charged.") % float(goose.get("_eat_charge")))
	_ok(labels.is_empty(),
		"walking away mid-hold still scored %s. An abort is not a dose." % str(labels))
	print("[input] eat: abort mid-hold dropped the charge and scored nothing")

static func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_fails.append(msg)


## Put the bird on the ground, sober, stationary, with the clock running.
##
## Delegates to `probe_common.gd`. This file carried its own copy, identical but
## for one thing: when `fresh_goose()` gained a refusal to hand out a bird on a
## paused tree (lesson 9), this copy did not — which is what a second copy is for.
static func _fresh_goose(tree: SceneTree, main: Node) -> CharacterBody3D:
	return await preload("res://tools/probe_common.gd").fresh_goose(tree, main)


static func _settle(tree: SceneTree, goose: CharacterBody3D) -> void:
	_release_all()
	# Annotated, not inferred: Engine.get_main_loop() is typed MainLoop, which has
	# no `root`, so the whole chain is a Variant and ':=' is a parse error. This
	# is the single most common mistake in the codebase and it caught this file.
	var subs: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Subs")
	if subs != null and subs.has_method("reset_for_new_leg"):
		subs.reset_for_new_leg()
	goose.velocity = Vector3.ZERO
	# Long enough for the input buffer to drain and for the bird to stop sliding.
	for _i in 90:
		await tree.physics_frame


static func _release_all() -> void:
	for a in ["gg_forward", "gg_back", "gg_left", "gg_right", "gg_flap", "gg_dive", "gg_honk", "gg_share"]:
		if InputMap.has_action(a):
			Input.action_release(a)


## Hold forward for `secs` and return the horizontal distance covered.
static func _walk_test(tree: SceneTree, goose: CharacterBody3D, secs: float) -> float:
	await _settle(tree, goose)
	var start := goose.global_position
	Input.action_press("gg_forward")
	for _i in int(secs / TICK):
		await tree.physics_frame
	Input.action_release("gg_forward")
	var moved := goose.global_position - start
	moved.y = 0.0
	return moved.length()


static func _dosed_walk_test(tree: SceneTree, goose: CharacterBody3D, id: StringName, secs: float) -> float:
	await _settle(tree, goose)
	# Annotated, not inferred: Engine.get_main_loop() is typed MainLoop, which has
	# no `root`, so the whole chain is a Variant and ':=' is a parse error. This
	# is the single most common mistake in the codebase and it caught this file.
	var subs: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Subs")
	if subs != null and subs.has_method("take") and subs.has_method("get_substance"):
		var res: Resource = subs.get_substance(id)
		if res != null:
			subs.take(res, 0.6)
	# Let the dose land and the buffer fill past the lag window. The old bug got
	# WORSE with time — the buffer had to fill before it could hand back
	# four-second-old input — so waiting here is what makes this test bite.
	for _i in 120:
		await tree.physics_frame
	goose.velocity = Vector3.ZERO
	var start := goose.global_position
	Input.action_press("gg_forward")
	for _i in int(secs / TICK):
		await tree.physics_frame
	Input.action_release("gg_forward")
	var moved := goose.global_position - start
	moved.y = 0.0
	return moved.length()


## Run up, then flap. Returns (peak altitude gained, 1.0 if State.FLY was seen).
static func _takeoff_test(tree: SceneTree, goose: CharacterBody3D) -> Vector2:
	await _settle(tree, goose)
	var y0 := goose.global_position.y
	var peak := 0.0
	var flew := 0.0
	Input.action_press("gg_forward")
	# The run-up requirement is real: takeoff_run_speed m/s of ground speed
	# before a flap becomes a launch instead of a pathetic little hop.
	for _i in 60:
		await tree.physics_frame
	Input.action_press("gg_flap")
	for _i in 150:
		await tree.physics_frame
		peak = maxf(peak, goose.global_position.y - y0)
		if int(goose.get("state")) == 2:   # State.FLY
			flew = 1.0
	_release_all()
	return Vector2(peak, flew)

## THE SHARE VERB, AND THE TWO WAYS IT USED TO PAY FOR NOTHING.
##
## `gg_share` doses the whole flock and scores 75 chaos. It had no cooldown
## and no check that the dose landed, so mashing it paid 75 a press forever —
## and once every bird sat at intox 1.0 the dose was a no-op that still paid.
## Both are fixed in `goose_controller.gd::_unhandled_input`; this is what
## proves it, by pressing the key.
##
## COUNTS SCORING EVENTS, NOT CHAOS. The first version asserted that three
## presses paid no more than 75 and it failed on a correct build at 92:
## `Game.score()` multiplies by the live combo, so one share is worth 75 x
## whatever chain the run is on. The amount is not the thing being tested —
## how many times the verb FIRED is — so this counts `chaos_scored` emissions
## carrying the share label.
##
## Returns [fires_on_mash, fires_when_saturated] as a Vector2i.
static func _share_test(tree: SceneTree, main: Node, goose: CharacterBody3D, at := Vector3.INF) -> Vector2i:
	await _settle(tree, goose)
	var game := main.get_node_or_null("/root/Game")
	var subs := main.get_node_or_null("/root/Subs")
	if game == null or subs == null:
		return Vector2i(-1, -1)
	if at.is_finite():
		goose.global_position = at
		goose.velocity = Vector3.ZERO
		for _i0 in 20:
			await tree.physics_frame

	# The verb needs something to share. Any substance will do.
	var res = subs.get_substance(&"grass")
	if res == null:
		return Vector2i(-1, -1)
	subs.take(res, 0.5)
	for _i in 4:
		await tree.physics_frame

	# Sober the flock first, so the first share definitely has room to land.
	for b in Flock.birds:
		b.intox = 0.0

	# THREE PRESSES IN SIX FRAMES. One should fire.
	var fires := [0]
	var tally := func(_amount: int, _total: int, _combo: int, label: String) -> void:
		if label == "SHARED WITH THE FLOCK":
			fires[0] += 1
	game.chaos_scored.connect(tally)
	for _i in 3:
		var ev := InputEventAction.new()
		ev.action = "gg_share"
		ev.pressed = true
		Input.parse_input_event(ev)
		await tree.physics_frame
		var up := InputEventAction.new()
		up.action = "gg_share"
		up.pressed = false
		Input.parse_input_event(up)
		await tree.physics_frame
	var mashed: int = int(fires[0])

	# Now saturate the flock and wait out the cooldown. A press that moves
	# nothing must pay nothing.
	for b2 in Flock.birds:
		b2.intox = 1.0
	for _i in 80:
		await tree.physics_frame
	fires[0] = 0
	var ev2 := InputEventAction.new()
	ev2.action = "gg_share"
	ev2.pressed = true
	Input.parse_input_event(ev2)
	for _i in 6:
		await tree.physics_frame
	var up2 := InputEventAction.new()
	up2.action = "gg_share"
	up2.pressed = false
	Input.parse_input_event(up2)
	var saturated: int = int(fires[0])
	game.chaos_scored.disconnect(tally)

	subs.call("reset_for_new_leg")
	return Vector2i(mashed, saturated)


## The zone's flock pen, found by script.
static func _pen(main: Node) -> Node:
	var cur: Node = main.get("current")
	if cur == null or not is_instance_valid(cur):
		return null
	var pen_script: Script = preload("res://scripts/world/flock_pen.gd")
	for c in cur.get_children():
		if c.get_script() == pen_script:
			return c
	return null


## A spot 1.2 m beside a pen goose that is NOT the designated driver — the pen
## refuses to dose the DD and lets the key fall through, which would test the
## controller's path instead of its own. INF when there is none.
static func _pen_spot(main: Node) -> Vector3:
	var pen := _pen(main)
	if pen == null:
		return Vector3.INF
	var dd: int = int(Flock.designated_driver())
	for b in pen.get("_birds"):
		var bird: Dictionary = b
		var idx: int = bird["index"]
		var root: Node3D = bird["root"]
		if idx != dd and root != null and is_instance_valid(root):
			return root.global_position + Vector3(1.2, 0.4, 0.0)
	return Vector3.INF


## Metres from `pos` to the nearest pen goose; INF with no pen.
static func _pen_distance(main: Node, pos: Vector3) -> float:
	var pen := _pen(main)
	var best := INF
	if pen == null:
		return best
	for b in pen.get("_birds"):
		var bird: Dictionary = b
		var root: Node3D = bird["root"]
		if root != null and is_instance_valid(root):
			best = minf(best, root.global_position.distance_to(pos))
	return best


## Honk and see whether the world reacted. Returns the chaos gained.
static func _honk_test(tree: SceneTree, main: Node, goose: CharacterBody3D) -> int:
	await _settle(tree, goose)
	var game := main.get_node_or_null("/root/Game")
	if game == null:
		return 0

	# Stand next to something breakable rather than trusting the spawn point to
	# have one in range — the honk's radius is 7.5 m and the zone is 80 m across.
	var props := tree.get_nodes_in_group("chaos_prop")
	if props.is_empty():
		return 0
	var target := props[0] as Node3D
	if target != null:
		goose.global_position = target.global_position + Vector3(0, 0.6, 2.0)
		goose.velocity = Vector3.ZERO
		for _i in 10:
			await tree.physics_frame

	var before: int = int(game.chaos)
	# THE HONK IS EVENT-DRIVEN, not polled. goose_controller.gd:730 tests
	# `e.is_action_pressed("gg_honk")` inside an input callback, while movement
	# and the flap are read with `Input.is_action_pressed` in _physics_process.
	# `Input.action_press()` sets action STATE without emitting an InputEvent, so
	# it drives the bird's legs and not its voice — the first version of this
	# test reported "the honk's physical presence is gone" and the honk was fine.
	var down := InputEventAction.new()
	down.action = "gg_honk"
	down.pressed = true
	Input.parse_input_event(down)
	for _i in 6:
		await tree.physics_frame
	var up := InputEventAction.new()
	up.action = "gg_honk"
	up.pressed = false
	Input.parse_input_event(up)
	for _i in 30:
		await tree.physics_frame
	return int(game.chaos) - before
