extends Node3D
## THE FLOCK PEN — your flock, standing in the zone, where you can see them.
##
## ── WHY THIS EXISTS ─────────────────────────────────────────────────────
## The migration already honours `Flock.birds[i].is_dd`: a sober goose can
## always take a lead shift, which is worth more than anything else you can
## carry into the flight. But there was no way to SET it. The mechanic existed
## and was unreachable, so the only lever the player had over their flock was
## the blanket `Flock.dose_flock()` on the share key — an action with a cost
## they could not see and a counterweight they could not use.
##
## Two problems, one object:
##
##   1. **The DD becomes a decision you make in the world.** Walk up to a
##      specific goose, press G, and that bird is out for the rest of the run.
##      It wears a hi-vis vest so the choice is visible for the whole leg, and
##      it refuses every substance from then on — `Flock.set_dd()` already
##      guarantees that, because both `dose_flock()` and `dose_bird()` skip a DD.
##
##   2. **The flock's condition becomes visible DURING the zone.** Previously
##      you found out what you had done to your friends when the flight started
##      wobbling. Now a wrecked goose sits lower, lists, wanders in circles and
##      is labelled WRECKED in red from across the lot. That is the whole
##      cause-and-effect chain of this game — dose them, watch them fall apart,
##      pay for it in the air — and it was entirely invisible in the middle
##      third of it.
##
## The share key gains a second, better mode here: standing near the flock and
## pressing Q doses THE GEESE YOU ARE STANDING NEXT TO instead of everybody. It
## is the same verb, but aimed — you can dose four and keep two clean, which is
## the difference between "sharing is a trap" and "sharing is a decision".
##
## ── ADDING IT TO A ZONE ─────────────────────────────────────────────────
## One line, at the end of the zone's _ready(), after the goose exists:
##
##     add_child(preload("res://scripts/world/flock_pen.gd").new().setup(
##         Vector3(-24, 0.6, -12)))
##
## `setup()` only records the centre and returns self, so it is safe to call
## before the node is in the tree. Everything else — finding the player, finding
## the ground, building the birds — happens in _ready()/_physics_process().
##
## ── DELIBERATELY NOT PHYSICAL ───────────────────────────────────────────
## The pen geese have no colliders. A StaticBody goose is a bollard you get
## wedged behind; a RigidBody goose is a thing you punt across the lot, which is
## extremely funny for four seconds and then your designated driver is on a
## roof. They are ghosts you walk among. The interaction is proximity, and
## proximity does not need a collider.

const LPB := preload("res://scripts/goose/lowpoly_builder.gd")

## Both scripts expose an identical API (animate / set_bank / set_tint /
## tint_targets / body), so nothing here cares which one is live. Same table the
## goose controller uses, for the same reason.
const MODEL_SCRIPTS := {
	"classic": "res://scripts/goose/goose_visual.gd",
	"lowpoly": "res://scripts/goose/goose_visual_lowpoly.gd",
}

## Registered here rather than in project.godot, matching how Game and the
## mission HUD handle their own actions: version-proof and visible in a diff.
const ACTION_DESIGNATE := "gg_designate"

## How close you have to be to name a bird. Generous — this is a comedy sandbox
## and a precision-aim requirement on a menu action is a cruelty.
const DESIGNATE_RANGE := 3.4
## How close a goose has to be to catch a targeted share.
const SHARE_RANGE := 5.0
## What a targeted share costs each bird it lands on. Higher than the blanket
## 0.32 on purpose: aiming it is more deliberate, so it should be worth more per
## goose AND hurt more per goose. A decision with no downside isn't one.
const SHARE_DOSE := 0.42

## Both goose models put their origin at the hips, not at the feet: the body
## loft spans roughly +/-0.34 around it and the webbed foot plate bottoms out at
## -0.44. Dropping a bird straight onto a raycast hit therefore buries it to the
## waterline, which is exactly what the first render showed.
const STAND_HEIGHT := 0.46

## Ground probe geometry. See `_ground_at()` for why the up margin is small and
## why that is the whole fix.
const GROUND_UP_MARGIN := 0.6
const GROUND_DOWN_REACH := 8.0

const C_VEST := Color(0.98, 0.86, 0.10)
const C_VEST_STRIPE := Color(0.88, 0.90, 0.94)

