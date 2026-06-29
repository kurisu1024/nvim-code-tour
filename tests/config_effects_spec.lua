local config = require("codetour.config")
local model = require("codetour.core.model")
local player = require("codetour.player")
local discovery = require("codetour.core.discovery")

local here = debug.getinfo(1, "S").source:sub(2)
local fixtures = vim.fn.fnamemodify(here, ":h") .. "/fixtures/repo"

local function make_tour()
  return model.normalize({
    title = "Cfg Tour",
    steps = { { title = "one", file = "src/example.lua", line = 2, description = "body" } },
  })
end

local function find_float_win()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local cfg = vim.api.nvim_win_get_config(win)
    if cfg.relative ~= nil and cfg.relative ~= "" then
      return win
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

describe("config effects", function()
  after_each(function()
    pcall(player.stop)
    config.setup({}) -- restore defaults between cases
  end)

  it("places and sizes the narrator float per config", function()
    config.setup({ float = { position = "top", width = 0.4, height = 0.25 } })
    player.start(make_tour(), { root = fixtures, step = 1 })

    local win = find_float_win()
    assert.is_not_nil(win)
    local cfg = vim.api.nvim_win_get_config(win)
    assert.equals(math.floor(vim.o.columns * 0.4), cfg.width)
    assert.equals(math.floor(vim.o.lines * 0.25), cfg.height)
    assert.equals(1, cfg.row) -- "top" anchors near the first row
  end)

  it("anchors the float to the bottom by default", function()
    config.setup({})
    player.start(make_tour(), { root = fixtures, step = 1 })

    local win = find_float_win()
    local cfg = vim.api.nvim_win_get_config(win)
    assert.is_true(cfg.row > 1) -- bottom -> well below the first row
  end)

  it("suppresses tour keymaps when default_keymaps is false", function()
    config.setup({ default_keymaps = false })
    player.start(make_tour(), { root = fixtures, step = 1 })

    local buf = vim.api.nvim_get_current_buf()
    assert.is_false(buf_has_map(buf, "]t"))
    assert.is_false(buf_has_map(buf, "[t"))
    assert.is_false(buf_has_map(buf, "q"))
  end)

  it("honors remapped tour keys", function()
    config.setup({ keymaps = { next = "<C-n>", prev = "<C-p>", stop = "<C-c>" } })
    player.start(make_tour(), { root = fixtures, step = 1 })

    local buf = vim.api.nvim_get_current_buf()
    assert.is_true(buf_has_map(buf, "<C-N>"))
    assert.is_true(buf_has_map(buf, "<C-P>"))
    -- The default keys are no longer bound.
    assert.is_false(buf_has_map(buf, "]t"))
  end)

  it("flows tour_dir into discovery so an out-of-tree dir is honored", function()
    local root = vim.fn.tempname()
    local extra = vim.fn.tempname()
    vim.fn.mkdir(root, "p")
    vim.fn.mkdir(extra, "p")
    vim.fn.writefile({ '{ "title": "Extra", "steps": [ { "description": "x" } ] }' }, extra .. "/e.tour")

    config.setup({ tour_dir = extra })
    assert.equals(extra, config.get().tour_dir)

    local tours = discovery.find(root, { tour_dir = config.get().tour_dir })
    local titles = {}
    for _, t in ipairs(tours) do
      titles[t.title] = true
    end
    assert.is_true(titles["Extra"] == true)
  end)
end)
