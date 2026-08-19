extends Node
## Autoload: Juice
##
## Reusable game-feel toolkit: hitstop, a global shake bus, squash-and-stretch,
## pooled particle bursts, and pooled world-anchored floating text.
##
## WHAT THIS IS FOR
## Nijman's "The Art of Screenshake" and Jonasson & Purho's "Juice it or lose
## it" both make the same argument: the mechanics don't change, the *feedback*
## does, and the feedback is what people call "feel". The techniques are cheap
## individually and compound heavily. This node exists so that any system —
## a prop breaking, a landing, a dose landing in the sweet spot — can reach for
## them in one line instead of growing its own.
##
## WHAT THIS IS NOT FOR
## The same talks' critics are right, and the criticism is not a footnote:
##   * Shake is a vestibular problem. Persistent camera motion that the player's
##     body did not ask for is a documented motion-sickness trigger, and every
##     major accessibility guideline (Xbox Accessibility Guideline 117 is the
##     clearest) says to provide a way to scale or kill it. Halo Infinite and
##     Cyberpunk both ship 0-100% sliders for exactly this.
##   * Effects that occlude gameplay are a net negative, however good the GIF
##     looks. Bursts here are short, small and never spawn in front of the
##     camera by design.
##   * Hitstop is a *readability* tool. Used on every minor contact it stops
##     reading as impact and starts reading as frame drops.
##
## So: every entry point in this file is gated on the two accessibility prefs
## the game already has. `fx_intensity` at 0 makes hitstop, pop, burst and
## floating_text into no-ops; `screen_shake` at 0 makes shake() a no-op. They
## scale continuously in between rather than being on/off, because a player who
## wants "less" is far more common than one who wants "none".
##
## ---------------------------------------------------------------------------
## HITSTOP vs THE SUBSTANCE SYSTEM — the one genuinely tricky part
## ---------------------------------------------------------------------------
## `substance_manager.gd` already drives Engine.time_scale, every frame:
##
##     Engine.time_scale = lerpf(Engine.time_scale, mods.time_scale, ...)
##
## Two systems writing one global is how you get a clock that never settles.
## Naively dipping Engine.time_scale for hitstop would be immediately fought by
## that lerp, and worse, Subs would then be lerping *from* the dipped value, so
## the dip would leak into the substance slow-motion state.
##
## The composition rule here is: **Subs owns the baseline, Juice owns a
## multiplier, and Juice always writes last.**
##
##   1. `process_priority = 100` guarantees Juice's _process runs after Subs'
##      regardless of autoload order, so Juice's write is the one that lands.
##   2. Juice never reads Engine.time_scale to decide anything. It reads
##      `Subs.mods.time_scale` — the substance system's *intent*, which is a
##      plain unsmoothed number that nothing else touches — and publishes
##      `base * dip`.
##   3. When the hitstop ends Juice writes exactly `base` once and then stops
##      writing entirely. Subs' lerp resumes from precisely the value it was
##      heading for, so there is no snap and no fight.
##
## The payoff is that hitstop is *relative*. On nitrous (time_scale 0.45) a
## hitstop dips to 0.45 * depth and recovers to 0.45, not to 1.0 — it reads as
## an impact inside the slow-motion rather than cancelling it. Hitstop strength
## is additionally scaled down while the world is already slowed, because a
## freeze frame inside slow motion is nearly invisible and just costs response.

