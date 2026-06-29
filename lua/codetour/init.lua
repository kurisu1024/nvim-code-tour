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
  return vim.fs.root(start, ".git") or vim.fn.getcwd()
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

-- start(opts?) — opts: { root?, step? }. Discovers, then plays.
function M.start(opts)
  opts = opts or {}
  local root = resolve_root(opts)
  local tours = discovery.find(root)
  if #tours == 0 then
    vim.notify("codetour: no tours found under " .. root, vim.log.levels.INFO)
    return
  end

  for _, t in ipairs(tours) do
    local tour, err = load_tour(t.path)
    if tour then
      player.start(tour, { root = root, step = opts.step })
      return
    end
    vim.notify("codetour: skipping " .. t.path .. " (" .. err .. ")", vim.log.levels.WARN)
  end

  vim.notify("codetour: no playable tours found", vim.log.levels.WARN)
end

function M.list()
  local root = resolve_root({})
  local tours = discovery.find(root)
  if #tours == 0 then
    vim.notify("codetour: no tours found under " .. root, vim.log.levels.INFO)
    return
  end
  local names = vim.tbl_map(function(t)
    return "  " .. vim.fn.fnamemodify(t.path, ":.")
  end, tours)
  vim.notify("codetour: tours found:\n" .. table.concat(names, "\n"), vim.log.levels.INFO)
end

-- Delegate the navigation surface to the player.
M.next = player.next
M.prev = player.prev
M["goto"] = player["goto"] -- `goto` is a reserved word; index form is portable
M.resume = player.resume
M.stop = player.stop

return M
