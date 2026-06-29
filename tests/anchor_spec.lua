local anchor = require("codetour.core.anchor")
local model = require("codetour.core.model")

-- Normalize a single raw step through the model so anchor.resolve is exercised
-- against the same typed shape the player feeds it.
local function step_of(raw)
  return model.normalize({ title = "t", steps = { raw } }).steps[1]
end

describe("core.anchor.resolve", function()
  it("resolves a file+line step to its line", function()
    local r = anchor.resolve(step_of({ description = "d", file = "a.lua", line = 5 }))

    assert.equals("line", r.kind)
    assert.equals(5, r.line)
    assert.is_nil(r.selection)
  end)

  it("resolves a selection step to its range with the line at the selection start", function()
    local r = anchor.resolve(step_of({
      description = "d",
      file = "a.lua",
      selection = { start = { line = 3, character = 1 }, ["end"] = { line = 6, character = 4 } },
    }))

    assert.equals("selection", r.kind)
    assert.equals(3, r.line)
    assert.equals(3, r.selection.start.line)
    assert.equals(6, r.selection["end"].line)
  end)

  it("prefers the selection range over a bare line when both are present", function()
    local r = anchor.resolve(step_of({
      description = "d",
      file = "a.lua",
      line = 99,
      selection = { start = { line = 2, character = 1 }, ["end"] = { line = 4, character = 1 } },
    }))

    assert.equals("selection", r.kind)
    assert.equals(2, r.line)
  end)

  it("resolves a content step (no file) to no code location", function()
    local r = anchor.resolve(step_of({ description = "just prose" }))

    assert.equals("content", r.kind)
    assert.is_nil(r.line)
    assert.is_nil(r.selection)
  end)

  it("treats a file step with neither line nor selection as anchored at the top", function()
    local r = anchor.resolve(step_of({ description = "d", file = "a.lua" }))

    assert.equals("line", r.kind)
    assert.equals(1, r.line)
  end)

  it("is a pure function — no windows, buffers, or globals touched", function()
    -- A sanity guard: calling resolve must not create any nvim buffer.
    local before = #vim.api.nvim_list_bufs()
    anchor.resolve(step_of({ description = "d", file = "a.lua", line = 2 }))
    assert.equals(before, #vim.api.nvim_list_bufs())
  end)
end)

-- NCT-004 integration: pattern resolution via core/jsregex, in the kind shape.
describe("core.anchor.resolve pattern steps", function()
  local lines = { "local M = {}", "function M.greet()", "  return 'hi'", "end" }

  it("resolves a pattern step to the first matching line", function()
    local r = anchor.resolve(step_of({ description = "d", file = "a.lua", pattern = "function" }), lines)
    assert.equals("line", r.kind)
    assert.equals(2, r.line)
  end)

  it("first match wins for a pattern that occurs more than once", function()
    local r = anchor.resolve(step_of({ description = "d", file = "a.lua", pattern = "M|return" }), lines)
    assert.equals("line", r.kind)
    assert.equals(1, r.line)
  end)

  it("honors line > pattern precedence", function()
    local r = anchor.resolve(step_of({ description = "d", file = "a.lua", line = 3, pattern = "function" }), lines)
    assert.equals("line", r.kind)
    assert.equals(3, r.line)
  end)

  it("degrades an untranslatable pattern to unresolved, never crashing", function()
    local r = anchor.resolve(step_of({ description = "d", file = "a.lua", pattern = "\\bword\\b" }), { "a word" })
    assert.equals("unresolved", r.kind)
    assert.is_string(r.reason)
  end)

  it("degrades a non-matching pattern to unresolved", function()
    local r = anchor.resolve(step_of({ description = "d", file = "a.lua", pattern = "zzz" }), lines)
    assert.equals("unresolved", r.kind)
  end)

  it("degrades to unresolved when no file lines are available to scan", function()
    local r = anchor.resolve(step_of({ description = "d", file = "a.lua", pattern = "function" }))
    assert.equals("unresolved", r.kind)
  end)
end)
