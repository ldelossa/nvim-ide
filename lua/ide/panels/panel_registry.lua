-- PanelRegistry is a registry associating panels to tabs.
--
-- It is a global singleton which other components may use after import.
local PanelRegistry = {}

local registry = {
	["1"] = {
		top = nil,
		bottom = nil,
		left = nil,
		right = nil,
	},
}

local prototype = {
	top = nil,
	bottom = nil,
	left = nil,
	right = nil,
}

function PanelRegistry.register(panel)
	if not vim.api.nvim_tabpage_is_valid(panel.tab) then
		error(string.format("attempted to register %s panel for non-existent tab %d", panel.tab, panel.position))
	end
	if registry[panel.tab] == nil then
		registry[panel.tab] = vim.deepcopy(prototype)
		registry[panel.tab][panel.position] = panel
		return
	end
	if registry[panel.tab][panel.position] ~= nil then
		error(
			string.format(
				"attempted to registry %s panel for tab %d but panel already exist for position.",
				panel.position,
				panel.tab
			)
		)
	end
	registry[panel.tab][panel.position] = panel
end

function PanelRegistry.unregister(panel)
	if panel == nil then
		return
	end
	if registry[panel.tab] == nil then
		return
	end
	if registry[panel.tab].top ~= nil then
		registry[panel.tab].top.close()
	end
	if registry[panel.tab].left ~= nil then
		registry[panel.tab].left.close()
	end
	if registry[panel.tab].right ~= nil then
		registry[panel.tab].right.close()
	end
	if registry[panel.tab].bottom ~= nil then
		registry[panel.tab].bottom.close()
	end
	registry[panel.tab] = vim.deepcopy(prototype)
end

function PanelRegistry.get_panels(tab)
	if tab == nil then
		return registry
	end
	return registry[tab]
end

return PanelRegistry
