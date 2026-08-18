extends Node3D
## THE MIGRATION LEG — the interstitial flight between zones.
##
## This is the payoff for everything you did in the sandbox. The flock arrives
## here in exactly the condition you left it in, and the central mechanic is
## LEAD ROTATION:
##
##   The bird at the point of the V gets no drafting benefit and burns far more
##   energy, which is why real geese rotate the lead. So you have to hand the
##   point off — but only to a bird sober and rested enough to hold it. Party
##   too hard in the zone and there's nobody to hand off to, you burn out, and
##   you land short.
##
## That single rule makes "how hard did I party" the whole tension of the
## flight, and it's true biology. Keep this to 60–90 seconds. It must never
## feel like a tax between the fun parts.

signal finished(distance: float, target: float)

const TARGET_DISTANCE := 2000.0
const BASE_SPEED := 34.0
const CORRIDOR_X := 13.0
const Y_MIN := 5.0
const Y_MAX := 34.0
const SLOT_RADIUS := 3.4

## Stamina cost per second at the point of the V vs. tucked in the draft.
## Tuned so a 75-second flight forces 2-3 lead handoffs. If the player can
## hold the point the whole way, the entire mechanic is decorative.
const DRAIN_LEAD := 0.028
const DRAIN_DRAFT := -0.020

## Where each flight happens, indexed by the leg you are flying OUT of. Used
## only to write scar and loss lines, because "clipped a wire over Buffalo" is a
## thing a player remembers and "scars: 2" is not. Matches the route in
## main.gd and the beat names in docs/CAMPAIGN_SPEC.md Part 3.
const FLIGHT_PLACES := [
	"the 401",              # 1 -> 2  THE 401
	"the QEW",              # 2 -> 3  OVER THE QEW
	"Georgian Bay",         # 3 -> 4  THE WRONG WAY (north, on purpose)
	"Buffalo",              # 4 -> 5  THE LONG HAUL
	"the Susquehanna",      # 5 -> 6  DOWN THE SUSQUEHANNA
	"the fall line",        # 6 -> 7  THE FALL LINE
	"I-95",                 # 7 -> 8  THE INTERSTATE
]

## Anything at or under this at the buzzer flew the last of it on empty, which
## is a near-death by any honest reading and is the exhaustion scar the campaign
## spec asks for (§4.8: "a bird survives a flight at < 0.1 stamina").
const SPENT_STAMINA := 0.1

var birds: Array = []              ## [{node, idx, slot, drift, pos}]
var player_bird_index := -1        ## index into Flock.birds that the PLAYER is
var lead_index := -1               ## which Flock.birds index holds the point
var player_leads := true

var distance := 0.0
var target_distance := TARGET_DISTANCE
var speed := BASE_SPEED
var integrity := 1.0
var player_pos := Vector3(0, 18, 0)
var player_node: Node3D
var over := false
## `finished` is TERMINAL — exactly one emission per flight, for the life of
## this node. See _process().
var _emitted := false

var _cam: Camera3D
var _obstacles: Array = []
var _thermals: Array = []
var _clouds: Array = []
var _spawn_t := 0.0
var _honk_cd := 0.0
var _msg := ""
var _msg_t := 0.0
var _hud: CanvasLayer
var _lbl_top: Label
var _lbl_mid: Label
var _lbl_bot: Label
var _bar: Control
var _roster: Control
## Throttle on the thermal sparkle. Riding a thermal is a continuous state and
## the reward has to be a rhythm, not a firehose into the burst pool.
var _thermal_fx := 0.0

## The most recent near-miss, for the strip's caption. Index into Flock.birds
## and a countdown; -1 when there is nothing to say.
var _scar_idx := -1
var _scar_t := 0.0

## Distress call cadence. A bird in trouble honks; it does NOT honk every frame.
const DISTRESS_STAMINA := 0.25
const DISTRESS_EVERY := 4.0
var _distress_t := 0.0


func _ready() -> void:
	var sfx := get_node_or_null("/root/Sfx")
	if sfx:
		sfx.loop(&"wind_loop", &"wind", -12.0)
	_environment()
	_build_hud()
	_spawn_flock()
	_pick_initial_lead()
	if not Flock.bird_scarred.is_connected(_on_bird_scarred):
		Flock.bird_scarred.connect(_on_bird_scarred)


## A bird survived something. The strip says so, briefly, by name — the whole
## point of the flight HUD is that attrition is legible WHILE it happens.
func _on_bird_scarred(index: int, _reason: String) -> void:
	_scar_idx = index
	_scar_t = 6.0


# ---------------------------------------------------------------- setup

func _environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	# Late-autumn dusk at altitude. This should feel like relief after the lot.
	sm.sky_top_color = Color(0.18, 0.24, 0.44)
	sm.sky_horizon_color = Color(0.92, 0.62, 0.42)
	sm.ground_bottom_color = Color(0.10, 0.12, 0.18)
	sm.ground_horizon_color = Color(0.72, 0.52, 0.42)
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.9
	env.fog_enabled = true
	env.fog_density = 0.0022
	env.fog_light_color = Color(0.86, 0.66, 0.52)
	we.environment = env
	add_child(we)

	# Warm low sun ahead of the flock for the rim light...
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-14, 150, 0)
	sun.light_color = Color(1.0, 0.80, 0.62)
	sun.light_energy = 1.1
	add_child(sun)

	# ...and a cool fill from behind the camera, or the whole flock reads as
	# black cut-outs against the sky and you can't see who's drifting.
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-34, 12, 0)
	fill.light_color = Color(0.74, 0.82, 1.0)
	fill.light_energy = 1.25
	fill.shadow_enabled = false
	add_child(fill)

	_cam = Camera3D.new()
	_cam.fov = 74.0
	_cam.position = Vector3(0, 19.5, 13.5)
	_cam.rotation_degrees = Vector3(-5, 0, 0)
	add_child(_cam)

	# Ground FAR below. If it sits close, the flock reads as standing in a field
	# instead of flying, which kills the entire sequence.
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1800, 2600)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.13, 0.17, 0.14)
	ground.material_override = gm
	ground.position = Vector3(0, -150, -900)
	add_child(ground)

	# Cloud slabs for parallax — cheap, and they carry most of the speed read.
	for i in 22:
		var cl := MeshInstance3D.new()
		var cb := BoxMesh.new()
		cb.size = Vector3(randf_range(18, 46), 1.2, randf_range(14, 30))
		cl.mesh = cb
		var cm := StandardMaterial3D.new()
		cm.albedo_color = Color(1.0, 0.93, 0.88, 0.30)
		cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		cl.material_override = cm
		cl.position = Vector3(randf_range(-90, 90), randf_range(-16, 44), randf_range(-900, 40))
		add_child(cl)
		_clouds.append(cl)


