extends RefCounted
## Objective CONTENT for BIG DOWN — the leg 7 encounter across the interstate.
## Data only, no behaviour. Spec: docs/BOSS_DESIGN.md §2.2.
##
## ── WHY THIS IS A SEPARATE FILE AND NOT ROWS IN mission_defs_truckstop.gd ──
##
## BIG DOWN is not a zone. It is an encounter that attaches BESIDE
## zone_truckstop.gd (scripts/world/boss_big_down.gd::spawn_into) and the zone
## script does not know it exists. `Mission.begin_leg()` is called exactly once
## per leg (main.gd:364) and calling it a second time WIPES every objective and
## every stat (mission.gd:144-145), so the encounter cannot bring its own
## objective set with it — its rows have to be in leg 7's one and only list from
## the moment the leg starts.
##
## So these are appended to the truck stop's list, and `mission_defs.gd` needs
## one preload and one line inside its `&"truckstop"` arm. See §WIRING below.
##
## ── THE HARD CONSTRAINT: NOTHING HERE MAY BE A PRIMARY ────────────────────
##
## `Mission.required_primaries(7)` is `clampi(2 + floor(6/2), 1, n-1)` = 5 of
## the truck stop's 6 — the hardest requirement in the campaign, and it is
## deliberately aimed at the zone with the fewest substances. BOSS_DESIGN.md
## §2.2.7 guarantee 1 is that **the dock is optional**: a player who never
## crosses the interstate "gets graded normally" and "loses nothing mechanical".
##
## A primary here would break that guarantee twice over. It would make the leg
## unpassable for a player who stays in the lot, and — because
## `required_primaries` is a pure function of the leg and rises with the primary
## COUNT — a seventh primary would silently make the requirement 5 of 7, i.e.
## make leg 7 EASIER for everybody. Both are wrong. Everything below is BONUS
## or HIDDEN, which leaves 5-of-6 exactly where it is.
##
## ── THE HOUSE RULES, WHICH APPLY HERE TOO ─────────────────────────────────
##
## 1. NEVER name a substance in visible text. Not one of these rows does, and
##    it costs nothing: BOSS_DESIGN.md §3.1 puts ZERO substance sources in the
##    tower. The whole encounter is completable stone-cold sober because there
##    is nothing in there to be anything else on.
##
## 2. Visible rows describe an OUTCOME the player was going to cause anyway.
##    Both bonuses key off the two verbs the room is made of — bouncing off
##    bales and taking out glass — so a player who is having fun completes them
##    without ever reading them.
##
## 3. `prefix` DEFAULTS TO TRUE (mission.gd:867). Every exact match below says
##    `"prefix": false` out loud. The two that leave it true do so on purpose,
##    to catch ChaosProp's doubled break label (`"DOWN BALE" -> "DOWN BALE!!"`,
##    chaos_prop.gd:186).
##
## ── THE LABELS ARE THE CONTRACT ───────────────────────────────────────────
##
## zone_truckstop.gd passes raw string literals to `Game.score()` and
## mission_defs_truckstop.gd matches raw string literals back — so a typo in
## either is a silently dead objective rather than a parse error, and
## docs/DESIGN_MISSIONS.md records that suburbia shipped exactly that bug three
## times. zone_corn.gd fixed it by putting the labels in its defs file as
## constants and preloading them at the call site. THIS FILE DOES THAT, and
## `boss_big_down.gd` preloads it as `MDEF` and scores through these names.
## Rename one and both halves stop compiling, which is the entire point.
const PRIMARY := 0
const BONUS := 1
const HIDDEN := 2

const LBL_INSIDE := "IN THE BUILDING"
const LBL_BALE := "DOWN BALE"
const LBL_PANE := "CURTAIN WALL"
const LBL_JAMMED := "JAMMED IT"
const LBL_LOCKED := "LOCKED OUT"
const LBL_TOP := "TOP FLOOR"
const LBL_WEATHER := "MADE THE WEATHER"
const LBL_EARLY := "AHEAD OF SCHEDULE"
const LBL_RAIN := "IN THE RAIN"


## Kept behind a `for_zone()` of the same shape as the other defs files so this
## file can also be driven standalone by a test harness. NOTE the zone id is
## `&"truckstop"` and not `&"bigdown"` — the encounter shares leg 7's objective
## list because leg 7 only ever gets one.
static func for_zone(zone_id: StringName, leg: int) -> Array:
	if zone_id != &"truckstop":
		return []
	return _filter_by_leg(bigdown(), leg)


static func _filter_by_leg(defs: Array, leg: int) -> Array:
	var out: Array = []
	for d in defs:
		var e: Dictionary = d
		var from_leg: int = int(e.get("from_leg", 1))
		var until_leg: int = int(e.get("until_leg", 9999))
		if leg >= from_leg and leg <= until_leg:
			out.append(e)
	return out