## ---------------------------------------------------------------------------
## THE INTENSITY BUDGET — read this before adding a call site
## ---------------------------------------------------------------------------
## The most common way a juice pass makes a game worse is inflation: shake on
## everything until nothing reads as significant, and hitstop on every contact
## until the game reads as dropping frames. So the budget is fixed, written
## down, and spent deliberately. MAX_SHAKE (1.2) is the ceiling the bus can ever
## reach; the camera turns shake 1.0 into a +/-0.06 viewport offset.
##
##  tier            event                                shake        hitstop
##  --------------  -----------------------------------  -----------  -----------
##  5 PEAK          blackout (three substances at once)  1.10         0.11 @ 1.00
##  4 HUGE          faceplant / tumble                   0.90         0.09 @ 1.00
##  3 BIG           prop break                           0.25 - 0.70  0.07 @ 0.80
##                  hard landing                         0.15 - 0.90  0.05 @ 0.55
##                  goose lost to a wire (migration)     0.55         0.06 @ 0.75
##  2 MEDIUM        overdose                             0.30         none
##                  player clips a wire (migration)      0.45         none
##                  combo milestone (every 5th)          0.12 - 0.30  none
##                  nobody fit to take the point         0.25         none
##  1 SMALL         prop hit (non-fatal)                 0.04 - 0.30  none
##                  water entry                          0.18         none
##                  honk pressure wave                   0.05 - 0.22  none
##                  takeoff downwash                     0.10         none
##  0 NONE          sweet-spot dose, cat frenzy, thermal 0.00         none
##                  lead handoff, pickup drained,
##                  NPC startle, combo colour ramp
##
## Three rules that follow from the table and are not negotiable:
##
##   1. HITSTOP HAS EXACTLY THE CALL SITES IN `HITSTOP_SITES` BELOW, and
##      `tools/selftest.gd::_the_hitstops()` fails the build if the code and
##      that table disagree. Nothing the player can trigger more than a few
##      times a minute may freeze the frame. If you are adding one, you are
##      probably wrong — and if you are right, you add a row here in the same
##      commit and write down what it is for.
##
##      **This rule used to say "EXACTLY FIVE CALL SITES" and there were
##      eight.** All three extra ones are argued at length where they sit, so
##      the sites were fine and the RULE was the thing that had rotted — a
##      count in a comment cannot notice a fourth caller. That is the failure
##      mode `CLAUDE.md`'s banner is about, in the file that is most emphatic
##      about not having it.
##   2. Anything the player can retrigger faster than once a second lives in
##      tier 0 or 1. A routine cart-bump is 0.06 — about 5% of the peak — and
##      that ratio is the whole point: the blackout has to be twenty times the
##      cart, or the cart has stolen the blackout's job.
##   3. SHAKE IS THE VOCABULARY FOR VIOLENCE. Rewards (sweet spot, thermal,
##      handoff) get light, particles and colour, never shake. Spending shake on
##      a success weakens both readings.
##
## EVERY HITSTOP IN THE GAME, and what it is for. Rows are
## `[path, seconds, strength, what]` and the order does not matter; the check
## compares the SET. A site in the code and not here fails, and a row here
## with no call site fails too — a table that can quietly describe a call that
## was deleted is the same rot in a new place.
##
## Sorted by strength, which is also the tier order the table above argues.
##
## The check keys on two decimal places, so two sites 0.005 apart would read as
## the same row. Every value here is written to two places and there is no
## reason for a third — but that is why, and a canary that moved 0.04 to 0.045
## passed when it should not have.
const HITSTOP_SITES := [
	["scripts/world/boss_ranger.gd", 0.04, 0.40, "HAZED — the Ranger takes control away"],
	["scripts/goose/goose_controller.gd", 0.05, 0.55, "hard landing"],
	["scripts/world/boss_big_down.gd", 0.05, 0.70, "a storey of glass goes at once"],
	["scripts/migration/migration.gd", 0.06, 0.75, "a goose is lost — the only permanent loss in a run"],
	["scripts/world/zone_truckstop.gd", 0.06, 0.80, "the diner window"],
	["scripts/world/chaos_prop.gd", 0.07, 0.80, "a prop breaks — the headline verb"],
	["scripts/goose/goose_controller.gd", 0.09, 1.00, "the faceplant"],
	["scripts/goose/goose_controller.gd", 0.11, 1.00, "blackout — the peak of the whole budget"],
]

## Everything above is pre-pref; screen_shake and fx_intensity scale it, and at
## 0 the whole table collapses to nothing, which is the point of the sliders.

