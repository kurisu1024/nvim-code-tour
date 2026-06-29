local discovery = require("codetour.core.discovery")

-- Resolve tests/fixtures/repo relative to this spec file.
local here = debug.getinfo(1, "S").source:sub(2)
local fixtures = vim.fn.fnamemodify(here, ":h") .. "/fixtures/repo"

describe("core.discovery.find", function()
  it("finds a .tour file under .tours/", function()
    local tours = discovery.find(fixtures)

    local names = vim.tbl_map(function(t)
      return vim.fn.fnamemodify(t.path, ":t")
    end, tours)

    assert.is_true(vim.tbl_contains(names, "intro.tour"))
  end)

  it("returns absolute paths that exist on disk", function()
    local tours = discovery.find(fixtures)

    assert.is_true(#tours > 0)
    for _, t in ipairs(tours) do
      assert.is_true(vim.startswith(t.path, "/"))
      assert.equals(1, vim.fn.filereadable(t.path))
    end
  end)

  it("returns an empty list for a root with no tours", function()
    local tours = discovery.find(vim.fn.fnamemodify(here, ":h"))

    assert.same({}, tours)
  end)
end)
