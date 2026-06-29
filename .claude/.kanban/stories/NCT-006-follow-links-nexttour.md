---
id: NCT-006
type: story
epic: NCT
status: backlog
priority: medium
size: M
labels: [ready-for-agent]
created: 2026-06-28
updated: 2026-06-28
---

# Follow links in narrative + nextTour chaining

## Parent
EPIC-001 · nvim-code-tour

## What to build
Make tours traversable as authored. The `markdown` module parses a step description into render
lines + a link map (offset → action). In the narrator float, `<CR>` follows the link under the
cursor: a step ref `[#3]` → `player.goto(3)`; a tour ref `[Title]` / `[Title#2]` → resolve the
title against discovered tours and `player.start(that, step)`; a file ref `[label](./path)` →
open the file with no anchor. A tour's `nextTour` is followable through the same tour-resolution
path.

## Acceptance criteria
- [ ] `<CR>` on a step ref jumps to that step in the current tour.
- [ ] `<CR>` on a tour ref starts the referenced tour (at the given step if present).
- [ ] `<CR>` on a file ref opens that file.
- [ ] `nextTour` chains to the next tour by title.
- [ ] The `markdown` link parser is tested as a pure function (description → link map).

## Blocked by
- NCT-001
- NCT-002
