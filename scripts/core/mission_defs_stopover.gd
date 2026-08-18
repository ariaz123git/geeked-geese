extends RefCounted
## Objective CONTENT for LEG 5 — THE STOPOVER. Data only, no behaviour.
##
## Same schema, same house rules and the same condition grammar as
## scripts/core/mission_defs.gd. This file exists as a separate unit only so
## that adding a zone is adding a file rather than editing a 600-line one; the
## hook into `for_zone()` is three lines and is listed in the build handoff.
##
## ── THE HOUSE RULES, RESTATED BECAUSE THEY ARE EASY TO BREAK ─────────────
##
## 1. NEVER name a substance in visible text. Not once. Visible objectives
##    describe an OUTCOME; the player supplies the chemistry. HIDDEN objectives
##    may key off a specific substance, because the player never reads them
##    beforehand — that is discovery, not homework.
##
## 2. Every objective must be completable WHILE doing the thing the player
##    already wants to do. (This zone bends that rule once, on purpose, and the
##    bend is argued below.)
##
## 3. Write like a person who finds this funny, not like a quest log.
##
## 4. Targets are BASE values for leg 1; Mission scales them (x1.72 at leg 5).
##    `no_scale` for anything inherently one-shot.
##
## ===========================================================================
## WHAT THIS ZONE'S LIST IS FOR, SPECIFICALLY — AND WHY IT IS THE ODD ONE
## ===========================================================================
##
## CAMPAIGN_SPEC §2.5 says leg 5 adds "a reason not to use the verbs". It is the
## deep trough of a two-peak curve, intensity 2, a 150-second clock, and the
## only full mechanical heal in the back half of the run. §2.5 is explicit about
## what that means for THIS list:
##
##   > The zone contains every substance in the game and never mentions this.
##   > Its objectives are mostly bonuses. Its primaries are gentle. There are
##   > forty other geese standing around not doing anything. And the flock pen
##   > is the biggest thing in the level.
##
## and:
##
##   > Two of the four primaries are about the flock rather than about chaos —
##   > the only place in the game where that's true.
##
## So this list breaks rule 2 exactly once, deliberately, and it is the whole
## point of the leg: `mind_the_flock` and `name_a_driver` both ask the player to
## stop and look at their own birds. In any other zone that would be a chore
## objective and would be deleted. Here it is the content.
##
## ── THE ONE CONSTRAINT EVERY PRIMARY IN THIS FILE OBEYS ──────────────────
##
## **ALL FOUR PRIMARIES ARE COMPLETABLE STONE-COLD SOBER.**
##
## That is not a nicety, it is a correctness requirement, and it is the reason
## `sweet_science` is a BONUS here and a primary everywhere else. The zone's
## best hidden objective — `slept_on_it` — fires only when `subs_taken == 0` at
## the buzzer. If any required primary needed a dose, the game would be handing
## out a pass mark and a secret that are mutually exclusive, i.e. punishing the
## exact behaviour the leg exists to teach. mission_defs_truckstop.gd states the
## same rule for leg 7 for a different reason (scarcity); here the reason is the
## thesis.
##
## The corollary is that a player who does absolutely nothing chemical can still
## clear the leg, take the heal, AND find the secret. That is the design.
##
## ── WHAT THIS LIST MUST NEVER SAY ────────────────────────────────────────
##
## CAMPAIGN_SPEC.md:504, blockquoted in the spec and repeated here because it is
## the single easiest thing to ruin:
##
##   > This is the harm-reduction thesis as level design, and it never says a
##   > word. The trough is only a trough if you take it.
##
## No objective text, hint, done_text, title or line in this file may mention
## resting, recovering, staying clean *as a virtue*, moderation, or what the
## substances are doing to the flock. `slept_on_it` is allowed to be arch about
## it AFTER the buzzer, when the choice is already spent — that is the joke
## landing, not a lecture arriving. Anything that fires DURING the leg and nudges
## the player toward restraint deletes the entire point of the level.
##
## ── THE TWO DELIBERATE DEVIATIONS FROM docs/ROUTE_DATA.md §7.2 ───────────
##
## 1. `sweet_science` is a BONUS, not a primary. Reason above.
## 2. `mind_the_flock` is a LABEL condition fed by the zone, not
##    `stat flock_stamina_min >= 0.5`. Two reasons, both hard:
##      * There is no `flock_stamina_min` stat. mission.gd tracks 24 stats and
##        that is not one of them (mission.gd:369-400), so as written the
##        objective could never tick — the exact "silently dead objective" bug
##        class this project has already shipped.
##      * Even if it existed it would be a free tick. `Flock.rest()` runs on
##        ARRIVAL at leg 5 with REST_CURVE[4] = 1.00 (flock_state.gd:213), so
##        every alive bird is at stamina 1.0 before the player sees the marsh,
##        and nothing inside a zone lowers flock stamina. A primary that is
##        already complete on frame one is a checkbox, not an objective.
##    So the zone scores `LBL_HEAD_COUNT` once per distinct flock bird the
##    player walks up to, which is the same INTENT — go and look at your flock —
##    with an action attached. See zone_stopover.gd::_tick_head_count().
##
## ── THE TUNING RISKS, NAMED ──────────────────────────────────────────────
##
## `required_primaries(5)` is 3 of 4 today, because the spec's
## `required_override: 2` has no hook in mission.gd. All four are sober and
## gentle, so 3 of 4 is survivable — but it is one notch tighter than the trough
## wants, and the override is the single highest-value wiring change for this
## leg.
##
## If leg 5 tests as too busy, the first knob is `meet_the_locals`' cap (8 -> 6)
## and the second is `take_the_air`'s seconds (10 -> 8). Do NOT touch
## `mind_the_flock` or `name_a_driver`: they are the two primaries the spec
## names, and without them this is just a quiet zone rather than the rest beat.

