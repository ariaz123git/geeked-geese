# Vibecoding Geeked Geese — what the research actually says

Written 30 July 2026. Everything version-specific here was checked against the Godot 4.7 source and docs, or
executed against a real 4.7.1 binary — not recalled. Sources at the end.

This is the "why" document. The rules themselves live in `CLAUDE.md`; the API details in
`docs/GODOT_4.7_RULES.md`; the decisions in `docs/ARCHITECTURE.md`. Read this one once, then mostly ignore it.

---

## The short version

Six things, in order of how much they matter.

1. **Give the agent a way to check its own work.** Everything else is downstream of this. `verify.ps1` is
   the most important file in the kit.
2. **The engine is newer than the model's training data.** Godot 4.7 shipped six weeks ago. Left alone, the
   agent will write Godot 4.2-era code, and a nonzero amount of Godot *3* code.
3. **Static typing is your compiler.** GDScript's warnings-as-errors config turns a hallucinated method name
   into a parse error. It only works if types are known.
4. **Three files, maximum, per task.** This ceiling shows up in every first-hand account of this going wrong.
5. **Commit before every task; `git reset --hard` instead of debugging a bad run.** Anthropic's own data
   science team calls it treating the agent like a slot machine.
6. **You will have to learn some Godot.** Every honest account of vibecoding a game reaches this. Better to
   plan for it than to discover it at 3 AM.

---

## 1. The feedback loop is the whole problem

Anthropic's own best-practices doc puts this first, and the phrasing is worth memorising:

> *"Claude stops when the work looks done. Without a check it can run, 'looks done' is the only signal
> available, and you become the verification loop."*

For web work the loop is free — run the tests, curl the endpoint. For a game it's the hard part: the agent
can't press play, can't see the screen, can't feel whether the goose is fun. One developer's summary of
building with Claude in Godot: *"it reads the scene file, it does not run the scene… it cannot press play
and read a live debugger error."*

So the loop has to be built. Here's what actually works in Godot 4.7.1, cheapest first. All of this is in
`verify.ps1`.

**Layer 1 — does it load?** `tools/validate_project.gd` loads every script and every scene, instantiates
each one, adds it to the tree so `_ready` and `@onready $NodePaths` resolve, then frees it. Takes about
0.3 seconds on a small project and catches the majority of what goes wrong: syntax errors, type errors,
hallucinated method names, dangling resource references, missing node paths.

Two non-obvious things about this:

- **Don't use `--check-only`.** It's the flag everyone reaches for and it's much weaker than it looks. It
  reports a *false failure* on every script that touches an autoload — the analyzer resolves autoloads but
  the compiler needs the runtime global, which doesn't exist that early in startup. And by default it
  *passes* `node.this_method_does_not_exist()`. In a real project with autoloads it's close to useless.
- **Exit code 0 is not enough.** A `.tscn` with a dangling `ext_resource`, or a script with
  `@onready var x = $DoesNotExist`, prints loud errors and **exits 0 anyway**. `verify.ps1` greps stderr
  for `ERROR:` and fails on it. Without that check, half the value is gone.

**Layer 2 — do the systems behave?** Unit tests via GUT (use the `godot_4_7` branch of `bitwes/Gut`, version
9.7.1 — the Asset Library serves a 4.6-era build). Exit 0 all-pass, 1 any-fail.

Be ruthless about *what* you test, because this is where agent-written test suites waste the most effort:

*Worth testing:* pure functions (score math, dose curves, stamina), save/load round-trips, state-machine
transitions, signal contracts, and **physics invariants** — the goose never ends up below the floor, no
`Vector3` component is ever NaN, the simulation settles within N seconds, no orphan nodes after teardown.

*Not worth testing:* exact positions after a ragdoll interaction (Godot physics isn't bit-deterministic
across versions — these break on 4.7.2 and teach the agent to loosen tolerances until they mean nothing),
anything about feel or comedy timing, and re-verifying engine behaviour.

