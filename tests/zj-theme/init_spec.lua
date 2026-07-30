local config = require("zj-theme.config")
local pane_bg = require("zj-theme.pane_bg")
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

  it("leaves pane colors as-is on VimLeavePre — only polling stops", function()
    vim.api.nvim_set_hl(0, "Normal", { bg = 0x1a1b26, fg = 0xc0caf5 })
    local restore_system = stub_system()
    zj_theme.setup({})
    pane_bg.start_polling()
    assert.is_true(pane_bg.is_polling())

    vim.api.nvim_exec_autocmds("VimLeavePre", { group = "ZjTheme" })
    restore_system()

    assert.is_false(pane_bg.is_polling())
  end)
end)
