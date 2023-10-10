local config = require("ide.config").config
local panel = require("ide.panels.panel")
local panel_registry = require("ide.panels.panel_registry")
local workspace_registry = require("ide.workspaces.workspace_registry")
local workspace_cmds = require("ide.workspaces.commands")
local component_factory = require("ide.panels.component_factory")
local component_tracker = require("ide.workspaces.component_tracker")
local libwin = require("ide.lib.win")
local logger = require("ide.logger.logger")

local Workspace = {}

-- A Workspace is a control structure which governs a tab's @Panel creations and
-- @Component registrations to these components.
--
-- Workspaces associate with tabs and allow for per-tab manipulation of panels
-- and components.
Workspace.new = function(tab)
	if tab == nil then
		error("cannot construct a workspace with a nil tab")
	end
	if not vim.api.nvim_tabpage_is_valid(tab) then
		error(string.format("attempted to create workspace for invalid tab %d", tab))
	end

	local self = {
		-- the tab which owns this workspace
		tab = nil,
		-- the active @Panel(s) for the workspace.
		panels = {
			top = nil,
			left = nil,
			right = nil,
			bottom = nil,
		},
		-- a map between initialized panels and their panel-group name.
		panel_groups = {},
		-- a running list of editor windows (non-component windows) that this
		-- workspace has visited.
		win_history = {},
		-- tracks component and panel sizes for the workspace.
		component_tracker = nil,
	}

	-- ide.config contains the config already merged with any user modifications,
	-- we can just use the global here.
	self.config = vim.deepcopy(config)

	self.tab = tab

	-- attempt registration
	workspace_registry.register(self)

	function self.normalize_panels(pos)
		-- normalize the panels, because vim is vim, there is no way to ensure
		-- the side panels retain the full height of the editor, other then
		-- the order they are opened in.
		if pos == panel.PANEL_POS_BOTTOM or pos == panel.PANEL_POS_TOP then
			if self.panels[panel.PANEL_POS_LEFT] ~= nil and self.panels[panel.PANEL_POS_LEFT].is_open() then
				self.panels[panel.PANEL_POS_LEFT].close()
				self.panels[panel.PANEL_POS_LEFT].open()
			end
			if self.panels[panel.PANEL_POS_RIGHT] ~= nil and self.panels[panel.PANEL_POS_RIGHT].is_open() then
				self.panels[panel.PANEL_POS_RIGHT].close()
				self.panels[panel.PANEL_POS_RIGHT].open()
			end
		end
	end

	function self.swap_panel(position, panel_group, open)
		if self.panels[position] ~= nil then
			self.panels[position].close()
		end
		if self.panel_groups[panel_group] == nil then
			error(string.format("panel group %s does not exist", panel_group))
		end
		self.panels[position] = self.panel_groups[panel_group]
		self.panels[position].set_position(position, self.config.panel_sizes[position])
		if open then
			self.panels[position].open()
			self.equal_components()
		end
	end

	function self.select_swap_panel(args)
		local groups = {}
		for group, _ in pairs(self.panel_groups) do
			if -- filter our groups we don't want to let users swap.
					group ~= "terminal"
			then
				table.insert(groups, group)
			end
		end
		vim.ui.select(groups, {
			prompt = "Pick a panel group: ",
		}, function(group)
			if group == nil or group == "" then
				return
			end
			vim.ui.select({ "left", "right" }, {
				prompt = "Swap to position: ",
			}, function(position)
				if position == nil or position == "" then
					return
				end
				self.swap_panel(position, group, true)
			end)
		end)
	end

	-- Initialize the workspace, creating the necessary @Panel(s) and registering
	-- the appropriate @Component(s).
	--
	-- Must be called after construction such that the Workspace's tab and config
	-- fields are set.
	function self.init()
		local function init_panels()
			for i, group in pairs(self.config.panel_groups) do
				local components = {}
				for _, name in ipairs(group) do
					local constructor = component_factory.get_constructor(name)
					if constructor ~= nil then
						-- merge the global keymap before construction.
						local comp_config = (config.components[name] or {})
						comp_config.keymaps =
								vim.tbl_extend("force", config.components.global_keymaps, (comp_config.keymaps or {}))

						table.insert(components, constructor(name, comp_config))
					end
				end
				self.panel_groups[i] = panel.new(self.tab, nil, components)
				self.panel_groups[i].set_workspace(self)
			end
		end

		init_panels()

		-- bottom panel is always terminal, user cannot swap this.
		self.swap_panel(panel.PANEL_POS_BOTTOM, "terminal", false)

		for pos, group in pairs(self.config.panels) do
			self.swap_panel(pos, group, false)
		end
		--
		-- set panels open/closed based on config
		if self.config.workspaces.auto_open == "left" then
			self.panels.left.open()
		elseif self.config.workspaces.auto_open == "right" then
			self.panels.right.open()
		elseif self.config.workspaces.auto_open == "both" then
			self.panels.right.open()
			self.panels.left.open()
		elseif self.config.workspaces.auto_open == "none" then
		else
			-- default to 'left'
			self.panels.left.open()
		end
		self.component_tracker = component_tracker.new(self)
		self.component_tracker.refresh()
	end

	-- Closes the workspace.
	-- This will unregister all associated @Panel(s) from the @PanelRegistry
	-- and then unregister itself from the @WorkspaceRegistry
	function self.close()
		local function unregister_panel(pos)
			panel_registry.unregister(self.panels[pos])
		end

		unregister_panel(panel.PANEL_POS_TOP)
		unregister_panel(panel.PANEL_POS_LEFT)
		unregister_panel(panel.PANEL_POS_RIGHT)
		unregister_panel(panel.PANEL_POS_BOTTOM)
	end

	-- Open a panel at the provided position.
	--
	-- @pos - one of @Panel.PANEL_POSITIONS
	-- @return void
	function self.open_panel(pos)
		local restore = libwin.restore_cur_win()
		if self.panels[pos] ~= nil then
			self.panels[pos].open()
		end
		self.normalize_panels(pos)
		restore()
	end

	-- Close a panel at the provided position.
	--
	-- @pos - one of @Panel.PANEL_POSITIONS
	-- @return void
	function self.close_panel(pos)
		local restore = libwin.restore_cur_win()
		if self.panels[pos] ~= nil then
			self.panels[pos].close()
		end
		restore()
	end

	-- Toggle a panel at the provided position.
	--
	-- @pos - one of @Panel.PANEL_POSITIONS
	-- @return void
	function self.toggle_panel(pos)
		local restore = libwin.restore_cur_win()
		if self.panels[pos] ~= nil then
			if self.panels[pos].is_open() then
				self.panels[pos].close()
			else
				self.panels[pos].open()
			end
		end
		self.normalize_panels(pos)
		restore()
	end

	-- Get components will provide a list of the registered components in this
	-- workspace
	--
	-- return: An array of component descriptions. Where a component description is
	--         a table with the following fields:
	--         @name - @string, the unique name of the @Component
	--         @component - @Component, the instance of the @Component
	--         @panel - @Panel, the instance of the @Panel the @Component exists in.
	function self.get_components()
		local components = {}
		for _, p in pairs(self.panels) do
			for _, c in ipairs(p.get_components()) do
				table.insert(components, {
					component = c,
					panel = p,
					name = c.name,
				})
			end
		end
		return components
	end

	-- Search for a registered component in this workspace.
	--
	-- return: A component description. Where a component description is a table
	--         with the following fields:
	--         @name - @string, the unique name of the @Component
	--         @component - @Component, the instance of the @Component
	--         @panel - @Panel, the instance of the @Panel the @Component exists in.
	function self.search_component(name)
		for p, panel in pairs(self.panels) do
			for _, c in ipairs(panel.components) do
				if c.name == name then
					return {
						component = c,
						panel = p,
						name = c.name,
					}
				end
			end
		end
		return nil
	end

	-- Returns an array of command descriptions for this workspace.
	--
	-- return: An array of command descriptions. A command description table is
	--         defined in `ide.lib.commands.prototype`
	function self.get_commands()
		-- these are the workspace related commands displayed to a user such as
		-- manipulating the panels.
		local cmds = workspace_cmds.new(self).get()

		-- now, create synthetic commands for each component, implementing a
		-- "submenu" for the current workspace's component commands.
		for _, c in ipairs(self.get_components()) do
			local cmd = {
				name = c.name,
				shortname = c.name,
				callback = c.component.get_commands,
				kind = "subcommand",
				opts = {
					desc = string.format("%s subcommands", c.name),
				},
			}
			table.insert(cmds, cmd)
		end
		return cmds
	end

	-- Returns the entire history of visited windows in the workspace.
	--
	-- return: @table, an array of win ids, where the largest index is the most
	--         recently viewed window.
	function self.get_win_history()
		return self.win_history
	end

	-- Returns the most recently visited window of the workspace.
	--
	-- return: win id | nil, the most recently visited window in the workspace.
	function self.get_last_visited_win()
		return self.win_history[#self.win_history]
	end

	-- Add a window to the window history
	--
	-- @win - win id, the window to append.
	--
	-- return: void
	function self.append_win_history(win)
		table.insert(self.win_history, win)
	end

	-- Asks the workspace to intelligently provide a window to the caller.
	--
	-- It first attempts to provide the last visited window, if this is not
	-- valid, it performs a search for an file buffer (a buffer with a file loaded).
	--
	-- Finally, if it can't find one, it attempts to make a new window and cleanly
	-- restore the panels.
	function self.get_win(opts)
		local log = logger.new("workspaces", string.format("[%d]Workspace.open_filenode", self.tab))
		log.debug("request to get a window from workspace")

		-- if the last visited window is valid, return this
		local last_win = self.get_last_visited_win()
		if libwin.win_is_valid(last_win) then
			log.debug("last visited window %d is valid, returning this window", last_win)
			return last_win
		end

		-- its not, do we have any non-component windows?
		log.debug("last visited window %d was invalid, searching for open win to use.", last_win)
		for _, w in ipairs(vim.api.nvim_list_wins()) do
			local buf = vim.api.nvim_win_get_buf(w)
			local buf_name = vim.api.nvim_buf_get_name(buf)
			if buf_name == "" then
				goto continue
			end
			-- only consider normal buffers with files loaded into them.
			if vim.api.nvim_buf_get_option(buf, "buftype") ~= "" then
				goto continue
			end
			if string.sub(buf_name, 1, 7) == "diff://" then
				goto continue
			end
			if not string.sub(buf_name, 1, 12) == "component://" then                                                     
				log.debug("found valid window %d with buffer %d %s, returning window to use.", w, buf, buf_name)
				return w
			end 
			::continue::
		end
		log.debug("failed to find a usable window, creating a new one")

		-- there are only component windows, and we must be inside of one...

		-- create a new window via split
		vim.cmd("split")
		local new_win = vim.api.nvim_get_current_win()
		-- we are now inside the split, place an empty buffer in it, and return
		-- this window.
		vim.api.nvim_win_set_buf(new_win, vim.api.nvim_create_buf(false, true))
		-- force the WinEnter command to run on this window so it gets added to
		-- self.win_history
		vim.cmd("doautocmd WinEnter noname")

		-- record which panels are open and close them, only leaving us in a
		-- split
		local restores = {}
		for _, p in pairs(self.panels) do
			if p.is_open() then
				p.close()
				table.insert(restores, function()
					p.open()
					-- normalize the panels
					self.normalize_panels(p.position)
				end)
			end
		end

		-- restore panels
		for _, f in ipairs(restores) do
			f()
		end

		log.debug("created window %d, returning this window.", new_win)
		return new_win
	end

	function self.equal_components()
		for _, p in pairs(self.panels) do
			if p.is_open() then
				p.equal()
			end
		end
	end

	return self
end

return Workspace
