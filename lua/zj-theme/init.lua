local config = require("zj-theme.config")
local sync = require("zj-theme.sync")

local M = {}

function M.setup(opts)
  config.setup(opts)

  local augroup = vim.api.nvim_create_augroup("ZjTheme", { clear = true })

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = augroup,
    callback = function()
      sync.apply(vim.g.colors_name)
    end,
  })

  -- Sync whatever colorscheme is already active once nvim finishes starting,
  -- so zellij matches even if the user never switches colorschemes again.
  vim.api.nvim_create_autocmd("VimEnter", {
    group = augroup,
    once = true,
    callback = function()
      sync.apply(vim.g.colors_name)
    end,
  })
end

function M.sync_now()
  sync.apply(vim.g.colors_name)
end

return M
