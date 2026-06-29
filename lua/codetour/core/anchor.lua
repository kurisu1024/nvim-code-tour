-- Pure resolution of a normalized Step to a concrete code location.
--
-- This is the headless seam between the typed Step model and the UI: given a
-- step (and, later, the file's lines for pattern scanning), it yields where the
-- code window should land and what should be highlighted — without ever opening
-- a window or buffer. The player consumes the result and drives the UI adapters.
--
-- resolve(step, file_lines?) -> resolution
--   line       -> { kind = "line",      line = n }
--   selection  -> { kind = "selection", line = startLine, selection = { start, end } }
--   content    -> { kind = "content" }                 -- no code location
--   unresolved -> { kind = "unresolved", reason = ... } -- e.g. pattern (NCT-004)
--
-- Precedence (from the design): a present `selection` range wins over a bare
-- `line`; a `line` wins over a `pattern`. Pattern scanning itself is owned by
-- NCT-004 and slots into the `pattern` branch here; until then a pattern-only
-- step degrades to `unresolved` rather than crashing playback.

local M = {}

-- A selection is usable only if it carries both endpoints with line numbers.
local function has_range(selection)
  return type(selection) == "table"
    and type(selection.start) == "table"
    and type(selection["end"]) == "table"
    and selection.start.line ~= nil
    and selection["end"].line ~= nil
end

-- resolve(step, file_lines?) — file_lines is unused today; it is the seam for
-- pattern scanning (NCT-004) and is accepted now so the signature stays stable.
function M.resolve(step, file_lines) -- luacheck: ignore file_lines
  if type(step) ~= "table" then
    return { kind = "content" }
  end

  if step.type == "content" then
    return { kind = "content" }
  end

  if has_range(step.selection) then
    return {
      kind = "selection",
      line = step.selection.start.line,
      selection = { start = step.selection.start, ["end"] = step.selection["end"] },
    }
  end

  if step.line ~= nil then
    return { kind = "line", line = step.line }
  end

  if step.pattern ~= nil then
    -- Pattern resolution arrives in NCT-004; degrade gracefully for now.
    return { kind = "unresolved", reason = "pattern resolution not available" }
  end

  -- A file step with neither line nor selection anchors at the top of the file.
  if step.file ~= nil then
    return { kind = "line", line = 1 }
  end

  return { kind = "content" }
end

return M
