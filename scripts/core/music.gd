extends Node
## Autoload: Music
##
## The adaptive score for "Geeked Geese". Canadiana through a blown speaker.
##
## ---------------------------------------------------------------------------
## ARCHITECTURE: VERTICAL REMIXING, NOT HORIZONTAL RE-SEQUENCING
## ---------------------------------------------------------------------------
## Every stem for every zone is loaded at boot, started on the SAME FRAME, and
## never stopped. Nothing is ever re-triggered, re-queued or restarted. The
## only thing that ever changes is a volume.
##
## That is deliberate, and it is the whole reason this file is short. The
## alternative -- horizontal re-sequencing, where you stop one cue and start
## another at a musically safe boundary -- means owning a scheduler, a bar
## clock, transition segments, and a queue of "please switch when we reach the
## next downbeat". Every one of those is a place to have a bug you can hear.
##
## Vertical remixing has exactly one hard requirement instead: the stems must
## stay in sync forever. We meet it structurally rather than by scheduling:
##
##   * every bed stem is EXACTLY 1,008,000 samples (16 bars @ 84 BPM, 22050 Hz)
##   * every bed stem is in D mixolydian on the same grid
##   * they all start in one loop in _start_all(), i.e. one audio-server tick
##   * when we bend pitch, we bend ALL of them by the same value in the same
##     frame, so they bend together
##
## Same length + same start + same rate = permanently phase-locked. Any layer
## can be added or removed at any instant, mid-bar, with no transition asset,
## because the layer was already playing -- it was just at -80 dB.
##
## Horizontal movement does still exist, but only where the game itself hard
## cuts: zone -> migration -> zone. Those are scene swaps, so a 1.8 s
## crossfade between two cues that share a key and a tempo is not a seam, it's
## a modulation.
##
## ---------------------------------------------------------------------------
## BUSES
## ---------------------------------------------------------------------------
## Created at runtime so the project ships no .tres bus layout:
##
##   Master
##    +- Music        <- owned by Prefs (`music_volume`). We never write its
##    |   |              volume, only its mute flag at exactly zero.
##    |   +- MusicBed    <- the 16 looping layers. Lowpass + pitch-shift live
##    |   |                 here. This is what ducks.
##    |   +- MusicSting  <- one-shots. Never ducked, never filtered: a stinger
##                          that gets ducked by its own duck is a stinger you
##                          can't hear.
##
## ---------------------------------------------------------------------------
## Autoload AFTER Mission (it resolves Game/Subs/Flock/Mission in _ready).
## Everything here degrades to silence if the WAVs aren't there.

const AUDIO_DIR := "res://audio/"

const BUS_MUSIC := "Music"
const BUS_BED := "MusicBed"
const BUS_STING := "MusicSting"

## STEM SET -> role -> wav basename. Four sets exist and there will not be more
## without running `tools/gen_music.py`, which writes 33 MB. The migration cue's
## rhythm role is a driving eighth-note pulse rather than a backbeat, hence the
## different filename; the ROLE name stays `rhythm` so the mix curve doesn't
## need a special case.
##
## NOTE: this is keyed by STEM SET, not by zone. `ZONE_STEMS` below maps the
## game's zone ids onto these. Two zones may share a set; their MIX (floor and
## entry windows) still belongs to the zone.
const STEMS := {
	&"strip_mall": {
		&"base": &"mus_mall_base", &"rhythm": &"mus_mall_rhythm",
		&"lead": &"mus_mall_lead", &"hi": &"mus_mall_hi",
	},
	&"suburbia": {
		&"base": &"mus_burb_base", &"rhythm": &"mus_burb_rhythm",
		&"lead": &"mus_burb_lead", &"hi": &"mus_burb_hi",
	},
	&"cottage": {
		&"base": &"mus_lake_base", &"rhythm": &"mus_lake_rhythm",
		&"lead": &"mus_lake_lead", &"hi": &"mus_lake_hi",
	},
	&"migration": {
		&"base": &"mus_mig_base", &"rhythm": &"mus_mig_pulse",
		&"lead": &"mus_mig_lead", &"hi": &"mus_mig_hi",
	},
}

## ZONE ID -> which stem set plays there.
##
## Every zone that ships must have an entry, or it plays in silence: `set_zone()`
## falls back to `none` for anything it doesn't recognise, which is the right
## behaviour for a typo and the wrong one for a zone somebody actually built.
## `corn` and `truckstop` shipped without one and BOTH LEGS RAN SILENT, printing
## `Music: unknown zone 'corn' — going quiet` on every load.
##
## The two new legs borrow existing sets rather than getting their own, because
## the only way to get a fifth set is to regenerate 33 MB of audio and that is a
## much larger decision than fixing the silence. What they get instead is their
## own MIX — `ZONE_FLOOR` and `ENTER_BY_ZONE` — which is where a zone's character
## actually lives. Reasoning for each choice is in docs/CLOCK_AND_CAMERA_NOTES.md.
##
##   corn      -> suburbia. `mus_burb_base` is the only stem in the library with
##                a MACHINE in it (a tuned two-stroke mower), and leg 6's
##                antagonist is a combine. Bright midday pad, walking bass, and
##                sprinklers in 3-against-4 — the most agricultural forty-five
##                seconds available. The migration set was the other candidate
##                and is rejected on purpose: MUSIC_NOTES §3 is explicit that the
##                V-I cadence is withheld from every zone so the flight can land
##                it, and spending that on leg 6 costs the flight its one sincere
##                gesture.
##   truckstop -> cottage. The night set: a harmonium an octave down with a 3.4 s
##                tail, one bass note a bar, a wet dock-board knock, fiddle
##                fragments arriving from a long way off through a 2.1 kHz
##                lowpass. It is the only music in the project that is already
##                dark, wet and far away, which is the zone. Runner-up was the
##                strip mall set for its 60 Hz mains hum — genuinely the right
##                detail for a lot lit by sodium — but its rhythm layer is a
##                lounge shuffle with a cart-wheel rim on it, and leg 7 is the
##                one zone in the run that is not a joke.
##   stopover  -> cottage. LIVE. This was written as a dormant entry, on the
##                grounds that "leg 5 is still `zone_cottage.gd` and still
##                reports `cottage`" — which stopped being true the moment
##                `zone_stopover.gd` landed and `main.gd::ROUTE` was pointed at
##                it. Leg 5 reports `stopover` now and this is the entry that
##                answers it. It is here rather than in `ZONE_ALIASES` — where
##                ROUTE_DATA §Music suggested it — for one concrete reason:
##                `ZONE_FLOOR` and `ENTER_BY_ZONE` are read with the RESOLVED
##                zone id (see `_update_intensity`, `_update_layers`), so an
##                alias to `cottage` would hand leg 5 leg 4's mix. Leg 4 is the
##                first peak (intensity 7) and leg 5 is the deep trough
##                (intensity 2, CAMPAIGN_SPEC §Part 3 beat 9), which is the
##                largest single drop on the whole curve. Same four WAVs, its
##                own floor and its own entry windows — exactly the split corn
##                and truckstop already use. The lake set is also the right
##                sound on its merits: dawn on a drowned marsh is the same
##                instrument as night on a lake, played quieter.
const ZONE_STEMS := {
	&"strip_mall": &"strip_mall",
	&"suburbia": &"suburbia",
	&"cottage": &"cottage",
	&"migration": &"migration",
	&"corn": &"suburbia",
	&"truckstop": &"cottage",
	&"stopover": &"cottage",
}

