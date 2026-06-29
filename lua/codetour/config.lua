-- Plugin configuration: defaults plus a merged active table.

local M = {}

M.defaults = {
  tour_dir = nil, -- extra dir beyond the conventional locations
  -- Active renderer: "float" (fixed narrator float, A), "float-anchored" (float
  -- pinned near the anchored line, B), or "split" (narrator in a split, C).
  -- Switchable live mid-tour via `:CodeTour renderer <mode>`.
  renderer = "float",
  float = { position = "bottom", width = 0.5, height = 0.3, hint = true },
  default_keymaps = true, -- buffer-local maps during a tour
  -- `focus` toggles between the code window and the narrator; `help` is reserved.
  keymaps = { next = "]t", prev = "[t", follow = "<CR>", stop = "q", focus = "]f", help = "g?" },
  markdown_renderer = "auto",
}

local options = vim.deepcopy(M.defaults)

function M.setup(opts)
  options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
  return options
end

function M.get()
  return options
end

return M
