local codetour = require("codetour")
local player = require("codetour.player")

-- Build a throwaway tour repo outside the project tree (so git-root resolution
-- lands on it, not on this plugin's repo) and chdir into it.
local function make_repo()
  local root = vim.fn.tempname()
  vim.fn.mkdir(root .. "/.tours", "p")
  vim.fn.mkdir(root .. "/src", "p")
  vim.fn.writefile({ "line one", "line two", "line three" }, root .. "/src/hi.lua")
  vim.fn.writefile({
    "{",
    '  "title": "Walk",',
    '  "steps": [',
    '    { "file": "src/hi.lua", "line": 2, "description": "the **second** line" }',
    "  ]",
    "}",
  }, root .. "/.tours/walk.tour")
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

describe(":CodeTour command", function()
  after_each(function()
    pcall(player.stop)
  end)

  it("registers the :CodeTour command on setup", function()
    codetour.setup()
    assert.equals(2, vim.fn.exists(":CodeTour"))
  end)

  it("plays the discovered tour end to end via :CodeTour start", function()
    local root = make_repo()
    vim.fn.chdir(root)
    vim.cmd("enew") -- unnamed buffer so root resolves from cwd
    codetour.setup()

    vim.cmd("CodeTour start")

    assert.is_true(vim.endswith(vim.api.nvim_buf_get_name(0), "src/hi.lua"))
    assert.equals(2, vim.api.nvim_win_get_cursor(0)[1])

    local fbuf = find_float_buf()
    assert.is_not_nil(fbuf)
    local text = table.concat(vim.api.nvim_buf_get_lines(fbuf, 0, -1, false), "\n")
    assert.is_true(text:find("1/1", 1, true) ~= nil)
  end)

  it("notifies and does not crash when no tours are found", function()
    local empty = vim.fn.tempname()
    vim.fn.mkdir(empty, "p")
    vim.fn.chdir(empty)
    vim.cmd("enew")
    codetour.setup()

    assert.has_no.errors(function()
      vim.cmd("CodeTour start")
    end)
    assert.is_nil(find_float_buf())
  end)
end)