The rule of thumb: **if a test's expected value had to be obtained by running the game once and copying the
number, it's a change-detector, not a test.**

**Layer 3 — does it look right?** This is the layer people skip and shouldn't. `--headless` in Godot 4.7
**cannot render at all** — the headless display driver only advertises a `dummy` renderer,
`RenderingServer.frame_post_draw` never fires, and `--headless --write-movie` segfaults outright. But you're
on Windows with a real desktop, so:

```powershell
godot --path . --write-movie shots/run.png --fixed-fps 6 --quit-after 12
```

writes a numbered PNG filmstrip in about a second. The agent can then *look at them*. That's `verify.ps1 -Shots`.

This matters more than it sounds. The most technically sophisticated Godot-agent project found so far
(`godogen`) uses a separate model to compare rendered screenshots against references, specifically because
the agent judging its own output is unreliable. Its design principle: **the agent judges progress from
"captured screenshots, not from code that compiles."** Their reviewer catches z-fighting, floating objects,
physics explosions, and wrong scale — none of which text analysis will ever find.

**MCP servers** are an accelerator, not a foundation. `tugcantopaloglu/godot-mcp` is the most capable one
found (screenshots, runtime error capture, simulated input, and its README claims testing against 4.7), but
it's young — ~240 stars — and MCP servers run arbitrary code with your permissions. The CLI loop above gets
you 80% of the value with zero new dependencies. Start there; add MCP later if the loop feels slow.

---

## 2. The version problem is worse than usual

Godot 4.7 released 18 June 2026; 4.7.1 on 14 July. Six weeks ago. And the 4.x line has been moving fast:

- **4.6 made Jolt the default 3D physics engine** — but only because the *editor* writes it into new
  projects. The actual setting default is still `"DEFAULT"`, which means GodotPhysics. **A `project.godot`
  written by hand gets the wrong physics engine**, and the symptoms (cylinder collisions misbehaving, node
  scale silently ignored, sleep tuning doing nothing) are the kind you'd chase for a week.
- **4.6 removed `load_steps=` from the `.tscn` format** and added `unique_id=` to node headings. Essentially
  every blog post, Stack Overflow answer and training corpus predates both.
- **4.6 overhauled the glow defaults** — blend mode changed, intensity 0.8 → 0.3. Any glow values from an
  older tutorial will look wrong on screen.
- **4.5 silently changed `Resource.duplicate(true)`** so it no longer deep-duplicates external resources,
  and renamed the parameter. Old code compiles and behaves differently.
- **4.7 moved mouse and keyboard off device ID 0**, so `if event.device == 0:` is now wrong.
- **4.4 introduced `.uid` sidecar files** for scripts, which is the single most dangerous file type an agent
  can touch (see §4).

On top of that sits the ordinary Godot 3 → 4 problem, which is severe because Godot 3 tutorials dominate the
training data. `move_and_slide(velocity, Vector3.UP)` is probably the most-hallucinated API call in the
entire engine — in Godot 4 it takes **zero arguments** and reads/writes a `velocity` property instead.

`docs/GODOT_4.7_RULES.md` is the countermeasure: a version-pinned reference the agent reads instead of
recalling. `CLAUDE.md` bans the Godot 3 idioms by name.

One genuinely encouraging note: a comparative review found **Claude Opus drifts into Godot 3 patterns the
least of any model tested**, and an HN commenter reported getting "completely fine GDScript and even decent
perfectly functional `.tscn` files" — *conditional on* starting from a playable scaffold with guidance
documentation, using a CLAUDE.md, and going through plan mode before each change. That's exactly the setup
this kit builds.

---

## 3. Static typing is the closest thing to a compiler you get

This is the highest-leverage lever available, and it's underused.

GDScript has a per-warning severity system: `0 = Ignore`, `1 = Warn`, `2 = Error`. Several warnings that
would catch agent hallucinations ship as **Ignore** by default — `unsafe_method_access`,
`unsafe_property_access`, `unsafe_call_argument`, `unsafe_cast`, `missing_await`.

