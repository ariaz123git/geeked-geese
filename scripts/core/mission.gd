extends Node
## Autoload: Mission
##
## The objective system. Owns the set of goals for the leg the player is
## currently in, watches the game's existing signal traffic to advance them,
## and decides how the leg went.
##
## ── WHY THIS EXISTS ──────────────────────────────────────────────────────
## The previous checklist was decoration: nothing read it, nothing gated on it,
## and the leg advanced on a timer no matter what you did. A goal you cannot
## fail and that nobody checks is not a goal, it's a label. Goal-setting theory
## is blunt about this — a goal only changes behaviour if it is SPECIFIC,
## DIFFICULT, and FED BACK ON. All three or none of it works.
##
## ── HOW IT PLUGS IN ──────────────────────────────────────────────────────
## Mission is a passive observer. It subscribes to signals that already exist
## (Game.chaos_scored, Subs.*, Goose.*) and derives everything from them. No
## prop, NPC or zone has to know objectives exist — the same decision the old
## system made, kept, because it's the right one.
##
## The only thing the integrator MUST do is call begin_leg() when a zone loads,
## bind_goose() with that zone's bird, and end_leg() when the clock runs out.
##
## ── FAIL PHILOSOPHY ──────────────────────────────────────────────────────
## You cannot lose a run here. evaluate_leg() never returns "game over"; it
## returns how much clock you get next time. Missing the primaries costs you
## seconds and flock stamina, exactly like landing short on a migration costs
## you seconds. Every failure in this game is paid for in future comfort, never
## in a restart. That's deliberate: comedy sandboxes die the instant the player
## is punished for messing around, because messing around IS the game.
##
## ── WHY THE VISIBLE LIST IS SHORT ────────────────────────────────────────
## Three to four visible objectives, of which you only need MOST. Long
## checklists read as homework and convert optional content into obligation.
## The interesting goals in this system are hidden ones you trip over, so the
## HUD can stay thin without the leg feeling thin.

const Defs = preload("res://scripts/core/mission_defs.gd")

enum Kind { PRIMARY, BONUS, HIDDEN }

## Score labels this system emits itself. They are filtered out of every
## condition — otherwise an "any hit counts" objective would complete itself
## off its own reward payout, which is exactly the kind of bug that makes a
## mission system feel broken and random.
const SELF_LABELS := ["OBJECTIVE", "BONUS OBJECTIVE", "HIDDEN", "MISSION"]

const GRADES := ["F", "D", "C", "B", "A", "S"]

## ── THE ONE NUMBER TO CALIBRATE AFTER THE FIRST REAL PLAYTEST ───────────
## Score a "B" run is expected to reach on leg 1. Everything else in the
## grading table is a ratio against this, so tuning difficulty is one edit.
##
## The starting value is derived, not guessed: hitting every static prop in the
## strip mall exactly once is worth about 2,600 base chaos, and the combo
## multiplier on a run that keeps moving roughly doubles that. 6,000 is
## therefore "you cleared the lot and kept your chain alive" — a good afternoon,
## not a perfect one. If early playtests grade everyone S, this goes up.
const PAR_BASE := 6000.0

## ── THE LEG CLOCK HAS EXACTLY ONE OWNER, AND IT IS NOT THIS FILE ────────
##
## `main.gd::ROUTE` owns each leg's clock. It is per-leg data, the route is the
## thing that knows a tutorial pond needs longer than a truck stop, and it is
## what `_on_migration_done()` actually obeys. This file used to compute the
## number the results screen PROMISES from a hard-coded 180 s base clamped to
## [110, 210], while main.gd started the leg from `ROUTE[leg].seconds` clamped
## to [110, 240]. The route is not all 180 — leg 1 is 240 and leg 5 is 150 — so
## the card promised a clock the game did not hand out, and the comment above
## main.gd's clamp said the two ranges agreed at the exact moment they didn't.
## (HANDOFF §2.5 records this bug as fixed. It regressed here.)
##
## So: the base comes from the ROUTE via `leg_seconds()`, and the clamp lives in
## `clamp_zone_seconds()` — one function both sides can call. Deliberately the
## SAME range main.gd currently hard-codes, so the two agree today with no edit
## to main.gd; see docs/CLOCK_AND_CAMERA_NOTES.md for the one-line change that
## makes the shared ownership real rather than merely coincident.
const ZONE_SECONDS_MIN := 110.0
const ZONE_SECONDS_MAX := 240.0
## Only reached when there is no Main in the tree at all — a unit harness, or the
## card being driven standalone. Never on any path a player takes.
const ZONE_SECONDS_FALLBACK := 180.0

## Funny one-liner per grade index. Shown on the results card.
const RANK_LINES := [
	"You were in a parking lot. Technically.",
	"A goose was present. That is the finding.",
	"Some property was damaged. Not enough.",
	"A solid afternoon of being a problem.",
	"The plaza will be talking about this.",
	"They are going to name the retention pond after you.",
]

signal objectives_ready(list: Array)
signal objective_progressed(id: StringName, progress: int, target: int, kind: int)
signal objective_completed(id: StringName, kind: int, reward: int)
signal hidden_revealed(id: StringName, title: String, line: String, reward: int)
signal primaries_completed()
signal leg_decided(result: Dictionary)

var zone_id: StringName = &""
var leg: int = 1
var running := false

var _objs: Array[Dictionary] = []
var _stats: Dictionary = {}          ## StringName -> float
var _sets: Dictionary = {}           ## StringName -> Dictionary (used as a set)
var _elapsed := 0.0
var _wake_until := -1.0              ## post-blackout scoring window

var _game: Node = null
var _subs: Node = null
var _flock: Node = null
var _sfx: Node = null
var _goose: Node = null

var _required := 2
var _decided := false
var _result: Dictionary = {}
## Cached scene director, resolved lazily. See _main_node().
var _main: Node = null


func _ready() -> void:
	_game = get_node_or_null("/root/Game")
	_subs = get_node_or_null("/root/Subs")
	_flock = get_node_or_null("/root/Flock")
	_sfx = get_node_or_null("/root/Sfx")
	_connect_globals()


# ══════════════════════════════════════════════════════════════ LIFECYCLE

## Call when a zone finishes building. `zone` may expose `mission_zone_id()`
## or `zone_id`; otherwise pass the id directly.
func begin_leg(p_zone_id: StringName, p_leg: int = -1) -> void:
	zone_id = p_zone_id
	leg = p_leg if p_leg > 0 else _current_leg()
	running = true
	_decided = false
	_result = {}
	_elapsed = 0.0
	_wake_until = -1.0
	_reset_stats()
	_build(zone_id, leg)
	objectives_ready.emit(visible_objectives())


