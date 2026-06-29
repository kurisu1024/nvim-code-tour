# nvim-code-tour — PRD

**Date:** 2026-06-28
**Status:** Ready for agent
**Companion:** [design spec](./2026-06-28-nvim-code-tour-design.md) (architecture, module decomposition, data flow)

---

## Problem Statement

A developer working in Neovim cannot natively play CodeTour `.tour` files. These files —
guided, step-by-step walkthroughs of a codebase, each step anchored to a file/line and
carrying a markdown explanation — are a first-class onboarding and knowledge-transfer
artifact in the VS Code world (`vsls-contrib.codetour`). They are increasingly authored by
AI (e.g. Claude / the `ecc:code-tour` skill) and checked into repos as JSON.

Today, a Neovim user who encounters a `.tour` file has no way to *experience* it. They can
open the raw JSON and read it, but they lose everything that makes a tour valuable: the
narrative shown beside the code, the cursor landing on the exact line under discussion, the
ability to step forward and back through an authored path, and resilience to the code
having drifted since the tour was written. A keyboard-driven developer is forced out of
their editor (into VS Code) to consume a format that is, underneath, just data.

## Solution

A Neovim plugin that **plays** `.tour` files natively. The developer opens a project,
runs a command, picks a tour from a fuzzy list, and walks through it without leaving the
editor: a fixed-position "narrator" float shows the current step's rendered markdown and
position (`Step 3/12`), while the code window jumps to the anchored file/line and
highlights it. Navigation is keyboard-native (`]t` / `[t` to move, `<CR>` to follow links
to other steps, tours, or files). The plugin is resilient — a step whose code has moved is
re-located by content (pattern matching), a partially-broken tour still plays its valid
steps, and a tour recorded against a different git ref warns rather than silently
misleading.

The plugin consumes the `.tour` JSON contract; it does **not** author tours. Tours are
written elsewhere (by Claude, by hand, or by the VS Code extension). Neovim's job is to
make playing them excellent.

## User Stories

**Discovering tours**

1. As a tour viewer, I want the plugin to find tours in the standard locations (`.tours/`, `.vscode/tours/`, `.github/tours/`, a root `main.tour`/`.tour`), so that I don't have to tell it where my tours live.
2. As a tour viewer, I want tour discovery to search from my project's git root (falling back to the working directory), so that tours are found regardless of which file I'm currently editing.
3. As a tour viewer, I want to configure an additional tour directory, so that projects using a non-standard location (e.g. `docs/tours`) still work.
4. As a tour viewer, I want to pick a tour from a fuzzy (telescope) list showing each tour's title and step count, so that I can quickly choose among several tours.
5. As a tour viewer, I want the primary tour (marked `isPrimary` or titled `#1 - …`) to be recognizable in the list, so that I know where to start in an unfamiliar codebase.
6. As a tour viewer, I want a tour with broken/invalid content to still appear in the list but flagged, so that I know it exists and that it has problems rather than it silently vanishing.

**Playing a tour**

7. As a tour viewer, I want to start a tour and immediately see the first step's narrative in a floating panel, so that I understand what I'm looking at.
8. As a tour viewer, I want the narrator float to stay in a fixed, predictable position and update in place as I navigate, so that my window layout is never disturbed.
9. As a tour viewer, I want the code window to open the step's file and move the cursor to the anchored line, so that I'm looking at exactly the code the step describes.
10. As a tour viewer, I want the anchored line (or selection range) highlighted, so that the relevant code is visually obvious.
11. As a tour viewer, I want to see my position in the tour (`Step 3/12`), so that I know how far through I am.
12. As a tour viewer, I want a content-only step (no file) to show just its narrative, so that introductory/explanatory steps work.
13. As a tour viewer, I want a selection step to highlight a multi-line range rather than a single line, so that steps about a block of code read correctly.

**Navigating**

14. As a tour viewer, I want to move to the next and previous step with `]t` / `[t` while a tour is active, so that I can walk the tour from the keyboard.
15. As a tour viewer, I want to jump to a specific step number, so that I can move around a long tour quickly.
16. As a tour viewer, I want to end a tour with `q` and have all of its UI (float, highlights, maps) cleanly removed, so that my editor returns exactly to normal.
17. As a tour viewer, I want to resume a tour I ended at the step I left off (within the session), so that I don't lose my place.
18. As a tour viewer, I want a help affordance (`g?`) listing the active tour keymaps, so that I can discover navigation without leaving the tour.
19. As a tour viewer, I want the in-tour keymaps to be enabled by default but disable-able via config, so that they work out of the box yet don't conflict if I'd rather map them myself.
20. As a tour viewer, I want to drive everything via a `:CodeTour` subcommand (`start|next|prev|goto|resume|end|list`) with tab-completion, so that I have a discoverable command surface.
21. As a power user, I want a Lua API (`require('codetour').start()` etc.) and `<Plug>` mappings, so that I can script my own bindings and integrations.
22. As a tour viewer, I want the plugin to set no global keymaps by default, so that it never steals keys from my config.

