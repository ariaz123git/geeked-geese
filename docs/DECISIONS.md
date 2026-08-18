# Decisions

The authoritative record of **decision status** for this project — whether a
thing is open, decided, or has been reversed. Other docs may discuss a decision
at length; they should link here for its *status* rather than asserting it.

> **Convention.** A lightweight, single-file variant of **Architecture Decision
> Records (ADR)** — the pattern from Michael Nygard's "Documenting Architecture
> Decisions," where each record is a dated, numbered, immutable entry and a
> reversal is a *new* record that supersedes the old one rather than an edit to
> it. That "supersede, don't edit" rule is the whole point: it makes reversals
> visible instead of silent. This is established practice, not a house
> invention. The single-file, low-ceremony shape is borrowed from the same
> author's other project — **an entirely separate repo**, `C:/projects/habitmaxxer`,
> whose `docs/decisions/DECISIONS.md` and `docs/README.md` are the working model.
> Nothing at that path exists in *this* repo; ours is `docs/DECISIONS.md`.

---

## Why this file exists here specifically

This project has a documented, expensive failure mode: **a constraint recorded
as prose keeps applying after it stops being true, because a comment cannot
run.** It has now happened three times that anyone has counted:

1. `main.gd::ROUTE` forbade a 230 s leg 7 because `DEPART_AT` was "written
   against a 180 s clock" — after `zone_truckstop.gd` had grown `_clock_scale()`
   and made that false. It blocked the change for a whole session.
2. `boss_ranger.gd` said leg 6's exam was unbuilt because "leg 6 does not exist
   yet" — after `zone_corn.gd` shipped the corn field.
3. `CLAUDE.md`'s own banner told every session that the game "has never had a
   human playing it" and that "the next real work is tuning", after a session
   had built the instruments to do that tuning.

A decision that lives only in prose, in a commit message, or in one person's
head is the same bug. **If you make a call, log it here in the same session.**

---

## How to use this file

**When to add an entry** — low-judgment trigger, and when in doubt write the
one-liner: whenever a choice is made or reversed about scope, a feel/pacing
number, an architectural rule, a verification standard, or anything a future
session would otherwise assume is still open (or still settled).

**Who decides what** — see `CLAUDE.md`, *"Taste is the human's. Everything
measurable is yours."* Entries owned by the human are marked **Open (human)**
and must not be quietly closed by an agent. Entries an agent decided are marked
with what it measured, and are revertible in one commit.

**Lifecycle**
- **Open → Decided:** update the *same* entry, flip Status, stamp the date.
- **Decided → Superseded / Reversed:** do **not** rewrite the old entry. Flip its
  Status to `Superseded by [ID]` and add a **new** entry on top. The old one
  stays as the record.

**Entry format**

```
## [ID] · [YYYY-MM-DD] · [short title]
Status: Open (human) | Open | Decided | Superseded by [ID] ([date])
Decision: one line — the choice
Why: one line — the reasoning, with the number if there is one
Refs: files, commits, docs
```

IDs increment. Newest on top.

---

## D-019 · 2026-08-18 · Tolerance softens penalties, against the documented economy — recorded, not changed
Status: Open (human)
Decision: **Unresolved, and deliberately not decided by an agent.** `resolve()` picks `good` or `bad` per FIELD, but each of the four multipliers is a benefit on one side of 1.0 and a penalty on the other, so each scaling is right for only half its range.
Why: `docs/ARCHITECTURE.md` §3 and `substance.gd`'s own comment both say *"tolerance scales the good parts and never the bad ones — that asymmetry is the entire economy."* Measured at tolerance 3 (`tol = 0.488`): **eight substances have penalties softened** (percs' flap 0.80 → 0.90, speed 0.70 → 0.85; grass 0.78 → 0.89; plus bars, berries, gravy, robo, special_k, toad_slime) and **eight have benefits that never fade** (double_double's turn stays 1.50 at every tolerance, molly's 1.20, darts' 1.05; special_k's gravity stays 0.55, and four more). So the fourth percocet impairs you less than the first. The doc's own worked example — *"the fourth double-double gives you less speed and the same jitter"* — is one of the cases that is already correct.
**Recommendation if you want one:** select the scale by the DIRECTION of the declared value rather than by the field name, for `flap_mult`, `speed_mult` and `turn_mult` only. **Left open because** it makes six substances materially more punishing at tolerance and no instrument in this project can evaluate that; and because `gravity_mult` below 1.0 is genuinely ambiguous — floatier is a traversal *benefit* and a control *impairment* at once, which is a design call rather than arithmetic.
Refs: `scripts/core/substance.gd::resolve`; `docs/HANDOFF.md` §4.