## Wire up the zone's bird. Safe to call with null; everything degrades to
## "that condition just never fires" rather than erroring.
func bind_goose(g: Node) -> void:
	if _goose != null and is_instance_valid(_goose):
		if _goose.has_signal("landed") and _goose.landed.is_connected(_on_landed):
			_goose.landed.disconnect(_on_landed)
		if _goose.has_signal("tumbled") and _goose.tumbled.is_connected(_on_tumbled):
			_goose.tumbled.disconnect(_on_tumbled)
		if _goose.has_signal("took_off") and _goose.took_off.is_connected(_on_took_off):
			_goose.took_off.disconnect(_on_took_off)
	_goose = g
	if _goose == null:
		return
	if _goose.has_signal("landed"):
		_goose.landed.connect(_on_landed)
	if _goose.has_signal("tumbled"):
		_goose.tumbled.connect(_on_tumbled)
	if _goose.has_signal("took_off"):
		_goose.took_off.connect(_on_took_off)


## Close the leg out. Idempotent — calling twice returns the same verdict.
func end_leg() -> Dictionary:
	if _decided:
		return _result
	running = false
	_result = evaluate_leg()
	_decided = true
	leg_decided.emit(_result)
	return _result


## Manual event feed, for anything that isn't already on a signal.
##   Mission.note(&"sub_taken", {"id": &"berries", "dose": 0.5})
func note(event: StringName, payload: Dictionary = {}) -> void:
	if not running:
		return
	var ev: Dictionary = payload.duplicate()
	ev["_kind"] = &"event"
	ev["_event"] = event
	_dispatch(ev)


# ══════════════════════════════════════════════════════════════════ BUILD

func _build(p_zone: StringName, p_leg: int) -> void:
	_objs.clear()
	var raw: Array = Defs.for_zone(p_zone, p_leg)
	var mult := target_scale(p_leg)
	var rew := reward_scale(p_leg)
	var order := 0
	for d in raw:
		var e: Dictionary = d
		var kind: int = int(e.get("kind", Kind.PRIMARY))
		var no_scale: bool = bool(e.get("no_scale", false))
		# Hidden objectives do NOT scale. They're one-off jokes with a fixed
		# shape; a "5 carts in 6 seconds" gag that quietly becomes 9 carts on
		# leg 6 stops being the same joke and starts being a wall.
		var m: float = 1.0 if (no_scale or kind == Kind.HIDDEN) else mult
		var cond_src: Dictionary = e.get("cond", {})
		var cond: Dictionary = _scale_cond(cond_src, m)
		# Objective text writes its number as "{n}" and we substitute the SCALED
		# target. Hardcoding it in the string is a slow-acting bug: on leg 3 the
		# HUD cheerfully reads "Introduce 8 shopping carts to physics   5/11".
		var n_txt := str(_cond_target(cond))
		var obj: Dictionary = {
			"id": e.get("id", &""),
			"kind": kind,
			"text": String(e.get("text", "")).replace("{n}", n_txt),
			"hint": String(e.get("hint", "")).replace("{n}", n_txt),
			"done_text": String(e.get("done_text", "")).replace("{n}", n_txt),
			"title": String(e.get("title", "")),
			"line": String(e.get("line", "")),
			"reward": int(round(float(int(e.get("reward", 100))) * rew)),
			"cond": cond,
			"state": _make_state(cond),
			"late": bool(e.get("late", false)),
			"flock": e.get("flock", {}),
			"done": false,
			"revealed": kind != Kind.HIDDEN,
			"order": order,
		}
		order += 1
		_objs.append(obj)

	_required = required_primaries(p_leg)


## ── THE ESCALATION CURVE, AND WHY IT BENDS WHERE IT DOES ────────────────
##
## Target multiplier by leg. 18% per leg, hard-capped at 1.9x from leg 6.
##
## The cap is the important part. The clock never grows — every leg is three
## minutes — and a zone contains a finite number of carts, gnomes and bins.
## Scaling targets forever produces an objective that is not hard, it is
## impossible, and impossible objectives teach the player to ignore the HUD.
## So volume escalates for five legs and then stops.
##
## Past the cap, difficulty comes from CONSTRAINTS instead: leg 3 adds a
## ten-second window objective, leg 5 adds a chain-length or no-touching-the-
## ground objective, and the required-primaries count rises. Same amount of
## stuff, less freedom in how you get it. That's the roguelike lesson — later
## runs aren't bigger, they're narrower.
static func target_scale(p_leg: int) -> float:
	return minf(1.0 + 0.18 * float(maxi(1, p_leg) - 1), 1.9)


## Rewards drift up more slowly than targets so late legs still feel worth
## doing without turning the score into a leg-number contest.
static func reward_scale(p_leg: int) -> float:
	return minf(1.0 + 0.10 * float(maxi(1, p_leg) - 1), 1.6)


## How many primaries you must complete to pass.
##
## Legs 1-2: 2. You are learning what a substance does to your legs; the game
##            should not be grading you yet.
## Legs 3-4: 3. The set also grows to 5 primaries here, so you get a real
##            choice about WHICH three — choice is what stops a required list
##            from reading as a chore.
## Legs 5+ : 4 of 6. Still not all of them. There is deliberately never a leg
##            where you must do everything, because "do everything" is the
##            exact structure that turns optional content into obligation.
## A zone may override how many of its primaries are required.
##
## THE FORMULA IS A CURVE AND THE CAMPAIGN HAS A TROUGH IN IT. `required` climbs
## with the leg number, which is right for six of the seven legs and wrong for
## the one whose entire job is to be a rest — docs/CAMPAIGN_SPEC.md §2.5 asks for
## **2 of 4** at the Stopover and the formula hands out 3, which is a notch
## tighter than the deep trough of the intensity curve is supposed to be.
##
## `docs/ROUTE_DATA.md` §7.2 has specified `required_override` for a long time
## and nothing has ever read it. This is the hook; `mission_defs_stopover.gd`'s
## header names its absence as the highest-value wiring change for that leg.
##
## Keyed by zone id rather than by leg, for the reason every table in this
## project is: leg numbers move and zone ids do not.
const REQUIRED_OVERRIDE := {
	&"stopover": 2,
}

## Par multiplier per zone. A grade is `score / par`, and par is a curve that
## assumes every leg is a chaos leg.
##
## LEG 5 IS NOT A CHAOS LEG. It is a 150-second rest beat at intensity 2 whose
## entire thesis is that the correct play may be to do nothing, and it was being
## graded against the unscaled leg-5 par of 9,600 — so a player who took the
## trough exactly as designed, sat on a pond and let their flock recover, got an
## F for it. The scoreboard was punishing the one behaviour the level exists to
## teach, which is worse than a missing feature: it is the game arguing against
## itself in the one place it least wanted to.
##
## 0.55 is docs/CAMPAIGN_SPEC.md §2.5's own number. Keyed by zone id for the
## reason every table here is: leg numbers move, zone ids do not.
const PAR_SCALE := {
	&"stopover": 0.55,
}


