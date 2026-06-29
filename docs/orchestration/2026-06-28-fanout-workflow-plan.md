# Fanout workflow plan — nvim-code-tour (NCT-002…009)

_Solidified 2026-06-28 while NCT-001 (walking skeleton) is in `review`, owned by the main agent._

This is the orchestration plan for fanning the remaining stories out across parallel
subagents with an **independent per-story verify gate** ("a story is not done until a
different agent confirms every acceptance criterion is met and the full suite is green").

---

## 0. Two corrections to the earlier framing

1. **The stack is decided, not open.** Lua, Neovim 0.10 floor, telescope as the only hard
   dep, plenary/busted with two test seams (pure core + headless-nvim integration), one
   `make test`. The design spec (`docs/superpowers/specs/2026-06-28-nvim-code-tour-design.md`)
   fixes the module layout. So agents get a concrete file map, not a green field — that's
   what makes the collision analysis below trustworthy.

2. **The GAN *evaluator agent* is the wrong tool for this repo; the GAN *pattern* is
   right.** `ecc:gan-evaluator` tests a *live running app via Playwright* — browser/web.
   This is a headless TUI Neovim plugin; there's no page to drive. So the verify gate uses
   an **independent reviewer agent that runs `make test` and checks the card's acceptance
   boxes against the actual code**, not the Playwright evaluator. We keep the
   generate→evaluate→iterate-until-pass *loop shape* (that's the valuable part); we just
   swap the evaluator's body for "run the busted suite + audit criteria." `make test` green
   is a far stronger, deterministic gate than a screenshot rubric anyway.

---

## 1. Dependency graph (from the cards)

```
NCT-001 walking skeleton ──┬─ NCT-002 discovery ──┬─ NCT-003 telescope picker
  (in review now)          │                      └─ NCT-006 links + nextTour
                           ├─ NCT-004 pattern + jsregex
                           ├─ NCT-005 selection / content
                           ├─ NCT-007 git ref drift
                           ├─ NCT-008 resilience  (cross-cutting — see §3)
                           └─ NCT-009 config / commands / health / resume
```

Everything is blocked by 001. 003 and 006 are additionally blocked by 002.

---

## 2. The real constraint: shared-file contention

Vertical slices share core modules. Parallel agents editing the same file collide. Mapping
each story to the modules it must touch (from the design spec §3/§7):

| Module | NCT-002 | NCT-003 | NCT-004 | NCT-005 | NCT-006 | NCT-007 | NCT-008 | NCT-009 |
|---|---|---|---|---|---|---|---|---|
| `core/discovery.lua` | **own** | | | | (title resolve) | | edit (skip bad) | |
| `core/jsregex.lua` (new) | | | **own** | | | | | |
| `core/anchor.lua` | | | edit (pattern) | edit (sel/content) | | | edit (unresolved) | |
| `core/markdown.lua` (new) | | | | | **own** | | edit (inert cmd) | |
| `core/git.lua` (new) | | | | | | **own** | | |
| `core/schema.lua` | | | | | | | **own** (lenient) | |
| `core/model.lua` | | | edit (precedence) | | | | edit | |
| `player.lua` | | edit (→picker) | | edit (spine) | edit (goto/start) | edit (drift) | | edit (resume) |
| `ui/picker.lua` (new) | | **own** | | | | | flag broken | |
| `ui/float.lua` | | | | | edit (`<CR>`) | | edit (inert) | edit (config) |
| `ui/highlight.lua` | | | | edit (range) | | | | |
| `ui/codewin.lua` | | | | edit (content skip) | | | | |
| `command.lua` | (list) | edit (start) | | | | | | **own** (subcmds) |
| `config.lua` / `health.lua` (new) | | | | | | | | **own** |

Three hot files:
- **`core/anchor.lua`** — 004, 005, 008 all touch it.
- **`player.lua`** — 003, 005, 006, 007, 009 (but mostly *additive* method/branch edits).
- **`ui/float.lua`** — 006, 008, 009.

And **NCT-008 (resilience) is cross-cutting** — it hardens schema, discovery, anchor,
markdown, renderer, float. It edits files that 002/004/005/006 *create*. **008 cannot run
in parallel with them** — it's the integrator/hardening pass and must run *after* they land.

---

## 3. Wave structure (the decided plan)

> Principle: **parallel authoring in isolated worktrees, serialized integration.** Wins come
> from agents writing code at the same time; the merge-and-run-full-suite step is sequential
> and human-gated. Anyone promising conflict-free parallel merges on `anchor.lua` is
> hand-waving — we serialize those.

**Wave 0 — now (main agent, solo):** NCT-001 → verify gate → `done`. Nothing else starts
until the skeleton's seams (player, renderer, anchor stub, model, schema, discovery stub)
exist on `main`, because every worktree branches from them.

**Wave 1 — fan out (4 agents, after 001 is `done`):**
- NCT-007 git ref — fully isolated (new `core/git.lua` + one additive player branch). Safest; good canary.
- NCT-004 pattern + jsregex — new `core/jsregex.lua` + `anchor.lua` pattern path + `model` precedence.
- NCT-005 selection / content — `anchor.lua` sel/content + `highlight`/`codewin`/player spine.
- NCT-002 discovery — pure-core deepen of `discovery.lua` (unblocks Wave 2).

  _Integration order for Wave 1 (both touch `anchor.lua`):_ merge **004 first** (it also
  sets `model` precedence `line` > `pattern`), then rebase/integrate **005** on top. 002 and
  007 integrate independently. Full `make test` green after each merge.

**Wave 2 — (2 agents, after 002 is `done`):**
- NCT-003 telescope picker — new `ui/picker.lua` + `command.lua` start path.
- NCT-006 links + nextTour — new `core/markdown.lua` + `ui/float.lua` `<CR>` + player goto/start.

**Wave 3 — hardening + surface (sequential, after Waves 1–2 land):**
- NCT-008 resilience **first** — the cross-cutting hardening pass; its `degradation_spec` is
  the gate. Touches modules all prior waves created, so it goes after them, mostly solo.
- NCT-009 config / commands / health / resume **last** — final user-facing polish. Shares
  `command.lua` with 003 and `ui/float.lua` with 006/008, so it integrates dead last.

Net: a 4-wide wave, then a 2-wide wave, then a serialized 2. Not one big fan-out — the
dependency graph and the hot files won't allow it, and pretending otherwise just buys merge
pain.

---

## 4. The verify gate (the "another agent confirms" requirement)

Each story runs as **generator → verifier**, and only the verifier can advance it to `review`:

1. **Generator agent** (in its own worktree, `isolation: 'worktree'`): implements the story
   test-first per `/feature-dev` / `ecc:tdd-guide`. Returns its diff + a self-report of which
   acceptance boxes it ticked.
2. **Verifier agent** (separate agent, *not* the author — this is the whole point): on the
   generator's branch, independently
   - runs `make test` from clean and captures the result,
   - reads the card's `## Acceptance criteria` and checks **each box against the actual code
     and the actual spec it runs**, not against the generator's say-so,
   - returns a structured verdict `{ pass: bool, failing_criteria: [...], suite_green: bool, notes }`.
3. **Gate:** story → `review` only if `pass && suite_green`. On fail, the verdict feeds back
   to the generator for another iteration (bounded, e.g. 3 rounds) — the GAN loop shape,
   evaluator body swapped for the busted suite. Human merges to `main` (serialized per §3).

This is encoded directly in the Workflow script below as a two-stage pipeline per story.

---

## 5. Ready-to-run Workflow skeleton

> Do **not** launch until NCT-001 is `done` on `main`. Run Wave 1, integrate, then re-invoke
> for Wave 2, then drive Wave 3 sequentially. Stories carry their real acceptance criteria so
> the verifier checks the actual boxes.

```js
export const meta = {
  name: 'nct-fanout-wave',
  description: 'Fan out NCT stories: generator (worktree, TDD) → independent verifier (make test + criteria audit)',
  phases: [{ title: 'Implement' }, { title: 'Verify' }],
}

// One wave's worth of stories. Edit `WAVE` per invocation (see §3).
const WAVE = [
  { id: 'NCT-007', card: '.claude/.kanban/stories/NCT-007-git-ref-drift-warning.md' },
  { id: 'NCT-004', card: '.claude/.kanban/stories/NCT-004-pattern-anchoring-jsregex.md' },
  { id: 'NCT-005', card: '.claude/.kanban/stories/NCT-005-selection-content-steps.md' },
  { id: 'NCT-002', card: '.claude/.kanban/stories/NCT-002-discovery-engine.md' },
]

const VERDICT = {
  type: 'object',
  required: ['pass', 'suite_green', 'failing_criteria', 'notes'],
  properties: {
    pass: { type: 'boolean' },
    suite_green: { type: 'boolean' },
    failing_criteria: { type: 'array', items: { type: 'string' } },
    notes: { type: 'string' },
  },
}

const results = await pipeline(
  WAVE,
  // Stage 1 — generator, isolated worktree, test-first.
  (s) => agent(
    `Implement story ${s.id} for the nvim-code-tour plugin, test-first (plenary/busted), ` +
    `following docs/superpowers/specs/2026-06-28-nvim-code-tour-design.md. Read the card at ` +
    `${s.card} for scope and acceptance criteria. Only touch the modules that story owns/edits. ` +
    `Run \`make test\` before returning. Return your diff summary + which acceptance boxes you ticked.`,
    { label: `impl:${s.id}`, phase: 'Implement', isolation: 'worktree' }
  ).then((diff) => ({ s, diff })),

  // Stage 2 — INDEPENDENT verifier (different agent). Gate = pass && suite_green.
  (prev, s) => agent(
    `You are an independent verifier for story ${s.id} — you did NOT write this code. ` +
    `Read the acceptance criteria in ${s.card}. From a clean state run \`make test\` and capture the result. ` +
    `Then check EACH acceptance criterion against the actual code and the actual spec that exercises it — ` +
    `not against the implementer's report. A criterion only passes if a test demonstrably proves it. ` +
    `Report every criterion you could not confirm.`,
    { label: `verify:${s.id}`, phase: 'Verify', schema: VERDICT }
  ).then((v) => ({ id: s.id, verdict: v, impl: prev?.diff })),
)

