local workspace = require('ide.workspaces.workspace')
local panel = require('ide.panels.panel')
local component_factory = require('ide.panels.component_factory')
local test_component = require('ide.panels.test_component')

local M = {}

function M.test_default()
	-- register a component with the component factory
	component_factory.register("test-component", test_component.new)

	-- create a workspace for the current tab.
	local ws = workspace.new(vim.api.nvim_get_current_tabpage())

	-- open the workspace
	ws.init()
	ws.panels[panel.PANEL_POS_TOP].open()
	ws.panels[panel.PANEL_POS_LEFT].open()
	ws.panels[panel.PANEL_POS_RIGHT].open()
	ws.panels[panel.PANEL_POS_BOTTOM].open()
	-- ws.close()
end

function M.test_custom()
	local custom_config = {
		-- A unique name for this workspace
		name = nil,
		-- Defines which panels will be displayed in this workspace along with
		-- a list of component names to register to the displayed panel.
		--
		-- Each key associates a list of component names that should we registered
		-- for that panel.
		--
		-- If the associated list is empyt for a panel at a given position it is
		-- assumed a panel at that position will not be used and the @Workspace will
		-- not instantiate a panel there.
		panels = {
			top = {},
			left = { "test-component", "test-component" },
			right = { "test-component" },
			bottom = { "test-component" }
		}
	}
	-- register a component with the component factory
	component_factory.register("test-component", test_component.new)

	-- create a workspace for the current tab.
	local ws = workspace.new(vim.api.nvim_get_current_tabpage(), custom_config)

	-- open the workspace
	ws.init()
	ws.panels[panel.PANEL_POS_LEFT].open()
	ws.panels[panel.PANEL_POS_RIGHT].open()
	ws.panels[panel.PANEL_POS_BOTTOM].open()
	-- ws.close()
end

return M