# ---------------------------------------------------------------------------
# Tuning
# ---------------------------------------------------------------------------

## Hard ceiling on a single hitstop. Past about 120 ms a freeze stops reading as
## impact and starts reading as a stutter — this is the single easiest way to
## make a game feel broken while thinking you are making it feel good.
const MAX_HITSTOP := 0.12

## Shake is capped and decays fast. An uncapped shake accumulator plus a busy
## frame is how you get thirty seconds of nausea from one collision.
const MAX_SHAKE := 1.20
const SHAKE_DECAY := 2.4

const POOL_BURSTS := 14
const POOL_LABELS := 18
const LABEL_LIFE := 1.15
const LABEL_RISE := 1.6
const LABEL_MAX_DIST := 55.0

## Per-kind burst behaviour. Feathers hang and drift, debris is fast and heavy,
## splash is wide and wet, sparkle is slow and weightless.
const BURST_KINDS := {
	&"debris": {"speed": 5.2, "grav": -17.0, "size": 0.16, "life": 0.75, "spread": 52.0, "damp": 1.6},
	&"feathers": {"speed": 2.1, "grav": -1.3, "size": 0.13, "life": 2.00, "spread": 82.0, "damp": 3.2},
	&"splash": {"speed": 4.4, "grav": -13.0, "size": 0.11, "life": 0.85, "spread": 40.0, "damp": 0.7},
	&"sparkle": {"speed": 1.5, "grav": -0.4, "size": 0.10, "life": 1.10, "spread": 90.0, "damp": 0.5},
}

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _fx := 1.0            ## fx_intensity pref, 0..2
var _shake_pref := 1.0    ## screen_shake pref, 0..2

var _shake := 0.0
var _hit_t := 0.0
var _hit_dur := 0.0
var _hit_depth := 1.0
var _hitstopping := false

var _root: Node3D
var _layer: CanvasLayer
var _bursts: Array[CPUParticles3D] = []
var _burst_next := 0
var _labels: Array[Label] = []
var _label_state: Array[Dictionary] = []
var _pops: Array[Dictionary] = []
var _subs: Node = null
var _particle_mat: StandardMaterial3D


func _ready() -> void:
	# Runs after Subs no matter how project.godot orders the autoloads.
	process_priority = 100
	# Hitstop ticks in real seconds, so it resolves even if something pauses
	# the tree mid-freeze. Without this a pause during hitstop would leave
	# Engine.time_scale pinned at 0.05 forever.
	process_mode = Node.PROCESS_MODE_ALWAYS

	_subs = get_node_or_null("/root/Subs")
	_read_prefs()
	var prefs := get_node_or_null("/root/Prefs")
	if prefs and prefs.has_signal("pref_changed"):
		prefs.pref_changed.connect(func(_k, _v): _read_prefs())

	_build_pools()


func _read_prefs() -> void:
	var prefs := get_node_or_null("/root/Prefs")
	if prefs == null:
		return
	_fx = clampf(float(prefs.get_pref(&"fx_intensity", 1.0)), 0.0, 2.0)
	_shake_pref = clampf(float(prefs.get_pref(&"screen_shake", 1.0)), 0.0, 2.0)


# ---------------------------------------------------------------------------
# Pools
#
# Everything is allocated once, here. burst() and floating_text() are called
# from collision handling and from scoring, which are exactly the moments you
# cannot afford to be instancing nodes — and a leak in either would be a slow
# crash rather than a visible bug.
# ---------------------------------------------------------------------------

