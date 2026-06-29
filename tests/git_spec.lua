-- core.git: resolve a tour's `ref` and compare to HEAD, reporting drift.
--
-- Tested entirely through an injected fake runner — no real repo, no
-- subprocess. The runner contract is fn(args, cwd) -> { code, stdout, stderr }.

local git = require("codetour.core.git")

-- A fake runner keyed on the space-joined git args. Unknown commands fail like
-- git would (non-zero) so the module's degrade paths get exercised.
local function fake_runner(responses)
  return function(args)
    local key = table.concat(args, " ")
    local r = responses[key]
    if not r then
      return { code = 128, stdout = "", stderr = "unknown: " .. key }
    end
    return { code = r.code or 0, stdout = r.stdout or "", stderr = r.stderr or "" }
  end
end

describe("core.git.status", function()
  it("reports match when ref resolves to the same commit as HEAD", function()
    local runner = fake_runner({
      ["rev-parse HEAD"] = { stdout = "abc123\n" },
      ["rev-parse --abbrev-ref HEAD"] = { stdout = "main\n" },
      ["rev-parse main"] = { stdout = "abc123\n" },
    })

    local s = git.status("main", { runner = runner })

    assert.equals("match", s.state)
    assert.equals("main", s.ref)
  end)

  it("reports drift when ref resolves to a different commit than HEAD", function()
    local runner = fake_runner({
      ["rev-parse HEAD"] = { stdout = "deadbeef\n" },
      ["rev-parse --abbrev-ref HEAD"] = { stdout = "feature\n" },
      ["rev-parse v1.0"] = { stdout = "cafef00d\n" },
    })

    local s = git.status("v1.0", { runner = runner })

    assert.equals("drift", s.state)
    assert.equals("feature", s.branch)
    assert.equals("v1.0", s.ref)
  end)

  it("reports drift when the recorded ref can't be resolved locally", function()
    local runner = fake_runner({
      ["rev-parse HEAD"] = { stdout = "deadbeef\n" },
      ["rev-parse --abbrev-ref HEAD"] = { stdout = "main\n" },
      -- no entry for the ref => non-zero, unresolvable
    })

    local s = git.status("gone-branch", { runner = runner })

    assert.equals("drift", s.state)
  end)

  it("reports no-repo when HEAD cannot be resolved (not a git repo)", function()
    local runner = fake_runner({
      ["rev-parse HEAD"] = { code = 128, stderr = "fatal: not a git repository" },
    })

    local s = git.status("main", { runner = runner })

    assert.equals("no-repo", s.state)
  end)

  it("treats a nil/empty ref as nothing to compare (no-repo)", function()
    local called = false
    local runner = function()
      called = true
      return { code = 0, stdout = "x\n" }
    end

    local s = git.status(nil, { runner = runner })

    assert.equals("no-repo", s.state)
    assert.is_false(called) -- short-circuits without touching git
  end)

  it("never issues a working-tree-mutating git command", function()
    local seen = {}
    local runner = function(args)
      table.insert(seen, table.concat(args, " "))
      if args[1] == "rev-parse" then
        return { code = 0, stdout = "sha\n" }
      end
      return { code = 0, stdout = "" }
    end

    git.status("main", { runner = runner })

    assert.is_true(#seen > 0)
    for _, cmd in ipairs(seen) do
      assert.equals("rev-parse", cmd:match("^%S+")) -- only read-only rev-parse
      assert.is_nil(cmd:find("checkout", 1, true))
      assert.is_nil(cmd:find("switch", 1, true))
      assert.is_nil(cmd:find("reset", 1, true))
    end
  end)

  it("degrades to no-repo when the runner throws", function()
    local runner = function()
      error("boom")
    end

    local s = git.status("main", { runner = runner })

    assert.equals("no-repo", s.state)
  end)
end)

describe("core.git.drift_message", function()
  it("names the recorded ref and the current branch and warns of drift", function()
    local msg = git.drift_message({ state = "drift", ref = "abc123", branch = "main" })

    assert.is_true(msg:find("abc123", 1, true) ~= nil)
    assert.is_true(msg:find("main", 1, true) ~= nil)
    assert.is_true(msg:find("drift", 1, true) ~= nil)
  end)
end)
