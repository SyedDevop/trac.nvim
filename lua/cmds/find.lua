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

M.find_references = function()
	local id = get_id()
	if id == nil then
		return
	end
	vim.cmd.grep(id)
	vim.cmd.copen()
end

return M
