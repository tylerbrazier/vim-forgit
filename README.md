# vim-forgit

It's common to work in multiple git projects at once
and always needing to switch between them.
Some people manage this by opening a terminal tab per project
or using a terminal multiplexer,
but it's better to have all your projects open within the same vim instance:

- vim already has tabs, windows, & terminals so make use of them
- no need to install multiplexers or learn shortcuts for different terminals
- lighter on resources than having a separate vim instance per project or file
- easy to compare/diff files belonging to different projects

The problem with this is commands like `:grep`, `:find`, `:term`, etc.
work according to the current working directory (cwd), so that needs to be
changed when switching projects.
This plugin solves that problem by inverting it:
**switch projects by changing the cwd**.
Think of it this way: the cwd determines what project you're working in.
The plugin responds to `DirChanged` events by updating `grepprg` and `path`
so `:grep`, `:find`, `gf`, etc are scoped to the cwd.
Each vim window or tab can have its own cwd
so you can have a project per window or per tab, however you want.
The plugin shows the cwd in the statusline, and project root in the tabline.

## TODO

- haven't tested this with submodules
- if the path is set e.g. in a modeline, it will get cleared when changing cwd