## D-018 · 2026-08-18 · `Substance.stamina_restore` is wired, not deleted
Status: Decided (agent — revertible in one `if`)
Decision: `goose_controller.gd` now adds `res.stamina_restore` to the bird's stamina when a dose lands, flat and capped at 1.0. It was exported, set non-zero by **six** substances — bars 0.20, darts 0.20, double_double 0.40, grass 0.25, math 0.50, molly 0.30 — and read by **nothing**: not a key in `resolve()`, not named in any file under `scripts/`.
Why: The `.tres` files are this game's design record and six of them recorded a refund the player has never once received. Wired rather than deleted because the `float_height` precedent turns on *can it be honestly connected* — that dial went because there was no water surface to connect it to; this one connects in one statement at the exact site the dose lands, with substance and bird both in scope. **It is a balance change and nothing measures it**: `flap_cost` is 0.058, so math's 0.50 is about 8.6 extra flaps per dose. Revert by deleting the `if`.
Refs: `scripts/goose/goose_controller.gd::_tick_eat`; guarded by **D-017**.

## D-017 · 2026-08-18 · Every export on `Substance` must be connected to something
Status: Decided (agent)
Decision: `tools/selftest.gd::_the_substance_fields()` fails the build if an export on `Substance` is neither a key in `resolve()`'s returned Dictionary nor named by any file under `scripts/`. **No allowlist**, deliberately.
Why: `stamina_restore` (D-018) was dead for the life of the project and every gate passed, including the one that doses all sixteen substances and measures the bird — because they all reach into `Subs.take()` and none of them reads the export surface. The check is a floor, not a proof: naming a field anywhere counts, so it cannot false-fail, only false-pass. Watched fail on `stamina_restore` before the fix and pass after: **553 invariants**, up from 541.
Refs: `tools/selftest.gd`.

## D-016 · 2026-08-18 · A blown noise floor suppresses the ratio channels rather than reporting them
Status: Decided (agent)
Decision: When `substancetest.gd`'s two sober runs disagree, the two channels measured **as a ratio against sober** — peak turn rate and one-flap climb — are skipped for every substance, with a printed banner. Everything that stands on its own — drift, the macropsia pulse, `cannot_idle`, the clock, the cats — keeps running, and the build still fails on the one honest line.
Why: The file already printed *"nothing it reports about a substance can be trusted"* and then ran every ratio check anyway. On the red build that opened this session that turned **one** harness fault into **eight** failures, seven of which accused healthy substances of a broken `turn_mult` for being exactly 1/0.7 out. Canary-proven: forcing the floor to fail gives **1 of 109** instead of 8, and the one is true.
Refs: `tools/substancetest.gd`.

## D-015 · 2026-08-18 · The substance fingerprint is leashed to the pad
Status: Decided (agent)
Decision: The walk channel snaps the bird back to the pad, velocity intact, whenever it strays more than 6 m. The idle channel is deliberately **not** leashed — it sums path length and a teleport would be counted as travel.
Why: `PAD_RADIUS` is 9 m and its docstring sizes it for `feeltest`'s *"1.2 s of held forward at waddle_speed … about 5 m."* The substance fingerprint holds forward for **2.0 s** and not at `waddle_speed`: `math` measures 9.75 m/s = **18.5 m**, `fly_agaric` 11.8, `double_double` 11.4. On leg 1 the pad sits 21.5 m from an 11 m pond, leaving 10.5 m of grass and a 31° half-angle — measured **three failures in five runs**, against the ~40% the geometry predicts. Extending the pad was rejected: a 20 m clear ring may not exist in a zone, and a harness that fails on level design gets deleted. Nothing the walk measures reads position, so the leash is invisible to all three channels.
Refs: `tools/substancetest.gd::_fingerprint`.

## D-014 · 2026-08-18 · The dry-pad probe settles on a condition and rejects what it cannot answer
Status: Decided (agent)
Decision: `probe_common.gd` gains `_drop()`. Every pad probe now waits for the bird to reach the floor or the water instead of counting frames, the ring has **eight** spokes instead of four, a ring point the bird cannot floor is **rejected** rather than assumed dry, and the candidate is re-proven standing on its own centre before it is accepted. `substancetest.gd` also counts frames spent in water during a ground channel and names it a HARNESS FAULT — which `feeltest.gd` had done since it was written and this file never had.
Why: **This session opened on a red build.** The ring probed for water 6 frames after a 1 m teleport; ground gravity is 28 m/s², so that is 0.16 m of fall, and leg 1's pond is a cylinder that stops at y = 1.70 — a probe hovering at 2.16 over open water reported *dry*. The certified pad's ring point was **9.90 m from the pond centre against an 11 m radius**. The first sober fingerprint waded in and returned `speed 5.40` (`swim_speed` exactly) and `turnrate 19.79` (`28.27 × 0.7`, and the 0.7 lives only in `_tick_water()`). Seven substances were then accused of a broken `turn_mult`. Canary-proven by forcing the pad into the pond: **the old reproducibility guard passes** — both sober runs agree, being equally underwater — while the new counter fires 18 times.
Refs: `tools/probe_common.gd`; `tools/substancetest.gd`; `tools/feeltest.gd`.

