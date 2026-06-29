---
id: NCT-009
type: story
epic: NCT
status: backlog
priority: medium
size: M
labels: [ready-for-agent]
created: 2026-06-28
updated: 2026-06-28
---

# Config, command surface, checkhealth & resume

## Parent
EPIC-001 · nvim-code-tour

## What to build
Complete the user-facing surface. Full `:CodeTour` subcommands with tab-completion
(`start|next|prev|goto|resume|end|list`); `goto N`; in-session `resume` (retain step after
`end`). Config via `setup{}`: float position/size, `default_keymaps` toggle + remappable keys,
`tour_dir`, `markdown_renderer = "auto"` (detect `render-markdown.nvim`/`markview.nvim`, else
treesitter). Expose `<Plug>(codetour-*)` mappings (no global keymaps set). `:checkhealth
codetour` reports discovery + validation problems and optional-integration status.

## Acceptance criteria
- [ ] `:CodeTour` exposes all subcommands with working tab-completion; `goto`/`resume` work.
- [ ] `resume` re-enters the last tour at the last step within the session.
- [ ] Config options take effect (float placement, keymap toggle/remap, tour_dir, renderer).
- [ ] An optional md-renderer plugin is used when present; treesitter otherwise.
- [ ] `<Plug>` mappings exist; no global keymaps are set by default.
- [ ] `:checkhealth codetour` reports discovery/validation/integration status.

## Blocked by
- NCT-001
