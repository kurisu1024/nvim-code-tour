---
id: NCT-004
type: story
epic: NCT
status: done
priority: high
size: L
labels: [ready-for-agent]
created: 2026-06-28
updated: 2026-06-28
---

# Pattern anchoring + Tier-2 JS→Vim regex translation

## Parent
EPIC-001 · nvim-code-tour

## What to build
Support `pattern`-anchored steps so a step re-locates by code content when `line` is absent.
Build the `jsregex` module: translate a JavaScript-style regex into a Vim regex usable by
`vim.regex()` — force very-magic and map the common JS constructs (`(?:)`, `(?=)`, `(?!)`,
`(?<=)`, character classes, `{n,m}`), with a graceful fallback (warn, don't crash) on anything
untranslatable. The `anchor` module scans the file's lines, first match wins, and yields the
resolved line; an unresolved pattern is flagged so playback can degrade (handled fully in
NCT-008) rather than error.

The `jsregex` translator is the model TDD target: a fixture table of `(js_pattern, text,
expected)` including fallback cases.

## Acceptance criteria
- [ ] `pattern` steps resolve to the correct line via `vim.regex()` over translated patterns.
- [ ] JS constructs in the supported subset translate and match correctly (fixture table).
- [ ] Untranslatable patterns fall back gracefully with a warning, no crash.
- [ ] First match wins; precedence `line` > `pattern` honored.
- [ ] Unresolved pattern is flagged (not fatal).
- [ ] `jsregex` and `anchor` tested as pure functions.

## Blocked by
- NCT-001
