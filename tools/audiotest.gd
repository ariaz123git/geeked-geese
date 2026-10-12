extends RefCounted
## THE AUDIO GATE — the tenth, and the only one that opens the WAVs.
##
##     godot --headless --path . -- --audiotest 2>&1 | grep '^\[audio\]'
##
## ═══════════════════════════════════════════════════════════════════════════
## WHAT THIS CAN AND CANNOT DO, STATED FIRST BECAUSE IT MATTERS
## ═══════════════════════════════════════════════════════════════════════════
##
## **It cannot tell you anything sounds good.** A headless run cannot listen,
## and `docs/HANDOFF.md` §4 records that the ambience beds have never been
## auditioned by ear. Every assertion below is about a property a WAV either has
## or does not have, and none of them is an opinion.
##
## What it replaces is a much weaker check. `selftest.gd::_the_assets()` proves
## a file EXISTS for every key the code asks for. The bug that got past it is in
## the record: **the truck stop's "rain" was a 0.700 s goose hiss that never
## looped**, because `Sfx` only forced looping on keys ending `_loop`. The file
## existed. The key resolved. The zone played 0.7 seconds of goose and then 174
## seconds of silence.
##
## ═══════════════════════════════════════════════════════════════════════════
## THE FIVE THINGS IT ASSERTS
## ═══════════════════════════════════════════════════════════════════════════
##
##   1. **A bed loops.** Every ambience key and every `*_loop` key must come out
##      of `Sfx` with `LOOP_FORWARD` set and a `loop_end` past its `loop_begin`.
##      This is checked on the stream `Sfx` hands out, not on the `.import`
##      file, because `sfx.gd::_configure_loop_if_needed()` fixes some of them at
##      runtime and what the player hears is the fixed one.
##   2. **A bed is long enough to be a bed, and a one-shot is short enough to be
##      a one-shot.** The 0.700 s hiss passes any existence check and fails this.
##   3. **Nothing is silent.** A generated file whose synthesis produced zeros is
##      indistinguishable from a missing one at play time and identical to a
##      correct one on disk.
##   4. **Nothing clips.** More than a hair of full-scale samples means the
##      generator's gain staging is wrong, which is audible as distortion on
##      every play.
##   5. **Layered stems share a length.** The 16 music stems are mixed on top of
##      each other; if one is a different length they drift apart a little more
##      on every loop until the music is wrong in a way nobody can point at.
##
## 3 and 4 need real samples, so they are skipped for QOA-compressed files with
## a printed count. That is a named limit, not a silent one: 40 of the 68 files
## import as QOA and the gate says so on every run.

const AUDIO_DIR := "res://audio/"
const COMMON := preload("res://tools/probe_common.gd")

## THREE FAMILIES LOOP, AND THEY ARE NOT THE SAME THING. The first version of
## this file had one floor for all of them and immediately accused two healthy
## files: `dose_charge_loop` is 1.000 s because the dose arc is 1.1 s, and
## `swim_loop` is 2.000 s because that is how long a paddle cycle is. Neither
## is a bed. A single number here would have had to be lowered to 1.0 to let
## them through, which would also have let the bug this gate exists for
## straight through — the truck stop's "rain", a **0.700 s goose hiss**.
##
## So the floor is per family, and each one is argued:
##   * `amb_*` — a zone bed plays under a three-minute leg. The shortest real
##     one is 6.000 s and the longest 16.000. **4.0** leaves room and still
##     catches a 0.700 s hiss by a factor of six.
##   * `*_loop` — a looping SFX is as long as the action it covers. Under
##     **0.25** it is not a loop, it is a buzz at 4 Hz.
##   * `mus_*` — a layered music stem is bar-aligned; all sixteen are 45.714 s.
##     **10.0** is a floor, not a target.
const AMBIENCE_MIN_SECONDS := 4.0
const SFX_LOOP_MIN_SECONDS := 0.25
const STEM_MIN_SECONDS := 10.0

## A one-shot longer than this is a bed that lost its key. The longest real
## one-shot is `fx_*` at 2.000 s.
const ONESHOT_MAX_SECONDS := 6.0

