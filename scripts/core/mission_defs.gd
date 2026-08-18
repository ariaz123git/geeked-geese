extends RefCounted
## Objective CONTENT. Data only — no behaviour lives here.
##
## Mission (scripts/core/mission.gd) reads these, scales the numbers for the
## current leg, and runs them. Nothing in this file knows how a condition is
## evaluated, which is the point: adding an objective should be a data edit.
##
## ── HOUSE RULES FOR WRITING OBJECTIVES HERE ──────────────────────────────
##
## 1. NEVER name a substance in visible text. Not once. The moment an objective
##    says "use the whippet" it stops being a goal and becomes an instruction,
##    and the player stops experimenting. Visible objectives describe an
##    OUTCOME ("hit four things while you're on two things"); the player
##    supplies the chemistry. Hidden objectives MAY key off a specific
##    substance, because the player never reads them beforehand — that's
##    discovery, not homework.
##
## 2. Every objective must be completable WHILE doing the thing the player
##    already wants to do. If an objective makes you stop causing chaos and go
##    stand somewhere, delete it. There are no fetch quests in a 3-minute leg.
##
## 3. Write like a person who finds this funny, not like a quest log. "Wreck 8
##    shopping carts" is a work order. "Introduce 8 shopping carts to physics"
##    is a joke you can also complete.
##
## 4. Targets are BASE values for leg 1. Mission scales them. Put `no_scale`
##    on anything that is inherently one-shot (you cannot land on 1.9 roofs).
##
## ── DEF SCHEMA (see mission.gd for the condition grammar) ────────────────
##
## {
##   "id":        StringName   required, unique within the leg
##   "kind":      int          Mission.Kind.PRIMARY / BONUS / HIDDEN
##   "text":      String       HUD line. Imperative, funny, <= ~46 chars.
##   "hint":      String       optional second line, dimmer. Use sparingly.
##   "done_text": String       optional replacement line once complete
##   "title":     String       HIDDEN only — the banner headline, caps
##   "line":      String       HIDDEN only — the banner punchline
##   "reward":    int          chaos awarded on completion (scaled by leg)
##   "cond":      Dictionary   completion condition tree
##   "no_scale":  bool         opt out of leg target scaling
##   "late":      bool         only evaluated in evaluate_leg(), not live
##   "from_leg":  int          objective does not appear before this leg
##   "until_leg": int          objective stops appearing after this leg
##   "flock":     Dictionary   {"stamina": f, "intox": f} applied on completion
## }

## Leg 3's objective set lives in its own file — the cottage zone is big
## enough that inlining it here would double this file.
const COTTAGE := preload("res://scripts/core/mission_defs_cottage.gd")
const CORN := preload("res://scripts/core/mission_defs_corn.gd")
const TRUCKSTOP := preload("res://scripts/core/mission_defs_truckstop.gd")
const STOPOVER := preload("res://scripts/core/mission_defs_stopover.gd")
const BIGDOWN := preload("res://scripts/core/mission_defs_bigdown.gd")


const PRIMARY := 0
const BONUS := 1
const HIDDEN := 2


## ── SCORE LABELS: ONE SPELLING, TWO READERS ──────────────────────────────
##
## Every `label` condition below matches a string some zone passed to
## Game.score(). That is two files agreeing on a literal by hand, and it is
## exactly the bug class that shipped here: suburbia's bespoke moments and the
## objectives that wait on them drifted apart, and the only symptom a player
## sees is an objective that never ticks — which is indistinguishable from the
## whole system being broken.
##
## So the bespoke labels live HERE, once, and the zone imports them. A rename
## is now a parse error in both files instead of a silent dead objective.
##
## Only the labels a zone emits from its OWN Game.score() calls need this.
## ChaosProp labels are matched by prefix and are already visible at their one
## call site. `zone_suburbia.gd` is converted; the other zones should follow
## the next time one of them is touched.
const LBL_ROOF := "ON THE ROOF"
const LBL_BOING := "BOING"
const LBL_CANNONBALL := "CANNONBALL"
const LBL_LAUNDRY := "LAUNDRY"


