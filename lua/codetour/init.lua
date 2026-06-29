-- Public entry point. setup() + the navigation API, plus the discovery→play
-- path behind `start()`.
--
-- The player owns playback of a concrete tour; this module finds a tour on disk
-- (skeleton: first valid one — the Telescope picker arrives in NCT-003) and
-- hands it over. Resilient by construction: a bad file is skipped, never fatal.

local config = require("codetour.config")
local discovery = require("codetour.core.discovery")
local json = require("codetour.core.json")
local model = require("codetour.core.model")
local player = require("codetour.player")
local command = require("codetour.command")
local picker = require("codetour.ui.picker")

local M = {}

function M.setup(opts)
  config.setup(opts)
  command.register()
  return M
end

local function resolve_root(opts)
  if opts and opts.root then
    return opts.root
  end
  local name = vim.api.nvim_buf_get_name(0)
  local start = name ~= "" and name or vim.fn.getcwd()
  -- Git-root-then-cwd resolution lives in discovery (the engine owns it).
  return discovery.resolve_root(start)
end

-- The configured extra directory beyond the conventional locations.
local function find_opts()
  return { tour_dir = config.get().tour_dir }
end

local function load_tour(path)
  -- A file discovered by the glob can vanish or become unreadable before we read
  -- it; that must skip the file, not crash discovery.
  local read_ok, lines = pcall(vim.fn.readfile, path)
  if not read_ok then
    return nil, "unreadable: " .. tostring(lines)
  end
  local ok, raw = json.decode(table.concat(lines, "\n"))
  if not ok then
    return nil, "bad JSON: " .. tostring(raw)
  end
  local tour, err = model.normalize(raw)
  if not tour then
    return nil, "invalid: " .. table.concat(err, "; ")
  end
  return tour
end

-- Load one discovered tour meta and hand it to the player. Resilient: a file
-- that vanished or fails to normalize is skipped with a notice, never fatal.
local function play_meta(meta, root, step)
  local tour, err = load_tour(meta.path)
  if not tour then
    vim.notify("codetour: skipping " .. meta.path .. " (" .. err .. ")", vim.log.levels.WARN)
    return false
  end
  player.start(tour, { root = root, step = step })
  return true
end

-- When we must choose a tour without prompting (telescope absent), prefer the
-- codebase's primary tour, else the first discovered.
local function default_choice(tours)
  for _, t in ipairs(tours) do
    if t.is_primary then
      return t
    end
  end
  return tours[1]
end

-- start(opts?) — opts: { root?, step? }. Discovers, then plays. One tour starts
-- directly; several open the telescope picker (the single telescope touchpoint).
function M.start(opts)
  opts = opts or {}
  local root = resolve_root(opts)
  local tours = discovery.find(root, find_opts())
  if #tours == 0 then
    vim.notify("codetour: no tours found under " .. root, vim.log.levels.INFO)
    return
  end

  if #tours == 1 then
    play_meta(tours[1], root, opts.step)
    return
  end

  -- Selecting an entry plays it via the player; the picker hands back a meta.
  local function on_select(meta)
    play_meta(meta, root, opts.step)
  end

  if picker.available() then
    picker.pick(tours, on_select)
  else
    -- Telescope is the picker's only home; without it, degrade rather than fail:
    -- notify and play the primary (or first) tour so `start` still does something.
    vim.notify(
      "codetour: telescope not found; playing the primary tour ("
        .. #tours
        .. " tours — use :CodeTour list to see them all)",
      vim.log.levels.WARN
    )
    on_select(default_choice(tours))
  end
end

function M.list()
  local root = resolve_root({})
  local tours = discovery.find(root, find_opts())
  if #tours == 0 then
    vim.notify("codetour: no tours found under " .. root, vim.log.levels.INFO)
    return
  end
  local lines = vim.tbl_map(function(t)
    local steps = string.format("%d step%s", t.step_count, t.step_count == 1 and "" or "s")
    local primary = t.is_primary and " (primary)" or ""
    return string.format("  %s  [%s]%s — %s", t.title, steps, primary, vim.fn.fnamemodify(t.path, ":."))
  end, tours)
  vim.notify("codetour: tours found:\n" .. table.concat(lines, "\n"), vim.log.levels.INFO)
end

-- Delegate the navigation surface to the player.
M.next = player.next
M.prev = player.prev
M["goto"] = player["goto"] -- `goto` is a reserved word; index form is portable
M.resume = player.resume
M.stop = player.stop

return M
