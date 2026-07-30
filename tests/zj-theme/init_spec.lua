local config = require("zj-theme.config")
local pane_bg = require("zj-theme.pane_bg")
local osc = require("zj-theme.osc")
local zj_theme = require("zj-theme")

-- Stubs vim.system so tests never shell out to a real `zellij` binary.
local function stub_system()
  local orig = vim.system

  vim.system = function(cmd, _opts, callback)
    if cmd[3] == "list-panes" then
      callback({ code = 0, stdout = vim.json.encode({}), stderr = "" })
    else
      callback({ code = 0, stdout = "", stderr = "" })
    end
  end

  return function()
    vim.system = orig
  end
end

-- Stubs osc.write so tests can assert on it without a real controlling
-- terminal on fd 1.
local function stub_osc_write()
  local writes = {}
  local orig = osc.write

  osc.write = function(bytes)
    table.insert(writes, bytes)
  end

  return writes, function()
    osc.write = orig
  end
end

describe("zj-theme (setup)", function()
  local orig_zellij, orig_pane_id

  before_each(function()
    config.setup({})
    pane_bg.reset_warnings()
    orig_zellij = vim.env.ZELLIJ
    orig_pane_id = vim.env.ZELLIJ_PANE_ID
    vim.env.ZELLIJ = "0"
    vim.env.ZELLIJ_PANE_ID = "1"
  end)

  after_each(function()
    pane_bg.stop_polling()
    -- Drop any autocmds a setup() call in this test registered, so they
    -- can't fire later (e.g. once VimEnter actually happens after the
    -- whole suite finishes) or bleed into other spec files.
    vim.api.nvim_create_augroup("ZjTheme", { clear = true })
    vim.env.ZELLIJ = orig_zellij
    vim.env.ZELLIJ_PANE_ID = orig_pane_id
  end)

  it("stops a timer left over from a prior setup() call when reconfigured to disable it", function()
    local restore = stub_system()
    -- Simulates a poll timer already running from an earlier setup() call.
    pane_bg.start_polling()
    assert.is_true(pane_bg.is_polling())

    zj_theme.setup({ sync_pane_backgrounds = false })

    assert.is_false(pane_bg.is_polling())
    restore()
  end)

  it("does not eagerly start polling before nvim has finished starting", function()
    local restore = stub_system()
    assert.is_false(pane_bg.is_polling())

    zj_theme.setup({ sync_pane_backgrounds = true })

    -- vim.v.vim_did_enter is 0 while tests run (VimEnter hasn't fired yet
    -- in this harness), so setup() should defer to the VimEnter autocmd
    -- instead of starting the timer immediately.
    assert.is_false(pane_bg.is_polling())
    restore()
  end)

  it("applies OSC colors for the current pane on ColorScheme", function()
    vim.api.nvim_set_hl(0, "Normal", { bg = 0x1a1b26, fg = 0xc0caf5 })
    local restore_system = stub_system()
    zj_theme.setup({})

    local writes, restore_write = stub_osc_write()
    vim.api.nvim_exec_autocmds("ColorScheme", { group = "ZjTheme" })
    restore_write()
    restore_system()

    assert.equals(2, #writes)
    assert.equals("\027]11;#1a1b26\007", writes[1])
    assert.equals("\027]12;#c0caf5\007", writes[2])
  end)

  it("resets OSC colors for the current pane on VimLeavePre", function()
    vim.api.nvim_set_hl(0, "Normal", { bg = 0x1a1b26, fg = 0xc0caf5 })
    local restore_system = stub_system()
    zj_theme.setup({})

    local writes, restore_write = stub_osc_write()
    vim.api.nvim_exec_autocmds("VimLeavePre", { group = "ZjTheme" })
    restore_write()
    restore_system()

    assert.equals(2, #writes)
    assert.equals("\027]111\007", writes[1])
    assert.equals("\027]112\007", writes[2])
  end)
end)
