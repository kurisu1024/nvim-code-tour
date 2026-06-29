-- Resolve a tour's `ref` and compare it to current HEAD, reporting drift.
--
-- WARN-ONLY by contract: this module NEVER mutates the working tree. It issues
-- only read-only `git rev-parse` queries through an injected runner, so it is
-- fully testable without a real repo and can never check out, reset, or switch.
--
-- status(ref, opts) -> {
--   state   = "match" | "drift" | "no-repo",
--   ref     = <recorded ref>,
--   branch  = <current branch or "HEAD" when detached>,   -- present unless no-repo
--   head    = <current HEAD sha>,                          -- present unless no-repo
--   ref_sha = <resolved sha of ref, or nil if unresolvable>,
-- }
--   opts.cwd    : directory to run git in (defaults to the process cwd)
--   opts.runner : fn(args, cwd) -> { code, stdout, stderr } (defaults to vim.system)
--
-- States:
--   match   — ref resolves to the same commit as HEAD; anchors are trustworthy.
--   drift   — ref resolves to a different commit, or can't be resolved locally.
--   no-repo — not a git repo (HEAD unresolvable), no ref, or git unavailable.
--             The caller ignores `ref` silently in this case.

local M = {}

local function trim(s)
  return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Default runner: a thin, read-only wrapper over `git` via vim.system. Any
-- failure to even launch git degrades to a non-zero result rather than throwing.
function M.default_runner(args, cwd)
  local cmd = { "git" }
  for _, a in ipairs(args) do
    table.insert(cmd, a)
  end
  local ok, res = pcall(function()
    return vim.system(cmd, { cwd = cwd, text = true }):wait()
  end)
  if not ok or type(res) ~= "table" then
    return { code = 127, stdout = "", stderr = "git unavailable" }
  end
  return { code = res.code or 0, stdout = res.stdout or "", stderr = res.stderr or "" }
end

-- Invoke the runner defensively: a throwing or malformed runner must degrade,
-- never crash playback.
local function run(runner, args, cwd)
  local ok, res = pcall(runner, args, cwd)
  if not ok or type(res) ~= "table" then
    return { code = 127, stdout = "", stderr = "runner error" }
  end
  return res
end

local function ok_code(res)
  return (res.code or 0) == 0
end

function M.status(ref, opts)
  opts = opts or {}
  local runner = opts.runner or M.default_runner
  local cwd = opts.cwd

  ref = trim(ref)
  if ref == "" then
    -- No ref to compare against — nothing to warn about.
    return { state = "no-repo", ref = ref }
  end

  -- HEAD resolution doubles as the "is there a repo?" probe.
  local head = run(runner, { "rev-parse", "HEAD" }, cwd)
  if not ok_code(head) then
    return { state = "no-repo", ref = ref }
  end
  local head_sha = trim(head.stdout)

  local br = run(runner, { "rev-parse", "--abbrev-ref", "HEAD" }, cwd)
  local branch = ok_code(br) and trim(br.stdout) or ""
  if branch == "" then
    branch = "HEAD" -- detached or unknown
  end

  local refrev = run(runner, { "rev-parse", ref }, cwd)
  local ref_sha = ok_code(refrev) and trim(refrev.stdout) or nil

  -- Same commit => trustworthy. Different commit, or a ref we can't resolve
  -- locally, both mean "you are not where this tour was recorded" => drift.
  local state = (ref_sha and ref_sha == head_sha) and "match" or "drift"

  return {
    state = state,
    ref = ref,
    branch = branch,
    head = head_sha,
    ref_sha = ref_sha,
  }
end

-- A single, non-blocking line describing the drift, for vim.notify.
function M.drift_message(status)
  return string.format(
    "codetour: recorded at %s; you're on %s — anchors may have drifted",
    status.ref or "?",
    status.branch or "?"
  )
end

return M
