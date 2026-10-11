extends RefCounted
## CAN A PLAYER FIND WHAT A LEG OFFERS? MEASURED, NOT JUDGED.
##
##     godot --headless --path . -- --probe --findtest 2>&1 | grep '^\[find\]'
##
## ═══════════════════════════════════════════════════════════════════════════
## THIS IS A REPORT, NOT A GATE. IT ASSERTS NOTHING AND FAILS NOTHING.
## ═══════════════════════════════════════════════════════════════════════════
##
## The human, on playing leg 1: *"why are there no drugs on level one now? i
## remember there used to be hella drugs but now all i can find is grass."*
## D-068 (`docs/DECISIONS.md`) split that into two questions. How MANY substances
## leg 1 offers is one constant and it is the human's (D-022, D-037). How
## FINDABLE the ones it offers are is arithmetic, and nobody had counted it —
## the only record was a sentence saying the other pickups are "up a tree,
## elevated, or in a far corner".
##
## So for every leg the director builds, for every pickup in that leg's zone:
##
##   * how far it is from where the goose spawns, in a straight line;
##   * whether a goose standing on real ground beside it can eat it — DRIVEN:
##     the zone's own goose is put on the ground around the pickup and its
##     trigger has to fire (see `_reachable_on_foot`); and how high the trigger
##     sits above the ground, and on what, for the reading;
##   * whether the opening camera — the rig the zone itself builds, left to
##     settle behind the bird — has the pickup's model in frame;
##   * and whether anything solid stands between that camera and the model.
##
## It prints facts per pickup and a count per leg. Where things SHOULD go is a
## level-design call and stays one; this gives it its numbers. Same shape as
## `tools/glidetest.gd`, which did the same for D-006.
##
## WHAT IT CANNOT SEE, stated so it is not mistaken for more than it is: whether
## a model READS as something edible from where it is visible, how bright its
## glow is against the zone, and the walking route — distance is a straight line.
## "In view" treats a collider with no drawn geometry as see-through, which is
## right for the invisible boundary walls and wrong for a hidden graybox whose
## look is a separate mesh; "on" what uses a footprint heuristic for ground.
##
## MEASURED TWICE: the per-leg summary lines and every ON FOOT verdict came back
## identical across two runs; "in view" flickers for a few pickups because
## people and cars walk through the view ray, which is the zone being alive.
##
## ITS FIRST FOUR RUNS WERE WRONG IN FOUR WAYS, and each is fixed and commented
## where it happened: a ray from an underground origin found no ground; a ray
## that stopped at a dumpster lid called the pickup on it "on foot"; views were
## taken after walking had moved the camera; and the booted leg-1 zone, which
## never leaves the tree, answered for the zone under test.

const GEOM := preload("res://tools/geomtest.gd")
const COMMON := preload("res://tools/probe_common.gd")

## "Near the spawn" for the summary count. Leg 1's lot is about 80 m across and
## `waddle_speed` is 4.2 m/s, so 25 m is six seconds of walking.
const NEAR := 25.0


static func run(tree: SceneTree, main: Node) -> void:
	# probe_common lesson 10: `run()` is reached from main._ready(), where the
	# scene root refuses add_child() silently and hands back an empty node.
	await COMMON.settled(tree)
	var route: Array = main.get_script().get_script_constant_map().get("ROUTE", [])
	if route.is_empty():
		print("[find] FAIL — could not read main.gd's ROUTE")
		tree.quit(1)
		return
	print("[find] per leg, per pickup: metres from spawn, trigger height above the ground under it,")
	print("[find] framed by the opening camera, and line of sight from it. ON FOOT = a goose standing on the")
	print("[find] ground beside it arms its trigger; height and what it sits on are for reading, not the verdict.")
	var was_leg: int = Flock.leg
	for i in route.size():
		await _one_leg(tree, main, i + 1, str(route[i].get("zone", "")), str(route[i].get("name", "?")))
	Flock.leg = was_leg
	tree.quit(0)


