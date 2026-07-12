-- option.vim からのLua移植。挙動は同一
local opt = vim.opt

-- ######################## 見た目 ########################
opt.termguicolors = true -- True Color対応
opt.title = true -- ターミナルのタブ名に現在編集中のファイル名を設定
opt.number = true -- 行番号を表示する
opt.relativenumber = true -- 行番号を今いる行から相対的に表示する(13ddとかするときに便利)
opt.wrap = true -- 右端まで表示される行を折り返して表示する
opt.showmatch = true -- 括弧入力時の対応する括弧を表示
opt.list = true -- 不可視文字(改行記号など)の可視化
-- デフォルト不可視文字は美しくないのでUnicodeできれいに
opt.listchars = { tab = "»-", trail = "-", extends = "»", precedes = "«", nbsp = "%", eol = "↲" }
opt.matchtime = 3 -- 対応括弧のハイライト表示を3sにする

-- ######################## 検索・置換 ########################
opt.ignorecase = true -- 大文字小文字の区別なく検索する
opt.smartcase = true -- 検索文字列に大文字が含まれている場合は区別して検索する
opt.wrapscan = true -- 検索時に最後まで行ったら最初に戻る
opt.hlsearch = true -- 検索語をハイライト表示
opt.incsearch = true -- 検索文字列入力時に順次対象文字列にヒットさせる
opt.inccommand = "split" -- インタラクティブに変更

-- ######################## インデント ########################
opt.smartindent = true -- オートインデント
opt.expandtab = true -- タブの代わりにスペースを挿入
opt.tabstop = 4 -- スペースn個分で1つのタブとしてカウントするか
opt.softtabstop = 4 -- <tab>を押したとき、n個のスペースを挿入
opt.shiftwidth = 4 -- <Enter>や<<, >>などを押したとき、n個のスペースを挿入

-- ######################## 補完 ########################
opt.wildmode = "list:longest" -- コマンドラインの補完
opt.infercase = true -- 補完時に大文字小文字を区別しない
opt.wildmenu = true -- コマンドの補完を有効に

-- ######################## 操作 ########################
opt.clipboard:append("unnamedplus") -- クリップボードにコピーできるようにする
opt.backspace = { "indent", "eol", "start" } -- backspaceで様々な文字を消せるようにする
opt.hidden = true -- タブを切り替えるときに保存していなくてもOKにする
opt.textwidth = 0 -- 自動改行する文字数

-- ######################## ログ ########################
opt.history = 500 -- 保持するコマンド履歴の数
opt.swapfile = false -- swapファイルを保存しない
opt.undofile = false -- undoファイルを保存しない
opt.backup = false -- backupを保存しない
opt.writebackup = false -- writebackupを保存しない
opt.shada = "" -- shadaファイルに保存しない

-- ######################## 外部変更の自動検知 ########################
opt.autoread = true -- 外部でファイルが変更されたら自動で読み込む
opt.updatetime = 1000 -- CursorHoldイベントの発火を1秒後に(デフォルト4秒)

local checktime = vim.api.nvim_create_augroup("auto-checktime", { clear = true })
-- カーソル停止時・フォーカス復帰時・バッファ切替時にファイル変更をチェック
vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI", "FocusGained", "BufEnter" }, {
  group = checktime,
  command = "checktime",
})

-- ######################## その他 ########################
-- ファイル保存時にディレクトリがなかったら作成するか問う
local auto_mkdir = vim.api.nvim_create_augroup("vimrc-auto-mkdir", { clear = true })
vim.api.nvim_create_autocmd("BufWritePre", {
  group = auto_mkdir,
  callback = function(args)
    local dir = vim.fn.fnamemodify(args.file, ":p:h")
    if vim.fn.isdirectory(dir) == 1 then
      return
    end
    local force = vim.v.cmdbang == 1
    if not force then
      local answer = vim.fn.input(string.format('"%s" does not exist. Create? [y/N]', dir)):lower()
      if answer ~= "y" and answer ~= "ye" and answer ~= "yes" then
        return
      end
    end
    vim.fn.mkdir(dir, "p")
  end,
})
