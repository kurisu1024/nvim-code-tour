# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Status: greenfield — read this first

This repository is **empty**. There is no source code, no build system, no tests, and
no chosen tech stack yet. Do not search for an implementation, build/lint/test commands,
or an existing architecture — none exist. If a task assumes code is already here, that is
the gap to report, not something to hunt for.

When the stack is chosen, replace this section with the real build/run/test commands.

## What we are building

A **Neovim plugin** that natively supports CodeTour `.tour` files, aiming for feature
parity with the VS Code [CodeTour extension](https://github.com/microsoft/codetour)
(`vsls-contrib.codetour`). A `.tour` file is a guided, step-by-step walkthrough of a
codebase: each step anchors to a file/line (or directory, URI, or selection) and shows a
markdown explanation. The goal is to *play* (and eventually *record*) these tours inside
Neovim the way the VS Code extension does inside VS Code.

The `.tour` format is the contract. It is shared, stable, and authoritative — the schema
below is the source of truth, taken from the upstream extension. The
[`ecc:code-tour` skill](~/.claude/skills) also encodes this format and how tours are
authored; consult it when generating or validating tour files.

## The `.tour` file format (the contract)

Tours are JSON. By convention they live in `.tours/` or `.vscode/tours/` at the repo root
(VS Code also recognizes a root `main.tour`). Schema:
`https://aka.ms/codetour-schema`.

**Top-level** (required: `title`, `steps`):

| Field | Type | Purpose |
|-------|------|---------|
| `title` | string | Tour name (required). |
| `steps` | array | Ordered list of steps (required). |
| `description` | string | Optional tour summary. |
| `ref` | string | Pins the tour to a git branch/commit/tag — playback should be checkout-aware. |
| `isPrimary` | boolean | Marks the codebase's primary tour. |
| `nextTour` | string | Title of the tour that should follow this one (tour chaining). |
| `when` | string | JavaScript condition gating whether the tour is shown. |
| `stepMarker` | string | Marker string that flags a code line as a step. |

**Per-step** (required: `description`):

| Field | Type | Purpose |
|-------|------|---------|
| `description` | string | Markdown explanation shown at the step (required). |
| `file` | string | File path relative to workspace root. |
| `line` | number | Line the step points to. |
| `pattern` | string | Regex to resolve the line by content — used only when `line` is absent. Must survive edits that shift line numbers. |
| `directory` | string | Directory path (directory-anchored step). |
| `uri` | string | Absolute URI (content/external step). |
| `selection` | object | Highlighted range: `start`/`end`, each `{ line, character }` (1-based). |
| `title` | string | Optional step heading. |
| `view` | string | View the step targets (`explorer`, `terminal`, `scm`, `debug`, `search`, … or a custom id). |
| `commands` | array | Command URIs executed when the step is navigated to. |

`description` markdown also carries special CodeTour syntax in the VS Code extension
(runnable shell commands, links to other steps/tours/files, insertable code blocks).
Parity work will need to decide which of these to honor and how.

## Architectural shape (for whoever picks the stack)

Most plugins will be Lua (the modern Neovim default), but that is **not yet decided** —
treat it as an open question, not a fact. Whatever the language, the design pressure that
matters:

- **Separate the tour model from the UI.** Parsing + validating `.tour` JSON against the
  schema above, resolving `pattern` → line, and resolving `ref` against git should be a
  headless, testable core with no dependency on how steps are rendered.
- **Map VS Code UI concepts onto Neovim equivalents**, since the format assumes VS Code's
  UI. Rough correspondences to reason about: comment-thread step popups → floating windows
  or virtual text via extmarks; the CodeTour tree view → a sidebar/list buffer or
  quickfix; CodeLens "start tour" affordances → extmarks or statusline; selection
  highlight → extmark highlights.
- **Playback first, recording later.** Reading and navigating existing tours is the core
  value; interactive tour authoring is a larger, separable phase.

## Conventions

- Use `fd` (not `find`) for locating files.
- For code navigation in a real codebase, use the jCodemunch MCP tools per the global
  policy — but until source exists here, there is nothing to navigate.
