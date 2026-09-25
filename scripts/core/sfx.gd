extends Node
## Sfx -- autoload singleton for "Geeked Geese".
##
## Lazily loads WAVs from res://audio/<name>.wav, plays non-positional UI/SFX
## through a small round-robin pool of AudioStreamPlayer nodes, plays
## positional one-shots via temporary AudioStreamPlayer3D nodes, and manages
## a handful of named persistent looping players (wind, swim, ambience,
## charge, ...).
##
## Autoload this script as `Sfx` in Project Settings > Autoload.

const AUDIO_DIR := "res://audio/"
const POOL_SIZE := 16

## The bus every sound effect plays on.
##
## IT DID NOT EXIST, AND THE SFX VOLUME SLIDER DID NOTHING FOR THE LIFE OF THE
## PROJECT. `pause_menu.gd` offers the control and `prefs.gd::_apply_audio()`
## writes it to a bus of this name — but nothing ever created one, and all 17
## players here were routed straight to "Master". `get_bus_index()` returns -1
## for a missing bus without raising anything, so the whole branch was skipped
## in silence and the slider moved a number nobody could hear.
##
## Built in code rather than shipped as a bus layout for the reason
## `music.gd::_setup_buses()` gives: a `.tres` layout is a file nobody diffs
## and it silently loses every bus if it fails to load.
const SFX_BUS := "SFX"

var _cache: Dictionary = {}          # StringName -> AudioStream
var _pool: Array = []                # Array[AudioStreamPlayer]
var _pool_started_at: Array = []     # Array[int] (Time.get_ticks_msec() per pool slot)
var _next_pool_index: int = 0

var _loops: Dictionary = {}          # StringName (bus_key) -> AudioStreamPlayer
var _loop_keys: Dictionary = {}      # StringName (bus_key) -> StringName (sound key currently playing)
var _loop_tweens: Dictionary = {}    # StringName (bus_key) -> Tween (volume ramp, may be dead)

var _amb_zone: StringName = &""      # the zone id whose bed is currently up


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_sfx_bus()
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.name = "SfxPoolPlayer%d" % i
		p.bus = SFX_BUS
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_pool.append(p)
		_pool_started_at.append(0)


## STOP EVERYTHING, THEN GIVE THE AUDIO THREAD A MOMENT. docs/RECENT_FAILURES
## F-001, closed 2026-09-25: the engine's exit report listed 17 AudioStreamWAVs
## and 17 AudioStreamPlaybackWAVs "still in use" — Music's sixteen stems and this
## node's parking-lot bed — each held once, by a playback. `stop()` does not
## drop a playback; it marks it for deletion, and the MIXER THREAD retires it a
## few mix steps later. At quit there were no later mix steps before the report,
## so every playing stream leaked. Stopping here alone had been tried and measured
## to change nothing, which is exactly what that predicts. Stopping and then
## pausing 60 ms for the mixer took `--gate` from 17 to 0 and cleared nine of ten
## gates; the tenth leaked one sound once in eight runs, a sound started in the
## last frames. 100 ms here bought the margin — 0 leaks in 20 runs of all ten
## gates — and it covers Music's stems too: a node's children leave the tree
## last-first, so Sfx (autoload 3) exits after Music (autoload 10). `music.gd`
## stops and waits for its own stems as well. This is guarded, not trusted:
## `verify.ps1`'s ScriptErrors fails any gate whose exit reports resources still
## in use, and setting both waits to 0 fails the run (canaried 2026-09-25).
const EXIT_MIX_WAIT_MS := 100

func _exit_tree() -> void:
	for p in _pool:
		var pp := p as AudioStreamPlayer
		if pp != null and is_instance_valid(pp):
			pp.stop()
	for k in _loops.keys():
		var lp := _loops[k] as AudioStreamPlayer
		if lp != null and is_instance_valid(lp):
			lp.stop()
	OS.delay_msec(EXIT_MIX_WAIT_MS)