Set `unsafe_method_access=2` and this happens:

```
SCRIPT ERROR: Parse Error: The method "this_method_does_not_exist()" is not present on
              the inferred type "Node2D". (Warning treated as error.)
EXIT=1
```

A typo'd or invented method name goes from "runtime crash three hours later, probably during a playtest" to
"hard failure the agent sees in `verify.ps1` immediately."

But it only fires when the type is known. `var n = get_node("Foo")` is a `Variant` and nothing can be
checked. `var n: Node3D = get_node("Foo")` can be. **That's why typing is a non-negotiable in `CLAUDE.md`
rather than a style preference** — it's the mechanism, not the aesthetics.

The full block is in `docs/GODOT_4.7_RULES.md` §8. There is no global "treat warnings as errors" switch; it
has to be set per warning. Start `untyped_declaration` at `1` (warn) and raise it to `2` once the codebase
is clean.

One caveat: this whole system is compiled under `DEBUG_ENABLED`, so validation must run against the editor
binary, not an export template.

---

## 4. The Godot-specific traps that silently corrupt things

Most Godot mistakes fail loudly. These don't — which is what makes them worth knowing about in advance.

**UIDs.** Since 4.4, every `.gd` gets a `.gd.uid` sidecar containing one line like `uid://c4wt6ace7hycd`.
Scenes reference resources by *both* UID and path, and **the UID wins when it resolves**.

- An *invented* UID is mostly harmless — it fails to resolve, Godot warns loudly and falls back to the path.
- A *duplicated* UID is a disaster. If an agent copies a `.tscn` as a template and keeps the `uid=` in its
  header, two files now claim the same identity. Godot's filesystem scanner warns **only on the first
  scan**, then silently applies last-scanned-wins. Every `uid://X` reference project-wide now points at
  whichever file the directory walk hit last. Two scenes quietly become the same scene.

The contract in `CLAUDE.md`: never invent a UID, never create a `.uid` file, omit `uid=` from anything you
author, and never copy a `.tscn`/`.tres` without stripping the header UID. Godot fills them in on next scan.

Also: **commit `.uid` files.** Godot's own announcement is explicit — *"`*.uid` should not be added to
`.gitignore`."* If they're not committed, every clone generates fresh UIDs and every reference breaks.

**Duplicate resource ids inside a `.tscn`.** `ExtResource("1_abc")` declared twice? The parser uses a
hashmap — last declaration silently wins, no error. The scene loads clean and the wrong script or texture is
bound. Dangling ids, by contrast, fail loudly. So: **dangling is safe, duplicated is dangerous.**

**`class_name` collisions.** One flat global namespace shared with every engine class *and* every autoload
name. Two scripts declaring `class_name SpeedEffect` produces no error at all — last file wins, the other is
unreachable by name. With 40 substances and 40+ effect classes, this *will* happen. Hence the `Gg` prefix
convention.

**`DirAccess` in an exported build.** This one is proven, not theoretical. On export, every text resource
becomes binary and a `.remap` stub is left behind:

```
DirAccess.get_files_at        -> ["speed.tres.remap", ...]   # every load() then FAILS
ResourceLoader.list_directory -> ["speed.tres", ...]         # correct
```

Code that scans a folder with `DirAccess` works perfectly in the editor and ships completely broken. Always
`ResourceLoader.list_directory()`.

**Resource sharing.** Two scene instances with `@export var s: MySubstance` hold **the same object**. Godot
also keeps a global path-keyed cache, so mutating that resource at runtime poisons every future `load()` of
that path for the rest of the session. `substance.elapsed += delta` looks completely reasonable and is the
worst possible line in this codebase. The architecture avoids it by making substance resources immutable.

