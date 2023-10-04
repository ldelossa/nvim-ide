local p_reg = require("ide.panels.panel_registry")
local p = require("ide.panels.panel")

local M = {}

function M.test()
	local tp = p.new(1, p.PANEL_POS_TOP)
	local lp = p.new(1, p.PANEL_POS_LEFT)
	local rp = p.new(1, p.PANEL_POS_RIGHT)
	local bp = p.new(1, p.PANEL_POS_BOTTOM)

	p_reg.register(1, tp)
	p_reg.register(1, lp)
	p_reg.register(1, rp)
	p_reg.register(1, bp)

	if pcall(p_reg.register, 1, tp) then
		error("expected duplicate register of top panel to fail.")
	end

	local panels = p_reg.get_panels(1)

	if not vim.deep_equal(panels.top, tp) then
		error("retrieved top panel did not match constructed")
	end
	if not vim.deep_equal(panels.left, lp) then
		error("retrieved left panel did not match constructed")
	end
	if not vim.deep_equal(panels.right, rp) then
		error("retrieved right panel did not match constructed")
	end
	if not vim.deep_equal(panels.left, lp) then
		error("retrieved left panel did not match constructed")
	end

	p_reg.unregister(1, tp)
	p_reg.unregister(1, lp)
	p_reg.unregister(1, rp)
	p_reg.unregister(1, bp)

	panels = p_reg.get_panels(1)

	if panels.top ~= nil then
		error("expected top panel to be nil after unregistering")
	end
	if panels.left ~= nil then
		error("expected left panel to be nil after unregistering")
	end
	if panels.right ~= nil then
		error("expected right panel to be nil after unregistering")
	end
	if panels.bottom ~= nil then
		error("expected bottom panel to be nil after unregistering")
	end
end

return M
