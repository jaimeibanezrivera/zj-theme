local config = require("zj-theme.config")
local sync = require("zj-theme.sync")
local pane_bg = require("zj-theme.pane_bg")
local osc = require("zj-theme.osc")

local M = {}

local function apply_all()
  sync.apply(vim.g.colors_name)
  pane_bg.apply()
  osc.apply()
end

function M.setup(opts)
  config.setup(opts)

  -- Reconcile the poll timer with the (possibly new) config: a prior
  -- setup() call may have started one under different settings, and
  -- VimEnter — which normally starts it — only fires once, so it won't
  -- run again to pick up a second setup() call's changes on its own.
  pane_bg.stop_polling()
  if vim.v.vim_did_enter == 1 then
    pane_bg.start_polling()
  end

  local augroup = vim.api.nvim_create_augroup("ZjTheme", { clear = true })

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = augroup,
    callback = apply_all,
  })

  -- Sync whatever colorscheme is already active once nvim finishes starting,
  -- so zellij matches even if the user never switches colorschemes again.
  -- Also starts polling for panes created after this point (see
  -- pane_poll_interval_ms) — otherwise a pane opened after a colorscheme
  -- switch would keep zellij's default background until the next one.
  vim.api.nvim_create_autocmd("VimEnter", {
    group = augroup,
    once = true,
    callback = function()
      apply_all()
      pane_bg.start_polling()
    end,
  })

  -- Resets every pane this plugin recolored — the current one (via raw
  -- terminal escapes) and every other one (via the zellij CLI) — back to
  -- the terminal's/zellij's own defaults.
  vim.api.nvim_create_autocmd({ "VimLeavePre", "VimSuspend" }, {
    group = augroup,
    callback = function()
      pane_bg.stop_polling()
      pane_bg.reset()
      osc.reset()
    end,
  })

  -- Undoes the VimSuspend handling above: resume syncing and polling once
  -- nvim is foregrounded again.
  vim.api.nvim_create_autocmd("VimResume", {
    group = augroup,
    callback = function()
      apply_all()
      pane_bg.start_polling()
    end,
  })
end

function M.sync_now()
  apply_all()
end

return M