static func _one_leg(tree: SceneTree, main: Node, leg: int, path: String, leg_name: String) -> void:
	var zs = load(path)
	if zs == null:
		print("[find] leg %d: %s did not load" % [leg, path])
		return
	Flock.leg = leg
	var z: Node = zs.new()
	main.add_child(z)
	# Frames for the rig to adopt its heading and the models to settle
	# (`geomtest.gd` pass 2 has the reason a pickup lies about where it renders
	# before its first `_process`), and physics frames for the colliders.
	for _i in 6:
		await tree.process_frame
	for _j in 3:
		await tree.physics_frame

	var goose: Node3D = z.get("goose") as Node3D
	var rig: Node = null if goose == null else goose.get("cam") as Node
	var cam: Camera3D = null if rig == null else rig.get("camera") as Camera3D
	if goose == null or cam == null:
		print("[find] leg %d %s: no goose or no camera rig to look from" % [leg, leg_name])
		main.remove_child(z)
		z.free()
		return
	var spawn := goose.global_position
	var space := goose.get_world_3d().direct_space_state
	var exclude: Array[RID] = [(goose as CollisionObject3D).get_rid()]

	var rows: Array[Dictionary] = []
	for node in GEOM._in_group_under(z, "substance_source"):
		var pick := node as Node3D
		if pick == null or not is_instance_valid(pick):
			continue
		var res: Object = pick.get("substance")
		var id := "?" if res == null else str(res.get("id"))
		var box: AABB = GEOM._mesh_box(pick)
		var centre: Vector3 = pick.global_position if box.size == Vector3.ZERO else box.get_center()

		# Height of the TRIGGER above the GROUND — not above the first thing under
		# it. The first run measured the double-double on top of leg 1's dumpster
		# as "on foot", because the ray stopped at the dumpster's lid; and the
		# pickups whose origin sits a hand's width under the verge read "on
		# nothing", because a ray starting underground finds no ground. So the ray
		# starts above the trigger and passes through anything standing ON the
		# ground, naming the first thing it passed.
		var below := _ground_below(space, pick.global_position + Vector3.UP * 0.6, exclude, z)
		var ground_y: float = float(below.ground_y)
		var height: float = pick.global_position.y - ground_y if ground_y > -INF else INF
		var on_what: String = str(below.on)

		# Framed, and seen.
		var framed := cam.is_position_in_frustum(centre)
		# Seen: the first DRAWN thing between the camera and the model. Invisible
		# colliders are passed through and not counted.
		var blocker := ""
		var ray_ex: Array[RID] = exclude.duplicate()
		for _b in 6:
			var ray := PhysicsRayQueryParameters3D.create(cam.global_position, centre)
			ray.exclude = ray_ex
			var block := space.intersect_ray(ray)
			if block.is_empty():
				break
			if _mine(block.collider as Node, z) and _drawn(block.collider as Node):
				blocker = _name_of(block.collider)
				break
			var brid: RID = block.rid
			ray_ex.append(brid)

		var flat := Vector2(centre.x - spawn.x, centre.z - spawn.z).length()
		rows.append({"id": id, "dist": flat, "height": height, "on": on_what,
			"framed": framed, "blocker": blocker, "pick": pick})

	# SECOND PASS, AND ONLY AFTER EVERY VIEW IS TAKEN: walking the goose moves the
	# camera rig with it, and the third run measured most of the "opening"
	# views from wherever the previous pickup's walk had left the bird.
	for row in rows:
		row["walk"] = await _reachable_on_foot(tree, space, goose, row.pick as Node3D, exclude, z)
	# Put the bird back where the zone left it, for anything that looks after.
	goose.global_position = spawn
	goose.velocity = Vector3.ZERO

	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.dist) < float(b.dist))
	var kinds := {}
	var near_on_foot := 0
	var seen := 0
	var need_flight := 0
	for r in rows:
		kinds[r.id] = true
		var on_foot: bool = bool(r.walk)
		if on_foot and float(r.dist) <= NEAR:
			near_on_foot += 1
		if not on_foot:
			need_flight += 1
		if bool(r.framed) and str(r.blocker) == "":
			seen += 1
	print("[find]")
	print("[find] leg %d  %s  (%s)" % [leg, leg_name, path.get_file()])
	print("[find]   %d pickups of %d substances: %d on foot within %.0f m of the spawn, %d need a flap or a flight, %d in view from the opening camera"
		% [rows.size(), kinds.size(), near_on_foot, NEAR, need_flight, seen])
	for r2 in rows:
		var h: float = float(r2.height)
		var where := "ON FOOT" if bool(r2.walk) else "needs a flap"
		if h == INF:
			where += ", no ground under it"
		elif str(r2.on) != "":
			where += ", %.1f m up on the %s" % [h, str(r2.on)]
		elif h > 0.3:
			where += ", %.1f m up" % h
		var sight := ("in view" if bool(r2.framed) and str(r2.blocker) == ""
			else ("out of frame" if not bool(r2.framed) else "behind %s" % str(r2.blocker)))
		print("[find]     %-14s %5.1f m   %-34s %s" % [str(r2.id), float(r2.dist), where, sight])

	main.remove_child(z)
	z.free()
	await tree.process_frame


