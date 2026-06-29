-- The conductor: one active tour, the real public surface.
--
-- Holds the playback state and runs the navigation spine on every move:
--   anchor (skeleton: file+line) -> codewin.open -> highlight.apply
--   -> markdown.parse -> renderer.present
--
-- In-session resume: stop() tears down the UI but keeps the tour + step in
-- memory so resume() re-enters where you left off.

local config = require("codetour.config")
local anchor = require("codetour.core.anchor")
local discovery = require("codetour.core.discovery")
local git = require("codetour.core.git")
local json = require("codetour.core.json")
local markdown = require("codetour.core.markdown")
local model = require("codetour.core.model")
local codewin = require("codetour.ui.codewin")
local highlight = require("codetour.ui.highlight")
local renderer = require("codetour.ui.renderer")

local M = {}

local state = {
  tour = nil,
  index = 0,
  root = nil,
  code_win = nil,
  hl_buf = nil, -- buffer currently carrying the line highlight
  map_buf = nil, -- buffer currently carrying nav maps
  renderer = nil,
  drift_notified = false, -- one git-ref drift notice per activation
}

-- When the tour pins a `ref`, compare it to HEAD and emit a single non-blocking
-- notice on drift. Read-only and never mutates the tree (see core.git). The
-- check runs at most once per activation: the flag is set up front so a slow or
-- failing git call can never re-fire on every navigation, and match / no-repo
-- stay silent.
local function maybe_notify_drift()
  if state.drift_notified then
    return
  end
  local ref = state.tour and state.tour.ref
  if not ref or ref == "" then
    return
  end
  state.drift_notified = true
  local ok, status = pcall(git.status, ref, { cwd = state.root })
  if not ok or type(status) ~= "table" then
    return
  end
  if status.state == "drift" then
    vim.notify(git.drift_message(status), vim.log.levels.WARN)
  end
end

local function clear_maps()
  if state.map_buf and vim.api.nvim_buf_is_valid(state.map_buf) then
    local km = config.get().keymaps
    for _, lhs in ipairs({ km.next, km.prev, km.stop, km.focus }) do
      if lhs then
        pcall(vim.keymap.del, "n", lhs, { buffer = state.map_buf })
      end
    end
  end
  state.map_buf = nil
end

local function set_maps(buf)
  clear_maps()
  if not config.get().default_keymaps then
    return
  end
  local km = config.get().keymaps
  local opts = { nowait = true, silent = true }
  vim.keymap.set("n", km.next, M.next, vim.tbl_extend("force", { buffer = buf }, opts))
  vim.keymap.set("n", km.prev, M.prev, vim.tbl_extend("force", { buffer = buf }, opts))
  vim.keymap.set("n", km.stop, M.stop, vim.tbl_extend("force", { buffer = buf }, opts))
  if km.focus then
    vim.keymap.set("n", km.focus, M.focus, vim.tbl_extend("force", { buffer = buf }, opts))
  end
  state.map_buf = buf
end

local function teardown_ui()
  if state.hl_buf then
    highlight.clear(state.hl_buf)
    state.hl_buf = nil
  end
  clear_maps()
  if state.renderer then
    state.renderer:close()
    state.renderer = nil
  end
end

-- Drop the line highlight carried by the previous step, wherever it landed.
local function clear_highlight()
  if state.hl_buf then
    highlight.clear(state.hl_buf)
    state.hl_buf = nil
  end
end

-- Open a file-anchored step's resolution (line or selection) in the code window.
local function render_code(step, resolution)
  local sel = resolution.selection
  local col = sel and math.max(0, (sel.start.character or 1) - 1) or 0
  local buf, win = codewin.open(state.code_win, state.root, step.file, resolution.line, col)
  if buf and win then
    state.code_win = win -- codewin may have resolved a different, usable window
    clear_highlight()
    highlight.clear(buf)
    if resolution.kind == "selection" then
      highlight.apply_selection(buf, sel)
    elseif resolution.line then
      highlight.apply(buf, resolution.line)
    end
    state.hl_buf = buf
    set_maps(buf)
  else
    -- No safe window to open into; narrate only, drop any stale anchor, but
    -- still wire nav keys on whatever buffer the user is looking at.
    clear_highlight()
    set_maps(vim.api.nvim_get_current_buf())
  end
end

-- Resolve a workspace-relative step.file to an absolute path (the CodeTour spec
-- makes file paths relative to the root). Shared by pattern reading and the
-- missing-file guard so both agree on what "the file" means.
local function resolve_path(file)
  local path = file
  if state.root and not vim.startswith(path, "/") then
    path = state.root .. "/" .. path
  end
  return vim.fn.fnamemodify(path, ":p")
end

-- Does a file-anchored step point at something that actually exists on disk?
local function file_exists(file)
  return vim.fn.filereadable(resolve_path(file)) == 1
end

