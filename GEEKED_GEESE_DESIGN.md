# GEEKED GEESE
### *Honk Responsibly*

> A 3D physics-comedy game where you are a Canada goose who has discovered the
> human world's chemistry set, and you have 2,000 km to fly before winter.

**Status: the campaign is built end to end — 16 substances, eight zones, two
bosses, seven flights and an ending.** See
`README.md` for how to run it and exactly what's wired up. This document is the
design bible — it describes the whole intended game, including parts not built.

---

## 0. The one-line pitch

**Untitled Goose Game** meets **Katamari Damacy**, except every substance you
eat rewrites your control scheme, and you have to get an entire flock of
increasingly wrecked geese to Florida.

The joke that makes the whole game work: **geese are already the most
belligerent animal in North America.** Nobody needs to explain why a goose
would eat something it found in a parking lot. That's just Tuesday.

---

## 1. Structure — "The Flyway"

Roguelike migration south, alternating two modes:

**ZONE (3 min).** A hand-built sandbox — a Tim Hortons parking lot, a prairie
grain silo, a Muskoka cottage at night, a Montreal alley in winter. Loud,
freeform, comedic. Rack up Chaos, get wrecked, wreck your flock.

**MIGRATION (60–90 s).** Fly the V to the next leg. Rhythmic, focused, tense.
See §5 — this is where the bill for the zone arrives.

Building the zones this way means **"Free Honk" mode falls out for free**: same
zones, all unlocked, no stamina clock, no migrations. That's the demo. A
4-player physics brawler stays a post-launch idea, only if the physics hold up.

The alternation is doing real work. Games that switch texture like this feel
much bigger than they are.

---

## 2. The core mechanic: substances are VERBS, not stat buffs

The single most important rule in this document.

> **A substance must never be only a number that goes up. It must change how
> the player's hands work.**

If `"Fermented Berries: +20% damage"` ends up in this game, the game is dead.
Every substance gets its own **control mutation**, **camera treatment**,
**post-process look**, and **honk pitch**. Players should be able to tell what
someone else is on from across the room with the sound off.

### The substance table

Every entry names what it's a joke about. If you can't fill in the Mimics
column, you don't know what you're designing yet — and you'll need that column
anyway for the ESRB self-report.

