local model = require("codetour.core.model")

describe("core.model.normalize", function()
  it("returns a Tour with normalized steps for a valid file+line tour", function()
    local tour, err = model.normalize({
      title = "Intro",
      description = "a walkthrough",
      steps = {
        { description = "open here", file = "lua/a.lua", line = 10, title = "Step A" },
      },
    })

    assert.is_nil(err)
    assert.equals("Intro", tour.title)
    assert.equals("a walkthrough", tour.description)
    assert.equals(1, #tour.steps)

    local step = tour.steps[1]
    assert.equals("file", step.type)
    assert.equals("lua/a.lua", step.file)
    assert.equals(10, step.line)
    assert.equals("open here", step.description)
    assert.equals("Step A", step.title)
  end)

  it("classifies a step with no anchor as a content step", function()
    local tour = model.normalize({
      title = "T",
      steps = { { description = "just prose" } },
    })

    assert.equals("content", tour.steps[1].type)
  end)

  it("applies directory-over-file precedence", function()
    local tour = model.normalize({
      title = "T",
      steps = { { description = "d", directory = "src", file = "src/a.lua" } },
    })

    assert.equals("directory", tour.steps[1].type)
  end)

  it("returns nil and an error list for a fatally invalid tour", function()
    local tour, err = model.normalize({ steps = {} })

    assert.is_nil(tour)
    assert.is_table(err)
    assert.is_true(#err > 0)
  end)

  it("carries skipped-step records onto the tour", function()
    local tour = model.normalize({
      title = "T",
      steps = {
        { description = "ok", file = "a.lua", line = 1 },
        { file = "b.lua" }, -- skipped
      },
    })

    assert.equals(1, #tour.steps)
    assert.equals(1, #tour.skipped)
  end)
end)
