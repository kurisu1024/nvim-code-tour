-- Pure / headless tests for the telescope picker adapter.
--
-- Telescope is NOT required to load or exercise the picker's list/selection
-- logic: requiring the module, formatting entries, and dispatching a selection
-- are all pure and must work with no telescope on the runtimepath. The telescope
-- UI itself (pick) is the only part that touches telescope, and it is guarded.

local picker = require("codetour.ui.picker")

local function meta(t)
  return vim.tbl_extend("force", {
    path = "/tmp/x.tour",
    title = "Tour",
    step_count = 1,
    is_primary = false,
  }, t or {})
end

describe("picker.format", function()
  it("shows the title and a pluralized step count", function()
    assert.equals("Walkthrough  [3 steps]", picker.format(meta({ title = "Walkthrough", step_count = 3 })))
  end)

  it("uses the singular form for a one-step tour", function()
    local out = picker.format(meta({ title = "Solo", step_count = 1 }))
    assert.is_true(out:find("1 step", 1, true) ~= nil)
    assert.is_nil(out:find("1 steps", 1, true))
  end)

  it("marks the primary tour", function()
    local out = picker.format(meta({ title = "1 - Onboarding", step_count = 2, is_primary = true }))
    assert.is_true(out:find("(primary)", 1, true) ~= nil)
  end)

  it("flags a broken tour", function()
    local out = picker.format(meta({ title = "Bad", step_count = 2, broken = true }))
    assert.is_true(out:find("(broken)", 1, true) ~= nil)
  end)
end)

describe("picker.build_entries", function()
  it("builds one entry per tour, carrying the originating meta", function()
    local tours = { meta({ title = "A", step_count = 2 }), meta({ title = "B", step_count = 5 }) }
    local entries = picker.build_entries(tours)

    assert.equals(2, #entries)
    assert.equals(tours[1], entries[1].tour)
    assert.equals(tours[2], entries[2].tour)
    assert.is_true(entries[1].display:find("A", 1, true) ~= nil)
    assert.is_true(entries[1].display:find("2 steps", 1, true) ~= nil)
    assert.is_true(entries[2].display:find("5 steps", 1, true) ~= nil)
  end)

  it("tolerates an empty / nil tour list", function()
    assert.same({}, picker.build_entries({}))
    assert.same({}, picker.build_entries(nil))
  end)
end)

describe("picker.select", function()
  it("hands a playable tour to on_select", function()
    local m = meta({ title = "Playable" })
    local got
    local ok = picker.select(m, function(chosen)
      got = chosen
    end)
    assert.is_true(ok)
    assert.equals(m, got)
  end)

  it("does not start a broken tour; it notifies instead", function()
    local called = false
    local original = vim.notify
    local notified = false
    vim.notify = function()
      notified = true
    end
    local ok = picker.select(meta({ title = "Broken", broken = true }), function()
      called = true
    end)
    vim.notify = original

    assert.is_false(ok)
    assert.is_false(called)
    assert.is_true(notified)
  end)
end)

describe("picker.available", function()
  it("never errors and reports telescope's presence as a boolean", function()
    local ok, result = pcall(picker.available)
    assert.is_true(ok)
    assert.equals("boolean", type(result))
  end)
end)