func _par_scale() -> float:
	if PAR_SCALE.has(zone_id):
		return maxf(0.05, float(PAR_SCALE[zone_id]))
	return 1.0


func required_primaries(p_leg: int) -> int:
	var n := primary_count()
	if n <= 0:
		return 0
	if REQUIRED_OVERRIDE.has(zone_id):
		var forced: int = int(REQUIRED_OVERRIDE[zone_id])
		return clampi(forced, 1, n)
	var req: int = 2 + int(floor(float(maxi(1, p_leg) - 1) / 2.0))
	# Never demand more than two-thirds-ish of what's on offer.
	return clampi(req, 1, maxi(1, n - 1))


func _current_leg() -> int:
	if _flock != null:
		var l: int = int(_flock.leg)
		return maxi(1, l)
	return 1


# ── THE LEG CLOCK ───────────────────────────────────────────────────────
# See the ZONE_SECONDS_* block at the top of the file for why these exist.

## The one clamp on a zone clock. Public so main.gd can call it instead of
## repeating the literals — that is the one-line change requested in
## docs/CLOCK_AND_CAMERA_NOTES.md. Until then the range here is deliberately
## identical to main.gd's, so the two already agree.
func clamp_zone_seconds(seconds: float) -> float:
	return clampf(seconds, ZONE_SECONDS_MIN, ZONE_SECONDS_MAX)


## The ROUTE's clock for `p_leg`, in seconds, BEFORE any mission modifier.
##
## Asks main.gd rather than assuming, because main.gd is where the number the
## game obeys lives. Three tiers, deliberately, and every one of them is real:
##
##   1. `Main.leg_seconds(leg)` — the public accessor requested in
##      docs/CLOCK_AND_CAMERA_NOTES.md. Preferred once it exists.
##   2. `ROUTE` read off Main's script constant map. Works against the CURRENT,
##      unmodified main.gd, so the clock lie is fixed today rather than
##      conditionally on somebody else applying a patch.
##   3. 180 s, only when there is no director in the tree at all.
##
## Out-of-range legs clamp to the ends of the route, matching `_route_entry()`.
func leg_seconds(p_leg: int) -> float:
	var m := _main_node()
	if m == null:
		return ZONE_SECONDS_FALLBACK
	if m.has_method("leg_seconds"):
		var s: float = float(m.leg_seconds(p_leg))
		if s > 0.0:
			return s
	var route := _route_of(m)
	if route.is_empty():
		return ZONE_SECONDS_FALLBACK
	var entry: Dictionary = route[clampi(p_leg - 1, 0, route.size() - 1)]
	return float(entry.get("seconds", ZONE_SECONDS_FALLBACK))


## The scene director. `/root/Main` in the shipping build; the recursive search
## and the current_scene check are there so a harness that instances main.tscn
## under a probe root still resolves — which is exactly how the seven-leg clock
## proof in docs/CLOCK_AND_CAMERA_NOTES.md is run.
func _main_node() -> Node:
	if _main != null and is_instance_valid(_main):
		return _main
	var t := get_tree()
	if t == null:
		return null
	var cands: Array[Node] = []
	if t.root != null:
		var direct := t.root.get_node_or_null(^"Main")
		if direct != null:
			cands.append(direct)
		var found := t.root.find_child("Main", true, false)
		if found != null:
			cands.append(found)
	if t.current_scene != null:
		cands.append(t.current_scene)
	for c in cands:
		if c.has_method("leg_seconds") or not _route_of(c).is_empty():
			_main = c
			return c
	return null


## ROUTE off a node's script. `get_script()` and the constant map are both
## Variant-typed, so both reads are annotated — `var x := node.get_script()` is
## the parse error this codebase breaks on most often.
func _route_of(n: Node) -> Array:
	var sc: Script = n.get_script()
	if sc == null:
		return []
	var consts: Dictionary = sc.get_script_constant_map()
	var v: Variant = consts.get("ROUTE", null)
	if v is Array:
		var route: Array = v
		return route
	return []


func _reset_stats() -> void:
	_stats = {
		&"chaos": 0.0,
		&"peak_combo": 0.0,
		&"peak_subs": 0.0,
		&"subs_taken": 0.0,
		&"sweet_spots": 0.0,
		&"overdoses": 0.0,
		&"blackouts": 0.0,
		&"shares": 0.0,
		&"honks": 0.0,
		&"hard_landings": 0.0,
		&"tumbles": 0.0,
		&"takeoffs": 0.0,
		&"airtime": 0.0,
		&"flight_streak": 0.0,
		&"longest_flight": 0.0,
		&"water_time": 0.0,
		&"peak_size": 1.0,
		&"min_size": 1.0,
		&"flock_intox": 0.0,
		&"peak_flock_intox": 0.0,
		&"combos_started": 0.0,
		&"post_blackout_chaos": 0.0,
		&"elapsed": 0.0,
		&"hits": 0.0,
	}
	_sets = {
		&"labels": {},
		&"subs": {},
		&"combos": {},
	}


# ══════════════════════════════════════════════════════ CONDITION GRAMMAR
#
# A condition is a Dictionary with a "type". Composites nest via "of".
#
#   label     count chaos-score labels
#             {labels: ["CART"], prefix: true, target: 8, when: {...}}
#             labels: [] means "any hit, whatever it was"
#   event     count named events fed by note() or the built-in hooks
#             {event: &"sub_taken", id: &"toad_slime", target: 1, when: {...}}
#   window    N matching hits inside a rolling T-second window (timed challenge)
#             {labels: ["CART"], target: 5, window: 6.0}
#   sequence  ordered steps, all inside one T-second window
#             {steps: [{labels:[..], count:3}, {labels:[..], count:1}], window: 14.0}
#   stat      threshold on tracked run state
#             {stat: &"peak_subs", op: &"gte", value: 2.0, before: 30.0}
#   unique    distinct entries in a tracked set
#             {set: &"combos", target: 3}
#   sustain   hold a predicate continuously for T seconds
#             {when: {airborne: true}, seconds: 12.0}
#   all/any   {of: [cond, cond, ...]}
#
# "when" is a predicate over live state, evaluated at the moment of the event:
#   subs_min / subs_max        simultaneous active substances
#   combo_min                  current chaos combo
#   airborne / in_water        bool
#   size_min / size_max        body scale
#   flock_intox_min/_max       flock average intoxication
#   blacked_out                bool
#   combo_active               a NAMED substance combo is running


