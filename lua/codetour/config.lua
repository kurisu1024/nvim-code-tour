-- Plugin configuration: defaults plus a merged active table.

local M = {}

M.defaults = {
  tour_dir = nil, -- extra dir beyond the conventional locations
  float = { position = "bottom", width = 0.5, height = 0.3 },
  default_keymaps = true, -- buffer-local maps during a tour
  keymaps = { next = "]t", prev = "[t", follow = "<CR>", stop = "q", help = "g?" },
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
