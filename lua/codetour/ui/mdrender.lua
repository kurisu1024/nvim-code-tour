-- Markdown-renderer selection for the narrator float.
--
-- The float buffer is always `filetype=markdown`, which gives Treesitter
-- highlighting out of the box. When an optional prettifier plugin
-- (render-markdown.nvim / markview.nvim) is installed, we let it decorate the
-- float instead. This module owns only the *decision* — which is pure and unit
-- tested — plus a fully guarded best-effort `apply`. The optional plugins are a
-- soft dependency: they are never required at load time and their absence is the
-- normal case (Treesitter is the floor).

local M = {}

-- Optional providers, in auto-detect priority order.
M.providers = { "render-markdown", "markview" }

-- Default availability probe: is the plugin module loadable right now? Guarded so
-- a missing dependency never raises.
local function default_has(name)
  return (pcall(require, name)) == true
end

-- select(value, has?) -> "render-markdown" | "markview" | "treesitter"
--
--   value = config.markdown_renderer:
--     "auto"        -> first installed provider, else "treesitter"
--     "treesitter"  -> always treesitter (opt out of prettifiers)
--     "<provider>"  -> that provider when installed, else "treesitter"
--     nil/false     -> treated as "auto"
--
-- `has` is an injectable predicate (name -> bool) so the decision is testable
-- without the plugins present.
function M.select(value, has)
  has = has or default_has
  if value == nil then
    value = "auto"
  end
  if value == "treesitter" or value == false then
    return "treesitter"
  end
  if value == "auto" then
    for _, name in ipairs(M.providers) do
      if has(name) then
        return name
      end
    end
    return "treesitter"
  end
  -- Explicit provider name: honor it only if actually installed.
  if has(value) then
    return value
  end
  return "treesitter"
end

-- apply(buf, choice): let the chosen renderer decorate `buf`. Treesitter needs
-- nothing beyond the float's `filetype=markdown`. The optional plugins are poked
-- best-effort and fully guarded, so an absent or erroring plugin can never break
-- playback. Returns the choice for convenience.
function M.apply(buf, choice)
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    return choice
  end
  if choice == "render-markdown" then
    pcall(function()
      require("render-markdown").enable()
    end)
  elseif choice == "markview" then
    pcall(function()
      require("markview").render(buf, { enable = true })
    end)
  end
  return choice
end

return M
