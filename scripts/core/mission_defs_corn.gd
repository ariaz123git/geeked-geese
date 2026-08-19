extends RefCounted
## Objective CONTENT for LEG 6 — THE CUT CORN. Data only, no behaviour.
##
## Same schema, same house rules and the same condition grammar as
## scripts/core/mission_defs.gd. This file exists as a separate unit only so
## that adding a zone is adding a file rather than editing a 600-line one; see
## docs/ZONE_CORN_NOTES.md § Integration for the three-line hook into
## `for_zone()`.
##
## ── THE HOUSE RULES, RESTATED BECAUSE THEY ARE EASY TO BREAK ─────────────
##
## 1. NEVER name a substance in visible text. Not once. Visible objectives
##    describe an OUTCOME; the player supplies the chemistry. HIDDEN objectives
##    may key off a specific substance, because the player never reads them
##    beforehand — that is discovery, not homework.
##
## 2. Every objective must be completable WHILE doing the thing the player
##    already wants to do. If it makes you stop causing chaos and go stand
##    somewhere, delete it.
##
## 3. Write like a person who finds this funny, not like a quest log.
##
## 4. Targets are BASE values for leg 1; Mission scales them (x1.9 by leg 6,
##    which is the cap). `no_scale` for anything inherently one-shot.
##
## ── WHAT THIS ZONE'S LIST IS FOR, SPECIFICALLY ───────────────────────────
##
## CAMPAIGN_SPEC §1.3 says every leg after leg 2 adds a CONTEXT rather than a
## verb, and leg 6's context is **cover and open ground**. This list has exactly
## one job beyond being funny: make the player use the difference between the
## two. Every zone before this one has a safe ground and a dangerous sky. This
## one inverts it, and the objectives are how the player is taught the inversion
## without a single line of tutorial text.
##
##   * `close_quarters` is the reason to go near the machine.
##   * `run_the_open` is the reason to leave the corn, and the only objective in
##     the game that pays you for being *exposed*.
##   * `harvest_festival` is the reason to put things in front of the machine —
##     which is also the safest way to learn what it does to a body.
##   * `oldest_trick` (hidden) is the payoff: hide, let it pass, walk back out.
##     A player who does that once has understood the whole zone.
##
## None of them asks the player to stop causing chaos and go stand somewhere,
## which is the line rule 2 draws. `run_the_open` looks like a traversal
## objective and is actually "sprint across a wide-open field with a combine on
## it", which is the most fun available thing to do here.
##
## ── THE TUNING RISK, NAMED ───────────────────────────────────────────────
##
## `required_primaries(6)` is 4 of 6, and FOUR of these six depend on the
## combine or the field being used in a specific way. If leg 6 tests badly, the
## first knob is `close_quarters`' cap (5 -> 4) and the second is
## `harvest_festival`'s cap (4 -> 3). Do not touch `run_the_open`: it is the
## objective that teaches the zone.

const PRIMARY := 0
const BONUS := 1
const HIDDEN := 2


## ── SCORE LABELS: ONE SPELLING, TWO READERS ──────────────────────────────
##
## Every `label` condition below matches a string some zone passed to
## Game.score(). That is two files agreeing on a literal by hand, and it is
## exactly the bug class that already shipped in this project: suburbia's
## bespoke moments and the objectives waiting on them drifted apart, and the
## only symptom a player sees is an objective that never ticks — which is
## indistinguishable from the whole system being broken.
##
## So leg 6's bespoke labels live HERE, once, and `zone_corn.gd` preloads this
## file and uses these constants at its `Game.score()` call sites. A rename is
## now a parse error in both files instead of a silently dead objective.
##
## ChaosProp labels (BALE, FEED SACK, SCARECROW, ...) are matched by prefix and
## are already visible at their one call site, so they stay as literals.
const LBL_CLOSE_PASS := "CLOSE PASS"
const LBL_INTO_CORN := "INTO THE CORN"
const LBL_BROKE_COVER := "BROKE COVER"
const LBL_OPEN_GROUND := "OPEN GROUND"
const LBL_HARVESTED := "HARVESTED"
const LBL_SILO := "TOP OF THE SILO"


