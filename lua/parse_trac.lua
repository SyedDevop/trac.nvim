local config = require("config")
local utils = require("utils")
local M = {}
M.HUID_REGEX = vim.regex([[\v(\d{8}-\d{6})(-[a-zA-Z0-9\-]*)?]])

--- @alias PathObject { path: string, id: string, info: string }The path and id of the task

--- Parse a line from `tatr|trac ls` and return task information.
--- @param line string
--- @return PathObject
M.task_from_ls_line = function(line)
	local path, _, info = line:match("^(.-):(%d+):%s*(.*)$")
	local dir_p = vim.fs.dirname(path)
	return {
		id = vim.fs.basename(dir_p),
		path = path,
		info = vim.trim(info or ""),
	}
end
--- Build the `trac <cmd_name> [query...]` command.
--- @param cmd_name "ls"|"summary"|"new"|"find"|"id"
--- @param query ?string[]
--- @return string[]
M.build_cmd = function(cmd_name, query)
	local cmd = { config.options.program, cmd_name }
	if query then
		vim.list_extend(cmd, query)
	end
	return cmd
end

--- Turn a `trac` stdout blob into a list of string.
--- @param stdout ?string
--- @return PathObject[]
M.parse_stdout = function(stdout)
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
	local result = vim.system(M.build_cmd("ls", query), { text = true }):wait()
	return M.parse_stdout(result.stdout)
end

--- Get a list of tasks from `tatr|trac ls` without blocking the UI.
--- @param query ?string[]
--- @param callback fun(tasks: PathObject[], err?: string)
M.get_tasks_async = function(query, callback)
	vim.system(M.build_cmd("ls", query), { text = true }, function(result)
		vim.schedule(function()
			if result.code ~= 0 then
				callback({}, vim.trim(result.stderr or ("trac ls exited " .. result.code)))
				return
			end
			callback(M.parse_stdout(result.stdout))
		end)
	end)
end

---@param n TSNode?
---@return boolean
local function is_comment(n)
	return n ~= nil and n:type():find("comment") ~= nil
end

--- Last row a node actually occupies (end_() is exclusive).
---@param n TSNode
---@return integer
local function last_row(n)
	local row, col = n:end_()
	if col == 0 and row > n:start() then
		row = row - 1
	end
	return row
end

--- Get the TODO block from the current buffer and courser position
---@return { block_start: integer, block_end: integer, block : string[] }?
M.get_todo_block = function()
	local node = vim.treesitter.get_node()
	if not node then
		vim.notify("No Tree-sitter node found at cursor.", vim.log.levels.ERROR)
		return nil
	end
	if node:type() ~= "comment" then
		vim.notify("Cursor is not in a comment", vim.log.levels.ERROR)
		return nil
	end

	local start_row = node:start()
	local end_row = last_row(node)

	local prev = node:prev_sibling()
	while prev and is_comment(prev) and last_row(prev) == start_row - 1 do
		start_row = prev:start()
		prev = prev:prev_sibling()
	end

	local next = node:next_sibling()
	while next and is_comment(next) and next:start() == end_row + 1 do
		end_row = last_row(next)
		next = next:next_sibling()
	end

	return {
		block_start = start_row,
		block_end = end_row + 1,
		block = vim.api.nvim_buf_get_lines(0, start_row, end_row + 1, true),
	}
end

local function is_digit(c)
	return c:match("%d") ~= nil
end

local function is_alnum_or_dash(c)
	return c:match("[%w%-]") ~= nil
end
--- Check if a huuid is valid
---@param huuid string
---@return boolean
M.is_valid_huuid = function(huuid)
	local len = #huuid
	if len < 15 then
		return false
	end

	for i = 1, len do
		local c = huuid:sub(i, i)

		if i <= 8 then
			if not is_digit(c) then
				return false
			end
		elseif i == 9 then
			if c ~= "-" then
				return false
			end
		elseif i <= 15 then
			if not is_digit(c) then
				return false
			end
		else
			if i == 16 then
				if len < 17 then
					return false
				end
				if c ~= "-" then
					return false
				end
			end
			if not is_alnum_or_dash(c) then
				return false
			end
		end
	end

	return true
end
return M