## Which goose mesh the formation is built out of. Both scripts expose an
## identical API (animate / set_bank / set_tint), so nothing downstream cares
## which one is live — the same table, read off the same pref, that
## goose_controller.gd:132 and flock_pen.gd:55 use. This file used to preload
## goose_visual.gd unconditionally, which meant a player on the faceted art
## style flew a formation of smooth ones in the one sequence that is nothing
## but geese.
const MODEL_SCRIPTS := {
	"classic": "res://scripts/goose/goose_visual.gd",
	"lowpoly": "res://scripts/goose/goose_visual_lowpoly.gd",
}


func _model_path() -> String:
	var prefs := get_node_or_null("/root/Prefs")
	var key := "lowpoly"
	if prefs:
		key = str(prefs.get_pref(&"goose_model", "lowpoly"))
	if not MODEL_SCRIPTS.has(key):
		key = "lowpoly"
	var path: String = MODEL_SCRIPTS[key]
	return path


## Returns the wrapper Node3D. The visual is its only child and is named
## "Visual", matching the controller, because _spawn_flock() has to keep a
## handle on it: a goose nobody calls animate() on is a plank.
func _make_goose(scale_f := 1.0) -> Node3D:
	var n := Node3D.new()
	var vis: Node3D = load(_model_path()).new()
	vis.name = "Visual"
	n.add_child(vis)
	n.scale = Vector3.ONE * scale_f
	add_child(n)
	return n


func _spawn_flock() -> void:
	var alive: Array[int] = []
	for i in Flock.birds.size():
		if Flock.birds[i].alive:
			alive.append(i)

	if alive.is_empty():
		_finish()
		return

	# The player IS one of the birds, and WHICH one is Flock's to say, not this
	# scene's. This used to be `alive[0]`, which agreed with Flock.player_index
	# only because player_index is 0 and bird 0 can never be lost. Move
	# player_index and two things break at once: the flight steers somebody
	# else's goose, and the player's real bird goes down the loss path in
	# _check_obstacle(), where Flock.lose_bird() silently refuses it — leaving a
	# living roster entry with no node in the formation.
	player_bird_index = Flock.player_index
	if not alive.has(player_bird_index):
		# Unreachable while lose_bird() refuses player_index. A fallback rather
		# than an assert because the failure mode of getting this wrong is a
		# flight with no player node at all, which is worse than flying the
		# wrong goose.
		push_warning("[migration] Flock.player_index %d is not alive — flying %d instead"
			% [player_bird_index, alive[0]])
		player_bird_index = alive[0]

	for n in alive.size():
		var idx: int = alive[n]
		var node := _make_goose(1.5)
		birds.append({
			"node": node,
			"vis": node.get_node_or_null("Visual"),
			"idx": idx,
			"slot": n,
			"pos": Vector3.ZERO,
			"drift": Vector3.ZERO,
			"seed": Vector3(randf() * 10.0, randf() * 10.0, randf() * 10.0),
		})
		if idx == player_bird_index:
			player_node = node

	_layout_slots()


## Slot 0 is the point of the V. Odd slots go left, even go right.
func _slot_position(slot: int) -> Vector3:
	if slot == 0:
		return Vector3(0, 0, 0)
	var rank := (slot + 1) / 2
	var side := -1.0 if slot % 2 == 1 else 1.0
	return Vector3(side * float(rank) * 2.6, 0.0, float(rank) * 2.9)


func _layout_slots() -> void:
	for b in birds:
		b.pos = _slot_position(b.slot)


func _pick_initial_lead() -> void:
	lead_index = player_bird_index
	player_leads = true
	# _reassign_slots() derives every slot from lead_index, which is the line two
	# above. A loop used to sit here setting b.slot = 0 for the player and `pass`
	# for everyone else, and was then overwritten in full on the very next line —
	# a no-op containing an explicit empty else, which reads as a placeholder
	# somebody still means to fill in. Nobody does; the lead index is the input
	# and _reassign_slots is the whole function.
	_reassign_slots()
	_say("YOU HAVE THE POINT — [Q] to hand off the lead", 3.2)


## Rebuild slot assignment so the lead is slot 0 and everyone else fills in.
func _reassign_slots() -> void:
	var n := 1
	for b in birds:
		if b.idx == lead_index:
			b.slot = 0
		else:
			b.slot = n
			n += 1


# ---------------------------------------------------------------- HUD

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	add_child(_hud)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(root)

	_lbl_top = _mk_label(28, Color.WHITE)
	_lbl_top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_lbl_top.position = Vector2(-380, 12)
	_lbl_top.custom_minimum_size = Vector2(760, 0)
	_lbl_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_lbl_top)

	_lbl_mid = _mk_label(30, Color(1, 0.85, 0.4))
	_lbl_mid.set_anchors_preset(Control.PRESET_CENTER)
	_lbl_mid.position = Vector2(-420, -60)
	_lbl_mid.custom_minimum_size = Vector2(840, 0)
	_lbl_mid.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_lbl_mid)

	_lbl_bot = _mk_label(16, Color(0.85, 0.88, 0.94))
	_lbl_bot.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_lbl_bot.position = Vector2(20, -104)
	root.add_child(_lbl_bot)

	# CAMPAIGN_SPEC §4.7. Sits directly above the stamina/formation line, so the
	# whole bottom-left corner is one block of flock state instead of two.
	_roster = RosterStrip.new()
	_roster.mig = self
	_roster.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_roster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_roster)
	_roster.refresh(Flock.alive_birds().size())

	_bar = ProgressPanel.new()
	_bar.mig = self
	_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_bar.position = Vector2(-330, -46)
	_bar.custom_minimum_size = Vector2(660, 30)
	_bar.size = Vector2(660, 30)
	root.add_child(_bar)


func _mk_label(size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 5)
	return l


func _say(msg: String, secs: float) -> void:
	_msg = msg
	_msg_t = secs


# ---------------------------------------------------------------- loop

func _process(delta: float) -> void:
	# Ahead of the `over` early-out on purpose: without it the camera would
	# freeze holding whatever sub-pixel offset the last shake left it at, and
	# the results card would sit very slightly off-centre for good.
	_tick_shake()

	if over:
		# ONE emission, ever. This used to fire on every gg_skip press once the
		# flight was over, and it was survivable only because the handler ran to
		# completion synchronously inside the emit. main.gd::_on_migration_done()
		# now awaits, which opens a window in which a second press advances the
		# leg twice off one keypress. main.gd carries a `_migration_done` guard
		# as a backstop; a signal that claims to be terminal has to actually be
		# terminal, or the next handler that awaits will rediscover this.
		if not _emitted and Input.is_action_just_pressed("gg_skip"):
			_emitted = true
			finished.emit(distance, TARGET_DISTANCE)
		return

	_honk_cd = maxf(0.0, _honk_cd - delta)
	_thermal_fx = maxf(0.0, _thermal_fx - delta)
	_scar_t = maxf(0.0, _scar_t - delta)
	_tick_distress(delta)
	if _msg_t > 0.0:
		_msg_t -= delta
		if _msg_t <= 0.0:
			_msg = ""

	# Keep the formation framed no matter what altitude the player picks.
	_cam.position.y = lerpf(_cam.position.y, player_pos.y + 1.6, clampf(3.0 * delta, 0.0, 1.0))

	_tick_player(delta)
	_tick_birds(delta)
	_tick_stamina(delta)
	_tick_world(delta)
	_tick_lead_rotation()
	_tick_hud()

	# Formation drag: a ragged V costs you speed, which costs you distance.
	speed = BASE_SPEED * lerpf(0.55, 1.15, integrity)
	distance += speed * delta * 0.6

	if distance >= TARGET_DISTANCE:
		_finish()
	elif _flock_exhausted():
		_say("THE FLOCK IS DONE. PUTTING DOWN.", 2.0)
		_finish()


