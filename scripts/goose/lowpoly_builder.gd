extends RefCounted
class_name LowPolyBuilder
## Faceted low-poly mesh construction. Polygons only — no SphereMesh, no
## CylinderMesh, no curved primitives anywhere.
##
## HOW THE FLAT SHADING WORKS
## Every triangle gets its own three vertices with one shared face normal. No
## vertex is ever reused between faces, so there is nothing for the renderer to
## smooth across and you get hard facets for free. That's also why the vertex
## count looks high relative to the silhouette — it's the cost of the look, and
## it's the correct trade.
##
## HOW COLOUR WORKS
## All colour lives in VERTEX COLOURS, and the material is white with
## `vertex_color_use_as_albedo = true`. Two payoffs:
##   1. The whole bird is one draw call and one material.
##   2. Markings like the chinstrap can be painted per-face by a callback that
##      looks at where the face actually sits, instead of needing separate
##      geometry glued onto the head.
## Substance tinting then just multiplies the material's albedo_color, exactly
## like the classic model.
##
## HOW WINDING IS HANDLED
## It isn't, by you. Every face-emitting call takes an `inside` reference point
## — normally the spine position the face wraps around — and flips its own
## winding if the computed normal points inward. So you can author rings in
## whichever direction is convenient and never think about backface culling.

## Deterministic per-face brightness variation. This is most of what separates
## a low-poly model that looks intentional from one that looks like flat shading
## on a cylinder. Keep it subtle — beyond ~0.06 it reads as noise.
const DEFAULT_JITTER := 0.045

var _st: SurfaceTool
var _face_index := 0
var _jitter := DEFAULT_JITTER
var tri_count := 0


func _init(jitter := DEFAULT_JITTER) -> void:
	_jitter = jitter
	_st = SurfaceTool.new()
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)


# ---------------------------------------------------------------- primitives

## Deterministic hash so the same model always shades identically. The build
## verification renders and compares frames, so randf() here would be a bug.
func _shade(i: int) -> float:
	var h := float((i * 2654435761) % 1024) / 1024.0
	return 1.0 - _jitter + h * (_jitter * 2.0)


func _emit(a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return   # degenerate: a collapsed ring segment, silently drop it
	n = n.normalized()
	var s := _shade(_face_index)
	_face_index += 1
	var cc := Color(col.r * s, col.g * s, col.b * s, col.a)
	# WINDING — the subtle one. Every call above reasons in right-hand-rule
	# terms: `n` is the outward normal of the triangle a->b->c. But Godot's
	# front faces are CLOCKWISE when viewed from the front, which is the
	# opposite handedness. Emitting a,b,c directly produces a mesh that is
	# geometrically correct, shades plausibly, and is entirely BACK-FACING —
	# invisible on any open surface and silently lit from the wrong side on
	# closed ones. So the vertices go out reversed while the normal stays as
	# computed. Do not "simplify" this loop.
	for v in [a, c, b]:
		_st.set_normal(n)
		_st.set_color(cc)
		_st.set_uv(Vector2(v.x * 0.5 + 0.5, v.z * 0.5 + 0.5))
		_st.add_vertex(v)
	tri_count += 1


## Triangle with outward-facing winding relative to `inside`.
func tri(a: Vector3, b: Vector3, c: Vector3, col: Color, inside: Vector3) -> void:
	var n := (b - a).cross(c - a)
	var centre := (a + b + c) / 3.0
	if n.dot(centre - inside) < 0.0:
		_emit(a, c, b, col)
	else:
		_emit(a, b, c, col)


## Quad with outward-facing winding relative to `inside`. Split into two tris;
## on a non-planar quad that split is visible as a crease, which is fine and
## often desirable here.
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, inside: Vector3) -> void:
	var n := (b - a).cross(c - a)
	var centre := (a + b + c + d) * 0.25
	if n.dot(centre - inside) < 0.0:
		_emit(a, d, c, col)
		_emit(a, c, b, col)
	else:
		_emit(a, b, c, col)
		_emit(a, c, d, col)


# ---------------------------------------------------------------- rings

## A closed polygon cross-section, oriented by a forward and up vector.
## `sides` is the facet count: 5-8 for organic low-poly, 4 for limbs and bills.
## `phase` rotates the ring so facet edges can be aligned between sections —
## a mismatched phase between two lofted rings produces visible twisting.
static func ring(centre: Vector3, fwd: Vector3, up: Vector3, rx: float, ry: float,
		sides: int, phase := 0.0) -> PackedVector3Array:
	var f := fwd.normalized()
	if f.length_squared() < 1e-9:
		f = Vector3.FORWARD
	var r := up.cross(f)
	if r.length_squared() < 1e-9:
		r = Vector3.RIGHT
	r = r.normalized()
	var u := f.cross(r).normalized()

	var out := PackedVector3Array()
	for i in sides:
		var a := TAU * (float(i) / float(sides)) + phase
		out.append(centre + r * (cos(a) * rx) + u * (sin(a) * ry))
	return out


## Squash a ring toward a plane. Used for flattening a bill or a foot without
## having to author a second ring by hand.
static func flatten(r: PackedVector3Array, centre: Vector3, axis: Vector3, amount: float) -> PackedVector3Array:
	var n := axis.normalized()
	var out := PackedVector3Array()
	for v in r:
		var d := (v - centre).dot(n)
		out.append(v - n * d * amount)
	return out


# ---------------------------------------------------------------- lofting

