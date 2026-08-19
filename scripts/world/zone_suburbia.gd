extends Node3D
## LEG 3 — SUBURBIA
##
## Graybox, built procedurally so it runs correctly the first time you open the
## project with no import step and no missing references.
##
## A cul-de-sac. Somebody mowed this lawn an hour ago. You are about to ruin
## that. The whole point of the zone is verticality-as-reward: everything fun
## (a roof, a trampoline, a fenced backyard, berries in the canopy) requires
## the player to actually fly, not just waddle fast.
##
## ---------------------------------------------------------------------------
## ART PASS — faceted models over graybox colliders
## ---------------------------------------------------------------------------
## Every collider in this file is exactly where it was. What changed is what
## you see: the BoxMeshes (and the roof PrismMesh, and the torus rims, and the
## SphereMesh canopies) are gone, replaced by the hand-built models in
## prop_models.gd. The split is deliberate:
##
##   * PHYSICS is boxes. The roof plateau the goose lands on, the picket line
##     of the fence, the trampoline legs — all untouched, all the same size and
##     in the same place, so the "get on a roof" objective still works exactly
##     as it did.
##   * ART is a model hung off that box, base-anchored to the collider's floor.
##
## The two anchoring conventions do not agree, and that is the one thing to get
## right: prop_models.gd builds every model with its base at local y = 0, while
## BoxShape3D/BoxMesh are centred on the origin. So a model always drops by
## half the box height. Miss it and the whole street hovers.

const LOT := 80.0

## Preloaded rather than referenced by class_name: global class registration
## only exists after an editor import pass, so a `class_name` reference breaks
## in a fresh checkout or a headless CI run. A preload const always resolves.
const PROPS := preload("res://scripts/world/prop_models.gd")

## The finale zone's model file, imported for ONE model: its sprinkler. That
## zone's signature prop is a sprinkler and it is already faceted, already
## rendered, and already authored with its nozzle throwing along -Z about a
## base-anchored origin — which is exactly what this zone's oscillating heads
## need. Writing a second one here is the "grew a second copy" failure.
const FIN_PROPS := preload("res://scripts/world/prop_models_finale.gd")

## Molly, the golden retriever in house 0's yard, is boss_ranger_visual.gd's
## dog in its &"golden" coat. Same reason: there is one dog model in this
## project and this file used to hold a second one made of a CapsuleMesh and a
## SphereMesh.
const DOG_VIS := preload("res://scripts/world/boss_ranger_visual.gd")

## The objective content file, imported for its score-label constants ONLY.
## The bespoke moments below (roof, trampoline, pool, laundry) are the half of
## a contract whose other half is a `label` condition in mission_defs.gd, and
## the two used to agree only by both being typed correctly. They now share the
## literal, so a rename breaks the build instead of breaking an objective.
const MDEF := preload("res://scripts/core/mission_defs.gd")

## Chaos-prop label -> model kind. Keyed off the label the prop already carries
## (the same string scoring and objectives match on) so there is one place to
## look and no call site repeats itself. Labels with no entry — LAUNDRY,
## SAUSAGE, PATIO TABLE, UMBRELLA, LEAVES, BIRD FEEDER — keep the old BoxMesh,
## which is correct: there is no model for those yet and a wrong model is worse
## than an honest box.
const PROP_KIND := {
	"CAR": &"minivan",
	"MAILBOX": &"mailbox",
	"HYDRANT": &"hydrant",
	"GARBAGE BIN": &"recycling_bin",
	"RECYCLING BIN": &"recycling_bin",
	"GARBAGE BAG": &"garbage_bag",
	"BBQ": &"bbq",
	"PATIO CHAIR": &"patio_chair",
	"GNOME": &"gnome",
	"STOP SIGN": &"stop_sign",
	"BASKETBALL": &"basketball",
}

var goose: Goose
var camera_rig: Node3D

var _tex = null   # Node, /root/Tex — may not exist, always guard.
var _sfx = null   # Node, /root/Sfx — may not exist, always guard.

var _sprinkler_heads: Array = []
var _t := 0.0

## ── WHY THE BESPOKE MOMENTS RE-ARM ──────────────────────────────────────
##
## The roof and the pool used to be permanent one-shots (`_roof_bonus_given`,
## `_pool_bonus_given`). Each fired its score label exactly once per leg, and
## that quietly made two objectives impossible:
##
##   * `ascension`  — three trampoline bounces THEN a roof, inside fourteen
##     seconds. The `get_up_there` primary explicitly sends the player to a
##     roof first, so by the time they find the trampoline the ON THE ROOF
##     label had already been spent and the hidden objective could never fire.
##   * `pool_party` — cannonball the pool with two substances up. The latch
##     burned on the FIRST entry, which is almost always a sober one, so the
##     objective was decided by an event the player didn't know mattered.
##
## They are now per-trigger cooldowns instead. You still cannot farm them —
## you have to leave and come back, and there is a floor of RE_ARM seconds —
## but the moment stays available for the whole leg, which is what an
## objective that waits on it needs.
const RE_ARM := 4.0

var _cooldowns: Dictionary = {}   ## Area3D instance id (int) -> seconds left

## Road layout, computed once in _road() and reused by street furniture,
## driveways and the garbage-day curb row.
var _bulb_r := 12.0
var _corridor_hw := 5.5
var _corridor_z := 0.0
var _corridor_len := 0.0


func _ready() -> void:
	_tex = get_node_or_null("/root/Tex")
	_sfx = get_node_or_null("/root/Sfx")

	_environment()
	_ground()
	_road()
	_central_island()
	var houses := _houses()
	_yards(houses)
	_backyards(houses)
	_driveways_and_cars(houses)
	_street_furniture(houses)
	_garbage_day(houses)
	_backyard_fun(houses)
	_front_yard_fun(houses)
	_sources(houses)
	_people()
	_cats()
	_spawn_goose()

	# ── RANGER BOSS GOES HERE ────────────────────────────────────────────
	# docs/BOSS_DESIGN.md puts the Ranger in this zone. It needs the goose, so
	# it hooks in after _spawn_goose() and nowhere earlier. One line:
	#
	#   add_child(preload("res://scripts/world/boss_ranger.gd").new().setup(self, goose))
	#
	# Nothing else in this file has to change for it — the boss scores through
	# Game.score() like everything else, and Mission picks it up from there.


func _process(delta: float) -> void:
	_t += delta
	for head in _sprinkler_heads:
		if is_instance_valid(head):
			var phase: float = head.get_meta("phase", 0.0)
			head.rotation.y = sin(_t * 1.4 + phase) * 1.15
	for key in _cooldowns.keys():
		var left: float = float(_cooldowns[key]) - delta
		if left <= 0.0:
			_cooldowns.erase(key)
		else:
			_cooldowns[key] = left


## True once, then locks the trigger out for RE_ARM seconds. Keyed on the
## Area3D so each roof keeps its own clock.
func _trigger_ready(area: Node) -> bool:
	var key := area.get_instance_id()
	if _cooldowns.has(key):
		return false
	_cooldowns[key] = RE_ARM
	return true


# ------------------------------------------------------------------ helpers

