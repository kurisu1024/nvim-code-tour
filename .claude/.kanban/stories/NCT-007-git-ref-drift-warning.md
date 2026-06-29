---
id: NCT-007
type: story
epic: NCT
status: done
priority: medium
size: S
labels: [ready-for-agent]
created: 2026-06-28
updated: 2026-06-28
---

# Git `ref` drift warning

## Parent
EPIC-001 · nvim-code-tour

## What to build
When a tour declares a `ref`, the `core/git` module resolves it and compares to current HEAD.
On drift, the player emits a single non-blocking notice ("recorded at <ref>; you're on
<branch> — anchors may have drifted") on first activation. The working tree is never modified.
If there's no git repo, `ref` is ignored silently. Git runs through an injected runner so the
module is testable without a real repo.

## Acceptance criteria
- [ ] A tour whose `ref` differs from HEAD warns once per activation.
- [ ] A matching `ref` produces no warning.
- [ ] No working-tree mutation ever occurs (no checkout).
- [ ] No git repo → `ref` ignored, no error.
- [ ] `core/git` tested via an injected fake runner (match / drift / no-repo).

## Blocked by
- NCT-001
