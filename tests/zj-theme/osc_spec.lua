local config = require("zj-theme.config")
local osc = require("zj-theme.osc")

-- Stubs osc.write so tests never need a real controlling terminal on fd 1,
-- and can assert on the exact bytes sent.
local function stub_write()
  local writes = {}
  local orig = osc.write

  osc.write = function(bytes)
    table.insert(writes, bytes)
  end

  return writes, function()
    osc.write = orig
  end
end

describe("zj-theme.osc", function()
  local orig_zellij, orig_pane_id

  before_each(function()
    config.setup({})
    vim.api.nvim_set_hl(0, "Normal", { bg = 0x1a1b26, fg = 0xc0caf5 })

    orig_zellij = vim.env.ZELLIJ
    orig_pane_id = vim.env.ZELLIJ_PANE_ID
    vim.env.ZELLIJ = "0"
    vim.env.ZELLIJ_PANE_ID = "1"
  end)

  after_each(function()
    vim.env.ZELLIJ = orig_zellij
    vim.env.ZELLIJ_PANE_ID = orig_pane_id
  end)

  describe("apply", function()
    it("writes OSC 11 (bg) then OSC 12 (cursor, via fg)", function()
      local writes, restore = stub_write()
      osc.apply()
      restore()

      assert.equals(2, #writes)
      assert.equals("\027]11;#1a1b26\007", writes[1])
      assert.equals("\027]12;#c0caf5\007", writes[2])
    end)

    it("is idempotent across repeated calls with an unchanged colorscheme", function()
      local writes, restore = stub_write()
      osc.apply()
      osc.apply()
      restore()

      assert.equals(4, #writes)
      assert.same(writes[1], writes[3])
      assert.same(writes[2], writes[4])
    end)

    it("does nothing outside a zellij session", function()
      vim.env.ZELLIJ = nil
      local writes, restore = stub_write()
      osc.apply()
      restore()
      assert.equals(0, #writes)
    end)

    it("does nothing when sync_pane_backgrounds is disabled", function()
      config.setup({ sync_pane_backgrounds = false })
      local writes, restore = stub_write()
      osc.apply()
      restore()
      assert.equals(0, #writes)
    end)

    it("does nothing when Normal has no bg/fg set", function()
      vim.api.nvim_set_hl(0, "Normal", {})
      local writes, restore = stub_write()
      osc.apply()
      restore()
      assert.equals(0, #writes)
    end)
  end)
end)
