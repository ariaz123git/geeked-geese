# NEXT SESSION — AUTONOMOUS. THE QUEUE IS IN HANDOFF §3.

**Set by the human on 2026-09-20:** *"wrap this session for now and next session
will be another autonomous."* That is still the instruction.

**This file no longer carries the queue.** It did until 2026-09-25, when one
session worked all six of its items — the controls sweep, the per-step timeout,
`migtest`'s half crossing, F-001, the `CLAUDE.md` cut, leg 1's findability — and
kept going (D-054 to D-085). `docs/HANDOFF.md` §3 ranks what comes next. What
stays here is the material behind the decisions only the human can make, and the
pattern that keeps producing bugs.

> **This file has said three different things in three weeks** — a planning
> session, then "keep building", then autonomous with a queue — and each time a
> stale instruction in a rarely-read file nearly sent a session the wrong way.
> CLAUDE.md's banner is about exactly this. If you change what this file says,
> change the banner at the top of `docs/HANDOFF.md` in the same commit.

**This file is a working agenda, not a claim surface.** Where it states a number,
the command that recomputes it is next to it, because the number will rot and
the command will not.

---

## STILL THE HUMAN'S — do not decide these alone

- **Substances as keys (§1).** It overrides a written design principle
  (`BOSS_DESIGN.md` §3.5, *"chemistry is a lever, never a key"*). If you want to
  move it without them, the ONLY direction that does not override the rule is
  making the lever steeper — and that is still taste.
- **Cat petting (§4).** The human said explicitly: *"needs to be discussed in
  detail in the next session."* Designed, deliberately unbuilt.
- **Where leg 1's pickups go (§2, D-068).** Now measured; still level design.
- **Whether two quick honks may rout the Ranger (D-084).** Measured; it is
  difficulty, and the fix would change how hard the honk hits everything.
- The `Open (human)` entries in `docs/DECISIONS.md`, listed in HANDOFF §3.
  **D-019 is worth raising first** — tolerance softening penalties is arguably
  part of why chemistry feels inconsequential.

---

## 6. THE PATTERN WORTH CARRYING INTO THE NEXT SESSION

**An advertised control wired to nothing, passing every gate because no gate
asked whether the far end was attached.** Five on 2026-09-20 (D-047, D-050 to
D-053). On 2026-09-25 the sweep kept going and the seam was nowhere near
exhausted — HANDOFF §2 has the table: a pad that could not leave flight 1, four
Settings rows that did nothing, a second share handler nobody had fixed, a card
nothing called, a menu watch that could not see a menu, a right stick bound to
nothing. **And the same sweep kept finding a second shape underneath the
first:** once a control was finally driven, what it drove was sometimes wrong —
the flight scored formation backwards (D-073), the card taught the draft
backwards (D-075), the ending scored on the screen with no score (D-079).

**The tell is always the same.** Something is declared in one place and consumed
in another, the consumer looks it up *by name or by signal*, and the lookup fails
softly — `get_bus_index()` returns `-1`, an unconnected signal does nothing, a
`process_mode` gates the callback, a second handler takes the key first. No
error is raised anywhere.

**The method that works:** find the declaration, go and check the far end
exists, and drive it the way a player would rather than calling the handler —
`Input.parse_input_event()` for keys, pad buttons and sticks,
`Viewport.push_input()` for the mouse (headless, a parsed mouse event never
reaches the GUI), a click on the Button rather than its signal, the pref rather
than the field. Then read what the far end did, not just that it ran.

---

## 0. Why the autonomous sessions missed all of this

Worth saying plainly at the top, because it is the most useful finding here and
it is about the process rather than the code.

The autonomous sessions were **extremely good at finding things that were wrong
and blind to things that were absent.** Every gate, every canary, every
assertion answers *"does the code do what the code says it does?"* Nothing in
the repo asks *"is this game any good to play?"* — so nine defects got found and
fixed in one session while the substance system sat there being, in the human's
words, *"so stupid, there's no thinking involved."*

Worse: **two of the four items below were actively blocked by documents this
project wrote and I obeyed.** That is not a hypothetical failure mode, it is
what happened, and it is the same failure CLAUDE.md's own banner note describes.
See items 1 and 2.

---

## 1. SUBSTANCES DO NOT MATTER — the human's central critique

Their words, kept verbatim because the paraphrase loses it:

> *"the drugs need to have an effect that is more load-bearing or influential or
> has more... like.. it needs to matter somehow to the game objective cuz rn the
> mechanic is so stupid like there's no thinking involved like 'should I take
> this drug vs this drug or combine these drugs to maximize my score and my
> ability to complete X task' like we should add more sophisticated tasks where
> you need drugs to do them"*