## The zone-specific set. `mission_defs.gd` appends its own universal hidden
## objectives on top of this, so nothing universal is duplicated here.
##
## Kept behind a `for_zone()` of the same shape as mission_defs.gd's so this
## file can also be used standalone by a test harness.
static func for_zone(zone_id: StringName, leg: int) -> Array:
	if zone_id != &"corn":
		return []
	return _filter_by_leg(corn(), leg)


static func _filter_by_leg(defs: Array, leg: int) -> Array:
	var out: Array = []
	for d in defs:
		var e: Dictionary = d
		var from_leg: int = int(e.get("from_leg", 1))
		var until_leg: int = int(e.get("until_leg", 9999))
		if leg >= from_leg and leg <= until_leg:
			out.append(e)
	return out


# ══════════════════════════════════════════════════════════════ THE CUT CORN

static func corn() -> Array:
	return [
		# ── PRIMARY (6; leg 6 requires 4) ───────────────────────────────────
		{
			"id": &"close_quarters",
			"kind": PRIMARY,
			"text": "Get {n} close passes on the combine",
			"hint": "it is not looking where it is going",
			"done_text": "{n} close passes. It never slowed down.",
			"reward": 320,
			# THE ZONE'S SIGNATURE OBJECTIVE. It is the strip mall's shopping
			# cart in reverse: instead of a thing you break, a thing that breaks
			# you, and the score comes from proximity rather than from contact.
			# Capped at 5 because the machine only completes about thirteen
			# passes in a 180 s leg and an objective you can only satisfy by
			# never doing anything else is a chore.
			"cond": {"type": &"label", "labels": [LBL_CLOSE_PASS], "prefix": false,
				"target": 3, "cap": 5},
		},
		{
			"id": &"run_the_open",
			"kind": PRIMARY,
			"text": "Cross the open ground {n} times",
			"hint": "nothing out there is on your side",
			"done_text": "{n} crossings. Nothing caught you.",
			"reward": 340,
			# THE OBJECTIVE THAT TEACHES THE ZONE. It only ticks when the bird
			# is a long way from cover and stays there, so it cannot be
			# satisfied by hugging the corn — and because it re-arms only when
			# you get back near cover, "cross" means cross, not "stand in a
			# field". Four crossings is roughly a minute of a three-minute leg
			# spent deliberately exposed, which is exactly the ask.
			"cond": {"type": &"label", "labels": [LBL_OPEN_GROUND], "prefix": false,
				"target": 2, "cap": 4},
		},
		{
			"id": &"harvest_festival",
			"kind": PRIMARY,
			"text": "Let the combine have {n} of them",
			"hint": "it does not check what it is eating",
			"done_text": "{n} things went through the header. None of them were corn.",
			"reward": 380,
			# The zone's best physics toy: shove a bale, a pallet or a sack into
			# the lane and let five tonnes of machine deal with it. Two props
			# start in the lane on purpose (see zone_corn.gd::_lane_litter) so
			# the first two tick for free and TEACH the verb; the rest have to
			# be pushed. That "demonstrate, then charge for it" shape is the
			# kishotenketsu introduce/develop step, and it is the only thing
			# standing between this objective and a dead end.
			"cond": {"type": &"label", "labels": [LBL_HARVESTED], "prefix": false,
				"target": 2, "cap": 4},
		},
		{
			"id": &"silo_business",
			"kind": PRIMARY,
			"text": "Get on top of the grain bin",
			"hint": "there is only one candidate",
			"no_scale": true,
			"done_text": "Highest point in Sampson County. Briefly.",
			"reward": 240,
			# Suburbia's `get_up_there` and the cottage's `above_the_waterline`,
			# rebuilt for a zone that is otherwise DEAD FLAT. Eleven metres of
			# grain bin is the only vertical thing on the map, and getting up it
			# is also the only way to see the whole field at once — which is the
			# other half of the zone's idea, that altitude buys information and
			# costs cover. One objective, two lessons.
			"cond": {"type": &"label", "labels": [LBL_SILO], "prefix": false, "target": 1},
		},
		{
			"id": &"sweet_science",
			"kind": PRIMARY,
			"text": "Land {n} doses in the sweet spot",
			"hint": "watch the meter, not the vibes",
			"done_text": "{n} clean doses. Look at you.",
			"reward": 300,
			# Deliberately identical in every zone. The dose meter is the only
			# real skill in the game and a skill you practise in one zone isn't
			# one.
			#
			# CAPPED AT 4 HERE, AND ONLY HERE. Leg 6 ships six substances rather
			# than sixteen (CAMPAIGN_SPEC §2.6: "deliberately thin"), and the
			# uncapped leg-6 multiplier would ask for six clean doses off eight
			# pickups. That is not escalation, it is the objective system lying
			# to the player, which §_scale_cond's own comment calls out as the
			# failure mode to avoid.
			"cond": {"type": &"label", "labels": ["SWEET SPOT"], "prefix": false,
				"target": 3, "cap": 4},
		},
		{
			"id": &"loud_lad",
			"kind": PRIMARY,
			"text": "Honk at {n} things that did not ask",
			"done_text": "Everything on this farm has been honked at.",
			"reward": 180,
			# The anti-stall objective. It matters here for a specific reason:
			# this is the only zone where a player can be standing inside the
			# level and unable to SEE any of it, because they are in the corn.
			# Honking is free, always available, needs no line of sight, and
			# banks progress while you work out where the machine went.
			"cond": {"type": &"label", "labels": ["HONK"], "prefix": false, "target": 10},
		},

		# MOVED HERE FROM `mission_defs.gd::_strip_mall` on 2026-08-18, and it is
		# the only chain-length objective in the game. It was authored with
		# `from_leg: 5` in a zone `ROUTE` plays on legs 1 and 2 ONLY, so the
		# chain-length constraint `mission.gd`'s escalation comment promises at
		# leg 5 was unreachable and nothing else supplied it.
		#
		# The cut corn rather than the Stopover, which is the other leg-5+
		# candidate: the Stopover is the run's one recovery beat (`par_scale`
		# 0.55, two required primaries) and a 10x chain primary fights the whole
		# point of it. Leg 6 is an open field with a combine and the highest prop
		# density in the back half. Design call, D-034.
		{
			"id": &"sustained_campaign",
			"kind": PRIMARY,
			"text": "Get a {n}x chain going and hold it",
			"done_text": "{n}x. The field is a write-off.",
			"reward": 450,
			"cond": {"type": &"stat", "stat": &"peak_combo", "op": &"gte", "value": 10.0},
		},
		# ── BONUS ───────────────────────────────────────────────────────────
		{
			"id": &"bale_out",
			"kind": BONUS,
			"text": "Put {n} round bales somewhere they weren't",
			"hint": "they are round for a reason",
			"done_text": "The bales have been redistributed.",
			"reward": 280,
			# A round bale is the heaviest thing a goose can actually move here,
			# and it ROLLS — the model is authored lying on its side with its
			# axis across the rows, so one good shove sends it the length of the
			# field. A bonus should be "enjoy the toy", and a half-tonne
			# cylinder on a flat plane is a toy.
			"cond": {"type": &"label", "labels": ["BALE"], "target": 2, "cap": 5},
		},
		{
			"id": &"share_the_wealth",
			"kind": BONUS,
			"from_leg": 2,
			"text": "Share what you're on with the flock, {n}x",
			"hint": "they will remember this in the air",
			"done_text": "The flock is now your problem.",
			"reward": 300,
			# The only objective in the game with a real cost, and it belongs in
			# every zone. It is worth MORE here than anywhere: the flight out of
			# leg 6 is where PUT DOWN HERE is introduced, and `rest()` arriving
			# at leg 7 restores almost nothing. The hint says so out loud, which
			# is what makes skipping it a decision instead of an oversight.
			"cond": {"type": &"label", "labels": ["SHARED WITH THE FLOCK"],
				"prefix": false, "target": 2},
		},
		{
			"id": &"variety_pack",
			"kind": BONUS,
			"from_leg": 4,
			"text": "Wreck {n} different kinds of thing",
			"done_text": "Nothing on this farm is safe from you.",
			"reward": 350,
			# Late-leg breadth. In this zone it does a second job: the props are
			# deliberately spread between the yard (bins, chairs, mailbox), the
			# lane (sacks, pallets, bales) and the field edge (fence, scarecrow),
			# so "different kinds" means "walked the whole map", which in a zone
			# where half the map is a wall you cannot see through is a real ask.
			"cond": {"type": &"unique", "set": &"labels", "target": 5, "cap": 9},
		},
		{
			"id": &"low_flying_aircraft",
			"kind": BONUS,
			"from_leg": 5,
			"text": "Land {n} hits without ever landing",
			"hint": "crop dusting",
			"done_text": "{n} hits, feet never down.",
			"reward": 450,
			# The leg-5+ mastery constraint named in DESIGN_MISSIONS.md §206.
			# It forces sustained flight AND aggression at once, which is only
			# comfortable with a stimulant up — a chemistry problem stated
			# without naming chemistry.
			#
			# It is also, in THIS zone specifically, a trade: everything worth
			# hitting is on the ground, the standing corn hides the ground, and
			# the moment you are airborne you can see everything and are visible
			# to everything. That is the leg's whole thesis expressed as a
			# scoring rule.
			"cond": {"type": &"label", "labels": [], "target": 3,
				"when": {"airborne": true}},
		},

		# ── HIDDEN (zone-flavoured) ─────────────────────────────────────────
		#
		# Rule for writing one: it must be something a player could plausibly do
		# BY ACCIDENT while messing around, and the reveal has to feel like the
		# game was watching. If you'd need a wiki, it isn't hidden, it's a
		# secret, and secrets belong in the Almanac.
		{
			"id": &"oldest_trick",
			"kind": HIDDEN,
			"title": "THE OLDEST TRICK",
			"line": "Hid in the corn until it went past. Nothing in your ancestry prepared you for that machine and you did it anyway.",
			"text": "Waited it out",
			"reward": 500,
			# THE ZONE'S BEST OBJECTIVE AND THE REASON THE COVER MECHANIC PAYS.
			# Three beats inside fourteen seconds: get into the standing corn,
			# have the combine pass within five metres of you while you are in
			# there, and come back out. A player who does that has invented
			# hiding, unprompted, in a game that has never once had a stealth
			# mechanic — and the game noticing is the entire reward.
			#
			# It is reachable by accident, which is the test: the corn is the
			# obvious place to run when a combine is coming at you, and the
			# obvious thing to do afterwards is come back out and look at it.
			"cond": {"type": &"sequence", "window": 14.0, "steps": [
				{"labels": [LBL_INTO_CORN], "prefix": false, "count": 1},
				{"labels": [LBL_CLOSE_PASS], "prefix": false, "count": 1},
				{"labels": [LBL_BROKE_COVER], "prefix": false, "count": 1},
			]},
		},
		{
			"id": &"redundant",
			"kind": HIDDEN,
			"title": "REDUNDANT",
			"line": "That was its entire job.",
			"text": "Dealt with the scarecrow",
			"reward": 400,
			# One joke, one line, and it lands the moment the player does the
			# most obvious thing in the level. Paying 400 rather than 500 is the
			# difference between a gag you walk into and a trick you invent —
			# `oldest_trick` gets the extra hundred because it was found.
			"cond": {"type": &"label", "labels": ["SCARECROW"], "target": 1},
		},
	]
