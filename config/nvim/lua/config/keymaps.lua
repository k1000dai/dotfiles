-- keymap.vim からのLua移植。挙動は同一
-- (mapleader は init.lua 冒頭で設定済み)
local map = vim.keymap.set

-- 入力モード中に素早くjjと入力した場合はESCとみなす(保存も行う)
map("i", "jj", "<Esc>:<C-u>w<CR>", { silent = true })
-- terminalモードからの離脱
map("t", "<Esc>", "<C-\\><C-n>")
map("t", "jj", "<C-\\><C-n>", { silent = true })
-- ESCを2回押すことでハイライトを消す
map("n", "<Esc><Esc>", ":nohlsearch<CR>", { silent = true })

-- ##### ウィンドウ操作系 #####
map("n", "<Leader>v", ":vs<CR>", { silent = true }) -- 縦分割
map("n", "<Leader>s", ":sp<CR>", { silent = true }) -- 横分割
map("n", "<Leader>+", ":vertical resize +5<CR>", { silent = true }) -- 拡大
map("n", "<Leader>-", ":vertical resize -5<CR>", { silent = true }) -- 縮小

-- hjklの方向にカーソルを移動させる
map("n", "<Leader>h", "<C-w>h", { silent = true })
map("n", "<Leader>j", "<C-w>j", { silent = true })
map("n", "<Leader>k", "<C-w>k", { silent = true })
map("n", "<Leader>l", "<C-w>l", { silent = true })

-- ##### 行・列関係 #####
-- 折り返し表示された行を見た目通りに上下移動する
map({ "n", "v" }, "j", "gj")
map({ "n", "v" }, "k", "gk")
