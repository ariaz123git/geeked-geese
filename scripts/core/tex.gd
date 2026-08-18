extends Node
## Tex - autoload singleton for lazily loading & caching procedural textures.
##
## All textures live at res://textures/<name>.png (see tools/gen_textures.py).
## Register this script as an autoload named "Tex" in Project Settings.

const TEXTURE_DIR: String = "res://textures/"

# Cache of loaded Texture2D resources, keyed by StringName.
var _tex_cache: Dictionary = {}

# Cache of built StandardMaterial3D resources, keyed by a composite cache key
# (see _surface_cache_key), so repeated calls with identical args reuse one
# material instead of building duplicates.
var _material_cache: Dictionary = {}

# Tracks which missing keys we've already warned about, so we only
# push_warning once per key instead of spamming every frame.
var _warned_missing: Dictionary = {}

# substance_id -> icon file base name (without extension), for icon_for().
#
# EVERY SUBSTANCE MUST BE IN HERE. This table held twelve of sixteen for most of
# the project's life: acid, bars, gravy and percs had no icon at all, so
# icon_for() push_warning'd once and returned null, and four of the sixteen
# things the game is about showed up on the HUD as nothing. A missing icon is
# not an error in Godot — it is a null albedo and a silent shrug — which is
# exactly why tools/selftest.gd now asserts this table covers
# data/substances/ and that every file it names exists on disk.
const SUBSTANCE_ICONS: Dictionary = {
	&"acid": "icon_acid",
	&"bars": "icon_bars",
	&"gravy": "icon_gravy",
	&"percs": "icon_percs",
	&"berries": "icon_berries",
	&"double_double": "icon_double_double",
	&"nitrous": "icon_nitrous",
	&"math": "icon_math",
	&"grass": "icon_grass",
	&"special_k": "icon_special_k",
	&"robo": "icon_robo",
	&"molly": "icon_molly",
	&"darts": "icon_darts",
	&"catnip": "icon_catnip",
	&"toad_slime": "icon_toad_slime",
	&"fly_agaric": "icon_fly_agaric",
}


## Returns the cached Texture2D for `key`, loading it from disk on first use.
## Returns null (and warns once) if the file does not exist.
func get_tex(key: StringName) -> Texture2D:
	if _tex_cache.has(key):
		var cached: Texture2D = _tex_cache[key]
		return cached

	var path: String = TEXTURE_DIR + String(key) + ".png"
	if not ResourceLoader.exists(path):
		if not _warned_missing.has(key):
			_warned_missing[key] = true
			push_warning("Tex.get_tex: missing texture for key '%s' (expected %s)" % [key, path])
		_tex_cache[key] = null
		return null

	var loaded: Resource = ResourceLoader.load(path)
	var result: Texture2D = loaded as Texture2D
	_tex_cache[key] = result
	return result


## Maps a substance id (e.g. &"fly_agaric") to its HUD icon texture.
func icon_for(substance_id: StringName) -> Texture2D:
	if not SUBSTANCE_ICONS.has(substance_id):
		if not _warned_missing.has(substance_id):
			_warned_missing[substance_id] = true
			push_warning("Tex.icon_for: no icon mapped for substance '%s'" % substance_id)
		return null
	var icon_name: String = SUBSTANCE_ICONS[substance_id]
	return get_tex(StringName(icon_name))


func _surface_cache_key(prefix: String, key: StringName, uv_scale: float, rough: float, tint: Color) -> StringName:
	return StringName("%s:%s:%s:%s:%s" % [prefix, key, uv_scale, rough, tint.to_html(true)])


## Builds (and caches) a StandardMaterial3D using texture `key` as albedo.
func surface(key: StringName, uv_scale: float = 1.0, rough: float = 0.9, tint: Color = Color.WHITE) -> StandardMaterial3D:
	var cache_key: StringName = _surface_cache_key("surface", key, uv_scale, rough, tint)
	if _material_cache.has(cache_key):
		var cached_mat: StandardMaterial3D = _material_cache[cache_key]
		return cached_mat

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_texture = get_tex(key)
	mat.albedo_color = tint
	mat.uv1_scale = Vector3(uv_scale, uv_scale, uv_scale)
	mat.roughness = rough
	_material_cache[cache_key] = mat
	return mat


## Same as surface(), but with alpha transparency enabled (for chainlink, etc).
func surface_transparent(key: StringName, uv_scale: float = 1.0) -> StandardMaterial3D:
	var cache_key: StringName = _surface_cache_key("surface_transparent", key, uv_scale, 0.9, Color.WHITE)
	if _material_cache.has(cache_key):
		var cached_mat: StandardMaterial3D = _material_cache[cache_key]
		return cached_mat

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_texture = get_tex(key)
	mat.uv1_scale = Vector3(uv_scale, uv_scale, uv_scale)
	mat.roughness = 0.9
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material_cache[cache_key] = mat
	return mat


## Builds (and caches) the pond-water material: albedo + normal map, alpha blended.
func water_material() -> StandardMaterial3D:
	var cache_key: StringName = &"water_material"
	if _material_cache.has(cache_key):
		var cached_mat: StandardMaterial3D = _material_cache[cache_key]
		return cached_mat

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_texture = get_tex(&"water")
	mat.albedo_color = Color(1.0, 1.0, 1.0, 0.75)
	mat.normal_enabled = true
	mat.normal_texture = get_tex(&"water_normal")
	mat.roughness = 0.15
	mat.metallic = 0.3
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material_cache[cache_key] = mat
	return mat
