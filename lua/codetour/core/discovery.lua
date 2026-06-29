-- Find `.tour` files under a workspace root and surface lightweight metadata.
--
-- Engine scope (NCT-002): resolve the workspace root (git-root then cwd), scan
-- every conventional CodeTour location (`.tours/`, `.vscode/tours/`,
-- `.github/tours/`, all nested), the repo root (`main.tour` / `.tour` / any
-- `*.tour`), and a configurable extra dir. For each tour return *metadata only*
-- — title, step count, primary flag, source path — without fully loading and
-- normalizing the tour. Resilient by construction: a file that can't be read,
-- parsed, or that lacks a title/steps is skipped, never fatal.
--
-- find(root, opts?) -> { { path, title, step_count, is_primary }, ... }
--   opts.tour_dir : an extra directory (absolute, or relative to root) to scan.
-- resolve_root(start?) -> absolute workspace root (git root, else cwd).

local json = require("codetour.core.json")
local schema = require("codetour.core.schema")

local M = {}

-- Conventional tour locations, scanned recursively, plus root-level files.
local TOUR_DIRS = { ".tours", ".vscode/tours", ".github/tours" }

-- A title flags the codebase's primary tour when it begins with the "1 - …"
-- ordering convention (optional leading '#', surrounding whitespace tolerated).
local PRIMARY_TITLE = "^#?%s*1%s*%-"

local function normalize_dir(path)
  return (vim.fn.fnamemodify(path, ":p"):gsub("/$", ""))
end

-- Resolve the workspace root: the git root (the dir containing `.git`) when one
-- is found by walking up from `start`, otherwise the current working directory.
function M.resolve_root(start)
  start = (start ~= nil and start ~= "") and start or vim.fn.getcwd()
  return vim.fs.root(start, ".git") or vim.fn.getcwd()
end

local function glob(pattern)
  return vim.fn.glob(pattern, true, true)
end

local function is_primary_title(title)
  return title:match(PRIMARY_TITLE) ~= nil
end

-- Peek at a tour file's metadata without normalizing it.
--
-- Resilience posture (NCT-008): a file that is unreadable or not valid JSON has
-- no recoverable identity, so it is skipped (returns nil). A file that *is*
-- parseable JSON but structurally invalid (no title, no steps, or no valid
-- steps) is NOT hidden — it surfaces flagged `broken = true` (with a filename
-- fallback for a missing title) so the picker can list it rather than silently
-- dropping it. `step_count` reflects the count of *valid* steps.
local function read_meta(path)
  local ok_read, lines = pcall(vim.fn.readfile, path)
  if not ok_read then
    return nil
  end

  local ok, raw = json.decode(table.concat(lines, "\n"))
  if not ok or type(raw) ~= "table" then
    return nil
  end

  local result = schema.validate(raw)
  local broken = #result.errors > 0

  local title = raw.title
  if type(title) ~= "string" or title == "" then
    -- No usable title: fall back to the file stem so the broken tour still has
    -- a stable display identity in the list.
    title = vim.fn.fnamemodify(path, ":t:r")
  end

  return {
    path = path,
    title = title,
    step_count = #result.valid_steps,
    is_primary = raw.isPrimary == true or is_primary_title(title),
    broken = broken,
  }
end

function M.find(root, opts)
  opts = opts or {}
  root = normalize_dir(root or M.resolve_root())

  local seen = {}
  local paths = {}
  local function add(path)
    if not seen[path] then
      seen[path] = true
      table.insert(paths, path)
    end
  end

  -- Conventional directories (recursive).
  for _, dir in ipairs(TOUR_DIRS) do
    for _, path in ipairs(glob(root .. "/" .. dir .. "/**/*.tour")) do
      add(path)
    end
  end

  -- Root-level tours: `main.tour`, any other `*.tour`, and a literal `.tour`
  -- dotfile (which `*` does not match).
  for _, path in ipairs(glob(root .. "/*.tour")) do
    add(path)
  end
  local dot_tour = root .. "/.tour"
  if vim.fn.filereadable(dot_tour) == 1 then
    add(dot_tour)
  end

  -- Configured extra directory (recursive); relative paths resolve against root.
  if type(opts.tour_dir) == "string" and opts.tour_dir ~= "" then
    local extra = opts.tour_dir
    if not vim.startswith(extra, "/") then
      extra = root .. "/" .. extra
    end
    extra = normalize_dir(extra)
    for _, path in ipairs(glob(extra .. "/**/*.tour")) do
      add(path)
    end
  end

  table.sort(paths)

  local tours = {}
  for _, path in ipairs(paths) do
    local meta = read_meta(path)
    if meta then
      table.insert(tours, meta)
    end
  end
  return tours
end

return M
