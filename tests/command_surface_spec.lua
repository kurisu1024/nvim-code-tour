local command = require("codetour.command")
local model = require("codetour.core.model")
local player = require("codetour.player")

local here = debug.getinfo(1, "S").source:sub(2)
local fixtures = vim.fn.fnamemodify(here, ":h") .. "/fixtures/repo"

local function completions(arglead)
  return command.complete(arglead)
end

local function contains(list, value)
  for _, v in ipairs(list) do
    if v == value then
      return true
    end
  end
  return false
end

local function float_text()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local cfg = vim.api.nvim_win_get_config(win)
    if cfg.relative ~= nil and cfg.relative ~= "" then
      return table.concat(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win), 0, -1, false), "\n")
    end
  end
  return ""
end

local function make_tour()
  return model.normalize({
    title = "Surface",
    steps = {
      { file = "src/example.lua", line = 2, description = "one" },
      { file = "src/example.lua", line = 6, description = "two" },
    },
  })
end

describe(":CodeTour command surface", function()
  after_each(function()
    pcall(player.stop)
  end)

  it("completes every subcommand on an empty arglead", function()
    local c = completions("")
    for _, sub in ipairs({ "start", "next", "prev", "goto", "resume", "end", "list" }) do
      assert.is_true(contains(c, sub), "missing completion: " .. sub)
    end
  end)

  it("filters completions by prefix", function()
    local c = completions("g")
    assert.is_true(contains(c, "goto"))
    assert.is_false(contains(c, "start"))
  end)

  it("dispatches goto N to the numbered step", function()
    player.start(make_tour(), { root = fixtures, step = 1 })
    command.dispatch({ "goto", "2" })
    assert.equals(6, vim.api.nvim_win_get_cursor(0)[1])
    assert.is_true(float_text():find("2/2", 1, true) ~= nil)
  end)

  it("dispatches end to stop() and resume to re-enter", function()
    player.start(make_tour(), { root = fixtures, step = 1 })
    command.dispatch({ "next" })
    command.dispatch({ "end" })
    assert.equals("", float_text()) -- torn down

    command.dispatch({ "resume" })
    assert.is_true(float_text():find("2/2", 1, true) ~= nil)
  end)

  it("warns, does not crash, on an unknown subcommand", function()
    assert.has_no.errors(function()
      command.dispatch({ "bogus" })
    end)
  end)
end)