func _scale_cond(cond: Dictionary, mult: float) -> Dictionary:
	var out: Dictionary = cond.duplicate(true)
	if is_equal_approx(mult, 1.0):
		return out
	var t: StringName = StringName(out.get("type", &"label"))
	if out.has("target"):
		var tgt: int = int(out["target"])
		# `unique` and `window` targets scale at HALF rate.
		#
		# Both are bounded by something the leg doesn't give you more of: a zone
		# has a fixed number of prop categories, and a ten-second window is ten
		# seconds on leg 8 exactly as it was on leg 1. Scaling them at the same
		# rate as a plain count produced "wreck 11 things inside ten seconds" by
		# leg 5, which is not difficult, it's a wall.
		var rate: float = mult
		if t == &"unique" or t == &"window":
			rate = 1.0 + (mult - 1.0) * 0.5
		var scaled_t: int = maxi(1, int(ceil(float(tgt) * rate)))
		# Hard ceiling: a zone contains what it contains. An objective asking
		# for 18 garbage bins in a cul-de-sac that has 10 is not an escalation,
		# it's a bug the player experiences as the game lying to them.
		if out.has("cap"):
			scaled_t = mini(scaled_t, int(out["cap"]))
		if t == &"unique":
			scaled_t = mini(scaled_t, 9)
		out["target"] = scaled_t
	if t == &"all" or t == &"any":
		var kids: Array = out.get("of", [])
		var scaled: Array = []
		for k in kids:
			var kd: Dictionary = k
			scaled.append(_scale_cond(kd, mult))
		out["of"] = scaled
	return out


## The number an objective's text is talking about, after leg scaling.
func _cond_target(cond: Dictionary) -> int:
	var t: StringName = StringName(cond.get("type", &"label"))
	match t:
		&"sustain":
			return int(cond.get("seconds", 10))
		&"stat":
			return int(cond.get("value", 1))
		&"all", &"any":
			var kids: Array = cond.get("of", [])
			return kids.size()
		&"sequence":
			var steps: Array = cond.get("steps", [])
			return steps.size()
		_:
			return int(cond.get("target", 1))


func _make_state(cond: Dictionary) -> Dictionary:
	var st: Dictionary = {
		"prog": 0.0,
		"hits": [],       ## Array[float] timestamps, for window conditions
		"sustain": 0.0,
		"step": 0,
		"step_count": 0,
		"t0": -1.0,
		"met": false,
		"subs": [],
	}
	var t: StringName = StringName(cond.get("type", &"label"))
	if t == &"all" or t == &"any":
		var kids: Array = cond.get("of", [])
		var sub_states: Array = []
		for k in kids:
			var kd: Dictionary = k
			sub_states.append(_make_state(kd))
		st["subs"] = sub_states
	return st


# ══════════════════════════════════════════════════════════ SIGNAL INTAKE

func _connect_globals() -> void:
	if _game != null and _game.has_signal("chaos_scored"):
		if not _game.chaos_scored.is_connected(_on_chaos):
			_game.chaos_scored.connect(_on_chaos)
	if _subs == null:
		return
	if _subs.has_signal("substance_taken") and not _subs.substance_taken.is_connected(_on_sub_taken):
		_subs.substance_taken.connect(_on_sub_taken)
	if _subs.has_signal("substance_ended") and not _subs.substance_ended.is_connected(_on_sub_ended):
		_subs.substance_ended.connect(_on_sub_ended)
	if _subs.has_signal("combo_started") and not _subs.combo_started.is_connected(_on_combo):
		_subs.combo_started.connect(_on_combo)
	if _subs.has_signal("blackout_started") and not _subs.blackout_started.is_connected(_on_blackout):
		_subs.blackout_started.connect(_on_blackout)
	if _subs.has_signal("blackout_ended") and not _subs.blackout_ended.is_connected(_on_wake):
		_subs.blackout_ended.connect(_on_wake)


func _on_chaos(amount: int, _total: int, combo: int, label: String) -> void:
	if not running:
		return
	if _is_self_label(label):
		return
	_stats[&"chaos"] = float(_stats[&"chaos"]) + float(amount)
	_stats[&"hits"] = float(_stats[&"hits"]) + 1.0
	_stats[&"peak_combo"] = maxf(float(_stats[&"peak_combo"]), float(combo))
	if _wake_until > 0.0 and _elapsed <= _wake_until:
		_stats[&"post_blackout_chaos"] = float(_stats[&"post_blackout_chaos"]) + float(amount)
	# Category set for "different kinds of thing" objectives. Strip the "!!"
	# the break score appends so a smashed cart isn't its own category.
	var base := label.trim_suffix("!!")
	var lset: Dictionary = _sets[&"labels"]
	lset[base] = true
	if label.begins_with("HONK"):
		_stats[&"honks"] = float(_stats[&"honks"]) + 1.0
	elif label == "SWEET SPOT":
		_stats[&"sweet_spots"] = float(_stats[&"sweet_spots"]) + 1.0
	elif label == "OVERDOSE":
		_stats[&"overdoses"] = float(_stats[&"overdoses"]) + 1.0
	elif label == "SHARED WITH THE FLOCK":
		_stats[&"shares"] = float(_stats[&"shares"]) + 1.0

	var ev: Dictionary = {"_kind": &"label", "label": label, "amount": amount, "combo": combo}
	_dispatch(ev)


func _is_self_label(label: String) -> bool:
	for s in SELF_LABELS:
		if label.begins_with(String(s)):
			return true
	return false


func _on_sub_taken(res, dose: float, _resolved: Dictionary) -> void:
	if not running or res == null:
		return
	_stats[&"subs_taken"] = float(_stats[&"subs_taken"]) + 1.0
	var sset: Dictionary = _sets[&"subs"]
	sset[res.id] = true
	if _subs != null:
		var n: int = _subs.actives.size()
		_stats[&"peak_subs"] = maxf(float(_stats[&"peak_subs"]), float(n))
	note(&"sub_taken", {"id": res.id, "dose": dose})


func _on_sub_ended(id: StringName) -> void:
	if not running:
		return
	note(&"sub_ended", {"id": id})


func _on_combo(combo_name: String) -> void:
	if not running:
		return
	_stats[&"combos_started"] = float(_stats[&"combos_started"]) + 1.0
	var cset: Dictionary = _sets[&"combos"]
	cset[combo_name] = true
	note(&"combo", {"name": combo_name})


func _on_blackout() -> void:
	if not running:
		return
	_stats[&"blackouts"] = float(_stats[&"blackouts"]) + 1.0
	note(&"blackout", {})


## Coming to after a blackout opens a 25-second window in which chaos counts
## double-duty toward the comeback objective.
func _on_wake() -> void:
	if not running:
		return
	_wake_until = _elapsed + 25.0
	_stats[&"post_blackout_chaos"] = 0.0
	note(&"wake", {})


func _on_landed(hard: bool, speed: float) -> void:
	if not running:
		return
	if hard:
		_stats[&"hard_landings"] = float(_stats[&"hard_landings"]) + 1.0
	_end_flight_streak()
	note(&"landed", {"hard": hard, "speed": speed})


