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
  " 文件在磁盘上被修改且 vim 中也有未保存修改时，询问如何处理
  autocmd FileChangedShell * call <SID>HandleFileChanged()
augroup END

" 外部修改与 vim 本地修改冲突时的处理（popup 弹窗询问）：
"   Y   = 覆盖：用 vim 中的内容写回磁盘（保留 vim 修改）
"   N   = 不覆盖：放弃 vim 中的修改，加载磁盘上的最新内容
"   Esc = 暂不处理，保留 vim 修改，下次触发时再询问
function! s:HandleFileChanged() abort
  let l:buf = str2nr(expand('<abuf>'))
  " vim 中没有本地修改时交给 autoread 自动加载，无需处理
  if !getbufvar(l:buf, '&modified')
    return
  endif
  " 有本地修改时由本函数全权处理，阻止 vim 默认的 W12 警告
  let v:fcs_choice = ''
  let l:name = fnamemodify(bufname(l:buf), ':t')
  if v:fcs_reason ==# 'deleted'
    echohl WarningMsg
    echom '文件 "' . l:name . '" 已在磁盘上被删除，vim 中的内容保持不变'
    echohl None
    return
  endif
  " 只是时间戳变化（内容相同）时不打扰
  if v:fcs_reason !=# 'changed' && v:fcs_reason !=# 'conflict'
    return
  endif
  " 该 buffer 已有弹窗时不重复弹
  if getbufvar(l:buf, 'conflict_popup', 0)
    return
  endif
  call setbufvar(l:buf, 'conflict_popup', 1)
  call popup_dialog(
        \ '文件 "' . l:name . '" 在磁盘上发生了变化，' . "\n"
        \ . '且 vim 中也有未保存的修改。' . "\n\n"
        \ . '是否用 vim 中的内容覆盖磁盘文件？' . "\n\n"
        \ . '[Y] 覆盖（保留 vim 修改，写回磁盘）' . "\n"
        \ . '[N] 不覆盖（放弃 vim 修改，加载磁盘最新内容）' . "\n"
        \ . '[Esc] 暂不处理，保留 vim 修改',
        \ #{
        \   filter: function('s:ConflictFilter'),
        \   callback: function('s:OnConflictChoice', [l:buf]),
        \   highlight: 'FuzzyPopup',
        \   border: [],
        \   padding: [0, 2, 0, 2],
        \ })
endfunction

" 弹窗按键：Y=覆盖 N=不覆盖 Esc/Ctrl-C=稍后，其他键放行给正常编辑
function! s:ConflictFilter(id, key) abort
  if a:key ==# 'y' || a:key ==# 'Y' || a:key ==# "\<CR>"
    call popup_close(a:id, 1)
  elseif a:key ==# 'n' || a:key ==# 'N'
    call popup_close(a:id, 0)
  elseif a:key ==# "\<Esc>" || a:key ==# "\<C-c>"
    call popup_close(a:id, -1)
  else
    return 0
  endif
  return 1
endfunction

" popup_dialog 是异步的，按键结果通过回调返回；用定时器延迟执行，
" 避免在 popup 回调上下文里直接改写 buffer
function! s:OnConflictChoice(buf, id, result) abort
  call setbufvar(a:buf, 'conflict_popup', 0)
  if a:result == 1
    call timer_start(10, {t -> s:ConflictApply(a:buf, 'write!')})
  elseif a:result == 0
    call timer_start(10, {t -> s:ConflictApply(a:buf, 'edit!')})
  endif
  " 其他（Esc / Ctrl-C 关闭弹窗）：什么都不做，保留 vim 修改
endfunction

" 在指定 buffer 的窗口里执行 :write!（覆盖磁盘）或 :edit!（重新加载磁盘内容）
function! s:ConflictApply(buf, cmd) abort
  if !bufexists(a:buf) || !getbufvar(a:buf, '&modified')
    return
  endif
  let l:win = bufwinid(a:buf)
  if l:win == -1 && bufnr('%') != a:buf
    " buffer 不在任何窗口中（极少见），无法安全执行，等下次触发再询问
    return
  endif
  if a:cmd ==# 'write!'
    " write! 遇到磁盘文件已变化时会再弹一次 "(y/n)" 确认，预先回答 y 避免二次确认
    call feedkeys('y', 'nL')
  endif
  if l:win != -1
    call win_execute(l:win, a:cmd)
  else
    execute a:cmd
  endif
  if a:cmd ==# 'write!'
    echom '已用 vim 中的内容覆盖磁盘文件'
  endif
endfunction

" 可选：添加文件修改提示
set report=0

" 可选：在状态栏显示文件状态
set statusline+=%{&modified?'[+]':''}
set laststatus=2

" 每个窗口上方显示文件名（需要支持 'winbar' 的较新 Vim，不支持的版本自动跳过）
if exists('+winbar')
  set winbar=\ %f%m
endif

" ===== 纯 Vimscript 模糊搜索（文件名 / 内容，带预览，回车打开选中文件） =====
" 用法：
"   <leader>ff  模糊搜索项目文件名，右侧预览，回车打开选中文件
"   <leader>fg  搜索项目内容（变量名、字符串等，输入即搜），回车打开并跳转到匹配行
"   可视模式 <leader>ff / <leader>fg  把选中内容作为搜索关键词
"   弹窗中：回车=当前窗口打开，-=水平分屏打开，\=垂直分屏打开
" 搜索窗口中：Ctrl-j / Ctrl-k（或方向键）上下选择，回车打开，Esc 关闭，退格删除字符
" 依赖 ripgrep(rg)；没有 rg 时文件名搜索自动退化为 globpath

