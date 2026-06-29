local health = require("codetour.health")

-- A throwaway tour repo with one valid and one broken tour, outside this repo so
-- git-root resolution lands on it.
local function make_repo()
  local root = vim.fn.tempname()
  vim.fn.mkdir(root .. "/.tours", "p")
  vim.fn.writefile({
    '{ "title": "Good", "steps": [ { "description": "hi" } ] }',
  }, root .. "/.tours/good.tour")
  vim.fn.writefile({
    '{ "steps": [] }', -- no title, no valid steps -> broken
  }, root .. "/.tours/bad.tour")
  return root
end

local function levels(results)
  local out = {}
  for _, r in ipairs(results) do
    out[r.level] = (out[r.level] or 0) + 1
  end
  return out
end

local function find(results, needle)
  for _, r in ipairs(results) do
    if r.message:find(needle, 1, true) then
      return r
    end
  end
  return nil
end

describe("checkhealth codetour", function()
  it("collects a structured report of discovery, validation and integrations", function()
    local root = make_repo()
    local results = health.collect(root)

    assert.is_true(#results > 0)
    -- It found tours under the root.
    assert.is_not_nil(find(results, "discovered"))
    -- The broken tour is surfaced as a warning.
    local warn = find(results, "validation")
    assert.is_not_nil(warn)
    assert.equals("warn", warn.level)
  end)

  it("reports telescope integration status", function()
    local results = health.collect(make_repo())
    assert.is_not_nil(find(results, "telescope"))
  end)

  it("reports the active markdown renderer", function()
    local results = health.collect(make_repo())
    local md = find(results, "markdown renderer")
    assert.is_not_nil(md)
    -- Optional plugins absent on CI -> treesitter.
    assert.is_true(md.message:find("treesitter", 1, true) ~= nil)
  end)

  it("reports info (not error) when no tours are found", function()
    local empty = vim.fn.tempname()
    vim.fn.mkdir(empty, "p")
    local results = health.collect(empty)
    assert.is_not_nil(find(results, "no tours"))
    assert.is_nil(find(results, "validation"))
  end)

  it("runs :checkhealth codetour without error", function()
    assert.has_no.errors(function()
      vim.cmd("checkhealth codetour")
    end)
  end)

  it("never raises from collect even on a strange root", function()
    assert.has_no.errors(function()
      local _ = levels(health.collect("/nonexistent/path/xyz"))
    end)
  end)
end)
