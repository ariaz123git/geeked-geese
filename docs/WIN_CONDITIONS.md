# GEEKED GEESE — WIN CONDITIONS

### A decision document. Three options. Pick one.

*Read time: ten minutes. Consequence: months.*

> **Status stamp, 2026-08-04. The decision was made and most of it is built.**
> This document is kept for its *reasoning* — `HANDOFF.md` §5 says to read it
> "for *why*, not what" — and none of that reasoning has been touched. But
> several of the observations it uses as evidence describe a codebase that no
> longer exists, and a reader who takes them as current will re-derive work that
> is done. Checked against the source on this date:
>
> - **`ZONE_ROTATION` is gone.** It is `ROUTE`, eight fixed legs, with
>   `FINAL_LEG = 8`. The game can be won.
> - **Part 4 §3 — "`grep Flock. scripts/ui/` returns nothing … zero surfaces".**
>   No longer true. `scripts/ui/flock_roster.gd` is the roster screen, built by
>   `main.gd` and reachable from the pause menu and the results card.
> - **Part 4 §4 — "`Flock.set_dd()` exists, and nothing calls it".** No longer
>   true: `flock_pen.gd:369` calls it behind the `[G]` prompt. (The claim that
>   "the README lists it as unbuilt" is also spent — the README no longer
>   mentions the DD at all.)
> - **Part 4 §5 — "`scars` is dead … written by nothing".** No longer true.
>   `flock_state.gd::scar_bird()` is the writer; `migration.gd` and `main.gd`
>   call it; `can_lead()`, the roster and the flight strip read it.
> - The ending is built (`scripts/world/zone_finale.gd`), and a boss shipped
>   (`scripts/world/boss_ranger.gd`) despite this document and
>   `CAMPAIGN_SPEC.md` §2.10 both arguing against one for v1.
>
> The day-estimate tables further down are estimates for work that has since been
> done. They are not a to-do list any more.

---

## 0. The decision in one page

The per-leg mission system is good and survives all three options untouched. What is missing is
**the layer above the leg**: the game cannot be won, cannot be lost, has no arc, and has no reason
to be played twice. `ZONE_ROTATION` wraps modulo 3 and `Flock.leg` counts up forever into nothing.

Three coherent answers, differing in kind:

**A — THE FLYWAY.** *One finite journey.* A fixed 8-leg route from a stormwater retention pond in
Ontario to a golf course in Florida. Roughly 45 minutes, one sitting. You always arrive; the
question the game asks is **who arrived with you.** Geese die permanently and are never replaced,
so the ending is written by your flock roster, not by a score. Credits roll. The bible's "one
sincere moment" happens on the 18th green. Replay comes from an Ascension-style escalation ladder,
not from unlocks. No hard fail — soft-fail precedent intact.

**B — THE LONG WINTER.** *Endless attrition with a real lose condition.* No destination. Legs
continue forever, escalating: shorter clocks, longer flights, denser hazards, tolerance that never
resets. Geese die and are never replaced. When the last goose is gone, **the run is over** — score
screen, distance flown, personal best. The flock becomes the health bar, and every unit of health
has a name. Cheapest option by a wide margin. Costs you Florida, the credits, and the sincere
moment, permanently.

**C — THE POND.** *Campaign across several runs.* A run is an attempt at the route and can genuinely
fail. Between runs you return to the pond hub: the roster, the nest, the codex. Geese that survived
a failed run retire and stay at the pond; the ones that didn't are gone. Florida is reachable only
after several attempts, and the sincere ending is the *game's* ending, not the run's. This is
literally what §6 of the design bible describes. It is also the most work by a factor of two or
three, and it walks straight into the meta-progression research, which is largely damning.

> **Recommendation: A, with two specific borrowings from B and C.** Reasoning in Part 3. What to
> build first: the route table and the arrival, in that order — both are achievable before a single
> new zone exists.

### Comparison

| | **A — Flyway** | **B — Long Winter** | **C — The Pond** |
|---|---|---|---|
| Run length | ~45 min, fixed | 20–90 min, until you die | 30–45 min × N runs |
| Win | Reach Florida | none (best distance) | Reach Florida once, ever |
| Lose | none (graded arrival) | flock hits zero | flock hits zero / run ends short |
| Carries over | Almanac, Ascension tier | Almanac, personal best | roster, nest, codex, unlocks |
| Ending exists? | **yes, every run** | no | yes, once |
| Soft-fail precedent | intact | **broken, deliberately** | broken |
| Flock's role | who arrives = the ending | the health bar | the memorial |
| New zones needed | 1–2 (see §A.5) | 0 | 3+ plus 2 metagame screens |
| Rough effort | 2–4 weeks | 3–6 days | 2–4 months |
| Identity | a comedy road movie | an arcade cabinet | a roguelite with a hub |
| Biggest risk | 8 legs of 3 zones reads thin | endless is forgettable | grind gates the jokes |

---

# PART 1 — RESEARCH

Ten sources actually changed something below. Where research merely confirmed an instinct I say so
rather than dressing it up.

## 1.1 Fail states are a ladder, not a switch

Josh Bycer's [hierarchy of fail states](https://game-wisdom.com/critical/hierarchy-of-fail-states-game-design)
ranks failure punishments from lightest to heaviest: **time → progress → resources → power →
everything**. The load-bearing rule is that *harder games take softer punishments*: "Most hard games
will only feature time as the punishment, as the title is hard enough without taxing the player
more." And the inverse — heavy punishment is only earned when the game compensates: "if the player
is going to be starting over again, the game has to offer enough variances to make the runs feel
different."

Geeked Geese currently sits on **rung 1 and a half**: missing objectives costs you time (clock next
leg) and a sliver of resource (flock stamina). Nothing else. The article's warning is the one that
matters for this decision: *"The moment the player feels like they are no longer making progress in
your game is when they will consider leaving your game altogether."* That is the actual disease
here. Not the absence of punishment — the absence of a destination.

