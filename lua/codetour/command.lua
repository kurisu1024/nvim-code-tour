-- `:CodeTour <sub>` dispatch + completion. The Lua API (codetour/init) is the
-- real surface; this just routes subcommands to it.

local M = {}

-- `end` maps to stop() (reads better as a user verb; avoids the Lua keyword).
local SUBCOMMANDS = { "start", "next", "prev", "goto", "resume", "end", "list", "focus", "renderer" }

-- Renderer modes, for completing `:CodeTour renderer <mode>`.
local RENDERERS = { "float", "float-anchored", "split" }

-- Tab-completion: complete subcommands, or renderer modes after `renderer`.
-- Exposed so the surface is unit-testable without driving the command line.
function M.complete(arglead, line)
  if line and line:match("%srenderer%s+%S*$") then
    return vim.tbl_filter(function(name)
      return vim.startswith(name, arglead or "")
    end, RENDERERS)
  end
  return vim.tbl_filter(function(name)
    return vim.startswith(name, arglead or "")
  end, SUBCOMMANDS)
end

function M.dispatch(fargs)
  local ct = require("codetour")
  local sub = fargs[1] or "start"
  if sub == "start" then
    ct.start()
  elseif sub == "next" then
    ct.next()
  elseif sub == "prev" then
    ct.prev()
  elseif sub == "goto" then
    ct["goto"](tonumber(fargs[2]) or 1)
  elseif sub == "resume" then
    ct.resume()
  elseif sub == "end" then
    ct.stop()
  elseif sub == "list" then
    ct.list()
  elseif sub == "focus" then
    ct.focus()
  elseif sub == "renderer" then
    ct.set_renderer(fargs[2])
  else
    vim.notify("codetour: unknown subcommand '" .. sub .. "'", vim.log.levels.WARN)
  end
end

function M.register()
  vim.api.nvim_create_user_command("CodeTour", function(opts)
    M.dispatch(opts.fargs)
  end, {
    nargs = "*",
    force = true, -- plugin/ bootstrap + setup() both register; don't E174 on the second
    desc = "Play CodeTour .tour files",
    complete = function(arglead, line)
      return M.complete(arglead, line)
    end,
  })
end

return M
