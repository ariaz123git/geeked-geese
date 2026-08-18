extends Node3D
## THE RANGER — a boss encounter with no combat in it.
##
## Spec: docs/BOSS_DESIGN.md §2.1. This file is the leg 3 INTRODUCTION, which
## §7.5 nominates as the whole project's cheapest answer to "is a boss without
## combat fun in this controller". Leg 6's exam (the corn rows, the propane
## cannon, RELOCATED) is deliberately not here — leg 6 does not exist yet.
##
## ---------------------------------------------------------------------------
## WHAT A BOSS IS HERE
## ---------------------------------------------------------------------------
## "A rule the sandbox does not normally have, given a body you cannot break,
## that arrives, takes something away, and leaves on a timer." No health bar, no
## damage, no defeat state. He is on a 45-second clock and he leaves whether or
## not you were any good.
##
## THE TWO-BODY SPLIT is the whole design:
##
##   THE RANGER  2.4 m/s, slower than a waddle. Wants the clipboard. Flinches at
##               a honk and drops it, then has to pick it up again.
##   PIPER       9.5 m/s. The only thing in the game that outruns a goose on the
##               ground. Does not care about honks. DOES care about cats.
##
## So the man is something you bully and the dog is something you cannot, and
## the counter to the dog is the one thing neither of them has: a Y axis.
##
## ---------------------------------------------------------------------------
## WHAT IT SUBTRACTS
## ---------------------------------------------------------------------------
## He bins substance sources — up to five of the zone's sixteen, gone for the
## rest of the leg. It is the first time in the run that the sandbox gets
## SMALLER, and a player who ignores him plays the back half of Suburbia with a
## third of the shelf missing.
##
## ---------------------------------------------------------------------------
## HOW IT ATTACHES
## ---------------------------------------------------------------------------
## Exactly like hallucinations.gd: it lives BESIDE a zone and needs nothing from
## the zone author. One line in main.gd::_load_zone —
##
##     BossRanger.spawn_into(zone, zone.goose, 80.0)
##
## — see docs/BOSS_RANGER_BUILD.md. Being a child of the zone means main._clear()
## frees it with everything else, and every path in here restores the goose
## before it goes.
##
## ---------------------------------------------------------------------------
## HOW IT CANNOT SOFT-LOCK
## ---------------------------------------------------------------------------
##  * The encounter is a timer. Nothing the player does can extend it, and
##    ignoring it entirely is a valid (worse) way to play the leg.
##  * The carry has a hard 6.5 s ceiling regardless of where the dog gets to.
##  * The dog gives up on anything it cannot reach, anything more than 42 m
##    away, and any pursuit that stops closing.
##  * If the zone clock stops (results screen, leg end) the encounter stands
##    down and hands control back on the same frame.
##  * The goose is only ever control-locked by the carry, and _exit_tree()
##    unlocks it.

const VIS := preload("res://scripts/world/boss_ranger_visual.gd")
const PROPS := preload("res://scripts/world/prop_models.gd")
const CHAOS_PROP := preload("res://scripts/world/chaos_prop.gd")

signal encounter_started()
## outcome is one of &"departed" (the clock ran out) or &"routed" (you took the
## clipboard off him and broke it).
signal encounter_ended(outcome: StringName)

enum Phase { WAITING, ARRIVE, SWEEP, COUNT, DEPART, DONE }

# ---------------------------------------------------------------- the clock
## BOSS_DESIGN.md §2.1.3: 45 seconds. §0 caps every encounter in the game at 90,
## which _physics_process enforces as a hard failsafe.
const T_ARRIVE_END := 4.0
## Earlier than the spec's 30 s: measured, he needs the best part of fifteen
## seconds to walk from wherever the sweep left him to the pen, and at 30 s the
## count beat did not happen at all.
const T_COUNT := 26.0
const T_DEPART := 40.0

## He takes five of the zone's sixteen sources. Any more and the back half of
## the leg is a different, worse zone; any fewer and nobody notices.
const MAX_BINNED := 5
## Sources further out than this (from `arena_at`, not from the truck) or higher
## than this are not his problem. The practical effect is that the berries in
## the tree canopy and anything on a roof survive — which is exactly the lesson
## the encounter is teaching.
const BIN_RANGE := 30.0
const BIN_MAX_Y := 1.6

const TRUCK_APPROACH := 26.0
const TRUCK_TIME := 3.4

# ---------------------------------------------------------------- state
var goose: CharacterBody3D = null
var park_at := Vector3(6.5, 0.0, 19.0)
var drop_at := Vector3(0.0, 0.0, 33.0)
var pen_at := Vector3(0.0, 0.0, 34.0)
## The middle of the playable space. Suburbia's cul-de-sac bulb is the origin,
## which is why this defaults there rather than to the truck.
var arena_at := Vector3.ZERO

var phase: int = Phase.WAITING
var count := 0                      ## the number on the clipboard

var _delay := 0.0
var _t := 0.0
var _binned := 0
var _truck: Node3D
var _truck_body: StaticBody3D
var _truck_shape: CollisionShape3D
var _truck_bin: Node3D
var _truck_light: OmniLight3D
var _truck_t := 0.0
var _truck_moving := 0               ## -1 arriving, 0 parked, +1 leaving
var _ranger: Node3D                  ## a Ranger (inner class)
var _dog: Node3D                     ## a Piper (inner class)
var _sweep_target: Node3D = null
var _sweep_stuck := 0.0
## Sources he tried and could not get to. Without this he re-picks the nearest
## one every time he gives up on it and stands in a driveway for the whole
## encounter — which is exactly what the second render caught him doing.
var _unreachable: Array[Node3D] = []
var _count_tick := 0.0
var _ended := false
var _sfx: Node = null
var _music: Node = null


# ===========================================================================
# THE INTEGRATION API — this is the whole thing
# ===========================================================================

## Drop the Ranger into a running zone. Returns the encounter node, whose only
## interesting members are `encounter_started` / `encounter_ended`.
##
##   BossRanger.spawn_into(zone, zone.goose, 80.0)
##
## [param delay] is seconds from now until the truck pulls in. The defaults for
## [param park] and [param drop] are Suburbia's: the mouth of the cul-de-sac and
## a point 33 m down the entrance corridor.
##
## Self-`load()` rather than `preload()` because a script cannot preload itself,
## and the resource is in the cache by the time anything can call this.
static func spawn_into(zone: Node, goose_ref: CharacterBody3D, delay := 0.0,
		park := Vector3(6.5, 0.0, 19.0), drop := Vector3(0.0, 0.0, 33.0)) -> Node3D:
	var script: GDScript = load("res://scripts/world/boss_ranger.gd")
	# Deliberately untyped: a statically-typed Node3D has no `goose` property as
	# far as the analyser is concerned, and this is the only place in the file
	# that pays for it.
	var boss = script.new()
	boss.name = "BossRanger"
	boss.goose = goose_ref
	boss.park_at = park
	boss.drop_at = drop
	boss._delay = maxf(delay, 0.0)
	zone.add_child(boss)
	return boss


