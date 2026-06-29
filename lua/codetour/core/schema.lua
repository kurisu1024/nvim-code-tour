-- Lenient structural validation of a decoded `.tour` table.
--
-- Posture (from the design): best-effort. A tour with no title or no steps is
-- fatally invalid (the file gets skipped during discovery). Individual steps
-- that lack a required field are dropped but never sink the whole tour.
--
-- validate(raw) -> {
--   errors      = string[],   -- tour-level fatal problems (non-empty => unplayable)
--   valid_steps = table[],    -- raw step tables that passed
--   skipped     = { { index = number, reason = string }, ... },
-- }

local M = {}

local function is_nonempty_string(v)
  return type(v) == "string" and v ~= ""
end

function M.validate(raw)
  local errors = {}
  local valid_steps = {}
  local skipped = {}

  if type(raw) ~= "table" then
    table.insert(errors, "tour must be a JSON object")
    return { errors = errors, valid_steps = valid_steps, skipped = skipped }
  end

  if not is_nonempty_string(raw.title) then
    table.insert(errors, "tour is missing a non-empty 'title'")
  end

  if type(raw.steps) ~= "table" or vim.tbl_isempty(raw.steps) then
    table.insert(errors, "tour is missing a non-empty 'steps' array")
    return { errors = errors, valid_steps = valid_steps, skipped = skipped }
  end

  for index, step in ipairs(raw.steps) do
    if type(step) ~= "table" then
      table.insert(skipped, { index = index, reason = "step is not an object" })
    elseif not is_nonempty_string(step.description) then
      table.insert(skipped, { index = index, reason = "step is missing a 'description'" })
    else
      table.insert(valid_steps, step)
    end
  end

  return { errors = errors, valid_steps = valid_steps, skipped = skipped }
end

return M