let s:ff = {'kind': 'files', 'query': '', 'items': [], 'matches': [], 'sel': 0,
      \ 'first': 0, 'win_h': 20, 'prev_path': '',
      \ 'list_id': -1, 'prev_id': -1, 'maxshow': 300}

" 弹窗配色：弹窗默认使用 Pmenu（浅底色），深色终端下看不清，
" 这里让弹窗跟随终端默认前景/背景色，选中行用反色显示
highlight FuzzyPopup ctermfg=NONE ctermbg=NONE guifg=NONE guibg=NONE
highlight FuzzySel cterm=reverse gui=reverse

" 选中行 / 预览中匹配行的高亮类型
if !empty(prop_type_get('ff_sel'))
  call prop_type_delete('ff_sel')
endif
call prop_type_add('ff_sel', #{highlight: 'FuzzySel', priority: 10})
if empty(prop_type_get('ff_match'))
  call prop_type_add('ff_match', #{highlight: 'Search', priority: 10})
endif

function! s:FuzzyStart(kind, ...) abort
  let s:ff.kind = a:kind
  let s:ff.query = a:0 > 0 ? a:1 : ''
  let s:ff.matches = []
  let s:ff.sel = 0
  let s:ff.first = 0
  let s:ff.prev_path = ''
  if a:kind ==# 'files'
    if executable('rg')
      let s:ff.items = systemlist('rg --files --hidden --glob "!.git" 2>/dev/null | sort')
    else
      let s:ff.items = filter(split(globpath('.', '**/*'), "\n"), '!isdirectory(v:val)')
    endif
  else
    let s:ff.items = []
  endif

  let l:total_w = &columns - 8
  let l:list_w = float2nr(l:total_w * 0.45)
  let l:h = &lines - 10
  let s:ff.win_h = l:h

  " 右侧预览窗口
  let s:ff.prev_id = popup_create([''], #{
        \ title: ' 预览 ',
        \ line: 3, col: 6 + l:list_w,
        \ minwidth: l:total_w - l:list_w - 2, maxwidth: l:total_w - l:list_w - 2,
        \ minheight: l:h, maxheight: l:h,
        \ border: [], wrap: 0, scrollbar: 0,
        \ highlight: 'FuzzyPopup',
        \ })

  " 左侧列表窗口（接收键盘输入）
  let s:ff.list_id = popup_create([''], #{
        \ title: ' ',
        \ line: 3, col: 4,
        \ minwidth: l:list_w, maxwidth: l:list_w,
        \ minheight: l:h, maxheight: l:h,
        \ border: [], padding: [0, 1, 0, 1],
        \ wrap: 0, mapping: 0,
        \ highlight: 'FuzzyPopup',
        \ filter: function('s:FuzzyFilter'),
        \ })

  call s:FuzzyUpdate()
endfunction

