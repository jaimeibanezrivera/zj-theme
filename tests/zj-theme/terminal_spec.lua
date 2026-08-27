local config = require("zj-theme.config")
local terminal = require("zj-theme.terminal")
local wezterm_adapter = require("zj-theme.terminals.wezterm")
local alacritty_adapter = require("zj-theme.terminals.alacritty")

describe("zj-theme.terminal", function()
  local orig_background

  before_each(function()
    terminal.reset_warnings()
    orig_background = vim.o.background
    vim.o.background = "dark"
  end)

  after_each(function()
    vim.o.background = orig_background
  end)

  describe("adapter", function()
    it("returns nil when terminal.emulator is unset", function()
      config.setup({})
      assert.is_nil(terminal.adapter())
    end)

    it("returns the matching adapter for a known terminal.emulator", function()
      config.setup({ terminal = { emulator = "wezterm" } })
      assert.equals(wezterm_adapter, terminal.adapter())
    end)

    it("returns nil and warns once for an unknown terminal.emulator", function()
      config.setup({ terminal = { emulator = "not-a-real-terminal" } })

      local messages = {}
      local orig_notify = vim.notify
      vim.notify = function(msg)
        table.insert(messages, msg)
      end

      assert.is_nil(terminal.adapter())
      assert.is_nil(terminal.adapter()) -- second call: no duplicate warning

      vim.notify = orig_notify
      assert.equals(1, #messages)
      assert.matches("not supported", messages[1])
    end)
  end)

  describe("config_path", function()
    it("returns nil when unset and the adapter has no default", function()
      config.setup({ terminal = { emulator = "wezterm" } })
      assert.is_nil(terminal.config_path({}))
    end)

    it("falls back to the adapter's default_config_path when unset", function()
      config.setup({ terminal = { emulator = "wezterm" } })
      assert.equals(wezterm_adapter.default_config_path, terminal.config_path(wezterm_adapter))
    end)

    it("expands and returns terminal.config_path when set, overriding the adapter default", function()
      config.setup({ terminal = { emulator = "wezterm", config_path = "~/zj-theme.lua" } })
      assert.equals(vim.fn.expand("~/zj-theme.lua"), terminal.config_path(wezterm_adapter))
    end)
  end)

  describe("resolve_theme", function()
    before_each(function()
      config.setup({ terminal = { emulator = "wezterm" } })
    end)

    it("resolves a known colorscheme via the adapter's built-in defaults", function()
      assert.equals("nord", terminal.resolve_theme(wezterm_adapter, "nord"))
    end)

    it("returns nil for an unknown colorscheme", function()
      assert.is_nil(terminal.resolve_theme(wezterm_adapter, "not-a-real-colorscheme"))
    end)

    it("lets terminal.mappings override/extend the adapter's defaults", function()
      config.setup({
        terminal = {
          emulator = "wezterm",
          mappings = { mytheme = "Custom Scheme", nord = "Custom Nord" },
        },
      })
      assert.equals("Custom Scheme", terminal.resolve_theme(wezterm_adapter, "mytheme"))
      assert.equals("Custom Nord", terminal.resolve_theme(wezterm_adapter, "nord"))
    end)

    it("resolves background-dependent mappings via vim.o.background", function()
      vim.o.background = "dark"
      assert.equals("ayu", terminal.resolve_theme(wezterm_adapter, "ayu"))
      vim.o.background = "light"
      assert.equals("ayu_light", terminal.resolve_theme(wezterm_adapter, "ayu"))
    end)
  end)

  describe("default_theme", function()
    it("uses the adapter's default when no override is set", function()
      config.setup({ terminal = { emulator = "wezterm" } })
      vim.o.background = "dark"
      assert.equals(wezterm_adapter.default_dark_theme, terminal.default_theme(wezterm_adapter))
      vim.o.background = "light"
      assert.equals(wezterm_adapter.default_light_theme, terminal.default_theme(wezterm_adapter))
    end)

    it("lets terminal.default_dark_theme/default_light_theme override the adapter", function()
      config.setup({
        terminal = {
          emulator = "wezterm",
          default_dark_theme = "My Dark",
          default_light_theme = "My Light",
        },
      })
      vim.o.background = "dark"
      assert.equals("My Dark", terminal.default_theme(wezterm_adapter))
      vim.o.background = "light"
      assert.equals("My Light", terminal.default_theme(wezterm_adapter))
    end)
  end)

  describe("apply", function()
    it("does nothing when terminal.emulator is unset", function()
      config.setup({})
      terminal.apply("nord")
      -- no config_path to inspect; absence of an error is the assertion
    end)

    it("warns and no-ops when config_path is unset and the adapter has no default", function()
      local orig_default = wezterm_adapter.default_config_path
      wezterm_adapter.default_config_path = nil
      config.setup({ terminal = { emulator = "wezterm" } })

      local messages = {}
      local orig_notify = vim.notify
      vim.notify = function(msg)
        table.insert(messages, msg)
      end

      terminal.apply("nord")
      terminal.apply("nord") -- second call: no duplicate warning

      vim.notify = orig_notify
      wezterm_adapter.default_config_path = orig_default
      assert.equals(1, #messages)
      assert.matches("terminal.config_path must be set", messages[1])
    end)

    it("writes to the adapter's default_config_path when terminal.config_path is unset", function()
      local orig_default = wezterm_adapter.default_config_path
      local path = vim.fn.tempname()
      wezterm_adapter.default_config_path = path
      config.setup({ terminal = { emulator = "wezterm" } })

      terminal.apply("nord")

      wezterm_adapter.default_config_path = orig_default
      local lines = vim.fn.readfile(path)
      assert.matches('return "nord"', table.concat(lines, "\n"))
      vim.fn.delete(path)
    end)

    it("writes the mapped theme into the wezterm managed file", function()
      local path = vim.fn.tempname()
      config.setup({ terminal = { emulator = "wezterm", config_path = path } })

      terminal.apply("nord")

      local lines = vim.fn.readfile(path)
      assert.matches('return "nord"', table.concat(lines, "\n"))
      vim.fn.delete(path)
    end)

    it("writes an import line into the alacritty managed file", function()
      local path = vim.fn.tempname()
      config.setup({
        terminal = {
          emulator = "alacritty",
          config_path = path,
          themes_dir = "/tmp/alacritty-theme/themes",
        },
      })

      terminal.apply("nord")

      local lines = vim.fn.readfile(path)
      assert.matches('import = %["/tmp/alacritty%-theme/themes/nord%.toml"%]', table.concat(lines, "\n"))
      vim.fn.delete(path)
    end)

    it("warns and no-ops when themes_dir is unset and the adapter has no default", function()
      local orig_default = alacritty_adapter.default_themes_dir
      alacritty_adapter.default_themes_dir = nil
      local path = vim.fn.tempname()
      config.setup({ terminal = { emulator = "alacritty", config_path = path } })

      local messages = {}
      local orig_notify = vim.notify
      vim.notify = function(msg)
        table.insert(messages, msg)
      end

      terminal.apply("nord")

      vim.notify = orig_notify
      alacritty_adapter.default_themes_dir = orig_default
      assert.equals(1, #messages)
      assert.matches("terminal.themes_dir must be set", messages[1])
      assert.is_false(vim.fn.filereadable(path) == 1)
    end)

    it("falls back to the adapter's default_themes_dir when terminal.themes_dir is unset", function()
      local path = vim.fn.tempname()
      config.setup({ terminal = { emulator = "alacritty", config_path = path } })

      terminal.apply("nord")

      local lines = vim.fn.readfile(path)
      local expected_import = alacritty_adapter.default_themes_dir .. "/nord.toml"
      assert.is_true((table.concat(lines, "\n")):find(expected_import, 1, true) ~= nil)
      vim.fn.delete(path)
    end)

    it("falls back to the default theme for an unmapped colorscheme", function()
      local path = vim.fn.tempname()
      config.setup({
        terminal = {
          emulator = "wezterm",
          config_path = path,
          default_dark_theme = "Fallback Scheme",
        },
      })
      vim.o.background = "dark"

      terminal.apply("some-unmapped-theme")

      local lines = vim.fn.readfile(path)
      assert.matches('return "Fallback Scheme"', table.concat(lines, "\n"))
      vim.fn.delete(path)
    end)

    it("warns and no-ops when the managed file's directory doesn't exist", function()
      config.setup({
        terminal = {
          emulator = "wezterm",
          config_path = "/nonexistent/dir/zj-theme.lua",
        },
      })

      local messages = {}
      local orig_notify = vim.notify
      vim.notify = function(msg)
        table.insert(messages, msg)
      end

      terminal.apply("nord")

      vim.notify = orig_notify
      assert.equals(1, #messages)
      assert.matches("failed writing", messages[1])
    end)
  end)
end)