func _mat(c: Color, rough := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


func _surf(key: StringName, uv_scale: float, fallback: Color) -> StandardMaterial3D:
	if _tex != null:
		return _tex.surface(key, uv_scale, 0.9, Color.WHITE)
	return _mat(fallback)


func _static_box(pos: Vector3, size: Vector3, color: Color, rot_y := 0.0) -> StaticBody3D:
	var sb := StaticBody3D.new()
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(color)
	sb.add_child(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	add_child(sb)
	sb.global_position = pos
	sb.rotation.y = rot_y
	return sb


func _decal_box(pos: Vector3, size: Vector3, color: Color, rot_y := 0.0) -> void:
	## Visual only — no collider. For paint, lines, flat detail.
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := _mat(color)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mi.material_override = m
	add_child(mi)
	mi.global_position = pos
	mi.rotation.y = rot_y


func _prop(pos: Vector3, size: Vector3, color: Color, mass_kg: float, pts: int,
		lbl: String, extra := {}) -> ChaosProp:
	var p := ChaosProp.new()
	add_child(p)
	var kind: StringName = PROP_KIND.get(lbl, &"")
	var params: Dictionary = extra.duplicate()
	if kind != &"":
		params[_colour_key(kind)] = color
	p.setup(size, color, mass_kg, pts, lbl, kind, params)
	p.global_position = pos
	p.rotation.y = randf_range(-PI, PI)
	return p


## Which params key a model takes its main colour under. Only the minivan is
## odd — it has a body colour and a lot of trim that must NOT follow it.
func _colour_key(kind: StringName) -> String:
	if kind == &"minivan":
		return "body_colour"
	return "colour"


## Hide the box mesh of an existing StaticBody3D and hang a faceted model off
## it instead. The collider is untouched — this is a visual swap only.
##
## `base_y` is the model's base in the body's LOCAL frame, which for a box
## collider of height h centred on the body is always -h * 0.5.
func _model_body(sb: StaticBody3D, kind: StringName, base_y: float, params := {},
		uniform := 1.0) -> Node3D:
	_hide_meshes(sb)
	var m: Node3D = PROPS.build(kind, sb, params)
	m.position.y = base_y
	if not is_equal_approx(uniform, 1.0):
		m.scale = Vector3.ONE * uniform
	return m


## A free-standing model with no collider at all — the _decal_box equivalent.
## `pos` is where the model's FEET go, so pass ground height, not centre.
func _model_at(kind: StringName, pos: Vector3, rot_y := 0.0, params := {},
		uniform := 1.0) -> Node3D:
	var n := Node3D.new()
	add_child(n)
	n.global_position = pos
	n.rotation.y = rot_y
	PROPS.build(kind, n, params)
	if not is_equal_approx(uniform, 1.0):
		n.scale = Vector3.ONE * uniform
	return n


## Keep a body's collision, drop its graybox. Used wherever the visual is
## replaced by a model that spans several colliders at once (the fence run, the
## trampoline's ring of legs, the roof plateau).
func _hide_meshes(sb: StaticBody3D) -> void:
	for c in sb.get_children():
		if c is MeshInstance3D:
			c.visible = false


func _source(pos: Vector3, res: Substance, size := 0.5) -> void:
	if res == null:
		return
	var s := SubstancePickup.new()
	add_child(s)
	s.setup(res, size)
	s.global_position = pos


## A disc-shaped cosmetic overlay (road, sidewalk, pool water). Never
## collidable — the real walking surface is the single flat ground plane in
## _ground(); this is paint on top of it, so there's never a physical seam.
## Uses a Tex surface when `tex_key` is given and Tex is available, otherwise
## falls back to a flat `color`.
func _disc(pos: Vector3, radius: float, height: float, color: Color, transparent := false,
		tex_key: StringName = &"") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	mi.mesh = cm
	var m: StandardMaterial3D
	if tex_key != &"":
		m = _surf(tex_key, radius * 0.5, color)
	else:
		m = _mat(color)
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	add_child(mi)
	mi.global_position = pos
	return mi


## A flat, non-colliding textured rectangle — the decal_box() equivalent for
## large surfaces (road, driveways, lawns) that should pick up a Tex material
## when one is available instead of a flat color.
func _flat_surf(pos: Vector3, size: Vector3, tex_key: StringName, fallback: Color,
		rot_y := 0.0, uv_scale := 1.0) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _surf(tex_key, uv_scale, fallback)
	add_child(mi)
	mi.global_position = pos
	mi.rotation.y = rot_y


## Static post + shelf, with a ChaosProp resting on top of the shelf so it
## reads as "mounted" while still being a fully physical, knockable object.
func _on_post(pos: Vector3, post_h: float, shelf_size: Vector3, prop_size: Vector3,
		post_color: Color, prop_color: Color, mass_kg: float, pts: int, lbl: String) -> ChaosProp:
	_static_box(pos + Vector3(0, post_h * 0.5, 0), Vector3(0.14, post_h, 0.14), post_color)
	_static_box(pos + Vector3(0, post_h + shelf_size.y * 0.5, 0), shelf_size, post_color.darkened(0.1))
	return _prop(pos + Vector3(0, post_h + shelf_size.y + prop_size.y * 0.5 + 0.06, 0),
		prop_size, prop_color, mass_kg, pts, lbl)


## Maps a local offset (x = right/left, y = up, z: negative = toward the
## road/front, positive = toward the backyard) into world space for a house.
func _house_point(h: Dictionary, local: Vector3) -> Vector3:
	var pos: Vector3 = h.pos
	var right: Vector3 = h.right
	var back: Vector3 = -(h.front as Vector3)
	return pos + right * local.x + Vector3.UP * local.y + back * local.z


## A run of fence between two XZ points.
##
## The colliders are unchanged: the same line of 0.10 x height x 0.16 picket
## boxes every 0.55 m. Only the look changes — the boxes go invisible and
## fence_panel models are tiled along the run instead, each one carrying its own
## dog-eared boards, two back rails and an end post.
##
## fence_panel is authored 2.20 m wide with its post on the LEFT end, which is
## what makes it tile: butt the panels and every post lands exactly on a seam.
## The run is divided into a whole number of panels and each is scaled to the
## remainder, so a 9.3 m fence gets four 2.325 m panels rather than four full
## panels and a visible stub.
func _fence_run(a: Vector2, b: Vector2, height: float, color: Color) -> void:
	var d: Vector2 = b - a
	var length: float = d.length()
	if length < 0.05:
		return
	var dir: Vector2 = d / length
	var rot: float = atan2(-dir.y, dir.x)
	var n: int = maxi(2, int(length / 0.55))
	for i in range(n + 1):
		var t: float = float(i) / float(n)
		var p: Vector2 = a + d * t
		_hide_meshes(_static_box(Vector3(p.x, height * 0.5, p.y),
			Vector3(0.10, height, 0.16), color, rot))
	# Local +X of a box yawed by `rot` points along the run, and the model is
	# authored the same way round, so the panels take the same rotation as the
	# pickets they replace.
	var panels: int = maxi(1, int(round(length / 2.20)))
	var pw: float = length / float(panels)
	for i in panels:
		var c: Vector2 = a + dir * (pw * (float(i) + 0.5))
		_model_at(&"fence_panel", Vector3(c.x, 0.0, c.y), rot,
			{"size": Vector3(pw, height, 0.16), "colour": color})


func _fence_rect(h: Dictionary, half_width: float, near: float, far: float, height: float, color: Color) -> void:
	var c1 := _house_point(h, Vector3(-half_width, 0, near))
	var c2 := _house_point(h, Vector3(half_width, 0, near))
	var c3 := _house_point(h, Vector3(half_width, 0, far))
	var c4 := _house_point(h, Vector3(-half_width, 0, far))
	_fence_run(Vector2(c1.x, c1.z), Vector2(c2.x, c2.z), height, color)
	_fence_run(Vector2(c2.x, c2.z), Vector2(c3.x, c3.z), height, color)
	_fence_run(Vector2(c3.x, c3.z), Vector2(c4.x, c4.z), height, color)
	_fence_run(Vector2(c4.x, c4.z), Vector2(c1.x, c1.z), height, color)


# ------------------------------------------------------------------ world shell

func _environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	# Golden hour. Long shadows, warm horizon, a deeper blue overhead.
	sm.sky_top_color = Color(0.18, 0.28, 0.46)
	sm.sky_horizon_color = Color(0.94, 0.62, 0.38)
	sm.ground_bottom_color = Color(0.22, 0.18, 0.16)
	sm.ground_horizon_color = Color(0.86, 0.58, 0.40)
	sm.sun_angle_max = 26.0
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.6
	env.fog_enabled = true
	env.fog_density = 0.0015
	env.fog_light_color = Color(0.92, 0.68, 0.48)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-22, 52, 0)
	sun.light_energy = 1.15
	sun.light_color = Color(1.0, 0.82, 0.62)
	sun.shadow_enabled = true
	add_child(sun)

	# Cool, dim fill from roughly the opposite side so shaded faces don't go
	# fully black — no shadows of its own, just enough to lift the silhouette.
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-35, 52 - 180, 0)
	fill.light_energy = 0.22
	fill.light_color = Color(0.55, 0.62, 0.78)
	fill.shadow_enabled = false
	add_child(fill)


