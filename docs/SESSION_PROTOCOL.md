# Session protocol

How to start and finish a session on this project without losing anything. A
how-to guide, not a reference — the *rules* live in `CLAUDE.md`, the *state*
lives in `docs/HANDOFF.md`, and the *decisions* live in `docs/DECISIONS.md`.

---

## Read order for a fresh session

Read these in order. **When two of them disagree, the earlier one wins**, except
that the codebase beats everything — it is the only thing that cannot lie about
what is currently built.

| # | File | What it is authoritative for |
|---|---|---|
| 0 | the code, and `.\verify.ps1` | what is actually built and actually passing |
| 1 | `docs/HANDOFF.md` | **current state** — what changed last session, what to do next, what is broken |
| 2 | `docs/DECISIONS.md` | **decision status** — what is settled, what is open, what is the human's call |
| 3 | `CLAUDE.md` | **stable rules** — how to work here, what the engine will do to you |
| 3.5 | `docs/RECENT_FAILURES.md` | **what went wrong most recently, and what would retire it.** Five entries, capped. Shorter than everything above it and the most likely to save you an hour |
| 4 | `docs/FEEL_TARGETS.md`, `docs/ARCHITECTURE.md`, the specs | why a number or a structure is what it is |
| — | `docs/CLAIMS.md` | not read, *run*. Every number the docs state, recomputed from the project by `--doctest` |

`CLAUDE.md` is deliberately *below* HANDOFF and DECISIONS in this order. It
changes rarely, which is its value and also its risk: it went a whole session
telling every reader the game "has never had a human playing it" after that had
stopped being the useful framing. **Rules age. State and decisions are dated.**

---

## Starting

1. **Run `.\verify.ps1` before touching anything.** Eight gates, about four
   minutes. You need to know whether you inherited a green tree — if it is red
   when you arrive, that is the first thing to say and the first thing to fix.
2. **Read HANDOFF §1–§4**, then skim **DECISIONS** for anything `Open (human)`.
   Do not silently close a human's open decision.
3. **Check you are on a branch**, not `main`. `main` is the last known-good.

## Finishing

Do all seven. The first four are cheap; skipping them is how the next session
loses a day. **Steps 6 and 7 are the two that make this repo get better rather
than merely bigger, and they are the two a gate can check.**

1. **Update the four ⟳ sections of `docs/HANDOFF.md`** — §1 where the project
   is, §2 what changed, §3 what to do next, §4 known issues and honest gaps.
   HANDOFF's own header says it: *"If it goes stale it is worse than useless,
   because the next session will trust it."*
2. **Log every decision in `docs/DECISIONS.md`**, in the session it happened.
   Ask explicitly: *did I decide anything, or discover that something already
   decided is now false?* A choice that lives only in a commit message is
   invisible to the next reader.
3. **Run the full `.\verify.ps1`** and paste the real output into the commit.
   Exit code 0 is not sufficient — read the lines.
4. **Commit with the reasoning, not the diff.** The diff is in git; what is not
   in git is *why*, *what you measured*, and *what you rejected*. The commit
   messages on `session2-feel` are the worked example.
5. **Say plainly what you did not finish**, and put it in HANDOFF §3 or §4 with
   enough context to be picked up cold.
6. **Every number you wrote into a document gets a row in `docs/CLAIMS.md`, or
   gets deleted.** One row plus one `match` case in `tools/doctest.gd::_live()`.
   A fact stated in prose and checked nowhere is the failure mode this project
   has paid for ten times: three constraints (see above) and seven facts, found
   on 2026-08-18 by the survey that produced the claims gate. If you cannot
   compute the number from the booted project, do not write it down.
7. **Write what went wrong into `docs/RECENT_FAILURES.md`, or retire one.** The
   file holds **five** entries and no more. If it is full, the price of adding
   yours is converting one of the existing five into an assertion, a hook, or a
   deleted footgun — and naming that check in the same commit that removes the
   entry. The cap is the mechanism, not housekeeping: it is the only reason a
   lessons file ever gets *smaller*, and an ever-growing lessons file is
   `CLAUDE.md` with extra steps. Every entry needs a `**Retires when:**` line
   naming a specific artefact; if you cannot name one, what you have is not a
   lesson and it belongs in HANDOFF §4 with its arithmetic.

> **Both of those are enforced by `--doctest`**, step 6b of `verify.ps1`, so
> "I forgot" fails the build rather than costing the next session a day. It also
> holds `CLAUDE.md` to a line ceiling that ratchets **down only** (D-026): to add
> a rule, take one out, or convert one into a check.

---

## Things that cost real time here — do not rediscover them

**A harness accuses the game long before it finds a real bug.** Four measuring
gates were written in one session and *every one of them* spent its first runs
blaming a healthy game: the goose spawns in a pond so "ground" metrics measured
swimming; the zone's cats shove the bird mid-measurement; the tree pauses behind
your back and freezes the thing you are timing; a substance ends before the
measurement does; and half the drivers are sine-phased or rotating so a short
sample, or a net-displacement metric, reads zero. **Read the header of
`tools/probe_common.gd` before writing a fifth.** The habit that caught all of
them: measure the baseline twice and refuse to report anything if the two runs
disagree.

**`sed -i` destroys this repo's line endings.** Most of the tree is CRLF, GNU sed
rewrites it LF, and you get a diff where every line changed. It cost `verify.ps1`
a 488-line diff for a 30-line edit. Use the Edit tool or a Python read/replace on
`'rb'`/`'wb'` bytes. `git diff --stat` catches it instantly.

**A reused local name can hang the parser with no output at all.** `--gate`
prints nothing — not even `compiling N scripts` — and never exits. It happened
twice in one session. If the gate goes silent, the last edit is the suspect:
`git stash push <file>` and re-run. See `CLAUDE.md`.

**Anchor your string replacements.** A blanket replace of `_release_all()` also
rewrote the *definition* into `static func COMMON.release_all()`, which the gate
reported only as "Could not preload resource script".

**Kill stray Godot processes before diagnosing a hang.** A killed run can leave a
process holding the project, and the next gate looks like it is stalling when it
is only queued behind a corpse.

---

## What only the human can do

Playtesting, deciding what is funny, and judging whether the game is fun — see
`CLAUDE.md`, *"Taste is the human's. Everything measurable is yours."* The open
entries in `docs/DECISIONS.md` marked **Open (human)** are the current list, and
it is short on purpose: right now it is the glide ratio (**D-006**), the
hard-landing threshold (**D-005**), and the truck stop's closing beat (**D-007**).

**Never fabricate a judgement about how something feels.** Report what you
measured, or say you decided without measuring and why. Never claim you played it.
