local parse_trac = require("parse_trac")
local M = {}

---@param line string
---@return string
local function strip_comment_prefix(line)
	local prefix = vim.trim(vim.split(vim.bo.commentstring, "%s")[1] or "")
	return (line:gsub("^%s*" .. vim.pesc(prefix) .. "%s*", "", 1))
end

M.open = function()
	local block = parse_trac.get_todo_block()
	if block == nil then
		return
	end
	local prefix = vim.trim(vim.split(vim.bo.commentstring, "%s")[1] or "")

	local title_indent = 0
	---@type string?
	local title = nil
	---@type string[]
	local body = {}
	for _, raw_line in ipairs(block.block) do
		local line = strip_comment_prefix(raw_line)
		if title == nil then
			local lower_line = line:lower()
			if vim.startswith(lower_line, "todo") then
				title_indent = math.min(#raw_line - #(vim.trim(raw_line)), title_indent)
				title = line:gsub("^[Tt][Oo][Dd][Oo]%s*:", "")
			end
		else
			body[#body + 1] = line
		end
	end
	local cmd = parse_trac.build_cmd("new", {
		title,
		"--body",
		table.concat(body, "\n"),
	})

	local result = vim.system(cmd, { text = true }):wait()
	local task = parse_trac.parse_stdout(result.stdout)[1]

	local content = ("%s%s TASK(%s):%s"):format(string.rep(" ", title_indent), prefix, task.id, title)
	vim.api.nvim_buf_set_lines(0, block.block_start, block.block_end, true, { content })
	vim.notify("Created task: " .. task.id, vim.log.levels.INFO, { title = "Trac (Task Tracker)" })
end

return M
