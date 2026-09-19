local windows = require("window")
local parse_trac = require("parse_trac")

local api = vim.api
local ns = api.nvim_create_namespace("trac_ls_picker")
local sel_ns = api.nvim_create_namespace("trac_ls_picker_selection")

local PROMPT = "> "
local MAX_SHOWN = 500
local function set_hl()
	local links = {
		TracLsPickerBorder = "FloatBorder",
		TracLsPickerTitle = "Title",
		TracLsPickerPreviewTitle = "Special",
		TracLsPickerCounter = "Comment",
		TracLsPickerMatch = "Special",
		TracLsPickerSelected = "CursorLine",
		TracLsPickerBadge = "IncSearch",
		TracLsPickerKey = "Function",
	}
	for name, target in pairs(links) do
		api.nvim_set_hl(0, name, { link = target, default = true })
	end
end

--- Set the lines in the picker window
--- @param buf integer
--- @param lines string[]
local function set_lines(buf, lines)
	vim.bo[buf].modifiable = true
	api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
end

--- @class Cmds.LsPicker
--- @field prompt Win.FloatingWindows
--- @field results Win.FloatingWindows
--- @field preview Win.FloatingWindows
--- @field footer Win.FloatingWindows
--- @field background Win.FloatingWindows
--- @field state { all: PathObject[], items: PathObject[], closed: boolean, selected: integer} The current state of the picker.
local LsPicker = {}
LsPicker.__index = LsPicker

--- @param tasks PathObject[]: The list of tasks id and path to show
--- @return Cmds.LsPicker
function LsPicker.new(tasks)
	local win = windows.open_all()
	return setmetatable({
		prompt = win.prompt,
		results = win.results,
		preview = win.preview,
		footer = win.footer,
		background = win.background,
		state = {
			all = tasks,
			items = tasks,
			closed = false,
			selected = 1,
		},
	}, LsPicker)
end

function LsPicker:set_win_and_buf_options()
	vim.wo[self.results.win].cursorline = true
	vim.wo[self.results.win].signcolumn = "yes:1"
	vim.wo[self.preview.win].number = true

	vim.bo[self.prompt.buf].buftype = "prompt"
	vim.fn.prompt_setprompt(self.prompt.buf, PROMPT)
end

--- Get the currently selected item
--- @return PathObject
function LsPicker:selected_item()
	return self.state.items[self.state.selected]
end

