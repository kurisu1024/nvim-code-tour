-- Extmark highlight of the anchored line in the code window.
--
-- The namespace is created with the name "codetour" so it is discoverable via
-- nvim_get_namespaces() (used by tests and :checkhealth).

local M = {}

M.ns = vim.api.nvim_create_namespace("codetour")

local hl_defined = false
local function ensure_hl()
  if not hl_defined then
    vim.api.nvim_set_hl(0, "CodeTourLine", { link = "Visual", default = true })
    hl_defined = true
  end
end

-- Highlight a 1-based line in `buf`. Clamps to the buffer's bounds.
function M.apply(buf, line)
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    return
  end
  ensure_hl()
  local count = vim.api.nvim_buf_line_count(buf)
  local row = math.max(0, math.min(line or 1, count) - 1)
  return vim.api.nvim_buf_set_extmark(buf, M.ns, row, 0, {
    line_hl_group = "CodeTourLine",
  })
end

-- Highlight a multi-line selection range in `buf`. `selection` is the CodeTour
-- shape: { start = { line, character }, ["end"] = { line, character } }, all
-- 1-based. The range is clamped to the buffer's bounds and rendered as a single
-- region extmark from the start position through the end position, so the whole
-- start→end span is highlighted (not just the first line).
function M.apply_selection(buf, selection)
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    return
  end
  if type(selection) ~= "table" or type(selection.start) ~= "table" or type(selection["end"]) ~= "table" then
    return
  end
  ensure_hl()
  local count = vim.api.nvim_buf_line_count(buf)
  local function clamp_row(line)
    return math.max(0, math.min((line or 1) - 1, count - 1))
  end
  local start_row = clamp_row(selection.start.line)
  local end_row = clamp_row(selection["end"].line)
  if end_row < start_row then
    start_row, end_row = end_row, start_row
  end
  local start_col = math.max(0, (selection.start.character or 1) - 1)
  -- Highlight through the end of the last selected line so the full multi-line
  -- span reads as one block, not just the first line.
  local end_col = #(vim.api.nvim_buf_get_lines(buf, end_row, end_row + 1, false)[1] or "")
  return vim.api.nvim_buf_set_extmark(buf, M.ns, start_row, start_col, {
    end_row = end_row,
    end_col = end_col,
    hl_group = "CodeTourLine",
  })
end

function M.clear(buf)
  if buf and vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_clear_namespace(buf, M.ns, 0, -1)
  end
end

return M