func _build_pools() -> void:
	_root = Node3D.new()
	_root.name = "JuiceWorld"
	add_child(_root)

	# One material for every particle in the game. CPUParticles3D pushes its
	# `color` through as an instance colour, so a single vertex-colour material
	# recolours every burst for free.
	_particle_mat = StandardMaterial3D.new()
	_particle_mat.vertex_color_use_as_albedo = true
	_particle_mat.albedo_color = Color.WHITE
	_particle_mat.roughness = 0.85
	_particle_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL

	# Unit cube on purpose: CPUParticles3D's scale_amount is a MULTIPLIER on the
	# mesh, not an absolute size, so a 0.09 m mesh times a 0.10 scale gave 9 mm
	# specks that were invisible at gameplay distance. With a unit mesh the
	# `size` entries in BURST_KINDS are the particle size in metres, which is
	# what they read as.
	var chunk := BoxMesh.new()
	chunk.size = Vector3.ONE
	chunk.material = _particle_mat

	for i in POOL_BURSTS:
		var p := CPUParticles3D.new()
		p.name = "Burst%d" % i
		p.mesh = chunk
		p.emitting = false
		p.one_shot = true
		p.explosiveness = 1.0
		p.local_coords = false
		p.amount = 12
		_root.add_child(p)
		_bursts.append(p)

	_layer = CanvasLayer.new()
	_layer.name = "JuiceHUD"
	_layer.layer = 8
	add_child(_layer)

	for i in POOL_LABELS:
		var l := Label.new()
		l.name = "Float%d" % i
		l.size = Vector2(190, 44)
		l.pivot_offset = Vector2(95, 22)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.visible = false
		l.add_theme_font_size_override("font_size", 26)
		l.add_theme_constant_override("outline_size", 6)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		_layer.add_child(l)
		_labels.append(l)
		_label_state.append({"active": false, "t": 0.0, "pos": Vector3.ZERO, "drift": Vector3.ZERO})


# ---------------------------------------------------------------------------
# Frame
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	# Everything here is authored in real seconds. A hitstop that ticks in
	# scaled time never ends, and floating text that fades in scaled time
	# crawls whenever the player is on nitrous.
	var real := delta / maxf(Engine.time_scale, 0.02)
	_tick_hitstop(real)
	_shake = maxf(0.0, _shake - real * SHAKE_DECAY)
	_tick_pops(real)
	_tick_labels(real)


# ---------------------------------------------------------------------------
# Hitstop
# ---------------------------------------------------------------------------

## Brief dip in Engine.time_scale for an impact, then a smooth recovery.
## [param seconds] is real time and is clamped to MAX_HITSTOP.
## [param strength] 0..1 controls how deep the dip goes.
##
## Requests do not queue. The longest outstanding request wins and a shorter one
## arriving mid-freeze is ignored — five props breaking in one frame should read
## as one impact, not as five stacked freezes.
func hitstop(seconds: float, strength := 1.0) -> void:
	if _fx <= 0.001 or seconds <= 0.0:
		return
	var base := _substance_scale()
	# A freeze frame inside slow motion is nearly invisible and costs response,
	# so fade hitstop out as the substance system takes the clock down.
	var relevance := clampf(base, 0.0, 1.0)
	if relevance < 0.15:
		return
	var dur := clampf(seconds, 0.0, MAX_HITSTOP) * clampf(_fx, 0.0, 1.0)
	if dur <= _hit_t:
		return
	_hit_t = dur
	_hit_dur = dur
	var s := clampf(strength, 0.0, 1.0) * clampf(_fx, 0.0, 1.0) * relevance
	_hit_depth = clampf(1.0 - 0.92 * s, 0.04, 1.0)
	_hitstopping = true


func _tick_hitstop(real: float) -> void:
	if not _hitstopping:
		return
	_hit_t -= real
	var base := _substance_scale()
	if _hit_t <= 0.0:
		_hitstopping = false
		_hit_t = 0.0
		# Hand the clock back at exactly the substance system's own target, so
		# its lerp continues from where it expects to be instead of snapping.
		Engine.time_scale = base
		return
	# k runs 1 -> 0.
	#
	# The curve matters more than it looks. An ease that is symmetric (k*k) has
	# already given back a third of the freeze by the time the first frame is
	# drawn — the headless test measured a requested depth of 0.08 arriving on
	# screen as 0.36, which is a slowdown, not a hit. A hitstop has to be at
	# full depth on the very first visible frame and then release.
	#
	# pow(k, 0.4) holds near the requested depth for the first half of the
	# window and eases out over the second half, so the impact lands hard and
	# hands the clock back without a pop.
	var k := _hit_t / maxf(_hit_dur, 0.0001)
	Engine.time_scale = maxf(base * lerpf(1.0, _hit_depth, pow(k, 0.4)), 0.01)


