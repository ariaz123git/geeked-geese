# Geeked Geese — agent kit

Drop-in setup for vibecoding this game with an AI agent that has file access to
`C:\Projects\Geeked_Geese`. Built 30 July 2026, pinned to **Godot 4.7.1**.

| File | Who reads it | What it is |
|---|---|---|
| **`VIBECODING_BRIEFING.md`** | **You. Read this first.** | The research: what goes wrong, what the data says, how to work. ~20 min. |
| **`KICKOFF_PROMPT.md`** | **You** | Ordered setup steps, then the exact message to paste into the other chat. |
| `CLAUDE.md` | The agent, automatically, every session | Project rules. Under 200 lines on purpose. |
| `docs/GODOT_4.7_RULES.md` | The agent, on demand | Version-pinned API reference. The antidote to stale training data. |
| `docs/ARCHITECTURE.md` | The agent, before structural changes | The decisions already made, and why. |
| `verify.ps1` | The agent, after every edit | The verification loop. The most important file here. |
| `tools/validate_project.gd` | Called by `verify.ps1` | Loads and instantiates every script and scene. |
| `.gitignore` | git | Godot 4.7 canonical. Note the comment about `.uid` files. |

## Order of operations

1. Read `VIBECODING_BRIEFING.md`.
2. Follow `KICKOFF_PROMPT.md` step 1 — create the project **in the Godot editor**, not from the agent.
3. `git init` and commit before the agent touches anything.
4. Paste `KICKOFF_PROMPT.md` step 3 into the other chat.

## The four things worth remembering

1. **Nothing is done until `verify.ps1` passes and you've read its output.** Exit code 0 is not enough —
   the script also fails on `ERROR:` in stderr, because broken scenes exit 0.
2. **Commit before every task.** When a run goes bad, `git reset --hard` beats debugging it.
3. **Three files per task, maximum.** Beyond that, plan first.
4. **`/clear` after two failed corrections on the same problem.** A fresh session with a better prompt
   beats a long one full of patches.

## Maintaining this

`CLAUDE.md` is the only file that should grow, and only by the trigger *"the agent got this wrong twice."*
Anthropic's pruning test for each line: **would removing this cause a mistake?** If not, cut it — a bloated
rules file makes the agent ignore the rules that matter.

`docs/GODOT_4.7_RULES.md` can grow freely; it loads on demand, not every session. When the agent discovers
a 4.7 quirk the hard way, that's where it goes.
