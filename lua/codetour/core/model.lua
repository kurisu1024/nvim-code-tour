-- Normalize a decoded `.tour` table into a Tour with typed Steps.
--
-- Applies anchor precedence (directory > file > uri > content) and copies the
-- consumed fields onto a stable internal shape so the rest of the engine never
-- touches raw JSON again.
--
-- normalize(raw) -> Tour | (nil, errors[])
--
-- Tour  = { title, description?, ref?, nextTour?, steps = Step[], skipped[] }
-- Step  = { type, description, title?, file?, line?, pattern?, directory?,
--           uri?, selection? }

local schema = require("codetour.core.schema")

local M = {}

-- JSON null decodes to vim.NIL (a truthy userdata), which slips through Lua nil
-- guards and then crashes downstream string/number ops. Strip it at the
-- normalize boundary so the rest of the engine only ever sees real values or nil.
local function denil(v)
  if v == nil or v == vim.NIL then
    return nil
  end
  return v
end

-- Resolve a step's anchor kind from already-cleaned values. Precedence is fixed
-- so a step with both a directory and a file is treated as directory-anchored.
local function step_type(file, directory, uri)
  if directory ~= nil then
    return "directory"
  elseif file ~= nil then
    return "file"
  elseif uri ~= nil then
    return "uri"
  end
  return "content"
end

local function normalize_step(raw)
  local file = denil(raw.file)
  local directory = denil(raw.directory)
  local uri = denil(raw.uri)
  return {
    type = step_type(file, directory, uri),
    description = raw.description,
    title = denil(raw.title),
    file = file,
    line = denil(raw.line),
    pattern = denil(raw.pattern),
    directory = directory,
    uri = uri,
    selection = denil(raw.selection),
    -- Carried through for graceful degradation (NCT-008): no `view` is supported
    -- in the MVP, so a view-anchored step degrades to narrating its description.
    view = denil(raw.view),
  }
end

function M.normalize(raw)
  local result = schema.validate(raw)
  if #result.errors > 0 then
    return nil, result.errors
  end

  local steps = {}
  for _, raw_step in ipairs(result.valid_steps) do
    table.insert(steps, normalize_step(raw_step))
  end

  return {
    title = raw.title,
    description = denil(raw.description),
    ref = denil(raw.ref),
    nextTour = denil(raw.nextTour),
    steps = steps,
    skipped = result.skipped,
  }
end

return M
