# vim-forgit

Forget managing the cwd and other options for git projects.

The current working directory impacts a lot of useful commands
like `:grep` and `:term` but managing it is a burden,
especially when working in multiple projects at once.
This plugin includes autocommands that will:

- `:lcd` to the project root when editing a file in a git project
- set `path` (for `:find`, etc.) and `grepprg` when the cwd is in a git project

It also shows the current git project in the statusline and tabline,
unless you set those options.

## Why not lua?

- I probably know vimscript better than I know lua right now
- backwards compatibility with good ol' vim
- I might rewrite in lua down the road

## TODO

- show cwd in statusline/tabline relative to git dir
- don't `:lcd` if `autochdir` is on
- if a tab has two repos show them both like `repoA|repoB`
- if there's more than two should they all be shown?
- how will it work with submodules?
- restore opts when moving out of a git project
- make git calls async (then also don't need to worry about nested autocmds)