## Connect a chain of rings into a faceted tube.
## `col` may be a Color (uniform) or a Callable taking the face centroid
## (Vector3) and returning a Color — that's how the chinstrap gets painted
## without any extra geometry.
func loft(rings: Array, spine: Array, col) -> void:
	for i in range(rings.size() - 1):
		var r0: PackedVector3Array = rings[i]
		var r1: PackedVector3Array = rings[i + 1]
		var n: int = mini(r0.size(), r1.size())
		var inside: Vector3 = (spine[i] + spine[i + 1]) * 0.5
		for j in n:
			var k := (j + 1) % n
			var a := r0[j]
			var b := r0[k]
			var c := r1[k]
			var d := r1[j]
			quad(a, b, c, d, _resolve(col, (a + b + c + d) * 0.25), inside)


## Close off a ring with a triangle fan to an apex point.
func cap(r: PackedVector3Array, apex: Vector3, inside: Vector3, col) -> void:
	var n := r.size()
	for j in n:
		var a := r[j]
		var b := r[(j + 1) % n]
		tri(a, b, apex, _resolve(col, (a + b + apex) / 3.0), inside)


## Close off a ring flat, fanning from its own centroid.
func cap_flat(r: PackedVector3Array, inside: Vector3, col) -> void:
	var centre := Vector3.ZERO
	for v in r:
		centre += v
	centre /= float(r.size())
	cap(r, centre, inside, col)


func _resolve(col, centroid: Vector3) -> Color:
	if col is Callable:
		return col.call(centroid)
	return col


# ---------------------------------------------------------------- plates

## A flat faceted plate from an outline, given thickness and a lengthwise
## crease so it catches light like a wing rather than reading as cardboard.
## `outline` is a closed polygon in the XZ plane (y ignored).
## `crease` lifts the interior of the plate along +Y, proportional to how far
## each point is from the outline's long axis.
func plate(outline: PackedVector3Array, thickness: float, crease: float, col) -> void:
	var n := outline.size()
	if n < 3:
		return
	var centre := Vector3.ZERO
	for v in outline:
		centre += v
	centre /= float(n)

	# Top and bottom shells, both bowed away from the mid-plane.
	var top := PackedVector3Array()
	var bot := PackedVector3Array()
	for v in outline:
		var t := 1.0 - clampf(v.distance_to(centre) / maxf(_max_radius(outline, centre), 0.001), 0.0, 1.0)
		var lift := crease * t
		top.append(Vector3(v.x, v.y + thickness * 0.5 + lift, v.z))
		bot.append(Vector3(v.x, v.y - thickness * 0.5 - lift * 0.35, v.z))

	var top_apex := Vector3(centre.x, centre.y + thickness * 0.5 + crease, centre.z)
	var bot_apex := Vector3(centre.x, centre.y - thickness * 0.5 - crease * 0.35, centre.z)
	cap(top, top_apex, centre, col)
	cap(bot, bot_apex, centre, col)

	# Rim.
	for j in n:
		var k := (j + 1) % n
		quad(top[j], top[k], bot[k], bot[j], _resolve(col, (top[j] + bot[k]) * 0.5), centre)


func _max_radius(outline: PackedVector3Array, centre: Vector3) -> float:
	var m := 0.0
	for v in outline:
		m = maxf(m, v.distance_to(centre))
	return m


## A faceted wedge: a polygon that tapers to a ridge line. Good for tails.
func wedge(base: PackedVector3Array, tip_a: Vector3, tip_b: Vector3, inside: Vector3, col) -> void:
	var n := base.size()
	for j in n:
		var a := base[j]
		var b := base[(j + 1) % n]
		var t: Vector3 = tip_a if float(j) < float(n) * 0.5 else tip_b
		tri(a, b, t, _resolve(col, (a + b + t) / 3.0), inside)
	tri(tip_a, tip_b, base[0], _resolve(col, (tip_a + tip_b) * 0.5), inside)


## A convex box from 8 corners, for limbs and blocky detail.
func box(centre: Vector3, half: Vector3, col, basis := Basis.IDENTITY) -> void:
	var c := []
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				c.append(centre + basis * Vector3(half.x * sx, half.y * sy, half.z * sz))
	# indices into c: bit0=z, bit1=y, bit2=x
	var f := [
		[0, 1, 3, 2],   # -x
		[4, 6, 7, 5],   # +x
		[0, 4, 5, 1],   # -y
		[2, 3, 7, 6],   # +y
		[0, 2, 6, 4],   # -z
		[1, 5, 7, 3],   # +z
	]
	for face in f:
		quad(c[face[0]], c[face[1]], c[face[2]], c[face[3]],
			_resolve(col, (c[face[0]] + c[face[2]]) * 0.5), centre)


# ---------------------------------------------------------------- output

func commit() -> ArrayMesh:
	return _st.commit()


## One material for every low-poly part: white albedo modulated by the vertex
## colours the builder baked in. Tinting a whole creature is then a single
## albedo_color write.
static func make_material(rough := 0.92) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.WHITE
	m.vertex_color_use_as_albedo = true
	m.roughness = rough
	m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	# Facets are the point. Nothing here should ever be smooth-shaded.
	m.cull_mode = BaseMaterial3D.CULL_BACK
	return m


## Convenience: build a mesh into a fresh MeshInstance3D under `parent`.
static func attach(parent: Node3D, mesh: ArrayMesh, mat: StandardMaterial3D,
		name_hint := "Part") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name_hint
	mi.mesh = mesh
	mi.material_override = mat
	parent.add_child(mi)
	return mi
