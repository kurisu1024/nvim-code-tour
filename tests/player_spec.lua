local model = require("codetour.core.model")
local player = require("codetour.player")

local here = debug.getinfo(1, "S").source:sub(2)
local fixtures = vim.fn.fnamemodify(here, ":h") .. "/fixtures/repo"

local function make_tour()
  return model.normalize({
    title = "Intro Tour",
    steps = {
      { title = "one", file = "src/example.lua", line = 2, description = "step **one** body" },
      { title = "two", file = "src/example.lua", line = 6, description = "step two body" },
    },
  })
end

-- Behavioural probes: find the narrator float and the named highlight namespace
-- without reaching into player internals.
local function find_float_buf()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local cfg = vim.api.nvim_win_get_config(win)
    if cfg.relative ~= nil and cfg.relative ~= "" then
      return vim.api.nvim_win_get_buf(win), win
    end
  end
  return nil
end

local function float_text()
  local buf = find_float_buf()
  if not buf then
    return ""
  end
  return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
end

local function ns_id()
  return vim.api.nvim_get_namespaces()["codetour"]
end

local function code_line_extmarks()
  local ns = ns_id()
  if not ns then
    return {}
  end
  local buf = vim.api.nvim_get_current_buf()
  return vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, {})
end

describe("player", function()
  after_each(function()
    pcall(player.stop)
  end)

  it("opens the step's file with the cursor on the anchored line", function()
    player.start(make_tour(), { root = fixtures, step = 1 })

    assert.is_true(vim.endswith(vim.api.nvim_buf_get_name(0), "src/example.lua"))
    assert.equals(2, vim.api.nvim_win_get_cursor(0)[1])
  end)

  it("highlights the anchored line with an extmark", function()
    player.start(make_tour(), { root = fixtures, step = 1 })

    local marks = code_line_extmarks()
    assert.is_true(#marks >= 1)
    assert.equals(1, marks[1][2]) -- 0-indexed row for line 2
  end)

  it("shows the step markdown and a Step n/m counter in a float", function()
    player.start(make_tour(), { root = fixtures, step = 1 })

    local text = float_text()
    assert.is_true(text:find("step", 1, true) ~= nil)
    assert.is_true(text:find("1/2", 1, true) ~= nil)
  end)

  it("moves to the next and previous step in place", function()
    player.start(make_tour(), { root = fixtures, step = 1 })

    player.next()
    assert.equals(6, vim.api.nvim_win_get_cursor(0)[1])
    assert.is_true(float_text():find("2/2", 1, true) ~= nil)

    player.prev()
    assert.equals(2, vim.api.nvim_win_get_cursor(0)[1])
    assert.is_true(float_text():find("1/2", 1, true) ~= nil)
  end)

  it("clamps navigation at the ends", function()
    player.start(make_tour(), { root = fixtures, step = 1 })

    player.prev() -- already first
    assert.equals(2, vim.api.nvim_win_get_cursor(0)[1])

    player.goto(2)
    player.next() -- already last
    assert.equals(6, vim.api.nvim_win_get_cursor(0)[1])
  end)

  it("wires buffer-local nav maps on the code buffer and removes them on stop", function()
    player.start(make_tour(), { root = fixtures, step = 1 })

    local buf = vim.api.nvim_get_current_buf()
    local function has_map(lhs)
      for _, m in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do
        if m.lhs == lhs then
          return true
        end
      end
      return false
    end

    assert.is_true(has_map("]t"))
    assert.is_true(has_map("[t"))
    assert.is_true(has_map("q"))

    player.stop()
    assert.is_false(has_map("]t"))
    assert.is_false(has_map("q"))
  end)

  it("tears down the float and extmarks on stop", function()
    player.start(make_tour(), { root = fixtures, step = 1 })
    player.stop()

    assert.is_nil(find_float_buf())
    assert.equals(0, #code_line_extmarks())
  end)

  it("resolves a pattern step and lands the cursor on the matched line", function()
    local tour = model.normalize({
      title = "Pattern",
      steps = { { description = "the fn", file = "src/example.lua", pattern = "function" } },
    })
    player.start(tour, { root = fixtures, step = 1 })

    assert.is_true(vim.endswith(vim.api.nvim_buf_get_name(0), "src/example.lua"))
    assert.equals(3, vim.api.nvim_win_get_cursor(0)[1]) -- "function M.greet(name)"
  end)

  it("retains state so resume re-enters the last step", function()
    player.start(make_tour(), { root = fixtures, step = 1 })
    player.next()
    player.stop()

    player.resume()
    assert.equals(6, vim.api.nvim_win_get_cursor(0)[1])
    assert.is_true(float_text():find("2/2", 1, true) ~= nil)
  end)
end)