| In-game | Mimics | The bit | What it does to your HANDS | Built |
|---|---|---|---|---|
| **Fermented Berries** 🍒 | Ethanol | Crabapples that spent all winter turning to cider on the branch | Input lag + drift. Landings become full ragdoll. Smashes through props. | ✅ |
| **Double-Double** ☕ | Caffeine | Dumpster coffee. Still warm. Don't ask. | 2× flap rate, and you **cannot stand still** — idle input still drifts | ✅ |
| **Whippet** 💨 | Nitrous oxide | Whipped cream cans in the party garbage | 7 seconds of slow-motion, sub-bass honk, then you fall out of the sky | ✅ |
| **Math** 📄 | Methamphetamine | A page of grade 9 long division blowing across the lot | Fastest thing in the game and **you cannot turn**. Comedown lasts 16s. | ✅ |
| **Grass** 🌿 | Cannabis | It's grass. You're a goose. This is lunch with extra steps. | Slow, heavy, dopey, longest duration, and the **lowest Chaos multiplier in the game** | ✅ |
| **Special K** 🥣 | Ketamine | A cereal box in the recycling | **The camera detaches from your bird** and drifts. You still steer. Good luck. | ✅ |
| **Robo-Trippin'** 🍷 | DXM | Cough syrup from a bathroom cabinet | Movement **snaps to 90°**. You are now a robot goose. | ✅ |
| **Molly** 🐕 | MDMA | Molly is a golden retriever at the dog park. She licks your face. | Everything is wonderful, flock cohesion maxes, 13-second serotonin crash | ✅ |
| **Darts** 🚬 | Nicotine | Half a pack behind the plaza | Barely does anything — and racks up tolerance **3× faster than anything else** | ✅ |
| **Gravy** 🥣 | Dimenhydrinate (Gravol) | A poutine container that is not poutine | Deliriant: spawns **fake props and fake NPCs you cannot tell from real ones** | ✅ |
| **Bars** 🧼 | Alprazolam | A bar of soap in the laundromat | Perfect steadiness, zero screen shake — and **the HUD forgets to exist** | ✅ |
| **Percs** 💊 | Oxycodone | A pill organiser in a purse | No fall damage, can't tumble, nothing hurts. Slow. You nod off. | ✅ |
| **Acid** 🔋 | LSD | A car battery leaking in the lot | 90-second trip level. Colours cycle, geometry breathes. | ✅ |
| **Catnip** 🌿 | Nepetalactone | Somebody's herb garden | Nothing to *you*. Turns every cat in the zone into your artillery. | ✅ |
| **Toad Slime** 🐸 | Bufotoxin / 5-MeO-DMT | A toad in the cattails, at night | Kaleidoscope trip you **cannot end early** | ✅ |
| **Fly Agaric** 🍄 | Muscimol | The storybook mushroom, red cap and white spots | **Macropsia**: your body pulses 0.35×–2.8× in waves. Scale is a traversal tool. | ✅ |
| **Shrooms** 🍄 | Psilocybin | Lawn mushrooms after rain | The **world** rescales, not you. Non-Euclidean shortcuts open. | ⬜ |
| **The Toad** 🐸 | 5-MeO-DMT | A cane toad at the cottage, at night | Different render pipeline entirely. Flock members become geometry. | ⬜ |
| **Bath Salts** 🧂 | Synthetic cathinones | A jar by the tub | You become the aggressor and **cannot stop attacking** | ⬜ |
| **Screech** 🥃 | Rum | Newfoundland's finest, found in a shed | Berries, but worse, and it lasts | ⬜ |
| **Poutine** 🍟 | *nothing* | Every parking lot in Québec | Mass +300%. Sink in water. Terrible idea. Extremely funny. | ⬜ |
| **Road Salt** 🧂 | *nothing* | Highway shoulder | Restores stamina, no downside. The boring correct answer — include it so the player can *choose* not to be interesting. | ⬜ |

Two deliberately aren't drugs. The table needs a floor and a ceiling of
seriousness or the joke has nothing to push against.

### The Sweet Spot bar

Every substance has a dose curve drawn as an arc: too little does nothing, the
middle band is the power, past the band is the funny-but-bad zone. Holding
[E] longer = more dose. **The skill is stopping, not holding.**

---

## 3. The Goose Brain (the HUD, and the whole educational spine)

Bottom-left: a cutaway goose skull with four glowing fluids sloshing in it,
labelled with the real names, **never explained**.

- **Dopamine** (gold) — drives the Chaos multiplier
- **Adrenaline** (red) — flap power, panic-honk range
- **GABA** (blue) — steadiness, precision, landing accuracy
- **Serotonin** (green) — flock cohesion

Players learn the words by reading their own HUD for twenty hours and then go
look them up themselves. That's the win condition. No tooltip ever says
"dopamine is a neurotransmitter."

---

## 4. Systems that are secretly the lesson

Good game design first. The education is a side effect — the only way it
survives contact with a player.

**Tolerance.** Same substance in consecutive zones and the effect band shrinks.
Tolerance scales the *good* and never the bad. Persists across legs forever.

**Mixing.** Two at once is a third unique effect and usually *great* — Coffee +
Berries = **THE WOBBLER**, fast and uncontrollable, best speedrun tool in the
game. **Three at once always rolls the bad table**: 20 seconds gone, screen
black, you wake up somewhere else. Players will teach each other "never
triple," which is the entire lesson delivered by other players for free.

**Comedown.** Every effect ends strictly worse than baseline. The tension is
*when* to spend, never whether. Chain it into a safe glide and you're fine.
Chain it into the 401 and you're a hood ornament.

**Set & setting, literally.** Same substance behaves differently by zone. Toad
slime on a quiet cottage lake is a beautiful trip and a big payout. Toad slime
in downtown traffic is the worst 90 seconds of the run. The mechanics encode
the real principle and never say the words.

**Hydration.** A pond meter. Effects resolve cleaner. Trivial to build, true,
and it gives the player a reason to touch every water body in the level.

---

## 5. The migration, and the best mechanic in the game

