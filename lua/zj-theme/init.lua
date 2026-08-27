local config = require("zj-theme.config")
local sync = require("zj-theme.sync")
local terminal = require("zj-theme.terminal")

local M = {}

local function apply_all()
  sync.apply(vim.g.colors_name)
  terminal.apply(vim.g.colors_name)
end

function M.setup(opts)
  config.setup(opts)

  local augroup = vim.api.nvim_create_augroup("ZjTheme", { clear = true })

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = augroup,
    callback = apply_all,
  })

  -- Sync the already-active colorscheme once nvim finishes starting.
  vim.api.nvim_create_autocmd("VimEnter", {
    group = augroup,
    once = true,
    callback = apply_all,
  })
end

function M.sync_now()
  apply_all()
end

return M