-- A single, consistently-formatted degradation notice that always names the
-- offending step number (the "notify" leg of "degrade, notify, continue").
local function notify_step(msg)
  vim.notify(string.format("codetour: step %d: %s", state.index, msg), vim.log.levels.WARN)
end

-- Pattern steps need the file's lines to scan; read them lazily (only when a
-- pattern actually has to be resolved) so line/selection steps stay I/O-free.
local function pattern_lines(step)
  if step.type ~= "file" or not step.file or step.pattern == nil or step.line ~= nil then
    return nil
  end
  local ok, lines = pcall(vim.fn.readfile, resolve_path(step.file))
  return ok and lines or nil
end

-- Load + normalize a tour file off disk. Resilient: a vanished/unreadable/bad
-- file yields nil, never an error (tour-link/chain resolution then notifies).
local function load_tour(path)
  local read_ok, lines = pcall(vim.fn.readfile, path)
  if not read_ok then
    return nil
  end
  local ok, raw = json.decode(table.concat(lines, "\n"))
  if not ok then
    return nil
  end
  return (model.normalize(raw)) -- drop the error tail; nil is enough here
end

-- Resolve a tour by title against the discovered set under the active root and
-- start it at `step`. Returns true when a tour was started. Shared by tour-ref
-- links and `nextTour` chaining (one tour-resolution path, per the design).
local function follow_tour(title, step)
  if not title or title == "" or not state.root then
    return false
  end
  local tours = discovery.find(state.root, { tour_dir = config.get().tour_dir })
  for _, meta in ipairs(tours) do
    if meta.title == title then
      local tour = load_tour(meta.path)
      if tour then
        M.start(tour, { root = state.root, step = step })
        return true
      end
    end
  end
  vim.notify("codetour: tour not found: " .. title, vim.log.levels.WARN)
  return false
end

-- Open a file-ref target in the code window with no anchor (cursor at the top).
-- Path is workspace-relative per the CodeTour spec; codewin handles resolution
-- and window safety. Never executes anything.
local function open_file(path)
  if not path or path == "" then
    return
  end
  local _, win = codewin.open(state.code_win, state.root, path, nil, 0)
  if win then
    state.code_win = win
  end
end

-- Directory step (fast-follow): open the directory listing in the code window.
-- Root-relative per the spec; whatever directory handler is installed (netrw,
-- neo-tree, oil…) takes it from there. Missing dirs degrade with a notice.
local function open_directory(dir)
  local abs = resolve_path(dir)
  if vim.fn.isdirectory(abs) ~= 1 then
    notify_step("directory " .. dir .. " not found")
    return
  end
  local _, win = codewin.open(state.code_win, state.root, dir, nil, 0)
  if win then
    state.code_win = win
  end
end

-- The opener for external uri steps; injectable so tests can capture without
-- spawning a browser. Defaults to vim.ui.open (Neovim 0.10+).
M._opener = function(target)
  if vim.ui and type(vim.ui.open) == "function" then
    pcall(vim.ui.open, target)
  end
end

-- uri step (fast-follow): a file:// uri opens the file in the code window; any
-- other scheme is handed to the external opener (browser, etc.) with a notice.
-- Never executes shell — vim.ui.open is the OS "open" handler, not a command.
local function open_uri(uri)
  local file_path = uri:match("^file://(.*)$")
  if file_path then
    open_file(vim.uri_decode and vim.uri_decode(file_path) or file_path)
    return
  end
  notify_step("opening external uri " .. uri)
  M._opener(uri)
end

-- Dispatch a markdown link action selected via `<CR>` in the narrator float.
-- Degrade-notify-continue: an unknown or malformed action is simply ignored.
function M.follow(action)
  if type(action) ~= "table" then
    return
  end
  if action.kind == "step" then
    M["goto"](action.step)
  elseif action.kind == "tour" then
    follow_tour(action.title, action.step or 1)
  elseif action.kind == "file" then
    open_file(action.path)
  end
end

-- Follow the markdown link under the narrator-float cursor. Drives the active
-- renderer's hit-test (the float owns link geometry); a no-op when no tour is
-- active or the renderer has no such affordance. Backs `<Plug>(codetour-follow)`.
function M.follow_cursor()
  local r = state.renderer
  if r and type(r.follow_under_cursor) == "function" then
    r:follow_under_cursor()
  end
end

-- Move focus into the narrator window. Bound to `keymaps.focus` on the code
-- buffer; the renderer mirrors the same key to return focus here (a toggle).
-- A no-op when the renderer has no focusable window (or none is open yet).
function M.focus()
  local r = state.renderer
  if r and type(r.focus) == "function" then
    r:focus()
  end
end

-- Return focus to the code window. The renderer binds this to `keymaps.focus`
-- on its own buffer so the same key toggles back. Falls back to the current
-- window's nearest usable code window via codewin's own safety net.
local function focus_code()
  if state.code_win and vim.api.nvim_win_is_valid(state.code_win) then
    pcall(vim.api.nvim_set_current_win, state.code_win)
  end
end

