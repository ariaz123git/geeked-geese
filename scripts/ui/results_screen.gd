extends CanvasLayer
## THE LEG RESULTS SCREEN — the game's only moment of reflection.
##
## Shown after the zone clock expires and `Mission.end_leg()` has decided the
## leg, BEFORE the migration briefing. It is the one place the player stops
## moving, so it has to do three jobs and no more:
##
##   1. Tell them what they DID, not just what they scored.
##   2. Land a verdict they feel.
##   3. Make the CONSEQUENCE legible, because a gate the player can't see is a
##      gate that isn't in the game.
##
## ── RESEARCH, AND WHAT WAS TAKEN FROM IT ────────────────────────────────
##
## **Reveal slowly; never dump.** Dave Strachan's breakdown of scoring systems
## is unambiguous that "slowly revealing scores at the end of a level with
## bonuses ... slamming down onto the screen makes people happy", and that a
## score sitting on screen the whole time goes unread — "hiding it for a period
## and then revealing it ... stops the player just becoming saturated and blind
## to the score". Our chaos counter is in the HUD for three solid minutes, so
## this screen deliberately does NOT restate it. It takes it apart into
## chaos / style / secrets and rebuilds it in front of the player. Same number;
## first time they've actually looked at it.
##
## **The rank is the payoff, not the number.** Same source: "going from 5600 to
## 6100 is unlikely to be noticed" but "a different coloured B they are more
## likely to notice". So the grade is not a field in a table. It is the last
## thing to happen, it arrives after a deliberate beat of silence, it overshoots
## its scale, it flashes the screen and it kicks the card. Everything before it
## is setup for that one frame.
##
## **A held beat before the payoff.** The reward-design writing on Soulsborne
## victory moments makes the same point in another genre: "a moment of silence
## and triumphant visuals" is what lets a win land. There is a deliberate ~0.45s
## of nothing between the last line of data and the grade. It is not dead time;
## it is the setup.
##
## **Bonuses, never penalties.** "It's far better to give a bonus" than to take
## points away — subtraction framing produces dissatisfaction even when the
## player agrees with the rule perfectly. So the clock consequence is always
## headlined as the clock you GET (a positive quantity, "2:20 IN THE NEXT
## ZONE"), with the arithmetic underneath as an explanation. This screen never
## renders a big red minus.
##
## **Never make anyone watch a number tick.** Unskippable victory screens are
## the single most-complained-about friction in the games that have them (the
## recurring "please let players disable them to speed things up" thread). ANY
## key, pad button or click fast-forwards straight to the grade beat — and the
## grade still gets its sting, because skipping the tally must not cost you the
## payoff. Holding also runs the tally at 6x. A second press dismisses.
##
## **Roguelike run summaries sell the run, not the spreadsheet.** What makes a
## post-run screen worth reading is the narrative of what happened, which is why
## hidden objectives are listed BY NAME here, with their punchlines. Finding one
## mid-zone buys a two-second banner; this is where you get to keep it.
##
## ── INTEGRATION ─────────────────────────────────────────────────────────
##   var res := preload("res://scripts/ui/results_screen.gd").new()
##   res.name = "Results"
##   add_child(res)
##   res.show_result(Mission.end_leg(), zone_title)
##   await res.continued
##
## It pauses the tree itself and hands the mouse back the way it found it, so
## the caller manages neither.

signal continued

## Above the HUD (2), the mission HUD (3) and the briefing (25); below the pause
## menu (30) so Escape can still reach that.
const LAYER := 28

const FONT_OK := Color(0.62, 0.93, 0.66)
const FONT_DIM := Color(0.55, 0.59, 0.67)
const C_GOLD := Color(0.99, 0.80, 0.30)
const C_SECRET := Color(1.00, 0.62, 0.86)
const C_CHAOS := Color(0.98, 0.55, 0.34)
const C_STYLE := Color(0.55, 0.80, 0.98)
const C_WARN := Color(0.99, 0.74, 0.40)
const C_PLATE := Color(0.045, 0.05, 0.082, 0.985)

## Indexed by grade_index 0..5 == F D C B A S.
const GRADE_COL := [
	Color(0.80, 0.36, 0.33),
	Color(0.86, 0.54, 0.34),
	Color(0.89, 0.77, 0.39),
	Color(0.56, 0.88, 0.61),
	Color(0.45, 0.81, 0.99),
	Color(1.00, 0.85, 0.35),
]

## Design canvas. Fixed size, uniformly scaled, centred — the single most
## reliable way to be correct at 1280x720 and 1920x1080 at the same time: there
## is no anchoring to get wrong, because there is only one rectangle.
const CARD_W := 1150.0
const CARD_PAD := 30.0
const CARD_INNER := CARD_W - CARD_PAD * 2.0
const LCOL := 410.0
const COL_GAP := 44.0
## Allowed to grow on big screens so 1080p isn't a small card marooned in black.
const MAX_UPSCALE := 1.30

## How long after the grade lands before a press will dismiss. Stops the same
## press that skipped the tally from also closing the screen.
const GRADE_LOCKOUT := 0.34

var _sfx: Node = null
var _mission: Node = null
var _flock: Node = null

var _open := false
var _t := 0.0
var _tick_acc := 0.0
var _fired: Dictionary = {}
var _shake := 0.0
var _lockout := 0.0
## Probe only: halts the timeline so a render can catch a mid-punch frame.
var _frozen := false
var _restore_mouse: int = Input.MOUSE_MODE_VISIBLE

var _backdrop: ColorRect = null
var _flash: ColorRect = null
var _card: Control = null


func _ready() -> void:
	# ALWAYS, not WHEN_PAUSED: this node owns the paused state, so it has to
	# keep running across the frame on which it flips it.
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = LAYER
	visible = false
	_sfx = get_node_or_null("/root/Sfx")
	_mission = get_node_or_null("/root/Mission")
	_flock = get_node_or_null("/root/Flock")

	_backdrop = ColorRect.new()
	_backdrop.name = "Backdrop"
	_backdrop.color = Color(0.015, 0.018, 0.032, 0.94)
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)

	_flash = ColorRect.new()
	_flash.name = "Flash"
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

	get_viewport().size_changed.connect(_reflow)


# ════════════════════════════════════════════════════════════ PUBLIC API

func is_open() -> bool:
	return _open


## Present the dictionary returned by `Mission.end_leg()` (identically, the one
## carried by `Mission.leg_decided`). `zone_title` is cosmetic — pass
## `zone.zone_title()` if the zone has one; otherwise the zone id is prettified.
func show_result(result: Dictionary, zone_title: String = "") -> void:
	if _open:
		return
	_t = 0.0
	_tick_acc = 0.0
	_shake = 0.0
	_frozen = false
	_lockout = 0.0
	_fired.clear()

	if _card != null and is_instance_valid(_card):
		_card.queue_free()
	_card = Card.new()
	_card.name = "Card"
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.setup(_gather(result, zone_title))
	add_child(_card)
	_place_card()

	_open = true
	visible = true
	_flash.color = Color(1, 1, 1, 0)
	_restore_mouse = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	if _sfx != null:
		_sfx.play(&"unlock", -10.0, 0.70)


## Close it from code — the phase got yanked out from under us.
func force_close() -> void:
	if _open:
		_dismiss()