**Following links in narrative**

23. As a tour viewer, I want `<CR>` on a step reference (`[#3]`) to jump to that step, so that authored cross-references work.
24. As a tour viewer, I want `<CR>` on a tour reference (`[Other Tour]` / `[Title#2]`) to start that tour (at that step), so that linked/related tours are navigable.
25. As a tour viewer, I want a tour's `nextTour` to be followable, so that authored multi-tour sequences chain.
26. As a tour viewer, I want `<CR>` on a file link (`[label](./path)`) to open that file, so that supporting references in the narrative are reachable.

**Resilience to drift**

27. As a tour viewer, I want a step anchored by `pattern` to be re-located by matching code content, so that the step still points to the right place after lines have shifted.
28. As a tour author who wrote a tour with JavaScript-style regex patterns, I want those patterns to work in Neovim, so that I don't have to rewrite my tours for a different regex flavor.
29. As a tour viewer, I want a step whose anchor can't be found to show its narrative with a warning and keep navigation working, so that code drift degrades gracefully instead of crashing the tour.
30. As a tour viewer, I want a tour recorded against a git `ref` different from my current HEAD to warn me once that anchors may have drifted, so that I interpret the tour correctly.
31. As a tour viewer, I want the plugin to never modify my working tree (no checkout) when handling `ref`, so that playing a tour is always safe.

**Robustness and trust**

32. As a tour viewer, I want one malformed `.tour` file to not break discovery of the others, so that a single bad file doesn't take down the feature.
33. As a tour viewer, I want one invalid step to not break the rest of its tour, so that a partially-broken tour still delivers value.
34. As a tour viewer, I want clear notifications naming the file/step when something is wrong, so that I (or the author) can fix it.
35. As a tour viewer, I want `:checkhealth codetour` to report discovery and validation problems, so that I can diagnose setup issues.
36. As a tour viewer, I want shell-command (`>>`) and code-injection syntax in a tour to NOT execute automatically (rendered inert in MVP), so that opening a tour from any source can never run code or edit files behind my back.
37. As a tour viewer encountering a VS-Code-specific step (`view`-anchored) or `command:` link, I want it to degrade gracefully (narrative shown, unsupported part ignored), so that VS-Code-authored tours don't choke.

**Rendering**

38. As a tour viewer, I want step markdown rendered with treesitter highlighting by default, so that headings, emphasis, and code fences are readable with no extra setup.
39. As a tour viewer who already has a markdown-rendering plugin (`render-markdown.nvim` / `markview.nvim`), I want the float to use it automatically, so that I get prettier rendering without configuring anything.

**Installation**

40. As a Neovim user, I want the plugin to require only telescope as a hard dependency and otherwise work on a stock Neovim 0.10+, so that installation is simple and predictable.

## Implementation Decisions

- **Language / floor:** Lua, minimum Neovim 0.10. 0.10 core APIs (`vim.system`, `vim.fs.root`, `vim.ui.open`, modern extmarks, `vim.json`) are used directly without backward polyfills.
- **Dependencies:** Telescope is the only hard runtime dependency (and brings plenary transitively). It is confined to the discovery/selection seam (`ui/picker`) and never imported by the core. `render-markdown.nvim` / `markview.nvim` are optional, runtime-detected enhancements.
- **Architecture (layered core / player / UI):**
  - *Core engine* — pure Lua modules with no UI dependency: JSON decode, lenient schema validation, model normalization (applying `directory`>`file` and `line`>`pattern` precedence), discovery, JS→Vim regex translation, anchor resolution, markdown link parsing, git ref-status. These are the primary test surface.
  - *Player* — single-active-tour orchestration and the real public API (`start/next/prev/goto/resume/stop`). Holds in-memory state designed to later accept persistence.
  - *UI adapters* — a `Renderer` interface (MVP implementation: fixed-position narrator float) plus code-window jump, extmark highlighting, and the telescope picker.
