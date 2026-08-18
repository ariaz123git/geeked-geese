# The zone clock, and the camera at spawn

Two small systems that each shipped a bug twice, for the same underlying reason:
**two files independently computing something that only one of them should own.**

---

## 1. The clock

### What went wrong, twice

The results card tells you how much time you get next leg. The game then hands
out a different number.

- **First occurrence.** `mission.gd` clamped the next zone's time to `[110, 210]`
  and `main.gd` clamped it to `[100, 220]`. The card promised 2:20 and the game
  gave 1:48.
- **Second occurrence** (this session, after `ROUTE` was introduced).
  `main.gd` computed the base from `ROUTE[leg].seconds` — 150 s at the stopover,
  240 s at the pond — while `mission.gd` still assumed a hardcoded `180.0`. The
  worst case was leg 4 → 5: card `3:00`, game `2:30`.

The second occurrence is the instructive one. The first fix unified the *clamp*
and left two copies of the *base*, so the moment the base stopped being a
constant the bug came back wearing different numbers.

### The rule now

**`main.gd::ROUTE` is the only place a leg's length is written down**, and
**`Mission.clamp_zone_seconds()` is the only place a length is bounded.** Both
the promise and the payment call the same two functions:

```gdscript
# main.gd — the payment
var base: float = float(_route_entry(Flock.leg).seconds)
if not made_it:
    base -= 60.0
Game.start_zone(Mission.clamp_zone_seconds(base + modifier))
```

```gdscript
# mission.gd — the promise
var base := leg_seconds(next_leg)          # reads ROUTE
result.next_seconds = clamp_zone_seconds(base + result.zone_time_modifier)
```

If you add a leg, add it to `ROUTE`. If you change the bounds, change
`clamp_zone_seconds()`. **Do not write `clampf(..., 110.0, 240.0)` anywhere
else** — that literal is the bug, and it has now been the bug twice.

### The one place they still legitimately disagree

`main.gd` subtracts 60 s for a migration that landed short. The results card is
computed *before* the flight, so it cannot know, and is therefore optimistic by a
minute on a missed crossing. That is a design question — should the card promise
a range? should the flight's own results screen restate it? — not a drift bug.
It is deliberately left alone and recorded here so it is not "fixed" by
reintroducing a second base.

### Why not a hard fail?

Nothing about the clock kills a run. A weak leg and a short landing both cost
time and never a life. The floor exists so the worst possible compounding still
leaves a playable zone; the ceiling exists so a perfect run does not turn the
pond into a ten-minute sandbox.

---

## 2. The camera at spawn

### What went wrong

`goose_camera.gd` derived its yaw from the goose's **velocity**. A goose standing
still has no velocity, so the fallback was world `-Z`, and **every zone's opening
shot was decided by the world axis rather than by the zone author.**

`zone_cottage.gd` had a comment saying "face the water" next to a `heading` that
pointed away from the lake — and nobody noticed, because the camera was ignoring
`heading` entirely and the two errors cancelled into something that looked
deliberate.

### The rule now

The camera **adopts `goose.heading` when the goose is not moving**, including on
the first frame, and returns to following velocity as soon as it is. So:

- A zone author sets `goose.heading` and gets the shot they asked for.
- Turning in place turns the camera; the old behaviour left it pinned.
- Nothing changes once the goose is actually moving, which is the case the
  velocity-follow was written for and is still correct for.

### Why it matters more than it sounds

Every zone's first two seconds are its whole first impression, and this is the
only code that decides what the player is looking at during them. It is also the
kind of bug that hides forever behind a plausible-looking result: pointing at
world `-Z` is a *reasonable* shot in a zone that happens to be laid out along
`-Z`, which four of the seven are.

### The related trap

`-Z` is forward and **Godot's front faces are clockwise**. A `heading` off by π
looks like a camera bug, a mirrored decal looks like a texture bug, and an
inside-out mesh looks like a lighting bug. When something is "backwards" in this
project, check the axis convention before you check anything else.
