extends Node
## Autoload: Unlocks
##
## Tracks which Almanac (Bird Brain codex) entries have ever been discovered.
## Discovery = you've actually eaten the thing at least once. Persists through
## Prefs so it survives between runs. Deliberately dumb: it only listens and
## remembers, the Almanac UI does all the rendering.

signal newly_unlocked(res)  # untyped: `res` is a Substance in the real project

var _subs = null   # Node, /root/Subs
var _prefs = null  # Node, /root/Prefs

var _unlocked: Dictionary = {}  # StringName -> true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_prefs = get_node_or_null("/root/Prefs")
	_load_from_prefs()

	_subs = get_node_or_null("/root/Subs")
	if _subs == null:
		# Subs isn't registered (yet, or in a scratch/test project). Bail
		# gracefully — is_unlocked()/unlock() still work, we just never
		# hear about new substances automatically.
		return
	_subs.substance_taken.connect(_on_substance_taken)


func _load_from_prefs() -> void:
	_unlocked.clear()
	if _prefs == null:
		return
	var arr: Array = _prefs.get_pref(&"unlocked", [])
	for item in arr:
		_unlocked[StringName(item)] = true


func _on_substance_taken(res, _dose: float, _resolved: Dictionary) -> void:
	if res == null:
		return
	unlock(res.id)


func is_unlocked(id: StringName) -> bool:
	return _unlocked.has(id)


func unlock(id: StringName) -> void:
	if _unlocked.has(id):
		return
	_unlocked[id] = true
	_save()

	var res = null
	if _subs != null and _subs.library.has(id):
		res = _subs.library[id]
	newly_unlocked.emit(res)


func _save() -> void:
	if _prefs == null:
		return
	var arr: Array = []
	for key in _unlocked.keys():
		arr.append(String(key))
	_prefs.set_pref(&"unlocked", arr)


func unlocked_count() -> int:
	return _unlocked.size()


## Every discovered id, in the library's own order rather than in the order the
## player found them — `Subs._load_library()` scans `data/substances/`, so that
## is alphabetical by filename, and a list of substances that reads
## alphabetically reads like a glossary instead of like a diary. Falls back to
## the internal insertion order if Subs is not registered.
##
## **Discovery is cross-run and permanent** (it round-trips through Prefs, and
## `Game.new_run()` deliberately does not clear it). This is therefore the
## contents of the Almanac, NOT this run's intake, and there is no per-run set
## anywhere in the project to ask instead. Anything that prints this list must
## be worded so it is still true on a second playthrough — see
## `zone_finale.gd::_almanac_section()`, which says what the things *were* and
## never claims this run is where you learned it.
func unlocked_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	if _subs != null:
		for key in _subs.library.keys():
			# `keys()` hands back Variants, so this needs the explicit
			# conversion — see CLAUDE.md. Same idiom as _load_from_prefs().
			var id := StringName(str(key))
			if _unlocked.has(id):
				out.append(id)
		return out
	for key2 in _unlocked.keys():
		out.append(StringName(str(key2)))
	return out


func total_count() -> int:
	if _subs == null:
		return 0
	return int(_subs.library.size())
