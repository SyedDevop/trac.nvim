local M = {}

M.ls_open = function()
	require("cmds.ls_picker").open()
end
M.summary_open = function()
	require("cmds.summary").open()
end

M.new_task = function()
	require("cmds.new").open()
end

--- Find all code references to the task on the current line.
---
--- The current line must contain a task HUUID, for example:
--- `// TASK(20260922-075442): Add tests`
---
--- Searches the codebase for the HUUID and opens the matches
--- in the quickfix list.
M.find_task_references = function()
	require("cmds.find").find_task_references()
end

--- Find all tasks referenced by the current task file.
---
--- The current file must be a `TASKS.md` file inside a task
--- directory named by its HUUID, for example:
--- `20260922-075442/TASKS.md`
---
--- Extracts the HUUIDs referenced by the task file and searches
--- the codebase for their references.
M.find_referenced_tasks = function()
	require("cmds.find").find_referenced_tasks()
end

M.goto_task_file = function()
	require("cmds.find").goto_file()
end

---@class Trac.SetupOpts
---@field program? "trac"|"tatr" The executable to use for task management.

---Configure the Trac plugin.
---@param opts? Trac.SetupOpts Configuration options.
M.setup = function(opts)
	require("config").setup(opts)
end

return M
