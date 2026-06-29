-- Minimal init for headless plenary test runs.
-- Puts this plugin and plenary.nvim on the runtimepath, nothing else.

-- PlenaryBustedDirectory runs spec files as parallel headless nvim jobs. Several
-- specs `:edit` the same fixture (tests/fixtures/repo/src/example.lua) at once,
-- so leaving swapfiles on produces an E325 swap conflict in whichever process
-- loses the race — that file then opens without honouring the requested cursor
-- position, intermittently failing cursor-line assertions. No headless test ever
-- wants a swapfile; turn them off so fixture edits are deterministic.
vim.o.swapfile = false

local function add_to_rtp(path)
  if path and vim.uv.fs_stat(path) then
    vim.opt.runtimepath:append(path)
    return true
  end
  return false
end

-- This plugin: tests/ -> repo root.
local here = debug.getinfo(1, "S").source:sub(2)
local repo_root = vim.fn.fnamemodify(here, ":h:h")
add_to_rtp(repo_root)

-- plenary.nvim — try the usual install locations, then fall back to scanning
-- packpath. One of these must succeed or PlenaryBustedDirectory won't exist.
local data = vim.fn.stdpath("data")
local candidates = {
  data .. "/lazy/plenary.nvim",
  data .. "/site/pack/packer/start/plenary.nvim",
  data .. "/site/pack/vendor/start/plenary.nvim",
  vim.fn.expand("~/.local/share/nvim/lazy/plenary.nvim"),
}
local found = false
for _, c in ipairs(candidates) do
  if add_to_rtp(c) then
    found = true
    break
  end
end
if not found then
  error("plenary.nvim not found on this machine; set one of the candidate paths in tests/minimal_init.lua")
end

vim.cmd("runtime plugin/plenary.vim")
vim.cmd("runtime plugin/codetour.lua")
