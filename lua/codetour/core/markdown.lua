-- Parse a step description into renderable lines and a link map.
--
-- A description is split into render lines verbatim, and its CodeTour link
-- syntax is extracted into a link map that drives `<CR>`-follow in the narrator:
--
--   step ref   [#3]            -> { kind = "step", step = 3 }
--   tour ref   [Title]         -> { kind = "tour", title = "Title" }
--   tour+step  [Title#2]       -> { kind = "tour", title = "Title", step = 2 }
--   file ref   [label](path)   -> { kind = "file", path = path }
--
-- Each link carries the 1-based render line it sits on and the 1-based inclusive
-- byte span of its source token (`from`..`to`), so the UI can hit-test the link
-- under the cursor without re-parsing.
--
-- Safety: `command:` link targets are rendered inert (no actionable link) — the
-- engine never executes anything on the user's behalf. The parser is pure (no
-- nvim UI), so it is exercised directly in markdown_spec.
--
-- parse(description) -> { lines = string[], links = Link[] }
--   Link = { line, from, to, action = { kind, step? | title?,step? | path? } }

local M = {}

-- Strip leading/trailing ASCII whitespace.
local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Classify the inner text of a `[...]` token (not a file link) into an action,
-- or nil when it isn't a recognizable ref.
local function classify_ref(inner)
  local text = trim(inner)
  if text == "" then
    return nil
  end

  -- Step ref: `#<digits>` only.
  local step = text:match("^#(%d+)$")
  if step then
    return { kind = "step", step = tonumber(step) }
  end

  -- Tour+step ref: `Title#<digits>` (lazy title so the trailing #n binds last).
  local title, tstep = text:match("^(.-)#(%d+)$")
  if title and trim(title) ~= "" then
    return { kind = "tour", title = trim(title), step = tonumber(tstep) }
  end

  -- Bare tour ref: `[Title]`.
  return { kind = "tour", title = text }
end

-- A `command:` target acts on the machine; render it inert (no link).
local function is_inert_target(path)
  return path:lower():match("^%s*command:") ~= nil
end

-- Extract every link on one render line, in source order, appending to `links`.
local function parse_line(text, lineno, links)
  local i, n = 1, #text
  while i <= n do
    local s, e = text:find("%b[]", i)
    if not s then
      break
    end
    local inner = text:sub(s + 1, e - 1)

    if text:sub(e + 1, e + 1) == "(" then
      -- File ref: `[label](target)`.
      local ps, pe = text:find("%b()", e + 1)
      if ps == e + 1 then
        local path = text:sub(ps + 1, pe - 1)
        if path ~= "" and not is_inert_target(path) then
          links[#links + 1] = {
            line = lineno,
            from = s,
            to = pe,
            action = { kind = "file", path = path },
          }
        end
        i = pe + 1
      else
        i = e + 1
      end
    else
      -- Step or tour ref: `[...]` not followed by `(`.
      local action = classify_ref(inner)
      if action then
        links[#links + 1] = { line = lineno, from = s, to = e, action = action }
      end
      i = e + 1
    end
  end
end

function M.parse(description)
  local lines = vim.split(description or "", "\n", { plain = true })
  local links = {}
  for idx, line in ipairs(lines) do
    parse_line(line, idx, links)
  end
  return { lines = lines, links = links }
end

return M
