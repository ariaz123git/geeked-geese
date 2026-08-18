extends Node
## Autoload: Subs
##
## Owns everything chemical: what's active, tolerance, mixing, comedowns, and
## the four neurotransmitter levels the HUD draws.
##
## Everything the goose controller needs is aggregated into `mods` every frame,
## so the controller never asks "am I on berries?" — it only asks "what is my
## input lag right now?". That separation is what lets you add substance #40
## without touching the controller.

signal substance_taken(res: Substance, dose: float, resolved: Dictionary)
signal substance_ended(id: StringName)
signal combo_started(name: String)
signal blackout_started()
signal blackout_ended()

const BASELINE := 0.40
const MAX_STACK := 2  ## Three at once always rolls the bad table.

## Named combos. Most are GOOD — mixing should be exciting, not punished,
## right up until the third one.
const COMBOS := {
	"berries|double_double": {
		"name": "THE WOBBLER",
		"speed_mult": 1.55, "drift": 0.30, "chaos_mult": 2.0, "turn_mult": 1.4,
	},
	"berries|nitrous": {
		"name": "THE DITCH",
		"gravity_mult": 1.7, "ragdoll_landings": true, "chaos_mult": 2.4,
	},
	"double_double|nitrous": {
		"name": "THE OVERCLOCK",
		"time_scale": 0.45, "flap_mult": 1.9, "chaos_mult": 2.2,
	},
	"berries|fly_agaric": {
		"name": "THE LEWIS CARROLL",
		"scale_amp": 1.0, "input_lag": 0.12, "drift": 0.25, "chaos_mult": 2.8,
	},
	"catnip|math": {
		"name": "THE CAT DISTRIBUTION SYSTEM",
		"speed_mult": 1.3, "chaos_mult": 3.0, "aggro_cats": true,
	},
}

var library: Dictionary = {}          ## StringName -> Substance
var actives: Array[Dictionary] = []   ## {res, resolved, t, comedown}
var tolerance: Dictionary = {}        ## StringName -> int
var brain := {"dopamine": BASELINE, "adrenaline": BASELINE, "gaba": BASELINE, "serotonin": BASELINE}
var mods: Dictionary = {}
var active_combo: String = ""
var blacked_out := false

## Bumped whenever a blackout begins AND whenever a leg resets. `_blackout()`
## captures it before its await and refuses to finish if the number has moved
## underneath it. See the comment on the await itself.
var _blackout_gen := 0

var _comedowns: Array[Dictionary] = []  ## {t, strength}


func _ready() -> void:
	_load_library()
	mods = _empty_mods()


func _load_library() -> void:
	var dir := DirAccess.open("res://data/substances")
	if dir == null:
		push_warning("No substance library at res://data/substances")
		return
	for f in dir.get_files():
		var path := "res://data/substances/" + f.trim_suffix(".remap")
		if not path.ends_with(".tres"):
			continue
		var res := load(path)
		if res is Substance:
			library[res.id] = res
	print("[Subs] loaded %d substances: %s" % [library.size(), library.keys()])


func get_substance(id: StringName) -> Substance:
	return library.get(id, null)


