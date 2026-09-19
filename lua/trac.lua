local utils = require("utils")
local Wins = require("window")
local parse_trac = require("parse_trac")
local api = vim.api
local M = {}

local ns = api.nvim_create_namespace("trac")
local sel_ns = api.nvim_create_namespace("trac_selection")

local PROMPT = "> "
local MAX_SHOWN = 500

local function set_hl()
	local links = {
		TracBorder = "FloatBorder",
		TracTitle = "Title",
		TracPreviewTitle = "Special",
		TracCounter = "Comment",
		TracMatch = "Special",
		TracSelected = "CursorLine",
		TracBadge = "IncSearch",
		TracKey = "Function",
	}
	for name, target in pairs(links) do
		api.nvim_set_hl(0, name, { link = target, default = true })
	end
end

local function set_lines(buf, lines)
	vim.bo[buf].modifiable = true
	api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
end

local tracLs = function()
	local all = parse_trac.get_tasks({})
	local items = all
	local closed = false
	local selected = 1

	set_hl()
	local wins = Wins.open_all()
	vim.wo[wins.results.win].cursorline = true
	vim.wo[wins.results.win].signcolumn = "yes:1"
	vim.wo[wins.preview.win].number = true

	vim.bo[wins.prompt.buf].buftype = "prompt"
	vim.fn.prompt_setprompt(wins.prompt.buf, PROMPT)

	local function render_selection()
		api.nvim_buf_clear_namespace(wins.results.buf, sel_ns, 0, -1)
		if #items == 0 then
			return
		end
		api.nvim_buf_set_extmark(wins.results.buf, sel_ns, selected - 1, 0, {
			sign_text = ">",
			sign_hl_group = "TracMatch",
		})
		api.nvim_win_set_cursor(wins.results.win, { selected, 0 })
	end

	local function render_results()
		local lines = {}
		for i = 1, math.min(#items, MAX_SHOWN) do
			lines[i] = items[i].id
		end
		set_lines(wins.results.buf, lines)

		-- "15 / 102" counter, right-aligned inside the prompt
		api.nvim_buf_clear_namespace(wins.prompt.buf, ns, 0, -1)
		api.nvim_buf_set_extmark(wins.prompt.buf, ns, 0, 0, {
			virt_text = { { ("%d"):format(#items), "TracCounter" } },
			virt_text_pos = "right_align",
		})

		render_selection()
	end

	local function render_preview()
		local task = items[selected]
		if not task then
			return
		end
		local buf = wins.preview.buf
		local ok, lines = pcall(vim.fn.readfile, task.path or "", "", 1000)
		set_lines(buf, (task.id and ok) and lines or {})

		api.nvim_win_set_config(wins.preview.win, {
			title = { { task.id, "TracPreviewTitle" } },
			title_pos = "center",
		})
		api.nvim_win_set_cursor(wins.preview.win, { 1, 0 })

		-- syntax highlighting: treesitter if available, else regex syntax
		pcall(vim.treesitter.stop, buf)
		vim.bo[buf].syntax = ""
		local ft = task and vim.filetype.match({ filename = task.path }) or ""
		local lang = ft ~= "" and vim.treesitter.language.get_lang(ft) or nil
		if not (lang and pcall(vim.treesitter.start, buf, lang)) then
			vim.bo[buf].syntax = ft
		end
	end

	local function update()
		local line = api.nvim_buf_get_lines(wins.prompt.buf, 0, 1, false)[1] or ""
		local query = line:sub(#PROMPT + 1)
		local new_item = parse_trac.get_tasks({ query })
		if #new_item > 0 then
			items = new_item
		else
			items = all
		end
		selected = 1
		render_results()
		render_preview()
	end

	local function move(delta)
		local n = math.min(#items, MAX_SHOWN)
		if n == 0 then
			return
		end
		selected = (selected - 1 + delta) % n + 1
		render_selection()
		render_preview()
	end

	local close = function()
		if closed then
			return
		end
		closed = true
		vim.cmd.stopinsert()
		for _, w in pairs(wins) do
			w:close()
		end
	end

	local function confirm()
		local task = items[selected]
		close()
		if not task then
			return
		end
		vim.schedule(function()
			vim.cmd.edit(vim.fn.fnameescape(task.path))
		end)
	end

	wins.prompt:mapKey({ "i", "n" }, "<Down>", function()
		move(1)
	end)
	wins.prompt:mapKey({ "i", "n" }, "<Up>", function()
		move(-1)
	end)

	wins.prompt:mapKey("i", "<C-c>", close)
	wins.prompt:mapKey({ "i", "n" }, "<Esc>", close)
	wins.prompt:mapKey({ "i", "n" }, "<Cr>", confirm)

	api.nvim_create_autocmd({ "TextChangedI", "TextChanged" }, {
		buffer = wins.prompt.buf,
		callback = update,
	})

	api.nvim_create_autocmd("BufLeave", {
		buffer = wins.prompt.buf,
		once = true,
		callback = close,
	})
	api.nvim_set_current_win(wins.prompt.win)
	update()
	vim.cmd.startinsert()
end

M.setup = function()
	vim.keymap.set("n", "<leader>ff", function()
		tracLs()
	end)
end

return M
