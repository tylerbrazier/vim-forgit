" Sets 'path', 'grepprg/format', and 'status/tabline' options for git projects.

if exists("g:loaded_forgit") || &cp
	finish
endif
let g:loaded_forgit = 1

" For debugging:
" :let g:debug_forgit = 1
" and tail -f ~/.forgit.log in a separate terminal
" (otherwise writefile() in debug() triggers an endess looping statusline update)
let g:debug_forgit = 0
let s:debug_log = expand('$HOME/.forgit.log')

" The cache is used to avoid unnecessary external calls to git.
" It's a dictionary of working dirs to their paths like:
" {
" 	'/path/to/git/project': ['src', 'src/lib'],
" 	'/not/a/project': 0
" }
let s:cache = {}

augroup forgit
	autocmd!
	autocmd VimEnter,DirChanged * call s:set_opts()
augroup END

if empty(&statusline)
	set statusline=%!ForgitStatusLine()
endif

if empty(&tabline)
	set tabline=%!ForgitTabLine()
endif

" Sets 'grepprg', 'grepformat', and 'path' for :grep, :find, etc.
function s:set_opts()
	call s:debug('set_opts()')

	let path = s:get_path(getcwd())

	if path is 0
		call s:debug('resetting opts because path is 0')
		set path&
		set grepprg&
		set grepformat&
		return
	endif

	call s:debug('setting grep opts and path =', path)
	let &path = path
	let &grepprg = 'git grep -I -n --column'
	let &grepformat = '%f:%l:%c:%m'
endfunction

" Given a dir like /home/tyler/proj/src
" returns a string for the 'path' option like 'tools,tools/misc,,'
" If dir is outside of a git project then return 0.
function s:get_path(dir)
	call s:debug('get_path('..a:dir..')')

	let proj_dir = s:get_proj_dir(a:dir)

	if proj_dir is 0
		call s:debug('returning get_path() = 0')
		return 0
	endif

	" first check the cache
	if has_key(s:cache, proj_dir)
		let val = s:cache[proj_dir]

		call s:debug('found dir in cache['..proj_dir..']:', val)

		if val is 0
			call s:debug('cache hit. returning get_path() = 0')
			return 0
		endif

		if type(val) is v:t_list
			let result = s:path_list_to_str(proj_dir, a:dir, val)
			call s:debug('cache hit. returning get_path() =', result)
			return result
		endif

		" val must be 1, meaning it's in a git project but we
		" haven't cached the path array yet; in that case we still
		" need to run the git command, so move on.
	endif

	" TODO make this async
	let cmd = 'git -C '..shellescape(proj_dir)..' ls-tree -rd --name-only HEAD'
	call s:debug('path not cached yet; running:', cmd)
	let cmd_result = systemlist(cmd)
	call s:debug('cmd result:', cmd_result)

	let val = v:shell_error ? 0 : cmd_result

	let s:cache[proj_dir] = val
	call s:debug('cache:', s:cache)

	if val is 0
		call s:debug('must not be in proj. returning get_path() = 0')
		return 0
	endif

	let val = s:path_list_to_str(proj_dir, a:dir, val)

	call s:debug('returning get_path() =', val)
	return val
endfunction

" If dir is in a git project then return the top level project directory;
" otherwise return 0
function s:get_proj_dir(dir)
	call s:debug('get_proj_dir('..a:dir..')')

	" check the cache first
	for cached_dir in keys(s:cache)
		if cached_dir is a:dir
			let result = s:cache[a:dir] is 0 ? 0 : cached_dir
			call s:debug('cache hit exact match. returning', result)
			return result
		endif

		" if it's a subdir of the cached dir
		if !empty(s:trim_parent(cached_dir, a:dir))
			if s:cache[cached_dir] is 0
				call s:debug('cache skipping possible project '
						\..a:dir..
						\' in nonproject parent '
						\..cached_dir)
				continue
			endif

			call s:debug('cache hit parent; returning', cached_dir)
			return cached_dir
		endif


	endfor

	" TODO make this async
	let cmd = 'git -C '..shellescape(a:dir)..' rev-parse --show-toplevel'
	call s:debug('cache miss. running:', cmd)
	let cmd_result = trim(system(cmd))
	call s:debug('cmd result:', cmd_result)

	if v:shell_error
		" 0 means not in a git project
		let s:cache[a:dir] = 0
		let result = 0
	else
		" 1 means it's a git project; we'll set the path later
		let s:cache[cmd_result] = 1
		let result = cmd_result
	endif

	call s:debug('cache:', s:cache)

	call s:debug('returning get_proj_dir() result =', result)
	return result
endfunction