func _ready() -> void:
	_sfx = get_node_or_null("/root/Sfx")
	_music = get_node_or_null("/root/Music")
	_find_pen()
	if Game.has_signal("chaos_scored"):
		Game.chaos_scored.connect(_on_chaos_scored)


## The flock pen is where he does his counting, and no zone publishes its
## position. Rather than make every zone author declare one, sniff for the node
## by its signal — flock_pen.gd is the only thing in the project that emits
## `dd_designated`. Falls back to the caller's default if it isn't there.
func _find_pen() -> void:
	var parent := get_parent()
	if parent == null:
		return
	for c in parent.get_children():
		if c.has_signal("dd_designated"):
			var raw = c.get("_centre")
			if typeof(raw) == TYPE_VECTOR3:
				var v: Vector3 = raw
				pen_at = Vector3(v.x, 0.0, v.z)
			return


func _exit_tree() -> void:
	# Last line of defence. If the zone is torn down mid-carry the dog goes with
	# it, so the goose's process mode has to be handed back from here too.
	if _dog and is_instance_valid(_dog) and _dog.has_method("abort_carry"):
		_dog.abort_carry()


# ===========================================================================
# FRAME
# ===========================================================================

func _physics_process(delta: float) -> void:
	if _ended:
		# The encounter is over but the truck is still reversing out of the
		# cul-de-sac with the bin on it, and it frees the whole node when it
		# gets there. This branch is why _tick_truck is not inside the match.
		_tick_truck(delta)
		return

	# The zone clock stopping (results card, leg end, a restart) stands the
	# whole encounter down on the same frame rather than leaving a dog holding
	# a goose behind a menu. WAITING is exempt: the zone's opening briefing
	# pauses the clock, and standing down there would kill the encounter before
	# it ever existed.
	if not Game.zone_running:
		if phase != Phase.WAITING:
			_stand_down()
		return

	if phase == Phase.WAITING:
		_delay -= delta
		if _delay <= 0.0:
			_begin()
		return

	_t += delta
	_tick_truck(delta)

	# Absolute ceiling, above every other exit in the file. BOSS_DESIGN.md §0:
	# no encounter may exceed 90 seconds under any circumstances. If he is
	# somehow wedged in a fence with the departure unreachable, he still goes.
	if _t > 90.0:
		_finish()
		return

	match phase:
		Phase.ARRIVE:
			if _t >= T_ARRIVE_END:
				phase = Phase.SWEEP
				_next_source()
		Phase.SWEEP:
			_tick_sweep(delta)
			if _t >= T_COUNT or _binned >= MAX_BINNED:
				_begin_count()
		Phase.COUNT:
			_tick_count(delta)
			if _t >= T_DEPART:
				_begin_depart(&"departed")
		Phase.DEPART:
			_tick_depart()

	_tick_light(delta)


# ===========================================================================
# ARRIVAL
# ===========================================================================

func _begin() -> void:
	phase = Phase.ARRIVE
	_t = 0.0
	_build_truck()
	_build_ranger()
	_build_dog()

	_truck_moving = -1
	_truck_t = 0.0

	# TIER 2 (see the budget in juice.gd). A vehicle arriving is a bigger event
	# than a prop hit and a much smaller one than a faceplant. No hitstop.
	Juice.shake(0.28)
	if _sfx:
		# There is no engine or air-horn sample in the project yet. `honk_angry`
		# at a third of pitch is a serviceable stand-in for a truck horn and it
		# rhymes with the goose, which is funnier than a correct sample would be.
		# tools/gen_audio.py should grow `air_horn` and `dog_bark`.
		_sfx.play_at(&"honk_angry", self, 2.0, 0.32)
	if _music:
		_music.set_intensity(0.62)

	_air_horn(park_at)
	if _ranger and _ranger.has_method("say"):
		_ranger.say("...Canadian geese, approximately—", 4.0)
	Mission.note(&"ranger_arrived")
	encounter_started.emit()


## The air horn, which is the arrival's actual mechanic: it knocks over
## everything light within 9 m, INCLUDING things the player had lined up. It is
## the honk's own pressure wave with a different owner, and the first thing the
## encounter does is take something.
func _air_horn(at: Vector3) -> void:
	for node in get_tree().get_nodes_in_group("chaos_prop"):
		if not (node is Node3D):
			continue
		var n3: Node3D = node
		var d := n3.global_position.distance_to(at)
		if d > 9.0:
			continue
		if n3.has_method("shove"):
			var dir: Vector3 = (n3.global_position - at).normalized() + Vector3.UP * 0.45
			n3.shove(dir * (6.5 * (1.0 - d / 9.0) + 1.5))
	for node in get_tree().get_nodes_in_group("npc"):
		if node == _ranger or node == _dog:
			continue
		if node is Node3D and node.global_position.distance_to(at) < 9.0:
			if node.has_method("startle"):
				node.startle(at)
	Juice.burst(at + Vector3.UP * 1.6, Color(0.95, 0.94, 0.86), 12, &"sparkle")


# ===========================================================================
# THE SWEEP — the subtraction
# ===========================================================================

func _tick_sweep(delta: float) -> void:
	if _ranger == null or not is_instance_valid(_ranger):
		return
	# A flinching Ranger, or one walking back to a dropped clipboard, is not
	# sweeping. That is the entire point of the honk: it costs him seconds.
	if _ranger.call("is_busy"):
		return

	if _sweep_target == null or not is_instance_valid(_sweep_target):
		_next_source()
		return

	_ranger.call("set_goal", _sweep_target.global_position)
	_sweep_stuck += delta
	var d: float = _ranger.global_position.distance_to(_sweep_target.global_position)
	# 2.4 m, not touching distance. He has arms and a bin bag, and every metre
	# he does not have to walk is another source he gets through inside the
	# twenty-two seconds the sweep actually has.
	if d < 2.4:
		_bin(_sweep_target)
		_next_source()
	elif _sweep_stuck > 6.0:
		# He walked into a fence anyway. Real municipal contractors also do
		# this; the encounter cannot afford to watch. Blacklist it so he does
		# not immediately choose the same fence again.
		if _sweep_target != null and is_instance_valid(_sweep_target):
			_unreachable.append(_sweep_target)
		_next_source()


func _next_source() -> void:
	_sweep_stuck = 0.0
	_sweep_target = null
	if _binned >= MAX_BINNED or _ranger == null or not is_instance_valid(_ranger):
		return
	var from: Vector3 = _ranger.global_position
	var best: Node3D = null
	var best_d := 1e9
	for n in get_tree().get_nodes_in_group("substance_source"):
		if not (n is Node3D):
			continue
		var s: Node3D = n
		if s.global_position.y > BIN_MAX_Y:
			continue
		if s.global_position.distance_to(arena_at) > BIN_RANGE:
			continue
		if _unreachable.has(s):
			continue
		var d := s.global_position.distance_to(from)
		if d >= best_d:
			continue
		if not _walkable(from, s.global_position):
			continue
		best_d = d
		best = s
	_sweep_target = best