func _on_tumbled() -> void:
	if not running:
		return
	_stats[&"tumbles"] = float(_stats[&"tumbles"]) + 1.0
	note(&"tumbled", {})


func _on_took_off() -> void:
	if not running:
		return
	_stats[&"takeoffs"] = float(_stats[&"takeoffs"]) + 1.0
	note(&"took_off", {})


func _end_flight_streak() -> void:
	var streak: float = float(_stats[&"flight_streak"])
	_stats[&"longest_flight"] = maxf(float(_stats[&"longest_flight"]), streak)
	_stats[&"flight_streak"] = 0.0


# ═══════════════════════════════════════════════════════════════════ TICK

func _process(delta: float) -> void:
	if not running:
		return
	# Real seconds. Engine.time_scale swings hard during slow-motion combos and
	# a timed challenge that gets easier because you took a substance would be
	# an exploit, not a feature.
	var dt := delta / maxf(Engine.time_scale, 0.05)
	_elapsed += dt
	_stats[&"elapsed"] = _elapsed
	_sample_state(dt)
	_tick_objectives(dt)


func _sample_state(dt: float) -> void:
	if _goose != null and is_instance_valid(_goose):
		var sz: float = float(_goose.size)
		_stats[&"peak_size"] = maxf(float(_stats[&"peak_size"]), sz)
		_stats[&"min_size"] = minf(float(_stats[&"min_size"]), sz)
		if _is_airborne():
			_stats[&"airtime"] = float(_stats[&"airtime"]) + dt
			var streak: float = float(_stats[&"flight_streak"]) + dt
			_stats[&"flight_streak"] = streak
			_stats[&"longest_flight"] = maxf(float(_stats[&"longest_flight"]), streak)
		else:
			_stats[&"flight_streak"] = 0.0
		if _in_water():
			_stats[&"water_time"] = float(_stats[&"water_time"]) + dt
	if _subs != null:
		var n: int = _subs.actives.size()
		_stats[&"peak_subs"] = maxf(float(_stats[&"peak_subs"]), float(n))
	if _flock != null:
		var fi: float = float(_flock.average_intox())
		_stats[&"flock_intox"] = fi
		_stats[&"peak_flock_intox"] = maxf(float(_stats[&"peak_flock_intox"]), fi)


func _tick_objectives(dt: float) -> void:
	for i in _objs.size():
		var obj: Dictionary = _objs[i]
		if obj.done or obj.late:
			continue
		var cond: Dictionary = obj.cond
		var state: Dictionary = obj.state
		var before: float = float(_node_prog(cond, state).x)
		_tick_node(cond, state, dt)
		var after: float = float(_node_prog(cond, state).x)
		if not is_equal_approx(before, after):
			_announce_progress(obj)
		if _node_met(cond, state):
			_complete(obj)


# ══════════════════════════════════════════════════════════ EVENT ROUTING

func _dispatch(ev: Dictionary) -> void:
	for i in _objs.size():
		var obj: Dictionary = _objs[i]
		if obj.done or obj.late:
			continue
		var cond: Dictionary = obj.cond
		var state: Dictionary = obj.state
		var before: float = float(_node_prog(cond, state).x)
		_feed_node(cond, state, ev)
		var after: float = float(_node_prog(cond, state).x)
		if not is_equal_approx(before, after):
			_announce_progress(obj)
		if _node_met(cond, state):
			_complete(obj)


func _announce_progress(obj: Dictionary) -> void:
	# Hidden objectives stay silent until they fire. Progress-pinging an
	# objective the player can't see is just noise with a mystery attached.
	if int(obj.kind) == Kind.HIDDEN and not bool(obj.revealed):
		return
	var pv: Vector2 = _node_prog(obj.cond, obj.state)
	objective_progressed.emit(obj.id, int(pv.x), int(pv.y), int(obj.kind))


# ═══════════════════════════════════════════════════════════ NODE MACHINE

func _feed_node(cond: Dictionary, st: Dictionary, ev: Dictionary) -> void:
	var t: StringName = StringName(cond.get("type", &"label"))
	match t:
		&"all", &"any":
			var kids: Array = cond.get("of", [])
			var sub_states: Array = st.subs
			for i in kids.size():
				if i >= sub_states.size():
					break
				var kd: Dictionary = kids[i]
				var ks: Dictionary = sub_states[i]
				_feed_node(kd, ks, ev)
		&"label", &"event":
			if not _ev_matches(cond, ev):
				return
			if not _predicate_ok(cond.get("when", {})):
				return
			var tgt: int = int(cond.get("target", 1))
			st["prog"] = minf(float(tgt), float(st.prog) + 1.0)
		&"window":
			if not _ev_matches(cond, ev):
				return
			if not _predicate_ok(cond.get("when", {})):
				return
			var hits: Array = st.hits
			hits.append(_elapsed)
			_prune(hits, float(cond.get("window", 10.0)))
			st["prog"] = float(hits.size())
		&"sequence":
			_feed_sequence(cond, st, ev)
		_:
			pass


func _feed_sequence(cond: Dictionary, st: Dictionary, ev: Dictionary) -> void:
	var steps: Array = cond.get("steps", [])
	if steps.is_empty():
		return
	var idx: int = int(st.step)
	if idx >= steps.size():
		return
	var window: float = float(cond.get("window", 12.0))
	# Started but stale? Drop back to the beginning. A sequence objective that
	# accepts a bounce from ninety seconds ago isn't a sequence.
	var t0: float = float(st.t0)
	if t0 >= 0.0 and _elapsed - t0 > window:
		st["step"] = 0
		st["step_count"] = 0
		st["t0"] = -1.0
		st["prog"] = 0.0
		idx = 0
	var step: Dictionary = steps[idx]
	if not _ev_matches(step, ev):
		return
	if not _predicate_ok(step.get("when", {})):
		return
	if float(st.t0) < 0.0:
		st["t0"] = _elapsed
	var need: int = int(step.get("count", 1))
	var sc: int = int(st.step_count) + 1
	if sc >= need:
		st["step"] = idx + 1
		st["step_count"] = 0
	else:
		st["step_count"] = sc
	st["prog"] = float(st.step)


