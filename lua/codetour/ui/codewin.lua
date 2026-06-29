-- Open a step's file in a usable code window and move the cursor to the anchor.
--
-- Window safety lives here: the narrator float is focusable, so a naive "edit in
-- the current/given window" can `:edit` the source file *into the float* (or into
-- a terminal/quickfix window), destroying it. open() therefore resolves a normal,
-- non-floating window — preferring the one the player hands it — and never edits
-- a special window. Path resolution is root-relative (step.file is relative to
-- the workspace root per the CodeTour spec).

local M = {}

-- A window we may safely `:edit` into: valid, non-floating, ordinary buffer.
local function is_usable(win)
  if not (win and vim.api.nvim_win_is_valid(win)) then
    return false
  end
  if vim.api.nvim_win_get_config(win).relative ~= "" then
    return false -- floating window (e.g. the narrator)
  end
  local buftype = vim.bo[vim.api.nvim_win_get_buf(win)].buftype
  return buftype == "" or buftype == "acwrite"
end

local function pick_win(preferred)
  if is_usable(preferred) then
    return preferred
  end
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if is_usable(win) then
      return win
    end
  end
  return nil
end

-- open(preferred_win, root, file, line, col?) -> (bufnr, win) | (nil, nil)
-- Returns nil,nil when no safe window exists; the caller then narrates only.
-- `col` is an optional 0-based column for the cursor (selection steps land the
-- cursor on the selection's start character); it defaults to the start of line.
function M.open(preferred_win, root, file, line, col)
  local win = pick_win(preferred_win)
  if not win then
    return nil, nil
  end

  local path = file
  if root and not vim.startswith(file, "/") then
    path = root .. "/" .. file
  end
  path = vim.fn.fnamemodify(path, ":p")

  vim.api.nvim_set_current_win(win)
  local edit_ok = pcall(vim.cmd.edit, vim.fn.fnameescape(path))
  if not edit_ok then
    return nil, win
  end

  local buf = vim.api.nvim_win_get_buf(win)
  local count = vim.api.nvim_buf_line_count(buf)
  local target = math.max(1, math.min(line or 1, count))
  -- Clamp the column to the target line so a selection's start character can't
  -- push the cursor past the line's end.
  local line_text = vim.api.nvim_buf_get_lines(buf, target - 1, target, false)[1] or ""
  local target_col = math.max(0, math.min(col or 0, #line_text))
  -- Set the cursor on the explicit win: autocommands fired by :edit may have
  -- shifted the current window out from under us.
  vim.api.nvim_win_set_cursor(win, { target, target_col })
  return buf, win
end

return M
