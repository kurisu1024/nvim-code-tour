-- Integration: the player fires a single, non-blocking git-drift notice on the
-- first activation of a tour that declares a `ref`. The git runner is faked, so
-- no real repo is touched and the working tree is never mutated.

local model = require("codetour.core.model")
local player = require("codetour.player")
local git = require("codetour.core.git")

local here = debug.getinfo(1, "S").source:sub(2)
local fixtures = vim.fn.fnamemodify(here, ":h") .. "/fixtures/repo"

local function tour_with_ref(ref)
  return model.normalize({
    title = "Ref Tour",
    ref = ref,
    steps = {
      { description = "one", file = "src/example.lua", line = 2 },
      { description = "two", file = "src/example.lua", line = 6 },
    },
  })
end

-- Swap the module-default git runner and capture vim.notify for the duration of
-- a test. Returns a list that collects every drift notice the player emits.
local function with_git(responses, body)
  local saved_runner = git.default_runner
  local saved_notify = vim.notify
  local drift_notices = {}

  git.default_runner = function(args)
    local key = table.concat(args, " ")
    local r = responses[key]
    if not r then
      return { code = 128, stdout = "", stderr = "unknown" }
    end
    return { code = r.code or 0, stdout = r.stdout or "", stderr = r.stderr or "" }
  end
  vim.notify = function(msg)
    if type(msg) == "string" and msg:find("recorded at", 1, true) then
      table.insert(drift_notices, msg)
    end
  end

  local ok, err = pcall(body, drift_notices)

  git.default_runner = saved_runner
  vim.notify = saved_notify
  if not ok then
    error(err)
  end
end

local DRIFT = {
  ["rev-parse HEAD"] = { stdout = "headsha\n" },
  ["rev-parse --abbrev-ref HEAD"] = { stdout = "main\n" },
  ["rev-parse abc123"] = { stdout = "abc123sha\n" },
}
local MATCH = {
  ["rev-parse HEAD"] = { stdout = "samesha\n" },
  ["rev-parse --abbrev-ref HEAD"] = { stdout = "main\n" },
  ["rev-parse abc123"] = { stdout = "samesha\n" },
}
local NO_REPO = {
  ["rev-parse HEAD"] = { code = 128, stderr = "not a git repository" },
}

describe("player git-ref drift notice", function()
  after_each(function()
    pcall(player.stop)
  end)

  it("warns once when the tour ref differs from HEAD", function()
    with_git(DRIFT, function(notices)
      player.start(tour_with_ref("abc123"), { root = fixtures, step = 1 })
      assert.equals(1, #notices)
      assert.is_true(notices[1]:find("abc123", 1, true) ~= nil)
      assert.is_true(notices[1]:find("main", 1, true) ~= nil)
    end)
  end)

  it("warns only once per activation across multiple navigations", function()
    with_git(DRIFT, function(notices)
      player.start(tour_with_ref("abc123"), { root = fixtures, step = 1 })
      player.next()
      player.prev()
      player["goto"](2)
      assert.equals(1, #notices)
    end)
  end)

  it("does not warn when the ref matches HEAD", function()
    with_git(MATCH, function(notices)
      player.start(tour_with_ref("abc123"), { root = fixtures, step = 1 })
      player.next()
      assert.equals(0, #notices)
    end)
  end)

  it("does not warn when there is no git repo", function()
    with_git(NO_REPO, function(notices)
      player.start(tour_with_ref("abc123"), { root = fixtures, step = 1 })
      player.next()
      assert.equals(0, #notices)
    end)
  end)

  it("does not warn for a tour without a ref", function()
    with_git(DRIFT, function(notices)
      player.start(tour_with_ref(nil), { root = fixtures, step = 1 })
      player.next()
      assert.equals(0, #notices)
    end)
  end)
end)
