local M = {}

-- Alacritty has no built-in schemes — these are filenames (sans ".toml")
-- from alacritty/alacritty-theme's themes/. Override via terminal.mappings.
-- Value can be { dark=, light= }, same as mappings.lua.

local solarized = { dark = "solarized_dark", light = "solarized_light" }

M.default_mappings = {
  -- Catppuccin
  ["catppuccin"] = "catppuccin_mocha",
  ["catppuccin-mocha"] = "catppuccin_mocha",
  ["catppuccin-macchiato"] = "catppuccin_macchiato",
  ["catppuccin-frappe"] = "catppuccin_frappe",
  ["catppuccin-latte"] = "catppuccin_latte",

  -- Gruvbox (no plain "light" material variant upstream; reuse gruvbox_light)
  ["gruvbox"] = { dark = "gruvbox_dark", light = "gruvbox_light" },
  ["gruvbox-material"] = { dark = "gruvbox_material", light = "gruvbox_light" },

  -- Tokyonight (no distinct "moon" file upstream; falls back to tokyo_night)
  ["tokyonight"] = "tokyo_night",
  ["tokyonight-night"] = "tokyo_night",
  ["tokyonight-storm"] = "tokyo_night_storm",
  ["tokyonight-moon"] = "tokyo_night",
  ["tokyonight-day"] = "tokyo_night_light",

  -- Nightfox
  ["nightfox"] = "nightfox",
  ["dayfox"] = "dayfox",
  ["carbonfox"] = "carbonfox",

  -- Ayu
  ["ayu"] = { dark = "ayu_dark", light = "ayu_light" },
  ["ayu-dark"] = "ayu_dark",
  ["ayu-light"] = "ayu_light",
  ["ayu-mirage"] = "ayu_mirage",

  -- Solarized
  ["solarized"] = solarized,
  ["solarized8"] = solarized,
  ["solarized8_flat"] = solarized,
  ["solarized8_high"] = solarized,
  ["solarized8_low"] = solarized,

  -- One-dark (onehalfdark has no accurate upstream file, left unmapped)
  ["onedark"] = "one_dark",

  -- Others
  ["nord"] = "nord",
  ["dracula"] = "dracula",
  ["kanagawa"] = "kanagawa_wave",
  ["everforest"] = { dark = "everforest_dark", light = "everforest_light" },
  ["PaperColor"] = "papercolor_light",
}

M.default_dark_theme = "solarized_dark"
M.default_light_theme = "solarized_light"

M.default_config_path = vim.fn.expand("~/.config/alacritty/zj-theme.toml")

-- Matches the README's `ln -s alacritty-theme/themes ~/.config/alacritty/themes`.
M.default_themes_dir = vim.fn.expand("~/.config/alacritty/themes")

-- Writes a `general.import` pointing at "<themes_dir>/<theme>.toml". Reads
-- themes_dir straight off config.lua — it's specific to this adapter.
function M.write(path, theme)
  local themes_dir = require("zj-theme.config").options.terminal.themes_dir or M.default_themes_dir
  if not themes_dir or themes_dir == "" then
    return false, "terminal.themes_dir must be set when terminal.emulator = 'alacritty'"
  end

  local theme_path = (vim.fn.expand(themes_dir):gsub("/$", "")) .. "/" .. theme .. ".toml"

  local lines = {
    "# Managed by zj-theme.nvim -- do not edit by hand, changes are overwritten.",
    "[general]",
    ('import = ["%s"]'):format(theme_path:gsub('"', '\\"')),
  }
  return vim.fn.writefile(lines, path) == 0
end

return M
