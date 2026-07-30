local colors = require("zj-theme.colors")
local config = require("zj-theme.config")
local sync = require("zj-theme.sync")

local M = {}

local ESC, BEL = "\027", "\007"

local function osc(code, payload)
  return ESC .. "]" .. code .. (payload and (";" .. payload) or "") .. BEL
end

local tty, tty_checked = nil, false

local function get_tty()
  if not tty_checked then
    tty_checked = true
    tty = vim.uv.new_tty(1, false) -- nil if stdout isn't a real terminal
  end
  return tty
end

-- Exposed for tests: the actual byte-sending step, so tests can stub it
-- (save/replace/restore, same shape as vim.system stubbing elsewhere in this
-- repo) instead of needing a real controlling terminal on fd 1.
function M.write(bytes)
  local h = get_tty()
  if h then
    h:write(bytes)
  end
end

local function enabled()
  return config.options.sync_pane_backgrounds ~= false and sync.in_zellij_session()
end

-- Colors the pane nvim itself is running in to match the current
-- colorscheme: OSC 11 for background, OSC 12 for cursor (colored via fg).
-- No-op outside zellij, when sync_pane_backgrounds is disabled, when
-- Normal has no bg/fg, or when stdout isn't a real terminal. Unlike
-- pane_bg.lua's mechanism, this one has no zellij-CLI/version dependency —
-- it's a plain terminal capability — so it keeps working even if the
-- `zellij` CLI is missing or too old for `set-pane-color`.
function M.apply()
  if not enabled() then
    return
  end

  local bg, fg = colors.hl_colors()
  if not bg then
    return
  end

  M.write(osc("11", bg))
  M.write(osc("12", fg))
end

-- Restores the terminal's own default background/cursor color.
function M.reset()
  if not enabled() then
    return
  end

  M.write(osc("111"))
  M.write(osc("112"))
end

return M
