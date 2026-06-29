-- ui/picker.lua — the ONLY telescope touchpoint.
--
-- Lists discovered tours (title + step count, primary marked, broken flagged)
-- and hands the chosen one back through an injected `on_select` callback. The
-- core never imports this module; only `init.lua` does, at the `start()` seam.
--
-- Telescope is a *soft* reference here: it is required lazily inside `pick()`
-- and `available()`, always guarded with `pcall`. Requiring this module — and
-- therefore loading the whole plugin — never errors when telescope is absent.
-- Everything except `pick()` is pure and works with no telescope present, which
-- is exactly how the list/selection logic is unit-tested.

local M = {}

-- Pure: human label for one tour's step count ("1 step" / "3 steps").
local function steps_label(n)
  n = n or 0
  return string.format("%d step%s", n, n == 1 and "" or "s")
end

-- Pure: the one-line display for a tour meta.
--   "Walkthrough  [3 steps]"
--   "1 - Onboarding  [1 step] (primary)"
--   "Bad Tour  [2 steps] (broken)"
function M.format(meta)
  local parts = { meta.title or "(untitled)", "  [", steps_label(meta.step_count), "]" }
  if meta.is_primary then
    table.insert(parts, " (primary)")
  end
  if meta.broken then
    table.insert(parts, " (broken)")
  end
  return table.concat(parts)
end

-- Pure: build selectable entries from discovered tour metas. Each entry keeps
-- the originating meta so a selection can be handed back untouched.
function M.build_entries(tours)
  local entries = {}
  for _, meta in ipairs(tours or {}) do
    table.insert(entries, {
      tour = meta,
      display = M.format(meta),
      ordinal = meta.title or "",
    })
  end
  return entries
end

-- Pure: dispatch a chosen meta. A broken tour can't be played, so selecting one
-- notifies instead of starting. Returns true only when the selection was handed
-- to `on_select`.
function M.select(meta, on_select)
  if not meta then
    return false
  end
  if meta.broken then
    vim.notify(
      "codetour: '" .. (meta.title or "?") .. "' is broken and can't be played",
      vim.log.levels.WARN
    )
    return false
  end
  on_select(meta)
  return true
end

-- Is telescope importable right now? Guarded so a missing dep never raises.
function M.available()
  return (pcall(require, "telescope")) == true
end

-- Open the telescope picker over `tours`; on confirm, hand the chosen meta to
-- `on_select` via `M.select`. Telescope is required lazily and guarded: if it
-- isn't installed this is a no-op returning false, and `init` decides how to
-- degrade. Returns true once the picker has been opened.
function M.pick(tours, on_select)
  local ok, pickers = pcall(require, "telescope.pickers")
  if not ok then
    return false
  end
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  pickers
    .new({}, {
      prompt_title = "CodeTour",
      finder = finders.new_table({
        results = M.build_entries(tours),
        entry_maker = function(entry)
          return {
            value = entry.tour,
            display = entry.display,
            ordinal = entry.ordinal,
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          if selection then
            M.select(selection.value, on_select)
          end
        end)
        return true
      end,
    })
    :find()

  return true
end

return M
