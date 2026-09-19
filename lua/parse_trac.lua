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

--- Get a list of tasks from `tatr|trac ls`.
--- @param query ?string[]
--- @return PathObject[]
M.get_tasks = function(query)
	local cmd = { "trac", "ls" }
	if query then
		vim.list_extend(cmd, query)
	end
	local result = vim.system(cmd, { text = true }):wait()
	local all = vim.split(result.stdout, "\n")
	local tasks = {}
	for _, line in ipairs(all) do
		if line ~= "" then
			local task = M.task_from_ls_line(line)
			table.insert(tasks, task)
		end
	end
	return tasks
end

return M