## Peak amplitude below this is silence. -60 dBFS.
const SILENCE_PEAK := 0.001

## Fraction of samples allowed to sit at full scale before it is clipping
## rather than a peak that happens to touch.
const CLIP_FRACTION := 0.002

static var _fails: Array[String] = []
static var _checks := 0
static var _skipped_qoa := 0


static func run(tree: SceneTree, main: Node) -> void:
	_fails.clear()
	_checks = 0
	_skipped_qoa = 0
	await COMMON.settled(tree)   # probe_common lesson 10: _quit_mid_sound() adds a node

	var sfx := main.get_node_or_null("/root/Sfx")
	if sfx == null:
		print("[audio] FAIL — no Sfx autoload, so nothing can be asked for a stream")
		tree.quit(1)
		return

	var names := _wav_names()
	_ok(names.size() >= 40,
		"found %d wavs under %s — this gate has gone blind, fix the walk" % [names.size(), AUDIO_DIR])
	print("[audio] %d wav files on disk" % names.size())

	var beds: Array[String] = []
	var lengths := {}
	for one in names:
		var key := StringName(one)
		var stream: AudioStream = sfx.call("_get_stream", key)
		_ok(stream != null, "%s.wav did not load as an AudioStream" % one)
		if stream == null:
			continue
		var secs: float = stream.get_length()
		var loops := _is_loop_key(one)
		if loops:
			beds.append(one)

		# 1 + 2. shape
		var wav := stream as AudioStreamWAV
		if loops:
			_ok(wav != null and wav.loop_mode != AudioStreamWAV.LOOP_DISABLED,
				("%s is an ambience or _loop key and its stream does not loop. The truck stop's "
				+ "\"rain\" was a 0.700 s goose hiss that never looped and every existence check "
				+ "passed.") % one)
			if wav != null:
				_ok(wav.loop_end > wav.loop_begin,
					"%s loops with loop_end %d <= loop_begin %d, which is a loop of nothing." % [
						one, wav.loop_end, wav.loop_begin])
			var floor_s := _loop_floor(one)
			_ok(secs >= floor_s,
				("%s loops for %.3f s, under the %.2f s floor for its family. The truck stop's "
				+ "\"rain\" was a 0.700 s goose hiss and every existence check passed it.") % [
					one, secs, floor_s])
		else:
			_ok(secs <= ONESHOT_MAX_SECONDS,
				"%s is a one-shot of %.3f s, over the %.1f s ceiling. A one-shot that long is a bed whose key lost its suffix." % [
					one, secs, ONESHOT_MAX_SECONDS])

		# 3 + 4. content, where the format allows it
		if wav != null and wav.format == AudioStreamWAV.FORMAT_16_BITS:
			var peak_clip := _peak_and_clip(wav)
			_ok(peak_clip.x > SILENCE_PEAK,
				("%s peaks at %.5f, which is silence. A generated file whose synthesis produced "
				+ "zeros is identical to a correct one on disk and identical to a missing one at "
				+ "play time.") % [one, peak_clip.x])
			_ok(peak_clip.y <= CLIP_FRACTION,
				"%s has %.2f%% of its samples at full scale, over the %.2f%% ceiling. That is clipping, and it is audible on every play." % [
					one, peak_clip.y * 100.0, CLIP_FRACTION * 100.0])
		elif wav != null:
			_skipped_qoa += 1

		if one.begins_with("mus_") and not one.begins_with("mus_sting"):
			lengths[one] = secs

	# 5. the layered stems
	var uniq := {}
	for k in lengths.keys():
		uniq[snappedf(float(lengths[k]), 0.001)] = k
	_ok(uniq.size() == 1,
		("the %d layered music stems have %d different lengths (%s). They are mixed on top of each "
		+ "other, so any difference makes them drift a little further apart on every loop.") % [
			lengths.size(), uniq.size(), str(uniq.keys())])
	if uniq.size() == 1 and not lengths.is_empty():
		print("[audio] %d layered stems, all %.3f s" % [lengths.size(), float(uniq.keys()[0])])
	print("[audio] %d looping beds; %d files skipped for content checks (QOA-compressed, no PCM samples to read)"
		% [beds.size(), _skipped_qoa])

	_the_volume_sliders(main)
	await _quit_mid_sound(tree, main)

	if _fails.is_empty():
		print("[audio] PASS — %d checks over %d files" % [_checks, names.size()])
		tree.quit(0)
		return
	print("[audio] FAIL — %d of %d checks:" % [_fails.size(), _checks])
	for f in _fails:
		print("[audio]   %s" % f)
	tree.quit(1)



