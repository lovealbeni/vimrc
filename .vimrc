let mapleader=" "
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

" 重映射快捷键（这里用 <leader>f，你可以改成你喜欢的键）
nnoremap <leader>p :call FindWithoutSlashes()<CR>

function! FindWithoutSlashes()
    " 获取光标下的单词
    let word = expand('<cword>')
    " 去掉所有的斜杠
    let word = substitute(word, '/', '', 'g')
    " 执行查找
    execute 'find ' . word
endfunction

syntax on

set number

filetype on

filetype indent on

set hlsearch

set incsearch

set smartindent

" Set default indentation to 2 spaces
set shiftwidth=2
set tabstop=2
set softtabstop=2
set expandtab

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
nnoremap <leader>f :find<Space>

filetype plugin indent on

autocmd FileType html setl ofu=htmlcomplete#CompleteTags
autocmd FileType css setl ofu=csscomplete#CompleteCSS
autocmd FileType javascript,typescript setl ofu=javascriptcomplete#CompleteJS
autocmd FileType typescriptreact setl ofu=javascriptcomplete#CompleteJS
set omnifunc=syntaxcomplete#Complete

" 自动读取文件变化配置
set autoread
set updatetime=1000

" 定时检查文件变化
augroup AutoReload
  autocmd!
  autocmd CursorHold,CursorHoldI * checktime
  autocmd BufEnter * checktime
  autocmd FocusGained * checktime
augroup END

" 可选：添加文件修改提示
set report=0

" 可选：在状态栏显示文件状态
set statusline+=%{&modified?'[+]':''}
set laststatus=2

" ===== 纯 Vimscript 模糊搜索（文件名 / 内容，带预览，回车打开选中文件） =====
" 用法：
"   <leader>ff  模糊搜索项目文件名，右侧预览，回车打开选中文件
"   <leader>fg  搜索项目内容（变量名、字符串等，输入即搜），回车打开并跳转到匹配行
"   可视模式 <leader>fg  把选中内容作为全局搜索的关键词
" 搜索窗口中：Ctrl-j / Ctrl-k（或方向键）上下选择，回车打开，Esc 关闭，退格删除字符
" 依赖 ripgrep(rg)；没有 rg 时文件名搜索自动退化为 globpath

let s:ff = {'kind': 'files', 'query': '', 'items': [], 'matches': [], 'sel': 0,
      \ 'list_id': -1, 'prev_id': -1, 'maxshow': 300}

" 选中行 / 预览中匹配行的高亮类型
if empty(prop_type_get('ff_sel'))
  call prop_type_add('ff_sel', #{highlight: 'PmenuSel', priority: 10})
endif
if empty(prop_type_get('ff_match'))
  call prop_type_add('ff_match', #{highlight: 'Search', priority: 10})
endif

function! s:FuzzyStart(kind, ...) abort
  let s:ff.kind = a:kind
  let s:ff.query = a:0 > 0 ? a:1 : ''
  let s:ff.matches = []
  let s:ff.sel = 0
  if a:kind ==# 'files'
    if executable('rg')
      let s:ff.items = systemlist('rg --files --hidden --glob "!.git" 2>/dev/null')
    else
      let s:ff.items = filter(split(globpath('.', '**/*'), "\n"), '!isdirectory(v:val)')
    endif
  else
    let s:ff.items = []
  endif

  let l:total_w = &columns - 8
  let l:list_w = float2nr(l:total_w * 0.45)
  let l:h = &lines - 10

  " 右侧预览窗口
  let s:ff.prev_id = popup_create([''], #{
        \ title: ' 预览 ',
        \ line: 3, col: 6 + l:list_w,
        \ minwidth: l:total_w - l:list_w - 2, maxwidth: l:total_w - l:list_w - 2,
        \ minheight: l:h, maxheight: l:h,
        \ border: [], wrap: 0, scrollbar: 0,
        \ })

  " 左侧列表窗口（接收键盘输入）
  let s:ff.list_id = popup_create([''], #{
        \ title: ' ',
        \ line: 3, col: 4,
        \ minwidth: l:list_w, maxwidth: l:list_w,
        \ minheight: l:h, maxheight: l:h,
        \ border: [], padding: [0, 1, 0, 1],
        \ wrap: 0, mapping: 0,
        \ filter: function('s:FuzzyFilter'),
        \ })

  call s:FuzzyUpdate()
endfunction

function! s:FuzzyFilter(id, key) abort
  if a:key ==# "\<Esc>" || a:key ==# "\<C-c>"
    call s:FuzzyClose()
  elseif a:key ==# "\<CR>"
    call s:FuzzyAccept()
  elseif a:key ==# "\<C-j>" || a:key ==# "\<C-n>" || a:key ==# "\<Down>"
    call s:FuzzyMove(1)
  elseif a:key ==# "\<C-k>" || a:key ==# "\<C-p>" || a:key ==# "\<Up>"
    call s:FuzzyMove(-1)
  elseif a:key ==# "\<BS>" || a:key ==# "\<C-h>"
    if !empty(s:ff.query)
      let s:ff.query = strcharpart(s:ff.query, 0, strchars(s:ff.query) - 1)
      call s:FuzzyUpdate()
    endif
  elseif strchars(a:key) == 1 && char2nr(a:key) >= 32
    let s:ff.query .= a:key
    call s:FuzzyUpdate()
  endif
  return 1
