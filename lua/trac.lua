local M = {}

M.setup = function()
	vim.keymap.set("n", "<leader>ff", function()
		require("cmds.ls_picker").open()
	end)
end

return M
