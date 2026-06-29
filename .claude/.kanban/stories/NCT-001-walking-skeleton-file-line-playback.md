---
id: NCT-001
type: story
epic: NCT
status: backlog
priority: high
size: M
labels: [ready-for-agent]
created: 2026-06-28
updated: 2026-06-28
---

# Walking skeleton — play a single file+line tour

## Parent
EPIC-001 · nvim-code-tour

## What to build
The thinnest end-to-end path that touches every architectural seam. `require('codetour').setup()`
registers a `:CodeTour start` command. Starting discovers a tour from a standard location,
decodes the JSON, runs minimal structural validation, normalizes it to the Tour/Step model,
and hands it to the player. The player opens the step's `file`, moves the cursor to `line`,
highlights the anchored line with an extmark, and shows the step's markdown in a
fixed-position narrator float (treesitter-highlighted) with a `Step n/m` counter. Buffer-local
maps `]t`/`[t` move between steps (updating float + code window in place); `q` ends the tour
and tears down the float, extmarks, and maps cleanly, never disturbing window layout.

This establishes skeletal versions of: discovery, json, schema, model, player, renderer
(`Renderer` interface + fixed-float impl), codewin, highlight. Later stories deepen each.

## Acceptance criteria
- [ ] `setup()` + `:CodeTour start` plays a valid file+line tour end to end.
- [ ] Code window opens the right file with the cursor on the anchored line, line highlighted.
- [ ] Narrator float shows the step's markdown (treesitter highlight) + `Step n/m`, in a fixed position.
- [ ] `]t`/`[t` navigate; float and code window update in place without reflowing layout.
- [ ] `q` ends the tour and removes float, extmarks, and buffer-local maps completely.
- [ ] Core modules (model/schema) tested as pure functions; player/float tested in headless nvim.

## Blocked by
None — can start immediately.
