local M = {}

-- Verified against wezterm.get_builtin_color_schemes() — some scheme names
-- have "(Gogh)"/"(base16)" suffixes and only exact strings resolve.
-- Override via terminal.mappings. Value can be { dark=, light= }, same as
-- mappings.lua.

local solarized = { dark = "Builtin Solarized Dark", light = "Builtin Solarized Light" }

M.default_mappings = {
  -- Catppuccin
  ["catppuccin"] = "catppuccin-mocha",
  ["catppuccin-mocha"] = "catppuccin-mocha",
  ["catppuccin-macchiato"] = "catppuccin-macchiato",
  ["catppuccin-frappe"] = "catppuccin-frappe",
  ["catppuccin-latte"] = "catppuccin-latte",

  -- Gruvbox (wezterm has no distinct "material" variant; reuse plain gruvbox)
  ["gruvbox"] = { dark = "GruvboxDark", light = "GruvboxLight" },
  ["gruvbox-material"] = { dark = "GruvboxDark", light = "GruvboxLight" },

  -- Tokyonight (wezterm, unlike zellij, has all four variants for real)
  ["tokyonight"] = "tokyonight_night",
  ["tokyonight-night"] = "tokyonight_night",
  ["tokyonight-storm"] = "tokyonight_storm",
  ["tokyonight-moon"] = "tokyonight_moon",
  ["tokyonight-day"] = "tokyonight_day",

  -- Nightfox
  ["nightfox"] = "nightfox",
  ["dayfox"] = "dayfox",
  ["carbonfox"] = "carbonfox",

  -- Ayu
  ["ayu"] = { dark = "ayu", light = "ayu_light" },
  ["ayu-dark"] = "ayu",
  ["ayu-light"] = "ayu_light",
  ["ayu-mirage"] = "Ayu Mirage",

  -- Solarized
  ["solarized"] = solarized,
  ["solarized8"] = solarized,
  ["solarized8_flat"] = solarized,
  ["solarized8_high"] = solarized,
  ["solarized8_low"] = solarized,

  -- One-dark
  ["onedark"] = "OneDark (Gogh)",
  ["onehalfdark"] = "OneHalfDark",

  -- Others
  ["nord"] = "nord",
  ["dracula"] = "Dracula",
  ["kanagawa"] = "kanagawa (Gogh)",
  ["everforest"] = { dark = "EverforestDark (Gogh)", light = "EverforestLight (Gogh)" },
  ["PaperColor"] = "PaperColorLight (Gogh)",
}

-- Guaranteed present in any wezterm version.
M.default_dark_theme = "Builtin Solarized Dark"
M.default_light_theme = "Builtin Solarized Light"

M.default_config_path = vim.fn.expand("~/.config/wezterm/zj-theme.lua")

-- Writes `return "<scheme name>"`. Needs README's require()/reload-watch wiring.
function M.write(path, theme)
  local lines = {
    "-- Managed by zj-theme.nvim -- do not edit by hand, changes are overwritten.",
    ('return "%s"'):format(theme:gsub('"', '\\"')),
  }
  return vim.fn.writefile(lines, path) == 0
end

return M
