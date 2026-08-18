extends Node
## Autoload: Flock
##
## The flock is DATA during a zone and only becomes physical birds during the
## migration flight. This is the scope-saving decision of the whole project:
## no flock AI has to survive the chaos sandbox.
##
## What you did in the zone rides along in here. The zone is where you write
## the cheque. The migration is where it clears.

signal bird_dosed(index: int, amount: float)
signal bird_lost(index: int, bird_name: String)
## A bird survived something it nearly didn't. `reason` is the line the roster
## prints, so it is written in the past tense and names a place.
signal bird_scarred(index: int, reason: String)

const NAMES := [
	"Gord", "Wayne", "Céline", "Shania", "Bruce", "Margaret",
	"Terry", "Rick", "Stompin' Tom", "Bobby", "Doug", "Hayley",
]

## intox 0..1  — how wrecked. Drives formation drift and disqualifies from lead.
## stamina 0..1 — burns fast at the point of the V, recovers while drafting.
## Which entry is the player's own bird. It can be dosed and exhausted like
## any other, but it can NEVER be lost — that is what guarantees the journey
## always has someone to finish it, and it is why the empty-flock case became
## unreachable rather than merely handled.
var player_index := 0

var birds: Array[Dictionary] = []
var leg: int = 1

## How many scar lines a bird remembers. A goose with a nine-line rap sheet is a
## spreadsheet; a goose with three is a character.
const SCAR_LOG_MAX := 3

## What each scar costs a bird at the point of the V, per scar, capped at
## SCAR_LEAD_CAP scars. See can_lead().
const SCAR_LEAD_PENALTY := 0.05
const SCAR_LEAD_CAP := 3


func _ready() -> void:
	if birds.is_empty():
		new_flock(6)


func new_flock(n: int) -> void:
	birds.clear()
	_topped_up = false
	var pool := NAMES.duplicate()
	pool.shuffle()
	for i in n:
		birds.append({
			"name": pool[i % pool.size()],
			"is_dd": false,
			"intox": 0.0,
			"stamina": 1.0,
			"alive": true,
			"scars": 0,
			# What it survived, most recent last. Read by the roster screen; this
			# is the difference between "scars: 2" and "clipped a wire over
			# Buffalo", and the second one is the only one anybody cares about.
			"scar_log": [],
			# How and where it left the flock. Empty while alive.
			"lost_reason": "",
			"lost_leg": 0,
			"joined_at_leg": 1,
		})
	# Nobody starts as the DD. Making one is a choice you pay for in the zone.


func alive_birds() -> Array[Dictionary]:
	return birds.filter(func(b): return b.alive)


func designated_driver() -> int:
	for i in birds.size():
		if birds[i].is_dd and birds[i].alive:
			return i
	return -1


## Assign the DD. The DD refuses every substance for the rest of the run.
func set_dd(index: int) -> void:
	for b in birds:
		b.is_dd = false
	if index >= 0 and index < birds.size():
		birds[index].is_dd = true
		birds[index].intox = 0.0


## Share what you're on with the flock. Great for chaos, terrible for the flight.
func dose_flock(amount: float) -> void:
	for i in birds.size():
		var b := birds[i]
		if not b.alive or b.is_dd:
			continue
		b.intox = clampf(b.intox + amount, 0.0, 1.0)
		bird_dosed.emit(i, amount)


func dose_bird(index: int, amount: float) -> void:
	if index < 0 or index >= birds.size():
		return
	var b := birds[index]
	if not b.alive or b.is_dd:
		return
	b.intox = clampf(b.intox + amount, 0.0, 1.0)
	bird_dosed.emit(index, amount)


## Can this bird hold the point of the V?
## The lead gets NO drafting benefit and burns far more energy — which is why
## real geese rotate the lead. A wrecked bird cannot take a shift.
##
## A SCARRED bird is slightly worse at it. Each scar tightens both thresholds by
## SCAR_LEAD_PENALTY, capped at three scars: at the cap a bird needs to be under
## 0.30 intox and over 0.40 stamina instead of 0.45 / 0.25. That is deliberately
## small — it never disqualifies a rested goose, it just means the ones that have
## been through something drop out of the rotation first, which is what turns a
## scar from a label on a menu into a reason the flight got harder.
func can_lead(index: int) -> bool:
	if index < 0 or index >= birds.size():
		return false
	var b := birds[index]
	var wear := float(mini(int(b.get("scars", 0)), SCAR_LEAD_CAP)) * SCAR_LEAD_PENALTY
	return b.alive and b.intox < 0.45 - wear and b.stamina > 0.25 + wear


func lead_candidates() -> Array[int]:
	var out: Array[int] = []
	for i in birds.size():
		if can_lead(i):
			out.append(i)
	return out


## `reason` is what the roster screen prints under the struck-out name — the
## whole point of recording it is that a loss should have a cause the player can
## read back, not just a gap in the list. Written in the past tense, naming a
## place: "hit a turbine over Buffalo".
func lose_bird(index: int, reason: String = "") -> void:
	if index < 0 or index >= birds.size():
		return
	# The player's own bird is never lost. Without this the run can end with
	# zero geese, which the migration handles by spawning nothing, finishing at
	# 0 km, awarding a short zone, and repeating that forever — a soft-lock
	# dressed as difficulty.
	if index == player_index:
		return
	if not birds[index].alive:
		return
	birds[index].alive = false
	birds[index]["lost_reason"] = reason
	birds[index]["lost_leg"] = leg
	bird_lost.emit(index, birds[index].name)


