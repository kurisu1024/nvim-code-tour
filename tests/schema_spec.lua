local schema = require("codetour.core.schema")

describe("core.schema.validate", function()
  it("accepts a minimal valid tour and returns its steps", function()
    local result = schema.validate({
      title = "My Tour",
      steps = {
        { description = "first", file = "a.lua", line = 1 },
        { description = "second", file = "b.lua", line = 2 },
      },
    })

    assert.same({}, result.errors)
    assert.equals(2, #result.valid_steps)
    assert.same({}, result.skipped)
  end)

  it("rejects a non-table input as a fatal tour error", function()
    local result = schema.validate("not a tour")

    assert.is_true(#result.errors > 0)
    assert.same({}, result.valid_steps)
  end)

  it("treats a missing title as a fatal tour error", function()
    local result = schema.validate({ steps = { { description = "x" } } })

    assert.is_true(#result.errors > 0)
  end)

  it("treats missing steps as a fatal tour error", function()
    local result = schema.validate({ title = "T" })

    assert.is_true(#result.errors > 0)
  end)

  it("skips a step with no description but keeps the valid ones", function()
    local result = schema.validate({
      title = "T",
      steps = {
        { description = "good", file = "a.lua", line = 1 },
        { file = "b.lua", line = 2 }, -- no description -> skipped
        { description = "also good", file = "c.lua", line = 3 },
      },
    })

    assert.same({}, result.errors)
    assert.equals(2, #result.valid_steps)
    assert.equals(1, #result.skipped)
    assert.equals(2, result.skipped[1].index)
    assert.is_string(result.skipped[1].reason)
  end)
end)
