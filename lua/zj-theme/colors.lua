local M = {}

-- Reads the current colorscheme's Normal bg/fg, formatted as "#rrggbb".
-- Single source of truth for pane_bg.lua's "what color should panes be
-- right now". Returns nil, nil if Normal has no bg/fg set.
function M.hl_colors()
  local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false, create = false })
  if not normal.bg or not normal.fg then
    return nil, nil
  end
  return string.format("#%06x", normal.bg), string.format("#%06x", normal.fg)
end

return M