**The editor dialog that eats your work.** You can leave Godot open while the agent edits — it holds no
long-lived file locks and scripts auto-reload. But when you alt-tab back, Godot may show *"Files have been
modified outside Godot"* with two buttons. **"Reload from disk" is correct. "Ignore external changes"
overwrites the agent's work on disk with the editor's stale in-memory copy.** That's the one real data-loss
path here. Close the editor for large structural refactors.

---

## 5. What goes wrong, with numbers

The best quantitative source is a 2026 study of 547 manually-confirmed real-world safety incidents mined
from 16,586 GitHub issues across 13 code models. (It's an arXiv preprint — treat the taxonomy as more
reliable than the exact percentages.)

| Failure | Share | What it looks like here |
|---|---|---|
| Ignoring explicit constraints | **40%** | You said don't touch the camera; it touched the camera |
| Losing track of prior state | **16%** | Hour 3, it reintroduces the bug you fixed at hour 1 |
| Claiming it did something it didn't | **16%** | "I've implemented and tested this" — it never ran Godot |
| Fabricating evidence | 10% | Invented test output |
| Confidently presenting broken work | 9% | Ships a scene that doesn't load |
| Explanation contradicts the code | 6% | The summary describes something the diff doesn't do |
| Over-abstraction | 5% | `BaseAbstractSubstanceEffectFactory` for three substances |
| Masking failures instead of fixing | 2% | Assertion weakened rather than bug fixed |

Root causes they name: **instruction prioritisation failure (45%)** — *"agents drop negative constraints
during complex tasks"* — and **reward exploitation (22%)**. And a detail worth internalising: **bug-fixing
tasks produce their highest-severity damage 65% of the time.** Be most careful exactly when you're most
frustrated.

**Context degrades measurably.** Chroma's study across 18 models found performance drops with input length
*even on trivially simple tasks*, and that **a single distractor measurably reduces accuracy** — not ten,
one. Counterintuitively, models did *worse* when the irrelevant context had a coherent logical flow;
shuffled context performed better across all 18 models. Coherent-but-irrelevant material is more harmful
than noise. Which is an argument for `/clear` between unrelated tasks, and for keeping `CLAUDE.md` short.

Anthropic's own numbers on CLAUDE.md: **target under 200 lines**, stated in three separate places. Nothing
truncates a longer file — it just quietly degrades adherence to everything in it. Their pruning test for
each line: *"Would removing this cause Claude to make mistakes?"* If not, cut it. And their diagnostic: *"If
Claude keeps doing something you don't want despite having a rule against it, the file is probably too long
and the rule is getting lost."*

Also worth knowing, because it explains a lot: **CLAUDE.md is delivered as a user message, not as part of
the system prompt.** It's a strong request, not a guarantee. For things that must always happen, hooks are
enforcement; CLAUDE.md is advisory.

---

## 6. What happened to other people who tried this

**The most relevant failure** is a Godot forum post-mortem by someone in almost exactly your position — mid
30s, cybersecurity professional, no GDScript, no Godot, positioned himself as product owner and delegated
all technical work. Building a metroidvania.

The shape of it:

- **First 3–4 hours: genuinely good.** Working character with running, jumping, ladder climbing, an
  in-fiction tablet, scanner equipment, and save/load.
- **Then it stalled hard.** Combat and enemies: *"Prompt after prompt didn't fix anything and it often got
  worse."*
- **The killer:** after a grid-size migration, the player script got unwieldy. The AI produced a "state
  machine" that was actually just *"a global variable the player script would check. None of the logic or
  functionality made it into the state machine."* He only caught it by running an adversarial analysis.

His three conclusions:

1. *"The agents can't handle more than 2-3 scripts at a time."*
2. *"There's a murky middle area that's too specific for web based sessions and too vast for IDE based agents."*
3. *"There's not much you could build with AI that you couldn't build yourself in the same amount of time
   while learning the actual technical skills."*

