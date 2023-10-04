local component = require("ide.panels.component")

-- TestComponent is a derived Component which simply creates a buffer with its
-- name.
--
-- Used for testing purposes.
local TestComponent = {}

TestComponent.new = function(name)
	local self = component.new(name)

	-- implementation open which returns a simple buffer with a
	-- string.
	function self.open()
		local buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "test component: " .. self.name })
		return buf
	end

	-- no-op for post_win_create()
	function self.post_win_create() end

	return self
end

return TestComponent