## ═══════════════════════════════════════════════════════════════════════════
## QUITTING WITH SOUNDS STILL PLAYING — the exit this gate takes on purpose
## ═══════════════════════════════════════════════════════════════════════════
##
## D-074. A positional sound still playing at quit leaked its stream:
## `Sfx.play_at()` parents its player under a zone node, a player that leaves
## the tree only PAUSES its playback, and the stop came with deletion, after
## every exit wait had already run. Twelve of them leaked 4 streams on 6 runs of
## 6. The full campaign found it only because it happened to quit on a green
## full of honking geese — which is a gate catching a bug by luck.
##
## The engine prints that report AFTER `quit()`, where nothing in here can read
## it. So this does not assert the leak: it guarantees the condition on every
## run, and `verify.ps1`'s ScriptErrors — which fails any step whose exit
## reports a resource still in use — is the assertion. The one thing asserted
## here is that the condition was really arranged: an exit with nothing playing
## would prove nothing.
static func _quit_mid_sound(tree: SceneTree, main: Node) -> void:
	var sfx := main.get_node_or_null("/root/Sfx")
	var at := Node3D.new()
	at.name = "AudiotestExitSounds"
	main.add_child(at)
	for k in [&"honk_a", &"honk_b", &"honk_c", &"thud_land"]:
		for _j in 3:
			sfx.call("play_at", k, at, -60.0, 1.0)
	await tree.process_frame
	await tree.process_frame
	var playing := 0
	for c in at.get_children():
		var p := c as AudioStreamPlayer3D
		if p != null and p.playing:
			playing += 1
	print("[audio] exit: quitting with %d positional sounds still playing — verify.ps1 fails this step if the engine then reports a stream still in use"
		% playing)
	_ok(playing >= 12,
		"only %d of 12 positional sounds were still playing at quit, so this exit proves nothing about a leak" % playing)


