# vim-forgit

Sets options for git projects:

- `statusline` to include project/cwd
- `tabline` to show projects (based on cwd of windows)
- `path` to include tracked subdirs (for efficient `:find`, `gf`, etc.)
- `grepprg` to use `git grep` (for efficient `:grep`)

This way multiple projects can be opened in a single vim instance (no tmux),
either per window or per tab; just `:lcd` to set the project for that window/tab,
and the plugin will set the options when switching between them.

## TODO

- haven't tested this with submodules
- if the path is set e.g. in a modeline, it will get cleared when changing cwd
