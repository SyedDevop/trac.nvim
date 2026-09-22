local utils = require("utils")
local parse_trac = require("parse_trac")
local M = {}

---Get the HUUID from the current line
---Or return nil and logs the messages
---@return string?
local function get_id()
	local raw_line = vim.api.nvim_get_current_line()
	local line = utils.strip_comment_prefix(raw_line)
	local id = line:match("%(([^)]+)%)")

	if id == nil then
		vim.notify("No HUUID found in current line", vim.log.levels.WARN)
		return nil
	end
	if not parse_trac.is_valid_huuid(id) then
		vim.notify(('"%s" is not a valid HUUID'):format(id), vim.log.levels.WARN)
		return nil
	end
	return id
end

M.goto_file = function()
	local id = get_id()
	if id == nil then
		return
	end

	local cmd = parse_trac.build_cmd("find", { id })
	local result = vim.system(cmd, { text = true }):wait()
	if result.code ~= 0 then
		vim.notify(("trac find exited " .. result.stderr), vim.log.levels.WARN)
		return
	end
	local task = parse_trac.parse_stdout(result.stdout)[1]
	vim.schedule(function()
		vim.cmd.edit(vim.fn.fnameescape(task.path))
	end)
end

--- Find all code references to the task on the current line.
---
--- The current line must contain a task HUUID, for example:
--- `// TASK(20260922-075442): Add tests`
---
--- Searches the codebase for the HUUID and opens the matches
--- in the quickfix list.
M.find_task_references = function()
	local id = get_id()
	if id == nil then
		return
	end
	vim.cmd.grep(id)
	vim.cmd.copen()
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
	local cmd = parse_trac.build_cmd("id")
	local cwd = vim.fn.expand("%:p:h")
	local result = vim.system(cmd, { text = true, cwd = cwd }):wait()
	if result.code ~= 0 then
		vim.notify(("Find referenced tasks: " .. result.stderr), vim.log.levels.WARN, { title = "Trac (Task Tracker)" })
		return
	end
	if result.stdout == nil or result.stdout == "" then
		vim.notify("Find referenced tasks: Unknown error", vim.log.levels.WARN, { title = "Trac (Task Tracker)" })
		return
	end

	vim.cmd.grep(vim.trim(result.stdout))

	if #vim.fn.getqflist() == 0 then
		vim.notify("No references found", vim.log.levels.INFO, { title = "Trac (Task Tracker)" })
		return
	end
	vim.cmd.copen()
end
return M
