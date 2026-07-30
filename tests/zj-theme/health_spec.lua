local config = require("zj-theme.config")
local health = require("zj-theme.health")

local function write_temp_config(lines)
  local path = vim.fn.tempname()
  vim.fn.writefile(lines, path)
  return path
end

-- Captures vim.health.* calls instead of rendering them into a real health
-- report buffer, so we can assert on which level fired for which message.
local function capture_health()
  local calls = {}
  local orig = {
    start = vim.health.start,
    ok = vim.health.ok,
    warn = vim.health.warn,
    error = vim.health.error,
    info = vim.health.info,
  }

  for _, level in ipairs({ "start", "ok", "warn", "error", "info" }) do
    vim.health[level] = function(msg, advice)
      table.insert(calls, { level = level, msg = msg, advice = advice })
    end
  end

  return calls, function()
    for level, fn in pairs(orig) do
      vim.health[level] = fn
    end
  end
end

local function find(calls, level, pattern)
  for _, call in ipairs(calls) do
    if call.level == level and call.msg:match(pattern) then
      return call
    end
  end
  return nil
end

-- Forces vim.fn.executable("zellij") to a known value, so the version-check
-- branch runs (or doesn't) regardless of whether the machine running the
-- tests actually has zellij installed (CI doesn't).
local function stub_executable(zellij_available)
  local orig = vim.fn.executable
  vim.fn.executable = function(name)
    if name == "zellij" then
      return zellij_available and 1 or 0
    end
    return orig(name)
  end
  return function()
    vim.fn.executable = orig
  end
end

-- Stubs vim.system for the synchronous `:wait()` pattern health.lua uses to
-- read `zellij --version`, so tests never shell out to a real binary.
local function stub_system_version(result)
  local orig = vim.system
  vim.system = function(_cmd, _opts)
    return {
      wait = function()
        return result
      end,
    }
  end
  return function()
    vim.system = orig
  end
end

describe("zj-theme.health", function()
  local temp_config_path
  local orig_colors_name

  before_each(function()
    temp_config_path = write_temp_config({ 'theme "onedark"' })
    config.setup({ zellij_config_path = temp_config_path })
    vim.env.ZELLIJ = "0"
    orig_colors_name = vim.g.colors_name
  end)

  after_each(function()
    vim.fn.delete(temp_config_path)
    vim.g.colors_name = orig_colors_name
  end)

  it("reports ok when setup() has been called", function()
    local calls, restore = capture_health()
    health.check()
    restore()
    assert.truthy(find(calls, "ok", "setup%(%) has been called"))
  end)

  it("reports warn when setup() has not been called", function()
    config.did_setup = false
    local calls, restore = capture_health()
    health.check()
    restore()
    assert.truthy(find(calls, "warn", "setup%(%) has not been called"))
  end)

  it("reports info when inside a zellij session", function()
    vim.env.ZELLIJ = "0"
    local calls, restore = capture_health()
    health.check()
    restore()
    assert.truthy(find(calls, "info", "Running inside a zellij session"))
  end)

  it("reports info when not inside a zellij session", function()
    vim.env.ZELLIJ = nil
    local calls, restore = capture_health()
    health.check()
    restore()
    assert.truthy(find(calls, "info", "Not running inside a zellij session"))
  end)

  it("reports error when the config file doesn't exist", function()
    config.setup({ zellij_config_path = "/nonexistent/path/config.kdl" })
    local calls, restore = capture_health()
    health.check()
    restore()
    assert.truthy(find(calls, "error", "not found or not readable"))
  end)

  it("reports ok for an existing config file with a theme line", function()
    local calls, restore = capture_health()
    health.check()
    restore()
    assert.truthy(find(calls, "ok", "zellij config found"))
    assert.truthy(find(calls, "ok", 'theme "%.%.%." line found'))
  end)

  it("reports error when the config file has no theme line", function()
    local no_theme_path = write_temp_config({ "// no theme line here" })
    config.setup({ zellij_config_path = no_theme_path })

    local calls, restore = capture_health()
    health.check()
    restore()

    assert.truthy(find(calls, "error", "no theme"))
    vim.fn.delete(no_theme_path)
  end)

  it("reports info when no colorscheme is active", function()
    vim.g.colors_name = nil
    local calls, restore = capture_health()
    health.check()
    restore()
    assert.truthy(find(calls, "info", "No colorscheme currently active"))
  end)

  it("reports ok when the active colorscheme is mapped", function()
    vim.g.colors_name = "nord"
    local calls, restore = capture_health()
    health.check()
    restore()
    assert.truthy(find(calls, "ok", "'nord' is mapped"))
  end)

  it("reports warn when the active colorscheme is not mapped", function()
    vim.g.colors_name = "some-unmapped-theme"
    local calls, restore = capture_health()
    health.check()
    restore()
    assert.truthy(find(calls, "warn", "'some%-unmapped%-theme' has no mapping"))
  end)

  describe("zellij version check", function()
    it("reports ok when the installed zellij is new enough", function()
      local restore_exec = stub_executable(true)
      local restore_sys = stub_system_version({ code = 0, stdout = "zellij 0.44.1\n", stderr = "" })

      local calls, restore_health = capture_health()
      health.check()
      restore_health()
      restore_sys()
      restore_exec()

      assert.truthy(find(calls, "ok", "zellij 0%.44%.1 supports"))
    end)

    it("reports error when the installed zellij is too old", function()
      local restore_exec = stub_executable(true)
      local restore_sys = stub_system_version({ code = 0, stdout = "zellij 0.40.0\n", stderr = "" })

      local calls, restore_health = capture_health()
      health.check()
      restore_health()
      restore_sys()
      restore_exec()

      assert.truthy(find(calls, "error", "zellij 0%.40%.0 is too old"))
    end)

    it("reports warn when the zellij version can't be determined", function()
      local restore_exec = stub_executable(true)
      local restore_sys = stub_system_version({ code = 1, stdout = "", stderr = "not found" })

      local calls, restore_health = capture_health()
      health.check()
      restore_health()
      restore_sys()
      restore_exec()

      assert.truthy(find(calls, "warn", "couldn't determine the zellij version"))
    end)

    it("doesn't run at all when the zellij CLI isn't on PATH", function()
      local restore_exec = stub_executable(false)

      local calls, restore_health = capture_health()
      health.check()
      restore_health()
      restore_exec()

      assert.is_nil(find(calls, "ok", "supports `set%-pane%-color`"))
      assert.is_nil(find(calls, "error", "too old"))
    end)
  end)

  describe("current-pane OSC sync", function()
    it("reports ok for the current pane regardless of the zellij CLI", function()
      local restore_exec = stub_executable(false)
      local calls, restore = capture_health()
      health.check()
      restore()
      restore_exec()
      assert.truthy(find(calls, "ok", "gets its background/cursor synced via raw terminal"))
    end)

    it("reports a single info and skips everything else when sync_pane_backgrounds is disabled", function()
      config.setup({ sync_pane_backgrounds = false })
      local calls, restore = capture_health()
      health.check()
      restore()

      assert.truthy(find(calls, "info", "sync_pane_backgrounds is disabled"))
      assert.is_nil(find(calls, "ok", "gets its background/cursor synced via raw terminal"))
      assert.is_nil(find(calls, "ok", "zellij` CLI found on PATH"))
    end)
  end)
end)

describe("zj-theme.health.parse_zellij_version", function()
  it("parses a version out of `zellij --version` output", function()
    assert.same({ 0, 44, 1 }, health.parse_zellij_version("zellij 0.44.1\n"))
  end)

  it("returns nil when no version-shaped substring is found", function()
    assert.is_nil(health.parse_zellij_version("not a version"))
    assert.is_nil(health.parse_zellij_version(""))
    assert.is_nil(health.parse_zellij_version(nil))
  end)
end)

describe("zj-theme.health.zellij_version_at_least", function()
  it("is true when equal", function()
    assert.is_true(health.zellij_version_at_least({ 0, 44, 0 }, { 0, 44, 0 }))
  end)

  it("is true when greater", function()
    assert.is_true(health.zellij_version_at_least({ 0, 44, 1 }, { 0, 44, 0 }))
    assert.is_true(health.zellij_version_at_least({ 0, 45, 0 }, { 0, 44, 0 }))
    assert.is_true(health.zellij_version_at_least({ 1, 0, 0 }, { 0, 44, 0 }))
  end)

  it("is false when lesser", function()
    assert.is_false(health.zellij_version_at_least({ 0, 43, 9 }, { 0, 44, 0 }))
    assert.is_false(health.zellij_version_at_least({ 0, 44, 0 }, { 0, 44, 1 }))
  end)
end)