--- Update the prompt with the current number of items
function LsPicker:selection_stat()
	-- "15 / 102" counter, right-aligned inside the prompt
	api.nvim_buf_clear_namespace(self.prompt.buf, ns, 0, -1)
	api.nvim_buf_set_extmark(self.prompt.buf, ns, 0, 0, {
		virt_text = { { (" %d | %d "):format(self.state.selected, #self.state.items), "TracLsPickerCounter" } },
		virt_text_pos = "right_align",
	})
end

function LsPicker:render_selection()
	api.nvim_buf_clear_namespace(self.results.buf, sel_ns, 0, -1)
	if #self.state.items == 0 then
		return
	end
	api.nvim_buf_set_extmark(self.results.buf, sel_ns, self.state.selected - 1, 0, {
		sign_text = ">",
		sign_hl_group = "TracLsPickerMatch",
	})
	api.nvim_win_set_cursor(self.results.win, { self.state.selected, 0 })
end

function LsPicker:render_results()
	local lines = {}
	for i = 1, math.min(#self.state.items, MAX_SHOWN) do
		lines[i] = self.state.items[i].id
	end
	set_lines(self.results.buf, lines)

	self:selection_stat()
	self:render_selection()
end

function LsPicker:render_preview()
	local task = self:selected_item()
	if not task then
		return
	end

	local buf = self.preview.buf
	local ok, lines = pcall(vim.fn.readfile, task.path or "", "", 1000)
	set_lines(buf, (task.id and ok) and lines or {})

	api.nvim_win_set_config(self.preview.win, {
		title = { { task.id, "TracPreviewTitle" } },
		title_pos = "center",
	})
	api.nvim_win_set_cursor(self.preview.win, { 1, 0 })

	-- syntax highlighting: treesitter if available, else regex syntax
	pcall(vim.treesitter.stop, buf)
	vim.bo[buf].syntax = ""
	local ft = task and vim.filetype.match({ filename = task.path }) or ""
	local lang = ft ~= "" and vim.treesitter.language.get_lang(ft) or nil
	if not (lang and pcall(vim.treesitter.start, buf, lang)) then
		vim.bo[buf].syntax = ft
	end
end

function LsPicker:render_footer()
	local geo = windows.layout()
	local badge = " " .. ("Task Tracker"):upper() .. " "
	local hints = { { "Open", "<CR>" }, { "Move", "C-n/C-p" }, { "Scroll", "C-d/C-u" }, { "Close", "Esc" } }
	local right, key_hls = "", {}
	for i, h in ipairs(hints) do
		if i > 1 then
			right = right .. " • "
		end
		right = right .. h[1] .. ": "
		key_hls[#key_hls + 1] = { #right, #right + #h[2] }
		right = right .. h[2]
	end
	local gap = math.max(1, geo.footer.width - #badge - vim.fn.strdisplaywidth(right) - 2)
	local prefix = " " .. badge .. string.rep(" ", gap)
	set_lines(self.footer.buf, { prefix .. right })

	api.nvim_buf_clear_namespace(self.footer.buf, ns, 0, -1)
	api.nvim_buf_set_extmark(self.footer.buf, ns, 0, 1, { end_col = 1 + #badge, hl_group = "TracLsPickerBadge" })
	for _, r in ipairs(key_hls) do
		api.nvim_buf_set_extmark(self.footer.buf, ns, 0, #prefix + r[1], {
			end_col = #prefix + r[2],
			hl_group = "TracLsPickerKey",
		})
	end
end

function LsPicker:update()
	local line = api.nvim_buf_get_lines(self.prompt.buf, 0, 1, false)[1] or ""
	local query = line:sub(#PROMPT + 1)
	local new_item = parse_trac.get_tasks({ query })
	if #new_item > 0 then
		self.state.items = new_item
	else
		self.state.items = self.state.all
	end
	self.state.selected = 1
	self:render_results()
	self:render_preview()
end

function LsPicker:move(delta)
	local n = math.min(#self.state.items, MAX_SHOWN)
	if n == 0 then
		return
	end
	self.state.selected = (self.state.selected - 1 + delta) % n + 1
	self:render_selection()
	self:render_preview()
	self:selection_stat()
end

function LsPicker:scroll_preview(key)
	local keys = api.nvim_replace_termcodes(key, true, false, true)
	api.nvim_win_call(self.preview.win, function()
		vim.cmd("normal! " .. keys)
	end)
end

function LsPicker:close()
	if self.state.closed then
		return
	end
	self.state.closed = true
	vim.cmd.stopinsert()
	self.background:close()
	self.prompt:close()
	self.results:close()
	self.preview:close()
	self.footer:close()
end

function LsPicker:confirm()
	local task = self:selected_item()
	self:close()
	if not task then
		return
	end
	vim.schedule(function()
		vim.cmd.edit(vim.fn.fnameescape(task.path))
	end)
end

function LsPicker.open()
	set_hl()
	local ls_pick = LsPicker.new(parse_trac.get_tasks({}))
	ls_pick:set_win_and_buf_options()

	ls_pick.prompt:mapKeys({ "i", "n" }, { "<Down>", "<C-n>" }, function()
		ls_pick:move(1)
	end)
	ls_pick.prompt:mapKeys({ "i", "n" }, { "<Up>", "<C-p>" }, function()
		ls_pick:move(-1)
	end)

	ls_pick.prompt:mapKey({ "i", "n" }, "<C-u>", function()
		ls_pick:scroll_preview("<C-u>")
	end)
	ls_pick.prompt:mapKey({ "i", "n" }, "<C-d>", function()
		ls_pick:scroll_preview("<C-d>")
	end)

	ls_pick.prompt:mapKey("i", "<C-c>", function()
		ls_pick:close()
	end)
	ls_pick.prompt:mapKeys({ "i", "n" }, { "<Esc>" }, function()
		ls_pick:close()
	end)

	ls_pick.prompt:mapKey({ "i", "n" }, "<Cr>", function()
		ls_pick:confirm()
	end)

	api.nvim_create_autocmd({ "TextChangedI", "TextChanged" }, {
		buffer = ls_pick.prompt.buf,
		callback = function()
			ls_pick:update()
		end,
	})

	api.nvim_create_autocmd("BufLeave", {
		buffer = ls_pick.prompt.buf,
		once = true,
		callback = function()
			ls_pick:close()
		end,
	})

	api.nvim_set_current_win(ls_pick.prompt.win)
	ls_pick:render_footer()
	ls_pick:update()
	vim.cmd.startinsert()
end

return LsPicker
