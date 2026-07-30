local config = require("zj-theme.config")
local sync = require("zj-theme.sync")

local M = {}

-- `set-pane-color` (used by pane_bg.lua) was added in this zellij release.
local MIN_ZELLIJ_VERSION = { 0, 44, 0 }

local function version_str(v)
  return ("%d.%d.%d"):format(v[1], v[2], v[3])
end

-- Pulls the first `X.Y.Z` out of `zellij --version` output (e.g.
-- "zellij 0.44.1"). Returns nil if none is found. Exposed for tests.
function M.parse_zellij_version(output)
  local major, minor, patch = (output or ""):match("(%d+)%.(%d+)%.(%d+)")
  if not major then
    return nil
  end
  return { tonumber(major), tonumber(minor), tonumber(patch) }
end

-- Exposed for tests.
function M.zellij_version_at_least(version, minimum)
  for i = 1, 3 do
    if version[i] ~= minimum[i] then
      return version[i] > minimum[i]
    end
  end
  return true
end

local function zellij_version()
  local result = vim.system({ "zellij", "--version" }, { text = true }):wait(2000)
  if result.code ~= 0 then
    return nil
  end
  return M.parse_zellij_version(result.stdout)
end

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

  if config.options.sync_pane_backgrounds == false then
    vim.health.info("sync_pane_backgrounds is disabled; no pane's background will be synced")
    return
  end

  if vim.fn.executable("zellij") == 1 then
    vim.health.ok("`zellij` CLI found on PATH — pane backgrounds can be synced")

    local version = zellij_version()
    if not version then
      vim.health.warn("couldn't determine the zellij version from `zellij --version`", {
        ("Pane background sync needs zellij >= %s (for `set-pane-color`)"):format(version_str(MIN_ZELLIJ_VERSION)),
      })
    elseif M.zellij_version_at_least(version, MIN_ZELLIJ_VERSION) then
      vim.health.ok(("zellij %s supports `set-pane-color`"):format(version_str(version)))
    else
      vim.health.error(
        ("zellij %s is too old for pane background sync (needs >= %s)"):format(
          version_str(version),
          version_str(MIN_ZELLIJ_VERSION)
        ),
        { "Upgrade zellij, or set sync_pane_backgrounds = false to silence this" }
      )
    end

    local interval = config.options.pane_poll_interval_ms
    if interval and interval > 0 then
      vim.health.info(("New panes are picked up within %dms (pane_poll_interval_ms)"):format(interval))
    else
      vim.health.info(
        "pane_poll_interval_ms <= 0; panes created between colorscheme "
          .. "switches won't be synced until the next one"
      )
    end
  else
    vim.health.error("`zellij` CLI not found on PATH; pane backgrounds can't be synced", {
      "Install zellij, or set sync_pane_backgrounds = false to silence this",
    })
  end
end

return M
