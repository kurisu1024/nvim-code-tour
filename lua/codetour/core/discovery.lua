-- Find `.tour` files under a workspace root.
--
-- Skeleton scope (NCT-001): scan the conventional CodeTour locations and the
-- repo root for `*.tour` files and return their paths. The richer engine
-- (git-root resolution, a configured extra dir, per-tour metadata, broken-file
-- flagging) lands in NCT-002 — this is intentionally the thin version.
--
-- find(root) -> { { path = absolute_path }, ... }   (sorted, de-duplicated)

local M = {}

-- Conventional tour locations, scanned recursively, plus root-level files.
local TOUR_DIRS = { ".tours", ".vscode/tours", ".github/tours" }

local function glob(pattern)
  return vim.fn.glob(pattern, true, true)
end

function M.find(root)
  root = vim.fn.fnamemodify(root, ":p"):gsub("/$", "")

  local seen = {}
  local paths = {}
  local function add(path)
    if not seen[path] then
      seen[path] = true
      table.insert(paths, path)
    end
  end

  for _, dir in ipairs(TOUR_DIRS) do
    for _, path in ipairs(glob(root .. "/" .. dir .. "/**/*.tour")) do
      add(path)
    end
  end
  for _, path in ipairs(glob(root .. "/*.tour")) do
    add(path)
  end

  table.sort(paths)
  return vim.tbl_map(function(p)
    return { path = p }
  end, paths)
end

return M
