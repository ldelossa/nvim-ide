local panel = require("ide.panels.panel")
local tc = require("ide.panels.test_component")

local M = {}

function M.test_component_register()
	local tp = panel.new(vim.api.nvim_get_current_tabpage(), panel.PANEL_POS_TOP)
	if not tp then
		assert(false, "expected panel creation to succeed")
	end
	local lp = panel.new(vim.api.nvim_get_current_tabpage(), panel.PANEL_POS_LEFT)
	if not lp then
		assert(false, "expected panel creation to succeed")
	end
	local rp = panel.new(vim.api.nvim_get_current_tabpage(), panel.PANEL_POS_RIGHT)
	if not rp then
		assert(false, "expected panel creation to succeed")
	end
	local bp = panel.new(vim.api.nvim_get_current_tabpage(), panel.PANEL_POS_BOTTOM)
	if not bp then
		assert(false, "expected panel creation to succeed")
	end

	tp.register_component(tc.new("top_component_1"))
	tp.register_component(tc.new("top_component_2"))
	lp.register_component(tc.new("left_component_1"))
	lp.register_component(tc.new("left_component_2"))
	rp.register_component(tc.new("right_component_1"))
	rp.register_component(tc.new("right_component_2"))
	bp.register_component(tc.new("bottom_component_1"))
	bp.register_component(tc.new("bottom_component_2"))

	tp.open_panel()
	lp.open_panel()
	rp.open_panel()
	bp.open_panel()
end

function M.test_panel_close()
	local tp = panel.new(vim.api.nvim_get_current_tabpage(), panel.PANEL_POS_TOP)
	if not tp then
		assert(false, "expected panel creation to succeed")
	end
	local lp = panel.new(vim.api.nvim_get_current_tabpage(), panel.PANEL_POS_LEFT)
	if not lp then
		assert(false, "expected panel creation to succeed")
	end
	local rp = panel.new(vim.api.nvim_get_current_tabpage(), panel.PANEL_POS_RIGHT)
	if not rp then
		assert(false, "expected panel creation to succeed")
	end
	local bp = panel.new(vim.api.nvim_get_current_tabpage(), panel.PANEL_POS_BOTTOM)
	if not bp then
		assert(false, "expected panel creation to succeed")
	end

	tp.register_component(tc.new("top_component_1"))
	tp.register_component(tc.new("top_component_2"))
	lp.register_component(tc.new("left_component_1"))
	lp.register_component(tc.new("left_component_2"))
	rp.register_component(tc.new("right_component_1"))
	rp.register_component(tc.new("right_component_2"))
	bp.register_component(tc.new("bottom_component_1"))
	bp.register_component(tc.new("bottom_component_2"))

	tp.open_panel()
	lp.open_panel()
	rp.open_panel()
	bp.open_panel()

	tp.close_panel()
	lp.close_panel()
	rp.close_panel()
	bp.close_panel()
end

function M.test_panel_functionality()
	-- run this test with another component open, ensuring all things work while
	-- a secondary panel is present.
	local lp = panel.new(vim.api.nvim_get_current_tabpage(), panel.PANEL_POS_LEFT)
	if not lp then
		assert(false, "expected left panel creation to succeed")
	end
	local lc = tc.new("left_component_1")
	lp.register_component(lc)
	lp.open_panel()

	local tp = panel.new(vim.api.nvim_get_current_tabpage(), panel.PANEL_POS_TOP)
	if not tp then
		assert(false, "expected top panel creation to succeed")
	end

	local c = tc.new("top_component_1")
	tp.register_component(c)

	tp.open_panel()
	assert(tp.is_open(), "expected is_open to return true.")

	tp.close_panel()
	assert(not tp.is_open(), "expected is_open to return false.")

	tp.open_component(c.name)
	assert(tp.is_open(), "expected is_open to return true.")
	local cur_win = vim.api.nvim_get_current_win()
	local cur_buf = vim.api.nvim_get_current_buf()
	assert(cur_win == c.win, "expected current win to be component's win")
	assert(cur_buf == c.buf, "expected current win to be component's buf")

	tp.hide_component(c.name)
	cur_win = vim.api.nvim_get_current_win()
	assert(cur_win ~= c.win, "expected current win to be component's win")
	assert(c.is_hidden(), "expected component to be in hidden state")

	-- confirm open after hide, unhides the element
	tp.open_component(c.name)
	assert(tp.is_open(), "expected is_open to return true.")
	cur_win = vim.api.nvim_get_current_win()
	cur_buf = vim.api.nvim_get_current_buf()
	assert(cur_win == c.win, "expected current win to be component's win")
	assert(cur_buf == c.buf, "expected current win to be component's buf")
	assert(not c.is_hidden(), "expected component to not be in hidden state")

	local c2 = tc.new("top_component_2")
	tp.register_component(c2)
	-- TODO: it takes an open and a close of the panel to display a newly registered
	-- component, consider if this should be done automatically in the register
	-- method, somewhere else or not at all.
	tp.close_panel()
	tp.open_panel()
	tp.open_component(c2.name)
	cur_win = vim.api.nvim_get_current_win()
	cur_buf = vim.api.nvim_get_current_buf()
	assert(cur_win == c2.win, "expected current win to be component's win")
	assert(cur_buf == c2.buf, "expected current win to be component's buf")
	assert(not c2.is_hidden(), "expected component to not be in hidden state")

	tp.hide_component(c2.name)
	cur_win = vim.api.nvim_get_current_win()
	cur_buf = vim.api.nvim_get_current_buf()
	assert(cur_win == c.win, "expected current win to be component's win")
	assert(cur_buf == c.buf, "expected current win to be component's buf")
end

return M
