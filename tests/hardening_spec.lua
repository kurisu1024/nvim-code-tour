-- Hardening pass from the NCT-001 code review: JSON-null (vim.NIL) safety,
-- lenient-fatal on zero valid steps, window-safety in codewin, stale-highlight
-- clearing, double-setup, and resume re-entry.

local model = require("codetour.core.model")
local schema = require("codetour.core.schema")
local codewin = require("codetour.ui.codewin")
local player = require("codetour.player")
local codetour = require("codetour")

local here = debug.getinfo(1, "S").source:sub(2)
local fixtures = vim.fn.fnamemodify(here, ":h") .. "/fixtures/repo"

local function count_floats()
  local n = 0
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(win).relative ~= "" then
      n = n + 1
    end
  end
  return n
end

describe("model vim.NIL safety", function()
  it("converts JSON-null step fields to Lua nil", function()
    local tour = model.normalize({
      title = "T",
      steps = {
        { description = "d", file = vim.NIL, line = vim.NIL, title = vim.NIL },
      },
    })
    local step = tour.steps[1]
    assert.is_nil(step.title)
    assert.is_nil(step.file)
    assert.is_nil(step.line)
    assert.equals("content", step.type) -- file was null, so not a file step
  end)

  it("converts JSON-null tour fields to Lua nil", function()
    local tour = model.normalize({
      title = "T",
      description = vim.NIL,
      ref = vim.NIL,
      steps = { { description = "d", file = "a.lua", line = 1 } },
    })
    assert.is_nil(tour.description)
    assert.is_nil(tour.ref)
  end)
end)

describe("schema fatal-on-empty", function()
  it("treats a steps array with no valid steps as fatally invalid", function()
    local result = schema.validate({
      title = "T",
      steps = { { file = "a.lua" }, vim.NIL }, -- none have a description
    })
    assert.is_true(#result.errors > 0)
    assert.same({}, result.valid_steps)
  end)

  it("returns nil from model.normalize for an all-invalid-steps tour", function()
    local tour, err = model.normalize({ title = "T", steps = { { file = "a.lua" } } })
    assert.is_nil(tour)
    assert.is_table(err)
  end)
end)

describe("codewin window safety", function()
  it("never opens a file inside a floating window", function()
    local fbuf = vim.api.nvim_create_buf(false, true)
    local fwin = vim.api.nvim_open_win(fbuf, false, {
      relative = "editor", width = 10, height = 3, row = 1, col = 1, style = "minimal",
    })

    local buf, win = codewin.open(fwin, fixtures, "src/example.lua", 2)

    assert.is_not_nil(win)
    assert.are_not.equal(fwin, win) -- did not hijack the float
    assert.equals(fbuf, vim.api.nvim_win_get_buf(fwin)) -- float buffer untouched
    assert.is_true(vim.endswith(vim.api.nvim_buf_get_name(buf), "src/example.lua"))

    pcall(vim.api.nvim_win_close, fwin, true)
  end)
end)

describe("player hardening", function()
  after_each(function()
    pcall(player.stop)
  end)

  it("clears the prior file highlight when moving to a content step", function()
    local tour = model.normalize({
      title = "Mixed",
      steps = {
        { description = "code", file = "src/example.lua", line = 2 },
        { description = "just prose" }, -- content step
      },
    })
    player.start(tour, { root = fixtures, step = 1 })
    local code_buf = vim.api.nvim_get_current_buf()
    local ns = vim.api.nvim_get_namespaces()["codetour"]
    assert.is_true(#vim.api.nvim_buf_get_extmarks(code_buf, ns, 0, -1, {}) >= 1)

    player.next() -- to content step
    assert.equals(0, #vim.api.nvim_buf_get_extmarks(code_buf, ns, 0, -1, {}))
  end)

  it("leaves exactly one float after stop+resume (no orphan)", function()
    local model_tour = model.normalize({
      title = "T",
      steps = {
        { description = "one", file = "src/example.lua", line = 2 },
        { description = "two", file = "src/example.lua", line = 6 },
      },
    })
    player.start(model_tour, { root = fixtures, step = 1 })
    player.next()
    player.stop()
    assert.equals(0, count_floats())

    player.resume()
    assert.equals(1, count_floats())
  end)
end)

describe("setup idempotency", function()
  it("does not error when setup() is called twice", function()
    assert.has_no.errors(function()
      codetour.setup()
      codetour.setup()
    end)
    assert.equals(2, vim.fn.exists(":CodeTour"))
  end)
end)