Weight the structural lessons heavily and the pessimism lightly — he was using a mix of 2025-era tools
across multiple IDE agents, not one well-configured session with a rules file and plan mode. The most useful
reply on that thread came from an experienced dev who distinguished **broad delegation (failed) from small
modular tasks with critical review (works)**. That distinction is the actual lesson.

**A milder, completed account:** someone shipped a playable match-3 in Godot with no prior Godot knowledge.
Her first build didn't compile and the AI hallucinated an entirely different game. She got there. Her
verdict on the trade is the emotional crux of all of this:

> Delegating everything meant avoiding the satisfying parts of development — learning, understanding,
> problem-solving — while inheriting the worst parts: *"code reviews and dealing with code that I didn't
> write and don't fully understand."*

**The most sophisticated attempt** (`godogen`, 205 comments on HN) identified three engineering problems
that generalise cleanly: GDScript training scarcity (they built a hand-written spec and a "quirks database"
— this kit's `GODOT_4.7_RULES.md` is a small version of that), build-time vs runtime API confusion (solved
by generating scenes from headless scripts rather than hand-writing `.tscn`), and self-evaluation bias
(solved with a separate vision model doing screenshot QA).

The negative comments there are the valuable part. Reviewers found the generated games **"lifeless."** The
snowboarding demo had *"really bad physics"* and no gameplay — *"a physics entity wildly crashing down a
hill with no consequences or score."* And one comment names the risk of fast prototyping precisely:

> *"Most of the time I spend prototyping is taken up by wrestling with tools, engines, and assets. Then I
> discover that my game design just isn't very fun."*

**AI removes the wrestling. It does not remove the discovery.** Your design doc's gate — hand it to someone
who has never seen it, and if they're not laughing inside 90 seconds, fix the controller — is the right
instrument and it stays entirely yours.

**Where AI reliably helps:** initial scaffolding and first playable, boilerplate (save/load, input maps,
menus, settings), build/CI tooling, and explaining the engine to you. **Where it reliably doesn't:** game
feel and tuning, level design and spatial layout, multi-system integration (this is where every account
broke), art assets, and knowing when something is fun.

One structural advantage you have: **Godot is the right engine for this.** Unity and Unreal store scenes and
prefabs as binary or as GUID-laden YAML that reads "like a database dump" to a language model. Godot stores
essentially everything as human-readable text, so the agent can read your entire project the way it reads a
web codebase. That's not a small edge — it's arguably the single biggest reason this is feasible at all.

---

## 7. Your actual workflow

**Once, before anything else**

1. `git init`, commit, use the `.gitignore` in this kit. **Do not gitignore `*.uid`.**
2. Confirm `verify.ps1` runs and that a deliberate break makes it fail. Prove the loop before you trust it.
3. Install gdtoolkit: `py -m pip install --user "gdtoolkit==4.*"`.
4. Get one trivial GUT test passing headless. That's your bedrock.

**Every task**

1. **Commit first.** `git commit -am "wip: before X"` costs three seconds.
2. **Plan mode** (`Shift+Tab`) for anything touching more than one file or any system you don't understand —
   which is currently all of them. `Ctrl+G` opens the plan in your editor so you can edit it directly.
3. **Scope it explicitly.** Name the files it may touch and what's out of scope. The difference between
   *"add a dash"* and a properly-scoped request is most of the difference between this working and not.
4. **Demand evidence.** The command and its actual output, not "I've implemented and tested this."
5. **`git diff --stat`.** Look at the *shape* before you look at code — unexpected files touched, negative
   line counts you didn't ask for, a 400-line diff for a 20-line feature. This is the single highest-value
   five-second habit available to you, and it works without reading a line of GDScript.
6. **Play it.**
7. **Commit, or `git reset --hard`.** Anthropic's data science team's framing: treat it like a slot machine
   — save state, let it run, then *accept or restart*. Do not debug the agent's mess.
8. **`/clear`** before the next unrelated task.

**The two rules with the most evidence behind them**

