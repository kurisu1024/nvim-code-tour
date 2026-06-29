-- <Plug> mappings for user-defined bindings.
--
-- The plugin sets NO global keymaps by default (the tour keys in config.keymaps
-- are buffer-local, applied only while a tour is playing). For users who want
-- their own global bindings, we expose `<Plug>(codetour-*)` targets they can map
-- to any key. Registering these binds nothing to a real key on its own.

local M = {}

-- <Plug> name -> entry point. Each defers `require` so mapping registration at
-- bootstrap never forces the whole plugin to load.
M.mappings = {
  ["<Plug>(codetour-next)"] = function()
    require("codetour").next()
  end,
  ["<Plug>(codetour-prev)"] = function()
    require("codetour").prev()
  end,
  ["<Plug>(codetour-stop)"] = function()
    require("codetour").stop()
  end,
  ["<Plug>(codetour-resume)"] = function()
    require("codetour").resume()
  end,
  ["<Plug>(codetour-list)"] = function()
    require("codetour").list()
  end,
  ["<Plug>(codetour-follow)"] = function()
    require("codetour.player").follow_cursor()
  end,
}

-- Register every <Plug> target as a normal-mode mapping. Idempotent: vim.keymap
-- .set overwrites, so calling twice is harmless.
function M.register()
  for lhs, rhs in pairs(M.mappings) do
    vim.keymap.set("n", lhs, rhs, { silent = true, desc = "codetour " .. lhs })
  end
end

return M
