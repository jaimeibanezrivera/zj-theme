local M = {}

-- Reads the current colorscheme's Normal bg/fg, formatted as "#rrggbb".
-- Shared by pane_bg.lua (other panes, via the zellij CLI) and osc.lua (the
-- pane nvim itself runs in, via raw terminal escape sequences), so both read
-- colors from exactly one place. Returns nil, nil if Normal has no bg/fg set.
function M.hl_colors()
  local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false, create = false })
  if not normal.bg or not normal.fg then
    return nil, nil
  end
  return string.format("#%06x", normal.bg), string.format("#%06x", normal.fg)
end

return M