## The migration builds its own Camera3D rather than using goose_camera.gd, so
## without this every Juice.shake() fired during the flight would be silently
## discarded — the bus would fill and decay with nobody reading it. Same 0.06
## conversion and the same bus as the zone rig, so a shake means the same thing
## in both halves of the game.
func _tick_shake() -> void:
	if _cam == null or not is_instance_valid(_cam):
		return
	var s := Juice.shake_value() * 0.06
	if s > 0.0001:
		_cam.h_offset = randf_range(-s, s)
		_cam.v_offset = randf_range(-s, s)
	else:
		_cam.h_offset = 0.0
		_cam.v_offset = 0.0


func _tick_player(delta: float) -> void:
	var v := Input.get_vector("gg_left", "gg_right", "gg_forward", "gg_back")
	var lift := 0.0
	if Input.is_action_pressed("gg_flap"):
		lift += 1.0
	if Input.is_action_pressed("gg_dive"):
		lift -= 1.4

	player_pos.x = clampf(player_pos.x + v.x * 17.0 * delta, -CORRIDOR_X, CORRIDOR_X)
	player_pos.y = clampf(player_pos.y + lift * 13.0 * delta - 1.6 * delta, Y_MIN, Y_MAX)
	player_pos.z = clampf(player_pos.z + v.y * 9.0 * delta, -6.0, 14.0)

	if Input.is_action_just_pressed("gg_honk") and _honk_cd <= 0.0:
		_honk_cd = 0.7
		_rally()


## Honk the worst drifter back into its slot. Attention management, not combat.
func _rally() -> void:
	var worst = null
	var worst_d := 0.0
	for b in birds:
		if b.idx == player_bird_index:
			continue
		var d: float = b.drift.length()
		if d > worst_d:
			worst_d = d
			worst = b
	if worst and worst_d > 0.4:
		worst.drift *= 0.15
		_say("%s, GET BACK IN LINE" % Flock.birds[worst.idx].name.to_upper(), 1.2)
	else:
		_say("HONK", 0.5)


func _tick_birds(delta: float) -> void:
	var total_err := 0.0
	var count := 0

	for b in birds:
		var bird: Dictionary = Flock.birds[b.idx]
		var slot_pos := _slot_position(b.slot)

		# Wings first, and for EVERY bird — the player branch below `continue`s,
		# so anything placed after it silently skips your own goose, which is the
		# one the camera is closest to.
		_animate_bird(b, delta)

		if b.idx == player_bird_index:
			# The player's own bird. When leading, you ARE the point and the
			# formation forms around you. When drafting, you must HOLD your slot.
			b.node.position = player_pos
			if not player_leads:
				var err := Vector2(player_pos.x - slot_pos.x, player_pos.z - slot_pos.z).length()
				total_err += clampf(err / SLOT_RADIUS, 0.0, 2.0)
				count += 1
			continue

		# Drift scales with how wrecked the bird is. Sober birds hold station.
		var wobble: float = bird.intox * 2.4 + (0.25 if bird.stamina < 0.3 else 0.0)
		var t := float(Time.get_ticks_msec()) * 0.001
		b.drift = b.drift.lerp(Vector3(
			sin(t * 1.3 + b.seed.x) * wobble,
			cos(t * 0.9 + b.seed.y) * wobble * 0.7,
			sin(t * 0.7 + b.seed.z) * wobble * 0.8
		), 1.0 - pow(0.2, delta))

		var target: Vector3 = slot_pos + b.drift
		if player_leads:
			target += Vector3(player_pos.x, player_pos.y, 0.0) * 0.92
			target.y = lerpf(target.y, player_pos.y, 0.85)
		else:
			# An AI lead flies its own wandering line and everyone follows it.
			target += _ai_lead_offset()

		b.node.position = b.node.position.lerp(target, clampf(3.4 * delta, 0.0, 1.0))

		var e: float = b.drift.length() / SLOT_RADIUS
		total_err += clampf(e, 0.0, 2.0)
		count += 1

		# Bank into the drift so the formation reads as alive. Deliberately the
		# WRAPPER node and not visual.set_bank(): animate()'s airborne branch
		# lerps body.rotation.z toward zero every frame it runs, so a set_bank()
		# issued after it is a tug-of-war between two lerps on one property and
		# settles at well under the angle it was asked for. The wrapper is a
		# transform animate() never touches, so this number means what it says.
		b.node.rotation.z = clampf(-b.drift.x * 0.12, -0.5, 0.5)

	var err_avg: float = (total_err / float(count)) if count > 0 else 0.0
	integrity = lerpf(integrity, clampf(1.0 - err_avg * 0.7, 0.05, 1.0), 1.0 - pow(0.1, delta))


## Drive one bird's own visual.
##
## Nothing in this file called animate() for the entire life of the flight. The
## visuals build their wings extended and dead level and then never move them
## again unless somebody ticks them, so a 75-second sequence whose entire subject
## is a flock of geese was flown by a formation of rigid planks. Fixed here
## rather than by hand-rotating a wing, because both models already own the fold,
## the flap, the trailing hand, the leg tuck, the neck bob and the tail sway, and
## the API is identical across the pair by contract.
##
## `airborne` is true and `ground_speed` is 0: these birds never touch ground,
## and the not-airborne branch would bob the body and cycle the feet against
## nothing.
##
## `flapping` is a per-bird sine and not a constant because it sets the wingbeat
## RATE as well as its depth (lerpf(6.0, 20.0, flapping) in both files), so one
## shared value puts every goose on the same wing at the same instant — which
## reads as one goose drawn nine times, which is worse than not animating them.
## Keyed off b.seed, which already exists to desynchronise the drift.
##
## The lead gets a floor under it. That is this file's entire thesis — the point
## of the V burns far more energy — and it costs one maxf. It is decoration, not
## information: the roster strip is where stamina is actually read.
func _animate_bird(b: Dictionary, delta: float) -> void:
	var vis: Node3D = b.vis
	if vis == null or not is_instance_valid(vis) or not vis.has_method("animate"):
		return
	var t := float(Time.get_ticks_msec()) * 0.001
	var flap: float = 0.30 + 0.26 * sin(t * 1.7 + b.seed.x)
	if b.idx == lead_index:
		flap = maxf(flap, 0.66)
	vis.animate(delta, clampf(flap, 0.0, 1.0), 0.0, true)


