# Records zj-theme.nvim syncing zellij's theme live as the active nvim
# colorscheme changes, cycling through catppuccin, gruvbox-material,
# tokyonight, PaperColor (light), and finishing on carbonfox.
#
# Run from the repo root: vhs demo.tape

Require zellij
Require nvim

Output assets/demo.gif

Set Shell "zsh"
Set FontSize 14
Set Width 1200
Set Height 700
Set Padding 10
Set TypingSpeed 60ms
Set Framerate 15

Type "zellij"
Enter
Sleep 2s
Escape
Sleep 500ms

Type "nvim lua/zj-theme/mappings.lua"
Enter
Sleep 1.5s

Type ":colorscheme catppuccin"
Enter
Sleep 3s

Type ":colorscheme gruvbox-material"
Enter
Sleep 3s

Type ":colorscheme tokyonight"
Enter
Sleep 3s

Type ":colorscheme PaperColor"
Enter
Sleep 3s

Type ":colorscheme carbonfox"
Enter
Sleep 4s
