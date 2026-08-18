extends RefCounted
## Objective CONTENT for LEG 7 — THE TRUCK STOP. Data only, no behaviour.
##
## Same schema, same house rules and the same condition grammar as
## scripts/core/mission_defs.gd. This file exists as a separate unit only so
## that adding a zone is adding a file rather than editing a 500-line one; see
## ZONE_TRUCKSTOP_NOTES.md §Integration for the three-line hook into
## `for_zone()`.
##
## ── THE HOUSE RULES, RESTATED BECAUSE THEY ARE EASY TO BREAK ─────────────
##
## 1. NEVER name a substance in visible text. Not once. The moment an objective
##    says "drink the coffee" it stops being a goal and becomes an instruction,
##    and the player stops experimenting. Visible objectives describe an
##    OUTCOME; the player supplies the chemistry. HIDDEN objectives may key off
##    a specific substance, because the player never reads them beforehand —
##    that's discovery, not homework.
##
## 2. Every objective must be completable WHILE doing the thing the player
##    already wants to do. If it makes you stop causing chaos and go stand
##    somewhere, delete it.
##
## 3. Write like a person who finds this funny, not like a quest log.
##
## 4. Targets are BASE values for leg 1; Mission scales them. `no_scale` for
##    anything inherently one-shot. At leg 7 `target_scale` is pinned at its
##    1.9 ceiling, so **every base number here is very nearly doubled** by the
##    time a player sees it. A base of 6 reads as 12 on the HUD. Nothing in this
##    file was written without checking what it becomes.
##
## ── WHAT THIS ZONE'S LIST IS FOR, SPECIFICALLY ───────────────────────────
##
## `required_primaries(7)` is `2 + floor(6/2)` = **5**, clamped to `n - 1` = 5
## of 6. That is the hardest requirement in the campaign and it lands on the
## zone with the fewest and weakest substances in the campaign. CAMPAIGN_SPEC
## §2.7 names that as "the single most likely place for the mission system to
## feel unfair", and gives the fix:
##
##   > Leg 7's six primaries must be writable without chemistry — honking,
##   > wrecking, riding a truck, the dumpster corral, the diner window. Write
##   > them that way or drop the override to 4.
##
## **All six primaries below are completable stone-cold sober**, and five of
## them are the five things the spec names. The sixth (`up_top`) is the other
## half of the moving-platform mechanic and is also free.
##
## The one casualty of that rule is `sweet_science`, the dose-meter objective
## that is deliberately identical in all three built zones. It is still here —
## it is demoted to a BONUS. Losing the skill objective entirely would be worse
## than losing its primary slot, and a player who wants to practise the meter on
## four half-strength sources can still be paid for it without anyone being
## *required* to find chemistry in the zone that does not have any.
##
## The other thing this list does that no other zone's does: **three of its
## objectives are on a clock the zone owns rather than the HUD.** The rigs leave
## on a schedule, so `hitch` and `up_top` quietly expire, one bay at a time,
## whether or not the player has noticed. Nothing says so. The lot just gets
## emptier.

const PRIMARY := 0
const BONUS := 1
const HIDDEN := 2


## The zone-specific set. `mission_defs.gd` appends its own universal hidden
## objectives on top of this, so nothing universal is duplicated here.
##
## Kept behind a `for_zone()` of the same shape as mission_defs.gd's so this
## file can also be used standalone by a test harness.
static func for_zone(zone_id: StringName, leg: int) -> Array:
	if zone_id != &"truckstop":
		return []
	return _filter_by_leg(truckstop(), leg)


static func _filter_by_leg(defs: Array, leg: int) -> Array:
	var out: Array = []
	for d in defs:
		var e: Dictionary = d
		var from_leg: int = int(e.get("from_leg", 1))
		var until_leg: int = int(e.get("until_leg", 9999))
		if leg >= from_leg and leg <= until_leg:
			out.append(e)
	return out


# ═══════════════════════════════════════════════════════════════ TRUCK STOP