## The whole content set for one leg of one zone.
## Order matters only for display: primaries first, then bonuses. Hidden
## objectives are shuffled into the same array but the HUD never shows them
## until they fire.
static func for_zone(zone_id: StringName, leg: int) -> Array:
	if zone_id == &"cottage":
		return _filter_by_leg(COTTAGE.cottage() + _universal_hidden(), leg)
	var out: Array = []
	match zone_id:
		&"strip_mall":
			out.append_array(_strip_mall())
		&"suburbia":
			out.append_array(_suburbia())
		&"corn":
			out.append_array(CORN.corn())
		&"truckstop":
			out.append_array(TRUCKSTOP.truckstop())
			# BIG DOWN is the back half of leg 7 rather than a leg of its own, so
			# its objectives are part of the truck stop's set and not a separate
			# zone id — the encounter must never call Mission.begin_leg() again
			# or the grade for the first 110 seconds is thrown away.
			out.append_array(BIGDOWN.bigdown())
		&"stopover":
			out.append_array(STOPOVER.stopover())
		_:
			# Unknown zone still gets a playable set rather than an empty HUD.
			#
			# THIS IS A SILENT FAILURE and it is the reason tools/selftest.gd
			# asserts every ROUTE zone's id resolves to something other than this
			# branch. A new zone whose id nobody wired here is fully playable,
			# graded, and running somebody else's objectives.
			out.append_array(_generic())
	out.append_array(_universal_hidden())
	return _filter_by_leg(out, leg)


static func _filter_by_leg(defs: Array, leg: int) -> Array:
	var out: Array = []
	for d in defs:
		var e: Dictionary = d
		var from_leg: int = int(e.get("from_leg", 1))
		var until_leg: int = int(e.get("until_leg", 9999))
		if leg >= from_leg and leg <= until_leg:
			out.append(e)
	return out


# ═══════════════════════════════════════════════════════════ STRIP MALL LOT

