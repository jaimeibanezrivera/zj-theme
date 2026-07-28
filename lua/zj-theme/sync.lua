local config = require("zj-theme.config")

local M = {}

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

function M.in_zellij_session()
  return vim.env.ZELLIJ ~= nil and vim.env.ZELLIJ ~= ""
end

-- Some colorscheme plugins (e.g. Shatur/neovim-ayu) set the same
-- vim.g.colors_name regardless of vim.o.background, so a plain string
-- mapping can't distinguish their light/dark variants. For those, a
-- mapping value can be { dark = "...", light = "..." } instead of a string,
-- resolved via the current background.
function M.resolve_theme(colors_name)
  if not colors_name or colors_name == "" then
    return nil
  end

  local mapped = config.options.mappings[colors_name]
  if type(mapped) == "table" then
    if vim.o.background == "light" then
      return mapped.light or mapped.dark
    end
    return mapped.dark or mapped.light
  end
  return mapped
end

-- vim.o.background is the standard signal colorscheme plugins set
-- correctly almost universally, so an unmapped/failed dark colorscheme
-- falls back to a dark zellij theme instead of a jarring light one (or
-- vice versa).
function M.default_theme()
  if vim.o.background == "light" then
    return config.options.default_light_theme
  end
  return config.options.default_dark_theme
end

-- Read-only inspection of the zellij config file, shared by write_theme()
-- and :checkhealth so the "does it exist / does it have a theme line" logic
-- lives in exactly one place. Never writes anything.
function M.config_file_status(path)
  path = path or config.options.zellij_config_path

  if vim.fn.filereadable(path) ~= 1 then
    return { exists = false, has_theme_line = false }
  end

  local has_theme_line = false
  for _, line in ipairs(vim.fn.readfile(path)) do
    if line:match('^theme%s+".+"$') then
      has_theme_line = true
      break
    end
  end

  return { exists = true, has_theme_line = has_theme_line }
end

-- Rewrites the `theme "..."` line in zellij's config.kdl in place. zellij
-- watches its config file for changes (a ~1s poll) and applies them to the
-- current session automatically, so this takes effect live, no restart
-- needed.
local function write_theme(theme)
  local path = config.options.zellij_config_path
  local status = M.config_file_status(path)

  if not status.exists then
    notify_once(
      "no_config_file",
      ("zellij config not found or not readable at '%s'"):format(path),
      vim.log.levels.ERROR
    )
    return false
  end

  if not status.has_theme_line then
    notify_once(
      "no_theme_line",
      ("no `theme \"...\"` line found in '%s'; add one so it can be updated"):format(path),
      vim.log.levels.ERROR
    )
    return false
  end

  local lines = vim.fn.readfile(path)
  for i, line in ipairs(lines) do
    if line:match('^theme%s+".+"$') then
      lines[i] = string.format('theme "%s"', theme)
      break
    end
  end

  local write_failed = vim.fn.writefile(lines, path) ~= 0
  if write_failed then
    notify_once("write_failed", ("failed writing '%s'"):format(path), vim.log.levels.ERROR)
    return false
  end

  warned["no_config_file"] = nil
  warned["no_theme_line"] = nil
  warned["write_failed"] = nil
  return true
end

function M.apply(colors_name)
  if not M.in_zellij_session() then
    return
  end

  local theme = M.resolve_theme(colors_name)
  local fallback = M.default_theme()
  if not theme then
    notify_once(
      "unmapped:" .. tostring(colors_name),
      ("no zellij theme mapped for colorscheme '%s'; falling back to '%s'"):format(colors_name, fallback)
    )
    theme = fallback
  end

  if not write_theme(theme) and theme ~= fallback then
    write_theme(fallback)
  end
end

return M