endfunction

" 上下移动选中项（循环），并刷新高亮和预览
function! s:FuzzyMove(step) abort
  if empty(s:ff.matches)
    return
  endif
  let s:ff.sel = (s:ff.sel + a:step) % len(s:ff.matches)
  if s:ff.sel < 0
    let s:ff.sel += len(s:ff.matches)
  endif
  call s:FuzzyRender()
  call s:FuzzyPreview()
endfunction

function! s:FuzzyUpdate() abort
  if s:ff.kind ==# 'files'
    if empty(s:ff.query)
      let s:ff.matches = s:ff.items[:s:ff.maxshow - 1]
    else
      let s:ff.matches = matchfuzzy(s:ff.items, s:ff.query)[:s:ff.maxshow - 1]
    endif
  else
    if strchars(s:ff.query) >= 2
      let l:cmd = 'rg --vimgrep --no-heading --smart-case --hidden'
            \ . ' --glob "!.git" -- ' . shellescape(s:ff.query)
            \ . ' 2>/dev/null | head -n ' . s:ff.maxshow
      let s:ff.matches = systemlist(l:cmd)
    else
      let s:ff.matches = []
    endif
  endif
  let s:ff.sel = 0
  call popup_setoptions(s:ff.list_id, #{title:
        \ (s:ff.kind ==# 'files' ? ' 文件: ' : ' 内容: ') . s:ff.query . ' '})
  call s:FuzzyRender()
  call s:FuzzyPreview()
endfunction

" 重绘列表，用文本属性高亮当前选中行
function! s:FuzzyRender() abort
  let l:lines = []
  let l:i = 0
  for l:item in s:ff.matches
    if l:i == s:ff.sel
      call add(l:lines, #{text: l:item,
            \ props: [#{col: 1, length: max([1, strlen(l:item)]), type: 'ff_sel'}]})
    else
      call add(l:lines, #{text: l:item})
    endif
    let l:i += 1
  endfor
  if empty(l:lines)
    let l:lines = [#{text: '（无结果）'}]
  endif
  call popup_settext(s:ff.list_id, l:lines)
endfunction

function! s:FuzzyCurrent() abort
  if empty(s:ff.matches) || s:ff.sel >= len(s:ff.matches)
    return ''
  endif
  return s:ff.matches[s:ff.sel]
endfunction

function! s:FuzzyPreview() abort
  let l:item = s:FuzzyCurrent()
  if empty(l:item)
    call popup_settext(s:ff.prev_id, [''])
    return
  endif
  let l:lnum = 1
  if s:ff.kind ==# 'files'
    let l:path = l:item
  else
    " rg --vimgrep 输出格式： 文件:行:列:内容
    let l:m = matchlist(l:item, '^\([^:]*\):\(\d\+\):')
    let l:path = l:m[1]
    let l:lnum = str2nr(l:m[2])
  endif
  if empty(l:path) || !filereadable(l:path)
    call popup_settext(s:ff.prev_id, ['（无法预览）'])
    return
  endif
  " 让匹配行显示在预览窗口靠上的位置
  let l:start = max([0, l:lnum - 6])
  let l:lines = readfile(l:path, '', l:lnum + 200)[l:start :]
  if empty(l:lines)
    let l:lines = ['（空文件或二进制文件）']
  endif
  " 统一转成 dict（popup_settext 不允许字符串和 dict 混用）；
  " 内容搜索时高亮预览中的匹配行
  let l:idx = l:lnum - 1 - l:start
  call map(l:lines, {i, v -> (s:ff.kind ==# 'grep' && i == l:idx)
        \ ? #{text: v, props: [#{col: 1, length: max([1, strlen(v)]), type: 'ff_match'}]}
        \ : #{text: v}})
  call popup_settext(s:ff.prev_id, l:lines)
  call popup_setoptions(s:ff.prev_id, #{title: ' ' . l:path . ' '})
endfunction

function! s:FuzzyAccept() abort
  let l:item = s:FuzzyCurrent()
  if empty(l:item)
    return
  endif
  let l:kind = s:ff.kind
  call s:FuzzyClose()
  if l:kind ==# 'files'
    execute 'edit ' . fnameescape(l:item)
  else
    let l:m = matchlist(l:item, '^\([^:]*\):\(\d\+\):')
    if !empty(l:m[1])
      execute 'edit +' . l:m[2] . ' ' . fnameescape(l:m[1])
      normal! zz
    endif
  endif
endfunction

function! s:FuzzyClose() abort
  if s:ff.list_id > 0
    call popup_close(s:ff.list_id)
  endif
  if s:ff.prev_id > 0
    call popup_close(s:ff.prev_id)
  endif
  let s:ff.list_id = -1
  let s:ff.prev_id = -1
  redraw
endfunction

command! FFiles call <SID>FuzzyStart('files')
command! FGrep  call <SID>FuzzyStart('grep')
nnoremap <leader>ff :FFiles<CR>
nnoremap <leader>fg :FGrep<CR>

" 可视模式下 <leader>fg：把选中的内容作为全局搜索的关键词（结果带预览，回车打开）
function! s:VisualSearch() abort
  let l:save = @"
  normal! gvy
  let l:text = @"
  let @" = l:save
  " 多行选择时取第一行，去掉首尾空白
  let l:text = trim(split(l:text, "\n")[0])
  if !empty(l:text)
    call s:FuzzyStart('grep', l:text)
  endif
endfunction
xnoremap <leader>fg :<C-u>call <SID>VisualSearch()<CR>

" ===== 纯 Vimscript 文件树侧边栏 =====
" <leader>e 开关侧边栏
" 树中按键：回车(或 o) 打开文件 / 展开折叠目录，r 刷新，q 关闭

let s:tree = {'bufnr': -1, 'expanded': {}, 'lines': []}

function! s:TreeToggle() abort
  let l:win = bufwinid(s:tree.bufnr)
  if l:win != -1
    call win_gotoid(l:win)
    close
    return
  endif
  call s:TreeOpen()
endfunction

function! s:TreeOpen() abort
  let s:tree.expanded = {}
  topleft vertical 30new
  let s:tree.bufnr = bufnr('%')
  setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted
  setlocal nonumber norelativenumber nowrap signcolumn=no cursorline winfixwidth
  file FileTree
  nnoremap <buffer> <CR> :call <SID>TreeActivate()<CR>
  nnoremap <buffer> o :call <SID>TreeActivate()<CR>
  nnoremap <buffer> r :call <SID>TreeRender()<CR>
  nnoremap <buffer> q :close<CR>
  call s:TreeRender()
endfunction

function! s:TreeRender() abort
  let s:tree.lines = []
  let l:display = []
  call s:TreeAddNodes(getcwd(), 0, l:display, 0)
  if empty(l:display)
    let l:display = ['（空目录）']
  endif
  let l:buf = s:tree.bufnr
  call setbufvar(l:buf, '&modifiable', 1)
  call setbufline(l:buf, 1, l:display)
  let l:total = len(getbufline(l:buf, 1, '$'))
  if l:total > len(l:display)
    call deletebufline(l:buf, len(l:display) + 1, l:total)
  endif
  call setbufvar(l:buf, '&modifiable', 0)
endfunction

" 递归构建目录内容：目录在前，文件在后，按名称排序（忽略大小写）
function! s:TreeAddNodes(dir, depth, display, guard) abort
  if a:guard > 20
    return
  endif
  let l:entries = readdir(a:dir)
  call filter(l:entries, 'v:val !=# ".git"')
  let l:dirs = filter(copy(l:entries), 'isdirectory(a:dir . "/" . v:val)')
  let l:files = filter(copy(l:entries), '!isdirectory(a:dir . "/" . v:val)')
  call sort(l:dirs, 'i')
  call sort(l:files, 'i')
  for l:name in l:dirs + l:files
    let l:path = a:dir . '/' . l:name
    let l:isdir = isdirectory(l:path)
    let l:indent = repeat('  ', a:depth)
    if l:isdir
      let l:open = get(s:tree.expanded, l:path, 0)
      call add(a:display, l:indent . (l:open ? '▾ ' : '▸ ') . l:name . '/')
      call add(s:tree.lines, #{path: l:path, isdir: 1})
      if l:open
        call s:TreeAddNodes(l:path, a:depth + 1, a:display, a:guard + 1)
      endif
    else
      call add(a:display, l:indent . '  ' . l:name)
      call add(s:tree.lines, #{path: l:path, isdir: 0})
    endif
  endfor
endfunction

function! s:TreeActivate() abort
  let l:idx = line('.') - 1
  if l:idx < 0 || l:idx >= len(s:tree.lines)
    return
  endif
  let l:node = s:tree.lines[l:idx]
  if l:node.isdir
    let s:tree.expanded[l:node.path] = !get(s:tree.expanded, l:node.path, 0)
    let l:lnum = line('.')
    call s:TreeRender()
    call cursor(min([l:lnum, line('$')]), 1)
  else
    " 在之前的窗口中打开文件，焦点随之过去
    wincmd p
    execute 'edit ' . fnameescape(l:node.path)
  endif
endfunction

nnoremap <leader>e :call <SID>TreeToggle()<CR>