" Given a proj_dir like:	/home/tyler/proj
" and wd like:			/home/tyler/proj/src
" and path list like:		['src', 'src/tools']
" this would return a string suitable to be assigned to 'path' opt
" e.g. in this case:		'tools,,'
" Assumes wd is either the same as proj_dir or a subdir of it.
function s:path_list_to_str(proj_dir, wd, list)
	call s:debug('path_list_to_str(...)', a:list)
	call s:debug('proj_dir =', a:proj_dir)
	call s:debug('wd =', a:wd)

	" Get a bare wd without the project dir part e.g.
	" proj_dir:	/home/tyler/proj
	" wd:		/home/tyler/proj/src
	" then bare_wd:	src
	let bare_wd = s:trim_parent(a:proj_dir, a:wd)

	let result = []
	for d in a:list
		call s:debug('processing subdir d =', d)

		" The ls-tree cmd outputs './' if there's no subdirs
		if d is './'
			call s:debug('must be no subdirs of', a:wd)
			break
		endif

		if a:proj_dir is a:wd
			call s:debug('wd is at top of project; using all subdirs')
			let result = copy(a:list)
			break
		endif

		call s:debug('wd must be a proper subdir of proj')

		" select only dirs beginning with wd and trim the wd part
		let subdir_of_wd = s:trim_parent(bare_wd, d)

		if empty(subdir_of_wd)
			call s:debug(d..' must not be subdir of '..a:wd)
			continue
		endif

		call s:debug('found a subdir of wd:', subdir_of_wd)
		call add(result, subdir_of_wd)
	endfor

	let result = join(result, ',')..',,'

	call s:debug('path_list_to_str() returning', result)
	return result
endfunction

" Given a parent like:	/home/tyler/proj
" and child like:	/home/tyler/proj/src
" this would return:	'src'
" Otherwise returns 0 if either
" - parent == child
" - child is not a subdir of parent
function s:trim_parent(parent, child)
	call s:debug('trim_parent('..a:parent..', '..a:child..')')

	if a:parent is a:child
		call s:debug('parent == child; returning 0') 
		return 0
	endif

	let index = stridx(a:child..'/', a:parent..'/')
	if index isnot 0
		call s:debug('not a child of parent; returning 0') 
		return 0
	endif

	let result = a:child[strlen(a:parent..'/'):]

	call s:debug('trim_parent() returning', result)
	return result
endfunction

" Adds item to list if not already there.
" If len(list) is at the limit then return 1, otherwise return 0.
" Use overflow str as the last item (if it's longer than the overflow).
function s:merge(list, item, limit = 3, overflow = '...')
	call s:debug('merging('..a:item..') into', a:list)

	if len(a:list) >= a:limit
		call s:debug('list already full. returning 1')
		return 1
	endif

	if index(a:list, a:item) >= 0
		call s:debug('item already in list. returning 0')
		return 0
	endif

	if len(a:list)+1 == a:limit
		call s:debug('adding last item')

		if len(a:item) > len(a:overflow)
			call s:debug('using overflow instead of '..a:item)
			call add(a:list, a:overflow)
		else
			call s:debug('adding final item: '..a:item)
			call add(a:list, a:item)
		endif

		call s:debug('list is now full. returning 1')
		return 1
	endif

	call s:debug('adding item: '..a:item)
	call add(a:list, a:item)

	call s:debug('list is not full yet. returning 0')
	return 0
endfunction

function s:debug(message, obj = v:null)
	if empty(g:debug_forgit)
		return
	endif

	let timestamp = strftime('%H:%M:%S')
	let lines = [timestamp..' '..a:message]

	if type(a:obj) is v:t_number || type(a:obj) is v:t_string
		let lines[0] ..= ' '..a:obj
	elseif type(a:obj) is v:t_list
		let lines += copy(a:obj)->map('"\t"..v:val')
	elseif type(a:obj) is v:t_dict
		let lines += items(a:obj)->map('"\t"..join(v:val, ": ")')
	endif

	call writefile(lines, s:debug_log, 'a')
endfunction

function ForgitStatusLine()
	return '%f (%{ForgitWD(winnr())})%h%w%m%r%= %l,%c%V %P'
endfunction

" Returns the working dir of window/tab
" e.g. for a nongit dir /home/tyler returns 'tyler'
" e.g. in a project dir /home/tyler/proj/src returns 'proj/src'
function ForgitWD(winnr, tabnr = 0)
	let wd = getcwd(a:winnr, a:tabnr)
	let proj_dir = s:get_proj_dir(wd)

	if empty(proj_dir)
		return fnamemodify(wd, ':t')
	endif

	let parent = fnamemodify(proj_dir, ':h')
	return s:trim_parent(parent, wd)
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

		" the label is made by ForgitTabLabel()
		let tabline ..= ' %{ForgitTabLabel('..(i+1)..')} '
	endfor

	" after the last tab fill with TabLineFill and reset tab page nr
	let tabline ..= '%#TabLineFill#%T'

	return tabline
endfunction

function ForgitTabLabel(tabnr)
	let wids = gettabinfo(a:tabnr)[0]['windows']

	let uniq_dirs = []

	for wid in wids
		let dir = s:get_proj_dir(getcwd(wid, a:tabnr))

		if empty(dir)
			" not in a git dir

			" if it's the only window, just show the filename
			if len(wids) == 1
				let file = bufname(winbufnr(wid))
				let name = empty(file) ? '[No Name]' : file
				return fnamemodify(name,':t')
			endif

			" otherwise use the cwd of the file
			let dir = getcwd(wid, a:tabnr)
		endif

		if s:merge(uniq_dirs, fnamemodify(dir, ':t'))
			" merge() returns 1 if the list is full
			break
		endif
	endfor

	return join(uniq_dirs, '|')
endfunction
