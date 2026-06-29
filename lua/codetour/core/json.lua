-- Decode `.tour` text. Thin wrapper over vim.json that never throws — a
-- malformed tour must degrade to a notice, not crash discovery.
--
-- decode(text) -> (true, value) | (false, message)

local M = {}

function M.decode(text)
  local ok, value = pcall(vim.json.decode, text)
  if not ok then
    return false, tostring(value)
  end
  return true, value
end

return M