[Game Developer's balance-of-fail-states piece](https://www.gamedeveloper.com/design/the-balance-of-fail-states-in-game-design)
supplies the counterweight: fail states exist so that winning means something. *"They are required in
order to create tension and allow the player to feel like they've won."* Its concrete rules are
anti-spiral (punishments must not compound) and proportionality (*"The more demanding or involved
your game is, the less punishing your fail state should be"*).

**What this changed:** I stopped treating "add a lose condition" and "keep soft fail" as opposites.
They operate on different units. The current soft-fail contract is about **legs**. Ending a **run**
is a different promise and can be broken without breaking the first one. Option B leans on this
distinction; A sidesteps it.

## 1.2 End conditions have a taxonomy, and yours should be "thematically inseparable"

[Games Precipice's late-game structures piece](https://www.gamesprecipice.com/endings/) sorts endings
along two axes. On *player control*: fixed-length ("completely objective and happens the same way
every time," but hard to balance and prone to runaway leaders), indirect, and direct. On
*integration*: incidental → balance-justified → mechanically persuasive → **thematically
inseparable**, where "theme and mechanics align perfectly" — the example being that *Risk* "ends
precisely when it's intuitive for it to end."

This is the single most useful frame in the research, because Geeked Geese has an unusually strong
thematically-inseparable ending available and is not using it. **A migration ends when you arrive.**
Not at a score, not at a round count — at a *place*. Real Canada geese fly a real flyway to real
overwintering grounds and the game is named after the trip. Any ending other than arrival is
incidental by comparison.

That article's other gift is the "mechanically persuasive" category: endings you can *see coming*
because a physical thing is depleting. The flock is exactly that. Six geese, permanently lost, never
replaced, each with a name — a visible, tactile countdown to something.

## 1.3 Meta-progression: the research is mostly hostile

I went in expecting the "campaign + meta" hybrid to be the safe modern answer. The literature
pushed back hard.

Zeno Rogue's [*Are roguelikes bad?*](https://zenorogue.medium.com/are-roguelikes-bad-de3a9856a3e5)
argues metaprogression "artificially extends playtime by making early runs too difficult and late
runs too easy," reintroducing grinding under a new name, and that short runs are not a courtesy to
busy players but a hook: roguelites are "time-stealers" with addictive "one more run" design.

The [Hacker News thread on meta-progression](https://news.ycombinator.com/item?id=43658059) has the
sharpest formulation of the core objection, from *chongli*: *"Meta-progression takes away the
from-scratch element and just allows you to win through sheer persistence, chipping away at the
problem until it's easy enough… It's like a mountain that keeps getting smaller every time you
attempt to climb it, until it's finally shrunk to the size of an anthill."* The strongest defence in
the thread (*tstrimple*) is **not** "it rewards grinding" but "it gates *complexity*, not power" —
unlocks that introduce systems gradually and may be *harder*, not easier.

The alternative that keeps coming up is Slay the Spire's Ascension ladder.
[Frostilyte's analysis](https://frostilyte.ca/2020/04/16/more-games-should-handle-difficulty-like-slay-the-spire/)
notes that "each of the ascension levels only makes Slay the Spire marginally more difficult… rather
there are several small steps," and argues this teaches the game's depth in a way a difficulty menu
cannot: each rung forces re-evaluation of strategies the player had settled into.

**What this changed my mind about:** I came in assuming the hybrid was the recommendation. It isn't.
Ascension-style escalation delivers roughly the same replay value as meta-progression with none of
the grind, none of the content gating, and about a tenth of the build cost — and for *this* game,
gating substances behind grind would make the first two hours **less funny**, which is the one
outcome the project cannot afford.

## 1.4 The run is a unit of meaning, and it should fit in a sitting

Miguel Sicart's [*The Run*](https://playingsoftware.substack.com/p/the-run) treats the run as the
minimum unit of meaning — "a coherent attempt at finishing a roguelike," bounded, narratable,
"easy to record, stream, or write up." His comparison is instructive: *Balatro*'s ten-minute runs
invite immediate repetition; *Returnal*'s variable-length runs are designed to exhaust. Both work,
but they are different promises. The line worth keeping: **"The run is to the roguelike what stanzas
are to the sonnet."**

On length specifically, [Delayed Respawnse on Vampire Survivors](https://delayedrespawnse.com/blog/does-vampire-survivors-respect-your-limited-play-time/)
argues the 30-minute cap is a *contract*: "A run has a defined shape," and players know "exactly what
kind of time commitment" they're making. The warning is that the surrounding unlock treadmill can
undo that virtue by turning completion into "an obligation instead of a bonus."

**Applied to the numbers in this repo** (measured, see §5): a leg is ~5 minutes of wall clock —
180 s zone + 85–125 s flight + results and briefing. So:

| legs | wall clock | verdict |
|---|---|---|
| 6 | ~30 min | tight; the mission escalation curve barely finishes |
| **8** | **~40–45 min** | **fits a sitting; the escalation curve completes exactly here** |
| 10 | ~55 min | acceptable ceiling |
| 12+ | 65 min+ | past the contract; players start abandoning mid-run |

## 1.5 Endless and score-attack: the psychology is worse than it looks

Yu-kai Chou's [leaderboard guide](https://yukaichou.com/gamification-analysis/leaderboard-design-definitive-guide-octalysis/)
is blunt about the failure mode: *"When you put 10,000 users on a single global ranking, you get one
euphoric winner and 9,900 demoralized losers."* His remedies are relative and sliced boards —
neighbourhood views ("5 above and 5 below"), time-sliced, region-sliced, friends-sliced — and the
success test is behavioural: *"Are users taking screenshots of their #1 rankings and sharing them?"*

For a single-player indie with no backend, only one slice is actually available: **the player against
themself.** Personal best, previous-run ghost, "your longest migration." That is not nothing —
but note that Geeked Geese *already has* `best_chaos` in `Prefs`, and it has done nothing for the
game's shape. A number that persists is not a structure.

Chou's Ariely reference is the one to fear: "when people see the value of their work being
dismantled… they lose motivation fast." An endless mode where every run ends in the same score
screen dismantles the flock's story every single time.

## 1.6 Journey games and party attrition: the two closest references

**The Oregon Trail** is the nearest structural relative and the design history is
[well documented](https://www.format.com/magazine/features/design/you-have-died-of-dysentery-oregon-trail-design).
Three findings transfer almost verbatim:

- The 1985 redesign replaced abstract two-week cycles with **landmark segments**: "The journey will
  consist of distinct segments of varying length, each ending at a unique major landmark along the
  trail." That is `ZONE_ROTATION` replaced by a route table, exactly.
- **Naming makes deaths land.** Players name four travelling companions, and "If any of them gets
  sick or dies, then they are mentioned by name." Geeked Geese already does this — Gord, Wayne,
  Céline, Shania — and then never shows the names anywhere outside the flight HUD.
- **Failure was made shareable and funny** — the tombstone, persisted on disk for the next player.
  Failure as a joke you can pass on, not a punishment.

**Death Road to Canada** is the tonal relative: a comedy road trip with permadeath and a fixed
destination. [Its structure](https://tvtropes.org/pmwiki/pmwiki.php/VideoGame/DeathRoadToCanada) —
linear progression toward a border, party members who permanently die, morale-driven "Despair
Events," and a lighthearted register throughout — is proof that **permadeath and slapstick coexist
fine** when the art and writing keep the register light. Its meta layer ("Zombo Points") is the
optional part, not the load-bearing part.

**XCOM** explains *why* named party death works.
[Game Developer's analysis](https://www.gamedeveloper.com/design/why-do-we-get-so-attached-to-our-soldiers-in-xcom-)
credits time investment and scarcity above customisation — "There is a serious personal time
investment on each and every one of our team members" — plus emergent narrative: "every action we
take… writes another paragraph to our story." Attachment comes from *scarcity plus history*, not
from portraits.

Geeked Geese has scarcity (6 birds, never replaced) and history (`scars` field, already in
`flock_state.gd`, currently written by nothing). It has zero surfaces showing either.

## 1.7 Endings, completion rates, and whether an ending is even worth building

[Completion-rate data](https://www.twoaveragegamers.com/game-completion-rates/) across 19 Steam
titles puts the **median completion rate at about 36%** — "roughly two-thirds of players never
finish" — and it drops toward 25% for long prestige games. The inverse relationship between scope
and completion is the actionable part.

The counter-example is instructive: **Untitled Goose Game is about two hours long**
([~1.5–2.5h across IGN, GameSpot and Kotaku](https://www.svg.com/166946/how-long-does-it-take-to-beat-untitled-goose-game/)),
which is precisely why so many people saw its ending and why it became a shared cultural reference
rather than a thing people owned.

**Conclusion: a 45-minute run is the strongest possible argument for building an ending at all.** At
that length the ending is not a reward for the dedicated 25% — it is content nearly everyone
reaches. At fifteen hours, per the bible's original framing, it is a cutscene almost nobody sees.

## 1.8 Landing a sincere beat after hours of stupidity

The [GDC narrative review of Untitled Goose Game](https://media.gdcvault.com/gdc2020/GameNarrativeReview/MaryArroz-UntitledGooseGame-paper.pdf)
describes the exact manoeuvre the bible is asking for. The finale is a *retrospective*: the goose
steals the bell and retraces the whole village, so "As the player re-encounters villagers they have
previously harassed, they are simultaneously reliving the comedic moments and character interactions
within their Goose's generated history." Closure arrives "through implication rather than
exposition" — the pile of stolen bells in the lair, no dialogue anywhere.

On tonal whiplash, the [writing advice](https://writing.codidact.com/posts/33211) that transfers
best is four-fold: **give processing time** (a neutral beat between registers), **use dramatic irony**
rather than a hard cut, **blend the modes** so a scene is funny and sad simultaneously, and —
the best one — **distinguish joy from comedy**: joy after loss can be "coloured by the price paid"
and reads as earned, where a joke in the same slot reads as deflection.

**Concretely for the Florida ending:** don't cut from a parking lot to a monologue. The correct
shape is a retrospective, wordless, in the game's own vocabulary. Arrive on the golf course. The
sprinklers come on. The retired geese are already there and they are doing the same stupid things
you have been doing for 45 minutes — one is on a golf cart, one is in a water hazard. **The comedy
does not stop; the stakes do.** Your surviving flock walks in and joins them. The names of the geese
who didn't make it appear on nothing — they simply aren't there, and their slots in the V are empty
in the last flight. That is implication rather than exposition, and it costs a text file and a
static scene.

## 1.9 Educational layer

The [JMIR scoping review of serious games for youth substance-use prevention](https://games.jmir.org/2022/3/e39086)
(29 games, 2010–2022) supports what the project already does and adds one warning. Supported:
"vicarious learning" through observed consequences, "possible actions, and the consequences
associated with those actions," and enjoyment as a genuine predictor — enjoyment "predicted intention
to drink less." The warning: gamification cannot rescue tedium — one study found "a gamified version
could not sufficiently counteract the tiresome nature" of repetitive content and *reduced* motivation
relative to the non-gamified version.

Translation: **tolerance, comedown, mixing and the load-bearing sober friend are already the right
design.** The risk under every option below is turning the Almanac into a grind reward. The moment a
true fact about nicotine is something you *earn* rather than something you *find*, the educational
layer becomes homework and the review's warning applies.

---

# PART 2 — THE THREE OPTIONS

---

## OPTION A — THE FLYWAY

### One paragraph

The game becomes a single finite journey: eight named legs on a real flyway, from a stormwater
retention pond behind an Ontario strip mall to a golf course in Florida, in about 45 minutes. You
always arrive — there is no game over — but you arrive with whatever is left of your flock, and the
ending is written by that roster. Geese lost in the migration are gone; the last flight has empty
slots in the V. Credits roll, the Almanac tallies what you learned, and the sincere beat happens
once, wordlessly, on the 18th green. Replay is an Ascension-style ladder of escalating rule
modifiers, not unlocks — nothing is ever gated behind repetition.

### The shape of a run

```
LEG 1  The Retention Pond      tutorial, no clock pressure, bread is bad for you
LEG 2  Strip Mall Lot          ✅ built
LEG 3  Suburbia                ✅ built
LEG 4  The Prairie Silo        new, or Strip Mall at dawn with a new objective set
LEG 5  Cottage Country         ✅ built
LEG 6  Montreal Alley (winter) new, or Suburbia + snow + ice friction
LEG 7  The 401                 a MIGRATION variant, not a zone (see §A.5)
LEG 8  The Golf Course         a finale scene, not a sandbox
```

Each leg is a zone plus a flight. Legs are **named places, not numbers**. The route is visible: a
map screen on the results card with a pin that moves south, and a distance-remaining figure that
counts down to zero across the whole run rather than resetting to 2,000 km every flight.

### Win condition

Complete leg 8. That's it. Arrival *is* the win — "thematically inseparable" in the Games Precipice
sense. There is no score threshold to clear and no boss.

### Lose condition

**None, mechanically.** The soft-fail contract is untouched: a bad leg costs clock, a short flight
costs clock, and you keep flying. But the *ending is graded by the flock*, on two axes the player
has been feeding all game:

| axis | source | what it changes |
|---|---|---|
| survivors | `Flock.alive_birds().size()` | who is standing on the green; the size of the last V |
| the DD | `Flock.designated_driver()` | whether the bird you kept clean made it, and gets the last shot |

Six geese arriving is a different ending from one goose arriving, and the difference is entirely
composed of things you did in parking lots. Nobody has to write six endings — one scene, one roster
readout, one line that varies.

### What carries between runs

- **The Almanac** (already persists). "You learned 11 of 16 things" on the credits.
- **Ascension tier.** Finishing the route unlocks the next rung. Each rung is one rule:
  `+1 required primary` · `zone clock −15 s` · `tolerance no longer resets between legs` ·
  `the DD can be lost` · `flock starts at 5` · `substances spawn 30% less often` ·
  `no thermals on the flight`. Ten rungs is a text file. **Nothing is gated. Every substance, zone
  and joke is available on rung 0.**
- **Best run per rung.** Fastest, most chaos, most geese home.

### How the per-leg mission system fits

Untouched, and better served. Two things fall out for free:

1. `mission_defs` already has `from_leg` / `until_leg`. In a finite route those become **route
   authoring** rather than difficulty scaling — leg 6 is Montreal and gets Montreal objectives.
2. **The escalation curve already targets exactly this length.** `target_scale()` caps at 1.9× on
   leg 6; `required_primaries()` caps at leg 7; new objective kinds arrive on legs 3, 4 and 5.
   Past leg 7 the system has nothing left to say. The content curve in `DESIGN_MISSIONS.md` §4 is
   already an eight-leg curve — it was written for this option without knowing it.

### What has to be built

| item | size |
|---|---|
| `ROUTE` table replacing `ZONE_ROTATION` — leg → {script, name, region, km} | half a day |
| Win branch: `Flock.leg > ROUTE.size()` → `Phase.RESULTS` (the enum value already exists and is never set) | half a day |
| Arrival scene: the golf course, sprinklers, retired geese, your survivors | 2–4 days |
| Run summary + credits: route walked, geese home, geese lost by name, Almanac tally | 2 days |
| Route map on the results card, pin moving south | 1 day |
| Ascension ladder + selector on the main menu | 2 days |
| Flock roster screen (needed regardless — see Part 4) | 1–2 days |
| Legs 1 and 7 (tutorial pond; the 401 as a migration variant) | 3–4 days |
| Legs 4 and 6 as variants of built zones, or as new zones | 3 days as variants / 3+ weeks as zones |

**Rough total: 2–4 weeks if legs 4 and 6 are variants. Two to three months if they are new zones.**

### What has to change

- `main.gd:16–20` `ZONE_ROTATION` → `ROUTE`; `_zone_script_for_leg()` stops using modulo.
- `main.gd:302–315` `_on_migration_done()` gains a terminal branch.
- `Game.new_run()` becomes "start the flyway"; `R` restarts the journey, not the loop.
- Migration `TARGET_DISTANCE` becomes per-leg, from the route table, so total distance is a real
  number counting down.
- `Flock.rest()` needs to stop being unconditional healing on the last legs, or attrition never
  bites.

### What it does to the game's identity

It becomes **a comedy road movie**. That is a bigger, more marketable, more coherent identity than
"physics sandbox with legs." It also matches every piece of framing already written — the tagline,
the flyway, the 2,000 km, the title. Nothing in the bible has to be re-litigated. The trailer writes
itself: a pin moving south while a goose is on fire.

### What it does with the flock

**The flock becomes the story of the run, and the ending's entire content.** Six named geese leave
Ontario. Some don't arrive. The last flight has holes in the V where they were. This is the highest
emotional return available anywhere in this document for the least code, because the data already
exists (`birds[]`, `name`, `alive`, `scars`, `is_dd`) and is currently rendered nowhere.

It also finally makes the Designated Driver mechanic matter, which the README lists as unbuilt and
which the bible calls the flight's best decision.

### What it costs — honestly

- **Content is the whole bill.** Eight legs of three zones will read thin if the variants aren't
  genuinely different. A "Strip Mall at dawn" that is the same geometry with an orange light is a
  reskin, and players notice reskins in about nine seconds.
- **The ending is a cliff.** Once you've flown to Florida twice, the Ascension ladder is doing 100%
  of the retention work. If those rungs are boring, the game is over at 90 minutes. Slay the Spire's
  ladder works because its systems are deep; a physics comedy's ladder has to lean on *rule* changes
  that produce new jokes, not on numbers.
- **You give up the "one more run" hook.** A finite journey with a credits sequence is a thing people
  finish and put down. That is honest, and it is worse for playtime metrics.
- **Loss can be toothless.** With `Flock.rest()` healing everyone every leg and only wires and
  turbines killing birds, a competent player will arrive with 6 of 6 every time, and the graded
  ending grades nothing. Attrition needs to actually happen — that is a tuning risk, not a design
  risk, but it is the risk that decides whether the ending lands.
- **You must resist making leg 8 a level.** The moment the golf course has objectives, the sincere
  moment dies. It has to be the one place with no clock and no HUD.

### What it does with the educational layer

Best fit of the three. The route is a **real flyway**, so each leg's loading and results screen
carries one true migration fact placed exactly where the bible says facts belong — where the player
is already stopped. The credits become the Almanac tally: *"You found 11 of 16. You never touched
the toad."* And the finite length means the sincere beat, which is where the harm-reduction thesis
finally gets to speak plainly for ten seconds, is reached by most players rather than the top 25%.

---

## OPTION B — THE LONG WINTER

### One paragraph

Delete the destination. Legs continue forever with escalating pressure — the clock shortens,
flights lengthen, hazards thicken, and tolerance stops resetting — and geese die permanently and are
never replaced. When the last goose is gone the run ends: a score screen with distance flown, legs
survived, and the names of everyone you lost, against your personal best. The flock is the health
bar and every point of health has a name and a personality. This is the cheapest option in the
document by a factor of five, it is shippable in a week, and it permanently forecloses Florida, the
credits, and the sincere moment.

### The shape of a run

Identical to today's loop, with three dials turning:

| leg band | what changes |
|---|---|
| 1–4 | today's game. Learn the verbs. |
| 5–8 | tolerance stops clearing between legs. Flight target rises 8% a leg. |
| 9–12 | zone clock floor drops to 90 s. Hazard spawn interval tightens. `Flock.rest()` heals less. |
| 13+ | no thermals. Substance spawns thin out. Every flight is attrition. |

Runs will land somewhere between 20 and 90 minutes depending on skill — which is a wider spread than
the "one sitting" constraint really wants, and needs a stated cap (see costs).

### Win condition

None. There is a **personal best**, which is a goal, not a win.

### Lose condition

**Yes, and this is the whole argument.** The run ends when `Flock.alive_birds().is_empty()`.

**The case against the soft-fail precedent — made explicitly, as requested:**

1. **The precedent is about legs, not runs.** `DESIGN_MISSIONS.md` §6 says `evaluate_leg()` "cannot
   return 'you lost'" — a statement about a three-minute unit. Ending a run after 40 minutes is a
   different promise. Bycer's hierarchy would call this a rung-5 punishment ("everything"), which is
   only earned if runs vary enough to be worth repeating. In this game they do: 16 substances × a
   procedural flight is genuine variance.
2. **The lose condition already exists; it is just unhandled.** In `migration.gd:156–162`,
   `_spawn_flock()` with no alive birds calls `_finish()` immediately — distance 0, "LANDED SHORT",
   next zone at 120 s, forever. `Flock.new_flock()` is only ever called from `_ready()` and
   `Game.new_run()`, so the flock never replenishes. **A player who loses all six geese today enters
   an infinite unwinnable loop that the game never mentions.** That is a hard fail wearing a soft
   fail's clothes, and it is strictly worse than an honest one.
3. **Loss is what makes the flock matter.** Per the XCOM analysis, attachment comes from scarcity
   plus history. Scarcity without consequence is decoration.

### What carries between runs

The Almanac (already persists), personal bests, and — the one meta-progression worth having here —
**a memorial**. Every goose lost, across every run, by name, with the leg and the cause. That is the
Oregon Trail tombstone: failure made shareable and funny rather than punishing.

### How the per-leg mission system fits

It fits, but **it needs a real fix**, and this is the option's hidden cost. `par` grows 15% per leg
forever (`PAR_BASE * (1 + 0.15 * (leg-1))`) while `target_scale()` caps at 1.9× on leg 6 and the
clock never grows. At leg 12 par is 15,900 against a permanently capped achievable score. **Every
player's grades decay to F by leg 10 regardless of skill.** Under a finite route this is unnoticed
(the route ends before it bites). Under an endless run it is the primary balance problem and needs
either a par cap or a par that tracks the volume cap.

The system also runs out of *content* past leg 7 — no new objective kinds, no new requirements. An
endless mode needs a fourth escalation dial: rotating rule modifiers per leg ("this leg: no
honking," "this leg: one substance only"). That is cheap and funny, and it is real work.

### What has to be built

| item | size |
|---|---|
| Run-over branch on empty flock + score screen | 1 day |
| Escalation dials as a curve table | 1 day |
| Par fix (cap, or track the volume cap) | half a day |
| Personal best + memorial in `Prefs` | 1 day |
| Per-leg rule modifiers (10–15 of them) | 2 days |
| Flock roster screen (needed regardless) | 1–2 days |

**Rough total: 3–6 days.** This is genuinely a week of work.

### What it does to the game's identity

It becomes **an arcade cabinet**. High-score, clip-friendly, endlessly restartable, no narrative
obligation. That is a legitimate and good identity for a physics comedy — it is roughly what Goat
Simulator's score mode is — but it is not the identity this project's own bible describes, and it
retires "you have 2,000 km to fly before winter" from a premise to a joke.

### What it does with the flock

**The flock becomes the health bar,** and this is the most mechanically elegant idea in the
document. Six lives, each named, each one you chose how hard to poison. Every death is a decision
you made in a parking lot forty minutes ago, arriving late. Losing Céline hurts in a way losing a
heart icon cannot, and it costs nothing to build because the data is already there.

If you pick B, this is why.

### What it costs — honestly

- **You lose the ending, permanently.** Florida, the credits, the retired geese, the one sincere
  moment. §7.5 of the bible becomes unbuildable. This is not a deferral; an endless game has no slot
  for a sincere beat, because there is no "at the end."
- **Endless modes are forgettable.** They produce numbers, not stories. Chou's Ariely point applies
  directly: every run dismantles the flock's story and starts over, and after ten runs the player
  has ten identical score screens and no memory of any of them.
- **Personal-best is the only leaderboard you can actually have** without a backend, and the repo
  already proves a persisted number changes nothing — `best_chaos` has been in `Prefs` this whole
  time.
- **Run length becomes unbounded and unpredictable.** A skilled player's run could exceed 90 minutes,
  which breaks the one-sitting constraint. You will end up adding a soft cap, at which point you
  have quietly reinvented a finite route with worse framing.
- **The escalation has to be genuinely funny or it's just a slope.** Numbers going down is not
  comedy. The rule modifiers carry the whole entertainment load past leg 8.

### What it does with the educational layer

Surprisingly strong, and worth saying out loud: **"tolerance stops resetting" is the harm-reduction
thesis converted directly into the difficulty curve.** The longer you play and the more you dose,
the less anything does for you, and eventually you cannot get the effect you need to make the flight.
That is the true pharmacology, it is the escalation mechanic, and it never says a word. It is the
single most on-thesis mechanic available in this entire document.

The Almanac becomes the only thing that persists and grows, which makes it the de facto meta-game.
Fine — as long as entries stay *found*, never *earned*.

---

## OPTION C — THE POND

### One paragraph

Runs are attempts at the route, and they can genuinely fail. Between them you return to the
retention pond: the roster, the nest, the codex. Geese that survived a failed run **retire and stay
at the pond**; geese that died are gone. Retirees give you something small and permanent — a
memory, a hint, a starting bonus — so the arc completes across five to fifteen hours and several
runs, and Florida is the *game's* ending, reached once. This is §6 of the design bible, literally.
It is also the most work by a wide margin, and the meta-progression research is largely against it.

### The shape of a run

Pond hub → route attempt (5–8 legs, ~30–45 min) → the run ends in one of three states:

| outcome | what happens |
|---|---|
| **Arrived** | Florida. The ending. Once per save, then it becomes a victory lap. |
| **Grounded** | flock hit zero, or you fell too far behind the winter clock. Survivors retire to the pond. |
| **Wintered short** | you stopped somewhere real — Kentucky, Georgia. Better than grounded, worse than Florida. A partial ending with its own line. |

### Win condition

Reach the golf course once. The game is beaten. Everything after is replay.

### Lose condition

Yes — flock zero, or a **winter clock**: a global timer across the run that a slow route
overruns. Same argument as B, with the same soft-fail caveat, plus one more: in C, failure has a
*consumer* — the pond — so the punishment is converted into content rather than into nothing.

### What carries between runs

This is the option's whole design surface, and its whole risk.

**Safe (complexity-gating, per the HN defence):**
- The roster of retirees, with names and scars. Pure memorial.
- The codex, as today.
- Route knowledge: legs you've reached become selectable start points for *practice*, not for the
  real run.
- New route branches revealed by reaching them once — content *revealed*, not *gated behind grind*.

**Dangerous (grind-to-win, per chongli):**
- Nest upgrades that make the flock start healthier.
- Substances unlocked by usage counts.
- Anything that makes attempt #7 easier than attempt #1.

The second list is what the bible's "nest upgrades" implies and what the research says to avoid.
If you pick C, **the discipline is that meta-progression may add options and remove nothing, and may
never make the route easier.**

### How the per-leg mission system fits

Unchanged, plus one addition: **run-level objectives**. "Arrive with the DD alive." "Reach Montreal
with 5 geese." "Never triple-stack on the whole route." Those are a natural extension of the
existing schema (`late: true` already exists for whole-leg verdicts) and would give the pond
something to hand out that isn't power.

### What has to be built

Everything in Option A, plus:

| item | size |
|---|---|
| Pond hub scene: roster, codex, route map, launch | 1–2 weeks |
| Save format beyond `Prefs` (roster, retirees, run history, unlock state) | 3–4 days |
| Winter clock + fail branches + three ending variants | 1 week |
| Unlock economy, and balancing it across 5–15 hours | **open-ended** |
| Run-level objective layer | 3–4 days |

**Rough total: 2–4 months on top of Option A's content bill.** For one person, this is the option
that risks not shipping.

### What it does to the game's identity

It becomes **a roguelite with a hub**, which is the most commercially legible shape of the three and
also the most crowded shelf. It is the only option where the game has fifteen hours of intended
content, and the only one where the bible's own §6 is implemented as written.

### What it does with the flock

**The best version of the flock in this document, and it isn't close.** The pond fills up with
retired geese across runs. Gord, who made it to Georgia twice and never further. The DD you kept
clean for six legs. They stand around the pond doing nothing, permanently, and the population of
that pond is the record of everything you've done.

**That is the bible's "one sincere moment" — "the retired geese who stayed" — as a mechanic rather
than a cutscene.** If you read §7.5 of `GEEKED_GEESE_DESIGN.md` and felt something, this is the
option that builds it.

### What it costs — honestly

- **Scope.** Two to four months on top of A, for one person, before the game is finishable. The
  realistic failure mode is a half-built hub and no ending at all — strictly worse than today.
- **The grind trap is directly in the game's blast radius.** The 16 substances are the product. Every
  one of them locked at the start is a joke the player doesn't get to hear for two hours, and the
  first two hours are where the game is either funny or dead. The README's own gate — "if they're
  laughing inside 90 seconds, build the rest" — is incompatible with a substance unlock economy.
- **Time to the ending balloons back to ~10 hours**, which drops the fraction of players who see it
  back toward the 25% band the completion data describes. The sincere moment gets built for a
  quarter of the audience.
- **It needs a real save system,** and `Prefs` (a debounced `ConfigFile`) is not one. Save corruption
  in a game where the pond is the player's memorial is a uniquely bad bug.
- **Balancing across runs is a playtest problem, and there is one developer.** A/B'ing an unlock
  curve requires players.

### What it does with the educational layer

Highest ceiling and the highest risk. The pond hub is the natural home for the Bird Brain Almanac as
a real reading room — the bible's "hub… codex" — and a place where facts sit where the player is
already stopped.

The risk is exactly the failure the JMIR review names: if codex entries become *rewards* on an
unlock curve, the educational layer becomes the grind, and gamified tedium reduces motivation below
the ungamified baseline. **Rule if you pick C: the Almanac unlocks by encounter only, never by
currency.** Which is precisely what `unlocks.gd` already does, so the discipline is "don't change
it."

---

# PART 3 — RECOMMENDATION

## Build Option A — The Flyway.

With two specific borrowings:

1. **Steal B's flock-as-stakes.** Do not let `Flock.rest()` heal everyone unconditionally on the
   back half of the route. Geese should be genuinely, visibly at risk from leg 5 on. The graded
   arrival is worthless if everyone always arrives.
2. **Steal C's memorial, but only the free half.** Persist the names of geese lost across all runs.
   That is one array in `Prefs` and it is the entire emotional payload of C's pond for none of C's
   cost. Show it on the credits.

## Why

**1. It is the only option where the game the bible describes can exist.** Florida, the credits, the
retired geese, the one sincere moment — B deletes them and C postpones them past the point where
most players will reach them. A ships them in a form that nearly everyone sees.

**2. The mission system's own escalation curve is already an eight-leg curve.** `target_scale()`
caps at leg 6. `required_primaries()` caps at leg 7. New objective kinds land on legs 3, 4 and 5.
Past leg 7 the system has nothing further to say and `par` starts outrunning the achievable score.
`DESIGN_MISSIONS.md` §4 was written for a finite run of roughly this length. Option A is the only
one that doesn't require re-tuning it.

**3. The completion-rate data inverts the bible's own assumption.** §7.5 says "earn it with fifteen
hours of stupidity first." At fifteen hours, roughly a quarter of players get there. At 45 minutes,
most do. **A shorter route makes the sincere moment hit *more* people, not fewer** — and the
Untitled Goose Game comparison is direct: a two-hour comedy game whose ending became a shared
reference precisely because everyone reached it.

**4. Meta-progression is a worse deal than it looks, and Ascension is a better one.** The research
on meta-progression is mostly hostile — grind-to-win, the shrinking mountain, content gated behind
repetition — and for this game specifically, gating substances would make the opening hours *less
funny*, which is the one thing the project cannot survive. An Ascension ladder delivers comparable
replay for a text file.

**5. It is achievable.** Two to four weeks to a finishable game, if legs 4 and 6 are variants rather
than new zones. B is cheaper but forecloses the game's identity. C is the right shape and the wrong
size for one person.

**6. It leaves C's door open.** A route table, a run-summary payload, and a persisted memorial are
exactly the data a pond hub would read. If the game is good and there's a second year, C is an
addition, not a rewrite. That asymmetry matters: **A → C is possible; B → A is a redesign.**

## The honest case against my own recommendation

If the goal is *ship something and find out whether it's funny*, **B is right and I am wrong.** It's
one week, it makes the flock matter immediately, it makes the game clip-friendly, and the README's
own gate ("hand it to someone who's never seen it") doesn't need a route to Florida to be answered.
If the controller doesn't feel good yet, build B, run the gate, and revisit this document.

**The tiebreaker question, and the developer should answer it before reading further:** *Has anyone
who is not you played this and laughed inside 90 seconds?* If yes — build A. If no — build B this
week, run the test, and come back.

## What I'd do first, in order

**Day 1 — make it finishable.** Replace `ZONE_ROTATION` in `main.gd:16` with a `ROUTE` array of
eight leg descriptors `{script, name, region, km}` — using the three built zones in an 8-slot order
with placeholder repeats. Add the terminal branch in `_on_migration_done()`: when
`Flock.leg > ROUTE.size()`, set `Game.Phase.RESULTS` (the enum value exists at `game.gd:14` and is
never set; `music.gd:832` already has a branch for it). Show a placeholder "YOU MADE IT" card.
**After this the game can be won, before any new content exists.** Everything else is quality.

**Day 2–3 — the flock roster screen.** Six named birds, condition, scars, DD toggle. This
simultaneously delivers the roster surface, ships the Designated Driver assignment the README lists
as missing, and gives the ending something to be about. It is the highest emotional return per hour
in the whole plan and is required by all three options.

**Week 1 — the arrival.** Build leg 8 before legs 1, 4, 6, or 7. It's the thing you're least sure
you can land, it's the thing the whole option rests on, and it's the cheapest possible test of
whether the sincere beat works: a golf course, sprinklers, retired geese doing stupid things, your
survivors walking in, no clock, no HUD, no text. If that scene doesn't land in a static mockup, the
option is wrong and you've spent a week finding out instead of two months.

**Week 2 — attrition tuning.** Make geese actually die. Then check that a competent player arrives
with 4 of 6, not 6 of 6.

**Week 3–4 — route content.** Legs 1 and 7 (cheap: a tutorial pond and a migration variant), then
legs 4 and 6 as variants with genuinely different objective sets, weather and hazards.

**Later — the Ascension ladder.** Only after someone has flown the route twice and asked what's next.

---

# PART 4 — TRUE REGARDLESS

Nine things every option needs. All can start today, before the decision is made. Several are
outright bugs.

### 1. Zero geese is currently a soft-lock. Fix it.

`migration.gd:156` `_spawn_flock()` bails to `_finish()` when nothing is alive → distance 0 →
"LANDED SHORT" → 120-second zone → repeat forever. `Flock.new_flock()` is called only from
`Flock._ready()` and `Game.new_run()`, so the flock never returns. **The game already has a lose
condition and handles it by hanging.** Every option needs a branch here — a run-over screen, a
rescue, or a replenishment. This is the single most important item in this document that isn't a
decision.

### 2. Par outruns the achievable score, unbounded.

`par = PAR_BASE * (1 + 0.15 * (leg - 1))` grows forever; `target_scale()` caps at 1.9× on leg 6 and
the clock never grows. Grades therefore decay toward F with leg number regardless of skill. Under a
finite 8-leg route this is nearly invisible; under any longer structure it is the dominant balance
bug. Cap par, or tie it to `target_scale()`.

### 3. The flock appears in no UI outside the migration.

`grep Flock. scripts/ui/` returns nothing. Six named birds, permanent death, a `scars` field that
nothing ever writes, and zero surfaces. The XCOM research says attachment is scarcity plus history;
the game has the scarcity and renders none of the history. A roster screen is 1–2 days and is
required by all three options.

### 4. The Designated Driver cannot be assigned.

`migration.gd` honours `is_dd`, `Flock.set_dd()` exists, and nothing calls it. The bible calls this
the flight's best decision and the README lists it as unbuilt. It rides free on the roster screen.

### 5. `scars` is dead. Wake it up.

The field exists in `flock_state.gd:41` and is written by nothing. Every option benefits from geese
that visibly accumulate history — a limp, a stain, a missing feather, a number on a roster row. The
bible already asks for it (§12, "The goose remembers").

### 6. Legs need names, not numbers.

`"LEG %d — STRIP MALL LOT"` is the whole of the game's sense of place. Even in an endless run, "leg 7
— somewhere past Buffalo" is worth more than "leg 7." A `region` string on whatever structure replaces
`ZONE_ROTATION` costs nothing and pays in every screen.

### 7. There is no end-of-run screen of any kind.

Per-leg results are excellent (`results_screen.gd`, 1,300 lines). Whole-run results do not exist.
Every option ends a run somehow and needs one: legs flown, total distance, chaos, geese home, geese
lost by name, Almanac tally. Build it against the `leg_decided` payload shape, which already has
everything except the roster.

### 8. `Phase.RESULTS` exists and is never set.

`game.gd:14` declares it; nothing in the codebase transitions to it; `music.gd:832` already has a
branch that goes quiet for it. The hook for "the run is over" is already carved. Use it.

### 9. The Almanac is already the meta-progression, and should stay exactly as it is.

`unlocks.gd` unlocks by encounter and persists through `Prefs`. It is the one persistent system in
the game and it gates nothing — you unlock the page by *eating the thing*, which is the correct
educational design and the exact opposite of the grind failure the JMIR review warns about. Under
every option: **surface it harder — put the tally on the run summary — and never make it a currency.**

Two smaller ones worth folding in while you're there:

- **Clock clamps disagree.** `mission.gd:1151` clamps `next_seconds` to `[110, 210]`;
  `main.gd:315` clamps the value it actually uses to `[100, 220]`. The results card can therefore
  promise a number the game doesn't hand out. Same bug family as the one already fixed in the
  `zone_time_modifier` comment.
- **The flight has no clock, only a distance.** It ends on arrival or exhaustion. Under every option
  the flight wants a decision point — "push on or put down here" — rather than a pure arrival check.
  That is one input and one branch, and it is where a lose condition, a partial ending, or a
  route fork would all attach.

---

## Appendix — measurements taken from the repo

| thing | value | source |
|---|---|---|
| zone clock, base | 180 s | `game.gd:98`, `main.gd:312` |
| zone clock, floor / ceiling | 100 s / 220 s (`main`), 110 / 210 (`mission`) | `main.gd:315`, `mission.gd:1151` |
| flight duration | 85 s at full integrity → ~125 s at 0.4 | `migration.gd:20,27,306–307` |
| **one leg, wall clock** | **≈ 5 min** | 180 s + ~100 s + results + briefing |
| zones built | 3 (strip mall, suburbia, cottage) | `main.gd:16–20` |
| route in the bible | 8 stops | `GEEKED_GEESE_DESIGN.md` §6 |
| flock size | 6, never replenished | `game.gd:165`, `flock_state.gd:30` |
| leg advances | only on `made_it` | `main.gd:303–305` |
| objective volume scaling | caps at 1.9× on leg 6 | `mission.gd` `target_scale()` |
| required primaries | caps at leg 7 | `mission.gd` `required_primaries()` |
| par growth | +15% per leg, **uncapped** | `mission.gd:1124` |
| cross-run persistence | Almanac unlocks, `best_chaos`, settings | `prefs.gd:18–35`, `unlocks.gd` |
| unused hook | `Phase.RESULTS` | `game.gd:14`, `music.gd:832` |

---

## Sources

- [The Hierarchy of Fail States in Game Design — Game Wisdom](https://game-wisdom.com/critical/hierarchy-of-fail-states-game-design)
- [The Balance of Fail States in Game Design — Game Developer](https://www.gamedeveloper.com/design/the-balance-of-fail-states-in-game-design)
- [Late Game Structures – End Conditions — Games Precipice](https://www.gamesprecipice.com/endings/)
- [Are roguelikes bad? — Zeno Rogue](https://zenorogue.medium.com/are-roguelikes-bad-de3a9856a3e5)
- [Meta-progression debate — Hacker News](https://news.ycombinator.com/item?id=43658059)
- [More games should handle difficulty like Slay the Spire — Frostilyte](https://frostilyte.ca/2020/04/16/more-games-should-handle-difficulty-like-slay-the-spire/)
- [The Run — Miguel Sicart, Playing Software](https://playingsoftware.substack.com/p/the-run)
- [Does Vampire Survivors Respect Your Limited Play Time? — Delayed Respawnse](https://delayedrespawnse.com/blog/does-vampire-survivors-respect-your-limited-play-time/)
- [Leaderboard Design: Why Most Fail — Yu-kai Chou](https://yukaichou.com/gamification-analysis/leaderboard-design-definitive-guide-octalysis/)
- [You Have Died of Dysentery: Oregon Trail's Design History — Format](https://www.format.com/magazine/features/design/you-have-died-of-dysentery-oregon-trail-design)
- [Death Road to Canada — TV Tropes](https://tvtropes.org/pmwiki/pmwiki.php/VideoGame/DeathRoadToCanada)
- [Why do we get so attached to our soldiers in XCOM? — Game Developer](https://www.gamedeveloper.com/design/why-do-we-get-so-attached-to-our-soldiers-in-xcom-)
- [What Percentage of Players Finish Games? — Two Average Gamers](https://www.twoaveragegamers.com/game-completion-rates/)
- [How Long Does It Take To Beat Untitled Goose Game? — SVG](https://www.svg.com/166946/how-long-does-it-take-to-beat-untitled-goose-game/)
- [Untitled Goose Game narrative review — GDC Vault](https://media.gdcvault.com/gdc2020/GameNarrativeReview/MaryArroz-UntitledGooseGame-paper.pdf)
- [Preventing tonal whiplash between comedy and tragedy — Codidact Writing](https://writing.codidact.com/posts/33211)
- [Serious Games for Alcohol and Drug Prevention in Youth: Scoping Review — JMIR Serious Games](https://games.jmir.org/2022/3/e39086)
- [Game Design Breakdown: Katamari Damacy — Alexia Mandeville](https://alexiamandeville.medium.com/game-design-breakdown-katamari-damacy-e3f927f9a392)