const passed = results.filter(Boolean).filter((r) => r.verdict?.pass && r.verdict?.suite_green)
const blocked = results.filter(Boolean).filter((r) => !(r.verdict?.pass && r.verdict?.suite_green))
log(`Passed gate: ${passed.map((r) => r.id).join(', ') || 'none'}`)
log(`Held back:  ${blocked.map((r) => r.id).join(', ') || 'none'}`)
return { passed, blocked }
```

Per-story workflows (`/feature-dev` or `ecc:orch-add-feature`) are the proven *inner*
pipeline (understand → plan → TDD → review); the script above is the *outer* fan-out +
independent gate. The generator stage can invoke the per-story workflow rather than a raw
agent if we want the full plan/PRD treatment per slice.

---

## 6. Open decisions for Chris (don't need answers to start)

1. **`anchor.lua` contention (004 vs 005):** parallel-author + serialized integrate
   (004 → 005), as planned — or hand both `anchor` edits to a single agent to avoid the merge
   entirely? Plan assumes the former. _(Recommend: keep parallel; the regions are distinct.)_
2. **Generator depth:** raw TDD agent per story (cheaper) vs. full `/feature-dev` inner
   pipeline per story (more thorough, more tokens)? Plan's script uses a raw agent; swap-in is
   one line.
3. **Iteration bound:** how many generator↔verifier rounds before a story escalates to you?
   _(Recommend: 3, then surface.)_
4. **Dry-run first?** Prove the harness on **NCT-007 + NCT-005** (one isolated, one
   anchor-touching) before turning loose the full Wave 1. _(Recommend: yes.)_

This is a 💲 heavy run (worktrees + 2 agents/story × waves). Gate it on 001 landing and on
your call for items 2–4 above.
