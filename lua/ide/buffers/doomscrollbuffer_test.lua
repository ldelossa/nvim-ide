local dsbuf = require("ide.buffers.doomscrollbuffer")

local M = {}

function M.test_functionality()
	local buf = dsbuf.new(function(_)
		return { "additional line 1", "additional line 2" }
	end)
	print(vim.inspect(buf))
	buf.write_lines({ "first" })
	buf.write_lines({ "second" })
	buf.write_lines({ "third" })
end

return M
