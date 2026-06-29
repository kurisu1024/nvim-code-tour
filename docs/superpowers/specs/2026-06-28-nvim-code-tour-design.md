# nvim-code-tour — Design Spec

**Date:** 2026-06-28
**Status:** Approved design, pre-implementation
**Author:** Chris + Puck (brainstorm + grilling session)

A Neovim plugin that natively **plays** CodeTour `.tour` files, targeting the feature
set of the VS Code [CodeTour extension](https://github.com/microsoft/codetour)
(`vsls-contrib.codetour`) for the *consumption* path. The `.tour` JSON format
(`https://aka.ms/codetour-schema`) is the contract.

---

## 1. Scope

**In scope (this plugin):** playback / consumption of existing `.tour` files. Tours are
authored elsewhere — by Claude (e.g. the `ecc:code-tour` skill), by hand, or by the VS
Code extension — and checked into repos as JSON. Neovim's job is to discover, play, and
navigate them well.

**Explicitly out of scope:** interactive tour **recording / authoring** in Neovim. We do
not create or edit `.tour` files. The JSON spec is the boundary; we consume it, we don't
produce it.

### MVP feature set

- Discover tours in the standard locations + a configurable dir.
- Telescope picker to choose a tour (and jump to a step).
- Play a tour: narrator float shows the step's markdown; the code window jumps to the
  anchor and highlights it.
- Step types: **file+line, file+pattern, selection, content**.
- Pattern anchoring via a **Tier-2 JS→Vim regex translation** module.
- Markdown: treesitter-highlighted baseline; `<CR>` follows **step / tour / file** links.
- Navigation: `:CodeTour` subcommands + a Lua API; buffer-local maps during a tour.
- Git `ref`: detect drift and **warn** (never mutate the working tree).
- Lenient, resilient validation and error handling throughout.
- In-session resume; `:checkhealth codetour`.

### Roadmap (deliberately deferred, ordered)

1. Fast-follows: **directory** & **uri** steps.
2. **view**-anchored steps.
3. Renderer modes **B** (line-anchored float) and **C** (split) behind the `Renderer` seam.
4. Cross-restart **resume** persistence (state file under `stdpath('state')/codetour/`).
5. Gated **shell `>>`** commands and **code-injection** ("Insert Code") — explicit/confirmed.
6. Git **ref**: checkout offer (B) and ref-blob playback without checkout (C).
7. **`when`** conditions — sandboxed evaluator, platform vars only (`isLinux/isMac/isWindows`), never arbitrary JS.
8. **Tier-3** full JS-regex fidelity (only if a real tour ever needs it; would require native PCRE2).
9. Native **markdown** pretty-renderer.
10. Extension / event API → the event-bus architecture (Approach 3) if/when needed.

---

## 2. Key decisions (from grilling)

| # | Decision | Choice |
|---|----------|--------|
| Scope | recording? | **No.** Playback only; JSON spec is the contract. |
| Runtime | language / nvim floor | **Lua, Neovim 0.10** (0.10 APIs are fair game; no backward polyfill). |
| Deps | runtime dependencies | **Telescope is the only hard dep** (pulls plenary transitively). Telescope lives *only* at the discovery/selection seam — never in the core. |
| Optional | markdown render / pickers | Opportunistic: use `render-markdown.nvim`/`markview.nvim` if present; else treesitter. Never a hard dep. |
| Testing | harness | **plenary busted**, two tiers (fast pure-core specs + nvim-driving integration specs), fixture-driven. |
| UX | step presentation | **Fixed-position narrator float** (Option A). Code window jumps + highlights underneath. Never disturbs window layout. Behind a `Renderer` seam so B/C slot in later. |
| Steps | MVP types | file+line, pattern, selection, content. Fast-follow: directory, uri. Roadmap: view. Unknown `view` → graceful-degrade (render description, ignore view). |
| Syntax | description specials | MVP: step/tour/file links via `<CR>`. Defer + **gate** shell `>>` and code-injection (they act on the machine). Drop `command:` links (render inert). |
| Markdown | fidelity | Treesitter baseline MVP; opportunistic plugin upgrade; native renderer on roadmap. |
| Discovery | workspace root | **git-root (`vim.fs.root`) then cwd.** Scan `.tours/`, `.vscode/tours/`, `.github/tours/`, root `main.tour`/`.tour`, + configured dir. Primary detection (`isPrimary` or `^#?\s*1\s*-`). |
| `when` | conditions | **Ignore in MVP** (show all). Never eval untrusted JS. Roadmap: sandboxed platform-vars only. |
| Commands | surface | **Lua API is the core.** Single `:CodeTour <sub>` with completion. **No global keymaps.** Buffer-local maps during a tour, **default on**, disable-able. |
| Git ref | drift behavior | **Warn-only in MVP**, never mutate the tree. Checkout offer (B) + ref-blob playback (C) on roadmap. |
| Pattern | regex | **`vim.regex()` + Tier-2 JS→Vim translation module** with graceful fallback. First-match-wins. Tier-3 full fidelity = roadmap. |
| State | tours / resume | **One active tour**; in-session resume in MVP. Cross-restart persistence deferred (state struct designed to accept it). |
| Validation | strictness | **Lenient best-effort.** Hand-rolled structural validation of consumed fields. Skip-invalid, flag-not-hide broken tours, clear notifications, `:checkhealth`. |
| Architecture | wiring | **Approach 1 — layered core / player / UI adapters**, held with discipline (no event bus until needed). |

---

## 3. Architecture (Approach 1: layered core / adapter)

Three tiers plus glue. Every module: single purpose, stated interface, small.

### Tier 1 — Core engine (pure Lua; no windows, no telescope)

| Module | Responsibility | In → Out | Depends on |
|--------|----------------|----------|------------|
| `core/json.lua` | decode `.tour` text | string → table / err | `vim.json` |
| `core/schema.lua` | validate consumed fields, lenient | table → `{valid_steps, skipped[], errors[]}` | — |
| `core/model.lua` | normalize to Tour/Step; apply precedence (`directory`>`file`, `line`>`pattern`) | table → `Tour` | schema |
| `core/discovery.lua` | find tour files; git-root-then-cwd; glob known dirs + configured dir | root → `Tour[]` (meta only) | `vim.fs`, `vim.uv` |
| `core/jsregex.lua` | Tier-2 JS→Vim regex translation + graceful fallback | js_pattern → vim_regex / `nil,reason` | — |
| `core/anchor.lua` | resolve a step to a concrete location; jsregex on file lines for pattern steps; first-match-wins; unresolved→flagged | `Step, file_lines` → `{line, selection?}` / `unresolved` | jsregex |
| `core/markdown.lua` | parse description for step/tour/file refs → render lines + link map (offset→action) | description → `{lines, links[]}` | — |
| `core/git.lua` | resolve `ref`, compare HEAD; status (`match`/`drift`/`no-repo`) | `ref` → status | `vim.system` (injected runner for tests) |

### Tier 2 — Player / state (orchestration; one active tour)

- `player.lua` — the conductor and the real public surface. Holds
  `{ tour, step_index, ns_id, float_win, drift_notified }`. Methods:
  `start(tour, step?)`, `next()`, `prev()`, `goto(n)`, `resume()`, `stop()`.
  On each move: `anchor.resolve` → `codewin.open` → `highlight.apply` →
  `markdown.parse` → `renderer.present`; fire git-drift notice once per activation.
  In-session resume = state retained after `stop()`.

### Tier 3 — UI adapters (nvim-facing, swappable, thin)

- `ui/renderer.lua` — the **`Renderer` interface** (`present(step_view)`, `close()`);
  MVP impl `ui/float.lua` (fixed-position narrator float: markdown buffer, `Step n/m`,
  nav hints, buffer-local maps, `<CR>`-follow). B/C drop in behind this.
- `ui/codewin.lua` — open the step's file, move cursor to the resolved anchor.
- `ui/highlight.lua` — extmark highlight of anchored line/selection; gutter sign for
  "line participates in a tour."
- `ui/picker.lua` — **the only telescope touchpoint**; lists tours/steps with counts,
  flags broken ones.

### Tier 0 — Glue

- `init.lua` — `setup(opts)`, re-exports the player API.
- `config.lua` — defaults + merge.
- `command.lua` — `:CodeTour` subcommand dispatch + completion.
- `health.lua` — `:checkhealth codetour`.
- `plugin/codetour.lua` — bootstrap (register command + `setup`), load-guard. Lazy: no
  disk scan until the user acts.

**Load-bearing seams:** the `Renderer` interface (presentation swap), the injected git
runner (testable git), and `anchor`/`jsregex` as pure functions (fixture-driven). UI
libraries never reach into the core.

---

## 4. Data flow & lifecycle

**Discovery → pick → start**
```
:CodeTour start
  → discovery.find(root)        root = vim.fs.root(.git) or cwd
      globs .tours/ .vscode/tours/ .github/tours/ + main.tour/.tour + configured dir
  → each file: json.decode → schema.validate → model.normalize
      bad JSON / no title-or-steps → skip file, notify, keep going
      invalid steps → drop them, keep the tour, remember skips
  → ui.picker (telescope) lists tours [step count] (broken ones flagged)
  → pick → player.start(tour)
```

**A navigation step** (the spine — runs on every `start/next/prev/goto`)
```
player sets step_index
  → if tour.ref and first activation: git.status(ref)
        drift → notify once ("recorded at abc123; you're on main")
  → step = tour.steps[i]
  → anchor.resolve(step, read(step.file)):
        line step    → that line
        pattern step → jsregex.translate → vim.regex scan → first match
        selection    → range
        content      → no code location
        unresolved   → flag, park at file top, keep going
  → codewin.open(step.file, anchor)      (skip for content steps)
  → highlight.apply(anchor)              extmark line/selection
  → markdown.parse(step.description) → renderer.present({lines, links, "n/m", title})
```

**Following a link** (`<CR>` in the float, from `markdown.links`)
- step ref `[#3]` → `player.goto(3)`
- tour ref `[Title#2]` → resolve title in discovery set → `player.start(that, 2)`
  (also how `nextTour` chaining works)
- file ref `[x](./p)` → `codewin.open(p)` (no anchor)

**Stop / teardown**
`player.stop()` → `renderer.close()`, clear extmarks/signs, drop buffer-local maps. State
retained in memory so `:CodeTour resume` re-enters at the same step. Never touches window
layout (narrator is a float); never mutates the working tree (ref is warn-only).

**Failure posture, everywhere:** one bad file never breaks discovery; one bad step never
breaks a tour; one unresolved anchor never breaks navigation. Degrade, notify, continue.

---

## 5. Public API & config

**Lua API** (the real surface; commands and tests wrap this):
```lua
local ct = require("codetour")
ct.setup(opts)
ct.start(opts?)   ct.next()   ct.prev()   ct.goto(n)
ct.resume()       ct.stop()   ct.list()
```

**Command:** `:CodeTour start|next|prev|goto|resume|end|list` with tab-completion. The
`end` subcommand maps to the `stop()` API method (`end` reads better as a user verb; `stop`
avoids the Lua `end` keyword in code).

**Config defaults:**
```lua
{
  tour_dir   = nil,        -- extra dir beyond the known locations
  float      = { position = "bottom", width = 0.5, height = 0.3 },
  default_keymaps = true,  -- buffer-local maps during a tour
  keymaps    = { next="]t", prev="[t", follow="<CR>", stop="q", help="g?" },
  markdown_renderer = "auto",  -- auto-detect render-markdown/markview, else treesitter
}
```

No global keymaps are set. `<Plug>(codetour-next|prev|follow|...)` mappings are exposed
for users who want their own bindings.

---

## 6. Testing strategy (TDD, plenary busted)

Every module is written test-first. Core specs never open a window — the fast inner loop.

| Spec | Tier | Pins |
|------|------|------|
| `jsregex_spec` | core | fixture table `(js_pattern, text, expected)` — Tier-2 translation + fallback |
| `anchor_spec` | core | line/pattern/selection/content resolution, first-match, unresolved flagging |
| `schema_spec` / `model_spec` | core | lenient validation, skip-invalid, precedence rules |
| `discovery_spec` | core | finds all known locations under a fixture tree; git-root; broken-file skip |
| `markdown_spec` | core | step/tour/file ref extraction → correct link map |
| `git_spec` | core | ref status via an injected fake runner (match/drift/no-repo) |
| `player_spec` | integration | start/next/prev/goto/resume/stop transitions |
| `float_spec` / `highlight_spec` | integration | float content + `n/m`; extmark on the right line; buffer-local maps |
| `command_spec` | integration | `:CodeTour` dispatch + completion |
| `degradation_spec` | integration | broken tour still lists + plays its valid steps |

Fixtures: `tests/fixtures/tours/` (valid + deliberately malformed `.tour` files) and
`tests/fixtures/repo/` (a tiny sample source tree to anchor steps against). One command:
`make test`.

---

## 7. Repo layout

```
lua/codetour/
  init.lua  config.lua  command.lua  health.lua  player.lua
  core/  json schema model discovery jsregex anchor markdown git
  ui/    renderer float codewin highlight picker
plugin/codetour.lua
tests/  *_spec.lua  fixtures/{tours/, repo/}
Makefile   README.md   ROADMAP.md   doc/codetour.txt
```
