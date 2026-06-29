local markdown = require("codetour.core.markdown")

-- The link parser is a pure function: description text in, render lines + a link
-- map out. Each link records the rendered line it sits on, the 1-based inclusive
-- byte span of its source token, and a structured action.
local function only_link(desc)
  local parsed = markdown.parse(desc)
  assert.equals(1, #parsed.links, "expected exactly one link in: " .. desc)
  return parsed.links[1]
end

describe("core.markdown.parse", function()
  it("splits the description into render lines (unchanged text)", function()
    local parsed = markdown.parse("first line\nsecond line")
    assert.same({ "first line", "second line" }, parsed.lines)
  end)

  it("returns an empty link map for plain prose", function()
    local parsed = markdown.parse("just some **bold** prose, no links")
    assert.same({}, parsed.links)
  end)

  it("handles nil/empty descriptions without error", function()
    assert.same({ "" }, markdown.parse(nil).lines)
    assert.same({}, markdown.parse(nil).links)
  end)

  it("parses a step ref [#n] into a step action", function()
    local link = only_link("See [#3] for the detail.")
    assert.same({ kind = "step", step = 3 }, link.action)
    assert.equals(1, link.line)
    -- "See [#3]" — '[' is the 5th byte, ']' the 8th.
    assert.equals(5, link.from)
    assert.equals(8, link.to)
  end)

  it("parses a bare tour ref [Title] into a tour action with no step", function()
    local link = only_link("Continue with [Deployment Tour].")
    assert.same({ kind = "tour", title = "Deployment Tour" }, link.action)
  end)

  it("parses a tour-and-step ref [Title#n] into a tour action with a step", function()
    local link = only_link("Jump to [Deployment Tour#4] now.")
    assert.same({ kind = "tour", title = "Deployment Tour", step = 4 }, link.action)
  end)

  it("trims surrounding whitespace from a tour title", function()
    local link = only_link("Go to [  Setup  #2 ].")
    assert.same({ kind = "tour", title = "Setup", step = 2 }, link.action)
  end)

  it("parses a file ref [label](path) into a file action", function()
    local link = only_link("Open [the config](./src/config.lua) please.")
    assert.same({ kind = "file", path = "./src/config.lua" }, link.action)
    -- span covers '[' through the closing ')'.
    assert.equals(6, link.from)
    assert.equals(35, link.to)
  end)

  it("tracks the line a link sits on across multiple lines", function()
    local parsed = markdown.parse("intro\nthen [#2] follows\nend")
    assert.equals(1, #parsed.links)
    assert.equals(2, parsed.links[1].line)
  end)

  it("collects multiple links on one line in source order", function()
    local parsed = markdown.parse("from [#1] to [Other Tour] to [x](p.lua)")
    assert.equals(3, #parsed.links)
    assert.equals("step", parsed.links[1].action.kind)
    assert.equals("tour", parsed.links[2].action.kind)
    assert.equals("file", parsed.links[3].action.kind)
  end)

  it("renders command: links inert (no actionable link)", function()
    local parsed = markdown.parse("Run [danger](command:workbench.action.terminal.new)")
    assert.same({}, parsed.links)
  end)

  it("ignores empty brackets and empty link targets", function()
    assert.same({}, markdown.parse("an empty [] bracket").links)
    assert.same({}, markdown.parse("empty target [x]()").links)
  end)
end)
