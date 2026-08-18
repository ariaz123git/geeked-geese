extends RefCounted
## Objective CONTENT for LEG 3 — COTTAGE COUNTRY. Data only, no behaviour.
##
## Same schema, same house rules and the same condition grammar as
## scripts/core/mission_defs.gd. This file exists as a separate unit only so
## that adding a zone is adding a file rather than editing a 500-line one; see
## ZONE3_NOTES.md §Integration for the three-line hook into `for_zone()`.
##
## ── THE HOUSE RULES, RESTATED BECAUSE THEY ARE EASY TO BREAK ─────────────
##
## 1. NEVER name a substance in visible text. Not once. The moment an objective
##    says "use the toad" it stops being a goal and becomes an instruction, and
##    the player stops experimenting. Visible objectives describe an OUTCOME;
##    the player supplies the chemistry. HIDDEN objectives may key off a
##    specific substance, because the player never reads them beforehand —
##    that's discovery, not homework.
##
## 2. Every objective must be completable WHILE doing the thing the player
##    already wants to do. If it makes you stop causing chaos and go stand
##    somewhere, delete it. There are no fetch quests in a three-minute leg.
##
## 3. Write like a person who finds this funny, not like a quest log.
##
## 4. Targets are BASE values for leg 1; Mission scales them. `no_scale` for
##    anything inherently one-shot.
##
## ── WHAT THIS ZONE'S LIST IS FOR, SPECIFICALLY ───────────────────────────
##
## The other two zones are flat. Everything the player learned there is
## "travel horizontally at things". This zone is a six-metre granite step with
## a lake at the bottom, and its objective list has exactly one job beyond
## being funny: get the player OFF THE SHELF. Two of the six primaries
## (`long_way_down`, `above_the_waterline`) cannot be completed with your feet
## on the plateau, and the hidden set pays out for swimming, for diving and
## for getting on top of a building in the middle of a lake.
##
## It does that WITHOUT ever asking the player to go somewhere and not cause
## chaos, which is the line rule 2 draws. "Land four hits without landing" is
## satisfied by doing the most fun available thing — jumping off the cliff into
## the middle of everything — and only reads as a traversal objective in
## hindsight.

const PRIMARY := 0
const BONUS := 1
const HIDDEN := 2


## The zone-specific set. `mission_defs.gd` appends its own universal hidden
## objectives on top of this, so nothing universal is duplicated here.
##
## Kept behind a `for_zone()` of the same shape as mission_defs.gd's so this
## file can also be used standalone by a test harness.
static func for_zone(zone_id: StringName, leg: int) -> Array:
	if zone_id != &"cottage":
		return []
	return _filter_by_leg(cottage(), leg)


static func _filter_by_leg(defs: Array, leg: int) -> Array:
	var out: Array = []
	for d in defs:
		var e: Dictionary = d
		var from_leg: int = int(e.get("from_leg", 1))
		var until_leg: int = int(e.get("until_leg", 9999))
		if leg >= from_leg and leg <= until_leg:
			out.append(e)
	return out


# ══════════════════════════════════════════════════════════ COTTAGE COUNTRY

