if vim.g.loaded_zj_theme then
  return
end
vim.g.loaded_zj_theme = true

vim.api.nvim_create_user_command("ZjThemeNow", function()
  require("zj-theme").sync_now()
end, { desc = "Re-apply the current nvim colorscheme's mapped zellij theme" })
