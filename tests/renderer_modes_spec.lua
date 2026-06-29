local config = require("codetour.config")
local model = require("codetour.core.model")
local player = require("codetour.player")

local here = debug.getinfo(1, "S").source:sub(2)
local fixtures = vim.fn.fnamemodify(here, ":h") .. "/fixtures/repo"

local function make_tour()
  return model.normalize({
    title = "Render Tour",
    steps = { { title = "one", file = "src/example.lua", line = 2, description = "body **x**" } },
  })
end

local function float_win()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(win).relative ~= "" then
      return win
    end
  end
  return nil
end

-- The narrator buffer in a split is the nofile markdown buffer in a normal window.
local function split_win()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(win).relative == "" then
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.bo[buf].buftype == "nofile" and vim.bo[buf].filetype == "markdown" then
        return win, buf
      end
    end
  end
  return nil
end

local function buf_has_map(buf, lhs)
  for _, m in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do
    if m.lhs == lhs then
      return true
    end
  end
  return false
end

describe("renderer modes", function()
  after_each(function()
    pcall(player.stop)
    config.setup({})
  end)

  it("defaults to the fixed float", function()
    player.start(make_tour(), { root = fixtures, step = 1 })
    assert.is_not_nil(float_win())
  end)

  it("puts a keybinding hint in the float footer", function()
    player.start(make_tour(), { root = fixtures, step = 1 })
    local cfg = vim.api.nvim_win_get_config(float_win())
    -- footer is a list of {text, hl} chunks; flatten to a string.
    local footer = ""
    for _, chunk in ipairs(cfg.footer or {}) do
      footer = footer .. (type(chunk) == "table" and chunk[1] or chunk)
    end
    assert.is_true(footer:find("next", 1, true) ~= nil)
    assert.is_true(footer:find("]f", 1, true) ~= nil)
  end)

  it("switches live to a split and back to a float", function()
    player.start(make_tour(), { root = fixtures, step = 1 })
    assert.is_not_nil(float_win())

    player.set_renderer("split")
    assert.is_nil(float_win()) -- the float is gone
    local win, buf = split_win()
    assert.is_not_nil(win)
    local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
    assert.is_true(text:find("1/1", 1, true) ~= nil)

    player.set_renderer("float")
    assert.is_not_nil(float_win())
    assert.is_nil(split_win())
  end)

  it("switches to an anchored float (still a floating window)", function()
    player.start(make_tour(), { root = fixtures, step = 1 })
    player.set_renderer("float-anchored")
    assert.is_not_nil(float_win())
  end)

  it("rejects an unknown renderer without disturbing the active one", function()
    player.start(make_tour(), { root = fixtures, step = 1 })
    player.set_renderer("nope")
    assert.is_not_nil(float_win()) -- unchanged
    assert.equals("float", config.get().renderer) -- not overwritten by junk
  end)

  it("keeps a bottom-float's anchored line above the float (not under it)", function()
    -- A tall fixture so there is room to scroll; anchor deep in the file.
    local lines = {}
    for i = 1, 200 do
      lines[i] = "line " .. i
    end
    local tmp = vim.fn.tempname() .. ".txt"
    vim.fn.writefile(lines, tmp)
    local tour = model.normalize({
      title = "Deep",
      steps = { { description = "deep", file = tmp, line = 150 } },
    })

    config.setup({ float = { position = "bottom", height = 0.3 } })
    player.start(tour, { root = "/", step = 1 })

    local code_win = vim.api.nvim_get_current_win()
    local win_h = vim.api.nvim_win_get_height(code_win)
    local screenrow = vim.fn.winline() -- screen row of the anchored line (cursor)
    -- The line should sit in the upper portion, clear of a ~bottom-30% float.
    assert.equals(150, vim.api.nvim_win_get_cursor(code_win)[1])
    assert.is_true(screenrow <= math.floor(win_h * 0.5))
  end)

  it("focuses the narrator window and the same key is mapped to return", function()
    player.start(make_tour(), { root = fixtures, step = 1 })
    local fwin = float_win()
    local fbuf = vim.api.nvim_win_get_buf(fwin)
    assert.is_true(buf_has_map(fbuf, "]f")) -- focus-back wired on the float

    player.focus()
    assert.equals(fwin, vim.api.nvim_get_current_win())
  end)
end)