## He has no navmesh and this project does not have one to give him. A single
## ray at chest height is enough to stop him picking a source that is behind a
## backyard fence, a house or a parked car — which was most of them, because
## Suburbia's whole design is that the good stuff is enclosed.
##
## Cheap: at most fourteen rays, and only when he picks a new target.
func _walkable(from: Vector3, to: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	if space == null:
		return true
	var a := Vector3(from.x, 0.9, from.z)
	var b := Vector3(to.x, 0.9, to.z)
	var q := PhysicsRayQueryParameters3D.create(a, b)
	q.collide_with_areas = false
	var excl: Array[RID] = []
	if _ranger is CollisionObject3D:
		excl.append((_ranger as CollisionObject3D).get_rid())
	if _truck_body and is_instance_valid(_truck_body):
		excl.append(_truck_body.get_rid())
	q.exclude = excl
	return space.intersect_ray(q).is_empty()


## The source goes in the bin on the truck and is gone for the rest of the leg.
## Freeing it is safe: goose_controller.gd guards its `_eating` reference with
## is_instance_valid, so taking a source out from under a charging player aborts
## the charge cleanly. Which is, obviously, the funniest moment available.
func _bin(src: Node3D) -> void:
	_binned += 1
	var tint := Color(0.85, 0.85, 0.85)
	var raw = src.get("substance")
	if raw != null and typeof(raw) == TYPE_OBJECT:
		var t = raw.get("tint")
		if typeof(t) == TYPE_COLOR:
			tint = t

	Juice.burst(src.global_position + Vector3.UP * 0.4, tint, 10, &"sparkle")
	Juice.floating_text(src.global_position + Vector3.UP * 1.1, "CONFISCATED",
		Color(0.98, 0.82, 0.34))
	if _sfx:
		_sfx.play_at(&"crash_light", self, -8.0, 1.35)
	if _ranger and _ranger.has_method("say") and _binned == 1:
		_ranger.say("...and this is coming with me.", 2.6)
	Mission.note(&"source_binned", {"n": _binned})

	# A visible cube in the truck bed per confiscated source. It is the only
	# readout the encounter has and it is a physical object, which is the rule.
	if _truck_bin and is_instance_valid(_truck_bin):
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.42, 0.42, 0.42)
		mi.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = tint
		m.roughness = 0.85
		mi.material_override = m
		var col := (_binned - 1) % 3
		var row := (_binned - 1) / 3
		mi.position = Vector3(-0.5 + float(col) * 0.5, 0.22 + float(row) * 0.44, 0.0)
		_truck_bin.add_child(mi)

	src.queue_free()


# ===========================================================================
# THE COUNT — the threat display
# ===========================================================================

func _begin_count() -> void:
	if phase == Phase.COUNT:
		return
	phase = Phase.COUNT
	_count_tick = 0.0
	_sweep_target = null


func _tick_count(delta: float) -> void:
	if _ranger == null or not is_instance_valid(_ranger):
		return
	if _ranger.call("is_busy"):
		return
	_ranger.call("set_goal", pen_at)
	var d: float = _ranger.global_position.distance_to(pen_at)
	# He starts counting on the APPROACH, not on arrival. Waiting until he is
	# standing in the pen means the beat only fires if he happens to get there,
	# and the point of the beat is that the number is climbing while you watch.
	if d > 14.0:
		return

	# He is standing in your flock writing down how many of you there are. At
	# leg 3 nothing is lost — this is the mechanic being shown once, for free,
	# in the leg before the one where it costs a bird.
	_count_tick -= delta
	if _count_tick <= 0.0:
		_count_tick = 0.7
		var flock: int = Flock.alive_birds().size()
		if count < flock:
			count += 1
			_refresh_board()
			if _sfx:
				_sfx.play_at(&"score_blip", self, -14.0, 0.8)
			if count == flock and _ranger.has_method("say"):
				_ranger.say("...%d. %d of them." % [flock, flock], 3.0)


# ===========================================================================
# DEPARTURE
# ===========================================================================

func _begin_depart(outcome: StringName) -> void:
	if phase == Phase.DEPART or phase == Phase.DONE:
		return
	phase = Phase.DEPART
	_sweep_target = null
	if _dog and is_instance_valid(_dog):
		_dog.call("stand_down")
	if _ranger and _ranger.has_method("say"):
		if outcome == &"routed":
			# The victory line is an administrative threat. Nobody won anything.
			_ranger.say("...I'll come back next year.", 5.0)
		else:
			_ranger.say("Right. That's the survey.", 4.0)
	set_meta("outcome", outcome)


func _tick_depart() -> void:
	if _ranger == null or not is_instance_valid(_ranger):
		_finish()
		return
	var door := park_at + Vector3(-2.0, 0.0, 2.2)
	_ranger.call("set_goal", door)
	if _ranger.global_position.distance_to(door) < 2.0 or _t >= T_DEPART + 9.0:
		_finish()


func _finish() -> void:
	if _ended:
		return
	_ended = true
	phase = Phase.DONE
	if _dog and is_instance_valid(_dog):
		_dog.call("abort_carry")
		_dog.queue_free()
	if _ranger and is_instance_valid(_ranger):
		_ranger.queue_free()
	# The truck reverses out of the cul-de-sac with the bin still on it. Its
	# collider goes first, so a goose standing on the roof is put down rather
	# than driven to the county line.
	if _truck_shape and is_instance_valid(_truck_shape):
		_truck_shape.set_deferred("disabled", true)
	_truck_moving = 1
	_truck_t = 0.0
	if _music:
		_music.set_intensity(0.0)
	var outcome: StringName = &"departed"
	if has_meta("outcome"):
		outcome = get_meta("outcome")
	Mission.note(&"ranger_left", {"binned": _binned, "outcome": String(outcome)})
	encounter_ended.emit(outcome)


## Called when the zone stops running under us. Not the same as _finish(): this
## one is not a story beat, it just gets everything out of the player's way.
func _stand_down() -> void:
	_ended = true
	phase = Phase.DONE
	if _dog and is_instance_valid(_dog):
		_dog.call("abort_carry")
	if _music:
		_music.set_intensity(0.0)


# ===========================================================================
# THE CLIPBOARD
# ===========================================================================

## Fired by the Ranger when a honk (or a cat) lands on him.
func on_flinch(from: Vector3) -> void:
	if _ranger == null or not is_instance_valid(_ranger):
		return
	Game.score(75, "RANGER", _ranger.global_position + Vector3.UP * 1.2)
	Mission.note(&"ranger_flinched")
	_drop_board(from)


