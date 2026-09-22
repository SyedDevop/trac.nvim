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
---@class Trac.SetupOpts
---@field program? "trac"|"tatr" The executable to use for task management.

---Configure the Trac plugin.
---@param opts? Trac.SetupOpts Configuration options.
M.setup = function(opts)
	require("config").setup(opts)
end

return M
