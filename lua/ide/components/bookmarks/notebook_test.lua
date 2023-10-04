local notebook = require("ide.components.bookmarks.notebook")

local M = {}

function M.test_functionality()
	vim.fn.mkdir("/tmp/notebook-test")
	vim.fn.writefile({}, "/tmp/notebook-test/test nb.notebook")

	local buf = vim.api.nvim_create_buf(true, false)

	local nb = notebook.new(buf, "test nb", "/tmp/notebook-test/test nb.notebook")
	nb.create_bookmark({})

	-- vim.fn.delete("/tmp/notebook-test", "rf")
end

return M