func _drop_board(from: Vector3) -> void:
	if _ranger == null or not is_instance_valid(_ranger):
		return
	var held: Node3D = _ranger.get("held_board")
	if held == null or not is_instance_valid(held) or not held.visible:
		return
	var at: Vector3 = held.global_position
	held.visible = false

	var prop := CHAOS_PROP.new()
	prop.name = "Clipboard"
	add_child(prop)
	# break_force 5.0 sits just above waddle speed (4.2), so knocking it out of
	# his hands is easy and DESTROYING it costs you a run-up, a dive, a cat or a
	# substance. Two different verbs for two different outcomes.
	prop.setup(Vector3(0.38, 0.48, 0.05), Color(0.94, 0.94, 0.91), 1.6, 150, "CLIPBOARD")
	prop.break_force = 5.0
	prop.global_position = at
	var mesh_node := prop.get_node_or_null("Mesh") as MeshInstance3D
	if mesh_node:
		# ChaosProp built a BoxMesh for us. Keep the NODE (it is the thing
		# _break() hides, by reference) and swap the geometry underneath it, so
		# a broken clipboard actually disappears.
		mesh_node.mesh = null
		VIS.build_clipboard(mesh_node)
		_attach_board_label(mesh_node)
	prop.apply_central_impulse((at - from).normalized() * 2.2 + Vector3.UP * 2.6)
	prop.angular_velocity = Vector3(randf_range(-4, 4), randf_range(-6, 6), randf_range(-4, 4))

	_ranger.call("go_retrieve", prop)
	Game.score(120, "CLIPBOARD", at)
	Mission.note(&"clipboard_dropped")
	if _sfx:
		_sfx.play_at(&"crash_light", self, -4.0, 1.2)


## Public because ChaosProp does its own scoring and the label is the only
## public signal that a specific prop broke. Cheaper and more honest than
## reaching into its private `_broken`.
func _on_chaos_scored(_amount: int, _total: int, _combo: int, label: String) -> void:
	if _ended:
		return
	if label != "CLIPBOARD!!":
		return
	Mission.note(&"clipboard_broken")
	if _music:
		_music.sting(&"hidden")
	if _ranger and is_instance_valid(_ranger):
		Juice.floating_text(_ranger.global_position + Vector3.UP * 2.2,
			"SURVEY VOID", Color(0.62, 0.98, 0.66))
		_ranger.call("give_up")
	_begin_depart(&"routed")


## The board's live face. BOSS_DESIGN.md §2.1.5 argues at length that this is
## not a health bar: it counts UP, it belongs to him, reducing it does nothing,
## and it is a prop rather than a UI element. It is also the encounter's entire
## tutorial — a player who has never seen him reads "a man is writing down how
## many of us there are" off one object with no text card anywhere.
func _attach_board_label(parent: Node3D) -> Label3D:
	var l := Label3D.new()
	l.name = "Face"
	l.text = _board_text()
	l.pixel_size = 0.0022
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.double_sided = true
	l.shaded = false
	l.outline_size = 7
	l.outline_modulate = Color(0, 0, 0, 0.9)
	# Light text on a heavy black outline, NOT dark ink on the paper. The label
	# billboards and the board does not, so as soon as he turns side-on the
	# "paper" behind the text is whatever the world is — and dark-on-dark is
	# unreadable. flock_pen.gd's tags make the same call for the same reason.
	l.modulate = Color(0.97, 0.97, 0.94)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector3(0, 0.0, -0.05)
	l.render_priority = 2
	parent.add_child(l)
	return l


func _board_text() -> String:
	# Two short lines rather than one long one: at 0.0022 m/px "CANADIAN GEESE"
	# on one line is half a metre wide and overhangs the board from every angle.
	return "CANADIAN\nGEESE  %d" % count


func _refresh_board() -> void:
	for l in _all_board_labels():
		l.text = _board_text()


func _all_board_labels() -> Array[Label3D]:
	var out: Array[Label3D] = []
	var stack: Array[Node] = [self]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Label3D and n.name == "Face":
			out.append(n as Label3D)
		for c in n.get_children():
			stack.append(c)
	return out


# ===========================================================================
# HAZED — the fail state, which is a bit rather than a punishment
# ===========================================================================

## Called by the dog the instant it gets a mouthful of goose.
func on_hazed(at: Vector3) -> void:
	# --- The sixth hitstop site in the game, and it is deliberate.
	# juice.gd's budget says there are exactly five and a sixth is "almost
	# certainly wrong". This one is argued for in BOSS_DESIGN.md §2.1.3, which
	# specifies the exact call: HAZED happens at most a handful of times in
	# forty-five seconds, and it takes control away for six of them, which is
	# the same class of event as a tumble. It is also the SMALLEST hitstop in
	# the table — 0.04 at 0.4 strength, a third of a prop break — because the
	# freeze is punctuation on the grab, not the event itself.
	Juice.hitstop(0.04, 0.4)
	Juice.shake(0.45)
	Juice.burst(at + Vector3.UP * 0.4, Color(0.94, 0.94, 0.92), 18, &"feathers")
	Juice.floating_text(at + Vector3.UP * 1.5, "GOOD DOG", Color(0.98, 0.86, 0.42))

	# The stake is the combo chain and the six seconds, and nothing else. No
	# damage, no ragdoll, no bird lost. Rung 1 of the failure hierarchy.
	#
	# There is no Game API for breaking a chain — score() only ever extends one
	# — so this writes the two fields directly. BOSS_DESIGN.md §2.1.3 asks for
	# `Game.score(0, "GOOD DOG")`, which would have made it a chain LINK.
	Game.combo = 0
	Game.combo_timer = 0.0

	Mission.note(&"hazed")
	if _sfx:
		_sfx.play_at(&"human_yelp_1", self, -2.0, 0.52)
		_sfx.play_at(&"tumble", self, -8.0, 1.3)


func on_haze_ended(at: Vector3) -> void:
	Juice.floating_text(at + Vector3.UP * 1.2, "HAZED", Color(0.98, 0.62, 0.34))
	if _sfx:
		_sfx.play_at(&"thud_land", self, -6.0, 1.05)


# ===========================================================================
# THE TRUCK
# ===========================================================================

