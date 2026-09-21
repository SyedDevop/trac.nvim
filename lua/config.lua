local M = {}

---@class Trac.Config
---@field program "trac"|"tatr" The executable to use for task management.
M.defaults = {
	program = "trac",
}

---@type Trac.Config
M.options = vim.deepcopy(M.defaults)

---@param opts? Trac.SetupOpts
M.setup = function(opts)
	M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

return M
