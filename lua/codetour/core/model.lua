-- Normalize a decoded `.tour` table into a Tour with typed Steps.
--
-- Applies anchor precedence (directory > file > uri > content) and copies the
-- consumed fields onto a stable internal shape so the rest of the engine never
-- touches raw JSON again.
--
-- normalize(raw) -> Tour | (nil, errors[])
--
-- Tour  = { title, description?, ref?, steps = Step[], skipped[] }
-- Step  = { type, description, title?, file?, line?, pattern?, directory?,
--           uri?, selection? }

local schema = require("codetour.core.schema")

local M = {}

-- Resolve a step's anchor kind. Precedence is fixed so a step with both a
-- directory and a file is treated as directory-anchored, etc.
local function step_type(raw)
  if raw.directory ~= nil then
    return "directory"
  elseif raw.file ~= nil then
    return "file"
  elseif raw.uri ~= nil then
    return "uri"
  end
  return "content"
end

local function normalize_step(raw)
  return {
    type = step_type(raw),
    description = raw.description,
    title = raw.title,
    file = raw.file,
    line = raw.line,
    pattern = raw.pattern,
    directory = raw.directory,
    uri = raw.uri,
    selection = raw.selection,
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
    description = raw.description,
    ref = raw.ref,
    steps = steps,
    skipped = result.skipped,
  }
end

return M