## D-013 · 2026-08-18 · The Ranger's leg 6 exam stays unbuilt, blocked on a sound
Status: Open
Decision: `docs/BOSS_DESIGN.md` §2.1.4's exam is not built. Its propane cannon needs a bang, every sound in this game is generated by `tools/gen_audio.py`, and **no agent can hear the result.**
Why: The stated blocker in `boss_ranger.gd` ("leg 6 does not exist yet") was false — the corn field ships the standing corn, the stubble, the boundary and a combine that eats a row per pass, three of the four things §2.1.4 asks for. The real blocker is the audio, and it is a human one.
Refs: `scripts/world/boss_ranger.gd` header; `docs/BOSS_DESIGN.md` §2.1.4; `docs/HANDOFF.md` §3.

## D-012 · 2026-08-18 · Racking leaves one stock slot in four empty
Status: Decided (agent — revertible in one `continue`)
Decision: `prop_models_bigdown.gd::_racking()` skips one bale slot in four, chosen off the seeded wobble the stock already uses.
Why: The deck collider promises a clear full-width landing at every beam level; the mesh left **0.07 m at the aisle face and 0.17 m at the bay edges**, against a goose capsule **0.68 m wide and 1.10 m long**. The bird landed on the promised collider and was inside the bales, which breaks the "one level per flap" argument the 1.70 m beam pitch exists for. A factual collider-vs-mesh disagreement, not a taste call — but the *density* is a look, so the human may want a different fraction.
Refs: `scripts/world/prop_models_bigdown.gd`; first-ever interior render `--probe --leg:7 --goto:-2,5.5,-70`; `docs/HANDOFF.md` §4.

## D-011 · 2026-08-18 · Drift is gated on the drift vector, not the off-axis angle
Status: Decided (agent)
Decision: `substancetest.gd` asserts on `_drift`'s magnitude; the off-axis angle it produces is printed as corroboration and asserts nothing.
Why: `_drift` is built from sines seeded by an unseeded `randf()` and phased on wall-clock ms, so the angle a substance produces in any 2 s window is genuinely random — percs measured 0.15 to 0.99 rad across runs and the gate failed about one run in seven. Gating on the deterministic vector also *raised* coverage from 5 substances to all 13 that declare any drift.
Refs: `tools/substancetest.gd`; `docs/FEEL_TARGETS.md`.

## D-010 · 2026-08-18 · The substance EXEMPT list is empty, and catnip is measured on the cats
Status: Decided (agent)
Decision: No substance is exempt from the design rule. `catnip`'s only control mutation is `aggro_cats`, so `substancetest.gd::_the_cats()` measures the **cats** — all seven in leg 1 must enter `_frenzy` on a dose and leave it when the dose clears.
Why: The exemption was an admission in writing that if `aggro_cats` broke, nothing in the project would notice. An allowlist is where a real failure gets reclassified as an expected one.
Refs: `tools/substancetest.gd`.

## D-009 · 2026-08-18 · `fly.glide_ratio` is asserted as a regression guard, not an endorsement
Status: Decided (agent)
Decision: The window `[0.70, 1.10] : 1` is centred on today's behaviour so `glide_gravity`, `air_speed` or `max_fall` cannot move roof-to-roof traversal silently. It does **not** assert that 0.85 : 1 is the right glide — that is **D-006**.
Why: A metric can be worth locking against drift long before anyone has decided it is correct.
Refs: `tools/feeltest.gd`; `docs/FEEL_TARGETS.md` §5.1.

## D-008 · 2026-08-18 · The flock pen prompt sits at 1.66 m with render priority 4
Status: Decided (agent)
Decision: Raised from 1.03 m and given priority over the decorative name tags. `no_depth_test` stays **off**.
Why: At 1.03 it was below head height on a 1.3 m bird, so the geese in front drew their necks through it — the render read `[G] …AKE GOR… THE DD`. `no_depth_test` would have "fixed" it by letting the label shine through the strip mall wall, which tells the player their flock is inside the building. Verified by render: now reads `[G] MAKE TERRY THE DD`, whole.
Refs: `scripts/world/flock_pen.gd`. Evidence regenerates with
`godot --path . --rendering-driver opengl3 -- --probe --leg:1 --shots:1 --secs:2 --out:<dir>`
— `shots/` is gitignored, so the command is the durable artefact, not the PNG.

