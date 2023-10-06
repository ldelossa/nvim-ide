local logger = require("ide.logger.logger")
local libwin = require("ide.lib.win")
local libpopup = require("ide.lib.popup")

local Component = {}

-- Component is a base class for a derived Component.
--
-- A component implements a particular plugin registered in a Panel.
--
-- A derived Component must implement:
--  open()
--  post_win_create()
--  get_commands()
--  close()
--
-- A component is expected to create a buffer and provide this on request from
-- a Panel.
--
-- The component is free to evaluate both its own state and Neovim's and return
-- a new buffer or an existing one.
--
-- The Panel will then create a window in the appropriate place and set the
-- Component's fields accordingly.
--
-- The same Component instance should not be shared across panels.
--
-- If the Component author wants to have their Component present in multiple
-- panels it should return the same buffer across Component instances.
--
-- @name - @string, a unique name in camel case which identifies this component.
-- @config - @table, a table consisting of component specific configuration.
Component.new = function(name, config)
	assert(name ~= nil, "Cannot construct a component without a unique name.")
	local self = {
		-- a unique name for this component.
		name = name,
		-- the component's panel window id.
		win = nil,
		-- the component's buffer containing the components UI.
		buf = nil,
		-- whether the component is hidden from the Panel_t.
		hidden = nil,
		-- the panel this component has been registered with.
		panel = nil,
		-- the workspace this component belongs to.
		workspace = nil,
		-- any component specific config passed in from the caller on construction.
		config = {},
		-- component specific state for use with implementations.
		-- implementations may store any private data here.
		state = {
			-- ensure a cursor restore just no-ops, this field is replaced once
			-- a panel begins tracking the component.
			cursor = {
				restore = function() end,
			},
		},
		-- a default logger that's set on construction.
		-- a derived class can set this logger instance and base class methods will
		-- derive a new logger from it to handle base class component level log fields.
		logger = logger.new("panels"),
	}
	if config ~= nil then
		self.config = config
	end

	-- An interface method which must be defined by a derived Component.
	--
	-- The method is invoked to display the implemented Component's UI buffer.
	--
	-- The Component_t must return a buffer ID with the component's UI rendered within
	-- it.
	--
	-- The Component is free to perform any plugin related tasks required before its
	-- window is displayed in the panel during this method.
	--
	-- @return: buffer id
	function self.open()
		error("Component must implement open method")
	end

	-- An interface method which must be defined by a derived Component.
	--
	-- The method is invoked just after a Panel displays the registered Component.
	--
	-- When this method is invoked Neovim's current window will be the Component's
	-- window within the Panel.
	--
	-- Any per-window configurations can be applied on this hook.
	--
	-- @return: void
	function self.post_win_create()
		error("Component must implement post_win_create method")
	end

	-- An interface method which must be defined by a derived Component.
	--
	-- When this method is invoked it signals to the derived Component that
	-- the Component will no longer be used.
	--
	-- The derived Component can safely free any resources associated with the
	-- Component during or any time after this method call.
	function self.close()
		error("Component must implement close method")
	end

	-- An interface method which must be defined by a derived Component.
	--
	-- Returns an array of command descriptions for this workspace.
	--
	-- When called from a @WorkSpace the @name field described below is displayed
	-- to the user, since it will be accessed from a subcomand menu matching the
	-- Component's name.
	--
	-- A @shortcut can be presented which will register a fully unique name for
	-- the command, which can be used to access the command quicker, and without
	-- hopping through sub-menus.
	--
	-- return: @table, An array of command descriptions. A command description is a table
	--         with the following fields:
	--         @shortname - @string, A name used when displayed by a subcommand
	--         @name - @string, A unique name of the command used outside the context
	--         of a sub command
	--         @callback - @function(args), A callback function which implements
	--         the command, args a table described in ":h nvim_create_user_command()"
	--         @opts - @table, the options table as described in ":h nvim_create_user_command()"
	function self.get_commands()
		error("Component must implement get_commands method")
	end

	-- Determines if this Component is currently displayed inside a Panel
	--
	-- @return: void
	function self.is_displayed()
		local log = self.logger.logger_from(nil, "Component.is_displayed")
		if self.win == nil then
			log.debug("component %s is not being displayed", self.name)
			return false
		end
		for _, w in ipairs(vim.api.nvim_list_wins()) do
			if w == self.win then
				if vim.api.nvim_win_is_valid(w) then
					log.debug("component %s is being displayed", self.name)
					return true
				end
			end
		end
		return false
	end

	-- Determines if this Component is valid.
	--
	-- Validity checks can be overwritten by a derived Component.
	--
	-- The default implementation simply checks if self.buf is valid.
	--
	-- @return: bool
	function self.is_valid()
		local log = self.logger.logger_from(nil, "Component.is_valid")
		return self.buf ~= nil and vim.api.nvim_buf_is_valid(self.buf)
	end

	-- Set the component's win as the current window.
	--
	-- @return: void
	function self.focus(cb)
		local log = self.logger.logger_from(nil, "Component.focus")
		local ws = nil
		if self.workspace ~= nil then
			ws = self.workspace.tab
		end
		log.debug("component %s in workspace %d wants focus", self.name, ws)

		if self.panel == nil then
			log.error("wanted focus but has nil panel, returning")
			return
		end

		-- unhide ourselves.
		if self.hidden then
			self.hidden = false
			-- close the panel, when opened again this component will be
			-- no longer hidden.
			self.panel.close()
		end

		if not self.panel.is_open() then
			log.debug("panel is not open, opening panel to display component")
			self.panel.open()
		end

		if not libwin.win_is_valid(self.win) then
			-- this could be okay, if the component doesn't want to be displayed,
			-- currently, the panel won't create a win for it.
			log.warning("panel opened but component's win is invalid.", self.name, self.win)
			return
		end

		-- normalize the panels, since we may have opened it.
		self.workspace.normalize_panels(self.panel.position)

		vim.api.nvim_set_current_win(self.win)
		log.debug("component %s focused", self.name)
	end

	-- Toggle the component hidden.
	--
	-- If bool is true the component will be closed (if displayed) and its hidden
	-- field will be set to true.
	--
	-- If bool is false the component's hidden field is set to false, but the
	-- Panel is responsible for re-rendering the component.
	--
	-- @return: bool
	function self.hide()
		local log = self.logger.logger_from(nil, "Component.hide")
		if self.is_displayed() then
			vim.api.nvim_win_close(self.win, true)
		end
		self.hidden = true
	end

	-- If a derived component has a 'self.config.keymaps' field we can display
	-- it nicely for the user.
	function self.help_keymaps()
		if self.config == nil or self.config.keymaps == nil then
			return
		end
		local lines = {}
		table.insert(lines, string.format("Keymaps:"))
		-- short self.config.keymaps alphabetically for consistent printing
		local sorted = {}
		for k, _ in pairs(self.config.keymaps) do
			table.insert(sorted, k)
		end
		table.sort(sorted, function(a, b)
			return a < b
		end)
		-- iterate over key and value in self.config.keymaps and format it
		-- nicely for the user
		for _, k in ipairs(sorted) do
			local v = self.config.keymaps[k]
			table.insert(lines, string.format("\t%s => %s\t\t\t\t", k, v))
		end
		libpopup.until_cursor_move(lines)
	end

	function self.minimize()
		local log = self.logger.logger_from(nil, "Component.minimize")
		if self.panel == nil then
			log.error("component %s wanted to minimize but had no panel", self.name)
		end
		if self.panel.position == "left" or self.panel.position == "right" then
			log.debug("adjusting win height of component %s due to panel position: %s", self.name, self.panel.position)
			vim.api.nvim_win_set_height(self.win, 0)
		else
			log.debug("adjusting win width of component %s due to panel position: %s", self.name, self.panel.position)
			vim.api.nvim_win_set_width(self.win, 0)
		end
		log.debug("minimized component %s", self.name)
	end

	function self.maximize()
		local log = self.logger.logger_from(nil, "Component.maximize")
		if self.panel == nil then
			log.error("component %s wanted to maximize but had no panel", self.name)
		end
		if self.panel.position == "left" or self.panel.position == "right" then
			log.debug("adjusting win height of component %s due to panel position: %s", self.name, self.panel.position)
			vim.api.nvim_win_set_height(self.win, 9999)
		else
			log.debug("adjusting win width of component %s due to panel position: %s", self.name, self.panel.position)
			vim.api.nvim_win_set_width(self.win, 9999)
		end
		log.debug("maximized component %s", self.name)
	end

	-- Returns whether the component is hidden in the panel.
	--
	-- @return: bool
	function self.is_hidden()
		local log = self.logger.logger_from(nil, "Component.is_hidden")
		return self.hidden
	end

	-- Will returns the cursor to the last recorded position, if it exists.
	--
	-- The @ComponentTracker is responsible for this state.
	function self.safe_cursor_restore() end

	function self.restore_dimensions()
		if self.state["dimensions"] ~= nil and libwin.win_is_valid(self.win) then
			vim.api.nvim_win_set_height(self.win, self.state["dimensions"].height)
			vim.api.nvim_win_set_width(self.win, self.state["dimensions"].width)
		end
	end

	return self
end

return Component
