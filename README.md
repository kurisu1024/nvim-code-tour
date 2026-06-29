# nvim-code-tour

Play [CodeTour](https://github.com/microsoft/codetour) `.tour` files natively in Neovim.

A `.tour` file is a guided, step-by-step walkthrough of a codebase: each step anchors to a
file and line (or a pattern, a selection, or inline content) and shows a markdown
explanation. This plugin **plays** those tours inside Neovim the way the VS Code CodeTour
extension plays them inside VS Code — a narrator float shows the step's prose while the code
window jumps to the anchor and highlights it.

> **Playback only.** This plugin reads and navigates existing tours. It does not record or
> author `.tour` files — the JSON format is the contract, and we consume it. Authoring is a
> separate, deferred phase.

## Status

The playback MVP is feature-complete: tour discovery, a Telescope picker, file/pattern/
selection/content step types, pattern anchoring via a JS→Vim regex translator, markdown
link following, `nextTour` chaining, git `ref` drift warnings, `:checkhealth`, and
in-session resume. See [Roadmap](#roadmap) for what is deliberately deferred.

## Requirements

- **Neovim 0.10+** (hard floor — 0.10 APIs are used with no backward polyfill).
- **[telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)** — the only hard
  dependency, and only for the tour picker. Without it, the plugin still works: `:CodeTour
  start` degrades to playing the primary (or first) tour, and `:CodeTour list` shows them
  all. Telescope pulls in `plenary.nvim` transitively.
- **Optional:** [render-markdown.nvim](https://github.com/MeanderingProgrammer/render-markdown.nvim)
  or [markview.nvim](https://github.com/OXY2DEV/markview.nvim) — if present, the narrator
  float uses one of them to prettify markdown. Otherwise it falls back to Treesitter
  highlighting. Never a hard dependency.

## Install

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "your/nvim-code-tour", -- or a local dir: dir = "~/path/to/nvim-code-tour"
  dependencies = { "nvim-telescope/telescope.nvim" },
  config = function()
    require("codetour").setup()
  end,
}
```

With [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use({
  "your/nvim-code-tour",
  requires = { "nvim-telescope/telescope.nvim" },
  config = function()
    require("codetour").setup()
  end,
})
```

As a native package (no plugin manager):

```sh
git clone <repo> \
  ~/.local/share/nvim/site/pack/codetour/start/nvim-code-tour
```

`:CodeTour` is registered at startup, so it works even before `setup()` is called.
`setup()` is only needed if you want to override defaults.

## Quick start

1. Open a project that has tours (in `.tours/`, `.vscode/tours/`, `.github/tours/`, or a
   root `main.tour` / `*.tour`).
2. Run `:CodeTour start`.
   - One tour → it plays immediately.
   - Several tours → the Telescope picker opens (or, without Telescope, the primary tour
     plays and a notice tells you to use `:CodeTour list`).
3. The narrator float appears at the bottom; the code window jumps to step 1 and highlights
   the anchored line.
4. Navigate with `]t` (next) and `[t` (prev). Press `q` to stop.

Focus stays in the **code window** while a tour plays, so `]t` / `[t` / `q` work without
touching the float. To follow a markdown link in the float (to another step, another tour,
or a file), focus the float and press `<CR>` over the link — or map
`<Plug>(codetour-follow)` to a key you can hit from the code window (see below).

## Commands

A single `:CodeTour <sub>` command with tab-completion:

| Subcommand        | Action                                                            |
|-------------------|-------------------------------------------------------------------|
| `:CodeTour start` | Discover tours and start one (picker if several). Default if no sub given. |
| `:CodeTour next`  | Go to the next step (chains to `nextTour` at the end).            |
| `:CodeTour prev`  | Go to the previous step.                                          |
| `:CodeTour goto N`| Jump to step `N`.                                                 |
| `:CodeTour resume`| Re-open the tour where you left off (after `:CodeTour end`).      |
| `:CodeTour end`   | Stop the tour (tears down the float; keeps position for resume).  |
| `:CodeTour list`  | List discovered tours (title, step count, primary flag, path).   |
| `:CodeTour focus` | Move focus into the narrator window.                              |
| `:CodeTour renderer {mode}` | Switch the narrator renderer live: `float`, `float-anchored`, or `split`. |

## Keymaps

The plugin sets **no global keymaps**. While a tour is playing, these buffer-local maps are
active (on the code buffer and on the float):

| Key   | Action                                  | Config field      |
|-------|-----------------------------------------|-------------------|
| `]t`  | Next step                               | `keymaps.next`    |
| `[t`  | Previous step                           | `keymaps.prev`    |
| `q`   | Stop the tour                           | `keymaps.stop`    |
| `<CR>`| Follow the link under the cursor (float)| `keymaps.follow`  |
| `]f`  | Toggle focus between code window and narrator | `keymaps.focus` |

The narrator also shows a one-line **keybinding hint** (in the float's border footer, or the
split's winbar) so you don't have to memorize these. Disable it with `float.hint = false`.

Set `default_keymaps = false` to suppress the maps entirely and drive everything via
`:CodeTour` or the Lua API.

For your own **global** bindings, map the provided `<Plug>` targets:

```lua
vim.keymap.set("n", "<leader>tn", "<Plug>(codetour-next)")
vim.keymap.set("n", "<leader>tp", "<Plug>(codetour-prev)")
vim.keymap.set("n", "<leader>tq", "<Plug>(codetour-stop)")
vim.keymap.set("n", "<leader>tr", "<Plug>(codetour-resume)")
vim.keymap.set("n", "<leader>tl", "<Plug>(codetour-list)")
vim.keymap.set("n", "<leader>tf", "<Plug>(codetour-follow)") -- follow link in float
vim.keymap.set("n", "<leader>tF", "<Plug>(codetour-focus)")  -- focus the narrator
```

## Configuration

`setup()` is optional; defaults shown:

```lua
require("codetour").setup({
  tour_dir = nil,          -- extra directory to scan beyond the conventional locations
  renderer = "float",      -- "float" (A) | "float-anchored" (B) | "split" (C)
  float = {
    position = "bottom",   -- "bottom" | "top"  (fixed float only)
    width = 0.5,           -- fraction of editor columns
    height = 0.3,          -- fraction of editor rows (also the split height)
    hint = true,           -- show the keybinding hint in the footer/winbar
  },
  default_keymaps = true,  -- buffer-local tour maps while playing
  keymaps = {
    next = "]t",
    prev = "[t",
    follow = "<CR>",
    stop = "q",
    focus = "]f",
  },
  markdown_renderer = "auto", -- "auto" | "treesitter" | "render-markdown" | "markview"
})
```

### Renderer modes

Three narrator presentations sit behind one seam; switch between them live mid-tour with
`:CodeTour renderer {mode}` to compare:

- **`float`** (A) — a fixed narrator float anchored to the top/bottom edge. Never disturbs
  your window layout. The code window scrolls so the highlighted line stays in the clear
  band (the float never covers the line it points at). The default.
- **`float-anchored`** (B) — a float pinned next to the step's anchored line — below it when
  there's room beneath, above it otherwise — so it sits beside the highlighted code without
  covering it.
- **`split`** (C) — the narrator in a horizontal split below the code window. Changes the
  layout, but some people prefer a stable, non-overlapping panel.

## Lua API

The Lua API is the real surface; `:CodeTour` just routes to it.

```lua
local ct = require("codetour")

ct.setup(opts)        -- configure (optional)
ct.start(opts)        -- opts: { root?, step? } — discover and play
ct.next()
ct.prev()
ct["goto"](n)         -- `goto` is a Lua keyword; use the index form
ct.resume()
ct.stop()
ct.list()
ct.focus()             -- move focus into the narrator window
ct.set_renderer(mode)  -- "float" | "float-anchored" | "split" (live switch)
```

## Health check

```vim
:checkhealth codetour
```

Reports how many tours were discovered (and flags any with validation problems), plus the
status of the two optional integrations (Telescope and the markdown prettifier).

## How tours are discovered

Discovery resolves the workspace root as **git root (`vim.fs.root`) then cwd**, and scans:

- `.tours/`
- `.vscode/tours/`
- `.github/tours/`
- root `main.tour` and `*.tour`
- any extra `tour_dir` you configured

A tour is marked **primary** if it sets `isPrimary: true` or its title starts with `1 -`.
Invalid tours are not hidden — they are flagged (visible in `:CodeTour list` and
`:checkhealth`) and skipped at play time rather than crashing discovery.

## What's supported (and what degrades)

| Feature                              | Behavior                                                     |
|--------------------------------------|-------------------------------------------------------------|
| `file` + `line` steps                | Jump and highlight the line.                                 |
| `file` + `pattern` steps             | Resolve the line by regex (JS→Vim translation, first match).|
| `selection` steps                    | Highlight the selected range.                                |
| `content` steps (no file)            | Narrate the description only; code window untouched.         |
| Markdown links (step / tour / file)  | Followed with `<CR>` in the float.                           |
| `nextTour` chaining                  | `]t` past the last step chains to the named tour.            |
| Git `ref`                            | Compares to HEAD; **warns** on drift. Never mutates the tree.|
| `directory` steps                    | Open the directory listing in the code window.               |
| `uri` steps                          | `file://` opens the file; other schemes via `vim.ui.open`.   |
| `view`-anchored steps                | Unsupported view → narrate the description, with a notice.   |
| `command:` links, shell `>>`, code injection | Rendered **inert** (never executed).                |

Resilience is a design principle: a missing file, an unresolvable pattern, or a broken tour
**degrades, notifies, and continues** — navigation keeps working throughout.

## Roadmap

Done since the MVP: fast-follow `directory` & `uri` steps; renderer modes B
(line-anchored float) and C (split) behind the `Renderer` seam, switchable live.

Still deferred, roughly in order:

1. `view`-anchored steps.
2. Cross-restart resume persistence (state file under `stdpath('state')/codetour/`).
3. Gated shell `>>` commands and code injection (explicit, confirmed).
4. Git `ref`: checkout offer and ref-blob playback without checkout.
5. `when` conditions — sandboxed evaluator, platform vars only, never arbitrary JS.
6. Tier-3 full JS-regex fidelity (only if a real tour needs it).
7. Native markdown pretty-renderer.
8. Extension / event API.

## Development

```sh
make test                          # run the whole suite headless (plenary/busted)
make test-file FILE=tests/foo_spec.lua  # run one spec (reliable per-file exit code)
```

Architecture: a layered, pure core (`core/`) → a `player` conductor → swappable UI adapters
behind a `Renderer` seam (`ui/`). The core never imports Telescope or opens windows. See
`docs/superpowers/specs/2026-06-28-nvim-code-tour-design.md` for the full design.
</content>
</invoke>
