extends Node3D
## THE HONK.
##
## Its own button, spammable, and it pitch-shifts per substance. That last
## detail is going to be most of your marketing clips, so treat the pitch table
## as a first-class design surface, not a sound effect.

## A honk ACTUALLY HAPPENED. Emitted after the cooldown check, so a suppressed
## press does not fire it.
##
## This exists because zones were listening to the KEY instead. `do_honk()`
## returns immediately while `_cd > 0.0`, and the button is spammable by design
## — so a zone reacting to `gg_honk` in `_input()` reacts about twice as often as
## the goose actually honks. zone_stopover.gd's `meet_the_locals` primary paid
## out on every press, which meant mashing H in a cluster of residents filled the
## objective in about a second with fewer than half of those presses making a
## sound: numbers appearing with no honk under them, in the quietest zone in the
## game.
signal honked(pitch: float)

const RADIUS := 7.5
const COOLDOWN := 0.22

var _cd := 0.0
var _player: AudioStreamPlayer3D
var _sfx: Node


func _ready() -> void:
	_sfx = get_node_or_null("/root/Sfx")
	_player = AudioStreamPlayer3D.new()
	_player.unit_size = 14.0
	_player.max_db = 3.0
	var stream = load("res://audio/honk.wav") if ResourceLoader.exists("res://audio/honk.wav") else null
	if stream:
		_player.stream = stream
	add_child(_player)


func _process(delta: float) -> void:
	_cd = maxf(0.0, _cd - delta)


func do_honk(pitch: float = 1.0) -> void:
	if _cd > 0.0:
		return
	_cd = COOLDOWN

	var p: float = clampf(pitch * randf_range(0.96, 1.04), 0.25, 3.0)
	if _sfx:
		# On stimulants the goose is not asking politely.
		var stimmed: bool = float(Subs.brain.get("adrenaline", 0.4)) > 0.72
		if stimmed:
			_sfx.play_at(&"honk_angry", self, 0.0, p)
		else:
			var keys := [&"honk_a", &"honk_b", &"honk_c"]
			_sfx.play_at(keys[randi() % keys.size()], self, 0.0, p)
	elif _player.stream:
		_player.pitch_scale = p
		_player.play()

	_ring(pitch)
	_pressure_wave(pitch)
	_shove(pitch)
	honked.emit(pitch)


## TIER 1 — the honk's physical presence.
##
## This is the game's signature verb and until now it moved the world without
## the world moving you: props flew, humans ran, and the camera did not so much
## as flinch. A honk should feel like it left the bird.
##
## Two constraints shape the numbers hard. The honk is on a 0.22 s cooldown and
## players WILL hold the button, so this has to sit at the very bottom of the
## budget: 0.14 at normal pitch, 0.22 at the deepest foghorn, 0.05 at the
## squeakiest. At 0.14 every 0.22 s against a 2.4/s decay the bus sheds 0.53
## between honks, so spamming settles at one honk's worth instead of piling up —
## which is the property that makes it safe to leave on a spammable button.
##
## Scaling by pitch is free characterisation: pitch already tracks body size
## (tiny goose squeaks, macropsia goose foghorns) and substance, so a big goose
## genuinely hits harder without a single extra branch.
func _pressure_wave(pitch: float) -> void:
	var p := maxf(pitch, 0.35)
	Juice.shake(clampf(0.14 / p, 0.05, 0.22))
	# A puff at the bill, not at the bird's centre. `sparkle` is the only kind
	# that hangs in the air without falling, which is what a pressure wave
	# should look like — and its 1.1 s life is short enough that held-down
	# honking doesn't leave a permanent cloud.
	var bill := global_position - global_transform.basis.z * 0.55 + Vector3.UP * 0.45
	Juice.burst(bill, Color(0.95, 0.95, 0.88), maxi(4, int(round(7.0 / p))), &"sparkle")


## Expanding shockwave ring. Reads clearly, costs nothing.
func _ring(pitch: float) -> void:
	var mi := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.45
	torus.outer_radius = 0.6
	mi.mesh = torus

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Subs.primary_tint()
	mat.albedo_color.a = 0.75
	mi.material_override = mat

	# Parent into the current zone, not the scene root: if the zone is freed
	# mid-tween (leg change) the ring goes with it instead of erroring.
	var host: Node = get_tree().current_scene
	var zone := host.get_node_or_null("Zone")
	if zone:
		host = zone
	host.add_child(mi)
	mi.global_position = global_position + Vector3.UP * 0.4

	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * (RADIUS / 0.6) * (1.0 / maxf(pitch, 0.4)), 0.45)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.45)
	tw.chain().tween_callback(mi.queue_free)


## Shove props, scatter humans, rally nothing (the flock isn't here — it's data).
##
## No Juice calls here on purpose, even though this is where the wave lands.
## Both victims already pop themselves on the way through — a prop via
## ChaosProp._maybe_score(), a person via NpcHuman.startle() — and both of those
## sit behind their own cooldowns (0.6 s and 0.5 s). Popping them again from
## here would double up on the first honk and, worse, would bypass those
## cooldowns, so holding the button would leave the whole parking lot
## permanently pulsating.
func _shove(pitch: float) -> void:
	var r: float = RADIUS / maxf(pitch, 0.5)
	var hits := 0

	for node in get_tree().get_nodes_in_group("chaos_prop"):
		if node is Node3D and node.global_position.distance_to(global_position) < r:
			# ONE STRENGTH AT EVERY HEIGHT (D-092). The push is still away-and-up,
			# but its LENGTH is now the level one. It used to be the raw sum
			# n + 0.4 up, which is 1.08 long for a prop level with the goose, 1.4
			# for one straight above and 0.6 for one below — and `ChaosProp` scores
			# a shove at 0.7 * |impulse|, so one honk hit 4.15, 5.39 or 2.31
			# depending only on height. Two quick honks under the Ranger shattered
			# his clipboard in the air that way (break 5.0, D-084) and routed him.
			# Now every honk lands at 4.15, so a prop that breaks above that (the
			# clipboard and suburbia's gnomes, both 5.0) is knocked about by a honk
			# but never broken by one; a cat's pounce or the goose's own body
			# (goose_controller.gd, `hit`) still breaks them. Not flattened: a flat
			# direction leaves a prop straight overhead only the 0.4 lift, too weak
			# to register at all. inputtest asserts both heights, and that both felt it.
			var dir: Vector3 = ((node.global_position - global_position).normalized()
				+ Vector3.UP * 0.4).normalized() * Vector3(1.0, 0.4, 0.0).length()
			if node.has_method("shove"):
				node.shove(dir * 5.5)
			hits += 1

	for node in get_tree().get_nodes_in_group("npc"):
		if node is Node3D and node.global_position.distance_to(global_position) < r:
			if node.has_method("startle"):
				node.startle(global_position)
			hits += 1

	if hits > 0:
		# Anchored at the goose rather than at any one victim: a honk that
		# clears six props is one event, not six.
		Game.score(10 * hits, "HONK", global_position + Vector3.UP * 0.5)