### The evidence, gathered 2026-09-10

**Nothing in any zone ever asks whether you are on anything.**
```
grep -rn 'Subs\.' scripts/world/zone_*.gd | grep -v 'get_substance\|library\|Subs.take'
```
Returns one hit, and it is a comment. Every other `Subs.` reference in all seven
zone builders is `Subs.get_substance()` — i.e. *placing a pickup*. No ledge, no
door, no reward, no hazard, no NPC reads `Subs.is_active()` or `Subs.mods`.
**There is no lock anywhere in the game that a substance is the key to.**

**Five objectives name a substance. All five are hidden, and all five fire on
merely swallowing it.**
```
grep -rnoE '&"(acid|bars|berries|catnip|darts|double_double|fly_agaric|grass|gravy|math|molly|nitrous|percs|robo|special_k|toad_slime|bread)"' scripts/core/mission_defs*.gd
```
`do_not_lick_the_toad`, `molly_good_dog`, the cottage toad, and truck stop's
`breakfast` (double_double + darts). Every one is `{"type": &"event", "event":
&"sub_taken"}` — *you ate it, here is a joke*. **Not one of them requires what
the substance does.** Zero primary or bonus objectives name one at all.

**The objective grammar already CAN watch chemistry** — `subs_taken`,
`peak_subs`, `sub_taken`, `sub_ended`, `overdoses`, `sweet_spots`,
`flock_intox`, `peak_flock_intox`, `blackouts`, `post_blackout_chaos`. It counts
substances. It never requires a *specific* one, and it cannot express "while
under the effect of X" as a condition at all. **Check whether that grammar needs
extending before designing tasks that assume it.**

**The closest thing to the human's idea that exists** is leg 1's
`"Hit {n} things while you're on two things"` — and it is substance-*agnostic*:
any two work identically, so there is no reason to prefer one over another. That
objective is the whole current answer to "should I take this drug or that one".

### THE BLOCKER — and it is a written rule, not an oversight

`docs/BOSS_DESIGN.md` §3.5, *"The rule that keeps this from collapsing"*:

> *"Every encounter above is completable **stone-cold sober**, using only the
> honk, altitude and a body at speed. **Chemistry is a lever, never a key.**
> The moment one encounter requires one substance, the substance shelf becomes a
> lock-and-key inventory and sixteen control mutations become sixteen items.
> That is the failure mode and it is one bad objective away at all times."*

Restated as a house rule in `docs/ROUTE_DATA.md` §7: *"never name a substance in
visible text."*

**This is the direct reason no autonomous session built what the human is now
asking for.** The design documents forbid it in writing, with an argument, and
the sessions followed them.

### What the planning session has to decide

The rule's argument is *good* — sixteen required substances really would turn a
control-mutation system into an item inventory. The human's complaint is *also*
good — a lever nobody has a reason to pull is not a lever. Both can be true.
Directions worth arguing, none of them chosen:

- **Several keys per lock.** A task that is only reachable *chemically*, but by
  three or four different chemistries — so the decision is "which", never
  "whether". Preserves the anti-inventory argument; kills the "no thinking".
- **Lever, but a steep one.** Sober is possible and bad; the right chemistry is
  dramatically better-scoring. Decision without a lock. Closest to the existing
  rule and the smallest change.
- **Combination play**, which the human named explicitly. `Subs.MAX_STACK` is
  already 2. Nothing anywhere rewards a *specific* pair.
- **Read the house rule literally.** It bans a substance's NAME in visible
  *text* — not its ROLE in a task. *"Get onto the pharmacy roof"* is legal
  under the rule as written and can still require a climb. **The rule may have
  been over-read for the whole project.** Check this first; it may unblock most
  of the above for free.

**An agent must not decide this alone** — it overrides a written design
principle, which makes it the human's call under CLAUDE.md.

---

## 2. LEG 1 HAS FOUR SUBSTANCES, AND THAT WAS MY DOING

> *"why are there no drugs on level one now? i remember there used to be hella
> drugs but now all i can find is grass."*

**Correct, and it was a deliberate change I made autonomously** — D-022 and
D-037, `zone_strip_mall.gd`:

```gdscript
const TUTORIAL_SHELF: Array[StringName] = [&"berries", &"double_double", &"grass", &"bread"]
const FULL_SHELF_FROM_LEG := 2
```

`_source()` is gated on `_shelf.has(res.id)`, so on leg 1 **thirteen of the
nineteen `_source()` call sites are silently skipped**, leaving 8 pickups of 4
substances. Legs 2+ get all 17. Recompute:
```
grep -c '_source(' scripts/world/zone_strip_mall.gd     # call sites (+1 for the def)
godot --headless --path . -- --probe --geomtest | grep 'Per zone'   # live pickup count
```

