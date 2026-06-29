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

function M.clear(buf)
  if buf and vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_clear_namespace(buf, M.ns, 0, -1)
  end
end

return M
