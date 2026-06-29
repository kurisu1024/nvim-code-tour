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

local jsregex = require("codetour.core.jsregex")

local M = {}

-- Scan file_lines with a step's JS pattern (translated to a Vim regex); the
-- first matching 1-based line wins. Any failure to translate, compile, or match
-- degrades to an unresolved flag — never an error.
local function resolve_pattern(step, file_lines)
  local vim_pattern, reason = jsregex.translate(step.pattern)
  if not vim_pattern then
    return { kind = "unresolved", reason = "untranslatable pattern: " .. tostring(reason) }
  end
  if type(file_lines) ~= "table" or #file_lines == 0 then
    return { kind = "unresolved", reason = "no file content to scan for pattern" }
  end
  local ok, re = pcall(vim.regex, vim_pattern)
  if not ok or not re then
    return { kind = "unresolved", reason = "vim.regex rejected translated pattern" }
  end
  for idx, text in ipairs(file_lines) do
    local matched_ok, col = pcall(function()
      return re:match_str(text)
    end)
    if matched_ok and col ~= nil then
      return { kind = "line", line = idx } -- first match wins
    end
  end
  return { kind = "unresolved", reason = "pattern matched no line in file" }
end

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
    return resolve_pattern(step, file_lines)
  end

  -- A file step with neither line nor selection anchors at the top of the file.
  if step.file ~= nil then
    return { kind = "line", line = 1 }
  end

  return { kind = "content" }
end

return M
