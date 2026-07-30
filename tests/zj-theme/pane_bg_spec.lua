local config = require("zj-theme.config")
local pane_bg = require("zj-theme.pane_bg")

-- Stubs vim.system so tests never shell out to a real `zellij` binary (CI
-- has none installed). Dispatches on the zellij subcommand
-- (cmd[3] = "list-panes" | "set-pane-color") and invokes the completion
-- callback synchronously, recording every call made.
local function stub_system(list_panes_result)
  local calls = {}
  local orig = vim.system

  vim.system = function(cmd, _opts, callback)
    table.insert(calls, cmd)
    if cmd[3] == "list-panes" then
      callback(list_panes_result)
    else
      callback({ code = 0, stdout = "", stderr = "" })
    end
  end

  return calls, function()
    vim.system = orig
  end
end

local function json_panes(panes)
  return { code = 0, stdout = vim.json.encode(panes), stderr = "" }
end

-- Stubs vim.system so calls never auto-complete: each call is recorded and
-- parked until resolve_next() is called, letting tests assert that a second
-- `zellij action` call is never dispatched while an earlier one is still
-- in flight (the whole point of the action queue in pane_bg.lua).
local function stub_system_async()
  local calls = {}
  local pending = {}
  local orig = vim.system

  vim.system = function(cmd, _opts, callback)
    table.insert(calls, cmd)
    table.insert(pending, callback)
  end

  local function in_flight()
    return #pending
  end

  local function resolve_next(result)
    local callback = table.remove(pending, 1)
    callback(result)
  end

  return calls, resolve_next, in_flight, function()
    vim.system = orig
  end
end

local function set_pane_color_calls(calls)
  local filtered = {}
  for _, cmd in ipairs(calls) do
    if cmd[3] == "set-pane-color" then
      table.insert(filtered, cmd)
    end
  end
  return filtered
end

