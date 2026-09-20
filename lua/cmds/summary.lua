local window = require("window")
local utils = require("utils")
local parse_trac = require("parse_trac")
local api = vim.api

local M = {}
M.f_win = nil

M.open_summary_window = function()
	local f_geo = window.float_geometry()
	local buf = window.scratch()
	local win = window.open(buf, f_geo, {
		title = "Trac Summary",
		title_pos = "center",
	})
	M.f_win = window.FloatingWindow.new(buf, win)
	vim.print("open_summary_window")
end

M.open = function()
	M.open_summary_window()
	api.nvim_set_current_win(M.f_win.win)

	vim.system(parse_trac.build_cmd("summary", {}), { text = true }, function(result)
		vim.schedule(function()
			if result.code ~= 0 then
				vim.notify(vim.trim(result.stderr or ("trac summary: " .. result.code)), vim.log.levels.ERROR)
				return
			end

			--- @type string[]
			local lines = {}
			if not result.stderr or result.stdout == "" then
				return
			end
			for _, line in ipairs(vim.split(result.stdout, "\n")) do
				if line ~= "" then
					table.insert(lines, line)
				end
			end
			utils.set_lines(M.f_win.buf, lines)
		end)
	end)
end

return M
