local config = require("zj-theme.config")
local sync = require("zj-theme.sync")

local M = {}

function M.check()
  vim.health.start("zj-theme")

  if config.did_setup then
    vim.health.ok("setup() has been called")
  else
    vim.health.warn(
      "setup() has not been called yet — the built-in mappings/defaults are active, "
        .. "but the ColorScheme/VimEnter autocmds are not registered",
      { "Call require('zj-theme').setup() in your config" }
    )
  end

  if sync.in_zellij_session() then
    vim.health.info("Running inside a zellij session ($ZELLIJ set)")
  else
    vim.health.info(
      "Not running inside a zellij session ($ZELLIJ unset) — this is normal outside zellij; "
        .. "sync is a no-op until you're inside one"
    )
  end

  local path = config.options.zellij_config_path
  local status = sync.config_file_status(path)

  if not status.exists then
    vim.health.error(("zellij config not found or not readable at '%s'"):format(path), {
      "Check zellij_config_path in setup()",
      "Make sure zellij has been run at least once to generate config.kdl",
    })
  else
    vim.health.ok(("zellij config found at '%s'"):format(path))

    if status.has_theme_line then
      vim.health.ok('theme "..." line found — this plugin can rewrite it')
    else
      vim.health.error(("no theme \"...\" line found in '%s'; add one manually so it can be managed"):format(path), {
        'Add a line like: theme "default"',
      })
    end
  end

  local colors_name = vim.g.colors_name
  if not colors_name or colors_name == "" then
    vim.health.info("No colorscheme currently active (vim.g.colors_name unset); nothing to check yet")
  else
    local theme = sync.resolve_theme(colors_name)
    if theme then
      vim.health.ok(("colorscheme '%s' is mapped to zellij theme '%s'"):format(colors_name, theme))
    else
      vim.health.warn(
        ("colorscheme '%s' has no mapping; will fall back to '%s'"):format(colors_name, sync.default_theme()),
        { "Add an entry to mappings in setup(), or accept the fallback" }
      )
    end
  end
end

return M
