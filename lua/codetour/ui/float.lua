-- Fixed-position narrator float (the MVP Renderer impl).
--
-- Shows the step's markdown with a `Step n/m` header, in a float anchored to the
-- bottom of the editor. It never enters the float (focus stays in the code
-- window) and never alters the window layout. Buffer-local maps on the float
-- mirror the tour navigation keys so the float is usable if focused.

local config = require("codetour.config")
local mdrender = require("codetour.ui.mdrender")

local M = {}

local Float = {}
Float.__index = Float

function M.new()
  return setmetatable({ win = nil, buf = nil, links = {} }, Float)
end

function Float:_ensure_buf()
  if self.buf and vim.api.nvim_buf_is_valid(self.buf) then
    return
  end
  self.buf = vim.api.nvim_create_buf(false, true)
  vim.bo[self.buf].filetype = "markdown" -- treesitter highlight when available
  vim.bo[self.buf].buftype = "nofile"
end

local function geometry()
  local cfg = config.get().float
  local cols, rows = vim.o.columns, vim.o.lines
  local width = math.max(20, math.floor(cols * (cfg.width or 0.5)))
  local height = math.max(3, math.floor(rows * (cfg.height or 0.3)))
  local col = math.max(0, math.floor((cols - width) / 2))
  local row = (cfg.position == "top") and 1 or math.max(0, rows - height - 2)
  return { width = width, height = height, row = row, col = col }
end

-- The header (counter line + blank) sits above the markdown render lines, so a
-- buffer row maps to a markdown line by subtracting these two.
local HEADER_ROWS = 2

-- Resolve the link under the float cursor (if any) and hand its action to the
-- player-supplied dispatcher. Pure hit-test against the parsed link map; never
-- executes anything itself.
function Float:_follow(dispatch)
  if not dispatch or not (self.win and vim.api.nvim_win_is_valid(self.win)) then
    return
  end
  local pos = vim.api.nvim_win_get_cursor(self.win)
  local md_line = pos[1] - HEADER_ROWS
  local col = pos[2] + 1 -- cursor col is 0-based; link spans are 1-based bytes
  for _, link in ipairs(self.links or {}) do
    if link.line == md_line and col >= link.from and col <= link.to then
      dispatch(link.action)
      return
    end
  end
end

function Float:_set_maps(view)
  local km = view.keymaps or {}
  local actions = view.actions or {}
  local function map(lhs, fn)
    if lhs and fn then
      vim.keymap.set("n", lhs, fn, { buffer = self.buf, nowait = true, silent = true })
    end
  end
  map(km.next, actions.next)
  map(km.prev, actions.prev)
  map(km.stop, actions.stop)
  if km.follow and actions.follow then
    vim.keymap.set("n", km.follow, function()
      self:_follow(actions.follow)
    end, { buffer = self.buf, nowait = true, silent = true })
  end
end

function Float:present(view)
  self:_ensure_buf()

  self.links = view.links or {}
  self._follow_dispatch = (view.actions or {}).follow

  local header = string.format("Step %s%s", view.counter, view.title and (" — " .. view.title) or "")
  local lines = { header, "" }
  vim.list_extend(lines, view.lines or {})

  vim.bo[self.buf].modifiable = true
  vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, lines)
  vim.bo[self.buf].modifiable = false

  -- Hand the float to the configured markdown renderer. Treesitter is the floor
  -- (filetype=markdown, already set); an installed prettifier decorates instead.
  mdrender.apply(self.buf, mdrender.select(config.get().markdown_renderer))

  local g = geometry()
  local win_opts = {
    relative = "editor",
    width = g.width,
    height = g.height,
    row = g.row,
    col = g.col,
    style = "minimal",
    border = "rounded",
    focusable = true,
    zindex = 50,
  }

  if self.win and vim.api.nvim_win_is_valid(self.win) then
    vim.api.nvim_win_set_config(self.win, win_opts)
  else
    -- enter = false: focus stays in the code window.
    self.win = vim.api.nvim_open_win(self.buf, false, win_opts)
  end

  self:_set_maps(view)
end

-- Public follow entry point for `<Plug>(codetour-follow)`: resolve and dispatch
-- the link under the float cursor using the dispatcher from the last present().
function Float:follow_under_cursor()
  self:_follow(self._follow_dispatch)
end

function Float:close()
  if self.win and vim.api.nvim_win_is_valid(self.win) then
    vim.api.nvim_win_close(self.win, true)
  end
  if self.buf and vim.api.nvim_buf_is_valid(self.buf) then
    vim.api.nvim_buf_delete(self.buf, { force = true })
  end
  self.win, self.buf = nil, nil
end

return M
