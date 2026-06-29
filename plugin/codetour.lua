-- Bootstrap: register :CodeTour at startup so it works before setup().
-- Lazy — registration touches no disk; discovery only runs when the user acts.

if vim.g.loaded_codetour then
  return
end
vim.g.loaded_codetour = true

require("codetour.command").register()
-- <Plug> targets only — no global keys are bound (the tour keys are buffer-local).
require("codetour.plug").register()