func _ground() -> void:
	# The single walkable, collidable plane for the whole zone. Road, sidewalk
	# and lawn tinting on top of it are purely cosmetic overlays (_flat_surf /
	# _disc) so there's never a physical seam between them.
	var sb := StaticBody3D.new()
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(LOT, 1.0, LOT)
	mi.mesh = bm
	mi.material_override = _surf(&"grass", 24.0, Color(0.30, 0.44, 0.24))
	sb.add_child(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(LOT, 1.0, LOT)
	cs.shape = bs
	sb.add_child(cs)
	add_child(sb)
	sb.global_position = Vector3(0, -0.5, 0)

	# Invisible walls so you can't waddle into the void.
	for i in 4:
		var a := float(i) * PI * 0.5
		var w := _static_box(Vector3(sin(a) * LOT * 0.5, 6.0, cos(a) * LOT * 0.5),
			Vector3(LOT, 14.0, 1.0), Color(1, 1, 1), a)
		for c in w.get_children():
			if c is MeshInstance3D:
				c.visible = false


func _road() -> void:
	## Cul-de-sac: a straight entrance corridor from the south edge of the map
	## up into a circular turnaround bulb. Every house faces this bulb.
	_disc(Vector3(0, 0.03, 0), _bulb_r + 1.6, 0.06, Color(0.72, 0.71, 0.68), false, &"concrete")  # sidewalk ring
	_disc(Vector3(0, 0.05, 0), _bulb_r, 0.10, Color(0.20, 0.20, 0.22), false, &"asphalt")          # asphalt bulb

	_corridor_len = LOT * 0.5 - 2.0
	_corridor_z = _bulb_r + _corridor_len * 0.5 - 3.0
	_flat_surf(Vector3(0, 0.03, _corridor_z), Vector3(_corridor_hw * 2 + 3.2, 0.06, _corridor_len),
		&"concrete", Color(0.72, 0.71, 0.68), 0.0, 6.0)
	_flat_surf(Vector3(0, 0.05, _corridor_z), Vector3(_corridor_hw * 2, 0.10, _corridor_len),
		&"asphalt", Color(0.20, 0.20, 0.22), 0.0, 6.0)

	# Dashed centre line down the entrance corridor.
	var n_dash := int(_corridor_len / 3.0)
	for i in n_dash:
		var z: float = _corridor_z - _corridor_len * 0.5 + 1.5 + float(i) * 3.0
		_decal_box(Vector3(0, 0.11, z), Vector3(0.18, 0.02, 1.4), Color(0.88, 0.78, 0.30))


func _central_island() -> void:
	## Real cul-de-sacs almost always have a little landscaped island in the
	## turnaround. This one gets a lamp and a grass source.
	_disc(Vector3(0, 0.07, 0), 3.4, 0.14, Color(0.28, 0.42, 0.22), false, &"grass")
	# The ornamental tree, which used to be a trunk box with a sphere floating
	# beside it. A small spruce is both the right shape and the right plant for
	# a municipal traffic island in this country. Trunk collider unchanged;
	# tree_conifer is 6 m at full size, so it comes down to about 3.6 m.
	var trunk := _static_box(Vector3(1.2, 1.0, 0), Vector3(0.4, 2.0, 0.4),
		Color(0.30, 0.24, 0.18))
	_model_body(trunk, &"tree_conifer", -1.0, {}, 0.60)
	# Island lamp. 6.0 m collider, so the 8.4 m model scales to match.
	# CENTRED AT 3.0, NOT 3.6. A 6 m box centred at 3.6 spans y 0.6 to 6.6: it
	# floats 0.6 m off the grass and overhangs its own luminaire by the same,
	# so a goose can be stopped by nothing and pass through the post's foot.
	# The MODEL was always right — `_model_body`'s offset was -3.6 to match the
	# wrong centre, which is why this looked correct in every render. Every
	# other post in the project sets the offset to minus HALF THE HEIGHT
	# (`zone_strip_mall.gd` 8.0/-4.0, `zone_cottage.gd` wall_h/-wall_h*0.5);
	# this was the only one that used minus the centre. Both move, so the
	# model stays exactly where it is and only the collider drops.
	var lamp := _static_box(Vector3(2.6, 3.0, 0), Vector3(0.28, 6.0, 0.28),
		Color(0.30, 0.30, 0.32))
	_model_body(lamp, &"lamp_post", -3.0, {}, 6.0 / 8.4)


# ------------------------------------------------------------------ houses

## Builds all 6 houses around the bulb and returns their layout data
## (Array of Dictionary) for reuse by yards/fences/driveways/sources.
func _houses() -> Array:
	# deg, radius, w, wall_h, d, wall_color, roof_color, roof_h, garage_side, fenced_backyard
	var specs: Array = [
		[-150.0, 28.0, 11.0, 3.4, 9.0, Color(0.74, 0.68, 0.60), Color(0.30, 0.22, 0.18), 2.0, 1.0, true],
		[-100.0, 26.0, 9.5, 3.1, 8.5, Color(0.55, 0.62, 0.52), Color(0.18, 0.18, 0.20), 1.8, -1.0, true],
		[-50.0, 25.0, 10.0, 3.3, 8.0, Color(0.66, 0.40, 0.32), Color(0.28, 0.16, 0.13), 2.1, 1.0, false],
		[50.0, 25.0, 9.0, 3.0, 7.5, Color(0.82, 0.78, 0.68), Color(0.36, 0.30, 0.24), 1.9, -1.0, true],
		[100.0, 26.0, 10.5, 3.2, 8.5, Color(0.42, 0.46, 0.58), Color(0.22, 0.18, 0.22), 2.0, 1.0, false],
		[150.0, 28.0, 9.5, 3.5, 9.0, Color(0.56, 0.28, 0.24), Color(0.16, 0.14, 0.16), 2.3, -1.0, false],
	]
	var houses: Array = []
	for i in specs.size():
		var s: Array = specs[i]
		var deg: float = s[0]
		var r: float = s[1]
		var rad := deg_to_rad(deg)
		var pos := Vector3(r * sin(rad), 0.0, r * cos(rad))
		var rot: float = atan2(pos.x, pos.z)
		var front := Vector3(-sin(rot), 0.0, -cos(rot))
		var right := Vector3(cos(rot), 0.0, -sin(rot))
		var hd: Dictionary = {
			"pos": pos, "rot": rot, "front": front, "right": right, "index": i,
			"w": s[2], "wall_h": s[3], "d": s[4],
			"wall": s[5], "roof": s[6], "roof_h": s[7],
			"garage_side": s[8], "fenced": s[9],
		}
		_build_house(hd)
		houses.append(hd)
	return houses


## The whole house is now ONE model call. It replaces the body box, the roof
## prism, the foundation trim, the chimney, the front door, the garage door,
## both front windows, the attic vent and the side window — every one of which
## used to be a separate _decal_box here.
##
## Colliders are unchanged: the body box, the invisible roof plateau in _roof()
## and the chimney block are all still the same sizes in the same places, so
## the goose lands on the roof exactly as before.
##
## ORIENTATION: `rot = atan2(pos.x, pos.z)` puts the node's -Z along `front`,
## which points at the cul-de-sac. The model's facade — door, garage, windows,
## and the gable end the ridge runs into — is authored at local -Z, so every
## house faces the street with no extra rotation.
func _build_house(h: Dictionary) -> void:
	var pos: Vector3 = h.pos
	var rot: float = h.rot
	var w: float = h.w
	var wall_h: float = h.wall_h
	var d: float = h.d
	var wall: Color = h.wall
	var roof_c: Color = h.roof
	var roof_h: float = h.roof_h
	var garage_side: float = h.garage_side
	var idx: int = h.index

	# Main body. Collider identical; box mesh swapped for the faceted house,
	# which is base-anchored and so drops by half the wall height.
	var body := _static_box(pos + Vector3(0, wall_h * 0.5, 0), Vector3(w, wall_h, d), wall, rot)
	_model_body(body, &"house", -wall_h * 0.5, {
		"w": w, "d": d, "wall_h": wall_h, "roof_h": roof_h,
		"wall_colour": wall, "roof_colour": roof_c,
		"garage_side": garage_side, "variant": float(idx),
	})

	_roof(h)

	# Chimney. The brickwork is part of the model now, so this is collision
	# only. It moves to the model's chimney side (the model mirrors it with
	# garage_side) — same size, same height, just no longer an invisible block
	# sitting on the wrong slope of three of the six roofs.
	var chim_pos := _house_point(h, Vector3(w * 0.28 * garage_side, 0.0, d * 0.12))
	chim_pos.y = wall_h + roof_h * 0.85
	_hide_meshes(_static_box(chim_pos, Vector3(0.65, roof_h * 1.5, 0.65),
		Color(0.40, 0.28, 0.24), rot))


## Roof COLLISION only. The visual gable — three banded pitches per side, a
## ridge cap, rake edges and an eave fascia — comes from the house model in
## _build_house(); the PrismMesh that used to live here is gone. The plateau
## and the bonus trigger below are untouched.
func _roof(h: Dictionary) -> void:
	var pos: Vector3 = h.pos
	var rot: float = h.rot
	var w: float = h.w
	var wall_h: float = h.wall_h
	var d: float = h.d
	var roof_h: float = h.roof_h
	var roof_c: Color = h.roof

	# Invisible plateau collider so the roof is actually landable — a flat
	# approximation of the pitched volume is plenty; nobody will notice while
	# flapping around up there.
	var sb := _static_box(pos + Vector3(0, wall_h + roof_h * 0.42, 0),
		Vector3(w * 0.9, roof_h * 0.6, d * 0.9), roof_c, rot)
	for c in sb.get_children():
		if c is MeshInstance3D:
			c.visible = false

	# EVERY house scores, not just the showcase one at the back. `get_up_there`
	# says "Get on a roof. Ideally not your own." — five of the six roofs in
	# the cul-de-sac used to be silent, so a player could do exactly what the
	# objective asked, land on house 4, and watch the row stay unticked. That
	# is the single most corrosive thing an objective system can do.
	#
	# The volume also used to sit INSIDE the plateau collider (4.10–4.90 while
	# the plateau filled 3.64–4.84), leaving a 6 cm sliver of usable trigger on
	# top. It now starts just under the plateau's surface and stands 1.3 m
	# proud of it, which is a goose-sized target.
	var plateau_top: float = wall_h + roof_h * 0.72
	var bonus := Area3D.new()
	add_child(bonus)
	bonus.global_position = pos + Vector3(0, plateau_top + 0.55, 0)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(w * 0.8, 1.3, d * 0.8)
	cs.shape = bs
	bonus.add_child(cs)
	bonus.monitoring = true
	bonus.monitorable = false
	bonus.body_entered.connect(_on_roof_entered.bind(bonus))


func _on_roof_entered(body: Node3D, area: Area3D) -> void:
	if not (body is Goose):
		return
	if not _trigger_ready(area):
		return
	# A position, so the 150 lands on the roof the player just reached
	# instead of only in the HUD counter.
	Game.score(150, MDEF.LBL_ROOF, body.global_position)
	if _sfx != null:
		_sfx.play_at(&"score_blip_hi", body, 0.0, 1.0)


# ------------------------------------------------------------------ yards

func _yards(houses: Array) -> void:
	for h in houses:
		var hd: Dictionary = h
		var w: float = hd.w
		var d: float = hd.d
		var rot: float = hd.rot
		var front_centre := _house_point(hd, Vector3(0, 0.01, -d * 0.5 - 3.4))
		_flat_surf(front_centre, Vector3(w + 3.6, 0.03, 5.2), &"grass", Color(0.26, 0.46, 0.20), rot, 2.0)
		# Hedges flanking the front walk. Twelve of these line the street and
		# every one of them was a flat green box. The collider is unchanged; the
		# visual is a clipped shrub with a lumpy top and a mulch bed.
		var hedge_z := -d * 0.5 - 1.0
		for side in [-1.0, 1.0]:
			var sd: float = side
			var hp := _house_point(hd, Vector3(sd * (w * 0.5 + 0.5), 0.25, hedge_z))
			var hb := _static_box(hp, Vector3(1.5, 0.5, 0.5), Color(0.16, 0.32, 0.14), rot)
			_model_body(hb, &"hedge", -0.25, {
				"size": Vector3(1.5, 0.5, 0.5),
				"colour": Color(0.16, 0.32, 0.14),
				"variant": float(hd.index) * 3.0 + sd,
			})


func _backyards(houses: Array) -> void:
	for h in houses:
		var hd: Dictionary = h
		var w: float = hd.w
		var d: float = hd.d
		var half_w: float = w * 0.5 + 1.4
		var near: float = d * 0.5 + 0.4
		var far: float = near + 7.0
		var centre := _house_point(hd, Vector3(0, 0.01, (near + far) * 0.5))
		_flat_surf(centre, Vector3(half_w * 2, 0.03, far - near), &"grass", Color(0.27, 0.44, 0.21), hd.rot, 2.0)
		if hd.fenced:
			_fence_rect(hd, half_w, near, far, 1.7, Color(0.72, 0.66, 0.52))
		hd["yard_near"] = near
		hd["yard_far"] = far
		hd["yard_half_w"] = half_w


func _driveways_and_cars(houses: Array) -> void:
	var colors := [Color(0.62, 0.16, 0.16), Color(0.20, 0.28, 0.48), Color(0.82, 0.82, 0.84),
		Color(0.14, 0.14, 0.16), Color(0.36, 0.46, 0.36), Color(0.70, 0.68, 0.20)]
	for i in houses.size():
		var hd: Dictionary = houses[i]
		var w: float = hd.w
		var d: float = hd.d
		var gs: float = hd.garage_side
		var dx: float = gs * (w * 0.5 - 1.3)
		var near_p := _house_point(hd, Vector3(dx, 0.02, -d * 0.5 - 0.05))
		var far_p := _house_point(hd, Vector3(dx, 0.02, -d * 0.5 - 5.6))
		var mid := (near_p + far_p) * 0.5
		_flat_surf(mid, Vector3(2.8, 0.05, 5.8), &"concrete", Color(0.66, 0.64, 0.60), hd.rot, 1.5)
		var car_p := _house_point(hd, Vector3(dx, 0.95, -d * 0.5 - 3.0))
		var v := _prop(car_p, Vector3(1.9, 1.6, 4.2), colors[i % colors.size()], 900.0, 120, "CAR")
		v.breakable = false
		v.break_force = 999.0
		v.rotation.y = hd.rot


func _street_furniture(houses: Array) -> void:
	# Lamp posts around the bulb, skipping the entrance mouth.
	for i in 6:
		var a := float(i) / 6.0 * TAU
		var p := Vector3(sin(a) * (_bulb_r + 2.2), 0, cos(a) * (_bulb_r + 2.2))
		if absf(p.x) < _corridor_hw + 2.0 and p.z > 0.0:
			continue
		# Collider stays the 6.8 m pole; the model supplies the taper, the
		# access hatch and the shoebox head, so the head decal is gone.
		var post := _static_box(p + Vector3(0, 3.4, 0), Vector3(0.22, 6.8, 0.22),
			Color(0.28, 0.28, 0.30))
		_model_body(post, &"lamp_post", -3.4, {}, 6.8 / 8.4)

	# A curbside mailbox for every house.
	for h in houses:
		var hd: Dictionary = h
		var d: float = hd.d
		var mb_local := Vector3(hd.garage_side * (hd.w * 0.5 + 2.0), 0, -d * 0.5 - 6.2)
		var mb_pos := _house_point(hd, mb_local)
		var mb := _on_post(mb_pos, 0.9, Vector3(0.42, 0.06, 0.30), Vector3(0.42, 0.3, 0.6),
			Color(0.32, 0.30, 0.28), Color(0.20, 0.36, 0.58), 3.0, 30, "MAILBOX")
		# _prop() yaws props at random, which is right for a bin and wrong for
		# a mailbox: the model has a hinged door and a raised flag on one end,
		# and the door belongs facing the road like the house it serves.
		mb.rotation.y = hd.rot

	# Stop sign + fire hydrant at the mouth of the cul-de-sac. The sign is
	# built as one combined post+octagon prop, so a good hit topples the
	# whole thing instead of just popping the placard off.
	#
	# The collider grew from 0.22 x 2.4 x 0.5 to the model's real footprint.
	# The old box was a placard-less stick: the goose spawns eight metres from
	# this thing and it was the most conspicuous graybox in the game.
	var mouth_z: float = _bulb_r + 1.5
	var sign := _prop(Vector3(-_corridor_hw - 1.8, 1.13, mouth_z), Vector3(0.72, 2.26, 0.16),
		Color(0.80, 0.13, 0.11), 9.0, 35, "STOP SIGN")
	# The face is authored at -Z like every model in the project, so a half turn
	# points it back down the entrance corridor at whatever is driving in — and
	# at the goose, which spawns staring straight up that corridor.
	sign.rotation.y = PI
	_prop(Vector3(_corridor_hw + 1.8, 0.4, mouth_z), Vector3(0.4, 0.8, 0.4),
		Color(0.82, 0.16, 0.10), 14.0, 45, "HYDRANT")


func _garbage_day(houses: Array) -> void:
	for i in houses.size():
		var hd: Dictionary = houses[i]
		var w: float = hd.w
		var d: float = hd.d
		var gs: float = hd.garage_side
		var right: Vector3 = hd.right
		var base := _house_point(hd, Vector3(-gs * (w * 0.5 + 1.0), 0, -d * 0.5 - 6.0))
		var recycling_pos: Vector3 = base + right * 0.85
		_prop(base, Vector3(0.6, 0.9, 0.55), Color(0.16, 0.42, 0.20), 6.0, 22, "GARBAGE BIN")
		_prop(recycling_pos, Vector3(0.6, 0.9, 0.55), Color(0.18, 0.30, 0.56), 6.0, 22, "RECYCLING BIN")
		hd["recycling_pos"] = recycling_pos
		if i == 1 or i == 3:
			# `variant` is a deterministic shape seed for the sack, so the two
			# bags slump differently without a randf() anywhere.
			_prop(base + right * 1.7, Vector3(0.48, 0.55, 0.5), Color(0.30, 0.30, 0.32),
				2.0, 18, "GARBAGE BAG", {"variant": float(i)})


# ------------------------------------------------------------------ backyard set-pieces

func _backyard_fun(houses: Array) -> void:
	# House 0 — trampoline + the golden retriever's yard.
	var h0: Dictionary = houses[0]
	var yard0_near: float = h0.yard_near
	var yard0_far: float = h0.yard_far
	var tramp_pos := _house_point(h0, Vector3(-2.0, 0, (yard0_near + yard0_far) * 0.5))
	_trampoline(tramp_pos, h0.rot)
	var dog_pos := _house_point(h0, Vector3(3.4, 0, yard0_near + 1.4))
	_dog_static(dog_pos, h0.rot)
	h0["molly_pos"] = dog_pos + Vector3(0, 0.5, 0.6)

	# House 1 — the kiddie pool yard.
	var h1: Dictionary = houses[1]
	var yard1_near: float = h1.yard_near
	var yard1_far: float = h1.yard_far
	var pool_pos := _house_point(h1, Vector3(-1.4, 0, (yard1_near + yard1_far) * 0.5))
	_kiddie_pool(pool_pos)
	_sprinkler(_house_point(h1, Vector3(2.6, 0, yard1_near + 1.4)))
	_sprinkler(_house_point(h1, Vector3(2.6, 0, yard1_far - 1.1)))

	# House 3 — fairy ring in the damp shady corner, plus the clothesline.
	var h3: Dictionary = houses[3]
	var yard3_near: float = h3.yard_near
	var yard3_far: float = h3.yard_far
	var ring_pos := _house_point(h3, Vector3(2.2, 0, yard3_far - 1.4))
	h3["ring_pos"] = ring_pos
	_fairy_ring(ring_pos)
	_clothesline(_house_point(h3, Vector3(-2.0, 0, (yard3_near + yard3_far) * 0.5)), h3.rot)


func _front_yard_fun(houses: Array) -> void:
	# House 2 — BBQ, patio set, and darts stashed behind the garage.
	var h2: Dictionary = houses[2]
	var w2: float = h2.w
	var d2: float = h2.d
	var bbq_pos := _house_point(h2, Vector3(-w2 * 0.5 - 2.6, 0, -d2 * 0.5 - 2.2))
	_bbq_patio(bbq_pos, h2.rot)
	h2["catnip_pos"] = _house_point(h2, Vector3(w2 * 0.5 + 2.2, 0, -d2 * 0.5 - 2.6))
	_herb_planter(h2["catnip_pos"], h2.rot)
	h2["darts_pos"] = _house_point(h2, Vector3(h2.garage_side * (w2 * 0.5 + 1.4), 0.5, d2 * 0.15))

	# House 4 — basketball, bird feeder, and a little gnome garden.
	var h4: Dictionary = houses[4]
	var w4: float = h4.w
	var d4: float = h4.d
	_basketball_hoop(_house_point(h4, Vector3(w4 * 0.5 + 3.0, 0, -d4 * 0.5 - 2.4)), h4.rot)
	_on_post(_house_point(h4, Vector3(-w4 * 0.5 - 2.4, 0, -d4 * 0.5 - 1.6)), 2.0,
		Vector3(0.5, 0.06, 0.5), Vector3(0.42, 0.5, 0.42),
		Color(0.36, 0.28, 0.20), Color(0.66, 0.42, 0.20), 2.0, 60, "BIRD FEEDER")
	var gnome_pos := _house_point(h4, Vector3(0, 0, -d4 * 0.5 - 3.6))
	h4["gnome_pos"] = gnome_pos
	_gnomes(gnome_pos)
	h4["math_pos"] = _house_point(h4, Vector3(-w4 * 0.3, 0, -d4 * 0.5 - 4.2))

	# House 5 — the crabapple tree, a leaf pile, and a bathroom windowsill.
	var h5: Dictionary = houses[5]
	var w5: float = h5.w
	var d5: float = h5.d
	var tree_pos := _house_point(h5, Vector3(w5 * 0.5 + 3.6, 0, -d5 * 0.5 - 1.6))
	h5["tree_pos"] = tree_pos
	_crabapple_tree(tree_pos)
	var leaf_pos := _house_point(h5, Vector3(-w5 * 0.5 - 2.2, 0, -d5 * 0.5 - 2.0))
	h5["leaf_pos"] = leaf_pos
	_leaf_pile(leaf_pos)
	var blower := NpcHuman.new()
	add_child(blower)
	blower.setup(Color(0.85, 0.55, 0.18))
	blower.global_position = leaf_pos + Vector3(1.3, 0.1, 0.6)
	var wall_h5: float = h5.wall_h
	var sill_pos := _house_point(h5, Vector3(w5 * 0.5 + 0.05, wall_h5 * 0.5, d5 * 0.2))
	_decal_box(sill_pos + Vector3(0, -0.32, 0), Vector3(0.5, 0.08, 0.35), Color(0.90, 0.88, 0.84), h5.rot + PI * 0.5)
	h5["robo_pos"] = sill_pos


# ------------------------------------------------------------------ set-pieces

func _trampoline(pos: Vector3, rot_y: float) -> void:
	## The single most fun object in the zone: fly into the mat and get
	## launched skyward. Frame is a ring of angled legs + a rim; the mat
	## itself is a plain non-colliding disc sitting inside an Area3D.
	var radius := 1.9
	# The eight leg colliders stay exactly where they were — they are what the
	# goose actually bumps into. Their boxes go invisible and one trampoline
	# model (padded rim, dished mat, six angled legs) covers the lot, replacing
	# the TorusMesh rim and the flat mat disc.
	for i in 8:
		var a := float(i) / 8.0 * TAU
		var leg_pos := pos + Vector3(cos(a) * radius * 0.92, 0.28, sin(a) * radius * 0.92)
		_hide_meshes(_static_box(leg_pos, Vector3(0.09, 0.56, 0.09), Color(0.30, 0.30, 0.32)))
	_model_at(&"trampoline", Vector3(pos.x, 0.0, pos.z), rot_y)

	var area := Area3D.new()
	add_child(area)
	area.global_position = pos + Vector3(0, 0.66, 0)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius * 0.8
	cyl.height = 0.5
	cs.shape = cyl
	area.add_child(cs)
	area.monitoring = true
	area.monitorable = false
	area.body_entered.connect(_on_trampoline_bounce)


func _on_trampoline_bounce(body: Node3D) -> void:
	if body is Goose:
		body.velocity.y = 20.0
		# No latch here on purpose: the launch itself throws you clear of the
		# area, so re-entry is already the cost, and `boing` wants seven of
		# these while `ascension` wants three inside fourteen seconds.
		Game.score(35, MDEF.LBL_BOING, body.global_position)
		if _sfx != null:
			_sfx.play_at(&"score_blip_hi", body, 0.0, 1.25)


func _dog_static(pos: Vector3, rot_y: float) -> void:
	## Molly. A very good dog. Set dressing only — she does not move, she does
	## not need to, she is perfect as she is.
	##
	## She used to be a CapsuleMesh body, a SphereMesh head and two box ears —
	## the last curved primitives in this backyard AND a second dog model in a
	## project that already had one. She is now boss_ranger_visual.gd's collie
	## in the &"golden" coat: same build, retriever colouring, dropped ears.
	##
	## The visual is authored origin-on-the-ground facing -Z, and `rot_y` is
	## the house's rotation with -Z as its front, so this is a straight
	## assignment — the old code hand-rotated a head offset by the same angle.
	var d := DOG_VIS.new()
	d.setup(&"golden")
	add_child(d)
	d.global_position = pos
	d.rotation.y = rot_y


func _kiddie_pool(pos: Vector3) -> void:
	## Comically small next to a goose the size of a toddler.
	var radius := 1.25
	# Moulded shell instead of a torus: an outward-flaring wall, a flat lip and
	# a real floor you can see down onto. The water disc below still sits inside
	# the rim and still takes the Tex water material, so the pool keeps the one
	# animated surface in the backyard.
	_model_at(&"kiddie_pool", Vector3(pos.x, 0.0, pos.z),
		0.0, {"colour": Color(0.86, 0.30, 0.42)})
	var water_mi := _disc(pos + Vector3(0, 0.12, 0), radius * 0.86, 0.10, Color(0.30, 0.62, 0.72), true)
	if _tex != null:
		water_mi.material_override = _tex.water_material()

	var water := Area3D.new()
	water.add_to_group("water")
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = radius * 0.86
	sh.height = 0.5
	cs.shape = sh
	water.add_child(cs)
	water.monitoring = false
	add_child(water)
	water.global_position = pos + Vector3(0, 0.2, 0)

	var bonus := Area3D.new()
	add_child(bonus)
	bonus.global_position = pos + Vector3(0, 0.2, 0)
	var bcs := CollisionShape3D.new()
	var bsh := CylinderShape3D.new()
	bsh.radius = radius * 0.86
	bsh.height = 0.6
	bcs.shape = bsh
	bonus.add_child(bcs)
	bonus.monitoring = true
	bonus.monitorable = false
	bonus.body_entered.connect(_on_pool_entered.bind(bonus))


func _on_pool_entered(body: Node3D, area: Area3D) -> void:
	if not (body is Goose):
		return
	if not _trigger_ready(area):
		return
	Game.score(100, MDEF.LBL_CANNONBALL, body.global_position)
	if _sfx != null:
		_sfx.play_at(&"splash_in", body, 0.0, 1.1)


func _sprinkler(pos: Vector3) -> void:
	## Riser collider unchanged. The two grey boxes are gone: the head is now
	## the faceted pop-up from prop_models_finale.gd, which already throws along
	## -Z about a base-anchored origin — the exact axis _process() oscillates.
	## _sprinkler_heads holds the whole model rather than a bare head mesh, so
	## the can turns with the nozzle; at six sides that is invisible, and it is
	## what the finale zone already does with the same model.
	var riser := _static_box(pos + Vector3(0, 0.1, 0), Vector3(0.10, 0.2, 0.10),
		Color(0.5, 0.5, 0.5))
	_hide_meshes(riser)

	var head := Node3D.new()
	add_child(head)
	head.global_position = pos
	FIN_PROPS.build(&"sprinkler", head, {"colour": Color(0.28, 0.32, 0.30)})
	head.set_meta("phase", randf() * TAU)
	_sprinkler_heads.append(head)

	var water := Area3D.new()
	water.add_to_group("water")
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 1.6
	cs.shape = sh
	water.add_child(cs)
	water.monitoring = false
	add_child(water)
	water.global_position = pos + Vector3(0, 0.5, 0)


func _fairy_ring(pos: Vector3) -> void:
	## Fly agaric fairy ring, tucked in a damp shady backyard corner.
	_decal_box(pos + Vector3(0, 0.01, 0), Vector3(4.2, 0.02, 4.2), Color(0.22, 0.30, 0.20))
	var count := 6
	for i in count:
		var a := float(i) / float(count) * TAU
		var p := pos + Vector3(cos(a) * 1.4, 0, sin(a) * 1.4)
		_mushroom(p, 0.4 + fmod(float(i) * 0.13, 0.2), i)


func _mushroom(pos: Vector3, scale: float, variant := 0) -> void:
	## Faceted fly agaric — prop_models.gd section 25. The SphereMesh
	## hemisphere, the box stem and the six flat white decal slabs are all
	## gone; the stem collider is the same box it always was, so the ring still
	## bumps the same way.
	##
	## The model is authored a metre across and scaled here, exactly as the old
	## SphereMesh was, and each mushroom gets its own `variant` so the ring is
	## six mushrooms rather than one mushroom six times.
	var sb := _static_box(pos + Vector3(0, 0.28 * scale, 0),
		Vector3(0.2 * scale, 0.56 * scale, 0.2 * scale), Color(0.94, 0.92, 0.86))
	_model_body(sb, &"fly_agaric", -0.28 * scale, {"variant": float(variant)}, scale)


## THE LAUNDRY WAS ON THE GROUND.
##
## The four LAUNDRY props were free RigidBody3Ds spawned in mid-air at y 1.62
## with nothing holding them up, and the "line" was a `_decal_box` with no
## collider. They fell the instant the zone loaded and spent the whole leg
## lying flat on the grass — so `wearing_it` ("A very large goose in a
## stranger's duvet") was asking the player to fly through a laundry line that
## stopped existing before the clock started.
##
## The wire is now a real static body and each item hangs off it on a pin, so
## the washing swings when a goose goes through it and the hidden objective
## describes something that is actually in the world. The pin is freed with its
## item, otherwise breaking a shirt leaves a joint pointing at a dead node.
func _clothesline(pos: Vector3, rot_y: float) -> void:
	var half := 2.2
	var right := Vector3(cos(rot_y), 0.0, -sin(rot_y))
	var p1 := pos - right * half
	var p2 := pos + right * half
	_static_box(p1 + Vector3(0, 0.9, 0), Vector3(0.1, 1.8, 0.1), Color(0.36, 0.34, 0.32))
	_static_box(p2 + Vector3(0, 0.9, 0), Vector3(0.1, 1.8, 0.1), Color(0.36, 0.34, 0.32))
	var wire := _static_box(pos + Vector3(0, 1.78, 0), Vector3(half * 2, 0.03, 0.03),
		Color(0.85, 0.83, 0.80), rot_y)
	var colors := [Color(0.85, 0.85, 0.90), Color(0.30, 0.42, 0.68), Color(0.80, 0.24, 0.24), Color(0.90, 0.78, 0.30)]
	for i in 4:
		var t := (float(i) + 0.5) / 4.0
		var lp := p1.lerp(p2, t) + Vector3(0, 1.60, 0)
		var item := _prop(lp, Vector3(0.4, 0.34, 0.05), colors[i % colors.size()],
			0.35, 12, MDEF.LBL_LAUNDRY)
		# Hung square to the line rather than at _prop()'s random yaw — a towel
		# pegged out at 40 degrees reads as debris, not as washing.
		item.rotation.y = rot_y
		var peg := PinJoint3D.new()
		add_child(peg)
		peg.global_position = lp + Vector3(0, 0.17, 0)
		peg.node_a = peg.get_path_to(wire)
		peg.node_b = peg.get_path_to(item)
		item.tree_exiting.connect(func() -> void:
			if is_instance_valid(peg):
				peg.queue_free())


func _bbq_patio(pos: Vector3, rot_y: float) -> void:
	var right := Vector3(cos(rot_y), 0.0, -sin(rot_y))
	# The BBQ itself — scatters when hit hard.
	var bbq := _prop(pos, Vector3(1.0, 1.05, 0.55), Color(0.18, 0.18, 0.20), 16.0, 45, "BBQ")
	bbq.break_force = 11.0
	for i in 3:
		_prop(pos + right * (1.0 + float(i) * 0.3) + Vector3(0, 0.15, 0.4),
			Vector3(0.32, 0.13, 0.13), Color(0.70, 0.32, 0.24), 0.3, 10, "SAUSAGE")
	# Patio table + chairs + an umbrella that goes flying.
	var table_pos := pos + right * 3.2
	_prop(table_pos, Vector3(1.1, 0.72, 1.1), Color(0.40, 0.30, 0.22), 14.0, 40, "PATIO TABLE")
	_prop(table_pos, Vector3(0.12, 1.7, 0.12), Color(0.85, 0.30, 0.20), 1.6, 35, "UMBRELLA")
	for i in 3:
		var a := float(i) / 3.0 * TAU
		_prop(table_pos + Vector3(cos(a) * 1.4, 0, sin(a) * 1.4), Vector3(0.55, 0.85, 0.55),
			Color(0.42, 0.30, 0.22), 5.0, 25, "PATIO CHAIR")


## Pole collider unchanged. The board decal, the TorusMesh rim — the last
## curved primitive left in the zone — and the floating hoop are all one model
## now, and the ball is a faceted sphere instead of a 42 cm cube.
func _basketball_hoop(pos: Vector3, rot_y: float) -> void:
	var front := Vector3(-sin(rot_y), 0.0, -cos(rot_y))
	var pole := _static_box(pos + Vector3(0, 1.6, 0), Vector3(0.14, 3.2, 0.14),
		Color(0.30, 0.30, 0.32), rot_y)
	_model_body(pole, &"basketball_hoop", -1.6)
	_prop(pos + front * 1.6 + Vector3(0.6, 0.25, 0), Vector3(0.42, 0.42, 0.42),
		Color(0.78, 0.36, 0.10), 0.6, 25, "BASKETBALL")


func _crabapple_tree(pos: Vector3) -> Dictionary:
	## Mountain-ash / crabapple. Fruit ferments on the branch in the fall,
	## which is the real mechanism behind the berries substance.
	##
	## Trunk collider unchanged, so the berry pickup at y 4.1 is still up in the
	## canopy where the design wants it. The SphereMesh is gone: tree_deciduous
	## is three interpenetrating faceted blobs on a leaning trunk with two
	## branch stubs holding them up.
	var trunk := _static_box(pos + Vector3(0, 1.6, 0), Vector3(0.5, 3.2, 0.5),
		Color(0.34, 0.26, 0.20))
	_model_body(trunk, &"tree_deciduous", -1.6, {
		"colour": Color(0.34, 0.26, 0.20),
		"leaf_colour": Color(0.28, 0.36, 0.22),
		"variant": 2.4,
	})
	var canopy_pos := pos + Vector3(0, 4.1, 0)
	for i in 9:
		var a := randf_range(0, TAU)
		_decal_box(pos + Vector3(cos(a) * 1.75, 3.9 + randf_range(-0.7, 0.8), sin(a) * 1.75),
			Vector3(0.28, 0.28, 0.28), Color(0.72, 0.14, 0.18))
	return {"ground": pos + Vector3(0, 0.5, 0), "canopy": canopy_pos}


func _leaf_pile(pos: Vector3) -> void:
	var colors := [Color(0.82, 0.44, 0.10), Color(0.86, 0.66, 0.16), Color(0.62, 0.30, 0.08)]
	for i in 12:
		var p := pos + Vector3(randf_range(-1.1, 1.1), 0.1 + randf_range(0.0, 0.3), randf_range(-1.1, 1.1))
		_prop(p, Vector3(0.32, 0.1, 0.32), colors[i % colors.size()], 0.4, 8, "LEAVES")


func _gnomes(pos: Vector3) -> void:
	for i in 5:
		var a := float(i) / 5.0 * TAU
		var p := pos + Vector3(cos(a) * 1.2, 0, sin(a) * 1.2)
		var g := _prop(p, Vector3(0.32, 0.55, 0.32), Color(0.78, 0.16, 0.14), 2.2, 50, "GNOME")
		g.break_force = 5.0


## The catnip source, and therefore one of the few props in the zone the player
## has a reason to walk right up to. The raised bed stays a box — a raised bed
## IS a box — but the five pale slabs standing in for herbs were the loudest
## graybox left on this side of the cul-de-sac, so they are small hedges now.
func _herb_planter(pos: Vector3, rot_y: float) -> void:
	_static_box(pos + Vector3(0, 0.3, 0), Vector3(3.0, 0.6, 1.4), Color(0.40, 0.27, 0.19), rot_y)
	var right := Vector3(cos(rot_y), 0.0, -sin(rot_y))
	for i in 3:
		_model_at(&"hedge", pos + right * (-0.9 + float(i) * 0.9) + Vector3(0, 0.6, 0), rot_y, {
			"size": Vector3(0.78, 0.44, 0.52),
			"colour": Color(0.40, 0.62, 0.30),
			"variant": float(i) * 4.0,
		})


# ------------------------------------------------------------------ substances

func _sources(houses: Array) -> void:
	var h0: Dictionary = houses[0]
	var h2: Dictionary = houses[2]
	var h3: Dictionary = houses[3]
	var h4: Dictionary = houses[4]
	var h5: Dictionary = houses[5]

	var d0: float = h0.d
	var d2: float = h2.d
	var d4: float = h4.d

	# Grass: infinite, spread across a few front lawns plus the cul-de-sac
	# island, so there's always a bite nearby wherever the chaos takes you.
	var grass := Subs.get_substance(&"grass")
	var grass_spots: Array = [
		_house_point(h0, Vector3(0, 0, -d0 * 0.5 - 3.4)),
		_house_point(h2, Vector3(0, 0, -d2 * 0.5 - 3.4)),
		_house_point(h4, Vector3(0, 0, -d4 * 0.5 - 3.4)),
		Vector3(-3.4, 0, 0),
	]
	for spot in grass_spots:
		var gp: Vector3 = spot
		var s := SubstancePickup.new()
		add_child(s)
		s.setup(grass, 0.42)
		s.infinite = true
		s.global_position = gp + Vector3(0, 0.4, 0)

	# Catnip in the herb planter — cats are placed elsewhere for it to command.
	var catnip_p: Vector3 = h2.catnip_pos
	_source(catnip_p + Vector3(0, 0.8, 0), Subs.get_substance(&"catnip"), 0.4)

	# Fly agaric fairy ring, in house 3's fenced shady corner.
	var ring_p: Vector3 = h3.ring_pos
	_source(ring_p + Vector3(0, 0.3, 0), Subs.get_substance(&"fly_agaric"), 0.42)

	# Berries: reachable on the ground, full-strength up in the canopy —
	# a better reward for the player who actually learned to fly.
	var tree_p: Vector3 = h5.tree_pos
	var berries := Subs.get_substance(&"berries")
	# 1.1 m OUT FROM THE TRUNK, not on its axis. `_crabapple_tree()` gives the
	# tree a 0.5 m square collider and this source used to sit at its centreline,
	# so the berry model rendered inside the wood. Out along the house's `right`
	# because that is the direction `tree_pos` itself was pushed — away from the
	# wall, into the open side yard — so the fruit stays on the side of the tree
	# a goose can actually stand on. tools/geomtest.gd pass 2.
	var right5: Vector3 = h5.right
	_source(tree_p + right5 * 1.1 + Vector3(0, 0.5, 0), berries, 0.5)
	_source(tree_p + Vector3(0, 4.1, 0), berries, 0.62)

	# Molly, the golden retriever, in house 0's fenced backyard.
	var molly_p: Vector3 = h0.molly_pos
	_source(molly_p, Subs.get_substance(&"molly"), 0.5)

	# Whipped cream cans in the recycling.
	var nitrous_bin: Vector3 = h0.recycling_pos
	_source(nitrous_bin + Vector3(0, 0.7, 0), Subs.get_substance(&"nitrous"), 0.45)

	# A teenager's stash, tucked behind the garage.
	var darts_p: Vector3 = h2.darts_pos
	_source(darts_p, Subs.get_substance(&"darts"), 0.34)

	# Cough syrup on the bathroom windowsill.
	var robo_p: Vector3 = h5.robo_pos
	_source(robo_p + Vector3(0, 0.2, 0), Subs.get_substance(&"robo"), 0.42)

	# Cereal box in the recycling.
	var special_k_bin: Vector3 = h2.recycling_pos
	_source(special_k_bin + Vector3(0, 0.7, 0), Subs.get_substance(&"special_k"), 0.44)

	# Grade 9 homework, blowing across the lawn.
	var math_p: Vector3 = h4.math_pos
	_source(math_p + Vector3(0, 0.3, 0), Subs.get_substance(&"math"), 0.42)
	_decal_box(math_p, Vector3(1.4, 0.02, 1.9), Color(0.95, 0.95, 0.92))


# ------------------------------------------------------------------ population

## A deterministic stream for one group of placements. Same mechanism and same
## reason as `zone_strip_mall.gd::_rng()`, which carries the long version of
## the argument: every builder used to draw from the one global RNG, so where
## an actor stood was a function of how many `randf()` calls happened first,
## and editing any builder moved every actor after it. `docs/RECENT_FAILURES.md`
## F-002.
##
## Suburbia and the strip mall are the only two zones that place actors
## randomly at all — the other four use fixed `spots[]` arrays — so between
## them this closes it. `tools/glidetest.gd::_the_layout_is_seeded()` builds
## every zone twice with global draws burned in between and requires every
## actor to land in the same place.
func _rng(tag: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash("suburbia|%d|%s" % [Flock.leg, tag])
	return r

func _people() -> void:
	var shirts := [Color(0.78, 0.24, 0.22), Color(0.22, 0.34, 0.62), Color(0.90, 0.86, 0.42),
		Color(0.28, 0.52, 0.34), Color(0.56, 0.30, 0.62), Color(0.92, 0.92, 0.92)]
	var folks := _rng("people")
	for i in 8:
		var n := NpcHuman.new()
		add_child(n)
		n.setup(shirts[i % shirts.size()])
		var a := folks.randf_range(0, TAU)
		var r := folks.randf_range(6.0, _bulb_r + 8.0)
		n.global_position = Vector3(sin(a) * r, 0.1, cos(a) * r)


func _cats() -> void:
	## Cats exist so catnip has something to command. About a third of them
	## ignore you entirely, which is both accurate and funnier.
	var furs := [Color(0.24, 0.22, 0.21), Color(0.78, 0.62, 0.36), Color(0.92, 0.92, 0.90),
		Color(0.46, 0.42, 0.40), Color(0.62, 0.44, 0.24), Color(0.30, 0.30, 0.32)]
	var moggies := _rng("cats")
	for i in 6:
		var c := Cat.new()
		add_child(c)
		c.setup(furs[i % furs.size()])
		var a := moggies.randf_range(0, TAU)
		var r := moggies.randf_range(6.0, _bulb_r + 10.0)
		c.global_position = Vector3(sin(a) * r, 0.2, cos(a) * r)


func _spawn_goose() -> void:
	goose = Goose.new()
	goose.name = "Goose"
	add_child(goose)
	goose.global_position = Vector3(0, 1.0, _bulb_r + 5.0)
	# Your flock, physically present. The only place the Designated Driver
	# can be chosen, and the only in-zone read on how wrecked they're getting.
	add_child(preload("res://scripts/world/flock_pen.gd").new().setup(Vector3(0, 0.8, 34.0)))

	camera_rig = preload("res://scripts/goose/goose_camera.gd").new()
	camera_rig.name = "CameraRig"
	camera_rig.target = goose
	add_child(camera_rig)
	goose.cam = camera_rig

	# NO SHAKE WIRING HERE. The zone used to connect landed/tumbled straight to
	# camera_rig.add_shake(); the Juice autoload owns the shake bus now and the
	# goose controller drives it, so leaving these lambdas in shook the camera
	# twice for one landing — and, worse, bypassed the screen_shake
	# accessibility pref that Juice gates every shake on.


# ------------------------------------------------------------------ objectives

## DELETED: the old `objectives()` list.
##
## It was dead code — `scripts/ui/objectives.gd` is orphaned and main.gd builds
## a MissionHUD instead — but it was actively misleading dead code, because it
## used ids that no longer exist anywhere (`get_on_the_roof`,
## `lawn_gnome_massacre`, `leaf_blower_beef`) alongside four that still do. The
## live set for this zone is `mission_defs.gd::_suburbia()`, selected by
## `mission_zone_id()` below. `zone_strip_mall.gd` still carries the same
## fossil and should lose it too.


## Which objective set the Mission autoload should load for this zone.
func mission_zone_id() -> StringName:
	return &"suburbia"


func zone_title() -> String:
	return "LEG %d — SUBURBIA" % Flock.leg