const C_FINE := Color(0.55, 0.92, 0.62)
const C_LOOSE := Color(0.96, 0.88, 0.38)
const C_ROUGH := Color(0.98, 0.62, 0.28)
const C_WRECKED := Color(0.98, 0.36, 0.32)
const C_DD := Color(1.00, 0.94, 0.24)

## Emitted after a successful designation, so a zone or the HUD can toast it.
signal dd_designated(index: int, bird_name: String)
## Emitted after a targeted share, with how many birds it actually landed on.
signal flock_dosed(count: int)

## The bird the player is currently close enough to name. -1 for none.
var focus_index := -1
## Set this before _ready() if the zone's `goose` property isn't the player.
var player: Node3D = null

var _centre := Vector3.ZERO
var _birds: Array[Dictionary] = []   ## one entry per pen goose, see _build()
var _flock: Node = null
var _subs: Node = null
var _sfx: Node = null
var _prefs: Node = null
var _juice: Node = null
var _grounded := false
var _t := 0.0
var _grumble_cd := 2.0
## Round-robin cursor for the ground probe: one raycast per physics frame, not
## one per bird per frame.
var _ground_cursor := 0


## Record where the flock stands. Returns self so a zone can add it in one line.
## Also names the node, because the one-line form gives Godot no chance to —
## and a pen called "@Node3D@7" is a pen nothing else can find.
func setup(spawn_centre: Vector3) -> Node3D:
	_centre = spawn_centre
	name = "FlockPen"
	return self


func _ready() -> void:
	_flock = get_node_or_null("/root/Flock")
	_subs = get_node_or_null("/root/Subs")
	_sfx = get_node_or_null("/root/Sfx")
	_prefs = get_node_or_null("/root/Prefs")
	_juice = get_node_or_null("/root/Juice")
	_ensure_action()
	_resolve_player()
	_build()
	if _flock != null and _flock.has_signal("bird_dosed"):
		if not _flock.bird_dosed.is_connected(_on_bird_dosed):
			_flock.bird_dosed.connect(_on_bird_dosed)
	if _prefs != null and _prefs.has_signal("pref_changed"):
		if not _prefs.pref_changed.is_connected(_on_pref_changed):
			_prefs.pref_changed.connect(_on_pref_changed)


func _ensure_action() -> void:
	if InputMap.has_action(ACTION_DESIGNATE):
		return
	InputMap.add_action(ACTION_DESIGNATE)
	var ev := InputEventKey.new()
	# G is the only unclaimed letter near the movement hand: E charges a dose,
	# Q shares, H/F honk, R restarts, TAB toggles objectives.
	ev.physical_keycode = KEY_G
	InputMap.action_add_event(ACTION_DESIGNATE, ev)
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_LEFT_SHOULDER
	InputMap.action_add_event(ACTION_DESIGNATE, pad)


func _resolve_player() -> void:
	if player != null and is_instance_valid(player):
		return
	var p := get_parent()
	if p != null:
		var g = p.get("goose")
		if g is Node3D:
			player = g
			return
	# Fallback for a zone that keeps its bird somewhere else.
	var group := get_tree().get_nodes_in_group("player")
	if not group.is_empty():
		var n = group[0]
		if n is Node3D:
			player = n


# ══════════════════════════════════════════════════════════════════ BUILD

func _model_path() -> String:
	var key := "lowpoly"
	if _prefs != null:
		key = str(_prefs.get_pref(&"goose_model", "lowpoly"))
	if not MODEL_SCRIPTS.has(key):
		key = "lowpoly"
	var path: String = MODEL_SCRIPTS[key]
	return path


