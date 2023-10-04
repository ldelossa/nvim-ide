-- WorkspaceRegistry is a registry associating Workspaces to tabs.
--
-- It is a global singleton which other components may use after import.
local WorkspaceRegistry = {}

local registry = {
	["1"] = nil,
}

function WorkspaceRegistry.register(workspace)
	if not vim.api.nvim_tabpage_is_valid(workspace.tab) then
		error(string.format("attempted to register workspace for non-existent tab %d", workspace.position))
	end
	if registry[workspace.tab] == nil then
		registry[workspace.tab] = workspace
		return
	end
	if registry[workspace.tab] ~= nil then
		error(
			string.format(
				"attempted to registry workspace for tab %d but workspace already exist for tab",
				workspace.tab
			)
		)
	end
	registry[workspace.tab] = workspace
end

function WorkspaceRegistry.unregister(workspace)
	if registry[workspace.tab] == nil then
		return
	end
	-- close the workspace first
	registry[workspace.tab].close()
	-- remove from registry
	registry[workspace.tab] = nil
end

function WorkspaceRegistry.get_workspace(tab)
	return registry[tab]
end

return WorkspaceRegistry