- **After two failed corrections on the same problem, `/clear` and rewrite the prompt** with what you
  learned. Anthropic states this twice: *"A clean session with a better prompt almost always outperforms a
  long session with accumulated corrections."*
- **If a task touches more than 2–3 scripts, it's too big.** Split it.

**Every few sessions**

- Prune `CLAUDE.md`. Delete anything the agent gets right without being told.
- Check the design doc against what actually exists. Run a fresh-context reviewer against it — fresh context
  matters, because an agent reviewing code it just wrote is biased toward it.
- Budget a consolidation session: delete duplication, no new features.

**One caution on reviewer prompts**, straight from Anthropic: *"A reviewer prompted to find gaps will
usually report some, even when the work is sound… Chasing every finding leads to over-engineering."* Tell
the reviewer to flag only things that affect correctness or the stated requirements.

---

## 8. Reviewing code in a language you don't know

You won't review GDScript line by line, and pretending otherwise is itself a failure mode. What works, in
order:

1. **Review the diff shape, not the code.** Covered above. Works with zero GDScript.
2. **Play the game.** *"If you haven't seen the code do the right thing yourself, it doesn't work."*
3. **Insist on proof, not promises.**
4. **Use a fresh-context reviewer** — a new session, or `/code-review` on the diff.
5. **Ask the agent to explain its own code to you**, the way you'd ask a senior engineer. This doubles as
   learning Godot, which the honest accounts all conclude is unavoidable anyway.

A useful reframe: the goal isn't to review every line. It's to stay able to tell when something has gone
wrong, and to keep the project in a state where a bad run costs you one `git reset` rather than a week.

---

## 9. A note on expectations

METR ran a randomised controlled trial and found experienced developers were **19% slower** with AI tools on
their own repos — while **believing they were 20% faster**. The perception gap is the durable finding. Their
own follow-up flags serious selection bias and says the numbers likely underestimate real gains, and the
study measured experts on codebases they already knew, which is roughly the opposite of your situation. So
don't over-read it.

But do take the perception gap seriously: **you cannot trust your own sense of velocity here.** The design
doc's 3-week vertical slice is the right instrument. Three weeks of wall time, one zone, one goose, three
substances, and a stranger laughing inside 90 seconds. If that gate passes, everything else is scaling. If
it doesn't, no amount of agent throughput fixes it.

The most encouraging thing in all of this research is small and specific: the people who reported good
results were, without exception, the ones who started from a playable scaffold, kept a rules file, planned
before changing anything, and scoped tasks tightly. That's a workflow, not a talent. You can just do it.

---

## Sources

