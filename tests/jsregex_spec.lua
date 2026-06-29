-- Tier-2 JS -> Vim regex translation (core/jsregex).
--
-- Pure-core spec: the translator never opens a window. We validate behaviour
-- end to end -- translate the JS pattern, compile the result with vim.regex,
-- and assert it matches (or does not match) the sample text. A separate table
-- pins the graceful-fallback cases (translate returns nil + a reason).

local jsregex = require("codetour.core.jsregex")

-- Compile a JS pattern through the translator and test it against `text`.
-- Returns true/false for a match; fails the test if the pattern was deemed
-- untranslatable (use the fallback table for those).
local function matches(js, text)
  local vim_pattern, reason = jsregex.translate(js)
  assert.is_not_nil(vim_pattern, "expected '" .. js .. "' to translate, got fallback: " .. tostring(reason))
  local ok, re = pcall(vim.regex, vim_pattern)
  assert.is_true(ok, "vim.regex rejected translated pattern for '" .. js .. "' -> '" .. tostring(vim_pattern) .. "'")
  return re:match_str(text) ~= nil
end

describe("core.jsregex.translate supported subset", function()
  -- (name, js_pattern, text, should_match)
  local fixtures = {
    { "literal text", "foo", "a foo b", true },
    { "literal non-match", "foo", "a bar b", false },
    { "dot wildcard", "f.o", "fxo", true },
    { "dot requires a char", "f.o", "fo", false },
    { "anchored start/end match", "^foo$", "foo", true },
    { "anchored start/end non-match", "^foo$", "foox", false },
    { "alternation", "cat|dog", "a dog here", true },
    { "char class member", "[abc]+", "zzcabzz", true },
    { "negated char class", "[^0-9]+", "abc", true },
    { "negated char class excludes", "[^0-9]", "5", false },
    { "digit shorthand", "\\d+", "x42y", true },
    { "digit shorthand non-match", "\\d", "abc", false },
    { "word shorthand", "\\w+", "hello", true },
    { "space shorthand", "a\\sb", "a b", true },
    { "shorthand inside class", "[\\dA-F]+", "9F", true },
    { "shorthand inside class excludes", "[\\d]", "z", false },
    { "bounded quantifier matches", "a{2,3}", "baaab", true },
    { "bounded quantifier too few", "a{2,3}", "bab", false },
    { "non-capturing group repeat", "(?:ab)+", "abab", true },
    { "non-capturing group repeat non-match", "(?:ab)+", "axb", false },
    { "non-capturing alternation", "(?:cat|dog)s", "two dogs", true },
    { "lookahead positive", "foo(?=bar)", "foobar", true },
    { "lookahead positive blocks", "foo(?=bar)", "foobaz", false },
    { "lookahead negative", "foo(?!bar)", "foobaz", true },
    { "lookahead negative blocks", "foo(?!bar)", "foobar", false },
    { "lookbehind positive", "(?<=\\$)\\d+", "price $50", true },
    { "lookbehind positive blocks", "(?<=\\$)\\d", "5", false },
    { "lookbehind negative", "(?<!\\$)\\d", "a5", true },
    { "lookbehind negative blocks", "(?<!\\$)\\d", "$5", false },
    { "escaped dot is literal", "a\\.b", "a.b", true },
    { "escaped dot rejects wildcard", "a\\.b", "axb", false },
    { "very-magic literal equals", "a=b", "a=b", true },
    { "very-magic literal equals rejects", "a=b", "ab", false },
    { "very-magic literal at", "a@b", "a@b", true },
    { "very-magic literal angle", "a<b", "a<b", true },
  }

  for _, fx in ipairs(fixtures) do
    local name, js, text, expected = fx[1], fx[2], fx[3], fx[4]
    it(name, function()
      assert.equals(expected, matches(js, text))
    end)
  end
end)

describe("core.jsregex.translate graceful fallback", function()
  -- Constructs outside the Tier-2 subset must return (nil, reason), never throw.
  local fallbacks = {
    { "empty pattern", "" },
    { "word boundary \\b", "\\bword\\b" },
    { "non-word boundary \\B", "a\\Bb" },
    { "backreference", "(a)\\1" },
    { "named capture group", "(?<name>a)" },
    { "inline flag group", "(?i)abc" },
    { "lazy star quantifier", "a*?" },
    { "lazy plus quantifier", "a+?" },
    { "trailing backslash", "abc\\" },
  }

  for _, fb in ipairs(fallbacks) do
    local name, js = fb[1], fb[2]
    it("falls back on " .. name, function()
      local vim_pattern, reason = jsregex.translate(js)
      assert.is_nil(vim_pattern)
      assert.is_string(reason)
    end)
  end

  it("never raises on untranslatable input", function()
    assert.has_no.errors(function()
      jsregex.translate("\\bxyz\\b")
      jsregex.translate("(?<n>a)\\1")
    end)
  end)
end)