const PRIMARY := 0
const BONUS := 1
const HIDDEN := 2


## ── SCORE LABELS: ONE SPELLING, TWO READERS ──────────────────────────────
##
## Every `label` condition below matches a string `zone_stopover.gd` passed to
## Game.score(). That is two files agreeing on a literal by hand, and it is
## exactly the bug class that already shipped here: suburbia's bespoke moments
## and the objectives waiting on them drifted apart, and the only symptom a
## player sees is an objective that never ticks — which is indistinguishable
## from the whole system being broken.
##
## So leg 5's bespoke labels live HERE, once, and `zone_stopover.gd` preloads
## this file and uses these constants at its `Game.score()` call sites. A rename
## is now a parse error in both files instead of a silently dead objective.
##
## ChaosProp labels ("COOLER", "CANOE", ...) are matched by prefix and are
## already visible at their one call site, so they stay as literals.
##
## NOTE that LBL_TOWER and LBL_WEIR share the prefix "ON THE ". Every condition
## in this file that reads them sets `prefix: false`, so they cannot bleed into
## each other; `variety_pack` counts them as two distinct keys, which is correct
## — they are two different places to be standing.
const LBL_LOCAL := "LOCAL GOOSE"
const LBL_HEAD_COUNT := "HEAD COUNT"
const LBL_DRIVER := "NAMED A DRIVER"
const LBL_SCOPE := "SCOPE"
const LBL_TOWER := "ON THE TOWER"
const LBL_WEIR := "ON THE WEIR"


## The zone-specific set. `mission_defs.gd` appends its own universal hidden
## objectives on top of this, so nothing universal is duplicated here.
##
## Kept behind a `for_zone()` of the same shape as mission_defs.gd's so this
## file can also be used standalone by a test harness.
static func for_zone(zone_id: StringName, leg: int) -> Array:
	if zone_id != &"stopover":
		return []
	return _filter_by_leg(stopover(), leg)


static func _filter_by_leg(defs: Array, leg: int) -> Array:
	var out: Array = []
	for d in defs:
		var e: Dictionary = d
		var from_leg: int = int(e.get("from_leg", 1))
		var until_leg: int = int(e.get("until_leg", 9999))
		if leg >= from_leg and leg <= until_leg:
			out.append(e)
	return out


# ══════════════════════════════════════════════════════════════ THE STOPOVER

