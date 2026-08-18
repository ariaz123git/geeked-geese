# GEEKED GEESE — MISSION / OBJECTIVE SYSTEM

*Design document for `scripts/core/mission.gd`, `scripts/core/mission_defs.gd`,
`scripts/ui/mission_hud.gd`.*

---

## 0. The problem

The zone ran a three-minute timer, the player racked up Chaos, and at zero the
game advanced to the migration **regardless of what they did**. There was a
checklist on screen. Nothing read it. Nothing gated on it. Completing one did
nothing.

That is worse than having no objectives at all, because it teaches the player
that the top-left corner of the screen is noise. Everything below is built to
undo that lesson.

---

## 1. Research, and the four principles that came out of it

### 1.1 Goal-setting theory (Locke & Latham, as applied to games)

The literature on gamification through goal-setting theory is consistent and
unambiguous: performance improves when goals are **specific** and **difficult**,
and it only improves *if* those goals come with **continuous, actionable
feedback** and the player is **committed** to them. Specificity and difficulty
without feedback produces nothing. Feedback without specificity produces
nothing. The HCI Games Group's write-up is blunt that difficulty must also
**scale with developing skill**, or the goal decays into either boredom or a
wall.

The old checklist had specificity ("Wreck 8 shopping carts") and nothing else.
No feedback loop that mattered, no consequence, no escalation.

**Principle 1 — a goal must be specific, difficult, fed back on continuously,
and consequential.** All four, or it's decoration. Every objective in this
system has a live progress readout, a payout, and a leg outcome that depends on
it.

### 1.2 The open-world checklist critique

The recurring complaint about checklist open-worlds isn't that they have
objectives — it's that the objectives *pull the player out of the loop they
came for*. Go here, collect this, return. The objective competes with the game
instead of pointing at it. The related literature on completionism (Game
Developer, "Fun & Grief: Completionism in Games") argues that exhaustive lists
convert play into obligation, and that the effective remedy is **abundance**:
when the set is visibly un-completable, the compulsion to complete it
evaporates and players go back to enjoying the parts they chose.

**Principle 2 — objectives must point *into* the core verb, and the player must
never see a completable list.** Every objective here is satisfiable *while*
causing chaos; none require travelling somewhere to do a different activity.
And the player is never shown the full set: bonuses stream two at a time,
hidden objectives are invisible until found, and passing never requires all
the primaries.

### 1.3 Soft fail in comedy sandboxes

Comedy sandboxes (Goat Simulator, Untitled Goose Game) are built on the
player's willingness to try stupid things. Punishing failure is fatal to that,
because the stupid thing *is* the content. Untitled Goose Game's to-do list is
the reference implementation: it states **outcomes**, not methods, accepts many
solutions, and lists unfound tasks as blanks rather than as a scoreboard of
your shortcomings.

The project already had the right instinct — land short on a migration and you
get a shorter next zone, never a game over.

**Principle 3 — extend the existing soft-fail contract, never break it.**
`evaluate_leg()` cannot return "you lost". It returns how much clock you get
next time and how tired your flock is. The worst possible leg costs you 60
seconds and some stamina, and you keep flying.

### 1.4 HUDs in peripheral vision

Player Research's work on perceiving HUDs without looking at them: the
periphery is good at **motion** and **luminance contrast**, bad at small text
and fine hue discrimination, and its dominant failure mode is **crowding** —
adjacent clutter destroys legibility more than small size does. The guidance is
big, stark elements, strong brightness separation from the scene, minimal
clutter.

This matters more here than in most games, because the player is often looking
through a shader that has recolored the world, with a camera that has detached
from the bird.

**Principle 4 — the HUD is read in the periphery or it isn't read.** Shapes
instead of glyphs, bars alongside numbers, redundant encoding of state across
four channels, motion to announce change, and an aggressive cap on row count.

### 1.5 Run-based escalation

Roguelikes escalate by narrowing options and adding rules, not by inflating
numbers — because inflated numbers eventually stop being difficult and start
being impossible, at which point players disengage from the goal entirely.

**Applied:** volume targets scale for five legs then stop. Everything after
that is constraints.

---

## 2. The objective schema

### 2.1 Definition (what you write in `mission_defs.gd`)

