# NEXT SESSION IS A PLANNING SESSION — DO NOT START IMPLEMENTING

**Set by the human on 2026-09-10, at the end of the twelve-gate session.**

> Read this before `docs/HANDOFF.md` §3. §3's ranked list is still correct about
> *instruments*, and it is the wrong queue to work from next time. The human's
> words: *"there are a lot of bugs and missing features that the full autonomous
> sessions somehow didn't think of doing, so next session will likely be a
> planning session with me (and also listing bugs) followed by autonomous
> implementation."*

**The shape of it:** plan and brainstorm WITH the human first, list the bugs
together, and only then go autonomous. Do not open with a code change. Do not
open by proposing the §3 list.

**This file is a working agenda, not a claim surface.** It is meant to be
consumed in the planning session and deleted or rewritten afterwards. Where it
states a number, the command that recomputes it is next to it, because the
number will rot and the command will not.

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

**A separate finding inside it, worth its own discussion:** the human could only
*find* the grass. That is not the shelf size, that is placement — the three
grass patches are infinite and obvious, while leg 1's other five pickups are two
berry sources at tree feet, one up a tree at y 4.6, a double-double at y 2.6
(elevated, needs a climb), and the bread over at (-34, -12) by the pond. **Even
the narrowed shelf is not discoverable.** Widening it back would not fix that.

Decide: revert, keep, or keep-and-fix-placement.

---

## 3. BUGS THE HUMAN HAS ACTUALLY HIT

~~**"there is still no pause menu"**~~ **FIXED 2026-09-20, D-050** — `process_mode`
was `WHEN_PAUSED`, which gates `_input()` too, so the menu could close itself and
never open itself. Everything behind it (settings, Almanac, control card, roster,
restart) was unreachable with it. `inputtest` now presses Escape through the
viewport. **The finding that outlives it:** nothing in this project had ever sent
an input event through the viewport at all, so the whole UI was unverified —
D-051 swept TAB, R and J too, and those three were fine. Original text:

**"there is still no pause menu"** — reported from real play. Do not treat as
missing; it is a live bug with a head start:
- `scripts/ui/pause_menu.gd` exists, is built in `main.gd::_build_overlays()`,
  sets `layer = 30`, and opens itself on `ui_cancel` in `_input()` (line 71).
- So the fault is downstream of all that. First suspects, in order: the
  `_suppressed` flag (line 44) that lets an overlay take ESC and may never hand
  it back; another overlay eating `ui_cancel` first (`almanac.gd:46`,
  `flock_roster.gd:260`, `briefing.gd`'s `DISMISS_ACTIONS`, `control_card.gd:88`
  — **five things listen for `ui_cancel`**); or the human seeing the mouse
  release (README: *"Escape releases it"*) and reading that as nothing happening.
- **No gate covers UI input at all.** Whatever this turns out to be, it got
  through twelve green gates, which is itself the finding.

**Everything else the human has hit belongs on this list too — collect it in the
session rather than guessing at it here.** The instruction was explicit:
*"listing bugs"* is part of the planning, with them.

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

## 5. Carried over from the instrument work — still true, still second

`docs/HANDOFF.md` §3 is accurate and is **not** the queue to open with. Its item
1 is real and cheap and should probably be swept up during implementation rather
than planned: `verify.ps1` has no per-step wall-clock timeout, so a `main.gd`
that will not parse hangs it forever, and the in-engine failsafe cannot help
because it lives in `main.gd` too. Recorded as F-005 in
`docs/RECENT_FAILURES.md`.

The five `Open (human)` decisions in `docs/DECISIONS.md` are unchanged and an
agent still must not close them. **D-019 is worth raising in the planning
session** — tolerance softening penalties is arguably part of why chemistry
feels inconsequential.