func _build_truck() -> void:
	_truck = Node3D.new()
	_truck.name = "Truck"
	add_child(_truck)
	# Authored facing -Z like everything else, so driving in down the entrance
	# corridor (toward -Z) needs no rotation at all, and leaving is a reverse.
	# A municipal contractor backing out of a cul-de-sac is the correct exit.
	_truck.global_position = park_at + Vector3(0, 0, TRUCK_APPROACH)

	PROPS.build(&"minivan", _truck, {
		"size": Vector3(2.15, 1.95, 5.20),
		"body_colour": Color(0.93, 0.93, 0.94),
	})
	var bar := VIS.build_light_bar(_truck)
	bar.position = Vector3(0, 1.98, -0.9)

	_truck_light = OmniLight3D.new()
	_truck_light.omni_range = 9.0
	_truck_light.light_energy = 0.0
	_truck_light.shadow_enabled = false
	_truck_light.position = Vector3(0, 2.1, -0.9)
	_truck.add_child(_truck_light)

	# CONSERVATION SERVICES on the doors. No real agency, no real wordmark.
	#
	# Both flanks, and each one gets its own yaw — see build_door_decals(). The
	# single -X label that used to live here read "ИOITAVЯƎƧNOƆ", because it was
	# turned to face into the truck and Label3D draws its back face by default.
	VIS.build_door_decals(_truck)

	_truck_bin = Node3D.new()
	_truck_bin.name = "Bin"
	_truck_bin.position = Vector3(0, 1.05, 1.5)
	_truck.add_child(_truck_bin)

	_truck_body = StaticBody3D.new()
	_truck_body.name = "TruckBody"
	add_child(_truck_body)
	_truck_shape = CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(2.15, 1.95, 5.20)
	_truck_shape.shape = bs
	_truck_shape.position.y = 0.975
	_truck_body.add_child(_truck_shape)
	# Disabled while it is moving. A moving StaticBody3D can shove a goose
	# through the world; a parked one is a 1.95 m platform that the dog cannot
	# reach, which makes hiding on the Ranger's own truck a legal answer.
	_truck_shape.set_deferred("disabled", true)
	_truck_body.global_position = _truck.global_position


func _tick_truck(delta: float) -> void:
	if _truck == null or not is_instance_valid(_truck):
		return
	if _truck_moving == 0:
		return
	_truck_t += delta
	var k := clampf(_truck_t / TRUCK_TIME, 0.0, 1.0)
	# Ease out on the way in (it brakes), ease in on the way out (it pulls
	# away). Same curve, read in opposite directions.
	if _truck_moving < 0:
		var e := 1.0 - pow(1.0 - k, 2.4)
		_truck.global_position = park_at + Vector3(0, 0, TRUCK_APPROACH * (1.0 - e))
		if k >= 1.0:
			_truck_moving = 0
			_truck_shape.set_deferred("disabled", false)
			if _sfx:
				_sfx.play_at(&"thud_land", self, -4.0, 0.85)
				_sfx.play_at(&"thud_land", self, -6.0, 0.78)
	else:
		var e2 := pow(k, 2.0)
		_truck.global_position = park_at + Vector3(0, 0, TRUCK_APPROACH * 1.6 * e2)
		if k >= 1.0:
			queue_free()
			return
	_truck_body.global_position = _truck.global_position


func _tick_light(delta: float) -> void:
	if _truck_light == null or not is_instance_valid(_truck_light):
		return
	var t := float(Time.get_ticks_msec()) * 0.001
	var flip := int(t * 3.0) % 2 == 0
	_truck_light.light_color = Color(0.95, 0.20, 0.18) if flip else Color(0.24, 0.42, 0.98)
	var pulse := 0.55 + 0.45 * sin(t * 18.0)
	_truck_light.light_energy = lerpf(_truck_light.light_energy, pulse * 1.4,
		1.0 - pow(0.02, delta))


# ===========================================================================
# BODIES
# ===========================================================================

func _build_ranger() -> void:
	var r := Ranger.new()
	r.name = "Ranger"
	r.boss = self
	add_child(r)
	# On the CUL-DE-SAC side of the truck (-X), not the roadside.
	#
	# Spawned at +X he and the dog were both pinned against the truck's own
	# 2.15 x 5.2 collider for the entire encounter, because every substance
	# source in the zone is west of the mouth and the truck was in the way. Two
	# renders in a row caught this; it is not obvious from the code.
	r.global_position = park_at + Vector3(-2.7, 0.6, 1.9)
	_ranger = r
	_refresh_board()


func _build_dog() -> void:
	var d := Piper.new()
	d.name = "Piper"
	d.boss = self
	d.goose = goose
	d.drop_at = drop_at
	add_child(d)
	d.global_position = park_at + Vector3(-3.6, 0.4, 3.2)
	_dog = d


func ranger_position() -> Vector3:
	if _ranger and is_instance_valid(_ranger):
		return _ranger.global_position
	return park_at


# ===========================================================================
# ═══ THE RANGER ═══
# ===========================================================================