## Consume `res` at `dose` (0..1). Returns false if refused.
func take(res: Substance, dose: float) -> bool:
	if blacked_out or res == null:
		return false

	# Already on it? A second dose of the same thing is a TOP-UP, not a no-op.
	#
	# This used to be `a.t = maxf(a.t, a.resolved.duration * 0.8); return true`,
	# and three things were wrong with it. The dose was thrown away, so a
	# perfect sweet spot and a panicked tap had identical effect — none.
	# Tolerance was not charged, and tolerance is the only scarcity this design
	# actually has, since sources respawn on purpose. And `substance_taken`
	# never fired, so the HUD and Mission never saw the dose at all. Meanwhile
	# the caller reads that `true` as success: goose_controller drains the
	# source and pays out 40 chaos for SWEET SPOT. For the entire duration of
	# every substance, the game's only input-timing test was switched off and
	# still paying.
	#
	# Of the three honest readings — refuse the pickup, top up, or force an
	# overdose — this is the top-up. Refusing is silent: the commit sound has
	# already played by the time we get here and the controller has no "that
	# did nothing" beat to show, so the player would learn less than they do
	# now. Forcing an overdose makes touching a source twice always wrong,
	# which deletes a verb rather than teaching one. The top-up keeps the dose
	# curve live in both directions and self-limits using a rule that already
	# exists: the new dose is re-resolved at the CURRENT tolerance and becomes
	# the truth, because the last thing you swallowed is what is in you. So a
	# clean top-up is a genuine refresh, a fumbled one dilutes a good high with
	# a bad one, and spamming one source walks tolerance up until the good half
	# is gone and only the input lag and the comedown are left. That last
	# sentence is the lesson, and it now delivers itself.
	#
	# The clock only ever moves forward (`maxf`) — resolve() shortens duration
	# for a small dose, and a fumbled top-up should not be able to cut short a
	# ride the player has already paid tolerance for.
	for a in actives:
		if a.res.id == res.id:
			var tol_now: int = tolerance.get(res.id, 0)
			var topped := res.resolve(dose, tol_now)
			tolerance[res.id] = tol_now + maxi(1, res.tolerance_gain)
			var left: float = a.t
			var dur: float = topped.duration
			a.resolved = topped
			# THE COMEDOWN ONLY EVER GROWS, for the same reason the clock only
			# ever moves forward one line down.
			#
			# `resolve()` scales comedown by `bad`, and `bad` for an UNDER-band
			# dose is `maxf(0.15, dose / sweet_min)` — as low as 0.15. So a
			# straight assignment let a deliberately tiny top-up ERASE a comedown
			# the player had already earned by overdosing: nibble the source and
			# the bill goes away. That is the exact inverse of the economy this
			# system exists to teach, and it is the kind of thing a player finds
			# in an hour and never tells you about.
			a.comedown = maxf(float(a.comedown), float(topped.comedown))
			a.t = maxf(left, dur)
			substance_taken.emit(res, dose, topped)
			return true

	if actives.size() >= MAX_STACK:
		_blackout()
		return false

	var tol: int = tolerance.get(res.id, 0)
	var resolved := res.resolve(dose, tol)
	# Nicotine gains 3 per dose. That's the whole reason Darts is in the game.
	tolerance[res.id] = tol + maxi(1, res.tolerance_gain)

	actives.append({"res": res, "resolved": resolved, "t": resolved.duration, "comedown": resolved.comedown})
	substance_taken.emit(res, dose, resolved)
	_check_combo()
	return true


func _check_combo() -> void:
	active_combo = ""
	if actives.size() != 2:
		return
	var ids := [String(actives[0].res.id), String(actives[1].res.id)]
	ids.sort()
	var key: String = "|".join(ids)
	if COMBOS.has(key):
		active_combo = key
		combo_started.emit(COMBOS[key].name)


func _blackout() -> void:
	_blackout_gen += 1
	var gen := _blackout_gen
	blacked_out = true
	actives.clear()
	active_combo = ""
	_comedowns.clear()
	blackout_started.emit()
	await get_tree().create_timer(3.0).timeout
	# Those three seconds are wall clock, and the leg is not guaranteed to
	# still be the same one when they are up. Game.start_zone() calls
	# reset_for_new_leg() on every transition, and it lands inside this await
	# for anyone who blacks out in the closing seconds of a leg. Everything
	# below then ran in the NEXT zone: an 8 s comedown worth -31% speed, -35%
	# flap and +0.14 drift, with no on-screen cause anywhere, plus "...ow."
	# floating over a place the player had never been.
	#
	# A parked coroutine cannot be cancelled from outside, so it checks whether
	# it is still the current one instead. reset_for_new_leg() bumps the
	# generation and emits blackout_ended itself, so bailing here leaves
	# nothing half-open — which matters, because music.gd only ever clears its
	# blackout duck on that signal and would otherwise stay muffled for good.
	if gen != _blackout_gen:
		return
	blacked_out = false
	# Wake up rough.
	_comedowns.append({"t": 8.0, "strength": 1.4})
	blackout_ended.emit()


func _process(delta: float) -> void:
	var scaled := delta / maxf(Engine.time_scale, 0.05)  # tick in real seconds

	for i in range(actives.size() - 1, -1, -1):
		var a := actives[i]
		a.t -= scaled
		if a.t <= 0.0:
			_comedowns.append({"t": a.comedown, "strength": 1.0})
			substance_ended.emit(a.res.id)
			actives.remove_at(i)
			_check_combo()

	for i in range(_comedowns.size() - 1, -1, -1):
		_comedowns[i].t -= scaled
		if _comedowns[i].t <= 0.0:
			_comedowns.remove_at(i)

	mods = _aggregate()
	_tick_brain(scaled)
	Engine.time_scale = lerpf(Engine.time_scale, mods.time_scale, 1.0 - pow(0.001, delta))


func _empty_mods() -> Dictionary:
	return {
		"input_lag": 0.0, "drift": 0.0, "flap_mult": 1.0, "speed_mult": 1.0,
		"gravity_mult": 1.0, "turn_mult": 1.0, "ragdoll_landings": false,
		"cannot_idle": false, "time_scale": 1.0, "smash_through": false,
		"fx_mode": 0, "fx_strength": 0.0, "honk_pitch": 1.0, "chaos_mult": 1.0,
		"camera_detach": 0.0, "grid_snap": false, "hud_amnesia": false,
		"hallucinate": 0.0, "no_fall_damage": false,
		"scale_amp": 0.0, "scale_period": 7.0, "aggro_cats": false,
		"no_early_exit": false,
	}


