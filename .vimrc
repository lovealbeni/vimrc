set completeopt=menu,menuone,noselect
set complete+=.
set complete-=w
set complete-=b
set complete-=u
set complete-=t

set tags=./tags,tags;

set path+=**

set wildmenu
set wildmode=list:longest,full

syntax on

set number

filetype on

filetype indent on

set hlsearch

set incsearch

set smartindent

" 自动检测并设置 shiftwidth
function! SetIndent()
    let l:line = getline(1, 100)
    let l:indent = 999
    for l:x in l:line
        let l:temp_indent = len(matchstr(l:x, '^\s*')) - len(substitute(matchstr(l:x, '^\s*'), '\t', '    ', 'g'))
        if l:temp_indent > 0 && l:temp_indent < l:indent
            let l:indent = l:temp_indent
        endif
    endfor
    if l:indent != 999
        let &shiftwidth = l:indent
        let &tabstop = l:indent
        let &softtabstop = l:indent
    endif
endfunction

" 当打开文件时自动运行
autocmd BufReadPost * call SetIndent()

" 自动触发补全菜单
inoremap <expr> <Tab> pumvisible() ? "\<C-n>" : 
            \ getline('.')[col('.')-2] =~# '\w' ? "\<C-n>" : "\<Tab>"
inoremap <expr> <S-Tab> pumvisible() ? "\<C-p>" : "\<S-Tab>"


