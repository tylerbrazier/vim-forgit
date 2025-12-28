" Autocommands for setting grep and path options in git projects;
" 'path' will be a list of all the tracked subdirectories in the project
" so ignored subdirs (e.g. node_modules) won't burn CPU cycles on :find.
" Note that if you cd into a subdirectory of the project, 'path' will
" still be set to all the subdirectories of the project root so it may
" still include dirs that aren't subdirs of the current dir; vim doesn't
" seem to have a problem with this.

if exists("g:loaded_forgit") || &cp
	finish
endif
let g:loaded_forgit = 1

" For debugging:
" :let g:debug_forgit = 1
" :vertical term tail -f ~/.forgit.log
let g:debug_forgit = 0
" absolute path for log file because of changing cwd
let s:debug_log = expand('$HOME/.forgit.log')

" The cache is used to avoid unnecessary external calls to git.
" It's a dictionary like:
" {
" 	'/some/working/dir': {
" 		'proj_dir': '/some/working',
" 		'path': 'dir,,'
" 	},
"
" 	'/another/working/dir': {
" 		'proj_dir': 0,
" 		'path': 0
" 	}
" }
" The second entry is the cache isn't a part of a git project.
let s:cache = {}

augroup forgit
	autocmd!
	" needs ++nested so :lcd will trigger other autocmds
	autocmd BufEnter * ++nested call s:lcd_to_proj_root()
	autocmd VimEnter,DirChanged * call s:set_opts()
augroup END

if empty(&tabline)
	set tabline=%!ForgitTabLine()
endif

function s:debug(message)
	if empty(g:debug_forgit)
		return
	endif

	let timestamp = strftime('%H:%M:%S')
	call writefile([timestamp..' '..a:message], s:debug_log, 'a')
endfunction

function s:log_cache()
	if empty(g:debug_forgit)
		return
	endif

	let timestamp = strftime('%H:%M:%S')
	let result = [timestamp..' cache:']

	for [dir, props] in items(s:cache)
		call add(result, "\t"..dir)

		for [prop, value] in items(props)
			call add(result, "\t\t"..prop..':'..value)
		endfor
	endfor

	call writefile(result, s:debug_log, 'a')
endfunction

" :lcd to the git project directory of the current file
function s:lcd_to_proj_root()
	" buftype is empty for a normal file
	if !empty(&buftype)
		call s:debug('skipping :lcd because buftype='..&buftype)
		return
	endif

	let proj_dir = s:get_proj_dir(expand('%:p:h'))

	if empty(proj_dir) || proj_dir == getcwd()
		return
	endif

	call s:debug(':lcd '..proj_dir)
	execute 'lcd' proj_dir
endfunction

" Sets 'grepprg', 'grepformat', and 'path' for :grep, :find, etc.
function s:set_opts()
	call s:debug('set_opts()')

	let path = s:get_path(getcwd())

	if empty(path)
		call s:debug('not setting opts because empty path')
		return
	endif

	call s:debug('setting grep opts and path='..path)
	let &path = path
	set grepprg=git\ grep\ -I\ -n\ --column
	set grepformat=%f:%l:%c:%m
endfunction

" If dir is in a git project then return the top level project directory;
" otherwise return 0
function s:get_proj_dir(dir)
	call s:debug('get_proj_dir('..a:dir..')')

	" check the cache first
	if !has_key(s:cache, a:dir)
		let s:cache[a:dir] = {}
	endif
	if has_key(s:cache[a:dir], 'proj_dir')
		call s:debug('cache hit: '..s:cache[a:dir].proj_dir)
		return s:cache[a:dir].proj_dir
	endif

	" TODO make this async
	let cmd = 'git -C '..shellescape(a:dir)..' rev-parse --show-toplevel'
	call s:debug('cache miss. running: '..cmd)
	let cmd_result = trim(system(cmd))
	call s:debug('result: '..cmd_result)

	let proj_dir = v:shell_error ? 0 : cmd_result

	let s:cache[a:dir].proj_dir = proj_dir
	call s:log_cache()

	return proj_dir
endfunction

function s:get_path(dir)
	call s:debug('get_path('..a:dir..')')

	" first check the cache
	if !has_key(s:cache, a:dir)
		let s:cache[a:dir] = {}
	endif
	if has_key(s:cache[a:dir], 'path')
		call s:debug('cache hit: '..s:cache[a:dir].path)
		return s:cache[a:dir].path
	endif

	" TODO make this async
	let cmd = 'git -C '..shellescape(a:dir)..' ls-tree -rd --name-only HEAD'
	call s:debug('cache miss. running: '..cmd)
	let cmd_result = join(systemlist(cmd), ',')..',,'
	call s:debug('result: '..cmd_result)

	let path = v:shell_error ? 0 : cmd_result

	let s:cache[a:dir].path = path
	call s:log_cache()

	return path
endfunction

" Modified from the example in :help setting-tabline
function ForgitTabLine()
	let tabline = ''
	for i in range(tabpagenr('$'))
		" select the highlighting
		if i + 1 == tabpagenr()
			let tabline ..= '%#TabLineSel#'
		else
			let tabline ..= '%#TabLine#'
		endif

		" set the tab page number (for mouse clicks)
		let tabline ..= '%'..(i+1)..'T'

		" the label is made by MyTabLabel()
		let tabline ..= ' %{ForgitTabLabel('..(i+1)..')} '
	endfor

	" after the last tab fill with TabLineFill and reset tab page nr
	let tabline ..= '%#TabLineFill#%T'

	return tabline
endfunction

function ForgitTabLabel(tab_n)
	let path = ''
	let window_n = tabpagewinnr(a:tab_n)
	let proj_dir = s:get_proj_dir(getcwd(window_n, a:tab_n))

	if empty(proj_dir)
		" fall back to using the file name
		let buf_list = tabpagebuflist(a:tab_n)
		let path = bufname(buf_list[window_n - 1])
	else
		let path = proj_dir
	endif

	return fnamemodify(path, ':t') ?? '[No Name]'
endfunction
