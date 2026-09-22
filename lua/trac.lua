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

M.find_references = function()
	require("cmds.find").find_references()
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
