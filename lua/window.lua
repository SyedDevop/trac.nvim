local M = {}
local api = vim.api

---@class Win.LayoutGeometry
---@field row integer
---@field col integer
---@field width integer
---@field height integer

---@class Win.Layout
---@field prompt Win.LayoutGeometry
---@field results Win.LayoutGeometry
---@field preview Win.LayoutGeometry
---@field footer Win.LayoutGeometry
---@field background Win.LayoutGeometry

--- Calculate the geometry for a centered floating window.
---
--- The window is sized relative to the current editor dimensions:
--- - Width: 90% of the available columns.
--- - Height: 85% of the available lines, excluding `cmdheight`.
--- - Position: centered horizontally and vertically.
--- used to position the floating window.
--- @return Win.LayoutGeometry geometry The width, height, row, and column
--- @see Win.LayoutGeometry
M.float_geometry = function()
	local cols = vim.o.columns
	local lines = vim.o.lines - vim.o.cmdheight
	local width = math.floor(cols * 0.9)
	local height = math.floor(lines * 0.85)
	return {
		width = width,
		height = height,
		row = math.floor((lines - height) / 2),
		col = math.floor((cols - width) / 2),
	}
end

--- Calculate the geometry for `ls_picker` component.
---@return Win.Layout
M.ls_layout = function()
	local f_geo = M.float_geometry()
	local left = math.floor(f_geo.width * 0.4) -- outer width of left column
	local right = f_geo.width - left - 1 -- 1 col gap between columns
	local pane_h = f_geo.height - 1 -- last line is the footer bar
	return {
		prompt = { row = f_geo.row, col = f_geo.col, width = f_geo.width - 2, height = 1 },
		results = { row = f_geo.row + 3, col = f_geo.col, width = left - 2, height = pane_h - 3 - 2 },
		preview = { row = f_geo.row + 3, col = f_geo.col + left + 1, width = right - 2, height = pane_h - 3 - 2 },
		footer = { row = f_geo.row + pane_h, col = f_geo.col, width = f_geo.width, height = 1 },
		background = { row = f_geo.row, col = f_geo.col, width = f_geo.width, height = f_geo.height },
	}
end

--- Create a scratch buffer that is wiped when no longer displayed.
---@return integer: Buffer id
M.scratch = function()
	local buf = api.nvim_create_buf(false, true)
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].buftype = "nofile"
	return buf
end

--- Open a floating window.
---@param buf integer
---@param geo Win.LayoutGeometry
---@param opts? vim.api.keyset.win_config
---@return integer
function M.open(buf, geo, opts)
	local config = vim.tbl_extend("force", {
		relative = "editor",
		style = "minimal",
		border = "rounded",
		zindex = 50,
	}, geo, opts or {})

	return api.nvim_open_win(buf, false, config)
end

--- Set the default picker highlights on a window.
---@param win integer
function M.set_highlight(win)
	vim.wo[win].winhighlight = "Normal:Normal,FloatBorder:PickerBorder,FloatTitle:PickerTitle,CursorLine:PickerSelected"
end

--- @class Win.FloatingWindows
--- @field win integer: Window id
--- @field buf integer: Buffer id
M.FloatingWindow = {}
M.FloatingWindow.__index = M.FloatingWindow

---@param modes string|string[]
---@param lhs string
---@param rhs string|function
function M.FloatingWindow:mapKey(modes, lhs, rhs)
	vim.keymap.set(modes, lhs, rhs, {
		buffer = self.buf,
		nowait = true,
	})
end

---@param modes string|string[]
---@param lhss string[]
---@param rhs string|function
function M.FloatingWindow:mapKeys(modes, lhss, rhs)
	for _, lhs in ipairs(lhss) do
		vim.keymap.set(modes, lhs, rhs, {
			buffer = self.buf,
			nowait = true,
		})
	end
end

function M.FloatingWindow:close()
	if api.nvim_win_is_valid(self.win) then
		api.nvim_win_close(self.win, true)
	end
end

---@param buf integer
---@param win integer
---@return Win.FloatingWindows
function M.FloatingWindow.new(buf, win)
	return setmetatable({
		buf = buf,
		win = win,
	}, M.FloatingWindow)
end

--- @class Win.AllWindows
--- @field prompt Win.FloatingWindows
--- @field results Win.FloatingWindows
--- @field preview Win.FloatingWindows
--- @field footer Win.FloatingWindows
--- @field background Win.FloatingWindows

--- Create all picker windows.
---@return Win.AllWindows
function M.open_ls_picker_window()
	local geo = M.ls_layout()

	---@type Win.AllWindows
	local windows = {}

	local configs = {
		prompt = { title = " Query: `OPEN` ", title_pos = "center", zindex = 51 },
		results = { title = " Results ", title_pos = "center" },
		preview = { title = " Task ", title_pos = "center" },
		footer = { border = "none" },
		background = { border = "none", zindex = 49 },
	}

	for name, config in pairs(configs) do
		local buf = M.scratch()
		local win = M.open(buf, geo[name], config)
		windows[name] = M.FloatingWindow.new(buf, win)
	end

	return windows
end

return M