## Dev/probe hook: jump the reveal to an absolute point on the timeline.
func debug_seek(to: float) -> void:
	if not _open:
		return
	_frozen = true
	for k in ["head", "chaos", "style", "total", "par", "obj", "sec", "flock", "next"]:
		_fired[k] = true
	if to >= Beats.T_GRADE:
		_fired["grade"] = true
	_t = to
	if _card != null and is_instance_valid(_card):
		_card.t = _t
		_card.queue_redraw()
	_place_card()


# ════════════════════════════════════════════════════════ DATA GATHERING
#
# Every read out of the result dictionary is a Variant, so every one of them is
# annotated on the way out. The typed helpers below exist so the call sites can
# use `:=` without the parser losing the type.

func _di(d: Dictionary, k: String, fb: int) -> int:
	if not d.has(k):
		return fb
	return int(d[k])


func _df(d: Dictionary, k: String, fb: float) -> float:
	if not d.has(k):
		return fb
	return float(d[k])


func _ds(d: Dictionary, k: String, fb: String) -> String:
	if not d.has(k):
		return fb
	return str(d[k])


func _db(d: Dictionary, k: String, fb: bool) -> bool:
	if not d.has(k):
		return fb
	return bool(d[k])


func _da(d: Dictionary, k: String) -> Array:
	if not d.has(k):
		return []
	var v: Variant = d[k]
	if v is Array:
		return v
	return []


func _dsub(d: Dictionary, k: String) -> Dictionary:
	if not d.has(k):
		return {}
	var v: Variant = d[k]
	if v is Dictionary:
		return v
	return {}


## Flatten the mission result plus the two live queries (objective names, flock
## condition) into one plain dictionary, so the drawing code never touches an
## autoload mid-frame and the card can be tested with a hand-written dict.
func _gather(result: Dictionary, zone_title: String) -> Dictionary:
	var breakdown := _dsub(result, "breakdown")

	var title := _strip_leg(zone_title)
	if title == "":
		title = _pretty(_ds(result, "zone", "the lot"))

	# ── objectives: ids -> the lines the player read in the HUD all leg ──
	var done_rows: Array[Dictionary] = []
	var missed_rows: Array[Dictionary] = []
	for id in _da(result, "completed"):
		done_rows.append(_row_for(StringName(id)))
	for id2 in _da(result, "missed"):
		missed_rows.append(_row_for(StringName(id2)))
	# Required work first in both lists: the primaries are what the pass
	# condition is about, so a bonus must never push one off the bottom.
	done_rows.sort_custom(_by_kind)
	missed_rows.sort_custom(_by_kind)

	# ── hidden objectives, BY NAME. This is the payment for finding them. ──
	var secrets: Array[Dictionary] = []
	for id3 in _da(result, "hidden_found"):
		var sid: StringName = StringName(id3)
		var r := _row_for(sid)
		var t3: String = str(r.get("title", ""))
		if t3 == "":
			t3 = _pretty(String(sid))
		secrets.append({
			"title": t3,
			"line": str(r.get("line", "")),
			"reward": int(r.get("reward", 0)),
		})

	# ── the flock, going into the flight ──
	var birds: Array[Dictionary] = []
	var summary := ""
	var leads := 0
	if _flock != null:
		if _flock.has_method("condition_summary"):
			summary = str(_flock.condition_summary())
		if _flock.has_method("lead_candidates"):
			var lc: Array = _flock.lead_candidates()
			leads = lc.size()
		var raw: Array = _flock.birds
		for i in raw.size():
			var b: Dictionary = raw[i]
			if not bool(b.get("alive", true)):
				continue
			var can := false
			if _flock.has_method("can_lead"):
				can = bool(_flock.can_lead(i))
			birds.append({
				"name": str(b.get("name", "?")),
				"intox": float(b.get("intox", 0.0)),
				"stamina": float(b.get("stamina", 1.0)),
				"is_dd": bool(b.get("is_dd", false)),
				"can_lead": can,
			})

	var best_combo := 0
	if _mission != null and _mission.has_method("stat"):
		best_combo = int(_mission.stat(&"peak_combo"))

	return {
		"leg": _di(result, "leg", 1),
		"zone_title": title,
		"passed": _db(result, "passed", false),
		"required": _di(result, "required", 2),
		"primaries_total": _di(result, "primaries_total", 0),
		"primaries_done": _di(result, "primaries_done", 0),
		"chaos": _di(breakdown, "chaos", 0),
		"style": _di(breakdown, "style", 0),
		"hidden_pts": _di(breakdown, "hidden", 0),
		"obj_pts": _di(breakdown, "objectives", 0),
		"total": _di(breakdown, "total", 0),
		"par": maxi(1, _di(breakdown, "par", 1)),
		"grade": _ds(result, "grade", "F"),
		"grade_index": clampi(_di(result, "grade_index", 0), 0, 5),
		"rank_text": _ds(result, "rank_text", ""),
		"flock_note": _ds(result, "flock_note", ""),
		"modifier": _df(result, "zone_time_modifier", 0.0),
		"next_secs": _df(result, "next_zone_seconds", 180.0),
		# The next leg's ROUTE clock before the mission modifier. The card used to
		# hard-code "3:00 base" in the explanation line, which was a second copy
		# of the same 180 assumption that made the promised clock wrong — leg 5's
		# base is 2:30. Falls back to next_secs (i.e. "base, unchanged") rather
		# than to 180, so an older result dict can't reintroduce the lie.
		"next_base": _df(result, "next_zone_base", _df(result, "next_zone_seconds", 180.0)),
		# The same promise if the flight lands short — the other soft fail, which
		# the card names so the two never read as one rule. main.gd takes the
		# minute off the BASE and then clamps, so this is computed through
		# Mission's clamp rather than by subtracting 60 from the promised clock:
		# on leg 5 (2:30 base) the clamp floor bites and a naive subtraction would
		# print a clock the game will not hand out. Which is this whole bug.
		"next_secs_short": _short_clock(result),
		"hidden_total": _di(result, "hidden_total", 0),
		"done_rows": done_rows,
		"missed_rows": missed_rows,
		"secrets": secrets,
		"birds": birds,
		"flock_summary": summary,
		"leads": leads,
		"best_combo": best_combo,
	}


## What the next zone's clock becomes if the flight lands short: main.gd's
## `base - 60`, plus the same mission modifier, through the same clamp. Goes
## through `Mission.clamp_zone_seconds()` so there is one owner of the range;
## the literals are only reached if this card is driven without the autoload.
func _short_clock(result: Dictionary) -> float:
	var base := _df(result, "next_zone_base", _df(result, "next_zone_seconds", 180.0))
	var raw := base - 60.0 + _df(result, "zone_time_modifier", 0.0)
	if _mission != null and _mission.has_method("clamp_zone_seconds"):
		return float(_mission.clamp_zone_seconds(raw))
	return clampf(raw, 110.0, 240.0)


func _by_kind(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("kind", 9)) < int(b.get("kind", 9))


func _row_for(id: StringName) -> Dictionary:
	if _mission != null and _mission.has_method("objective_row"):
		var r: Dictionary = _mission.objective_row(id)
		if not r.is_empty():
			return r
	return {"id": id, "text": _pretty(String(id)), "kind": 0, "title": "", "line": "", "reward": 0}


static func _pretty(s: String) -> String:
	return s.replace("_", " ").to_upper()