const STINGERS := {
	&"objective": &"mus_sting_objective",
	&"hidden": &"mus_sting_hidden",
	&"leg_pass": &"mus_sting_leg_pass",
	&"leg_fail": &"mus_sting_leg_fail",
	&"blackout": &"mus_sting_blackout",
	&"wake": &"mus_sting_wake",
}

## Whatever the rest of the codebase feels like calling a place.
##
## THE ENDING RESOLVES TO `cottage`, AND DELIBERATELY NOT TO ITS OWN ENTRY.
##
## `zone_finale.gd` already picks the ending's cue itself — it calls
## `set_zone(&"cottage")` and `set_intensity(0.26)` directly (and pokes
## `&"migration"` first, purely to clear the flight watchdog so the flight cue
## cannot be dragged back over the ending). That is the right owner: the ending
## is a scripted beat, not a zone with an intensity curve.
##
## So the finale needs an ALIAS, not a sixth `ZONE_STEMS` entry. An entry would
## be a second opinion — its own floor and entry windows silently competing with
## the numbers the finale sets by hand, and the two would drift the first time
## anyone touched either. Aliasing to `cottage` means every spelling of the
## ending lands on exactly the cue the finale already asked for.
##
## `cottage` is also the correct cue on its own merits, and the reason is in
## MUSIC_NOTES §3: the V-I cadence is withheld from every zone so the flight can
## land it, which rules out the migration set no matter how much the last scene
## wants to feel like an arrival. Of the three that remain, the lake set is the
## warmest and least percussive — a harmonium, one bass note a bar, fiddle
## fragments a long way off. Played at 0.26 with the sun coming up over the 18th
## green that reads as a quiet Florida dawn rather than as night.
##
## Without this, `set_zone(&"finale")` warned `unknown zone` and went SILENT —
## the same failure `corn` and `truckstop` shipped with.
##
## `pond` and `retention_pond` are here for the same reason `finale` is: leg 1 is
## called THE RETENTION POND everywhere except in code, where it reports
## `strip_mall`. The day somebody gives the pond its own zone script, the leg
## goes silent with a push_warning nobody reads — which is precisely how `corn`
## and `truckstop` shipped mute. One line now is cheaper than that bug twice.
const ZONE_ALIASES := {
	&"mall": &"strip_mall", &"parking_lot": &"strip_mall", &"stripmall": &"strip_mall",
	&"pond": &"strip_mall", &"retention_pond": &"strip_mall",
	&"burb": &"suburbia", &"suburb": &"suburbia", &"suburbs": &"suburbia",
	&"lake": &"cottage", &"cottage_night": &"cottage", &"cottage_lake": &"cottage",
	&"refuge": &"stopover", &"marsh": &"stopover", &"the_stopover": &"stopover",
	&"corn_field": &"corn", &"cornfield": &"corn", &"cut_corn": &"corn",
	&"truck_stop": &"truckstop", &"truckstop_night": &"truckstop",
	&"finale": &"cottage", &"green": &"cottage", &"eighteenth_green": &"cottage",
	&"ending": &"cottage", &"epilogue": &"cottage",
	&"flight": &"migration", &"fly": &"migration", &"v_formation": &"migration",
	&"": &"none", &"generic": &"none", &"silence": &"none",
}

