local config = require("zj-theme.config")
local sync = require("zj-theme.sync")

local function write_temp_config(lines)
  local path = vim.fn.tempname()
  vim.fn.writefile(lines, path)
  return path
end

describe("zj-theme.sync", function()
  local temp_config_path

  local orig_background

  before_each(function()
    temp_config_path = write_temp_config({
      "// some comment",
      'theme "onedark"',
      "",
      'default_mode "normal"',
    })
    config.setup({ zellij_config_path = temp_config_path })
    sync.reset_warnings()
    vim.env.ZELLIJ = "0"
    orig_background = vim.o.background
    vim.o.background = "dark"
  end)

  after_each(function()
    vim.fn.delete(temp_config_path)
    vim.o.background = orig_background
  end)

  describe("resolve_theme", function()
    it("resolves a known colorscheme via the built-in defaults", function()
      assert.equals("nord", sync.resolve_theme("nord"))
    end)

    it("returns nil for an unknown colorscheme", function()
      assert.is_nil(sync.resolve_theme("not-a-real-colorscheme"))
    end)

    it("maps ayu-light to zellij's real (hyphenated) theme name", function()
      -- zellij's actual bundled theme file names ayu-dark/ayu-light/ayu-mirage
      -- with hyphens — zellij's own theme-list docs page renders these with
      -- underscores, which is wrong; regression test for trusting that page
      -- over the real asset and mapping these incorrectly.
      assert.equals("ayu-light", sync.resolve_theme("ayu-light"))
    end)

    it("maps catppuccin-mocha directly (it does exist in zellij, despite the docs page omitting it)", function()
      assert.equals("catppuccin-mocha", sync.resolve_theme("catppuccin-mocha"))
    end)

    it("maps tokyonight-day to iceberg-light, not the broken tokyo-night-light", function()
      -- zellij's own tokyo-night-light.kdl has a near-black
      -- text_unselected.background - a real bug in the bundled theme, not
      -- our mapping. Regression test for switching to a working substitute.
      assert.equals("iceberg-light", sync.resolve_theme("tokyonight-day"))
    end)

    it("lets user-supplied mappings override/extend the defaults", function()
      config.setup({
        zellij_config_path = temp_config_path,
        mappings = { mytheme = "custom-zellij-theme", nord = "custom-nord" },
      })
      assert.equals("custom-zellij-theme", sync.resolve_theme("mytheme"))
      assert.equals("custom-nord", sync.resolve_theme("nord"))
    end)

    describe("background-dependent mappings", function()
      -- ayu.nvim (and gruvbox-material, everforest) keep vim.g.colors_name
      -- identical across light/dark, while still respecting vim.o.background
      -- for their actual palette — regression test for a bug where "ayu"
      -- always resolved to ayu_dark regardless of background.
      it("resolves to the dark variant when background is dark", function()
        vim.o.background = "dark"
        assert.equals("ayu-dark", sync.resolve_theme("ayu"))
      end)

      it("resolves to the light variant when background is light", function()
        vim.o.background = "light"
        assert.equals("ayu-light", sync.resolve_theme("ayu"))
      end)

      it("supports background-dependent tables in user-supplied mappings too", function()
        config.setup({
          zellij_config_path = temp_config_path,
          mappings = { mytheme = { dark = "my-dark-theme", light = "my-light-theme" } },
        })
        vim.o.background = "dark"
        assert.equals("my-dark-theme", sync.resolve_theme("mytheme"))
        vim.o.background = "light"
        assert.equals("my-light-theme", sync.resolve_theme("mytheme"))
      end)

      -- maxmx03/solarized.nvim has the same colors_name-stays-constant
      -- pattern as ayu; regression test for the same class of bug.
      it("resolves solarized to the dark variant when background is dark", function()
        vim.o.background = "dark"
        assert.equals("solarized-dark", sync.resolve_theme("solarized"))
      end)

      it("resolves solarized to the light variant when background is light", function()
        vim.o.background = "light"
        assert.equals("solarized-light", sync.resolve_theme("solarized"))
      end)

      -- lifepillar/vim-solarized8 has the same colors_name-stays-constant
      -- pattern as solarized/ayu; regression test for the same class of bug.
      it("resolves solarized8 to the dark variant when background is dark", function()
        vim.o.background = "dark"
        assert.equals("solarized-dark", sync.resolve_theme("solarized8"))
      end)

      it("resolves solarized8 to the light variant when background is light", function()
        vim.o.background = "light"
        assert.equals("solarized-light", sync.resolve_theme("solarized8"))
      end)

      -- solarized8_flat/high/low are separate colorscheme names (each its
      -- own colors_name), each still background-aware on top of that;
      -- zellij has no equivalent contrast variants so all three map the
      -- same as plain solarized8.
      for _, variant in ipairs({ "solarized8_flat", "solarized8_high", "solarized8_low" }) do
        it("resolves " .. variant .. " to the dark variant when background is dark", function()
          vim.o.background = "dark"
          assert.equals("solarized-dark", sync.resolve_theme(variant))
        end)

        it("resolves " .. variant .. " to the light variant when background is light", function()
          vim.o.background = "light"
          assert.equals("solarized-light", sync.resolve_theme(variant))
        end)
      end
    end)

    it("maps onehalfdark to zellij's one-half-dark (sonph/onehalf's colors_name has no hyphens)", function()
      -- Regression test for a bug where the mapping key was "one-half-dark",
      -- which sonph/onehalf never actually sets - its real colors_name is
      -- "onehalfdark"/"onehalflight" (no hyphens at all).
      assert.equals("one-half-dark", sync.resolve_theme("onehalfdark"))
      assert.is_nil(sync.resolve_theme("onehalflight")) -- zellij has no light variant
    end)
  end)

  describe("in_zellij_session", function()
    it("is true when $ZELLIJ is set", function()
      vim.env.ZELLIJ = "0"
      assert.is_true(sync.in_zellij_session())
    end)

    it("is false when $ZELLIJ is unset", function()
      vim.env.ZELLIJ = nil
      assert.is_false(sync.in_zellij_session())
    end)
  end)

  describe("apply", function()
    it("does nothing outside a zellij session", function()
      vim.env.ZELLIJ = nil
      sync.apply("nord")
      local lines = vim.fn.readfile(temp_config_path)
      assert.matches('theme "onedark"', table.concat(lines, "\n"))
    end)

    it("writes the mapped theme into the config file's theme line", function()
      sync.apply("nord")
      local lines = vim.fn.readfile(temp_config_path)
      assert.matches('theme "nord"', table.concat(lines, "\n"))
      -- everything else in the file is left untouched
      assert.equals("// some comment", lines[1])
      assert.equals('default_mode "normal"', lines[4])
    end)

    it("falls back to default_dark_theme for an unmapped colorscheme when background is dark", function()
      config.setup({
        zellij_config_path = temp_config_path,
        default_dark_theme = "default",
        default_light_theme = "pencil-light",
      })
      vim.o.background = "dark"
      sync.apply("some-unmapped-theme")
      local lines = vim.fn.readfile(temp_config_path)
      assert.matches('theme "default"', table.concat(lines, "\n"))
    end)

    it("falls back to default_light_theme for an unmapped colorscheme when background is light", function()
      config.setup({
        zellij_config_path = temp_config_path,
        default_dark_theme = "default",
        default_light_theme = "pencil-light",
      })
      vim.o.background = "light"
      sync.apply("some-unmapped-theme")
      local lines = vim.fn.readfile(temp_config_path)
      assert.matches('theme "pencil%-light"', table.concat(lines, "\n"))
    end)

    it("warns and no-ops when the config file doesn't exist", function()
      config.setup({ zellij_config_path = "/nonexistent/path/config.kdl" })
      local messages = {}
      local orig_notify = vim.notify
      vim.notify = function(msg)
        table.insert(messages, msg)
      end

      sync.apply("nord")

      vim.notify = orig_notify
      assert.equals(1, #messages)
      assert.matches("not found or not readable", messages[1])
    end)

    it("warns when the config file has no theme line, and does not loop forever", function()
      local no_theme_path = write_temp_config({ "// no theme line here" })
      config.setup({ zellij_config_path = no_theme_path, default_dark_theme = "default" })

      local messages = {}
      local orig_notify = vim.notify
      vim.notify = function(msg)
        table.insert(messages, msg)
      end

      sync.apply("nord")

      vim.notify = orig_notify
      assert.equals(1, #messages) -- notify_once collapses the retry's identical warning
      assert.matches("no `theme", messages[1])

      vim.fn.delete(no_theme_path)
    end)
  end)
end)
