extends RefCounted
## THE AUDIO GATE — the tenth, and the only one that opens the WAVs.
##
##     godot --headless --path . -- --audiotest 2>&1 | grep '^\[audio\]'
##
## ═══════════════════════════════════════════════════════════════════════════
## WHAT THIS CAN AND CANNOT DO, STATED FIRST BECAUSE IT MATTERS
## ═══════════════════════════════════════════════════════════════════════════
##
## **It cannot tell you anything sounds good.** No agent has heard a single one
## of these files and none ever will; `docs/HANDOFF.md` §4 says so in as many
## words — *"nobody has heard any of the ambience beds, including the agent that
## generated them."* Every assertion below is about a property a WAV either has
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

	if _fails.is_empty():
		print("[audio] PASS — %d checks over %d files" % [_checks, names.size()])
		tree.quit(0)
		return
	print("[audio] FAIL — %d of %d checks:" % [_fails.size(), _checks])
	for f in _fails:
		print("[audio]   %s" % f)
	tree.quit(1)


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