## The substance system's *intent* for the clock. Deliberately not
## Engine.time_scale: reading the live value would feed Juice's own output back
## into itself one frame later.
func _substance_scale() -> float:
	if _subs == null or not is_instance_valid(_subs):
		return 1.0
	var raw = _subs.get("mods")
	if typeof(raw) != TYPE_DICTIONARY:
		return 1.0
	var d: Dictionary = raw
	var ts: float = d.get("time_scale", 1.0)
	return clampf(ts, 0.05, 4.0)


## True while a freeze is in progress. Useful if a caller wants to suppress its
## own follow-up effect.
func is_hitstopped() -> bool:
	return _hitstopping


# ---------------------------------------------------------------------------
# Shake bus
# ---------------------------------------------------------------------------

## Add to the global shake accumulator. Anything, anywhere, can call this;
## the camera reads the result. Scaled by the `screen_shake` pref, which is the
## authoritative accessibility control — at 0 this does nothing at all.
func shake(amount: float) -> void:
	if _shake_pref <= 0.001 or amount <= 0.0:
		return
	_shake = minf(MAX_SHAKE, _shake + amount * _shake_pref * clampf(_fx, 0.0, 1.5))


## Current shake magnitude, 0..MAX_SHAKE. This is what goose_camera.gd should
## consult instead of keeping its own accumulator, so a shake triggered from a
## breaking prop and one triggered from a landing go through the same bus and
## obey the same cap.
func shake_value() -> float:
	return _shake


## The two accessibility prefs, read-only, so that a system with a *continuous*
## effect of its own (the substance camera jitter, say) can obey them without
## going back to Prefs and duplicating the clamp — and without pushing a
## per-frame top-up into the shake bus, which would sit inside the shared cap
## and mask real impacts. Nothing outside this file should ever read
## `screen_shake` or `fx_intensity` directly.
func shake_scale() -> float:
	return _shake_pref


func fx_scale() -> float:
	return _fx


# ---------------------------------------------------------------------------
# Squash and stretch
# ---------------------------------------------------------------------------

## Scale punch on any Node3D: stretch tall and thin, then settle.
##
## Do NOT use this on the goose's own body — substances already drive its scale
## and the two would fight. Props, pickups, HUD-adjacent 3D and NPCs are fine.
func pop(node: Node3D, amount := 0.25, secs := 0.18) -> void:
	if _fx <= 0.001 or node == null or not is_instance_valid(node):
		return
	var a := amount * clampf(_fx, 0.0, 1.5)
	for i in _pops.size():
		var p: Dictionary = _pops[i]
		var existing = p["node"]
		if existing == node:
			# Retrigger rather than stack: two overlapping pops on one node
			# multiply into a visible scale glitch.
			p["t"] = 0.0
			p["dur"] = maxf(secs, 0.02)
			p["amount"] = a
			return
	_pops.append({
		"node": node, "base": node.scale, "t": 0.0,
		"dur": maxf(secs, 0.02), "amount": a,
	})


func _tick_pops(real: float) -> void:
	for i in range(_pops.size() - 1, -1, -1):
		var p: Dictionary = _pops[i]
		var raw = p["node"]
		if raw == null or not is_instance_valid(raw):
			_pops.remove_at(i)
			continue
		var node: Node3D = raw
		var t: float = p["t"] + real
		p["t"] = t
		var dur: float = p["dur"]
		var base: Vector3 = p["base"]
		if t >= dur:
			node.scale = base
			_pops.remove_at(i)
			continue
		var a: float = p["amount"]
		var k := t / dur
		# One decaying overshoot. A plain ease back to 1.0 reads as a scale
		# change; the overshoot past the resting size is what reads as a pop,
		# and volume is roughly conserved so it looks elastic rather than
		# inflated.
		var e := sin(k * PI * 1.5) * pow(1.0 - k, 1.6)
		node.scale = Vector3(
			base.x * (1.0 - a * e * 0.55),
			base.y * (1.0 + a * e),
			base.z * (1.0 - a * e * 0.55))