-- Render the current step end to end.
local function render()
  maybe_notify_drift()
  local step = state.tour.steps[state.index]
  local resolution = anchor.resolve(step, pattern_lines(step))

  if resolution.kind == "content" or not step.file then
    -- Non-file step: no code anchor in a normal buffer. directory/uri steps act
    -- on the side (open the dir / hand the uri to the OS); content and unknown
    -- view steps just narrate. Either way nav maps go on the current buffer so
    -- ]t/[t/q work without having to focus the float.
    if step.type == "directory" and step.directory then
      open_directory(step.directory)
    elseif step.type == "uri" and step.uri then
      open_uri(step.uri)
    elseif step.view ~= nil and step.view ~= "" then
      -- An unsupported `view` is not an anchor we can honor; degrade to narrating
      -- the description — but visibly, with a notice.
      notify_step("unsupported view '" .. tostring(step.view) .. "'; showing description")
    end
    clear_highlight()
    set_maps(vim.api.nvim_get_current_buf())
  elseif not file_exists(step.file) then
    -- A file step pointing at a path that doesn't exist must not silently open
    -- an empty [New File] buffer (NCT-001 carry-over): notify and narrate only.
    notify_step("file " .. step.file .. " not found")
    clear_highlight()
    set_maps(vim.api.nvim_get_current_buf())
  else
    -- An anchor the resolver couldn't pin (e.g. a pattern that matched nothing)
    -- degrades to the file's top with a warning; navigation keeps working.
    if resolution.kind == "unresolved" then
      local detail = resolution.reason and (" (" .. resolution.reason .. ")") or ""
      notify_step("could not resolve anchor in " .. step.file .. detail)
    end
    render_code(step, resolution)
  end

  local parsed = markdown.parse(step.description)
  state.renderer:present({
    lines = parsed.lines,
    links = parsed.links,
    counter = string.format("%d/%d", state.index, #state.tour.steps),
    title = step.title,
    keymaps = config.get().keymaps,
    -- Where the code landed, for anchored (mode B) placement. nil for steps with
    -- no code location (content/directory/uri); fixed/split renderers ignore it.
    anchor = (resolution.line and state.code_win) and { win = state.code_win, line = resolution.line } or nil,
    actions = { next = M.next, prev = M.prev, stop = M.stop, follow = M.follow, focus_code = focus_code },
  })
end

-- start(tour, opts) — opts: { root, step }
function M.start(tour, opts)
  if not tour then
    return
  end
  opts = opts or {}
  teardown_ui()
  state.tour = tour
  state.index = 0
  state.drift_notified = false
  state.root = opts.root or vim.fn.getcwd()
  -- Preferred code window; codewin.open re-resolves if it isn't usable.
  state.code_win = vim.api.nvim_get_current_win()
  state.renderer = renderer.new(config.get().renderer)
  M["goto"](opts.step or 1)
end

-- Swap the active renderer mid-tour and re-draw the current step, so the modes
-- can be compared side by side without restarting. Persists the choice in config
-- so subsequent tours use it too. Backs `:CodeTour renderer <mode>`.
function M.set_renderer(mode)
  if not renderer.is_mode(mode) then
    vim.notify("codetour: unknown renderer '" .. tostring(mode) .. "'", vim.log.levels.WARN)
    return
  end
  config.setup({ renderer = mode })
  if not state.tour then
    return -- no active tour; the next start() picks up the new mode
  end
  if state.renderer then
    state.renderer:close()
  end
  state.renderer = renderer.new(mode)
  render()
end

-- `goto` is a Lua reserved word; the index form is portable across runtimes.
M["goto"] = function(n)
  if not state.tour then
    return
  end
  local total = #state.tour.steps
  if total == 0 then
    return
  end
  state.index = math.max(1, math.min(n, total))
  if not state.renderer then
    state.renderer = renderer.new(config.get().renderer)
  end
  render()
end

function M.next()
  if not state.tour then
    return
  end
  -- At the end of a tour that names a successor, chain onward by title through
  -- the same tour-resolution path as a tour-ref link.
  if state.index >= #state.tour.steps then
    local next_tour = state.tour.nextTour
    if next_tour and next_tour ~= "" and follow_tour(next_tour, 1) then
      return
    end
  end
  M["goto"](state.index + 1)
end

function M.prev()
  M["goto"](state.index - 1)
end

-- Tear down the UI but keep tour + step for resume().
function M.stop()
  teardown_ui()
end

function M.resume()
  if not state.tour then
    vim.notify("codetour: no tour to resume", vim.log.levels.INFO)
    return
  end
  -- Keep a still-valid code window; only fall back to the current one if the
  -- retained handle is gone (codewin.open makes the final safe choice anyway).
  if not (state.code_win and vim.api.nvim_win_is_valid(state.code_win)) then
    state.code_win = vim.api.nvim_get_current_win()
  end
  state.renderer = renderer.new(config.get().renderer)
  M["goto"](state.index < 1 and 1 or state.index)
end

return M
