set completeopt=menu,menuone,noselect
set complete+=.
set complete+=w
set complete+=b
set complete+=u
set complete+=t
set complete+=i

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
" 在进入插入模式时自动触发补全菜单
inoremap <silent> <C-n> <C-n><C-r>=pumvisible() ? "\<Down>" : ""<CR>
autocmd InsertEnter * call feedkeys("\<C-n>", 'n')

" 在插入模式下每次输入都触发补全菜单
function! TriggerCompletion()
    " 检查是否在特殊文件类型中
    if &filetype == 'help' || &filetype == 'gitcommit'
        return ""
    endif
    
    " 检查是否已经在补全菜单中
    if pumvisible()
        return ""
    endif
    
    " 检查当前行是否为空
    if getline('.') =~ '^\s*$'
        return ""
    endif
    
    " 触发补全
    call feedkeys("\<C-n>", 'n')
    return ""
endfunction

" 为所有可打印字符创建映射
for char in range(32, 126)
    execute 'inoremap <Char-' . char . '> <Char-' . char . '><C-r>=TriggerCompletion()<CR>'
endfor

" 为特殊键创建映射
inoremap <Space> <Space><C-r>=TriggerCompletion()<CR>
inoremap <Tab> <Tab><C-r>=TriggerCompletion()<CR>
inoremap <CR> <CR><C-r>=TriggerCompletion()<CR>
