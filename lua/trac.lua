local M = {}

M.ls_open = function()
	require("cmds.ls_picker").open()
end
M.summary_open = function()
	require("cmds.summary").open()
end

M.setup = function()
	vim.api.nvim_create_user_command("TracLs", M.ls_open, {
		desc = "Open trac ls. Task file selection.",
	})

	vim.api.nvim_create_user_command("TracSummary", M.summary_open, {
		desc = "Open trac summary. Summary of tasks.",
	})

	-- vim.keymap.set("n", "<leader>ts", function() end, {
	-- 	desc = "Open trac summary. Summary of tasks.",
	-- })
end

return M
