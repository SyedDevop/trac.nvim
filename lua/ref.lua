-- picker.lua — a television-style fuzzy finder built from floating windows
-- Put this at ~/.config/nvim/lua/picker.lua and map it:
--   vim.keymap.set("n", "<leader>ff", function() require("picker").open() end)
-- Requires Neovim 0.10+

local M = {}
local api = vim.api
local ns = api.nvim_create_namespace("picker")
local sel_ns = api.nvim_create_namespace("picker_selection")
local PROMPT = "> "
local MAX_SHOWN = 500

local function set_hl()
	local links = {
		PickerBorder = "FloatBorder",
		PickerTitle = "Title",
		PickerPreviewTitle = "Special",
		PickerCounter = "Comment",
		PickerMatch = "Special",
		PickerSelected = "CursorLine",
		PickerBadge = "IncSearch",
		PickerKey = "Function",
	}
	for name, target in pairs(links) do
		api.nvim_set_hl(0, name, { link = target, default = true })
	end
end

local function list_files()
	local cmd
	if vim.fn.executable("fd") == 1 then
		cmd = { "fd", "--type", "f" }
	elseif vim.fn.executable("rg") == 1 then
		cmd = { "rg", "--files" }
	end
	if cmd then
		return vim.fn.systemlist(cmd)
	end
	return vim.tbl_filter(function(f)
		return vim.fn.isdirectory(f) == 0
	end, vim.fn.glob("**/*", false, true))
end

-- Geometry. For bordered floats, row/col is the outer (border) corner,
-- while width/height are the inner size, so every box is inner + 2.
local function layout()
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

local function scratch()
	local buf = api.nvim_create_buf(false, true)
	vim.bo[buf].bufhidden = "wipe"
	return buf
end

local function set_lines(buf, lines)
	vim.bo[buf].modifiable = true
	api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
end

local function open_win(buf, geo, opts, transparent)
	local cfg = vim.tbl_extend("force", {
		relative = "editor",
		style = "minimal",
		border = "rounded",
		zindex = 50,
	}, geo, opts or {})
	local win = api.nvim_open_win(buf, false, cfg)
	if transparent == false then
		vim.wo[win].winhighlight =
			"Normal:Normal,FloatBorder:PickerBorder,FloatTitle:PickerTitle,CursorLine:PickerSelected"
	end
	return win
end