**The revert is one constant**: `FULL_SHELF_FROM_LEG := 1` restores the old leg
1 completely. It was built to be revertible for exactly this reason.

**A separate finding inside it, now measured (D-068):** the human could only
*find* the grass, and that is placement, not shelf size. `--probe --findtest`
drives a goose to every leg-1 pickup and reports reach and the opening shot:

```
godot --headless --path . -- --probe --findtest 2>&1 | grep '^\[find\]'
```

The three grass patches are the nearest things and all in the opening shot. The
**double-double — half of THE WOBBLER, leg 1's one named combo and its flagship
(D-037) — is the least findable pickup in the leg**: the farthest from the
spawn, the only one on a prop (it needs a flap onto the dumpster), and out of
frame. Bread is findable, which is the point of bread, and since D-069 it looks
like bread rather than a grey sphere. Widening the shelf would not fix this.

Decide: revert the shelf, keep it, or keep it and move the pickups.
**Recommended, not taken:** keep, and move the double-double off the dumpster to
the lot's near side, because the combo it completes is what leg 1 is for.

---

## 3. BUGS THE HUMAN HAS ACTUALLY HIT

~~**"there is still no pause menu"**~~ **FIXED 2026-09-20, D-050** — `process_mode`
was `WHEN_PAUSED`, which gates `_input()` too, so the menu could close itself and
never open itself. Everything behind it (settings, Almanac, control card, roster,
restart) was unreachable with it. `inputtest` now presses Escape through the
viewport. **The finding that outlives it:** nothing in this project had ever sent
an input event through the viewport at all, so the whole UI was unverified. Two
sweeps since (D-051 to D-081) have driven every `_input` in the game.

**"all I can find is grass"** — §2 above; measured, and the placement is the
human's (D-068).

**Everything else the human hits belongs on this list — collect it in the
session rather than guessing at it here.**

---

## 4. CAT PETTING — designed, deliberately not built

> *"allow petting of the cats and idk let's think of smth funny that should
> happen"* → then, on being shown options: **"needs to be discussed in detail in
> the next session."**

Not built. Nothing was committed for it. What the survey turned up, so the
discussion starts warm:

**There is no free input action.** All nine are taken (`gg_forward/back/left/
right/flap/dive/eat/honk/share`, registered at runtime in `game.gd`, not in
`project.godot`). So petting should reuse **`gg_eat`** — and that is the joke
rather than a compromise: *a goose holding E at a cat is trying to eat it*, and
the game choosing to read that as affection costs zero new controls and reuses
the whole existing charge arc, sweet-spot band and abort.

**The best hook is already in the code and already funny** — `cat.gd:17-25`:

> *"Roughly two thirds of cats respond to catnip at all; the rest are
> genetically indifferent. So one cat in three here will simply refuse to help
> you, which is both accurate and much funnier than all of them working."*

`responds_to_nip` is live at `cat.gd:150` (it gates the frenzy). It splits the
cat population 2/3 – 1/3 *today*, for free.

**The pitch I'd have built, for the human to accept, reject or reshape:** hold E
at a cat; the split runs off `responds_to_nip`. The two-thirds that love catnip
want chemistry, not affection, and turn on you. The one-third that are
genetically indifferent — *the ones that are useless to you as artillery* —
purr, and follow you, pouncing without catnip forever after. **The cat you
cannot drug is the only one that likes you.** Catnip becomes a diagnostic: dose
it, watch who frenzies, and whoever ignored it is your friend. Two systems that
already exist, made to talk to each other.

Three alternatives were also drafted (running-gag escalation; the cat demands
tribute; a five-second version with no system). All are open.

Other verified hooks: `_nearest_victim()` scans groups `["npc", "chaos_prop"]`
— **the goose is not in that list**, so frenzied cats never attack the player
today. `_pounce()` is duck-typed on `startle()` / `shove()`, so anything can be
made cat-attackable by growing those methods.

*(A design workflow was run for this and mostly failed — seven of its agents
died on a network error, including all six comedy pitches. The four code surveys
that survived are the source of the hooks above, and one of their claims was
wrong: they reported `responds_to_nip` as an unused hook for "nipping the cat".
It is neither unused nor about nipping. Verify agent claims against the file.)*

---

## 5. The instrument work

Consumed. The per-step timeout this section used to point at is D-062, and
`docs/RECENT_FAILURES.md` is empty. `docs/HANDOFF.md` §3 is the queue now, and
it lists the `Open (human)` decisions in one table.
