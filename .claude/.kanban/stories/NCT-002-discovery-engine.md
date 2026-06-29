---
id: NCT-002
type: story
epic: NCT
status: done
priority: high
size: M
labels: [ready-for-agent]
created: 2026-06-28
updated: 2026-06-28
---

# Full tour discovery engine

## Parent
EPIC-001 · nvim-code-tour

## What to build
Deepen discovery from the skeleton's minimal lookup into the complete engine. Resolve the
workspace root as the git root (`vim.fs.root` on `.git`), falling back to cwd. Scan all known
locations — `.tours/`, `.vscode/tours/`, `.github/tours/` (nested allowed), and a root
`main.tour` / `.tour` — plus a configurable extra directory. Detect the primary tour
(`isPrimary: true` or a title matching `^#?\s*1\s*-`). Return tour metadata (title, step count,
primary flag, source path) without fully loading every tour. Expose results via
`require('codetour').list()` / `:CodeTour list` (printed for now; the picker UI is NCT-003).

This is a pure-core module — fixture-tree driven, no UI.

## Acceptance criteria
- [ ] Finds tours in all standard locations + a configured extra dir, under a fixture tree.
- [ ] Root resolves to git root when present, else cwd.
- [ ] Primary tour detected via `isPrimary` or `^#?\s*1\s*-` title.
- [ ] `:CodeTour list` reports discovered tours with title + step count.
- [ ] Tested as a pure function against `tests/fixtures/`.

## Blocked by
- NCT-001