```gdscript
{
  "id":        StringName,   # unique within the leg
  "kind":      int,          # Mission.Kind.PRIMARY | BONUS | HIDDEN
  "text":      String,       # HUD line. "{n}" is replaced with the scaled target.
  "hint":      String,       # optional dim second line
  "done_text": String,       # optional replacement line once complete
  "title":     String,       # HIDDEN only — banner headline
  "line":      String,       # HIDDEN only — banner punchline
  "reward":    int,          # chaos paid out on completion (scaled by leg)
  "cond":      Dictionary,   # completion condition tree (below)
  "no_scale":  bool,         # opt out of leg target scaling
  "late":      bool,         # evaluated only at the buzzer, in evaluate_leg()
  "from_leg":  int,          # does not appear before this leg
  "until_leg": int,          # does not appear after this leg
  "flock":     Dictionary,   # {"stamina": f, "intox": f} applied on completion
}
```

`{n}` substitution is not cosmetic. Without it, leg 3 renders
`Introduce 8 shopping carts to physics   5/11` — the objective contradicting its
own counter. (This was caught on the first render test.)

### 2.2 Condition grammar

Nine node types. Composites nest through `of`.

| type | shape | what it's for |
|---|---|---|
| `label` | `{labels:["CART"], prefix:true, target:8, cap:18, when:{…}}` | count chaos-score labels. `labels: []` means *any hit*. |
| `event` | `{event:&"sub_taken", id:&"toad_slime", target:1}` | named events from `note()` or built-in hooks, with optional payload narrowing |
| `window` | `{labels:["CART"], target:5, window:6.0}` | N matching hits inside a **rolling** T-second window — timed challenges |
| `sequence` | `{steps:[{labels:["BOING"],count:3},{labels:["ON THE ROOF"],count:1}], window:14.0}` | ordered steps, all inside one window; goes stale and resets |
| `stat` | `{stat:&"peak_subs", op:&"gte", value:2.0, before:30.0}` | threshold on tracked run state; `before` gates it to the first T seconds and **latches** once met |
| `unique` | `{set:&"combos", target:3}` | distinct entries in a tracked set (`labels`, `subs`, `combos`) |
| `sustain` | `{when:{airborne:true}, seconds:12.0}` | hold a predicate **continuously**; breaking it resets to zero |
| `all` | `{of:[cond, cond]}` | every child met |
| `any` | `{of:[cond, cond]}` | at least one child met |

**`when` predicate** (evaluated at the instant of the event, gates counting):
`subs_min`/`subs_max`, `combo_min`, `airborne`, `in_water`, `size_min`/`size_max`,
`flock_intox_min`/`flock_intox_max`, `blacked_out`, `combo_active`.

**Tracked stats:** `chaos`, `peak_combo`, `peak_subs`, `subs_taken`,
`sweet_spots`, `overdoses`, `blackouts`, `shares`, `honks`, `hard_landings`,
`tumbles`, `takeoffs`, `airtime`, `flight_streak`, `longest_flight`,
`water_time`, `peak_size`, `min_size`, `flock_intox`, `peak_flock_intox`,
`combos_started`, `post_blackout_chaos`, `elapsed`, `hits`.

### 2.3 Two safety properties worth naming

**Self-label filtering.** Objective payouts go through `Game.score(reward,
"OBJECTIVE")` so they inherit the combo multiplier and appear in the normal
feed. Those labels are filtered out of every condition. Without that, an
"any hit counts" objective advances off its own reward, and the system drifts
in a way that reads to a player as random. Covered by a regression test.

**Zone-capacity caps.** `cap` bounds a scaled target by what the zone
physically contains. Suburbia has exactly ten bins and bags; unbounded scaling
asked for eighteen by leg 5. An impossible objective doesn't read as hard, it
reads as the game lying.

---

## 3. The objective list, with rationale

Rationale format: *why it exists* → *why it pushes toward the core verb*.

### 3.1 Strip Mall Lot — primaries

