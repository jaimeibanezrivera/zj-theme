local config = require("zj-theme.config")
local sync = require("zj-theme.sync")
local colors = require("zj-theme.colors")

local M = {}

local warned = {}

-- Pane ids already colored by a prior apply()/poll() call, so poll() only
-- has to act on panes that showed up since then instead of re-sending
-- set-pane-color to every pane on every tick.
local known_ids = {}

local timer = nil

-- `zellij action ...` invocations are queued and run one at a time rather
-- than fired concurrently: each invocation is a short-lived client that
-- connects and disconnects, and a burst of them (e.g. one apply() call
-- coloring several sibling panes at once) can race the server's tab-sync
-- bookkeeping for those clients ("active tab not found for client N",
-- logged by zellij as non-fatal, but avoidable).
local action_queue = {}
local action_running = false

local function process_action_queue()
  if action_running then
    return
  end

  local item = table.remove(action_queue, 1)
  if not item then
    return
  end

  action_running = true
  vim.system(item.cmd, { text = true }, function(result)
    action_running = false
    if item.on_done then
      item.on_done(result)
    end
    process_action_queue()
  end)
end

local function run_zellij_action(cmd, on_done)
  table.insert(action_queue, { cmd = cmd, on_done = on_done })
  process_action_queue()
end

local function notify(msg, level)
  if config.options.notify == false then
    return
  end
  vim.notify(("[zj-theme] %s"):format(msg), level or vim.log.levels.WARN)
end

local function notify_once(key, msg, level)
  if warned[key] then
    return
  end
  warned[key] = true
  notify(msg, level)
end

-- Exposed for tests so warning/known-pane state doesn't leak between cases.
function M.reset_warnings()
  warned = {}
  known_ids = {}
  action_queue = {}
  action_running = false
end

local function enabled()
  return config.options.sync_pane_backgrounds ~= false and sync.in_zellij_session()
end

-- Lists every real (non-plugin, non-exited) pane id in the session, other
-- than `except_id` (typically the current pane — osc.lua handles that one
-- directly via terminal escape sequences). Calls on_done(ids) asynchronously.
local function list_other_pane_ids(except_id, on_done)
  run_zellij_action({ "zellij", "action", "list-panes", "--json" }, function(result)
    if result.code ~= 0 then
      vim.schedule(function()
        notify_once(
          "list_panes_failed",
          "`zellij action list-panes` failed; is the `zellij` CLI on PATH?",
          vim.log.levels.ERROR
        )
      end)
      on_done({})
      return
    end

    local ok, panes = pcall(vim.json.decode, result.stdout or "")
    if not ok or type(panes) ~= "table" then
      on_done({})
      return
    end

    local ids = {}
    for _, pane in ipairs(panes) do
      if not pane.is_plugin and not pane.exited and tostring(pane.id) ~= tostring(except_id) then
        table.insert(ids, pane.id)
      end
    end
    on_done(ids)
  end)
end

local function set_pane_color(id, extra_args)
  local cmd = { "zellij", "action", "set-pane-color", "-p", tostring(id) }
  vim.list_extend(cmd, extra_args)
  run_zellij_action(cmd, function(result)
    if result.code ~= 0 then
      vim.schedule(function()
        notify_once(
          "set_pane_color_failed",
          "`zellij action set-pane-color` failed for at least one pane (requires zellij >= 0.44.0)",
          vim.log.levels.ERROR
        )
      end)
    end
  end)
end

-- Pushes the current colorscheme's bg/fg to every other pane in the zellij
-- session, via `zellij action set-pane-color`. No-op outside zellij, when
-- sync_pane_backgrounds is disabled, or when Normal has no bg/fg set.
function M.apply()
  if not enabled() then
    return
  end

  local bg, fg = colors.hl_colors()
  if not bg then
    return
  end

  list_other_pane_ids(vim.env.ZELLIJ_PANE_ID, function(ids)
    for _, id in ipairs(ids) do
      known_ids[id] = true
      set_pane_color(id, { "--bg", bg, "--fg", fg })
    end
  end)
end

-- Colors any pane that showed up since the last apply()/poll() — panes
-- created after a `:colorscheme` switch otherwise keep zellij's default
-- background until the next one. Cheap when nothing's new: one
-- `list-panes` call and zero `set-pane-color` calls.
function M.poll()
  if not enabled() then
    return
  end

  local bg, fg = colors.hl_colors()
  if not bg then
    return
  end

  list_other_pane_ids(vim.env.ZELLIJ_PANE_ID, function(ids)
    for _, id in ipairs(ids) do
      if not known_ids[id] then
        known_ids[id] = true
        set_pane_color(id, { "--bg", bg, "--fg", fg })
      end
    end
  end)
end

-- Resets every other pane's color to zellij's own defaults, mirroring
-- osc.lua's reset-on-exit behavior for the current pane.
function M.reset()
  if not enabled() then
    return
  end

  list_other_pane_ids(vim.env.ZELLIJ_PANE_ID, function(ids)
    for _, id in ipairs(ids) do
      set_pane_color(id, { "--reset" })
    end
  end)
end

function M.is_polling()
  return timer ~= nil
end

-- Starts a timer that calls poll() every pane_poll_interval_ms, so panes
-- created between colorscheme switches still get caught. No-op if already
-- polling, disabled, or pane_poll_interval_ms <= 0.
function M.start_polling()
  if timer or not enabled() then
    return
  end

  local interval = config.options.pane_poll_interval_ms
  if not interval or interval <= 0 then
    return
  end

  timer = vim.uv.new_timer()
  timer:start(interval, interval, vim.schedule_wrap(M.poll))
end

function M.stop_polling()
  if not timer then
    return
  end
  timer:stop()
  timer:close()
  timer = nil
end

return M