# ---------------------------------------------------------------------------
# Particle bursts
# ---------------------------------------------------------------------------

## Fire a pooled one-shot burst at [param pos].
##
## [param kind] is one of &"debris", &"feathers", &"splash", &"sparkle";
## anything else falls back to debris. Emitters are recycled round-robin, so
## enough simultaneous bursts will steal the oldest one — which is the correct
## failure mode, and much better than allocating during a pile-up.
func burst(pos: Vector3, colour: Color, count := 8, kind := &"debris") -> void:
	if _fx <= 0.001 or _bursts.is_empty():
		return
	var key: StringName = kind if BURST_KINDS.has(kind) else &"debris"
	var cfg: Dictionary = BURST_KINDS[key]

	var p: CPUParticles3D = _bursts[_burst_next]
	_burst_next = (_burst_next + 1) % _bursts.size()

	var speed: float = cfg["speed"]
	var grav: float = cfg["grav"]
	var size: float = cfg["size"]
	var life: float = cfg["life"]
	var spread: float = cfg["spread"]
	var damp: float = cfg["damp"]

	p.global_position = pos
	p.amount = maxi(1, int(round(float(count) * clampf(_fx, 0.0, 1.5))))
	p.lifetime = life
	p.direction = Vector3.UP
	p.spread = spread
	p.initial_velocity_min = speed * 0.45
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, grav, 0)
	p.damping_min = damp * 0.5
	p.damping_max = damp
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size
	p.angular_velocity_min = -260.0
	p.angular_velocity_max = 260.0
	p.color = colour
	# Fade the chunks out rather than popping them, and shrink them as they go.
	p.restart()
	p.emitting = true


# ---------------------------------------------------------------------------
# Floating text
# ---------------------------------------------------------------------------

## World-anchored score number that rises and fades.
##
## Anchored in 3D and projected every frame rather than being spawned at a
## screen position, so it stays glued to the thing that earned it while the
## camera moves. Culled when behind the camera or beyond LABEL_MAX_DIST, which
## matters: eleven minivans' worth of score popups drawn at 80 m is pure noise.
func floating_text(pos: Vector3, text: String, colour: Color) -> void:
	if _fx <= 0.001 or _labels.is_empty():
		return
	var cam := get_viewport().get_camera_3d()
	if cam != null and cam.global_position.distance_to(pos) > LABEL_MAX_DIST:
		return

	var slot := -1
	for i in _label_state.size():
		var st: Dictionary = _label_state[i]
		var active: bool = st["active"]
		if not active:
			slot = i
			break
	if slot < 0:
		# Pool exhausted: steal the oldest, which is the one closest to fading
		# out anyway.
		var oldest := 0.0
		for i in _label_state.size():
			var st: Dictionary = _label_state[i]
			var t: float = st["t"]
			if t >= oldest:
				oldest = t
				slot = i
	if slot < 0:
		return

	var st: Dictionary = _label_state[slot]
	st["active"] = true
	st["t"] = 0.0
	st["pos"] = pos
	# Deterministic sideways drift keyed off the slot index, so two numbers
	# scored in the same frame do not stack into an unreadable pile.
	var a := float(slot) * 2.399
	st["drift"] = Vector3(cos(a) * 0.5, 0.0, sin(a) * 0.5)

	var lbl: Label = _labels[slot]
	lbl.text = text
	lbl.add_theme_color_override("font_color", colour)
	lbl.visible = true


