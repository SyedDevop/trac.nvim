local M = {}

--- @param win  number :The id for  window to attach
--- @param buf  number :The id for the buffer
--- @param keys string[]|string:The keys to attach
function M.attach_close_keys(win, buf, keys)
	local k = type(keys) == "string" and { keys } or keys
	for _, key in ipairs(k) do
		vim.keymap.set("n", key, function()
			vim.api.nvim_win_close(win, true)
		end, { buffer = buf, noremap = true, silent = true })
	end
end

--- Set the lines in the picker window
--- @param buf integer
--- @param lines string[]
function M.set_lines(buf, lines)
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
end

function M.is_treesitter_active()
	local bufnr = vim.api.nvim_get_current_buf()

	-- Check if a highlighter is actively running on this buffer
	local has_highlighter = vim.treesitter.highlighter.active[bufnr] ~= nil

	-- Check if a parser even exists for this file type
	local lang = vim.bo[bufnr].filetype
	local has_parser = vim.treesitter.language.has_parser(lang)

	return has_highlighter and has_parser
end

return M
