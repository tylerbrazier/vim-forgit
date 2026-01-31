# vim-forgit

Sets options for git projects.

The purpose is to make `:find`, `:grep`, etc. work efficiently by setting
`path` to all the tracked subdirs of the cwd whenever it changes
and `grepprg` to use `git grep`.
It also sets the default `statusline` and `tabline` to show the cwd/project.

This makes it easy to open multiple projects in a single vim instance (no tmux)
by setting the tab/window's cwd.

## TODO

- haven't tested this with submodules
