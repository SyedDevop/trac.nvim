local M = {}

--- @class WinConfig
--- @field header vim.api.keyset.win_config
--- @field body vim.api.keyset.win_config
--- @field footer vim.api.keyset.win_config
--- @return WinConfig

M.create_window_configurations = function()
	local ui = vim.api.nvim_list_uis()[1]
	local width = math.floor(ui.width * 0.8)
	local height = math.floor(ui.height * 0.6)
	local row = math.floor((ui.height - height) / 2)
	local col = math.floor((ui.width - width) / 2)

	return {
		header = {
			relative = "editor",
			width = width,
			height = 1,
			style = "minimal",
			border = "rounded",
			col = col,
			row = row,
			zindex = 2,
		},
		body = {
			relative = "editor",
			width = width,
			height = height,
			row = row,
			col = col,
			style = "minimal", -- Removes line numbers, statusline, etc.
			border = "rounded", -- Can be "single", "double", "rounded", or "shadow"
		},
		footer = {
			relative = "editor",
			width = width,
			height = 1,
			style = "minimal",
			-- TODO: Just a border on the top?
			-- border = "rounded",
			col = 0,
			row = height - 1,
			zindex = 3,
		},
	}
end

return M