func _ai_lead_offset() -> Vector3:
	var t := float(Time.get_ticks_msec()) * 0.0006
	var lead_intox: float = Flock.birds[lead_index].intox if lead_index >= 0 else 0.0
	var amp := 5.0 + lead_intox * 9.0
	return Vector3(sin(t * 1.7) * amp, 18.0 + cos(t * 1.1) * 3.0, 0.0)


func _tick_stamina(delta: float) -> void:
	for b in birds:
		var bird: Dictionary = Flock.birds[b.idx]
		var is_lead: bool = b.idx == lead_index
		var rate: float = DRAIN_LEAD if is_lead else DRAIN_DRAFT
		# A ragged formation means nobody gets a clean draft.
		if not is_lead:
			rate *= lerpf(0.2, 1.0, integrity)
		bird.stamina = clampf(bird.stamina - rate * delta, 0.0, 1.0)
		# Being wrecked burns you out faster.
		bird.stamina = clampf(bird.stamina - bird.intox * 0.012 * delta, 0.0, 1.0)
		# And it wears off slowly in the cold air.
		bird.intox = maxf(0.0, bird.intox - 0.02 * delta)


func _tick_lead_rotation() -> void:
	if not Input.is_action_just_pressed("gg_share"):
		return

	if player_leads:
		var cands := Flock.lead_candidates().filter(func(i): return i != player_bird_index)
		if cands.is_empty():
			# THE punish. Everyone's too wrecked to take a shift, so you keep
			# burning. This is the bill for the last zone arriving.
			#
			# TIER 2, and the one refusal in the flight that gets a shake. The
			# message alone made the single most consequential moment in the
			# migration land as a line of text; a jolt turns "nothing happened"
			# into "something was denied". No hitstop — nothing was hit.
			_say("NOBODY CAN TAKE THE POINT — you're on your own", 2.6)
			Juice.shake(0.25)
			if player_node != null and is_instance_valid(player_node):
				Juice.floating_text(player_node.global_position + Vector3.UP * 1.6,
					"NOBODY'S FIT", Color(1.0, 0.42, 0.36))
			return
		# Hand off to the freshest eligible bird.
		var best: int = cands[0]
		for i in cands:
			if Flock.birds[i].stamina > Flock.birds[best].stamina:
				best = i
		lead_index = best
		player_leads = false
		_reassign_slots()
		var tag := " (the DD)" if Flock.birds[best].is_dd else ""
		_say("%s TAKES THE POINT%s — hold your slot" % [Flock.birds[best].name.to_upper(), tag], 2.6)
		# TIER 0. The handoff is the mechanic the whole flight is built around
		# and it was invisible — the V silently reshuffled and a line of text
		# changed. Popping the bird that steps up points straight at it, which
		# is the information the player actually needs. A success, so no shake.
		_mark_lead(best, Color(0.62, 0.92, 1.0))
	else:
		if Flock.birds[player_bird_index].stamina < 0.2:
			_say("TOO GASSED TO LEAD", 1.6)
			return
		lead_index = player_bird_index
		player_leads = true
		_reassign_slots()
		_say("YOU TAKE THE POINT BACK", 1.8)
		_mark_lead(player_bird_index, Color(1.0, 0.86, 0.42))


## Point at whichever bird just took the front of the V.
func _mark_lead(idx: int, tint: Color) -> void:
	for b in birds:
		if b.idx != idx:
			continue
		var node: Node3D = b.node
		if node == null or not is_instance_valid(node):
			return
		Juice.pop(node, 0.28, 0.26)
		Juice.burst(node.global_position + Vector3.UP * 0.4, tint, 9, &"sparkle")
		return


## Is this Flock index the player's own bird?
##
## Both halves matter and they are not the same question. `player_bird_index` is
## what the formation, the HUD and the stamina loop steer; `Flock.player_index`
## is what `Flock.lose_bird()` refuses to kill. _spawn_flock() sets them equal,
## and this keeps the COLLISION code correct even if they ever diverge again —
## sending a bird down the loss path that Flock will silently refuse to lose is
## exactly how you strand a living roster entry with no goose flying it.
func _is_player_bird(idx: int) -> bool:
	return idx == player_bird_index or idx == Flock.player_index


func _flock_exhausted() -> bool:
	for b in birds:
		if Flock.birds[b.idx].stamina > 0.02:
			return false
	return true


# ---------------------------------------------------------------- world

func _tick_world(delta: float) -> void:
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		_spawn_t = randf_range(1.1, 2.1)
		if randf() < 0.62:
			_spawn_obstacle()
		else:
			_spawn_thermal()

	var dz := speed * delta

	for cl in _clouds:
		cl.position.z += dz * 0.55
		if cl.position.z > 60.0:
			cl.position.z -= 960.0
			cl.position.x = randf_range(-90, 90)
			cl.position.y = randf_range(-16, 44)

	for i in range(_obstacles.size() - 1, -1, -1):
		var o: Dictionary = _obstacles[i]
		o.node.position.z += dz
		if o.node.position.z > 26.0:
			o.node.queue_free()
			_obstacles.remove_at(i)
			continue
		# The blades turn for the whole approach. This used to live inside
		# _check_obstacle(), which returns immediately unless the tower is within
		# 7 units of the formation plane — so a turbine spawned 230 units out was
		# a frozen three-blade rotor for several hundred frames, snapped into
		# motion for the ~30 frames it was already on top of you, then froze
		# again on the way out. A stationary rotor reads as scenery; the motion IS
		# the warning, and the warning has to arrive while there is still time to
		# steer. Uses the loop's own `delta` rather than
		# get_process_delta_time() — same number, but this one is passed in.
		if o.kind == "turbine" and o.has("hub"):
			o.hub.rotate_z(delta * 2.2)
		_check_obstacle(o)

	for i in range(_thermals.size() - 1, -1, -1):
		var th: Dictionary = _thermals[i]
		th.node.position.z += dz
		# Per RING, not per node. The rings are arrayed along Z now, so spinning
		# their shared parent would swing them out of the corridor and around
		# each other instead of turning each hoop on the spot. Same 0.8 rate.
		var rings: Array = th.rings
		for r in rings:
			r.rotate_y(delta * 0.8)
		if th.node.position.z > 26.0:
			th.node.queue_free()
			_thermals.remove_at(i)
			continue
		_check_thermal(th)


