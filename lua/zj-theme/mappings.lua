local M = {}

-- nvim colors_name -> zellij theme name. Verified against zellij's actual
-- theme files (zellij-utils/assets/themes/*.kdl), not its theme-list docs
-- page, which has real errors. Override via setup({ mappings = {...} }).
--
-- A value can be { dark = "...", light = "..." } for colorschemes that
-- keep colors_name constant across light/dark, still respecting
-- vim.o.background for their actual palette.

-- zellij has one solarized-dark/solarized-light pair; solarized8's
-- flat/high/low contrast variants have no zellij equivalent, so all five
-- colorscheme names below share this same mapping.
local solarized = { dark = "solarized-dark", light = "solarized-light" }

M.defaults = {
  -- Catppuccin
  ["catppuccin"] = "catppuccin-mocha",
  ["catppuccin-mocha"] = "catppuccin-mocha",
  ["catppuccin-macchiato"] = "catppuccin-macchiato",
  ["catppuccin-frappe"] = "catppuccin-frappe",
  ["catppuccin-latte"] = "catppuccin-latte",

  -- Gruvbox
  ["gruvbox"] = { dark = "gruvbox-dark", light = "gruvbox-light" },
  ["gruvbox-material"] = { dark = "gruvbox-dark", light = "gruvbox-light" },

  -- Tokyonight
  ["tokyonight"] = "tokyo-night-dark",
  ["tokyonight-night"] = "tokyo-night-dark",
  ["tokyonight-storm"] = "tokyo-night-storm",
  ["tokyonight-moon"] = "tokyo-night-dark",
  ["tokyonight-day"] = "iceberg-light", -- tokyo-night-light is broken upstream (near-black bg)

  -- Nightfox
  ["nightfox"] = "nightfox",
  ["dayfox"] = "dayfox",
  ["carbonfox"] = "default", -- I think it looks really cool with it :)

  -- Ayu
  ["ayu"] = { dark = "ayu-dark", light = "ayu-light" },
  ["ayu-dark"] = "ayu-dark",
  ["ayu-light"] = "ayu-light",
  ["ayu-mirage"] = "ayu-mirage",

  -- Solarized
  ["solarized"] = solarized,
  ["solarized8"] = solarized,
  ["solarized8_flat"] = solarized,
  ["solarized8_high"] = solarized,
  ["solarized8_low"] = solarized,

  -- One-dark
  ["onedark"] = "onedark",
  ["onehalfdark"] = "one-half-dark",

  -- Others
  ["nord"] = "nord",
  ["dracula"] = "dracula",
  ["kanagawa"] = "kanagawa",
  ["everforest"] = { dark = "everforest-dark", light = "everforest-light" },
  ["PaperColor"] = "pencil-light",
}

return M