static func stopover() -> Array:
	return [
		# ── PRIMARY (4; the spec wants 2 required, the code asks 3) ─────────
		{
			"id": &"meet_the_locals",
			"kind": PRIMARY,
			# KEEP THIS UNDER ABOUT 36 CHARACTERS. `mission_hud.gd:619` draws an
			# objective title into `w - tx - 46` = 344 px at font size 16, with the
			# 46 reserved for the "0/8" counter, and Godot CLIPS rather than
			# ellipsising. The first version of this line was "Honk at {n} geese
			# who were having a nice morning" and it rendered as "Honk at 8 geese
			# who were having a nice" — the joke cut off one word before its own
			# punchline, which is the worst possible place to lose it.
			#
			# The morning moved to the hint, which is where this zone keeps the
			# rest of its jokes anyway ("you have not looked at them since
			# Ontario") and which is drawn at 13 px with no counter beside it.
			"text": "Honk at {n} geese who got here first",
			"hint": "they were having a nice morning",
			"done_text": "{n} geese acknowledged. Barely.",
			"reward": 260,
			# THE ZONE'S SIGNATURE OBJECTIVE, and the cheapest possible one: the
			# verb is the honk, which the player has had since leg 1 and which
			# costs nothing, and the target is forty birds who do not care.
			#
			# It works because of what it is NOT. Every other zone's honk
			# objective ("HONK") pays for scattering a crowd. This one pays per
			# individual resident, once each, so it cannot be farmed by standing
			# in one place mashing the key — you have to walk the marsh and find
			# geese, which is the only "exploration" ask in the level and it is
			# indistinguishable from wandering around at dawn.
			#
			# Capped at 8. Base 5 scales to exactly 8 on leg 5 (x1.72 -> ceil
			# 8.6 -> 9, capped 8), which is a fifth of the crowd. Uncapped it
			# would reach 9 and keep climbing if the leg ever moves.
			"cond": {"type": &"label", "labels": [LBL_LOCAL], "prefix": false,
				"target": 5, "cap": 8},
		},
		{
			"id": &"mind_the_flock",
			"kind": PRIMARY,
			"text": "Go and stand with {n} of your own flock",
			"hint": "you have not looked at them since Ontario",
			"done_text": "{n} of them. All present.",
			"reward": 300,
			# THE ONLY FLOCK-CONDITION PRIMARY IN THE GAME (ROUTE_DATA §7.2), and
			# the one that breaks house rule 2 on purpose. It asks the player to
			# stop causing chaos and go stand somewhere. In leg 6 that would be
			# deleted on sight. Here it is the rest beat expressed as a goal.
			#
			# The zone scores LBL_HEAD_COUNT once per DISTINCT bird walked up to,
			# using the pen's own `focused_bird()` proximity — the same 3.4 m the
			# [G] designate prompt uses — so "stand with" means the bird's name
			# tag is in front of you, not "was within thirty metres".
			#
			# CAPPED AT TWO, AND THAT CAP IS THE MOST LOAD-BEARING NUMBER IN THIS
			# FILE. Do the arithmetic before changing it:
			#   * The Stopover top-up floor is 3 (flock_state.gd:219), so a player
			#     who has been mauled arrives here with exactly three ALIVE birds.
			#   * `Flock.birds[0]` IS the player (`player_index`, flock_state.gd:28)
			#     and `flock_pen.gd::_build()` renders a ghost for it like any
			#     other. The zone excludes that index — standing next to yourself
			#     is not checking on your flock — so the worst case leaves TWO
			#     countable geese.
			# Base 2 with no cap scales to 4 on leg 5. An objective asking for
			# four of two geese is the game lying to the player, which is the
			# exact failure `_scale_cond`'s own cap comment exists to prevent.
			"cond": {"type": &"label", "labels": [LBL_HEAD_COUNT], "prefix": false,
				"target": 2, "cap": 2},
		},
		{
			"id": &"name_a_driver",
			"kind": PRIMARY,
			"text": "Pick somebody to stay clean",
			"hint": "or pick somebody else",
			"no_scale": true,
			"done_text": "Somebody is flying this thing.",
			"reward": 260,
			# ROUTE_DATA §7.2 has this as a BONUS. It is a PRIMARY here because
			# CAMPAIGN_SPEC.md:508 says "The DD is assigned or re-assigned here"
			# and asks for TWO flock-facing primaries — and this is the second
			# one. It is also the gentlest objective in the game: walk to the pen
			# and press one key.
			#
			# ALWAYS AVAILABLE, EVEN IF YOU ALREADY HAVE A DD. flock_pen.gd:368
			# refuses only a re-designation of the SAME bird, and the flock is
			# never smaller than three, so there is always somebody else to
			# promote. That is why the hint is "or pick somebody else" rather
			# than the spec's "(if you haven't)" — the spec's phrasing implies
			# the objective can be un-completable, and it cannot.
			"cond": {"type": &"label", "labels": [LBL_DRIVER], "prefix": false,
				"target": 1},
		},
		{
			"id": &"take_the_air",
			"kind": PRIMARY,
			"text": "Get {n} seconds of continuous air",
			"hint": "there is a tower and there is a lot of nothing to cross",
			"done_text": "{n} seconds. A goose. Flying. Over a marsh. Correctly.",
			"reward": 300,
			# The only primary here that is about MOVEMENT, and the only one that
			# costs anything. CONTINUOUS, not cumulative — touching down resets
			# it — and `seconds` is never scaled by leg (mission.gd:441), so it
			# is the same ten seconds wherever this list ends up.
			#
			# Ten, not the universal hidden `free_bird`'s twelve, and sober-
			# reachable BY DESIGN rather than by luck: the observation tower's
			# ridge is at 5.55 m over ninety metres of open water with nothing to
			# hit, which is the longest unobstructed glide line in the game. A
			# player who works out that the tower is a launch pad gets this in
			# one go. That is the zone teaching its own geometry, quietly.
			"cond": {"type": &"sustain", "when": {"airborne": true}, "seconds": 10.0},
		},

		# ── BONUS ───────────────────────────────────────────────────────────
		{
			"id": &"birdwatcher",
			"kind": BONUS,
			"text": "Be observed",
			"hint": "somebody has been looking at this water for two hours",
			"no_scale": true,
			"done_text": "They wrote something down.",
			"reward": 220,
			# CAMPAIGN_SPEC.md:526 — "The birdwatcher says nothing, but their
			# scope tracks you, and if you honk at them they write something
			# down. That's the whole gag and it costs one Label3D."
			#
			# The objective is the smaller half of that gag: the scope is already
			# tracking you from the moment you can see it, and this fires once
			# you have been in its field for a moment. Two words of text, no
			# number, no counter — the player reads "Be observed", looks around,
			# finds a navy camp chair, and works out what it means. That is the
			# whole content, and it is why this is a bonus rather than a primary.
			"cond": {"type": &"label", "labels": [LBL_SCOPE], "prefix": false,
				"target": 1},
		},
		{
			"id": &"tower",
			"kind": BONUS,
			"text": "Get on the observation tower",
			"hint": "there is only one candidate",
			"no_scale": true,
			"done_text": "Best view in Seneca County.",
			"reward": 240,
			# Suburbia's `get_up_there`, the cottage's `above_the_waterline` and
			# corn's `silo_business`, rebuilt for a zone that is otherwise almost
			# perfectly flat. It is also the setup for `take_the_air`: the tower
			# is the only thing here worth climbing and the best thing here to
			# jump off, and the objective list points at it twice without ever
			# joining the two up.
			"cond": {"type": &"label", "labels": [LBL_TOWER], "prefix": false,
				"target": 1},
		},
		{
			"id": &"sweet_science",
			"kind": BONUS,
			"text": "Land {n} doses in the sweet spot",
			"hint": "watch the meter, not the vibes",
			"done_text": "{n} clean doses. Look at you.",
			"reward": 300,
			# A PRIMARY IN EVERY OTHER ZONE, AND A BONUS HERE. See the header:
			# a required primary that needs a dose would make a pass mark and
			# `slept_on_it` mutually exclusive.
			#
			# It stays in the list, and it stays worth 300, because the zone does
			# contain all sixteen substances and a player who wants to use them
			# should be paid properly for using them WELL. The leg is not against
			# chemistry; it is against chemistry being compulsory. Capped at 4:
			# leg 5's uncapped multiplier asks for six clean doses in a 150 s
			# clock, which is the shortest leg in the run.
			"cond": {"type": &"label", "labels": ["SWEET SPOT"], "prefix": false,
				"target": 3, "cap": 4},
		},
		{
			"id": &"variety_pack",
			"kind": BONUS,
			"from_leg": 4,
			"text": "Wreck {n} different kinds of thing",
			"done_text": "You have been thorough for somebody who is resting.",
			"reward": 320,
			# Late-leg breadth, and the only objective in the file that is about
			# destruction at all. It is a bonus, its target is low, and the zone
			# deliberately supplies only a handful of breakables — a cooler, a
			# couple of camp chairs, a canoe, a bin, a two-four somebody left on
			# the dyke. There is nothing here worth a rampage and that is the
			# point; a player who tries anyway gets one bonus for the effort.
			#
			# `unique` counts every distinct score label, so the zone's own
			# LOCAL GOOSE / HEAD COUNT / SCOPE / ON THE TOWER / ON THE WEIR all
			# feed it. That is intentional: in this zone "different kinds of
			# thing" means "went to different places", which is the mildest
			# possible reading of the word "wreck" and the correct one here.
			"cond": {"type": &"unique", "set": &"labels", "target": 4, "cap": 8},
		},

		# ── HIDDEN — the pair the spec calls the best in the game ────────────
		#
		# CAMPAIGN_SPEC.md:512. Both are `late`, which means Mission gives them
		# exactly one look, inside `evaluate_leg()`, at the buzzer
		# (mission.gd:1186-1192). That is not an optimisation — it is the joke's
		# structure. Neither of these may fire while the player can still change
		# their mind, because both of them are a VERDICT on a decision, and a
		# verdict that arrives while you are still deciding is advice.
		#
		# BOTH ARE PURE `stat` CONDITIONS AND THEY HAVE TO BE. A `late` objective
		# is never fed events: `_tick_objectives()` and `_dispatch()` both skip
		# on `obj.late`, and the single evaluation is `_tick_node()`, which
		# handles only all/any/window/sequence-reset/sustain/unique/stat. A late
		# objective containing a `label`, `event` or `sequence` node can never
		# complete. Keep new ones here to `stat` and `unique`.
		{
			"id": &"slept_on_it",
			"kind": HIDDEN,
			"late": true,
			"title": "SLEPT ON IT",
			"line": "You sat on a pond for two and a half minutes and did absolutely nothing. Your flock has never been fitter.",
			"text": "Did nothing at all",
			"reward": 650,
			"flock": {"stamina": 0.25},
			# THE LEG. Sixteen substances within a two-minute walk, a clock
			# counting down, an objective list you can clear without touching one
			# of them, and no line of text anywhere suggesting you shouldn't.
			# `subs_taken == 0` at the buzzer, and the game says so afterwards.
			#
			# `op: lte, value: 0.0` rather than an equality: the grammar has no
			# `eq`, and `subs_taken` only ever counts up from zero, so "at most
			# zero" and "exactly zero" are the same statement here.
			#
			# The flock payload is the spec's +0.25 stamina and it is honest
			# about being mostly symbolic: arriving at the Stopover already
			# restored every bird to full (REST_CURVE[4] = 1.00), so on a clean
			# run this adds nothing to a bar that is already at 1.0. It matters
			# on exactly the run where it should — one where a failed leg has
			# just taken 0.08 off everybody (mission.gd:1283).
			"cond": {"type": &"stat", "stat": &"subs_taken", "op": &"lte", "value": 0.0},
		},
		{
			"id": &"not_a_rest_stop",
			"kind": HIDDEN,
			"late": true,
			"title": "THIS IS NOT A REST STOP",
			"line": "Everyone was having a nice morning.",
			"text": "Three at once, at dawn",
			"reward": 300,
			# The other half, and the reason the pair works: this is not a
			# punishment card. It pays 300, it is funny, and it is the correct
			# reward for the player who looked at a wildlife refuge containing
			# every drug in the game and drew the obvious conclusion.
			#
			# NO FLOCK PENALTY, per CAMPAIGN_SPEC.md:518 — "the penalty is that
			# you skipped the heal." That penalty is real and it is entirely
			# invisible from here: it is paid two legs later, in the corn, by a
			# flock that spent its one guaranteed recovery being dosed. The
			# objective system should never explain that, and this line does not.
			#
			# Mutually exclusive with `slept_on_it` by construction: peak_subs
			# cannot be >= 3 if subs_taken is 0.
			"cond": {"type": &"stat", "stat": &"peak_subs", "op": &"gte", "value": 3.0},
		},
	]