static func cottage() -> Array:
	return [
		# ── PRIMARY ─────────────────────────────────────────────────────────
		{
			"id": &"chair_launch",
			"kind": PRIMARY,
			"text": "Introduce {n} Muskoka chairs to gravity",
			"done_text": "{n} chairs. Gravity won.",
			"reward": 250,
			# The zone's signature prop and the exact analogue of the strip
			# mall's shopping cart: light, high-value, cartwheels forever, and
			# there are six of them arranged in a ring around a fire at the top
			# of a cliff. Prefix match so the doubled break score counts too.
			"cond": {"type": &"label", "labels": ["MUSKOKA CHAIR"], "target": 5, "cap": 9},
		},
		{
			"id": &"sweet_science",
			"kind": PRIMARY,
			"text": "Land {n} doses in the sweet spot",
			"hint": "watch the meter, not the vibes",
			"done_text": "{n} clean doses. Look at you.",
			"reward": 300,
			# Deliberately identical in all three zones. The dose meter is the
			# only real skill in the game and a skill you practise in one zone
			# isn't one. It is also the objective that carries a player who has
			# no idea what to do in the dark yet.
			"cond": {"type": &"label", "labels": ["SWEET SPOT"], "prefix": false, "target": 3},
		},
		{
			"id": &"loud_lad",
			"kind": PRIMARY,
			"text": "Honk at {n} things that did not ask",
			"done_text": "Everyone at this lake has been honked at.",
			"reward": 180,
			# The anti-stall objective, and it matters MORE here than anywhere
			# else: this is the zone where a new player can genuinely fail to
			# find anything for twenty seconds because it is dark. Honking is
			# free, always available, needs no setup, and banks progress while
			# you work out where you are.
			"cond": {"type": &"label", "labels": ["HONK"], "prefix": false, "target": 10},
		},
		{
			"id": &"long_way_down",
			"kind": PRIMARY,
			"text": "Land {n} hits without landing",
			"hint": "the ground is further away than usual",
			"done_text": "{n} hits, feet never down.",
			"reward": 340,
			# THE VERTICALITY PRIMARY. It never says "fly" and it never says
			# "jump off the cliff"; it says the thing you want anyway, which
			# is to hit stuff, and quietly rules out the way you did it in the
			# other two zones. The honest solution is to walk off the deck and
			# take the fire pit apart on the way past, which is also the single
			# most fun thing this zone can be made to do.
			"cond": {"type": &"label", "labels": [], "target": 4, "when": {"airborne": true}},
		},
		{
			"id": &"above_the_waterline",
			"kind": PRIMARY,
			"text": "Stand on something out in the lake",
			"hint": "there is only one candidate",
			"no_scale": true,
			"done_text": "The boathouse is yours now.",
			"reward": 220,
			# Suburbia's `get_up_there`, rebuilt for a zone whose roofs are at
			# the BOTTOM. The boathouse roof is three flaps up from open water
			# and one committed dive down from the cliff, so this objective is
			# the thing that makes a player discover both routes — and having
			# discovered them, they own the whole vertical axis for the rest of
			# the leg. One objective seeding the zone's entire traversal.
			"cond": {"type": &"label", "labels": ["ON THE ROOF"], "prefix": false, "target": 1},
		},
		{
			"id": &"ten_second_cottage",
			"kind": PRIMARY,
			"from_leg": 3,
			"text": "Wreck {n} things inside ten seconds",
			"hint": "any {n}. the fire is surrounded by furniture.",
			"done_text": "Ten seconds. The whole fire pit.",
			"reward": 400,
			# The leg-3 escalation is a CONSTRAINT, not a bigger number — same
			# verb, now with a clock. In this zone it also does a second job:
			# the only place dense enough to satisfy a ten-second window is the
			# ring of chairs around the fire, so it routes the player straight
			# into the best-lit, most legible set-piece on the map at exactly
			# the leg where they've stopped needing help finding it.
			"cond": {"type": &"window", "labels": [], "target": 6, "window": 10.0},
		},

		# ── BONUS ───────────────────────────────────────────────────────────
		{
			"id": &"firewood_ballistics",
			"kind": BONUS,
			"text": "Redistribute {n} pieces of firewood",
			"hint": "somebody split those by hand",
			"done_text": "That wood is everywhere now.",
			"reward": 220,
			# The cheapest, most abundant prop in the zone, scattered in two
			# piles either side of the fire. A bonus should be "enjoy the toy",
			# and eleven loose logs on a granite shelf is a toy.
			"cond": {"type": &"label", "labels": ["FIREWOOD"], "target": 5, "cap": 11},
		},
		{
			"id": &"fleet_action",
			"kind": BONUS,
			"text": "Put {n} boats back in the water. Hard.",
			"done_text": "The fleet has been dealt with.",
			"reward": 300,
			# Canoes are the heaviest thing a goose can actually move here, so
			# shifting one is a physics achievement rather than a tap. And the
			# three on the terrace are at the bottom of the cliff, which means
			# the fastest way to satisfy this is to arrive at speed.
			"cond": {"type": &"label", "labels": ["CANOE", "KAYAK"], "target": 2, "cap": 5},
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
			# every zone rather than just the first: big points now, a wobbling
			# formation in the migration later. The hint says so out loud, which
			# is what makes skipping it a decision instead of an oversight.
			"cond": {"type": &"label", "labels": ["SHARED WITH THE FLOCK"], "prefix": false, "target": 2},
		},
		{
			"id": &"variety_pack",
			"kind": BONUS,
			"from_leg": 4,
			"text": "Wreck {n} different kinds of thing",
			"done_text": "Nothing at this lake is safe from you.",
			"reward": 350,
			# Late-leg breadth. Pushes the player off the fire pit and out to
			# the dock, the driveway and the boathouse — which in a dark zone
			# also means pushing them into the parts of the map they have not
			# yet had a reason to light up.
			"cond": {"type": &"unique", "set": &"labels", "target": 6},
		},
		{
			"id": &"night_flight",
			"kind": BONUS,
			"from_leg": 5,
			"text": "Land {n} hits airborne, on two things",
			"hint": "two at once. three is a nap.",
			"done_text": "Airborne, chemically, at night. Sure.",
			"reward": 450,
			# The mastery constraint, and it is a compound one: sustained flight
			# AND aggression AND a live pair of substances. Comfortable only
			# with a stimulant up, which creates a chemistry problem without
			# ever naming chemistry.
			"cond": {"type": &"label", "labels": [], "target": 4,
				"when": {"airborne": true, "subs_min": 2}},
		},

		# ── HIDDEN (zone-flavoured) ─────────────────────────────────────────
		#
		# Rule for writing one: it must be something a player could plausibly do
		# BY ACCIDENT while messing around, and the reveal has to feel like the
		# game was watching. If you'd need a wiki, it isn't hidden, it's a
		# secret, and secrets belong in the Almanac.
		{
			"id": &"do_not_lick_the_toad",
			"kind": HIDDEN,
			"title": "DO NOT LICK THE TOAD",
			"line": "There was no sign. There is now.",
			"text": "Licked the toad",
			"reward": 500,
			# THIS IS THE TOAD'S HOME. The strip mall has a version of this
			# gag, but there it is a lump in the cattails you trip over; here
			# the toad is under the dock, in the dark, at the outer edge of the
			# dock light, with two glowing eyes and a croak on a timer, and
			# getting to it means going down the cliff and under the boards.
			# Paying 500 rather than 350 is the difference: this one was found,
			# not stumbled into.
			"cond": {"type": &"event", "event": &"sub_taken", "id": &"toad_slime", "target": 1},
		},
		{
			"id": &"chair_avalanche",
			"kind": HIDDEN,
			"title": "MUSKOKA CHAIR AVALANCHE",
			"line": "Four chairs, five seconds. Somebody's grandfather made those.",
			"text": "Cleared the fire pit",
			"reward": 420,
			# The cart train, ported. Rewards finding the ring of six around the
			# fire and committing to one run through it instead of grazing — and
			# it is the most visible thing that can happen in this zone, because
			# it happens inside the biggest light.
			"cond": {"type": &"window", "labels": ["MUSKOKA CHAIR"], "target": 4, "window": 5.0},
		},
		{
			"id": &"night_swim",
			"kind": HIDDEN,
			"title": "NIGHT SWIM",
			"line": "The lake is warmer than the air. That is a lie the lake tells every year.",
			"text": "Went for a swim",
			"reward": 300,
			# CONTINUOUS, so paddling in and straight back out doesn't count.
			# Ten unbroken seconds on the water is long enough to notice the
			# loons and the moon path and the fact that the cottage is a very
			# small light a long way up — which is the whole reason the lake is
			# in this zone. A hidden objective that pays for looking around.
			"cond": {"type": &"sustain", "when": {"in_water": true}, "seconds": 10.0},
		},
		{
			"id": &"answered_the_loon",
			"kind": HIDDEN,
			"title": "THAT IS NOT WHAT IT SAID",
			"line": "It was not talking to you. You answered anyway.",
			"text": "Answered the loon",
			"reward": 350,
			# Six honks in five seconds WHILE IN THE WATER. Every part of that
			# is discoverable by accident: the player is already going to mash
			# honk (the universal `outburst` objective guarantees it), and the
			# first time they do it floating in the middle of a dark lake with
			# a loon calling back, the game should notice. The best kind of
			# hidden objective is one the player thinks they invented.
			"cond": {"type": &"window", "labels": ["HONK"], "prefix": false, "target": 6,
				"window": 5.0, "when": {"in_water": true}},
		},
		{
			"id": &"view_from_up_here",
			"kind": HIDDEN,
			"title": "THE VIEW FROM UP HERE",
			"line": "On a roof, over a lake, in the dark, on two things. This is a lifestyle.",
			"text": "Boathouse, wrecked",
			"reward": 400,
			# Layers on top of a primary the player has already been taught to
			# want, so the reveal lands as "oh, there was MORE to that" rather
			# than as a separate errand. Same trick as suburbia's `pool_party`.
			"cond": {"type": &"label", "labels": ["ON THE ROOF"], "prefix": false, "target": 1,
				"when": {"subs_min": 2}},
		},
	]
