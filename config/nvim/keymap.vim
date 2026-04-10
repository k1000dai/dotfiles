" leaderをスペースに変更
let mapleader = "\<Space>"

" 入力モード中に素早くjjと入力した場合はESCとみなす
inoremap <silent> jj <Esc>:<C-u>w<CR>
" terminalモード中に素早くjjと入力した場合はESCとみなす"
tnoremap <Esc> <C-\><C-n>
tnoremap <silent> jj <C-\><C-n>
" ESCを2回押すことでハイライトを消す
nmap <silent> <Esc><Esc> :nohlsearch<CR>

" ##### ウィンドウ操作系 #####
" 画面をspace+vで縦に分割する
nnoremap <silent> <Leader>v :vs<CR>
" 画面をspace+sで横に分割する
nnoremap <silent> <Leader>s :sp<CR>
" space + +でウィンドウを拡大する
nnoremap <silent> <Leader>+ :vertical resize +5<CR>
" space + -でウィンドウを縮小する
nnoremap <silent> <Leader>- :vertical resize -5<CR>

" hjklの方向ににカーソルを移動させる
nnoremap <silent> <Leader>h <C-w>h
nnoremap <silent> <Leader>j <C-w>j
nnoremap <silent> <Leader>k <C-w>k
nnoremap <silent> <Leader>l <C-w>l

" ##### 行・列関係 #####

" 文章が画面の右端に到達すると折り返す設定をoption.vimで入れている
" hjklはデフォルトだと、折り返す前の表示で上下左右に移動できる
" つまり、折り返して表示した状態だと直感と実際のhjklの動作が違う
" これを修正するオプションがしたの4つ
nnoremap j gj
nnoremap k gk
vnoremap j gj
vnoremap k gk

" 補完は nvim-cmp で設定 (lua/plugins.lua)

