-- Tier-2 JS -> Vim regex translation.
--
-- CodeTour `pattern` steps carry JavaScript-flavoured regexes. Neovim resolves
-- them with `vim.regex()`, which speaks Vim's regex dialect. This module bridges
-- the common subset and *gracefully falls back* on anything outside it, so a tour
-- with an exotic pattern degrades (the step is flagged unresolved upstream) rather
-- than crashing playback.
--
--   translate(js_pattern) -> vim_pattern        (translated, very-magic forced)
--                          | nil, reason         (untranslatable; caller degrades)
--
-- Strategy: force very-magic (`\v`) so the output reads close to the JS source,
-- then walk the pattern token by token. Supported subset:
--   - literals, `.`, `^`, `$`, `|`, `* + ?`, `{n,m}`
--   - groups: capturing `(...)`, non-capturing `(?:...)`
--   - lookaround: `(?=)`, `(?!)`, `(?<=)`, `(?<!)`  (reordered to Vim's postfix form)
--   - character classes `[...]` / `[^...]`, with `\d \w \s` mapped to POSIX classes
--   - shorthand escapes `\d \w \s \D \W \S` and escaped metacharacters
-- Anything else (word boundaries, backreferences, named/inline-flag groups, lazy
-- quantifiers, ...) returns nil + a human-readable reason.

local M = {}

-- Shorthand -> POSIX class body, used only *inside* a `[...]` where Vim does not
-- understand `\d` and friends. `\w` is alnum plus underscore.
local CLASS_POSIX = { d = "[:digit:]", w = "[:alnum:]_", s = "[:space:]" }

-- Literal in JS but special in Vim very-magic; escape so they match literally.
local VERYMAGIC_LITERAL = {
  ["@"] = true, ["%"] = true, ["&"] = true, ["="] = true,
  ["~"] = true, ["<"] = true, [">"] = true,
}

-- Read a `[...]` character class starting at `i` (which points at `[`).
-- Returns (translated_class, next_index) or (nil, reason).
local function read_class(js, i)
  local n = #js
  local j = i + 1
  local negate = false
  if js:sub(j, j) == "^" then
    negate = true
    j = j + 1
  end
  local body = {}
  local closed = false
  while j <= n do
    local c = js:sub(j, j)
    if c == "]" then
      closed = true
      j = j + 1
      break
    elseif c == "\\" then
      local nx = js:sub(j + 1, j + 1)
      if nx == "" then
        return nil, "unterminated character class"
      end
      if CLASS_POSIX[nx] then
        body[#body + 1] = CLASS_POSIX[nx]
      elseif nx == "D" or nx == "W" or nx == "S" or nx == "b" or nx == "B" then
        return nil, "escape \\" .. nx .. " inside [] unsupported"
      else
        body[#body + 1] = "\\" .. nx
      end
      j = j + 2
    else
      body[#body + 1] = c
      j = j + 1
    end
  end
  if not closed then
    return nil, "unterminated character class"
  end
  return "[" .. (negate and "^" or "") .. table.concat(body) .. "]", j
end

-- Read a `{...}` quantifier starting at `i` (which points at `{`).
-- Returns (translated, next_index) or (nil, reason).
local function read_brace(js, i)
  local close = js:find("}", i + 1, true)
  if not close then
    return nil, "unterminated { quantifier"
  end
  local body = js:sub(i + 1, close - 1)
  if not body:match("^%d*,?%d*$") or body == "" then
    return nil, "unsupported {} content '" .. body .. "'"
  end
  -- A trailing `?` makes the quantifier lazy, which Vim spells differently.
  if js:sub(close + 1, close + 1) == "?" then
    return nil, "lazy quantifier unsupported"
  end
  return "{" .. body .. "}", close + 1
end

function M.translate(js)
  if type(js) ~= "string" or js == "" then
    return nil, "empty or non-string pattern"
  end

  local out = { "\\v" } -- force very-magic
  local group_suffix = {} -- stack: suffix to append when the matching `)` closes
  local i, n = 1, #js

  while i <= n do
    local c = js:sub(i, i)

    if c == "\\" then
      local nx = js:sub(i + 1, i + 1)
      if nx == "" then
        return nil, "trailing backslash"
      elseif nx == "b" or nx == "B" then
        return nil, "word-boundary \\" .. nx .. " unsupported"
      elseif nx:match("%d") then
        return nil, "backreference \\" .. nx .. " unsupported"
      elseif nx == "p" or nx == "P" or nx == "u" or nx == "k" or nx == "x" then
        return nil, "escape \\" .. nx .. " unsupported"
      end
      -- \d \w \s \D \W \S \t \n ... and escaped metacharacters carry through.
      out[#out + 1] = "\\" .. nx
      i = i + 2

    elseif c == "[" then
      local class, ni = read_class(js, i)
      if not class then
        return nil, ni
      end
      out[#out + 1] = class
      i = ni

    elseif c == "(" then
      local rest3 = js:sub(i + 1, i + 3)
      local rest2 = js:sub(i + 1, i + 2)
      if rest3 == "?<=" then
        out[#out + 1] = "("
        group_suffix[#group_suffix + 1] = "@<="
        i = i + 4
      elseif rest3 == "?<!" then
        out[#out + 1] = "("
        group_suffix[#group_suffix + 1] = "@<!"
        i = i + 4
      elseif rest2 == "?:" then
        out[#out + 1] = "%("
        group_suffix[#group_suffix + 1] = ""
        i = i + 3
      elseif rest2 == "?=" then
        out[#out + 1] = "("
        group_suffix[#group_suffix + 1] = "@="
        i = i + 3
      elseif rest2 == "?!" then
        out[#out + 1] = "("
        group_suffix[#group_suffix + 1] = "@!"
        i = i + 3
      elseif js:sub(i + 1, i + 1) == "?" then
        -- (?<name>...), (?i), (?P=...) and friends.
        return nil, "unsupported group construct '(?...'"
      else
        out[#out + 1] = "("
        group_suffix[#group_suffix + 1] = ""
        i = i + 1
      end

    elseif c == ")" then
      if #group_suffix == 0 then
        return nil, "unbalanced ')'"
      end
      out[#out + 1] = ")" .. table.remove(group_suffix)
      i = i + 1

    elseif c == "{" then
      local brace, ni = read_brace(js, i)
      if not brace then
        return nil, ni
      end
      out[#out + 1] = brace
      i = ni

    elseif c == "*" or c == "+" then
      if js:sub(i + 1, i + 1) == "?" then
        return nil, "lazy quantifier unsupported"
      end
      out[#out + 1] = c
      i = i + 1

    elseif c == "?" then
      if js:sub(i + 1, i + 1) == "?" then
        return nil, "lazy quantifier unsupported"
      end
      out[#out + 1] = "?"
      i = i + 1

    elseif VERYMAGIC_LITERAL[c] then
      out[#out + 1] = "\\" .. c
      i = i + 1

    else
      -- `.` `^` `$` `|` letters, digits, and other ordinary characters whose
      -- very-magic meaning matches JS already.
      out[#out + 1] = c
      i = i + 1
    end
  end

  if #group_suffix > 0 then
    return nil, "unbalanced '('"
  end

  return table.concat(out)
end

return M
