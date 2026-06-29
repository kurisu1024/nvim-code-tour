-- Integration: `:CodeTour start` chooses between a direct start and the picker.
--
-- With exactly one tour, start plays it directly (no picker). With several, the
-- picker is the touchpoint; when telescope is absent on the runtime (as in CI
-- here) start degrades — it notifies and plays the primary tour rather than
-- erroring or doing nothing. The selecting -> player.start dispatch is pinned by
-- this degrade path (and unit-tested in picker_spec via picker.select).

local codetour = require("codetour")
local config = require("codetour.config")
local player = require("codetour.player")

-- A throwaway repo outside this plugin's tree so git-root resolution lands here.
local function make_multi_repo()
  local root = vim.fn.tempname()
  vim.fn.mkdir(root .. "/.tours", "p")
  vim.fn.mkdir(root .. "/src", "p")
  vim.fn.writefile({ "primary one", "primary two", "primary three" }, root .. "/src/primary.lua")
  vim.fn.writefile({ "other one", "other two", "other three" }, root .. "/src/other.lua")
  -- Primary tour (title uses the "1 - " ordering convention).
  vim.fn.writefile({
    '{ "title": "1 - Primary", "steps": ['
      .. '{ "file": "src/primary.lua", "line": 2, "description": "p" } ] }',
  }, root .. "/.tours/primary.tour")
  -- A second, non-primary tour so discovery returns more than one.
  vim.fn.writefile({
    '{ "title": "Aux", "steps": ['
      .. '{ "file": "src/other.lua", "line": 3, "description": "o" },'
      .. '{ "file": "src/other.lua", "line": 1, "description": "o2" } ] }',
  }, root .. "/.tours/aux.tour")
  return root
end

local function find_float_buf()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local cfg = vim.api.nvim_win_get_config(win)
    if cfg.relative ~= nil and cfg.relative ~= "" then
      return vim.api.nvim_win_get_buf(win)
    end
  end
  return nil
end

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

describe(":CodeTour start with multiple tours", function()
  before_each(function()
    config.setup({})
  end)

  after_each(function()
    pcall(player.stop)
  end)

  it("does not error and starts a tour when several exist (degrades without telescope)", function()
    local root = make_multi_repo()
    vim.fn.chdir(root)
    vim.cmd("enew")
    codetour.setup()

    capture_notify(function()
      vim.cmd("CodeTour start")
    end)

    -- Telescope is absent here, so start falls back to the primary tour.
    assert.is_true(vim.endswith(vim.api.nvim_buf_get_name(0), "src/primary.lua"))
    assert.equals(2, vim.api.nvim_win_get_cursor(0)[1])
    assert.is_not_nil(find_float_buf())
  end)

  it("mentions telescope when it degrades", function()
    local root = make_multi_repo()
    vim.fn.chdir(root)
    vim.cmd("enew")
    codetour.setup()

    local out = capture_notify(function()
      vim.cmd("CodeTour start")
    end)
    assert.is_true(out:lower():find("telescope", 1, true) ~= nil)
  end)
end)