## Intensity window per role: x = fade start, y = fully in.
## `base` is Vector2.ZERO, i.e. always on -- there is always a bed.
const ENTER := {
	&"base": Vector2(0.0, 0.0),
	&"rhythm": Vector2(0.04, 0.34),
	&"lead": Vector2(0.22, 0.58),
	&"hi": Vector2(0.55, 0.92),
}
## Migration enters earlier and fuller. The flight is not a reward for a
## combo -- it is the one sincere cue in the game and it should be allowed to
## be a whole piece of music from the first second.
const ENTER_MIGRATION := {
	&"base": Vector2(0.0, 0.0),
	&"rhythm": Vector2(0.02, 0.26),
	&"lead": Vector2(0.08, 0.34),
	&"hi": Vector2(0.40, 0.82),
}
## THE CUT CORN — leg 6, the run's second intensity peak, hard midday, a combine
## coming up the lane at you. Everything arrives early and the top end is
## reachable rather than reserved for a ten-chain: the band is already playing
## when you land in the stubble, which is the difference between a field that is
## dangerous and a field that becomes dangerous once you have earned it.
const ENTER_CORN := {
	&"base": Vector2(0.0, 0.0),
	&"rhythm": Vector2(0.02, 0.20),
	&"lead": Vector2(0.14, 0.44),
	&"hi": Vector2(0.42, 0.80),
}
## THE TRUCK STOP — leg 7, 3 a.m., rain, the quietest zone in the run and
## deliberately the breath before the climax. The inverse of the corn: the tune
## has to be earned and the top end very nearly cannot be. At rest you get a
## harmonium and the rain loop the zone runs itself, and that is the whole
## intent -- see ZONE_TRUCKSTOP_NOTES §2.1 on scarcity.
const ENTER_TRUCKSTOP := {
	&"base": Vector2(0.0, 0.0),
	&"rhythm": Vector2(0.10, 0.46),
	&"lead": Vector2(0.40, 0.78),
	&"hi": Vector2(0.72, 1.00),
}
## THE STOPOVER — leg 5, dawn on a drowned marsh, the run's deep trough and the
## only full mechanical heal in the back half. The truck stop's curve pushed
## further in the same direction: at rest you get the harmonium and nothing
## else, and the top end is not reachable at all without a chain you would have
## to go looking for. CAMPAIGN_SPEC §Part 3 is explicit that "a palette
## cleanser that is still 60% as loud is not a palette cleanser", and the zone's
## whole argument — that the trough is only a trough if you take it — is
## undermined by a band that starts playing the moment you knock something over.
const ENTER_STOPOVER := {
	&"base": Vector2(0.0, 0.0),
	&"rhythm": Vector2(0.34, 0.72),
	&"lead": Vector2(0.58, 0.94),
	&"hi": Vector2(0.88, 1.00),
}
## Zone id -> its entry-window table. Anything absent uses ENTER. Keyed by ZONE,
## not by stem set, which is the point: the corn and suburbia share four WAVs and
## do not share a mix.
const ENTER_BY_ZONE := {
	&"migration": ENTER_MIGRATION,
	&"corn": ENTER_CORN,
	&"truckstop": ENTER_TRUCKSTOP,
	&"stopover": ENTER_STOPOVER,
}

## The mix never drops below this per zone, no matter how quietly the player
## is behaving. Without it the backbeat appears when you hit something and
## evaporates six seconds later, and the score reads as a reactive system
## rather than as a band that is already in the room -- which is the wrong
## joke. What responds to the player is the TUNE and the top end, not whether
## music is happening at all.
##
## Migration sits much higher: the flight cue is a whole piece of music from
## the first bar and is not something you earn.
##
## The two new legs sit at the extremes on purpose, and they are the two ends of
## the campaign's intensity curve: the corn is the second peak (0.44 — the mix is
## already busy before you touch anything) and the truck stop is the trough
## (0.16, below every other zone in the game — you are meant to notice how little
## is happening).
##
## The stopover goes BELOW the truck stop — 0.10, the lowest in the game. The
## truck stop is the shallow trough (intensity 4) and the stopover is the deep
## one (intensity 2), and at 0.10 the `ENTER_STOPOVER` rhythm window has not
## opened, so a player standing still on the marsh hears the bed and nothing
## else. That is the leg.
const ZONE_FLOOR := {
	&"strip_mall": 0.30,
	&"suburbia": 0.30,
	&"cottage": 0.26,
	&"corn": 0.44,
	&"truckstop": 0.16,
	&"stopover": 0.10,
	&"migration": 0.55,
}

const FADE_UP := 0.85          ## seconds to ~63% when a layer comes in
const FADE_DOWN := 1.55        ## slower going out: layers should ebb, not cut
const STING_POOL := 4
const HEAT_TAU := 3.6          ## chaos "recent activity" decay
const WAKE_RECOVER := 2.6      ## seconds for the bed to climb back post-blackout
const RESYNC_EVERY := 5.0
const RESYNC_TOL := 0.020      ## seconds of drift we'll tolerate silently

## Every write to a player property, a bus volume or an effect parameter is a
## command posted to the audio thread. At rest this node has nothing to say,
## and saying it sixty times a second anyway is pure queue traffic. These
## epsilons are all comfortably below audibility (0.02 dB, 0.9 cents, 0.2% of
## a filter cutoff), so skipping a write inside them cannot change what the
## player hears -- it only stops us shouting at the mixer about nothing.
const EPS_DB := 0.02
const EPS_PITCH := 0.0005
const EPS_CUT := 0.002

## --- runtime state ---------------------------------------------------------

var _enabled := false
var _playing := false

var _players: Dictionary = {}      ## StringName "zone/role" -> AudioStreamPlayer
var _gain: Dictionary = {}         ## StringName "zone/role" -> float (linear)
var _stings: Array[AudioStreamPlayer] = []
var _sting_next := 0
var _cache: Dictionary = {}        ## StringName -> AudioStream

var _bed_idx := -1
var _sting_idx := -1
var _music_idx := -1
var _lpf: AudioEffectLowPassFilter = null
var _shifter: AudioEffectPitchShift = null
var _shift_slot := -1

var zone: StringName = &"none"
var intensity := 0.0

var _intensity_target := 0.0
var _manual_floor := 0.0
var _heat := 0.0
var _floor_until := -1.0        ## a temporary intensity floor (named combos)
var _floor_value := 0.0

var _duck_db := 0.0
var _duck_left := 0.0
var _duck_span := 1.0
var _duck_cur := 0.0

var _pitch := 1.0               ## tape speed, applied to every bed player
var _cut := 20000.0             ## bed lowpass cutoff
var _shift := 1.0               ## musical detune, independent of speed
var _bed_db := 0.0

var _blackout := false
var _wake_until := -1.0
var _lead_mute_until := -1.0
var _resync_t := 0.0
var _mig_watch := 0.0
var _mig_deadline := -1.0
var _clock := 0.0               ## our own real-time clock, immune to time_scale

var _game: Node = null
var _subs: Node = null
var _mission: Node = null
var _prefs: Node = null


# ===========================================================================
# ------------------------------  LIFECYCLE  --------------------------------
# ===========================================================================

func _ready() -> void:
	# The music must keep playing over the pause menu, the results card and
	# the briefing overlays -- all of which pause the tree.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_resolve_nodes()
	_setup_buses()
	_load_stems()
	if not _enabled:
		push_warning("Music: no music stems found in %s -- score disabled. "
			% AUDIO_DIR + "Run tools/gen_music.py.")
		return
	_connect_signals()
	_apply_music_volume()
	_start_all()