## Zones name themselves "LEG 1 — STRIP MALL LOT", and the header already says
## which leg it was, so passing zone_title() straight through renders
## "LEG 1 · LEG 1 — STRIP MALL LOT". Strip the zone's own leg prefix rather than
## making every integrator remember not to send one.
static func _strip_leg(s: String) -> String:
	var t := s.strip_edges()
	if not t.to_upper().begins_with("LEG "):
		return t
	for sep in [" — ", " – ", " - ", " · "]:
		var i := t.find(sep)
		if i > 0:
			return t.substr(i + sep.length()).strip_edges()
	return t


# ═══════════════════════════════════════════════════════════ LOOP + INPUT

func _process(delta: float) -> void:
	if not _open:
		return
	# Re-assert. If anything else unpauses while the card is up, the phase
	# behind it starts ticking unwatched.
	if not get_tree().paused:
		get_tree().paused = true

	# Wall-clock, not scaled. Substances leave Engine.time_scale anywhere and
	# the tally must not run at half speed because the player was on a whippet.
	var real := delta / maxf(Engine.time_scale, 0.05)

	# HOLD to fast-forward as well as press-to-skip. Some players hold and some
	# tap; punishing either is a fail.
	var rate := 1.0
	if _t < Beats.T_GRADE and _held():
		rate = 6.0
	var prev := _t
	if not _frozen:
		_t += real * rate
	_beats(prev, _t, real * rate)

	if _lockout > 0.0:
		_lockout = maxf(0.0, _lockout - real)

	_shake = maxf(0.0, _shake - real * 3.4)
	if _flash != null:
		var fa: float = _flash.color.a
		_flash.color = Color(1, 1, 1, maxf(0.0, fa - real * 3.0))

	if _card != null and is_instance_valid(_card):
		_card.t = _t
		_card.queue_redraw()
		_place_card()


func _held() -> bool:
	for a in ["ui_accept", "gg_skip", "gg_flap", "gg_honk"]:
		if InputMap.has_action(a) and Input.is_action_pressed(a):
			return true
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)


func _input(event: InputEvent) -> void:
	if not _open:
		return
	var is_press := false
	if event is InputEventKey and event.pressed and not event.echo:
		is_press = true
	elif event is InputEventJoypadButton and event.pressed:
		is_press = true
	elif event is InputEventMouseButton and event.pressed:
		is_press = true
	if not is_press:
		return

	# Nothing reaches the paused phase behind the card, and critically the pause
	# menu never opens underneath it.
	get_viewport().set_input_as_handled()

	if _t < Beats.T_GRADE:
		_skip()
		return
	if _lockout <= 0.0:
		_dismiss()


## Collapse the tally. Deliberately lands just BEFORE the grade beat rather than
## after it: skipping the numbers must not cost you the payoff, which is the
## only part of this screen anyone actually wanted.
func _skip() -> void:
	for k in ["head", "chaos", "style", "total", "par", "obj", "sec", "flock", "next"]:
		_fired[k] = true
	_t = Beats.T_GRADE - 0.001
	if _card != null and is_instance_valid(_card):
		_card.t = _t


# ── audio + punch, edge-triggered off the timeline ──────────────────────

func _beats(t0: float, t1: float, real: float) -> void:
	_cross(t0, t1, Beats.T_HEAD, "head", &"score_blip", -15.0, 0.80)
	_cross(t0, t1, Beats.T_CHAOS, "chaos", &"score_blip_hi", -13.0, 0.90)
	_cross(t0, t1, Beats.T_STYLE, "style", &"score_blip_hi", -13.0, 1.00)
	# No blip at the old T_SECRETS: SECRETS is no longer a row in the left column
	# (it is an itemisation of CHAOS, not an addend — see Card.setup), and a
	# rising tally blip with nothing arriving under it is a bug you can hear.
	# The secrets still get their own cue at T_SEC, with the named list.
	_cross(t0, t1, Beats.T_OBJ, "obj", &"score_blip", -18.0, 1.15)
	_cross(t0, t1, Beats.T_TOTAL, "total", &"score_blip_hi", -10.0, 0.72)
	_cross(t0, t1, Beats.T_PAR, "par", &"score_blip", -17.0, 1.35)
	_cross(t0, t1, Beats.T_SEC, "sec", &"unlock", -13.0, 1.05)
	_cross(t0, t1, Beats.T_FLOCK, "flock", &"score_blip", -18.0, 0.95)
	_cross(t0, t1, Beats.T_NEXT, "next", &"thud_land", -15.0, 1.25)

	# ── the count-up tick, rising in pitch as the number climbs ──
	# Rate-limited hard: Sfx has a 16-slot pool, and an ungated tick at 60Hz both
	# machine-guns it and steals every other one-shot on the screen.
	if _card != null and is_instance_valid(_card):
		# _card is typed Control, so this call is a Variant. Annotate or the
		# parser refuses it outright — `var x := <Variant>` is a hard error.
		var frac: float = _card.tick_progress(t1)
		if frac >= 0.0:
			_tick_acc += real
			if _tick_acc >= 0.045:
				_tick_acc = 0.0
				if _sfx != null:
					# 0.78 -> 1.95 across the run of the number. The rising pitch
					# is the entire reason a tally feels like it's going somewhere
					# instead of merely taking a while.
					_sfx.play(&"score_blip", -21.0, lerpf(0.78, 1.95, clampf(frac, 0.0, 1.0)))
		else:
			_tick_acc = 0.045

	# ── the grade. The payoff beat. ──
	if t0 < Beats.T_GRADE and t1 >= Beats.T_GRADE and not _fired.has("grade"):
		_fired["grade"] = true
		_grade_sting()


func _grade_sting() -> void:
	_lockout = GRADE_LOCKOUT
	# ACCESSIBILITY. This card is 2D, so it cannot go through Juice's shake bus
	# (that bus drives a Camera3D's offsets), but the PREFS are not optional and
	# they were being ignored here: a player with screen shake at 0 still got a
	# card thrown +/-12 px, and a player with FX at 0 still got a full-screen
	# white flash at 30% alpha. Both are exactly what those two sliders exist to
	# switch off. Scaled from Juice so there is one interpretation of the prefs
	# in the codebase and this never drifts out of sync with the 3D side again.
	_shake = 1.0 * clampf(Juice.shake_scale(), 0.0, 1.0)
	var fx := clampf(Juice.fx_scale(), 0.0, 1.0)
	var gi := 0
	if _card != null and is_instance_valid(_card):
		gi = int(_card.grade_index)
	var g := float(gi) / 5.0
	if _flash != null:
		_flash.color = Color(1, 1, 1, lerpf(0.09, 0.30, g) * fx)
	if _sfx == null:
		return
	# Pitch tracks the grade, so an S sounds like an S before you've read it.
	_sfx.play(&"crash_heavy", -12.0, lerpf(0.80, 1.15, g))
	_sfx.play(&"unlock", -5.0, lerpf(0.74, 1.30, g))


func _cross(t0: float, t1: float, at: float, key: String, snd: StringName,
		db: float, pitch: float) -> void:
	if _fired.has(key):
		return
	if t0 >= at or t1 < at:
		return
	_fired[key] = true
	if _sfx != null:
		_sfx.play(snd, db, pitch)


# ══════════════════════════════════════════════════════════════ LAYOUT

func _reflow() -> void:
	if _card == null or not is_instance_valid(_card):
		return
	_card.measure()
	_place_card()


