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

return M