## Create the SFX bus if it is not there, and make `Prefs` re-apply the saved
## volume to it. The re-apply is not optional: `Prefs` is autoload #1 and has
## already run `_apply_audio()` against a world with no SFX bus in it by the
## time this runs at #3.
func _ensure_sfx_bus() -> void:
	if AudioServer.get_bus_index(SFX_BUS) < 0:
		var idx := AudioServer.get_bus_count()
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, SFX_BUS)
		AudioServer.set_bus_send(idx, "Master")
		AudioServer.set_bus_volume_db(idx, 0.0)
	var prefs := get_node_or_null("/root/Prefs")
	if prefs != null and prefs.has_method("apply_audio"):
		prefs.call("apply_audio")


## Returns true if a wav resource exists on disk for `key`.
func exists(key: StringName) -> bool:
	var path := AUDIO_DIR + String(key) + ".wav"
	return ResourceLoader.exists(path)


func _get_stream(key: StringName) -> AudioStream:
	if _cache.has(key):
		var cached: AudioStream = _cache[key]
		return cached
	var path := AUDIO_DIR + String(key) + ".wav"
	if not ResourceLoader.exists(path):
		push_warning("Sfx: missing audio file for key '%s' (%s)" % [String(key), path])
		return null
	var stream: Resource = load(path)
	if stream == null:
		push_warning("Sfx: failed to load '%s'" % path)
		return null
	if not (stream is AudioStream):
		push_warning("Sfx: resource at '%s' is not an AudioStream" % path)
		return null
	_configure_loop_if_needed(key, stream)
	_cache[key] = stream
	return stream


## Force forward-looping on any stream whose KEY names it as a loop, so a wav's
## import settings don't have to be right for the sound to work.
##
## TWO FAMILIES COUNT, and the second one is why this comment is long.
## Anything ending in `_loop` (swim_loop, wind_loop, dose_charge_loop, and every
## ambience bed), and anything beginning with `amb_` — because
## `amb_parking_lot` predates the suffix convention, did not match the old gate,
## and was therefore NEVER LOOPED: it played its six seconds once per zone load
## and left the remaining ~174 seconds of the leg in silence.
##
## `loop_end` is measured in FRAMES, and the frame count is NOT derivable from
## `data.size()` for every format. Godot's default wav import is QOA
## (`compress/mode=2`), where `data` holds compressed bytes. Measured in a
## booted 4.7.1 project:
##
##   swim_loop.wav        fmt=3 (QOA)  len=2.0000s  data=35720  ->  data/2 = 17860 frames
##                                                  true frame count = 88200
##
## So the old `data.size() / bytes_per_frame` set `loop_end` to a FIFTH of the
## file, and swim / wind / charge have been looping their first fraction of a
## second. `get_length()` decodes the QOA header and is correct for every
## format, so the frame count comes from there instead. For a PCM stream the two
## agree exactly (verified: mus_mall_base data/2 = 1008000 = get_length()*rate),
## which is what makes this strictly a fix and not a change.
##
## `loop_end` is only recomputed when the importer left it unset. The ambience
## beds ship a PCM `.import` with `edit/loop_mode=2` and arrive already looping
## with a correct `loop_end`; there is no reason to second-guess it. See
## `tools/gen_audio.py::write_import`.
func _configure_loop_if_needed(key: StringName, stream: AudioStream) -> void:
	# Not `name` -- that shadows Node.name.
	var key_s := String(key)
	if not (key_s.ends_with("_loop") or key_s.begins_with("amb_")):
		return
	if not (stream is AudioStreamWAV):
		return
	var wav: AudioStreamWAV = stream
	var frames: int = int(round(wav.get_length() * float(wav.mix_rate)))
	if frames <= 0:
		return
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	if wav.loop_end <= wav.loop_begin:
		wav.loop_begin = 0
		wav.loop_end = frames


## --- Pool management for non-positional one-shots -------------------------