func _spawn_obstacle() -> void:
	var kind := randi() % 3
	var n := Node3D.new()
	add_child(n)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.16, 0.20)

	if kind == 0:
		# Transmission tower with lines strung across a gap.
		var x := randf_range(-8.0, 8.0)
		for s in [-1.0, 1.0]:
			var pole := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(1.0, 34.0, 1.0)
			pole.mesh = bm
			pole.material_override = mat
			pole.position = Vector3(x + s * 11.0, 12.0, 0)
			n.add_child(pole)
		for k in 3:
			var wire := MeshInstance3D.new()
			var wb := BoxMesh.new()
			wb.size = Vector3(22.0, 0.16, 0.16)
			wire.mesh = wb
			wire.material_override = mat
			wire.position = Vector3(x, 20.0 + k * 3.0, 0)
			n.add_child(wire)
		n.position = Vector3(0, 0, -230.0)
		# `resolved` — see _check_obstacle(). A wire is a single-strike hazard and
		# nothing here used to say so.
		_obstacles.append({"node": n, "kind": "wires", "x": x, "half": 11.0, "ymin": 19.0,
			"ymax": 27.0, "resolved": false})
		return

	elif kind == 1:
		# Wind turbine. Rotates. Genuinely a real hazard for migrating birds.
		var x := randf_range(-11.0, 11.0)
		var tower := MeshInstance3D.new()
		var cb := CylinderMesh.new()
		cb.top_radius = 0.5
		cb.bottom_radius = 0.9
		cb.height = 40.0
		tower.mesh = cb
		tower.material_override = mat
		tower.position = Vector3(0, 6.0, 0)
		n.add_child(tower)
		var hub := Node3D.new()
		hub.position = Vector3(0, 26.0, 0)
		hub.name = "Hub"
		n.add_child(hub)
		for k in 3:
			var blade := MeshInstance3D.new()
			var bb := BoxMesh.new()
			bb.size = Vector3(1.2, 15.0, 0.3)
			blade.mesh = bb
			blade.material_override = mat
			blade.position = Vector3(0, 7.5, 0)
			var pivot := Node3D.new()
			pivot.rotation.z = TAU * float(k) / 3.0
			pivot.add_child(blade)
			hub.add_child(pivot)
		n.position = Vector3(x, 0, -230.0)
		_obstacles.append({"node": n, "kind": "turbine", "x": x, "half": 8.0, "ymin": 19.0,
			"ymax": 33.0, "hub": hub, "resolved": false})
		return

	else:
		# Headwind band — no collision, just a wall of drag.
		var band := MeshInstance3D.new()
		var pm := BoxMesh.new()
		# 14 deep, not 2, because 14 is the depth of the window _check_obstacle
		# gates it with (|z| <= 7). At 2 the slab was a red sheet that had already
		# gone past you for most of the time the drag was running and the HEADWIND
		# caption was up: the one hazard in the flight whose whole job is "get out
		# of the visible thing" was draining stamina several bird-lengths either
		# side of anything visible, which reads as random attrition rather than as
		# a rule. Growing the geometry to the trigger keeps the total cost of a
		# band identical — same window, same seconds, same drag — while making it
		# a volume you are demonstrably inside.
		pm.size = Vector3(30.0, 22.0, 14.0)
		band.mesh = pm
		var bm2 := StandardMaterial3D.new()
		bm2.albedo_color = Color(0.95, 0.34, 0.30, 0.16)
		bm2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bm2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		band.material_override = bm2
		n.add_child(band)
		var yy := randf_range(10.0, 28.0)
		n.position = Vector3(0, yy, -230.0)
		# NO `resolved` key, on purpose: drag is a continuous state and re-firing
		# every frame is the correct behaviour for it. The flag exists to stop
		# single-strike hazards billing you twice; this one is not one.
		_obstacles.append({"node": n, "kind": "wind", "x": 0.0, "half": 15.0, "ymin": yy - 11.0, "ymax": yy + 11.0})
		return


func _spawn_thermal() -> void:
	## Rising air. Free altitude and a breather — the reward for reading the sky.
	##
	## The rings used to stack in Y at 0/3/6, while the trigger that gates them is
	## a 4.4 m circle in XY extruded +/-6 along Z (_check_thermal). Two of the
	## three hoops therefore sat outside the volume they were drawing, and the
	## whole column had no depth at all in the one axis this flight travels
	## along — so RIDING THE THERMAL came up and stamina came back while the
	## rings were still several bird-lengths ahead of the flock. A reward the
	## player cannot correlate with anything on screen is not a rule they can
	## learn, it is just a number twitching.
	##
	## Arrayed along Z, they are the tunnel the code was already testing for, and
	## pushing the tube out to a 4.4 outer radius makes the hoop you fly through
	## the literal edge of the trigger. No gameplay number moved: same radius,
	## same window, same regen rate. Only the thing you can see moved.
	var n := Node3D.new()
	add_child(n)
	var rings: Array[Node3D] = []
	for k in 3:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 3.9
		tm.outer_radius = 4.4
		ring.mesh = tm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 0.86, 0.35, 0.5)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring.material_override = m
		# Hole down Z: a gate you fly through, not a hoop you look at edge-on.
		ring.rotation.x = PI * 0.5
		# Started out of phase so the three shimmer independently under the spin
		# in _tick_world rather than turning edge-on together as one object.
		ring.rotation.y = float(k) * 0.9
		ring.position.z = -5.0 + float(k) * 5.0
		n.add_child(ring)
		rings.append(ring)
	n.position = Vector3(randf_range(-11, 11), randf_range(9, 26), -230.0)
	_thermals.append({"node": n, "rings": rings})


## Where this flight is happening, for a scar or a loss line.
func _where() -> String:
	var i: int = clampi(Flock.leg - 1, 0, FLIGHT_PLACES.size() - 1)
	return str(FLIGHT_PLACES[i])


