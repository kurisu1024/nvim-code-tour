---
id: NCT-008
type: story
epic: NCT
status: backlog
priority: high
size: M
labels: [ready-for-agent]
created: 2026-06-28
updated: 2026-06-28
---

# Resilience & graceful degradation

## Parent
EPIC-001 · nvim-code-tour

## What to build
Harden the whole feature against malformed and VS-Code-specific tours. Lenient validation: skip
invalid steps but keep the tour; one bad `.tour` file never breaks discovery of the others; a
broken tour still appears in the list but flagged (not hidden). An unresolved anchor shows the
step's narrative with a warning and keeps navigation working. An unknown/unsupported `view`
degrades to rendering the description. Shell-command (`>>`), code-injection ("Insert Code"), and
`command:` links render as visible-but-inert text — nothing executes or edits files. All
problems surface as clear `vim.notify` messages naming the file/step.

## Acceptance criteria
- [ ] One malformed file doesn't break discovery; one invalid step doesn't break its tour.
- [ ] Broken tours appear in the list, flagged.
- [ ] Unresolved anchor → narrative + warning, navigation still works.
- [ ] Unknown `view` degrades to narrative; no error.
- [ ] `>>`, code-injection, and `command:` syntax render inert — nothing runs or edits.
- [ ] A `degradation` integration spec drives malformed fixtures and asserts no crash.

## Blocked by
- NCT-001
