local codetour = require("codetour")
local config = require("codetour.config")

-- Build a throwaway tour repo outside the project tree so git-root resolution
-- lands on it, and chdir into it (mirrors command_spec).
local function make_repo()
  local root = vim.fn.tempname()
  vim.fn.mkdir(root .. "/.tours", "p")
  vim.fn.writefile({
    '{ "title": "Walkthrough", "steps": ['
      .. '{ "description": "a" }, { "description": "b" }, { "description": "c" } ] }',
  }, root .. "/.tours/walk.tour")
  vim.fn.writefile({
    '{ "title": "1 - Onboarding", "steps": [ { "description": "only" } ] }',
  }, root .. "/.tours/onboard.tour")
  return root
end

-- Capture the messages emitted through vim.notify while `fn` runs.
local function capture_notify(fn)
  local captured = {}
  local original = vim.notify
  vim.notify = function(msg)
    table.insert(captured, msg)
  end
  local ok, err = pcall(fn)
  vim.notify = original
  assert(ok, err)
  return table.concat(captured, "\n")
end

describe(":CodeTour list", function()
  before_each(function()
    config.setup({})
  end)

  it("reports each discovered tour with its title and step count", function()
    local root = make_repo()
    vim.fn.chdir(root)
    vim.cmd("enew")
    codetour.setup()

    local out = capture_notify(function()
      vim.cmd("CodeTour list")
    end)

    assert.is_true(out:find("Walkthrough", 1, true) ~= nil)
    assert.is_true(out:find("3 steps", 1, true) ~= nil)
    assert.is_true(out:find("1 - Onboarding", 1, true) ~= nil)
    assert.is_true(out:find("1 step", 1, true) ~= nil)
    assert.is_true(out:find("(primary)", 1, true) ~= nil) -- the "1 - " title
  end)

  it("includes tours from a configured extra directory", function()
    local root = make_repo()
    local extra = root .. "/walkthroughs"
    vim.fn.mkdir(extra, "p")
    vim.fn.writefile({
      '{ "title": "Extra Tour", "steps": [ { "description": "x" } ] }',
    }, extra .. "/x.tour")

    vim.fn.chdir(root)
    vim.cmd("enew")
    codetour.setup({ tour_dir = extra })

    local out = capture_notify(function()
      codetour.list()
    end)

    assert.is_true(out:find("Extra Tour", 1, true) ~= nil)
  end)

  it("notifies and does not crash when no tours are found", function()
    local empty = vim.fn.tempname()
    vim.fn.mkdir(empty, "p")
    vim.fn.chdir(empty)
    vim.cmd("enew")
    codetour.setup()

    local out = capture_notify(function()
      vim.cmd("CodeTour list")
    end)
    assert.is_true(out:find("no tours found", 1, true) ~= nil)
  end)
end)