func _tick_node(cond: Dictionary, st: Dictionary, dt: float) -> void:
	var t: StringName = StringName(cond.get("type", &"label"))
	match t:
		&"all", &"any":
			var kids: Array = cond.get("of", [])
			var sub_states: Array = st.subs
			for i in kids.size():
				if i >= sub_states.size():
					break
				var kd: Dictionary = kids[i]
				var ks: Dictionary = sub_states[i]
				_tick_node(kd, ks, dt)
		&"window":
			var hits: Array = st.hits
			var n0 := hits.size()
			_prune(hits, float(cond.get("window", 10.0)))
			if hits.size() != n0:
				st["prog"] = float(hits.size())
		&"sequence":
			var t0: float = float(st.t0)
			if t0 >= 0.0 and _elapsed - t0 > float(cond.get("window", 12.0)):
				st["step"] = 0
				st["step_count"] = 0
				st["t0"] = -1.0
				st["prog"] = 0.0
		&"sustain":
			if _predicate_ok(cond.get("when", {})):
				st["sustain"] = float(st.sustain) + dt
			else:
				st["sustain"] = 0.0
			st["prog"] = float(st.sustain)
		&"unique":
			var key: StringName = StringName(cond.get("set", &"labels"))
			var s: Dictionary = _sets.get(key, {})
			st["prog"] = minf(float(int(cond.get("target", 1))), float(s.size()))
		&"stat":
			# A "before T" stat condition latches: once you've done 500 chaos in
			# the first 30 seconds, dropping past 30 seconds must not un-earn it.
			if bool(st.met):
				return
			var before_t: float = float(cond.get("before", -1.0))
			if before_t > 0.0 and _elapsed > before_t:
				st["prog"] = 0.0
				return
			var v: float = _stat(StringName(cond.get("stat", &"chaos")))
			var target_v: float = float(cond.get("value", 1.0))
			var op: StringName = StringName(cond.get("op", &"gte"))
			var ok := v >= target_v if op == &"gte" else v <= target_v
			if ok:
				st["met"] = true
				st["prog"] = 1.0
			elif op == &"gte" and target_v > 0.0:
				st["prog"] = clampf(v / target_v, 0.0, 0.999)
			else:
				st["prog"] = 0.0
		_:
			pass


## Does this event satisfy the matcher part of `cond`?
func _ev_matches(cond: Dictionary, ev: Dictionary) -> bool:
	var ekind: StringName = StringName(ev.get("_kind", &"label"))
	if cond.has("event"):
		if ekind != &"event":
			return false
		if StringName(ev.get("_event", &"")) != StringName(cond["event"]):
			return false
		# Optional payload narrowing, e.g. a specific substance id.
		if cond.has("id"):
			if StringName(ev.get("id", &"")) != StringName(cond["id"]):
				return false
		return true
	if ekind != &"label":
		return false
	var labels: Array = cond.get("labels", [])
	if labels.is_empty():
		return true  # "any hit counts"
	var lab: String = String(ev.get("label", ""))
	var prefix: bool = bool(cond.get("prefix", true))
	for l in labels:
		var s: String = String(l)
		if prefix:
			if lab.begins_with(s):
				return true
		elif lab == s or lab == s + "!!":
			# Exact matchers still accept the doubled break score — the player
			# smashed the thing; refusing to count it is a bug, not a rule.
			return true
	return false


func _prune(hits: Array, window: float) -> void:
	var cutoff := _elapsed - window
	while not hits.is_empty() and float(hits[0]) < cutoff:
		hits.remove_at(0)


## (current, target) for display. Always integers on screen.
func _node_prog(cond: Dictionary, st: Dictionary) -> Vector2:
	var t: StringName = StringName(cond.get("type", &"label"))
	match t:
		&"all":
			var kids: Array = cond.get("of", [])
			var sub_states: Array = st.subs
			var n := 0
			for i in kids.size():
				if i >= sub_states.size():
					break
				var kd: Dictionary = kids[i]
				var ks: Dictionary = sub_states[i]
				if _node_met(kd, ks):
					n += 1
			return Vector2(float(n), float(kids.size()))
		&"any":
			return Vector2(1.0 if _node_met(cond, st) else 0.0, 1.0)
		&"sustain":
			return Vector2(floor(float(st.sustain)), float(cond.get("seconds", 10.0)))
		&"stat":
			var target_v: float = float(cond.get("value", 1.0))
			var op: StringName = StringName(cond.get("op", &"gte"))
			if op == &"gte" and target_v > 0.0 and not bool(st.met):
				return Vector2(floor(_stat(StringName(cond.get("stat", &"chaos")))), target_v)
			return Vector2(1.0 if bool(st.met) else 0.0, 1.0)
		&"sequence":
			var steps: Array = cond.get("steps", [])
			return Vector2(float(st.step), float(steps.size()))
		_:
			return Vector2(float(st.prog), float(int(cond.get("target", 1))))


func _node_met(cond: Dictionary, st: Dictionary) -> bool:
	var t: StringName = StringName(cond.get("type", &"label"))
	match t:
		&"all":
			var kids_a: Array = cond.get("of", [])
			var states_a: Array = st.subs
			if kids_a.is_empty():
				return false
			for i in kids_a.size():
				if i >= states_a.size():
					return false
				var kd: Dictionary = kids_a[i]
				var ks: Dictionary = states_a[i]
				if not _node_met(kd, ks):
					return false
			return true
		&"any":
			var kids_b: Array = cond.get("of", [])
			var states_b: Array = st.subs
			for i in kids_b.size():
				if i >= states_b.size():
					break
				var kd2: Dictionary = kids_b[i]
				var ks2: Dictionary = states_b[i]
				if _node_met(kd2, ks2):
					return true
			return false
		&"stat":
			return bool(st.met)
		&"sustain":
			return float(st.sustain) >= float(cond.get("seconds", 10.0))
		&"sequence":
			var steps: Array = cond.get("steps", [])
			return int(st.step) >= steps.size() and not steps.is_empty()
		_:
			return float(st.prog) >= float(int(cond.get("target", 1)))


func _stat(key: StringName) -> float:
	# Chaos is mirrored from Game when available so the stat survives anything
	# that scores without going through our own handler.
	if key == &"chaos" and _game != null:
		return maxf(float(_stats.get(&"chaos", 0.0)), float(_game.leg_chaos))
	return float(_stats.get(key, 0.0))


# ═══════════════════════════════════════════════════════════════ PREDICATE

func _predicate_ok(w: Dictionary) -> bool:
	if w.is_empty():
		return true
	if w.has("subs_min") or w.has("subs_max"):
		var n := 0
		if _subs != null:
			n = _subs.actives.size()
		if w.has("subs_min") and n < int(w["subs_min"]):
			return false
		if w.has("subs_max") and n > int(w["subs_max"]):
			return false
	if w.has("combo_min"):
		var c := 0
		if _game != null:
			c = int(_game.combo)
		if c < int(w["combo_min"]):
			return false
	if w.has("airborne"):
		if _is_airborne() != bool(w["airborne"]):
			return false
	if w.has("in_water"):
		if _in_water() != bool(w["in_water"]):
			return false
	if w.has("size_min") or w.has("size_max"):
		var sz := 1.0
		if _goose != null and is_instance_valid(_goose):
			sz = float(_goose.size)
		if w.has("size_min") and sz < float(w["size_min"]):
			return false
		if w.has("size_max") and sz > float(w["size_max"]):
			return false
	if w.has("flock_intox_min") or w.has("flock_intox_max"):
		var fi := 0.0
		if _flock != null:
			fi = float(_flock.average_intox())
		if w.has("flock_intox_min") and fi < float(w["flock_intox_min"]):
			return false
		if w.has("flock_intox_max") and fi > float(w["flock_intox_max"]):
			return false
	if w.has("blacked_out"):
		var bo := false
		if _subs != null:
			bo = bool(_subs.blacked_out)
		if bo != bool(w["blacked_out"]):
			return false
	if w.has("combo_active"):
		var ca := false
		if _subs != null:
			ca = String(_subs.active_combo) != ""
		if ca != bool(w["combo_active"]):
			return false
	return true


