# zj-theme.nvim

[![CI](https://github.com/jaimeibanezrivera/zj-theme/actions/workflows/ci.yml/badge.svg)](https://github.com/jaimeibanezrivera/zj-theme/actions/workflows/ci.yml)

Sync your zellij theme to whatever colorscheme is active in neovim.

It rewrites zellij's config file directly. zellij watches that file for
changes and applies them to your already-running session automatically
(zellij polls it roughly once a second), so this takes effect live — no
restart needed.

Requires Neovim >= 0.10 (for the `vim.health.*` API used by `:checkhealth`).
See also `:help zj-theme`.

## How it works

1. A `ColorScheme` autocmd fires whenever you run `:colorscheme ...` (or a
   plugin sets one on your behalf).
2. The new `vim.g.colors_name` is looked up in a mapping table (built-in
   defaults + anything you add) to find the corresponding zellij theme name.
3. The `theme "..."` line in zellij's `config.kdl` is rewritten in place with
   that theme name.
4. If any step fails — the colorscheme has no mapping, the config file isn't
   readable, or it has no `theme` line to rewrite — it falls back to a
   configurable default zellij theme instead of leaving things inconsistent.

## Installation

### lazy.nvim

```lua
-- For `plugins/zj-theme.lua` users.
return {
  "jaimeibanezrivera/zj-theme",
  lazy = false,
  config = function()
    require("zj-theme").setup({
      -- see Configuration below
    })
  end,
}
```

```lua
-- For `plugins.lua` users.
{
  "jaimeibanezrivera/zj-theme",
  lazy = false,
  config = function()
    require("zj-theme").setup({
      -- see Configuration below
    })
  end,
}
```
### packer.nvim

```lua
use({
  "jaimeibanezrivera/zj-theme",
  config = function()
    require("zj-theme").setup({
      -- see Configuration below
    })
  end,
})
```

### vim-plug

```vim
Plug 'jaimeibanezrivera/zj-theme'
```

Then, elsewhere in your `init.vim`/`init.lua` (vim-plug has no per-plugin
config callback):

```lua
lua require("zj-theme").setup({
  -- see Configuration below
})
```

### mini.deps

```lua
local MiniDeps = require("mini.deps")

MiniDeps.add({ source = "jaimeibanezrivera/zj-theme" })

MiniDeps.now(function()
  require("zj-theme").setup({
    -- see Configuration below
  })
end)
```

### vim.pack (Neovim >= 0.12, built in, no plugin manager needed)

```lua
vim.pack.add({ "https://github.com/jaimeibanezrivera/zj-theme" })

require("zj-theme").setup({
  -- see Configuration below
})
```

### Local development (no plugin manager, this repo checked out on disk)

```lua
{
  dir = "~/path/to/zj-theme.nvim",
  config = function()
    require("zj-theme").setup({
      -- see Configuration below
    })
  end,
}
```

## Configuration

```lua
require("zj-theme").setup({
  -- Path to zellij's config.kdl. Defaults to ~/.config/zellij/config.kdl.
  zellij_config_path = vim.fn.expand("~/.config/zellij/config.kdl"),

  -- zellij themes to fall back to when the current colorscheme has no
  -- mapping, or when writing zellij_config_path fails. Picked based on
  -- vim.o.background so a dark colorscheme doesn't fall back to a light
  -- zellij theme or vice versa.
  default_dark_theme = "default",
  default_light_theme = "pencil-light",

  -- nvim colors_name -> zellij theme name. Merged over the built-in table
  -- in lua/zj-theme/mappings.lua, so you only need overrides/additions.
  -- A value can also be { dark = "...", light = "..." } for colorschemes
  -- that keep vim.g.colors_name the same across light/dark (ayu.nvim,
  -- gruvbox-material, everforest-nvim all do this, and are already handled
  -- by the bundled defaults) — resolved via the current vim.o.background.
  mappings = {
    mycustomtheme = "my-zellij-theme-name",
    myflexibletheme = { dark = "my-dark-zellij-theme", light = "my-light-zellij-theme" },
  },

  -- Set to false to silence vim.notify warnings/errors.
  notify = true,
})
```

Your `config.kdl` needs an actual (uncommented) `theme "..."` line already
present for this plugin to find and rewrite — it won't add one from
scratch.

### On the zellij side

Whatever `"my-zellij-theme-name"` you map a colorscheme to in `mappings`
has to actually exist for zellij, or nothing changes color once written.
Two ways to make that true:

- It's one of zellij's [built-in themes](https://zellij.dev/documentation/theme-list) —
  nothing further needed, this is what [Supported colorschemes](#supported-colorschemes)
  above uses.
- It's a theme you've defined yourself, in a `themes { "my-zellij-theme-name" { ... } }`
  block in `config.kdl` (or a separate file in zellij's `theme_dir`) — see zellij's
  [theme documentation](https://zellij.dev/documentation/themes.html) for the format.

This plugin only rewrites the `theme "..."` line; it doesn't check whether
that name resolves to anything on zellij's side. Map to a theme that
doesn't exist (a typo, or one you meant to define but didn't) and zellij
will just silently fail to apply it — nothing will look wrong here, the
line will be written correctly, it just won't do anything.

### Manual trigger

`:ZjThemeNow` re-applies the mapping for whatever colorscheme is
currently active — useful for testing config changes without switching
colorschemes.

## Supported colorschemes

Best-effort mappings for these plugins are bundled by default — see
[`lua/zj-theme/mappings.lua`](lua/zj-theme/mappings.lua) for the exact
zellij theme each one resolves to, and override any of them via `mappings`
in `setup()`.

| Plugin | Colorscheme names |
|---|---|
| [catppuccin/nvim](https://github.com/catppuccin/nvim) | `catppuccin`, `catppuccin-mocha`, `catppuccin-macchiato`, `catppuccin-frappe`, `catppuccin-latte` |
| [ellisonleao/gruvbox.nvim](https://github.com/ellisonleao/gruvbox.nvim) | `gruvbox` |
| [sainnhe/gruvbox-material](https://github.com/sainnhe/gruvbox-material) | `gruvbox-material` |
| [folke/tokyonight.nvim](https://github.com/folke/tokyonight.nvim) | `tokyonight`, `tokyonight-night`, `tokyonight-storm`, `tokyonight-moon`, `tokyonight-day` |
| [EdenEast/nightfox.nvim](https://github.com/EdenEast/nightfox.nvim) | `nightfox`, `dayfox`, `carbonfox` |
| [Shatur/neovim-ayu](https://github.com/Shatur/neovim-ayu) | `ayu` (`ayu-dark`/`ayu-light`/`ayu-mirage` are also mapped, for other ayu-family plugins that set those names directly) |
| [maxmx03/solarized.nvim](https://github.com/maxmx03/solarized.nvim) | `solarized` |
| [lifepillar/vim-solarized8](https://github.com/lifepillar/vim-solarized8) | `solarized8`, `solarized8_flat`, `solarized8_high`, `solarized8_low` |
| [navarasu/onedark.nvim](https://github.com/navarasu/onedark.nvim) | `onedark` |
| [sonph/onehalf](https://github.com/sonph/onehalf) | `onehalfdark` (`onehalflight` has no zellij light-theme equivalent) |
| [gbprod/nord.nvim](https://github.com/gbprod/nord.nvim) | `nord` |
| [Mofiqul/dracula.nvim](https://github.com/Mofiqul/dracula.nvim) | `dracula` |
| [rebelot/kanagawa.nvim](https://github.com/rebelot/kanagawa.nvim) | `kanagawa` |
| [neanias/everforest-nvim](https://github.com/neanias/everforest-nvim) | `everforest` |
| [NLKNguyen/papercolor-theme](https://github.com/NLKNguyen/papercolor-theme) | `PaperColor` |

Using something else? Add it via `mappings` in `setup()` — see
[Configuration](#configuration).

## Fallback behavior

`default_dark_theme` or `default_light_theme` (chosen by `vim.o.background`)
is used whenever:

- nvim is not running inside a zellij session (`$ZELLIJ` unset) — no-op,
  nothing is written at all.
- the active colorscheme has no entry in `mappings`.
- `zellij_config_path` doesn't exist/isn't readable, or has no `theme "..."`
  line to rewrite.

## Health

Run `:checkhealth zj-theme` to check whether `setup()` has been
called, whether you're currently inside a zellij session, whether
`zellij_config_path` exists and has a `theme "..."` line, and whether the
active colorscheme is mapped.

## Recommended plugins

- **[zellij-nav.nvim](https://github.com/swaits/zellij-nav.nvim)** — seamless
  navigation between nvim splits and zellij panes, so the same keys move
  focus across both. Complements this plugin: that one syncs navigation,
  this one syncs the theme.

- **[bg.nvim](https://github.com/typicode/bg.nvim)** — syncs your terminal
  emulator's own background/cursor color to your active nvim colorscheme,
  live, via OSC 11/12 escape sequences. It doesn't work reliably *inside*
  zellij, though: zellij intercepts OSC sequences itself (applying them
  per-pane) instead of passing them through to the real terminal underneath
  — a real, currently open zellij limitation
  ([zellij-org/zellij#3954](https://github.com/zellij-org/zellij/issues/3954),
  [#4712](https://github.com/zellij-org/zellij/issues/4712)), not a bug in
  bg.nvim. Workaround: exit zellij, let bg.nvim sync your terminal's theme
  (e.g. open nvim briefly outside zellij), then launch zellij — and nvim
  inside it — again.

## License

MIT, see [LICENSE](LICENSE).