static func _strip_mall() -> Array:
	return [
		# ── PRIMARY ─────────────────────────────────────────────────────────
		{
			"id": &"cart_carnage",
			"kind": PRIMARY,
			"text": "Introduce {n} shopping carts to physics",
			"done_text": "{n} carts. Physics won.",
			"reward": 250,
			# Prefix match so the doubled "CART!!" break score also counts —
			# breaking a cart should never feel like it didn't register.
			"cond": {"type": &"label", "labels": ["CART"], "target": 8, "cap": 18},
		},
		{
			"id": &"sweet_science",
			"kind": PRIMARY,
			"text": "Land {n} doses in the sweet spot",
			"hint": "watch the meter, not the vibes",
			"done_text": "{n} clean doses. Look at you.",
			"reward": 300,
			"cond": {"type": &"label", "labels": ["SWEET SPOT"], "prefix": false, "target": 3},
		},
		{
			"id": &"loud_lad",
			"kind": PRIMARY,
			"text": "Honk at {n} things that did not ask",
			"done_text": "Everyone has been honked at.",
			"reward": 180,
			"cond": {"type": &"label", "labels": ["HONK"], "prefix": false, "target": 10},
		},
		{
			"id": &"double_parked",
			"kind": PRIMARY,
			"text": "Hit {n} things while you're on two things",
			"hint": "two at once. three is a nap.",
			"done_text": "Multitasking, chemically.",
			"reward": 320,
			# The mixing tutorial, disguised. Says nothing about WHICH two —
			# every pair in the game satisfies it, so the player picks.
			"cond": {"type": &"label", "labels": [], "target": 4, "when": {"subs_min": 2}},
		},
		{
			"id": &"no_brakes",
			"kind": PRIMARY,
			"from_leg": 3,
			"text": "Wreck {n} things inside ten seconds",
			"hint": "any {n}. go.",
			"done_text": "Ten seconds. Gone.",
			"reward": 400,
			# Leg-3 escalation is a CONSTRAINT, not a bigger number: same verb,
			# now with a clock on it. Pushes the player from wandering to routing.
			"cond": {"type": &"window", "labels": [], "target": 6, "window": 10.0},
		},
		{
			"id": &"sustained_campaign",
			"kind": PRIMARY,
			"from_leg": 5,
			"text": "Get a {n}x chain going and hold it",
			"done_text": "{n}x. The lot is a write-off.",
			"reward": 450,
			"cond": {"type": &"stat", "stat": &"peak_combo", "op": &"gte", "value": 10.0},
		},

		# ── BONUS ───────────────────────────────────────────────────────────
		{
			"id": &"cat_army",
			"kind": BONUS,
			"text": "Get the cats to land {n} hits for you",
			"hint": "so it isn't technically you",
			"done_text": "The cats did that. Not you.",
			"reward": 275,
			"cond": {"type": &"label", "labels": ["CAT "], "target": 5},
		},
		{
			"id": &"vehicular",
			"kind": BONUS,
			"text": "Bounce off {n} parked minivans",
			"done_text": "{n} minivans, deeply inconvenienced.",
			"reward": 200,
			"cond": {"type": &"label", "labels": ["VEHICLE"], "target": 4, "cap": 9},
		},
		{
			"id": &"share_the_wealth",
			"kind": BONUS,
			"from_leg": 2,
			"text": "Share what you're on with the flock, {n}x",
			"hint": "they will remember this in the air",
			"done_text": "The flock is now your problem.",
			"reward": 300,
			# The only objective in the game with a real cost. Big points now,
			# a wobbling formation later. Making the tempting option expensive
			# is what stops "optional" from meaning "obviously do it".
			"cond": {"type": &"label", "labels": ["SHARED WITH THE FLOCK"], "prefix": false, "target": 2},
		},
		{
			"id": &"variety_pack",
			"kind": BONUS,
			"from_leg": 4,
			"text": "Wreck {n} different kinds of thing",
			"done_text": "Nothing in this lot is safe from you.",
			"reward": 350,
			"cond": {"type": &"unique", "set": &"labels", "target": 6},
		},

		# ── HIDDEN (zone-flavoured) ─────────────────────────────────────────
		{
			"id": &"cart_train",
			"kind": HIDDEN,
			"title": "SHOPPING CART TRAIN",
			"line": "Five carts, six seconds. Somebody's groceries are in orbit.",
			"text": "Shopping cart train",
			"reward": 400,
			"cond": {"type": &"window", "labels": ["CART"], "target": 5, "window": 6.0},
		},
		{
			"id": &"do_not_lick_the_toad",
			"kind": HIDDEN,
			"title": "DO NOT LICK THE TOAD",
			"line": "There was no sign. There is now.",
			"text": "Licked the toad",
			"reward": 350,
			"cond": {"type": &"event", "event": &"sub_taken", "id": &"toad_slime", "target": 1},
		},
		{
			"id": &"molly_good_dog",
			"kind": HIDDEN,
			"title": "MOLLY IS A GOOD DOG",
			"line": "Whatever was in that dog's fur, it was not regulated.",
			"text": "Met Molly",
			"reward": 250,
			"cond": {"type": &"event", "event": &"sub_taken", "id": &"molly", "target": 1},
		},
	]


# ═══════════════════════════════════════════════════════════════ SUBURBIA