The flock is **data during a zone** and only becomes physical birds during the
flight. That's the scope-saving decision of the whole project — no flock AI
has to survive the chaos sandbox. And the flock arrives at the flight in
exactly the condition you left it in. **The zone is where you write the cheque.
The migration is where it clears.**

### Lead rotation

The bird at the point of the V gets **no drafting benefit** and burns far more
energy — which is why real geese rotate the lead. So mid-flight you have to
hand the point off. But only to a bird sober and rested enough to hold a shift.

Party too hard in the last zone and there is **nobody to hand off to.** You
keep burning. You land short.

That one rule makes "how hard did I party" the central tension of the flight,
it's true biology, and it turns the interstitial into the most strategically
interesting screen in the game instead of a tax between the fun parts.

Supporting systems: **drafting** (tight V costs less stamina), **formation
integrity** (wrecked birds drift, drag goes up, distance slows), **honk to
rally** a drifter back into slot, **thermals** for free altitude and a
breather, **headwind bands**, and hazards that are real hazards for real
migrating birds — transmission wires and wind turbines.

Fail state is **landing short**, never death. You arrive at the next leg with
less time on the clock.

### The Designated Driver

You may assign one goose to stay clean. It refuses everything for the rest of
the run. It's the bird you can *always* rotate the lead to.

You make that choice in the zone, by resisting the urge to dose one bird, and
you get paid for it in the air. Give it a tiny high-vis vest. Name it. Players
will build around the sober one and grieve when it goes down, and that's a
genuinely great emergent lesson that cost you zero cutscenes.

---

## 6. World & route

Hub is **the pond** — a suburban stormwater retention pond behind a strip mall,
true natural habitat of the modern Canada goose. Nest upgrades, flock roster,
codex.

1. **The Retention Pond** — tutorial. Bread. It's bad for you. (True.)
2. **Strip Mall Lot** — Tim Hortons, caffeine, shopping carts, minivans ✅ *built*
3. **Suburbia** — sprinklers, cats, catnip, a guy with a leaf blower
4. **The Prairie Silo** — fermented grain, combines, big skies
5. **Cottage Country** — night zone, loons, campfire, toad slime, canoes
6. **Montreal Alley (winter)** — vertical, icy, poutine, fire escapes
7. **The 401** — pure highway hell, no substances, tests everything
8. **The Golf Course, Florida** — the promised land. Sprinklers forever.

**Bosses:** the **Park Ranger** (a pursuit, not a health bar) · the **Zamboni**
(arena chase on a frozen pond) · **BIG DOWN**, the CEO of a luxury parka
company in a glass tower with a very specific interest in your species.

---

## 7. Making the educational part not suck

1. **Never interrupt fun with text.** Zero mid-gameplay popups. Ever.
2. **Facts go where the player is already stopped** — death screen, loading
   glide, codex, back of a collectible card.
3. **The Bird Brain Almanac** — real, sourced animal and drug pharmacology.
   All nine built substances already carry a true `codex_fact`. A sample:
   - **Waxwings really do get drunk.** Mountain ash and crabapple ferment on
     the branch through winter; birds that gorge on them fly into windows.
     Canadian rehabbers take them in every year and let them sleep it off.
   - **Caffeine is in flower nectar on purpose.** A 2013 *Science* paper found
     caffeinated nectar sharpens a bee's memory of a flower and makes it return
     more often. The plant is dosing its pollinator to build brand loyalty.
   - **Nicotine is an insecticide** the tobacco plant makes to paralyse insects
     chewing its leaves. It was sold as a commercial pesticide for decades.
   - **Reindeer and fly agaric** — the "shamans drank reindeer urine" story is
     far shakier than the internet claims. Put the *dispute* in the codex.
     Teaching a kid that a fun fact is contested is worth more than the fact.
   - **It's a "Canada goose," not a "Canadian goose."** Running gag: any NPC
     who says "Canadian goose" gets attacked on sight. First codex unlock.
4. **The harm-reduction content is the difficulty curve.** Tolerance, mixing,
   comedown, set-and-setting, hydration, and the load-bearing sober friend.
   Those six systems are the whole message and none of them is a sentence
   anyone reads.