static func truckstop() -> Array:
	return [
		# ── PRIMARY — all six free of chemistry, per §2.7 ────────────────────
		{
			"id": &"loud_lad",
			"kind": PRIMARY,
			"text": "Honk at {n} things that did not ask",
			"done_text": "Everyone at this exit has been honked at.",
			"reward": 180,
			# The anti-stall objective, and the one that survives every possible
			# state the player can arrive in. A bird that comes off leg 6 with
			# nothing left can bank this lying down. Base 8 rather than the other
			# zones' 10 because leg 7 doubles it: 8 becomes 16, and 16 honks is
			# already one every eleven seconds of a 180 s clock.
			"cond": {"type": &"label", "labels": ["HONK"], "prefix": false, "target": 8},
		},
		{
			"id": &"dead_hours",
			"kind": PRIMARY,
			"text": "Wreck {n} things. Nobody will hear it.",
			"done_text": "{n} things. Nobody heard it.",
			"reward": 260,
			# The generic wrecking primary, and in this zone it is also the
			# EXPLORATION primary: props are in four tight clusters with sixty
			# metres of nothing between them, so twelve hits means visiting at
			# least two of the four. It never says "explore".
			"cond": {"type": &"label", "labels": [], "target": 6, "cap": 26},
		},
		{
			"id": &"hitch",
			"kind": PRIMARY,
			"no_scale": true,
			"text": "Leave with one of them",
			"hint": "they are not waiting for you",
			"done_text": "You left with one of them.",
			"reward": 420,
			# THE ZONE'S IDENTITY OBJECTIVE. Get on a trailer roof and still be
			# there when it pulls out. `no_scale` because you cannot ride 1.9
			# trucks, and because this is the one thing in the leg with a real
			# deadline: six rigs go at 0:22, 0:48, 1:16, 1:46, 2:18 and 2:46, and
			# once the last one has gone this objective is simply over.
			#
			# The hint is doing real work. It is the only warning in the zone
			# that anything is on a timer, and it is deliberately not a clock.
			"cond": {"type": &"label", "labels": ["RODE A RIG"], "prefix": false, "target": 1},
		},
		{
			"id": &"corral",
			"kind": PRIMARY,
			"text": "Redistribute {n} things from the corral",
			"hint": "behind the diner. it is not locked.",
			"done_text": "The corral has been dealt with.",
			"reward": 300,
			# The spec names the dumpster corral as a primary source, so it is a
			# real place: three skips, six sacks, six pallets and two bins behind
			# a three-sided block wall with one caged light on it. Base 4 becomes
			# 8, and there are seventeen scoreable objects in there.
			"cond": {"type": &"label", "labels": ["DUMPSTER", "GARBAGE", "PALLET", "RECYCLING"],
				"target": 4, "cap": 15},
		},
		{
			"id": &"window_seat",
			"kind": PRIMARY,
			"text": "Put {n} of the diner's windows somewhere else",
			"hint": "arrive quickly",
			"done_text": "The diner is open to the elements.",
			"reward": 340,
			# Five panes, each of which needs the goose moving at 4 m/s or more,
			# so it is a *run-up* objective rather than a nudging one — and the
			# run-up is across the one stretch of the lot with an awning over it.
			# Base 2 becomes 4 of the 5. Capped so the number can never exceed
			# the glazing that exists; an objective asking for six panes of a
			# five-pane window is the game lying to the player.
			"cond": {"type": &"label", "labels": ["DINER WINDOW"], "prefix": false,
				"target": 2, "cap": 5},
		},
		{
			"id": &"up_top",
			"kind": PRIMARY,
			"text": "Stand on {n} different rigs",
			"hint": "a parked truck is a very tall rock",
			"done_text": "{n} roofs. All of them left without you.",
			"reward": 320,
			# The other half of the moving-platform mechanic, and the traversal
			# primary — a trailer roof is 4.05 m, which is three flaps from the
			# asphalt or one from the fuel-island kerb, and from up there the
			# travel centre roof is a single flap further. One objective seeds
			# the whole vertical axis, exactly like the cottage's boathouse.
			#
			# It also has the leg's tightening clock built into it for free: base
			# 2 becomes 4, there are six rigs, and they leave one at a time.
			"cond": {"type": &"label", "labels": ["ON THE RIG"], "prefix": false,
				"target": 2, "cap": 6},
		},

		# ── BONUS ────────────────────────────────────────────────────────────
		{
			"id": &"sweet_science",
			"kind": BONUS,
			"text": "Land {n} doses in the sweet spot",
			"hint": "watch the meter, not the vibes",
			"done_text": "{n} clean doses out of almost nothing.",
			"reward": 300,
			# A BONUS here, not a primary — see the header. Base 2 rather than
			# the other zones' 3: at leg 7 that is 4, off four half-strength
			# sources on a 9 s respawn, which is a real ask in a lot this size
			# and an absurd one at base 3 (which would read as 6).
			"cond": {"type": &"label", "labels": ["SWEET SPOT"], "prefix": false, "target": 2},
		},
		{
			"id": &"share_the_wealth",
			"kind": BONUS,
			"text": "Share what you're on with the flock, {n}x",
			"hint": "the next one is the long one",
			"done_text": "The flock is now your problem. Again.",
			"reward": 320,
			# The only objective in the game with a real cost, and this is the
			# leg where it costs the most: the next flight is 130 s, the longest
			# in the run, with no thermals for the first 60% of it, and `rest()`
			# at leg 7 restores 0.25 stamina. One blanket share here is the
			# difference between arriving with four geese and arriving with two.
			#
			# The hint says so out loud without saying anything, which is what
			# makes taking it a decision rather than an oversight.
			"cond": {"type": &"label", "labels": ["SHARED WITH THE FLOCK"], "prefix": false,
				"target": 2},
		},
		{
			"id": &"gator_country",
			"kind": BONUS,
			"text": "Rehome {n} pieces of somebody's tyre",
			"hint": "they came off at speed. so can you.",
			"done_text": "The shoulder is clear. You're welcome.",
			"reward": 220,
			# The cheap toy, and the bonus a bonus should be. Seven shed retreads
			# lying around the truck row and the exit lane; base 3 becomes 6, and
			# there are seven. Finding them is the point — they are the only
			# props in the zone that are not in a cluster.
			"cond": {"type": &"label", "labels": ["GATOR"], "target": 3, "cap": 7},
		},
		{
			"id": &"long_way_round",
			"kind": BONUS,
			"text": "Land {n} hits without landing",
			"hint": "the roofs are the fast way across",
			"done_text": "{n} hits, feet never down.",
			"reward": 340,
			# The verticality bonus, ported from the cottage, and free of
			# chemistry — which matters because it is the objective most likely
			# to be attempted by a player who has already given up on the
			# substances. In this zone the honest solution is to take off from a
			# trailer roof and glide the length of the row.
			"cond": {"type": &"label", "labels": [], "target": 3, "when": {"airborne": true}},
		},
		{
			"id": &"variety_pack",
			"kind": BONUS,
			"from_leg": 4,
			"text": "Wreck {n} different kinds of thing",
			"done_text": "Nothing at this exit is safe from you.",
			"reward": 350,
			# Late-leg breadth, and in a zone built out of four separate clusters
			# it is the objective that walks the player around the whole lot.
			# `unique` scales at half rate, so base 4 reads as 6 — of the twelve
			# kinds the zone actually contains.
			"cond": {"type": &"unique", "set": &"labels", "target": 4},
		},

		# ── HIDDEN (zone-flavoured) ──────────────────────────────────────────
		#
		# Rule for writing one: it must be something a player could plausibly do
		# BY ACCIDENT while messing around, and the reveal has to feel like the
		# game was watching. If you'd need a wiki, it isn't hidden, it's a
		# secret, and secrets belong in the Almanac.
		{
			"id": &"where_are_you_going",
			"kind": HIDDEN,
			"title": "WHERE ARE YOU GOING",
			"line": "Six seconds on the roof of a stranger's trailer, doing sixty, in the rain. Nobody made you.",
			"text": "Went with it",
			"reward": 500,
			# Layers on top of a primary the player has already been taught to
			# want, so the reveal lands as "oh, there was MORE to that" rather
			# than as a separate errand. Riding for 1.2 s completes `hitch`;
			# staying on for six and a half takes you past the property line, and the map
			# wall scrapes you off at the far end of a dark access road with the
			# lot's lights small behind you. That is the whole leg in one shot.
			"cond": {"type": &"label", "labels": ["WENT WITH IT"], "prefix": false, "target": 1},
		},
		{
			"id": &"closing_time",
			"kind": HIDDEN,
			"title": "CLOSING TIME",
			"line": "Everyone else had somewhere to be.",
			"text": "Watched the last one go",
			"reward": 350,
			# Fires when the sixth rig pulls out at 2:46, if you are still there.
			# It requires nothing, it cannot be missed by a player who stays, and
			# it cannot be earned by a player who has already been carried out of
			# the lot. It is the zone saying the quiet part exactly once, in
			# nine words, and then never again.
			"cond": {"type": &"label", "labels": ["LAST CALL"], "prefix": false, "target": 1},
		},
		{
			"id": &"breakfast",
			"kind": HIDDEN,
			"title": "BREAKFAST",
			"line": "Coffee and a cigarette at three in the morning. You are not a goose, you are a driver.",
			"text": "Had breakfast",
			"reward": 400,
			# Hidden objectives MAY name a substance, because the player never
			# reads them beforehand. These are the two most obvious things at a
			# truck stop and they are also the two weakest things in the game —
			# which is the joke, and which is why this is the zone's cheapest
			# secret and the one most likely to fire by accident.
			"cond": {"type": &"all", "of": [
				{"type": &"event", "event": &"sub_taken", "id": &"double_double", "target": 1},
				{"type": &"event", "event": &"sub_taken", "id": &"darts", "target": 1},
			]},
		},
		{
			"id": &"it_counts_as_water",
			"kind": HIDDEN,
			"title": "IT COUNTS AS WATER",
			"line": "Sixteen metres of parking lot with nowhere to drain. To a goose that is a lake.",
			"text": "Swam in a parking lot",
			"reward": 300,
			# CONTINUOUS, so paddling through and straight out doesn't count.
			# Eight unbroken seconds is long enough to notice that the lamp on
			# the east shore is reflected in it, that the storm drain in the
			# middle is doing nothing, and that you are a wild animal swimming in
			# a puddle off I-95. A hidden objective that pays for looking around.
			"cond": {"type": &"sustain", "when": {"in_water": true}, "seconds": 8.0},
		},
		{
			"id": &"through_the_front",
			"kind": HIDDEN,
			"title": "THROUGH THE FRONT WINDOW",
			"line": "They will be talking about this at shift change.",
			"text": "Came in the hard way",
			"reward": 420,
			# The window primary, but airborne. Same trick as the cottage's
			# `view_from_up_here`: it sits on something the player is already
			# doing and rewards the more committed version of it. The honest
			# route is off the awning, which is 3.5 m up and directly above the
			# glass, so the discovery is "wait, I can get on that" rather than
			# anything the objective had to say.
			"cond": {"type": &"label", "labels": ["DINER WINDOW"], "prefix": false,
				"target": 1, "when": {"airborne": true}},
		},
	]