## Godot reports every still-referenced Resource at exit. Sixteen cached
## AudioStreamWAVs held by an autoload count. Drop them explicitly.
func _exit_tree() -> void:
	for key in _players.keys():
		var p: AudioStreamPlayer = _players[key]
		if is_instance_valid(p):
			p.stop()
			p.stream = null
	for s in _stings:
		if is_instance_valid(s):
			s.stop()
			s.stream = null
	_cache.clear()
	_playing = false


func _resolve_nodes() -> void:
	_game = get_node_or_null("/root/Game")
	_subs = get_node_or_null("/root/Subs")
	_mission = get_node_or_null("/root/Mission")
	_prefs = get_node_or_null("/root/Prefs")


## Buses are built in code rather than shipped as a bus layout resource:
## a .tres layout is a binary-ish file nobody diffs, and it silently loses
## every bus if it fails to load. Five AudioServer calls cannot fail.
func _setup_buses() -> void:
	_music_idx = _ensure_bus(BUS_MUSIC, "Master")
	_bed_idx = _ensure_bus(BUS_BED, BUS_MUSIC)
	_sting_idx = _ensure_bus(BUS_STING, BUS_MUSIC)

	if AudioServer.get_bus_effect_count(_bed_idx) == 0:
		_lpf = AudioEffectLowPassFilter.new()
		_lpf.cutoff_hz = 20000.0
		_lpf.resonance = 0.12
		AudioServer.add_bus_effect(_bed_idx, _lpf, 0)

		# Kept present but DISABLED. Godot's pitch shifter is a phase vocoder;
		# even at ratio 1.0 it smears transients, and this score is mostly
		# transients (bow attacks, brushes, plucks). Enabling it only while a
		# substance actually needs it means the smear arrives exactly when the
		# player has taken something that should smear.
		_shifter = AudioEffectPitchShift.new()
		_shifter.pitch_scale = 1.0
		AudioServer.add_bus_effect(_bed_idx, _shifter, 1)
		_shift_slot = 1
		AudioServer.set_bus_effect_enabled(_bed_idx, _shift_slot, false)
	else:
		var e0: AudioEffect = AudioServer.get_bus_effect(_bed_idx, 0)
		if e0 is AudioEffectLowPassFilter:
			_lpf = e0
		if AudioServer.get_bus_effect_count(_bed_idx) > 1:
			var e1: AudioEffect = AudioServer.get_bus_effect(_bed_idx, 1)
			if e1 is AudioEffectPitchShift:
				_shifter = e1
				_shift_slot = 1


func _ensure_bus(bus_name: String, send_to: String) -> int:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		return idx
	idx = AudioServer.get_bus_count()
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, send_to)
	AudioServer.set_bus_volume_db(idx, 0.0)
	return idx


func _load_stems() -> void:
	for zone_key in STEMS.keys():
		var zk: StringName = zone_key
		var roles: Dictionary = STEMS[zk]
		for role_key in roles.keys():
			var rk: StringName = role_key
			var wav: StringName = roles[rk]
			var stream: AudioStream = _stream(wav, true)
			if stream == null:
				continue
			var p := AudioStreamPlayer.new()
			p.name = "Bed_%s_%s" % [String(zk), String(rk)]
			p.stream = stream
			p.bus = BUS_BED
			p.volume_db = -80.0
			p.process_mode = Node.PROCESS_MODE_ALWAYS
			add_child(p)
			var key := _key(zk, rk)
			_players[key] = p
			_gain[key] = 0.0
			_enabled = true

	for i in range(STING_POOL):
		var s := AudioStreamPlayer.new()
		s.name = "Sting%d" % i
		s.bus = BUS_STING
		s.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(s)
		_stings.append(s)


func _key(z: StringName, r: StringName) -> StringName:
	return StringName(String(z) + "/" + String(r))


func _stream(wav: StringName, loop: bool) -> AudioStream:
	if _cache.has(wav):
		var cached: AudioStream = _cache[wav]
		return cached
	var path := AUDIO_DIR + String(wav) + ".wav"
	if not ResourceLoader.exists(path):
		return null
	var res: Resource = load(path)
	if res == null or not (res is AudioStream):
		return null
	var stream: AudioStream = res
	# Belt and braces, exactly as Sfx does: force forward looping on the
	# resource so a stale or hand-edited .import can't silently turn a bed
	# layer into a 45-second one-shot.
	if loop and stream is AudioStreamWAV:
		var w: AudioStreamWAV = stream
		if w.data != null:
			var bpf: int = 4 if w.stereo else 2
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = int(w.data.size() / bpf)
	_cache[wav] = stream
	return stream


## The one place sync is established. Every bed layer is started inside a
## single loop, so they all begin on the same audio-server mix. Combined with
## identical stem lengths this is the entire synchronisation strategy.
func _start_all() -> void:
	if not _enabled:
		return
	for key in _players.keys():
		var p: AudioStreamPlayer = _players[key]
		p.pitch_scale = _pitch
		p.play()
	_playing = true


func _connect_signals() -> void:
	if _game != null:
		if _game.has_signal("chaos_scored"):
			_game.chaos_scored.connect(_on_chaos)
		if _game.has_signal("phase_changed"):
			_game.phase_changed.connect(_on_phase)
	if _subs != null:
		if _subs.has_signal("blackout_started"):
			_subs.blackout_started.connect(_on_blackout)
		if _subs.has_signal("blackout_ended"):
			_subs.blackout_ended.connect(_on_wake)
		if _subs.has_signal("substance_taken"):
			_subs.substance_taken.connect(_on_substance)
		if _subs.has_signal("combo_started"):
			_subs.combo_started.connect(_on_sub_combo)
	if _mission != null:
		if _mission.has_signal("objectives_ready"):
			_mission.objectives_ready.connect(_on_objectives_ready)
		if _mission.has_signal("objective_completed"):
			_mission.objective_completed.connect(_on_objective_done)
		if _mission.has_signal("hidden_revealed"):
			_mission.hidden_revealed.connect(_on_hidden)
		if _mission.has_signal("leg_decided"):
			_mission.leg_decided.connect(_on_leg_decided)
	if _prefs != null and _prefs.has_signal("pref_changed"):
		_prefs.pref_changed.connect(_on_pref_changed)