static func _suburbia() -> Array:
	return [
		# ── PRIMARY ─────────────────────────────────────────────────────────
		{
			"id": &"trash_day",
			"kind": PRIMARY,
			"text": "It's garbage day. Ruin it. ({n} bins)",
			"done_text": "Garbage day, ruined, as promised.",
			"reward": 250,
			"cond": {"type": &"label", "labels": ["GARBAGE", "RECYCLING"], "target": 10, "cap": 14},
		},
		{
			"id": &"gnome_reckoning",
			"kind": PRIMARY,
			"text": "Behead {n} garden gnomes",
			"hint": "they knew what they signed up for",
			"done_text": "{n} gnomes. No survivors.",
			"reward": 275,
			"cond": {"type": &"label", "labels": ["GNOME"], "target": 5, "cap": 10},
		},
		{
			"id": &"sweet_science",
			"kind": PRIMARY,
			"text": "Land {n} doses in the sweet spot",
			"hint": "watch the meter, not the vibes",
			"done_text": "{n} clean doses. Look at you.",
			"reward": 300,
			# Deliberately repeated across zones. The dose meter is the one real
			# skill in the game; a skill you only practise in one zone isn't one.
			"cond": {"type": &"label", "labels": ["SWEET SPOT"], "prefix": false, "target": 3},
		},
		{
			"id": &"get_up_there",
			"kind": PRIMARY,
			"text": "Get on a roof. Ideally not your own.",
			"no_scale": true,
			"done_text": "You live up here now.",
			"reward": 200,
			"cond": {"type": &"label", "labels": [LBL_ROOF], "prefix": false, "target": 1},
		},
		{
			"id": &"backyard_blitz",
			"kind": PRIMARY,
			"from_leg": 3,
			"text": "Wreck {n} things inside ten seconds",
			"hint": "any {n}. pick a backyard.",
			"done_text": "One backyard. Ten seconds. Gone.",
			"reward": 400,
			"cond": {"type": &"window", "labels": [], "target": 6, "window": 10.0},
		},
		{
			"id": &"low_flying_aircraft",
			"kind": PRIMARY,
			"from_leg": 5,
			"text": "Land {n} hits without ever landing",
			"done_text": "{n} hits, feet never down.",
			"reward": 450,
			"cond": {"type": &"label", "labels": [], "target": 4, "when": {"airborne": true}},
		},

		# ── BONUS ───────────────────────────────────────────────────────────
		{
			"id": &"boing",
			"kind": BONUS,
			"text": "Use the trampoline like it owes you money",
			"hint": "{n} bounces",
			"done_text": "The trampoline has been dealt with.",
			"reward": 200,
			"cond": {"type": &"label", "labels": [LBL_BOING], "prefix": false, "target": 5},
		},
		{
			"id": &"cannonball",
			"kind": BONUS,
			"text": "Cannonball the kiddie pool",
			"no_scale": true,
			"done_text": "That pool is a crime scene.",
			"reward": 150,
			"cond": {"type": &"label", "labels": [LBL_CANNONBALL], "prefix": false, "target": 1},
		},
		{
			"id": &"barbecue_ruined",
			"kind": BONUS,
			"text": "Ruin exactly one man's barbecue",
			"done_text": "He was going to eat that.",
			"reward": 250,
			"cond": {"type": &"label", "labels": ["BBQ", "SAUSAGE", "PATIO"], "target": 3},
		},
		{
			"id": &"share_the_wealth",
			"kind": BONUS,
			"from_leg": 2,
			"text": "Share what you're on with the flock, {n}x",
			"hint": "they will remember this in the air",
			"done_text": "The flock is now your problem.",
			"reward": 300,
			"cond": {"type": &"label", "labels": ["SHARED WITH THE FLOCK"], "prefix": false, "target": 2},
		},
		{
			"id": &"variety_pack",
			"kind": BONUS,
			"from_leg": 4,
			"text": "Wreck {n} different kinds of thing",
			"done_text": "This whole street hates you.",
			"reward": 350,
			"cond": {"type": &"unique", "set": &"labels", "target": 6},
		},

		# ── HIDDEN (zone-flavoured) ─────────────────────────────────────────
		{
			"id": &"ascension",
			"kind": HIDDEN,
			"title": "ASCENSION",
			"line": "The trampoline was always the stairs.",
			"text": "Trampolined onto a roof",
			"reward": 450,
			# A physics discovery, not a checklist item: the player works out
			# that the bounce prop is the traversal tool. Sequenced, so it can
			# only happen on purpose-ish.
			"cond": {"type": &"sequence", "steps": [
				{"labels": [LBL_BOING], "prefix": false, "count": 3},
				{"labels": [LBL_ROOF], "prefix": false, "count": 1},
			], "window": 14.0},
		},
		{
			"id": &"wearing_it",
			"kind": HIDDEN,
			"title": "WEARING IT",
			"line": "A very large goose in a stranger's duvet. Keep it.",
			"text": "Wore the laundry",
			"reward": 350,
			"cond": {"type": &"label", "labels": [LBL_LAUNDRY], "target": 1, "when": {"size_min": 1.6}},
		},
		{
			"id": &"pool_party",
			"kind": HIDDEN,
			"title": "POOL PARTY",
			"line": "Nobody invited you. Nobody is going to ask you to leave, either.",
			"text": "Cannonballed, chemically",
			"reward": 400,
			"cond": {"type": &"label", "labels": [LBL_CANNONBALL], "prefix": false, "target": 1,
				"when": {"subs_min": 2}},
		},
	]


