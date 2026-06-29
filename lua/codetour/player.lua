-- The conductor: one active tour, the real public surface.
--
-- Holds the playback state and runs the navigation spine on every move:
--   anchor (skeleton: file+line) -> codewin.open -> highlight.apply
--   -> markdown.parse -> renderer.present
--
-- In-session resume: stop() tears down the UI but keeps the tour + step in
-- memory so resume() re-enters where you left off.

local config = require("codetour.config")
local anchor = require("codetour.core.anchor")
local git = require("codetour.core.git")
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
  drift_notified = false, -- one git-ref drift notice per activation
}

-- When the tour pins a `ref`, compare it to HEAD and emit a single non-blocking
-- notice on drift. Read-only and never mutates the tree (see core.git). The
-- check runs at most once per activation: the flag is set up front so a slow or
-- failing git call can never re-fire on every navigation, and match / no-repo
-- stay silent.
local function maybe_notify_drift()
  if state.drift_notified then
    return
  end
  local ref = state.tour and state.tour.ref
  if not ref or ref == "" then
    return
  end
  state.drift_notified = true
  local ok, status = pcall(git.status, ref, { cwd = state.root })
  if not ok or type(status) ~= "table" then
    return
  end
  if status.state == "drift" then
    vim.notify(git.drift_message(status), vim.log.levels.WARN)
  end
end

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

-- Drop the line highlight carried by the previous step, wherever it landed.
local function clear_highlight()
  if state.hl_buf then
    highlight.clear(state.hl_buf)
    state.hl_buf = nil
  end
end

-- Open a file-anchored step's resolution (line or selection) in the code window.
local function render_code(step, resolution)
  local sel = resolution.selection
  local col = sel and math.max(0, (sel.start.character or 1) - 1) or 0
  local buf, win = codewin.open(state.code_win, state.root, step.file, resolution.line, col)
  if buf and win then
    state.code_win = win -- codewin may have resolved a different, usable window
    clear_highlight()
    highlight.clear(buf)
    if resolution.kind == "selection" then
      highlight.apply_selection(buf, sel)
    elseif resolution.line then
      highlight.apply(buf, resolution.line)
    end
    state.hl_buf = buf
    set_maps(buf)
  else
    -- No safe window to open into; narrate only, drop any stale anchor, but
    -- still wire nav keys on whatever buffer the user is looking at.
    clear_highlight()
    set_maps(vim.api.nvim_get_current_buf())
  end
end

-- Render the current step end to end.
local function render()
  maybe_notify_drift()
  local step = state.tour.steps[state.index]
  local resolution = anchor.resolve(step)

  if resolution.kind == "content" or not step.file then
    -- Content step: no code anchor. Leave the code window untouched, clear any
    -- prior highlight, and wire nav maps on the current buffer so ]t/[t/q work
    -- without having to focus the float.
    clear_highlight()
    set_maps(vim.api.nvim_get_current_buf())
  else
    render_code(step, resolution)
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
  state.drift_notified = false
  state.root = opts.root or vim.fn.getcwd()
  -- Preferred code window; codewin.open re-resolves if it isn't usable.
  state.code_win = vim.api.nvim_get_current_win()
  state.renderer = renderer.new()
  M["goto"](opts.step or 1)
end

-- `goto` is a Lua reserved word; the index form is portable across runtimes.
M["goto"] = function(n)
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
  render()
end

function M.next()
  M["goto"](state.index + 1)
end

function M.prev()
  M["goto"](state.index - 1)
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
  -- Keep a still-valid code window; only fall back to the current one if the
  -- retained handle is gone (codewin.open makes the final safe choice anyway).
  if not (state.code_win and vim.api.nvim_win_is_valid(state.code_win)) then
    state.code_win = vim.api.nvim_get_current_win()
  end
  state.renderer = renderer.new()
  M["goto"](state.index < 1 and 1 or state.index)
end

return M