# ===========================================================================
# ---------------------------  PUBLIC API  ----------------------------------
# ===========================================================================

## Switch the bed. Accepts every mission zone id in `ZONE_STEMS` (`strip_mall`,
## `suburbia`, `cottage`, `corn`, `truckstop`, `stopover`), `migration`, `none`,
## and the aliases above. Unknown ids fall back to silence rather than to a wrong zone --
## a missing bed is a bug you notice, a wrong bed is a bug you ship.
##
## The check is against ZONE_STEMS, not STEMS: a zone is known if we know which
## stem set it plays, which is not the same as it owning one.
func set_zone(id: StringName) -> void:
	var z: StringName = id
	if ZONE_ALIASES.has(z):
		var alias: StringName = ZONE_ALIASES[z]
		z = alias
	if z != &"none" and not ZONE_STEMS.has(z):
		push_warning("Music: unknown zone '%s', going quiet." % String(id))
		z = &"none"
	if z == zone:
		return
	zone = z
	if z == &"migration":
		_mig_deadline = -1.0


## Which stem set the current zone plays, or &"" for silence.
func _live_set() -> StringName:
	var s: StringName = ZONE_STEMS.get(zone, &"")
	return s


## 0..1. Drives which layers are audible.
##
## This sets a FLOOR, not an absolute value: the final intensity is
## max(what you asked for, what the player's chaos/chemistry is asking for).
## Two reasons. First, it is sticky -- a caller that wants a fuller mix for
## the next thirty seconds says so once instead of every frame. Second, it
## cannot be used to accidentally disable the adaptive behaviour: a cutscene
## that pins 0.5 still lets a twelve-hit chain push the mix to 1.0, which is
## what anyone would actually want.
##
## `set_intensity(0.0)` hands control back to the game entirely.
func set_intensity(v: float) -> void:
	_manual_floor = clampf(v, 0.0, 1.0)


## Fire a one-shot on the sting bus. Ducks the bed a little so it reads.
func sting(key: StringName) -> void:
	if not _enabled or _stings.is_empty():
		return
	if not STINGERS.has(key):
		return
	var wav: StringName = STINGERS[key]
	var stream: AudioStream = _stream(wav, false)
	if stream == null:
		return
	var p: AudioStreamPlayer = _stings[_sting_next]
	_sting_next = (_sting_next + 1) % _stings.size()
	p.stream = stream
	p.volume_db = 0.0
	p.play()
	# 4 dB for a beat. Ducking a stinger under itself would be silly, which is
	# why stingers live on their own bus and only the bed moves.
	if key != &"blackout":
		duck(0.9, 4.0)


## Pull the bed down by `amount_db` and let it back over `seconds`. Attack is
## fast (~60 ms) and release is the full `seconds`, per the standard game-audio
## ducking shape -- slow attacks make the duck audible as a swell, which is
## worse than not ducking at all.
func duck(seconds: float = 0.6, amount_db: float = 6.0) -> void:
	var amt := absf(amount_db)
	if amt <= 0.0:
		return
	_duck_db = maxf(_duck_db, amt)
	_duck_span = maxf(_duck_span if _duck_left > 0.0 else 0.0, maxf(seconds, 0.05))
	_duck_left = _duck_span


func stop_all() -> void:
	for key in _players.keys():
		var p: AudioStreamPlayer = _players[key]
		p.stop()
		_gain[key] = 0.0
		p.volume_db = -80.0
	for s in _stings:
		s.stop()
	_playing = false


## Restart every layer in sync. Safe to call at any time; layers come back at
## whatever gain the current zone/intensity asks for.
func start() -> void:
	if not _enabled:
		return
	if _playing:
		return
	_start_all()


func is_enabled() -> bool:
	return _enabled


## For the headless harness and for anyone debugging the mix live.
func debug_state() -> Dictionary:
	var gains := {}
	for key in _gain.keys():
		var k: StringName = key
		var g: float = _gain[k]
		gains[k] = g
	return {
		"enabled": _enabled,
		"playing": _playing,
		"zone": zone,
		## Which stem set the zone is playing. Not always the same name -- the
		## corn borrows suburbia's and the truck stop borrows the cottage's.
		"stem_set": _live_set(),
		"floor": ZONE_FLOOR.get(zone, 0.0),
		"intensity": intensity,
		"gains": gains,
		"bed_db": AudioServer.get_bus_volume_db(_bed_idx) if _bed_idx >= 0 else 0.0,
		"music_db": AudioServer.get_bus_volume_db(_music_idx) if _music_idx >= 0 else 0.0,
		"music_muted": AudioServer.is_bus_mute(_music_idx) if _music_idx >= 0 else false,
		"cutoff": _lpf.cutoff_hz if _lpf != null else 0.0,
		"pitch": _pitch,
		"shift": _shift,
		"shift_on": (_shift_slot >= 0 and _bed_idx >= 0
			and AudioServer.is_bus_effect_enabled(_bed_idx, _shift_slot)),
		"duck_db": _duck_cur,
		"blackout": _blackout,
	}


# ===========================================================================
# -------------------------------  TICK  ------------------------------------
# ===========================================================================

func _process(delta: float) -> void:
	if not _enabled:
		return
	# Every timer in this file runs on REAL seconds. Under nitrous
	# Engine.time_scale is 0.45 and a 0.9 s duck release would otherwise take
	# two real seconds -- the mix would slow down along with the world, which
	# is a different (and much worse) design than the one we chose for pitch.
	var real := delta / maxf(Engine.time_scale, 0.05)
	_clock += real

	_read_substances(real)
	_update_intensity(real)
	_update_layers(real)
	_update_bed_bus(real)
	_update_filters(real)
	_watch_migration(real)
	_resync(real)


