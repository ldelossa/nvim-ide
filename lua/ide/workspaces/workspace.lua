local panel              = require('ide.panels.panel')
local panel_registry     = require('ide.panels.panel_registry')
local workspace_registry = require('ide.workspaces.workspace_registry')
local workspace_cmds     = require('ide.workspaces.commands')
local component_factory  = require('ide.panels.component_factory')
local libwin             = require('ide.lib.win')
local logger             = require('ide.logger.logger')

-- default components
local explorer      = require('ide.components.explorer')
local outline       = require('ide.components.outline')
local callhierarchy = require('ide.components.callhierarchy')
local timeline      = require('ide.components.timeline')
local terminal      = require('ide.components.terminal')
local terminalbrowser = require('ide.components.terminal.terminalbrowser')
local changes       = require('ide.components.changes')
local bookmarks     = require('ide.components.bookmarks')

Workspace = {}

-- A prototype which defines a Workspace configuration.
--
-- The config instructs the @Workspace to create the desired panels and
-- register the desired components.
local config_prototype = {
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
        left = { outline.Name, explorer.Name, callhierarchy.Name, changes.Name, timeline.Name, terminalbrowser.Name},
        right = { bookmarks.Name },
        bottom = { terminal.Name }
    }
}

-- A Workspace is a control structure which governs a tab's @Panel creations and
-- @Component registrations to these components.
--
-- A @config_prototype is used to define exactly how a Workspace performs these
-- creations.
--
-- Workspaces associate with tabs and allow for per-tab manipulation of panels
-- and components.
Workspace.new = function(tab, config)
    if tab == nil then
        error("cannot construct a workspace with a nil tab")
    end
    if not vim.api.nvim_tabpage_is_valid(tab) then
        error(string.format("attempted to create workspace for invalid tab %d", tab))
    end

    local self = {
        -- the tab which owns this workspace
        tab = nil,
        -- the constructed @Panel objects for this workspace.
        panels = {
            top = nil,
            left = nil,
            right = nil,
            bottom = nil,
        },
        -- the Workspace config which constructs the Workspace to initialize specific
        -- panels and components.
        config = vim.deepcopy(config_prototype),
        -- a running list of editor windows (non-component windows) that this
        -- workspace has visited.
        win_history = {}
    }

    -- a pre-baked workspace could be passed in via config, replace the default.
    if config ~= nil then
        -- TODO: validate config
        self.config = config
    end
    self.tab = tab

    -- attempt registration
    workspace_registry.register(self)

    function self.normalize_panels(pos)
        -- normalize the panels, because vim is vim, there is no way to ensure
        -- the side panels retain the full height of the editor, other then
        -- the order they are opened in.
        if pos == panel.PANEL_POS_BOTTOM or pos == panel.PANEL_POS_TOP then
            if self.panels[panel.PANEL_POS_LEFT] ~= nil and
                self.panels[panel.PANEL_POS_LEFT].is_open() then
                self.panels[panel.PANEL_POS_LEFT].close()
                self.panels[panel.PANEL_POS_LEFT].open()
            end
            if self.panels[panel.PANEL_POS_RIGHT] ~= nil and
                self.panels[panel.PANEL_POS_RIGHT].is_open() then
                self.panels[panel.PANEL_POS_RIGHT].close()
                self.panels[panel.PANEL_POS_RIGHT].open()
            end
        end
    end

    local function _normalize_panels(pos)
        -- normalize the panels, because vim is vim, there is no way to ensure
        -- the side panels retain the full height of the editor, other then
        -- the order they are opened in.
        if pos == panel.PANEL_POS_BOTTOM or pos == panel.PANEL_POS_TOP then
            if self.panels[panel.PANEL_POS_LEFT] ~= nil and
                self.panels[panel.PANEL_POS_LEFT].is_open() then
                self.panels[panel.PANEL_POS_LEFT].close()
                self.panels[panel.PANEL_POS_LEFT].open()
            end
            if self.panels[panel.PANEL_POS_RIGHT] ~= nil and
                self.panels[panel.PANEL_POS_RIGHT].is_open() then
                self.panels[panel.PANEL_POS_RIGHT].close()
                self.panels[panel.PANEL_POS_RIGHT].open()
            end
        end
    end
    -- Initialize the workspace, creating the necessary @Panel(s) and registering
    -- the appropriate @Component(s).
    --
    -- Must be called after construction such that the Workspace's tab and config
    -- fields are set.
    function self.init()
        local function init_panel(pos)
            if #self.config.panels[pos] ~= 0 then
                local components = {}
                for _, c_name in ipairs(self.config.panels[pos]) do
                    local constructor = component_factory.get_constructor(c_name)
                    if constructor == nil then
                        -- noop
                    else
                        table.insert(components, constructor(c_name))
                    end
                end
                self.panels[pos] = panel.new(self.tab, pos, components)
                self.panels[pos].set_workspace(self)
                self.panels[pos].open()
                self.normalize_panels(pos)
            end
        end

        -- order matters here, since we want left and right to take full height.
        -- TODO: enforce this in workspace.open_panel(), as it has a full view
        -- of available opened panels.
        init_panel(panel.PANEL_POS_TOP)
        init_panel(panel.PANEL_POS_BOTTOM)
        init_panel(panel.PANEL_POS_LEFT)
        init_panel(panel.PANEL_POS_RIGHT)
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
                    desc = string.format("%s subcommands", c.name)
                }
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
    function self.get_last_visted_win()
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
        local last_win = self.get_last_visted_win()
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
            if vim.fn.match("component://", buf_name) == 0 then
                log.debug("found valid window %d with buffer %d %s, returning window to use.", w, buf, buf_name)
                return w
            end
            ::continue::
        end
        log.debug("failed to find a useable window, creating a new one")

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