func _place_card() -> void:
	if _card == null or not is_instance_valid(_card):
		return
	var vs := get_viewport().get_visible_rect().size
	var want: Vector2 = _card.card_size
	var s: float = minf((vs.x - 40.0) / want.x, (vs.y - 28.0) / want.y)
	s = clampf(s, 0.30, MAX_UPSCALE)
	_card.size = want
	_card.pivot_offset = Vector2.ZERO
	var isc: float = _card.intro_scale()
	_card.scale = Vector2(s, s) * isc
	var drawn: Vector2 = want * _card.scale
	var jitter := Vector2.ZERO
	if _shake > 0.001:
		var k: float = _shake * _shake * 12.0
		jitter = Vector2(randf_range(-k, k), randf_range(-k, k))
	_card.position = ((vs - drawn) * 0.5).round() + jitter


func _dismiss() -> void:
	if not _open:
		return
	_open = false
	visible = false
	if _card != null and is_instance_valid(_card):
		_card.queue_free()
	_card = null
	get_tree().paused = false
	Input.mouse_mode = _restore_mouse
	if _sfx != null:
		_sfx.play(&"score_blip_hi", -12.0, 1.2)
	continued.emit()


# ══════════════════════════════════════════════════════════════ THE CARD

class Card extends Control:
	## One `_walk(do_draw)` is the single source of truth for layout: called once
	## with false to measure and once a frame with true to paint, so the two can
	## never disagree about where anything is. Lifted from briefing.gd because it
	## is the right pattern and this is the same shape of problem.

	## Hard caps. Leg 5 offers six primaries and four bonuses; listing all ten
	## next to three secrets produced a card taller than a 720p screen on the
	## first measure pass, which scales the 12px notes down to 8px and makes the
	## whole thing unreadable. Overflow becomes a "+N more" line.
	const MAX_OBJ_ROWS := 6
	const OBJ_ROW_H := 22.0
	const MAX_SEC_ROWS := 3
	const SEC_ROW_H := 33.0

	var d: Dictionary = {}
	var t := 0.0
	var card_size := Vector2(RW, 700.0)
	var grade_index := 0

	var _rcol := 0.0
	var _panel: StyleBoxFlat
	var _badge: StyleBoxFlat
	var _next_box: StyleBoxFlat
	var _grade_col := Color.WHITE
	var _score_rows: Array = []
	var _tick_windows: Array = []


	func setup(data: Dictionary) -> void:
		d = data
		grade_index = clampi(int(d.get("grade_index", 0)), 0, 5)
		var gc: Color = RGrades[grade_index]
		_grade_col = gc

		_panel = StyleBoxFlat.new()
		_panel.bg_color = RPlate
		_panel.set_corner_radius_all(18)
		_panel.border_width_top = 6
		_panel.border_width_left = 1
		_panel.border_width_right = 1
		_panel.border_width_bottom = 1
		_panel.border_color = _grade_col
		_panel.shadow_color = Color(0, 0, 0, 0.65)
		_panel.shadow_size = 26

		_badge = StyleBoxFlat.new()
		_badge.bg_color = Color(_grade_col.r, _grade_col.g, _grade_col.b, 0.14)
		_badge.set_corner_radius_all(16)
		_badge.border_width_left = 3
		_badge.border_width_right = 3
		_badge.border_width_top = 3
		_badge.border_width_bottom = 3
		_badge.border_color = _grade_col

		var passed: bool = bool(d.get("passed", false))
		var nc: Color = RGold if passed else RWarn
		_next_box = StyleBoxFlat.new()
		_next_box.bg_color = Color(nc.r, nc.g, nc.b, 0.10)
		_next_box.set_corner_radius_all(10)
		_next_box.border_width_left = 5
		_next_box.border_color = nc

		var secrets: Array = d.get("secrets", [])
		var hidden_total: int = int(d.get("hidden_total", 0))
		var obj_pts: int = int(d.get("obj_pts", 0))
		var best_combo: int = int(d.get("best_combo", 0))

		# CHAOS + STYLE ARE THE ONLY TWO ADDENDS, BECAUSE THEY ARE THE ONLY TWO
		# TERMS MISSION SUMS INTO `total`.
		#
		# Every objective payout — PRIMARY, BONUS and HIDDEN alike — goes through
		# `Game.score()`, which adds it to `Game.leg_chaos`, and Mission's
		# `_stat(&"chaos")` returns `max(_stats.chaos, _game.leg_chaos)`. So both
		# `objectives` and `hidden` are ALREADY INSIDE chaos, at their
		# combo-multiplied value. They are an itemisation of it, not additions to
		# it, which is exactly what `total = chaos + style` says.
		#
		# `objectives` was already handled that way. `SECRETS` was not: it sat
		# here as a third addend under a comment claiming the column added up, and
		# it visibly did not — 12,208 + 150 + 4,000 printed a TOTAL of 12,358.
		# A scoreboard whose own arithmetic is wrong reads as the game lying about
		# your score, which is worse than showing one fewer number. So secrets
		# join objectives in the CHAOS note, keeping the "N of M found" count,
		# which is the part the player wanted; the payoff — the secrets BY NAME,
		# with their punchlines — is in the right-hand column and is untouched.
		var sec_note := "%d of %d secrets found" % [secrets.size(), hidden_total]
		if not secrets.is_empty():
			sec_note = "%s from %d of %d secrets" % [
				_commas(int(d.get("hidden_pts", 0))), secrets.size(), hidden_total]
		_score_rows = [
			{"label": "CHAOS", "value": int(d.get("chaos", 0)), "col": RChaos,
				"t": Beats.T_CHAOS, "dur": 0.50,
				"note": "includes %s from objectives  ·  %s" % [_commas(obj_pts), sec_note]},
			{"label": "STYLE", "value": int(d.get("style", 0)), "col": RStyle,
				"t": Beats.T_STYLE, "dur": 0.35,
				"note": "best chain %dx  ·  chaining and chemistry" % best_combo},
		]
		_tick_windows = []
		for r in _score_rows:
			var row: Dictionary = r
			_tick_windows.append([float(row["t"]), float(row["dur"])])
		_tick_windows.append([Beats.T_TOTAL, Beats.D_TOTAL])

		measure()


	func measure() -> void:
		_rcol = CARD_INNER - LCOL - COL_GAP
		var h := _walk(false)
		card_size = Vector2(RW, h)
		custom_minimum_size = card_size
		size = card_size


	## The card slams in with a small overshoot. Scale only — a card that also
	## slides has to come from somewhere, and there is no somewhere.
	func intro_scale() -> float:
		if t >= 0.34:
			return 1.0
		return lerpf(0.86, 1.0, _back_out(clampf(t / 0.34, 0.0, 1.0)))


	## -1.0 when nothing is currently counting, else 0..1 through the current
	## number. Drives the rising-pitch tick.
	func tick_progress(now: float) -> float:
		for w in _tick_windows:
			var win: Array = w
			var t0: float = win[0]
			var dur: float = win[1]
			if now > t0 and now < t0 + dur:
				return (now - t0) / maxf(dur, 0.001)
		return -1.0


	# ── easing + reveal helpers ────────────────────────────────────────

	static func _ease_out(u: float) -> float:
		return 1.0 - pow(1.0 - clampf(u, 0.0, 1.0), 3.0)


	static func _back_out(u: float) -> float:
		var c: float = clampf(u, 0.0, 1.0)
		var c1 := 1.70158
		var c3 := c1 + 1.0
		return 1.0 + c3 * pow(c - 1.0, 3.0) + c1 * pow(c - 1.0, 2.0)


	## 0..1 fade-in for a block starting at t0.
	func _rev(t0: float, dur := 0.22) -> float:
		if t <= t0:
			return 0.0
		return _ease_out((t - t0) / dur)


	func _count(t0: float, dur: float, target: int) -> int:
		if t <= t0:
			return 0
		if t >= t0 + dur:
			return target
		return int(round(float(target) * _ease_out((t - t0) / dur)))


	static func _commas(n: int) -> String:
		var s := str(absi(n))
		var out := ""
		var c := 0
		for i in range(s.length() - 1, -1, -1):
			out = s[i] + out
			c += 1
			if c % 3 == 0 and i > 0:
				out = "," + out
		if n < 0:
			return "-" + out
		return out


	static func _mmss(secs: float) -> String:
		var s: int = int(round(maxf(0.0, secs)))
		return "%d:%02d" % [s / 60, s % 60]


	func _f() -> Font:
		return ThemeDB.fallback_font


	## draw_string with a black outline. Every readable thing here sits on a
	## translucent plate over a live 3D scene; the outline is what keeps it
	## legible when what's behind it happens to be a white minivan.
	func _text(pos: Vector2, s: String, fs: int, col: Color,
			align := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0, outline := 4) -> void:
		if col.a <= 0.004 or s == "":
			return
		var f := _f()
		if outline > 0:
			f.draw_string_outline(get_canvas_item(), pos, s, align, w, fs, outline,
				Color(0, 0, 0, col.a * 0.85))
		f.draw_string(get_canvas_item(), pos, s, align, w, fs, col)


	func _draw() -> void:
		draw_style_box(_panel, Rect2(Vector2.ZERO, card_size))
		_walk(true)


	# ══════════════════════════════════════════════════ THE ONE LAYOUT PASS

	func _walk(do_draw: bool) -> float:
		var f := _f()
		var x := CARD_PAD
		var y := CARD_PAD
		var inner := CARD_INNER

		# ── header ─────────────────────────────────────────────────────
		# Reading order is verdict-then-grade on purpose: "LEG CLEARED" is the
		# fact and the grade is the opinion, and the opinion has to arrive last.
		var ha := _rev(Beats.T_HEAD, 0.26)
		var oy := (1.0 - ha) * 10.0
		var kicker := "LEG %d   ·   %s" % [int(d.get("leg", 1)), str(d.get("zone_title", ""))]
		if do_draw:
			_text(Vector2(x, y + oy + f.get_ascent(15)), kicker, 15,
				Color(RGold.r, RGold.g, RGold.b, 0.85 * ha))
		y += f.get_ascent(15) + f.get_descent(15) + 6.0

		var passed: bool = bool(d.get("passed", false))
		var verdict := "LEG CLEARED" if passed else "FELL SHORT"
		var vcol: Color = ROk if passed else RWarn
		if do_draw:
			_text(Vector2(x, y + oy + f.get_ascent(42)), verdict, 42,
				Color(vcol.r, vcol.g, vcol.b, ha), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 5)
		y += f.get_ascent(42) + f.get_descent(42) + 2.0

		var need := "%d of %d primaries  ·  needed %d" % [
			int(d.get("primaries_done", 0)), int(d.get("primaries_total", 0)),
			int(d.get("required", 0))]
		if do_draw:
			_text(Vector2(x, y + f.get_ascent(15)), need, 15, Color(RDim.r, RDim.g, RDim.b, ha))
			_pips(Vector2(x + f.get_string_size(need, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 18.0,
				y + 9.0), ha)
		y += f.get_ascent(15) + f.get_descent(15)

		# The grade badge occupies the right of the header band. Measured here,
		# drawn last, so it sits over everything when it overshoots.
		var badge := 126.0
		var badge_rect := Rect2(Vector2(RW - CARD_PAD - badge, CARD_PAD - 2.0),
			Vector2(badge, badge))
		y = maxf(y, badge_rect.end.y)

		y += 18.0
		if do_draw:
			draw_rect(Rect2(x, y, inner, 1.0), Color(1, 1, 1, 0.14 * ha), true)
		y += 18.0

		# ── two columns ────────────────────────────────────────────────
		var band_top := y
		var ly := _left_column(x, y, do_draw)
		var ry := _right_column(x + LCOL + COL_GAP, y, do_draw)
		y = maxf(ly, ry)
		if do_draw:
			# Two columns with no divider read as one badly-spaced column.
			draw_rect(Rect2(x + LCOL + COL_GAP * 0.5, band_top, 1.0, y - band_top),
				Color(1, 1, 1, 0.08 * ha), true)

		# ── the flock, going into the flight ───────────────────────────
		y += 18.0
		if do_draw:
			draw_rect(Rect2(x, y, inner, 1.0), Color(1, 1, 1, 0.14 * ha), true)
		y += 15.0
		y = _flock_band(x, y, do_draw)

		# ── THE CONSEQUENCE ────────────────────────────────────────────
		y += 16.0
		y = _next_leg(x, y, do_draw)

		# ── footer: the rank line, and the way out ─────────────────────
		y += 15.0
		var ra := _rev(Beats.T_RANK, 0.3)
		if do_draw and ra > 0.002:
			_text(Vector2(x, y + f.get_ascent(19)),
				"“" + str(d.get("rank_text", "")) + "”", 19,
				Color(0.87, 0.89, 0.96, ra))
		y += f.get_ascent(19) + f.get_descent(19) + 9.0

		if do_draw:
			var pa := _rev(Beats.T_PROMPT, 0.35)
			if pa > 0.002:
				# Gentle pulse so it reads as "waiting for you" rather than as a
				# label. The card is completely static by this point.
				var pulse: float = 0.72 + 0.28 * (0.5 + 0.5 * sin(t * 4.0))
				_text(Vector2(x, y + f.get_ascent(15)),
					"ENTER  ·  SPACE  ·  CLICK      CONTINUE TO THE FLIGHT", 15,
					Color(1, 1, 1, 0.68 * pa * pulse), HORIZONTAL_ALIGNMENT_RIGHT, inner)
			# The escape hatch is advertised from the very start of the tally,
			# not once it's over. Announcing a skip after the thing you wanted to
			# skip has finished is a joke at the player's expense.
			if t < Beats.T_GRADE and t > 0.55:
				_text(Vector2(x, y + f.get_ascent(15)),
					"any key skips the tally", 15, Color(RDim.r, RDim.g, RDim.b, 0.95))
		y += f.get_ascent(15) + f.get_descent(15)

		# ── the grade, last, over the top of everything ────────────────
		if do_draw:
			_grade(badge_rect)

		return y + CARD_PAD * 0.9


	## One pip per required primary, filled as you banked them. Same shape
	## language as the mission HUD's header, so the pass condition looks like the
	## rule it already was rather than one invented for the results screen.
	func _pips(at: Vector2, a: float) -> void:
		var req: int = int(d.get("required", 0))
		var got: int = int(d.get("primaries_done", 0))
		for i in mini(req, 8):
			var p := at + Vector2(float(i) * 16.0, 0.0)
			if i < got:
				draw_circle(p, 5.0, Color(ROk.r, ROk.g, ROk.b, a))
			else:
				draw_arc(p, 5.0, 0.0, TAU, 12, Color(1, 1, 1, 0.32 * a), 1.6)


	# ── LEFT: the score, taken apart ───────────────────────────────────

	func _left_column(x: float, y0: float, do_draw: bool) -> float:
		var f := _f()
		var y := y0
		var w := LCOL

		for r in _score_rows:
			var row: Dictionary = r
			var t0: float = row["t"]
			var dur: float = row["dur"]
			var a := _rev(t0, 0.20)
			if do_draw and a > 0.002:
				var label: String = row["label"]
				var col: Color = row["col"]
				var target: int = row["value"]
				var shown := _count(t0, dur, target)
				# Slides up 8px as it lands. Motion is what makes a row read as
				# having ARRIVED rather than as having always been there.
				var oy := (1.0 - a) * 8.0
				_text(Vector2(x, y + oy + f.get_ascent(16)), label, 16,
					Color(col.r, col.g, col.b, a))
				# Brighten the number while it is still moving.
				var hot: float = 1.0 if t < t0 + dur else 0.0
				_text(Vector2(x, y + oy + f.get_ascent(27)), _commas(shown), 27,
					Color(0.95, 0.97, 1.0).lerp(Color.WHITE, hot) * Color(1, 1, 1, a),
					HORIZONTAL_ALIGNMENT_RIGHT, w)
				var note: String = row["note"]
				if note != "":
					_text(Vector2(x, y + oy + f.get_ascent(27) + 13.0), note, 12,
						Color(RDim.r, RDim.g, RDim.b, 0.9 * a))
			y += 48.0

		# ── total ──
		y += 6.0
		var ta := _rev(Beats.T_TOTAL, 0.2)
		if do_draw:
			draw_rect(Rect2(x, y, w, 1.0), Color(1, 1, 1, 0.18 * ta), true)
		y += 11.0
		var total: int = int(d.get("total", 0))
		var shown_total := _count(Beats.T_TOTAL, Beats.D_TOTAL, total)
		if do_draw and ta > 0.002:
			_text(Vector2(x, y + f.get_ascent(18)), "TOTAL", 18, Color(1, 1, 1, 0.94 * ta))
			_text(Vector2(x, y + f.get_ascent(38)), _commas(shown_total), 38,
				Color(1, 1, 1, ta), HORIZONTAL_ALIGNMENT_RIGHT, w, 5)
		y += f.get_ascent(38) + f.get_descent(38) + 8.0

		# ── the par bar: the entire grading rule, as one picture ──
		# The grade is total/par and nothing else. A bar that crosses a marked
		# par line is the difference between "the game gave me a B" and "I was
		# nine hundred short of an A".
		var pa := _rev(Beats.T_PAR, 0.35)
		var par: int = maxi(1, int(d.get("par", 1)))
		var bar_h := 9.0
		if do_draw and pa > 0.002:
			# Full width == 1.75x par == the S threshold.
			var frac: float = clampf(float(shown_total) / (float(par) * 1.75), 0.0, 1.0)
			draw_rect(Rect2(x, y, w, bar_h), Color(0, 0, 0, 0.55 * pa), true)
			draw_rect(Rect2(x, y, w * frac * pa, bar_h),
				Color(_grade_col.r, _grade_col.g, _grade_col.b, 0.94 * pa), true)
			var px := x + w * (1.0 / 1.75)
			draw_rect(Rect2(px - 1.0, y - 3.0, 2.0, bar_h + 6.0), Color(1, 1, 1, 0.7 * pa), true)
			_text(Vector2(px + 7.0, y + bar_h + 14.0), "PAR %s" % _commas(par), 12,
				Color(RDim.r, RDim.g, RDim.b, pa))
			_text(Vector2(x, y + bar_h + 14.0), "F", 12, Color(1, 1, 1, 0.38 * pa))
			_text(Vector2(x, y + bar_h + 14.0), "S", 12, Color(1, 1, 1, 0.38 * pa),
				HORIZONTAL_ALIGNMENT_RIGHT, w)
		y += bar_h + 20.0

		return y


	# ── RIGHT: what you actually did ───────────────────────────────────

	func _right_column(x: float, y0: float, do_draw: bool) -> float:
		var f := _f()
		var y := y0
		var w := _rcol

		var done: Array = d.get("done_rows", [])
		var missed: Array = d.get("missed_rows", [])
		var ha := _rev(Beats.T_OBJ, 0.25)
		if do_draw:
			_text(Vector2(x, y + f.get_ascent(14)), "OBJECTIVES", 14,
				Color(RGold.r, RGold.g, RGold.b, 0.92 * ha))
			_text(Vector2(x, y + f.get_ascent(14)),
				"%d of %d" % [done.size(), done.size() + missed.size()], 14,
				Color(1, 1, 1, 0.78 * ha), HORIZONTAL_ALIGNMENT_RIGHT, w)
		y += f.get_ascent(14) + f.get_descent(14) + 7.0

		# Completed first and bright, missed after and dim. Showing what was
		# missed is not a scoreboard of shortcomings here — it is the only
		# actionable feedback the player gets, and this is the one screen where
		# they are standing still long enough to read it.
		var shown := 0
		for r in done:
			if shown >= MAX_OBJ_ROWS:
				break
			var row: Dictionary = r
			var a := _rev(Beats.T_OBJ + float(shown) * Beats.OBJ_STEP, 0.22)
			if do_draw and a > 0.002:
				_obj_row(Vector2(x, y), row, true, a, w)
			y += OBJ_ROW_H
			shown += 1
		for r2 in missed:
			if shown >= MAX_OBJ_ROWS:
				break
			var row2: Dictionary = r2
			var a2 := _rev(Beats.T_OBJ + float(shown) * Beats.OBJ_STEP, 0.22)
			if do_draw and a2 > 0.002:
				_obj_row(Vector2(x, y), row2, false, a2, w)
			y += OBJ_ROW_H
			shown += 1
		var over: int = done.size() + missed.size() - shown
		if over > 0:
			if do_draw:
				_text(Vector2(x + 20.0, y + f.get_ascent(12)), "+%d more" % over, 12,
					Color(RDim.r, RDim.g, RDim.b, ha))
			y += 17.0

		# ── the secrets, BY NAME ───────────────────────────────────────
		y += 14.0
		var secrets: Array = d.get("secrets", [])
		var sa := _rev(Beats.T_SEC, 0.25)
		if do_draw:
			_text(Vector2(x, y + f.get_ascent(14)), "SECRETS FOUND", 14,
				Color(RSecret.r, RSecret.g, RSecret.b, 0.92 * sa))
			_text(Vector2(x, y + f.get_ascent(14)),
				"%d of %d" % [secrets.size(), int(d.get("hidden_total", 0))], 14,
				Color(1, 1, 1, 0.78 * sa), HORIZONTAL_ALIGNMENT_RIGHT, w)
		y += f.get_ascent(14) + f.get_descent(14) + 6.0

		if secrets.is_empty():
			if do_draw and sa > 0.002:
				_text(Vector2(x, y + f.get_ascent(13)),
					"None this time. They are not on any list.", 13,
					Color(RDim.r, RDim.g, RDim.b, sa))
			y += 20.0
		else:
			var sn := 0
			for s in secrets:
				if sn >= MAX_SEC_ROWS:
					break
				var sec: Dictionary = s
				var a3 := _rev(Beats.T_SEC + float(sn) * Beats.SEC_STEP, 0.26)
				if do_draw and a3 > 0.002:
					var oy := (1.0 - a3) * 7.0
					# Diamond marker — the same shape the mission HUD gives a
					# revealed hidden objective, so this reads as the same thing.
					var c := Vector2(x + 6.0, y + oy + 9.0)
					draw_colored_polygon(PackedVector2Array([
						c + Vector2(0, -5.5), c + Vector2(5.5, 0),
						c + Vector2(0, 5.5), c + Vector2(-5.5, 0)]),
						Color(RSecret.r, RSecret.g, RSecret.b, a3))
					_text(Vector2(x + 20.0, y + oy + f.get_ascent(16)),
						_clip(str(sec.get("title", "")), 16, w - 22.0), 16,
						Color(1.0, 0.83, 0.94, a3))
					var line: String = str(sec.get("line", ""))
					if line != "":
						_text(Vector2(x + 20.0, y + oy + f.get_ascent(16) + 15.0),
							_clip(line, 12, w - 22.0), 12,
							Color(RDim.r, RDim.g, RDim.b, 0.95 * a3))
				y += SEC_ROW_H
				sn += 1
			if secrets.size() > MAX_SEC_ROWS:
				if do_draw:
					_text(Vector2(x + 20.0, y + f.get_ascent(12)),
						"+%d more" % (secrets.size() - MAX_SEC_ROWS), 12,
						Color(RDim.r, RDim.g, RDim.b, sa))
				y += 17.0

		return y


	func _obj_row(at: Vector2, row: Dictionary, done: bool, a: float, w: float) -> void:
		var f := _f()
		var kind: int = int(row.get("kind", 0))
		var p := at + Vector2(0.0, (1.0 - a) * 6.0)
		var col := Color(0.94, 0.96, 1.0)
		if not done:
			col = Color(0.56, 0.59, 0.67) if kind == 0 else Color(0.43, 0.46, 0.53)
		col.a = a

		# Marker as a SHAPE, not a glyph: filled square + tick when done, hollow
		# when not. Readable at a glance and immune to a missing font glyph.
		var m := Vector2(p.x + 6.0, p.y + 9.0)
		if done:
			draw_rect(Rect2(m - Vector2(6, 6), Vector2(12, 12)),
				Color(ROk.r, ROk.g, ROk.b, a), true)
			draw_polyline(PackedVector2Array([
				m + Vector2(-3.2, 0.2), m + Vector2(-0.8, 2.8), m + Vector2(3.6, -3.0)]),
				Color(0.05, 0.09, 0.06, a), 2.0)
		else:
			draw_rect(Rect2(m - Vector2(6, 6), Vector2(12, 12)),
				Color(1, 1, 1, 0.30 * a), false, 1.6)

		var txt: String = str(row.get("text", ""))
		if kind == 1:
			txt = "+ " + txt
		_text(Vector2(p.x + 20.0, p.y + f.get_ascent(15)), _clip(txt, 15, w - 22.0), 15, col)


	## Hard-truncate to a pixel width. draw_string clips silently at `width`,
	## which produces a line ending mid-word with no indication it was cut.
	func _clip(s: String, fs: int, w: float) -> String:
		var f := _f()
		if f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= w:
			return s
		var out := s
		while out.length() > 4 and f.get_string_size(out + "…",
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w:
			out = out.substr(0, out.length() - 1)
		return out + "…"


	# ── the flock: drawn as birds, not described as a sentence ─────────

	func _flock_band(x: float, y0: float, do_draw: bool) -> float:
		var f := _f()
		var y := y0
		var a := _rev(Beats.T_FLOCK, 0.3)
		if do_draw:
			_text(Vector2(x, y + f.get_ascent(14)), "THE FLOCK, GOING INTO THE FLIGHT", 14,
				Color(RGold.r, RGold.g, RGold.b, 0.92 * a))
			_text(Vector2(x, y + f.get_ascent(14)), str(d.get("flock_summary", "")), 14,
				Color(0.87, 0.90, 0.96, 0.95 * a), HORIZONTAL_ALIGNMENT_RIGHT, CARD_INNER)
		y += f.get_ascent(14) + f.get_descent(14) + 9.0

		# One slot per bird: a condition bar with the name under it, and the DD
		# wearing its vest colour. Same information as condition_summary(), but
		# you can read it without reading it — and it is the only place the DD
		# choice made back in the zone visibly pays off before the flight.
		var birds: Array = d.get("birds", [])
		if not birds.is_empty():
			var slot: float = minf(112.0, CARD_INNER / float(birds.size()))
			var bw := slot - 16.0
			for i in birds.size():
				var b: Dictionary = birds[i]
				var ba := _rev(Beats.T_FLOCK + float(i) * 0.05, 0.24)
				if not do_draw or ba <= 0.002:
					continue
				var bx := x + float(i) * slot
				var intox: float = float(b.get("intox", 0.0))
				var can: bool = bool(b.get("can_lead", false))
				var is_dd: bool = bool(b.get("is_dd", false))
				# Green = fit to take a lead shift, red = no use to anyone.
				# Redundant with the bar length on purpose.
				var col := Color(0.42, 0.86, 0.52)
				if intox > 0.7:
					col = Color(0.94, 0.36, 0.32)
				elif intox > 0.45:
					col = Color(0.96, 0.62, 0.28)
				elif intox > 0.2:
					col = Color(0.95, 0.85, 0.35)
				if is_dd:
					col = Color(0.99, 0.93, 0.20)
				col.a = ba

				draw_rect(Rect2(bx, y, bw, 7.0), Color(0, 0, 0, 0.55 * ba), true)
				draw_rect(Rect2(bx, y, bw * clampf(1.0 - intox, 0.05, 1.0), 7.0), col, true)
				if is_dd:
					draw_rect(Rect2(bx - 2.0, y - 2.0, bw + 4.0, 11.0),
						Color(0.99, 0.93, 0.20, 0.9 * ba), false, 1.6)
				var tag: String = str(b.get("name", "?"))
				if is_dd:
					tag += "  DD"
				_text(Vector2(bx, y + 9.0 + f.get_ascent(12)), _clip(tag, 12, bw), 12,
					Color(0.83, 0.86, 0.93, ba if can else 0.55 * ba))
			y += 9.0 + f.get_ascent(12) + f.get_descent(12)

		var note: String = str(d.get("flock_note", ""))
		if note != "":
			y += 4.0
			if do_draw:
				_text(Vector2(x, y + f.get_ascent(13)), note, 13,
					Color(RDim.r, RDim.g, RDim.b, a))
			y += f.get_ascent(13) + f.get_descent(13)

		return y


	# ── THE CONSEQUENCE ────────────────────────────────────────────────
	#
	# The most important block on the card and half the reason it exists. The
	# objective system gates the next leg's clock; if the player never connects
	# "I ignored the objectives" to "I have less time now", that gate is
	# invisible and the whole system may as well not be there.
	#
	# Framed as an ADDITION, never a subtraction: the headline is the clock you
	# GET, and the arithmetic underneath merely explains it. Penalty framing
	# produces dissatisfaction even when the player agrees with the rule.

	func _next_leg(x: float, y0: float, do_draw: bool) -> float:
		var f := _f()
		var box_h := 102.0
		var a := _rev(Beats.T_NEXT, 0.28)
		if not do_draw or a <= 0.002:
			return y0 + box_h

		var passed: bool = bool(d.get("passed", false))
		var next_secs: float = float(d.get("next_secs", 180.0))
		# THE BASE IS PER-LEG AND COMES FROM THE ROUTE. It is not 3:00 — leg 1 is
		# 4:00 and leg 5 is 2:30 — and hard-coding it here printed arithmetic that
		# didn't add up to the clock directly above it on exactly those legs.
		var base_secs: float = float(d.get("next_base", next_secs))
		# Derived from the clock actually being promised, never from the raw
		# modifier: `next_zone_seconds` is clamped, so a big shortfall would
		# otherwise print arithmetic that doesn't match the number above it.
		var delta_s := int(round(next_secs - base_secs))
		var base_txt := _mmss(base_secs)

		var pop := 1.0
		if t < Beats.T_NEXT + 0.3:
			pop = lerpf(1.06, 1.0, _ease_out((t - Beats.T_NEXT) / 0.3))

		var oy := (1.0 - a) * 10.0
		draw_style_box(_next_box, Rect2(Vector2(x, y0 + oy), Vector2(CARD_INNER, box_h)))
		var tx := x + 22.0
		var ty := y0 + oy + 14.0
		_text(Vector2(tx, ty + f.get_ascent(14)), "WHAT THIS BUYS YOU", 14,
			Color(1, 1, 1, 0.62 * a))

		var clock := _mmss(next_secs)
		var nc: Color = RGold if passed else RWarn
		var fs: int = int(round(40.0 * pop))
		_text(Vector2(tx, ty + 21.0 + f.get_ascent(fs)), clock, fs,
			Color(nc.r, nc.g, nc.b, a), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 5)
		var cw: float = f.get_string_size(clock, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_text(Vector2(tx + cw + 14.0, ty + 21.0 + f.get_ascent(fs)), "IN THE NEXT ZONE", 17,
			Color(0.91, 0.93, 0.98, 0.95 * a))

		# The why, in the player's own terms and matching the number above.
		var short: int = maxi(0, int(d.get("required", 0)) - int(d.get("primaries_done", 0)))
		var why := ""
		if delta_s > 0:
			why = "%s base  +  %ds banked for clearing the leg with a %s." % [
				base_txt, delta_s, str(d.get("grade", ""))]
		elif delta_s < 0 and passed:
			why = "%s base  −  %ds. You cleared it, but a %s banks nothing back." % [
				base_txt, absi(delta_s), str(d.get("grade", ""))]
		elif delta_s < 0:
			var word := "primary" if short == 1 else "primaries"
			why = "%s base  −  %ds:  %d %s short of the %d you needed." % [
				base_txt, absi(delta_s), short, word, int(d.get("required", 0))]
		else:
			why = "%s base, unchanged. Clear a leg with a B or better and you bank seconds." % base_txt
		_text(Vector2(tx, ty + 21.0 + f.get_ascent(fs) + 17.0), why, 14,
			Color(0.81, 0.84, 0.91, a))

		# The other soft fail, named, so the two never look like one rule. The
		# minute it costs comes off the SAME per-leg base and through the same
		# clamp (see _short_clock), so this number moves with the one above it
		# instead of being a second hard-coded 3:00.
		_text(Vector2(x, ty + 21.0 + f.get_ascent(fs) + 17.0),
			"land short on the flight and it's %s instead"
				% _mmss(float(d.get("next_secs_short", next_secs))),
			12, Color(RDim.r, RDim.g, RDim.b, 0.9 * a), HORIZONTAL_ALIGNMENT_RIGHT,
			CARD_INNER - 22.0)

		return y0 + box_h


	# ── THE GRADE. Last thing to happen, and the point of the screen. ──

	func _grade(r: Rect2) -> void:
		if t <= Beats.T_GRADE:
			return
		var f := _f()
		var u: float = clampf((t - Beats.T_GRADE) / 0.42, 0.0, 1.0)
		# Comes in HUGE and slams down to size with a back-out overshoot. The
		# scale RANGE is doing all the work here: 2.6 -> 1.0 reads as impact,
		# 1.2 -> 1.0 reads as a UI element politely appearing.
		var s: float = lerpf(2.6, 1.0, _back_out(u))
		var c := r.get_center()
		draw_set_transform(c, 0.0, Vector2(s, s))
		var local := Rect2(-r.size * 0.5, r.size)
		draw_style_box(_badge, local)
		var g: String = str(d.get("grade", "?"))
		var fs := 96
		# Centre on the cap height rather than the full line box: a lone capital
		# in a big font sits visibly high otherwise.
		var base: float = local.position.y + (r.size.y + f.get_ascent(fs) - f.get_descent(fs)) * 0.5
		f.draw_string_outline(get_canvas_item(), Vector2(local.position.x, base), g,
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, 8, Color(0, 0, 0, 0.8))
		f.draw_string(get_canvas_item(), Vector2(local.position.x, base), g,
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, _grade_col)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

		# A shockwave ring out of the badge on the landing frames. Kept tight to
		# the badge: the first render pushed it to 1.5x the badge width, which
		# sails off the corner of the card and reads as a stray circle floating
		# on the backdrop rather than as an impact.
		if u < 1.0:
			var ru := _ease_out(u)
			draw_arc(c, lerpf(r.size.x * 0.52, r.size.x * 0.98, ru), 0.0, TAU, 40,
				Color(_grade_col.r, _grade_col.g, _grade_col.b, (1.0 - ru) * 0.75), 5.0)


## Inner classes can't see the outer script's members by every name, so
## everything the card needs gets one explicit alias here — the same trick
## briefing.gd uses for its key-cap renderer.
const RGrades := GRADE_COL
const RGold := C_GOLD
const RSecret := C_SECRET
const RChaos := C_CHAOS
const RStyle := C_STYLE
const RPlate := C_PLATE
const RWarn := C_WARN
const RDim := FONT_DIM
const ROk := FONT_OK
const RW := CARD_W


## THE REVEAL TIMELINE, in one box so the outer script and the card read the
## same numbers. Everything on screen is a pure function of `t`, which is why
## skipping is a single assignment and nothing can ever end up half-revealed.
class Beats extends RefCounted:
	const T_HEAD := 0.22
	const T_CHAOS := 0.40
	const T_STYLE := 0.95
	## No T_SECRETS. Secrets are not a left-column row any more — they are an
	## itemisation of CHAOS. `T_SEC` below is the right column's named list and is
	## a different, still-live beat; the two used to be one letter apart, which is
	## most of why the addend row survived as long as it did.
	## The right column runs in PARALLEL with the left one's count-up rather
	## than after it. Serialising them pushed the whole reveal past five seconds
	## and left half the card visibly empty for most of it.
	const T_OBJ := 1.05
	const OBJ_STEP := 0.09
	const T_TOTAL := 1.80
	const D_TOTAL := 0.65
	const T_SEC := 1.95
	const SEC_STEP := 0.15
	const T_PAR := 2.50
	const T_FLOCK := 2.60
	const T_NEXT := 2.92
	## 2.92 -> 3.62 is the savour beat. Nothing happens in it on purpose, and
	## deleting it measurably flattens the grade when it arrives.
	const T_GRADE := 3.62
	const T_RANK := 4.04
	const T_PROMPT := 4.36