func _update_intensity(real: float) -> void:
	_heat = maxf(_heat - _heat * (real / HEAT_TAU), 0.0)

	var auto := 0.0
	if _game != null:
		var combo: int = int(_game.combo)
		auto = clampf(float(combo) / 8.0, 0.0, 1.0)
	auto = maxf(auto, _heat)

	# Adrenaline is a mix control. Caffeine and nitrous make the arrangement
	# busier even standing still, which is exactly what they do to you.
	var zf: float = ZONE_FLOOR.get(zone, 0.0)
	auto = maxf(auto, zf)

	# Adrenaline ADDS on top rather than competing with the floor. Caffeine
	# and nitrous should make whatever is already happening bigger, not clamp
	# it to a fixed value -- being wired while doing nothing and being wired
	# mid-chain are different states and should sound different.
	auto = clampf(auto + _adrenaline_push(), 0.0, 1.0)

	_intensity_target = maxf(auto, _manual_floor)

	if _clock < _floor_until:
		_intensity_target = maxf(_intensity_target, _floor_value)

	var tau := FADE_UP if _intensity_target > intensity else FADE_DOWN
	intensity = _slew(intensity, _intensity_target, real, tau)


func _update_layers(real: float) -> void:
	var lead_off := _clock < _lead_mute_until or _hud_amnesia()
	# Both looked up once, off the ZONE. Only the live set has a non-zero target,
	# so per-set tables would be dead code -- and the entry windows deliberately
	# belong to the zone rather than to the WAVs it happens to borrow.
	var live := _live_set()
	var tbl: Dictionary = ENTER_BY_ZONE.get(zone, ENTER)
	for zone_key in STEMS.keys():
		var zk: StringName = zone_key
		var roles: Dictionary = STEMS[zk]
		var here := (zk == live)
		for role_key in roles.keys():
			var rk: StringName = role_key
			var key := _key(zk, rk)
			if not _players.has(key):
				continue
			var target := 0.0
			if here:
				var w: Vector2 = tbl.get(rk, Vector2.ZERO)
				target = 1.0 if w.y <= w.x else smoothstep(w.x, w.y, intensity)
				if rk == &"lead" and lead_off:
					target = 0.0
			var cur: float = _gain[key]
			var tau := FADE_UP if target > cur else FADE_DOWN
			# Killing the melody is a GESTURE (blackout, amnesia), not an ebb.
			# It gets a fast fade so it reads as "the tune stopped", which is
			# the point, rather than as the mix quietly losing interest.
			if rk == &"lead" and lead_off:
				tau = 0.35
			cur = _slew(cur, target, real, tau)
			_gain[key] = cur
			var p: AudioStreamPlayer = _players[key]
			var db := linear_to_db(maxf(cur, 0.0001))
			if absf(db - p.volume_db) > EPS_DB:
				p.volume_db = db
			if absf(_pitch - p.pitch_scale) > EPS_PITCH:
				p.pitch_scale = _pitch


func _update_bed_bus(real: float) -> void:
	if _duck_left > 0.0:
		_duck_left = maxf(_duck_left - real, 0.0)
	var want := _duck_db * clampf(_duck_left / maxf(_duck_span, 0.001), 0.0, 1.0)
	# Fast in, ramp-governed out.
	var tau := 0.06 if want > _duck_cur else 0.20
	_duck_cur = _slew(_duck_cur, want, real, tau)
	if _duck_left <= 0.0 and _duck_cur < 0.05:
		_duck_db = 0.0
		_duck_cur = 0.0

	var target_db := _bed_db - _duck_cur
	if _bed_idx >= 0:
		var cur := AudioServer.get_bus_volume_db(_bed_idx)
		var next := _slew(cur, target_db, real, 0.10)
		if absf(next - cur) > EPS_DB or (absf(next - target_db) <= EPS_DB
				and absf(cur - target_db) > EPS_DB):
			AudioServer.set_bus_volume_db(_bed_idx, next)


func _update_filters(real: float) -> void:
	if _lpf != null:
		# Interpolate the cutoff in LOG space. A linear sweep from 20 kHz to
		# 180 Hz spends 95% of its time in the top octave and then falls off a
		# cliff; in log space it reads as a filter closing evenly.
		var cur := maxf(_lpf.cutoff_hz, 20.0)
		var tau := 0.12 if _cut < cur else 0.9   # slam shut, open slowly
		var lg := _slew(log(cur), log(maxf(_cut, 20.0)), real, tau)
		var next := clampf(exp(lg), 20.0, 20500.0)
		if absf(next - cur) / cur > EPS_CUT:
			_lpf.cutoff_hz = next

	if _shifter != null and _shift_slot >= 0 and _bed_idx >= 0:
		var want_on := absf(_shift - 1.0) > 0.012
		var is_on := AudioServer.is_bus_effect_enabled(_bed_idx, _shift_slot)
		if want_on != is_on:
			AudioServer.set_bus_effect_enabled(_bed_idx, _shift_slot, want_on)
		if want_on:
			var next := _slew(_shifter.pitch_scale, _shift, real, 0.25)
			if absf(next - _shifter.pitch_scale) > EPS_PITCH:
				_shifter.pitch_scale = next
		elif _shifter.pitch_scale != 1.0:
			_shifter.pitch_scale = 1.0


func _slew(cur: float, target: float, real: float, tau: float) -> float:
	if tau <= 0.0:
		return target
	return lerpf(cur, target, 1.0 - exp(-real / tau))


# ===========================================================================
# ---------------------------  SUBSTANCES  ----------------------------------
# ===========================================================================
#
# This is the part that justifies the whole file. The game is about what
# chemicals do to a goose; a score that ignores them is a score that has
# opted out of the premise.

