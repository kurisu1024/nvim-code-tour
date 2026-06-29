-- Open a step's file in the code window and move the cursor to the anchor.
--
-- Pure-ish UI seam: it only touches the given window + the editing buffer, never
-- the narrator float. Path resolution is root-relative (step.file is relative to
-- the workspace root per the CodeTour spec).

local M = {}

-- open(win, root, file, line) -> bufnr
function M.open(win, root, file, line)
  local path = file
  if root and not vim.startswith(file, "/") then
    path = root .. "/" .. file
  end
  path = vim.fn.fnamemodify(path, ":p")

  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_set_current_win(win)
  end
  vim.cmd.edit(vim.fn.fnameescape(path))

  local buf = vim.api.nvim_get_current_buf()
  local count = vim.api.nvim_buf_line_count(buf)
  local target = math.max(1, math.min(line or 1, count))
  vim.api.nvim_win_set_cursor(0, { target, 0 })
  return buf
end

return M