function! s:FuzzyFilter(id, key) abort
  if a:key ==# "\<Esc>" || a:key ==# "\<C-c>"
    call s:FuzzyClose()
  elseif a:key ==# "\<CR>"
    call s:FuzzyAccept('edit')
  elseif a:key ==# '-'
    call s:FuzzyAccept('split')
  elseif a:key ==# '\'
    call s:FuzzyAccept('vsplit')
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
      if empty(s:ff.matches)
        " 选中内容含多余字符（引号、行号、部分路径等）时的兜底：
        " 按非单词字符切分，统计每个候选命中的片段数（相似度），按相似度降序排序
        let l:tokens = filter(split(tolower(s:ff.query), '[^0-9a-zA-Z_.-]\+'), '!empty(v:val)')
        if !empty(l:tokens)
          let l:scored = []
          let l:i = 0
          for l:item in s:ff.items
            let l:lower = tolower(l:item)
            let l:score = 0
            for l:t in l:tokens
              if stridx(l:lower, l:t) >= 0
                let l:score += 1
              endif
            endfor
            if l:score > 0
              call add(l:scored, [l:score, l:i, l:item])
            endif
            let l:i += 1
          endfor
          " 相似度降序，同分保持原顺序
          call sort(l:scored, {a, b -> b[0] == a[0] ? a[1] - b[1] : b[0] - a[0]})
          let s:ff.matches = map(l:scored, 'v:val[2]')[:s:ff.maxshow - 1]
        endif
      endif
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
  let s:ff.first = 0
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
  " 让选中行始终可见：移出可见区域时滚动列表
  if s:ff.sel < s:ff.first
    let s:ff.first = s:ff.sel
  elseif s:ff.sel >= s:ff.first + s:ff.win_h
    let s:ff.first = s:ff.sel - s:ff.win_h + 1
  endif
  call popup_setoptions(s:ff.list_id, #{firstline: s:ff.first + 1})
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
    call s:PreviewSyntax('')
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
    call s:PreviewSyntax('')
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
  call s:PreviewSyntax(l:path)
endfunction

" 预览窗语法高亮：按真实文件路径检测文件类型；同一文件不重复检测
function! s:PreviewSyntax(path) abort
  if s:ff.prev_path ==# a:path
    return
  endif
  let s:ff.prev_path = a:path
  if empty(a:path)
    call win_execute(s:ff.prev_id, 'setlocal syntax=')
  else
    call win_execute(s:ff.prev_id, 'doautocmd <nomodeline> BufRead ' . fnameescape(a:path))
  endif
endfunction

" how: edit=当前窗口打开, split=水平分屏, vsplit=垂直分屏
function! s:FuzzyAccept(how) abort
  let l:item = s:FuzzyCurrent()
  if empty(l:item)
    return
  endif
  let l:kind = s:ff.kind
  call s:FuzzyClose()
  if l:kind ==# 'files'
    execute a:how . ' ' . fnameescape(l:item)
  else
    let l:m = matchlist(l:item, '^\([^:]*\):\(\d\+\):')
    if !empty(l:m[1])
      execute a:how . ' +' . l:m[2] . ' ' . fnameescape(l:m[1])
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

" 获取可视模式选中的文本（多行选择时取第一行，去掉首尾空白）
function! s:GetVisualText() abort
  let l:save = @"
  normal! gvy
  let l:text = @"
  let @" = l:save
  return trim(split(l:text, "\n")[0])
endfunction

" 可视模式下 <leader>fg：把选中的内容作为全局搜索的关键词（结果带预览，回车打开）
function! s:VisualSearch() abort
  let l:text = s:GetVisualText()
  if !empty(l:text)
    call s:FuzzyStart('grep', l:text)
  endif
endfunction
xnoremap <leader>fg :<C-u>call <SID>VisualSearch()<CR>

" 可视模式下 <leader>ff：把选中的内容作为文件路径/名称进行模糊查找
function! s:VisualFindFile() abort
  let l:text = s:GetVisualText()
  if !empty(l:text)
    call s:FuzzyStart('files', l:text)
  endif
endfunction
xnoremap <leader>ff :<C-u>call <SID>VisualFindFile()<CR>

" ===== 纯 Vimscript 文件树侧边栏 =====
" <leader>e 开关侧边栏
" 树中按键：回车(或 o) 打开文件 / 展开折叠目录，- 水平分屏打开，\ 垂直分屏打开，r 刷新，q 关闭

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
  nnoremap <buffer> - :call <SID>TreeActivate('split')<CR>
  nnoremap <buffer> <Bslash> :call <SID>TreeActivate('vsplit')<CR>
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

" how: edit=在之前窗口打开, split=水平分屏, vsplit=垂直分屏（目录节点始终为展开/折叠）
function! s:TreeActivate(...) abort
  let l:how = a:0 > 0 ? a:1 : 'edit'
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
    execute l:how . ' ' . fnameescape(l:node.path)
  endif
endfunction

nnoremap <leader>e :call <SID>TreeToggle()<CR>

" ===== 纯 Vimscript Git 状态窗口 =====
" <leader>g 在独立标签页打开/关闭，内容只有 git 信息：
"   左侧状态列表，右侧两个窗格用 vim 内置 diff 模式做 split diff（旧版本 | 新版本）
" 状态窗口中按键：
"   j/k 移动（右侧实时显示该文件的 split diff）
"   回车  打开选中的文件
"   s     stage 选中的文件（git add，未跟踪文件/目录同样适用）
"   u     unstage 选中的文件（git restore --staged，取消暂存）
"   r     刷新，q 关闭

let s:git = {'bufnr': -1, 'oldbuf': -1, 'newbuf': -1, 'lines': [], 'root': '', 'closing': 0, 'difftimer': -1}

function! s:GitToggle() abort
  if s:git.bufnr > 0 && bufwinid(s:git.bufnr) != -1
    call s:GitClose()
    return
  endif
  call s:GitOpen()
endfunction

function! s:GitScratch(name) abort
  setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted
  setlocal nonumber norelativenumber nowrap signcolumn=no
  execute 'file ' . a:name
  nnoremap <buffer> q :call <SID>GitClose()<CR>
endfunction

function! s:GitOpen() abort
  let l:root = trim(system('git rev-parse --show-toplevel 2>/dev/null'))
  if v:shell_error != 0 || empty(l:root)
    echo '当前目录不是 git 仓库'
    return
  endif
  let s:git.root = l:root
  let s:git.closing = 0

  " 独立标签页：状态列表 + 两个 diff 窗格
  tabnew
  let s:git.bufnr = bufnr('%')
  call s:GitScratch('GitStatus')
  setlocal cursorline winfixwidth
  nnoremap <buffer> <CR> :call <SID>GitOpenFile()<CR>
  nnoremap <buffer> s :call <SID>GitStageFile()<CR>
  nnoremap <buffer> u :call <SID>GitUnstageFile()<CR>
  nnoremap <buffer> r :call <SID>GitRefresh()<CR>
  autocmd CursorMoved <buffer> call <SID>GitScheduleDiff()
  autocmd BufWipeout <buffer> call <SID>GitClose()

  " 中：旧版本（HEAD / 暂存区）
  belowright vertical new
  let s:git.oldbuf = bufnr('%')
  call s:GitScratch('GitOld')

  " 右：新版本（暂存区 / 工作区）
  belowright vertical new
  let s:git.newbuf = bufnr('%')
  call s:GitScratch('GitNew')

  " 状态窗口固定宽度，焦点留在状态窗口
  call win_gotoid(bufwinid(s:git.bufnr))
  vertical resize 34
  call s:GitRefresh()
endfunction

function! s:GitClose() abort
  if s:git.closing
    return
  endif
  let s:git.closing = 1
  for l:b in [s:git.oldbuf, s:git.newbuf, s:git.bufnr]
    let l:w = bufwinid(l:b)
    if l:w != -1
      call win_gotoid(l:w)
      close
    endif
  endfor
  let s:git.bufnr = -1
  let s:git.oldbuf = -1
  let s:git.newbuf = -1
endfunction

function! s:GitRefresh() abort
  let s:git.lines = []
  let l:display = ['# Changes （回车打开, s=stage, u=unstage, r=刷新, q=关闭）']
  call add(s:git.lines, #{type: 'header'})
  for l:line in systemlist('git -C ' . shellescape(s:git.root) . ' status --porcelain')
    let l:x = strpart(l:line, 0, 1)
    let l:y = strpart(l:line, 1, 1)
    let l:path = strpart(l:line, 3)
    " 重命名条目取新路径
    let l:path = substitute(l:path, '.* -> ', '', '')
    let l:path = substitute(l:path, '^"\|"$', '', 'g')
    call add(l:display, strpart(l:line, 0, 2) . ' ' . l:path)
    call add(s:git.lines, #{type: 'file', path: l:path,
          \ untracked: l:x ==# '?', staged: l:x !~# '[ ?]'})
  endfor

  let l:buf = s:git.bufnr
  call setbufvar(l:buf, '&modifiable', 1)
  call setbufline(l:buf, 1, l:display)
  let l:total = len(getbufline(l:buf, 1, '$'))
  if l:total > len(l:display)
    call deletebufline(l:buf, len(l:display) + 1, l:total)
  endif
  call setbufvar(l:buf, '&modifiable', 0)
  call s:GitUpdateDiff()
endfunction

" 光标所在行对应的节点
function! s:GitCurrentNode() abort
  let l:idx = line('.') - 1
  if l:idx < 0 || l:idx >= len(s:git.lines)
    return {'type': 'none'}
  endif
  return s:git.lines[l:idx]
endfunction

" 把内容写入 diff 窗格
function! s:GitSetPane(buf, lines) abort
  let l:lines = empty(a:lines) ? [''] : a:lines
  call setbufvar(a:buf, '&modifiable', 1)
  call setbufline(a:buf, 1, l:lines)
  let l:total = len(getbufline(a:buf, 1, '$'))
  if l:total > len(l:lines)
    call deletebufline(a:buf, len(l:lines) + 1, l:total)
  endif
  call setbufvar(a:buf, '&modifiable', 0)
endfunction

" git show 取某个版本的文件内容，失败（如新文件未入 HEAD）返回空列表
function! s:GitShow(ref) abort
  let l:out = systemlist('git -C ' . shellescape(s:git.root)
        \ . ' show ' . shellescape(a:ref) . ' 2>/dev/null')
  return v:shell_error != 0 ? [] : l:out
endfunction

" 给窗格设置语法高亮：按真实文件路径检测文件类型；空路径则清除
function! s:GitSetPaneSyntax(buf, path) abort
  let l:w = bufwinid(a:buf)
  if l:w == -1
    return
  endif
  if empty(a:path)
    call win_execute(l:w, 'setlocal syntax=')
  else
    call win_execute(l:w, 'doautocmd <nomodeline> BufRead ' . fnameescape(a:path))
  endif
endfunction

" 光标移动时延迟更新 diff：定时器回调不在自动命令上下文里，
" 这样窗格的语法高亮（doautocmd 文件类型检测）才能生效；同时起到防抖作用
function! s:GitScheduleDiff() abort
  if s:git.difftimer != -1
    call timer_stop(s:git.difftimer)
  endif
  let s:git.difftimer = timer_start(80, {t -> s:GitUpdateDiff()})
endfunction

" 光标移动时用 vim 内置 diff 模式做 split diff（旧版本 | 新版本）
function! s:GitUpdateDiff() abort
  let l:oldwin = bufwinid(s:git.oldbuf)
  let l:newwin = bufwinid(s:git.newbuf)
  if l:oldwin == -1 || l:newwin == -1
    return
  endif
  call win_execute(l:oldwin, 'diffoff')
  call win_execute(l:newwin, 'diffoff')
  let l:node = s:GitCurrentNode()
  let l:ft_path = ''
  let l:use_diff = 0
  if l:node.type ==# 'file'
    let l:full = s:git.root . '/' . l:node.path
    if isdirectory(l:full)
      " 新增目录：列出其中的内容
      call s:GitSetPane(s:git.oldbuf, ['（新增目录）'])
      call s:GitSetPane(s:git.newbuf, readdir(l:full))
    else
      if l:node.untracked
        call s:GitSetPane(s:git.oldbuf, [])
        call s:GitSetPane(s:git.newbuf, filereadable(l:full)
              \ ? readfile(l:full, '', 2000) : ['（无法读取）'])
      elseif l:node.staged
        call s:GitSetPane(s:git.oldbuf, s:GitShow('HEAD:' . l:node.path))
        call s:GitSetPane(s:git.newbuf, s:GitShow(':' . l:node.path))
      else
        call s:GitSetPane(s:git.oldbuf, s:GitShow(':' . l:node.path))
        call s:GitSetPane(s:git.newbuf, filereadable(l:full)
              \ ? readfile(l:full, '', 2000) : ['（无法读取）'])
      endif
      let l:ft_path = l:full
      let l:use_diff = 1
    endif
    call s:GitSetPaneSyntax(s:git.oldbuf, l:ft_path)
    call s:GitSetPaneSyntax(s:git.newbuf, l:ft_path)
  else
    call s:GitSetPane(s:git.oldbuf, ['（无内容）'])
    call s:GitSetPane(s:git.newbuf, [''])
    call s:GitSetPaneSyntax(s:git.oldbuf, '')
    call s:GitSetPaneSyntax(s:git.newbuf, '')
  endif
  if l:use_diff
    call win_execute(l:oldwin, 'diffthis')
    call win_execute(l:newwin, 'diffthis')
  endif
endfunction

function! s:GitOpenFile() abort
  let l:node = s:GitCurrentNode()
  if l:node.type !=# 'file'
    return
  endif
  let l:path = s:git.root . '/' . l:node.path
  call s:GitClose()
  execute 'edit ' . fnameescape(l:path)
endfunction

" stage：git add 选中的文件（未跟踪文件/目录同样适用）
function! s:GitStageFile() abort
  let l:node = s:GitCurrentNode()
  if l:node.type !=# 'file'
    echo '请把光标放在要 stage 的文件上'
    return
  endif
  call system('git -C ' . shellescape(s:git.root)
        \ . ' add -- ' . shellescape(l:node.path))
  if v:shell_error != 0
    echo 'git add 失败: ' . l:node.path
    return
  endif
  call s:GitRefresh()
endfunction

" unstage：取消暂存选中的文件（git restore --staged）
function! s:GitUnstageFile() abort
  let l:node = s:GitCurrentNode()
  if l:node.type !=# 'file' || !get(l:node, 'staged', 0)
    echo '请把光标放在已暂存的文件上'
    return
  endif
  call system('git -C ' . shellescape(s:git.root)
        \ . ' restore --staged -- ' . shellescape(l:node.path) . ' 2>/dev/null')
  if v:shell_error != 0
    " 老版本 git 没有 restore，退回 reset
    call system('git -C ' . shellescape(s:git.root)
          \ . ' reset -q HEAD -- ' . shellescape(l:node.path))
  endif
  call s:GitRefresh()
endfunction

nnoremap <leader>g :call <SID>GitToggle()<CR>

" ===== 状态栏显示当前行的 git blame =====
" 光标停留（CursorHold）时查询当前行的 blame 信息，显示在状态栏右侧
set statusline+=%{get(b:,'blame_info','')}

augroup GitBlameStatus
  autocmd!
  autocmd CursorHold * call <SID>BlameUpdate()
augroup END

function! s:BlameUpdate() abort
  if &buftype !=# '' || expand('%:p') ==# '' || !filereadable(expand('%:p'))
    let b:blame_info = ''
    return
  endif
  let l:lnum = line('.')
  " 同一行且文件未变时不重复查询
  if exists('b:blame_last') && b:blame_last[0] == l:lnum
        \ && b:blame_last[1] == getftime(expand('%:p'))
    return
  endif
  let b:blame_last = [l:lnum, getftime(expand('%:p'))]
  let l:out = systemlist('git blame -L ' . l:lnum . ',' . l:lnum
        \ . ' --porcelain -- ' . shellescape(expand('%:p')) . ' 2>/dev/null')
  if v:shell_error != 0 || empty(l:out)
    let b:blame_info = ''
    redrawstatus
    return
  endif
  let l:author = matchstr(get(filter(copy(l:out), 'v:val =~# "^author "'), 0, ''),
        \ '^author \zs.*')
  let l:time = str2nr(matchstr(get(filter(copy(l:out), 'v:val =~# "^author-time "'), 0, ''),
        \ '\d\+'))
  let l:summary = matchstr(get(filter(copy(l:out), 'v:val =~# "^summary "'), 0, ''),
        \ '^summary \zs.*')
  if l:author =~# 'Not Committed'
    let b:blame_info = ' [Not committed]'
  else
    " 作者在最前并保证完整显示，摘要过长时截断
    let l:info = ' [' . l:author . ' ' . strftime('%Y-%m-%d', l:time)
    let l:room = 50 - strchars(l:info)
    if l:room > 1 && !empty(l:summary)
      let l:info .= ' ' . strcharpart(l:summary, 0, l:room)
      if strchars(l:summary) > l:room
        let l:info .= '…'
      endif
    endif
    let b:blame_info = l:info . ']'
  endif
  redrawstatus
endfunction

" ===== 纯 Vimscript Buffer 切换栏 =====
" <leader>b 在底部以状态栏形式横向显示所有 buffer：
"   Tab / Shift-Tab  循环切换 buffer（即时生效）
"   每个 buffer 带两个字母标识：绿色=切换过去，红色=关闭它
"   标识符按 a b c ... 分配，不够用 aa bb cc ...
"   输入字母时只显示标识符以输入内容开头的 buffer；只剩唯一候选时立即执行
"   输入是某个标识符的精确匹配但有更长候选时（如 a 与 aa），按回车执行精确匹配项
"   回车 切换到当前选中的 buffer，Esc 关闭

highlight BufSwitch ctermfg=green guifg=green
highlight BufClose ctermfg=red guifg=red
if !empty(prop_type_get('bb_switch'))
  call prop_type_delete('bb_switch')
endif
call prop_type_add('bb_switch', #{highlight: 'BufSwitch', priority: 20})
if !empty(prop_type_get('bb_close'))
  call prop_type_delete('bb_close')
endif
call prop_type_add('bb_close', #{highlight: 'BufClose', priority: 20})

let s:bb = {'popup': -1, 'bufs': [], 'sel': 0, 'input': '', 'win': -1}

" 标识符序列：a..z, aa..zz, aaa...
function! s:BufLabel(n) abort
  return repeat(nr2char(char2nr('a') + a:n % 26), a:n / 26 + 1)
endfunction

function! s:BufBarCollect() abort
  let s:bb.bufs = map(getbufinfo({'buflisted': 1}),
        \ {_, b -> {'nr': b.bufnr, 'name': b.name, 'changed': b.changed}})
endfunction

function! s:BufBarOpen() abort
  if s:bb.popup != -1
    call s:BufBarClose()
    return
  endif
  let s:bb.win = win_getid()
  let s:bb.input = ''
  call s:BufBarCollect()
  if empty(s:bb.bufs)
    echo '没有可用的 buffer'
    return
  endif
  " 当前 buffer 作为初始选中
  let s:bb.sel = 0
  let l:cur = bufnr('%')
  for l:i in range(len(s:bb.bufs))
    if s:bb.bufs[l:i].nr == l:cur
      let s:bb.sel = l:i
      break
    endif
  endfor
  let s:bb.popup = popup_create('', #{
        \ line: &lines - 1, col: 1,
        \ minwidth: &columns, maxwidth: &columns,
        \ zindex: 200, mapping: 0,
        \ highlight: 'FuzzyPopup',
        \ filter: function('s:BufBarFilter'),
        \ })
  call s:BufBarRender()
endfunction

function! s:BufBarRender() abort
  let l:line = empty(s:bb.input) ? '' : '[' . s:bb.input . '] '
  let l:props = []
  for l:i in range(len(s:bb.bufs))
    let l:b = s:bb.bufs[l:i]
    let l:sw = s:BufLabel(l:i * 2)
    let l:cl = s:BufLabel(l:i * 2 + 1)
    " 过滤：只显示标识符以输入内容开头的 buffer
    if !empty(s:bb.input) && stridx(l:sw, s:bb.input) != 0 && stridx(l:cl, s:bb.input) != 0
      continue
    endif
    let l:title = empty(l:b.name) ? '[No Name]' : fnamemodify(l:b.name, ':t')
    let l:title .= l:b.changed ? '+' : ''
    let l:tab = ' ' . l:sw . ' ' . l:cl . ' ' . l:title . ' '
    let l:start = strlen(l:line)
    " 绿色=切换标识，红色=关闭标识（高优先级，选中反色不覆盖字母颜色）
    call add(l:props, #{col: l:start + 2, length: strlen(l:sw), type: 'bb_switch'})
    call add(l:props, #{col: l:start + 2 + strlen(l:sw) + 1, length: strlen(l:cl), type: 'bb_close'})
    if l:i == s:bb.sel
      call add(l:props, #{col: l:start + 1, length: strlen(l:tab), type: 'ff_sel'})
    endif
    let l:line .= l:tab
  endfor
  if l:line =~# '^\[.*\] $'
    let l:line .= '（无匹配）'
  endif
  call popup_settext(s:bb.popup, [#{text: empty(l:line) ? ' （无 buffer）' : l:line, props: l:props}])
endfunction

function! s:BufBarFilter(id, key) abort
  if a:key ==# "\<Esc>" || a:key ==# "\<C-c>"
    call s:BufBarClose()
  elseif a:key ==# "\<Tab>"
    call s:BufBarCycle(1)
  elseif a:key ==# "\<S-Tab>"
    call s:BufBarCycle(-1)
  elseif a:key ==# "\<CR>"
    " 有输入时优先执行精确匹配的标识符（用于 a 与 aa 并存时的消歧）
    if !empty(s:bb.input)
      for l:i in range(len(s:bb.bufs))
        if s:bb.input ==# s:BufLabel(l:i * 2)
          call s:BufBarSwitch(l:i)
          call s:BufBarClose()
          return 1
        elseif s:bb.input ==# s:BufLabel(l:i * 2 + 1)
          call s:BufBarDelete(l:i)
          return 1
        endif
      endfor
    endif
    call s:BufBarSwitch(s:bb.sel)
    call s:BufBarClose()
  elseif a:key ==# "\<BS>" || a:key ==# "\<C-h>"
    if !empty(s:bb.input)
      let s:bb.input = strcharpart(s:bb.input, 0, strchars(s:bb.input) - 1)
      call s:BufBarRender()
    endif
  elseif a:key =~# '^[a-z]$'
    let s:bb.input .= a:key
    " 候选：标识符以输入内容开头；只剩唯一候选时立即执行
    let l:switch_to = -1
    let l:close_idx = -1
    let l:count = 0
    for l:i in range(len(s:bb.bufs))
      if stridx(s:BufLabel(l:i * 2), s:bb.input) == 0
        let l:switch_to = l:i
        let l:count += 1
      elseif stridx(s:BufLabel(l:i * 2 + 1), s:bb.input) == 0
        let l:close_idx = l:i
        let l:count += 1
      endif
    endfor
    if l:count == 1
      if l:switch_to >= 0
        call s:BufBarSwitch(l:switch_to)
        call s:BufBarClose()
      else
        call s:BufBarDelete(l:close_idx)
      endif
      return 1
    endif
    " 没有任何候选时，清空输入重来
    if l:count == 0
      let s:bb.input = ''
    endif
    call s:BufBarRender()
  endif
  return 1
endfunction

function! s:BufBarCycle(step) abort
  if empty(s:bb.bufs)
    return
  endif
  let s:bb.sel = (s:bb.sel + a:step) % len(s:bb.bufs)
  if s:bb.sel < 0
    let s:bb.sel += len(s:bb.bufs)
  endif
  call s:BufBarSwitch(s:bb.sel)
  call s:BufBarRender()
endfunction

function! s:BufBarSwitch(i) abort
  if a:i < 0 || a:i >= len(s:bb.bufs)
    return
  endif
  let l:nr = s:bb.bufs[a:i].nr
  if win_id2win(s:bb.win) > 0
    call win_execute(s:bb.win, 'buffer ' . l:nr)
  else
    execute 'buffer ' . l:nr
  endif
endfunction

function! s:BufBarDelete(i) abort
  if a:i < 0 || a:i >= len(s:bb.bufs)
    return
  endif
  let l:b = s:bb.bufs[a:i]
  if l:b.changed
    echo fnamemodify(l:b.name, ':t') . ' 有未保存的修改，未关闭'
    let s:bb.input = ''
    call s:BufBarRender()
    return
  endif
  execute 'bdelete ' . l:b.nr
  call s:BufBarCollect()
  let s:bb.input = ''
  let s:bb.sel = empty(s:bb.bufs) ? 0 : min([s:bb.sel, len(s:bb.bufs) - 1])
  call s:BufBarRender()
endfunction

function! s:BufBarClose() abort
  if s:bb.popup != -1
    call popup_close(s:bb.popup)
    let s:bb.popup = -1
  endif
endfunction

nnoremap <leader>b :call <SID>BufBarOpen()<CR>

" ===== Git 行状态标记（sign 列显示新增/修改行）+ 修改块 diff 预览 =====
" 在行号左侧的 sign 列用颜色标出当前文件相对 git 暂存区的变化：
"   绿色 + = 新增行，黄色 ~ = 修改行（未跟踪文件所有行标记为新增）
" 更新时机：打开文件、保存文件后立即刷新；编辑停止约 0.3 秒后自动刷新
" <leader>d 在光标所在的修改块弹出 diff 预览窗口（q / Esc 关闭）

highlight GitSignAdd ctermfg=green guifg=green
highlight GitSignChange ctermfg=yellow guifg=yellow
sign define GitSignAdd text=+ texthl=GitSignAdd
sign define GitSignChange text=~ texthl=GitSignChange

let s:gitsign_timer = -1

augroup GitSigns
  autocmd!
  autocmd BufEnter,BufWritePost * call <SID>GitSignsUpdate()
  autocmd TextChanged,TextChangedI * call <SID>GitSignsSchedule()
augroup END

" 编辑后防抖刷新，避免每次按键都跑一次 git + diff
function! s:GitSignsSchedule() abort
  if s:gitsign_timer != -1
    call timer_stop(s:gitsign_timer)
  endif
  let s:gitsign_timer = timer_start(300, {t -> s:GitSignsUpdate()})
endfunction

function! s:GitSignsUpdate() abort
  let l:buf = bufnr('%')
  call sign_unplace('gitsigns', #{buffer: l:buf})
  let b:gitsign_hunks = []
  if &buftype !=# '' || expand('%:p') ==# ''
    return
  endif
  let l:root = trim(system('git -C ' . shellescape(expand('%:p:h'))
        \ . ' rev-parse --show-toplevel 2>/dev/null'))
  if v:shell_error != 0 || empty(l:root)
    return
  endif
  " ls-files 同时用于判断文件是否被 git 跟踪，并取仓库相对路径
  let l:rel = trim(system('git -C ' . shellescape(l:root)
        \ . ' ls-files --full-name -- ' . shellescape(expand('%:p'))))
  if empty(l:rel)
    " 未跟踪文件：所有行都标记为新增
    let l:hunk = #{start: 1, end: line('$'), lines: []}
    for l:l in getline(1, '$')
      call add(l:hunk.lines, '+' . l:l)
    endfor
    let b:gitsign_hunks = [l:hunk]
    call s:GitSignsPlace(l:buf, 1, line('$'), 'GitSignAdd')
    return
  endif
  " 以暂存区版本为基准（未暂存过时即 HEAD 版本）
  let l:base = systemlist('git -C ' . shellescape(l:root)
        \ . ' show ' . shellescape(':' . l:rel) . ' 2>/dev/null')
  call s:GitSignsDiff(l:buf, l:base, getline(1, '$'))
endfunction

" 用外部 diff 对比基准版本和 buffer 当前内容，解析 hunk、放置 sign、记录 diff 文本
function! s:GitSignsDiff(buf, base, cur) abort
  let l:tmpA = tempname()
  let l:tmpB = tempname()
  call writefile(a:base, l:tmpA)
  call writefile(a:cur, l:tmpB)
  let l:diff = systemlist('diff -U3 ' . shellescape(l:tmpA) . ' ' . shellescape(l:tmpB))
  call delete(l:tmpA)
  call delete(l:tmpB)

  " 先按 @@ 头切分 hunk，保留完整 hunk 文本供 diff 预览
  let l:hunks = []
  let l:h = {}
  for l:line in l:diff
    if l:line =~# '^@@'
      let l:m = matchlist(l:line,
            \ '^@@ -\(\d\+\)\%(,\(\d\+\)\)\? +\(\d\+\)\%(,\(\d\+\)\)\? @@')
      let l:h = #{new_start: str2nr(l:m[3]),
            \ new_n: l:m[4] ==# '' ? 1 : str2nr(l:m[4]),
            \ lines: [l:line]}
      call add(l:hunks, l:h)
    elseif !empty(l:h) && l:line !~# '^[+-]\{3}'
      call add(l:h.lines, l:line)
    endif
  endfor

  " hunk 内部按上下文行分隔成若干变化组，逐组分类：
  "   只有 '+' 行       = 新增（绿色）
  "   既有 '-' 又有 '+' = 修改（黄色）
  "   只有 '-' 行       = 删除，无对应行可标记，仅记录位置供 diff 预览
  for l:h in l:hunks
    " 整个 hunk 在新侧为 0 行时，new_start 指删除点之前的那一行
    let l:st = #{new: l:h.new_n == 0 ? l:h.new_start + 1 : l:h.new_start,
          \ minus: 0, plus_first: -1, plus_n: 0}
    for l:ln in l:h.lines[1:]
      if l:ln =~# '^\\'
        continue
      endif
      let l:type = l:ln[0]
      if l:type ==# ' '
        " 上下文行：结算当前变化组
        call s:GitSignsGroupEnd(a:buf, l:h, l:st)
        let l:st.new += 1
      elseif l:type ==# '-'
        let l:st.minus += 1
      elseif l:type ==# '+'
        if l:st.plus_first < 0
          let l:st.plus_first = l:st.new
        endif
        let l:st.plus_n += 1
        let l:st.new += 1
      endif
    endfor
    " 结算 hunk 末尾的变化组
    call s:GitSignsGroupEnd(a:buf, l:h, l:st)
  endfor
endfunction

" 结算一个变化组：放置 sign 或记录删除位置，然后重置组状态
function! s:GitSignsGroupEnd(buf, h, st) abort
  if a:st.plus_n > 0
    let l:last = a:st.plus_first + a:st.plus_n - 1
    call s:GitSignsPlace(a:buf, a:st.plus_first, l:last,
          \ a:st.minus > 0 ? 'GitSignChange' : 'GitSignAdd')
    call add(b:gitsign_hunks,
          \ #{start: a:st.plus_first, end: l:last, lines: a:h.lines})
  elseif a:st.minus > 0
    " 纯删除：锚定在删除点前的行
    let l:anchor = max([1, a:st.new - 1])
    call add(b:gitsign_hunks,
          \ #{start: l:anchor, end: l:anchor, lines: a:h.lines})
  endif
  let a:st.minus = 0
  let a:st.plus_first = -1
  let a:st.plus_n = 0
endfunction

function! s:GitSignsPlace(buf, first, last, type) abort
  for l:lnum in range(a:first, a:last)
    call sign_place(0, 'gitsigns', a:type, a:buf, #{lnum: l:lnum, priority: 10})
  endfor
endfunction

" <leader>d：预览光标所在修改块的 diff（含上下文，diff 语法高亮）
function! s:GitHunkPopup() abort
  let l:lnum = line('.')
  for l:h in get(b:, 'gitsign_hunks', [])
    if l:lnum >= l:h.start && l:lnum <= l:h.end
      let l:id = popup_create(l:h.lines, #{
            \ title: ' git diff（q / Esc 关闭） ',
            \ border: [],
            \ padding: [0, 1, 0, 1],
            \ pos: 'topleft',
            \ line: 'cursor+1',
            \ col: 'cursor',
            \ maxwidth: &columns - 8,
            \ maxheight: &lines - 8,
            \ wrap: 0,
            \ highlight: 'FuzzyPopup',
            \ filter: function('s:GitHunkPopupFilter'),
            \ })
      call win_execute(l:id, 'setlocal syntax=diff')
      return
    endif
  endfor
  echo '当前行不在任何修改块中'
endfunction

function! s:GitHunkPopupFilter(id, key) abort
  if a:key ==# "\<Esc>" || a:key ==# 'q' || a:key ==# "\<C-c>"
    call popup_close(a:id)
    return 1
  endif
  return 0
endfunction

nnoremap <leader>d :call <SID>GitHunkPopup()<CR>

" ===== 常用快捷键 =====
" Ctrl+S 保存（仅在有修改时写入）
nnoremap <C-s> :update<CR>
inoremap <C-s> <C-o>:update<CR>
xnoremap <C-s> <Esc>:update<CR>

" Ctrl + h/j/k/l 在分屏窗口之间移动
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" ===== 显示缩进用的是空格还是 Tab =====
" 开启后每行行首一眼可辨：
"   Tab 缩进   显示为 "→      "（箭头）
"   空格缩进   显示为 "····"（暗灰色小点）
" 另外行尾多余空格显示为 "·"，nbsp 显示为 "␣"
" <leader>l 可随时开关这个显示
set list
" 旧版本 Vim 的 listchars 不支持 lead（行首空格），失败时退回只显示 Tab
try
  set listchars=tab:→\ ,lead:·,trail:·,nbsp:␣
catch
  set listchars=tab:→\ ,trail:·,nbsp:␣
endtry
" 这些符号用暗灰色显示，不抢眼
highlight SpecialKey ctermfg=darkgray guifg=#555555
nnoremap <leader>l :set list!<CR>