func _tick_labels(real: float) -> void:
	var cam := get_viewport().get_camera_3d()
	for i in _label_state.size():
		var st: Dictionary = _label_state[i]
		var active: bool = st["active"]
		if not active:
			continue
		var lbl: Label = _labels[i]
		var t: float = st["t"] + real
		st["t"] = t
		if t >= LABEL_LIFE:
			st["active"] = false
			lbl.visible = false
			continue
		if cam == null or not is_instance_valid(cam):
			lbl.visible = false
			continue

		var k := t / LABEL_LIFE
		var base: Vector3 = st["pos"]
		var drift: Vector3 = st["drift"]
		# Ease-out rise: most of the travel happens early, which is when the
		# player is actually looking at it.
		var world: Vector3 = base + Vector3.UP * (LABEL_RISE * (1.0 - pow(1.0 - k, 2.2))) \
			+ drift * k

		if cam.is_position_behind(world):
			lbl.visible = false
			continue
		var dist := cam.global_position.distance_to(world)
		if dist > LABEL_MAX_DIST:
			lbl.visible = false
			continue

		var screen := cam.unproject_position(world)
		lbl.position = screen - lbl.size * 0.5
		# Shrink with distance so a number at 40 m does not shout as loudly as
		# one at 4 m.
		var s := clampf(lerpf(1.15, 0.55, dist / LABEL_MAX_DIST), 0.5, 1.2)
		lbl.scale = Vector2(s, s)
		# Hold opaque for the first third, then fade.
		lbl.modulate.a = clampf((1.0 - k) * 1.5, 0.0, 1.0)
		lbl.visible = true


# ---------------------------------------------------------------------------
# Housekeeping
# ---------------------------------------------------------------------------

## Drop all in-flight effects and release the clock. Call this on a leg change
## or a restart, next to Subs.reset_for_new_leg(), so a hitstop or a pop cannot
## survive across a scene swap holding a stale node reference.
func reset() -> void:
	_shake = 0.0
	_hit_t = 0.0
	# Releasing the clock has to be an actual WRITE, not just clearing the flag.
	# Dropping _hitstopping alone stops _tick_hitstop() from ever reaching its
	# "hand the clock back" branch, so Engine.time_scale stays pinned at
	# whatever depth the freeze had reached — measured at 0.106 when a leg ended
	# one frame into a 0.12 s hitstop. Subs' lerp does eventually drag it back,
	# but the delta it lerps with is itself scaled by the dipped clock, so
	# recovery takes ~2 real seconds and the player watches the next zone fade
	# in through treacle.
	#
	# main._clear() calls reset() on every scene swap and is the path that hits
	# this: Game.start_zone() happens to be safe only because
	# Subs.reset_for_new_leg() writes 1.0 immediately before.
	#
	# Guarded, because an unconditional write here would stomp the substance
	# system's lerp on every reset where nothing was frozen at all.
	if _hitstopping:
		Engine.time_scale = _substance_scale()
	_hitstopping = false
	for p in _pops:
		var entry: Dictionary = p
		var raw = entry["node"]
		if raw != null and is_instance_valid(raw):
			var node: Node3D = raw
			var base: Vector3 = entry["base"]
			node.scale = base
	_pops.clear()
	for i in _label_state.size():
		var st: Dictionary = _label_state[i]
		st["active"] = false
		var lbl: Label = _labels[i]
		lbl.visible = false
	for b in _bursts:
		var e: CPUParticles3D = b
		e.emitting = false


## Live pool occupancy, for the dev overlay and for the pooling test.
func debug_counts() -> Dictionary:
	var active_labels := 0
	for st in _label_state:
		var d: Dictionary = st
		var a: bool = d["active"]
		if a:
			active_labels += 1
	return {
		"burst_pool": _bursts.size(),
		"label_pool": _labels.size(),
		"labels_active": active_labels,
		"pops_active": _pops.size(),
		"shake": _shake,
		"hitstopping": _hitstopping,
	}
