local window = require("window")
local utils = require("utils")
local parse_trac = require("parse_trac")
local api = vim.api
local ns = api.nvim_create_namespace("trac_summary")

local M = {}
M.f_win = nil

local function set_hl()
	local links = {
		TracSummaryBorder = "FloatBorder",
		TracSummaryTitle = "Title",
		TracSummaryLabel = "Comment",
		TracSummaryValue = "Number",
		TracSummaryTag = "Special",
		TracSummaryCount = "Number",
	}
	for name, target in pairs(links) do
		api.nvim_set_hl(0, name, { link = target, default = true })
	end
end

--- Highlight the `KEY: VALUE` and `tag => N` tokens `trac summary` prints,
--- and show the window's keymap hints.
--- @param buf integer
--- @param lines string[]
local function highlight_lines(buf, lines)
	api.nvim_buf_clear_namespace(buf, ns, 0, -1)
	for i, line in ipairs(lines) do
		local row = i - 1
		local key, val = line:match("^(%u+:)%s*(.*)$")
		if key then
			api.nvim_buf_set_extmark(buf, ns, row, 0, { end_col = #key, hl_group = "TracSummaryLabel" })
			if val ~= "" then
				api.nvim_buf_set_extmark(buf, ns, row, #line - #val, { end_col = #line, hl_group = "TracSummaryValue" })
			end
		else
			local indent, tag = line:match("^(%s*)(%S+)%s+=>")
			if tag then
				local tag_col = #indent
				api.nvim_buf_set_extmark(
					buf,
					ns,
					row,
					tag_col,
					{ end_col = tag_col + #tag, hl_group = "TracSummaryTag" }
				)
				local count_col = line:find("%d+%s*$")
				if count_col then
					api.nvim_buf_set_extmark(
						buf,
						ns,
						row,
						count_col - 1,
						{ end_col = #line, hl_group = "TracSummaryCount" }
					)
				end
			end
		end
	end

	api.nvim_buf_set_extmark(buf, ns, 0, 0, {
		virt_text = { { " q:close  r:refresh ", "TracSummaryLabel" } },
		virt_text_pos = "right_align",
	})
end

--- Open (or focus, if one is already open) the floating summary window.
local function open_summary_window()
	if M.f_win and api.nvim_win_is_valid(M.f_win.win) then
		return
	end
	set_hl()
	local f_geo = window.float_geometry()
	local buf = window.scratch()
	local win = window.open(buf, f_geo, {
		title = " Trac Summary ",
		title_pos = "center",
	})
	vim.wo[win].winhighlight = "FloatBorder:TracSummaryBorder,FloatTitle:TracSummaryTitle"

	M.f_win = window.FloatingWindow.new(buf, win)
	M.f_win:mapKeys("n", { "q", "<Esc>" }, function()
		M.f_win:close()
	end)
	M.f_win:mapKey("n", "r", function()
		M.refresh()
	end)
end

--- Re-run `trac summary` and redraw the window with the result.
M.refresh = function()
	if not M.f_win or not api.nvim_win_is_valid(M.f_win.win) then
		return
	end
	utils.set_lines(M.f_win.buf, { "Loading…" })

	vim.system(parse_trac.build_cmd("summary", {}), { text = true }, function(result)
		vim.schedule(function()
			if result.code ~= 0 then
				local msg = vim.trim(result.stderr or "")
				if msg == "" then
					msg = ("trac summary exited %d"):format(result.code)
				end
				vim.notify("trac summary: " .. msg, vim.log.levels.ERROR)
				utils.set_lines(M.f_win.buf, { msg })
				return
			end

			if not result.stdout or result.stdout == "" then
				utils.set_lines(M.f_win.buf, { "No tasks found." })
				return
			end

			--- @type string[]
			local lines = {}
			for _, line in ipairs(vim.split(result.stdout, "\n")) do
				if line ~= "" then
					table.insert(lines, line)
				end
			end
			utils.set_lines(M.f_win.buf, lines)
			highlight_lines(M.f_win.buf, lines)
		end)
	end)
end

M.open = function()
	open_summary_window()
	api.nvim_set_current_win(M.f_win.win)
	M.refresh()
end

return M