func _read_substances(real: float) -> void:
	var cut := 20000.0
	var pitch := 1.0
	var shift := 1.0
	var bed := 0.0

	if _blackout:
		_wake_until = -1.0
		# ------------------------------------------------------------------
		# BLACKOUT. Three seconds, and it is allowed to be extreme because it
		# is three seconds and because it is the loudest structural event in
		# the game. The bed does not fade -- it collapses: -34 dB, the filter
		# slams to 180 Hz, the transport drags to 0.55x. What you are left
		# with is the low thud of music happening in another room, which is
		# what passing out actually sounds like.
		#
		# The memorable half is the RECOVERY, handled in _on_wake(): the tune
		# stays gone for eight seconds after you come round. Silence where a
		# melody used to be is the single most effective anti-loop-fatigue
		# device there is (Halo used it deliberately), and here it costs
		# nothing because the game has already justified it.
		# ------------------------------------------------------------------
		_cut = 180.0
		_pitch = _slew(_pitch, 0.55, real, 0.18)
		_shift = 1.0
		_bed_db = -34.0
		return

	# Coming round. The bed climbs back over ~2.6 s and the filter sweeps open
	# behind it, so waking up is a gesture rather than a cut. The melody is
	# handled separately and stays away far longer -- see _on_wake().
	if _clock < _wake_until:
		var k := clampf((_wake_until - _clock) / WAKE_RECOVER, 0.0, 1.0)
		bed -= 26.0 * k * k
		cut = minf(cut, lerpf(20000.0, 300.0, k))

	if _subs != null:
		var mods: Dictionary = _subs.mods
		var brain: Dictionary = _subs.brain

		# -- TAPE SPEED ----------------------------------------------------
		# The nitrous question, decided on purpose.
		#
		# Godot's audio thread ignores Engine.time_scale, so doing nothing
		# means "the music RESISTS": the world goes to syrup and the band
		# plays on at full speed. We reject that. The entire identity of this
		# score is a cassette in a cold car, and a tape transport slowing
		# down is the most legible sound there is. If the picture drags and
		# the tape doesn't, the gag has no soundtrack.
		#
		# But we don't follow it linearly either. Mapping time_scale 0.45
		# straight onto playback rate is more than an octave down: the fiddle
		# becomes a foghorn, 84 BPM becomes 38 BPM, and every layer we placed
		# in its own frequency band lands on top of the bass. Funny once.
		# Unbearable by leg two.
		#
		# So: pitch = time_scale ^ 0.45, clamped to [0.72, 1.10]. Nitrous
		# lands on the 0.72 floor -- a minor third down, unmistakably a
		# transport dragging, still musical, still countable in 4. Asymmetric
		# slew (0.30 s down, 0.85 s up) so it spools like a motor.
		#
		# And we read Subs.mods.time_scale -- the substance system's INTENT --
		# never Engine.time_scale itself. Juice dips Engine.time_scale for
		# hitstop on every impact; a score that warbles each time you clip a
		# shopping cart is not a broken tape, it's a broken score. This is the
		# same rule juice.gd states for itself, for the same reason.
		var ts: float = mods.get("time_scale", 1.0)
		pitch = clampf(pow(clampf(ts, 0.05, 4.0), 0.45), 0.72, 1.10)

		# -- FILTER --------------------------------------------------------
		# GABA is the "everything is soft and far away" axis. A lowpass is
		# literally that, so it gets mapped straight onto one.
		var gaba: float = brain.get("gaba", 0.40)
		var g := clampf((gaba - 0.40) / 0.60, 0.0, 1.0)
		cut = lerpf(20000.0, 2400.0, g)

		# Slow-mo FX branch (nitrous and friends) closes it further -- a
		# dragging tape loses its top end, always has.
		var fx_mode: int = int(mods.get("fx_mode", 0))
		var fx_str: float = mods.get("fx_strength", 0.0)
		if fx_mode == 3:
			cut = minf(cut, lerpf(20000.0, 3600.0, clampf(fx_str, 0.0, 1.0)))

		# Comedown: the world goes grey and so does the mix. This is the only
		# effect the player never chose, so it is the only one that is purely
		# subtractive -- no wobble, no sparkle, just less.
		if bool(_subs.in_comedown()):
			cut = minf(cut, 2600.0)
			bed -= 2.0

		# Dopamine opens it back up a little. Chemical brightness, rendered
		# as actual brightness.
		var dopa: float = brain.get("dopamine", 0.40)
		cut *= 1.0 + 0.5 * clampf((dopa - 0.40) / 0.60, 0.0, 1.0)

		# -- MUSICAL DETUNE (pitch-shift effect, not tape speed) -----------
		# MACROPSIA. fly agaric makes the goose pulse between tiny and huge;
		# the music is tied to the SAME clock, so as you grow the score drops
		# and as you shrink it rises. Your size and the music's register
		# become the same variable. It costs one sine call and it is the best
		# idea in this file.
		var amp: float = mods.get("scale_amp", 0.0)
		if amp > 0.01:
			var period: float = mods.get("scale_period", 7.0)
			var phase := TAU * _clock / maxf(period, 0.5)
			shift *= pow(2.0, -0.42 * clampf(amp, 0.0, 2.0) * sin(phase))

		# Deliriants: a slow wandering detune that never settles, because
		# nothing about a deliriant settles. Two incommensurate sines so it
		# doesn't read as vibrato.
		var hal: float = mods.get("hallucinate", 0.0)
		if hal > 0.05:
			var w := 0.035 * clampf(hal, 0.0, 1.0)
			shift *= 1.0 + w * (sin(_clock * 0.37) * 0.6 + sin(_clock * 0.113) * 0.4)

		shift = clampf(shift, 0.55, 1.85)

	_cut = cut
	_shift = shift
	_bed_db = bed
	var ptau := 0.30 if pitch < _pitch else 0.85
	_pitch = _slew(_pitch, pitch, real, ptau)


func _adrenaline_push() -> float:
	if _subs == null:
		return 0.0
	var brain: Dictionary = _subs.brain
	var adr: float = brain.get("adrenaline", 0.40)
	return 0.42 * clampf((adr - 0.45) / 0.55, 0.0, 1.0)


## Benzos wipe the HUD (`hud_amnesia`). The tune is the melodic HUD -- it is
## the thing that tells you where you are in the bar. So it goes too, and you
## are left with a bed and a backbeat and no idea how long you've been here.
## Played completely straight, which is why it works.
func _hud_amnesia() -> bool:
	if _subs == null:
		return false
	var mods: Dictionary = _subs.mods
	var am: bool = mods.get("hud_amnesia", false)
	return am