func _check_obstacle(o: Dictionary) -> void:
	if absf(o.node.position.z + (0.0)) > 7.0:
		return  # only test near the formation plane

	# Already collected its toll. See the `resolved` block below.
	if bool(o.get("resolved", false)):
		return

	# Collect the casualty and remove it AFTER the loop. Array.erase() on a
	# Dictionary matches by deep value comparison in GDScript, which could
	# delete the wrong bird if two ever held identical data.
	var casualty := -1
	for bi in birds.size():
		var b: Dictionary = birds[bi]
		var p: Vector3 = b.node.position
		var hit := false
		match o.kind:
			"wires":
				hit = absf(p.x - o.x) < o.half and p.y > o.ymin and p.y < o.ymax
			"turbine":
				# No upper bound, so `o.ymax` is not read for this kind. That is
				# deliberate rather than an oversight: the rotor is a 15 m blade
				# swung off a hub at y = 26, so the swept disc reaches roughly
				# y = 41 and no altitude inside Y_MAX (34) clears it. A ceiling
				# here would be fiction.
				hit = absf(p.x - o.x) < 8.0 and p.y > o.ymin
			"wind":
				if p.y > o.ymin and p.y < o.ymax:
					Flock.birds[b.idx].stamina = maxf(0.0, Flock.birds[b.idx].stamina - 0.30 * get_process_delta_time())
					if _is_player_bird(b.idx):
						_say("HEADWIND — climb or drop out of it", 0.5)
		if hit:
			# ONE strike, ONE bill. _check_obstacle runs every frame the obstacle
			# spends inside the z window — 20 to 40 of them — and until this line
			# nothing stopped the same wire charging again on the next one. The
			# only brake was the 3 m altitude drop, so a player clip repeated 3-6
			# times: three to six shakes, three to six scars (each of which
			# permanently tightens Flock.can_lead), the entire stamina bar, and 45
			# to 90 feathers through a 14-emitter pool that then had nothing left
			# for anything else in the flight. The flock branch was worse — it
			# takes one bird and returns, so a turbine parked over the formation
			# removed a DIFFERENT goose every frame until the V was gone.
			#
			# A wire is designed as TIER 2 and a loss as TIER 3-and-rare; this
			# makes one strike cost what one strike was always meant to cost. It
			# is not a rebalance in the other direction either: nothing here is
			# softened, the same hit still lands, it just lands once.
			o["resolved"] = true
			var sfx := get_node_or_null("/root/Sfx")
			var where: Vector3 = b.node.global_position
			if _is_player_bird(b.idx):
				Flock.birds[b.idx].stamina = maxf(0.0, Flock.birds[b.idx].stamina - 0.22)
				integrity = maxf(0.05, integrity - 0.25)
				# You lived. That is what a scar is: the near miss that stayed on
				# the bird. Your own goose can never be lost, so a strike is the
				# only permanent mark it can carry out of a flight.
				Flock.scar_bird(b.idx, "%s over %s" % [
					"took a turbine blade" if o.kind == "turbine" else "clipped a wire",
					_where()])
				_say("YOU CLIPPED IT", 1.2)
				player_pos.y = clampf(player_pos.y - 3.0, Y_MIN, Y_MAX)
				# TIER 2. Clipping a wire costs stamina, formation and altitude
				# all at once and had exactly one thin sound to say so. It gets
				# a real hit — but NO hitstop: the flight is a long, smooth,
				# low-input sequence, and a freeze frame in the middle of it
				# reads as the game hitching, not as impact.
				Juice.shake(0.45)
				# Counts run ~25% above their zone equivalents throughout the
				# migration: the flight camera sits roughly twice as far back as
				# the chase rig, and a render pass showed the same burst reading
				# as a few specks out here. Density is the only lever burst()
				# exposes for apparent size.
				Juice.burst(where, Color(0.94, 0.94, 0.92), 15, &"feathers")
				Juice.floating_text(where + Vector3.UP * 1.2, "CLIPPED IT",
					Color(1.0, 0.52, 0.34))
				if sfx:
					sfx.play(&"crash_light", -2.0)
			else:
				var nm: String = Flock.birds[b.idx].name
				var lost_idx: int = b.idx
				# The roster screen reads this back. A loss the player can name
				# the cause of is a story; a gap in a list is a bug report.
				Flock.lose_bird(lost_idx, "%s over %s" % [
					"went into a turbine" if o.kind == "turbine" else "flew into a wire",
					_where()])
				_say("%s IS DOWN" % nm.to_upper(), 2.4)
				# TIER 3, and the fifth and last hitstop site in the game.
				# Losing a bird is the only PERMANENT loss in a run — it is
				# gone from the flock for good — and it happens at most a
				# couple of times across a whole migration. That rarity is
				# exactly what earns the freeze. Sited below the faceplant,
				# above the player's own clip, because the player caused this
				# by flying a ragged formation and should feel it land.
				Juice.hitstop(0.06, 0.75)
				Juice.shake(0.55)
				Juice.burst(where, Color(0.94, 0.94, 0.92), 18, &"feathers")
				Juice.floating_text(where + Vector3.UP * 1.4,
					"%s IS DOWN" % nm.to_upper(), Color(1.0, 0.38, 0.34))
				b.node.queue_free()
				casualty = bi
				if sfx:
					sfx.play(&"honk_angry", -4.0, 0.7)
				if lead_index == lost_idx:
					lead_index = player_bird_index
					player_leads = true
			break

	if casualty >= 0:
		birds.remove_at(casualty)
		_reassign_slots()
		return


func _check_thermal(th: Dictionary) -> void:
	if absf(th.node.position.z) > 6.0:
		return
	var p := player_pos
	var c: Vector3 = th.node.position
	if Vector2(p.x - c.x, p.y - c.y).length() < 4.4:
		var b := Flock.birds[player_bird_index]
		b.stamina = clampf(b.stamina + 0.9 * get_process_delta_time(), 0.0, 1.0)
		integrity = minf(1.0, integrity + 0.25 * get_process_delta_time())
		_say("RIDING THE THERMAL", 0.4)
		# TIER 0. A reward, so: light, no shake. It is also a CONTINUOUS state
		# rather than an event, which is the trap here — fired every frame this
		# would burn the 14-emitter pool three times a second and starve every
		# real impact in the flight. Throttled to a heartbeat instead, which
		# also reads better: warm air arriving in pulses.
		if _thermal_fx <= 0.0 and player_node != null and is_instance_valid(player_node):
			_thermal_fx = 0.32
			Juice.burst(player_node.global_position + Vector3.DOWN * 0.6,
				Color(1.0, 0.86, 0.35), 7, &"sparkle")


# ---------------------------------------------------------------- hud + end

func _tick_hud() -> void:
	var lead_name: String = "YOU" if player_leads else Flock.birds[lead_index].name.to_upper()
	_lbl_top.text = "MIGRATION — LEG %d → %d    POINT: %s" % [Flock.leg, Flock.leg + 1, lead_name]
	_lbl_mid.text = _msg

	var me: Dictionary = Flock.birds[player_bird_index]
	var cands := Flock.lead_candidates().filter(func(i): return i != player_bird_index)
	_lbl_bot.text = "YOUR STAMINA %d%%    FORMATION %d%%    FLOCK %d    FIT TO LEAD: %d\n%s" % [
		int(me.stamina * 100.0), int(integrity * 100.0), birds.size(), cands.size(),
		"WASD steer · SPACE climb · SHIFT drop · [Q] hand off the point · [H] honk a drifter back into line"
	]
	if _bar:
		_bar.queue_redraw()
	if _roster:
		_roster.refresh(birds.size())


