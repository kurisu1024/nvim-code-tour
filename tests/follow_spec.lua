local model = require("codetour.core.model")
local player = require("codetour.player")

local here = debug.getinfo(1, "S").source:sub(2)
local fixtures = vim.fn.fnamemodify(here, ":h") .. "/fixtures/follow"

-- Starting tour built inline (like player_spec). Its first step's description
-- carries one link per line so each is trivially hit-tested:
--   line 1: a step ref   [#2]
--   line 2: a tour ref   [Second Tour#2]   (resolved against the on-disk tours)
--   line 3: a file ref   [beta](src/beta.lua)
-- It also chains onward via nextTour = "Second Tour".
local function make_tour()
  return model.normalize({
    title = "Alpha Tour",
    nextTour = "Second Tour",
    steps = {
      {
        title = "a1",
        file = "src/alpha.lua",
        line = 3,
        description = "step ref [#2]\ntour ref [Second Tour#2]\nfile ref [beta](src/beta.lua)",
      },
      { title = "a2", file = "src/alpha.lua", line = 7, description = "the second alpha step" },
    },
  })
end

local function find_float()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local cfg = vim.api.nvim_win_get_config(win)
    if cfg.relative ~= nil and cfg.relative ~= "" then
      return vim.api.nvim_win_get_buf(win), win
    end
  end
  return nil
end

local function float_text()
  local buf = find_float()
  if not buf then
    return ""
  end
  return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
end

-- Place the cursor on a link (float row = md_line + 2 header lines) and fire the
-- float's `<CR>` follow map by invoking its buffer-local callback directly.
local function follow_at(md_line, col0)
  local buf, win = find_float()
  assert.is_not_nil(buf, "narrator float should be open")
  vim.api.nvim_win_set_cursor(win, { md_line + 2, col0 })
  for _, m in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do
    if m.lhs == "<CR>" and m.callback then
      m.callback()
      return
    end
  end
  error("no <CR> follow map on the narrator float")
end

describe("following links + nextTour chaining", function()
  after_each(function()
    pcall(player.stop)
  end)

  it("<CR> on a step ref jumps to that step in the current tour", function()
    player.start(make_tour(), { root = fixtures, step = 1 })

    follow_at(1, 10) -- on "[#2]" at md line 1

    assert.is_true(vim.endswith(vim.api.nvim_buf_get_name(0), "src/alpha.lua"))
    assert.equals(7, vim.api.nvim_win_get_cursor(0)[1]) -- step 2 anchors line 7
    assert.is_true(float_text():find("2/2", 1, true) ~= nil)
  end)

  it("<CR> on a tour ref starts the referenced tour at the given step", function()
    player.start(make_tour(), { root = fixtures, step = 1 })

    follow_at(2, 10) -- on "[Second Tour#2]" at md line 2

    assert.is_true(vim.endswith(vim.api.nvim_buf_get_name(0), "src/beta.lua"))
    assert.equals(3, vim.api.nvim_win_get_cursor(0)[1]) -- Second Tour step 2 anchors line 3
    assert.is_true(float_text():find("2/2", 1, true) ~= nil)
  end)

  it("<CR> on a file ref opens that file with no step change", function()
    player.start(make_tour(), { root = fixtures, step = 1 })

    follow_at(3, 10) -- on "[beta](src/beta.lua)" at md line 3

    assert.is_true(vim.endswith(vim.api.nvim_buf_get_name(0), "src/beta.lua"))
    -- Still narrating the same step of the same tour (no goto/start happened).
    assert.is_true(float_text():find("1/2", 1, true) ~= nil)
  end)

  it("nextTour chains to the next tour by title from the last step", function()
    player.start(make_tour(), { root = fixtures, step = 2 }) -- start on the last step

    player.next() -- past the end -> chains via nextTour

    assert.is_true(vim.endswith(vim.api.nvim_buf_get_name(0), "src/beta.lua"))
    assert.equals(1, vim.api.nvim_win_get_cursor(0)[1]) -- Second Tour step 1
    assert.is_true(float_text():find("1/2", 1, true) ~= nil)
  end)

  it("<CR> off any link is a no-op (stays on the current step)", function()
    player.start(make_tour(), { root = fixtures, step = 1 })

    follow_at(1, 0) -- column 0 of "step ref [#2]" is before the link span

    assert.equals(3, vim.api.nvim_win_get_cursor(0)[1]) -- unchanged, still step 1
    assert.is_true(float_text():find("1/2", 1, true) ~= nil)
  end)
end)
