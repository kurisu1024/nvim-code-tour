-- The Renderer seam.
--
-- A renderer presents a step view and can tear itself down. The MVP impl is the
-- fixed-position narrator float (ui/float). Line-anchored (B) and split (C)
-- renderers drop in behind this same contract later.
--
-- Renderer interface:
--   present(view)   view = { lines, counter, title, keymaps, actions }
--   close()
--
-- A step view's `actions` table carries the player callbacks the renderer wires
-- to buffer-local maps: { next, prev, stop, follow }.

local float = require("codetour.ui.float")

local M = {}

-- Construct the configured renderer. Only the float exists for now.
function M.new()
  return float.new()
end

return M
