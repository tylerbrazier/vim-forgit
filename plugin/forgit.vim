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
" It's a dictionary of:
" git project directory -> subdirectories
" (the subdirectories are used to set 'path')
let s:cache = {}

augroup forgit
	autocmd!
	autocmd BufEnter * call s:lcd_to_proj_root()
	autocmd VimEnter,DirChanged * call s:set_opts()
augroup END

if empty(&tabline)
	set tabline=%!ForgitTabline()
endif

function s:debug(message)
	if empty(g:debug_forgit)
		return
	endif

	let timestamp = strftime('%H:%M:%S')
	let line = timestamp..' '..a:message
	call writefile([line], s:debug_log, 'as')
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
	" need to call set_opts() manually (:help autocmd-nested)
	call s:set_opts()
endfunction

" If dir is in a git project then return the top level project directory;
" otherwise return 0
function s:get_proj_dir(dir)
	call s:debug('get_proj_dir('..a:dir..')')

	" check the cache first
	for proj_dir in keys(s:cache)
		" if proj_dir is a parent of dir
		" (NOTE this probably won't work in Windows)
		if match(a:dir..'/', proj_dir..'/') == 0
			call s:debug('cache hit: '..proj_dir)
			return proj_dir
		endif
	endfor

	" TODO make this async
	let cmd = 'git -C '..shellescape(a:dir)..' rev-parse --show-toplevel'
	call s:debug('cache miss. running: '..cmd)
	let proj_dir = trim(system(cmd))
	call s:debug('result: '..proj_dir)

	if v:shell_error
		" not in a git project
		call s:debug('v:shell_error = '..v:shell_error)
		return
	endif

	" add project dir key to the cache; value will be set later
	let s:cache[proj_dir] = ''

	return proj_dir
endfunction

" Sets 'grepprg', 'grepformat', and 'path' for :grep, :find, etc.
function s:set_opts()
	let proj_dir = s:get_proj_dir(getcwd())

	if empty(proj_dir)
		return
	endif

	let subdirs = s:get_subdirs(proj_dir)
	if !empty(subdirs)
		let &path = subdirs
	endif

	set grepprg=git\ grep\ -I\ -n\ --column
	set grepformat=%f:%l:%c:%m
endfunction

" Returns all the subdirectories of proj_dir, separated by commas;
" otherwise returns 0
function s:get_subdirs(proj_dir)
	call s:debug('get_subdirs('..a:proj_dir..')')

	if has_key(s:cache, a:proj_dir) && !empty(s:cache[a:proj_dir])
		call s:debug('cache hit: '..s:cache[a:proj_dir])
		return s:cache[a:proj_dir]
	endif

	" TODO make this async
	let cmd = 'git -C '..shellescape(a:proj_dir)
				\..' ls-tree -rd --name-only HEAD'
	call s:debug('cache miss. running: '..cmd)
	let subdirs = join(systemlist(cmd), ',')..',,'
	call s:debug('result: '..subdirs)

	if v:shell_error
		call s:debug('v:shell_error = '..v:shell_error)
		return
	endif

	let s:cache[a:proj_dir] = subdirs

	return subdirs
endfunction

" Modified from the example in :help setting-tabline
function ForgitTabline()
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
