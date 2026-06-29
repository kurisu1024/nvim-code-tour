-- The conductor: one active tour, the real public surface.
--
-- Holds the playback state and runs the navigation spine on every move:
--   anchor (skeleton: file+line) -> codewin.open -> highlight.apply
--   -> markdown.parse -> renderer.present
--
-- In-session resume: stop() tears down the UI but keeps the tour + step in
-- memory so resume() re-enters where you left off.

local config = require("codetour.config")
local markdown = require("codetour.core.markdown")
local codewin = require("codetour.ui.codewin")
local highlight = require("codetour.ui.highlight")
local renderer = require("codetour.ui.renderer")

local M = {}

local state = {
  tour = nil,
  index = 0,
  root = nil,
  code_win = nil,
  hl_buf = nil, -- buffer currently carrying the line highlight
  map_buf = nil, -- buffer currently carrying nav maps
  renderer = nil,
}

local function clear_maps()
  if state.map_buf and vim.api.nvim_buf_is_valid(state.map_buf) then
    local km = config.get().keymaps
    for _, lhs in ipairs({ km.next, km.prev, km.stop }) do
      pcall(vim.keymap.del, "n", lhs, { buffer = state.map_buf })
    end
  end
  state.map_buf = nil
end

local function set_maps(buf)
  clear_maps()
  if not config.get().default_keymaps then
    return
  end
  local km = config.get().keymaps
  local opts = { nowait = true, silent = true }
  vim.keymap.set("n", km.next, M.next, vim.tbl_extend("force", { buffer = buf }, opts))
  vim.keymap.set("n", km.prev, M.prev, vim.tbl_extend("force", { buffer = buf }, opts))
  vim.keymap.set("n", km.stop, M.stop, vim.tbl_extend("force", { buffer = buf }, opts))
  state.map_buf = buf
end

local function teardown_ui()
  if state.hl_buf then
    highlight.clear(state.hl_buf)
    state.hl_buf = nil
  end
  clear_maps()
  if state.renderer then
    state.renderer:close()
    state.renderer = nil
  end
end

-- Render the current step end to end.
local function render()
  local step = state.tour.steps[state.index]

  if step.type == "file" and step.file then
    local buf = codewin.open(state.code_win, state.root, step.file, step.line)
    if state.hl_buf and state.hl_buf ~= buf then
      highlight.clear(state.hl_buf)
    end
    highlight.clear(buf)
    if step.line then
      highlight.apply(buf, step.line)
    end
    state.hl_buf = buf
    set_maps(buf)
  end

  local parsed = markdown.parse(step.description)
  state.renderer:present({
    lines = parsed.lines,
    counter = string.format("%d/%d", state.index, #state.tour.steps),
    title = step.title,
    keymaps = config.get().keymaps,
    actions = { next = M.next, prev = M.prev, stop = M.stop, follow = function() end },
  })
end

-- start(tour, opts) — opts: { root, step }
function M.start(tour, opts)
  if not tour then
    return
  end
  opts = opts or {}
  teardown_ui()
  state.tour = tour
  state.index = 0
  state.root = opts.root or vim.fn.getcwd()
  state.code_win = vim.api.nvim_get_current_win()
  state.renderer = renderer.new()
  M.goto(opts.step or 1)
end

function M.goto(n)
  if not state.tour then
    return
  end
  local total = #state.tour.steps
  if total == 0 then
    return
  end
  state.index = math.max(1, math.min(n, total))
  if not state.renderer then
    state.renderer = renderer.new()
  end
  if not (state.code_win and vim.api.nvim_win_is_valid(state.code_win)) then
    state.code_win = vim.api.nvim_get_current_win()
  end
  render()
end

function M.next()
  M.goto(state.index + 1)
end

function M.prev()
  M.goto(state.index - 1)
end

-- Tear down the UI but keep tour + step for resume().
function M.stop()
  teardown_ui()
end

function M.resume()
  if not state.tour then
    vim.notify("codetour: no tour to resume", vim.log.levels.INFO)
    return
  end
  state.code_win = vim.api.nvim_get_current_win()
  state.renderer = renderer.new()
  M.goto(state.index < 1 and 1 or state.index)
end

return M
