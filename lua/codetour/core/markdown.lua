-- Parse a step description into renderable lines and a link map.
--
-- Skeleton scope (NCT-001): split into lines, no link extraction yet. The
-- step/tour/file link parsing that drives `<CR>`-follow lands in NCT-006.
--
-- parse(description) -> { lines = string[], links = table[] }

local M = {}

function M.parse(description)
  return {
    lines = vim.split(description or "", "\n", { plain = true }),
    links = {},
  }
end

return M
