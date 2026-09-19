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

--- Calculate the geometry for each picker component.
---@return Win.Layout
M.layout = function()
	local cols, lines = vim.o.columns, vim.o.lines - vim.o.cmdheight
	local W = math.floor(cols * 0.9)
	local H = math.floor(lines * 0.85)
	local row = math.floor((lines - H) / 2)
	local col = math.floor((cols - W) / 2)
	local left = math.floor(W * 0.4) -- outer width of left column
	local right = W - left - 1 -- 1 col gap between columns
	local pane_h = H - 1 -- last line is the footer bar
	return {
		prompt = { row = row, col = col, width = W - 2, height = 1 },
		results = { row = row + 3, col = col, width = left - 2, height = pane_h - 3 - 2 },
		preview = { row = row + 3, col = col + left + 1, width = right - 2, height = pane_h - 3 - 2 },
		footer = { row = row + pane_h, col = col, width = W, height = 1 },
		background = { row = row, col = col, width = W, height = H },
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
function M.open_all()
	local geo = M.layout()

	---@type Win.AllWindows
	local windows = {}

	local configs = {
		prompt = { title = " files ", title_pos = "center", zindex = 51 },
		results = { title = " Results ", title_pos = "center" },
		preview = { title = " Preview ", title_pos = "center" },
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