func _is_airborne() -> bool:
	if _goose == null or not is_instance_valid(_goose):
		return false
	if _goose.has_method("is_airborne"):
		return bool(_goose.is_airborne())
	return false


func _in_water() -> bool:
	if _goose == null or not is_instance_valid(_goose):
		return false
	if _goose.has_method("state_name"):
		return String(_goose.state_name()) == "WATER"
	return false


# ══════════════════════════════════════════════════════════════ COMPLETION

func _complete(obj: Dictionary) -> void:
	if bool(obj.done):
		return
	obj["done"] = true
	var kind: int = int(obj.kind)
	var reward: int = int(obj.reward)
	var id: StringName = obj.id

	# Payout goes through Game.score so it inherits the combo multiplier and
	# shows up in the same feed as everything else. The label is filtered out of
	# every condition, so this can never feed back into an objective.
	if _game != null and reward > 0:
		var label := "OBJECTIVE"
		if kind == Kind.BONUS:
			label = "BONUS OBJECTIVE"
		elif kind == Kind.HIDDEN:
			label = "HIDDEN"
		_game.score(reward, label)

	var fl: Dictionary = obj.get("flock", {})
	if _flock != null and not fl.is_empty():
		_apply_flock(fl)

	if kind == Kind.HIDDEN:
		obj["revealed"] = true
		if _sfx != null:
			_sfx.play(&"unlock")
		hidden_revealed.emit(id, String(obj.title), String(obj.line), reward)
	else:
		if _sfx != null:
			_sfx.play(&"score_blip_hi")
	objective_completed.emit(id, kind, reward)

	if kind == Kind.PRIMARY and primaries_done() >= _required:
		primaries_completed.emit()


func _apply_flock(fl: Dictionary) -> void:
	var st: float = float(fl.get("stamina", 0.0))
	var ix: float = float(fl.get("intox", 0.0))
	if is_zero_approx(st) and is_zero_approx(ix):
		return
	var birds: Array = _flock.birds
	for b in birds:
		var bird: Dictionary = b
		if not bool(bird.alive):
			continue
		if not is_zero_approx(st):
			bird["stamina"] = clampf(float(bird.stamina) + st, 0.0, 1.0)
		if not is_zero_approx(ix):
			bird["intox"] = clampf(float(bird.intox) + ix, 0.0, 1.0)


# ══════════════════════════════════════════════════════════════ QUERIES

func primary_count() -> int:
	var n := 0
	for o in _objs:
		var obj: Dictionary = o
		if int(obj.kind) == Kind.PRIMARY:
			n += 1
	return n


func primaries_done() -> int:
	var n := 0
	for o in _objs:
		var obj: Dictionary = o
		if int(obj.kind) == Kind.PRIMARY and bool(obj.done):
			n += 1
	return n


func required_count() -> int:
	return _required


## Everything the HUD is allowed to draw right now: primaries, bonuses, and
## any hidden objective that has already announced itself.
func visible_objectives() -> Array:
	var out: Array = []
	for o in _objs:
		var obj: Dictionary = o
		if int(obj.kind) == Kind.HIDDEN and not bool(obj.revealed):
			continue
		out.append(_row(obj))
	return out


func objective_row(id: StringName) -> Dictionary:
	for o in _objs:
		var obj: Dictionary = o
		if StringName(obj.id) == id:
			return _row(obj)
	return {}


func _row(obj: Dictionary) -> Dictionary:
	var pv: Vector2 = _node_prog(obj.cond, obj.state)
	var text := String(obj.text)
	if bool(obj.done) and String(obj.done_text) != "":
		text = String(obj.done_text)
	return {
		"id": obj.id,
		"kind": int(obj.kind),
		"text": text,
		"hint": String(obj.hint),
		"title": String(obj.title),
		"line": String(obj.line),
		"reward": int(obj.reward),
		"progress": int(pv.x),
		"target": int(pv.y),
		"done": bool(obj.done),
		"order": int(obj.order),
		"unit": "s" if StringName(obj.cond.get("type", &"")) == &"sustain" else "",
	}


func stat(key: StringName) -> float:
	return _stat(key)


func hidden_total() -> int:
	var n := 0
	for o in _objs:
		var obj: Dictionary = o
		if int(obj.kind) == Kind.HIDDEN:
			n += 1
	return n


func hidden_found() -> int:
	var n := 0
	for o in _objs:
		var obj: Dictionary = o
		if int(obj.kind) == Kind.HIDDEN and bool(obj.done):
			n += 1
	return n


# ═══════════════════════════════════════════════════════════════ VERDICT

