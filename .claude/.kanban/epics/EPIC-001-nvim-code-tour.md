---
id: EPIC-001
type: epic
prefix: NCT
status: backlog
priority: high
size: L
labels: [ready-for-agent]
created: 2026-06-28
updated: 2026-06-28
---

# nvim-code-tour

A Neovim plugin that natively **plays** CodeTour `.tour` files — feature parity with the VS
Code CodeTour extension for the *consumption* path. Tours are authored elsewhere (Claude,
hand, or VS Code) as JSON; Neovim discovers, plays, and navigates them.

**Source of truth:**
- PRD — `docs/superpowers/specs/2026-06-28-nvim-code-tour-prd.md`
- Design spec — `docs/superpowers/specs/2026-06-28-nvim-code-tour-design.md`

**Shape:** Lua, Neovim 0.10 floor. Telescope is the only hard dep. Layered architecture —
pure core engine (parse/validate/anchor/jsregex/markdown/discovery/git) → player/state →
swappable UI adapters (fixed narrator float). TDD with plenary busted across two seams
(pure core + headless-nvim integration).

Stories (NCT-NNN) are vertical tracer-bullet slices, each demoable on its own.
