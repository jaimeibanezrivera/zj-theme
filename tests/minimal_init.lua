-- Minimal init used to run the test suite headlessly, independent of the
-- user's actual nvim config. Assumes plenary.nvim is installed somewhere
-- discoverable (defaults to the common lazy.nvim install path; override with
-- $PLENARY_DIR if yours lives elsewhere).
local plenary_dir = os.getenv("PLENARY_DIR") or vim.fn.expand("~/.local/share/nvim/lazy/plenary.nvim")

vim.opt.rtp:append(".")
vim.opt.rtp:append(plenary_dir)

require("plenary.busted")
