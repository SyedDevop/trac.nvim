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

return M