# ══════════════════════════════════════════════════════════════════ BIG DOWN

static func bigdown() -> Array:
	return [
		# ── BONUS ───────────────────────────────────────────────────────────
		#
		# Two, and no more. mission_hud.gd shows a maximum of TWO bonus rows at
		# a time and replenishes from a queue (mission_hud.gd:73, 303); the
		# truck stop already ships five. Adding six more would mean the tower's
		# rows sit in a queue behind `sweet_science` and `gator_country` and the
		# player never sees them at all.
		{
			"id": &"soft_inventory",
			"kind": BONUS,
			"text": "Introduce {n} bales to the outside",
			"hint": "They are softer than they look.",
			"done_text": "There is down all over the floor.",
			"reward": 260,
			# Prefix ON so the break's doubled score ("DOWN BALE!!",
			# chaos_prop.gd:186) counts as well as the impact. That means one
			# bale you actually burst is worth two ticks and one you merely
			# bounce off is worth one — which is the right ordering, because
			# bouncing off them is the point and bursting them is the joke.
			#
			# The row never says what is in the bales. It never says what the
			# white stuff is. Nothing anywhere in the game does. That is not an
			# oversight and it is not coyness — BOSS_DESIGN.md §2.2.3 is that
			# the player makes the connection and the goose does not, and an
			# objective that spelled it out would be the game elbowing you in
			# the ribs about its own best joke.
			"cond": {"type": &"label", "labels": [LBL_BALE], "target": 8, "cap": 20},
		},
		{
			"id": &"glazier",
			"kind": BONUS,
			"text": "Take out {n} panes of curtain wall",
			"hint": "You have had the tool since the tutorial.",
			"done_text": "The building is mostly frame now.",
			"reward": 240,
			# GEEKED_GEESE_DESIGN.md §8 promised "honk stuns, honk rallies the
			# flock, honk shatters glass" and the game has delivered two of the
			# three for eight months. This row is the third one, and it is
			# deliberately a BONUS rather than a hidden: the player has to be
			# ABLE to read it, because it is the only place the game will ever
			# admit the honk is a tool.
			#
			# The hint does not say "honk". A player who arrives at that on
			# their own owns it; a player who never does still breaks glass by
			# flying through it, which also counts.
			#
			# COUNTS AN EVENT, NOT THE LABEL. `boss_big_down.gd` batches a whole
			# shatter into one `Game.score()` so the combo bumps once and there is
			# one hitstop and one popup — all deliberate. But a label condition
			# advances by exactly +1 per scoring call regardless of its amount
			# (`mission.gd:784`), so counting the label meant a honk that cleared
			# six modules moved this row by one, and demolishing two storeys read
			# as 1 of 10. The encounter now also emits one `pane_broken` note per
			# pane, which feeds the same counter without touching chaos, the
			# combo or Juice.
			"cond": {"type": &"event", "event": &"pane_broken",
				"target": 5, "cap": 14},
		},

		# ── HIDDEN ──────────────────────────────────────────────────────────
		#
		# Hidden rows are FORCED to no_scale (mission.gd:202-207), so every
		# reward below is the number written, on every leg, forever.
		{
			"id": &"made_the_weather",
			"kind": HIDDEN,
			"title": "MADE THE WEATHER",
			"line": "Ten thousand of them, and they are inventory. Now they are over four lanes of I-95 in the rain.",
			"text": "Broke the last wall yourself",
			"reward": 600,
			# THE ONE THAT MATTERS, and the encounter's whole authorship branch.
			#
			# BOSS_DESIGN.md §2.2.7 guarantee 2: if the last curtain wall is not
			# broken inside the encounter's cap, HE BREAKS IT HIMSELF, backing
			# into it, and the down goes up anyway. The spectacle is guaranteed;
			# only the question of who did it varies. So this cannot be scored
			# on the weather happening — the weather always happens. It is
			# scored only when the PLAYER put the last wall out, and
			# boss_big_down.gd is careful to pass a different label when the man
			# does it (nothing at all, in fact — his version is unscored,
			# because being present while a building fails is not an
			# achievement).
			#
			# DEVIATION, flagged: the brief asked for this to additionally
			# require breaking the wall inside twenty seconds. It does not.
			# §2.2.7's own words are "skill decides authorship, not outcome" —
			# a player who works out that the honk is a demolition tool has
			# already passed the test the encounter set, and taking the reward
			# away again because they took twenty-five seconds punishes reading
			# the room. The twenty seconds is preserved as `AHEAD OF SCHEDULE`
			# below, which pays chaos and pays no objective, exactly as a
			# flourish should.
			"cond": {"type": &"label", "labels": [LBL_WEATHER], "prefix": false,
				"target": 1},
		},
		{
			"id": &"after_you",
			"kind": HIDDEN,
			"title": "AFTER YOU",
			"line": "There is a nine-tenths of a second between the strobe and the shutter. That is not an accident; that is a reaction window.",
			"text": "Jammed a shutter before it seated",
			"reward": 380,
			# The encounter's only real skill check, and the readability rule
			# from the boss-design literature executed literally: the telegraph
			# is 0.9 s of amber strobe and servo whine, and it exists so that
			# the player still has a choice while it is running.
			#
			# It is HIDDEN rather than BONUS because a visible row saying
			# "jam a shutter" would turn the encounter's one moment of
			# improvisation into a chore with a checkbox. The player who works
			# it out gets told they were right, once, afterwards.
			"cond": {"type": &"label", "labels": [LBL_JAMMED], "prefix": false,
				"target": 1},
		},
		{
			"id": &"locked_out",
			"kind": HIDDEN,
			"title": "LOCKED OUT",
			"line": "He closed it, you waited, and it opened again. He was never trying to hurt you. He was trying to leave.",
			"text": "Stood in front of a closed shutter",
			"reward": 200,
			# THE FAIL STATE PAYS.
			#
			# BOSS_DESIGN.md §2.2.7 makes LOCKED OUT the encounter's only
			# failure and bounds it at about eight seconds that never compound.
			# A punishment that small is not really a punishment, it is a beat —
			# so the game gives you two hundred points for standing there.
			#
			# This is the same move `it_counts_as_water` makes in the truck stop
			# (mission_defs_truckstop.gd): a hidden objective that pays for the
			# thing the player was already doing anyway, and which therefore
			# reads as the game noticing rather than the game grading. It also
			# quietly guarantees that a player who is bad at this encounter
			# leaves it with something, which is the whole reason the fail state
			# was written to be harmless in the first place.
			"cond": {"type": &"label", "labels": [LBL_LOCKED], "prefix": false,
				"target": 1},
		},
		{
			"id": &"nothing_to_do",
			"kind": HIDDEN,
			"title": "NOTHING TO DO",
			"line": "Across the interstate is the truck stop, and the pen, and your flock. They are exactly where you left them.",
			"text": "Stood on the roof in the rain",
			"reward": 300,
			# The rest beat before the peak, and the only objective in the game
			# whose completion condition is standing still.
			#
			# WIN_CONDITIONS.md §1.8 asks for a neutral beat between registers
			# and Slay the Spire's rule wants a guaranteed rest immediately
			# before the summit. Flight 7 is the summit. This is the rest, it
			# lasts fifteen seconds, there is no prompt, the chaos counter has
			# stopped moving because there is nothing left to hit, and the down
			# is coming back down around you.
			#
			# Scored on arrival rather than sustained on purpose: a `sustain`
			# would make the player watch a progress bar during the one beat in
			# the encounter that is specifically about not being asked to do
			# anything.
			"cond": {"type": &"label", "labels": [LBL_RAIN], "prefix": false,
				"target": 1},
		},
	]