func _build() -> void:
	for b in _birds:
		var old: Dictionary = b
		var root: Node3D = old["root"]
		if is_instance_valid(root):
			root.queue_free()
	_birds.clear()
	if _flock == null:
		return

	var raw: Array = _flock.birds
	var alive: Array[int] = []
	for i in raw.size():
		var rec: Dictionary = raw[i]
		if bool(rec.get("alive", true)):
			alive.append(i)
	if alive.is_empty():
		return

	var model := _model_path()
	var n := alive.size()
	for slot in n:
		var index: int = alive[slot]
		var rec2: Dictionary = raw[index]

		# A loose arc facing roughly back toward the middle, rather than a ring
		# or a grid. A grid of geese reads as a car park; an arc reads as a
		# gaggle that was standing here before you turned up.
		var ang := PI * (-0.55 + 1.10 * (float(slot) + 0.5) / float(n))
		var rad := 2.1 + 0.9 * float(slot % 3)
		var home := _centre + Vector3(sin(ang) * rad, 0.0, cos(ang) * rad)

		var root := Node3D.new()
		root.name = "Goose_%d" % index
		add_child(root)
		root.global_position = home
		root.rotation.y = ang + PI

		var model_script: GDScript = load(model)
		var visual: Node3D = model_script.new()
		visual.name = "Visual"
		root.add_child(visual)

		var name_lbl := _label(str(rec2.get("name", "?")), 0.0070, 1.34, 18)
		root.add_child(name_lbl)
		var state_lbl := _label("", 0.0050, 1.19, 14)
		root.add_child(state_lbl)
		# ABOVE THE GAGGLE, NOT UNDER ITS CHINS.
		#
		# This sat at 1.03, below the name tag at 1.34 and below head height on a
		# bird that stands about 1.3 m tall. Six geese cluster around the pen, so
		# the prompt for the one you are next to was drawn BEHIND the necks of
		# the ones in front of it: a render of leg 1 caught it as
		# `[G] …AKE GOR… THE DD`, with a goose neck through the middle of it.
		#
		# `no_depth_test` is not the answer and stays off — a label that shines
		# through the strip mall wall tells the player their flock is inside the
		# building, which is the reason given at `_label()` and it is a good one.
		# Lifting the prompt clear of the flock's own geometry fixes the same
		# problem without lying about where anything is.
		var prompt_lbl := _label("", 0.0052, 1.66, 14, 4)
		prompt_lbl.visible = false
		root.add_child(prompt_lbl)

		_birds.append({
			"index": index,
			"root": root,
			"visual": visual,
			"name_lbl": name_lbl,
			"state_lbl": state_lbl,
			"prompt_lbl": prompt_lbl,
			"vest": null,
			"home": home,
			"target": home,
			"heading": root.rotation.y,
			"phase": randf() * TAU,
			"wander": randf_range(1.5, 4.0),
			"speed": 0.0,
			"tint": Color.WHITE,
			"bob": 0.0,
			"ground_y": home.y,
			"neck": visual.get("neck"),
		})

	_sync_vests()