## Mark a bird for something it SURVIVED. Cheap on purpose: a count plus a short
## line, capped at SCAR_LOG_MAX lines.
##
## `scars` sat in this dictionary being written by nothing for the whole build,
## which meant the flight's near-misses left no trace at all — a goose that took
## a wire and lived was identical, forever, to one that had a quiet trip. This is
## the writer. can_lead() is the reader that makes it cost something.
func scar_bird(index: int, reason: String) -> void:
	if index < 0 or index >= birds.size():
		return
	var b := birds[index]
	if not bool(b.get("alive", true)):
		return
	b["scars"] = int(b.get("scars", 0)) + 1
	var log_lines: Array = b.get("scar_log", [])
	# Same thing twice in a row is one story, not two — a bird sitting in a
	# headwind band would otherwise collect eleven identical lines.
	if log_lines.is_empty() or str(log_lines[log_lines.size() - 1]) != reason:
		log_lines.append(reason)
	while log_lines.size() > SCAR_LOG_MAX:
		log_lines.remove_at(0)
	b["scar_log"] = log_lines
	bird_scarred.emit(index, reason)


## The most recent thing this bird survived, or "" if it has had an easy run.
func scar_note(index: int) -> String:
	if index < 0 or index >= birds.size():
		return ""
	var lines: Array = birds[index].get("scar_log", [])
	if lines.is_empty():
		return ""
	return str(lines[lines.size() - 1])


## How many birds are carrying at least one scar.
func scarred_count() -> int:
	var n := 0
	for b in birds:
		if bool(b.get("alive", true)) and int(b.get("scars", 0)) > 0:
			n += 1
	return n


## Recovery between legs, on a CURVE rather than a flat heal.
##
## The old version restored 0.6 stamina to everyone unconditionally, which
## meant a bird could never actually run down and the flock could never
## meaningfully deteriorate — so arriving in Florida with five geese and
## arriving with two were the same event wearing different numbers.
##
## Early legs top you up almost fully (the run has to be learnable); late legs
## barely help (the arrival has to cost something). Leg 5 is the deliberate
## exception — see STOPOVER_LEG.
const REST_CURVE := [0.95, 0.95, 0.80, 0.65, 1.00, 0.45, 0.35, 0.25]

## The mid-run rest beat. A full mechanical heal, not just a quieter zone —
## without it a two-bird flock has to carry the last twenty minutes, which
## kills the game's best system exactly when it should be at its sharpest.
const STOPOVER_LEG := 5
const STOPOVER_FLOOR := 3

## Has the Stopover already given geese back this run? Reset only by
## `new_flock()`, which is the one thing that starts a run.
var _topped_up := false


func rest() -> void:
	var i: int = clampi(leg - 1, 0, REST_CURVE.size() - 1)
	var amount: float = REST_CURVE[i]
	for b in birds:
		b.intox = maxf(0.0, b.intox - 0.75)
		b.stamina = minf(1.0, b.stamina + amount)

	# The stopover is the only place in the run that gives geese back — and it
	# does it ONCE.
	#
	# `rest()` runs on arrival at a leg, and landing short does not advance the
	# leg (`main.gd::_on_migration_done()` only increments on `made_it`), so a
	# player who fails the flight 5 crossing arrives at leg 5 again and gets the
	# whole thing a second time. Both halves were repeatable: the full heal —
	# leg 5's REST_CURVE entry is 1.00, the only 1.00 in the table — and the
	# revive.
	#
	# The heal repeating is defensible; you did play the leg again. THE REVIVE IS
	# NOT. docs/CAMPAIGN_SPEC.md §4.5 is unambiguous — "never above three, never
	# anywhere else on the route. This is the only place in the game a goose is
	# ever gained" — and a repeatable revive turns deliberately bailing on one
	# crossing into a free resurrection, on the one leg whose entire design is
	# about restraint having consequences. The attrition numbers in §4 assume
	# this fires at most once.
	if leg == STOPOVER_LEG and not _topped_up:
		_topped_up = true
		_top_up_to(STOPOVER_FLOOR)


## Bring the living flock back up to `floor_count` by reviving the most
## recently lost birds. Only ever called at the stopover.
func _top_up_to(floor_count: int) -> void:
	var living := alive_birds().size()
	if living >= floor_count:
		return
	for i in range(birds.size() - 1, -1, -1):
		if living >= floor_count:
			return
		if not birds[i].alive:
			birds[i].alive = true
			birds[i].intox = 0.0
			birds[i].stamina = 0.8
			birds[i]["lost_reason"] = ""
			birds[i]["joined_at_leg"] = leg
			# The bird that comes back comes back marked. scar_bird() checks
			# alive, so it has to run after the revive above, not before.
			scar_bird(i, "wintered short and caught up at the refuge")
			living += 1


func average_intox() -> float:
	var a := alive_birds()
	if a.is_empty():
		return 0.0
	var s := 0.0
	for b in a:
		s += b.intox
	return s / float(a.size())


## One-line read on how bad the coming flight is going to be.
func condition_summary() -> String:
	var a := alive_birds()
	if a.is_empty():
		return "No flock left."
	var avg := average_intox()
	var leads := lead_candidates().size()
	var desc := "sober"
	if avg > 0.7: desc = "completely hammered"
	elif avg > 0.45: desc = "very rough"
	elif avg > 0.2: desc = "a bit loose"
	var out := "%d geese, %s — %d fit to take a lead shift." % [a.size(), desc, leads]
	# One clause, only when it is true. A scar tightens can_lead(), so the two
	# halves of this sentence are actually related and the player can see that.
	var marked := scarred_count()
	if marked > 0:
		out += "  %d carrying scars." % marked
	return out
