-- The Renderer seam.
--
-- A renderer presents a step view and can tear itself down. Three impls slot in
-- behind one contract, selected by `config.renderer` and switchable live:
--   "float"          (A) fixed-position narrator float        ui/float
--   "float-anchored" (B) float pinned near the anchored line  ui/float (opt)
--   "split"          (C) narrator in a horizontal split       ui/split
--
-- Renderer interface:
--   present(view)   view = { lines, links, counter, title, keymaps, anchor, actions }
--   focus()         move focus into the narrator window
--   close()
--
-- A step view's `actions` table carries the player callbacks the renderer wires
-- to buffer-local maps: { next, prev, stop, follow, focus_code }.

local float = require("codetour.ui.float")
local split = require("codetour.ui.split")

local M = {}

-- The selectable renderer modes (also the completion list for :CodeTour renderer).
M.modes = { "float", "float-anchored", "split" }

function M.is_mode(mode)
  return mode == "float" or mode == "float-anchored" or mode == "split"
end

-- Construct the renderer for a mode (defaults to the configured / fixed float).
function M.new(mode)
  if mode == "split" then
    return split.new()
  elseif mode == "float-anchored" then
    return float.new({ placement = "anchored" })
  end
  return float.new({ placement = "fixed" })
end

return M