5. **One sincere moment, at the end.** After the Florida golf course, the
   retired geese who stayed. Don't moralise. Earn it with fifteen hours of
   stupidity first and it'll hit harder than any lecture.

---

## 8. Art & audio

**Art:** stylized low-poly, chunky silhouettes, oversaturated. Not realistic —
realistic geese on drugs is a horror game. *Untitled Goose Game*'s restraint
with *Jet Set Radio*'s palette. Cheap, ages well, reads at speed.

**Each substance owns a full post-process stack.** This is where the "wow"
budget goes. It's shader work, not art assets, so one person can do all of it.

**Audio is 50% of the comedy.**
- **The honk gets its own button.** Let players spam it. Honk stuns, honk
  rallies the flock, honk shatters glass.
- **The honk pitch-shifts per substance.** Nitrous honk is demonic sub-bass;
  Math honk is a stuttering machine gun. This one detail will be 100% of your
  clips on social media. Treat the pitch table as a design surface.
- Soundtrack: Canadiana through a blown speaker. Fiddle, but wrong.
- Ambient muffled Canadian dialogue, all of it complaining.

---

## 9. Tech

**Godot 4.7.1**, plain build, GDScript. Free, no revenue share, good 3D, and
its shader system is ideal for the per-substance work. GL Compatibility
renderer so it runs on integrated graphics.

**Substances are data-driven from day one** — one `Substance` resource holding
stat deltas, control mutations, a post-process stack, honk pitch, and dose
curve. Adding substance #40 is a designer filling in a form. This was worth
getting right in week one; it would have been a rewrite in month four.

**Multiplayer: don't.** Not in v1. Physics-comedy netcode will eat the entire
project.

---

## 10. Shipping reality check

- Steam is fine with drug content. Self-report it; expect **ESRB M / PEGI
  16–18** for "Use of Drugs." Consoles are fine too, Nintendo will look harder.
- **File the serial numbers off the parka company.** No real logo, no real name
  in text. "BIG DOWN," visually unmistakable, legally distinct. Parody is
  defensible; trademark use in your store art is a fight you don't need.
- Same for Tim Hortons — "Tim Hornton's," "Grimmy's." Canadians will get it
  from the cup silhouette alone.
- **Never write a how-to.** No substance in this game should ever teach
  sourcing, preparation, or real dosing. The joke is the *name* and the
  *control mutation*. That line is also what keeps the rating from sliding and
  the store pages from getting pulled.
- Discovery strategy is a 9-second video of a goose on nitrous. Build for that.

---

## 11. Two decisions worth not re-litigating

**Substances are resources, not code.** One `.tres` per substance, loaded from
`data/substances/` at boot. Sixteen exist; adding the seventeenth is a designer
filling in a form. The controller never asks "am I on berries?" — it asks
`Subs.mods` what its input lag is *right now*. That indirection is why the
substance count could quadruple in an afternoon without touching the controller.

**Fly agaric taught us the right way to do "the world changes size."** Don't
scale the world — scale the goose, and let the camera and movement speed follow.
It's physically honest (a tiny goose genuinely fits under the dumpster; a huge
one steps over a minivan), it's one line of transform code instead of a
rendering project, and it turns a screen effect into a **traversal tool**. Reach
for that pattern before reaching for a shader.

---

## 12. Loose ideas worth stealing later

- **Bread Debuff.** Bread is genuinely bad for geese. Make it the one purely
  negative consumable, and let humans throw it at you as an attack.
- **Angel Shot.** A goose so wrecked it briefly achieves perfect flight. Once
  per run. Unreliable. Legendary when it lands.
- **Molting season.** Real geese lose flight feathers for ~6 weeks a year. A
  mandatory mid-game zone where you *cannot fly.* Ground stealth chapter, real
  biology forcing a genre shift.
- **Photo mode.** Non-negotiable. This is a game about how things look when
  they're wrong.
- **Honk-activated formations.** Long honk swaps the V for a wedge, a line, a
  column. Different drag profiles. Skill ceiling for free.
- **The goose remembers.** Persistent scars, limps and stains across runs.

---

*"Honk responsibly" is the tagline, the joke, and the entire thesis. Keep it.*
