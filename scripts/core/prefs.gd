extends Node
## Autoload: Prefs
##
## Settings persistence. Everything the pause menu's SETTINGS panel touches
## lives here, plus the two bits of cross-run memory the rest of the UI
## needs: best_chaos (bragging rights) and unlocked (which Almanac entries
## have ever been seen, tracked by Unlocks but persisted through us).
##
## Writes are debounced through a short one-shot Timer so mashing a slider
## doesn't hammer the disk — call set_pref() as often as you like.

signal pref_changed(key: StringName, value)

const CONFIG_PATH := "user://geeked_geese.cfg"
const SECTION := "prefs"
const SAVE_DEBOUNCE := 0.4

const DEFAULTS := {
	## Which goose mesh to build. "lowpoly" is the faceted polygons-only
	## model; "classic" is the original smooth-primitive one.
	"goose_model": "lowpoly",
	## Briefing cards already shown, so first-run cards stay first-run.
	"seen_briefings": [],
	"mouse_sensitivity": 0.25,
	"invert_y": false,
	"fov": 68.0,
	"master_volume": 0.9,
	"sfx_volume": 0.9,
	"music_volume": 0.6,
	"screen_shake": 1.0,
	"fx_intensity": 1.0,
	"show_hints": true,
	"best_chaos": 0,
	"unlocked": [],
}

var _values: Dictionary = {}
var _save_timer: Timer = null
var _dirty := false

## TRUE FOR EVERY RUN LAUNCHED WITH ARGUMENTS AFTER `--`: every gate, every
## render probe. Such a run starts from DEFAULTS and never writes the disk.
##
## Until 2026-09-25 the gates shared one save file with the player. Measured on
## the machine this project is built on: `best_chaos=131201955`, a number no
## run a human plays can reach, so the pause menu's BEST CHAOS line was dead for
## the only person who reads it; all seventeen substances `unlocked`, because
## the `--ui` and `--finale` probes unlock entries to photograph them and the
## substance gate doses everything — so the Almanac, which is a DISCOVERY
## mechanic, was fully revealed before the player had found anything; and both
## first-run briefings marked seen, because `--probe` force-closes the card and
## closing it is what records it. A full `verify.ps1` rewrote the file on every
## run, and `audiotest` round-trips each volume slider through 0.25 and 1.00, so
## a harness that died in the middle left the player's volume wherever it
## stopped. It also ran the other way: every gate READ the player's settings,
## so what they measured depended on how the person who owns the machine had
## last configured the game.
##
## Keyed on "any user argument", not on a list of flags, so a harness added
## tomorrow is hermetic without anyone remembering to add it anywhere. A player
## launching the game has no arguments after `--`. `verify.ps1` hashes the real
## save before and after the gates and fails if they touched it.
var hermetic := false


func _ready() -> void:
	# Settings must be adjustable (and savable) while the game is paused —
	# that's literally when the pause menu's SETTINGS panel is open.
	process_mode = Node.PROCESS_MODE_ALWAYS
	hermetic = not OS.get_cmdline_user_args().is_empty()
	load_prefs()


func load_prefs() -> void:
	_values = DEFAULTS.duplicate(true)
	if not hermetic:
		var cf := ConfigFile.new()
		var err := cf.load(CONFIG_PATH)
		if err == OK:
			for key in DEFAULTS.keys():
				if cf.has_section_key(SECTION, key):
					_values[key] = cf.get_value(SECTION, key)
	_apply_audio()


func save_prefs() -> void:
	if hermetic:
		_dirty = false
		return
	var cf := ConfigFile.new()
	for key in _values.keys():
		cf.set_value(SECTION, key, _values[key])
	cf.save(CONFIG_PATH)
	_dirty = false


func get_pref(key: StringName, fallback = null):
	if _values.has(key):
		return _values[key]
	if DEFAULTS.has(key):
		return DEFAULTS[key]
	return fallback


func set_pref(key: StringName, value) -> void:
	_values[key] = value
	pref_changed.emit(key, value)
	if key == &"master_volume" or key == &"sfx_volume" or key == &"music_volume":
		_apply_audio()
	_queue_save()


func _queue_save() -> void:
	_dirty = true
	if _save_timer == null:
		_save_timer = Timer.new()
		_save_timer.one_shot = true
		_save_timer.wait_time = SAVE_DEBOUNCE
		_save_timer.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(_save_timer)
		_save_timer.timeout.connect(_on_save_timeout)
	_save_timer.start()


func _on_save_timeout() -> void:
	if _dirty:
		save_prefs()


## FLUSH ON THE WAY OUT, OR THE LAST CHANGE IS THE ONE THAT IS LOST.
##
## Writes are debounced through a one-shot `SAVE_DEBOUNCE` timer so that
## dragging a slider does not rewrite the file every frame. That is right,
## and it has a tail: **any setting changed within SAVE_DEBOUNCE of quitting
## never reached disk.** Turn the music down and close the game — which is
## exactly the order a person does those two things in — and the game comes
## back loud.
##
## `_exit_tree()` runs on a clean shutdown, including `get_tree().quit()` and
## the window close button. It cannot help with a crash, and nothing can:
## the alternative is writing on every keystroke, which is the thrash the
## debounce exists to prevent.
func _exit_tree() -> void:
	if _dirty:
		save_prefs()


## Master always lives on bus 0. SFX/Music buses may not exist yet in every
## project build, so those are looked up by name and skipped if missing —
## this can never crash a build that hasn't wired its audio buses up yet.
## Re-apply the saved volumes to the audio buses.
##
## `Sfx` and `Music` call this once they have created their buses. `Prefs` is
## autoload #1 and applies at its own `_ready()`, which is BEFORE either of
## those buses exists — `get_bus_index()` returns -1 there and the branch is
## skipped in silence, so without this the value the player saved reaches
## nothing until they next move the slider themselves.
func apply_audio() -> void:
	_apply_audio()


func _apply_audio() -> void:
	if AudioServer.get_bus_count() <= 0:
		return
	var master_v: float = get_pref(&"master_volume", 0.9)
	AudioServer.set_bus_volume_db(0, linear_to_db(clampf(master_v, 0.0001, 1.0)))

	var sfx_idx := AudioServer.get_bus_index("SFX")
	if sfx_idx >= 0:
		var sfx_v: float = get_pref(&"sfx_volume", 0.9)
		AudioServer.set_bus_volume_db(sfx_idx, linear_to_db(clampf(sfx_v, 0.0001, 1.0)))

	var music_idx := AudioServer.get_bus_index("Music")
	if music_idx >= 0:
		var music_v: float = get_pref(&"music_volume", 0.6)
		AudioServer.set_bus_volume_db(music_idx, linear_to_db(clampf(music_v, 0.0001, 1.0)))
