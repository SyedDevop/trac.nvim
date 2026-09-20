local M = {}

--- @alias PathObject { path: string, id: string }The path and id of the task

--- Parse a line from `tatr|trac ls` and return task information.
--- @param line string
--- @return PathObject
M.task_from_ls_line = function(line)
	local parts = vim.split(line, ":")
	local path = parts[1] or ""
	local dir_p = vim.fs.dirname(path)
	return {
		id = vim.fs.basename(dir_p),
		path = path,
	}
end

--- Build the `trac <cmd_name> [query...]` command.
--- @param cmd_name "ls"|"summary"
--- @param query ?string[]
--- @return string[]
local function build_cmd(cmd_name, query)
	local cmd = { "trac", cmd_name }
	if query then
		vim.list_extend(cmd, query)
	end
	return cmd
end

--- Turn a `trac ls` stdout blob into a list of tasks.
--- @param stdout ?string
--- @return PathObject[]
local function parse_stdout(stdout)
	local tasks = {}
	if not stdout or stdout == "" then
		return tasks
	end
	for _, line in ipairs(vim.split(stdout, "\n")) do
		if line ~= "" then
			table.insert(tasks, M.task_from_ls_line(line))
		end
	end
	return tasks
end

--- Get a list of tasks from `tatr|trac ls`, blocking until it returns.
--- @param query ?string[]
--- @return PathObject[]
M.get_tasks = function(query)
	local result = vim.system(build_cmd("ls", query), { text = true }):wait()
	return parse_stdout(result.stdout)
end

--- Get a list of tasks from `tatr|trac ls` without blocking the UI.
--- @param query ?string[]
--- @param callback fun(tasks: PathObject[], err?: string)
M.get_tasks_async = function(query, callback)
	vim.system(build_cmd("ls", query), { text = true }, function(result)
		vim.schedule(function()
			if result.code ~= 0 then
				callback({}, vim.trim(result.stderr or ("trac ls exited " .. result.code)))
				return
			end
			callback(parse_stdout(result.stdout))
		end)
	end)
end

return M
