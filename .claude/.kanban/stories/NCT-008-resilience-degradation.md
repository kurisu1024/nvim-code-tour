---
id: NCT-008
type: story
epic: NCT
status: done
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

## Carried over from NCT-001 review
- A file step pointing at a **nonexistent path** silently opens an empty
  `[New File]` buffer with no notice. The window-safety + pcall hardening already
  prevents a crash; this story should add the **notify** leg ("step N: file X not
  found") so the degradation is visible, per "degrade, notify, continue."

## Blocked by
- NCT-001
