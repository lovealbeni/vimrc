set completeopt=menu,menuone,noselect
set complete+=.
set complete+=w
set complete+=b
set complete+=u
set complete+=t

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

inoremap <expr> <silent> <C-p> pumvisible() ? '<C-p>' : '<C-p><C-p>'

augroup AutoComplete
    autocmd!
    autocmd InsertCharPre * if pumvisible() == 0 | call feedkeys("\<C-p>", 'n') | endif
augroup END

let g:loaded_files = []

let g:last_tags_update = 0
let g:tags_update_interval = 300  " 5分钟间隔

function! UpdateTagsWithStatus()
    let l:current_time = localtime()
    
    " 检查是否需要更新
    if l:current_time - g:last_tags_update < g:tags_update_interval
        return
    endif
    
    let l:gitdir = system('git rev-parse --show-toplevel 2>/dev/null')[:-2]
    if l:gitdir == ''
        return
    endif
    
    " 显示更新状态 使用ctags更新，需要安装ctags
    echo "Updating tags..."
    
    if has('job')
        let l:job = job_start('cd ' . l:gitdir . ' && ctags -R --exclude=dist .', {
            \ 'exit_cb': function('TagsUpdateComplete')
            \ })
    elseif has('nvim')
        let l:job_id = jobstart('cd ' . l:gitdir . ' && ctags -R --exclude=dist .', {
            \ 'on_exit': function('TagsUpdateComplete')
            \ })
    else
        call system('cd ' . l:gitdir . ' && ctags -R --exclude=node_modules --exclude=dist .')
        call TagsUpdateComplete()
    endif
    
    let g:last_tags_update = l:current_time
endfunction

function! TagsUpdateComplete(...)
    echo "Tags updated successfully!"
endfunction

" 自动更新
autocmd BufWritePost *.py,*.js,*.cpp,*.h silent! call UpdateTagsWithStatus()

" 手动更新快捷键
nnoremap <leader>ut :call UpdateTagsWithStatus()<CR>

function! LoadAllFiles()
    if len(g:loaded_files) > 0
        return
    endif
    
    let l:patterns = ['**/*.py', '**/*.js', '**/*.cpp', '**/*.h']
    
    for l:pattern in l:patterns
        let l:files = glob(l:pattern, 0, 1)
        for l:file in l:files
            if filereadable(l:file)
                execute 'badd ' . fnameescape(l:file)
                call add(g:loaded_files, l:file)
            endif
        endfor
    endfor
endfunction

command! Gan call LoadAllFiles()
