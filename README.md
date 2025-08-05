# vim-forgit

Forget managing the cwd and other options for git projects.

The current working directory impacts a lot of useful commands
like `:grep` and `:term` but managing it is a burden,
especially when working in multiple projects at once.
This plugin includes autocommands that will:

- `:lcd` to the project root when editing a file in git project
- set `path` (for `:find`, etc.) and `grepprg` when the cwd is in a git project

## Why not lua?

- I probably know vimscript better than I know lua right now
- backwards compatibility with good ol' vim
- I might rewrite in lua down the road

## TODO

- don't bother if `autochdir` is on
- `let g:netrw_keepdir=1`?
- add debug logs?
- show the cwd somehow (set statusline or echo it when it changes)
- how will it work with submodules?
- restore opts when moving out of a git project
- make git calls async (then also don't need to worry about nested autocmds)
