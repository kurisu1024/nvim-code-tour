-- Split narrator renderer (mode C).
--
-- Presents the step markdown in a horizontal split below the code window instead
-- of a floating window. Unlike the float, a split does change the window layout
-- (that is the point of mode C — a different feel to compare against). It still
-- never steals focus on present: focus returns to the code window after opening.
-- The keybinding hint rides in the split's winbar.

local config = require("codetour.config")
local mdrender = require("codetour.ui.mdrender")

local M = {}

local Split = {}
Split.__index = Split

function M.new()
  return setmetatable({ win = nil, buf = nil, links = {} }, Split)
end

function Split:_ensure_buf()
  if self.buf and vim.api.nvim_buf_is_valid(self.buf) then
    return
  end
  self.buf = vim.api.nvim_create_buf(false, true)
  vim.bo[self.buf].filetype = "markdown"
  vim.bo[self.buf].buftype = "nofile"
end

local HEADER_ROWS = 2

-- Keybinding hint for the winbar. % must be escaped for the winbar format.
local function hint_text(keymaps)
  local km = keymaps or {}
  local parts = {}
  local function add(key, label)
    if key then
      parts[#parts + 1] = key .. " " .. label
    end
  end
  add(km.next, "next")
  add(km.prev, "prev")
  add(km.follow, "follow")
  add(km.focus, "focus")
  add(km.stop, "stop")
  if #parts == 0 then
    return nil
  end
  return (" " .. table.concat(parts, "  ") .. " "):gsub("%%", "%%%%")
end

function Split:_follow(dispatch)
  if not dispatch or not (self.win and vim.api.nvim_win_is_valid(self.win)) then
    return
  end
  local pos = vim.api.nvim_win_get_cursor(self.win)
  local md_line = pos[1] - HEADER_ROWS
  local col = pos[2] + 1
  for _, link in ipairs(self.links or {}) do
    if link.line == md_line and col >= link.from and col <= link.to then
      dispatch(link.action)
      return
    end
  end
end

function Split:_set_maps(view)
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
  map(km.focus, actions.focus_code)
  if km.follow and actions.follow then
    vim.keymap.set("n", km.follow, function()
      self:_follow(actions.follow)
    end, { buffer = self.buf, nowait = true, silent = true })
  end
end

function Split:present(view)
  self:_ensure_buf()

  self.links = view.links or {}
  self._follow_dispatch = (view.actions or {}).follow

  local header = string.format("Step %s%s", view.counter, view.title and (" — " .. view.title) or "")
  local lines = { header, "" }
  vim.list_extend(lines, view.lines or {})

  vim.bo[self.buf].modifiable = true
  vim.api.nvim_buf_set_lines(self.buf, 0, -1, false, lines)
  vim.bo[self.buf].modifiable = false

  -- Open the split once, below everything, without taking focus.
  if not (self.win and vim.api.nvim_win_is_valid(self.win)) then
    local prev = vim.api.nvim_get_current_win()
    local height = math.max(3, math.floor(vim.o.lines * (config.get().float.height or 0.3)))
    vim.cmd("botright " .. height .. "split")
    self.win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(self.win, self.buf)
    vim.wo[self.win].number = false
    vim.wo[self.win].relativenumber = false
    vim.wo[self.win].signcolumn = "no"
    if vim.api.nvim_win_is_valid(prev) then
      vim.api.nvim_set_current_win(prev) -- focus stays in the code window
    end
  end

  mdrender.apply(self.buf, mdrender.select(config.get().markdown_renderer))

  if config.get().float.hint then
    local hint = hint_text(view.keymaps)
    if hint then
      vim.wo[self.win].winbar = "%=" .. hint
    end
  end

  self:_set_maps(view)
end

function Split:focus()
  if self.win and vim.api.nvim_win_is_valid(self.win) then
    pcall(vim.api.nvim_set_current_win, self.win)
  end
end

function Split:follow_under_cursor()
  self:_follow(self._follow_dispatch)
end

function Split:close()
  if self.win and vim.api.nvim_win_is_valid(self.win) then
    pcall(vim.api.nvim_win_close, self.win, true)
  end
  if self.buf and vim.api.nvim_buf_is_valid(self.buf) then
    vim.api.nvim_buf_delete(self.buf, { force = true })
  end
  self.win, self.buf = nil, nil
end

return M
