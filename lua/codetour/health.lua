-- `:checkhealth codetour`.
--
-- Reports three things: tour discovery (how many tours, and any with validation
-- problems), and the status of the two optional integrations — telescope.nvim
-- (the tour picker) and the markdown prettifier. The work is split so it is
-- testable: `collect(root)` returns a pure list of { level, message } entries;
-- `check()` is the thin adapter Neovim calls, replaying that list into the
-- `vim.health` reporter. Resilient by construction: discovery is pcall-guarded so
-- a strange root degrades to an error entry instead of raising.

local M = {}

-- collect(root?) -> { { level = "ok"|"warn"|"error"|"info", message = string }, ... }
function M.collect(root)
  local config = require("codetour.config")
  local discovery = require("codetour.core.discovery")
  local picker = require("codetour.ui.picker")
  local mdrender = require("codetour.ui.mdrender")

  local results = {}
  local function add(level, message)
    results[#results + 1] = { level = level, message = message }
  end

  root = root or discovery.resolve_root()

  -- Tour discovery + per-tour validation.
  local ok, tours = pcall(discovery.find, root, { tour_dir = config.get().tour_dir })
  if not ok then
    add("error", "tour discovery failed: " .. tostring(tours))
  elseif #tours == 0 then
    add("info", "no tours found under " .. root)
  else
    add("ok", string.format("%d tour(s) discovered under %s", #tours, root))
    for _, t in ipairs(tours) do
      if t.broken then
        add("warn", string.format("tour has validation problems: %s", vim.fn.fnamemodify(t.path, ":.")))
      end
    end
  end

  -- Optional integration: telescope.nvim (the tour picker).
  if picker.available() then
    add("ok", "telescope.nvim found (tour picker enabled)")
  else
    add("info", "telescope.nvim not found (picker degrades to the primary tour)")
  end

  -- Optional integration: markdown prettifier, else Treesitter.
  local choice = mdrender.select(config.get().markdown_renderer)
  if choice == "treesitter" then
    add("info", "markdown renderer: treesitter (no render-markdown.nvim / markview.nvim detected)")
  else
    add("ok", "markdown renderer: " .. choice)
  end

  return results
end

-- The reporter Neovim calls for `:checkhealth codetour`. Replays collect() into
-- vim.health. Guarded per-entry so one odd value can't abort the report.
function M.check()
  local health = vim.health
  health.start("codetour")
  local report = {
    ok = health.ok,
    warn = health.warn,
    error = health.error,
    info = health.info,
  }
  for _, r in ipairs(M.collect()) do
    local fn = report[r.level] or health.info
    pcall(fn, r.message)
  end
end

return M
