local M = {}

M.ls_open = function()
	require("cmds.ls_picker").open()
end
M.summary_open = function()
	require("cmds.summary").open()
end

M.setup = function() end

return M
