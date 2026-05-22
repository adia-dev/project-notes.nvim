local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
local data_home = vim.fn.tempname()

vim.env.XDG_DATA_HOME = data_home .. "/data"
vim.env.XDG_STATE_HOME = data_home .. "/state"
vim.env.XDG_CACHE_HOME = data_home .. "/cache"

vim.opt.runtimepath:prepend(root)
package.path = root .. "/?.lua;" .. root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

vim.opt.swapfile = false
vim.g.mapleader = " "