func _acquire_pool_player() -> AudioStreamPlayer:
	# First pass: round-robin starting at _next_pool_index, take the first
	# player that isn't currently playing.
	for i in range(_pool.size()):
		var idx: int = (_next_pool_index + i) % _pool.size()
		var p: AudioStreamPlayer = _pool[idx]
		if not p.playing:
			_next_pool_index = (idx + 1) % _pool.size()
			return p
	# All busy: steal the oldest (smallest start timestamp).
	var oldest_idx: int = 0
	var oldest_time: int = _pool_started_at[0]
	for i in range(1, _pool_started_at.size()):
		var started: int = _pool_started_at[i]
		if started < oldest_time:
			oldest_time = started
			oldest_idx = i
	_next_pool_index = (oldest_idx + 1) % _pool.size()
	return _pool[oldest_idx]


## Non-positional one-shot playback.
func play(key: StringName, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var stream: AudioStream = _get_stream(key)
	if stream == null:
		return
	var p: AudioStreamPlayer = _acquire_pool_player()
	var slot_idx: int = _pool.find(p)
	if slot_idx >= 0:
		_pool_started_at[slot_idx] = Time.get_ticks_msec()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


## Picks a random key from `keys` and plays it with a small random pitch
## variation. Use for footsteps / flaps / honks so repeats don't sound
## identical.
func play_var(keys: Array, volume_db: float = 0.0, pitch_jitter: float = 0.06) -> void:
	if keys.is_empty():
		return
	var idx: int = randi() % keys.size()
	var key: StringName = keys[idx]
	var jitter: float = randf_range(-pitch_jitter, pitch_jitter)
	play(key, volume_db, 1.0 + jitter)


## Positional one-shot: spawns a temporary AudioStreamPlayer3D as a child of
## `parent`, plays, and frees itself when finished. Safe to call with a null
## or freed/out-of-tree parent (it's a no-op).
func play_at(key: StringName, parent: Node3D, volume_db: float = 0.0,
		pitch: float = 1.0, unit_size: float = 14.0) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	if not parent.is_inside_tree():
		return
	var stream: AudioStream = _get_stream(key)
	if stream == null:
		return
	var p3d := AudioStreamPlayer3D.new()
	p3d.stream = stream
	p3d.volume_db = volume_db
	p3d.pitch_scale = pitch
	p3d.unit_size = unit_size
	p3d.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(p3d)
	p3d.finished.connect(_on_positional_finished.bind(p3d))
	p3d.play()


func _on_positional_finished(p3d: AudioStreamPlayer3D) -> void:
	if is_instance_valid(p3d):
		p3d.queue_free()


## --- Persistent named loops ------------------------------------------------

## Starts `key` looping on the named bus (e.g. &"wind", &"swim", &"ambience",
## &"charge"). If that bus is already playing the same key, this is a no-op
## so callers can call `loop()` freely every frame without restarting.
func loop(key: StringName, bus_key: StringName, volume_db: float = -6.0) -> void:
	if _loop_keys.has(bus_key) and _loop_keys[bus_key] == key:
		var existing: AudioStreamPlayer = _loops[bus_key]
		if existing != null and is_instance_valid(existing) and existing.playing:
			return
	var stream: AudioStream = _get_stream(key)
	if stream == null:
		return
	var p: AudioStreamPlayer
	if _loops.has(bus_key):
		p = _loops[bus_key]
	else:
		p = AudioStreamPlayer.new()
		p.name = "SfxLoop_%s" % String(bus_key)
		p.bus = SFX_BUS
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_loops[bus_key] = p
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = 1.0
	p.play()
	_loop_keys[bus_key] = key


## Stops and clears whatever is looping on `bus_key`, if anything.
func stop_loop(bus_key: StringName) -> void:
	_kill_loop_tween(bus_key)
	if bus_key == AMBIENCE_BUS:
		_amb_zone = &""
	if not _loops.has(bus_key):
		return
	var p: AudioStreamPlayer = _loops[bus_key]
	if p != null and is_instance_valid(p):
		p.stop()
	_loop_keys.erase(bus_key)


## Adjusts the volume of a currently-managed loop bus (fade it in/out from
## calling code). No-op if that bus has nothing set up yet.
func set_loop_volume(bus_key: StringName, volume_db: float) -> void:
	if not _loops.has(bus_key):
		return
	var p: AudioStreamPlayer = _loops[bus_key]
	if p != null and is_instance_valid(p):
		p.volume_db = volume_db


## Adjusts the pitch of a currently-managed loop bus (bend it as tension/
## speed changes). No-op if that bus has nothing set up yet.
func set_loop_pitch(bus_key: StringName, pitch: float) -> void:
	if not _loops.has(bus_key):
		return
	var p: AudioStreamPlayer = _loops[bus_key]
	if p != null and is_instance_valid(p):
		p.pitch_scale = pitch


## Ramps a loop bus to `to_db` over `seconds`. `loop()` starts at full level and
## `stop_loop()` is a hard stop, which is fine for a splash and audible as a
## click on a twelve-second bed, so ambience uses this instead.
##
## Any ramp already running on that bus is killed first. That is the whole
## lifetime story: a fade left running while the bus swapped to a different
## sound would spend the next second writing the OLD fade's volumes onto the
## NEW bed.
func fade_loop(bus_key: StringName, to_db: float, seconds: float = 0.8) -> void:
	_kill_loop_tween(bus_key)
	if not _loops.has(bus_key):
		return
	var p: AudioStreamPlayer = _loops[bus_key]
	if p == null or not is_instance_valid(p):
		return
	if seconds <= 0.0:
		p.volume_db = to_db
		return
	var tw := create_tween()
	tw.tween_property(p, "volume_db", to_db, seconds)
	_loop_tweens[bus_key] = tw


func _kill_loop_tween(bus_key: StringName) -> void:
	if not _loop_tweens.has(bus_key):
		return
	var tw: Tween = _loop_tweens[bus_key]
	if tw != null and is_instance_valid(tw):
		tw.kill()
	_loop_tweens.erase(bus_key)


## --- Zone ambience ---------------------------------------------------------
##
## Every leg used to run `amb_parking_lot`, hardcoded in `main.gd::_load_zone()`,
## so a cottage lake at night, a dawn marsh and a truck stop in the rain all
## sounded like a strip mall.
##
## THE BED IS CHOSEN BY ZONE ID, NEVER BY LEG NUMBER. Leg numbers move — leg 8
## was deleted last session and leg 5 is scheduled to become its own zone — and
## a lookup keyed by one silently repoints every bed when the route changes.
## Zone ids do not move: `zone.mission_zone_id()` is the same contract the
## mission system and the score already key off, so a zone that knows what it is
## gets the right bed for free, including a zone that does not exist yet.
##
## Two zone ids share the parking-lot bed on purpose. Legs 1 and 2 are both
## `strip_mall` — the retention pond behind the plaza and the plaza itself —
## and a sodium-lit lot is the right sound for both.

const AMBIENCE_BUS := &"ambience"
const AMBIENCE_FADE_IN := 1.1        ## seconds, so a zone load does not thump
const AMBIENCE_FALLBACK := &"amb_parking_lot"

## Zone id -> the wav that plays there. Every bed except the parking lot is
## generated by `tools/gen_audio.py::gen_amb_beds()`; the seam guarantees and
## the reason each one contains what it contains are documented there.
##
## An id that is not in here gets AMBIENCE_FALLBACK rather than silence. That is
## the opposite of `Music.set_zone()`, which goes quiet on an unknown id, and the
## difference is deliberate: a wrong bed is a texture you might not notice, a
## missing bed is a zone with no air in it at all. `Music`'s rule made two legs
## ship silent; this one cannot.
const AMBIENCE_BEDS := {
	&"strip_mall": &"amb_parking_lot",
	&"suburbia": &"amb_suburbia_loop",
	&"cottage": &"amb_lake_night_loop",
	&"stopover": &"amb_marsh_dawn_loop",
	&"corn": &"amb_corn_loop",
	&"truckstop": &"amb_truckstop_loop",
	&"green": &"amb_green_loop",
	&"generic": &"amb_parking_lot",
}

## Per-zone resting level. Not one number, because the beds do different jobs:
## the truck stop's rain and the marsh's geese ARE the zone and sit forward,
## while the strip mall is meant to be wallpaper. The truck stop also has the
## lowest music floor in the game (`music.gd::ZONE_FLOOR` = 0.16) specifically
## so that at rest you hear the weather.
const AMBIENCE_DB := {
	&"strip_mall": -20.0,
	&"suburbia": -19.0,
	&"cottage": -18.0,
	&"stopover": -17.0,
	&"corn": -18.5,
	&"truckstop": -16.0,
	&"green": -19.0,
	&"generic": -20.0,
}

## Whatever a zone, a doc or a future author feels like calling a place. Mirrors
## `music.gd::ZONE_ALIASES` so the two systems cannot disagree about what a place
## is called — including `pond`, which `music.gd` does not have and which would
## go musically silent today.
const AMBIENCE_ALIASES := {
	&"mall": &"strip_mall", &"parking_lot": &"strip_mall", &"stripmall": &"strip_mall",
	&"pond": &"strip_mall", &"retention_pond": &"strip_mall",
	&"burb": &"suburbia", &"suburb": &"suburbia", &"suburbs": &"suburbia",
	&"lake": &"cottage", &"cottage_night": &"cottage", &"cottage_lake": &"cottage",
	&"refuge": &"stopover", &"marsh": &"stopover", &"the_stopover": &"stopover",
	&"corn_field": &"corn", &"cornfield": &"corn", &"cut_corn": &"corn",
	&"truck_stop": &"truckstop", &"truckstop_night": &"truckstop",
	&"finale": &"green", &"eighteenth_green": &"green", &"ending": &"green",
	&"epilogue": &"green", &"18th_green": &"green",
}


## Resolve a spelling to a canonical zone id.
func ambience_zone_id(zone_id: StringName) -> StringName:
	if AMBIENCE_ALIASES.has(zone_id):
		var alias: StringName = AMBIENCE_ALIASES[zone_id]
		return alias
	return zone_id


## Which wav `zone_id` would play. Falls back to the parking lot for anything
## unknown, and again if the chosen bed is not on disk — a bed that has not been
## generated yet must not be able to take a zone's air away.
func ambience_bed_for(zone_id: StringName) -> StringName:
	var z: StringName = ambience_zone_id(zone_id)
	var bed: StringName = AMBIENCE_BEDS.get(z, AMBIENCE_FALLBACK)
	if not exists(bed):
		push_warning("Sfx: no ambience bed '%s' for zone '%s', using '%s'"
				% [String(bed), String(zone_id), String(AMBIENCE_FALLBACK)])
		return AMBIENCE_FALLBACK
	return bed


## The canonical zone id whose bed is currently playing, or &"" for none.
func ambience_zone() -> StringName:
	return _amb_zone


## THE one call a zone load makes. Starts (or keeps) the bed for `zone_id` on the
## ambience bus and fades it in.
##
## Idempotent: calling it again with the same zone leaves the running bed alone
## rather than restarting it, so legs 1 and 2 — both `strip_mall` — do not
## re-trigger the lot between them.
func set_ambience(zone_id: StringName, volume_offset_db: float = 0.0) -> void:
	var z: StringName = ambience_zone_id(zone_id)
	var bed: StringName = ambience_bed_for(z)
	var target: float = float(AMBIENCE_DB.get(z, -20.0)) + volume_offset_db

	var already: bool = _amb_zone == z and _loop_keys.get(AMBIENCE_BUS, &"") == bed
	if already and _loops.has(AMBIENCE_BUS):
		var running: AudioStreamPlayer = _loops[AMBIENCE_BUS]
		if running != null and is_instance_valid(running) and running.playing:
			fade_loop(AMBIENCE_BUS, target, AMBIENCE_FADE_IN)
			return

	_kill_loop_tween(AMBIENCE_BUS)
	loop(bed, AMBIENCE_BUS, -60.0)
	_amb_zone = z
	fade_loop(AMBIENCE_BUS, target, AMBIENCE_FADE_IN)


## Stop the bed. `Sfx` loops run at PROCESS_MODE_ALWAYS and outlive whatever
## started them, so a bed nobody stops follows the player through the results
## card, the whole migration flight and into the next zone. Ambience was the one
## loop bus in the game that nothing ever stopped.
func stop_ambience() -> void:
	stop_loop(AMBIENCE_BUS)
