# Claims

**Every number this repo writes into a document, and where that number is
written.** `tools/doctest.gd` recomputes each one from the booted project on
every run and fails the build if any listed document disagrees.

> **The one rule this file exists to enforce:**
> **A number you put in a document gets a row here, or it gets deleted.**

---

## Why this file exists

`CLAUDE.md`'s banner names the project's most expensive failure mode — *"a
constraint recorded as prose keeps applying after it stops being true, because a
comment cannot run"* — and counts three blockages it caused. `docs/DECISIONS.md`
was the answer for **decisions**. This file is the answer for **facts**, which
rot exactly as silently and were never counted until 2026-08-18, when a survey
found **seven** live instances:

| where | said | actually |
|---|---|---|
| `docs/ARCHITECTURE.md` §5 | 35 textures, 12 HUD icons, 40 SFX | 39, 16, 39 |
| `README.md` §1 | 35 textures and 40 sounds | 39 and 68 |
| `README.md` §4 | six zones | eight |
| `README.md` | leg 5 is "the last placeholder in the route" | built, the stopover |
| `README.md` | "every zone still borrows the parking-lot loop" | seven beds |
| `GEEKED_GEESE_DESIGN.md` | "playable, 16 substances, **2 zones**" | eight zones |
| `README_KIT.md` | `CLAUDE.md` is "under 200 lines on purpose" | 379 |

Not one of those is a typo. Each is a sentence that was *true when written*, in
a well-written document, sitting next to sentences that are still true — which
is what makes it dangerous rather than merely wrong. Work on how models use
retrieved evidence (Xie et al., ICLR 2024) finds that external evidence is
adopted in proportion to how **coherent** it is, not how correct: a confidently
wrong number in a good document is the most persuasive thing in the repo.

## Why a live value, and not a "last verified" date

The obvious alternative is the shape a self-improving system is usually drawn
as: entries carrying counters or freshness stamps that some reflection pass
maintains. That needs a loop that runs every session and is trusted to be honest
about its own work — and a hand-maintained freshness stamp is stale metadata
*about* staleness.

**Nothing in this file stores an expected value.** `doctest.gd::_live()`
recomputes every number from the file tree or from the running project. There is
nothing here to maintain, nothing to go out of date, and no way for the gate to
pass by agreeing with an equally-stale copy of itself.

## How to add one

Two lines of work:

1. A row in the block below — **append, never rewrite**, the same discipline
   `docs/DECISIONS.md` uses and for the same reason.
2. A `match` case in `tools/doctest.gd::_live()` that computes it from the
   project.

**A key `_live()` cannot compute fails the build** with *"this check has gone
blind"* rather than being skipped. A check that silently does nothing is the
failure mode this project rates worst.

## How a row leaves

Two triggers, both mechanical, neither needing judgement:

- **The marker stops matching.** If a row's marker appears **zero** times in a
  listed file, the prose moved or was deleted and the row fails — fix it or
  delete it. If it appears **more than once**, two sentences carry the fact and
  the row is checking an arbitrary one of them; make the marker specific.
- **No document carries the fact any more.** A row whose file list is `—` still
  computes and prints its live value, but asserts nothing about any document.
  That is the state to delete a row from.

The marker is the literal string the prose writes **immediately after** the
number, so `| Code | 69 GDScript files |` is matched by `" GDScript files"` and
the row does not care where in the table it sits.

---

```claims
# id   | since      | key              | marker                | files
C-001  | 2026-08-18 | gd_scripts       | " GDScript files"     | docs/HANDOFF.md
C-002  | 2026-08-18 | substances       | " substances in the shelf" | docs/CLAIMS.md
C-003  | 2026-08-18 | png_textures     | " textures ("         | docs/HANDOFF.md
C-004  | 2026-08-18 | substance_icons  | " substance icons"    | docs/HANDOFF.md, CLAUDE.md
C-005  | 2026-08-18 | sfx_clips        | " SFX + "             | docs/HANDOFF.md
C-006  | 2026-08-18 | ambience_beds    | " zone ambience beds" | docs/HANDOFF.md, CLAUDE.md, docs/ARCHITECTURE.md, README.md
C-007  | 2026-08-18 | music_stems      | " music stems"        | docs/HANDOFF.md, CLAUDE.md, docs/ARCHITECTURE.md
C-008  | 2026-08-18 | route_legs       | " flown legs"         | docs/CLAIMS.md
C-009  | 2026-08-18 | flight_entries   | " flights, seven shapes" | docs/CLAIMS.md
C-010  | 2026-08-18 | autoloads        | " autoloads, in this order" | CLAUDE.md
C-011  | 2026-08-18 | feel_windows     | " windows asserted"   | docs/CLAIMS.md
C-012  | 2026-08-18 | claude_md_lines  | ""                    | —
C-013  | 2026-08-18 | wav_files        | " .wav files on disk" | docs/CLAIMS.md
C-014  | 2026-08-18 | png_textures     | " textures ("         | docs/ARCHITECTURE.md
C-015  | 2026-08-18 | png_textures     | " textures and"       | README.md
C-016  | 2026-08-18 | wav_files        | " .wav files."        | README.md
C-017  | 2026-08-18 | sfx_clips        | " SFX and "           | CLAUDE.md, docs/ARCHITECTURE.md, README.md
C-018  | 2026-08-18 | surface_textures | " textures and 16"    | CLAUDE.md
C-019  | 2026-08-18 | music_stems      | " music stems from"   | README.md
```

---

## The facts, in prose, so this file carries its own claims

Several rows above name `docs/CLAIMS.md` as the document that carries the fact.
That is deliberate rather than circular: the number has to be written down
*somewhere* in prose for a marker to check, and a fact with no natural home in
another document gets its home here. The gate reads these sentences exactly as
it reads `README.md`'s.

- The shelf holds **16 substances in the shelf**, loaded from `data/substances/`
  at boot by `Subs`. Adding one is a `.tres`, never a code change.
- The campaign is **7 flown legs**, plus the arrival on the 18th green, which is
  not a leg — no clock, no objectives, no flight out of it.
- The migration is **7 flights, seven shapes**: `migration.gd::FLIGHTS` gives
  each leg its own duration, hazard density, opening quiet and lethality.
- `tools/feeltest.gd` has **13 windows asserted**, each argued in
  `docs/FEEL_TARGETS.md` §2. `doctest.gd` checks that the two agree bound for
  bound — the file carrying the *argument* could previously drift from the file
  carrying the *enforcement*.
- The project ships **68 .wav files on disk**, all generated by
  `tools/gen_audio.py` and `tools/gen_music.py`. No imported audio anywhere.

## What is deliberately NOT claimed here

- **Anything the gates already print.** `[gate] PASS — N scripts` and
  `[selftest] PASS — N invariants` are recomputed and printed on every run; a
  claim row would only add a second place for them to be wrong. Numbers move
  into this file when a *document* starts repeating them.
- **`docs/DECISIONS.md`'s arithmetic.** D-019's tolerance table, D-015's pad
  geometry and the rest are dated, immutable records of what was measured *at
  the time*. They are history, and history is allowed to describe a build that
  no longer exists. That is the whole point of the supersede-don't-edit rule.
- **Anything in `docs/archive/`.** Archived documents are stamped with the date
  they stopped being current and are not checked.