## A person on a fixed errand. Built on npc_human.gd's contracts rather than
## extending it: same "npc" group, same `startle(from)` signature, same
## human_visual_lowpoly.gd body — so the honk, the cats and anything else that
## already knows how to bother a person bothers him for free — but with a state
## machine instead of a wander, which is the one thing NpcHuman cannot lend.
class Ranger extends CharacterBody3D:
	const BODY_VIS := preload("res://scripts/world/human_visual_lowpoly.gd")
	const KIT := preload("res://scripts/world/boss_ranger_visual.gd")

	## Slower than a waddle (4.2). He is not the threat and his speed says so.
	const WALK := 2.4
	const FLINCH_TIME := 1.8
	const FLINCH_CD := 2.4

	var boss: Node = null
	var held_board: Node3D = null

	var _goal := Vector3.ZERO
	var _has_goal := false
	var _flinch := 0.0
	var _flinch_cd := 0.0
	var _retrieve: Node3D = null
	var _given_up := false
	var _lp: Node3D = null
	var _say: Label3D = null
	var _say_t := 0.0
	var _sfx: Node = null
	var _arm: Node3D = null
	var _forearm: Node3D = null
	var _arm_l: Node3D = null
	var _forearm_l: Node3D = null
	var _prev := Vector3.ZERO
	var _stall := 0.0
	var _slide := 0.0
	var _slide_side := 1.0


	func _ready() -> void:
		_sfx = get_node_or_null("/root/Sfx")
		add_to_group("npc")

		var cs := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.3
		cap.height = 1.7
		cs.shape = cap
		cs.position.y = 0.85
		add_child(cs)

		_lp = BODY_VIS.new()
		_lp.name = "VisLP"
		# No y offset. human_visual_lowpoly.gd used to end its shoe blocks 6.6 cm
		# below its own origin, and this line lifted the visual to compensate.
		# That is fixed at the source now (BODY_VIS's HIP_Y), so a compensator
		# here would lift the Ranger 6.6 cm off the pavement instead.
		add_child(_lp)
		# A dull municipal work shirt UNDER the vest, not a hi-vis shirt. The
		# vest has to read as issued kit sitting on top of a person.
		_lp.call("setup", Color(0.34, 0.40, 0.46), Color(0.20, 0.26, 0.22),
			Color(0.84, 0.66, 0.53))

		var body_node: Node3D = _lp.get("body")
		if body_node:
			KIT.build_vest(body_node)
		var head_node: Node3D = _lp.get("head")
		if head_node:
			KIT.build_cap(head_node)

		var arm_r: Node3D = _lp.get("arm_r")
		if arm_r:
			_arm = arm_r
			_forearm = arm_r.get_node_or_null("Forearm")
		_arm_l = _lp.get("arm_l")
		if _arm_l:
			_forearm_l = _arm_l.get_node_or_null("Forearm")

		# The board hangs off the TORSO, not off the hand.
		#
		# Parented to the forearm it rendered as a brown slab floating a hand's
		# width out in front of a zombie-stiff arm, because the forearm's local
		# frame is upside down relative to the pose and the two rotations fight.
		# Mounting it on the chest and posing both arms UP TO it is one number
		# to tune instead of four, and it reads correctly from every angle the
		# camera can get to.
		if body_node:
			held_board = Node3D.new()
			held_board.name = "HeldBoard"
			# Belly height and tilted up, not chest height and upright: at chest
			# height a 0.38 m board covers the entire hi-vis vest from the front,
			# and the vest is the read that says which kind of man this is.
			held_board.position = Vector3(0.02, 0.19, -0.26)
			held_board.rotation = Vector3(-0.86, 0.0, 0.0)
			body_node.add_child(held_board)
			KIT.build_clipboard(held_board)
			if boss and boss.has_method("_attach_board_label"):
				boss.call("_attach_board_label", held_board)

		_say = Label3D.new()
		_say.name = "Say"
		_say.pixel_size = 0.0042
		_say.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_say.shaded = false
		_say.double_sided = true
		# WRAP IT. An unwrapped Label3D is one line of any length in world space,
		# and his longest line — "...Canadian geese, approximately—" — is about
		# 2.3 m of it. He delivers that line while walking past the camera at
		# arm's length, so a render of the encounter is a screen with the word
		# "...Canadian" across it and the rest of the sentence off both edges.
		# 420 px at this pixel_size caps him at 1.76 m and breaks the line
		# instead, which is what a speech bubble is supposed to do.
		_say.width = 420.0
		_say.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_say.outline_size = 6
		_say.outline_modulate = Color(0, 0, 0, 0.85)
		_say.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_say.position = Vector3(0, 2.15, 0)
		_say.render_priority = 2
		_say.visible = false
		add_child(_say)


	## Exactly four lines per appearance, per the spec. No card, no popup.
	func say(text: String, secs := 3.0) -> void:
		if _say == null:
			return
		_say.text = text
		_say.visible = true
		_say_t = secs


	func set_goal(p: Vector3) -> void:
		_goal = p
		_has_goal = true


	func is_busy() -> bool:
		return _flinch > 0.0 or _retrieve != null or _given_up


	func go_retrieve(prop: Node3D) -> void:
		_retrieve = prop


	## The clipboard is in pieces. He stops sweeping; he still walks to the
	## truck, because _tick_depart drives him regardless of is_busy().
	func give_up() -> void:
		_given_up = true
		_retrieve = null
		if held_board:
			held_board.visible = false


	## The honk's hook, and the cats'. NpcHuman calls this method name, honk.gd
	## looks it up by name, and cat.gd's pounce calls it too — so setting a
	## frenzied cat on the man works with no code anywhere knowing about it,
	## which BOSS_DESIGN.md §2.1.6 correctly calls the best joke in the fight.
	func startle(from: Vector3) -> void:
		if _flinch_cd > 0.0 or _given_up:
			return
		_flinch_cd = FLINCH_CD
		_flinch = FLINCH_TIME
		# Pop the VISUAL, not the body. npc_human.gd pops itself, which drags a
		# 1.7 m capsule collider through the pavement; cat.gd's comment explains
		# why that is wrong and this follows the comment rather than the code.
		if _lp:
			Juice.pop(_lp, 0.26, 0.22)
		if _sfx:
			_sfx.play_var([&"human_yelp_1", &"human_yelp_2"], -2.0, 0.12)
		say("— I lost count.", 2.2)
		if boss and boss.has_method("on_flinch"):
			boss.call("on_flinch", from)


	func _physics_process(delta: float) -> void:
		_flinch_cd = maxf(0.0, _flinch_cd - delta)
		if _say_t > 0.0:
			_say_t -= delta
			if _say_t <= 0.0 and _say:
				_say.visible = false

		var speed := WALK
		var dir := Vector3.ZERO

		if _flinch > 0.0:
			_flinch -= delta
			speed = 0.0
			if _lp:
				_lp.call("animate", delta, 0.0, 1.0)
		else:
			if _retrieve != null:
				if not is_instance_valid(_retrieve):
					# Somebody destroyed it while he was walking back. give_up()
					# is driven from the boss on the break event; this is the
					# case where it simply stopped existing.
					_retrieve = null
				else:
					_goal = _retrieve.global_position
					_has_goal = true
					if global_position.distance_to(_goal) < 1.3:
						_pick_up()
			if _has_goal:
				var to := _goal - global_position
				to.y = 0.0
				if to.length() > 0.6:
					dir = to.normalized()
					# Wall following. There is no navmesh in this project and
					# Suburbia is nothing but fences, houses and parked cars, so
					# a man who walks in a straight line stands in one for the
					# whole encounter. If he stops making ground while he still
					# wants to, he picks a side and slides along whatever it is
					# for a second and a half. Crude, cheap, and it is the
					# difference between a boss and a statue.
					if global_position.distance_to(_prev) < 0.06:
						_stall += delta
					else:
						_stall = 0.0
						_prev = global_position
					if _stall > 0.7 and _slide <= 0.0:
						_stall = 0.0
						_slide = 1.5
						_slide_side = 1.0 if randf() < 0.5 else -1.0
					if _slide > 0.0:
						_slide -= delta
						var side := Vector3(-dir.z, 0.0, dir.x) * _slide_side
						dir = (dir * 0.35 + side).normalized()
				else:
					speed = 0.0
			else:
				speed = 0.0
			if _lp:
				_lp.call("animate", delta, speed / WALK, 0.0)

		# Both hands up to the board, AFTER animate() has run its walk cycle over
		# the same joints. A clipboard swinging at his side would be a
		# different, worse character. When he has dropped it the arms go back to
		# the normal gait, which is most of what sells the flinch.
		if held_board and held_board.visible:
			var k := 1.0 - pow(0.01, delta)
			if _arm:
				_arm.rotation.x = lerpf(_arm.rotation.x, -0.62, k)
				_arm.rotation.z = lerpf(_arm.rotation.z, -0.34, k)
			if _forearm:
				_forearm.rotation.x = lerpf(_forearm.rotation.x, -1.02, k)
			if _arm_l:
				_arm_l.rotation.x = lerpf(_arm_l.rotation.x, -0.62, k)
				_arm_l.rotation.z = lerpf(_arm_l.rotation.z, 0.34, k)
			if _forearm_l:
				_forearm_l.rotation.x = lerpf(_forearm_l.rotation.x, -1.02, k)

		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		velocity.y -= 22.0 * delta
		if is_on_floor():
			velocity.y = 0.0
		if dir.length() > 0.05:
			rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z),
				clampf(6.0 * delta, 0.0, 1.0))
		move_and_slide()


	## And here is the joke: he has to pick it up again, and that costs him four
	## more seconds than the flinch did.
	func _pick_up() -> void:
		if _retrieve and is_instance_valid(_retrieve):
			_retrieve.queue_free()
		_retrieve = null
		if held_board:
			held_board.visible = true
		say("Right. Where was I.", 2.0)


