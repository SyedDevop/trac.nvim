local ls_open = function()
	require("cmds.ls_picker").open()
end
local summary_open = function()
	require("cmds.summary").open()
end

vim.api.nvim_create_user_command("TracLs", ls_open, {
	desc = "Open trac ls. Task file selection.",
})

vim.api.nvim_create_user_command("TracSummary", summary_open, {
	desc = "Open trac summary. Summary of tasks.",
})
