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
end)