## The whole point of the system. Structured so the results screen, the
## migration and the next zone's clock can all read one dictionary.
func evaluate_leg() -> Dictionary:
	# Late objectives — the ones that are a verdict on the whole leg rather
	# than a moment inside it — get their one and only look here.
	for o in _objs:
		var obj: Dictionary = o
		if not bool(obj.late) or bool(obj.done):
			continue
		_tick_node(obj.cond, obj.state, 0.0)
		if _node_met(obj.cond, obj.state):
			_complete(obj)

	var completed: Array = []
	var missed: Array = []
	var hidden: Array = []
	var obj_bonus := 0
	var hidden_bonus := 0

	for o in _objs:
		var obj: Dictionary = o
		var kind: int = int(obj.kind)
		var id: StringName = obj.id
		if bool(obj.done):
			if kind == Kind.HIDDEN:
				hidden.append(id)
				hidden_bonus += int(obj.reward)
			else:
				completed.append(id)
				obj_bonus += int(obj.reward)
		elif kind != Kind.HIDDEN:
			missed.append(id)

	var done_p := primaries_done()
	var passed := done_p >= _required
	var chaos_pts: int = int(_stat(&"chaos"))

	# Style is the "you played with flair" axis: chaining and chemistry, the
	# two things the objective list can't fully capture.
	var style: int = int(round(_stat(&"peak_combo") * 25.0))
	var cset: Dictionary = _sets.get(&"combos", {})
	style += cset.size() * 120
	style += int(_stat(&"peak_subs")) * 60

	# NEITHER objective bonus is an addend here, and for the same reason: every
	# payout in `_complete()` — PRIMARY, BONUS and HIDDEN alike — goes through
	# `Game.score()`, which adds it to `Game.leg_chaos`, and `_stat(&"chaos")`
	# returns `max(_stats.chaos, _game.leg_chaos)`. So `chaos_pts` ALREADY
	# contains both, at their combo-multiplied value. `obj_bonus` was correctly
	# left out; `hidden_bonus` was not, and re-added the raw reward of every
	# secret on top of the multiplied one already counted — up to ~2,500 of
	# phantom score on a good leg, which is a whole grade band. The two names
	# survive because the results card itemises them; they are a BREAKDOWN of
	# `chaos_pts`, not additions to it.
	var total := chaos_pts + style
	# Par rises 15% a leg. Deliberately slower than the player improves, so a
	# veteran on leg 6 feels the escalation in the OBJECTIVES (which have gone
	# from "hit 8 carts" to "hit 6 things in ten seconds without landing") and
	# not in a score bar that quietly outruns them.
	# Par grows with the leg, but CAPS where the objective escalation caps.
	# Without the cap, par kept climbing past leg 6 while the achievable score
	# stopped, so grades decayed toward F purely as a function of leg number —
	# the scoreboard punishing you for surviving.
	var par_leg: int = mini(maxi(1, leg), 6)
	var par := PAR_BASE * (1.0 + 0.15 * float(par_leg - 1)) * _par_scale()
	var ratio := float(total) / maxf(par, 1.0)

	var gi := 0
	if ratio >= 1.75: gi = 5
	elif ratio >= 1.35: gi = 4
	elif ratio >= 1.0: gi = 3
	elif ratio >= 0.7: gi = 2
	elif ratio >= 0.45: gi = 1
	# Missing the primaries caps you at a C no matter how much you scored.
	# Otherwise "ignore the objectives, hit things fast" always beats the
	# system, and the objectives are decoration again.
	if not passed:
		gi = mini(gi, 2)

	# ── SOFT FAIL ────────────────────────────────────────────────────────
	# You never lose the run. You lose comfort. Missing primaries costs 20
	# seconds each off the next leg's clock (floored, so a disastrous leg is
	# still a playable one), and the flock gets a little more tired because
	# they spent the afternoon watching you do nothing.
	var shortfall: int = maxi(0, _required - done_p)
	var modifier := -20.0 * float(shortfall)
	if passed:
		# Overachieving buys a little back, capped. A reward you can bank
		# forever turns into a snowball; a reward that tops out is a pat on
		# the head, which is all it needs to be.
		modifier = minf(10.0 * float(gi - 2), 20.0)
	# The base is the NEXT leg's clock, taken from the ROUTE rather than assumed
	# to be 180 — main.gd increments the leg before it reads the route, so what
	# this card is promising is `ROUTE[leg + 1]`. Same clamp main.gd applies, in
	# one function, so the promise and the payout cannot drift apart again.
	var next_base := leg_seconds(leg + 1)
	var next_seconds := clamp_zone_seconds(next_base + modifier)
	# AND THE SHORT-LANDING CLOCK IS A DIFFERENT LEG'S.
	#
	# The card quotes two futures: "make the crossing and the next leg is
	# X", and "land short and it is Y". Landing short does NOT advance the
	# leg — `main.gd::_on_migration_done()` only increments on `made_it` — so
	# the player replays THIS one. The card was deriving both from
	# `leg_seconds(leg + 1)`, so on every leg whose clock differs from the
	# next one it promised the wrong number: leg 1 is 240 and leg 2 is 180,
	# so failing flight 1 was advertised as a 120 s retry of a 240 s zone.
	var short_base := leg_seconds(leg)

	var flock_note := ""
	if not passed:
		flock_note = "The flock watched you accomplish very little."
		if _flock != null:
			for b in _flock.birds:
				var bird: Dictionary = b
				if bool(bird.alive):
					bird["stamina"] = clampf(float(bird.stamina) - 0.08, 0.0, 1.0)
	elif _stat(&"flock_intox") > 0.5:
		flock_note = "Everyone is wrecked. This flight is going to be a story."
	elif gi >= 4:
		flock_note = "The flock is fed, rested, and slightly frightened of you."

	var result: Dictionary = {
		"zone": zone_id,
		"leg": leg,
		"passed": passed,
		"required": _required,
		"primaries_total": primary_count(),
		"primaries_done": done_p,
		"completed": completed,
		"missed": missed,
		"hidden_found": hidden,
		"hidden_total": hidden_total(),
		"breakdown": {
			"chaos": chaos_pts,
			"objectives": obj_bonus,
			"hidden": hidden_bonus,
			"style": style,
			# `objectives` and `hidden` are ITEMISATIONS of `chaos`, not addends.
			# Both payouts went through Game.score() and are already inside it.
			# `total` is chaos + style and nothing else — see the comment on the
			# `total` assignment above. The old note here claimed the hidden
			# double-count was already fixed while the line above was still
			# doing it, which is worse than no comment: it tells the next reader
			# not to look.
			"total": total,
			"par": int(par),
		},
		"grade": GRADES[gi],
		"grade_index": gi,
		"rank_text": RANK_LINES[gi],
		"zone_time_modifier": modifier,
		"next_zone_seconds": next_seconds,
		# The unmodified route clock the card should quote as "base". Was assumed
		# to be 3:00 on the card too, which was wrong on exactly the legs the
		# promise itself was wrong on.
		"next_zone_base": next_base,
		# The clock a SHORT landing replays, which is this leg's and not the
		# next one's. See `short_base` above.
		"short_zone_base": short_base,
		"flock_note": flock_note,
	}
	return result


## Last computed verdict, or {} if the leg is still running.
func last_result() -> Dictionary:
	return _result


## Debug: dump the live objective table. Used by the headless harness.
func debug_dump() -> String:
	var lines: Array = []
	lines.append("LEG %d — %s — need %d of %d primaries" % [leg, String(zone_id), _required, primary_count()])
	for o in _objs:
		var obj: Dictionary = o
		var kind: int = int(obj.kind)
		var tag: String = ["PRIMARY", "BONUS  ", "HIDDEN "][kind]
		var pv: Vector2 = _node_prog(obj.cond, obj.state)
		var mark := "x" if bool(obj.done) else " "
		var name_txt := String(obj.text)
		if kind == Kind.HIDDEN and not bool(obj.revealed):
			name_txt = "??? (%s)" % String(obj.id)
		lines.append("  [%s] %s %-46s %d/%d" % [mark, tag, name_txt, int(pv.x), int(pv.y)])
	return "\n".join(lines)