**Anthropic**
[Best practices](https://code.claude.com/docs/en/best-practices) ·
[Memory / CLAUDE.md](https://code.claude.com/docs/en/memory) ·
[Extend Claude Code](https://code.claude.com/docs/en/features-overview) ·
[Permission modes](https://code.claude.com/docs/en/permission-modes) ·
[Context window](https://code.claude.com/docs/en/context-window) ·
[Effective context engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) ·
[Steering Claude Code](https://claude.com/blog/steering-claude-code-skills-hooks-rules-subagents-and-more) ·
[How Anthropic teams use Claude Code (PDF)](https://www-cdn.anthropic.com/58284b19e702b49db9302d5b6f135ad8871e7658.pdf)

**Research**
[What Breaks When LLMs Code? (arXiv 2605.30777)](https://arxiv.org/html/2605.30777v1) ·
[Chroma: Context Rot](https://www.trychroma.com/research/context-rot) ·
[EvilGenie reward-hacking benchmark (MIT FutureTech)](https://futuretech.mit.edu/publication/evilgenie-a-reward-hacking-benchmark) ·
[METR RCT](https://metr.org/blog/2025-07-10-early-2025-ai-experienced-os-dev-study/) ·
[METR update](https://metr.org/blog/2026-02-24-uplift-update/)

**Godot — official**
[4.7 release notes](https://godotengine.org/releases/4.7/) ·
[4.7.1](https://godotengine.org/article/maintenance-release-godot-4-7-1/) ·
[Command line tutorial](https://docs.godotengine.org/en/4.7/tutorials/editor/command_line_tutorial.html) ·
[GDScript warning system](https://docs.godotengine.org/en/4.7/tutorials/scripting/gdscript/warning_system.html) ·
[Using Jolt Physics](https://docs.godotengine.org/en/4.7/tutorials/physics/using_jolt_physics.html) ·
[Troubleshooting physics](https://docs.godotengine.org/en/4.7/tutorials/physics/troubleshooting_physics_issues.html) ·
[Physics interpolation](https://docs.godotengine.org/en/4.7/tutorials/physics/interpolation/using_physics_interpolation.html) ·
[Using 3D transforms](https://docs.godotengine.org/en/4.7/tutorials/3d/using_transforms.html) ·
[Ragdoll system](https://docs.godotengine.org/en/4.7/tutorials/physics/ragdoll_system.html) ·
[TSCN file format](https://github.com/godotengine/godot-docs/blob/4.7/engine_details/file_formats/tscn.rst) ·
[Version control](https://docs.godotengine.org/en/4.7/tutorials/best_practices/version_control_systems.html) ·
[UID changes in 4.4](https://godotengine.org/article/uid-changes-coming-to-godot-4-4/) ·
[Upgrading from Godot 3 to 4](https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.html) ·
[Pipeline compilations](https://github.com/godotengine/godot-docs/blob/4.7/tutorials/performance/pipeline_compilations.rst) ·
[Screen-reading shaders](https://github.com/godotengine/godot-docs/blob/4.7/tutorials/shaders/screen-reading_shaders.rst)

**Tools**
[gdtoolkit](https://github.com/Scony/godot-gdscript-toolkit) ·
[GUT](https://github.com/bitwes/Gut) ·
[gdUnit4](https://github.com/godot-gdunit-labs/gdUnit4) ·
[tugcantopaloglu/godot-mcp](https://github.com/tugcantopaloglu/godot-mcp) ·
[Coding-Solo/godot-mcp](https://github.com/Coding-Solo/godot-mcp)

**First-hand accounts**
[Post-mortem of my failed attempt to vibe-code a metroidvania](https://forum.godotengine.org/t/post-mortem-of-my-failed-attempt-to-vibe-code-a-metroidvania-game/137567) ·
[I vibe-coded a game in Godot](https://olgabiro.substack.com/p/i-vibe-coded-a-game-in-godot) ·
[Show HN: Claude Code skills that build complete Godot games](https://news.ycombinator.com/item?id=47400868) ·
[htdt/godogen](https://github.com/htdt/godogen) ·
[Vibe coding works for web apps, it breaks on game engines](https://dev.to/ziva/vibe-coding-works-for-web-apps-it-breaks-on-game-engines-heres-why-446g) ·
[Best LLM for GDScript in 2026](https://www.summerengine.com/blog/best-llm-for-godot) ·
[Claude for Godot](https://www.summerengine.com/blog/claude-for-godot) ·
[Addy Osmani: The 80% problem in agentic coding](https://addyo.substack.com/p/the-80-problem-in-agentic-coding) ·
[Armin Ronacher: Things that didn't work](https://lucumr.pocoo.org/2025/7/30/things-that-didnt-work/) ·
[Simon Willison: Agentic engineering patterns](https://simonwillison.net/guides/agentic-engineering-patterns/)

**Flagged as unverified:** the arXiv paper is a preprint, not confirmed peer-reviewed. Widely-quoted stats
like "AI game code has 1.7× more bugs" could not be traced to a primary source — ignore them. Godot MCP
servers were not evaluated for quality or security. Godot's June 2026 policy of rejecting fully
AI-generated PRs applies only to contributions to the *engine*, not to your game — but it's worth knowing
before you ask for help in Godot community spaces.
