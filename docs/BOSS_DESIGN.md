# GEEKED GEESE — BOSS ENCOUNTERS

### Three antagonists for a bird that cannot fight

*Build-ready. `CAMPAIGN_SPEC.md` cut all three of these in §2.10 with one line
each. It was right to, on the evidence it had. This document is the evidence it
didn't have. Where I disagree with that spec I say so explicitly and show what
it does to the curve; where I agree, I leave it alone.*

> **Status stamp, 2026-08-04.** §7.5's recommendation was taken: **the Ranger's
> leg 3 introduction is built and wired.** `scripts/world/boss_ranger.gd` +
> `scripts/world/boss_ranger_visual.gd`, spawned from `main.gd::_load_zone()`
> when `Flock.leg == 3`, probe-able with `-- --probe --boss`. What shipped, and
> the six places it deliberately departs from this spec, are recorded in
> **`docs/BOSS_RANGER_BUILD.md`** — read that before treating anything in §2.1
> as a description of the code. **Still unbuilt:** the Ranger's leg 6 exam (leg 6
> does not exist as a bespoke zone), BIG DOWN in its entirety, and the Zamboni
> (correctly — §2.3 defers it to a winter zone that does not exist).

---

## 0. The one page

| | |
|---|---|
| **What a boss is here** | A rule imposed on the sandbox, wearing a body. Never a health bar, never a damage race. |
| **How many ship** | **Two.** The Park Ranger and BIG DOWN. |
| **The Zamboni** | **Not a boss.** It is a prop archetype, and the archetype already ships as leg 6's combine. Full spec in §2.3 for when winter exists. |
| **Where they sit** | Ranger: inside leg 3 (45 s) and inside leg 6 (60 s). BIG DOWN: the back half of leg 7 (75 s + a 15 s rest). |
| **What it does to the curve** | Peaks in the back half go 7 → 8 → 8 → **9**, growing *and* tightening. Both of `CAMPAIGN_SPEC.md`'s rest beats survive. Leg 8 is untouched. |
| **The climax stays where it is** | **Flight 7.** BIG DOWN is the last laugh, not the climax. It supplies flight 7's weather. |
| **Hard cap** | **No encounter exceeds 90 seconds.** |
| **Fail state** | `HAZED` (Ranger) and `LOCKED OUT` (BIG DOWN). Both cost seconds and a combo chain. Neither can end a run. One new permanent-loss channel, `RELOCATED`, bounded to one bird once per run and fully preventable. |
| **Build first** | **The Ranger**, in Suburbia, which is already built. Two days to know whether a non-combat boss works in this controller at all. |
| **Total cost** | Ranger ≈ 6.5 days · BIG DOWN ≈ 11 days · reduced BIG DOWN ≈ 3.5 days. |

**The single most important claim in this document:** the three bosses were cut
because they were imagined as *fights*. None of them needs to be. The goose
already has four verbs that no other game's protagonist has, and each of the two
surviving encounters is built entirely out of verbs that shipped months ago.

---

# PART 1 — THE DESIGN PROBLEM, STATED HONESTLY

## 1.1 The goose cannot fight, and that is not the problem

The goose has no attack. It has:

| Verb | Where it lives | What it can do to an antagonist |
|---|---|---|
| **Honk** | `honk.gd` — `_ring`, `_pressure_wave`, `_shove` | Shoves props. Startles `NpcHuman` into `FLEE_SPEED`. Rallies flock in flight. The bible promises it shatters glass and the game has never delivered on that. |
| **A body at speed** | `goose_controller.gd::_resolve_collisions` — `force = speed` | Breaks anything in `chaos_prop`. This is the whole combat system and it is one function. |
| **Sixteen control mutations** | `Subs.mods` | Changes what the *player* can do, never what the world can take. |
| **Indirect agents** | `cat.gd` + `aggro_cats` | The one true summon. Catnip is artillery. |
| **Scale** | `_tick_size` — 0.35× to 2.8× | A traversal tool, per the bible's §11. |
| **Altitude** | `State.FLY`, with a run-up requirement | The single largest asymmetry the goose has against anything on the ground. |

Nothing in that list reduces a number on an enemy. Trying to build one would
require a damage system, an enemy health model, a hit-reaction system and an
animation system — four things this project does not have and, per the README's
own gate, should not build.

**The problem is not that the goose can't fight. The problem is that "boss" is a
word that arrives pre-loaded with a health bar.** Strip that and the structural
job of a boss is still available.

## 1.2 What a boss is *for*, structurally

The research converges hard, and it converges on something this game can do.

Mike Stout's canonical breakdown frames the two jobs as **a test** and **a
story**, and adds the line that matters most for a physics comedy:

> **"A boss is a reward from the game designer to the player. For a short time,
> the player gets to take a break and do something new!"**
> — [Boss Battle Design and Structure, Game Developer](https://www.gamedeveloper.com/design/boss-battle-design-and-structure)

Yu-kai Chou's framing of the same thing is blunter and is the sentence I keep
coming back to:

> **"A boss fight is the moment the game asks the player: 'everything you've
> learned — prove it now.'"**
> — [Mastering the Boss Fight, Yu-kai Chou](https://yukaichou.com/advanced-gamification/game-design-technique-14-mastering-the-boss-fight/)

And the exam model, from the same Stout material and echoed in
[GameDesignSkills' boss guide](https://gamedesignskills.com/game-design/game-boss-design/):
before you design anything, **list the skills the boss tests**, then build attacks
that test *those* skills. GameDesignSkills is also explicit that this doesn't
require combat — *"boss fights have two main purposes (which can also be
combined)"* and puzzle/timing/environmental encounters qualify.

## 1.3 The reference implementation is a game about a goose

*Untitled Goose Game*'s finale is the exact manoeuvre this project needs and it
contains no combat, no health bar and no new mechanic. You steal a bell and carry
it home, and **the bell takes your verbs away** — move your neck or press the honk
button and it rings and summons everyone.

> *"Every single thing you've done up until grabbing the bell has been a lesson,
> and you have to keep all of it in mind in order to make your way back through
> the village."*
> — [AV Club, on Untitled Goose Game's final puzzle](https://www.avclub.com/with-its-final-puzzle-untitled-goose-game-becomes-a-ma-1838423723)

The finale *"demands mastery of previously learned skills under increased
pressure."* It is a boss in every structural sense and it is made of subtraction.

The second reference is the **alpha antagonist** — Mr. X, the Nemesis, the SA-X,
the Alien. Josh Bycer's account of why it works:

> *"Once introduced, Mr. X and the xenomorph actively go hunting for the player.
> The knowledge that they could be attacked at any time by something that can't
> be stopped is a powerful motivator."*
> — [The Horrific Appeal of Mr. X, Game Wisdom](https://game-wisdom.com/critical/mr-x)

Crucially, the alpha antagonist is *not permanently defeatable* — which is
exactly right for a game where you can't defeat anything — and it must **leave**.
*Alien: Isolation*'s "menace gauge" pushes the creature into **backstage mode**
once its presence crosses a threshold, giving the player relief, and its sweep
parameters have *"constrained durations and distance limits, preventing infinite
pursuit"*
([Revisiting the AI of Alien: Isolation](https://www.gamedeveloper.com/design/revisiting-the-ai-of-alien-isolation)).
That is the mechanism that lets a pursuer coexist with `CAMPAIGN_SPEC.md`'s
saw-tooth: **a pursuer that goes away on a timer is a spike, not a plateau.**

Third: mechanical comedy. The Polaris paper's definition —

> **"Mechanical comedy is when players are *performing* the joke, rather than
> reading or hearing it."**
> — [Mechanical Comedy In Games, Polaris Game Design Retreat](https://polarisgamedesign.com/2025/mechanical-comedy-in-games/)

— and its component list reads like a spec sheet for these encounters:
*emergent physics*, *props*, *dramatic irony*, *indirect control of independent
agents*, *limited verbs*. It also supplies the warning that governs every fail
state below: *"If failures feel random rather than player-caused, humor transforms
into frustration."*

## 1.4 The definition this document works from

> **A boss in Geeked Geese is a rule the sandbox does not normally have, given a
> body you cannot break, that arrives, takes something away, and leaves on a
> timer.**

Five consequences, all binding:

1. **No health bars.** Nothing in either encounter has hit points. The single
   readout that resembles one is argued for individually in §2.2.4 and it counts
   *up*, belongs to the enemy, and is a physical prop.
2. **The boss subtracts.** Every one of them removes an affordance the player has
   been relying on — the substance shelf, the ground, the score, the flock, the
   HUD, the sky. Addition is what a combat game does when it adds an attack
   pattern. Subtraction is what this game has instead.
3. **The boss is bounded in time and it leaves whether or not you were good.**
   The Level Design Book is unambiguous — *"any intense boss fight will feel like
   a slog after 10+ minutes"* — so the hard cap is **90 seconds**, and the exit
   condition is always a timer with an early-out for skill, never a timer *only*
   for skill.
4. **The boss is made of shipped code.** `NpcHuman`, `Cat`, `ChaosProp`,
   `SubstancePickup`, `flock_pen.gd`, `Juice`, `Mission.note()`. If an encounter
   needs a new system, the encounter is wrong.
5. **The boss enforces the leg's existing question, it does not add a new one.**
   `CAMPAIGN_SPEC.md` §1.3 established the campaign's governing rule: *"the
   campaign never adds a verb after leg 2. Every leg after leg 2 adds a CONTEXT
   that recombines verbs the player already has."* Bosses are the strongest
   possible form of that rule — a boss is a *reason* the leg's context matters.

## 1.5 Which of the three should not be a boss

**The Zamboni. Cut it as a boss; keep it as an archetype.** Full reasoning in
§2.3, but the short version is three-fold:

1. **It has no verb the game doesn't already own.** The Ranger tests altitude,
   concealment and the flock. BIG DOWN tests the honk, glass and the substance
   economy. The Zamboni tests *dodging a slow vehicle in a bounded space* — and
   `zone_corn.gd`'s combine (already budgeted, M9.2) does that better, because it
   is contextualised: it is harvesting, you are in its way, and it does not care
   about you. An antagonist that does not care about you is funnier than one that
   does.
2. **Its home was cut for good reasons that still hold.** `CAMPAIGN_SPEC.md`
   §2.10 deferred the Montreal winter zone on geography, premise (*"winter is what
   you are fleeing"*) and — decisively — because **ice friction is a controller
   change**, and the README's own rule is that the controller is the game. A boss
   whose arena requires special-casing ground friction risks the one thing that is
   good.
3. **An arena chase in a game with no combat is ninety seconds of running in a
   circle.** There is no reason to change direction, no resource to manage, no
   reason the loop is not the same on second 10 and second 80.

There is a genuinely excellent Zamboni idea and I have specified it in §2.3 so it
is build-ready when rung 10 exists. It is not a v1 boss.

---

# PART 2 — THE THREE ENCOUNTERS

---

## 2.1 THE RANGER

### 2.1.0 At a glance

| | |
|---|---|
| **Where** | **Inside leg 3 (Suburbia)** as a 45 s introduction, and **inside leg 6 (The Cut Corn)** as a 60 s exam. Two appearances, one boss, two phases. |
| **Absent from** | Legs 1, 2, 5, 7, 8. Every flight. The tutorial, both rest beats and the finale never see him. |
| **Intensity** | L3 zone 5 → **6** for 45 s. L6 zone 7 → **8** for 60 s. |
| **Fantasy** | You are a wild animal and somebody has been sent to *manage* you. He has a clipboard. He is not the dangerous one. |
| **Tests** | Leg 3: altitude — *"what's up there?"*, the leg's own stated question. Leg 6: concealment and open ground — *"what if the ground was the dangerous part?"*, the leg's own stated question. |
| **Fail state** | `HAZED`. Carried to the edge of the zone. −6 s, combo chain broken. Nothing else at leg 3; one active substance cleared at leg 6. |
| **New permanent loss** | `RELOCATED` — one bird, once per run, leg 6 only, entirely preventable. See §4.2. |
| **Build** | ≈ 6.5 days. Reuses `NpcHuman`, `Cat`, `ChaosProp`, `flock_pen.gd`. |

### 2.1.1 Who he is, and the joke that carries him

He is not a US-style park ranger. He is the true thing, which is funnier:
**municipal goose management.** Cities really do contract wildlife control to haze
Canada geese off parks, stormwater ponds and golf courses, and the real toolkit is
already a comedy sketch — a border collie, an air horn, a coyote decoy, a laser
pointer, and a clipboard for the population survey.

Hi-vis vest. Clipboard. A white pickup with a light bar and `CONSERVATION
SERVICES` on the door. A `Label3D` speech bubble that fires exactly four times per
appearance.

**His first line, ever, at leg 3, is:**

```
"...Canadian geese, approximately—"
```

`GEEKED_GEESE_DESIGN.md` §7.3 already established the running gag — *"any NPC who
says 'Canadian goose' gets attacked on sight"* — and made it the **first codex
unlock in the game**. The player has been primed for this since minute two. The
boss's introduction is therefore not an introduction, it is a punchline with a
pre-installed setup, and the correct player response is instantaneous and requires
no instruction at all.

That is the whole reason this encounter reads as comedy rather than as pressure.
He is not scary. He is *rude*, in a way the game taught you to punish.

### 2.1.2 The two-body structure

> **The Ranger is not the threat. The dog is.**

| | The Ranger | The dog (`PIPER`) |
|---|---|---|
| Speed | 2.4 m/s. Slower than a waddle. | 9.5 m/s in pursuit. The only thing in the game that outruns a goose on the ground. |
| What it wants | The clipboard. He is counting. | You. Entirely. Joyfully. |
| Vertical | None. Cannot climb, cannot reach a roof. | None. Cannot climb, cannot reach a roof. |
| Reacts to honk | Flinches, drops the clipboard, 1.8 s stun | **No.** A honk is what it came for. |
| Reacts to cats | No | **Yes.** Loses target for 3 s per cat. |
| Built from | `NpcHuman` + a state machine | `cat.gd`, forked. Two-tone faceted body, longer, a tail. |

This split does three things at once. It gives the encounter **two different
counters** so there is a choice. It makes the boss's *body* (the man) something
you can bully and its *threat* (the dog) something you can't, which is the shape
of every good non-combat antagonist. And it makes the funniest possible statement
about authority: **the dog is better at his job than he is, and it knows.**

### 2.1.3 Leg 3 — THE INTRODUCTION (45 s, intensity 6)

Fires at **T−100 s** on the zone clock (i.e. 80 s in). No card, no popup — the
rule from `GEEKED_GEESE_DESIGN.md` §7.1 is absolute.

**The arrival.** The truck pulls into the cul-de-sac. Two door slams. An air horn
— one blast, using the existing honk pressure wave with a different pitch, which
knocks over anything light in a 9 m radius, *including things you had lined up*.
Then the line, in a `Label3D` over his head.

**Moment to moment, 45 seconds:**

| Beat | s | What is happening | What the player does |
|---|---|---|---|
| Arrival | 0–4 | Truck, horn, "Canadian geese, approximately—" | Almost always: honks at him. This is correct and is rewarded. |
| The sweep | 4–30 | He walks a fixed route through the cul-de-sac **collecting substance sources into a bin on the truck.** ~1 pickup every 5 s. The dog quarters the ground between him and you. | Get to the sources first, or get him to drop the bin. Or go up. |
| The dog closes | 12–40 | Piper acquires you whenever you are on the ground and within 22 m. It is faster than you. | **Get off the ground.** Roof, trampoline, fence, minivan roof, a tree. Anything above 2.2 m. |
| Departure | 40–45 | He writes a number down, gets in the truck, leaves. The bin goes with him. | Nothing. He leaves regardless. |

**The subtraction:** he takes the shelf. Any source he bins is gone for the rest
of the leg. A player who ignores him entirely arrives at the second half of
Suburbia with **five of the sixteen sources missing**, which is the first time in
the run the sandbox has ever gotten *smaller*.

**The counter, three ways, all shipped:**

1. **Go up.** Neither of them has a Y axis. The roof, which `get_up_there`
   (leg 3's own primary) has been sending you to look for, is now a *sanctuary*.
   `ascension` — the hidden objective where the trampoline turns out to be the
   stairs — becomes an escape route. **The Ranger is the reason leg 3's verticality
   matters.** He adds nothing; he charges rent on what the leg already taught.
2. **Honk him.** A direct honk inside `RADIUS` (7.5 m) flinches him: he drops the
   clipboard as a `ChaosProp`, stops sweeping for 1.8 s, and — the joke — **has to
   pick it up again**, losing four more seconds. The clipboard's `Label3D` face
   reads `CANADIAN GEESE .......... 6` and the number is live.
3. **Cats.** Suburbia has cats. Catnip has always turned them into artillery
   (`aggro_cats`). A frenzied cat that targets Piper instead of a prop is the best
   emergent solution in the encounter and nothing tells you it works.

**Fail state — `HAZED`.** Piper catches you. There is no damage, no ragdoll, no
loss. The screen does a `Juice.hitstop(0.04, 0.4)`, a feather burst, and **you are
carried, in the dog's mouth, at speed, to the mouth of the cul-de-sac and put
down.** Six seconds of no control, your combo chain is gone, and the dog trots back
looking extremely pleased. `Game.score(0, "GOOD DOG", pos)`.

That is a **rung-1 punishment on Bycer's hierarchy** — time only — and it is the
funniest possible version of one. The player is not hurt. The player is
*humiliated*, which in a comedy is a reward with the sign flipped.

### 2.1.4 Leg 6 — THE EXAM (60 s, intensity 8)

Leg 6 is a half-cut corn field with standing corn on one side, stubble on the
other, and a **combine working the boundary**. `CAMPAIGN_SPEC.md` §2.6 calls its
new idea *"cover, and a ground that is dangerous"* and notes that standing corn is
*"the only concealment in the game."*

**Concealment with nothing to hide from is scenery.** The Ranger is what makes
leg 6's central mechanic mean anything, and this is the strongest single argument
in this document for building leg 6 as the corn field rather than taking
`CAMPAIGN_SPEC.md` §8.6's intended cut to a Carolina subdivision.

He is there from the moment the leg starts. He does not arrive; you land in his
field.

**What is new at leg 6, and it is all subtraction:**

| Addition | What it removes |
|---|---|
| **The propane cannon** — a real bird-scaring device, on a 14 s timer, on the far edge | Removes *stillness*. Every 14 seconds a bang and a shockwave flush you out of whatever row you were hiding in. One `Timer`, one sound, one reuse of `_pressure_wave`. |
| **He searches** — he walks the rows. Standing corn hides you from him; it does not hide you from Piper, which is following its nose | Removes *safety*. Cover works against one of the two bodies. |
| **The combine is the clock** | Removes *the arena*. It is already cutting the field. Your cover shrinks for the whole encounter and nobody had to write a timer. |
| **The pen** — your flock is standing at the field edge and **he is walking toward it** | Removes *a bird*, if you let him. §4.2. |

**Phases, and they are the arena's phases, not his:**

| Phase | s | Standing corn remaining | The encounter |
|---|---|---|---|
| **1 — THE ROWS** | 0–20 | ~100% | You can lose him at will. Learn the two-body rule: hide from the man, run from the dog. Cannon fires at 14. |
| **2 — THE CUT** | 20–45 | 100% → ~35% | The combine has taken half the cover. Now hiding costs you position. He is closing on the pen. Cannon at 28, 42. |
| **3 — THE OPEN** | 45–60 | ~35% → ~10% | Stubble. Nothing to hide behind, a dog that is faster than you, and either you have taken the clipboard or a goose is walking to a truck. |

**The win, and it is not a defeat.** Honk the clipboard out of his hands, then
break it — into the combine, into the silo, into the pond. Any `ChaosProp` break
on it ends the encounter. He stands there for two seconds, gets in the truck,
and leaves. `Label3D`: `"...I'll come back next year."`

**This is the "kill sequence" beat** from Stout's eight-beat structure — a moment
where the boss is visibly finished and you get to enjoy it — and it contains no
violence and no death. Somebody's afternoon has been ruined. That is the register
the whole game is written in.

**Fail state — `HAZED`, escalated.** As leg 3, plus: he takes what you are on.
`Subs.actives` loses one entry, with the `Label3D` `"drop it."` That is a genuine
loss on a leg where the shelf is only six items deep and everything is tolerance-
worn, and it is still only time and resource — rungs 1 and 3 of the hierarchy,
never death.

**A bad player's leg 6.** They ignore him. They get hazed three times (18 seconds),
they lose a bird to `RELOCATED`, the corn gets cut, and at 60 seconds **he leaves
anyway** and they have 120 seconds of corn field left, unbothered, to make their
primaries. The encounter cannot trap anyone. It has an off switch and the off
switch is a clock.

### 2.1.5 The honest health-bar argument

There is exactly one readout in this encounter that resembles a health bar, and I
want it, and here is the case.

**The clipboard's face is a `Label3D` reading `CANADIAN GEESE .......... N`, and N
ticks up as he counts.** It is visible from across the zone because it is a giant
white rectangle held at chest height by a man in hi-vis.

It is not a health bar, on four counts:

1. **It counts up, and it belongs to him.** It is his progress, not his health.
2. **Reducing it is not how you win.** Taking it is. There is no state in which
   grinding the number down does anything.
3. **It is diegetic.** It is a prop in the world, not a UI element. It obeys the
   peripheral-vision rules in `DESIGN_MISSIONS.md` §7 by being *enormous and
   high-contrast*, which is the only way a world-space readout can obey them.
4. **It is the encounter's entire tutorial.** A player who has never seen the
   Ranger reads "a man is writing down how many of us there are" off one prop, with
   no text card, and knows both what he wants and what to take off him.

If it must go, the fallback is his `Label3D` line count, which is worse. Keep the
clipboard.

### 2.1.6 Why it's funny

- **The setup is six legs old.** "Canadian geese" is the first codex unlock in the
  game. He walks in and says it. That is a joke the *player* completes, which is
  the co-authorship the Polaris paper describes.
- **He is losing to a bird and to his own dog simultaneously.** Piper is
  competent, delighted and clearly management material. He is not.
- **The clipboard number is live.** It goes up. You are standing right there.
- **The best solution is illegal.** Setting a cat on a working dog is the single
  most on-brand thing this game can offer and nothing ever mentions it.
- **He comes back next year.** The victory line is an administrative threat.
- **`HAZED` is a carry, not a hit.** Being picked up in a dog's mouth and gently
  relocated 40 metres is not a punishment, it is a bit. The game's fifth-worst
  outcome is being *tidied away*.

---

## 2.2 BIG DOWN

### 2.2.0 At a glance

| | |
|---|---|
| **Where** | **The back half of leg 7.** The truck stop is unchanged and runs first. |
| **Leg 7 clock** | **230 s** (was 180). 110 s truck stop → the dock opens → ≤75 s tower → 15 s roof. Precedented: leg 1 is 240 s. |
| **Intensity** | Truck stop **4** (unchanged, the rest beat survives) → tower **8** → roof **2** → flight 7 **9**. |
| **Fantasy** | You are inside the building that the coats come from. You do not know what you are looking at. The player does. |
| **Tests** | The honk, which the game has taught since second ninety and has never once made load-bearing. Plus the substance economy under scarcity, and flight indoors. |
| **Fail state** | `LOCKED OUT`. A shutter comes down, you lose the shortcut, ~8 s. Nothing permanent. |
| **The boss** | A man in a suit who never touches you. He closes things. He is never defeated. He gets away. |
| **The payoff** | **Flight 7's weather.** The down goes up over the interstate and you fly through it. |
| **Build** | ≈ 11 days full, ≈ 3.5 days reduced (§7.3). |

### 2.2.1 Where it is, and why the geography works

A distribution centre with a glass office block on the front, off I-95 in
Georgia, at 3 a.m., in warm rain. **Next to a truck stop**, which is precisely
where distribution centres are.

This solves three problems at once:

1. **Geography.** `CAMPAIGN_SPEC.md` §1.4 made real flyway geography load-bearing
   and cut Montreal partly for it. A parka company's *headquarters* is in Toronto,
   which is leg 1–2 territory and far too early. A **distribution centre** is
   wherever the interstate is, which is exactly here.
2. **The satire lands harder in Georgia than in Toronto.** A company that sells
   arctic-rated parkas, running a warehouse in a place where it is 28 °C at three
   in the morning, is the joke telling itself. Nobody has to point at it.
3. **It costs one prop to set up.** The rigs at the truck stop — which
   `CAMPAIGN_SPEC.md` §2.7 already specifies as *launch pads, rides and hazards*
   on a timer — **are BIG DOWN trucks.** You have been climbing on them for a
   hundred seconds. The reveal is a decal on a trailer side, and the truck-stop
   identity gag ("ride one out of the lot and fly back") becomes **the way in**.

**The tower has been on the skyline since leg 6.** One lit box on the horizon
during flight 6 and the whole of leg 7, and nothing ever mentions it. This is the
Stopover manoeuvre from `CAMPAIGN_SPEC.md` §2.5 — put the image in the world
twenty minutes early so its arrival is a *return* rather than a first appearance.

### 2.2.2 The structure, and why the rest beat survives

`CAMPAIGN_SPEC.md` §1.2 correctly steals Slay the Spire's rule: a rest is
**guaranteed immediately before the boss**. Leg 7 is that rest, and this encounter
does not take it.

```
LEG 7 · 230 s

  0 ─────────────────────── 110      110 ──────────── ≤185      ≤185 ── ≤200
  THE TRUCK STOP                     THE TOWER                  THE ROOF
  intensity 4                        intensity 8                intensity 2
  quiet · 3am · rain · 4 subs        no subs · no flock         nothing at all
  rigs on a timer · humans asleep    75 s hard cap              15 s hard floor
  ← the rest beat, untouched         ← the last laugh           ← the rest before the peak
                                                                    ↓
                                                              FLIGHT 7 · 9
```

The rest beat did not move. A **second** one was added at `L7c`, immediately
before the summit, which is where Slay the Spire's rule actually points. The
truck stop's 110 seconds is still quiet, still nearly empty, still has the highest
primary requirement in the game keeping it from going slack.

**The dock opens at 110 s with no announcement.** The ground-floor lights come on
across the interstate. That is all. A player who does not go is fine — see §2.2.7.

### 2.2.3 Phase 1 — THE FLOOR (25 s, and it is the best 25 seconds in the game)

You get in through the loading dock, on a trailer or under your own power.

Inside is a warehouse. Dark, enormous, racked to the ceiling, and every rack holds
the same thing: **compressed white bales.** They are labelled with a fill-power
number and a lot code and nothing else.

There are no substances in here. There are no people. There is no music, only
the rain on a metal roof and the hum of the racking lights.

**And the goose is delighted.**

The bales are `ChaosProp`s with `mass_kg = 22`, a low `break_force`, and the
highest point value of any prop in the game. They are soft. They are bouncy. They
burst — and here is the entire satire, delivered by a particle system that shipped
months ago:

> **They burst into `Juice.burst(pos, Color(0.94, 0.94, 0.92), N, &"feathers")` —
> the same white feather burst the game has been spending on faceplants, wire
> strikes and `WAYNE IS DOWN` for six legs.**
>
> There are ten thousand of them in this room and they are inventory.

The player makes that connection. **The goose does not.** That is dramatic irony —
component 6 on the Polaris list — and it is the only way this material can be
handled in a comedy without the comedy dying. The goose is having the best time it
has had all run. The chaos counter is going berserk. The bales are trampolines.
Every point of it is horrible and **nobody says a single word about it.**

`CAMPAIGN_SPEC.md`'s ending rule is *"the comedy does not stop, the stakes do."*
This is the inverse and it is the one place the game earns it: **the comedy does
not stop; the meaning arrives underneath it.**

**Why the score must stay on.** I considered running the tower unscored, like leg
8. It is wrong. The horror is that it is *business as usual* — leg 7's grade is
substantially made of goose down, the results card reports it in the same typeface
as shopping carts, and nothing anywhere acknowledges it.

### 2.2.4 Phase 2 — THE ATRIUM (40 s): the honk becomes load-bearing

A glass office block bolted to the front of the warehouse. Four floors, an atrium,
a stair, and **one lit window at the top.**

> **`GEEKED_GEESE_DESIGN.md` §8: "Honk stuns, honk rallies the flock, honk
> shatters glass."**
>
> The game has delivered two of those three for eight months. This is the room
> the third one was written for.

**The mechanic.** Every pane is a `ChaosProp` with `break_force` tuned so a goose
at waddle speed bounces off it and **a honk inside `RADIUS` shatters it.** A goose
at flight speed also breaks it, which matters — see the substances section. The
only navigation verb that works reliably in a glass box is the one the player has
been mashing since the tutorial for fun.

That is the exam model executed exactly: **the boss tests the thing the game
taught first and never once tested.**

**The boss, and what he does.** He is a `NpcHuman` in a suit — different
proportions, a briefcase, no face beyond the faceted default. He has one
behaviour:

> **He closes things.**

Blinds. Shutters. Fire doors. The lift. He is not attacking you and he is not
capable of attacking you. He is a man retreating up his own building putting glass
between himself and a bird, and **the bird keeps honking.**

He has no health, no hit reaction, no stagger and no defeat state. **You never
catch him.** If you get within 4 m he simply takes the next stair. The encounter's
"attacks" are the shutters, and they are all subtraction:

| His move | Telegraph | What it removes | Counter |
|---|---|---|---|
| **Shutter** | A 0.9 s amber strobe on the frame + a servo whine | The direct route up. Adds ~8 s. | Honk it *before* it seats — the telegraph is a reaction window, per the readability rule in [GameDesignSkills](https://gamedesignskills.com/game-design/game-boss-design/). |
| **Blackout** | The floor lights cut, one bank at a time | Sightlines. The atrium goes to rim-light only. | Nothing. It is atmosphere and it lasts 6 s. |
| **Sprinklers** | A clunk, then water | Traction on the polished floor for 10 s | The only friction change in the game, bounded to one room, one phase, ten seconds. Cheap enough to be safe. |
| **The lift** | The doors close on him | The last shortcut | He is gone. Take the stair. |

**No health bar, and none is needed**, because the fight is not against him. It is
against the building, and the building's state is legible from thirty metres
because it is *made of glass and you can see which floors still have any.*

### 2.2.5 Phase 3 — THE WEATHER (10 s), and the reason this encounter exists

He reaches the top floor. It is glass on all six sides, and it is where the
finished coats are.

**You do not beat him. He leaves.** A car, a lift, a stair — it does not matter and
the camera does not follow. What happens instead:

The atrium is four storeys of open air with **the loose down stacked at the
bottom** and the rain coming down outside. Break the last curtain wall, and:

> **Every cubic metre of it goes up into the night over the interstate.**

One `GPUParticles3D` emitter, white quads, wind-driven, no collision. Snow, made
of goose, over four lanes of headlights in the rain, at three in the morning.

**And then it is on flight 7.**

`CAMPAIGN_SPEC.md` §2.8 specifies that flight 7's first twenty seconds *"contain
nothing. No obstacles, no thermals, no messages. Rain, wind, the formation, a
single held music stem."*

Change one thing:

> Rain, wind, the formation, a single held music stem, **and white down drifting
> past you in the dark for twenty seconds.**

That costs one emitter. It makes leg 7 and flight 7 into one continuous idea
instead of two adjacent events. It is the most beautiful thing in the game and it
is free, and it is the entire structural justification for BIG DOWN existing at
all: **the boss is not the climax. The boss gives the climax its weather.**

### 2.2.6 Phase 4 — THE ROOF (15 s, intensity 2)

The leg does not end when the down goes up. It ends fifteen seconds later.

You are on the roof of a distribution centre in Georgia, in the rain, in the dark,
alone, and the down is coming back down around you. There is nothing to do. There
is no prompt. The chaos counter has stopped moving because there is nothing left
to hit.

**In the far distance, across the interstate, is the truck stop, and the pen, and
your flock.** They are exactly where you left them.

Then the leg ends and you fly.

This is the "neutral beat between registers" that `WIN_CONDITIONS.md` §1.8 asks
for, it is the guaranteed rest immediately before the peak that Slay the Spire's
rule demands, and it costs a fifteen-second timer and a camera that is already
built.

**One more beat, and it is free.** In the atrium, if the player honks — and they
will, constantly, because it is the verb the room is made of — **nothing answers.**
Same cue, same code path, no response. Twenty minutes later, on the 18th green,
the player honks and forty geese honk back. `CAMPAIGN_SPEC.md` §5.2 already uses
this trick visually with the Stopover crowd. This is the audio version and it
costs nothing, and it makes the ending land harder for having been set up here.

### 2.2.7 The fail states, and what a bad player's tower looks like

**`LOCKED OUT`.** A shutter seats before you get through it. You lose the route,
you take the long way, ~8 seconds. That is the whole penalty. It is repeatable and
it never compounds.

**There is no way to lose the tower**, and there are three guarantees:

1. **The dock is optional.** A player who never crosses the interstate plays leg 7
   as `CAMPAIGN_SPEC.md` specified it, gets graded normally, and flies the
   Interstate without down in the air. They lose a set piece; they lose nothing
   mechanical. The Almanac entry still unlocks from the trailers in the lot.
2. **The 75-second cap is hard, and the spectacle is guaranteed.** If the last
   curtain wall is not broken by then, **he breaks it himself** — he backs into it,
   panicking, and the down goes up anyway.
3. **Skill decides authorship, not outcome.** A player who gets there in 20 seconds
   gets the hidden objective `MADE THE WEATHER` and the rest of the encounter as
   free time in a building full of the best props in the game. A player who never
   works out that honking breaks glass watches a man fall through a window.

This is the spectacle-versus-skill tension resolved in one branch. The finale
research is consistent that the climactic beat must be *"a memorable spectacle"*
([Bugnet, How to Design a Final Boss](https://bugnet.io/blog/how-to-design-a-final-boss))
and the DDA literature is consistent that adjustment must be invisible and must
never punish good play
([Game Developer, Dynamic Difficulty Adjustment](https://www.gamedeveloper.com/design/more-than-meets-the-eye-the-secrets-of-dynamic-difficulty-adjustment)).
A guaranteed spectacle with an authorship bonus satisfies both. **The building
fails whether or not you were good; only the question of who did it varies.**

### 2.2.8 Why it's funny

- **The goose does not know.** Every laugh in the warehouse is the player laughing
  at themselves for knowing.
- **The bales are the bounciest props in the game.** Physical comedy first,
  meaning second, and the order is not negotiable.
- **He is a man being hunted through his own building by a bird and he is losing.**
  He has a briefcase. He keeps it. He runs up four flights of stairs holding a
  briefcase in a suit, in Georgia, in August.
- **The honk is a demolition tool.** Eight months of a joke button, and here it
  takes out a curtain wall.
- **There is no boss music.** There is rain on a metal roof, a servo whine, and
  the sound of a lot of glass. `music.gd` gets one new stem and it is *quieter*
  than the truck stop's.
- **He gets away.** Nobody wins. It is three in the morning in Georgia and there
  is goose down all over the interstate and the geese have to be in Florida by
  Tuesday.

---

## 2.3 THE ZAMBONI — not a boss, and here is what it is

### 2.3.1 The verdict

**Cut as a boss. Kept as an archetype. Specified in full for Ascension rung 10.**

The reasoning is in §1.5. What follows is the part that makes this a promotion
rather than a deletion.

### 2.3.2 What ships in v1: `pathed_menace.gd`

`CAMPAIGN_SPEC.md` M9.2 already budgets *"the combine — pathed kinematic body that
wrecks props and punts geese."* Build that once, generically:

```
pathed_menace.gd  (CharacterBody3D on a Path3D / PathFollow3D)
  @export speed, path, punt_impulse, prop_damage, warning_sound, warning_lead_time
  @export erase_labels: Array[String]      # ← the Zamboni's one unique behaviour
  emits: menace_near(dist), menace_punt(goose), menace_wrecked(prop)
```

That is the combine at leg 6, and it is the Zamboni, and it is a street sweeper,
and it is a greens mower, and it is anything else the project ever wants. **The
Zamboni's design work is done. It just has nowhere to park.**

### 2.3.3 The good Zamboni idea, held for rung 10

Rung 10 (`THE LATE DEPARTURE`) is where the deferred Montreal winter content
lives. When it exists, the Zamboni gets one behaviour that no other pathed menace
has, and it is genuinely a boss-grade idea:

> **The Zamboni does not hurt you. It resurfaces.**
>
> A goose on ice leaves skid marks, cracks, scattered props, spilled everything.
> The Zamboni drives its route and **the ice behind it is clean.** Props are back
> on their pegs. Your marks are gone. And the chaos those things paid out is
> **deducted.**

That is a boss whose attack is **your score going down**, which is the only
"health bar" this game could ever honestly own — and it is pointed at the *player's*
number, not an enemy's. It is the exact inverse of every boss in the medium, it
requires no combat, and the counter-verbs are already in the game: get in front of
it, clog it (a shopping cart in the auger), get it stuck, make it crash. It is a
comedy about municipal maintenance versus a bird and the bird is not obviously
winning.

**Cost when the winter zone exists:** ≈ 3 days on top of `pathed_menace.gd` and
the arena. **Cost in v1:** zero, because it is not in v1.

### 2.3.4 Why not force it into the base route

Two failed attempts, recorded so nobody re-litigates them:

- **A Zamboni on the leg 1 retention pond.** The pond is not frozen. Freezing it
  requires the ice-friction controller change that `CAMPAIGN_SPEC.md` §2.10
  refused, in the tutorial, which is the worst possible place for it.
- **A greens roller on the 18th green.** It is a good gag and it is fatal. Leg 8
  must have no clock, no objective, no threat and no stakes. A machine that can
  punt you is a stake.

---

# PART 3 — THE SUBSTANCES IN BOSS FIGHTS

Sixteen control mutations is the product. A boss is where that system either
shines or collapses, and it collapses in exactly one way: **if one substance is
the answer, the encounter has a solution and the sandbox has a lock.**

The rule for every encounter below:

> **No encounter has a correct substance. Every encounter has a substance that
> looks correct and is not, and a substance nobody would pick that is.**

That is the trap/answer pairing, and it is the *twist* step of the four-step
kishōtenketsu structure `CAMPAIGN_SPEC.md` §1.3 cites: the same tool, looked at
from a new angle, on a later leg.

## 3.1 Availability, per encounter

| Encounter | Shelf | Sources during the encounter | Does the boss want you geeked? |
|---|---|---|---|
| **Ranger · leg 3** | All 16 | **Shrinking.** He bins ~5 of them. | **Yes, and it is the stake.** He is not punishing you for being high; he is taking away your ability to *get* high. A sober player at T−100 has the most to lose. |
| **Ranger · leg 6** | 6 (berries, coffee, grass, math, darts, whippet) | Unchanged, but tolerance has been climbing for six legs and doses are small | **Indifferent.** He does not react to your state at all, which is funnier and truer. |
| **BIG DOWN · truck stop** | 4, reduced dose | Yes, normal | — |
| **BIG DOWN · the tower** | **None. Zero. And the game does not say so.** | None | **Yes, catastrophically.** See §3.4. |

## 3.2 The Ranger at leg 3 — the trap is speed

| Substance | Read | Reality |
|---|---|---|
| **Double-Double** ☕ | 2× flap rate — the fastest way onto a roof | **Correct, and boring, and that is fine.** Every encounter needs one honest answer or it is a puzzle. The cost is `cannot_idle`: you cannot hold still on a roof. |
| **THE OVERCLOCK** (coffee + whippet) | `flap_mult 1.9`, `time_scale 0.45` | The best answer in the encounter, and it ends with you falling out of the sky next to a dog. |
| **Math** 📄 | *"Fastest thing in the game"* — outrun the dog | **The trap, and it is the best one.** You cannot turn. A cul-de-sac is fences. A goose that cannot turn runs in a straight line into a fence, at speed, next to a border collie. |
| **Percs** 💊 | `no_fall_damage`, cannot tumble — immunity | **A false answer.** `HAZED` is a carry, not a hit. Percs makes you unhurtable and slow, which is the exact wrong half of the problem. |
| **Grass** 🌿 | — | Slow, heavy, dopey, lowest chaos multiplier, longest duration. Nobody picks this on purpose. It is the correct floor of the shelf and it is hilarious when it happens by accident. |
| **Fly Agaric** 🍄 | Macropsia | **Genuinely great and nobody expects it.** At 0.35× you fit under a deck, into a downpipe, behind a garden gnome. At 2.8× the dog is a problem you can step over. Scale as a traversal tool, exactly as the bible's §11 promises. |
| **Catnip** 🌿 | Does nothing to you | **The intended emergent solution and the encounter's best joke.** Nothing hints at it. |

## 3.3 The Ranger at leg 6 — the reversal

Six substances, thin on purpose, and one of them flips polarity:

> **Math is the trap at leg 3 and the answer at leg 6.**
>
> *"Fastest thing in the game and you cannot turn."* A corn row is a straight
> line. It is the only place in Geeked Geese where "cannot turn" is a feature —
> you go down a row at full speed, the dog cannot corner into it fast enough, and
> the standing corn hides you from the man the whole way.

Twenty-five minutes apart, the same substance, the same mutation, opposite
verdicts, decided entirely by the shape of the ground. That is *set and setting*
— `GEEKED_GEESE_DESIGN.md` §4's principle — expressed as a boss encounter, and it
never says the words.

**And it decays.** The combine is cutting the rows. By phase 3 there are no
straight lines left and Math is a trap again.

| Substance | At leg 6 |
|---|---|
| **Math** | **The answer, until the corn is gone.** |
| **Whippet** | Seven seconds of slow-motion, then you fall out of the sky, in a field with a combine in it. High risk, spectacular payoff, entirely the player's fault either way. |
| **Berries** | `smash_through` on corn is nothing — corn is not a `ChaosProp`. Drift and input lag in a maze of rows is a disaster. **Reads useful, is not.** |
| **Double-Double** | Altitude works, but leg 6's whole thesis is that the sky gives you away. Going up shows him where you are. **The leg-3 answer is the leg-6 mistake.** |
| **Grass** | Still the floor. Still funny. |
| **Darts** | Does almost nothing and racks tolerance 3× faster than anything else. On the second-to-last shelf in the game, that is not a joke any more. Nobody comments. |

**Do not add fly agaric to leg 6 to make micropsia a hiding tool.** It is
tempting and it is wrong: `CAMPAIGN_SPEC.md` chose six deliberately, and the
thinness *is* the escalation. If the developer insists on a seventh, agaric is the
one — but the encounter is better without it.

## 3.4 BIG DOWN — the shelf runs out and nobody says so

**There are no substances inside the building.** Whatever you walked in on is what
you have, for up to ninety seconds, including the comedown.

This is `DESIGN_MISSIONS.md` §1.5's escalation rule at full extension — *escalate
by narrowing options, not by inflating numbers* — and it is the first genuine
resource decision the game has ever asked for: **do you dose before you cross the
interstate?**

**The four at the truck stop.** `CAMPAIGN_SPEC.md` §2.7 says *"four, all of them
ones you've had, all at reduced dose size"* and does not name them. Naming them:

| Substance | Where | Why this one |
|---|---|---|
| **Double-Double** | The diner's pot, on the burner since midnight | The only reliable altitude in a four-storey atrium. |
| **Fermented Berries** | Something in the dumpster corral | See below. It is the trap. |
| **Darts** | Behind the diner | Does nothing. Costs tolerance. Everybody takes it anyway. This is the truest thing the game says and it must never be commented on. |
| **Bars** | A vending machine by the restrooms | `hud_amnesia`. See below. |

**The trap, and it is the best one in the game.**

> **Berries.** `smash_through` — you break props you touch, regardless of speed. A
> building made of glass. It is the obvious answer, it is *genuinely* the answer,
> and it also gives you **input lag, drift and ragdoll landings inside a building
> made of walls.**
>
> The correct tool and the worst idea are the same object. That is the entire
> thesis of Geeked Geese in one pickup, sited at the last decision point in the
> run, and it never says a word.

**The second trap.** `Bars` gives perfect steadiness and zero screen shake — and
`hud_amnesia`. In an interior, with no horizon, in the dark, the HUD is the only
navigation you have. Bars is a precision tool that deletes your map. It also makes
a curtain wall shatter with **no screen shake at all**, which is quietly the most
unsettling thing in the encounter, and it rhymes with flight 7's HUD dismantling
ten seconds later.

**Blacking out in the tower.** Three at once still rolls the bad table. You go
down on the warehouse floor, in the down, for three seconds of black screen, and
`and_then_i_woke_up` is live and pays out if you come back swinging. That
objective already exists and this is the most dramatic possible place for it to
fire.

**Catnip in the tower does nothing.** There are no cats in a distribution centre.
It is the one substance the encounter completely refuses, and a player who brings
it deserves the silence.

## 3.5 The rule that keeps this from collapsing

Every encounter above is completable **stone-cold sober**, using only the honk,
altitude and a body at speed. Chemistry is a lever, never a key.

The moment one encounter requires one substance, the substance shelf becomes a
lock-and-key inventory and sixteen control mutations become sixteen items. That
is the failure mode and it is one bad objective away at all times. **No boss
objective may name a substance.** Hidden objectives may — that is discovery, not
instruction, and `DESIGN_MISSIONS.md` §5 already draws that line.

---

# PART 4 — THE FLOCK IN BOSS FIGHTS

The flock is data during a zone (`flock_state.gd`) and physical during flights
(`migration.gd`). The one exception is the **flock pen** — colliderless ghost geese
you can walk among, present in every zone, where the DD is assigned.

That pen has had exactly one reason to be looked at outside leg 5. It now has
three.

## 4.1 What each encounter does with it

| Encounter | The flock |
|---|---|
| **Ranger · leg 3** | **He counts them.** He walks to the pen and stands there writing. The clipboard number ticks to your live flock size. Nothing is lost. It is a threat display and it teaches the mechanic before it costs anything — the flow-channel rule of introducing in a low-stakes context immediately before it matters. |
| **Ranger · leg 6** | **He can take one.** `RELOCATED`. See §4.2. |
| **BIG DOWN** | **There is no flock.** The pen stays at the truck stop. The tower is the only encounter in the game you do alone, you cannot share, and **when you honk nothing answers.** See §4.3. |

## 4.2 `RELOCATED` — a third loss channel, bounded hard

`CAMPAIGN_SPEC.md` §4.2 names two channels and says why it needs two: `DOWN` is a
physics accident and `DROPPED` is a channel *the player authors*. This is a third,
and it is the only one **authored by inaction rather than by excess.**

| | |
|---|---|
| **Trigger** | The Ranger reaches the pen at leg 6 and is not interrupted for 12 continuous seconds. |
| **Frequency** | **At most one bird, once per run, leg 6 only.** Hard-coded, not a probability. |
| **Framing** | `"MARGARET IS BEING RELOCATED"` · no hitstop · she walks to the truck with him, calmly, and gets in. |
| **Prevention** | **Any** successful interference cancels it permanently for the run: one honk that lands on him, one hit on the clipboard, one cat on the dog, or simply standing between him and the pen. |
| **Recovery** | None. She is gone. She appears in the credits roster as `relocated · leg 6`. |
| **Truth** | Goose relocation and round-up programmes are real, documented and controversial. It is the Almanac fact for leg 6's alternate slot. |

**Why it earns its place.** It is the only loss in the game that is neither an
accident nor a consequence of partying. It happens because a man walked across a
field for twelve seconds and you did not care. That is a different flavour of
regret from `DOWN` and `DROPPED`, and it lands on the leg where the run is
supposed to start feeling lean.

**Why it will not break the attrition curve.** It is capped at one, it requires
sustained total inattention during a 60-second encounter that is *actively drawing
the player's eye to the pen*, and the careful/typical archetypes in
`CAMPAIGN_SPEC.md` §4.1 will essentially never trigger it. The reckless archetype
will, and that archetype's target is already 1–2 survivors.

> **Gate:** `tools/flight_harness.gd` gains a `ranger_ignored` flag. If enabling
> `RELOCATED` moves the *typical* archetype's median below 4, cut it and use the
> fallback: **he takes the vest.** The DD is un-designated, the hi-vis is on his
> clipboard, and you have to reassign at the truck stop. Same dread, no bird, one
> line of code.

## 4.3 BIG DOWN and the absence of the flock

The tower is the only place in Geeked Geese where you are alone, and it should be
loud about it by being silent about it.

- **The share key does nothing.** `gg_share` in the tower has no target. It is not
  disabled, it is not explained; it simply has nobody to give anything to.
- **The honk is not answered.** Same cue, same code, no reply. Twenty minutes
  later on the 18th green the same honk gets forty answers in a ragged wave. This
  is the same retrospective manoeuvre `CAMPAIGN_SPEC.md` §5.2 uses with the
  Stopover crowd, done in audio, for free.
- **The roof looks at them.** The last fifteen seconds of leg 7 are you, on a roof,
  in the rain, looking across the interstate at the truck stop where the pen is.
  Then you get up and fly with whoever is left.

That is the flock beat, and it is entirely structural — not one line of flock code
is touched.

---

# PART 5 — BIG DOWN AS THE FINALE, AND THE TONAL PROBLEM

## 5.1 The problem, stated plainly

`CAMPAIGN_SPEC.md` makes one decision it calls *"the single most important
structural decision in this document"*: **the climax is flight 7, not leg 8.**
Leg 8 is falling action — a golf course at first light, no clock, no HUD, no
score, one honk, playable credits. The pacing research behind it is
unambiguous — the Level Design Book's *"avoid maximum intensity final
bosses / encounters"* and the whiplash research's requirement of a neutral beat
between registers.

A final boss fights that structure two ways. It wants to be the loudest thing, and
it wants to be last. Leg 8 needs the loudest thing to be over and needs to be last
itself.

## 5.2 The three options, and why two of them fail

**Option 1 — BIG DOWN is the finale; the tower is leg 8 or a new leg 9.**
**Rejected.** This is the exact failure the pacing research names. Either the golf
course is deleted — which deletes the sincere moment, the honk wave, the residents,
the playable credits and the entire emotional payload of the campaign — or the
tower is inserted between flight 7 and the green, which puts a 9, then an 8, then
a 1 back to back with no trough, and asks the sincere beat to happen in a room
that is still shouting. It also pushes the run past the 45-minute contract.

**Option 2 — BIG DOWN is a mid-run encounter, at leg 4 or leg 6.**
**Rejected.** Leg 4 is the cottage at night and is the best zone in the project;
a corporate tower poisons it and collides with toad slime's set-and-setting
payoff. Leg 6 is a corn field in North Carolina; a glass tower in it is nonsense,
and leg 6 already has the Ranger's exam, which is the encounter that makes leg 6's
cover mechanic mean anything. And a mid-run BIG DOWN wastes the one thing this
encounter is uniquely able to give the run: **flight 7's weather.**

**Option 3 — the glass tower is the climax and the golf course is the epilogue.**
**Rejected as stated, adopted in modified form.** The unmodified version swaps
flight 7's climax for the tower's, which throws away the flight system's finale —
the HUD dismantling itself over eight seconds, the last fifteen seconds with no
interface, the 401 callback, and the final accounting of who is still in the V.
That climax is about the flock, and the flock is what the campaign is about.

## 5.3 The resolution

> **BIG DOWN is not the climax. Flight 7 is, and BIG DOWN's job is to give it its
> weather.**
>
> **BIG DOWN is the back half of leg 7 — the last thing that happens on the
> ground — and it hands the peak off to the Interstate mid-sentence.**

Three registers, in order, with a trough between each, none of them competing:

| Beat | Register | Peak of what |
|---|---|---|
| **Leg 7b — the tower** | **Satire.** The game's one authored antagonist, its one piece of commentary, its one held breath. | The *premise*. The reason a goose game is about a parka company. |
| **Flight 7 — the Interstate** | **Tension.** Longest, densest, darkest, wettest, and whoever is left. | The *flock*. Who arrived with you. |
| **Leg 8 — the 18th green** | **Sincerity.** No clock, no HUD, forty geese answering a honk. | The *journey*. |

Each one is the peak of a different axis. None of them is trying to be the peak of
the same axis as another, which is the only reason three big beats in a row can
coexist. The whiplash research's four techniques — processing time, dramatic irony,
blended modes, and joy-not-comedy after loss — are all satisfied by the ordering
rather than by anything authored.

**And the seam between them is a particle.** The down goes up over the interstate
at the end of leg 7 and is still in the air twenty seconds into flight 7. The
handoff is diegetic, wordless, and free.

## 5.4 The revised intensity curve

Twenty beats. Same 0–10 composite metric as `CAMPAIGN_SPEC.md` Part 3. Changed
rows are marked `◆`.

```
                                                     0    2    4    6    8   10
                                                     |    |    |    |    |    |
 1  L1  zone  THE RETENTION POND      overcast am     ####                        2
 2  F1        THE 401                             ######                          3
 3  L2  zone  THE STRIP MALL LOT      overcast pm  ########                       4
 4  F2        OVER THE QEW                         ########                       4
 5  L3a zone  SUBURBIA                golden hour  ##########                     5
 6  L3b BOSS  THE RANGER      45 s                 ############                   6   ◆ introduced
 7  F3        THE WRONG WAY    ↑km                 ############                   6
 8  L4  zone  COTTAGE COUNTRY         night        ##############                 7   ◀ peak
 9  F4        THE LONG HAUL                        ################               8   ◀ the bill
10  L5  zone  THE STOPOVER            dawn         ####                           2   ◀◀ REST BEAT
11  F5        DOWN THE SUSQUEHANNA                 ##########                      5
12  L6a zone  THE CUT CORN            hard midday  ##############                 7
13  L6b BOSS  THE RANGER      60 s                 ################               8   ◆ the exam
14  F6        THE FALL LINE                        ############                   6
15  L7a zone  THE TRUCK STOP          3 a.m. rain  ########                       4   ◀ breath (intact)
16  L7b BOSS  BIG DOWN        75 s                 ################               8   ◆ the last laugh
17  L7c       THE ROOF        15 s                 ####                           2   ◆ the guaranteed rest
18  F7        THE INTERSTATE   down in the air     ##################             9   ◀◀ THE PEAK
19  L8        THE 18TH GREEN           first light ##                             1   ◀ falling action
20  L8        credits (playable)                   ##                             1
```

### What changed, and what it does

| Property | Before | After | Verdict |
|---|---|---|---|
| **Peaks in the back half** | 7 (L6) → 4 (L7) → **9** (F7) | 7 → **8** (L6b) → 4 → **8** (L7b) → 2 → **9** (F7) | **Better.** Lopez asks that peaks *grow* or *tighten in frequency*. These do both: 7, 8, 8, 9, at gaps of 4, 3, 2 beats. The old back half had one lonely summit with a flat run-up. |
| **Deep rest (L5)** | intensity 2, 150 s, full mechanical heal | **unchanged** | The load-bearing trough is untouched. |
| **Pre-peak rest** | L7 truck stop at 4 | L7a truck stop at 4, **plus L7c at 2** | **Better.** Slay the Spire's rule wants the rest *immediately* before the boss. It now is — fifteen seconds of nothing directly against the summit, instead of a 4 with a flight-start in between. |
| **Micro-rest inside the peak** | first 20 s of F7 contain nothing | **unchanged, plus down in the air** | Same beat, more beautiful, one emitter. |
| **Leg 8** | intensity 1, no clock, no HUD, no score | **untouched. Not one line.** | Non-negotiable and not negotiated. |
| **Largest single transition** | beat 14→15, an 8-point drop | beat 18→19, still an 8-point drop | The ending's defining cut survives exactly. |
| **Run length** | ≈ 44 min | ≈ 45–46 min | Leg 7's clock goes 180 → 230 s. Legs 3 and 6 are unchanged — the Ranger happens *inside* their existing 180 s. |
| **Monotonic?** | No, deliberately | **Still no.** Drops of 6 (9→2... i.e. L6b→F6→L7a is 8→6→4), 6 (L7b→L7c), 7 (F7→L8) | Three drops of 6+. Saw-tooth, harder than before. |

### The shape in one sentence

*A rise to a peak at leg 4, a hard crash to a guaranteed trough at leg 5, a
higher peak at leg 6, a breath at the truck stop, the satire at the tower, fifteen
seconds of nothing on a roof, the summit on the Interstate, and a long flat
resolution on grass.*

## 5.5 The one thing that must not happen

**BIG DOWN must never be referred to again after leg 7.** Not in the credits
roster, not on the route recap, not in the verdict line, not by a resident goose
on the 18th green, not anywhere.

`CAMPAIGN_SPEC.md` §5.5 lists what the ending deliberately does not contain and
the list is correct. A callback to the tower on the golf course would convert the
ending from *arrival* into *victory over an antagonist*, and the whole point is
that nobody won anything. The geese got to Florida. The company is still there.
Next year there will be another survey.

The only trace BIG DOWN leaves in the ending is the one the player brings
themselves.

---

# PART 6 — LEGAL

*This is a designer's risk-management summary, not legal advice. Get a lawyer's
eye on the store page before it goes live; that is one hour of someone's time and
it is the cheapest insurance in the project.*

## 6.1 The one rule that changed recently

Post-*Jack Daniel's Properties v. VIP Products* (2023), the First Amendment
shield that expressive works have relied on is narrower than it was:

> **"Rogers does not apply when an alleged infringer uses a mark as a designation
> of source for its own goods."**
> — [Davis Wright Tremaine, on *Jack Daniel's v. VIP Products*](https://www.dwt.com/insights/2023/06/scotus-jack-daniels-trademark-rogers-test)

The Court preserved *Rogers* as a *"cabined doctrine"* for genuinely
non-source-identifying uses inside expressive works, and it explicitly held that
**parody does not automatically save you** — expressive content *"may properly
figure in assessing the likelihood of confusion"* but does not trigger *Rogers*
protection when the mark is doing source-identifying work.

The practical translation for this project is a single bright line:

> **Inside the game, BIG DOWN is a character in a story. Outside the game, BIG
> DOWN does not exist.**

Where *Rogers* still applies, it is generous — artistic relevance requires
*"anything more than zero"* and the second prong asks only whether the use is
*"deliberately misleading as to the source or content of the work"*
([Legal Moves, on trademarks in video games](https://legalmoveslawfirm.com/other-companies-trademarks-video-game/)).
The same source records that risk scales with **prominence in marketing** rather
than with in-game presence.

## 6.2 The concrete allow list

Everything here is safe and should be built:

| Allowed | Why |
|---|---|
| The name **BIG DOWN**, in a typeface bearing no resemblance to any real one | Not a real mark. Descriptive-comedic. |
| A **wordmark of your own design** on trailers, the tower, the bales | It is your mark, parodying a category. |
| A **roundel/patch device**, provided it is not a circular arctic map | See the deny list. A hexagon with a stylised feather is the recommendation, and it is a `tools/gen_textures.py` function. |
| **Parkas as objects.** Fur-trimmed hood silhouettes, puffer geometry, a rack of coats | Product categories are not protectable. |
| **A CEO character** — a suit, a briefcase, faceted default proportions, no name spoken or written | A generic executive is a stock figure. |
| The **down supply chain as subject matter**, in general, unnamed | Satire of an industry is core protected expression, and it is the target of the parody rather than a vehicle for it — which is the strongest kind. |
| **Down and feather production facts in the Almanac**, sourced, generic, with the contested parts flagged | See §6.4. |

## 6.3 The deny list — hard, and enforceable by a lint

| Forbidden | Where |
|---|---|
| **The real company's name**, in any form, in any string | Every `.tres`, every `.gd`, every `Label3D`, every objective title, every Almanac entry, every achievement, every file name, every commit message that ends up public |
| **The real roundel** or anything mistakable for it at 32 px | Textures, trailer decals, the tower, the coats. If a Canadian playtester says "that's just the logo," change it. |
| **The real typeface, the real palette, the real product names, the real model names** | Anywhere |
| **Any of it in marketing** | Store capsule, key art, trailer thumbnail, Steam page copy, press kit, screenshots chosen for the store, the game's own title. This is the *Jack Daniel's* line and it is the one that actually matters. |
| **Any real executive's name, face, or identifiable biography** | This is right of publicity plus potential defamation, which is a separate and worse problem than trademark, and it has no parody safe harbour worth relying on. The CEO must be nobody. |
| **Any depiction that reads as an accusation of specific illegal conduct by an identifiable real company** | Depicting a *down industry* is satire. Depicting *this company* committing *this crime* is trade libel. The encounter satirises a supply chain and a category. It does not allege anything about anyone. |

**Enforce it mechanically.** One CI grep over `data/`, `scripts/`, `docs/` and the
credits payload for a small blocklist of forbidden strings, failing the build.
That costs twenty minutes and it removes the entire class of "it slipped into a
debug label" failures.

## 6.4 What the encounter can and cannot show

**Can:**
- A warehouse of unbranded compressed down bales with fill-power numbers and lot
  codes.
- Racks of finished coats, unbranded, in a colourway that is not the real one.
- A man in a suit who runs away from a bird.
- Trailers with **your** wordmark on the side.
- The material going up into the sky over an interstate.

**Cannot:**
- Any process depiction that reads as a documentary claim about live-plucking, or
  about any named company's sourcing. The encounter shows a *warehouse*, which is
  the safe, funnier and more damning image anyway: nothing is happening in it. It
  is just very, very full.
- Anything that positions the game as commentary on a *specific* company's
  practices in the store description. The store page says it is a game about
  geese.

## 6.5 The Almanac entry, and why it is the safest possible version

`GEEKED_GEESE_DESIGN.md` §7.3 established the house rule: *"Teaching a kid that a
fun fact is contested is worth more than the fact."* Apply it here and the legal
problem solves itself.

The leg 7 entry is about **down as a material**: what it is, why it insulates
(loft traps air; fill power is a volume measurement, not a warmth measurement),
that the great majority of it is a by-product of the food industry, that
responsible-sourcing certification schemes exist because the practices they
certify against also existed, and — the contested part — that the certification
regimes' effectiveness is argued about by people with reasons on both sides.

No company is named. The fact is true, sourced, more interesting than an
accusation, and legally inert. **The encounter is the joke; the codex is the
honest version.** That split is the whole educational design of this project and
it works exactly as well here as it does for nicotine.

---

# PART 7 — BUILD COST

## 7.1 The Ranger — ≈ 6.5 days

| Item | Days | Notes |
|---|---|---|
| `ranger.gd` — `NpcHuman` fork: patrol → collect → search → flinch → depart | 1.5 | State machine over a `Path3D`. Speech via `Label3D`, four lines. |
| `dog.gd` — `cat.gd` fork: wander → acquire → pursue → carry → return | 1.5 | The pursuit is `cat.gd`'s `_frenzy` with different numbers. The carry is a reparent + a lerp. |
| Faceted border collie + hi-vis human variant | 0.5 | `cat_visual_lowpoly.gd` and `human_visual_lowpoly.gd` both take colour params already. Two-tone collie is a param. |
| The clipboard: `ChaosProp` + live `Label3D` face + drop/retrieve | 0.5 | |
| The truck: `prop_models.gd` `pickup_truck` + light bar | 0.5 | Nearest existing model is `minivan`. |
| `HAZED` transition | 0.5 | Hitstop, feather burst, 6 s carry, combo break, `Mission.note()`. |
| Source-collection behaviour (`SubstancePickup` despawn into the bin) | 0.25 | |
| Propane cannon (timer + sound + `_pressure_wave` reuse) | 0.25 | Leg 6 only. |
| `RELOCATED` + credits roster string | 0.5 | Plus the harness flag. |
| `mission_defs` entries for both legs + 3 hidden objectives | 0.5 | All expressible in the existing condition grammar via `event`. |
| **Total** | **6.5** | |

**Reusable output:** `dog.gd` is the game's second independent-agent AI and is a
gift to any future zone. `ranger.gd` is the template for every future authority
figure.

## 7.2 BIG DOWN — ≈ 11 days

| Item | Days | Notes |
|---|---|---|
| `zone_bigdown.gd` — warehouse interior, racking, dock | 2 | Boxes. The single cheapest-looking-most-impressive geometry ratio in the project. |
| The glass office block — 4 floors, atrium, stair, curtain wall grid | 2 | A box and a grid of thin transparent `ChaosProp`s. Genuinely trivial in primitives. |
| `glass_pane.gd` — honk-breakable `ChaosProp` variant + shatter particle | 1 | A `break_force` band plus a `Juice.burst` preset. |
| `down_bale.gd` — high-value soft prop, feather burst at volume | 0.5 | `ChaosProp` with tuned mass and the existing `&"feathers"` burst. |
| `ceo.gd` — `NpcHuman` fork: flee upward, close the nearest shutter, take the lift | 1 | No combat, no hit reaction, no defeat state. Genuinely simple. |
| Shutters, blinds, the lift, the sprinkler friction window | 1 | Four `AnimatableBody3D`s and one 10 s friction override. |
| The down release — `GPUParticles3D`, wind, the exterior shot | 0.75 | |
| Flight 7 down emitter + 20 s lifetime | 0.25 | One emitter in `migration.gd::_environment`. |
| The roof beat: 15 s, camera, the pen in the distance, leg-end override | 0.5 | |
| Leg 7 restructure: 230 s clock, dock trigger at 110 s, phase handoff | 0.5 | |
| Truck decals + skyline tower for legs 6–7 | 0.5 | One texture, one distant box. |
| `mus_bigdown` stem set (quieter than the truck stop) via `tools/gen_music.py` | 0.5 | |
| `mission_defs` + 2 hidden objectives + Almanac entry | 0.5 | |
| **Total** | **11** | |

## 7.3 The reduced BIG DOWN — ≈ 3.5 days

If the schedule bites, this is the cut, and it is a good version rather than a
sad one:

> **The tower has no interior above the ground floor. There is no CEO. There is
> one room, and it is the down floor.**

The dock opens at 110 s. You go in. It is dark, it is enormous, it is full of
white bales that burst into the same feathers the game spends on `WAYNE IS DOWN`.
You knock them over for forty seconds because they are the best props in the game.
Then the dock's roof vents open — on a timer, unprompted — and **all of it goes up
over the interstate**, and you fly out, and fifteen seconds later you are on flight
7 with down in the air.

| Kept | Cut |
|---|---|
| The satire, at full strength | The glass, and therefore the honk exam |
| The dramatic irony | The CEO, and therefore the boss |
| Flight 7's weather | The atrium, the shutters, the roof-as-arena |
| The Almanac entry | The `LOCKED OUT` fail state |
| The unanswered honk | |

**Cost: 3.5 days.** It delivers about 80% of what BIG DOWN is *for* and none of
what makes it a boss. If the choice is between this and nothing, build this.

## 7.4 What to cut, in the order I would cut it

| Cut | Saves | What you lose |
|---|---|---|
| **BIG DOWN → the reduced version** | 7.5 days | The honk exam. The game's one glass set piece. **This is the intended cut.** |
| **`RELOCATED`** | 0.5 days | A loss channel. Fall back to "he takes the vest." Cheap enough that the harness should decide, not the schedule. |
| **The propane cannon** | 0.25 days | Leg 6's pacing metronome. Genuinely cuttable; the combine already provides a clock. |
| **The Ranger at leg 3** | 2 days | The introduction. **Do not do this.** Leg 6's exam is unreadable if the player has never met him — the flow-channel rule is that you introduce a mechanic in a low-stakes context immediately before it matters, and leg 3 *is* that context. Cutting the introduction and keeping the exam is the worst possible half. |
| **The Ranger entirely** | 6.5 days | Leg 6's cover mechanic has nothing to hide from, and leg 3's verticality has no reason to exist beyond a primary objective. |
| **The Zamboni** | 0 days | Nothing. It is already not in v1. |

## 7.5 Build first: the Ranger, in Suburbia, in two days

Not because it is the more important encounter — BIG DOWN is the better trailer
and the reason the developer noticed the bosses were missing. Because it is the
cheapest possible answer to the question the whole document rests on:

> **Is a boss without combat fun in *this* controller?**

Suburbia is already built, with a roof, a trampoline, fences, cats and a flock
pen. `cat.gd` already has a wander/acquire/frenzy state machine. Forking it into a
dog that is faster than a goose and putting a man with a clipboard in the
cul-de-sac is **two days of work in a zone that already runs**, and at the end of
those two days you will know:

- whether being chased by something faster than you, with no way to fight it, is
  funny or infuriating in a goose;
- whether `HAZED` reads as a bit or as a punishment;
- whether the two-body split (bully the man, flee the dog) is legible without a
  single line of instruction;
- whether the honk feels like a *tool* when something is finally afraid of it.

If those four answers are yes, build the rest of the Ranger, then leg 6, then BIG
DOWN. If any of them is no, **BIG DOWN is probably also not fun, and you have
spent two days finding out instead of eleven.** That is precisely the logic
`WIN_CONDITIONS.md` used to justify building the 18th green before any other
content, and it applies here for the same reason.

## 7.6 Where this slots into `CAMPAIGN_SPEC.md`'s plan

The campaign's build plan is M1–M10, 34–38 days. These encounters are additive and
sequence cleanly:

| Milestone | Insert | Days |
|---|---|---|
| **After M3** (flock visible) | **M3.5 — THE PROTOTYPE.** The Ranger + dog in Suburbia. The gate above. | 2 |
| **After M7** (cheap legs — leg 7 exists) | **M7.5 — BIG DOWN.** The truck stop is built by then and the tower attaches to it. | 11 (or 3.5) |
| **Inside M9** (leg 6) | The Ranger's leg 6 encounter ships with the corn field. It is the strongest argument against M9's cut-to-a-variant fallback. | 4.5 |
| **New total** | **51.5 days ≈ 10 weeks** (or **44 days ≈ 8.5 weeks** with the reduced BIG DOWN) | |

---

## Sources

- [Boss Battle Design and Structure — Mike Stout, Game Developer](https://www.gamedeveloper.com/design/boss-battle-design-and-structure)
- [Boss Design: How to Make an Unforgettable Boss Battle — GameDesignSkills](https://gamedesignskills.com/game-design/game-boss-design/)
- [Game Design Technique #14: Mastering the Boss Fight — Yu-kai Chou](https://yukaichou.com/advanced-gamification/game-design-technique-14-mastering-the-boss-fight/)
- [How to Design a Final Boss — Bugnet](https://bugnet.io/blog/how-to-design-a-final-boss)
- [With its final puzzle, Untitled Goose Game becomes a masterpiece of the stealth genre — AV Club](https://www.avclub.com/with-its-final-puzzle-untitled-goose-game-becomes-a-ma-1838423723)
- [The Horrific Appeal of Mr. X: Creating the Alpha Antagonist — Josh Bycer, Game Wisdom](https://game-wisdom.com/critical/mr-x)
- [Revisiting the AI of Alien: Isolation — Tommy Thompson, Game Developer](https://www.gamedeveloper.com/design/revisiting-the-ai-of-alien-isolation)
- [Mechanical Comedy In Games — Polaris Game Design Retreat](https://polarisgamedesign.com/2025/mechanical-comedy-in-games/)
- [How to Handle Failure in Games: Designing Death and Retry Loops — JoyPlayX](https://www.joyplayx.com/article/how-to-handle-failure-in-games-designing-death-and-retry-loops)
- [More Than Meets the Eye: The Secrets of Dynamic Difficulty Adjustment — Caleb Compton, Game Developer](https://www.gamedeveloper.com/design/more-than-meets-the-eye-the-secrets-of-dynamic-difficulty-adjustment)
- [Metroid Dread and the escape sequence — Backlog](https://www.backlogmag.com/metroid-dread-and-the-escape-sequence/)
- [Jack Daniel's v. VIP Products: Supreme Court Clarifies When Rogers Test Applies — Davis Wright Tremaine](https://www.dwt.com/insights/2023/06/scotus-jack-daniels-trademark-rogers-test)
- [Can you use other companies' trademarks in your video game? — Legal Moves Law Firm](https://legalmoveslawfirm.com/other-companies-trademarks-video-game/)
- [Laugh It Off: A Guide to Parody Under U.S. Trademark Law — Faegre Drinker](https://www.faegredrinker.com/en/insights/publications/2023/4/laugh-it-off-a-guide-to-parody-under-us-trademark-law)

*Pacing, fail-state, flow-channel and tonal-whiplash research is not repeated
here; it is in `CAMPAIGN_SPEC.md` Part 1 and `WIN_CONDITIONS.md` Part 1, and this
document is built on top of both.*