## D-007 · 2026-08-18 · The truck stop's closing beat stays proportional
Status: Open (human)
Decision: `_clock_scale()` leaves exactly **6.0% of the leg** as empty lot at every clock — 13.8 s at leg 7's 230 s, but 6.6 s at Mission's 110 s floor.
Why: A readable moment is arguably *absolute*, not proportional — a human needs roughly ten seconds to notice an empty lot whatever the clock says. Changing it is one line in `zone_truckstop.gd::_clock_scale()`. Not changed, because nothing specifies it and it is pacing.
Refs: `docs/HANDOFF.md` §4; `tools/selftest.gd::_the_rig_schedule()`.

## D-006 · 2026-08-18 · The glide is 0.85 : 1 and nobody has decided whether that is right
Status: Open (human)
Decision: Unresolved. One metre forward per metre down is a controlled fall, and `GEEKED_GEESE_DESIGN.md:130` promises *"chain it into a safe glide and you're fine."*
Why: Against changing it — the zones are 80 m across, and a 3:1 glide crosses one from a single flap stack, which trivialises the ground traversal the chaos scoring is built around, and silently invalidates "the goose cannot reach that" in eight zone builders. For changing it — flight between rooftops is the fantasy and thermals are a whole migration mechanic premised on altitude being worth something. **Taste. The human's.**
Refs: `docs/FEEL_TARGETS.md` §5.1; guarded by **D-009**.

## D-005 · 2026-08-18 · Every 20 m glide arrives at 20.9 m/s against a 13.0 hard-landing threshold
Status: Open (human)
Decision: Unresolved. Sober this is a 15-point "ROUGH LANDING" and a small shake — a reward. On any substance with `ragdoll_landings` it is an unavoidable faceplant on every descent from height, and nothing teaches flaring on approach.
Why: Either a good implicit lesson or an unfair one. That depends on playing it.
Refs: `docs/FEEL_TARGETS.md` §5.2.

## D-004 · 2026-08-17 · Leg 7 is 230 seconds
Status: Decided
Decision: `main.gd::ROUTE` leg 7 goes 180 → 230 s, which is what `docs/BOSS_DESIGN.md` §2.2.2 has always asked for.
Why: The comment forbidding it described a constraint `zone_truckstop.gd::_clock_scale()` had already removed. BIG DOWN needed no change — `DOCK_OPENS_WITH` (118 s left) puts the truck-stop phase at t=112, the 110 s §2.2.2 specifies, to within two seconds. The constraint is now `selftest.gd::_the_rig_schedule()`, checked on every clock the leg can legally be dealt.
Refs: `scripts/core/main.gd`; `tools/selftest.gd`.

## D-003 · 2026-08-17 · The flap SETS the climb; it does not add to it
Status: Decided
Decision: `_flap()` uses `maxf(velocity.y, power)` rather than `maxf(velocity.y, 0.0) + power`.
Why: The old form compounded — **7.36 m of climb in the first second of a held flap and 23.66 m in the third**, unbounded, because the 0.30 s cooldown only lets gravity take 3.3 m/s back against a power of 6.08. There is a `max_fall` in the controller and there has never been a `max_rise`. The fix leaves the single flap bit-for-bit unchanged at **1.73 m**, which is the level-per-flap BIG DOWN's 1.70 m racking pitch was built around.
Refs: `scripts/goose/goose_controller.gd`; `docs/FEEL_TARGETS.md` §4.

## D-002 · 2026-08-17 · Taste is the human's; everything measurable is the agent's
Status: Decided (human directive)
Decision: Agents no longer end a session by asking the human to go and play the game. Feel splits in two: **response** (time to top speed, stop distance, whether a held button converges) is arithmetic and is the agent's to measure, decide and record; **taste** (is a waddling goose funny) stays the human's permanently. Deferring taste no longer means stopping — make the call, log it here, keep going.
Why: `HANDOFF` §3 said "Play it" at the top of the list for two sessions running, everything behind it was blocked on one person having a free evening, and nothing behind it moved. The honesty rule is unchanged: **never claim you felt it.**
Refs: `CLAUDE.md`; `docs/HANDOFF.md` §3; `docs/FEEL_TARGETS.md` §0.

## D-001 · 2026-08-17 · The project is under git
Status: Decided
Decision: `main` holds the untouched baseline; work happens on branches. `_to_delete/` (90 MB of superseded zips and stale `.godot` caches) is gitignored, **not** deleted — that is the human's call.
Why: There was no `.git` at all, despite `VIBECODING_BRIEFING.md` making "commit before every task; `git reset --hard` instead of debugging a bad run" one of its six headline rules. The undo it describes had never existed. It was used within hours — twice, to isolate a parser stall by `git stash push <file>`.
Refs: `.gitignore`; `docs/SESSION_PROTOCOL.md`.
