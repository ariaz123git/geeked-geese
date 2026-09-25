# Recent failures

**At most five. An entry leaves this file only when it has been turned into a
check, and it names the check that retired it.**

---

## What this is, and why it is capped

`CLAUDE.md` already carries a list of things that have gone wrong here — the
parser hang, the inside-out mesh builder, the goose that flew tail-first, the
four-second input lag. That list is permanent prose and it only grows. It is
also the file loaded into every session and every subagent, and instruction
adherence degrades with instruction **count**: the dominant failure is silent
omission, and what gets omitted is whatever is furthest down.

So this file is the *bounded* version, and the bound is the mechanism rather
than a tidiness preference. It is the shape Reflexion uses — write on failure
only, store the **diagnosis** and not the transcript, and hard-cap the buffer,
because past a few entries the reflections dilute each other rather than
compound.

**The cap is a forcing function.** A sixth failure cannot be written down until
a fifth has been converted into an assertion, a hook, or a deleted footgun. That
is the only way a lessons file gets *smaller*, and a lessons file that never
gets smaller is just `CLAUDE.md` with extra steps.

`tools/doctest.gd::_the_failure_log()` enforces both the cap and the dating.

## How to write one

```
### F-00N · YYYY-MM-DD · one-line title
**Symptom:** what you saw, including the wrong number if there was one.
**Diagnosis:** why, in one paragraph. Not the debugging story — the cause.
**Retires when:** the specific check or change that would make this impossible.
```

**"Retires when" is not optional and must be a specific artefact**, not "be
careful". If you cannot name the check, the entry is not a lesson, it is a
grievance — and it should go in `docs/HANDOFF.md` §4 with its arithmetic
instead, which is where evidenced-but-unfixed things live.

## How one leaves

Convert it, then delete it in the **same commit** as the check that retires it,
with the check named in the commit message. Never delete an entry any other way:
a silently dropped entry is a lesson unlearned twice.

---

*Empty since 2026-09-25.* The last entry, F-001 (the audio streams reported
"still in use at exit"), was retired by stopping every player and giving the
mixer thread a moment in `Music._exit_tree()` and `Sfx._exit_tree()`, and by
`verify.ps1`'s `ScriptErrors` now failing any step whose exit reports leaked
resources. The diagnosis lives in the comment above `sfx.gd::EXIT_MIX_WAIT_MS`;
the decision is D-072.