---@param opts? { title?: string, items?: string[], on_select?: fun(item: string) }
function M.open(opts)
	opts = opts or {}
	set_hl()

	local all = opts.items or list_files()
	local items, positions = all, {}
	local selected = 1
	local closed = false
	local geo = layout()

	local bufs =
		{ prompt = scratch(), results = scratch(), preview = scratch(), footer = scratch(), background = scratch() }
	local wins = {}

	wins.background = open_win(bufs.background, geo.background, { border = "none", zindex = 49 }, true)
	wins.results = open_win(bufs.results, geo.results, { title = " Results ", title_pos = "center" })
	wins.preview = open_win(bufs.preview, geo.preview, { title = " Preview ", title_pos = "center" })
	wins.footer = open_win(bufs.footer, geo.footer, { border = "none" })
	wins.prompt = open_win(bufs.prompt, geo.prompt, {
		title = " " .. (opts.title or "files") .. " ",
		title_pos = "center",
		zindex = 51,
	})

	vim.wo[wins.results].cursorline = true
	vim.wo[wins.results].signcolumn = "yes:1"
	vim.wo[wins.preview].number = true

	vim.bo[bufs.prompt].buftype = "prompt"
	vim.fn.prompt_setprompt(bufs.prompt, PROMPT)

	---------------------------------------------------------------- rendering

	local function render_selection()
		api.nvim_buf_clear_namespace(bufs.results, sel_ns, 0, -1)
		if #items == 0 then
			return
		end
		api.nvim_buf_set_extmark(bufs.results, sel_ns, selected - 1, 0, {
			sign_text = ">",
			sign_hl_group = "PickerMatch",
		})
		api.nvim_win_set_cursor(wins.results, { selected, 0 })
	end

	local function render_results()
		local lines = {}
		for i = 1, math.min(#items, MAX_SHOWN) do
			lines[i] = items[i]
		end
		set_lines(bufs.results, lines)

		-- highlight fuzzy-matched characters
		-- (matchfuzzypos gives character indices; fine for ASCII paths)
		api.nvim_buf_clear_namespace(bufs.results, ns, 0, -1)
		for i = 1, #lines do
			for _, p in ipairs(positions[i] or {}) do
				api.nvim_buf_set_extmark(bufs.results, ns, i - 1, p, {
					end_col = p + 1,
					hl_group = "PickerMatch",
					strict = false,
				})
			end
		end

		-- "15 / 102" counter, right-aligned inside the prompt
		api.nvim_buf_clear_namespace(bufs.prompt, ns, 0, -1)
		api.nvim_buf_set_extmark(bufs.prompt, ns, 0, 0, {
			virt_text = { { ("%d / %d "):format(#items, #all), "PickerCounter" } },
			virt_text_pos = "right_align",
		})

		render_selection()
	end

	local function render_preview()
		local path = items[selected]
		local buf = bufs.preview
		local ok, lines = pcall(vim.fn.readfile, path or "", "", 1000)
		set_lines(buf, (path and ok) and lines or {})

		api.nvim_win_set_config(wins.preview, {
			title = { { " " .. (path or "Preview") .. " ", "PickerPreviewTitle" } },
			title_pos = "center",
		})
		api.nvim_win_set_cursor(wins.preview, { 1, 0 })

		-- syntax highlighting: treesitter if available, else regex syntax
		pcall(vim.treesitter.stop, buf)
		vim.bo[buf].syntax = ""
		local ft = path and vim.filetype.match({ filename = path }) or ""
		local lang = ft ~= "" and vim.treesitter.language.get_lang(ft) or nil
		if not (lang and pcall(vim.treesitter.start, buf, lang)) then
			vim.bo[buf].syntax = ft
		end
	end

	local function render_footer(width)
		local badge = " " .. (opts.title or "files"):upper() .. " "
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
		local gap = math.max(1, width - #badge - vim.fn.strdisplaywidth(right) - 2)
		local prefix = " " .. badge .. string.rep(" ", gap)
		set_lines(bufs.footer, { prefix .. right })

		api.nvim_buf_clear_namespace(bufs.footer, ns, 0, -1)
		api.nvim_buf_set_extmark(bufs.footer, ns, 0, 1, { end_col = 1 + #badge, hl_group = "PickerBadge" })
		for _, r in ipairs(key_hls) do
			api.nvim_buf_set_extmark(bufs.footer, ns, 0, #prefix + r[1], {
				end_col = #prefix + r[2],
				hl_group = "PickerKey",
			})
		end
	end

	------------------------------------------------------------------ actions

	local function update()
		local line = api.nvim_buf_get_lines(bufs.prompt, 0, 1, false)[1] or ""
		local query = line:sub(#PROMPT + 1)
		if query == "" then
			items, positions = all, {}
		else
			local res = vim.fn.matchfuzzypos(all, query)
			items, positions = res[1], res[2]
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

	local function scroll(key)
		local keys = api.nvim_replace_termcodes(key, true, false, true)
		api.nvim_win_call(wins.preview, function()
			vim.cmd("normal! " .. keys)
		end)
	end

	local function close()
		if closed then
			return
		end
		closed = true
		vim.cmd.stopinsert()
		for _, w in pairs(wins) do
			if api.nvim_win_is_valid(w) then
				api.nvim_win_close(w, true)
			end
		end
		for _, b in pairs(bufs) do
			pcall(api.nvim_buf_delete, b, { force = true })
		end
	end

	local function confirm()
		local path = items[selected]
		close()
		if not path then
			return
		end
		vim.schedule(function()
			if opts.on_select then
				opts.on_select(path)
			else
				vim.cmd.edit(vim.fn.fnameescape(path))
			end
		end)
	end

	----------------------------------------------------------------- keymaps

	local function map(modes, lhs, fn)
		vim.keymap.set(modes, lhs, fn, { buffer = bufs.prompt, nowait = true })
	end
	map({ "i", "n" }, "<Down>", function()
		move(1)
	end)
	map({ "i", "n" }, "<Up>", function()
		move(-1)
	end)
	map("i", "<C-n>", function()
		move(1)
	end)
	map("i", "<C-p>", function()
		move(-1)
	end)
	map({ "i", "n" }, "<C-d>", function()
		scroll("<C-d>")
	end)
	map({ "i", "n" }, "<C-u>", function()
		scroll("<C-u>")
	end)
	map({ "i", "n" }, "<CR>", confirm)
	map({ "i", "n" }, "<Esc>", close)
	map("i", "<C-c>", close)

	---------------------------------------------------------------- autocmds

	api.nvim_create_autocmd({ "TextChangedI", "TextChanged" }, {
		buffer = bufs.prompt,
		callback = update,
	})
	api.nvim_create_autocmd("BufLeave", {
		buffer = bufs.prompt,
		once = true,
		callback = close,
	})
	api.nvim_create_autocmd("VimResized", {
		group = api.nvim_create_augroup("PickerResize", { clear = true }),
		callback = function()
			if closed then
				return true
			end -- returning true deletes the autocmd
			local g = layout()
			for name, w in pairs(wins) do
				api.nvim_win_set_config(w, vim.tbl_extend("force", { relative = "editor" }, g[name]))
			end
			render_footer(g.footer.width)
		end,
	})

	-------------------------------------------------------------------- start

	api.nvim_set_current_win(wins.prompt)
	render_footer(geo.footer.width)
	update()
	vim.cmd.startinsert()
end

return M