func _aggregate() -> Dictionary:
	var m := _empty_mods()
	if blacked_out:
		m.fx_mode = 4  # blackout branch
		m.fx_strength = 1.0
		m.speed_mult = 0.0
		return m

	var strongest_fx := 0.0
	for a in actives:
		var r: Dictionary = a.resolved
		m.input_lag += r.input_lag
		m.drift += r.drift
		m.flap_mult *= r.flap_mult
		m.speed_mult *= r.speed_mult
		m.gravity_mult *= r.gravity_mult
		m.turn_mult *= r.turn_mult
		m.honk_pitch *= r.honk_pitch
		m.chaos_mult *= r.chaos_mult
		m.time_scale = minf(m.time_scale, r.time_scale)
		m.ragdoll_landings = m.ragdoll_landings or r.ragdoll_landings
		m.cannot_idle = m.cannot_idle or r.cannot_idle
		m.smash_through = m.smash_through or r.smash_through
		m.grid_snap = m.grid_snap or r.grid_snap
		m.hud_amnesia = m.hud_amnesia or r.hud_amnesia
		m.no_fall_damage = m.no_fall_damage or r.no_fall_damage
		m.camera_detach = maxf(m.camera_detach, r.camera_detach)
		m.hallucinate = maxf(m.hallucinate, r.hallucinate)
		m.aggro_cats = m.aggro_cats or r.aggro_cats
		m.no_early_exit = m.no_early_exit or r.no_early_exit
		if r.scale_amp > m.scale_amp:
			m.scale_amp = r.scale_amp
			m.scale_period = r.scale_period
		if r.fx_strength > strongest_fx:
			strongest_fx = r.fx_strength
			m.fx_mode = r.fx_mode
			m.fx_strength = r.fx_strength

	if active_combo != "":
		var c: Dictionary = COMBOS[active_combo]
		for k in c:
			if k == "name":
				continue
			if typeof(c[k]) == TYPE_BOOL:
				m[k] = m[k] or c[k]
			elif k in ["drift", "input_lag", "scale_amp"]:
				m[k] += c[k]
			elif k == "time_scale":
				m[k] = minf(m[k], c[k])
			else:
				m[k] *= c[k]

	# Comedown: strictly worse than baseline. The cost, always paid.
	for cd in _comedowns:
		var s: float = cd.strength
		m.speed_mult *= 1.0 - 0.22 * s
		m.flap_mult *= 1.0 - 0.25 * s
		m.drift += 0.10 * s
		m.turn_mult *= 1.0 - 0.15 * s
		if m.fx_mode == 0:
			m.fx_mode = 1
			m.fx_strength = 0.25 * s

	return m


func _tick_brain(delta: float) -> void:
	var target := {"dopamine": BASELINE, "adrenaline": BASELINE, "gaba": BASELINE, "serotonin": BASELINE}
	for a in actives:
		var r: Dictionary = a.resolved
		target.dopamine += r.dopamine
		target.adrenaline += r.adrenaline
		target.gaba += r.gaba
		target.serotonin += r.serotonin
	for cd in _comedowns:
		target.dopamine -= 0.28 * cd.strength
		target.serotonin -= 0.22 * cd.strength
	for k in brain:
		brain[k] = lerpf(brain[k], clampf(target[k], 0.0, 1.0), 1.0 - pow(0.08, delta))


func is_active(id: StringName) -> bool:
	for a in actives:
		if a.res.id == id:
			return true
	return false


func active_names() -> Array[String]:
	var out: Array[String] = []
	for a in actives:
		out.append(a.res.display_name)
	return out


func primary_tint() -> Color:
	if actives.is_empty():
		return Color(1, 1, 1)
	return actives[0].res.tint


func in_comedown() -> bool:
	return not _comedowns.is_empty()


func reset_for_new_leg() -> void:
	# A blackout parked on its 3 s timer has to be ENDED here, not abandoned.
	# Bumping the generation stops the coroutine's tail from firing in the new
	# leg (see _blackout()); emitting the signal ourselves stops the listeners
	# from being stranded mid-blackout, which is a real failure and not a
	# theoretical one — music.gd sets its blackout duck on blackout_started and
	# clears it only on blackout_ended, so a swallowed signal would leave the
	# whole soundtrack cut to 180 Hz for the rest of the run.
	var was_out := blacked_out
	_blackout_gen += 1
	actives.clear()
	_comedowns.clear()
	active_combo = ""
	blacked_out = false
	Engine.time_scale = 1.0
	mods = _empty_mods()
	for k in brain:
		brain[k] = BASELINE
	# Tolerance deliberately PERSISTS across legs. That's the whole point.
	# Emitted last, so anything that reads Subs from the handler sees the clean
	# leg rather than the one that is being torn down.
	if was_out:
		blackout_ended.emit()
