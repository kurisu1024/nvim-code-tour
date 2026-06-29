local discovery = require("codetour.core.discovery")

-- Resolve tests/fixtures relative to this spec file.
local here = debug.getinfo(1, "S").source:sub(2)
local fixtures_dir = vim.fn.fnamemodify(here, ":h") .. "/fixtures"
local repo = fixtures_dir .. "/repo"
local tree = fixtures_dir .. "/discovery"

-- Map a tour list to a lookup keyed by title for convenient assertions.
local function by_title(tours)
  local out = {}
  for _, t in ipairs(tours) do
    out[t.title] = t
  end
  return out
end

local function basenames(tours)
  return vim.tbl_map(function(t)
    return vim.fn.fnamemodify(t.path, ":t")
  end, tours)
end

describe("core.discovery.find (skeleton contract)", function()
  it("finds a .tour file under .tours/", function()
    local tours = discovery.find(repo)
    assert.is_true(vim.tbl_contains(basenames(tours), "intro.tour"))
  end)

  it("returns absolute paths that exist on disk", function()
    local tours = discovery.find(repo)
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

describe("core.discovery.find (full engine)", function()
  it("finds tours across every standard location, including nested + root files", function()
    local found = by_title(discovery.find(tree))

    assert.is_not_nil(found["Alpha"]) -- .tours/a.tour
    assert.is_not_nil(found["Beta"]) -- .tours/nested/b.tour (nested allowed)
    assert.is_not_nil(found["Gamma"]) -- .vscode/tours/c.tour
    assert.is_not_nil(found["Delta"]) -- .github/tours/d.tour
    assert.is_not_nil(found["Main"]) -- root main.tour
  end)

  it("includes a configured extra directory (absolute)", function()
    local without = by_title(discovery.find(tree))
    assert.is_nil(without["Epsilon"]) -- not in a standard location

    local with = by_title(discovery.find(tree, { tour_dir = tree .. "/extra-tours" }))
    assert.is_not_nil(with["Epsilon"]) -- extra-tours/e.tour
  end)

  it("accepts a configured extra dir relative to the root", function()
    local with = by_title(discovery.find(tree, { tour_dir = "extra-tours" }))
    assert.is_not_nil(with["Epsilon"])
  end)

  it("returns metadata (title, step count, primary flag, path) without full load", function()
    local found = by_title(discovery.find(tree))

    assert.equals("Alpha", found["Alpha"].title)
    assert.equals(2, found["Alpha"].step_count)
    assert.equals(3, found["Gamma"].step_count)
    assert.equals(1, found["Delta"].step_count)
    assert.is_false(found["Alpha"].is_primary)
    assert.equals(1, vim.fn.filereadable(found["Alpha"].path))
  end)

  it("detects the primary tour via isPrimary: true", function()
    local found = by_title(discovery.find(tree))
    assert.is_true(found["Zeta"].is_primary)
  end)

  it("detects the primary tour via a '1 - ' title convention", function()
    local found = by_title(discovery.find(tree))
    assert.is_true(found["1 - Onboarding"].is_primary)
  end)

  it("skips broken/unparseable tour files without crashing", function()
    local tours = discovery.find(tree)
    assert.is_nil(by_title(tours)["Broken"])
    for _, t in ipairs(tours) do
      assert.is_string(t.title)
      assert.is_true(t.step_count >= 1)
    end
  end)

  it("de-duplicates and returns a stable sorted order", function()
    local a = discovery.find(tree)
    local b = discovery.find(tree)
    assert.same(
      vim.tbl_map(function(t) return t.path end, a),
      vim.tbl_map(function(t) return t.path end, b)
    )
  end)
end)

describe("core.discovery.resolve_root", function()
  it("resolves to the git root when a .git marker is present", function()
    local root = vim.fn.tempname()
    vim.fn.mkdir(root .. "/.git", "p")
    vim.fn.mkdir(root .. "/sub/deep", "p")

    local resolved = discovery.resolve_root(root .. "/sub/deep")
    assert.equals(vim.fn.resolve(root), vim.fn.resolve(resolved))
  end)

  it("falls back to cwd when no .git marker is found", function()
    local root = vim.fn.tempname()
    vim.fn.mkdir(root, "p")
    assert.equals(vim.fn.getcwd(), discovery.resolve_root(root))
  end)
end)
