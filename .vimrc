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

" 添加自动触发补全的设置
augroup AutoComplete
    autocmd!
    autocmd InsertCharPre * if pumvisible() == 0 | call feedkeys("\<C-x>\<C-u>", 'n') | endif
augroup END

" 修改自动补全触发
inoremap <expr> <C-p> pumvisible() ? "\<C-p>" : "\<C-x>\<C-u>"

" 添加新的自动补全函数
function! ProjectComplete(findstart, base)
    if a:findstart
        " 获取光标前的文本
        let line = getline('.')
        let start = col('.') - 1
        while start > 0 && line[start - 1] =~ '\a'
            let start -= 1
        endwhile
        return start
    else
        let results = []
        let patterns = ['**/*.py', '**/*.js', '**/*.cpp', '**/*.h']
        
        " 对每个文件类型进行搜索
        for pattern in patterns
            let files = glob(pattern, 0, 1)
            for file in files
                if filereadable(file)
                    " 读取文件内容并查找匹配
                    let content = readfile(file)
                    for line in content
                        let words = split(line, '\W\+')
                        for word in words
                            if word =~ '^' . a:base && len(results) < 5
                                call add(results, {'word': word, 'menu': '[' . fnamemodify(file, ':t') . ']'})
                            endif
                        endfor
                        " 如果已经找到5个匹配项，就停止搜索
                        if len(results) >= 5
                            break
                        endif
                    endfor
                endif
                if len(results) >= 5
                    break
                endif
            endfor
            if len(results) >= 5
                break
            endif
        endfor
        return results
    endif
endfunction

" 设置自定义补全
set completefunc=ProjectComplete

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