## ═══════════════════════════════════════════════════════════════════════════
## THE THREE VOLUME SLIDERS, AND WHETHER THEY DO ANYTHING
## ═══════════════════════════════════════════════════════════════════════════
##
## `pause_menu.gd` offers Master, SFX and Music. `prefs.gd::_apply_audio()`
## writes each to a bus by name. **A slider whose bus does not exist is a
## control that moves and changes nothing**, and `get_bus_index()` returns -1
## for a missing bus without raising anything — so the branch is skipped in
## silence. That is the `stamina_restore` shape again: an exported control
## nothing consumes.
##
## Boot order is the other half. `Prefs` is autoload #1 and calls
## `_apply_audio()` in its `_ready()`; `Music` is #10 and creates the Music bus
## long afterwards. Whatever the player saved is therefore applied to a bus
## that does not exist yet, unless somebody re-applies once the buses are up.
static func _the_volume_sliders(main: Node) -> void:
	var prefs := main.get_node_or_null("/root/Prefs")
	var sfx := main.get_node_or_null("/root/Sfx")
	_ok(prefs != null and sfx != null,
		"Prefs or Sfx autoload missing, so the volume sliders cannot be checked")
	if prefs == null or sfx == null:
		return

	# 1. THE BUSES THE SLIDERS NAME MUST EXIST.
	for bus_name in ["SFX", "Music"]:
		var idx := AudioServer.get_bus_index(bus_name)
		print("[audio] bus %-6s index=%d" % [bus_name, idx])
		_ok(idx >= 0,
			("prefs.gd::_apply_audio() writes the %s volume to a bus named \"%s\" and no such "
			+ "bus exists. `get_bus_index()` returns -1 and the branch is skipped without a "
			+ "word, so that slider moves and nothing happens.") % [bus_name.to_lower(), bus_name])

	# 2. THE SFX PLAYERS MUST ACTUALLY BE ON THE SFX BUS.
	# A bus that exists and carries nothing is the same dead slider wearing a
	# better disguise.
	var routed := 0
	var total := 0
	var elsewhere := {}
	for child in sfx.get_children():
		var pl := child as AudioStreamPlayer
		if pl == null:
			continue
		total += 1
		if pl.bus == "SFX":
			routed += 1
		else:
			elsewhere[pl.bus] = int(elsewhere.get(pl.bus, 0)) + 1
	print("[audio] sfx players on the SFX bus: %d of %d%s"
		% [routed, total, "" if elsewhere.is_empty() else "  elsewhere: " + str(elsewhere)])
	_ok(total > 0, "Sfx has no AudioStreamPlayer children, so nothing was checked")
	_ok(routed == total,
		("%d of %d Sfx players are not on the SFX bus (%s). The SFX volume slider writes "
		+ "to that bus, so anything routed past it is deaf to the control.")
			% [total - routed, total, str(elsewhere)])

	# 3. MOVING THE SLIDER MUST MOVE THE BUS.
	# The end-to-end statement, and the only one that survives a refactor of
	# how the volume is plumbed.
	for row in [["sfx_volume", "SFX"], ["music_volume", "Music"], ["master_volume", "Master"]]:
		var spec: Array = row
		var key: String = spec[0]
		var bus: String = spec[1]
		var idx2 := AudioServer.get_bus_index(bus)
		if idx2 < 0:
			continue
		var was = prefs.call("get_pref", StringName(key), 0.9)
		prefs.call("set_pref", StringName(key), 0.25)
		var quiet := AudioServer.get_bus_volume_db(idx2)
		prefs.call("set_pref", StringName(key), 1.0)
		var loud := AudioServer.get_bus_volume_db(idx2)
		prefs.call("set_pref", StringName(key), was)
		print("[audio] %-13s 0.25 -> %+.1f dB, 1.00 -> %+.1f dB" % [key, quiet, loud])
		_ok(loud > quiet + 3.0,
			("moving %s from 0.25 to 1.00 changed the %s bus by %.1f dB. The slider is "
			+ "connected to nothing the player can hear.") % [key, bus, loud - quiet])

static func _ok(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_fails.append(msg)


## The shortest a looping file of this family may honestly be.
static func _loop_floor(name: String) -> float:
	if name.begins_with("amb_"):
		return AMBIENCE_MIN_SECONDS
	if name.begins_with("mus_"):
		return STEM_MIN_SECONDS
	return SFX_LOOP_MIN_SECONDS

## The same rule `sfx.gd::_configure_loop_if_needed()` uses, deliberately
## duplicated rather than shared: if the two ever disagree, this gate should say
## so rather than inherit the mistake.
static func _is_loop_key(name: String) -> bool:
	return name.ends_with("_loop") or name.begins_with("amb_") or (
		name.begins_with("mus_") and not name.begins_with("mus_sting"))


static func _wav_names() -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(AUDIO_DIR)
	if d == null:
		return out
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if f.ends_with(".wav"):
			out.append(f.get_basename())
		f = d.get_next()
	d.list_dir_end()
	out.sort()
	return out


## Vector2(peak, clipped_fraction) over a 16-bit PCM stream.
static func _peak_and_clip(wav: AudioStreamWAV) -> Vector2:
	var bytes := wav.data
	var n := bytes.size() / 2
	if n <= 0:
		return Vector2.ZERO
	var peak := 0.0
	var clipped := 0
	# Every sample, not a sample of them: a burst of clipping in one region is
	# exactly what a stride would step over.
	for i in n:
		var v := bytes.decode_s16(i * 2)
		var a: float = absf(float(v)) / 32768.0
		peak = maxf(peak, a)
		if a >= 0.999:
			clipped += 1
	return Vector2(peak, float(clipped) / float(n))