| id | text | rationale |
|---|---|---|
| `cart_carnage` | Introduce {n} shopping carts to physics | The best-feeling prop in the zone: light, loud, rolls forever. → The objective is literally "keep doing the most satisfying thing available". Zero redirection cost. |
| `sweet_science` | Land {n} doses in the sweet spot *(hint: watch the meter, not the vibes)* | Dose accuracy is the only real skill gate in the game; every substance runs through it. → Doesn't say *what* to take, so it's satisfied by whatever the player was already curious about. It rewards experimenting, not obeying. |
| `loud_lad` | Honk at {n} things that did not ask | Free, always available, needs no setup. → The anti-stall objective: a player who has no idea what to do can always honk, bank progress, and stumble into something. Guarantees the pass condition is never gated on a resource you can't find. |
| `double_parked` | Hit {n} things while you're on two things *(hint: two at once. three is a nap.)* | The mixing tutorial in disguise. → Creates pressure to have two substances up simultaneously without ever naming a pair, which is where all 16 control mutations start interacting. The hint teaches the `MAX_STACK` rule as a joke instead of a tooltip. |
| `no_brakes` *(leg 3+)* | Wreck {n} things inside ten seconds *(hint: any {n}. go.)* | First constraint objective. → Converts wandering into routing: you have to line up a run through the corral or the patio set. Same verb, more intent. |
| `sustained_campaign` *(leg 5+)* | Get a {n}x chain going and hold it | Rewards the combo system the score already has. → Pure "don't stop moving" pressure. Impossible to satisfy by standing still and being careful. |

### 3.2 Strip Mall Lot — bonuses

