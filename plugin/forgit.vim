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

augroup forgit
	autocmd!
	autocmd BufEnter * call s:lcd_to_proj_root()
	autocmd VimEnter,DirChanged * call s:set_opts()
augroup END

" The cache is used to avoid unnecessary external calls to git.
" It's a dictionary of:
" git project directory -> subdirectories
" (the subdirectories are used to set 'path')
let s:cache = {}

" :lcd to the git project directory of the current file
function s:lcd_to_proj_root()
	let l:proj_dir = s:get_proj_dir(expand('%:p:h'))
	if l:proj_dir != getcwd()
		execute 'lcd' l:proj_dir
		" need to call set_opts() manually (:help autocmd-nested)
		call s:set_opts()
	endif
endfunction

" If dir is in a git project then return the top level project directory;
" otherwise return 0
function s:get_proj_dir(dir)
	" check the cache first
	for proj_dir in keys(s:cache)
		" if proj_dir is a parent of dir
		if match(a:dir, proj_dir) == 0
			return proj_dir
		endif
	endfor

	" TODO make this async
	let l:cmd = 'git -C '..shellescape(a:dir)..' rev-parse --show-toplevel'
	let l:proj_dir = trim(system(l:cmd))
	if v:shell_error
		" not in a git project
		return
	endif

	" add project dir key to the cache; value will be set later
	let s:cache[l:proj_dir] = ''

	return l:proj_dir
endfunction

" Sets 'grepprg', 'grepformat', and 'path' for :grep, :find, etc.
function s:set_opts()
	let l:proj_dir = s:get_proj_dir(getcwd())

	if empty(l:proj_dir)
		return
	endif

	let l:subdirs = s:get_subdirs(l:proj_dir)
	if !empty(l:subdirs)
		let &path = l:subdirs
	endif

	set grepprg=git\ grep\ -I\ -n\ --column
	set grepformat=%f:%l:%c:%m
endfunction

" Returns all the subdirectories of proj_dir, separated by commas;
" otherwise returns 0
function s:get_subdirs(proj_dir)
	if has_key(s:cache, a:proj_dir) && !empty(s:cache[a:proj_dir])
		return s:cache[a:proj_dir]
	endif

	" TODO make this async
	let l:cmd = 'git -C '..shellescape(a:proj_dir)
				\..' ls-tree -rd --name-only HEAD'
	let l:subdirs = join(systemlist(l:cmd), ',')..',,'
	if v:shell_error
		return
	endif

	let s:cache[a:proj_dir] = l:subdirs

	return l:subdirs
endfunction