## A bird flying on fumes calls for help, once every DISTRESS_EVERY seconds and
## never per-frame. The strip flashes the same bird at the same moment, so the
## sound sends you looking and the strip answers — the audio alone would just be
## an unexplained honk, and the flashing alone is easy to miss while you are
## watching the formation.
func _tick_distress(delta: float) -> void:
	_distress_t = maxf(0.0, _distress_t - delta)
	if _distress_t > 0.0:
		return
	for b in birds:
		var idx: int = b.idx
		if _is_player_bird(idx):
			continue
		if float(Flock.birds[idx].stamina) >= DISTRESS_STAMINA:
			continue
		_distress_t = DISTRESS_EVERY
		var sfx := get_node_or_null("/root/Sfx")
		if sfx:
			sfx.play(&"honk_c", -14.0, 1.18)
		return


## Everyone still airborne who arrived on fumes gets marked for it. Run once,
## from _finish(), rather than per-frame off a stamina threshold: a bird hovering
## either side of 0.1 for thirty seconds is one story, not thirty.
func _scar_the_spent() -> void:
	var place := _where()
	for b in birds:
		var idx: int = b.idx
		if idx < 0 or idx >= Flock.birds.size():
			continue
		var rec: Dictionary = Flock.birds[idx]
		if float(rec.get("stamina", 1.0)) > SPENT_STAMINA:
			continue
		Flock.scar_bird(idx, "flew the last of it on empty over %s" % place)


func _finish() -> void:
	if over:
		return
	over = true
	_scar_the_spent()
	var sfx := get_node_or_null("/root/Sfx")
	if sfx:
		sfx.stop_loop(&"wind")
	var pct := clampf(distance / TARGET_DISTANCE, 0.0, 1.0)
	var verdict := "MADE IT" if pct >= 0.999 else "LANDED SHORT"
	_lbl_mid.text = "%s\n%d / %d km\n%s\n\n[ENTER]" % [
		verdict, int(distance), int(TARGET_DISTANCE), Flock.condition_summary()]
	_lbl_top.text = ""


class ProgressPanel extends Control:
	var mig: Node

	func _draw() -> void:
		if mig == null:
			return
		var font := ThemeDB.fallback_font
		draw_rect(Rect2(0, 8, size.x, 16), Color(0, 0, 0, 0.55), true)
		var pct: float = clampf(mig.distance / maxf(mig.target_distance, 1.0), 0.0, 1.0)
		draw_rect(Rect2(0, 8, size.x * pct, 16), Color(0.98, 0.74, 0.32), true)
		draw_rect(Rect2(0, 8, size.x, 16), Color(0.8, 0.82, 0.88, 0.7), false, 1.0)
		draw_string(font, Vector2(0, 4), "%d km" % int(mig.distance),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.9, 0.92, 0.96))
		draw_string(font, Vector2(0, 4), "%d km" % int(mig.target_distance),
			HORIZONTAL_ALIGNMENT_RIGHT, size.x, 12, Color(0.9, 0.92, 0.96))


