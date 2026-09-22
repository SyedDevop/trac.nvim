# trac.nvim

A Neovim front-end for [`trac`](https://github.com/SyedDevop/trac) — a
plain-text, file-based task tracker CLI (written in Zig) that implements the
Tasks system spec. Tasks live as Markdown files on disk
(`tasks/<HUID>/TASK.md`), so the whole database is just a directory tree you
can commit to git, grep, and edit by hand. `trac.nvim` gives you a fuzzy
picker over your tasks, a task summary window, and commands for creating and
navigating tasks straight from `TODO` comments in your code.

`trac` implements and credits the spec from the original
[tatr project](https://github.com/tsoding/tatr) by rexim, so `trac.nvim` also
works against `tatr` itself — just set `program = "tatr"`.

## Features

- **Task picker** (`:TracLs`) — a floating fuzzy finder over your tasks with
  a live preview, open/closed toggle, and export to the quickfix/location
  list.
- **Task summary** (`:TracSummary`) — a floating window showing the output
  of `trac summary` (counts by status, tag, etc.), with syntax highlighting
  and a `r` key to refresh.
- **TODO → task** — turn a `TODO` comment block under the cursor into a
  tracked task, rewriting the comment as `TASK(<id>): <title>`.
- **Jump to task file** — put the cursor on a line containing a
  `TASK(<id>)` marker and open that task's file directly.
- **Find references** — from a `TASK(<id>)` comment, grep the codebase for
  every place that references it (results land in the quickfix list).
- **Find referenced tasks** — from a task's file, extract every HUUID it
  references and grep the codebase for all of them at once.

## Requirements

- Neovim >= 0.10
- The [`trac`](https://github.com/SyedDevop/trac) CLI (or the compatible
  [`tatr`](https://github.com/tsoding/tatr) CLI) available on your `PATH`
  (set the executable name via `program`, see
  [Configuration](#configuration))
- `grep`/`ripgrep` configured for `:grep` (used by the find commands)
- Tree-sitter parser for whatever filetype you write `TODO` comments in
  (needed to detect comment blocks for `:TracNewTask`)

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "SyedDevop/trac.nvim",
  opts = {
    program = "trac", -- or "tatr"
  },
}
```

Using [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use({
  "SyedDevop/trac.nvim",
  config = function()
    require("trac").setup({
      program = "trac",
    })
  end,
})
```

## Configuration

```lua
require("trac").setup({
  -- The executable to shell out to for task management.
  program = "trac", -- "trac" | "tatr"
})
```

## Commands

| Command        | Description                                   |
| -------------- | ---------------------------------------------- |
| `:TracLs`      | Open the task picker.                          |
| `:TracSummary` | Open the task summary window.                  |

## Lua API

```lua
local trac = require("trac")

trac.setup(opts)              -- configure the plugin

trac.ls_open()                -- same as :TracLs
trac.summary_open()           -- same as :TracSummary
trac.new_task()                -- turn the TODO under the cursor into a task
trac.goto_task_file()          -- open the task file for the TASK(<id>) on the current line
trac.find_task_references()    -- grep for references to the TASK(<id>) on the current line
trac.find_referenced_tasks()   -- grep for every task referenced by the current TASKS.md file
```

Example keymaps:

```lua
local trac = require("trac")

vim.keymap.set("n", "<leader>tl", trac.ls_open, { desc = "Trac: list tasks" })
vim.keymap.set("n", "<leader>ts", trac.summary_open, { desc = "Trac: summary" })
vim.keymap.set("n", "<leader>tn", trac.new_task, { desc = "Trac: new task from TODO" })
vim.keymap.set("n", "<leader>tg", trac.goto_task_file, { desc = "Trac: goto task file" })
vim.keymap.set("n", "<leader>tr", trac.find_task_references, { desc = "Trac: find task references" })
vim.keymap.set("n", "<leader>tR", trac.find_referenced_tasks, { desc = "Trac: find referenced tasks" })
```

## Usage

### Create a task from a TODO comment

Write a `TODO` comment block, with the cursor anywhere inside it, and run
`new_task` (`trac.new_task()`):

```lua
-- TODO: Add tests for the parser
-- Cover the empty-input and malformed-HUUID cases.
```

The comment is rewritten in place with the new task's id:

```lua
-- TASK(20260922-075442): Add tests for the parser
```

### Jump to / find references for a task

With the cursor on a line containing `TASK(<id>)`:

- `goto_task_file()` opens that task's file.
- `find_task_references()` greps the codebase for `<id>` and opens the
  quickfix list with every match.

### Find every task referenced by a task file

Open a task's `TASKS.md` (inside a directory named by its HUUID, e.g.
`20260922-075442/TASKS.md`) and run `find_referenced_tasks()` to grep the
codebase for every HUUID mentioned in that file at once.

## Task picker keymaps

Inside `:TracLs`:

| Key          | Action                          |
| ------------ | -------------------------------- |
| `<CR>`       | Open the selected task           |
| `<C-q>`      | Send all shown tasks to the location list |
| `<C-t>`      | Toggle between open/closed tasks |
| `<C-n>/<C-p>` or `<Down>/<Up>` | Move selection |
| `<C-d>/<C-u>` | Scroll the preview               |
| `<Esc>`      | Close the picker                 |

## Development

```sh
make test   # run the plenary test suite
make lint   # run luacheck
```

## Credits

- [SyedDevop/trac](https://github.com/SyedDevop/trac) — the task tracker CLI
  this plugin is a Neovim front-end for. All task storage and the `init`,
  `new`, `ls`, `find`, `summary`, and `untag` subcommands come from `trac`
  itself.
- [tsoding/tatr](https://github.com/tsoding/tatr) by rexim — the original
  Tasks system spec and CLI that `trac` implements and is credited from,
  and which `trac.nvim` also works against directly.

## License

[MIT](./LICENSE)