- **Key seams:** the `Renderer` interface (presentation is swappable — future line-anchored/split modes drop in behind it), an injected git runner (git is testable without a real repo), and the pure `anchor` / `jsregex` functions.
- **Pattern matching:** `vim.regex()` driven by a Tier-2 **JS→Vim regex translation** module (force very-magic, map common JS constructs: `(?:)`, `(?=)`, `(?!)`, `(?<=)`, character classes, `{n,m}`), with graceful fallback + warning on untranslatable input. First-match-wins. Full bit-for-bit JS fidelity (native PCRE2) is explicitly deferred.
- **Git `ref`:** detect drift vs. HEAD and warn once per activation; never mutate the working tree. No-repo → ignore `ref` silently.
- **`when` conditions:** ignored in MVP (all tours shown). Untrusted JavaScript is never evaluated.
- **Discovery semantics:** root = git root (`vim.fs.root`) else cwd; glob the known directories + a configurable extra dir; detect primary via `isPrimary` or a `^#?\s*1\s*-` title.
- **Commands / keymaps:** single `:CodeTour` subcommand with completion; the `end` subcommand maps to the `stop()` API method. No global keymaps; buffer-local maps active only during a tour, default-on and disable-able.
- **State:** one active tour; in-session resume retained in memory. Cross-restart persistence deferred but the state struct is shaped to accept a `persist()`/`restore()` pair.
- **Validation posture:** lenient, hand-rolled structural validation of consumed fields only — skip-invalid, flag-not-hide broken tours, clear notifications, `:checkhealth` reporting. Best-effort resilience over strict rejection.

## Testing Decisions

- **What makes a good test:** asserts *external behavior at a seam*, not implementation details. Core tests assert tour *semantics* (given this `.tour` data, this is the resolved anchor / link map / validation outcome). Integration tests assert *editor-observable* behavior (the right file is open, the cursor is on the right line, the extmark/float/maps exist). Tests never reach into private module internals.
- **Two seams, two tiers (plenary busted, `make test`):**
  - *Core seam (pure, fast, the test-mass):* `jsregex` (fixture table of `(js_pattern, text, expected)` incl. fallback cases), `anchor` (line/pattern/selection/content resolution, first-match, unresolved flagging against a fixture repo), `schema`/`model` (lenient validation, skip-invalid, precedence), `discovery` (finds all known locations under a fixture tree; git-root resolution; broken-file skip), `markdown` (ref extraction → link map), `git` (ref status via an **injected fake runner**: match/drift/no-repo).
  - *Integration seam (headless nvim):* `player` (start/next/prev/goto/resume/stop transitions), `float`/`highlight` (float content + counter; extmark on the right line; buffer-local maps), `command` (`:CodeTour` dispatch + completion), `degradation` (a broken tour still lists and plays its valid steps).
- **Fixtures:** `tests/fixtures/tours/` (valid + deliberately malformed `.tour` files) and `tests/fixtures/repo/` (a tiny source tree to anchor steps against).
- **Prior art:** standard Neovim-plugin test conventions — `*_spec.lua` under `tests/`, run via `PlenaryBustedDirectory` in headless nvim. This is the de-facto pattern used across the ecosystem (telescope, gitsigns, etc.).

## Out of Scope

- **Tour authoring / recording** in Neovim (creating or editing `.tour` files). The JSON spec is the boundary; the plugin only consumes it.
- **Executing tour-embedded actions in MVP:** shell commands (`>>`) and code-injection ("Insert Code") render inert; they are deferred and, when added, will be explicit/confirmed.
- **VS-Code-specific affordances:** `command:` links (dropped/inert) and `view`-anchored steps (graceful-degrade in MVP; full support is a roadmap item).
- **`when` condition evaluation** (deferred; only ever a sandboxed platform-var evaluator, never arbitrary JS).
- **Git working-tree mutation** for `ref` (checkout offer and ref-blob playback are roadmap, not MVP).
- **Cross-restart resume persistence** (deferred).
- **Full bit-for-bit JS regex fidelity** (Tier-3; deferred — requires a native dependency).
- **Native markdown pretty-renderer** (deferred; treesitter baseline + optional plugin in MVP).
- **Multiple concurrent active tours** (single active tour only).

## Further Notes

- The deferred items above are tracked, ordered, in the design spec's roadmap and will become their own issues after MVP.
- The plugin's resilience posture is a deliberate, repeated theme: one bad file never breaks discovery; one bad step never breaks a tour; one unresolved anchor never breaks navigation. Degrade, notify, continue.
- The MVP is genuinely a dozen-ish small modules; it is decomposed so that a thin end-to-end slice (discover → play a file+line step in the float) can land early, with the harder pieces (Tier-2 regex, pattern anchoring, link-following) layered on after.
