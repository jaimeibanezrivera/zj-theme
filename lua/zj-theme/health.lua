local config = require("zj-theme.config")
local sync = require("zj-theme.sync")
local terminal = require("zj-theme.terminal")

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
        .. "the zellij-theme channel is a no-op until you're inside one"
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

  if not config.options.terminal.emulator then
    vim.health.info("terminal.emulator is unset; the terminal-theme channel is disabled")
    return
  end

  local adapter = terminal.adapter()
  if not adapter then
    vim.health.error(("terminal.emulator '%s' is not supported"):format(config.options.terminal.emulator), {
      "Use one of the adapters in lua/zj-theme/terminals/ (currently: wezterm, alacritty)",
    })
    return
  end

  vim.health.ok(("terminal.emulator '%s' is supported"):format(config.options.terminal.emulator))

  local term_path = terminal.config_path(adapter)
  if not term_path then
    vim.health.error("terminal.config_path is not set — required once terminal.emulator is", {
      "Set terminal.config_path in setup() — see README's Terminal emulator theme section",
    })
    return
  end

  local dir = vim.fn.fnamemodify(term_path, ":h")
  if vim.fn.isdirectory(dir) == 1 then
    vim.health.ok(("this plugin writes the resolved theme to '%s'"):format(term_path))
  else
    vim.health.error(("directory '%s' does not exist; can't write '%s'"):format(dir, term_path), {
      "Create that directory, or point terminal.config_path somewhere that exists",
    })
  end

  if colors_name and colors_name ~= "" then
    local term_theme = terminal.resolve_theme(adapter, colors_name)
    if term_theme then
      vim.health.ok(
        ("colorscheme '%s' is mapped to %s theme '%s'"):format(
          colors_name,
          config.options.terminal.emulator,
          term_theme
        )
      )
    else
      vim.health.warn(
        ("colorscheme '%s' has no %s mapping; will fall back to '%s'"):format(
          colors_name,
          config.options.terminal.emulator,
          terminal.default_theme(adapter)
        ),
        { "Add an entry to terminal.mappings in setup(), or accept the fallback" }
      )
    end
  end
end

return M