## Billboarded name/state tags. `no_depth_test` is deliberately OFF — a label
## that shines through the strip mall wall tells the player their flock is
## inside the building.
func _label(txt: String, px: float, height: float, outline: int, priority: int = 1) -> Label3D:
	var l := Label3D.new()
	l.text = txt
	l.pixel_size = px
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.double_sided = true
	l.shaded = false
	l.fixed_size = false
	l.outline_size = outline
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.position = Vector3(0, height, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Keeps the tag readable across the whole lot without becoming a billboard
	# the size of a minivan when you stand on top of it.
	#
	# `priority` orders these labels AGAINST EACH OTHER, and only against each
	# other — `no_depth_test` stays off, so none of them shines through the strip
	# mall wall. Six birds stand in a gaggle with three tags each, and at 1 they
	# all sorted equally: a render of leg 1 caught the interaction prompt
	# crossed by two other birds' name tags into an unreadable smear reading
	# `[G] …AKE GOR… THE DD`.
	#
	# A PROMPT IS NOT DECORATION. The names and conditions are things you may
	# read; the prompt is the only one that tells you a button does something
	# right now, so it wins ties against them.
	l.render_priority = priority
	return l


func _on_pref_changed(key: StringName, _value) -> void:
	if key == &"goose_model":
		_build()


# ═══════════════════════════════════════════════════════════════ THE VEST
#
# Built with LowPolyBuilder so it is the same faceted vocabulary as the bird
# it's strapped to: a blocky torso band plus two reflective bands and a collar.
# It is deliberately a size too big and slightly angular — a hi-vis vest on a
# goose should look like it was issued, not tailored.

func _make_vest() -> MeshInstance3D:
	var b: RefCounted = LPB.new()
	# Torso band, a shade wider than the body's widest section (half-width 0.38)
	# so it sits ON the bird rather than inside it.
	b.box(Vector3(0.0, -0.005, -0.09), Vector3(0.395, 0.215, 0.235), C_VEST)
	# Two reflective bands around the barrel. Thin boxes rather than painted
	# faces: at this facet density a painted stripe on a box IS a box.
	b.box(Vector3(0.0, -0.005, -0.185), Vector3(0.405, 0.225, 0.030), C_VEST_STRIPE)
	b.box(Vector3(0.0, -0.005, 0.010), Vector3(0.405, 0.225, 0.030), C_VEST_STRIPE)
	# Shoulder yoke, so the vest reads from directly above — which is where the
	# camera usually is.
	b.box(Vector3(0.0, 0.175, -0.20), Vector3(0.26, 0.055, 0.115), C_VEST)
	var mi := MeshInstance3D.new()
	mi.name = "Vest"
	mi.mesh = b.commit()
	mi.material_override = LPB.make_material(0.55)
	return mi


## Bring every bird's vest into line with whoever `Flock.designated_driver()`
## currently is. Idempotent, so it is safe to call whenever anything changed.
func _sync_vests() -> void:
	if _flock == null:
		return
	var dd: int = int(_flock.designated_driver())
	for b in _birds:
		var bird: Dictionary = b
		var index: int = bird["index"]
		var have = bird["vest"]
		var want := index == dd
		if want and (have == null or not is_instance_valid(have)):
			var vest := _make_vest()
			var visual: Node3D = bird["visual"]
			# Parent to the body node when the model exposes one, so the vest
			# waddles and banks with the bird instead of floating beside it.
			var host: Node3D = visual
			var body = visual.get("body")
			if body is Node3D:
				host = body
			host.add_child(vest)
			bird["vest"] = vest
		elif not want and have != null and is_instance_valid(have):
			have.queue_free()
			bird["vest"] = null


# ══════════════════════════════════════════════════════════════════ INPUT
#
# _input, not _unhandled_input. The goose controller handles gg_share in
# _unhandled_input, and _input runs for the whole tree first — so consuming the
# event here reliably suppresses the blanket dose_flock() no matter what order
# the zone happened to add its children in. Relying on reverse-tree-order
# between two _unhandled_input handlers would work right up until somebody
# reordered a zone's _ready().

func _input(e: InputEvent) -> void:
	if _birds.is_empty():
		return
	if e.is_action_pressed(ACTION_DESIGNATE):
		if _designate(focus_index):
			get_viewport().set_input_as_handled()
		return
	if e.is_action_pressed("gg_share"):
		if _share_nearby():
			get_viewport().set_input_as_handled()


func _designate(index: int) -> bool:
	if index < 0 or _flock == null:
		return false
	var bird := _bird_by_index(index)
	if bird.is_empty():
		return false
	if int(_flock.designated_driver()) == index:
		return false

	# set_dd() clears every other flag and zeroes this bird's intoxication, so
	# naming a wrecked goose sobers it on the spot. That's the joke and also the
	# right mechanic: the DD is a role, not a state you have to have maintained.
	_flock.set_dd(index)
	_sync_vests()

	var root: Node3D = bird["root"]
	var lbl: Label3D = bird["name_lbl"]
	var nm := lbl.text
	if _sfx != null:
		_sfx.play_at(&"unlock", root, -4.0, 1.05)
		_sfx.play_at(&"honk_a", root, -8.0, 1.16)
	if _juice != null:
		_juice.pop(root, 0.35, 0.24)
		_juice.floating_text(root.global_position + Vector3(0, 1.5, 0),
			"DESIGNATED DRIVER", C_DD)
		_juice.burst(root.global_position + Vector3(0, 0.5, 0), C_VEST, 10)
	dd_designated.emit(index, nm)
	return true


## Dose only the geese you are standing next to. Returns true if it consumed
## the key, which also means the goose controller's blanket dose_flock() is
## suppressed for this press.
func _share_nearby() -> bool:
	if _flock == null or _subs == null:
		return false
	if player == null or not is_instance_valid(player):
		return false
	# You can only share what you are on. Same rule the controller applies, kept
	# identical so the key never behaves differently depending on where you're
	# standing beyond WHO it lands on.
	var actives: Array = _subs.actives
	if actives.is_empty():
		return false

	var here := player.global_position
	var hit := 0
	var dd_skipped := 0
	for b in _birds:
		var bird: Dictionary = b
		var root: Node3D = bird["root"]
		if root.global_position.distance_to(here) > SHARE_RANGE:
			continue
		var index: int = bird["index"]
		if _is_dd(index):
			dd_skipped += 1
			continue
		_flock.dose_bird(index, SHARE_DOSE)
		hit += 1
		if _sfx != null:
			_sfx.play_at(&"goose_grumble", root, -9.0, randf_range(0.86, 1.14))

	if hit <= 0:
		# Nobody in range who'd take it. Let the event fall through to the
		# controller so the old blanket share still works away from the pen —
		# and say so when the only bird in reach was the one who can't.
		if dd_skipped > 0 and _juice != null:
			_juice.floating_text(here + Vector3(0, 1.6, 0), "THEY'RE DRIVING", C_DD)
		return false

	# One score call, not one per goose: the `share_the_wealth` objective counts
	# occurrences of this exact label, and paying it per-bird would let a player
	# clear a four-share objective by standing in the middle of the gaggle once.
	var game := get_node_or_null("/root/Game")
	if game != null:
		game.score(60 + 22 * hit, "SHARED WITH THE FLOCK")
	if _juice != null:
		_juice.floating_text(here + Vector3(0, 1.7, 0), "SHARED WITH %d" % hit,
			Color(0.86, 0.72, 0.98))
	flock_dosed.emit(hit)
	return true


func _is_dd(index: int) -> bool:
	if _flock == null:
		return false
	return int(_flock.designated_driver()) == index


func _bird_by_index(index: int) -> Dictionary:
	for b in _birds:
		var bird: Dictionary = b
		if int(bird["index"]) == index:
			return bird
	return {}


func _on_bird_dosed(index: int, _amount: float) -> void:
	# Remember what they were dosed WITH, so the tint on a wrecked goose matches
	# whatever put it there rather than being a generic green.
	var bird := _bird_by_index(index)
	if bird.is_empty() or _subs == null:
		return
	var tint: Color = _subs.primary_tint()
	bird["tint"] = tint
	var root: Node3D = bird["root"]
	if _juice != null:
		_juice.pop(root, 0.22, 0.18)


# ═══════════════════════════════════════════════════════════════════ TICK

func _physics_process(_delta: float) -> void:
	if _birds.is_empty():
		return
	var space := get_world_3d().direct_space_state
	if not _grounded:
		# First pass: drop everyone onto whatever the zone actually has under
		# them. Done on a physics frame because the space state isn't queryable
		# before one, and a pen placed on the assumption of flat ground floats
		# over the pond bank in one zone and sinks into the lawn in the other.
		_grounded = true
		for b in _birds:
			var bird: Dictionary = b
			var root: Node3D = bird["root"]
			var home: Vector3 = bird["home"]
			var g := _ground_at(space, home, home.y)
			bird["ground_y"] = g
			home.y = g
			bird["home"] = home
			bird["target"] = home
			root.global_position = home + Vector3(0, STAND_HEIGHT, 0)
		return

	# Then keep following the ground, ONE bird per frame. The pen sits on the
	# grass/asphalt boundary in the strip mall, and a bird that keeps the Y it
	# spawned with walks straight into the tarmac the moment it wanders off the
	# verge — which is exactly what the third render showed, and it read as the
	# geese clipping through the level rather than as anything intentional.
	_ground_cursor = (_ground_cursor + 1) % _birds.size()
	var b2: Dictionary = _birds[_ground_cursor]
	var r2: Node3D = b2["root"]
	if not is_instance_valid(r2):
		return
	b2["ground_y"] = _ground_at(space, r2.global_position, float(b2["ground_y"]))


## THE GROUND UNDER A POINT — and it must be UNDER it.
##
## This used to start the ray at `at.y + 4.0`, which is not "the ground under the
## pen", it is "the first thing within four metres above or five metres below the
## pen". Any pen placed under an overhang lower than that snapped the WHOLE FLOCK
## onto the roof of it, silently and permanently: the truck stop's first render
## had four of six geese standing on top of a 3.5 m diner awning reading their
## own name tags, and diagnosing it cost a full render cycle. It is still the
## reason `zone_truckstop.gd` parks the pen out in the open with a comment about
## vertical clearance instead of under the light where the zone wanted it.
##
## The four metres were slop for a pen authored slightly BELOW the surface it
## should sit on. That is the wrong trade — a downward probe should never be able
## to return a surface above the point it was asked about, because every walkable
## overhang in this game (awnings 3.5 m, fuel canopy 5.4 m, trailer roofs 4.05 m)
## lives inside that window. So:
##
##   * UP_MARGIN is 0.6 m — enough for authoring slop and for the per-frame
##     re-probe, which starts from a bird's root at STAND_HEIGHT (0.46) above the
##     ground, and comfortably under the lowest thing anyone can stand on.
##   * DOWN_REACH is 8 m — generous, because the cost of overshooting downward is
##     nothing, and a pen on a bank wants the reach.
##   * A miss returns `fallback`, i.e. keep what you had. A pen authored more than
##     0.6 m below its own ground is an authoring error and holds its Y rather
##     than teleporting to whatever happens to be overhead.
func _ground_at(space: PhysicsDirectSpaceState3D, at: Vector3, fallback: float) -> float:
	var q := PhysicsRayQueryParameters3D.create(
		Vector3(at.x, at.y + GROUND_UP_MARGIN, at.z),
		Vector3(at.x, at.y - GROUND_DOWN_REACH, at.z))
	var res: Dictionary = space.intersect_ray(q)
	if res.has("position"):
		var p: Vector3 = res["position"]
		return p.y
	return fallback


func _process(delta: float) -> void:
	if _birds.is_empty():
		return
	# Wall-clock. Nitrous drops Engine.time_scale to a crawl and a flock that
	# freezes with the world is fine, but a flock that freezes with the world
	# while the player is picking a DD is not.
	var dt := delta / maxf(Engine.time_scale, 0.05)
	_t += dt
	_resolve_player()
	_pick_focus()
	_grumble_cd -= dt

	var raw: Array = []
	if _flock != null:
		raw = _flock.birds

	for b in _birds:
		var bird: Dictionary = b
		var index: int = bird["index"]
		var intox := 0.0
		var stamina := 1.0
		var alive := true
		if index < raw.size():
			var rec: Dictionary = raw[index]
			intox = float(rec.get("intox", 0.0))
			stamina = float(rec.get("stamina", 1.0))
			alive = bool(rec.get("alive", true))
		var is_dd := _is_dd(index)
		_tick_bird(bird, dt, intox, stamina, alive, is_dd)

	if _grumble_cd <= 0.0:
		_grumble_cd = randf_range(3.5, 8.0)
		_random_grumble()


## Everything the player learns about a bird without opening a menu.
func _tick_bird(bird: Dictionary, dt: float, intox: float, stamina: float,
		alive: bool, is_dd: bool) -> void:
	var root: Node3D = bird["root"]
	var visual: Node3D = bird["visual"]
	if not is_instance_valid(root) or not is_instance_valid(visual):
		return
	root.visible = alive
	if not alive:
		return

	var phase: float = float(bird["phase"]) + dt * lerpf(1.6, 5.2, intox)
	bird["phase"] = phase

	# ── WANDER ─────────────────────────────────────────────────────────
	# A sober goose picks a spot near home and walks to it. A wrecked one picks
	# a much worse spot much more often and takes ages to get there, which is
	# what "wandering off" looks like from thirty metres away.
	var wander: float = float(bird["wander"]) - dt
	if wander <= 0.0:
		var spread: float = lerpf(1.1, 2.6, intox)
		var home: Vector3 = bird["home"]
		bird["target"] = home + Vector3(randf_range(-spread, spread), 0.0,
			randf_range(-spread, spread))
		bird["wander"] = randf_range(2.2, 5.5) * lerpf(1.0, 0.55, intox)
	else:
		bird["wander"] = wander

	var target: Vector3 = bird["target"]
	var to := target - root.global_position
	to.y = 0.0
	var dist := to.length()
	# Stamina matters as well as intoxication: a tired bird shuffles.
	var walk: float = lerpf(1.15, 0.34, intox) * lerpf(0.55, 1.0, clampf(stamina, 0.0, 1.0))
	var speed := 0.0
	if dist > 0.18:
		var dir := to / dist
		# Drunk geese don't walk where they're pointed. The lateral wobble is
		# added to the direction, not to the position, so they weave.
		var side := Vector3(-dir.z, 0.0, dir.x) * sin(phase * 1.7) * intox * 0.75
		var step: float = minf(walk * dt, dist)
		root.global_position += (dir + side).normalized() * step
		speed = walk
		var want_heading := atan2(dir.x + side.x, dir.z + side.z)
		var head: float = float(bird["heading"])
		head = lerp_angle(head, want_heading, 1.0 - pow(0.001, dt))
		bird["heading"] = head
		root.rotation.y = head
	bird["speed"] = lerpf(float(bird["speed"]), speed, 1.0 - pow(0.02, dt))

	# Settle onto the ground height the probe last found under this bird. Lerped
	# rather than snapped so a kerb reads as a step up, not as a teleport.
	var want_y: float = float(bird["ground_y"]) + STAND_HEIGHT
	var pos := root.global_position
	pos.y = lerpf(pos.y, want_y, 1.0 - pow(0.0005, dt))
	root.global_position = pos

	# ── POSTURE ────────────────────────────────────────────────────────
	# Three redundant channels, because one is never enough at distance:
	# a wrecked goose SITS LOWER, LISTS, and BOBS. All three scale with intox.
	var slump: float = intox * 0.16
	var bob: float = sin(phase * 0.9) * lerpf(0.012, 0.055, intox)
	visual.position.y = -slump + bob
	visual.rotation.x = sin(phase * 0.63 + 1.1) * intox * 0.26
	# Squashes down as it goes: a bird that is only tilted reads as a bird on a
	# hill. A bird that is tilted AND shorter reads as a bird that has had it.
	var squash: float = lerpf(1.0, 0.86, intox)
	visual.scale = Vector3(lerpf(1.0, 1.07, intox), squash, lerpf(1.0, 1.05, intox))

	if visual.has_method("animate"):
		# `flapping` stays 0 and `airborne` false: these birds never leave the
		# ground, and passing the walk speed in drives the waddle for free.
		visual.animate(dt, 0.0, float(bird["speed"]), false)
	# AFTER animate(), never before: animate() writes body.rotation.z itself, so
	# banking first just gets overwritten by the waddle on the same frame. This
	# cost twenty minutes and one render to find.
	if visual.has_method("set_bank"):
		visual.set_bank(sin(phase) * intox * 0.52, dt)
	# The head goes down. This is the single most legible "that bird is not
	# okay" cue there is — more than the tilt, more than the height — and it is
	# also written by animate(), so it has to be set here and set absolutely.
	var neck = bird["neck"]
	if neck is Node3D:
		var nk: Node3D = neck
		nk.rotation.x = intox * 0.62 + sin(phase * 0.8) * intox * 0.22
	if visual.has_method("set_tint"):
		var tint: Color = bird["tint"]
		if is_dd:
			# The DD reads as scrubbed clean, whatever it was on before.
			visual.set_tint(Color.WHITE, 0.0)
		else:
			visual.set_tint(tint, clampf(intox * 0.55, 0.0, 0.55))

	# ── LABELS ─────────────────────────────────────────────────────────
	var name_lbl: Label3D = bird["name_lbl"]
	var state_lbl: Label3D = bird["state_lbl"]
	var prompt_lbl: Label3D = bird["prompt_lbl"]
	var col := C_FINE
	var word := "fine"
	if is_dd:
		col = C_DD
		word = "DESIGNATED DRIVER"
	elif intox > 0.75:
		col = C_WRECKED
		word = "WRECKED"
	elif intox > 0.45:
		col = C_ROUGH
		word = "rough"
	elif intox > 0.2:
		col = C_LOOSE
		word = "loose"
	elif stamina < 0.35:
		col = C_LOOSE
		word = "worn out"
	# Distance fade. Six billboarded tags on six birds standing in a gaggle pile
	# into an unreadable stack the moment you walk into the middle of them — the
	# render showed three names and two states occupying the same forty pixels.
	# Names go first because they are the least useful thing at range; the
	# CONDITION is what you want to read from across the lot, so it survives
	# considerably further out.
	var pd := 6.0
	if player != null and is_instance_valid(player):
		pd = root.global_position.distance_to(player.global_position)
	var name_a: float = clampf(inverse_lerp(18.0, 10.0, pd), 0.0, 1.0)
	var state_a: float = clampf(inverse_lerp(28.0, 16.0, pd), 0.0, 1.0)
	name_lbl.modulate = Color(0.96, 0.97, 1.0, name_a)
	name_lbl.outline_modulate = Color(0, 0, 0, 0.85 * name_a)
	name_lbl.visible = name_a > 0.02
	state_lbl.modulate = Color(col.r, col.g, col.b, state_a)
	state_lbl.outline_modulate = Color(0, 0, 0, 0.85 * state_a)
	state_lbl.text = word
	# A tag over a goose should always MEAN something. Labelling the healthy
	# ones "fine" is six lines of noise over a gaggle that is doing nothing
	# wrong, and it drowns the two that are.
	state_lbl.visible = word != "fine" and state_a > 0.02
	# The tags ride the slump, so the whole bird sinks as one thing.
	name_lbl.position.y = 1.34 - slump
	state_lbl.position.y = 1.19 - slump

	var focused: bool = int(bird["index"]) == focus_index
	prompt_lbl.visible = focused and not is_dd
	if prompt_lbl.visible:
		prompt_lbl.text = "[G]  MAKE %s THE DD" % str(name_lbl.text).to_upper()
		# Pulses, because a prompt that appears without moving is a label.
		var puls: float = 0.72 + 0.28 * (0.5 + 0.5 * sin(_t * 6.0))
		prompt_lbl.modulate = Color(C_DD.r, C_DD.g, C_DD.b, puls)
		prompt_lbl.position.y = 1.66 - slump


## Nearest bird inside DESIGNATE_RANGE, or -1. Nearest rather than "first found"
## so standing between two geese always names the one you're closest to instead
## of whichever happened to be earlier in the array.
func _pick_focus() -> void:
	focus_index = -1
	if player == null or not is_instance_valid(player):
		return
	var here := player.global_position
	var best := DESIGNATE_RANGE
	for b in _birds:
		var bird: Dictionary = b
		var root: Node3D = bird["root"]
		if not is_instance_valid(root):
			continue
		var dist := root.global_position.distance_to(here)
		if dist < best:
			best = dist
			focus_index = int(bird["index"])


## Occasional ambient noise from whoever is worst off — a flock that is silently
## falling apart doesn't read as falling apart.
func _random_grumble() -> void:
	if _sfx == null or _birds.is_empty() or _flock == null:
		return
	var raw: Array = _flock.birds
	var pick: Dictionary = _birds[randi() % _birds.size()]
	var index: int = pick["index"]
	if index >= raw.size():
		return
	var rec: Dictionary = raw[index]
	var intox: float = float(rec.get("intox", 0.0))
	var root: Node3D = pick["root"]
	if not is_instance_valid(root):
		return
	if intox > 0.55:
		_sfx.play_at(&"goose_grumble", root, -13.0, randf_range(0.62, 0.82))
	elif randf() < 0.4:
		_sfx.play_at(&"honk_c", root, -18.0, randf_range(0.95, 1.12))


# ══════════════════════════════════════════════════════════════════ QUERY

## For a HUD or a zone that wants to say something about the pen.
func flock_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for b in _birds:
		var bird: Dictionary = b
		var root: Node3D = bird["root"]
		if is_instance_valid(root):
			out.append(root.global_position)
	return out


## Index of the bird the player could name right now, or -1.
func focused_bird() -> int:
	return focus_index


## Dev/probe hook: force the pen into a legible spread of conditions.
func debug_scatter_intox() -> void:
	if _flock == null:
		return
	var raw: Array = _flock.birds
	var steps := [0.0, 0.25, 0.5, 0.72, 0.9, 1.0]
	for i in raw.size():
		var rec: Dictionary = raw[i]
		rec["intox"] = float(steps[i % steps.size()])