# ===========================================================================
# ------------------------------  SIGNALS  ----------------------------------
# ===========================================================================

func _on_chaos(_amount: int, _total: int, combo: int, _label: String) -> void:
	_heat = clampf(maxf(_heat, 0.18 + 0.06 * float(combo)), 0.0, 1.0)


func _on_phase(phase: int) -> void:
	if _game == null:
		return
	if phase == 0:                          # Phase.ZONE
		_mig_deadline = -1.0
		var zid: StringName = &"none"
		if _mission != null:
			var mz: StringName = _mission.zone_id
			zid = mz
		set_zone(zid)
	elif phase == 1:                        # Phase.MIGRATION
		# Go quiet FIRST. The leg-decided stinger and the results card land in
		# this gap, and they need the room. The flight cue comes in when the
		# Migration node actually exists (see _watch_migration).
		set_zone(&"none")
		_mig_deadline = _clock + 12.0
	else:                                    # Phase.RESULTS
		set_zone(&"none")


func _on_objectives_ready(_list: Array) -> void:
	if _mission == null:
		return
	var zid: StringName = _mission.zone_id
	set_zone(zid)


func _on_objective_done(_id: StringName, kind: int, _reward: int) -> void:
	# kind 2 is HIDDEN; that gets its own cue from hidden_revealed, which
	# fires alongside. Don't play both.
	if kind == 2:
		return
	sting(&"objective")


func _on_hidden(_id: StringName, _title: String, _line: String, _reward: int) -> void:
	sting(&"hidden")


func _on_leg_decided(result: Dictionary) -> void:
	var passed: bool = result.get("passed", false)
	sting(&"leg_pass" if passed else &"leg_fail")


func _on_substance(_res, _dose: float, _resolved: Dictionary) -> void:
	# Short duck so the gulp/hiss SFX reads over the bed, plus a nudge to the
	# arrangement: taking something should audibly commit the band.
	duck(0.45, 5.0)
	_heat = maxf(_heat, 0.30)


func _on_sub_combo(_name: String) -> void:
	# A named combo is the game's biggest positive moment. The score's answer
	# is not a joke sound -- it is to stop hedging and play everything, for
	# six seconds, straight-faced.
	_floor_value = 1.0
	_floor_until = _clock + 6.0
	duck(0.5, 3.0)


func _on_blackout() -> void:
	_blackout = true
	_duck_left = 0.0
	_duck_db = 0.0
	sting(&"blackout")


func _on_wake() -> void:
	_blackout = false
	sting(&"wake")
	# The melody stays away for eight seconds after you come round. See the
	# long comment in _read_substances().
	_lead_mute_until = _clock + 8.0
	_wake_until = _clock + WAKE_RECOVER


func _on_pref_changed(key: StringName, _value) -> void:
	if key == &"music_volume" or key == &"master_volume":
		_apply_music_volume()


## Prefs owns the Music bus VOLUME (it already writes it in _apply_audio()).
## We own only the mute flag, because Prefs clamps to 0.0001 -> -80 dB, and
## "-80 dB" is not the same promise as "off". A slider at zero must be silence,
## not very quiet.
func _apply_music_volume() -> void:
	if _music_idx < 0:
		return
	var v := 0.6
	if _prefs != null:
		var pv: float = _prefs.get_pref(&"music_volume", 0.6)
		v = pv
	AudioServer.set_bus_volume_db(_music_idx,
		linear_to_db(clampf(v, 0.0001, 1.0)))
	AudioServer.set_bus_mute(_music_idx, v <= 0.001)


# ===========================================================================
# ----------------------------  HOUSEKEEPING  -------------------------------
# ===========================================================================

## Zero-integration hook for the flight cue. main.gd builds the migration as a
## node literally named "Migration"; when it shows up, the music knows the
## results card is gone and the birds are in the air. If migration.gd calls
## Music.set_zone(&"migration") directly (the documented one-liner) this never
## has to fire. The 12 s deadline is the backstop for both.
func _watch_migration(real: float) -> void:
	if _mig_deadline < 0.0 or zone == &"migration":
		return
	_mig_watch -= real
	if _mig_watch > 0.0:
		return
	_mig_watch = 0.25
	var tree := get_tree()
	if tree != null and tree.root != null:
		var n := tree.root.find_child("Migration", true, false)
		if n != null:
			set_zone(&"migration")
			return
	if _clock >= _mig_deadline:
		set_zone(&"migration")


## Drift insurance. Every stem is the same length and every stem gets the same
## pitch in the same frame, so this should never do anything -- but "should
## never" is not "cannot", and a layer that has slipped 40 ms is a layer that
## sounds like a mistake. We only ever correct a player that is currently
## inaudible, so the correction itself can never be heard.
func _resync(real: float) -> void:
	if not _playing:
		return
	_resync_t -= real
	if _resync_t > 0.0:
		return
	_resync_t = RESYNC_EVERY
	var live := _live_set()
	var ref_key := _key(live if STEMS.has(live) else &"strip_mall", &"base")
	if not _players.has(ref_key):
		return
	var ref: AudioStreamPlayer = _players[ref_key]
	if not ref.playing:
		return
	var ref_pos := ref.get_playback_position()
	for key in _players.keys():
		var k: StringName = key
		if k == ref_key:
			continue
		var g: float = _gain[k]
		if g > 0.02:
			continue                       # audible: never touch it
		var p: AudioStreamPlayer = _players[k]
		if not p.playing:
			p.play()
			p.seek(ref_pos)
			continue
		var d := absf(p.get_playback_position() - ref_pos)
		# Ignore a whole-loop wrap: two players can be 45.7 s "apart" and
		# perfectly in phase.
		var len_s := 0.0
		var st: AudioStream = p.stream
		if st != null:
			len_s = st.get_length()
		if len_s > 0.0:
			d = minf(d, absf(len_s - d))
		if d > RESYNC_TOL:
			p.seek(ref_pos)
