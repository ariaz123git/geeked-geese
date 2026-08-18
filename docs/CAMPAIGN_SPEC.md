# GEEKED GEESE — CAMPAIGN SPECIFICATION

### THE FLYWAY: eight legs, one sitting, and whoever's left

*Build-ready. Route data lives in `ROUTE_DATA.md`. Nothing in here is a
proposal — the decisions are made. Where I've made a judgement call I say so and
say why, once, and then move on.*

---

## 0. The one page

**The game becomes a single finite journey.** Eight named legs from a stormwater
retention pond in Mississauga to a golf course in north Florida. Roughly 45
minutes. You always arrive. The ending's content is **which geese arrived with
you**, and the flock no longer heals to full between legs, so that roster is
written by forty-five minutes of decisions you made in parking lots.

| | |
|---|---|
| **Structure** | 8 legs · 7 zones · 7 flights · 1 finale. ~44 min. |
| **Win** | Complete leg 8. Arrival *is* the win. No score threshold, no boss. |
| **Lose** | None at the run level. The worst outcome is arriving alone, and you still arrive. |
| **Stakes** | 6 named geese. `rest()` heals less as the route goes on. Geese leave the flock permanently. |
| **Floor** | The player's own bird can never leave the flock. Arrival is guaranteed by construction. |
| **Ending** | The 18th green at first light. Playable. No cutscene, no text, one honk. Playable credits. |
| **Replay** | A ten-rung Ascension ladder of rule changes. Nothing is ever gated. |
| **New zone geometry needed** | **one** (leg 6) plus the finale. Everything else is variants of the three built zones. |
| **Effort** | ~5–7 weeks for one developer with AI assistance. Cut list in §8.6. |

**The three built zones land at legs 2, 3 and 4.** They are the middle of the
run, unchanged in shape. Legs 1, 5 and 7 are variants built from strip-mall and
cottage geometry. Leg 6 is the one new zone. Leg 8 is a bespoke scene that
forks `flock_pen.gd`.

**The single most important structural decision in this document** is that the
climax is **flight 7, not leg 8**. Leg 8 is falling action. The pacing research
is explicit that a maximum-intensity finale eats its own climax; the sincere
moment cannot happen in a room that is still shouting.

---

# PART 1 — RESEARCH

`WIN_CONDITIONS.md` covered fail-state hierarchies, end-condition taxonomy,
meta-progression, run length, leaderboards, journey games with party attrition,
completion rates, tonal whiplash and serious-games pedagogy. This part does not
repeat any of that. Six new areas, and I flag where each one actually changed
the design rather than confirming it.

## 1.1 Pacing across a fixed-length run: saw-tooth, not staircase

The strongest and most directly actionable line in the whole research pass comes
from a level-design difficulty piece:

> **"Saw-tooth beats staircase. Instead of ratcheting difficulty up in a
> straight line, strong games introduce a new mechanic in a low-stakes context,
> escalate it, test it in a peak challenge, then drop back down as the next
> mechanic enters."**
> — [Stepico, *Video Game Level Design and Difficulty*](https://stepico.com/blog/video-game-level-design-and-difficulty-how-to-challenge-players-without-losing-them/)

The same source pairs every peak with a recovery — *"Nearly every intense
sequence is followed by a slower stretch that lets players decompress and absorb
what they've learned"* — and supplies a lever this project needs:
*"You can make challenges harder if you make failure cheaper."* That is the
permission slip for making the back-half flights genuinely dangerous while
keeping the soft-fail contract: the punishment stays cheap, so the pressure can
rise.

The [Level Design Book's pacing chapter](https://book.leveldesignbook.com/process/preproduction/pacing)
supplies the physiological reason and the one rule that reshaped this document:

> *"Players adjust to prolonged periods of high intensity. Any intense boss
> fight will feel like a slog after 10+ minutes."*
> *"To keep it fresh, use occasional downtime as a contrast and palette
> cleanser, otherwise the player will simply go numb."*
> **"Avoid maximum intensity final bosses / encounters."**

That last one is the load-bearing finding. Classical structure puts *falling
action* after the climax so the final beat reads as an inevitable result rather
than the hardest test. It also recommends charting pacing on an explicit
**intensity graph** — beats against time on a 0–5 or 0–100% scale — which is
what Part 3 is.

Mike Lopez's [*Harnessed Pacing & Intensity*](https://www.gamedeveloper.com/design/gameplay-fundamentals-revisited-harnessed-pacing-intensity)
adds the shape of the ramp: peaks should grow, and the *frequency* between peaks
should tighten — *"order the high intensity events so they are growing, and
either at the same rate or so they speed up in frequency"* — and insists the
value is in the contrast, not the height: *"It is in fact the contrast between
the two which makes the action super riveting."*

Pete Ellis's [gameplay-beats method](https://www.worldofleveldesign.com/categories/wold-members-tutorials/peteellis/level-design-pacing-gameplay-beats-part2.php)
states the rule this project keeps forgetting: **"the troughs (or lulls) are as
important as the peaks (or spikes)"** and *"repetition equals boredom, so it is
the different experiences and contrasts in intensity that will create a
satisfying and compelling experience."*

Finally, the [flow-channel model](https://www.gamedeveloper.com/design/game-design-theory-applied-the-flow-channel)
gives the specific rule for *where* a trough goes: difficulty should drop
**immediately after a new mechanic is introduced** — *"when a puzzle introduces
a new mechanic, the next one is slightly easier, just to make the player 'feel
the power' that the new mastered game mechanic has given to him"* — and the
pattern should nest fractally, waves inside worlds inside the campaign.

**What this changed.** I arrived assuming an escalating ramp with a dip
somewhere in the middle. Three things moved:

1. The climax moved off leg 8 entirely and onto flight 7. Leg 8 is now
   explicitly denouement, and the spec forbids putting a clock or an objective
   on it.
2. The mid-run trough became a **deep** trough with a full mechanical heal
   (leg 5, The Stopover) rather than a slightly quieter zone. A palette cleanser
   that is still 60% as loud is not a palette cleanser.
3. A **second, shallower trough** was added at leg 7, immediately before the
   peak — see §1.2.

## 1.2 Where the rest beat goes, structurally

Slay the Spire's map generation has a rule worth stealing verbatim: a Rest Site
is **"guaranteed immediately before the Boss, regardless of what path you
chose"** ([Slay the Spire wiki](https://slay-the-spire.fandom.com/wiki/Rest_Site)).
Rest before the peak is not optional and is not left to chance.

Geeked Geese's route has one boss-shaped thing — flight 7, The Interstate — and
therefore needs a guaranteed rest immediately before it. That is leg 7's zone
(the truck stop), which is deliberately the quietest sandbox in the game, and
the first 20 seconds of flight 7 itself, which contain nothing at all.

**What this changed.** I originally ramped 5 → 6 → 7 → 8 monotonically after the
mid-run trough. Now there are two troughs: a deep one at leg 5 and a shallow one
at leg 7. The curve has two peaks (legs 4 and 6) and one summit (flight 7).

## 1.3 Introducing mechanics across a campaign — and why this game must reject the convention

The "one new idea per level" convention is Nintendo's four-step stage design,
articulated by *Super Mario 3D World* director Koichi Hayashida as
*kishōtenketsu*: **introduce** the mechanic in a safe environment where "you can
experiment with them without the risk of losing a life," **develop** it in a
dangerous context, **twist** it — *"a unique twist which makes you look at it
from a different perspective"* — then **conclude** with a mastery test
([Nintendo Life](https://www.nintendolife.com/news/2015/03/video_nintendos_four_step_stage_design_is_why_you_love_super_mario_games_so_much)).

The supporting pedagogy is consistent. Josh Bycer's
[hierarchy of learning](https://game-wisdom.com/critical/teaching-game-mechanics)
warns against stacking lessons — *"don't show me how to turn on window wipers in
a driving game at the same time I'm trying to learn how to start the car"* — and
against teaching in isolation from play: *"If you show the player how to do
something in a scenario separate from the main game, then how will they learn
when they will need that information when playing the game for real?"* A survey
of mechanic introduction adds the four practical rules — introduce in isolation,
show don't tell, teach through repetition in varied contexts, tie teaching to
theme — plus the warning that *"over-explaining every new thing on screen with
flashing neon lights and blocks of text can also make players feel patronized"*
([Pause Button](https://pausebutton.substack.com/p/how-video-games-introduce-their-mechanics)).

**The critique, and why it lands hard here.** The four-step structure's failure
mode is predictability: a campaign where every level is a new noun becomes a
tour of nouns, and by level 20 the player is being introduced to things rather
than playing with things. Geeked Geese has a specific and unusual problem — **it
has sixteen mechanics on leg 2.** The substance shelf opens fully at the strip
mall and never closes. There is no honest way to dole out control mutations one
per leg, and gating them would be actively destructive: `WIN_CONDITIONS.md` §3
already established that gating substances would make the opening hours *less
funny*, which is the one thing this project cannot survive.

**The rule this spec adopts, therefore:**

> **The campaign never adds a verb after leg 2. Every leg after leg 2 adds a
> CONTEXT that recombines verbs the player already has.**

Leg 3 doesn't add a mechanic, it adds *height*. Leg 4 adds *darkness and water*.
Leg 5 adds *a reason not to use the verbs*. Leg 6 adds *cover and open ground*.
Leg 7 adds *scarcity*. That satisfies "introduce in isolation" (each context is
introduced clean), satisfies "teach through repetition in varied contexts"
(sixteen mutations re-asked seven times), and dodges the convention's failure
mode entirely — because the new idea per leg is a question, not a noun.

**What this changed.** It killed a draft in which leg 5 introduced a new
traversal verb and leg 6 introduced a new substance family. Both are now
contexts. It also produced the "one new idea" column in Part 2, which is
explicitly a column of *questions the leg asks*, not features it adds.

## 1.4 Level ordering in a linear campaign — journey vs. list

The ingredients that make a linear sequence read as travel rather than as a
playlist, from [SuperJump's *When a Game Feels Like a Journey*](https://www.superjumpmagazine.com/when-a-game-feels-like-a-journey/):
*"a sense of purpose, direction and growth that propels the player forward"*;
alternating safe hubs with dangerous stretches so the rhythm mirrors real
travel; **"a clear visual distinction between each location you visit, creating
thematic novelty"**; NPCs with *"something relevant to say about their place,
your journey, and the general state of affairs"*; and self-contained locations
rather than a map you're sent back across.

Half-Life 2 supplies the counter-technique — the **stream pool**, described in
[Intermittent Mechanism's study](https://intermittentmechanism.blog/2018/04/28/lets-study-half-life-2-pt-5/)
as *"geographic nooks in otherwise linear games, where players are encouraged to
wander from the otherwise-apparent path forward."* The point: *"these little
pauses don't make the coastline of Half-Life 2 any less linear,"* but they hand
the player control of the pacing. A linear route with pockets of dawdling reads
as a journey; a linear route without them reads as a corridor.

**What this changed — and this is the biggest single revision in the document.**
The design bible's route does not survive contact with a real flyway. The
prairie silo is *west*. Montreal is *northeast*. The 401 is in Ontario and sits
at leg 7. A road movie whose map pin wanders in three directions is a list with
place names on it.

Rather than silently fixing the geography, I made the error the joke. **Leg 3's
flight goes 190 km north, to cottage country, at 2 a.m., and the
kilometres-to-Florida counter goes UP.** It is the funniest thing a map screen
can do, it is the single best argument for having a map at all, and it is backed
by a genuinely surprising true fact (the moult migration — Canada geese really
do fly north in summer, sometimes over a thousand kilometres). The prairie silo
is relocated south and becomes leg 6. Montreal is cut with reasons (§2.10). The
401 survives as a callback: it is the *first* flight, crossed low and safe, and
its rhyme is I-95 at leg 7 in the rain with half the flock gone.

## 1.5 Endings, and the playable epilogue

The decisive quote is Josef Fares on *Brothers: A Tale of Two Sons*:

> **"If the ending of Brothers happened in a cutscene, people wouldn't react at
> all."**
> — [Game Informer, *The Art Of Endings*](https://gameinformer.com/b/features/archive/2014/04/09/the-art-of-endings-tales-of-ending-a-game.aspx)

The same piece records that *The Last of Us*' hospital sequence was made
playable on a designer's argument that it *"should be playable,"* and Neil
Druckmann's reason: playing as Ellie means players *"enter that scene with the
viewpoint of Ellie."* Ken Levine's preference — *"My favorite endings are the
endings that leave you piecing everything together"* — is the same instinct
`WIN_CONDITIONS.md` reached via the Untitled Goose Game GDC paper: closure
through implication.

On the wind-down itself, the RPG-campaign literature is blunt that a climax
without a denouement doesn't land: *"games that have had a good denouement felt
the most satisfying,"* because *"We want to know if X led to Y and if all of our
effort paid off"* ([Gnome Stew](https://gnomestew.com/the-end-of-your-game-needs-denouement/)).
The questions a denouement must answer are exactly the ones this game has
mechanised: what happened to the characters, what changed, who is still here.

And on credits specifically — this is where a genuinely good idea came from that
I did not have going in. [Game Informer's survey of innovative credits](https://gameinformer.com/b/features/archive/2016/11/10/where-credit-is-due-video-game-credits-that-innovate.aspx)
records *Katamari Damacy* letting you *"roll up all the countries on Earth into
a ball"* during the credits — credits as a bonus stage using the core verb — and
*Rayman Origins* / *New Super Mario Bros. Wii* treating *"the thousands of names
like destructible platforms, free to be jumped on or butt-stomped."*

**What this changed.** Two things, and both are load-bearing for Part 5:

1. Every version of leg 8 that contained a cutscene is dead. The arrival, the
   flock settling, the honk and the credits are all played.
2. **The credits are physical objects on the fairway that you can honk over,
   land on and knock down.** That is the cheapest possible way to satisfy
   `WIN_CONDITIONS.md`'s instruction that *the comedy continues while the stakes
   stop* — and the design bible already names Katamari as one of its two
   reference points, so it is on-brand to the point of being a citation.

## 1.6 Replayability in a game with a fixed ending

The honest baseline: a finite game with credits is a thing people finish and put
down. What buys a second run is not content, it is a **different relationship to
the same content**. Kirk Hamilton's account of second playthroughs is the
clearest statement of the mechanism:

> **"What was at first a brute battle for survival becomes more of a
> performance."**
> — [Kotaku, *Video Games Are Better The Second Time You Play Them*](https://kotaku.com/video-games-are-better-the-second-time-you-play-them-1786856653)

He notes the drive to see what happens next is gone, so *"I'm more likely to
take my time,"* and that games explicitly built for mastery (Hitman, Souls)
*"strongly encourage me to play and replay levels."*

The mechanism list ([TV Tropes, *Replay Value*](https://tvtropes.org/pmwiki/pmwiki.php/Main/ReplayValue))
is the usual one — branches, New Game+, bonus content, randomisation, harder
difficulty levels, user content — and the article's own warning is that padding
these produces "Fake Longevity."

The best-in-class model is *Hades*' **Pact of Punishment**, which is
player-authored difficulty rather than a difficulty menu: fifteen distinct
conditions with 1–5 ranks each, each worth Heat, and *"For every one Heat point
you add to the total, you'll get the chance to re-earn"* the top-tier rewards
([RPG Site](https://www.rpgsite.net/feature/10287-hades-pact-of-punishment-heat-modifiers-and-how-to-maximize-your-rewards)).
The player composes the run they want to attempt.

**What this changed.** `WIN_CONDITIONS.md` recommended a Slay the Spire
Ascension ladder — a fixed, cumulative sequence of rungs. The Hades model is
strictly better for *this* game and costs the same, because a physics comedy's
replay value lives in **which jokes a rule change produces**, not in incremental
difficulty. A player who wants "no thermals + thin substance spawns" and a
player who wants "start with four geese + no rest between legs" are asking for
two different films. Part 7 therefore specifies a **cumulative ladder for
unlocking and a free-composition mode for playing** — the ladder teaches the
rules one at a time; once a rung is unlocked its rule can be toggled
independently. Ten rules, one text file, one screen.

## 1.7 Difficulty and accessibility options in campaign games

The Game Accessibility Guidelines' intermediate-level rule is specific and
applies directly:

> **"Allowing a choice during gameplay or upon death means being able choose to
> play at an appropriate level without having to lose your progress so far."**
> — [Game Accessibility Guidelines](https://gameaccessibilityguidelines.com/allow-difficulty-level-to-be-altered-during-gameplay-either-through-settings-or-adaptive-difficulty/)

In a 45-minute one-sitting run this is not a nicety. A player who discovers on
flight 4 that the flight is too hard has 25 minutes of run behind them; making
them restart to change a setting is the entire failure the guideline describes.

The framing lesson is Celeste's. The original Assist Mode screen said the
game's difficulty was *"essential to the experience,"* which disability advocate
Clint Lexa criticised as othering. The revised wording:

> *"Celeste is intended to be a challenging and rewarding experience. If the
> default game proves inaccessible to you, we hope that you can still find that
> experience with Assist Mode."*

Matt Thorson's stated goal was *"to accept that every player is different, and
that people come into the game at many different skill levels,"* and the team
also **removed the feature that branded save files using Assist Mode**
([Vice](https://www.vice.com/en/article/celeste-assist-mode-change-and-accessibility/)).

**What this changed.** It changed the wording of the toggle and it removed a
draft feature. I had sketched an "arrived on Easy Flying" note on the credits.
That is exactly the save-file branding Celeste removed, and it is now
prohibited: **the credits are identical regardless of accessibility settings.**
See §8.5 for the exact copy.

---

# PART 2 — THE ROUTE

Full data — km, clocks, flight parameters, `rest()` values, objective overrides,
Almanac facts — is in **`ROUTE_DATA.md`**, which is the file to implement from.
This part is the design intent per leg and the reasoning for each placement.

## 2.0 The shape

```
LEG 1  THE RETENTION POND     Mississauga, ON        strip_mall variant "pond"      NEW (cheap)
       ↓ flight 1  THE 401                12 km · 45 s · tutorial
LEG 2  THE STRIP MALL LOT     Mississauga, ON        zone_strip_mall.gd             ✅ BUILT
       ↓ flight 2                         38 km · 70 s
LEG 3  SUBURBIA               Oakville, ON           zone_suburbia.gd               ✅ BUILT
       ↓ flight 3  THE WRONG WAY         190 km · 80 s · the pin goes NORTH
LEG 4  COTTAGE COUNTRY        Muskoka, ON            zone_cottage.gd                ✅ BUILT
       ↓ flight 4  THE LONG HAUL         640 km · 110 s · the bill arrives
LEG 5  THE STOPOVER           Montezuma NWR, NY      cottage variant "refuge"       NEW (cheap)  ← REST BEAT
       ↓ flight 5                        690 km · 75 s
LEG 6  THE CUT CORN           Sampson County, NC     zone_corn.gd                   NEW (the only new geometry)
       ↓ flight 6                        390 km · 95 s
LEG 7  THE TRUCK STOP         somewhere off I-95, GA strip_mall variant "truckstop" NEW (cheap)
       ↓ flight 7  THE INTERSTATE        310 km · 130 s · THE PEAK
LEG 8  THE 18TH GREEN         north Florida          zone_green.gd                  NEW (bespoke finale)
```

Seven zones, seven flights, one finale. **2,270 km flown. 1,850 km in a straight
line.** The difference is Muskoka.

## 2.1 LEG 1 — THE RETENTION POND

| | |
|---|---|
| **Setting** | The stormwater pond behind the plaza. Mown grass to the waterline, a chain-link fence, a bench, one shopping cart already in the water. |
| **Time** | Overcast morning, flat grey. The dullest light in the game, on purpose — leg 2 at midday should feel like the lid coming off. |
| **Built from** | `zone_strip_mall.gd` with `variant = &"pond"`. The lot is behind a fence you can fly over but the objectives never send you there. The pond, `_pond()`, is already in that file. |
| **Zone clock** | **240 s.** The only leg longer than 180. |
| **Mission id** | `&"pond"` · required primaries overridden to **2 of 4** · `par_scale 0.55` |
| **Substances** | **Three.** Fermented Berries, Double-Double, Grass. Plus **bread**. |
| **Flight** | THE 401 — 45 s, 12 km, one span of wires and nothing else, thermals frequent. **`lethal: false`** — a wire strike here costs stamina and formation, never a bird. |
| **Intensity** | **2** |

**What's mechanically new:** everything, but delivered in the order Bycer's
hierarchy demands. Move → honk → the dose arc → the flock pen → share. The
existing `briefing.show_once(&"zone_first_run")` and `dose_hint()` cards fire
here, and the flight card fires on flight 1.

**What the objectives push toward:** touching the three verbs. Four primaries,
need two, all of them satisfiable by messing about.

**BREAD — build it, and build it here.** The design bible's §12 "Bread Debuff"
is the perfect first-90-seconds lesson and it has never had a better home. It is
a `.tres` like everything else.

> **Bread.** Mimics: nothing. The bit: a bag of it, and a sign asking you not
> to. **Control mutation: you are full.** For 20 seconds after eating bread you
> physically cannot take a substance — the dose arc refuses to charge and the
> HUD says `FULL`. Chaos multiplier ×0.5 while full.

That is a real control mutation (it removes the game's main verb), it is funny,
it is true, and it means the tutorial's lesson is *the obvious food is the trap*
— which is the entire thesis, delivered before the player has read a word.
Its Almanac entry is the first unlock in the game and it carries the dispute
(§9.3).

**Why leg 1 exists at all** rather than starting at the strip mall: the flight
is a completely different control scheme, and flight 1 is the only place in a
45-minute run where you can teach it with nothing at stake. `lethal: false` on
flight 1 is not a nicety, it is the tutorial.

## 2.2 LEG 2 — THE STRIP MALL LOT ✅ built

| | |
|---|---|
| **Setting** | Unchanged. |
| **Time** | Overcast midday. Unchanged. |
| **Built from** | `zone_strip_mall.gd` as it stands, `variant = &"mall"`. |
| **Zone clock** | 180 s |
| **Mission id** | `&"strip_mall"` · 2 of 4 primaries (formula) |
| **Substances** | All sixteen. This is where the lid comes off. |
| **Flight** | 70 s, 38 km. Thermals introduced with a HUD callout. |
| **Intensity** | **4** |

**What's new:** the full shelf, combos, cats, and the first flight that can cost
you something.

**What must change about it:**
- Delete the dead `objectives()` function (lines 577–586) — superseded by
  `mission_defs.gd` per `DESIGN_MISSIONS.md` §9.2.
- `zone_title()` reads its string from `ROUTE`, not from a literal
  (true-regardless #6).
- Add the `variant` export and branch `_environment()`, `_sources()`, `_props()`
  and `_people()` on it, so legs 1 and 7 can be built from the same file.
  Estimate ~200 lines added across all three variants.
- Nothing else. It is fine.

## 2.3 LEG 3 — SUBURBIA ✅ built

| | |
|---|---|
| **Setting** | Unchanged cul-de-sac. |
| **Time** | Golden hour. Unchanged. |
| **Built from** | `zone_suburbia.gd` as it stands. |
| **Zone clock** | 180 s |
| **Mission id** | `&"suburbia"` · 3 of 5 primaries · **leg 3 is where the timed-window primary arrives** (`backyard_blitz`) |
| **Flight** | 80 s, 190 km, **north**. Turbines and headwind bands introduced. |
| **Intensity** | **5** |

**What's new:** height. The roof, the trampoline-as-stairs, the fenced
backyards. This is the leg where the flight controller starts to matter on the
ground.

**What must change about it:**
- **BUG, blocking.** The README says the zone "doesn't report objective progress
  for its own bespoke moments." It half does: `_on_roof_entered` scores
  `"ON THE ROOF"`, `_on_trampoline_bounce` scores `"BOING"`, `_on_pool_entered`
  scores `"CANNONBALL"` — and `mission_defs.gd` matches `ON THE ROOF` and
  `BOING`, so those work. **`cannonball` and `pool_party` in `mission_defs.gd`
  do not match the label `CANNONBALL`.** Verify and fix the label match; also
  verify `LAUNDRY` is actually scored by the clothesline (`wearing_it` depends
  on it). Two of suburbia's six primaries and two hidden objectives are at risk.
  This must be fixed before leg 3 ships, and it is a bug, not content.
- Header comment says "LEG 3" already. Correct by luck; leave it.
- Nothing else.

## 2.4 LEG 4 — COTTAGE COUNTRY ✅ built · **first peak**

| | |
|---|---|
| **Setting** | Muskoka. Unchanged. |
| **Time** | Night. Unchanged. |
| **Built from** | `zone_cottage.gd` as it stands. |
| **Zone clock** | 180 s |
| **Mission id** | `&"cottage"` · 3 of 5 primaries |
| **Substances** | All sixteen, including the toad. **This is where toad slime is beautiful** — the design bible's set-and-setting principle, in the one place it pays off. |
| **Flight** | **THE LONG HAUL.** 110 s, 640 km, night, all three hazard types at maximum density. The longest flight until the Interstate. |
| **Intensity** | zone **7** · flight **8** |

**What's new:** darkness and water as a place. It is the game's biggest chaos
ceiling and its best-looking zone, so it gets the peak of the first half.

**Why the flight goes the wrong way, and why it's leg 3's flight not leg 4's:**
the wrong-way flight (leg 3 → cottage) is where the joke lands, because the
counter goes up *before* the big night rather than after. You go north, you have
the best night of your life, and then flight 4 makes you pay 640 km for it in
the dark. That ordering is the whole comedy of the first half.

**What must change about it:** the header comment says "LEG 3". Fix it. Nothing
else — it is the best zone in the project.

## 2.5 LEG 5 — THE STOPOVER · **the rest beat**

| | |
|---|---|
| **Setting** | A National Wildlife Refuge impoundment in upstate New York. A drowned marsh: open shallow water, cattails, dead standing timber, a gravel dyke road, a wooden observation tower, a **birdwatcher** with a scope and a folding chair. |
| **Time** | Dawn. Mist on the water, low pink light, the first warm palette since golden hour. |
| **Built from** | `zone_cottage.gd` with `variant = &"refuge"`: **no cottage, no dock, no boathouse, no campfire, no forest.** `WATER_Y` raised so the granite shelf is mostly submerged and the plateau becomes a low island. Add cattail instancing and ~40 NPC geese. Same code, different silhouette. |
| **Zone clock** | **150 s.** Short on purpose — a trough should not overstay. |
| **Mission id** | `&"stopover"` · required primaries overridden to **2 of 4** · `par_scale 0.55` |
| **Substances** | **All sixteen are present and the game says nothing about it.** |
| **Flight** | 75 s, 690 km. The lowest hazard density of the back half. |
| **Intensity** | **2** |

**What's mechanically new: restraint.** This is the deep trough, and it is not
tonal decoration — it is the **only full mechanical heal in the back half of the
run** (see §4.3). Arriving at the Stopover restores intoxication to zero and
stamina by 0.90. That happens whether you like it or not. What you do with the
next 150 seconds decides whether the healing sticks.

The zone contains every substance in the game and never mentions this. Its
objectives are mostly bonuses. Its primaries are gentle. There are forty other
geese standing around not doing anything. And the flock pen is the biggest thing
in the level.

> **This is the harm-reduction thesis as level design, and it never says a
> word.** The trough is only a trough if you take it.

**What the objectives push toward:** looking at your flock. The DD is assigned
or re-assigned here (the pen is the zone's centrepiece and the birdwatcher is
standing next to it). Two of the four primaries are about the flock rather than
about chaos — the only place in the game where that's true.

**Two hidden objectives, both `late: true`, and they are the best pair in the
game:**

| id | title / line | condition |
|---|---|---|
| `slept_on_it` | **"SLEPT ON IT"** / *"You sat on a pond for two and a half minutes and did absolutely nothing. Your flock has never been fitter."* | `subs_taken == 0` at the buzzer. `flock: {stamina: +0.25}` |
| `not_a_rest_stop` | **"THIS IS NOT A REST STOP"** / *"Everyone was having a nice morning."* | `peak_subs >= 3` at the buzzer. No flock penalty — the penalty is that you skipped the heal. |

**The other geese.** Around forty NPC geese on the water and the dyke, standing,
preening, arguing, asleep. They do not react to you much. **This is the visual
language of the ending, introduced 20 minutes early so that the 18th green is a
*return* rather than a first appearance** — the retrospective manoeuvre the
Untitled Goose Game GDC paper describes. They are the same objects leg 8 uses.
Build them once, here.

**The birdwatcher** says nothing, but their scope tracks you, and if you honk at
them they write something down. That's the whole gag and it costs one Label3D.

**Route top-up (see §4.5):** if you arrive at the Stopover with fewer than three
geese, strangers join the flock to bring you to three. Never above three, never
anywhere else on the route. This is the only place in the game a goose is ever
gained.

## 2.6 LEG 6 — THE CUT CORN · **second peak** · *the one new zone*

| | |
|---|---|
| **Setting** | A harvested corn field in eastern North Carolina. A half-cut field: standing corn on one side, stubble on the other, a **combine** working the boundary. A grain silo, two grain trucks, a farmhouse at the edge, round bales, a chained farm dog, a scarecrow. |
| **Time** | Hot midday, high hard sun, dust haze. The brightest zone in the game. |
| **Built from** | **`zone_corn.gd` — new.** The cheapest possible new zone: one big flat plane, a MultiMesh of corn, one moving vehicle, and props recycled from `prop_models.gd` (minivan → grain truck, house → farmhouse, fences, trees). |
| **Zone clock** | 180 s |
| **Mission id** | `&"corn"` · **4 of 6 primaries** (formula) · leg 5+ mastery constraints are live |
| **Substances** | **Six.** Fermented Berries (waste grain — the design bible's exact silo idea), Double-Double (a thermos in a truck cab), Grass, Math, Darts, Whippet. Deliberately thin. |
| **Flight** | 95 s, 390 km. Hazard density up. **The PUT DOWN HERE prompt is introduced on this flight** (§6.4). |
| **Intensity** | **7** |

**What's mechanically new: cover, and a ground that is dangerous.** Standing
corn is a wall at goose height and nothing from above — the only concealment in
the game, and the only place where flying costs you information instead of
giving it. Cut stubble is wide open. And the **combine** is a moving thing that
will absolutely run you over, throw you thirty metres and take the props with
it.

> Every zone before this one has a safe ground and a dangerous sky. This one
> inverts it. That inversion, 25 minutes in, is worth more than a new substance.

**What the objectives push toward:** using the corn. Primaries about doing things
*in front of* the combine, about crossing the open stubble, about the silo.

**Why this replaces the design bible's prairie silo:** the idea is good (big
skies, fermented grain, agricultural machinery) and the geography was wrong —
the prairies are west of Ontario, not south. Relocating it to a Carolina corn
field keeps every mechanical idea, puts it on the actual route, and lands on a
better true fact: waste grain in harvested fields is a major fuel source for
migrating geese, and the twentieth-century spread of corn agriculture measurably
changed where geese migrate and winter. **The silo survives. It is just in
North Carolina now.**

**This is the cut candidate.** If the schedule bites, leg 6 falls back to
`zone_suburbia.gd` with `variant = &"subdivision"`: a brand-new Carolina gated
community — hot haze, sod pallets, sprinklers on timers, palmettos, a retention
pond with an alligator in it, fire ants. Four days instead of eight, and it is a
genuinely different-feeling leg. It is worse than the corn field because it
doesn't invert anything, but it ships.

## 2.7 LEG 7 — THE TRUCK STOP · **the breath before the peak**

| | |
|---|---|
| **Setting** | A truck stop plaza off I-95 in Georgia. A fuel canopy, a diner, a row of parked rigs with their engines running, a dumpster corral, sodium lights, moths. |
| **Time** | **3 a.m.**, warm rain, wet asphalt reflecting orange. |
| **Built from** | `zone_strip_mall.gd` with `variant = &"truckstop"`. Same lot, same building footprint, night lighting, rain particles, the pond replaced by a flooded corner of the lot. |
| **Zone clock** | 180 s |
| **Mission id** | `&"truckstop"` · **5 of 6 primaries** — the escalation curve's hard cap, landing exactly on the last sandbox |
| **Substances** | **Four**, all of them ones you've had, all at reduced dose size. Tolerance has been climbing for seven legs. Nothing works properly any more. |
| **Flight** | **THE INTERSTATE.** See §2.8. |
| **Intensity** | **4** |

**What's mechanically new: scarcity, and moving platforms.** The rigs pull out
on a timer. A parked truck is a launch pad; a moving truck is a ride and a
hazard. Riding one out of the lot and having to fly back is the leg's identity
joke and it is a day's work on existing geometry.

**And the shelf is nearly bare.** This is the roguelike escalation lesson stated
in `DESIGN_MISSIONS.md` §1.5 — *escalate by narrowing options, not by inflating
numbers* — and it is also, quietly, the truest thing the game says. At the end of
a long trip there is almost nothing left, it barely does anything, and you are
still doing it. **Nobody says that out loud. Nobody ever should.**

**The tuning risk, named:** `required_primaries(7)` = 5 of 6 on a zone with four
weak substances. Leg 7's six primaries must be writable without chemistry —
honking, wrecking, riding a truck, the dumpster corral, the diner window. Write
them that way or drop the override to 4. This is the single most likely place
for the mission system to feel unfair, and it should be the first thing
playtested after the route exists.

**Why it's a trough:** Slay the Spire guarantees a rest immediately before the
boss. This is that rest. It is quiet, it is nearly empty, the humans are asleep,
and it is the last time in the run the player is not under pressure.

## 2.8 FLIGHT 7 — THE INTERSTATE · **the peak**

Not a zone. The seventh and last migration, and the climax of the run.

| | |
|---|---|
| **Length** | 130 s at integrity 1.0 — the longest flight, ~50% longer than the average |
| **Distance** | 310 km |
| **Weather** | Night, heavy rain. Fog density up, sky black, the ground below is **black with two rivers of headlights running through it.** |
| **Hazards** | Spawn interval `[0.9, 1.6]` — the tightest in the game. 80% obstacle / 20% thermal, and **no thermals at all in the first 60% of the distance.** Wires low and frequent, headwind bands wide. |
| **Flock** | Whatever leg 7 left you. There was no chance to heal — the Stopover was two legs ago and `rest()` at this point restores 0.35 intox / 0.25 stamina. |
| **The opening** | **The first 20 seconds contain nothing.** No obstacles, no thermals, no messages. Rain, wind, the formation, a single held music stem. Then it starts. |
| **Intensity** | **9** |

That 20 seconds of nothing is the micro-rest the pacing research demands
immediately before a peak, it costs one constant (`first_spawn_delay`), and it is
the most cinematic thing in the game for free.

**The ending of this flight is the ending of the flight system.** At 95%
distance the HUD dismantles itself, one element at a time, over about eight
seconds: the distance bar, the roster, the formation readout, the top line. The
music drops to one sustained stem. **The last 15 seconds of the run's last
flight have no interface at all.** Then the ground comes up and you land.

That is the "neutral beat between registers" the tonal-whiplash research asks
for, and it is a tween on existing labels.

**The 401 callback.** Flight 1 crossed the 401 at 12 km in daylight, safe, with
one span of wires and a briefing card. Flight 7 is the same shape at night in the
rain with half the flock gone. Nobody needs to point this out. The flight-end map
screen already names both.

## 2.9 LEG 8 — THE 18TH GREEN

Specified in full in **Part 5**.

## 2.10 What I rejected from the design bible's route, and why

| Bible item | Verdict | Reason |
|---|---|---|
| **The Retention Pond** (tutorial) | **Kept**, as leg 1 | It's the right tutorial and it's the game's own thesis object. Built as a strip-mall variant, not a new zone. |
| **The Prairie Silo** | **Relocated, not cut** | Mechanically good (open sky, fermented grain, farm machinery), geographically impossible (the prairies are west). Becomes leg 6, a Carolina corn field. The silo survives. |
| **Montreal Alley (winter)** | **Cut for v1** | Three reasons, in order of weight. (1) **Geography** — Montreal is northeast of southern Ontario; a southbound flyway does not pass through it, and after the leg-3 wrong-way joke the map cannot afford a second detour. (2) **Winter is what you are fleeing.** A snow zone on the route inverts the premise; snow should only ever be behind you. (3) **Ice friction is a controller change**, and the README's own rule is that the controller is the game. Special-casing ground friction for one zone risks the one thing that's good. **It is not gone** — it becomes Ascension rung 10, THE LATE DEPARTURE, where winter catches you at legs 5–7 and the snow is *earned* rather than scheduled. That is a better home for it than the base route. |
| **The 401** | **Kept, moved, and rhymed** | It is in Ontario, so it is flight 1, not leg 7. Its climax role goes to I-95 as flight 7, and the two are deliberately the same shape. |
| **The Golf Course, Florida** | **Kept, exactly** | See Part 5. |
| **Bosses** (Park Ranger / Zamboni / BIG DOWN) | **Cut for v1** | None of them fit a 45-minute route. A pursuit boss is a genre the controller doesn't have. The Zamboni belongs to the winter zone that just got deferred. BIG DOWN is a great post-launch idea and a bad first-shipment idea. **The route has no boss and doesn't need one — arrival is the win.** |
| **Molting season** (a no-fly ground chapter) | **Cut on truth grounds** | Moult happens in June, not on migration. This game's entire educational credibility rests on the mechanics encoding the real thing. A mid-migration moult zone would be the first lie in the project. The true fact (geese are genuinely flightless for ~6 weeks) goes in the Almanac instead. |

## 2.11 The per-leg summary table

| Leg | Name | Time | New question it asks | Zone s | Flight km / s | Intensity |
|---|---|---|---|---|---|---|
| 1 | The Retention Pond | overcast morning | *What do these buttons do, and what happens if I eat the obvious thing?* | 240 | 12 / 45 | 2 |
| 2 | The Strip Mall Lot | overcast midday | *What happens if I take two of them?* | 180 | 38 / 70 | 4 |
| 3 | Suburbia | golden hour | *What's up there?* | 180 | 190 / 80 | 5 |
| 4 | Cottage Country | night | *What does the same substance do somewhere beautiful?* | 180 | 640 / 110 | 7 |
| 5 | The Stopover | dawn | *What if you didn't?* | 150 | 690 / 75 | **2** |
| 6 | The Cut Corn | hard midday | *What if the ground was the dangerous part?* | 180 | 390 / 95 | 7 |
| 7 | The Truck Stop | 3 a.m. rain | *What's left?* | 180 | 310 / 130 | 4 |
| 8 | The 18th Green | first light | — | ∞ | — | 1 |

---

# PART 3 — THE INTENSITY CURVE

Sixteen beats. Intensity is a 0–10 subjective composite of hazard density,
required attention, consequence and noise — the "chosen metric" the Level Design
Book asks you to pick and hold.

```
                                                    0    2    4    6    8   10
                                                    |    |    |    |    |    |
 1  L1 zone   THE RETENTION POND     overcast am     ####                        2
 2  F1        THE 401                            ######                          3
 3  L2 zone   THE STRIP MALL LOT     overcast pm  ########                       4
 4  F2        OVER THE QEW                        ########                       4
 5  L3 zone   SUBURBIA               golden hour  ##########                     5
 6  F3        THE WRONG WAY   ↑km                 ############                   6
 7  L4 zone   COTTAGE COUNTRY        night        ##############                 7   ◀ peak
 8  F4        THE LONG HAUL                       ################               8   ◀ the bill
 9  L5 zone   THE STOPOVER           dawn         ####                           2   ◀◀ REST BEAT
10  F5        DOWN THE SUSQUEHANNA                ##########                     5
11  L6 zone   THE CUT CORN           hard midday  ##############                 7   ◀ peak
12  F6        THE FALL LINE                       ############                   6
13  L7 zone   THE TRUCK STOP         3 a.m. rain  ########                       4   ◀ breath
14  F7        THE INTERSTATE         night rain   ##################             9   ◀◀ THE PEAK
15  L8        THE 18TH GREEN         first light  ##                             1   ◀ falling action
16  L8        credits (playable)                  ##                             1
```

| # | Beat | Int | Why it sits there |
|---|---|---|---|
| 1 | **L1 zone** — The Retention Pond | 2 | Tutorial. Deliberately the dullest thing in the game so leg 2 reads as an event. Long clock, no pressure, three substances. |
| 2 | **F1** — The 401 | 3 | Slight lift: new control scheme, but non-lethal and short. The only rise here is *novelty*, not threat. |
| 3 | **L2 zone** — Strip Mall | 4 | The lid comes off. Sixteen substances, cats, the full toybox. High *noise*, low *threat* — that gap is what makes it feel like a party rather than a test. |
| 4 | **F2** | 4 | Holds. First flight that can cost a bird, but density is low. A plateau is correct here: two rises in a row this early would blunt the leg-3 lift. |
| 5 | **L3 zone** — Suburbia | 5 | First real rise. Verticality, 3-of-5 primaries, the first timed-window objective. The escalation the mission system already schedules for leg 3. |
| 6 | **F3** — The Wrong Way | 6 | Turbines and headwinds arrive. Also the map joke, which is a *tension release* inside a rising beat — the curve rises and the room laughs at the same time. |
| 7 | **L4 zone** — Cottage Country | **7** | **First peak.** The best-looking zone, the biggest chaos ceiling, night, water, the toad. This is the big night out and it should feel like one. |
| 8 | **F4** — The Long Haul | **8** | **The bill.** 110 s, night, all three hazard types at full density, and the flock is as wrecked as it will ever be. This is where most players lose their first bird, and it must be where they lose it — a first loss any earlier is bad luck, any later is too late to matter. |
| 9 | **L5 zone** — The Stopover | **2** | **THE REST BEAT.** A crash from 8 to 2 in one cut. Dawn, quiet, short clock, gentle objectives, a full mechanical heal. The Level Design Book's palette cleanser, and per the flow-channel model the drop is deep *because* the run just introduced its hardest thing (real attrition). A gentler dip would not register. |
| 10 | **F5** | 5 | Comes back up moderately. The lowest-hazard flight of the back half — you've just rested; the game should let you feel it. This is the flow-channel "feel the power" beat. |
| 11 | **L6 zone** — The Cut Corn | **7** | **Second peak, equal to the first.** Equal, not higher, because its *kind* of pressure is new (dangerous ground, a moving vehicle, cover) and novelty is doing the escalation work. Lopez: order the peaks so they grow, or grow in frequency. Here the frequency tightens instead — peaks at 4, 6 and 7 are three beats apart, then two. |
| 12 | **F6** | 6 | Hazard density up. Introduces the PUT DOWN HERE decision, which raises *attention* while the threat is still moderate — teaching a mechanic in a low-stakes context immediately before it matters. |
| 13 | **L7 zone** — The Truck Stop | **4** | **The breath before the peak.** Slay the Spire's guaranteed pre-boss rest site. Quiet, nearly empty, four weak substances, sleeping humans. Its *requirement* is the highest in the game (5 of 6) which keeps the beat from going slack — it's a low-noise, high-focus trough, not a nap. |
| 14 | **F7** — THE INTERSTATE | **9** | **THE PEAK.** Longest, densest, darkest, wettest, no thermals for 60% of it, and the flock is whatever survived. Opens with 20 s of nothing — a micro-trough inside the peak. Ends with the HUD dismantling itself. |
| 15 | **L8 arrival** | **1** | **Falling action, and it is not negotiable.** "Avoid maximum intensity final bosses." The stakes stop; the comedy does not. No clock, no HUD, no objectives, no score. |
| 16 | **L8 credits** | 1 | Stays at 1. Playable, but the only pressure is whether you want to knock over your own roster. |

**The shape in one sentence:** a rise to a peak at leg 4, a hard crash to a
guaranteed trough at leg 5, a second equal peak at leg 6, a shallow trough at
leg 7, the summit at flight 7, and a long flat resolution.

**Two things the graph is deliberately not:**

- **Not monotonic.** There are two drops of 4+ points (beat 8→9, beat 12→13→14
  goes 6→4→9). Both are the "saw-tooth beats staircase" rule in action.
- **Not maximal at the end.** Beat 14 is the summit and beat 15 is a 1. The
  eight-point drop across that cut is the largest single transition in the run
  and it is the whole design of the ending.

**Where the rest beats go, restated for the build:**

1. **Leg 5, The Stopover** — the primary rest beat. Deep, mechanical, 150 s.
2. **Leg 7, The Truck Stop** — the secondary rest beat. Shallow, 180 s,
   immediately before the peak.
3. **The first 20 seconds of flight 7** — the micro-rest inside the peak.
4. **The last 15 seconds of flight 7** — the neutral beat between registers,
   with no interface at all.

---

# PART 4 — PROGRESSION AND STAKES

This is the part the whole option rests on. If a competent player arrives 6-of-6
every time, the graded ending grades nothing and Part 5 is decoration.

## 4.1 The design targets

| Archetype | Behaviour | **Target survivors at leg 8** |
|---|---|---|
| **Careful** | Assigns a DD by leg 2 and keeps it. Shares ≤1× per leg, aimed via the pen rather than blanket. Rotates the lead whenever prompted. Flies tight (avg integrity > 0.75). Takes the Stopover. | **5–6 of 6** |
| **Typical** | Assigns a DD somewhere around leg 4. Shares 2–3× over the run. Rotates when the game tells them to. Avg integrity ~0.55. Half-uses the Stopover. | **3–4 of 6** |
| **Reckless** | Blanket-shares every leg. Never assigns a DD. Never rotates until forced. Avg integrity < 0.35. Doses at the Stopover. | **1–2 of 6** |
| **Floor** | Anything at all | **1** — guaranteed, always, by construction |

The spread that matters is **1 to 6**, and the *modal* outcome should be **4**.
A first-time player who has a good time and pays no attention to the flock should
arrive with four geese and feel the two absences.

## 4.2 The two loss channels, and why there are two

Today there is exactly one: a non-player bird whose drift carries it into a wire
or a turbine. That is a physics accident. Accidents cannot deliver "reckless →
alone," because they are not *earned*. There must be a channel the player
authors.

| Channel | Trigger | Frequency | Framing | Feel |
|---|---|---|---|---|
| **DOWN** | Wire or turbine strike (existing) | 0–2 per run | `"WAYNE IS DOWN"` · hitstop · feathers · the game's fifth and last hitstop site | Rare, shocking, mostly bad luck amplified by your drift |
| **DROPPED** *(new)* | Stamina at 0 for 3 continuous seconds | 0–4 per run | `"CÉLINE IS PUTTING DOWN"` · no hitstop · the bird peels off and glides away below the camera | Common, slow, entirely your fault, and **nobody dies** |

**DROPPED is not death and the copy must never imply it is.** The bird lands and
winters where it fell. That distinction is load-bearing for tone: this game
should not be killing named characters as a consequence of a joke about drugs,
and the sincere moment on the 18th green is much better if it is about *absence*
than about *death*.

It is also true. Geese that cannot keep up drop out of formation and winter
short of the destination. The Almanac fact writes itself.

## 4.3 `Flock.rest()` stops being unconditional healing

This is the borrowing from Option B, and it is a **curve, not a switch.** A
switch ("no healing after leg 5") produces a cliff; a curve produces dread.

`rest()` runs in `_on_migration_done()` and prepares the flock for the *next*
zone. Values are per-arrival:

| Arriving at | intox cleared | stamina restored | Why |
|---|---|---|---|
| Leg 2 (Strip Mall) | **1.00** | **1.00** | The tutorial forgives everything. Nobody should carry a leg-1 mistake. |
| Leg 3 (Suburbia) | 0.75 | 0.60 | Today's values. The baseline. |
| Leg 4 (Cottage) | 0.60 | 0.45 | The first leg where you arrive tired. |
| **Leg 5 (Stopover)** | **1.00** | **0.90** | **The rest beat is mechanical.** The only full clear in the back half. |
| Leg 6 (Cut Corn) | 0.40 | 0.28 | The back half is lean. |
| Leg 7 (Truck Stop) | 0.35 | 0.25 | You fly the Interstate on what's left. |
| Leg 8 (arrival) | — | — | No flight follows. |

**What this does to the run's shape:** the first half is forgiving and the second
half remembers. Combined with tolerance (which already persists forever), the
back half of the route is a slow narrowing on two independent axes — the
substances do less and the flock recovers less. Neither is ever stated.

## 4.4 The numbers that make attrition actually happen

Measured from the current build, drafting birds essentially never exhaust: at
intox 0.8 and integrity 0.5 a drafting bird *gains* stamina. Three changes fix
it.

**(1) Intoxication burn: `0.012` → `0.045` per second per unit of intox.**
`migration.gd:433`.

| bird intox | burn/s | draft recovery/s @ integrity 0.6 | net |
|---|---|---|---|
| 0.0 (sober / DD) | 0.000 | +0.0104 | **+0.0104** — never exhausts |
| 0.3 | 0.0135 | +0.0104 | −0.0031 — loses 0.34 over a 110 s flight |
| 0.6 | 0.027 | +0.0104 | −0.0166 — loses 1.0 over a 60 s flight |
| 0.9 | 0.0405 | +0.0104 | −0.030 — **zero from full in 33 s** |

That is the shape the design needs: **sober birds are safe forever; a bird you
blanket-dosed twice will not survive a long flight.** One blanket share is
`dose_flock(0.32)`; two is 0.64; three is 0.96. The share key already prices
itself, it just never charged.

**(2) The three-second grace, and the rescue.**

```
if b.stamina <= 0.0:  b.zero_t += delta   else:  b.zero_t = 0.0
if b.zero_t >= 3.0 and losses_this_flight < 2:  drop_out(b)
```

Below 0.15 stamina a bird's HUD pip flashes and it emits a distress honk every
4 s. **Honking at it saves it.** `_rally()` is extended: if any bird is below
0.20 stamina it targets the *lowest-stamina* bird rather than the worst drifter,
and grants **+0.06 stamina, once per bird per 8 seconds**, resetting `zero_t`.

Over a 110 s flight that is a maximum of ~13 rescues spread across the flock,
each worth about two seconds of lead drain. Enough to matter; nowhere near
enough to trivialise. And it converts the honk from a cosmetic into the flight's
only act of care, which is worth a great deal for four lines of code.

**(3) Two hard caps.**

- **At most 2 birds may leave the flock per flight.** A third drop-out is
  deferred — the bird "hangs on" and starts the next flight at 0.05 stamina.
  Reasons: a single catastrophic flight on leg 3 must not empty the roster and
  deaden 25 minutes of run; and three losses in one flight reads as noise where
  two reads as a story.
- **No losses at all on flight 1.** `lethal: false` in the route table.

**(4) Flight length rises across the route** (45 → 130 s), from `ROUTE_DATA.md`,
so late flights are genuinely longer rather than nominally harder.

## 4.5 Can geese ever be regained? Yes, once, and only downward

**The Stopover tops the flock back up to a floor of three, and nowhere else.**

```
on arrival at leg 5:
    while alive_birds().size() < 3:
        birds.append(new bird, intox 0.0, stamina 0.85, joined_at_leg 5)
```

Never above three. Never on any other leg. Never at Ascension rung 3+.

**Why this exists, and why it is not a cop-out.** Without it, a player who loses
four birds on flight 4 spends the last three legs with a two-bird flock: no lead
rotation, no attrition stakes, nothing to lose. The game's most interesting
system switches off for 20 minutes. That is a worse outcome than a small
top-up.

**Why it can't be farmed:** it caps at three, which is below the starting six. It
is never a reward. A player who arrives at the Stopover with five geese gets
nothing.

**Why it's true:** mixed-family flocks assembling at staging areas is real goose
behaviour and is the Almanac fact for leg 5.

**Why it's better than a clean 6/6:** the credits line *"two of the four geese
who arrived with you, you met in Pennsylvania"* is a better ending than *"you
kept everyone."* Strangers are marked `joined_at_leg: 5`, stand slightly apart on
the green, and get their own line in the credits roster.

Strangers are ordinary flock members in every other respect: dosable, leadable,
assignable as DD. One less special case.

## 4.6 The Designated Driver, and why it is not special-cased

`flock_pen.gd` already ships DD assignment in all three zones (the README is out
of date). Under the new stamina maths the DD needs **no protection rule at all**:

> A DD has intox 0 permanently. Intox burn is 0. Draft recovery is positive at
> any integrity above ~0.15. **The DD cannot exhaust.** Its survival is a
> consequence of the physics, not an exception to them.

It can still be taken by a wire. That is the right amount of risk: the bird you
kept clean is the bird that almost always arrives, and "almost" is doing real
work.

Ascension rung 8, NO PASSENGERS, sets DD intox burn to the normal rate — which
is to say, it makes the DD merely *sober*, not immune. One line.

## 4.7 The flight HUD must show the roster, or none of this exists

Currently the flight shows *your* stamina, formation %, flock count and a
fit-to-lead count. Attrition is invisible until a bird is gone, which makes every
loss feel arbitrary.

**Required:** a roster strip, bottom-left, one row per living bird, obeying the
peripheral-vision rules already established in `DESIGN_MISSIONS.md` §7 (shapes
not glyphs, bars alongside numbers, redundant encoding, no hue alone):

```
▶ GORD        ████████░░  LEAD
  CÉLINE      ██████░░░░
  WAYNE       ██░░░░░░░░  ⚠         ← flashing, distress honk every 4 s
  SHANIA ⬤    ██████████  DD        ← the vest, as a shape
  BRUCE       ████░░░░░░
```

`⚠` is a drawn triangle, not a glyph. The bar is the primary read. Intoxication
tints the *name*, not the bar, so the two channels don't collide.

**This is not optional polish.** Without it, the honk-rescue is undiscoverable,
the PUT DOWN decision is uninformed, and every drop-out is a surprise. It is the
single highest-value UI in the build plan after the roster screen itself.

## 4.8 What `scars` becomes

`flock_state.gd:41` declares `scars` and nothing writes it (true-regardless #5).
Wake it up with the cheapest possible writer:

```
scars += 1  when:  a bird survives a flight at < 0.1 stamina
                   a bird is rallied back from zero_t > 1.5
                   a bird is aboard for a leg where the player blacked out
```

Rendered in exactly three places: the flock pen's state label picks up a
suffix at 3+ scars (`WAYNE ·· ROUGH`), the roster row shows a pip per scar, and
the credits roster prints it. No visual mesh changes — a limp is a rig problem
and this is a spec, not a wish.

The design bible's §12 "The goose remembers" wants scars to persist across runs.
**They don't, and shouldn't** — a fresh flock every run is what makes the run a
unit of meaning. What persists across runs is the memorial (§7.3).

## 4.9 How to verify the balance without playtesters

One developer cannot A/B an attrition curve. Build the harness instead — it is
half a day and it is the only way these numbers get honest:

`tools/flight_harness.gd`: runs all seven flights headless at three scripted
intox/integrity profiles (careful / typical / reckless), 200 iterations each,
prints the survivor distribution per archetype and the leg at which the first
loss occurs.

**Pass condition:** careful median ≥ 5, typical median = 4 (mode 4, spread 3–5),
reckless median ≤ 2, floor never below 1, and the modal first-loss leg is 4.
Tune `intox_burn`, the drop-out grace and the per-flight lengths against that
table and nothing else.

---

# PART 5 — THE ENDING

## 5.0 The rule that governs everything below

> **The comedy does not stop. The stakes do.**

Every design decision in leg 8 is downstream of that. There is no monologue,
there is no text card, there is no swelling string section, and there is no
moment where the game stops being funny in order to be sincere. The sincere
thing happens *inside* the joke.

And, from `WIN_CONDITIONS.md`: **the moment the golf course has objectives, the
sincere moment dies.** No clock. No HUD. No score. No chaos counter. No Goose
Brain. Nothing in the top-left corner. Nothing in any corner.

## 5.1 The place

**THE 18TH GREEN.** A golf course in north Florida, first light. Named on screen
once, as the last route pin: `THE 18TH GREEN — FLORIDA · 0 KM`.

- A fairway running away from the player toward a green with a flag.
- A bunker, unraked.
- A water hazard with a fountain in it.
- A cart path. Palms. Spanish moss. A clubhouse in the middle distance you
  cannot reach and never need to.
- **Sprinklers.** Dozens, on a rotation, and they never stop for the entire
  duration of the ending including the credits. The design bible calls Florida
  "the promised land. Sprinklers forever." Take it literally.
- Mist, low pink-gold sun, long shadows. The warmest lighting in the game.

Built as `zone_green.gd`, bespoke, but geometrically trivial: a large mown plane,
a sand disc, a water disc, a few dozen instanced palms, a cart path spline. The
expensive part is not the geometry. It is the geese, and those already exist.

## 5.2 The residents

**About thirty NPC geese are already here, and they are doing exactly what the
player has been doing for forty-five minutes.**

This is the whole ending. Build it from `flock_pen.gd`'s `_build()` — it already
constructs named, labelled, tinted, wandering, model-agnostic geese with no
colliders. Fork it into `green_residents.gd`, delete the labels, keep everything
else.

The residents, as a spawn table:

| # | What it's doing | Source |
|---|---|---|
| 1 | Asleep in the bunker, on its back, feet up | one rotation |
| 2 | On a golf cart — one at the wheel — driving slow circles on the fairway, **forever** | the cart is a `PathFollow3D` |
| 1 | Standing in the water hazard. Not swimming. Standing. | |
| 4 | Clustered around a cooler that is open and empty | |
| 1 | On the clubhouse roof, honking at nothing, every ~9 seconds | |
| 1 | Doing laps of the same palm tree, in one direction, indefinitely | |
| 2 | Fighting over a golf ball. The ball is inert. They keep at it. | |
| 1 | **Wearing a tiny high-vis vest.** A retired DD. | reuse `_make_vest()` |
| 1 | Standing at the far edge of the map in the exact idle pose of the leg-1 tutorial goose, facing north | |
| ~16 | Grazing, preening, arguing, asleep — the Stopover crowd, reused | `zone_cottage.gd` variant `refuge` NPCs |

**None of them react to the player.** They do not stop. They do not look up. They
do not have dialogue. The player can honk at them, land on them, walk through
them — they carry on. That non-reaction is the joke and it is also the point:
you have arrived somewhere that was already like this before you got here.

**Why this reads and doesn't just look like set dressing:** because the player
saw it at the Stopover, twenty minutes ago, at dawn, sober, with the whole
journey still ahead. The 18th green is the same image at the other end. That is
implication rather than exposition, and it costs one reused spawner.

## 5.3 The beats, in order

**Beat 0 — the last flight lets go.** (~15 s, during flight 7)
At 95% distance the HUD dismantles: distance bar, roster, formation, top line,
one element every ~1.5 s. Music drops to a single sustained stem. The ground
comes up. No interface at all for the last 15 seconds. **Then you land.**

**Beat 1 — you land, and nobody says anything.** (~5 s)
Control is yours immediately. The camera pulls back slightly further than the
zone rig's default and stays there. The sprinklers are the loudest thing.

**Beat 2 — your survivors land with you.** (~10 s)
Every living flock member lands physically, in a loose line, using the migration's
own `_make_goose()`. They stand. They look around. One shakes itself off.

**Beat 3 — they settle in.** (~40–60 s, player-paced, runs in background)
Every ~7 seconds, one surviving bird peels away and **picks a resident to join**:

- The first goes to the bunker and lies down next to the sleeping one.
- The second climbs onto the golf cart.
- The third stands in the water hazard, next to the stander.
- The fourth joins the cooler cluster.
- The fifth starts doing laps of a different palm tree in the other direction.

Each departure: a soft honk, and **the bird's name floats up once, in world
space, and fades.** That is the *only* time in the entire game a flock member's
name is rendered in the world during play. It is the entire emotional payload and
it costs one `Label3D` and a tween.

> **The DD, if it is alive, goes last and does not join anybody. It stands next
> to you.** One `if`. It is the payment for six legs of restraint and it is the
> best thing the DD mechanic will ever do.

**Beat 4 — the sincere moment.** (~6 s, whenever the player triggers it)
Once every survivor has settled, the player is alone on the green — with the DD,
if they have one.

**There is one thing to do, and nothing tells you to do it: honk.**

When the player honks *anywhere*, every goose on the course honks back — **once,
in a ragged wave from nearest to farthest**, over about 2.5 seconds, including the
ones asleep, including the one on the cart, including the one in the water. Then
it is quiet again, except for the sprinklers.

That is the whole sincere beat. **The one sincere moment in Geeked Geese is a
sound effect.** No text, no camera move, no music swell, no slow-motion. Forty
geese answering a honk.

It can be re-triggered. It should be. It is slightly quieter each time for the
first three, then settles. A player who honks eleven times has understood the
game.

*Why it works on the worst run:* if the player arrived alone, the wave still
happens, and it lands harder, because there is nobody standing next to them.

**Beat 5 — the credits, and you are still playing.** (~2 min)
The player never loses control. Credits rise from the far end of the fairway as
**physical, honkable, knockable slabs** — low white monoliths lying on the grass
that scroll toward and past the camera. You can land on them. You can honk them
over. They break like every other prop in the game, with the same particles and
the same sound, and **they do not award chaos**, because there is no chaos
counter any more.

This is Katamari's credits-as-a-bonus-stage and Rayman's names-as-platforms,
applied to a game whose core verb is knocking things over. It is the cheapest
possible way to satisfy *the comedy continues while the stakes stop*, and the
design bible already names Katamari as a reference point.

Music: the game's theme, played straight, for the first and only time — fiddle
through a blown speaker, but in tune.

**Interleaved into the roll, in the same typeface, in this order:**

1. **The verdict line.** One sentence, the only authored sentence in the ending:

   | Survivors | Line |
   |---|---|
   | 6 | *"Everyone made it. Statistically, this does not happen."* |
   | 4–5 | *"Most of you made it."* |
   | 2–3 | *"Some of you made it."* |
   | 1 | *"You made it."* |

   Plus, if the DD is alive, one more: *"SHANIA never touched a thing. SHANIA is
   standing right there."* If the DD did not make it, **there is no line at
   all.** Implication.

2. **The route**, leg by leg, with the km. Eight lines.

3. **The roster.** Every goose, alive or not, with where they left:

   ```
   GORD          arrived
   CÉLINE        arrived
   SHANIA        arrived · designated driver · never touched a thing
   WAYNE         put down over Lake Ontario · leg 4
   BRUCE         hit a wire near Fayetteville · leg 6
   MARGARET      put down south of Savannah · leg 7
   DENISE        joined at the Stopover · arrived
   ```

4. **The distance.** *"2,270 km flown. 1,850 km in a straight line."*

5. **The Almanac tally, as a fact, not a score.** *"You found 13 of 16. You never
   touched the toad."* No percentage, no bar, no "completion". See §9.4.

6. **The memorial**, if this isn't the first run: every goose lost across all
   previous runs, by name, in small type, with no comment.

7. The actual credits.

**The player can wreck all of it, including their own roster.** That is
permitted and it is the tone.

**Beat 6 — after.** (forever)
When the credits finish, **nothing happens.** The course stays. The sprinklers
keep going. The residents keep doing their things. The player can waddle around
indefinitely. One small line in the corner: `[ESC]`.

The pause menu, and only the pause menu, now offers:

- **FLY IT AGAIN** — restarts the route, offering the next Ascension rung
- **STAY** — closes the menu

There is no "you unlocked" card, no score screen, no "press any key to
continue." The game ends by declining to end.

## 5.4 Total duration

| Beat | Duration |
|---|---|
| 0 — flight lets go | 15 s (inside flight 7) |
| 1 — landing | 5 s |
| 2 — flock lands | 10 s |
| 3 — settling | 40–60 s, background |
| 4 — the honk | player-paced, ~6 s |
| 5 — credits | ~120 s |
| 6 — after | ∞ |

**≈ 4.5 minutes**, of which only the credits have a fixed length, and all of it
is played.

## 5.5 What this deliberately does not contain

- No cutscene. Not one frame.
- No dialogue. No NPC ever speaks.
- No moral. The word "responsibly" does not appear.
- No score.
- No "you have unlocked".
- No difficulty branding, no accessibility branding (§1.7).
- No second ending. There is one ending; its content varies by four strings and
  a number of birds.

## 5.6 Build cost

The finale is cheaper than it reads because three of its four expensive parts
already exist:

| Part | Source | Cost |
|---|---|---|
| Named wandering geese with vests and tints | fork `flock_pen.gd::_build()` | 1 day |
| Physically-landing flock members | `migration.gd::_make_goose()` | 0.5 day |
| Golf course geometry | new, but trivial | 1.5 days |
| Resident behaviours (10 distinct ones) | new, all tiny | 1 day |
| The honk wave | new, one function | 0.5 day |
| Playable credits + roster/route/Almanac payload | new | 1.5 days |
| Music stem set `mus_green` | `tools/gen_music.py` | 0.5 day |

**≈ 6 days.** Build it *before* legs 1, 5, 6 and 7, exactly as `WIN_CONDITIONS.md`
recommends: it is the thing you are least sure you can land, and a week is a
cheap price for finding out.

---

# PART 6 — FAILURE

## 6.1 The current state

`migration.gd:162` — `_spawn_flock()` with no living birds calls `_finish()`
immediately: distance 0, "LANDED SHORT", 120-second zone, forever.
`Flock.new_flock()` is only called from `_ready()` and `Game.new_run()`. This is
`WIN_CONDITIONS.md` true-regardless #1 and it is a soft-lock.

**It is also currently unreachable**, and that matters. `lose_bird()` is only
called from `_check_obstacle()`, which special-cases `player_bird_index` into the
"you clipped it" branch. The player's own bird cannot be lost, so `alive` cannot
be empty. The hang is a real defect, but it is a defect in a branch that no
player has ever taken.

## 6.2 The design: make the guarantee explicit rather than accidental

> **The player's bird can never leave the flock. Arrival is guaranteed by
> construction.**

Codify it in three places rather than relying on one call site:

1. `Flock.lose_bird(i)` returns early if `i == Flock.player_index`.
   (`player_index` is currently local to `migration.gd`; promote it onto
   `Flock` so the guarantee lives with the data.)
2. The drop-out check skips `player_index`.
3. `Flock.alive_birds()` gains a `assert(size() >= 1)` in debug builds.

This is the answer to "what happens when the flock is wiped": **it cannot be.**
That is not a dodge — it is the same promise the game already makes at the leg
level, honoured at the run level, and it is what lets the back half of the route
be genuinely dangerous without a hard fail.

## 6.3 And handle the impossible state anyway

`_spawn_flock()` gains a branch:

```
if alive.is_empty():
    Flock.emergency_reseat()      # revive player_index at stamina 0.25
    push_warning("flock empty at leg %d — reseated" % Flock.leg)
```

Never surfaced to the player as a failure. It is a guard against a future feature
reintroducing the state, which is exactly what a defensive fix is for.

## 6.4 What replaces the missing punishment: **PUT DOWN HERE**

A run with no lose condition needs a *decision* where the loss would have been.
This is it, and it is the best new idea in the spec.

**The mechanic.** After 40% of a flight's distance, the player may **descend
below `Y_MIN + 4` and hold there for 1.5 seconds** to put the whole flock down
voluntarily. No new key — descending and staying down *is* putting down.

**The consequence:**

- The flight ends at the current distance. `LANDED SHORT`. You take the normal
  clock penalty.
- **Every bird below 0.2 stamina is saved** — it does not drop out, and it gains
  +0.15 stamina.

**Why this is the right answer:**

- It converts the soft fail from something you *suffer* into something you
  *choose*, which is what `WIN_CONDITIONS.md`'s appendix asks for ("the flight
  wants a decision point — push on or put down here").
- It is a genuine strategic trade with no dominant side: clock against flock.
- **It is the clearest statement the game ever makes of its own thesis.**
  Stopping early is the correct play, and it costs you something. Nobody says it.

**Introduction.** The prompt appears once, on flight 6, at 40%:
`DROP BELOW THE LINE AND HOLD — PUT DOWN HERE`, with a faint horizon line drawn
across the HUD at `Y_MIN + 4`. That is the flow-channel rule — teach the mechanic
in a low-stakes context immediately before it matters — and flight 7 is where it
matters.

## 6.5 Leg-level failure is unchanged

Everything in `DESIGN_MISSIONS.md` §6 survives untouched:

- Missing primaries → −20 s per shortfall, floored, plus −0.08 flock stamina.
- Landing short → 120 s base instead of 180 s.
- Both stack, both floored.
- `evaluate_leg()` still cannot return "you lost."

**Two bugs to fix while you're in there:**

- **Clock clamps disagree.** `mission.gd:1151` clamps `next_seconds` to
  `[110, 210]`; `main.gd:315` clamps the value it uses to `[100, 220]`. The
  results card can promise a number the game doesn't hand out. Pick `[110, 210]`
  and use it in both.
- **Par is unbounded.** `par = PAR_BASE * (1 + 0.15 * (leg - 1))` grows forever
  while `target_scale()` caps at 1.9× on leg 6. On an 8-leg route the damage is
  small but real, and the Stopover breaks it badly (a 150-second zone with a
  gentle objective set gets leg-5 par). Fix: `par = PAR_BASE * min(1 + 0.15 *
  (leg-1), 1.75) * route_entry.par_scale`.

## 6.6 The `R` key is currently a 45-minute landmine

`main.gd:338` — `gg_restart` calls `Game.new_run()` with no confirmation. In a
loop that never ends, that's fine. In a finite 45-minute run, a mis-pressed R on
leg 7 silently destroys the whole thing.

**Required: a confirm.** `R` opens a two-button modal:
`RESTART THE FLYWAY? · LEG 7 OF 8 · [Y] START AGAIN FROM THE POND / [N] NO`.
This is a one-screen fix and it is the difference between a finite game and a
cruel one.

## 6.7 The worst run, spelled out

A player who is maximally reckless: blanket-shares in every zone, never assigns a
DD, never rotates the lead, doses at the Stopover, lands short on every flight.

They arrive at the 18th green **alone**, having flown 2,270 km, with the minimum
clock on every leg from leg 3 onward, with an F on most legs, and with five names
in the credits roster that aren't standing on the grass.

**They still arrive, the sprinklers still come on, and when they honk, forty
geese honk back.** The verdict line reads *"You made it."*

That is the game's actual lose state, and it is the best version of the ending.

---

# PART 7 — REPLAY

## 7.0 The honest framing

**A finite game with credits is a thing people finish and put down.** That is the
deal Option A makes and this section will not pretend otherwise. The Ascension
layer buys two to four more runs, not forty hours. What it must *not* do is buy
them by gating jokes.

The mechanism that actually delivers is the one Hamilton names: **"What was at
first a brute battle for survival becomes more of a performance."** The second
run is a different activity. Everything below serves that.

## 7.1 The rule ladder — cheap, and the main event

Ten rules. **One text file and one screen.** Unlocked cumulatively by finishing
the route; once unlocked, freely composable in any combination — the Hades Pact
model rather than the Slay the Spire ladder, because a physics comedy's replay
value is *which jokes a rule produces*, not incremental difficulty.

| Rung | Name | Rule | Cost |
|---|---|---|---|
| 1 | **LATE START** | Every zone clock −15 s | 1 line |
| 2 | **THIN PICKINGS** | Substance sources −30% per zone | 1 line in `_sources()` |
| 3 | **NO TOP-UP** | The Stopover no longer replaces lost geese | 1 line |
| 4 | **HARD WATER** | All `rest()` values halved | 1 line |
| 5 | **THE LONG WAY** | +1 required primary per leg | 1 line in `required_primaries()` |
| 6 | **STILL AIR** | No thermals on any flight | 1 line |
| 7 | **SHORT FLOCK** | You start with 5 | 1 line |
| 8 | **NO PASSENGERS** | The DD burns stamina like anyone else | 1 line |
| 9 | **HEADWIND** | Every flight is 15% longer | 1 line |
| 10 | **THE LATE DEPARTURE** | Winter catches you. Legs 5–7 get snow, ice and a shorter clock. | **new content — see below** |

**Nothing is ever gated.** Every substance, every zone, every joke, every Almanac
entry is available on rung 0. The ladder adds constraints and removes nothing.

Rung 10 is deliberately the odd one out: it is the home for the deferred Montreal
winter zone, and it is the one rung that costs real work. Ship rungs 1–9 first;
rung 10 is the first post-launch content drop, and it arrives with a reason to
exist rather than as a slot on a route.

## 7.2 What's cheap

| Thing | Cost | Value |
|---|---|---|
| The nine rule rungs + selector | 2 days | High. The main event. |
| **Second-run text layer** — briefings, results lines and hidden-objective punchlines gain a run-2+ variant | 1 day (a text file) | High and underrated. The leg-1 briefing card becomes one line: *"You know how this goes."* Makes replay feel authored rather than merely harder. |
| **The memorial** — a persisted array in `Prefs` of every goose lost across all runs, with leg and cause, printed in the credits | 0.5 day | Very high per byte. `WIN_CONDITIONS.md`'s "steal C's memorial, but only the free half." |
| **Per-rung bests** — fastest route, most chaos, most geese home | 0.5 day | Moderate. It's the only leaderboard slice a backendless single-player game can honestly have. |
| **Route-order shuffle** | — | **Rejected.** The route is the identity. A journey whose order changes is not a journey. |

## 7.3 What's expensive, and honestly named

| Thing | Cost | Verdict |
|---|---|---|
| **Photo mode** | 2 days | **Build it, late.** Freeze, free camera, hide all UI, F12. The design bible calls it non-negotiable and §10 says the discovery strategy is a nine-second clip. It is a replay driver *and* a marketing asset, which is a rare double. |
| **New zones** | 2–4 weeks each | Post-launch. Rung 10's winter zone is first. |
| **Branching routes** | 3–4 weeks | Post-launch, and only if the map screen proved itself. |
| **A second ending** | — | **Never.** One ending, four strings. Adding a second ending halves the weight of the first. |
| **New Game+ with a changed opening** | 1–2 weeks | No. The second-run text layer gets 80% of the felt value for 5% of the cost. |
| **The Pond hub (Option C)** | 2–4 months | Out of scope, and the door is still open: a route table, a run-summary payload and a persisted memorial are exactly the data a hub would read. |

## 7.4 What actually brings someone back

In descending order of confidence:

1. **They want to try it with a designated driver this time.** The DD is the most
   discoverable "I should have done that" in the game, and it only pays off in
   the last twenty minutes.
2. **They want to arrive with everyone.** 6/6 is the one line that says
   *statistically, this does not happen*, and that is a challenge phrased as an
   observation.
3. **They want to see what the Stopover is for.** A player who blows through leg 5
   without understanding it will understand it retroactively on flight 7.
4. **A rule rung they picked themselves.** STILL AIR + THIN PICKINGS is a
   different film.
5. **The Almanac has three pages they never found**, and finding them is a
   *reason to play differently*, never a reward for playing more.

## 7.5 What replay must never become

The JMIR warning in `WIN_CONDITIONS.md` §1.9 is the line: **the moment an Almanac
entry is something you earn rather than something you find, the educational layer
is homework.** No rung unlocks a substance. No rung unlocks a zone. No rung
unlocks a page. `unlocks.gd` does the right thing today; the discipline is not
touching it.

---

# PART 8 — THE BUILD PLAN

Ordered. **BUG** = a defect in shipped code. **NEW** = content or systems.
The nine true-regardless items from `WIN_CONDITIONS.md` Part 4 are marked `TR#n`
and are placed where they actually belong in the sequence.

> **Status stamp, 2026-08-04.** The plan below is unchanged — it is the plan, and
> the reasoning in it is still the reasoning. But several `NEW` rows have since
> shipped, and a reader who works down this list will otherwise rebuild things
> that exist. Checked against the source on this date:
>
> | Row | Status |
> |---|---|
> | **M1** (route, `FINAL_LEG`, `_finish_run()` branch) | **Shipped.** `main.gd` has an 8-entry `ROUTE` and `FINAL_LEG = 8`. |
> | **M2.1 / 2.2** (empty-flock soft-lock, `player_index`) | **Shipped** — see `HANDOFF.md` §2. |
> | **M2.3** (par cap) · **M2.4** (clock clamps) | **Shipped.** |
> | **M2.5** (suburbia `CANNONBALL` / `LAUNDRY` labels) | **Still broken** — `HANDOFF.md` §4 still lists it. |
> | **M2.6** (`R` restart confirmation) | **Shipped.** `main.gd` arms and confirms; `_tick_restart_prompt()`. |
> | **M3.1** (`TR#3` flock roster screen) | **Shipped.** `scripts/ui/flock_roster.gd`, built by `main.gd` and probe-able with `-- --probe --roster`. |
> | **M3.3** (`TR#5` wake up `scars`) | **Shipped.** `flock_state.gd::scar_bird()` is the writer; `migration.gd` and `main.gd` call it; `can_lead()`, the roster and the flight strip read it. |
> | **M4.x** (the ending) | **Shipped, differently.** The zone is `scripts/world/zone_finale.gd` + `prop_models_finale.gd`, not `zone_green.gd` + `green_residents.gd`. `main.gd::_finish_run()` calls `install()`. Build notes and the list of deviations from Part 5 are in `docs/FINALE_NOTES.md`. |
> | Bosses (rejected below in §2.10) | **A boss shipped anyway** — the Ranger, at leg 3, per `docs/BOSS_DESIGN.md` §2.1/§7.5. See `docs/BOSS_RANGER_BUILD.md`. §2.10's "the route has no boss and doesn't need one" is now a description of a decision that was reversed, not of the build. |
>
> Row 3.2 tells you to "update the README, which says it's unbuilt" about the
> Designated Driver. **The README no longer mentions the DD at all**, so there is
> nothing to update; that instruction is spent.

## M1 — MAKE IT WINNABLE · 1 day · the smallest change that ends the game

| # | Item | Kind |
|---|---|---|
| 1.1 | `ROUTE` array replaces `ZONE_ROTATION` in `main.gd:16`. Eight entries, `{leg, id, zone, variant, name, region, seconds, flight{…}}`. Fill all eight slots with the three built zones in a placeholder order. | NEW (data) |
| 1.2 | `_zone_script_for_leg()` stops using modulo; indexes `ROUTE` directly. | NEW |
| 1.3 | **`TR#6` — legs get names.** `zone_title()` reads `ROUTE[leg].name` and `.region`. `"LEG 4 — COTTAGE COUNTRY · MUSKOKA, ON"`. | NEW |
| 1.4 | **`TR#8` — use `Phase.RESULTS`.** In `_on_migration_done()`: `if Flock.leg > ROUTE.size(): Game.set_phase(Game.Phase.RESULTS)`. `game.gd:14` declares it, `music.gd:832` already branches on it, nothing has ever set it. | NEW |
| 1.5 | Placeholder finale: a black screen reading `YOU MADE IT` + `N OF 6 GEESE ARRIVED` + `[ENTER]`. | NEW |

> **After M1 the game can be won.** No new zone, no new art, no new system.
> Everything after this milestone is quality.

## M2 — DON'T HANG, DON'T LIE · 1 day · all bug fixes

| # | Item | Kind |
|---|---|---|
| 2.1 | **`TR#1` — zero geese is a soft-lock.** `migration.gd:162`: `Flock.emergency_reseat()` + warning instead of `_finish()`. | **BUG** |
| 2.2 | Promote `player_index` onto `Flock`. `lose_bird()` refuses it. Arrival guaranteed by construction (§6.2). | **BUG** |
| 2.3 | **`TR#2` — par outruns the achievable score.** Cap at leg 6's value; multiply by `route.par_scale`. | **BUG** |
| 2.4 | **Clock clamps disagree.** `mission.gd:1151` `[110,210]` vs `main.gd:315` `[100,220]`. Unify on `[110,210]`. | **BUG** |
| 2.5 | **Suburbia's bespoke labels.** Verify `CANNONBALL` / `LAUNDRY` actually match their `mission_defs` entries. Two primaries and two hidden objectives depend on it. | **BUG** |
| 2.6 | **`R` restart confirmation modal** (§6.6). In a finite run, an unconfirmed restart is a 45-minute landmine. | **BUG** |
| 2.7 | Delete the dead `objectives()` functions in all three zones (superseded by `mission_defs.gd`). | **BUG** (dead code) |

## M3 — THE FLOCK BECOMES VISIBLE · 2 days

| # | Item | Kind |
|---|---|---|
| 3.1 | **`TR#3` — flock roster screen.** Pause menu → FLOCK. Six rows: name, condition bar, intox, stamina, DD vest, scars. Also reachable from the results card. | NEW |
| 3.2 | **`TR#4` — DD assignment.** **Already shipped.** `flock_pen.gd` is in all three zones with a `[G]` prompt. **Update the README, which says it's unbuilt.** | — |
| 3.3 | **`TR#5` — wake up `scars`.** Three writers (§4.8), three read sites. | NEW |
| 3.4 | **Flight HUD roster strip** (§4.7). Non-optional — attrition is invisible without it. | NEW |

## M4 — THE ARRIVAL · 6 days · build the ending before any other new content

| # | Item | Kind |
|---|---|---|
| 4.1 | `zone_green.gd` — course geometry, sprinklers, dawn lighting. | NEW |
| 4.2 | `green_residents.gd` — fork of `flock_pen.gd::_build()`, ten behaviours, ~30 birds. | NEW |
| 4.3 | Survivors land, settle, name-float. DD stands with you. | NEW |
| 4.4 | The honk wave. | NEW |
| 4.5 | Playable credits — knockable slabs, roster/route/distance/Almanac payload, four verdict strings. | NEW |
| 4.6 | `mus_green` stem set via `tools/gen_music.py`. | NEW |
| 4.7 | Pause menu: FLY IT AGAIN / STAY. | NEW |

> This is the milestone the whole option rests on. If the honk wave doesn't land
> in a rough build, the option is wrong and you have spent a week finding out
> instead of two months.

## M5 — THE RUN SUMMARY AND THE MAP · 2 days

| # | Item | Kind |
|---|---|---|
| 5.1 | **`TR#7` — end-of-run screen.** It is the credits (M4.5). Mark TR#7 done there. | — |
| 5.2 | **`TR#9` — surface the Almanac harder.** Tally on the credits, as a fact, never a currency. `unlocks.gd` unchanged. | NEW |
| 5.3 | **The route map on the flight-end screen.** The flight already blocks for ENTER; draw a stylised eight-point coastline, a pin, `km flown / km to Florida`, who left the flock, and the leg's true fact. **No new screen.** | NEW |
| 5.4 | Per-leg `target_distance` from `ROUTE`, replacing the constant 2,000. | NEW |
| 5.5 | The memorial array in `Prefs`. | NEW |

## M6 — ATTRITION · 4 days · the balance milestone

| # | Item | Kind |
|---|---|---|
| 6.1 | `Flock.rest(leg)` reads the per-leg curve from `ROUTE` (§4.3). | NEW |
| 6.2 | Intox burn `0.012 → 0.045`. | NEW (tuning) |
| 6.3 | Drop-out: 3 s at zero, max 2 per flight, `lethal:false` on flight 1. | NEW |
| 6.4 | Honk-rescue: lowest-stamina targeting, +0.06, 8 s per-bird cooldown. | NEW |
| 6.5 | **PUT DOWN HERE** (§6.4), introduced on flight 6. | NEW |
| 6.6 | Per-flight hazard mix, spawn interval, thermal share, sky and ground colour from `ROUTE`. | NEW |
| 6.7 | `tools/flight_harness.gd` — three archetypes × 200 runs, survivor distribution (§4.9). | NEW (tooling) |

> **Gate:** do not proceed past M6 until the harness reports careful ≥5,
> typical =4, reckless ≤2, floor 1, modal first loss on leg 4.

## M7 — THE CHEAP LEGS · 6 days

| # | Item | Kind |
|---|---|---|
| 7.1 | `zone_strip_mall.gd` gains `variant`; branch `_environment` / `_sources` / `_props` / `_people`. | NEW |
| 7.2 | **Leg 1 — The Retention Pond.** Variant `pond`. Three substances. 240 s. | NEW |
| 7.3 | **Bread.** A `.tres` plus the FULL state and the HUD line. | NEW |
| 7.4 | **Leg 7 — The Truck Stop.** Variant `truckstop`. Night, rain, four substances, rigs that leave. | NEW |
| 7.5 | **Flight 7 — The Interstate.** Rain, headlights below, the 20-second opening, the HUD dismantle. | NEW |
| 7.6 | `mission_defs` entries for `pond` and `truckstop`. (`_generic()` covers them until then, so both legs are playable the day the geometry exists.) | NEW |

## M8 — THE STOPOVER · 4 days

| # | Item | Kind |
|---|---|---|
| 8.1 | `zone_cottage.gd` gains `variant`; `refuge` raises `WATER_Y`, strips the buildings, adds cattails. | NEW |
| 8.2 | ~40 NPC geese — **the same spawner leg 8 uses.** Build once, here. | NEW |
| 8.3 | The birdwatcher. | NEW |
| 8.4 | `mission_defs` `stopover`: 4 primaries (2 required), 4 bonuses, `slept_on_it` and `not_a_rest_stop`. | NEW |
| 8.5 | The top-up-to-three rule. | NEW |

## M9 — LEG 6 · 8 days · the only new geometry, and the cut candidate

| # | Item | Kind |
|---|---|---|
| 9.1 | `zone_corn.gd` — plane, MultiMesh corn, stubble, silo, farmhouse, bales, trucks, scarecrow, farm dog. | NEW |
| 9.2 | The combine — pathed kinematic body that wrecks props and punts geese. | NEW |
| 9.3 | Six substances. | NEW |
| 9.4 | `mission_defs` `corn`: 6 primaries, 4 bonuses, 2 hidden. | NEW |

## M10 — REPLAY AND POLISH · 4 days

| # | Item | Kind |
|---|---|---|
| 10.1 | Rule rungs 1–9 + main-menu selector + per-rung bests. | NEW |
| 10.2 | Second-run text layer. | NEW |
| 10.3 | **EASY FLYING** accessibility toggle, changeable mid-run (§8.5). | NEW |
| 10.4 | Zone clock multiplier setting (×0.75 / ×1.0 / ×1.5). | NEW |
| 10.5 | Photo mode. | NEW |
| 10.6 | Update `README.md` — DD, flock pen, and the loop description are all stale. | — |

## 8.5 The accessibility copy, verbatim

Settings → **EASY FLYING**. Changeable at any time, mid-run, without restarting.

> **Geeked Geese is meant to be a mess. The flights are where the mess costs you
> something, and that is on purpose. If they are getting in the way of the mess,
> turn this on — the flights get forgiving and nothing else changes.**
>
> *Halves stamina drain · doubles thermal size · geese never drop out.*

Two rules, both from §1.7:

1. **It never touches the ending.** Same credits, same roster, same honk wave.
2. **The save is never branded.** No "arrived on Easy Flying." No asterisk
   anywhere.

## 8.6 The cut list, in the order I'd cut

| Cut | Saves | What you lose |
|---|---|---|
| **Leg 6 becomes a `suburbia` variant** (Carolina subdivision, sprinklers, alligator) instead of the corn field | 4 days | The ground-is-dangerous inversion. The route still works; leg 6's peak gets softer. **This is the intended cut.** |
| **Photo mode** | 2 days | A marketing asset and a replay driver. Ship without it, add it in the first patch. |
| **Rule rungs → a flat 3-rung ladder** | 1 day | Composability. Keep rungs 1, 4 and 7. |
| **Second-run text layer** | 1 day | A lot of charm for very little money. Cut last. |
| **The scars system** | 0.5 day | `TR#5`. Cheap enough that cutting it is a false economy. |
| **Leg 1's bread** | 1 day | The best 90 seconds in the game. **Do not cut this.** |
| **The Stopover** | 4 days | **Do not cut this.** The rest beat is load-bearing for the whole curve, and it is the only heal in the back half. Without it the attrition numbers in Part 4 are wrong. |

## 8.7 Total

| Milestone | Days |
|---|---|
| M1 winnable | 1 |
| M2 bugs | 1 |
| M3 flock visible | 2 |
| M4 the arrival | 6 |
| M5 summary + map | 2 |
| M6 attrition | 4 |
| M7 cheap legs | 6 |
| M8 the stopover | 4 |
| M9 leg 6 | 8 |
| M10 replay + polish | 4 |
| **Total** | **38 working days ≈ 7.5 weeks** |
| **With the intended cut (M9 → variant)** | **34 days ≈ 6.5 weeks** |

---

# PART 9 — WHAT THE CAMPAIGN DOES WITH THE EDUCATIONAL LAYER

## 9.1 The three rules, restated because they are load-bearing

1. **Never interrupt fun with text.** Zero mid-gameplay popups. The campaign adds
   none.
2. **Facts go where the player is already stopped.** The campaign creates seven
   new such places — the flight-end map screens — and puts one fact on each.
3. **The Almanac unlocks by encounter, never by currency.** `unlocks.gd` already
   does this. The campaign does not touch it.

## 9.2 What the campaign adds

**Eight route facts, one per leg**, each attached to the real geography of that
leg and shown on the flight-end map screen where the player has already stopped
moving. This is genuinely new educational content, it costs a text file, and it
is what makes the route *a real flyway* rather than a list of place names.

| Leg | Fact | Note |
|---|---|---|
| 1 | **Retention ponds.** Stormwater ponds are a modern human-made habitat and a large part of why some Canada geese stopped migrating at all — mown grass to the water's edge is close to ideal goose habitat. | The zone is the fact. |
| 2 | **"Canada goose," not "Canadian goose."** *Branta canadensis* — named for the place, not the nationality. | Already the design bible's first codex unlock. Keep the running gag: any NPC who says "Canadian goose" gets attacked on sight. |
| 3 | **The moult migration.** Non-breeding and failed-breeding Canada geese fly **north** in summer, sometimes over a thousand kilometres, to moult where food is plentiful and predators are fewer. Geese genuinely do fly the wrong way. | Fires on the wrong-way flight, retroactively justifying the joke. The best fact in the set. |
| 4 | **Flightless for six weeks.** Geese moult their flight feathers all at once and cannot fly for about a month and a half. The design bible's molting-season zone is here as a fact instead, because it cannot honestly be a leg. | |
| 5 | **Stopover ecology.** Migration is not one flight; it is hops between staging areas where birds refuel. For most migrants, time spent refuelling exceeds time spent flying. | |
| 6 | **Waste grain.** Corn stubble is a major fuel source for migrating geese, and the twentieth-century spread of corn agriculture measurably changed where North American geese migrate and winter. | The bible's fermented-grain idea, told straight. |
| 7 | **Power lines.** Collision with transmission lines and towers is a significant, documented cause of death for large birds — which is why bird diverters and marker balls exist on lines near wetlands. | Fires on the Interstate. The game has been killing you with wires for seven legs and only now says why they're there. |
| 8 | **Golf courses.** Short grass, open sightlines, standing water, no hunting. Golf courses are close to perfect goose habitat, which is why the "goose problem" on golf courses is a problem golf courses created. | The last fact in the game and the funniest true one. |

Plus one new substance entry: **bread**, unlocked in the first ninety seconds.

## 9.3 The dispute, and why it goes on the first page

The design bible's §7 rule — *"Teaching a kid that a fun fact is contested is
worth more than the fact"* — gets its best application on the very first Almanac
unlock.

The bread entry says: bread has little of what waterfowl need, and a bread-heavy
diet is associated with malnutrition and with **angel wing**, a wing deformity in
growing birds. **And then it says that the specific causal link between bread and
angel wing is not settled** — it's widely repeated, the underlying nutritional
mechanism is plausible and partly supported, and the direct evidence is thinner
than the internet's confidence about it. Feeding bread to waterfowl is still a
bad idea for reasons that don't depend on the disputed part.

That is the reindeer-and-fly-agaric treatment applied to the first thing the
player ever unlocks, and it sets the register for the whole codex.

## 9.4 Does completing the Almanac affect the ending?

**No. Decisively, and here is why.**

1. **The JMIR warning is the binding constraint.** The moment a true fact is
   something you *earn* rather than something you *find*, the educational layer
   becomes homework and gamified tedium measurably reduces motivation below the
   ungamified baseline. Tying the ending to codex completion is exactly that
   conversion.
2. **The ending has one axis and it must stay one axis.** The content of the
   ending is who arrived. Adding a second axis dilutes the first — six geese and
   sixteen pages competing for the same three minutes means neither lands.
3. **`unlocks.gd` already gates nothing**, and `WIN_CONDITIONS.md` true-regardless
   #9 says the discipline is to leave it alone.

**What the ending does instead** is *notice*, in the credits, as a fact:

> *"You found 13 of 16. You never touched the toad."*

No percentage. No bar. No "completion". If the player found all sixteen, the line
becomes:

> *"You found all sixteen. Every single one. There is no achievement for this and
> there is not going to be."*

That is the correct relationship: **the game notices, and declines to reward
you.** It costs two strings and it is funnier than a trophy.

## 9.5 The Goose Brain across the campaign

The neurotransmitter HUD is unchanged and is never explained. Two campaign-level
notes:

- **It disappears at leg 8** along with everything else. The last forty-five
  minutes were spent reading four sloshing fluids in a cutaway skull; the ending
  takes them away without comment. That absence is the loudest thing the HUD ever
  does.
- **It never appears on the flight.** It already doesn't. Keep it that way — the
  flight is where the bill arrives, and a serotonin bar during the bill would
  turn a consequence into a readout.

---

# APPENDIX A — EVERY CODE TOUCH-POINT

| File | Change | Milestone |
|---|---|---|
| `scripts/core/main.gd:16` | `ZONE_ROTATION` → `ROUTE` | M1 |
| `scripts/core/main.gd:163` | `_zone_script_for_leg()` — drop the modulo, pass `variant` | M1 |
| `scripts/core/main.gd:302` | `_on_migration_done()` — terminal branch to `Phase.RESULTS`; `rest(leg)` | M1, M6 |
| `scripts/core/main.gd:315` | clamp `[100,220]` → `[110,210]` | M2 |
| `scripts/core/main.gd:338` | `gg_restart` → confirmation modal | M2 |
| `scripts/core/main.gd:205` | `zone_title()` from `ROUTE` | M1 |
| `scripts/core/game.gd:14` | `Phase.RESULTS` finally set | M1 |
| `scripts/core/game.gd:160` | `new_run()` = "start the flyway" | M1 |
| `scripts/core/flock_state.gd` | `player_index`, `rest(leg)`, `lose_bird` guard, `emergency_reseat()`, `joined_at_leg`, `cause`, `lost_at_leg` | M2, M6 |
| `scripts/core/mission.gd:1124` | par cap + `par_scale` | M2 |
| `scripts/core/mission.gd:247` | `required_primaries()` honours `route.required_override` | M7 |
| `scripts/core/mission_defs.gd:62` | `for_zone()` gains `pond`, `stopover`, `corn`, `truckstop` | M7–M9 |
| `scripts/migration/migration.gd:20` | `TARGET_DISTANCE` → per-leg | M5 |
| `scripts/migration/migration.gd:162` | empty-flock branch | M2 |
| `scripts/migration/migration.gd:351` | `_rally()` → stamina rescue | M6 |
| `scripts/migration/migration.gd:433` | intox burn `0.012` → `0.045` | M6 |
| `scripts/migration/migration.gd:506` | `_tick_world()` reads per-leg hazard mix | M6 |
| `scripts/migration/migration.gd:749` | `_tick_hud()` → roster strip | M3 |
| `scripts/migration/migration.gd:764` | `_finish()` → map screen + fact + HUD dismantle | M5, M7 |
| `scripts/world/zone_strip_mall.gd` | `variant`; delete `objectives()` | M2, M7 |
| `scripts/world/zone_suburbia.gd` | label fixes; delete `objectives()` | M2 |
| `scripts/world/zone_cottage.gd` | `variant`; header comment says LEG 3 | M2, M8 |
| `scripts/world/flock_pen.gd` | fork → `green_residents.gd` | M4 |
| `scripts/ui/results_screen.gd` | roster button; `par_scale` display | M3 |
| `scripts/ui/pause_menu.gd` | FLOCK, FLY IT AGAIN / STAY, EASY FLYING | M3, M4, M10 |
| `scripts/core/prefs.gd` | `memorial`, `ascension_rungs`, `easy_flying`, `clock_scale`, per-rung bests | M5, M10 |
| `scripts/core/music.gd:65` | stems for `pond`/`stopover`/`corn`/`truckstop`/`green` | M4, M7–M9 |
| **new** `scripts/world/zone_corn.gd` | leg 6 | M9 |
| **new** `scripts/world/zone_green.gd` | leg 8 | M4 |
| **new** `scripts/world/green_residents.gd` | leg 8 | M4 |
| **new** `data/substances/bread.tres` | leg 1 | M7 |
| **new** `tools/flight_harness.gd` | balance verification | M6 |

# APPENDIX B — THE NUMBERS THAT NEED A PLAYTEST

Everything else in this document is a decision. These six are guesses with
reasoning attached, and they are the ones to change first.

| Number | Value | Where | What breaks if it's wrong |
|---|---|---|---|
| `intox_burn` | **0.045** | `migration.gd:433` | Too low: nobody ever drops out, the ending grades nothing. Too high: the whole flock dies on flight 4 and the back half is empty. **The single most important number in the campaign.** |
| Drop-out grace | **3.0 s** | new | Too short: losses feel arbitrary. Too long: the honk-rescue trivialises attrition. |
| `rest()` back-half values | **0.40 / 0.28** at leg 6 | `ROUTE` | Too generous and attrition never compounds; too lean and leg 7 is unflyable. |
| Stopover top-up floor | **3** | `ROUTE` | Too high and it forgives recklessness; too low and the back half has no flock. |
| Leg 7 required primaries | **5 of 6** | formula | The likeliest place the mission system feels unfair. Drop to 4 if leg 7's primaries can't be written without chemistry. |
| Flight 7 length | **130 s** | `ROUTE` | It's the climax; if it drags it's the worst beat in the game instead of the best. |

---

## Sources

- [Video Game Level Design and Difficulty — Stepico](https://stepico.com/blog/video-game-level-design-and-difficulty-how-to-challenge-players-without-losing-them/)
- [Pacing — The Level Design Book](https://book.leveldesignbook.com/process/preproduction/pacing)
- [Gameplay Fundamentals Revisited: Harnessed Pacing & Intensity — Mike Lopez, Game Developer](https://www.gamedeveloper.com/design/gameplay-fundamentals-revisited-harnessed-pacing-intensity)
- [Single Player Level Design Pacing and Gameplay Beats — Pete Ellis, World of Level Design](https://www.worldofleveldesign.com/categories/wold-members-tutorials/peteellis/level-design-pacing-gameplay-beats-part2.php)
- [Game Design Theory Applied: The Flow Channel — Game Developer](https://www.gamedeveloper.com/design/game-design-theory-applied-the-flow-channel)
- [Rest Site — Slay the Spire Wiki](https://slay-the-spire.fandom.com/wiki/Rest_Site)
- [Nintendo's Four Step Stage Design — Nintendo Life](https://www.nintendolife.com/news/2015/03/video_nintendos_four_step_stage_design_is_why_you_love_super_mario_games_so_much)
- [Teaching Game Mechanics: A Hierarchy of Learning — Josh Bycer, Game Wisdom](https://game-wisdom.com/critical/teaching-game-mechanics)
- [How Video Games Introduce Their Mechanics — Pause Button](https://pausebutton.substack.com/p/how-video-games-introduce-their-mechanics)
- [When a Game Feels Like a Journey — SUPERJUMP](https://www.superjumpmagazine.com/when-a-game-feels-like-a-journey/)
- [Let's Study Half-Life 2, Pt 5 — Intermittent Mechanism](https://intermittentmechanism.blog/2018/04/28/lets-study-half-life-2-pt-5/)
- [The Art Of Endings: Tales Of Ending A Game — Game Informer](https://gameinformer.com/b/features/archive/2014/04/09/the-art-of-endings-tales-of-ending-a-game.aspx)
- [The end of your game NEEDS denouement — Gnome Stew](https://gnomestew.com/the-end-of-your-game-needs-denouement/)
- [Where Credit Is Due – Video Game Credits That Innovate — Game Informer](https://gameinformer.com/b/features/archive/2016/11/10/where-credit-is-due-video-game-credits-that-innovate.aspx)
- [Video Games Are Better The Second Time You Play Them — Kotaku](https://kotaku.com/video-games-are-better-the-second-time-you-play-them-1786856653)
- [Replay Value — TV Tropes](https://tvtropes.org/pmwiki/pmwiki.php/Main/ReplayValue)
- [Hades Pact of Punishment: Heat, modifiers and rewards — RPG Site](https://www.rpgsite.net/feature/10287-hades-pact-of-punishment-heat-modifiers-and-how-to-maximize-your-rewards)
- [Allow difficulty level to be altered during gameplay — Game Accessibility Guidelines](https://gameaccessibilityguidelines.com/allow-difficulty-level-to-be-altered-during-gameplay-either-through-settings-or-adaptive-difficulty/)
- [The Small But Important Change 'Celeste' Made to Its Assist Mode — Vice](https://www.vice.com/en/article/celeste-assist-mode-change-and-accessibility/)

*Prior research, not repeated here, is in `WIN_CONDITIONS.md` Part 1.*