| id | text | rationale |
|---|---|---|
| `cat_army` | Get the cats to land {n} hits for you *(hint: so it isn't technically you)* | Cats exist so catnip has something to command. → Teaches that a substance can weaponise NPCs, which is the most surprising thing in the sandbox and easy to never discover. |
| `vehicular` | Bounce off {n} parked minivans | Minivans are immovable mass — they're the trampolines of the lot. → Encourages using the world as a physics toy rather than a set of targets. |
| `share_the_wealth` *(leg 2+)* | Share what you're on with the flock, {n}x *(hint: they will remember this in the air)* | **The only objective in the game with a real cost.** → Big points now, a wobbling formation in the migration later. This is what stops "optional" from meaning "obviously do it": there is a genuine argument for skipping it, and the hint says so out loud. |
| `variety_pack` *(leg 4+)* | Wreck {n} different kinds of thing | Late-leg breadth. → Pushes the player out of the cart corral and around the whole lot, without ever asking them to go somewhere and *not* cause chaos. |

### 3.3 Suburbia — primaries

| id | text | rationale |
|---|---|---|
| `trash_day` | It's garbage day. Ruin it. ({n} bins) | The single most legible fantasy in a Canadian cul-de-sac. → Bins are scattered across every driveway, so completing it is a tour of the zone by accident. |
| `gnome_reckoning` | Behead {n} garden gnomes *(hint: they knew what they signed up for)* | Gnomes have a low break force and a high point value — they're built to pop. → Rewards precision aggression, and the payoff is instant and funny. |
| `sweet_science` | Land {n} doses in the sweet spot | Deliberately repeated from the strip mall. → A skill you only practise in one zone isn't a skill. This is the system's through-line. |
| `get_up_there` | Get on a roof. Ideally not your own. | The zone's vertical space is invisible until someone tells you it's reachable. → Sends the player looking for a launch, which is what makes them find the trampoline, which is what unlocks `ascension`. One objective seeding another. |
| `backyard_blitz` *(leg 3+)* | Wreck {n} things inside ten seconds *(hint: any {n}. pick a backyard.)* | Suburbia's constraint objective. → Backyards are dense set-pieces; the ten-second clock makes you commit to one and demolish it rather than grazing. |
| `low_flying_aircraft` *(leg 5+)* | Land {n} hits without ever landing | Mastery constraint. → Forces sustained flight *and* aggression at once, which is only comfortable with a stimulant up. Creates a chemistry problem without naming chemistry. |

### 3.4 Suburbia — bonuses

| id | text | rationale |
|---|---|---|
| `boing` | Use the trampoline like it owes you money *(hint: {n} bounces)* | Bouncing is the most physically pleasurable thing in the zone. → The objective is "enjoy the toy", which is the ideal shape for a bonus. |
| `cannonball` | Cannonball the kiddie pool | One-shot, no scaling, always achievable. → A guaranteed win available to anyone having a bad leg. Soft-fail cushioning disguised as a joke. |
| `barbecue_ruined` | Ruin exactly one man's barbecue | Set-piece destruction with a narrative shape. → "Exactly one man" does the comedic work; mechanically it's three hits on a dense cluster. |
| `share_the_wealth` *(leg 2+)* | *(as above)* | The flock-cost decision should exist in every zone, not just the first. |
| `variety_pack` *(leg 4+)* | *(as above)* | |

### 3.5 Fallback set

`_generic()` gives any unregistered zone id three legible primaries and a bonus,
so a new zone is playable the moment it exists, before anyone writes its list.

---

## 4. The escalation curve

Three dials, deliberately moving at different rates.

### 4.1 Target volume — scales, then stops

```
target_scale(leg) = min(1.0 + 0.18 * (leg - 1), 1.9)
```

| leg | 1 | 2 | 3 | 4 | 5 | 6 | 7+ |
|---|---|---|---|---|---|---|---|
| multiplier | 1.00 | 1.18 | 1.36 | 1.54 | 1.72 | 1.90 | 1.90 |
| carts | 8 | 10 | 11 | 13 | 14 | 16 | 16 |

**Why it caps.** The clock never grows — every leg is three minutes — and the
strip mall contains twenty carts. Scaling forever produces objectives that are
not difficult but impossible, and impossible objectives teach the player to
stop reading the HUD, which is the exact failure this system exists to fix.

Two sub-rates:

- `window` and `unique` targets scale at **half rate**. A ten-second window is
  ten seconds on leg 8 exactly as it was on leg 1, and a zone has a fixed
  number of prop categories. At full rate, leg 5 asked for *eleven things
  inside ten seconds*. At half rate it asks for nine.
- Hidden objectives **never scale**. They are fixed-shape jokes; a "five carts
  in six seconds" gag that quietly becomes nine on leg 6 stops being the same
  joke and starts being a wall.
- `cap` bounds anything against zone capacity.

### 4.2 Required primaries — rises, never reaches "all"

```
required(leg) = clamp(2 + floor((leg - 1) / 2), 1, primary_count - 1)
```

| legs | required / available |
|---|---|
| 1–2 | 2 of 4 |
| 3–4 | 3 of 5 |
| 5–6 | 4 of 6 |
| 7+ | 5 of 6 |

The set *grows* at the same time the requirement does, so the player is always
choosing which subset to pursue. Choice is what stops a required list from
reading as a chore.

**The cap at `primary_count - 1` is load-bearing.** There is deliberately never
a leg on which you must do everything, because "do everything" is precisely the
structure that converts optional content into obligation.

### 4.3 New objective kinds — the real difficulty curve

Past the volume cap, escalation is entirely about constraints:

- **Leg 3** adds a timed-window primary. Same verb, now with a clock.
- **Leg 4** adds a breadth bonus.
- **Leg 5** adds a mastery constraint (chain length in the lot, never-touch-the-
  ground in suburbia).

Same amount of stuff; less freedom in how you get it. A veteran on leg 6 should
feel the escalation in what the objectives *ask* — not in a score bar that
quietly outran them, which is why par rises at only 15% a leg.

### 4.4 Rewards

```
reward_scale(leg) = min(1.0 + 0.10 * (leg - 1), 1.6)
```

Slower than targets, so late legs stay worth doing without turning the score
into a leg-number contest.

---

## 5. Hidden objectives

The best part of the system, and the reason the visible list is allowed to be
short: the *interesting* goals are ones you trip over, so the HUD doesn't have
to carry them.

**The rule for writing one:** it must be something a player could plausibly do
*by accident* while messing around, and the reveal has to feel like the game
was watching. If you'd need a wiki, it isn't a hidden objective, it's a secret,
and secrets belong in the Almanac.

They are never listed, never hinted, never counted — until the first one fires.
Only then does a discovery counter appear in the header. Showing "0 of 10
secrets" up front would tell the player they are already failing at something
they cannot see, which is exactly the anxiety this whole design avoids.

### The seven universal ones

**`opening_statement` — "OPENING STATEMENT"**
*"You did not read the objectives. You did not need to."*
1200 chaos inside the first 30 seconds. **The system winking at itself** — it
rewards the player who ignores the checklist entirely and just goes, which is
the behaviour we actually want and which a checklist accidentally discourages.
(First draft used 500 and fired in every test run inside fifteen seconds. A
secret that always happens is just an unusually loud tutorial.)

**`and_then_i_woke_up` — "AND THEN I WOKE UP"**
*"You blacked out and came back worse. Genuinely inspiring."*
400 chaos in the 25 seconds after coming to from a blackout. **This is the most
important hidden objective in the set.** Blacking out (three substances) is the
game's only real punishment — it clears your actives, freezes you for three
seconds and hands you a comedown. This turns the worst outcome into an
opportunity. A soft-fail game should *pay you for recovering*, not merely
decline to kill you. Also grants flock stamina.

**`amateur_chemist` — "AMATEUR CHEMIST"**
*"Three named combinations in one afternoon. The Almanac has a page about you now."*
Three distinct named combos in one leg. **The strongest "go mix things" pressure
in the game, and it never once says what to mix.** With five named combos in
`Subs.COMBOS`, finding three means genuinely exploring the pairing space.

**`both_ends_of_the_bus` — "BOTH ENDS OF THE BUS"**
*"You were a bus. You were a crouton. Same three minutes."*
Peak body size ≥1.9 *and* minimum ≤0.6 in one leg. Most players only ever
experience one half of the macropsia/micropsia scaling — the reveal tells them
the other half exists, retroactively, at the moment they've just found it. An
`all` composite of two opposing thresholds.

**`free_bird` — "FREE BIRD"**
*"Twelve seconds airborne. A goose. Flying. Groundbreaking."*
Twelve **continuous** seconds aloft — touching down resets it. Stamina makes
that a real ask, and the honest route is a stimulant or the flap-rate combo,
which the objective very carefully does not mention.

**`outburst` — "THAT WASN'T COMMUNICATION"**
*"That was an outburst."*
Eight honks in six seconds. **The gateway.** Cheap, loud, and discoverable in
the first minute by anyone who mashes the honk key — which is everyone. Its job
is to teach the player that hidden objectives exist *at all*, so the other six
feel findable instead of arbitrary. A secrets system with no easy first secret
is a secrets system nobody knows about.

**`designated_driver` — "THE DESIGNATED DRIVER"** *(evaluated at the buzzer)*
*"Obliterated, and you offered the flock nothing. Selfish. Correct. They'll fly straight."*
End the leg having peaked at two simultaneous substances, scored 900+, and left
the flock at ≤0.05 average intoxication. **This is the objective that ties the
zone to the flight.** It lands as a verdict on the whole leg rather than a
mid-run ping, it rewards the restraint that actually pays off in the migration,
and it names that restraint as a joke instead of a lecture. Grants +0.2 flock
stamina — mechanically, the reward for not dosing your friends is friends who
can take a lead shift.

### Zone-flavoured

**`cart_train`** — "SHOPPING CART TRAIN" / *"Five carts, six seconds. Somebody's
groceries are in orbit."* Five carts inside six seconds. Rewards finding the
corral and committing.

**`do_not_lick_the_toad`** — "DO NOT LICK THE TOAD" / *"There was no sign. There
is now."* The toad in the cattails is already in the zone with that exact
comment in the source. Keying a hidden objective off a specific substance is
fine *because the player never reads it beforehand* — that's discovery, not
instruction.

**`molly_good_dog`** — "MOLLY IS A GOOD DOG" / *"Whatever was in that dog's fur,
it was not regulated."*

**`ascension`** *(suburbia)* — "ASCENSION" / *"The trampoline was always the
stairs."* Three trampoline bounces then a roof, inside fourteen seconds. **A
physics discovery, not a checklist item** — the player works out that the bounce
prop is a traversal tool. Seeded by the `get_up_there` primary, which sends them
looking for a launch in the first place.

**`wearing_it`** *(suburbia)* — "WEARING IT" / *"A very large goose in a
stranger's duvet. Keep it."* Hit the laundry line while body size ≥1.6.

**`pool_party`** *(suburbia)* — "POOL PARTY" / *"Nobody invited you. Nobody is
going to ask you to leave, either."* Cannonball the kiddie pool with two
substances up.

---

## 6. Leg outcome

`evaluate_leg() -> Dictionary`:

```gdscript
{
  "zone", "leg",
  "passed": bool,               # primaries_done >= required
  "required", "primaries_total", "primaries_done",
  "completed": Array[StringName],
  "missed": Array[StringName],
  "hidden_found": Array[StringName], "hidden_total": int,
  "breakdown": {"chaos", "objectives", "hidden", "style", "total", "par"},
  "grade": String,              # "F".."S"
  "grade_index": int,           # 0..5
  "rank_text": String,          # a funny line per grade
  "zone_time_modifier": float,  # seconds to add to the next zone
  "next_zone_seconds": float,   # ready-to-use suggestion
  "flock_note": String,
}
```

**Style score** = `peak_combo × 25 + distinct_combos × 120 + peak_subs × 60`.
The "you played with flair" axis — chaining and chemistry, the two things an
objective list can't fully capture.

**Grade** = `total / par`, where `par = PAR_BASE × (1 + 0.15 × (leg - 1))`.

| ratio | ≥1.75 | ≥1.35 | ≥1.00 | ≥0.70 | ≥0.45 | else |
|---|---|---|---|---|---|---|
| grade | S | A | B | C | D | F |

**Missing the primaries caps you at C**, no matter how much you scored.
Otherwise "ignore the objectives, hit things fast" strictly dominates, and the
objectives are decoration again — which is the bug we started with. Verified by
a regression test that scores 15,000+ chaos with zero primaries and asserts the
grade is still capped.

> **`PAR_BASE = 6000` is the one number to calibrate after the first real
> playtest.** It is derived, not guessed: hitting every static prop in the strip
> mall once is worth roughly 2,600 base chaos, and the combo multiplier on a run
> that keeps moving roughly doubles that. So 6,000 is "you cleared the lot and
> kept your chain alive" — a good afternoon, not a perfect one. Everything else
> in the grading table is a ratio against it, so difficulty tuning is one edit.

### Soft fail

You cannot lose a run.

- **Missing primaries** costs 20 seconds off the next leg's clock per shortfall,
  and 0.08 flock stamina. Floored at 110 seconds — a disastrous leg still leaves
  a playable one.
- **Passing well** buys back up to 20 seconds, capped. A reward you can bank
  forever snowballs; a reward that tops out is a pat on the head, which is all
  it needs to be.

This composes with the existing migration soft fail (land short → 120s instead
of 180s) rather than replacing it. Two independent axes, both floored.

---

## 7. The HUD

### Applied peripheral-vision findings

| finding | implementation |
|---|---|
| periphery reads shapes, not small glyphs | markers are **drawn primitives** — outline square, filled square + tick, diamond. Also immune to a missing font glyph. |
| periphery detects size/length pre-attentively | progress is a **bar** as well as a number. `6/8` requires foveating; a bar doesn't. |
| periphery has poor hue discrimination | done-state is encoded **four** ways: marker changes, bar fills, text dims, strikethrough appears. Never hue alone. |
| periphery detects motion | bars **slide** rather than snap; completed rows punch, then collapse out. |
| crowding is the dominant failure | dark backing plate per row, generous separation, hard cap on row count. |
| brightness separation from scene | every row has its own plate; all text is drawn with a 4px black outline. The old panel was 32% alpha and vanished into both the overcast asphalt and the trip shader. |

### Primary vs bonus

Primaries: 16px, full brightness, **gold left accent stripe**.
Bonuses: 13px, ~75% brightness, no stripe, prefixed with `+`.

That size difference is doing design work. Optional content only stops feeling
mandatory if it visibly reads as secondary *before you read it* — the stripe's
presence or absence is a pre-attentive cue.

### `MAX_BONUS_ROWS = 2` — the most important number on the panel

Leg 4 has four bonuses. Listing all of them beside five primaries produced a
**nine-row wall** on the first render test — the open-world checklist failure,
reproduced faithfully.

Bonuses now show **two at a time and replenish** as you clear them. The player
never sees the full set, so there's no set to feel behind on, and clearing one
is rewarded with a *new* one appearing rather than with a shorter to-do list.
Optional content should feel like a supply, not a backlog.

Completed rows also **collapse out of the list** after 2.2 seconds, so the panel
gets *smaller* as you succeed — the opposite of what a checklist does to you.

### Completion feedback

1. Row punches scale and flashes near-white gold.
2. A `+250` chip arcs up and fades (parented to the row, so it tracks layout).
3. `score_blip_hi`.
4. A toast band appears directly under the panel — same place the eye already
   flicked to — reading `OBJECTIVE / Introduce 11 shopping carts to physics`.
   It tracks the panel's live bottom edge every frame, because the panel
   resizes constantly.
5. After 2.2s the row collapses out.

### Hidden reveal

Full-width band across the lower third: kicker `SOMETHING HAPPENED`, the title
in 32px, the punchline under it. Scales in with overshoot, holds 2.3s, fades.
Plays `unlock`. Then the row inserts into the list already-complete with a
diamond marker.

Reveals are **queued**, not overlapping — two hidden objectives can fire on the
same frame (a cart train that also tips you past the opening-chaos threshold),
and without a queue the second restarts the tween and the player sees half of
one banner and none of the other. That reads as a bug at exactly the moment the
game is trying to feel generous.

### Getting out of the way

- **TAB** cycles FULL → COMPACT (one line: `OBJECTIVES 2/3   3 FOUND`) → OFF.
- **Auto-dim**: after 10 seconds with no progress the panel fades to 45% alpha;
  any progress snaps it back. The list is there when you look for it and out of
  the way when you don't, with no setting to manage mid-flight.
- Still respects the existing `show_hints` pref.

### The header

`LEG 3   NEED 3 OF 5` plus one **pip per required primary**, filled as you bank
them. Goal-setting theory again: the pass condition must be specific and known,
not inferred. The pips are the most important information on the panel, so
they're a shape.

---

## 8. Verification

> **Corrected 2026-08-04.** The first bullet used to read
> `godot --headless --path . --import` — *"parse-clean, no errors"*. **That
> command never compiled GDScript.** `--import` imports assets; a file containing
> this project's most common parse error (`var x := some_dictionary.key`) passes
> it in silence. The real gate is `godot --headless --path . -- --gate`; see
> `tools/gate.gd`, which documents why the old one was worthless.
>
> Also: **`tools/mission_harness.gd` and `tools/mission_hud_probe.gd` are not in
> this repo.** `tools/` contains `gate.gd`, `gen_audio.py`, `gen_music.py` and
> `gen_textures.py` and nothing else. The results below are a record of a run
> that happened in a scratch project; they are **not reproducible here**. Treat
> them as history, not as regression coverage, and do not cite them as evidence
> that the mission system still works.

- `godot --headless --path . -- --gate` — every `.gd`, `.tres` and `.tscn` in the
  project is force-loaded inside the booted project, so autoload identifiers
  resolve. Exit 0 is the only pass.
- `tools/mission_harness.gd` *(missing — see the note above)* — **82 checks, 0
  failures**, exits non-zero on
  failure so it drops straight into CI. Covers every condition type, the `when`
  predicates, the self-label feedback guard, sequence staleness, the blackout
  window, late objectives, the grading table's monotonicity, the soft-fail
  arithmetic, and the full escalation curve.
- `tools/mission_hud_probe.gd` *(missing — see the note above)* — renders the panel, a completion, a hidden
  reveal and compact mode to PNG under `xvfb` + `opengl3`, because `_draw()`
  never runs headless and a bad `draw_string_outline()` signature would sail
  straight through the logic harness. It caught the text truncation, the stale
  `{n}` numbers, the nine-row bloat, the mispositioned reward chips and the
  overlapping toast.

---

## 9. Integration

> **⚠ ALREADY DONE. Do not apply this section again.** Verified 2026-08-04:
> `Mission` is registered in `project.godot`, both zones implement
> `mission_zone_id()`, and `main.gd::_load_zone()` calls `Mission.begin_leg()`
> and `Mission.bind_goose()`. This section is kept as a record of *how* it was
> wired, not as a task.
>
> **The `project.godot` block below is a historical snapshot and is now wrong** —
> the live file has **ten** autoloads, in the order
> `Prefs Tex Sfx Subs Game Flock Unlocks Juice Mission Music`. Pasting the block
> below over the real one would delete `Juice` and `Music`. Read `project.godot`.

### 9.1 `project.godot`

Add `Mission` as the **last** autoload:

```ini
Prefs="*res://scripts/core/prefs.gd"
Tex="*res://scripts/core/tex.gd"
Sfx="*res://scripts/core/sfx.gd"
Subs="*res://scripts/core/substance_manager.gd"
Game="*res://scripts/core/game.gd"
Flock="*res://scripts/core/flock_state.gd"
Unlocks="*res://scripts/core/unlocks.gd"
Mission="*res://scripts/core/mission.gd"      ; <-- must be after Game/Subs/Flock
```

Order is load-bearing. `Mission._ready()` resolves `/root/Game`, `/root/Subs`
and `/root/Flock` and subscribes to their signals; if it loads first those are
all null and it silently never connects.

### 9.2 Zone id

Each zone needs to name itself. Add to `zone_strip_mall.gd` and
`zone_suburbia.gd`:

```gdscript
func mission_zone_id() -> StringName:
	return &"strip_mall"      # &"suburbia" in the other
```

If you'd rather not touch the zones, `main.gd` can map its own
`ZONE_ROTATION` index instead — `Mission` accepts any `StringName`, and an
unrecognised one falls back to `_generic()` rather than an empty HUD.

The zones' existing `objectives()` functions become dead code and can be
deleted. (Note two of suburbia's old entries — `leaf_blower_beef` and
`get_on_the_roof` — had no `match` key and no matching score label, so they
could never have completed.)

### 9.3 `main.gd`

**Replace the body of `_setup_objectives()`:**

```gdscript
func _setup_objectives(zone: Node) -> void:
	objectives = preload("res://scripts/ui/mission_hud.gd").new()
	objectives.name = "MissionHud"
	add_child(objectives)

	var zid: StringName = &"strip_mall"
	if zone.has_method("mission_zone_id"):
		zid = zone.mission_zone_id()
	Mission.begin_leg(zid, Flock.leg)
	Mission.bind_goose(zone.goose)
```

The HUD is added *before* `begin_leg()` so it catches the `objectives_ready`
signal. (It also pulls current state in `_ready()`, so either order works.)

**Delete** the `_obj_matchers` field, the matcher loop, and this line from
`_on_chaos_scored()`:

```gdscript
if objectives and is_instance_valid(objectives) and _obj_matchers.has(label):
    objectives.progress(_obj_matchers[label], 1)
```

Mission subscribes to `Game.chaos_scored` itself. Leave the `best_chaos` pref
update alone.

**Close the leg out** at the top of `_load_migration()`, before `_clear()`:

```gdscript
func _load_migration() -> void:
	var result: Dictionary = Mission.end_leg()
	print("[leg] %s — %s  %d/%d primaries" % [
		result.grade, "PASSED" if result.passed else "FELL SHORT",
		result.primaries_done, result.required])
	_clear()
	...
```

`end_leg()` is idempotent, so a double call is safe.

**Feed the outcome into the next zone's clock** in `_on_migration_done()`:

```gdscript
func _on_migration_done(dist: float, target: float) -> void:
	var made_it := dist >= target * 0.999
	if made_it:
		Flock.leg += 1
	Flock.rest()
	# Two independent soft fails, both floored: landing short costs you the
	# clock, and so does ignoring the objectives.
	var base := 180.0 if made_it else 120.0
	var res: Dictionary = Mission.last_result()
	var modifier: float = float(res.get("zone_time_modifier", 0.0))
	Game.start_zone(clampf(base + modifier, 100.0, 220.0))
```

### 9.4 Signals available to connect

```gdscript
Mission.objectives_ready(list: Array)
Mission.objective_progressed(id: StringName, progress: int, target: int, kind: int)
Mission.objective_completed(id: StringName, kind: int, reward: int)
Mission.hidden_revealed(id: StringName, title: String, line: String, reward: int)
Mission.primaries_completed()
Mission.leg_decided(result: Dictionary)
```

`mission_hud.gd` wires the first four itself. `leg_decided` is the hook for a
results card — the dictionary in §6 has everything such a screen needs.
`primaries_completed` is a good hook for a one-off sting or a HUD flourish.

### 9.5 Optional extras

- `Mission.note(&"event", {...})` feeds anything not already on a signal.
- Nothing needs to be added to `Game.ACTIONS`; the HUD registers its own
  `gg_objectives` (TAB) toggle in `_ready()`, matching how `Game` handles input.
- `tools/mission_harness.gd` and `tools/mission_hud_probe.gd` are verification
  only — ship them or don't, they're never loaded by the game.
