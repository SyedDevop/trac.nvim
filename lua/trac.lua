local M = {}

M.ls_open = function()
	require("cmds.ls_picker").open()
end

M.setup = function()
	vim.api.nvim_create_user_command("TracLs", function()
		require("cmds.ls_picker").open()
	end, {
		desc = "Open trac ls. Task file selection.",
	})
end

return M
