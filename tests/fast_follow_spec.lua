local model = require("codetour.core.model")
local player = require("codetour.player")
local config = require("codetour.config")

local here = debug.getinfo(1, "S").source:sub(2)
local fixtures = vim.fn.fnamemodify(here, ":h") .. "/fixtures/repo"

local function start(step)
  player.start(model.normalize({ title = "FF", steps = { step } }), { root = fixtures, step = 1 })
end

describe("fast-follow steps", function()
  local saved_opener
  before_each(function()
    saved_opener = player._opener
  end)
  after_each(function()
    pcall(player.stop)
    player._opener = saved_opener
    config.setup({})
  end)

  it("types directory / uri steps in the model", function()
    local tour = model.normalize({
      title = "T",
      steps = {
        { description = "d", directory = "src" },
        { description = "u", uri = "https://example.com" },
      },
    })
    assert.equals("directory", tour.steps[1].type)
    assert.equals("uri", tour.steps[2].type)
  end)

  it("opens a directory step's directory in the code window", function()
    start({ description = "the source dir", directory = "src" })
    assert.equals(1, vim.fn.isdirectory(vim.api.nvim_buf_get_name(0)))
    assert.is_true(vim.endswith(vim.api.nvim_buf_get_name(0):gsub("/$", ""), "src"))
  end)

  it("notifies and does not open a missing directory", function()
    vim.cmd("enew") -- clean, non-directory scratch buffer as the starting point
    local before = vim.api.nvim_get_current_buf()
    start({ description = "nope", directory = "does/not/exist" })
    -- Should not error and should leave the code window's buffer untouched.
    assert.equals(before, vim.api.nvim_get_current_buf())
    assert.equals(0, vim.fn.isdirectory(vim.api.nvim_buf_get_name(0)))
  end)

  it("hands an external uri to the opener (no browser spawned in test)", function()
    local captured
    player._opener = function(target)
      captured = target
    end
    start({ description = "site", uri = "https://example.com/x" })
    assert.equals("https://example.com/x", captured)
  end)

  it("opens a file:// uri as a file in the code window", function()
    local abs = vim.fn.fnamemodify(fixtures .. "/src/example.lua", ":p")
    player._opener = function()
      error("file:// should not reach the external opener")
    end
    start({ description = "local file", uri = "file://" .. abs })
    assert.is_true(vim.endswith(vim.api.nvim_buf_get_name(0), "src/example.lua"))
  end)
end)
