---
id: NCT-003
type: story
epic: NCT
status: backlog
priority: medium
size: S
labels: [ready-for-agent]
created: 2026-06-28
updated: 2026-06-28
---

# Telescope tour picker

## Parent
EPIC-001 · nvim-code-tour

## What to build
A telescope picker (`ui/picker`) listing discovered tours with title + step count and a marker
for the primary tour; selecting one calls `player.start`. This is the single telescope
touchpoint — the core never imports telescope. `:CodeTour start` with multiple tours present
opens the picker; with exactly one tour it starts directly.

## Acceptance criteria
- [ ] `:CodeTour start` opens a telescope picker when multiple tours exist.
- [ ] Each entry shows title + step count; the primary tour is marked.
- [ ] Selecting an entry starts that tour via the player.
- [ ] A single discovered tour starts without prompting.
- [ ] Telescope is referenced only in the picker adapter, never in core.

## Blocked by
- NCT-002
