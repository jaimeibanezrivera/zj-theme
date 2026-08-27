local config = require("zj-theme.config")

local M = {}

-- One adapter per supported terminal — see lua/zj-theme/terminals/*.lua.
local adapters = {
  wezterm = require("zj-theme.terminals.wezterm"),
  alacritty = require("zj-theme.terminals.alacritty"),
}

local warned = {}

local function notify(msg, level)
  if config.options.notify == false then
    return
  end
  vim.notify(("[zj-theme] %s"):format(msg), level or vim.log.levels.WARN)
end

local function notify_once(key, msg, level)
  if warned[key] then
    return
  end
  warned[key] = true
  notify(msg, level)
end

-- Exposed for tests so warning state doesn't leak between cases.
function M.reset_warnings()
  warned = {}
end

-- nil if terminal.emulator is unset or unknown (warned once).
function M.adapter()
  local name = config.options.terminal.emulator
  if not name then
    return nil
  end

  local adapter = adapters[name]
  if not adapter then
    notify_once(
      "unknown_emulator:" .. name,
      ("terminal.emulator '%s' is not supported (known: %s)"):format(name, table.concat(vim.tbl_keys(adapters), ", ")),
      vim.log.levels.ERROR
    )
  end
  return adapter
end

-- Falls back to the adapter's default_config_path when unset.
function M.config_path(adapter)
  local path = config.options.terminal.config_path
  if not path or path == "" then
    path = adapter and adapter.default_config_path
  end
  if not path or path == "" then
    return nil
  end
  return vim.fn.expand(path)
end

-- Same shape as sync.resolve_theme. terminal.mappings wins over the
-- adapter's default_mappings.
function M.resolve_theme(adapter, colors_name)
  if not colors_name or colors_name == "" then
    return nil
  end

  local mapped = config.options.terminal.mappings[colors_name]
  if mapped == nil then
    mapped = adapter.default_mappings[colors_name]
  end

  if type(mapped) == "table" then
    if vim.o.background == "light" then
      return mapped.light or mapped.dark
    end
    return mapped.dark or mapped.light
  end
  return mapped
end

function M.default_theme(adapter)
  if vim.o.background == "light" then
    return config.options.terminal.default_light_theme or adapter.default_light_theme
  end
  return config.options.terminal.default_dark_theme or adapter.default_dark_theme
end

-- pcall catches vim.fn.writefile throwing (e.g. missing parent dir), and
-- adapter.write's optional reason string alongside a `false` result.
local function write_theme(adapter, path, theme)
  local call_ok, result, reason = pcall(adapter.write, path, theme)
  local write_ok = call_ok and result
  local err = call_ok and reason or result

  if not write_ok then
    local msg = ("failed writing '%s'"):format(path)
    if err then
      msg = msg .. (": %s"):format(err)
    end
    notify_once("write_failed", msg, vim.log.levels.ERROR)
    return false
  end

  warned["write_failed"] = nil
  return true
end

-- No-op when unset. No zellij-session gate, unlike sync.apply() — the
-- terminal is there regardless.
function M.apply(colors_name)
  local adapter = M.adapter()
  if not adapter then
    return
  end

  local path = M.config_path(adapter)
  if not path then
    notify_once(
      "no_config_path",
      "terminal.config_path must be set when terminal.emulator is set — see README's Terminal emulator theme section",
      vim.log.levels.ERROR
    )
    return
  end

  local theme = M.resolve_theme(adapter, colors_name)
  local fallback = M.default_theme(adapter)
  if not theme then
    notify_once(
      "unmapped:" .. tostring(colors_name),
      ("no %s theme mapped for colorscheme '%s'; falling back to '%s'"):format(
        config.options.terminal.emulator,
        colors_name,
        fallback
      )
    )
    theme = fallback
  end

  if not write_theme(adapter, path, theme) and theme ~= fallback then
    write_theme(adapter, path, fallback)
  end
end

return M
