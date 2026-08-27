local mappings = require("zj-theme.mappings")

local M = {}

M.defaults = {
  -- zellij's config.kdl. Rewritten in place; zellij's own file watch picks
  -- it up live.
  zellij_config_path = vim.fn.expand("~/.config/zellij/config.kdl"),

  -- Fallback zellij themes, picked by vim.o.background.
  default_dark_theme = "default",
  default_light_theme = "pencil-light",

  -- nvim colorscheme -> zellij theme. Merged over mappings.lua's defaults.
  mappings = {},

  -- Terminal emulator to also keep in sync — see terminals/*.lua and
  -- README's Terminal emulator theme section.
  terminal = {
    emulator = nil, -- nil disables this channel

    -- nil uses the adapter's default_config_path.
    config_path = nil,

    -- alacritty only. nil uses the adapter's default_themes_dir.
    themes_dir = nil,

    -- Same shape as `mappings`, merged per-lookup (adapter can change).
    mappings = {},

    -- Same semantics as above.
    default_dark_theme = nil,
    default_light_theme = nil,
  },

  -- Set to false to silence vim.notify warnings/errors.
  notify = true,
}

M.options = vim.deepcopy(M.defaults)

-- Lets :checkhealth tell "never configured" apart from "configured with
-- all defaults".
M.did_setup = false

function M.setup(opts)
  opts = opts or {}
  M.did_setup = true

  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts)
  M.options.mappings = vim.tbl_deep_extend("force", vim.deepcopy(mappings.defaults), opts.mappings or {})
end

return M
