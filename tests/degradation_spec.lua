-- NCT-008 — resilience & graceful degradation (the cross-cutting hardening pass).
--
-- Drives deliberately malformed tours/steps through the whole playback path and
-- asserts the design's failure posture: one bad file never breaks discovery of
-- the others; one bad step never breaks its tour; one unresolved anchor never
-- breaks navigation. Degrade, notify, continue — and never execute anything.

local discovery = require("codetour.core.discovery")
local model = require("codetour.core.model")
local markdown = require("codetour.core.markdown")
local player = require("codetour.player")
local config = require("codetour.config")

local here = debug.getinfo(1, "S").source:sub(2)
local fixtures = vim.fn.fnamemodify(here, ":h") .. "/fixtures"
local repo = fixtures .. "/repo"
local degr = fixtures .. "/degradation"

-- Capture every message sent through vim.notify while `fn` runs.
local function capture_notify(fn)
  local captured = {}
  local original = vim.notify
  vim.notify = function(msg, level)
    table.insert(captured, { msg = msg, level = level })
  end
  local ok, err = pcall(fn)
  vim.notify = original
  assert(ok, err)
  return captured
end

local function notify_text(captured)
  return table.concat(
    vim.tbl_map(function(e)
      return e.msg
    end, captured),
    "\n"
  )
end

local function by_title(tours)
  local out = {}
  for _, t in ipairs(tours) do
    out[t.title] = t
  end
  return out
end

describe("discovery degradation", function()
  it("surfaces a broken (parseable) tour flagged, but skips unparseable files", function()
    local found = by_title(discovery.find(degr))

    -- The valid tour is discovered and is not flagged.
    assert.is_not_nil(found["Good Tour"])
    assert.is_not_true(found["Good Tour"].broken)

    -- A parseable-but-structurally-broken tour (no valid steps) still appears in
    -- the list, flagged, rather than vanishing silently.
    assert.is_not_nil(found["Empty Tour"])
    assert.is_true(found["Empty Tour"].broken)

    -- Truly unparseable JSON has no recoverable identity, so it is skipped.
    assert.is_nil(found["Garbage"])
  end)

  it("one bad file never sinks discovery of the others", function()
    assert.has_no.errors(function()
      local tours = discovery.find(degr)
      assert.is_true(#tours >= 2)
    end)
  end)
end)

describe("schema degradation (skip-invalid, keep tour)", function()
  it("drops invalid steps but keeps the tour and its valid steps", function()
    local tour = model.normalize({
      title = "Half",
      steps = {
        { description = "ok", file = "a.lua", line = 1 },
        { file = "b.lua" }, -- no description -> invalid -> skipped
        "not even an object", -- skipped
        { description = "also ok", file = "c.lua", line = 2 },
      },
    })
    assert.is_not_nil(tour)
    assert.equals(2, #tour.steps)
    assert.equals(2, #tour.skipped)
  end)
end)

describe("player anchor degradation", function()
  before_each(function()
    config.setup({})
  end)
  after_each(function()
    pcall(player.stop)
  end)

  it("warns on an unresolved anchor but keeps navigating", function()
    local tour = model.normalize({
      title = "Unresolved",
      steps = {
        { description = "first", file = "src/example.lua", line = 2 },
        -- pattern that matches nothing in the file -> unresolved
        { description = "second", file = "src/example.lua", pattern = "ZZZ_NO_SUCH_LINE_ZZZ" },
        { description = "third", file = "src/example.lua", line = 3 },
      },
    })

    local captured = capture_notify(function()
      player.start(tour, { root = repo, step = 2 })
    end)
    -- The unresolved anchor surfaces a warning naming the step.
    local text = notify_text(captured)
    assert.is_true(text:lower():find("anchor", 1, true) ~= nil or text:lower():find("resolve", 1, true) ~= nil)

    -- Navigation still works from the degraded step.
    assert.has_no.errors(function()
      player.next()
      player.prev()
    end)
  end)
end)

describe("player missing-file degradation (carried over from NCT-001)", function()
  before_each(function()
    config.setup({})
  end)
  after_each(function()
    pcall(player.stop)
  end)

  it("notifies file-not-found instead of silently opening an empty buffer", function()
    local tour = model.normalize({
      title = "Ghost",
      steps = {
        { description = "points at nothing", file = "src/does_not_exist.lua", line = 3 },
      },
    })

    vim.cmd("enew")
    local before_buf = vim.api.nvim_get_current_buf()

    local captured = capture_notify(function()
      player.start(tour, { root = repo, step = 1 })
    end)

    local text = notify_text(captured)
    assert.is_true(text:lower():find("not found", 1, true) ~= nil)
    assert.is_true(text:find("does_not_exist.lua", 1, true) ~= nil)

    -- It did not silently open the phantom file into a buffer.
    local name = vim.api.nvim_buf_get_name(vim.api.nvim_get_current_buf())
    assert.is_nil(name:find("does_not_exist.lua", 1, true))
    -- And it certainly didn't crash; the buffer we were on is still around.
    assert.is_true(vim.api.nvim_buf_is_valid(before_buf))
  end)
end)

describe("player view degradation", function()
  before_each(function()
    config.setup({})
  end)
  after_each(function()
    pcall(player.stop)
  end)

  it("an unsupported view degrades to rendering the description (no error)", function()
    local tour = model.normalize({
      title = "Viewy",
      steps = {
        { description = "look at the terminal", view = "terminal" },
      },
    })

    local captured
    assert.has_no.errors(function()
      captured = capture_notify(function()
        player.start(tour, { root = repo, step = 1 })
      end)
    end)
    -- It degrades visibly: a notice mentions the unsupported view.
    local text = notify_text(captured)
    assert.is_true(text:lower():find("view", 1, true) ~= nil)
  end)
end)

describe("markdown inert specials", function()
  it("renders >> shell commands as inert text (no actionable link)", function()
    local parsed = markdown.parse(">> npm install && rm -rf /")
    assert.same({}, parsed.links)
    -- The text is preserved verbatim for the reader; nothing is parsed to run.
    assert.is_true(parsed.lines[1]:find("npm install", 1, true) ~= nil)
  end)

  it("renders a code-injection block as inert text", function()
    local desc = "Insert this:\n```js\nrequire('child_process').exec('boom')\n```"
    local parsed = markdown.parse(desc)
    assert.same({}, parsed.links)
  end)

  it("renders command: link targets inert in both forms", function()
    -- Parenthesized file form.
    assert.same({}, markdown.parse("[run](command:workbench.action.terminal.new)").links)
    -- Bare bracket form must not become an actionable tour link.
    assert.same({}, markdown.parse("[command:workbench.action.terminal.new]").links)
  end)
end)

describe("player end-to-end no-crash on a malformed tour", function()
  before_each(function()
    config.setup({})
  end)
  after_each(function()
    pcall(player.stop)
  end)

  it("plays a tour full of degraded steps without ever erroring", function()
    local tour = model.normalize({
      title = "Kitchen Sink",
      steps = {
        { description = "missing file", file = "src/nope.lua", line = 1 },
        { description = "bad pattern", file = "src/example.lua", pattern = "(((" },
        { description = "unsupported view", view = "scm" },
        { description = "inert specials\n>> rm -rf /\n[x](command:do.it)", file = "src/example.lua", line = 2 },
        { description = "content only" },
      },
    })

    assert.has_no.errors(function()
      capture_notify(function()
        player.start(tour, { root = repo, step = 1 })
        player.next()
        player.next()
        player.next()
        player.next()
        player.prev()
      end)
    end)
  end)
end)
