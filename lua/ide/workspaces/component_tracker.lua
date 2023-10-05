local logger = require("ide.logger.logger")
local libwin = require("ide.lib.win")

local ComponentTracker = {}

-- A ComponentTracker is responsible for listening to autocommand events and
-- updating stateful properties of a @Component within a @Panel and storing
-- these updates in the @Component's state field.
ComponentTracker.new = function(workspace)
	local self = {
		-- the @Workspace to track components for.
		-- a table of created autocommands for components being tracked.
		active_autocmds = {},
		workspace = workspace,
	}

	local function find_component_by_win(win)
		if self.workspace.panels.left ~= nil then
			for _, c in ipairs(self.workspace.panels.left.components) do
				if c.win == win then
					return c
				end
			end
		end
		if self.workspace.panels.right ~= nil then
			for _, c in ipairs(self.workspace.panels.right.components) do
				if c.win == win then
					return c
				end
			end
		end
		if self.workspace.panels.bottom ~= nil then
			for _, c in ipairs(self.workspace.panels.bottom.components) do
				if c.win == win then
					return c
				end
			end
		end
		return nil
	end

	function self.on_win_resized_event(args, component)
		local log = logger.new("workspaces", "ComponentTracker.on_win_resized_event")
		log.debug("recording window resizing for each component")
		if self.workspace.tab ~= vim.api.nvim_get_current_tabpage() then
			log.debug("Not for this workspace, returning.")
			return
		end

		local function handle_panel(panel)
			-- update all components h/w, this is necessary since scrolling a
			-- a window does not recursively fire a WinScrolled event for
			-- adjacent component windows.
			for _, cc in ipairs(panel.components) do
				if cc.is_displayed() then
					if cc.state["dimensions"] == nil then
						cc.state["dimensions"] = {}
					end
					local h = vim.api.nvim_win_get_height(cc.win)
					local w = vim.api.nvim_win_get_width(cc.win)
					cc.state["dimensions"].height = h
					cc.state["dimensions"].width = w
				end
			end
		end

		handle_panel(self.workspace.panels.left)
		handle_panel(self.workspace.panels.right)
		handle_panel(self.workspace.panels.bottom)

		log.debug("updated dimensions for components in workspace %s", self.workspace.tab)
	end

	-- an autocmd which records the last cursor position along with a restore
	-- function.
	function self.on_cursor_moved(_, component)
		local log = logger.new("panels", "ComponentTracker.on_cursor_moved")
		local win = vim.api.nvim_get_current_win()

		-- we will allow the passing in of the component, this is helpful on
		-- a call to self.refresh() since we want to populate component state
		-- sometimes before the autocmds fire
		if component ~= nil and component.win ~= nil then
			win = component.win
		end

		log.debug("handling cursor moved event ws %d", self.workspace.tab)
		local c = find_component_by_win(win)
		if c == nil then
			log.debug("nil component for win %d, returning", win)
			return
		end

		local cursor = libwin.get_cursor(win)
		c.state["cursor"] = {
			cursor = cursor,
			-- restore the *current* value of win if possible, this occurs when
			-- the component is toggled closed and open.
			restore = function()
				if not libwin.win_is_valid(c.win) then
					return
				end
				libwin.safe_cursor_restore(c.win, c.state["cursor"].cursor)
			end,
		}
		log.debug("wrote cursor update to component state: cursor [%d,%d]", cursor[1], cursor[2])
	end

	-- used to register autocommands on panel changes, like registering a new
	-- component.
	function self.refresh()
		local log = logger.new("panels", "ComponentTracker.refresh")
		log.debug("refreshing component tracker for workspace %d", self.workspace.tab)

		for _, aucmd in ipairs(self.active_autocmds) do
			vim.api.nvim_del_autocmd(aucmd.id)
		end

		self.active_autocmds = (function()
			return {}
		end)()

		table.insert(self.active_autocmds, {
			id = vim.api.nvim_create_autocmd("WinResized", {
				callback = self.on_win_resized_event,
			}),
		})

		table.insert(self.active_autocmds, {
			id = vim.api.nvim_create_autocmd({ "CursorMoved" }, {
				pattern = "component://*",
				callback = self.on_cursor_moved,
			}),
		})

			self.on_cursor_moved(nil)
			self.on_win_resized_event(nil)
	end

	function self.stop() end

	return self
end

return ComponentTracker
