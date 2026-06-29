---
id: NCT-005
type: story
epic: NCT
status: backlog
priority: medium
size: S
labels: [ready-for-agent]
created: 2026-06-28
updated: 2026-06-28
---

# Selection & content step types

## Parent
EPIC-001 · nvim-code-tour

## What to build
Two more MVP step types. Selection steps carry a `selection {start,end}` range — highlight the
full multi-line range (not just one line) and place the cursor at its start. Content steps have
no `file` — the narrator float shows the step's markdown only, with no code-window jump or
highlight. Both flow through the existing anchor/player/renderer seams.

## Acceptance criteria
- [ ] A selection step highlights the full `start`→`end` range and positions the cursor at start.
- [ ] A content step (no file) shows narrative only; the code window is untouched.
- [ ] Navigating into and out of a content step leaves prior highlights cleaned up.
- [ ] Anchor resolution for selection/content tested as pure functions.

## Blocked by
- NCT-001