# ═════════════════════════════════════════════════ UNIVERSAL HIDDEN SET
#
# These ride along in every zone. They are the best content in the system and
# the reason the HUD is allowed to be short: the visible list is deliberately
# thin because the interesting goals are the ones you trip over.
#
# Design rule for a hidden objective: it must be something a player could
# plausibly do BY ACCIDENT while messing around, and the reveal has to feel
# like the game was watching. If you'd have to read a wiki to get it, it isn't
# a hidden objective, it's a secret, and secrets belong in the Almanac.

static func _universal_hidden() -> Array:
	return [
		{
			"id": &"opening_statement",
			"kind": HIDDEN,
			"title": "OPENING STATEMENT",
			"line": "You did not read the objectives. You did not need to.",
			"text": "Came out swinging",
			"reward": 400,
			# The system winking at itself. Rewards the player who ignores the
			# checklist entirely for the first thirty seconds — which is the
			# behaviour we actually want and the checklist accidentally
			# discourages.
			#
			# 1200 is roughly a fifth of a par leg banked in a sixth of the
			# clock, so it needs a genuinely aggressive opening. An earlier
			# draft used 500 and it fired in every single test run inside
			# fifteen seconds — a secret that always happens is just an
			# unusually loud tutorial.
			"cond": {"type": &"stat", "stat": &"chaos", "op": &"gte", "value": 1200.0, "before": 30.0},
		},
		{
			"id": &"and_then_i_woke_up",
			"kind": HIDDEN,
			"title": "AND THEN I WOKE UP",
			"line": "You blacked out and came back worse. Genuinely inspiring.",
			"text": "Blackout comeback",
			"reward": 500,
			"flock": {"stamina": 0.08},
			# Turns the game's only real punishment into an opportunity. A
			# soft-fail game should pay you for recovering, not just decline to
			# kill you.
			"cond": {"type": &"stat", "stat": &"post_blackout_chaos", "op": &"gte", "value": 400.0},
		},
		{
			"id": &"amateur_chemist",
			"kind": HIDDEN,
			"title": "AMATEUR CHEMIST",
			"line": "Three named combinations in one afternoon. The Almanac has a page about you now.",
			"text": "Three named combos",
			"reward": 600,
			# The single strongest "go mix things" pressure in the game, and it
			# never once tells you what to mix.
			"cond": {"type": &"unique", "set": &"combos", "target": 3},
		},
		{
			"id": &"both_ends_of_the_bus",
			"kind": HIDDEN,
			"title": "BOTH ENDS OF THE BUS",
			"line": "You were a bus. You were a crouton. Same three minutes.",
			"text": "Every size at once",
			"reward": 450,
			# Teaches that body-scaling swings BOTH ways, which most players
			# only ever see one half of.
			"cond": {"type": &"all", "of": [
				{"type": &"stat", "stat": &"peak_size", "op": &"gte", "value": 1.9},
				{"type": &"stat", "stat": &"min_size", "op": &"lte", "value": 0.6},
			]},
		},
		{
			"id": &"free_bird",
			"kind": HIDDEN,
			"title": "FREE BIRD",
			"line": "Twelve seconds airborne. A goose. Flying. Groundbreaking.",
			"text": "Stayed up there",
			"reward": 300,
			# CONTINUOUS, not cumulative — touching down resets it to zero.
			# Stamina makes twelve unbroken seconds a real ask, and the honest
			# way to get there is a stimulant or the flap-rate combo, which the
			# objective very carefully does not mention.
			"cond": {"type": &"sustain", "when": {"airborne": true}, "seconds": 12.0},
		},
		{
			"id": &"outburst",
			"kind": HIDDEN,
			"title": "THAT WASN'T COMMUNICATION",
			"line": "That was an outburst.",
			"text": "Had an outburst",
			"reward": 200,
			# The gateway hidden objective. Cheap, loud, discoverable in the
			# first minute by anyone who mashes the honk key — which is
			# everyone. Its job is to teach the player that hidden objectives
			# exist at all, so the other six feel findable instead of arbitrary.
			"cond": {"type": &"window", "labels": ["HONK"], "prefix": false, "target": 8, "window": 6.0},
		},
		{
			"id": &"designated_driver",
			"kind": HIDDEN,
			"late": true,
			"title": "THE DESIGNATED DRIVER",
			"line": "Obliterated, and you offered the flock nothing. Selfish. Correct. They'll fly straight.",
			"text": "Kept it to yourself",
			"reward": 550,
			"flock": {"stamina": 0.2},
			# Evaluated at the buzzer, so it lands as a verdict on the whole leg
			# rather than a mid-run ping. Rewards the restraint that actually
			# pays off in the migration, and names it as a joke instead of a
			# lecture. This is the objective that ties the zone to the flight.
			"cond": {"type": &"all", "of": [
				{"type": &"stat", "stat": &"peak_subs", "op": &"gte", "value": 2.0},
				{"type": &"stat", "stat": &"chaos", "op": &"gte", "value": 900.0},
				{"type": &"stat", "stat": &"flock_intox", "op": &"lte", "value": 0.05},
			]},
		},
	]


# ══════════════════════════════════════════════════════ FALLBACK ZONE SET
#
# Any zone id we don't have content for still gets three legible primaries so
# a new zone is playable the moment it exists, before anyone writes its list.

static func _generic() -> Array:
	return [
		{
			"id": &"generic_mayhem",
			"kind": PRIMARY,
			"text": "Wreck {n} things. Dealer's choice.",
			"reward": 250,
			"cond": {"type": &"label", "labels": [], "target": 12},
		},
		{
			"id": &"sweet_science",
			"kind": PRIMARY,
			"text": "Land {n} doses in the sweet spot",
			"reward": 300,
			"cond": {"type": &"label", "labels": ["SWEET SPOT"], "prefix": false, "target": 3},
		},
		{
			"id": &"loud_lad",
			"kind": PRIMARY,
			"text": "Honk at {n} things that did not ask",
			"reward": 180,
			"cond": {"type": &"label", "labels": ["HONK"], "prefix": false, "target": 10},
		},
		{
			"id": &"double_parked",
			"kind": BONUS,
			"text": "Hit {n} things while you're on two things",
			"reward": 320,
			"cond": {"type": &"label", "labels": [], "target": 4, "when": {"subs_min": 2}},
		},
	]