## THE FLOCK ROSTER STRIP — CAMPAIGN_SPEC §4.7.
##
## Before this the flight told you a flock COUNT and nothing else, so attrition
## was invisible until a bird was already gone: every loss read as arbitrary,
## the honk-rescue was undiscoverable because you could not see who was
## drifting, and the hand-off decision was made blind. One row per bird, always
## in Flock-index order so the strip is re-read rather than re-parsed, and every
## channel redundant per DESIGN_MISSIONS.md §7 — shapes not glyphs, bars beside
## numbers, never hue on its own:
##
##   gold left edge     your own bird, plus a lifted row band
##   ▶ filled triangle   holds the point right now
##   ▷ hollow triangle   fit to take a shift  (Flock.can_lead)
##     nothing           too wrecked or too tired to lead
##   ● after the name    the DD's vest, as a shape
##   ▲ flashing          under DISTRESS_STAMINA — matches the distress honk
##   · · ·               one pip per scar (Flock scar log, capped at 3)
##
## Stamina is the ten-segment bar AND the number beside it AND the bar colour,
## so it survives colour-blindness, a small window and peripheral vision.
## Intoxication tints the NAME and, past 0.6, makes it sway — the bar is
## stamina's channel alone and the two must not collide.
##
## Everything here reads Flock and the parent migration directly and draws in
## one pass; there is no per-bird node, because this thing is rebuilt from
## scratch every frame of a 75-second sequence.
class RosterStrip extends Control:
	var mig: Node
	var rows := -1

	const ROW_H := 19.0
	const PAD := 6.0
	const HEAD_H := 15.0
	const CAP_H := 14.0
	const W := 352.0

	const X_MARK := 9.0
	const X_NAME := 20.0
	const X_VEST := 120.0
	const X_BAR := 134.0
	const BAR_W := 100.0
	const SEGS := 10
	const X_PCT := 240.0
	const X_WARN := 278.0
	const X_PIPS := 300.0
	const X_TAG := 300.0

	const C_OK := Color(0.55, 0.88, 0.52)
	const C_LOW := Color(0.99, 0.76, 0.34)
	const C_BAD := Color(0.96, 0.40, 0.36)
	const C_DIM := Color(0.62, 0.66, 0.74)
	const C_GOLD := Color(0.99, 0.80, 0.30)
	const C_DD := Color(0.55, 0.86, 1.00)

	## Resize to the living flock. Called every frame; only does work when the
	## count actually changed, which is at most a couple of times a flight.
	func refresh(n: int) -> void:
		if n != rows:
			rows = n
			var h := PAD * 2.0 + HEAD_H + CAP_H + ROW_H * float(maxi(n, 1))
			custom_minimum_size = Vector2(W, h)
			# OFFSETS, not `position`. With PRESET_BOTTOM_LEFT the anchors are
			# (0, 1, 0, 1), and `Control.position` is the rect relative to the
			# PARENT — so assigning it after add_child() back-solves an offset
			# against the live 720 px parent and parks the strip 267 px above
			# the top of the screen. (`_lbl_bot` above gets away with the same
			# assignment only because it makes it while the label is still
			# parentless and the anchor therefore resolves against zero.) The
			# offsets are what the anchor is measured from and they mean the
			# same thing either side of add_child(). Sits directly above the
			# stamina/formation line at -104.
			offset_left = 20.0
			offset_top = -112.0 - h
			offset_right = offset_left + W
			offset_bottom = offset_top + h
		queue_redraw()


	func _draw() -> void:
		if mig == null or not is_instance_valid(mig):
			return
		var list: Array = mig.birds
		if list.is_empty():
			return
		var font := ThemeDB.fallback_font
		var lead: int = mig.lead_index
		var me: int = mig.player_bird_index
		var t := float(Time.get_ticks_msec()) * 0.001

		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.05, 0.55), true)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.70, 0.74, 0.82, 0.22), false, 1.0)

		# ── header: the count, and how many are carrying something ──────
		var scarred: int = Flock.scarred_count()
		var head := "FLOCK  %d" % list.size()
		if scarred > 0:
			head += "   ·   %d SCARRED" % scarred
		_txt(font, Vector2(X_MARK, PAD + 11.0), head, 11, C_DIM)

		var y := PAD + HEAD_H
		for r in list.size():
			var b: Dictionary = list[r]
			var idx: int = b.idx
			if idx < 0 or idx >= Flock.birds.size():
				continue
			var rec: Dictionary = Flock.birds[idx]
			var stam: float = clampf(float(rec.get("stamina", 1.0)), 0.0, 1.0)
			var intox: float = clampf(float(rec.get("intox", 0.0)), 0.0, 1.0)
			var base := y + ROW_H * float(r)
			var mid := base + ROW_H * 0.5

			# The player's own row gets a value band, not a colour: you have to
			# be able to find yourself in one glance and hue is already spoken
			# for twice over.
			if idx == me:
				draw_rect(Rect2(1.0, base + 1.0, size.x - 2.0, ROW_H - 2.0),
					Color(1.0, 1.0, 1.0, 0.08), true)
				draw_rect(Rect2(1.0, base + 1.0, 3.0, ROW_H - 2.0),
					Color(0.99, 0.86, 0.42, 0.95), true)

			# ── lead marker ─────────────────────────────────────────────
			if idx == lead:
				_tri(Vector2(X_MARK, mid), 5.0, C_GOLD, true)
			elif Flock.can_lead(idx):
				_tri(Vector2(X_MARK, mid), 5.0, Color(0.70, 0.78, 0.88, 0.75), false)

			# ── name: intox tints it, and past 0.6 it sways ─────────────
			var name_col := Color(0.94, 0.96, 1.0).lerp(Color(0.88, 0.52, 0.98), intox)
			var sway := 0.0
			if intox > 0.6:
				sway = sin(t * 5.0 + float(r) * 1.7) * (intox - 0.6) * 5.0
			# No "(YOU)" suffix: the names are drawn from a shuffled pool and
			# "STOMPIN' TOM (YOU)" runs straight through the DD vest and into
			# the bar. The player's row is marked by the band and the gold edge
			# instead, which cost no width at all. Everything still gets clipped
			# to the name column, because the pool is data and the next name
			# added to it will be longer than the one that fit.
			var nm := String(rec.get("name", "?")).to_upper()
			var name_w := X_VEST - X_NAME - 6.0
			while nm.length() > 3 and \
					font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x > name_w:
				nm = nm.substr(0, nm.length() - 1)
			_txt(font, Vector2(X_NAME + sway, mid + 4.0), nm, 12, name_col)

			if bool(rec.get("is_dd", false)):
				draw_circle(Vector2(X_VEST, mid - 1.0), 4.0, C_DD)
				draw_arc(Vector2(X_VEST, mid - 1.0), 5.5, 0.0, TAU, 12,
					Color(0.10, 0.14, 0.20, 0.9), 1.5)

			# ── stamina: ten segments, plus the number ──────────────────
			var col := C_BAD if stam < 0.25 else (C_LOW if stam < 0.5 else C_OK)
			var filled: int = int(ceil(stam * float(SEGS) - 0.0001))
			var seg_w := BAR_W / float(SEGS)
			for s in SEGS:
				var rect := Rect2(X_BAR + seg_w * float(s) + 1.0, mid - 5.0,
					seg_w - 2.0, 10.0)
				if s < filled:
					draw_rect(rect, col, true)
				else:
					draw_rect(rect, Color(0.55, 0.58, 0.66, 0.30), true)
			_txt(font, Vector2(X_PCT, mid + 4.0), "%3d%%" % int(round(stam * 100.0)),
				11, col)

			# ── distress: a drawn triangle, flashing, never a glyph ─────
			var tagged := false
			if stam < DISTRESS_STAMINA:
				var pulse := 0.45 + 0.55 * absf(sin(t * 4.2))
				_warn(Vector2(X_WARN, mid), 6.5, Color(C_BAD.r, C_BAD.g, C_BAD.b, pulse))
			# ── tag column: LEAD beats DD, and a pip per scar under it ──
			if idx == lead:
				_txt(font, Vector2(X_TAG, mid + 4.0), "LEAD", 11, C_GOLD)
				tagged = true
			elif bool(rec.get("is_dd", false)):
				_txt(font, Vector2(X_TAG, mid + 4.0), "DD", 11, C_DD)
				tagged = true
			var scars: int = mini(int(rec.get("scars", 0)), 3)
			for s2 in scars:
				var py := mid + (7.0 if tagged else 0.0)
				draw_circle(Vector2(X_PIPS + 6.0 * float(s2) + 3.0, py), 1.8,
					Color(0.98, 0.62, 0.42, 0.95))

		# ── caption: the most recent near-miss, by name, then it fades ──
		var cy := size.y - PAD - 2.0
		var si: int = mig._scar_idx
		if mig._scar_t > 0.0 and si >= 0 and si < Flock.birds.size():
			var note := Flock.scar_note(si)
			if note != "":
				var fade: float = clampf(float(mig._scar_t) / 1.2, 0.0, 1.0)
				_txt(font, Vector2(X_MARK, cy), "%s %s" % [
					String(Flock.birds[si].get("name", "?")).to_upper(), note],
					11, Color(0.99, 0.72, 0.50, fade))


	## Outlined text. The strip sits over a sky that runs from near-black to
	## bright horizon in one screen height, so nothing here is legible without.
	func _txt(font: Font, at: Vector2, s: String, px: int, col: Color) -> void:
		draw_string_outline(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, 4,
			Color(0.0, 0.0, 0.0, col.a * 0.85))
		draw_string(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


	## Right-pointing triangle, centred on `at`. Filled = has the point,
	## hollow = could take it.
	func _tri(at: Vector2, r: float, col: Color, filled: bool) -> void:
		var pts := PackedVector2Array([
			at + Vector2(-r * 0.7, -r), at + Vector2(r * 0.9, 0.0),
			at + Vector2(-r * 0.7, r)])
		if filled:
			draw_colored_polygon(pts, col)
		else:
			var loop := pts.duplicate()
			loop.append(pts[0])
			draw_polyline(loop, col, 1.4)


	## The distress mark. A drawn up-triangle with a bar in it — a shape, so it
	## survives a font that has no warning glyph and reads at the edge of vision.
	func _warn(at: Vector2, r: float, col: Color) -> void:
		var pts := PackedVector2Array([
			at + Vector2(0.0, -r), at + Vector2(r * 0.92, r * 0.78),
			at + Vector2(-r * 0.92, r * 0.78)])
		draw_colored_polygon(pts, col)
		draw_line(at + Vector2(0.0, -r * 0.36), at + Vector2(0.0, r * 0.22),
			Color(0.06, 0.05, 0.08, col.a), 1.6)
		draw_line(at + Vector2(0.0, r * 0.44), at + Vector2(0.0, r * 0.52),
			Color(0.06, 0.05, 0.08, col.a), 1.6)
