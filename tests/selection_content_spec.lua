local model = require("codetour.core.model")
local player = require("codetour.player")

local here = debug.getinfo(1, "S").source:sub(2)
local fixtures = vim.fn.fnamemodify(here, ":h") .. "/fixtures/repo"

-- Tour with a selection step (lines 3..5 of the fixture) followed by a
-- content step (no file) so we can probe both kinds and the transition.
local function make_tour()
  return model.normalize({
    title = "Selection & Content",
    steps = {
      {
        title = "range",
        file = "src/example.lua",
        selection = {
          start = { line = 3, character = 1 },
          ["end"] = { line = 5, character = 4 },
        },
        description = "the greet function",
      },
      { title = "wrap up", description = "content **only** — no file here" },
    },
  })
end

local function ns_id()
  return vim.api.nvim_get_namespaces()["codetour"]
end

local function marks_with_details(buf)
  local ns = ns_id()
  if not ns then
    return {}
  end
  return vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
end

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

local function has_map(buf, lhs)
  for _, m in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do
    if m.lhs == lhs then
      return true
    end
  end
  return false
end

describe("selection & content steps", function()
  after_each(function()
    pcall(player.stop)
  end)

  it("highlights the full selection range and puts the cursor at its start", function()
    player.start(make_tour(), { root = fixtures, step = 1 })

    -- Cursor sits at the selection start line.
    assert.equals(3, vim.api.nvim_win_get_cursor(0)[1])

    local buf = vim.api.nvim_get_current_buf()
    local marks = marks_with_details(buf)
    assert.is_true(#marks >= 1)

    -- The extmark spans the whole range: start row 2 (line 3) → end row 4 (line 5).
    assert.equals(2, marks[1][2])
    assert.equals(4, marks[1][4].end_row)
  end)

  it("narrates a content step without touching the code window", function()
    player.start(make_tour(), { root = fixtures, step = 1 })
    local code_buf = vim.api.nvim_get_current_buf()
    local code_name = vim.api.nvim_buf_get_name(0)

    player.next() -- into the content step

    -- The code window is untouched: same buffer, same file on screen.
    assert.equals(code_buf, vim.api.nvim_get_current_buf())
    assert.equals(code_name, vim.api.nvim_buf_get_name(0))

    -- The narrator float shows the content prose and the 2/2 counter.
    local text = float_text()
    assert.is_true(text:find("content", 1, true) ~= nil)
    assert.is_true(text:find("2/2", 1, true) ~= nil)
  end)

  it("cleans up the prior highlight when navigating into a content step", function()
    player.start(make_tour(), { root = fixtures, step = 1 })
    local code_buf = vim.api.nvim_get_current_buf()
    assert.is_true(#marks_with_details(code_buf) >= 1)

    player.next() -- into the content step

    assert.equals(0, #marks_with_details(code_buf))
  end)

  it("wires buffer-local nav maps for a content step", function()
    player.start(make_tour(), { root = fixtures, step = 1 })
    player.next() -- into the content step

    local buf = vim.api.nvim_get_current_buf()
    assert.is_true(has_map(buf, "]t"))
    assert.is_true(has_map(buf, "[t"))
    assert.is_true(has_map(buf, "q"))
  end)

  it("wires nav maps when the tour opens directly on a content step", function()
    -- No prior file step could have left maps behind: this proves the content
    -- branch wires its own maps (the carried-over NCT-001 review gap).
    local content_first = model.normalize({
      title = "Content First",
      steps = {
        { title = "intro", description = "welcome — no file" },
        { title = "code", file = "src/example.lua", line = 3, description = "now some code" },
      },
    })
    player.start(content_first, { root = fixtures, step = 1 })

    local buf = vim.api.nvim_get_current_buf()
    assert.is_true(has_map(buf, "]t"))
    assert.is_true(has_map(buf, "[t"))
    assert.is_true(has_map(buf, "q"))
    assert.is_true(float_text():find("welcome", 1, true) ~= nil)
  end)

  it("restores the selection highlight when navigating back out of a content step", function()
    player.start(make_tour(), { root = fixtures, step = 1 })
    player.next() -- content
    player.prev() -- back to the selection step

    local buf = vim.api.nvim_get_current_buf()
    local marks = marks_with_details(buf)
    assert.equals(1, #marks) -- exactly the selection range, no stale leftovers
    assert.equals(2, marks[1][2])
    assert.equals(4, marks[1][4].end_row)
    assert.equals(3, vim.api.nvim_win_get_cursor(0)[1])
  end)
end)