# ===========================================================================
# ═══ PIPER ═══
# ===========================================================================

## The dog, forked from cat.gd's wander/acquire/frenzy shape with different
## numbers and one extra state. It is the only thing in the game that outruns a
## goose on the ground, it has no Y axis, and it does not care about honks.
##
## It is in the "npc" group ON PURPOSE: that is what makes a catnip-frenzied cat
## treat it as a target, which is the encounter's intended emergent solution and
## costs zero lines in cat.gd.
class Piper extends CharacterBody3D:
	const DOG_VIS := preload("res://scripts/world/boss_ranger_visual.gd")

	const HEEL_SPEED := 4.6
	const PURSUE_SPEED := 9.5
	const CARRY_SPEED := 8.2
	## The acquisition radius from the spec. Outside it you are not interesting.
	const ACQUIRE := 22.0
	const LOSE := 42.0
	const CATCH := 1.15
	## How high off the dog's own feet counts as out of reach.
	##
	## BOSS_DESIGN.md §2.1.3 says 2.2 m, and then lists "roof, trampoline,
	## fence, minivan roof, a tree" as the places to go. Suburbia's fences are
	## 1.7 m and its minivans 1.9 m, so at 2.2 m two of the spec's own four
	## examples are not sanctuary. 1.55 m keeps every listed escape and still
	## excludes the trampoline mat (0.7 m), which should be a launcher and not a
	## hiding place.
	const REACH_HEIGHT := 1.55
	const CARRY_MAX := 6.5
	## Long enough that the dog has to run all the way back from the drop point
	## before it may re-acquire, so an idle goose gets hazed on a rhythm rather
	## than continuously.
	const GRAB_COOLDOWN := 6.0

	enum Mode { HEEL, PURSUE, GIVEUP, CARRY, RETURN, OFF }

	var boss: Node = null
	var goose: CharacterBody3D = null
	var drop_at := Vector3.ZERO

	var _mode: int = Mode.HEEL
	var _lp: Node3D = null
	var _sfx: Node = null
	var _t := 0.0
	var _bark_t := 0.0
	var _quarter := Vector3.ZERO
	var _quarter_t := 0.0
	var _unreachable_t := 0.0
	var _pursue_t := 0.0
	var _best_gap := 1e9
	var _gap_t := 0.0
	var _giveup_t := 0.0
	var _grab_cd := 0.0
	var _arm_t := 8.0
	var _carry_t := 0.0
	var _distract := 0.0
	var _distract_at := Vector3.ZERO
	var _excite := 0.0

	var _goose_mode := Node.PROCESS_MODE_INHERIT
	var _carrying := false


	func _ready() -> void:
		_sfx = get_node_or_null("/root/Sfx")
		add_to_group("npc")

		var cs := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.20
		cap.height = 0.82
		cs.shape = cap
		cs.rotation_degrees = Vector3(90, 0, 0)
		# 0.20, NOT half the height. Laid on its side a capsule's vertical
		# half-extent is its RADIUS, so a shape parked at 0.34 rests the body
		# origin at -0.17 and buries the dog to the knees. Rendered and caught.
		cs.position.y = 0.20
		add_child(cs)

		_lp = DOG_VIS.new()
		_lp.name = "VisLP"
		add_child(_lp)
		_lp.call("setup")
		_new_quarter()


	func _exit_tree() -> void:
		abort_carry()


	func stand_down() -> void:
		abort_carry()
		_mode = Mode.RETURN


	## Idempotent. Called from _exit_tree, from the boss's _stand_down, and from
	## the normal end of a carry, and it must be safe from all three.
	func abort_carry() -> void:
		if not _carrying:
			return
		_carrying = false
		_release_goose()


	# ------------------------------------------------------------ perception

	func _reachable() -> bool:
		if goose == null or not is_instance_valid(goose):
			return false
		if goose.has_method("is_airborne") and goose.is_airborne():
			return false
		return goose.global_position.y < global_position.y + REACH_HEIGHT


	func _gap() -> float:
		if goose == null or not is_instance_valid(goose):
			return 1e9
		var a := global_position
		var b := goose.global_position
		return Vector2(a.x - b.x, a.z - b.z).length()


	## cat.gd calls startle() on anything in the "npc" group when it pounces,
	## and so does honk.gd. Both hand us a world position and nothing else, so
	## the two are told apart by whether there is a cat standing at it. A honk
	## comes from the goose, which is never inside a cat.
	##
	## That distinction is the entire two-body rule: the dog is the thing the
	## honk does not work on.
	func startle(from: Vector3) -> void:
		var cat_did_it := false
		for c in get_tree().get_nodes_in_group("cat"):
			if c is Node3D and c.global_position.distance_to(from) < 2.0:
				cat_did_it = true
				break
		if cat_did_it:
			_distract = 3.0
			_distract_at = from
			if _lp:
				Juice.pop(_lp, 0.3, 0.2)
			if _sfx:
				_sfx.play_var([&"human_yelp_1", &"human_yelp_2"], -6.0, 0.1)
			Juice.floating_text(global_position + Vector3.UP * 0.9, "!",
				Color(0.55, 0.92, 0.42))
			return
		# A honk. It came for this.
		_excite = 1.6
		_bark(0.0)


	# ------------------------------------------------------------ frame

	func _physics_process(delta: float) -> void:
		_t += delta
		# The arrival beat belongs to the truck, the horn and the line. A dog
		# that acquires you at t=0.7 (measured, in the first render) eats it.
		_arm_t = maxf(0.0, _arm_t - delta)
		_grab_cd = maxf(0.0, _grab_cd - delta)
		_distract = maxf(0.0, _distract - delta)
		_excite = maxf(0.0, _excite - delta)
		_bark_t -= delta

		match _mode:
			Mode.CARRY:
				_tick_carry(delta)
				return
			Mode.GIVEUP:
				_tick_giveup(delta)
			Mode.RETURN:
				_tick_heel(delta, true)
				if _grab_cd <= 0.0:
					_mode = Mode.HEEL
			Mode.OFF:
				_tick_heel(delta, true)
			Mode.PURSUE:
				_tick_pursue(delta)
			_:
				_tick_heel(delta, false)


	func _new_quarter() -> void:
		_quarter_t = randf_range(1.1, 2.4)
		var a := randf_range(0.0, TAU)
		_quarter = Vector3(cos(a), 0.0, sin(a)) * randf_range(3.0, 9.0)


	## Quartering the ground between the man and you, which is what a working
	## collie does when it has not been given anything specific to do.
	func _tick_heel(delta: float, passive: bool) -> void:
		var anchor := global_position
		if boss and is_instance_valid(boss) and boss.has_method("ranger_position"):
			anchor = boss.call("ranger_position")
		var mid := anchor
		if goose and is_instance_valid(goose) and not passive:
			mid = anchor.lerp(goose.global_position, 0.35)

		_quarter_t -= delta
		if _quarter_t <= 0.0:
			_new_quarter()
		_steer(mid + _quarter, HEEL_SPEED, delta, 0.25)

		if passive:
			return
		if _distract > 0.0:
			return
		if _grab_cd > 0.0 or _arm_t > 0.0:
			return
		if _reachable() and _gap() < ACQUIRE:
			_mode = Mode.PURSUE
			_pursue_t = 0.0
			_unreachable_t = 0.0
			_best_gap = _gap()
			_gap_t = 0.0
			_bark(-2.0)


	func _tick_pursue(delta: float) -> void:
		if goose == null or not is_instance_valid(goose):
			_mode = Mode.HEEL
			return
		if _distract > 0.0:
			_steer(_distract_at, PURSUE_SPEED * 0.8, delta, 0.9)
			return

		_pursue_t += delta
		var g := _gap()

		if g > LOSE:
			_mode = Mode.HEEL
			return

		if not _reachable():
			_unreachable_t += delta
			if _unreachable_t > 1.3:
				_begin_giveup()
				return
		else:
			_unreachable_t = 0.0

		# Anti-stuck. If a fence, a house corner or a deck is between the dog
		# and the goose, the gap stops closing — and a dog that runs at a wall
		# for the whole encounter is neither funny nor beatable.
		_gap_t += delta
		if g < _best_gap - 0.8:
			_best_gap = g
			_gap_t = 0.0
		elif _gap_t > 4.0:
			_begin_giveup()
			return

		var spd := PURSUE_SPEED * (1.18 if _excite > 0.0 else 1.0)
		_steer(goose.global_position, spd, delta, 1.0)

		if _bark_t <= 0.0:
			_bark(-6.0)

		if g < CATCH and _reachable() and _grab_cd <= 0.0 and not Subs.blacked_out:
			_grab()


	func _begin_giveup() -> void:
		_mode = Mode.GIVEUP
		_giveup_t = 3.2
		_bark(-1.0)


	## Barking at the bottom of a wall it cannot climb. This is the encounter's
	## reward beat: the thing that was faster than you is now a dog under a roof.
	func _tick_giveup(delta: float) -> void:
		_giveup_t -= delta
		var at := global_position
		if goose and is_instance_valid(goose):
			at = Vector3(goose.global_position.x, global_position.y, goose.global_position.z)
		_steer(at, HEEL_SPEED, delta, 0.6)
		if _bark_t <= 0.0:
			_bark(-4.0)
		# Look up at it.
		if _lp:
			_lp.call("animate", delta, 0.2, 0.0)
		if _giveup_t <= 0.0:
			_mode = Mode.HEEL
			_grab_cd = maxf(_grab_cd, 1.2)


	# ------------------------------------------------------------ the carry

	func _grab() -> void:
		if goose == null or not is_instance_valid(goose):
			return
		_mode = Mode.CARRY
		_carry_t = 0.0
		_carrying = true
		_goose_mode = goose.process_mode
		# The only way to take the controls away without editing
		# goose_controller.gd, which is not this file's to edit. The camera
		# keeps working because it reads global_position and velocity, and both
		# are driven below.
		goose.process_mode = Node.PROCESS_MODE_DISABLED
		goose.velocity = Vector3.ZERO
		if boss and is_instance_valid(boss) and boss.has_method("on_hazed"):
			boss.call("on_hazed", goose.global_position)


	func _tick_carry(delta: float) -> void:
		if goose == null or not is_instance_valid(goose):
			_carrying = false
			_mode = Mode.HEEL
			return
		_carry_t += delta
		var target := drop_at
		var to := target - global_position
		to.y = 0.0
		var arrived := to.length() < 2.0

		_steer(target, CARRY_SPEED, delta, 1.0)

		# In the mouth: forward of the head, at head height, wobbling.
		#
		# The first render had this 0.62 up, which put a full-size Canada goose
		# floating above a collie's skull instead of hanging out of its jaws.
		# 0.34 lands the bird's body on the dog's head, which is the read.
		var mouth := global_position + (-global_transform.basis.z * 0.55) + Vector3.UP * 0.34
		goose.global_position = mouth
		# The camera leads on velocity, so feed it the real one or the ride
		# frames badly.
		goose.velocity = velocity
		# Pitched forward and swinging: a carried bird is limp, not a passenger.
		goose.rotation = Vector3(0.30, rotation.y, sin(_carry_t * 17.0) * 0.30)

		if _lp:
			_lp.call("carry_pose", delta)

		# Hard ceiling regardless of where it got to. This is the anti-soft-lock
		# guarantee: six and a half seconds, always, even if the dog is wedged.
		if arrived or _carry_t > CARRY_MAX:
			_release_goose()
			_carrying = false
			_mode = Mode.RETURN
			_grab_cd = GRAB_COOLDOWN
			if boss and is_instance_valid(boss) and boss.has_method("on_haze_ended"):
				boss.call("on_haze_ended", goose.global_position)
			_bark(-3.0)


	func _release_goose() -> void:
		if goose == null or not is_instance_valid(goose):
			return
		goose.process_mode = _goose_mode
		goose.velocity = Vector3.ZERO
		var p := goose.global_position
		# Put it down, do not drop it into the asphalt.
		goose.global_position = Vector3(p.x, maxf(p.y, 0.7), p.z)
		goose.rotation = Vector3(0.0, rotation.y, 0.0)
		# `heading` is the controller's authoritative yaw; without this it snaps
		# back to whatever it was facing before the grab on the next frame.
		if goose.get("heading") != null:
			goose.set("heading", rotation.y)


	# ------------------------------------------------------------ locomotion

	func _steer(target: Vector3, speed: float, delta: float, chase: float) -> void:
		var to := target - global_position
		to.y = 0.0
		var dir := Vector3.ZERO
		if to.length() > 0.35:
			dir = to.normalized()
		else:
			speed = 0.0

		velocity.x = move_toward(velocity.x, dir.x * speed, 30.0 * delta)
		velocity.z = move_toward(velocity.z, dir.z * speed, 30.0 * delta)
		velocity.y -= 22.0 * delta
		if is_on_floor():
			velocity.y = 0.0
		if dir.length() > 0.05:
			rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z),
				clampf(9.0 * delta, 0.0, 1.0))
		move_and_slide()

		if _lp and _mode != Mode.CARRY:
			var s := Vector2(velocity.x, velocity.z).length() / PURSUE_SPEED
			_lp.call("animate", delta, s, chase)


	## There is no bark sample in the project. A human yelp at half pitch is a
	## surprisingly good woof and it is the only thing in audio/ that is close.
	## tools/gen_audio.py should grow a real one; until then this is honest
	## placeholder audio rather than silence.
	func _bark(db: float) -> void:
		_bark_t = randf_range(0.55, 1.1)
		if _sfx:
			_sfx.play_at(&"human_yelp_%d" % (1 + randi() % 2), self, db - 4.0,
				randf_range(0.46, 0.58))
