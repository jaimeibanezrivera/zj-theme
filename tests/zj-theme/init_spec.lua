local config = require("zj-theme.config")
local sync = require("zj-theme.sync")
local terminal = require("zj-theme.terminal")
local zj_theme = require("zj-theme")

describe("zj-theme (setup)", function()
  local orig_zellij, orig_colors_name

  before_each(function()
    config.setup({})
    sync.reset_warnings()
    terminal.reset_warnings()
    orig_zellij = vim.env.ZELLIJ
    orig_colors_name = vim.g.colors_name
    vim.env.ZELLIJ = "0"
  end)

  after_each(function()
    -- Drop any autocmds a setup() call in this test registered, so they
    -- can't bleed into other spec files.
    vim.api.nvim_create_augroup("ZjTheme", { clear = true })
    vim.env.ZELLIJ = orig_zellij
    vim.g.colors_name = orig_colors_name
  end)

  it("registers a ColorScheme autocmd that drives both channels", function()
    local temp_config_path = vim.fn.tempname()
    vim.fn.writefile({ 'theme "onedark"' }, temp_config_path)

    zj_theme.setup({ zellij_config_path = temp_config_path })

    vim.g.colors_name = "nord"
    vim.api.nvim_exec_autocmds("ColorScheme", { group = "ZjTheme" })

    local lines = vim.fn.readfile(temp_config_path)
    assert.matches('theme "nord"', table.concat(lines, "\n"))

    vim.fn.delete(temp_config_path)
  end)

  it("sync_now() re-applies the currently active colorscheme on demand", function()
    local temp_config_path = vim.fn.tempname()
    vim.fn.writefile({ 'theme "onedark"' }, temp_config_path)

    zj_theme.setup({ zellij_config_path = temp_config_path })
    vim.g.colors_name = "dracula"

    zj_theme.sync_now()

    local lines = vim.fn.readfile(temp_config_path)
    assert.matches('theme "dracula"', table.concat(lines, "\n"))

    vim.fn.delete(temp_config_path)
  end)

  it("also drives the terminal channel when terminal.emulator is set", function()
    local term_path = vim.fn.tempname()

    zj_theme.setup({ terminal = { emulator = "wezterm", config_path = term_path } })
    vim.g.colors_name = "nord"

    zj_theme.sync_now()

    local lines = vim.fn.readfile(term_path)
    assert.matches('return "nord"', table.concat(lines, "\n"))

    vim.fn.delete(term_path)
  end)
end)
