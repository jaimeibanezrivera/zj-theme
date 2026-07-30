local mappings = require("zj-theme.mappings")

local M = {}

M.defaults = {
  -- Path to zellij's config.kdl. This plugin rewrites its `theme "..."`
  -- line directly; zellij watches this file and picks up the change live
  -- (see README).
  zellij_config_path = vim.fn.expand("~/.config/zellij/config.kdl"),

  -- zellij themes to fall back to when the current nvim colorscheme has no
  -- mapping, or when writing to zellij_config_path fails. Picked based on
  -- vim.o.background, so an unmapped dark colorscheme doesn't dump you into
  -- a light zellij theme or vice versa.
  default_dark_theme = "default",
  default_light_theme = "pencil-light",

  -- nvim colors_name -> zellij theme name. Merged over the built-in
  -- defaults in mappings.lua, so you only need to specify overrides/additions.
  mappings = {},

  -- Whether to push the current colorscheme's bg/fg to every pane in the
  -- zellij session, including the one nvim itself is running in, via
  -- `zellij action set-pane-color` (requires zellij >= 0.44.0 and the
  -- `zellij` CLI on PATH). Set to false to leave every pane's background
  -- alone.
  sync_pane_backgrounds = true,

  -- How often (ms) to poll for newly created zellij panes and color them
  -- to match the current colorscheme — otherwise a pane opened after a
  -- `:colorscheme` switch keeps zellij's default background until the next
  -- one. Set to 0 to disable polling (panes are still synced on every
  -- colorscheme change, just not when a new pane appears in between).
  pane_poll_interval_ms = 1000,

  -- Whether to vim.notify on fallback/errors. Set to false to silence.
  notify = true,
}

M.options = vim.deepcopy(M.defaults)

-- M.options is always populated (even without setup()), so this flag is
-- what :checkhealth uses to tell "never configured" apart from "configured
-- with all defaults".
M.did_setup = false

function M.setup(opts)
  opts = opts or {}
  M.did_setup = true

  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts)
  M.options.mappings = vim.tbl_deep_extend("force", vim.deepcopy(mappings.defaults), opts.mappings or {})
end

return M
