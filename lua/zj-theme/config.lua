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