describe("zj-theme.pane_bg", function()
  local orig_zellij, orig_pane_id

  before_each(function()
    config.setup({})
    pane_bg.reset_warnings()
    vim.api.nvim_set_hl(0, "Normal", { bg = 0x1a1b26, fg = 0xc0caf5 })

    orig_zellij = vim.env.ZELLIJ
    orig_pane_id = vim.env.ZELLIJ_PANE_ID
    vim.env.ZELLIJ = "0"
    vim.env.ZELLIJ_PANE_ID = "1"
  end)

  after_each(function()
    -- Guards against a real timer surviving a failed assertion mid-test and
    -- firing later against the real `zellij` binary.
    pane_bg.stop_polling()
    vim.env.ZELLIJ = orig_zellij
    vim.env.ZELLIJ_PANE_ID = orig_pane_id
  end)

  local panes = {
    { id = 1, is_plugin = false, exited = false }, -- current pane, excluded
    { id = 2, is_plugin = false, exited = false }, -- a sibling terminal pane
    { id = 3, is_plugin = false, exited = false }, -- another sibling terminal pane
    { id = 4, is_plugin = true, exited = false }, -- zellij's own status-bar plugin pane
    { id = 5, is_plugin = false, exited = true }, -- exited pane
  }

  describe("apply", function()
    it("sets bg/fg on every other real, non-exited pane", function()
      local calls, restore = stub_system(json_panes(panes))
      pane_bg.apply()
      restore()

      local set_calls = set_pane_color_calls(calls)
      table.sort(set_calls, function(a, b)
        return a[5] < b[5]
      end)

      assert.equals(2, #set_calls)
      assert.same(
        { "zellij", "action", "set-pane-color", "-p", "2", "--bg", "#1a1b26", "--fg", "#c0caf5" },
        set_calls[1]
      )
      assert.same(
        { "zellij", "action", "set-pane-color", "-p", "3", "--bg", "#1a1b26", "--fg", "#c0caf5" },
        set_calls[2]
      )
    end)

    it("does nothing outside a zellij session", function()
      vim.env.ZELLIJ = nil
      local calls, restore = stub_system(json_panes(panes))
      pane_bg.apply()
      restore()
      assert.equals(0, #calls)
    end)

    it("does nothing when sync_pane_backgrounds is disabled", function()
      config.setup({ sync_pane_backgrounds = false })
      local calls, restore = stub_system(json_panes(panes))
      pane_bg.apply()
      restore()
      assert.equals(0, #calls)
    end)

    it("warns once when `zellij action list-panes` fails", function()
      local calls, restore = stub_system({ code = 1, stdout = "", stderr = "not found" })

      local messages = {}
      local orig_notify = vim.notify
      vim.notify = function(msg)
        table.insert(messages, msg)
      end

      pane_bg.apply()
      vim.wait(50, function()
        return #messages > 0
      end)

      vim.notify = orig_notify
      restore()

      assert.equals(0, #set_pane_color_calls(calls))
      assert.equals(1, #messages)
      assert.matches("zellij` CLI on PATH", messages[1])
    end)
  end)

  describe("reset", function()
    it("resets every other real, non-exited pane", function()
      local calls, restore = stub_system(json_panes(panes))
      pane_bg.reset()
      restore()

      local set_calls = set_pane_color_calls(calls)
      table.sort(set_calls, function(a, b)
        return a[5] < b[5]
      end)

      assert.equals(2, #set_calls)
      assert.same({ "zellij", "action", "set-pane-color", "-p", "2", "--reset" }, set_calls[1])
      assert.same({ "zellij", "action", "set-pane-color", "-p", "3", "--reset" }, set_calls[2])
    end)
  end)

  describe("poll", function()
    it("colors every other pane on the first poll, same as apply", function()
      local calls, restore = stub_system(json_panes(panes))
      pane_bg.poll()
      restore()

      assert.equals(2, #set_pane_color_calls(calls))
    end)

    it("does not re-color panes already synced by a previous apply", function()
      local apply_calls, restore1 = stub_system(json_panes(panes))
      pane_bg.apply()
      restore1()
      assert.equals(2, #set_pane_color_calls(apply_calls))

      -- Same panes, nothing new — poll should be a no-op set-pane-color-wise.
      local poll_calls, restore2 = stub_system(json_panes(panes))
      pane_bg.poll()
      restore2()

      assert.equals(0, #set_pane_color_calls(poll_calls))
    end)

    it("colors a pane that appeared after a previous apply", function()
      local _, restore1 = stub_system(json_panes(panes))
      pane_bg.apply()
      restore1()

      local grown_panes = vim.deepcopy(panes)
      table.insert(grown_panes, { id = 6, is_plugin = false, exited = false })

      local calls, restore2 = stub_system(json_panes(grown_panes))
      pane_bg.poll()
      restore2()

      local set_calls = set_pane_color_calls(calls)
      assert.equals(1, #set_calls)
      assert.same(
        { "zellij", "action", "set-pane-color", "-p", "6", "--bg", "#1a1b26", "--fg", "#c0caf5" },
        set_calls[1]
      )
    end)
  end)

  describe("polling lifecycle", function()
    it("is not polling until start_polling is called", function()
      assert.is_false(pane_bg.is_polling())
    end)

    it("start_polling begins polling; stop_polling ends it", function()
      local _, restore = stub_system(json_panes(panes))
      pane_bg.start_polling()
      assert.is_true(pane_bg.is_polling())
      pane_bg.stop_polling()
      assert.is_false(pane_bg.is_polling())
      restore()
    end)

    it("start_polling is a no-op when already polling (no second timer)", function()
      local _, restore = stub_system(json_panes(panes))
      pane_bg.start_polling()
      pane_bg.start_polling()
      assert.is_true(pane_bg.is_polling())
      pane_bg.stop_polling()
      assert.is_false(pane_bg.is_polling())
      restore()
    end)

    it("does not start polling outside a zellij session", function()
      vim.env.ZELLIJ = nil
      pane_bg.start_polling()
      assert.is_false(pane_bg.is_polling())
    end)

    it("does not start polling when sync_pane_backgrounds is disabled", function()
      config.setup({ sync_pane_backgrounds = false })
      pane_bg.start_polling()
      assert.is_false(pane_bg.is_polling())
    end)

    it("does not start polling when pane_poll_interval_ms is 0", function()
      config.setup({ pane_poll_interval_ms = 0 })
      pane_bg.start_polling()
      assert.is_false(pane_bg.is_polling())
    end)
  end)

  describe("action serialization", function()
    it("never has more than one `zellij action` call in flight at once", function()
      local calls, resolve_next, in_flight, restore = stub_system_async()

      pane_bg.apply()

      -- Only list-panes should have been dispatched so far.
      assert.equals(1, #calls)
      assert.equals(1, in_flight())
      assert.equals("list-panes", calls[1][3])

      resolve_next(json_panes(panes))

      -- Resolving list-panes must dispatch exactly one set-pane-color call,
      -- not both sibling panes' calls at once.
      assert.equals(2, #calls)
      assert.equals(1, in_flight())
      assert.equals("set-pane-color", calls[2][3])
      assert.equals("2", calls[2][5])

      resolve_next({ code = 0, stdout = "", stderr = "" })

      -- The second pane's call is only dispatched once the first completes.
      assert.equals(3, #calls)
      assert.equals(1, in_flight())
      assert.equals("set-pane-color", calls[3][3])
      assert.equals("3", calls[3][5])

      resolve_next({ code = 0, stdout = "", stderr = "" })

      assert.equals(3, #calls)
      assert.equals(0, in_flight())

      restore()
    end)
  end)
end)