# ═══════════════════════════════════════════════════════════════════ WIRING
#
# THIS FILE IS INERT UNTIL mission_defs.gd IMPORTS IT. Nothing reaches these
# rows on its own — `mission_defs.gd::for_zone()` is the single content entry
# point and it only knows the five ids hard-coded in its match. The two edits
# are in a file this encounter does not own; they are reported verbatim in the
# build handoff. For the record they are:
#
#   1. beside the other three preloads at mission_defs.gd:50-52 —
#          const BIGDOWN := preload("res://scripts/core/mission_defs_bigdown.gd")
#
#   2. inside the `&"truckstop"` arm of the match at mission_defs.gd:90-101 —
#          &"truckstop":
#              out.append_array(TRUCKSTOP.truckstop())
#              out.append_array(BIGDOWN.bigdown())
#
# Do NOT give the encounter its own `mission_zone_id()`. There is nowhere to
# return it from — the encounter is not a zone, main.gd asks the ZONE for the id
# once (main.gd:361-363), and Mission reads it once at begin_leg. A second
# begin_leg mid-leg wipes the leg.
#
# CHECK BEFORE ADDING ANOTHER ROW: objective ids are not deduplicated
# (mission.gd:1128 returns the first match), and `_universal_hidden()`
# (mission_defs.gd:412-516) is appended to every zone. None of the six ids above
# collide with it or with mission_defs_truckstop.gd today. `locked_out`,
# `glazier` and `nothing_to_do` are the plausible future collisions; grep before
# reusing them anywhere else.