## CAN A GOOSE STANDING ON THE GROUND EAT IT? Driven, not estimated: the zone's
## own goose is put on real ground — found by `_ground_below`, and never on top
## of a prop, since a point over a prop is somewhere the bird would have to land
## — at the pickup and on two rings around it, and the pickup's own trigger has
## to arm the eat verb (`_eating`) exactly as it does for a player walking in.
## The first two versions of this report GUESSED it from the trigger's height
## and called a double-double on a 2 m dumpster "on foot".
static func _reachable_on_foot(tree: SceneTree, space: PhysicsDirectSpaceState3D, goose: Node3D,
		pick: Node3D, exclude: Array[RID], zone: Node) -> bool:
	var spots: Array[Vector3] = [Vector3.ZERO]
	for ring in [1.0, 1.8]:
		for k in 8:
			var a := TAU * float(k) / 8.0
			spots.append(Vector3(cos(a), 0.0, sin(a)) * float(ring))
	for off in spots:
		var p: Vector3 = pick.global_position + off
		var g := _ground_below(space, Vector3(p.x, pick.global_position.y + 3.0, p.z), exclude, zone)
		if float(g.ground_y) == -INF or str(g.on) != "":
			continue
		# Away first, so the trigger sees a fresh ENTER rather than a body that
		# never left, then down onto the ground at this spot.
		goose.global_position = Vector3(p.x, float(g.ground_y) + 60.0, p.z)
		goose.set("velocity", Vector3.ZERO)
		await tree.physics_frame
		await tree.physics_frame
		goose.global_position = Vector3(p.x, float(g.ground_y) + 0.5, p.z)
		for _f in 6:
			await tree.physics_frame
			# THIS trigger, asked directly. Not `goose._eating`: the booted leg-1
			# zone never leaves the tree (probe_common lesson 7), its pickups sit
			# at the same coordinates as leg 2's and inside every other zone's
			# footprint, and whichever trigger fired last owned `_eating` — the
			# third run called the same grass "on foot" in leg 2 and not in leg 1.
			if (pick as Area3D).get_overlapping_bodies().has(goose):
				return true
	return false


## Straight down from `from`, through anything that stands ON the ground, until
## the ground itself. Returns {ground_y, on}: -INF if there is no ground, and
## `on` names the first thing passed through ("" when the pickup is on the
## ground). "Ground" is a body whose collider is broad and shallow — at least
## GROUND_AREA m² of footprint and at most GROUND_DEPTH m tall; a dumpster, a
## trunk, a house or a truck is none of those — OR one so broad it can only be
## land (LANDMASS_AREA): the second run read cottage country's walkable 80 × 35 m
## plateau as a thing seven pickups were "on". A building roof is under that,
## so a pickup on a roof still reads as up. This is a heuristic and says so.
const GROUND_AREA := 150.0
const GROUND_DEPTH := 2.5
const LANDMASS_AREA := 1500.0

static func _ground_below(space: PhysicsDirectSpaceState3D, from: Vector3, exclude: Array[RID],
		zone: Node) -> Dictionary:
	var ex: Array[RID] = exclude.duplicate()
	var on := ""
	for _k in 8:
		var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 40.0)
		q.exclude = ex
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			return {"ground_y": -INF, "on": on}
		var hp: Vector3 = hit.position
		var mine := _mine(hit.collider as Node, zone)
		if mine and _is_ground(hit.collider as Node):
			return {"ground_y": hp.y, "on": on}
		if mine and on == "":
			on = _name_of(hit.collider)
		var rid: RID = hit.rid
		ex.append(rid)
	return {"ground_y": -INF, "on": on}


## Whether a collider belongs to the zone being measured. The booted leg-1 zone
## is still in the tree the whole run (probe_common lesson 7) and every zone is
## built round the origin, so without this a ray in cottage country can stop on
## the strip mall's dumpster.
static func _mine(n: Node, zone: Node) -> bool:
	return n != null and zone.is_ancestor_of(n)


static func _is_ground(body: Node) -> bool:
	if body == null:
		return false
	for c in body.get_children():
		var cs := c as CollisionShape3D
		if cs == null or cs.shape == null:
			continue
		if cs.shape is ConcavePolygonShape3D or cs.shape is HeightMapShape3D or cs.shape is WorldBoundaryShape3D:
			return true
		var size: Vector3 = GEOM._extent_of(cs.shape) * cs.global_transform.basis.get_scale().abs()
		var area := size.x * size.z
		if (area >= GROUND_AREA and size.y <= GROUND_DEPTH) or area >= LANDMASS_AREA:
			return true
	return false


## Whether a player can SEE this body: some geometry in it or under it is drawn.
## Every zone rings itself with four invisible 80 m walls (the glidetest lesson in
## probe_common.gd), and a ray stopped by one of them says nothing about what a
## player sees. Approximate the other way too: a hidden graybox whose look is a
## separate mesh elsewhere reads as invisible here.
static func _drawn(body: Node) -> bool:
	var stack: Array[Node] = [body]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var g := n as GeometryInstance3D
		if g != null and g.is_visible_in_tree():
			return true
		for c in n.get_children():
			stack.append(c)
	return false


## A collider named for a person to read: a chaos prop by its label, a modelled
## solid by its model's kind, anything else as what it is.
static func _name_of(o: Object) -> String:
	var n := o as Node
	if n == null:
		return "?"
	var label: Variant = n.get("label")
	if label != null and str(label) != "":
		return str(label).to_lower()
	for c in n.get_children():
		if c.has_meta("kind"):
			return str(c.get_meta("kind")).replace("_", " ")
	var size := Vector3.ZERO
	for c2 in n.get_children():
		var cs := c2 as CollisionShape3D
		if cs != null and cs.shape != null:
			size = GEOM._extent_of(cs.shape)
			break
	if size != Vector3.ZERO:
		return "unmodelled %.1f x %.1f x %.1f m %s" % [size.x, size.y, size.z, n.get_class()]
	return n.get_class()
